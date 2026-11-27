package app.geocent.ui.navigation

import androidx.annotation.DrawableRes
import androidx.annotation.StringRes
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.offset
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import app.geocent.R
import app.geocent.data.settings.SettingsStore
import app.geocent.data.TransactionRepository
import app.geocent.ui.location.LocationPickerScreen
import app.geocent.ui.location.PICK_LOCATION_IDS
import app.geocent.ui.messages.MessagesScreen
import app.geocent.ui.map.MapScreen
import app.geocent.ui.budgets.BudgetsScreen
import app.geocent.ui.analytics.AnalyticsScreen
import app.geocent.data.BudgetTracker
import kotlinx.coroutines.flow.map
import androidx.navigation.NavType
import androidx.navigation.navArgument
import app.geocent.ui.onboarding.OnboardingScreen
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject
import app.geocent.ui.theme.GeocentTheme

enum class Tab(
    val route: String,
    @StringRes val label: Int,
    @DrawableRes val icon: Int,
    @DrawableRes val activeIcon: Int = icon,
) {
    Map("map", R.string.tab_map, R.drawable.ic_tab_map, R.drawable.ic_tab_map_active),
    Messages("messages", R.string.tab_messages, R.drawable.ic_tab_messages, R.drawable.ic_tab_messages_active),
    Budgets("budgets", R.string.tab_budgets, R.drawable.ic_tab_budgets),
    Analytics("analytics", R.string.tab_analytics, R.drawable.ic_tab_analytics),
    Profile("profile", R.string.tab_profile, R.drawable.ic_tab_profile),
}

@HiltViewModel
class RootViewModel @Inject constructor(
    settings: SettingsStore,
    transactions: TransactionRepository,
    budgets: BudgetTracker,
) : ViewModel() {
    /** null while loading, so neither onboarding nor tabs flash on start. */
    val onboardingDone = settings.onboardingDone
        .stateIn(viewModelScope, SharingStarted.Eagerly, null)

    /** Messages still missing a location or category; shown as a badge on the Messages tab. */
    val actionableCount = transactions.observeActionableCount()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), 0)

    /** Budgets already over their limit this period; shown as a badge on the Budgets tab. */
    val exceededBudgets = budgets.observeProgress().map { list -> list.count { it.exceeded } }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), 0)
}

/** Full-screen destinations shown above the tab bar. */
private object Routes {
    const val TABS = "tabs"
    const val PICK_LOCATION = "pick-location/{$PICK_LOCATION_IDS}"
    fun pickLocation(ids: List<String>) = "pick-location/${ids.joinToString(",")}"
}

/** Shows onboarding on first run, then the tab shell. */
@Composable
fun GeocentRoot(viewModel: RootViewModel = hiltViewModel()) {
    val done by viewModel.onboardingDone.collectAsStateWithLifecycle()
    when (done) {
        null -> Box(Modifier.fillMaxSize().background(GeocentTheme.colors.background))
        false -> OnboardingScreen()
        true -> AppNavHost(viewModel)
    }
}

@Composable
private fun AppNavHost(viewModel: RootViewModel) {
    val rootNav = rememberNavController()
    NavHost(rootNav, startDestination = Routes.TABS) {
        composable(Routes.TABS) {
            TabShell(viewModel, onPickLocation = { ids -> rootNav.navigate(Routes.pickLocation(ids)) })
        }
        composable(
            Routes.PICK_LOCATION,
            arguments = listOf(navArgument(PICK_LOCATION_IDS) { type = NavType.StringType }),
        ) {
            LocationPickerScreen(onDone = { rootNav.popBackStack() })
        }
    }
}

/** Five tabs with an iOS-style bottom bar, as in the Flutter app. */
@Composable
private fun TabShell(viewModel: RootViewModel, onPickLocation: (List<String>) -> Unit) {
    val actionable by viewModel.actionableCount.collectAsStateWithLifecycle()
    val exceeded by viewModel.exceededBudgets.collectAsStateWithLifecycle()
    val navController = rememberNavController()
    val backStack by navController.currentBackStackEntryAsState()
    val currentRoute = backStack?.destination?.route ?: Tab.Map.route

    Column(
        Modifier
            .fillMaxSize()
            .background(GeocentTheme.colors.background),
    ) {
        NavHost(
            navController = navController,
            startDestination = Tab.Map.route,
            modifier = Modifier.weight(1f),
        ) {
            Tab.entries.forEach { tab ->
                composable(tab.route) {
                    when (tab) {
                        Tab.Map -> MapScreen(onPickLocation = onPickLocation)
                        Tab.Messages -> MessagesScreen(onPickLocation = onPickLocation)
                        Tab.Budgets -> BudgetsScreen()
                        Tab.Analytics -> AnalyticsScreen()
                        else -> PlaceholderScreen(stringResource(tab.label))
                    }
                }
            }
        }
        GeocentTabBar(
            current = currentRoute,
            badges = mapOf(Tab.Messages to actionable, Tab.Budgets to exceeded),
            onSelect = { tab ->
                navController.navigate(tab.route) {
                    popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                    launchSingleTop = true
                    restoreState = true
                }
            },
        )
    }
}

@Composable
private fun GeocentTabBar(current: String, badges: Map<Tab, Int>, onSelect: (Tab) -> Unit) {
    val colors = GeocentTheme.colors
    Column(
        Modifier
            .fillMaxWidth()
            .background(colors.surface)
            .windowInsetsPadding(WindowInsets.navigationBars),
    ) {
        HorizontalDivider(thickness = 1.dp, color = colors.line)
        Row(
            Modifier
                .fillMaxWidth()
                .height(56.dp),
            horizontalArrangement = Arrangement.SpaceAround,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Tab.entries.forEach { tab ->
                val selected = tab.route == current
                val tint = if (selected) colors.accent else colors.textSecondary
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier
                        .weight(1f)
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null,
                        ) { onSelect(tab) }
                        .padding(vertical = 6.dp),
                ) {
                    Box {
                        Icon(
                            painter = painterResource(if (selected) tab.activeIcon else tab.icon),
                            contentDescription = null,
                            tint = tint,
                            modifier = Modifier.size(25.dp),
                        )
                        val count = badges[tab] ?: 0
                        if (count > 0) Badge(count, Modifier.align(Alignment.TopEnd).offset(x = 10.dp, y = (-4).dp))
                    }
                    Spacer(Modifier.height(2.dp))
                    Text(
                        text = stringResource(tab.label),
                        style = GeocentTheme.typography.tabLabel,
                        color = tint,
                    )
                }
            }
        }
    }
}

@Composable
private fun Badge(count: Int, modifier: Modifier = Modifier) {
    Text(
        if (count > 99) "99+" else count.toString(),
        style = GeocentTheme.typography.tabLabel,
        color = androidx.compose.ui.graphics.Color.White,
        modifier = modifier
            .clip(androidx.compose.foundation.shape.RoundedCornerShape(10.dp))
            .background(GeocentTheme.colors.dataWarning)
            .padding(horizontal = 5.dp, vertical = 1.dp),
    )
}

/** Stand-in until each tab is ported in its own phase. */
@Composable
private fun PlaceholderScreen(title: String) {
    Box(
        Modifier
            .fillMaxSize()
            .background(GeocentTheme.colors.background),
        contentAlignment = Alignment.Center,
    ) {
        Text(title, style = GeocentTheme.typography.title, color = GeocentTheme.colors.textPrimary)
    }
}
