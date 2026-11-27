package app.geocent.ui.profile

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.launch
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.geocent.data.settings.ImportRange
import app.geocent.ui.components.CategoryAvatar
import app.geocent.ui.components.NewCategoryDialog
import app.geocent.ui.components.SurfaceCard
import app.geocent.ui.components.TextButton
import app.geocent.ui.components.ToastHost
import app.geocent.ui.components.rememberFullSheetState
import app.geocent.ui.theme.GeocentTheme
import app.geocent.ui.theme.HugeIcons
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private val importLabels = linkedMapOf(
    ImportRange.LAST_7_DAYS to "Last 7 days",
    ImportRange.LAST_30_DAYS to "Last 30 days",
    ImportRange.LAST_3_MONTHS to "Last 3 months",
    ImportRange.EVERYTHING to "Everything",
)

private enum class ProfileSheet { NONE, IMPORT, CATEGORIES, LICENCES }

/** Profile tab: data, categories, permissions and about. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(viewModel: ProfileViewModel = hiltViewModel()) {
    val colors = GeocentTheme.colors
    val context = LocalContext.current
    val lastImport by viewModel.lastImportAt.collectAsStateWithLifecycle()
    val hotspots by viewModel.hotspotCount.collectAsStateWithLifecycle()
    val categories by viewModel.categoryList.collectAsStateWithLifecycle()
    var sheet by remember { mutableStateOf(ProfileSheet.NONE) }
    var creating by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf<Pair<String, Int>?>(null) }
    val scope = rememberCoroutineScope()

    // Permissions can change in system settings; re-read them on every resume.
    var resumes by remember { mutableIntStateOf(0) }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { resumes++ }
    val perms = remember(resumes) { PermissionState.read(context) }
    val monitoring = remember(resumes) { viewModel.canMonitorHotspots() }

    Box(Modifier.fillMaxSize().background(colors.background)) {
        Column(
            Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.statusBars)
                .verticalScroll(rememberScrollState())
                .padding(bottom = 24.dp),
        ) {
            Text(
                "Profile",
                style = GeocentTheme.typography.largeTitle,
                color = colors.textPrimary,
                modifier = Modifier.padding(start = 20.dp, top = 16.dp, bottom = 12.dp),
            )

            Section("Messages") {
                SettingRow(
                    label = "Import SMS history",
                    detail = lastImport?.let { "Last imported ${formatTime(it)}" } ?: "Not imported yet",
                    onClick = { sheet = ProfileSheet.IMPORT },
                )
            }

            Section("Categories") {
                SettingRow(
                    label = "Manage categories",
                    detail = "${categories.size} categories",
                    onClick = { sheet = ProfileSheet.CATEGORIES },
                )
            }

            Section("Spending hotspots") {
                SettingRow(
                    label = if (monitoring) "Monitoring $hotspots hotspot${if (hotspots == 1) "" else "s"}"
                    else "Hotspot alerts are off",
                    detail = if (monitoring) "You'll get a heads-up when you linger where you usually spend."
                    else "Allow location \"all the time\" to get alerts at places you spend often.",
                    onClick = if (monitoring) null else ({ openAppSettings(context) }),
                    warning = !monitoring,
                )
            }

            Section("Permissions") {
                PermissionRow("SMS", perms.sms, context)
                HorizontalDivider(thickness = 0.5.dp, color = colors.line)
                PermissionRow("Location", perms.location, context)
                HorizontalDivider(thickness = 0.5.dp, color = colors.line)
                PermissionRow("Location all the time", perms.background, context)
                HorizontalDivider(thickness = 0.5.dp, color = colors.line)
                PermissionRow("Notifications", perms.notifications, context)
            }

            Section("About") {
                SettingRow(label = "Version", detail = appVersion(context))
                HorizontalDivider(thickness = 0.5.dp, color = colors.line)
                SettingRow(label = "Licences", detail = "OpenStreetMap, fonts and icons", onClick = { sheet = ProfileSheet.LICENCES })
            }
        }
        ToastHost(viewModel.toasts, Modifier.windowInsetsPadding(WindowInsets.statusBars))
    }

    when (sheet) {
        ProfileSheet.IMPORT -> ModalBottomSheet(onDismissRequest = { sheet = ProfileSheet.NONE }, sheetState = rememberFullSheetState(), containerColor = colors.surface) {
            Column(Modifier.navigationBarsPadding().padding(horizontal = 20.dp).padding(bottom = 16.dp)) {
                Text("Import SMS history", style = GeocentTheme.typography.title, color = colors.textPrimary)
                Text(
                    "Messages already in Geocent, or ones you forgot, are skipped.",
                    style = GeocentTheme.typography.caption, color = colors.textSecondary,
                )
                Spacer(Modifier.height(8.dp))
                importLabels.forEach { (range, label) ->
                    Text(
                        label,
                        style = GeocentTheme.typography.body,
                        color = colors.textPrimary,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { viewModel.importAgain(range); sheet = ProfileSheet.NONE }
                            .padding(vertical = 14.dp),
                    )
                }
            }
        }
        ProfileSheet.CATEGORIES -> ModalBottomSheet(onDismissRequest = { sheet = ProfileSheet.NONE }, sheetState = rememberFullSheetState(), containerColor = colors.surface) {
            Column(Modifier.navigationBarsPadding()) {
                Row(Modifier.padding(horizontal = 20.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text("Categories", style = GeocentTheme.typography.title, color = colors.textPrimary, modifier = Modifier.weight(1f))
                    TextButton("New", { creating = true })
                }
                LazyColumn(Modifier.heightIn(max = 520.dp)) {
                    items(categories, key = { it.name }) { category ->
                        Row(
                            Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            CategoryAvatar(category, category.name, size = 36.dp)
                            Spacer(Modifier.width(12.dp))
                            Text(category.name, style = GeocentTheme.typography.body, color = colors.textPrimary, modifier = Modifier.weight(1f))
                            Icon(
                                painterResource(HugeIcons.delete02), "Delete ${category.name}", tint = colors.textSecondary,
                                modifier = Modifier.size(22.dp).clickable {
                                    scope.launch { confirmDelete = category.name to viewModel.usage(category.name) }
                                },
                            )
                        }
                    }
                }
                Spacer(Modifier.height(12.dp))
            }
        }
        ProfileSheet.LICENCES -> ModalBottomSheet(onDismissRequest = { sheet = ProfileSheet.NONE }, sheetState = rememberFullSheetState(), containerColor = colors.surface) {
            val text = remember { licenceText(context) }
            Column(Modifier.navigationBarsPadding().padding(horizontal = 20.dp)) {
                Text("Licences", style = GeocentTheme.typography.title, color = colors.textPrimary)
                Spacer(Modifier.height(8.dp))
                Text(
                    text,
                    style = GeocentTheme.typography.caption,
                    color = colors.textSecondary,
                    modifier = Modifier.heightIn(max = 560.dp).verticalScroll(rememberScrollState()).padding(bottom = 16.dp),
                )
            }
        }
        ProfileSheet.NONE -> Unit
    }

    if (creating) {
        NewCategoryDialog(
            taken = categories.map { it.name.lowercase() }.toSet(),
            usedIcons = categories.map { it.iconKey }.toSet(),
            onDismiss = { creating = false },
            onCreate = { name, icon, color -> viewModel.addCategory(name, icon, color); creating = false },
        )
    }

    confirmDelete?.let { (name, count) ->
        AlertDialog(
            onDismissRequest = { confirmDelete = null },
            containerColor = colors.surface,
            title = { Text("Delete $name?", style = GeocentTheme.typography.title, color = colors.textPrimary) },
            text = {
                Text(
                    if (count == 0) "No payments use it."
                    else "$count payment${if (count == 1) "" else "s"} will need a category again, and its budget will be removed.",
                    style = GeocentTheme.typography.body, color = colors.textSecondary,
                )
            },
            confirmButton = { TextButton("Delete", { viewModel.deleteCategory(name); confirmDelete = null }) },
            dismissButton = { TextButton("Cancel", { confirmDelete = null }) },
        )
    }
}

@Composable
private fun Section(title: String, content: @Composable () -> Unit) {
    Text(
        title.uppercase(),
        style = GeocentTheme.typography.tabLabel,
        color = GeocentTheme.colors.textSecondary,
        modifier = Modifier.padding(start = 32.dp, top = 16.dp, bottom = 6.dp),
    )
    SurfaceCard(Modifier.padding(horizontal = 16.dp).fillMaxWidth(), contentPadding = androidx.compose.foundation.layout.PaddingValues(0.dp)) {
        content()
    }
}

@Composable
private fun SettingRow(label: String, detail: String, onClick: (() -> Unit)? = null, warning: Boolean = false) {
    val colors = GeocentTheme.colors
    Row(
        Modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(label, style = GeocentTheme.typography.body, color = if (warning) colors.dataWarning else colors.textPrimary)
            Text(detail, style = GeocentTheme.typography.caption, color = colors.textSecondary)
        }
        if (onClick != null) Icon(painterResource(HugeIcons.arrowRight01), null, tint = colors.textSecondary, modifier = Modifier.size(18.dp))
    }
}

@Composable
private fun PermissionRow(label: String, granted: Boolean, context: Context) {
    val colors = GeocentTheme.colors
    Row(
        Modifier
            .fillMaxWidth()
            .clickable { openAppSettings(context) }
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(label, style = GeocentTheme.typography.body, color = colors.textPrimary)
        Text(
            if (granted) "Allowed" else "Off",
            style = GeocentTheme.typography.caption,
            color = if (granted) colors.dataPositive else colors.dataWarning,
        )
    }
}

private data class PermissionState(val sms: Boolean, val location: Boolean, val background: Boolean, val notifications: Boolean) {
    companion object {
        fun read(context: Context): PermissionState {
            fun has(p: String) = ContextCompat.checkSelfPermission(context, p) == PackageManager.PERMISSION_GRANTED
            return PermissionState(
                sms = has(Manifest.permission.RECEIVE_SMS) && has(Manifest.permission.READ_SMS),
                location = has(Manifest.permission.ACCESS_FINE_LOCATION),
                background = has(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
                notifications = Build.VERSION.SDK_INT < 33 || has(Manifest.permission.POST_NOTIFICATIONS),
            )
        }
    }
}

private fun openAppSettings(context: Context) {
    context.startActivity(
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
    )
}

private fun appVersion(context: Context): String =
    runCatching { context.packageManager.getPackageInfo(context.packageName, 0).versionName }.getOrNull() ?: "?"

private val timeFormat = DateTimeFormatter.ofPattern("d MMM yyyy, HH:mm")
private fun formatTime(millis: Long) = Instant.ofEpochMilli(millis).atZone(ZoneId.systemDefault()).format(timeFormat)

/** Map attribution plus the bundled font and icon licences from assets/licenses. */
private fun licenceText(context: Context): String = buildString {
    append("Map data © OpenStreetMap contributors (ODbL). Map tiles and styles by OpenFreeMap.\n\n")
    append("Maps rendered with MapLibre Native (BSD-2-Clause).\n\n")
    context.assets.list("licenses").orEmpty().sorted().forEach { file ->
        append("── ").append(file.removeSuffix(".txt")).append(" ──\n\n")
        append(context.assets.open("licenses/$file").bufferedReader().use { it.readText().trim() })
        append("\n\n")
    }
}
