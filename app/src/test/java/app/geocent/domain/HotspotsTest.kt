package app.geocent.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HotspotsTest {
    // ~11 m per 0.0001 degree near the equator.
    private fun near(id: String, base: Pair<Double, Double>, dLat: Double, dLng: Double, amount: Double = 100.0) =
        SpendPoint(id, base.first + dLat, base.second + dLng, amount)

    private val cbd = -1.2864 to 36.8172
    private val westlands = -1.2676 to 36.8108 // ~2 km away

    private fun group(prefix: String, base: Pair<Double, Double>, n: Int) =
        (0 until n).map { near("$prefix$it", base, it * 0.0001, it * 0.0001) }

    @Test
    fun `dense groups become clusters and stragglers are noise`() {
        val points = group("c", cbd, 5) + group("w", westlands, 4) + SpendPoint("lonely", -1.30, 36.90, 50.0)
        val clusters = Hotspots.cluster(points).sortedByDescending { it.count }
        assertEquals(2, clusters.size)
        assertEquals(5, clusters[0].count)
        assertEquals(500.0, clusters[0].totalSpend, 0.0)
        assertEquals(100.0, clusters[0].averageSpend, 0.0)
        assertTrue(clusters[0].radiusMeters >= Hotspots.MIN_RADIUS_METERS)
    }

    @Test
    fun `centre is a real member (medoid)`() {
        val points = group("c", cbd, 5)
        val c = Hotspots.cluster(points).single()
        assertTrue(points.any { it.latitude == c.latitude && it.longitude == c.longitude })
    }

    @Test
    fun `ids stay stable when a cluster shifts slightly`() {
        val old = listOf(Triple("hot-cbd", cbd.first, cbd.second), Triple("hot-west", westlands.first, westlands.second))
        val newClusters = listOf(
            Cluster(cbd.first + 0.0003, cbd.second, 80.0, 900.0, 6), // ~33 m away -> same hotspot
            Cluster(-1.40, 36.95, 60.0, 300.0, 4), // far from everything -> new id
        )
        var counter = 0
        val ids = Hotspots.assignIds(newClusters, old, { it.first }, { it.second }, { it.third }) { "new-${counter++}" }
        assertEquals("hot-cbd", ids[0].first)
        assertEquals("new-0", ids[1].first)
    }

    @Test
    fun `an old id is reused at most once, by the closest cluster`() {
        val old = listOf(Triple("hot", cbd.first, cbd.second))
        val clusters = listOf(
            Cluster(cbd.first + 0.0008, cbd.second, 60.0, 1.0, 4), // ~90 m
            Cluster(cbd.first + 0.0002, cbd.second, 60.0, 1.0, 4), // ~22 m (closer)
        )
        var n = 0
        val ids = Hotspots.assignIds(clusters, old, { it.first }, { it.second }, { it.third }) { "new${n++}" }
        assertEquals(listOf("new0", "hot"), ids.map { it.first })
    }
}
