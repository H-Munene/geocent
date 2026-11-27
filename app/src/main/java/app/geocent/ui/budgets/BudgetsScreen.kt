package app.geocent.ui.budgets

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.input.InputTransformation
import androidx.compose.foundation.text.input.TextFieldLineLimits
import androidx.compose.foundation.text.input.rememberTextFieldState
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.geocent.data.BudgetProgress
import app.geocent.data.db.BudgetEntity
import app.geocent.data.db.CategoryEntity
import app.geocent.domain.model.BudgetPeriod
import app.geocent.notify.Notifier
import app.geocent.ui.components.CategoryAvatar
import app.geocent.ui.components.PrimaryButton
import app.geocent.ui.components.SurfaceCard
import app.geocent.ui.components.TextButton
import app.geocent.ui.components.rememberFullSheetState
import app.geocent.ui.theme.GeocentTheme
import app.geocent.ui.theme.HugeIcons

private val periodLabels = mapOf(
    BudgetPeriod.DAILY to "Daily",
    BudgetPeriod.WEEKLY to "Weekly",
    BudgetPeriod.MONTHLY to "Monthly",
)

private fun resetLabel(period: BudgetPeriod) = when (period) {
    BudgetPeriod.DAILY -> "Resets at midnight"
    BudgetPeriod.WEEKLY -> "Resets on Sunday"
    BudgetPeriod.MONTHLY -> "Resets on the 1st"
}

/** Editor target: a budget to change, or a new one (null budget). */
private data class Editing(val budget: BudgetEntity?)

/** Budgets tab: per-category spending limits by period, with live progress. */
@Composable
fun BudgetsScreen(viewModel: BudgetsViewModel = hiltViewModel()) {
    val colors = GeocentTheme.colors
    val progress by viewModel.progress.collectAsStateWithLifecycle()
    val categories by viewModel.categories.collectAsStateWithLifecycle()
    val period by viewModel.period.collectAsStateWithLifecycle()
    var editing by remember { mutableStateOf<Editing?>(null) }
    val categoriesByName = remember(categories) { categories.associateBy { it.name } }

    Column(
        Modifier
            .fillMaxSize()
            .background(colors.background)
            .windowInsetsPadding(WindowInsets.statusBars),
    ) {
        Row(Modifier.padding(start = 20.dp, end = 16.dp, top = 16.dp, bottom = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("Budgets", style = GeocentTheme.typography.largeTitle, color = colors.textPrimary, modifier = Modifier.weight(1f))
            Box(
                Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(colors.accent)
                    .clickable { editing = Editing(null) },
                contentAlignment = Alignment.Center,
            ) {
                Icon(painterResource(HugeIcons.add01), "Add budget", tint = Color.White, modifier = Modifier.size(22.dp))
            }
        }

        val all = progress.orEmpty()
        PeriodSegments(
            selected = period,
            exceeded = all.filter { it.exceeded }.map { it.budget.period }.toSet(),
            onSelect = viewModel::setPeriod,
            modifier = Modifier.padding(horizontal = 16.dp),
        )

        val shown = all.filter { it.budget.period == period }.sortedByDescending { it.fraction }
        if (progress != null && shown.isEmpty()) {
            Column(
                Modifier.fillMaxSize().padding(32.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Text("No ${periodLabels.getValue(period).lowercase()} budgets", style = GeocentTheme.typography.title, color = colors.textPrimary)
                Spacer(Modifier.height(6.dp))
                Text(
                    "Set a spending limit for a category and Geocent will warn you at 50%, 80% and 100%.",
                    style = GeocentTheme.typography.body, color = colors.textSecondary, textAlign = TextAlign.Center,
                )
                Spacer(Modifier.height(20.dp))
                TextButton("Add a budget", { editing = Editing(null) })
            }
        } else {
            LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                items(shown, key = { it.budget.id }) { p ->
                    BudgetCard(p, categoriesByName[p.budget.categoryName]) { editing = Editing(p.budget) }
                }
            }
        }
    }

    editing?.let { target ->
        BudgetSheet(
            budget = target.budget,
            initialPeriod = period,
            categories = categories,
            budgeted = progress.orEmpty().map { it.budget.categoryName }.toSet(),
            onSave = { category, limit, p -> viewModel.save(category, limit, p); editing = null },
            onDelete = { id -> viewModel.delete(id); editing = null },
            onDismiss = { editing = null },
        )
    }
}

@Composable
private fun PeriodSegments(
    selected: BudgetPeriod,
    onSelect: (BudgetPeriod) -> Unit,
    modifier: Modifier = Modifier,
    exceeded: Set<BudgetPeriod> = emptySet(),
) {
    val colors = GeocentTheme.colors
    Row(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(colors.line)
            .padding(3.dp),
    ) {
        BudgetPeriod.entries.forEach { p ->
            val isSelected = p == selected
            Row(
                Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(10.dp))
                    .background(if (isSelected) colors.surface else Color.Transparent)
                    .clickable { onSelect(p) }
                    .padding(vertical = 8.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    periodLabels.getValue(p),
                    style = GeocentTheme.typography.caption.copy(fontWeight = FontWeight.SemiBold),
                    color = if (isSelected) colors.textPrimary else colors.textSecondary,
                )
                if (p in exceeded) {
                    Spacer(Modifier.width(5.dp))
                    Box(Modifier.size(7.dp).clip(CircleShape).background(colors.dataWarning))
                }
            }
        }
    }
}

