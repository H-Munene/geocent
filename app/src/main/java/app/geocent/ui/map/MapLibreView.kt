package app.geocent.ui.map

import android.os.Bundle
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import org.maplibre.android.MapLibre
import org.maplibre.android.maps.MapView

/** OpenStreetMap vector styles from OpenFreeMap (free, no API key). */
object MapStyles {
    const val STANDARD = "https://tiles.openfreemap.org/styles/liberty"
    const val LIGHT = "https://tiles.openfreemap.org/styles/positron"
    const val DARK = "https://tiles.openfreemap.org/styles/dark"
    val all = listOf(STANDARD, LIGHT, DARK)

    /** A saved value that is no longer offered falls back to Standard. */
    fun normalize(saved: String?): String = saved?.takeIf { it in all } ?: STANDARD
}

/** Nairobi CBD: the camera's starting point until a real location is known. */
const val DEFAULT_LAT = -1.2864
const val DEFAULT_LNG = 36.8172

/**
 * A MapLibre [MapView] whose lifecycle follows the screen it is shown on.
 * Wrap it in an AndroidView and call getMapAsync to configure it.
 */
@Composable
fun rememberMapView(): MapView {
    val context = LocalContext.current
    val mapView = remember {
        MapLibre.getInstance(context)
        MapView(context).apply { onCreate(Bundle()) }
    }
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    DisposableEffect(lifecycle, mapView) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_START -> mapView.onStart()
                Lifecycle.Event.ON_RESUME -> mapView.onResume()
                Lifecycle.Event.ON_PAUSE -> mapView.onPause()
                Lifecycle.Event.ON_STOP -> mapView.onStop()
                else -> Unit
            }
        }
        lifecycle.addObserver(observer)
        // Catch up if the screen is already started/resumed.
        if (lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) mapView.onStart()
        if (lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) mapView.onResume()
        onDispose {
            lifecycle.removeObserver(observer)
            mapView.onPause()
            mapView.onStop()
            mapView.onDestroy()
        }
    }
    return mapView
}
