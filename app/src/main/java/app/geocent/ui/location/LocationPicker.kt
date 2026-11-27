package app.geocent.ui.location

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import app.geocent.data.TransactionRepository
import app.geocent.data.settings.SettingsStore
import app.geocent.location.LocationProvider
import app.geocent.ui.components.PrimaryButton
import app.geocent.ui.map.DEFAULT_LAT
import app.geocent.ui.map.DEFAULT_LNG
import app.geocent.ui.map.MapStyles
import app.geocent.ui.map.rememberMapView
import app.geocent.ui.theme.GeocentTheme
import app.geocent.ui.theme.HugeIcons
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.location.LocationComponentActivationOptions
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.Style
import javax.inject.Inject

/** Route argument: comma-separated transaction ids to place. */
const val PICK_LOCATION_IDS = "ids"

@HiltViewModel
class LocationPickerViewModel @Inject constructor(
    savedState: SavedStateHandle,
    private val transactions: TransactionRepository,
    private val location: LocationProvider,
    settings: SettingsStore,
) : ViewModel() {

    val ids: List<String> = savedState.get<String>(PICK_LOCATION_IDS).orEmpty().split(',').filter { it.isNotBlank() }

    /** Where the camera starts: the transaction's saved spot, else the device, else Nairobi. */
    private val _start = MutableStateFlow<LatLng?>(null)
    val start = _start.asStateFlow()

    private val _done = MutableStateFlow(false)
    val done = _done.asStateFlow()

    val style = MutableStateFlow(MapStyles.STANDARD)

    init {
        viewModelScope.launch {
            style.value = MapStyles.normalize(settings.mapStyle.first())
            val saved = ids.firstNotNullOfOrNull { id ->
                transactions.get(id)?.takeIf { it.hasLocation }?.let { LatLng(it.latitude!!, it.longitude!!) }
            }
            _start.value = saved
                ?: location.currentLocation()?.let { LatLng(it.latitude, it.longitude) }
                ?: LatLng(DEFAULT_LAT, DEFAULT_LNG)
        }
    }

    suspend fun myLocation(): LatLng? = location.currentLocation()?.let { LatLng(it.latitude, it.longitude) }

    fun confirm(target: LatLng) = viewModelScope.launch {
        transactions.setLocation(ids, target.latitude, target.longitude)
        _done.value = true
    }
}

/**
 * Full-screen map with a fixed pin in the middle: move the map under the pin,
 * then confirm. Used for one message or a bulk selection.
 */
@Composable
fun LocationPickerScreen(onDone: () -> Unit, viewModel: LocationPickerViewModel = hiltViewModel()) {
    val colors = GeocentTheme.colors
    val context = LocalContext.current
    val start by viewModel.start.collectAsStateWithLifecycle()
    val done by viewModel.done.collectAsStateWithLifecycle()
    val styleUrl by viewModel.style.collectAsStateWithLifecycle()
    var map by remember { mutableStateOf<MapLibreMap?>(null) }
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    val mapView = rememberMapView()

    LaunchedEffect(done) { if (done) onDone() }

    LaunchedEffect(map, start) {
        val m = map ?: return@LaunchedEffect
        val target = start ?: return@LaunchedEffect
        m.cameraPosition = CameraPosition.Builder().target(target).zoom(17.0).build()
    }

    Box(Modifier.fillMaxSize().background(colors.background)) {
        AndroidView(
            factory = {
                mapView.apply {
                    getMapAsync { m ->
                        m.uiSettings.isCompassEnabled = false
                        m.uiSettings.isRotateGesturesEnabled = false
                        m.setStyle(Style.Builder().fromUri(styleUrl)) { style -> enableLocationDot(context, m, style) }
                        map = m
                    }
                }
            },
            modifier = Modifier.fillMaxSize(),
        )

        // The pin's tip marks the map centre.
        Icon(
            painterResource(HugeIcons.location06),
            contentDescription = null,
            tint = colors.accent,
            modifier = Modifier
                .align(Alignment.Center)
                .size(44.dp)
                .offset(y = (-20).dp),
        )
        Box(
            Modifier
                .align(Alignment.Center)
                .size(6.dp)
                .clip(CircleShape)
                .background(colors.accent),
        )

        Column(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing).padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                RoundButton(HugeIcons.arrowLeft01, "Back", onDone)
                Spacer(Modifier.width(12.dp))
                Column(
                    Modifier
                        .shadow(6.dp, RoundedCornerShape(14.dp))
                        .clip(RoundedCornerShape(14.dp))
                        .background(colors.surface)
                        .padding(horizontal = 14.dp, vertical = 8.dp),
                ) {
                    Text("Set location", style = GeocentTheme.typography.headline, color = colors.textPrimary)
                    val n = viewModel.ids.size
                    Text(
                        "Move the map so the pin marks where you paid" + if (n > 1) " ($n messages)" else "",
                        style = GeocentTheme.typography.caption,
                        color = colors.textSecondary,
                    )
                }
            }
            Spacer(Modifier.weight(1f))
            Row(Modifier.fillMaxWidth()) {
                Spacer(Modifier.weight(1f))
                RoundButton(HugeIcons.navigation03, "My location", onClick = {
                    scope.launch {
                        viewModel.myLocation()?.let { map?.animateCamera(CameraUpdateFactory.newLatLngZoom(it, 17.0)) }
                    }
                })
            }
            Spacer(Modifier.height(12.dp))
            PrimaryButton(
                text = if (viewModel.ids.size > 1) "Set location for ${viewModel.ids.size} messages" else "Confirm location",
                onClick = { map?.cameraPosition?.target?.let(viewModel::confirm) },
                enabled = map != null && viewModel.ids.isNotEmpty(),
            )
        }
    }
}

@SuppressLint("MissingPermission") // checked just before
private fun enableLocationDot(context: Context, map: MapLibreMap, style: Style) {
    val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
        PackageManager.PERMISSION_GRANTED
    if (!granted) return
    map.locationComponent.apply {
        activateLocationComponent(LocationComponentActivationOptions.builder(context, style).build())
        isLocationComponentEnabled = true
    }
}

@Composable
fun RoundButton(icon: Int, description: String, onClick: () -> Unit) {
    val colors = GeocentTheme.colors
    Box(
        Modifier
            .size(48.dp)
            .shadow(6.dp, CircleShape)
            .clip(CircleShape)
            .background(colors.surface)
            .border(1.dp, colors.line, CircleShape)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(painterResource(icon), description, tint = colors.textPrimary, modifier = Modifier.size(22.dp))
    }
}
