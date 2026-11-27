package app.geocent.domain

import java.time.LocalDateTime

/** Alert levels as a percentage of the budget, lowest first. */
val BUDGET_THRESHOLDS = listOf(50, 80, 100)

/**
 * Which alert (50/80/100) to send now, or null if none.
 *
 * Only the highest newly crossed threshold fires, and each fires once per
 * period: [lastThreshold] resets when the last alert was sent before the
 * current [periodStart].
 */
fun nextBudgetAlert(
    spent: Double,
    limit: Double,
    lastThreshold: Int,
    lastNotifiedAt: LocalDateTime?,
    periodStart: LocalDateTime,
): Int? {
    if (limit <= 0) return null
    val effectiveLast = if (lastNotifiedAt == null || lastNotifiedAt.isBefore(periodStart)) 0 else lastThreshold
    val percent = spent / limit * 100
    val crossed = BUDGET_THRESHOLDS.lastOrNull { percent >= it } ?: return null
    return crossed.takeIf { it > effectiveLast }
}
