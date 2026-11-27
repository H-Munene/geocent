package app.geocent.domain

import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.Year
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale

/** One payment as analytics sees it: when, how much, which category (null = none). */
data class Spend(val at: LocalDateTime, val amount: Double, val category: String?, val recipient: String)

/** How a range is split into chart bars. */
enum class Granularity { DAY, MONTH }

/** A period to analyse plus the equal-length period before it (for the trend). */
data class AnalyticsRange(
    val label: String,
    val start: LocalDateTime,
    val end: LocalDateTime,
    val previousStart: LocalDateTime,
    val previousEnd: LocalDateTime,
    val granularity: Granularity,
) {
    companion object {
        private val endOfDay: LocalTime = LocalTime.of(23, 59, 59)

        fun week(today: LocalDate): AnalyticsRange {
            val start = startOfWeek(today)
            return AnalyticsRange(
                "This week", start.atStartOfDay(), start.plusDays(6).atTime(endOfDay),
                start.minusDays(7).atStartOfDay(), start.minusDays(1).atTime(endOfDay), Granularity.DAY,
            )
        }

        fun month(month: YearMonth, current: Boolean): AnalyticsRange {
            val prev = month.minusMonths(1)
            val label = if (current) "This month" else month.format(DateTimeFormatter.ofPattern("MMMM yyyy"))
            return AnalyticsRange(
                label, month.atDay(1).atStartOfDay(), month.atEndOfMonth().atTime(endOfDay),
                prev.atDay(1).atStartOfDay(), prev.atEndOfMonth().atTime(endOfDay), Granularity.DAY,
            )
        }

        fun year(year: Year, current: Boolean): AnalyticsRange {
            val label = if (current) "This year" else year.toString()
            return AnalyticsRange(
                label, year.atDay(1).atStartOfDay(), year.atMonth(12).atEndOfMonth().atTime(endOfDay),
                year.minusYears(1).atDay(1).atStartOfDay(), year.minusYears(1).atMonth(12).atEndOfMonth().atTime(endOfDay),
                Granularity.MONTH,
            )
        }
    }

    fun contains(t: LocalDateTime) = !t.isBefore(start) && !t.isAfter(end)
    fun containsPrevious(t: LocalDateTime) = !t.isBefore(previousStart) && !t.isAfter(previousEnd)
}

/** One chart bar: its label and spending per category (null key = uncategorised). */
data class Bucket(val label: String, val byCategory: Map<String?, Double>) {
    val total: Double get() = byCategory.values.sum()
}

data class Breakdown(val name: String, val total: Double, val count: Int, val share: Double)

data class AnalyticsResult(
    val total: Double,
    val previousTotal: Double,
    val buckets: List<Bucket>,
    val categories: List<Breakdown>,
    val recipients: List<Breakdown>,
) {
    /** Change vs the previous period, e.g. 0.25 for +25%; null when there was nothing before. */
    val trend: Double? get() = if (previousTotal > 0) (total - previousTotal) / previousTotal else null
}

/** Name used for uncategorised spending in breakdowns. */
const val NO_CATEGORY = "No category"

fun analyse(spending: List<Spend>, range: AnalyticsRange, locale: Locale = Locale.getDefault()): AnalyticsResult {
    val current = spending.filter { range.contains(it.at) }
    val previousTotal = spending.filter { range.containsPrevious(it.at) }.sumOf { it.amount }
    val total = current.sumOf { it.amount }

    val buckets = when (range.granularity) {
        Granularity.DAY -> {
            val days = generateSequence(range.start.toLocalDate()) { it.plusDays(1) }
                .takeWhile { !it.isAfter(range.end.toLocalDate()) }.toList()
            val weekly = days.size == 7
            days.map { day ->
                val label = if (weekly) day.dayOfWeek.getDisplayName(TextStyle.NARROW, locale) else day.dayOfMonth.toString()
                Bucket(label, current.filter { it.at.toLocalDate() == day }.sumByCategory())
            }
        }
        Granularity.MONTH -> (1..12).map { m ->
            val label = java.time.Month.of(m).getDisplayName(TextStyle.NARROW, locale)
            Bucket(label, current.filter { it.at.monthValue == m }.sumByCategory())
        }
    }

    fun breakdown(key: (Spend) -> String) = current.groupBy(key)
        .map { (name, items) ->
            val sum = items.sumOf { it.amount }
            Breakdown(name, sum, items.size, if (total > 0) sum / total else 0.0)
        }
        .sortedByDescending { it.total }

    return AnalyticsResult(
        total = total,
        previousTotal = previousTotal,
        buckets = buckets,
        categories = breakdown { it.category ?: NO_CATEGORY },
        recipients = breakdown { it.recipient },
    )
}

private fun List<Spend>.sumByCategory(): Map<String?, Double> =
    groupBy { it.category }.mapValues { (_, items) -> items.sumOf { it.amount } }
