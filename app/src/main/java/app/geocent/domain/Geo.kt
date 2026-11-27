package app.geocent.domain

import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin
import kotlin.math.sqrt

private const val EARTH_RADIUS_M = 6_371_008.8
private const val METERS_PER_DEGREE_LAT = 111_320.0

/** Great-circle distance in metres. */
fun distanceMeters(lat1: Double, lng1: Double, lat2: Double, lng2: Double): Double {
    val dLat = Math.toRadians(lat2 - lat1)
    val dLng = Math.toRadians(lng2 - lng1)
    val a = sin(dLat / 2) * sin(dLat / 2) +
        cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) * sin(dLng / 2) * sin(dLng / 2)
    return 2 * EARTH_RADIUS_M * asin(sqrt(a))
}

/** Lat/lng box that fully contains the circle; used as a cheap SQL prefilter. */
data class BoundingBox(val minLat: Double, val maxLat: Double, val minLng: Double, val maxLng: Double)

fun boundingBox(lat: Double, lng: Double, radiusMeters: Double): BoundingBox {
    val dLat = radiusMeters / METERS_PER_DEGREE_LAT
    // Guard against the poles where cos(lat) -> 0.
    val dLng = radiusMeters / (METERS_PER_DEGREE_LAT * max(cos(Math.toRadians(lat)), 1e-6))
    return BoundingBox(lat - dLat, lat + dLat, lng - dLng, lng + dLng)
}
