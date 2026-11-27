package app.geocent.data

import app.geocent.data.db.BudgetEntity
import app.geocent.data.db.TransactionEntity
import app.geocent.domain.model.BudgetPeriod
import app.geocent.domain.model.TransactionSource
import app.geocent.domain.model.TransactionType
import app.geocent.domain.toEpochMillis
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime
import java.time.ZoneId

class BudgetProgressTest {
    private val zone = ZoneId.of("Africa/Nairobi")
    private val now = LocalDateTime.of(2026, 11, 27, 18, 0) // Friday

    private fun budget(category: String, limit: Double, period: BudgetPeriod) =
        BudgetEntity("b-$category", category, limit, period, 0L)

    private fun tx(id: String, category: String?, amount: Double, at: LocalDateTime, currency: String = "KES", type: TransactionType = TransactionType.PAYMENT) =
        TransactionEntity(id, amount, currency, "M", "", at.toEpochMillis(zone), null, TransactionSource.MPESA, type, category = category)

    @Test
    fun `each budget counts only its own period`() {
        val txs = listOf(
            tx("today", "Dining", 300.0, now.minusHours(2)),
            tx("monday", "Dining", 200.0, LocalDateTime.of(2026, 11, 23, 12, 0)),
            tx("lastMonth", "Dining", 999.0, LocalDateTime.of(2026, 10, 30, 12, 0)),
        )
        val progress = budgetProgress(
            listOf(
                budget("Dining", 1000.0, BudgetPeriod.DAILY),
            ),
            txs, now, zone,
        )
        assertEquals(300.0, progress.single().spent, 0.0)

        val weekly = budgetProgress(listOf(budget("Dining", 1000.0, BudgetPeriod.WEEKLY)), txs, now, zone)
        assertEquals(500.0, weekly.single().spent, 0.0)
    }

    @Test
    fun `ignores other categories, received money and USD`() {
        val txs = listOf(
            tx("a", "Dining", 100.0, now),
            tx("b", "Taxi", 50.0, now),
            tx("c", "Dining", 70.0, now, type = TransactionType.RECEIVED),
            tx("d", "Dining", 9.99, now, currency = "USD"),
        )
        val p = budgetProgress(listOf(budget("Dining", 1000.0, BudgetPeriod.MONTHLY)), txs, now, zone).single()
        assertEquals(100.0, p.spent, 0.0)
    }

    @Test
    fun `levels and exceeded`() {
        val b = budget("Dining", 1000.0, BudgetPeriod.MONTHLY)
        assertEquals(BudgetProgress.Level.LOW, BudgetProgress(b, 499.0).level)
        assertEquals(BudgetProgress.Level.MEDIUM, BudgetProgress(b, 500.0).level)
        assertEquals(BudgetProgress.Level.HIGH, BudgetProgress(b, 800.0).level)
        assertTrue(BudgetProgress(b, 1200.0).exceeded)
        assertEquals(-200.0, BudgetProgress(b, 1200.0).remaining, 0.0)
    }

    @Test
    fun `earliest period start covers week and month`() {
        // 1 Dec 2026 is a Tuesday: the week began Sunday 29 Nov, before the month.
        assertEquals(LocalDateTime.of(2026, 11, 29, 0, 0), earliestPeriodStart(LocalDateTime.of(2026, 12, 1, 9, 0)))
        assertEquals(LocalDateTime.of(2026, 11, 1, 0, 0), earliestPeriodStart(now))
    }
}
