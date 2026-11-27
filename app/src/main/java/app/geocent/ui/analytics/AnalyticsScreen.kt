package app.geocent.ui.analytics

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.geocent.data.db.CategoryEntity
import app.geocent.data.db.TransactionEntity
import app.geocent.domain.Breakdown
import app.geocent.domain.CategoryCatalog
import app.geocent.domain.NO_CATEGORY
import app.geocent.notify.Notifier
import app.geocent.ui.components.CategoryAvatar
import app.geocent.ui.components.SurfaceCard
import app.geocent.ui.components.color
import app.geocent.ui.components.rememberFullSheetState
import app.geocent.ui.theme.GeocentTheme
import java.time.Instant
import java.time.YearMonth
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlin.math.abs
import kotlin.math.roundToInt

private val monthFormat = DateTimeFormatter.ofPattern("MMM yyyy")
private val timeFormat = DateTimeFormatter.ofPattern("d MMM, HH:mm")

/** Analytics tab: spending over a range, how it's split, and quick insights. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AnalyticsScreen(viewModel: AnalyticsViewModel = hiltViewModel()) {
    val colors = GeocentTheme.colors
    val state by viewModel.state.collectAsStateWithLifecycle()
    val insights by viewModel.insights.collectAsStateWithLifecycle()
    val categories by viewModel.categories.collectAsStateWithLifecycle()
    val chart by viewModel.chart.collectAsStateWithLifecycle()
    val choice by viewModel.choice.collectAsStateWithLifecycle()
    val history by viewModel.history.collectAsStateWithLifecycle()

    var showRanges by remember { mutableStateOf(false) }
    var byRecipient by rememberSaveable { mutableStateOf(false) }
    var drillDown by remember { mutableStateOf<Pair<String, List<TransactionEntity>>?>(null) }

    val colorFor: (String?) -> Color = { name ->
        name?.let(categories::get)?.color() ?: Color(CategoryCatalog.FALLBACK_COLOR.toInt())
    }

    LazyColumn(
        Modifier
            .fillMaxSize()
            .background(colors.background)
            .windowInsetsPadding(WindowInsets.statusBars),
        contentPadding = PaddingValues(bottom = 24.dp),
    ) {
        item {
            Row(Modifier.padding(start = 20.dp, end = 16.dp, top = 16.dp, bottom = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("Analytics", style = GeocentTheme.typography.largeTitle, color = colors.textPrimary, modifier = Modifier.weight(1f))
                Text(
                    (state?.range?.label ?: "This week") + " ▾",
                    style = GeocentTheme.typography.caption.copy(fontWeight = FontWeight.SemiBold),
                    color = colors.accent,
                    modifier = Modifier
                        .clip(RoundedCornerShape(16.dp))
                        .background(colors.accent.copy(alpha = 0.1f))
                        .clickable { showRanges = true }
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                )
            }
        }

        if (insights.isNotEmpty()) {
            item {
                LazyRow(contentPadding = PaddingValues(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    items(insights) { InsightCard(it) }
                }
                Spacer(Modifier.height(16.dp))
            }
        }

        val s = state ?: return@LazyColumn
        item {
            SurfaceCard(Modifier.padding(horizontal = 16.dp).fillMaxWidth()) {
                Text("Spent · ${s.range.label.lowercase()}", style = GeocentTheme.typography.caption, color = colors.textSecondary)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(Notifier.formatKes(s.result.total), style = GeocentTheme.typography.amountLarge, color = colors.textPrimary, modifier = Modifier.weight(1f))
                    s.result.trend?.let { TrendPill(it) }
                }
                Spacer(Modifier.height(12.dp))
                ChartTypeSegments(chart, viewModel::setChart)
                Spacer(Modifier.height(16.dp))
                when (chart) {
                    ChartType.BARS -> StackedBarChart(s.result.buckets, colorFor)
                    ChartType.LINE -> SpendLineChart(s.result.buckets)
                    ChartType.DONUT -> DonutChart(s.result.categories, s.result.total, { colorFor(it.takeIf { n -> n != NO_CATEGORY }) })
                }
                if (s.result.categories.isNotEmpty()) {
                    Spacer(Modifier.height(14.dp))
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        s.result.categories.take(6).forEach { c ->
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Box(Modifier.size(9.dp).clip(CircleShape).background(colorFor(c.name.takeIf { it != NO_CATEGORY })))
                                Spacer(Modifier.width(5.dp))
                                Text("${c.name} ${(c.share * 100).roundToInt()}%", style = GeocentTheme.typography.caption, color = colors.textSecondary)
                            }
                        }
                    }
                }
            }
            Spacer(Modifier.height(20.dp))
            Row(
                Modifier
                    .padding(horizontal = 16.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(colors.line)
                    .padding(3.dp),
            ) {
                listOf(false to "Categories", true to "Recipients").forEach { (value, label) ->
                    Segment(label, selected = byRecipient == value, modifier = Modifier.weight(1f)) { byRecipient = value }
                }
            }
            Spacer(Modifier.height(8.dp))
        }

        val rows = if (byRecipient) s.result.recipients else s.result.categories
        if (rows.isEmpty()) {
            item {
                Text(
                    "No spending in this period.",
                    style = GeocentTheme.typography.body,
                    color = colors.textSecondary,
                    modifier = Modifier.padding(24.dp),
                )
            }
        }
        items(rows, key = { (if (byRecipient) "r:" else "c:") + it.name }) { row ->
            BreakdownRow(
                row = row,
                category = if (byRecipient) null else categories[row.name],
                showAvatar = !byRecipient,
                barColor = if (byRecipient) colors.accent else colorFor(row.name.takeIf { it != NO_CATEGORY }),
            ) {
                val txs = s.transactions.filter { tx ->
                    if (byRecipient) tx.merchant == row.name else (tx.category ?: NO_CATEGORY) == row.name
                }
                drillDown = row.name to txs
            }
        }
    }

    if (showRanges) {
        ModalBottomSheet(onDismissRequest = { showRanges = false }, sheetState = rememberFullSheetState(), containerColor = colors.surface) {
            RangeSheet(choice, history) { viewModel.choose(it); showRanges = false }
        }
    }

    drillDown?.let { (name, txs) ->
        ModalBottomSheet(onDismissRequest = { drillDown = null }, sheetState = rememberFullSheetState(), containerColor = colors.surface) {
            Column(Modifier.navigationBarsPadding()) {
                Text(name, style = GeocentTheme.typography.title, color = colors.textPrimary, modifier = Modifier.padding(horizontal = 20.dp))
                Spacer(Modifier.height(8.dp))
                LazyColumn(Modifier.heightIn(max = 520.dp)) {
                    items(txs, key = { it.id }) { tx ->
                        Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                            CategoryAvatar(tx.category?.let(categories::get), tx.merchant, size = 36.dp)
                            Spacer(Modifier.width(12.dp))
                            Column(Modifier.weight(1f)) {
                                Text(tx.merchant, style = GeocentTheme.typography.headline, color = colors.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                Text(
                                    Instant.ofEpochMilli(tx.timestamp).atZone(ZoneId.systemDefault()).format(timeFormat),
                                    style = GeocentTheme.typography.caption, color = colors.textSecondary,
                                )
                            }
                            Text(Notifier.formatKes(tx.amount), style = GeocentTheme.typography.amount, color = colors.textPrimary)
                        }
                    }
                }
                Spacer(Modifier.height(12.dp))
            }
        }
    }
}

@Composable
private fun InsightCard(insight: Insight) {
    val colors = GeocentTheme.colors
    SurfaceCard(Modifier.width(170.dp)) {
        Text(insight.label.uppercase(), style = GeocentTheme.typography.tabLabel, color = colors.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Spacer(Modifier.height(6.dp))
        Text(
            insight.value,
            style = GeocentTheme.typography.headline,
            color = if (insight.warning) colors.dataWarning else colors.textPrimary,
            maxLines = 1, overflow = TextOverflow.Ellipsis,
        )
        Text(insight.detail, style = GeocentTheme.typography.amountSmall, color = colors.textSecondary, maxLines = 1)
    }
}

/** Up is more spending (warning colour); down is less (positive colour). */
@Composable
private fun TrendPill(trend: Double) {
    val colors = GeocentTheme.colors
    val up = trend > 0
    val tint = if (up) colors.dataWarning else colors.dataPositive
    Text(
        "${if (up) "▲" else "▼"} ${(abs(trend) * 100).roundToInt()}%",
        style = GeocentTheme.typography.amountSmall,
        color = tint,
        modifier = Modifier
            .clip(RoundedCornerShape(10.dp))
            .background(tint.copy(alpha = 0.12f))
            .padding(horizontal = 8.dp, vertical = 4.dp),
    )
}

