package app.geocent.data

import app.geocent.data.db.TransactionEntity
import app.geocent.domain.distanceMeters

/** What was spent within a radius of a point (the map's "spending around here" card). */
data class AreaSummary(
    val total: Double,
    val count: Int,
    val average: Double,
    /** Highest-spend categories first; [NO_CATEGORY] for uncategorised spending. */
    val topCategories: List<Pair<String, Double>>,
    val topMerchants: List<Pair<String, Double>>,
    val transactions: List<TransactionEntity>,
) {
    companion object {
        const val NO_CATEGORY = app.geocent.domain.NO_CATEGORY
        val EMPTY = AreaSummary(0.0, 0, 0.0, emptyList(), emptyList(), emptyList())
    }
}

/**
 * Keeps only [candidates] within [radiusMeters] of the point (exact distance;
 * the database query is just a bounding-box prefilter) and summarises them.
 */
fun summarizeArea(
    candidates: List<TransactionEntity>,
    lat: Double,
    lng: Double,
    radiusMeters: Double,
    top: Int = 3,
): AreaSummary {
    val inside = candidates.filter { tx ->
        val tLat = tx.latitude ?: return@filter false
        val tLng = tx.longitude ?: return@filter false
        distanceMeters(lat, lng, tLat, tLng) <= radiusMeters
    }
    if (inside.isEmpty()) return AreaSummary.EMPTY

    fun ranked(key: (TransactionEntity) -> String) =
        inside.groupBy(key)
            .mapValues { (_, txs) -> txs.sumOf { it.amount } }
            .entries.sortedByDescending { it.value }
            .take(top)
            .map { it.key to it.value }

    val total = inside.sumOf { it.amount }
    return AreaSummary(
        total = total,
        count = inside.size,
        average = total / inside.size,
        topCategories = ranked { it.category ?: AreaSummary.NO_CATEGORY },
        topMerchants = ranked { it.merchant },
        transactions = inside.sortedByDescending { it.timestamp },
    )
}
