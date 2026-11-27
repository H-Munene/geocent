package app.geocent.ui.map

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.PointF
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.input.TextFieldLineLimits
import androidx.compose.foundation.text.input.clearText
import androidx.compose.foundation.text.input.rememberTextFieldState
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.SliderState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.geocent.data.AreaSummary
import app.geocent.data.db.CategoryEntity
import app.geocent.data.db.TransactionEntity
import app.geocent.domain.CategoryCatalog
import app.geocent.domain.Place
import app.geocent.domain.boundingBox
import app.geocent.domain.circlePolygon
import app.geocent.domain.markerSortKey
import app.geocent.notify.Notifier
import app.geocent.ui.components.CategoryAvatar
import app.geocent.ui.components.CategorySheet
import app.geocent.ui.components.SurfaceCard
import app.geocent.ui.components.color
import app.geocent.ui.components.rememberFullSheetState
import app.geocent.ui.location.RoundButton
import app.geocent.ui.theme.GeocentTheme
import app.geocent.ui.theme.HugeIcons
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.location.LocationComponentActivationOptions
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.Style
import java.time.format.DateTimeFormatter
import kotlin.math.roundToInt

/** What a popup card is showing: one or more transactions at a point. */
private data class PopupTarget(val latitude: Double, val longitude: Double, val transactions: List<TransactionEntity>)

private fun TransactionEntity.asTarget() = PopupTarget(latitude!!, longitude!!, listOf(this))
private fun Place<TransactionEntity>.asTarget() = PopupTarget(latitude, longitude, items)

private enum class Sheet { NONE, STYLE, EXPLORE, GROUP, CATEGORY_LIST }

