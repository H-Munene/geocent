package app.geocent.domain

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/** Transactions recorded at exactly the same spot, drawn as one marker. */
data class Place<T>(val latitude: Double, val longitude: Double, val items: List<T>) {
    /** Stable across refreshes as long as the coordinates don't change. */
    val key: String = "%.6f,%.6f".format(java.util.Locale.US, latitude, longitude)
}

/**
 * Groups items by identical coordinates (to 6 decimals, about 10 cm), keeping
 * the input order inside each group. Items without coordinates are dropped.
 */
fun <T> groupByLocation(items: List<T>, lat: (T) -> Double?, lng: (T) -> Double?): List<Place<T>> =
    items.mapNotNull { item ->
        val la = lat(item) ?: return@mapNotNull null
        val ln = lng(item) ?: return@mapNotNull null
        Triple("%.6f,%.6f".format(java.util.Locale.US, la, ln), item, la to ln)
    }
        .groupBy({ it.first }) { it.second to it.third }
        .map { (_, group) -> Place(group[0].second.first, group[0].second.second, group.map { it.first }) }

/**
 * Collision priority for a marker: lower draws first and wins overlaps.
 * The selected marker always wins, then multi-transaction places, then
 * smaller amounts (as in the Flutter app).
 */
fun markerSortKey(selected: Boolean, count: Int, amount: Double): Double = when {
    selected -> -1_000_000.0
    count > 1 -> -500_000.0
    else -> amount
}

/** Points of a circle of [radiusMeters] around a centre, closed (first == last), as (lat, lng). */
fun circlePolygon(lat: Double, lng: Double, radiusMeters: Double, steps: Int = 64): List<Pair<Double, Double>> {
    val dLat = radiusMeters / 111_320.0
    val dLng = radiusMeters / (111_320.0 * cos(Math.toRadians(lat)))
    return (0..steps).map { i ->
        val angle = 2 * PI * i / steps
        (lat + dLat * sin(angle)) to (lng + dLng * cos(angle))
    }
}
