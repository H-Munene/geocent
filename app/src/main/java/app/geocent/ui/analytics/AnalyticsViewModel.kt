package app.geocent.ui.analytics

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.geocent.data.BudgetTracker
import app.geocent.data.CategoryRepository
import app.geocent.data.TransactionRepository
import app.geocent.data.db.CategoryEntity
import app.geocent.data.db.TransactionEntity
import app.geocent.domain.AnalyticsRange
import app.geocent.domain.AnalyticsResult
import app.geocent.domain.Spend
import app.geocent.domain.analyse
import app.geocent.domain.toEpochMillis
import app.geocent.notify.Notifier
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.Year
import java.time.YearMonth
import java.time.ZoneId
import javax.inject.Inject

/** What the user picked in the range sheet. */
sealed interface RangeChoice {
    data object ThisWeek : RangeChoice
    data object ThisMonth : RangeChoice
    data object ThisYear : RangeChoice
    data class Month(val month: YearMonth) : RangeChoice
    data class YearOf(val year: Year) : RangeChoice
}

enum class ChartType(val label: String) { BARS("Bars"), LINE("Line"), DONUT("Donut") }

/** A short fact shown in the insights row. */
data class Insight(val label: String, val value: String, val detail: String, val warning: Boolean = false)

data class AnalyticsState(
    val range: AnalyticsRange,
    val result: AnalyticsResult,
    /** The payments inside the range, for drill-down lists. */
    val transactions: List<TransactionEntity>,
)

@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class AnalyticsViewModel @Inject constructor(
    private val transactions: TransactionRepository,
    categoryRepository: CategoryRepository,
    budgetTracker: BudgetTracker,
) : ViewModel() {

    private val zone = ZoneId.systemDefault()
    private val sharing = SharingStarted.WhileSubscribed(5_000)

    private val _choice = MutableStateFlow<RangeChoice>(RangeChoice.ThisWeek)
    val choice = _choice.asStateFlow()
    fun choose(choice: RangeChoice) { _choice.value = choice }

    private val _chart = MutableStateFlow(ChartType.BARS)
    val chart = _chart.asStateFlow()
    fun setChart(type: ChartType) { _chart.value = type }

    val categories: StateFlow<Map<String, CategoryEntity>> = categoryRepository.observeAll()
        .map { list -> list.associateBy { it.name } }
        .stateIn(viewModelScope, sharing, emptyMap())

    val state: StateFlow<AnalyticsState?> = _choice.flatMapLatest { choice ->
        val range = rangeFor(choice)
        transactions.observeBetween(range.previousStart.toEpochMillis(zone), range.end.toEpochMillis(zone)).map { all ->
            val spending = all.filter { it.type.isSpending && it.currency == "KES" }
            val result = analyse(spending.map { it.toSpend() }, range)
            AnalyticsState(range, result, spending.filter { range.contains(it.localTime()) })
        }
    }.stateIn(viewModelScope, sharing, null)

    /** Quick facts for the insights row: this week's leaders, today vs yesterday, budgets. */
    val insights: StateFlow<List<Insight>> = combine(
        transactions.observeBetween(
            AnalyticsRange.week(LocalDate.now(zone)).previousStart.toEpochMillis(zone),
            Long.MAX_VALUE,
        ),
        budgetTracker.observeProgress(),
    ) { recent, budgets ->
        val spending = recent.filter { it.type.isSpending && it.currency == "KES" }
        val today = LocalDate.now(zone)
        val week = AnalyticsRange.week(today)
        val thisWeek = spending.filter { week.contains(it.localTime()) }
        buildList {
            val spentToday = spending.filter { it.localTime().toLocalDate() == today }.sumOf { it.amount }
            val spentYesterday = spending.filter { it.localTime().toLocalDate() == today.minusDays(1) }.sumOf { it.amount }
            add(Insight("Today", Notifier.formatKes(spentToday), "Yesterday ${Notifier.formatKes(spentYesterday)}"))
            thisWeek.filter { it.category != null }.groupBy { it.category!! }
                .maxByOrNull { (_, txs) -> txs.sumOf { it.amount } }
                ?.let { (name, txs) -> add(Insight("Top category this week", name, Notifier.formatKes(txs.sumOf { it.amount }))) }
            thisWeek.maxByOrNull { it.amount }
                ?.let { add(Insight("Biggest payment this week", it.merchant, Notifier.formatKes(it.amount))) }
            budgets.sortedByDescending { it.fraction }.take(3).forEach { b ->
                val pct = (b.fraction * 100).toInt()
                add(
                    Insight(
                        "${b.budget.categoryName} budget",
                        "$pct% used",
                        if (b.exceeded) "${Notifier.formatKes(-b.remaining)} over" else "${Notifier.formatKes(b.remaining)} left",
                        warning = b.fraction >= 0.8,
                    ),
                )
            }
        }
    }.stateIn(viewModelScope, sharing, emptyList())

    /** Months and years with spending, for the custom range choices (newest first). */
    val history: StateFlow<Pair<List<YearMonth>, List<Year>>> = transactions.observeBetween(0, Long.MAX_VALUE).map { all ->
        val months = all.map { YearMonth.from(it.localTime()) }.distinct().sortedDescending()
        months to months.map { Year.of(it.year) }.distinct()
    }.stateIn(viewModelScope, sharing, emptyList<YearMonth>() to emptyList())

    private fun rangeFor(choice: RangeChoice): AnalyticsRange {
        val today = LocalDate.now(zone)
        return when (choice) {
            RangeChoice.ThisWeek -> AnalyticsRange.week(today)
            RangeChoice.ThisMonth -> AnalyticsRange.month(YearMonth.from(today), current = true)
            RangeChoice.ThisYear -> AnalyticsRange.year(Year.from(today), current = true)
            is RangeChoice.Month -> AnalyticsRange.month(choice.month, current = choice.month == YearMonth.from(today))
            is RangeChoice.YearOf -> AnalyticsRange.year(choice.year, current = choice.year == Year.from(today))
        }
    }

    private fun TransactionEntity.localTime(): LocalDateTime = LocalDateTime.ofInstant(Instant.ofEpochMilli(timestamp), zone)
    private fun TransactionEntity.toSpend() = Spend(localTime(), amount, category, merchant)
}