/**
 * Map tab: today's spending as price-tag markers,
 * plus the "spending around here" inspector (long-press anywhere).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MapScreen(onPickLocation: (List<String>) -> Unit, viewModel: MapViewModel = hiltViewModel()) {
    val colors = GeocentTheme.colors
    val context = LocalContext.current
    val density = LocalDensity.current
    val haptics = LocalHapticFeedback.current
    val scope = rememberCoroutineScope()

    val places by viewModel.todayPlaces.collectAsStateWithLifecycle()
    val categories by viewModel.categories.collectAsStateWithLifecycle()
    val categoryList by viewModel.categoryList.collectAsStateWithLifecycle()
    val styleUrl by viewModel.style.collectAsStateWithLifecycle()
    val area by viewModel.area.collectAsStateWithLifecycle()
    val areaSummary by viewModel.areaSummary.collectAsStateWithLifecycle()
    val mapped by viewModel.mapped.collectAsStateWithLifecycle()

    var map by remember { mutableStateOf<MapLibreMap?>(null) }
    var style by remember { mutableStateOf<Style?>(null) }
    var loadedStyleUrl by remember { mutableStateOf<String?>(null) }
    var cameraTick by remember { mutableIntStateOf(0) }
    var placedCamera by rememberSaveable { mutableStateOf(false) }

    var popup by remember { mutableStateOf<PopupTarget?>(null) }
    var sheet by remember { mutableStateOf(Sheet.NONE) }
    var sheetCategory by remember { mutableStateOf<String?>(null) }
    var categorizeId by remember { mutableStateOf<String?>(null) }

    val renderer = remember { CalloutRenderer(context) }
    val mapView = rememberMapView()

    // Latest values for the map's listeners, which are registered once.
    val placesNow by androidx.compose.runtime.rememberUpdatedState(places)
    val onMarker: (String, Boolean) -> Unit = { key, long ->
        placesNow.firstOrNull { it.key == key }?.let { place ->
            if (long) {
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                onPickLocation(place.items.map { it.id })
            } else if (place.items.size > 1) {
                popup = place.asTarget(); sheet = Sheet.GROUP
            } else {
                popup = place.asTarget()
            }
        }
    }
    val onMarkerNow by androidx.compose.runtime.rememberUpdatedState(onMarker)

    fun flyTo(lat: Double, lng: Double, zoom: Double = 16.5) {
        map?.animateCamera(CameraUpdateFactory.newLatLngZoom(LatLng(lat, lng), zoom), 700)
    }

    fun fitArea(lat: Double, lng: Double, radius: Double) {
        val m = map ?: return
        val box = boundingBox(lat, lng, radius * 1.15)
        val bounds = LatLngBounds.from(box.maxLat, box.maxLng, box.minLat, box.minLng)
        val px = { v: Int -> with(density) { v.dp.roundToPx() } }
        m.animateCamera(CameraUpdateFactory.newLatLngBounds(bounds, px(40), px(180), px(40), px(380)), 600)
    }

    // Style: (re)load when the chosen URL changes, then add Geocent's layers.
    LaunchedEffect(map, styleUrl) {
        val m = map ?: return@LaunchedEffect
        if (loadedStyleUrl == styleUrl) return@LaunchedEffect
        style = null
        m.setStyle(Style.Builder().fromUri(styleUrl)) { loaded ->
            installGeocentLayers(loaded, Color(0xFF0071E3).toArgb())
            enableLocationDot(context, m, loaded)
            loadedStyleUrl = styleUrl
            style = loaded
        }
    }

    // Start where the user is (or their latest spend), once.
    LaunchedEffect(map) {
        val m = map ?: return@LaunchedEffect
        if (placedCamera) return@LaunchedEffect
        val (lat, lng) = viewModel.startPoint()
        m.cameraPosition = CameraPosition.Builder().target(LatLng(lat, lng)).zoom(15.0).build()
        placedCamera = true
    }

    // Markers: one callout image per distinct (name, price, colour).
    LaunchedEffect(style, places, categories, popup) {
        val s = style ?: return@LaunchedEffect
        val selectedKey = popup?.let { p -> places.firstOrNull { it.latitude == p.latitude && it.longitude == p.longitude }?.key }
        s.setPlaces(
            places.map { place ->
                val first = place.items.first()
                val color = first.category?.let(categories::get)?.colorArgb ?: CategoryCatalog.FALLBACK_COLOR
                val name = if (place.items.size > 1) "${place.items.size} payments" else first.merchant
                val total = place.items.filter { it.currency == "KES" }.sumOf { it.amount }
                val price = Notifier.formatKes(total)
                val icon = "callout-${(name + price + color).hashCode()}"
                s.addImageIfMissing(icon) { renderer.render(name, price, color.toInt()) }
                PlaceFeature(
                    key = place.key,
                    latitude = place.latitude,
                    longitude = place.longitude,
                    icon = icon,
                    colorHex = String.format("#%06X", color.toInt() and 0xFFFFFF),
                    sortKey = markerSortKey(place.key == selectedKey, place.items.size, total),
                )
            },
        )
    }
    LaunchedEffect(style, area) {
        val s = style ?: return@LaunchedEffect
        val a = area
        s.setArea(a?.let { it.latitude to it.longitude }, a?.let { circlePolygon(it.latitude, it.longitude, it.radiusMeters) })
    }
    // Refit the camera when the area radius changes (debounced by the slider's settle).
    LaunchedEffect(Unit) {
        snapshotFlow { area?.let { Triple(it.latitude, it.longitude, it.radiusMeters) } }.collect { a ->
            if (a != null) { delay(250); fitArea(a.first, a.second, a.third) }
        }
    }

    Box(Modifier.fillMaxSize().background(colors.background)) {
        AndroidView(
            factory = {
                mapView.apply {
                    getMapAsync { m ->
                        m.uiSettings.apply {
                            isCompassEnabled = true
                            compassGravity = android.view.Gravity.TOP or android.view.Gravity.END
                            setCompassMargins(0, with(density) { 170.dp.roundToPx() }, with(density) { 16.dp.roundToPx() }, 0)
                            isLogoEnabled = false
                            setAttributionMargins(with(density) { 8.dp.roundToPx() }, 0, 0, with(density) { 4.dp.roundToPx() })
                        }
                        m.setMinZoomPreference(3.0)
                        m.setMaxZoomPreference(19.7)
                        m.addOnCameraMoveListener { cameraTick++ }
                        m.addOnMapClickListener { latLng ->
                            val key = markerAt(m, m.projection.toScreenLocation(latLng))
                            if (key != null) onMarkerNow(key, false) else popup = null
                            true
                        }
                        m.addOnMapLongClickListener { latLng ->
                            val key = markerAt(m, m.projection.toScreenLocation(latLng))
                            if (key != null) {
                                onMarkerNow(key, true)
                            } else {
                                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                                popup = null
                                viewModel.inspectArea(latLng.latitude, latLng.longitude)
                            }
                            true
                        }
                        map = m
                    }
                }
            },
            modifier = Modifier.fillMaxSize(),
        )

        // Popup card anchored above its marker; follows the camera.
        popup?.takeIf { sheet != Sheet.GROUP }?.let { target ->
            val m = map
            if (m != null) {
                @Suppress("UNUSED_VARIABLE") val tick = cameraTick // re-project when the camera moves
                val point = m.projection.toScreenLocation(LatLng(target.latitude, target.longitude))
                PopupCard(
                    target = target,
                    categories = categories,
                    anchor = IntOffset(point.x.roundToInt(), point.y.roundToInt()),
                    onCategorize = { categorizeId = it },
                    onMove = { onPickLocation(target.transactions.map { it.id }) },
                    onClose = { popup = null },
                )
            }
        }

        Column(Modifier.windowInsetsPadding(WindowInsets.statusBars).padding(horizontal = 16.dp, vertical = 8.dp)) {
            MapHeader(
                viewModel = viewModel,
                onResult = { tx -> popup = tx.asTarget(); flyTo(tx.latitude!!, tx.longitude!!) },
            )
            Spacer(Modifier.height(10.dp))
            CategoryChips(categoryList) { name -> sheetCategory = name; sheet = Sheet.CATEGORY_LIST }
            JustMappedBanner(viewModel) { tx -> popup = tx.asTarget(); flyTo(tx.latitude!!, tx.longitude!!) }
        }

        Column(Modifier.align(Alignment.BottomCenter).fillMaxWidth().padding(16.dp)) {
            Column(Modifier.align(Alignment.End), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                RoundButton(HugeIcons.layers01, "Map style") { sheet = Sheet.STYLE }
                RoundButton(HugeIcons.location06, "Spending around here") {
                    map?.cameraPosition?.target?.let { viewModel.inspectArea(it.latitude, it.longitude) }
                }
                RoundButton(HugeIcons.navigation03, "My location") {
                    scope.launch { viewModel.myLocation()?.let { (la, ln) -> flyTo(la, ln, 16.0) } }
                }
                if (mapped.isNotEmpty()) RoundButton(HugeIcons.search01, "Explore mapped spending") { sheet = Sheet.EXPLORE }
            }
            AnimatedVisibility(visible = area != null, enter = slideInVertically { it } + fadeIn(), exit = slideOutVertically { it } + fadeOut()) {
                area?.let { a ->
                    AreaCard(
                        selection = a,
                        summary = areaSummary,
                        categories = categories,
                        onRadius = viewModel::setAreaRadius,
                        onPeriod = viewModel::setAreaPeriod,
                        onClose = viewModel::closeArea,
                    )
                }
            }
        }
    }

    // Sheets
    when (sheet) {
        Sheet.STYLE -> ModalBottomSheet(onDismissRequest = { sheet = Sheet.NONE }, sheetState = rememberFullSheetState(), containerColor = colors.surface) {
            StylePicker(current = styleUrl) { viewModel.setStyle(it); sheet = Sheet.NONE }
        }
        Sheet.EXPLORE -> TransactionListSheet("Mapped spending", mapped, categories, onDismiss = { sheet = Sheet.NONE }) { tx ->
            sheet = Sheet.NONE; popup = tx.asTarget(); flyTo(tx.latitude!!, tx.longitude!!)
        }
        Sheet.GROUP -> popup?.let { target ->
            TransactionListSheet("${target.transactions.size} payments here", target.transactions, categories, onDismiss = { sheet = Sheet.NONE }) { tx ->
                categorizeId = tx.id
            }
        }
        Sheet.CATEGORY_LIST -> sheetCategory?.let { name ->
            val txs by viewModel.transactionsInCategory(name).collectAsStateWithLifecycle(emptyList())
            TransactionListSheet(name, txs, categories, onDismiss = { sheet = Sheet.NONE }) { tx ->
                sheet = Sheet.NONE
                if (tx.hasLocation) { popup = tx.asTarget(); flyTo(tx.latitude!!, tx.longitude!!) } else onPickLocation(listOf(tx.id))
            }
        }
        Sheet.NONE -> Unit
    }

    categorizeId?.let { id ->
        CategorySheet(
            title = "Choose a category",
            categories = categoryList,
            current = mapped.firstOrNull { it.id == id }?.category,
            onSelect = { viewModel.categorize(id, it); categorizeId = null },
            onCreate = { name, icon, color -> viewModel.createCategory(name, icon, color, id); categorizeId = null },
            onDismiss = { categorizeId = null },
        )
    }
}

/** Key of the marker under a screen point, if any. */
private fun markerAt(map: MapLibreMap, point: PointF): String? =
    map.queryRenderedFeatures(point, MapIds.CALLOUTS, MapIds.DOTS).firstOrNull()?.getStringProperty(MapIds.P_KEY)

