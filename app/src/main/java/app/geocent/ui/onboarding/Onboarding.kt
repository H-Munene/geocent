package app.geocent.ui.onboarding

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.border
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.viewModelScope
import app.geocent.data.settings.ImportRange
import app.geocent.data.settings.SettingsStore
import app.geocent.ingest.ImportInboxWorker
import app.geocent.ui.components.PrimaryButton
import app.geocent.ui.components.SurfaceCard
import app.geocent.ui.components.TextButton
import app.geocent.ui.theme.GeocentTheme
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class OnboardingViewModel @Inject constructor(
    private val settings: SettingsStore,
    @ApplicationContext private val context: Context,
) : ViewModel() {
    fun finish(range: ImportRange) {
        viewModelScope.launch {
            settings.completeOnboarding(range)
            if (range != ImportRange.NONE) ImportInboxWorker.enqueue(context)
        }
    }
}

private enum class Step { WELCOME, PERMISSIONS, IMPORT }

/** First-run flow: what the app does, permissions, and how much SMS history to import. */
@Composable
fun OnboardingScreen(viewModel: OnboardingViewModel = hiltViewModel()) {
    var step by rememberSaveable { mutableStateOf(Step.WELCOME) }
    Column(
        Modifier
            .fillMaxSize()
            .background(GeocentTheme.colors.background)
            .windowInsetsPadding(WindowInsets.safeDrawing)
            .padding(24.dp),
    ) {
        when (step) {
            Step.WELCOME -> WelcomeStep { step = Step.PERMISSIONS }
            Step.PERMISSIONS -> PermissionsStep { step = Step.IMPORT }
            Step.IMPORT -> ImportStep(onFinish = viewModel::finish)
        }
    }
}

@Composable
private fun Title(text: String, subtitle: String) {
    Text(text, style = GeocentTheme.typography.largeTitle, color = GeocentTheme.colors.textPrimary)
    Spacer(Modifier.height(12.dp))
    Text(subtitle, style = GeocentTheme.typography.body, color = GeocentTheme.colors.textSecondary)
    Spacer(Modifier.height(28.dp))
}

@Composable
private fun androidx.compose.foundation.layout.ColumnScope.WelcomeStep(onNext: () -> Unit) {
    Spacer(Modifier.weight(1f))
    Title(
        "Geocent",
        "Turns your M-PESA and bank SMS into a map of where your money goes: " +
            "automatically, privately, on this phone.",
    )
    Spacer(Modifier.weight(1f))
    PrimaryButton("Get started", onNext)
}

private fun Context.granted(permission: String) =
    ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED

@Composable
private fun androidx.compose.foundation.layout.ColumnScope.PermissionsStep(onNext: () -> Unit) {
    val context = LocalContext.current
    // Bumped after each request/return to the app so the rows re-read permission state.
    var refresh by remember { mutableIntStateOf(0) }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { refresh++ }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
        refresh++
    }

    val sms = remember(refresh) {
        context.granted(Manifest.permission.RECEIVE_SMS) && context.granted(Manifest.permission.READ_SMS)
    }
    val location = remember(refresh) { context.granted(Manifest.permission.ACCESS_FINE_LOCATION) }
    val background = remember(refresh) { context.granted(Manifest.permission.ACCESS_BACKGROUND_LOCATION) }
    val notifications = remember(refresh) {
        Build.VERSION.SDK_INT < 33 || context.granted(Manifest.permission.POST_NOTIFICATIONS)
    }

    Title("Permissions", "Everything stays on your phone. Only SMS access is required.")
    Column(
        Modifier
            .weight(1f)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        PermissionRow("Read SMS", "Required. Finds M-PESA and bank messages.", sms) {
            launcher.launch(arrayOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.READ_SMS))
        }
        PermissionRow("Location", "Tags each purchase with where you were.", location) {
            launcher.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
        }
        if (location) {
            PermissionRow(
                "Location all the time",
                "Choose \"Allow all the time\" so purchases are tagged even when Geocent is closed.",
                background,
            ) { launcher.launch(arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION)) }
        }
        if (Build.VERSION.SDK_INT >= 33) {
            PermissionRow("Notifications", "New expenses and budget alerts.", notifications) {
                launcher.launch(arrayOf(Manifest.permission.POST_NOTIFICATIONS))
            }
        }
    }
    Spacer(Modifier.height(16.dp))
    PrimaryButton("Continue", onNext, enabled = sms)
}

@Composable
private fun PermissionRow(title: String, description: String, granted: Boolean, onAllow: () -> Unit) {
    SurfaceCard(Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(title, style = GeocentTheme.typography.headline, color = GeocentTheme.colors.textPrimary)
                Spacer(Modifier.height(4.dp))
                Text(description, style = GeocentTheme.typography.caption, color = GeocentTheme.colors.textSecondary)
            }
            Spacer(Modifier.width(12.dp))
            if (granted) {
                Text("Allowed", style = GeocentTheme.typography.caption, color = GeocentTheme.colors.dataPositive)
            } else {
                TextButton("Allow", onAllow)
            }
        }
    }
}

private data class RangeOption(val range: ImportRange, val title: String, val description: String)

private val rangeOptions = listOf(
    RangeOption(ImportRange.NONE, "Start clean", "Don't import anything. Only new SMS from now on."),
    RangeOption(ImportRange.LAST_7_DAYS, "Last 7 days", "A quick start with this week's spending."),
    RangeOption(ImportRange.LAST_30_DAYS, "Last 30 days", "Enough for monthly budgets and trends."),
    RangeOption(ImportRange.LAST_3_MONTHS, "Last 3 months", "More history for analytics."),
    RangeOption(ImportRange.EVERYTHING, "Everything", "Every M-PESA and bank SMS in your inbox."),
)

@Composable
private fun androidx.compose.foundation.layout.ColumnScope.ImportStep(onFinish: (ImportRange) -> Unit) {
    var selected by rememberSaveable { mutableStateOf(ImportRange.LAST_30_DAYS) }
    Title(
        "Import past messages?",
        "Imported messages have no location yet; you can place them on the map later. " +
            "You can change this in Profile.",
    )
    Column(
        Modifier
            .weight(1f)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        rangeOptions.forEach { option ->
            SurfaceCard(
                Modifier.fillMaxWidth(),
                selected = option.range == selected,
                onClick = { selected = option.range },
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    RadioDot(option.range == selected)
                    Spacer(Modifier.width(14.dp))
                    Column {
                        Text(option.title, style = GeocentTheme.typography.headline, color = GeocentTheme.colors.textPrimary)
                        Text(option.description, style = GeocentTheme.typography.caption, color = GeocentTheme.colors.textSecondary)
                    }
                }
            }
        }
    }
    Spacer(Modifier.height(16.dp))
    PrimaryButton(if (selected == ImportRange.NONE) "Start clean" else "Import and finish", { onFinish(selected) })
}

@Composable
private fun RadioDot(selected: Boolean) {
    val colors = GeocentTheme.colors
    androidx.compose.foundation.layout.Box(
        Modifier
            .size(22.dp)
            .clip(CircleShape)
            .border(2.dp, if (selected) colors.accent else colors.line, CircleShape)
            .padding(5.dp)
            .clip(CircleShape)
            .background(if (selected) colors.accent else colors.surface),
    )
}
