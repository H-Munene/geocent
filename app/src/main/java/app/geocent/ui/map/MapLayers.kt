package app.geocent.ui.map

import android.graphics.Bitmap
import org.maplibre.android.maps.Style
import org.maplibre.android.style.expressions.Expression
import org.maplibre.android.style.expressions.Expression.get
import org.maplibre.android.style.expressions.Expression.literal
import org.maplibre.android.style.expressions.Expression.step
import org.maplibre.android.style.expressions.Expression.stop
import org.maplibre.android.style.expressions.Expression.toColor
import org.maplibre.android.style.expressions.Expression.zoom
import org.maplibre.android.style.layers.CircleLayer
import org.maplibre.android.style.layers.FillLayer
import org.maplibre.android.style.layers.LineLayer
import org.maplibre.android.style.layers.Property
import org.maplibre.android.style.layers.PropertyFactory.circleColor
import org.maplibre.android.style.layers.PropertyFactory.circleOpacity
import org.maplibre.android.style.layers.PropertyFactory.circleRadius
import org.maplibre.android.style.layers.PropertyFactory.circleSortKey
import org.maplibre.android.style.layers.PropertyFactory.circleStrokeColor
import org.maplibre.android.style.layers.PropertyFactory.circleStrokeOpacity
import org.maplibre.android.style.layers.PropertyFactory.circleStrokeWidth
import org.maplibre.android.style.layers.PropertyFactory.fillColor
import org.maplibre.android.style.layers.PropertyFactory.fillOpacity
import org.maplibre.android.style.layers.PropertyFactory.iconAllowOverlap
import org.maplibre.android.style.layers.PropertyFactory.iconAnchor
import org.maplibre.android.style.layers.PropertyFactory.iconIgnorePlacement
import org.maplibre.android.style.layers.PropertyFactory.iconImage
import org.maplibre.android.style.layers.PropertyFactory.iconOpacity
import org.maplibre.android.style.layers.PropertyFactory.lineColor
import org.maplibre.android.style.layers.PropertyFactory.lineDasharray
import org.maplibre.android.style.layers.PropertyFactory.lineWidth
import org.maplibre.android.style.layers.PropertyFactory.symbolSortKey
import org.maplibre.android.style.layers.SymbolLayer
import org.maplibre.android.style.sources.GeoJsonSource
import org.maplibre.geojson.Feature
import org.maplibre.geojson.FeatureCollection
import org.maplibre.geojson.Point
import org.maplibre.geojson.Polygon

/** Ids of everything Geocent adds on top of a base style. */
object MapIds {
    const val PLACES = "places"
    const val DOTS = "places-dots"
    const val CALLOUTS = "places-callouts"
    const val AREA = "area"
    const val AREA_FILL = "area-fill"
    const val AREA_LINE = "area-line"
    const val AREA_PIN = "area-pin"

    /** Feature properties on the places source. */
    const val P_KEY = "key"
    const val P_ICON = "icon"
    const val P_COLOR = "color"
    const val P_SORT = "sort"
}

/** Opacity 0 below [z], 1 from [z] up: the Flutter zoom rules. */
private fun visibleFrom(z: Float): Expression = step(zoom(), literal(0f), stop(z, 1f))

/**
 * Adds Geocent's sources and layers to a freshly loaded style. Order, bottom
 * to top: area circle, dots, callouts, area pin.
 */
fun installGeocentLayers(style: Style, accentArgb: Int) {
    val empty = FeatureCollection.fromFeatures(emptyList())
    style.addSource(GeoJsonSource(MapIds.AREA, empty))
    style.addSource(GeoJsonSource(MapIds.PLACES, empty))

    val accent = String.format("#%06X", accentArgb and 0xFFFFFF)
    style.addLayer(
        FillLayer(MapIds.AREA_FILL, MapIds.AREA).withProperties(fillColor(accent), fillOpacity(0.12f))
            .withFilter(Expression.eq(Expression.geometryType(), literal("Polygon"))),
    )
    style.addLayer(
        LineLayer(MapIds.AREA_LINE, MapIds.AREA).withProperties(lineColor(accent), lineWidth(2f), lineDasharray(arrayOf(2f, 1.5f)))
            .withFilter(Expression.eq(Expression.geometryType(), literal("Polygon"))),
    )

    // Dots stay visible under callouts, so they show when a callout is hidden by collision.
    style.addLayer(
        CircleLayer(MapIds.DOTS, MapIds.PLACES).withProperties(
            circleColor(toColor(get(MapIds.P_COLOR))),
            circleRadius(4f),
            circleStrokeWidth(1.5f),
            circleStrokeColor("#FFFFFF"),
            circleSortKey(get(MapIds.P_SORT)),
            circleOpacity(visibleFrom(9f)),
            circleStrokeOpacity(visibleFrom(9f)),
        ),
    )
    style.addLayer(
        SymbolLayer(MapIds.CALLOUTS, MapIds.PLACES).withProperties(
            iconImage(get(MapIds.P_ICON)),
            iconAnchor(Property.ICON_ANCHOR_CENTER),
            iconAllowOverlap(false),
            iconIgnorePlacement(false),
            symbolSortKey(get(MapIds.P_SORT)),
            iconOpacity(visibleFrom(11f)),
        ),
    )
    style.addLayer(
        CircleLayer(MapIds.AREA_PIN, MapIds.AREA).withProperties(
            circleColor(accent),
            circleRadius(7f),
            circleStrokeWidth(3f),
            circleStrokeColor("#FFFFFF"),
        ).withFilter(Expression.eq(Expression.geometryType(), literal("Point"))),
    )
}

/** One marker for the places source. [icon] must already be added with [Style.addImage]. */
data class PlaceFeature(
    val key: String,
    val latitude: Double,
    val longitude: Double,
    val icon: String,
    val colorHex: String,
    val sortKey: Double,
)

fun Style.setPlaces(places: List<PlaceFeature>) {
    val features = places.map { p ->
        Feature.fromGeometry(Point.fromLngLat(p.longitude, p.latitude)).apply {
            addStringProperty(MapIds.P_KEY, p.key)
            addStringProperty(MapIds.P_ICON, p.icon)
            addStringProperty(MapIds.P_COLOR, p.colorHex)
            addNumberProperty(MapIds.P_SORT, p.sortKey)
        }
    }
    getSourceAs<GeoJsonSource>(MapIds.PLACES)?.setGeoJson(FeatureCollection.fromFeatures(features))
}

/** Draws the "spending around here" circle and pin, or clears them when [ring] is null. */
fun Style.setArea(centre: Pair<Double, Double>?, ring: List<Pair<Double, Double>>?) {
    val features = if (centre == null || ring == null) emptyList() else listOf(
        Feature.fromGeometry(Polygon.fromLngLats(listOf(ring.map { (la, ln) -> Point.fromLngLat(ln, la) }))),
        Feature.fromGeometry(Point.fromLngLat(centre.second, centre.first)),
    )
    getSourceAs<GeoJsonSource>(MapIds.AREA)?.setGeoJson(FeatureCollection.fromFeatures(features))
}

fun Style.addImageIfMissing(name: String, render: () -> Bitmap) {
    if (getImage(name) == null) addImage(name, render())
}
