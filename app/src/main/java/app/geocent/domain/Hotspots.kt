package app.geocent.domain

import kotlin.math.max

/** A geotagged payment as clustering sees it. */
data class SpendPoint(val id: String, val latitude: Double, val longitude: Double, val amount: Double)

/** A cluster of spending: centred on its medoid, radius covering every member. */
data class Cluster(
    val latitude: Double,
    val longitude: Double,
    val radiusMeters: Double,
    val totalSpend: Double,
    val count: Int,
) {
    val averageSpend: Double get() = totalSpend / count
}

object Hotspots {
    /** Points within this distance are neighbours (same as Flutter). */
    const val EPSILON_METERS = 100.0
    /** Neighbours needed to start a cluster. */
    const val MIN_NEIGHBOURS = 3
    /** Clustering only runs with at least this many geotagged payments. */
    const val MIN_GEOTAGGED = 10
    /** Geofences are never smaller than this. */
    const val MIN_RADIUS_METERS = 50.0
    /** A new cluster this close to an old hotspot keeps the old hotspot's id. */
    const val MATCH_METERS = 150.0

    /**
     * DBSCAN over [points] (port of the Flutter HotspotService). Noise points
     * are dropped. Each cluster is centred on its medoid (the member with the
     * smallest total distance to the others) so it sits on real spending.
     */
    fun cluster(
        points: List<SpendPoint>,
        epsilon: Double = EPSILON_METERS,
        minNeighbours: Int = MIN_NEIGHBOURS,
    ): List<Cluster> {
        fun neighbours(p: SpendPoint) = points.filter {
            it.id != p.id && distanceMeters(p.latitude, p.longitude, it.latitude, it.longitude) <= epsilon
        }

        val visited = HashSet<String>()
        val clustered = HashSet<String>()
        val clusters = mutableListOf<List<SpendPoint>>()

        for (p in points) {
            if (!visited.add(p.id)) continue
            val seeds = neighbours(p)
            if (seeds.size < minNeighbours) continue // noise (may join a cluster later as a border point)

            val members = mutableListOf(p).also { clustered += p.id }
            val queue = ArrayDeque(seeds)
            while (queue.isNotEmpty()) {
                val q = queue.removeFirst()
                if (visited.add(q.id)) {
                    val more = neighbours(q)
                    if (more.size >= minNeighbours) queue.addAll(more.filter { it.id !in visited })
                }
                if (clustered.add(q.id)) members += q
            }
            clusters += members
        }
        return clusters.map(::summarise)
    }

    private fun summarise(members: List<SpendPoint>): Cluster {
        val medoid = members.minBy { c ->
            members.sumOf { distanceMeters(c.latitude, c.longitude, it.latitude, it.longitude) }
        }
        val reach = members.maxOf { distanceMeters(medoid.latitude, medoid.longitude, it.latitude, it.longitude) }
        return Cluster(
            latitude = medoid.latitude,
            longitude = medoid.longitude,
            radiusMeters = max(reach, MIN_RADIUS_METERS),
            totalSpend = members.sumOf { it.amount },
            count = members.size,
        )
    }

    /**
     * Gives each new cluster an id: the id of the closest previous hotspot
     * within [MATCH_METERS] (each old id used at most once, closest pairs
     * first), otherwise a fresh one from [newId]. Keeping ids stable keeps
     * geofences and alert cooldowns attached to the same place.
     */
    fun <T> assignIds(
        clusters: List<Cluster>,
        previous: List<T>,
        previousId: (T) -> String,
        previousLat: (T) -> Double,
        previousLng: (T) -> Double,
        newId: () -> String,
    ): List<Pair<String, Cluster>> {
        val candidates = clusters.indices.flatMap { ci ->
            previous.map { p ->
                Triple(ci, p, distanceMeters(clusters[ci].latitude, clusters[ci].longitude, previousLat(p), previousLng(p)))
            }
        }.filter { it.third <= MATCH_METERS }.sortedBy { it.third }

        val ids = arrayOfNulls<String>(clusters.size)
        val usedOld = HashSet<String>()
        for ((ci, p, _) in candidates) {
            val id = previousId(p)
            if (ids[ci] == null && id !in usedOld) {
                ids[ci] = id
                usedOld += id
            }
        }
        return clusters.mapIndexed { i, c -> (ids[i] ?: newId()) to c }
    }
}
