package app.geocent.domain

import app.geocent.domain.model.BudgetPeriod
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime

class PeriodsTest {
    @Test
    fun `weeks start on Sunday`() {
        // 2026-11-27 is a Friday; the week started Sunday 2026-11-22.
        assertEquals(LocalDate.of(2026, 11, 22), startOfWeek(LocalDate.of(2026, 11, 27)))
        // A Sunday is its own week start.
        assertEquals(LocalDate.of(2026, 11, 22), startOfWeek(LocalDate.of(2026, 11, 22)))
        // Saturday belongs to the week that began six days earlier.
        assertEquals(LocalDate.of(2026, 11, 22), startOfWeek(LocalDate.of(2026, 11, 28)))
    }

    @Test
    fun `period starts`() {
        val now = LocalDateTime.of(2026, 11, 27, 22, 15)
        assertEquals(LocalDateTime.of(2026, 11, 27, 0, 0), periodStart(BudgetPeriod.DAILY, now))
        assertEquals(LocalDateTime.of(2026, 11, 22, 0, 0), periodStart(BudgetPeriod.WEEKLY, now))
        assertEquals(LocalDateTime.of(2026, 11, 1, 0, 0), periodStart(BudgetPeriod.MONTHLY, now))
        assertEquals(LocalDateTime.of(2026, 11, 30, 23, 59, 59), thisMonth(now).end)
    }
}

class GeoTest {
    @Test
    fun `distance between two Nairobi points`() {
        // Kenyatta Avenue to Moi Avenue, roughly 300 m apart.
        val d = distanceMeters(-1.2833, 36.8219, -1.2860, 36.8227)
        assertTrue("was $d", d in 280.0..340.0)
    }

    @Test
    fun `bounding box contains the circle`() {
        val box = boundingBox(-1.2864, 36.8172, 500.0)
        assertTrue(distanceMeters(-1.2864, 36.8172, box.maxLat, 36.8172) in 495.0..505.0)
        assertTrue(distanceMeters(-1.2864, 36.8172, -1.2864, box.maxLng) in 495.0..505.0)
    }
}

class BudgetAlertsTest {
    private val start = LocalDateTime.of(2026, 11, 22, 0, 0)

    @Test
    fun `fires the highest newly crossed threshold once`() {
        assertNull(nextBudgetAlert(400.0, 1000.0, 0, null, start))
        assertEquals(50, nextBudgetAlert(500.0, 1000.0, 0, null, start))
        assertEquals(80, nextBudgetAlert(850.0, 1000.0, 0, null, start))
        assertEquals(100, nextBudgetAlert(1200.0, 1000.0, 50, start.plusDays(1), start))
        assertNull(nextBudgetAlert(900.0, 1000.0, 80, start.plusDays(1), start))
    }

    @Test
    fun `resets in a new period`() {
        val lastWeek = start.minusDays(2)
        assertEquals(50, nextBudgetAlert(600.0, 1000.0, 100, lastWeek, start))
    }

    @Test
    fun `no alert without a limit`() {
        assertNull(nextBudgetAlert(600.0, 0.0, 0, null, start))
    }
}