@Composable
private fun BudgetCard(progress: BudgetProgress, category: CategoryEntity?, onClick: () -> Unit) {
    val colors = GeocentTheme.colors
    val barColor = when (progress.level) {
        BudgetProgress.Level.LOW -> colors.dataPositive
        BudgetProgress.Level.MEDIUM -> Color(0xFFFF9500)
        BudgetProgress.Level.HIGH -> colors.dataWarning
    }
    SurfaceCard(Modifier.fillMaxWidth(), onClick = onClick) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            CategoryAvatar(category, progress.budget.categoryName)
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(progress.budget.categoryName, style = GeocentTheme.typography.headline, color = colors.textPrimary)
                Text(resetLabel(progress.budget.period), style = GeocentTheme.typography.caption, color = colors.textSecondary)
            }
            Column(horizontalAlignment = Alignment.End) {
                Text(Notifier.formatKes(progress.spent), style = GeocentTheme.typography.amount, color = colors.textPrimary)
                Text("of ${Notifier.formatKes(progress.budget.amountLimit)}", style = GeocentTheme.typography.amountSmall, color = colors.textSecondary)
            }
        }
        Spacer(Modifier.height(12.dp))
        Box(
            Modifier
                .fillMaxWidth()
                .height(8.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(colors.line),
        ) {
            Box(
                Modifier
                    .fillMaxWidth(progress.fraction.coerceIn(0.0, 1.0).toFloat())
                    .height(8.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(barColor),
            )
        }
        Spacer(Modifier.height(8.dp))
        Text(
            if (progress.exceeded) "${Notifier.formatKes(-progress.remaining)} over budget"
            else "${Notifier.formatKes(progress.remaining)} left · ${(progress.fraction * 100).toInt()}% used",
            style = GeocentTheme.typography.caption,
            color = if (progress.exceeded) colors.dataWarning else colors.textSecondary,
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun BudgetSheet(
    budget: BudgetEntity?,
    initialPeriod: BudgetPeriod,
    categories: List<CategoryEntity>,
    budgeted: Set<String>,
    onSave: (category: String, limit: Double, period: BudgetPeriod) -> Unit,
    onDelete: (id: String) -> Unit,
    onDismiss: () -> Unit,
) {
    val colors = GeocentTheme.colors
    // A category can hold one budget; new budgets offer only free categories.
    val choices = if (budget != null) categories.filter { it.name == budget.categoryName }
    else categories.filter { it.name !in budgeted }
    var category by remember { mutableStateOf(budget?.categoryName ?: choices.firstOrNull()?.name) }
    var period by remember { mutableStateOf(budget?.period ?: initialPeriod) }
    val amount = rememberTextFieldState(budget?.amountLimit?.toLong()?.toString().orEmpty())
    val limit = amount.text.toString().toDoubleOrNull()
    val changed = budget == null || limit != budget.amountLimit || period != budget.period
    val valid = category != null && limit != null && limit > 0 && changed

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = rememberFullSheetState(), containerColor = colors.surface) {
        Column(Modifier.navigationBarsPadding().padding(horizontal = 20.dp).padding(bottom = 20.dp)) {
            Text(if (budget == null) "New budget" else "Edit budget", style = GeocentTheme.typography.title, color = colors.textPrimary)
            Spacer(Modifier.height(16.dp))

            Label("Category")
            if (choices.isEmpty()) {
                Text("Every category already has a budget.", style = GeocentTheme.typography.body, color = colors.textSecondary)
            } else {
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    choices.forEach { c ->
                        val selected = c.name == category
                        Row(
                            Modifier
                                .clip(RoundedCornerShape(20.dp))
                                .border(if (selected) 2.dp else 1.dp, if (selected) colors.accent else colors.line, RoundedCornerShape(20.dp))
                                .clickable(enabled = budget == null) { category = c.name }
                                .padding(start = 4.dp, end = 12.dp, top = 4.dp, bottom = 4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            CategoryAvatar(c, c.name, size = 28.dp)
                            Spacer(Modifier.width(6.dp))
                            Text(c.name, style = GeocentTheme.typography.caption, color = colors.textPrimary)
                        }
                    }
                }
            }
            Spacer(Modifier.height(20.dp))

            Label("Limit")
            BasicTextField(
                state = amount,
                lineLimits = TextFieldLineLimits.SingleLine,
                inputTransformation = InputTransformation { if (!asCharSequence().all(Char::isDigit) || length > 9) revertAllChanges() },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                textStyle = GeocentTheme.typography.amountLarge.copy(color = colors.textPrimary),
                cursorBrush = SolidColor(colors.accent),
                decorator = { inner ->
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .background(colors.background)
                            .padding(horizontal = 14.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text("KES ", style = GeocentTheme.typography.amountLarge, color = colors.textSecondary)
                        Box(Modifier.weight(1f)) {
                            if (amount.text.isEmpty()) Text("0", style = GeocentTheme.typography.amountLarge, color = colors.line)
                            inner()
                        }
                    }
                },
            )
            Spacer(Modifier.height(20.dp))

            Label("Period")
            PeriodSegments(period, onSelect = { period = it })
            Spacer(Modifier.height(24.dp))

            PrimaryButton(
                if (budget == null) "Add budget" else "Save changes",
                onClick = { onSave(category!!, limit!!, period) },
                enabled = valid,
            )
            if (budget != null) {
                Spacer(Modifier.height(8.dp))
                Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    TextButton("Delete budget", { onDelete(budget.id) })
                }
            }
        }
    }
}

@Composable
private fun Label(text: String) {
    Text(text.uppercase(), style = GeocentTheme.typography.tabLabel, color = GeocentTheme.colors.textSecondary)
    Spacer(Modifier.height(8.dp))
}
