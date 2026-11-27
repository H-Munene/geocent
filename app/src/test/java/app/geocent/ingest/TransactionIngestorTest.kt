package app.geocent.ingest

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import app.geocent.data.BudgetRepository
import app.geocent.data.TransactionRepository
import app.geocent.data.db.GeocentDatabase
import app.geocent.domain.model.BudgetPeriod
import app.geocent.location.LatLng
import app.geocent.location.LocationProvider
import app.geocent.notify.BudgetChecker
import app.geocent.notify.Notifier
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TransactionIngestorTest {
    private lateinit var db: GeocentDatabase
    private lateinit var transactions: TransactionRepository
    private lateinit var budgets: BudgetRepository
    private var location: LatLng? = LatLng(-1.2864, 36.8172)

    private val fakeLocation = object : LocationProvider {
        override suspend fun currentLocation() = location
    }

    private var refreshes = 0
    private val refresher = object : HotspotRefresher { override fun requestRefresh() { refreshes++ } }

    private fun ingestor(): TransactionIngestor {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val notifier = Notifier(context)
        return TransactionIngestor(
            transactions, fakeLocation, BudgetChecker(budgets, transactions, notifier), notifier,
            app.geocent.data.settings.SettingsStore(context), refresher,
        )
    }

    /** A real-format M-PESA payment dated now, so it falls inside this week's budget. */
    private fun paidNow(code: String, amount: String, merchant: String = "JAVA HOUSE"): String {
        val now = LocalDateTime.now()
        val date = "${now.dayOfMonth}/${now.monthValue}/${now.year % 100}"
        val time = now.format(DateTimeFormatter.ofPattern("h:mm a", java.util.Locale.US))
        return "$code Confirmed. Ksh$amount paid to $merchant. on $date at $time. New M-PESA balance is Ksh1,000.00."
    }

    @Before
    fun setUp() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        db = Room.inMemoryDatabaseBuilder(context, GeocentDatabase::class.java).allowMainThreadQueries().build()
        transactions = TransactionRepository(db.transactions(), db.merchantCategories())
        budgets = BudgetRepository(db.budgets())
    }

    @After
    fun tearDown() = db.close()

    @Test
    fun `live SMS is stored and geotagged`() = runTest {
        val saved = ingestor().ingestLive(paidNow("LIVE000001", "450.00"))!!
        val stored = transactions.get(saved.id)!!
        assertEquals(-1.2864, stored.latitude!!, 0.0)
        assertEquals(36.8172, stored.longitude!!, 0.0)
        assertEquals(1, refreshes) // a new location re-clusters hotspots
    }

    @Test
    fun `without a location fix the transaction is kept unmapped`() = runTest {
        location = null
        val saved = ingestor().ingestLive(paidNow("LIVE000002", "450.00"))!!
        assertFalse(transactions.get(saved.id)!!.hasLocation)
    }

    @Test
    fun `non-financial and duplicate SMS are skipped`() = runTest {
        val ingestor = ingestor()
        assertNull(ingestor.ingestLive("Your OTP is 123456"))
        assertTrue(ingestor.ingestHistorical(paidNow("HIST000001", "10.00")))
        assertFalse(ingestor.ingestHistorical(paidNow("HIST000001", "10.00")))
    }

    @Test
    fun `budget alert threshold is recorded once crossed`() = runTest {
        val ingestor = ingestor()
        // Teach the merchant's category, then set a weekly budget for it.
        val first = ingestor.ingestLive(paidNow("BUDG000001", "100.00"))!!
        transactions.setCategory(listOf(first.id), "Dining")
        budgets.save("Dining", limit = 1000.0, period = BudgetPeriod.WEEKLY)

        ingestor.ingestLive(paidNow("BUDG000002", "500.00")) // 600 of 1000 -> 50%
        assertEquals(50, budgets.forCategory("Dining")!!.lastNotifiedThreshold)

        ingestor.ingestLive(paidNow("BUDG000003", "250.00")) // 850 -> 80%
        assertEquals(80, budgets.forCategory("Dining")!!.lastNotifiedThreshold)
    }
}
