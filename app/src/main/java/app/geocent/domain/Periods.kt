package app.geocent.domain

import app.geocent.domain.model.BudgetPeriod
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId

/** A closed time range in local time. */
data class TimeRange(val start: LocalDateTime, val end: LocalDateTime) {
    fun startMillis(zone: ZoneId = ZoneId.systemDefault()) = start.toEpochMillis(zone)
    fun endMillis(zone: ZoneId = ZoneId.systemDefault()) = end.toEpochMillis(zone)
}

fun LocalDateTime.toEpochMillis(zone: ZoneId = ZoneId.systemDefault()): Long =
    atZone(zone).toInstant().toEpochMilli()

/** Weeks start on Sunday everywhere in the app (budgets, analytics, alerts). */
fun startOfWeek(date: LocalDate): LocalDate = date.minusDays((date.dayOfWeek.value % 7).toLong())

private val END_OF_DAY: LocalTime = LocalTime.of(23, 59, 59)

fun today(now: LocalDateTime): TimeRange =
    TimeRange(now.toLocalDate().atStartOfDay(), now.toLocalDate().atTime(END_OF_DAY))

fun thisWeek(now: LocalDateTime): TimeRange {
    val start = startOfWeek(now.toLocalDate())
    return TimeRange(start.atStartOfDay(), start.plusDays(6).atTime(END_OF_DAY))
}

fun thisMonth(now: LocalDateTime): TimeRange {
    val first = now.toLocalDate().withDayOfMonth(1)
    return TimeRange(first.atStartOfDay(), first.plusMonths(1).minusDays(1).atTime(END_OF_DAY))
}

/** Start of the budget window containing [now]. */
fun periodStart(period: BudgetPeriod, now: LocalDateTime): LocalDateTime = when (period) {
    BudgetPeriod.DAILY -> today(now).start
    BudgetPeriod.WEEKLY -> thisWeek(now).start
    BudgetPeriod.MONTHLY -> thisMonth(now).start
}