@Composable
private fun ChartTypeSegments(selected: ChartType, onSelect: (ChartType) -> Unit) {
    val colors = GeocentTheme.colors
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(colors.background)
            .padding(3.dp),
    ) {
        ChartType.entries.forEach { type ->
            Segment(type.label, selected = type == selected, modifier = Modifier.weight(1f)) { onSelect(type) }
        }
    }
}

@Composable
private fun Segment(label: String, selected: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val colors = GeocentTheme.colors
    Box(
        modifier
            .clip(RoundedCornerShape(8.dp))
            .background(if (selected) colors.surface else Color.Transparent)
            .clickable(onClick = onClick)
            .padding(vertical = 7.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            label,
            style = GeocentTheme.typography.caption.copy(fontWeight = FontWeight.SemiBold),
            color = if (selected) colors.textPrimary else colors.textSecondary,
        )
    }
}

@Composable
private fun BreakdownRow(row: Breakdown, category: CategoryEntity?, showAvatar: Boolean, barColor: Color, onClick: () -> Unit) {
    val colors = GeocentTheme.colors
    Row(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 20.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (showAvatar) {
            CategoryAvatar(category, row.name, size = 36.dp)
            Spacer(Modifier.width(12.dp))
        }
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(row.name, style = GeocentTheme.typography.headline, color = colors.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                Spacer(Modifier.width(8.dp))
                Text(Notifier.formatKes(row.total), style = GeocentTheme.typography.amount, color = colors.textPrimary)
            }
            Spacer(Modifier.height(4.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.weight(1f).height(5.dp).clip(RoundedCornerShape(3.dp)).background(colors.line)) {
                    Box(Modifier.fillMaxWidth(row.share.toFloat().coerceIn(0f, 1f)).height(5.dp).clip(RoundedCornerShape(3.dp)).background(barColor))
                }
                Spacer(Modifier.width(10.dp))
                Text(
                    "${row.count} payment${if (row.count == 1) "" else "s"} · ${(row.share * 100).roundToInt()}%",
                    style = GeocentTheme.typography.amountSmall, color = colors.textSecondary,
                )
            }
        }
    }
}

