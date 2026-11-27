package app.geocent.data

import app.geocent.data.db.BudgetEntity
import app.geocent.data.db.TransactionEntity
import app.geocent.domain.model.Currency
import app.geocent.domain.periodStart
import app.geocent.domain.toEpochMillis
import java.time.LocalDateTime
import java.time.ZoneId

/** How a budget is doing in its current period. */
data class BudgetProgress(
    val budget: BudgetEntity,
    val spent: Double,
) {
    /** Spent / limit; can exceed 1 when over budget. */
    val fraction: Double get() = if (budget.amountLimit > 0) spent / budget.amountLimit else 0.0
    val remaining: Double get() = budget.amountLimit - spent
    val exceeded: Boolean get() = spent > budget.amountLimit

    /** Same bands as the Flutter app: under 50%, 50-80%, 80% and above. */
    val level: Level get() = when {
        fraction >= 0.8 -> Level.HIGH
        fraction >= 0.5 -> Level.MEDIUM
        else -> Level.LOW
    }

    enum class Level { LOW, MEDIUM, HIGH }
}

/**
 * Spending per budget in the period that contains [now]. [spending] must
 * cover at least the earliest period start (see [earliestPeriodStart]);
 * only outgoing KES transactions count.
 */
fun budgetProgress(
    budgets: List<BudgetEntity>,
    spending: List<TransactionEntity>,
    now: LocalDateTime,
    zone: ZoneId = ZoneId.systemDefault(),
): List<BudgetProgress> {
    val outgoing = spending.filter { it.type.isSpending && it.currency == Currency.KES }
    return budgets.map { budget ->
        val from = periodStart(budget.period, now).toEpochMillis(zone)
        val spent = outgoing
            .filter { it.category == budget.categoryName && it.timestamp >= from }
            .sumOf { it.amount }
        BudgetProgress(budget, spent)
    }
}

/** Earliest start among daily, weekly and monthly windows containing [now]. */
fun earliestPeriodStart(now: LocalDateTime): LocalDateTime =
    app.geocent.domain.model.BudgetPeriod.entries.minOf { periodStart(it, now) }
