package app.geocent.data

import androidx.sqlite.db.SimpleSQLiteQuery
import java.time.LocalDateTime
import java.time.ZoneId
import app.geocent.domain.toEpochMillis

/** Which messages the Messages tab lists (same meaning as the Flutter filters). */
enum class MessageFilter {
    /** Anything still missing a location or a category. */
    NEEDS_ACTION,
    /** No location yet. */
    NEEDS_LOCATION,
    /** Has a location but no category. */
    NEEDS_CATEGORY,
    /** Everything. */
    ALL,
}

enum class MessageAge { ANY, TODAY, YESTERDAY, LAST_3_DAYS, LAST_7_DAYS, OLDER_THAN_7_DAYS }

/**
 * Builds the SQL for the Messages list. Kept free of Android types except the
 * final query object so the WHERE clause can be unit tested.
 */
object MessageQuery {

    data class Sql(val where: String, val args: List<Any>)

    fun where(
        filter: MessageFilter,
        search: String?,
        age: MessageAge,
        now: LocalDateTime,
        zone: ZoneId = ZoneId.systemDefault(),
    ): Sql {
        val conditions = mutableListOf<String>()
        val args = mutableListOf<Any>()

        when (filter) {
            MessageFilter.NEEDS_ACTION -> conditions += "(latitude IS NULL OR category IS NULL)"
            MessageFilter.NEEDS_LOCATION -> conditions += "latitude IS NULL"
            MessageFilter.NEEDS_CATEGORY -> conditions += "(category IS NULL AND latitude IS NOT NULL)"
            MessageFilter.ALL -> Unit
        }

        // Search ignores case, commas, dashes and spaces so "1,200" matches "1200".
        val normalized = search?.lowercase()?.replace(Regex("[,\\-\\s]"), "").orEmpty()
        if (normalized.isNotEmpty()) {
            conditions += "REPLACE(REPLACE(REPLACE(LOWER(raw_message), ',', ''), '-', ''), ' ', '') LIKE ?"
            args += "%$normalized%"
        }

        val startOfToday = now.toLocalDate().atStartOfDay()
        when (age) {
            MessageAge.ANY -> Unit
            MessageAge.TODAY -> {
                conditions += "timestamp >= ?"
                args += startOfToday.toEpochMillis(zone)
            }
            MessageAge.YESTERDAY -> {
                conditions += "timestamp >= ? AND timestamp < ?"
                args += startOfToday.minusDays(1).toEpochMillis(zone)
                args += startOfToday.toEpochMillis(zone)
            }
            MessageAge.LAST_3_DAYS -> {
                conditions += "timestamp >= ?"
                args += now.minusDays(3).toEpochMillis(zone)
            }
            MessageAge.LAST_7_DAYS -> {
                conditions += "timestamp >= ?"
                args += now.minusDays(7).toEpochMillis(zone)
            }
            MessageAge.OLDER_THAN_7_DAYS -> {
                conditions += "timestamp < ?"
                args += now.minusDays(7).toEpochMillis(zone)
            }
        }

        val where = if (conditions.isEmpty()) "" else "WHERE " + conditions.joinToString(" AND ")
        return Sql(where, args)
    }

    fun build(
        filter: MessageFilter,
        search: String?,
        age: MessageAge,
        limit: Int,
        now: LocalDateTime = LocalDateTime.now(),
    ): SimpleSQLiteQuery {
        val sql = where(filter, search, age, now)
        return SimpleSQLiteQuery(
            "SELECT * FROM transactions ${sql.where} ORDER BY timestamp DESC LIMIT $limit",
            sql.args.toTypedArray(),
        )
    }
}
