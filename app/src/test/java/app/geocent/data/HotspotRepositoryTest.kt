package app.geocent.data

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import app.geocent.data.db.GeocentDatabase
import app.geocent.data.db.TransactionEntity
import app.geocent.domain.model.TransactionSource
import app.geocent.domain.model.TransactionType
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class HotspotRepositoryTest {
    private lateinit var db: GeocentDatabase
    private lateinit var repo: HotspotRepository

    @Before
    fun setUp() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        db = Room.inMemoryDatabaseBuilder(context, GeocentDatabase::class.java).allowMainThreadQueries().build()
        repo = HotspotRepository(db.hotspots(), db.transactions())
    }

    @After
    fun tearDown() = db.close()

    private suspend fun spendNear(prefix: String, lat: Double, lng: Double, n: Int) = repeat(n) { i ->
        db.transactions().insert(
            TransactionEntity(
                "$prefix$i", 100.0, "KES", "Shop", "", i.toLong(), null,
                TransactionSource.MPESA, TransactionType.PAYMENT,
                latitude = lat + i * 0.0001, longitude = lng + i * 0.0001,
            ),
        )
    }

    @Test
    fun `needs ten geotagged payments before clustering`() = runTest {
        spendNear("a", -1.2864, 36.8172, 9)
        assertTrue(repo.recompute().isEmpty())
    }

    @Test
    fun `recomputing keeps the id and alert cooldown of a surviving hotspot`() = runTest {
        spendNear("a", -1.2864, 36.8172, 10)
        val first = repo.recompute().single()
        repo.markNotified(first.id, 12345L)

        spendNear("b", -1.2865, 36.8173, 3) // more spending at the same spot
        val second = repo.recompute().single()
        assertEquals(first.id, second.id)
        assertEquals(12345L, second.lastNotifiedAt)
        assertEquals(13, second.transactionCount)
    }
}
