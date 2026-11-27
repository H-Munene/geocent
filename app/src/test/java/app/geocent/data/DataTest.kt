package app.geocent.data

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import app.geocent.data.db.GeocentDatabase
import app.geocent.data.db.TransactionEntity
import app.geocent.domain.SmsParser
import app.geocent.domain.model.TransactionSource
import app.geocent.domain.model.TransactionType
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.LocalDateTime
import java.time.ZoneId

class MessageQueryTest {
    private val now = LocalDateTime.of(2026, 11, 27, 12, 0)

    @Test
    fun `search normalises commas dashes and spaces`() {
        val sql = MessageQuery.where(MessageFilter.ALL, "Ksh 1,200", MessageAge.ANY, now)
        assertTrue(sql.where.contains("LIKE ?"))
        assertEquals(listOf("%ksh1200%"), sql.args)
    }

    @Test
    fun `filters combine with AND`() {
        val sql = MessageQuery.where(MessageFilter.NEEDS_CATEGORY, null, MessageAge.YESTERDAY, now)
        assertEquals(
            "WHERE (category IS NULL AND latitude IS NOT NULL) AND timestamp >= ? AND timestamp < ?",
            sql.where,
        )
        assertEquals(2, sql.args.size)
    }

    @Test
    fun `no conditions means no WHERE`() {
        assertEquals("", MessageQuery.where(MessageFilter.ALL, "  ", MessageAge.ANY, now).where)
    }
}

class AreaSpendingTest {
    private fun tx(id: String, lat: Double, lng: Double, amount: Double, category: String?) =
        TransactionEntity(
            id = id, amount = amount, currency = "KES", merchant = "M$id", rawMessage = "",
            timestamp = id.hashCode().toLong(), balanceAfter = null,
            source = TransactionSource.MPESA, type = TransactionType.PAYMENT,
            latitude = lat, longitude = lng, category = category,
        )

    @Test
    fun `keeps only points inside the radius and ranks categories`() {
        val center = -1.2864 to 36.8172
        val near1 = tx("a", -1.2865, 36.8173, 300.0, "Dining")
        val near2 = tx("b", -1.2866, 36.8170, 200.0, "Taxi")
        val near3 = tx("c", -1.2863, 36.8174, 150.0, "Dining")
        val far = tx("d", -1.3000, 36.8172, 999.0, "Dining") // ~1.5 km away

        val s = summarizeArea(listOf(near1, near2, near3, far), center.first, center.second, 200.0)

        assertEquals(3, s.count)
        assertEquals(650.0, s.total, 0.0)
        assertEquals("Dining" to 450.0, s.topCategories.first())
        assertEquals(650.0 / 3, s.average, 0.001)
    }

    @Test
    fun `empty area`() {
        assertEquals(AreaSummary.EMPTY, summarizeArea(emptyList(), 0.0, 0.0, 100.0))
    }
}

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TransactionRepositoryTest {
    private lateinit var db: GeocentDatabase
    private lateinit var repo: TransactionRepository
    private val zone = ZoneId.of("Africa/Nairobi")

    private val paid = "UDR0H250GJ Confirmed. Ksh750.00 paid to PAGE ALLIANCE CONSULTANTS. " +
        "on 27/4/26 at 9:58 PM. New M-PESA balance is Ksh1,037.84."

    @Before
    fun setUp() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        db = Room.inMemoryDatabaseBuilder(context, GeocentDatabase::class.java)
            .addCallback(GeocentDatabase.seedCallback)
            .allowMainThreadQueries()
            .build()
        repo = TransactionRepository(db.transactions(), db.merchantCategories())
    }

    @After
    fun tearDown() = db.close()

    @Test
    fun `saves once, then skips duplicates and forgotten ids`() = runTest {
        val parsed = SmsParser.parse(paid)!!
        assertNotNull(repo.save(parsed, zone))
        assertNull(repo.save(parsed, zone))

        repo.forget(listOf(parsed.id))
        assertNull(repo.get(parsed.id))
        assertNull(repo.save(parsed, zone))
    }

    @Test
    fun `learns merchant categories`() = runTest {
        val first = repo.save(SmsParser.parse(paid)!!, zone)!!
        repo.setCategory(listOf(first.id), "Services")

        val again = SmsParser.parse(paid.replace("UDR0H250GJ", "UDR0H250GK"))!!
        assertEquals("Services", repo.save(again, zone)!!.category)
    }

    @Test
    fun `daily totals group by local day`() = runTest {
        // 21:58 in Nairobi must stay on 27 April (the old ISO+localtime bug moved it to the 28th).
        repo.save(SmsParser.parse(paid)!!, zone)
        val start = LocalDateTime.of(2026, 4, 1, 0, 0).atZone(zone).toInstant().toEpochMilli()
        val end = LocalDateTime.of(2026, 4, 30, 23, 59).atZone(zone).toInstant().toEpochMilli()
        val days = withTimeZone(zone) { repo.dailyCategoryTotals(start, end) }
        assertEquals("2026-04-27", days.single().day)
    }

    @Test
    fun `default categories are seeded`() = runTest {
        val categories = db.categories().observeAll().first()
        assertEquals(16, categories.size)
        assertEquals("Dining", categories.first().name)
    }

    private suspend fun <T> withTimeZone(zone: ZoneId, block: suspend () -> T): T {
        val previous = java.util.TimeZone.getDefault()
        java.util.TimeZone.setDefault(java.util.TimeZone.getTimeZone(zone))
        return try { block() } finally { java.util.TimeZone.setDefault(previous) }
    }
}