@Composable
private fun RangeSheet(
    current: RangeChoice,
    history: Pair<List<YearMonth>, List<java.time.Year>>,
    onChoose: (RangeChoice) -> Unit,
) {
    val colors = GeocentTheme.colors
    Column(Modifier.navigationBarsPadding().padding(horizontal = 20.dp).padding(bottom = 20.dp)) {
        Text("Show spending for", style = GeocentTheme.typography.title, color = colors.textPrimary)
        Spacer(Modifier.height(12.dp))
        listOf(
            RangeChoice.ThisWeek to "This week",
            RangeChoice.ThisMonth to "This month",
            RangeChoice.ThisYear to "This year",
        ).forEach { (value, label) ->
            Text(
                label,
                style = GeocentTheme.typography.body.copy(fontWeight = if (value == current) FontWeight.SemiBold else FontWeight.Normal),
                color = if (value == current) colors.accent else colors.textPrimary,
                modifier = Modifier.fillMaxWidth().clickable { onChoose(value) }.padding(vertical = 12.dp),
            )
        }
        val (months, years) = history
        if (months.isNotEmpty()) {
            Spacer(Modifier.height(8.dp))
            Text("MONTH", style = GeocentTheme.typography.tabLabel, color = colors.textSecondary)
            Spacer(Modifier.height(8.dp))
            ChoiceChips(months.take(12).map { RangeChoice.Month(it) to it.format(monthFormat) }, current, onChoose)
        }
        if (years.size > 1) {
            Spacer(Modifier.height(12.dp))
            Text("YEAR", style = GeocentTheme.typography.tabLabel, color = colors.textSecondary)
            Spacer(Modifier.height(8.dp))
            ChoiceChips(years.map { RangeChoice.YearOf(it) to it.toString() }, current, onChoose)
        }
    }
}

@Composable
private fun ChoiceChips(options: List<Pair<RangeChoice, String>>, current: RangeChoice, onChoose: (RangeChoice) -> Unit) {
    val colors = GeocentTheme.colors
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        options.forEach { (value, label) ->
            val selected = value == current
            Text(
                label,
                style = GeocentTheme.typography.caption.copy(fontWeight = FontWeight.SemiBold),
                color = if (selected) Color.White else colors.textPrimary,
                modifier = Modifier
                    .clip(RoundedCornerShape(16.dp))
                    .background(if (selected) colors.accent else colors.background)
                    .clickable { onChoose(value) }
                    .padding(horizontal = 12.dp, vertical = 7.dp),
            )
        }
    }
}
