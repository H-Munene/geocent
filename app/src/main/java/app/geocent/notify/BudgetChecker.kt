package app.geocent.notify

import app.geocent.data.BudgetRepository
import app.geocent.data.TransactionRepository
import app.geocent.domain.nextBudgetAlert
import app.geocent.domain.periodStart
import app.geocent.domain.toEpochMillis
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import javax.inject.Inject
import javax.inject.Singleton

/** Sends the 50/80/100% budget alert for a category when one is due. */
@Singleton
class BudgetChecker @Inject constructor(
    private val budgets: BudgetRepository,
    private val transactions: TransactionRepository,
    private val notifier: Notifier,
) {
    suspend fun check(category: String, nearHotspot: Boolean = false, zone: ZoneId = ZoneId.systemDefault()) {
        val budget = budgets.forCategory(category) ?: return
        val now = LocalDateTime.now(zone)
        val start = periodStart(budget.period, now)
        val spent = transactions.categorySpending(category, start.toEpochMillis(zone), now.toEpochMillis(zone))
        val lastAt = budget.lastNotifiedAt?.let { LocalDateTime.ofInstant(Instant.ofEpochMilli(it), zone) }

        val threshold = nextBudgetAlert(spent, budget.amountLimit, budget.lastNotifiedThreshold, lastAt, start)
            ?: return
        notifier.budget(
            budgetId = budget.id,
            category = category,
            percent = (spent / budget.amountLimit * 100).toInt(),
            amountLeft = (budget.amountLimit - spent).coerceAtLeast(0.0),
            nearHotspot = nearHotspot,
        )
        budgets.markNotified(budget.id, threshold, now.toEpochMillis(zone))
    }
}
