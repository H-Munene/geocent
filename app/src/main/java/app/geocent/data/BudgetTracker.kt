package app.geocent.data

import app.geocent.domain.toEpochMillis
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import java.time.LocalDateTime
import java.time.ZoneId
import javax.inject.Inject
import javax.inject.Singleton

/** Live progress for every budget, recomputed whenever budgets or spending change. */
@Singleton
class BudgetTracker @Inject constructor(
    private val budgets: BudgetRepository,
    private val transactions: TransactionRepository,
) {
    fun observeProgress(zone: ZoneId = ZoneId.systemDefault()): Flow<List<BudgetProgress>> {
        val now = LocalDateTime.now(zone)
        val from = earliestPeriodStart(now).toEpochMillis(zone)
        return combine(budgets.observeAll(), transactions.observeBetween(from, Long.MAX_VALUE)) { all, spending ->
            budgetProgress(all, spending, LocalDateTime.now(zone), zone)
        }
    }
}
