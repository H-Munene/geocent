package app.geocent.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.Year
import java.time.YearMonth
import java.util.Locale

class AnalyticsTest {
    private val today = LocalDate.of(2026, 11, 27) // Friday; week = Sun 22 .. Sat 28 Nov

    private fun spend(day: Int, amount: Double, category: String?, recipient: String = "R", month: Int = 11, year: Int = 2026) =
        Spend(LocalDateTime.of(year, month, day, 12, 0), amount, category, recipient)

    @Test
    fun `week range has seven Sunday-first daily buckets and a previous week`() {
        val range = AnalyticsRange.week(today)
        assertEquals(LocalDateTime.of(2026, 11, 22, 0, 0), range.start)
        assertEquals(LocalDateTime.of(2026, 11, 15, 0, 0), range.previousStart)

        val r = analyse(listOf(spend(22, 100.0, "Dining"), spend(27, 50.0, null)), range, Locale.US)
        assertEquals(7, r.buckets.size)
        assertEquals("S", r.buckets.first().label)
        assertEquals(100.0, r.buckets[0].total, 0.0)
        assertEquals(50.0, r.buckets[5].total, 0.0)
    }

    @Test
    fun `trend compares with the previous period`() {
        val range = AnalyticsRange.week(today)
        val r = analyse(listOf(spend(16, 100.0, "Dining"), spend(23, 150.0, "Dining")), range)
        assertEquals(0.5, r.trend!!, 1e-9)
        assertNull(analyse(listOf(spend(23, 150.0, "Dining")), range).trend)
    }

    @Test
    fun `breakdowns rank by total with shares`() {
        val range = AnalyticsRange.month(YearMonth.of(2026, 11), current = true)
        val r = analyse(
            listOf(
                spend(2, 300.0, "Dining", "Java"),
                spend(3, 100.0, "Taxi", "Uber"),
                spend(4, 100.0, null, "Java"),
            ),
            range,
        )
        assertEquals(30, r.buckets.size)
        assertEquals(listOf("Dining", "Taxi", NO_CATEGORY), r.categories.map { it.name })
        assertEquals(0.6, r.categories.first().share, 1e-9)
        assertEquals("Java", r.recipients.first().name)
        assertEquals(2, r.recipients.first().count)
    }

    @Test
    fun `year range buckets by month`() {
        val r = analyse(listOf(spend(5, 10.0, "A", month = 3), spend(6, 20.0, "A", month = 3)), AnalyticsRange.year(Year.of(2026), true), Locale.US)
        assertEquals(12, r.buckets.size)
        assertEquals(30.0, r.buckets[2].total, 0.0)
        assertEquals("M", r.buckets[2].label)
    }
}
