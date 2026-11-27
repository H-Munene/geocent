package app.geocent.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PlacesTest {
    private data class P(val id: String, val lat: Double?, val lng: Double?)

    @Test
    fun `groups identical coordinates and drops unmapped`() {
        val items = listOf(
            P("a", -1.2864, 36.8172),
            P("b", -1.2864, 36.8172),
            P("c", -1.2900, 36.8200),
            P("d", null, null),
        )
        val places = groupByLocation(items, P::lat, P::lng)
        assertEquals(2, places.size)
        assertEquals(listOf("a", "b"), places[0].items.map { it.id })
        assertEquals("-1.286400,36.817200", places[0].key)
    }

    @Test
    fun `selected marker always wins collisions`() {
        assertTrue(markerSortKey(true, 1, 10.0) < markerSortKey(false, 3, 10.0))
        assertTrue(markerSortKey(false, 3, 10.0) < markerSortKey(false, 1, 5.0))
    }

    @Test
    fun `circle polygon is closed and has the right radius`() {
        val ring = circlePolygon(-1.2864, 36.8172, 500.0)
        assertEquals(ring.first().first, ring.last().first, 1e-9)
        assertEquals(ring.first().second, ring.last().second, 1e-9)
        ring.forEach { (la, ln) ->
            assertEquals(500.0, distanceMeters(-1.2864, 36.8172, la, ln), 5.0)
        }
    }
}