@SuppressLint("MissingPermission") // checked just before
private fun enableLocationDot(context: Context, map: MapLibreMap, style: Style) {
    if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) return
    map.locationComponent.apply {
        activateLocationComponent(LocationComponentActivationOptions.builder(context, style).build())
        isLocationComponentEnabled = true
    }
}

private val timeFormat = DateTimeFormatter.ofPattern("d MMM, HH:mm")

private fun formatAmount(tx: TransactionEntity) =
    if (tx.currency == "KES") Notifier.formatKes(tx.amount) else "${tx.currency} ${"%.2f".format(tx.amount)}"

@Composable
private fun MapHeader(viewModel: MapViewModel, onResult: (TransactionEntity) -> Unit) {
    val colors = GeocentTheme.colors
    val totals by viewModel.periodTotals.collectAsStateWithLifecycle()
    val results by viewModel.searchResults.collectAsStateWithLifecycle()
    val state = rememberTextFieldState()
    var periodIndex by rememberSaveable { mutableIntStateOf(1) }
    LaunchedEffect(state) { snapshotFlow { state.text.toString() }.collect(viewModel::setQuery) }

    Column {
        Row(verticalAlignment = Alignment.CenterVertically) {
            BasicTextField(
                state = state,
                lineLimits = TextFieldLineLimits.SingleLine,
                textStyle = GeocentTheme.typography.body.copy(color = colors.textPrimary),
                cursorBrush = SolidColor(colors.accent),
                modifier = Modifier.weight(1f),
                decorator = { inner ->
                    Row(
                        Modifier
                            .shadow(6.dp, RoundedCornerShape(14.dp))
                            .clip(RoundedCornerShape(14.dp))
                            .background(colors.surface)
                            .padding(horizontal = 12.dp, vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(painterResource(HugeIcons.search01), null, tint = colors.textSecondary, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(8.dp))
                        Box(Modifier.weight(1f)) {
                            if (state.text.isEmpty()) Text("Search spending", style = GeocentTheme.typography.body, color = colors.textSecondary)
                            inner()
                        }
                        if (state.text.isNotEmpty()) {
                            Icon(
                                painterResource(HugeIcons.cancel01), "Clear", tint = colors.textSecondary,
                                modifier = Modifier.size(18.dp).clickable { state.clearText() },
                            )
                        }
                    }
                },
            )
            Spacer(Modifier.width(8.dp))
            // Tap to cycle today / this week / this month.
            val (label, amount) = when (periodIndex) {
                0 -> "Today" to totals.today
                1 -> "This week" to totals.week
                else -> "This month" to totals.month
            }
            Column(
                Modifier
                    .shadow(6.dp, RoundedCornerShape(14.dp))
                    .clip(RoundedCornerShape(14.dp))
                    .background(colors.surface)
                    .clickable { periodIndex = (periodIndex + 1) % 3 }
                    .padding(horizontal = 12.dp, vertical = 6.dp),
                horizontalAlignment = Alignment.End,
            ) {
                Text(label.uppercase(), style = GeocentTheme.typography.tabLabel, color = colors.textSecondary)
                Text(Notifier.formatKes(amount), style = GeocentTheme.typography.amount, color = colors.textPrimary)
            }
        }
        if (results.isNotEmpty()) {
            Spacer(Modifier.height(6.dp))
            SurfaceCard(Modifier.fillMaxWidth().heightIn(max = 320.dp), contentPadding = androidx.compose.foundation.layout.PaddingValues(0.dp)) {
                LazyColumn {
                    items(results, key = { it.id }) { tx ->
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .clickable { state.clearText(); onResult(tx) }
                                .padding(horizontal = 14.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Column(Modifier.weight(1f)) {
                                Text(tx.merchant, style = GeocentTheme.typography.headline, color = colors.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                Text(viewModel.localTime(tx).format(timeFormat), style = GeocentTheme.typography.caption, color = colors.textSecondary)
                            }
                            Text(formatAmount(tx), style = GeocentTheme.typography.amount, color = colors.textPrimary)
                        }
                        HorizontalDivider(thickness = 0.5.dp, color = colors.line)
                    }
                }
            }
        }
    }
}

@Composable
private fun CategoryChips(categories: List<CategoryEntity>, onTap: (String) -> Unit) {
    val colors = GeocentTheme.colors
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        categories.forEach { category ->
            Row(
                Modifier
                    .shadow(3.dp, RoundedCornerShape(20.dp))
                    .clip(RoundedCornerShape(20.dp))
                    .background(colors.surface)
                    .clickable { onTap(category.name) }
                    .padding(start = 4.dp, end = 12.dp, top = 4.dp, bottom = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                CategoryAvatar(category, category.name, size = 26.dp)
                Spacer(Modifier.width(6.dp))
                Text(category.name, style = GeocentTheme.typography.caption, color = colors.textPrimary)
            }
        }
    }
}

/** Slides in for a few seconds when a transaction gets its location while the map is open. */
@Composable
private fun JustMappedBanner(viewModel: MapViewModel, onTap: (TransactionEntity) -> Unit) {
    val colors = GeocentTheme.colors
    var current by remember { mutableStateOf<TransactionEntity?>(null) }
    LaunchedEffect(Unit) {
        viewModel.justMapped.collect { tx ->
            current = tx
            delay(4_000)
            current = null
        }
    }
    AnimatedVisibility(visible = current != null, enter = slideInVertically { -it } + fadeIn(), exit = slideOutVertically { -it } + fadeOut()) {
        current?.let { tx ->
            Row(
                Modifier
                    .padding(top = 10.dp)
                    .fillMaxWidth()
                    .shadow(10.dp, RoundedCornerShape(24.dp))
                    .clip(RoundedCornerShape(24.dp))
                    .background(Color(0xFF1C1C1E))
                    .clickable { onTap(tx) }
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(painterResource(HugeIcons.location01), null, tint = colors.dataPositive, modifier = Modifier.size(20.dp))
                Spacer(Modifier.width(10.dp))
                Column(Modifier.weight(1f)) {
                    Text("Mapped just now", style = GeocentTheme.typography.caption, color = Color(0xFFAEAEB2))
                    Text(tx.merchant, style = GeocentTheme.typography.headline, color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                Text(formatAmount(tx), style = GeocentTheme.typography.amount, color = Color.White)
            }
        }
    }
}

@Composable
private fun PopupCard(
    target: PopupTarget,
    categories: Map<String, CategoryEntity>,
    anchor: IntOffset,
    onCategorize: (String) -> Unit,
    onMove: () -> Unit,
    onClose: () -> Unit,
) {
    val colors = GeocentTheme.colors
    val density = LocalDensity.current
    val tx = target.transactions.first()
    val category = tx.category?.let(categories::get)
    var size by remember { mutableStateOf(androidx.compose.ui.unit.IntSize.Zero) }
    val lift = with(density) { 46.dp.roundToPx() } // clear the callout under it
    Column(
        Modifier
            .offset { IntOffset(anchor.x - size.width / 2, anchor.y - size.height - lift) }
            .onSizeChanged { size = it }
            .widthIn(max = 280.dp)
            .shadow(12.dp, RoundedCornerShape(16.dp))
            .clip(RoundedCornerShape(16.dp))
            .background(colors.surface)
            .padding(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(tx.merchant, style = GeocentTheme.typography.headline, color = colors.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
            Spacer(Modifier.width(10.dp))
            Icon(painterResource(HugeIcons.cancel01), "Close", tint = colors.textSecondary, modifier = Modifier.size(18.dp).clickable(onClick = onClose))
        }
        Text(formatAmount(tx), style = GeocentTheme.typography.amountLarge, color = colors.textPrimary)
        Text(
            java.time.Instant.ofEpochMilli(tx.timestamp).atZone(java.time.ZoneId.systemDefault()).format(timeFormat),
            style = GeocentTheme.typography.caption, color = colors.textSecondary,
        )
        Spacer(Modifier.height(10.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Row(
                Modifier
                    .clip(RoundedCornerShape(10.dp))
                    .background((category?.color() ?: colors.accent).copy(alpha = 0.12f))
                    .clickable { onCategorize(tx.id) }
                    .padding(horizontal = 8.dp, vertical = 5.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (category != null) {
                    Icon(painterResource(app.geocent.ui.theme.categoryIcon(category.iconKey)), null, tint = category.color().copy(alpha = 1f), modifier = Modifier.size(14.dp))
                    Spacer(Modifier.width(5.dp))
                }
                Text(category?.name ?: "Set category", style = GeocentTheme.typography.caption, color = category?.color()?.copy(alpha = 1f) ?: colors.accent)
            }
            Spacer(Modifier.weight(1f))
            Text("Move", style = GeocentTheme.typography.caption.copy(fontWeight = FontWeight.SemiBold), color = colors.accent, modifier = Modifier.clickable(onClick = onMove).padding(4.dp))
        }
    }
}

@Composable
private fun AreaCard(
    selection: AreaSelection,
    summary: AreaSummary?,
    categories: Map<String, CategoryEntity>,
    onRadius: (Double) -> Unit,
    onPeriod: (AreaPeriod) -> Unit,
    onClose: () -> Unit,
) {
    val colors = GeocentTheme.colors
    // 100 m to 2 km, rounded to 50 m; reported to the view model when the drag ends.
    val slider = remember(selection.latitude, selection.longitude) {
        SliderState(selection.radiusMeters.toFloat(), 0, 100f..2000f)
    }
    val radius = (slider.value / 50).roundToInt() * 50f
    SurfaceCard(Modifier.padding(top = 12.dp).fillMaxWidth().navigationBarsPadding()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text("Spending around here", style = GeocentTheme.typography.headline, color = colors.textPrimary)
                Text("Within ${formatDistance(radius.toDouble())} · long-press the map to move", style = GeocentTheme.typography.caption, color = colors.textSecondary)
            }
            Icon(painterResource(HugeIcons.cancel01), "Close", tint = colors.textSecondary, modifier = Modifier.size(22.dp).clickable(onClick = onClose))
        }
        Slider(
            state = slider,
            onValueChange = { slider.value = it },
            onValueChangeFinished = { onRadius(radius.toDouble()) },
            colors = SliderDefaults.colors(thumbColor = colors.accent, activeTrackColor = colors.accent, inactiveTrackColor = colors.line),
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            AreaPeriod.entries.forEach { p ->
                val selected = p == selection.period
                Text(
                    p.label,
                    style = GeocentTheme.typography.caption.copy(fontWeight = FontWeight.SemiBold),
                    color = if (selected) Color.White else colors.textPrimary,
                    modifier = Modifier
                        .clip(RoundedCornerShape(14.dp))
                        .background(if (selected) colors.accent else colors.background)
                        .clickable { onPeriod(p) }
                        .padding(horizontal = 12.dp, vertical = 6.dp),
                )
            }
        }
        Spacer(Modifier.height(12.dp))
        val s = summary
        if (s == null) {
            Text("Loading…", style = GeocentTheme.typography.caption, color = colors.textSecondary)
        } else if (s.count == 0) {
            Text("No spending recorded here ${selection.period.label.lowercase()}.", style = GeocentTheme.typography.body, color = colors.textSecondary)
        } else {
            Text(Notifier.formatKes(s.total), style = GeocentTheme.typography.amountLarge, color = colors.textPrimary)
            Text(
                "${s.count} payment${if (s.count == 1) "" else "s"} · average ${Notifier.formatKes(s.average)}",
                style = GeocentTheme.typography.caption, color = colors.textSecondary,
            )
            Spacer(Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                Column(Modifier.weight(1f)) {
                    Text("TOP CATEGORIES", style = GeocentTheme.typography.tabLabel, color = colors.textSecondary)
                    s.topCategories.forEach { (name, amount) ->
                        Row(Modifier.padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                            CategoryAvatar(categories[name], name, size = 22.dp)
                            Spacer(Modifier.width(6.dp))
                            Text(name, style = GeocentTheme.typography.caption, color = colors.textPrimary, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                            Spacer(Modifier.width(6.dp))
                            Text(Notifier.formatKes(amount), style = GeocentTheme.typography.amountSmall, color = colors.textPrimary)
                        }
                    }
                }
                Column(Modifier.weight(1f)) {
                    Text("TOP PLACES", style = GeocentTheme.typography.tabLabel, color = colors.textSecondary)
                    s.topMerchants.forEach { (name, amount) ->
                        Row(Modifier.padding(top = 9.dp)) {
                            Text(name, style = GeocentTheme.typography.caption, color = colors.textPrimary, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                            Spacer(Modifier.width(6.dp))
                            Text(Notifier.formatKes(amount), style = GeocentTheme.typography.amountSmall, color = colors.textPrimary)
                        }
                    }
                }
            }
        }
    }
}

private fun formatDistance(m: Double) = if (m < 1000) "${m.roundToInt()} m" else "%.1f km".format(m / 1000)

@Composable
private fun StylePicker(current: String, onPick: (String) -> Unit) {
    val colors = GeocentTheme.colors
    val options = listOf(
        Triple(MapStyles.STANDARD, "Standard", listOf(Color(0xFFF2EFE9), Color(0xFFC8E6C9), Color(0xFFFFD580))),
        Triple(MapStyles.LIGHT, "Light", listOf(Color(0xFFF8F8F8), Color(0xFFE6E6E6), Color(0xFFFFFFFF))),
        Triple(MapStyles.DARK, "Dark", listOf(Color(0xFF1F1F1F), Color(0xFF2E2E2E), Color(0xFF4A4A4A))),
    )
    Column(Modifier.navigationBarsPadding().padding(horizontal = 20.dp).padding(bottom = 20.dp)) {
        Text("Map style", style = GeocentTheme.typography.title, color = colors.textPrimary)
        Spacer(Modifier.height(16.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            options.forEach { (url, name, swatch) ->
                val selected = url == current
                Column(
                    Modifier.weight(1f).clip(RoundedCornerShape(14.dp)).clickable { onPick(url) },
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    // A tiny abstract map: background with two "roads".
                    Box(
                        Modifier
                            .fillMaxWidth()
                            .height(90.dp)
                            .clip(RoundedCornerShape(14.dp))
                            .background(swatch[0])
                            .border(if (selected) 3.dp else 1.dp, if (selected) colors.accent else colors.line, RoundedCornerShape(14.dp)),
                    ) {
                        Box(Modifier.align(Alignment.Center).fillMaxWidth().height(10.dp).background(swatch[2]))
                        Box(Modifier.align(Alignment.Center).width(10.dp).height(90.dp).background(swatch[2]))
                        Box(Modifier.align(Alignment.TopStart).padding(10.dp).size(26.dp).clip(RoundedCornerShape(6.dp)).background(swatch[1]))
                    }
                    Spacer(Modifier.height(6.dp))
                    Text(name, style = GeocentTheme.typography.caption, color = if (selected) colors.accent else colors.textPrimary)
                }
            }
        }
        Spacer(Modifier.height(10.dp))
        Text("Map data © OpenStreetMap contributors, tiles by OpenFreeMap.", style = GeocentTheme.typography.caption, color = colors.textSecondary)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TransactionListSheet(
    title: String,
    transactions: List<TransactionEntity>,
    categories: Map<String, CategoryEntity>,
    onDismiss: () -> Unit,
    onTap: (TransactionEntity) -> Unit,
) {
    val colors = GeocentTheme.colors
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = rememberFullSheetState(), containerColor = colors.surface) {
        Column(Modifier.navigationBarsPadding()) {
            Row(Modifier.padding(horizontal = 20.dp), verticalAlignment = Alignment.Bottom) {
                Text(title, style = GeocentTheme.typography.title, color = colors.textPrimary, modifier = Modifier.weight(1f))
                Text(
                    Notifier.formatKes(transactions.filter { it.currency == "KES" && it.type.isSpending }.sumOf { it.amount }),
                    style = GeocentTheme.typography.amount, color = colors.textSecondary,
                )
            }
            Spacer(Modifier.height(8.dp))
            if (transactions.isEmpty()) {
                Text("Nothing here yet.", style = GeocentTheme.typography.body, color = colors.textSecondary, modifier = Modifier.padding(20.dp))
            }
            LazyColumn(Modifier.heightIn(max = 520.dp)) {
                items(transactions, key = { it.id }) { tx ->
                    Row(
                        Modifier.fillMaxWidth().clickable { onTap(tx) }.padding(horizontal = 20.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        CategoryAvatar(tx.category?.let(categories::get), tx.merchant, size = 36.dp)
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text(tx.merchant, style = GeocentTheme.typography.headline, color = colors.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                            val where = if (tx.hasLocation) "" else " · no location"
                            Text(
                                java.time.Instant.ofEpochMilli(tx.timestamp).atZone(java.time.ZoneId.systemDefault()).format(timeFormat) + where,
                                style = GeocentTheme.typography.caption, color = colors.textSecondary,
                            )
                        }
                        Text(formatAmount(tx), style = GeocentTheme.typography.amount, color = colors.textPrimary)
                    }
                }
            }
        }
    }
}
