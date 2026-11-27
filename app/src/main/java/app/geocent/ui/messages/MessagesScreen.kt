package app.geocent.ui.messages

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
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
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.input.clearText
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.geocent.data.MessageAge
import app.geocent.data.MessageFilter
import app.geocent.data.db.CategoryEntity
import app.geocent.data.db.TransactionEntity
import app.geocent.notify.Notifier
import app.geocent.ui.components.CategoryAvatar
import app.geocent.ui.components.CategorySheet
import app.geocent.ui.components.TextButton
import app.geocent.ui.components.ToastHost
import app.geocent.ui.theme.GeocentTheme
import app.geocent.ui.theme.HugeIcons
import com.airbnb.lottie.compose.LottieAnimation
import com.airbnb.lottie.compose.LottieCompositionSpec
import com.airbnb.lottie.compose.rememberLottieComposition
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private val filterLabels = listOf(
    MessageFilter.NEEDS_ACTION to "To do",
    MessageFilter.NEEDS_LOCATION to "Needs location",
    MessageFilter.NEEDS_CATEGORY to "Needs category",
    MessageFilter.ALL to "All",
)

private val ageLabels = listOf(
    MessageAge.ANY to "All time",
    MessageAge.TODAY to "Today",
    MessageAge.YESTERDAY to "Yesterday",
    MessageAge.LAST_3_DAYS to "Last 3 days",
    MessageAge.LAST_7_DAYS to "Last 7 days",
    MessageAge.OLDER_THAN_7_DAYS to "Older than a week",
)

/**
 * Messages tab: triage parsed SMS. Tap a message to place it on the map or
 * categorise it; long-press to select several and map, categorise or forget
 * them together.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MessagesScreen(
    onPickLocation: (ids: List<String>) -> Unit,
    viewModel: MessagesViewModel = hiltViewModel(),
) {
    val colors = GeocentTheme.colors
    val messages by viewModel.messages.collectAsStateWithLifecycle()
    val categories by viewModel.categories.collectAsStateWithLifecycle()
    val filter by viewModel.filter.collectAsStateWithLifecycle()
    val age by viewModel.age.collectAsStateWithLifecycle()
    val search by viewModel.search.collectAsStateWithLifecycle()
    val selection by viewModel.selection.collectAsStateWithLifecycle()
    val selecting = selection.isNotEmpty()
    val categoriesByName = remember(categories) { categories.associateBy { it.name } }

    var categorizeIds by remember { mutableStateOf<List<String>?>(null) }
    var showAgeSheet by remember { mutableStateOf(false) }
    var confirmForget by remember { mutableStateOf(false) }

    Box(
        Modifier
            .fillMaxSize()
            .background(colors.background),
    ) {
        Column(Modifier.windowInsetsPadding(WindowInsets.statusBars)) {
            Header(
                selecting = selecting,
                selectedCount = selection.size,
                onCancel = viewModel::clearSelection,
                onSelectAll = { messages?.let { list -> viewModel.select(list.map { it.id }) } },
            )
            SearchField(search, viewModel::setSearch)
            FilterRow(
                filter = filter,
                ageLabel = ageLabels.first { it.first == age }.second,
                onFilter = viewModel::setFilter,
                onAge = { showAgeSheet = true },
            )
            val list = messages
            when {
                list == null -> Unit
                list.isEmpty() -> EmptyState(searching = search.isNotBlank() || age != MessageAge.ANY, filter = filter)
                else -> MessageList(
                    messages = list,
                    categoriesByName = categoriesByName,
                    search = search,
                    selection = selection,
                    bottomPadding = if (selecting) 88.dp else 16.dp,
                    onLoadMore = { viewModel.loadMore(list.size) },
                    onClick = { tx ->
                        when {
                            selecting -> viewModel.toggle(tx.id)
                            !tx.hasLocation -> onPickLocation(listOf(tx.id))
                            else -> categorizeIds = listOf(tx.id)
                        }
                    },
                    onLongClick = { tx -> viewModel.toggle(tx.id) },
                    onToggleDay = { ids, allSelected ->
                        if (allSelected) viewModel.deselect(ids) else viewModel.select(ids)
                    },
                )
            }
        }

        AnimatedVisibility(
            visible = selecting,
            enter = slideInVertically { it },
            exit = slideOutVertically { it },
            modifier = Modifier.align(Alignment.BottomCenter),
        ) {
            SelectionBar(
                onMap = { onPickLocation(selection.toList()); viewModel.clearSelection() },
                onCategorize = { categorizeIds = selection.toList() },
                onForget = { confirmForget = true },
            )
        }

        ToastHost(viewModel.toasts, Modifier.windowInsetsPadding(WindowInsets.statusBars))
    }

    categorizeIds?.let { ids ->
        val current = if (ids.size == 1) messages?.firstOrNull { it.id == ids[0] }?.category else null
        CategorySheet(
            title = if (ids.size == 1) "Choose a category" else "Categorise ${ids.size} messages",
            categories = categories,
            current = current,
            onSelect = { name ->
                viewModel.categorize(ids, name)
                categorizeIds = null
            },
            onCreate = { name, icon, color ->
                viewModel.createCategory(name, icon, color, assignTo = ids)
                categorizeIds = null
            },
            onDismiss = { categorizeIds = null },
        )
    }

    if (showAgeSheet) {
        ModalBottomSheet(
            onDismissRequest = { showAgeSheet = false },
            sheetState = app.geocent.ui.components.rememberFullSheetState(),
            containerColor = colors.surface,
        ) {
            Column(Modifier.navigationBarsPadding().padding(bottom = 16.dp)) {
                Text(
                    "Show messages from",
                    style = GeocentTheme.typography.title,
                    color = colors.textPrimary,
                    modifier = Modifier.padding(start = 20.dp, bottom = 8.dp),
                )
                ageLabels.forEach { (value, label) ->
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .combinedClickable(onClick = { viewModel.setAge(value); showAgeSheet = false })
                            .padding(horizontal = 20.dp, vertical = 14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(label, style = GeocentTheme.typography.body, color = colors.textPrimary, modifier = Modifier.weight(1f))
                        if (value == age) Icon(painterResource(HugeIcons.tick02), null, tint = colors.accent)
                    }
                }
            }
        }
    }

    if (confirmForget) {
        val count = selection.size
        AlertDialog(
            onDismissRequest = { confirmForget = false },
            containerColor = colors.surface,
            title = { Text("Forget $count message${if (count == 1) "" else "s"}?", style = GeocentTheme.typography.title, color = colors.textPrimary) },
            text = {
                Text(
                    "Geocent will drop them and never import them again. They stay in your SMS app.",
                    style = GeocentTheme.typography.body,
                    color = colors.textSecondary,
                )
            },
            confirmButton = {
                TextButton("Forget", { viewModel.forget(selection.toList()); confirmForget = false })
            },
            dismissButton = { TextButton("Cancel", { confirmForget = false }) },
        )
    }
}

@Composable
private fun Header(selecting: Boolean, selectedCount: Int, onCancel: () -> Unit, onSelectAll: () -> Unit) {
    val colors = GeocentTheme.colors
    if (!selecting) {
        Text(
            "Messages",
            style = GeocentTheme.typography.largeTitle,
            color = colors.textPrimary,
            modifier = Modifier.padding(start = 20.dp, top = 16.dp, bottom = 12.dp),
        )
    } else {
        Row(
            Modifier
                .fillMaxWidth()
                .height(68.dp)
                .padding(horizontal = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            TextButton("Cancel", onCancel)
            Text(
                "$selectedCount selected",
                style = GeocentTheme.typography.headline,
                color = colors.textPrimary,
                textAlign = TextAlign.Center,
                modifier = Modifier.weight(1f),
            )
            TextButton("Select all", onSelectAll)
        }
    }
}

@Composable
private fun SearchField(initial: String, onChange: (String) -> Unit) {
    val colors = GeocentTheme.colors
    val state = androidx.compose.foundation.text.input.rememberTextFieldState(initial)
    LaunchedEffect(state) {
        androidx.compose.runtime.snapshotFlow { state.text.toString() }.collect(onChange)
    }
    val value = state.text
    BasicTextField(
        state = state,
        lineLimits = androidx.compose.foundation.text.input.TextFieldLineLimits.SingleLine,
        textStyle = GeocentTheme.typography.body.copy(color = colors.textPrimary),
        cursorBrush = SolidColor(colors.accent),
        modifier = Modifier.padding(horizontal = 16.dp),
        decorator = { inner ->
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(colors.line.copy(alpha = if (colors.isDark) 1f else 0.8f))
                    .padding(horizontal = 12.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(painterResource(HugeIcons.search01), null, tint = colors.textSecondary, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Box(Modifier.weight(1f)) {
                    if (value.isEmpty()) Text("Search messages", style = GeocentTheme.typography.body, color = colors.textSecondary)
                    inner()
                }
                if (value.isNotEmpty()) {
                    Icon(
                        painterResource(HugeIcons.cancel01), "Clear search", tint = colors.textSecondary,
                        modifier = Modifier
                            .size(18.dp)
                            .clip(CircleShape)
                            .combinedClickable(onClick = { state.clearText() }),
                    )
                }
            }
        },
    )
}

@Composable
private fun FilterRow(filter: MessageFilter, ageLabel: String, onFilter: (MessageFilter) -> Unit, onAge: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        filterLabels.forEach { (value, label) -> Chip(label, selected = value == filter) { onFilter(value) } }
        Chip("$ageLabel ▾", selected = false, onClick = onAge)
    }
}

@Composable
private fun Chip(label: String, selected: Boolean, onClick: () -> Unit) {
    val colors = GeocentTheme.colors
    Text(
        label,
        style = GeocentTheme.typography.caption.copy(fontWeight = FontWeight.SemiBold),
        color = if (selected) androidx.compose.ui.graphics.Color.White else colors.textPrimary,
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(if (selected) colors.accent else colors.surface)
            .border(1.dp, if (selected) colors.accent else colors.line, RoundedCornerShape(20.dp))
            .combinedClickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 8.dp),
    )
}

private val dayFormat = DateTimeFormatter.ofPattern("EEE, d MMM")
private val timeFormat = DateTimeFormatter.ofPattern("HH:mm")

private fun dayLabel(day: LocalDate, today: LocalDate): String = when (day) {
    today -> "Today"
    today.minusDays(1) -> "Yesterday"
    else -> day.format(dayFormat)
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun MessageList(
    messages: List<TransactionEntity>,
    categoriesByName: Map<String, CategoryEntity>,
    search: String,
    selection: Set<String>,
    bottomPadding: androidx.compose.ui.unit.Dp,
    onLoadMore: () -> Unit,
    onClick: (TransactionEntity) -> Unit,
    onLongClick: (TransactionEntity) -> Unit,
    onToggleDay: (ids: List<String>, allSelected: Boolean) -> Unit,
) {
    val zone = remember { ZoneId.systemDefault() }
    val today = remember { LocalDate.now(zone) }
    val byDay = remember(messages) {
        messages.groupBy { Instant.ofEpochMilli(it.timestamp).atZone(zone).toLocalDate() }
    }
    val state = rememberLazyListState()
    val nearEnd by remember {
        derivedStateOf {
            val last = state.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            last >= state.layoutInfo.totalItemsCount - 6
        }
    }
    LaunchedEffect(nearEnd, messages.size) { if (nearEnd) onLoadMore() }

    LazyColumn(state = state, contentPadding = PaddingValues(bottom = bottomPadding)) {
        byDay.forEach { (day, txs) ->
            stickyHeader(key = "day-$day") {
                val ids = txs.map { it.id }
                val allSelected = ids.all { it in selection }
                DayHeader(
                    label = dayLabel(day, today),
                    selecting = selection.isNotEmpty(),
                    allSelected = allSelected,
                    onToggle = { onToggleDay(ids, allSelected) },
                )
            }
            items(txs, key = { it.id }) { tx ->
                MessageTile(
                    tx = tx,
                    category = tx.category?.let(categoriesByName::get),
                    search = search,
                    selecting = selection.isNotEmpty(),
                    selected = tx.id in selection,
                    onClick = { onClick(tx) },
                    onLongClick = { onLongClick(tx) },
                )
            }
        }
    }
}

@Composable
private fun DayHeader(label: String, selecting: Boolean, allSelected: Boolean, onToggle: () -> Unit) {
    val colors = GeocentTheme.colors
    Row(
        Modifier
            .fillMaxWidth()
            .background(colors.background)
            .height(44.dp) // fixed so the list doesn't jump when "Select all" appears
            .padding(start = 20.dp, end = 8.dp, top = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label.uppercase(), style = GeocentTheme.typography.caption, color = colors.textSecondary, modifier = Modifier.weight(1f))
        if (selecting) TextButton(if (allSelected) "Unselect all" else "Select all", onToggle)
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun MessageTile(
    tx: TransactionEntity,
    category: CategoryEntity?,
    search: String,
    selecting: Boolean,
    selected: Boolean,
    onClick: () -> Unit,
    onLongClick: () -> Unit,
) {
    val colors = GeocentTheme.colors
    val haptics = LocalHapticFeedback.current
    Column(
        Modifier
            .fillMaxWidth()
            .background(if (selected) colors.accent.copy(alpha = 0.08f) else colors.surface)
            .combinedClickable(
                onClick = onClick,
                onLongClick = {
                    haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                    onLongClick()
                },
            ),
    ) {
        Row(Modifier.padding(horizontal = 16.dp, vertical = 12.dp), verticalAlignment = Alignment.Top) {
            if (selecting) {
                SelectionDot(selected)
                Spacer(Modifier.width(12.dp))
            }
            CategoryAvatar(category, tx.merchant)
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        tx.merchant,
                        style = GeocentTheme.typography.headline,
                        color = colors.textPrimary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f),
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(formatAmount(tx), style = GeocentTheme.typography.amount, color = colors.textPrimary)
                }
                Spacer(Modifier.height(4.dp))
                Text(
                    highlight(tx.rawMessage, search, colors.accent),
                    style = GeocentTheme.typography.caption,
                    color = colors.textSecondary,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(Modifier.height(8.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    StatusChip(tx, category)
                    Spacer(Modifier.weight(1f))
                    val time = Instant.ofEpochMilli(tx.timestamp).atZone(ZoneId.systemDefault()).format(timeFormat)
                    Text(time, style = GeocentTheme.typography.amountSmall, color = colors.textSecondary)
                }
            }
        }
        HorizontalDivider(thickness = 0.5.dp, color = colors.line, modifier = Modifier.padding(start = 68.dp))
    }
}

@Composable
private fun StatusChip(tx: TransactionEntity, category: CategoryEntity?) {
    val colors = GeocentTheme.colors
    val (icon, label, tint) = when {
        !tx.hasLocation -> Triple(HugeIcons.location01, "Needs location", colors.dataWarning)
        tx.category == null -> Triple(HugeIcons.tag01, "Needs category", colors.dataWarning)
        else -> Triple(HugeIcons.tick02, category?.name ?: tx.category, colors.dataPositive)
    }
    Row(
        Modifier
            .clip(RoundedCornerShape(8.dp))
            .background(tint.copy(alpha = 0.12f))
            .padding(horizontal = 8.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(painterResource(icon), null, tint = tint, modifier = Modifier.size(13.dp))
        Spacer(Modifier.width(4.dp))
        Text(label, style = GeocentTheme.typography.caption, color = tint)
    }
}

@Composable
private fun SelectionDot(selected: Boolean) {
    val colors = GeocentTheme.colors
    Box(
        Modifier
            .padding(top = 10.dp)
            .size(22.dp)
            .clip(CircleShape)
            .background(if (selected) colors.accent else colors.surface)
            .border(1.5.dp, if (selected) colors.accent else colors.textSecondary, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        if (selected) {
            Icon(painterResource(HugeIcons.tick02), null, tint = androidx.compose.ui.graphics.Color.White, modifier = Modifier.size(14.dp))
        }
    }
}

@Composable
private fun SelectionBar(onMap: () -> Unit, onCategorize: () -> Unit, onForget: () -> Unit) {
    val colors = GeocentTheme.colors
    Row(
        Modifier
            .padding(16.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(colors.surface)
            .border(1.dp, colors.line, RoundedCornerShape(18.dp))
            .padding(vertical = 6.dp),
        horizontalArrangement = Arrangement.SpaceEvenly,
    ) {
        BarAction(HugeIcons.location01, "Map", onMap)
        BarAction(HugeIcons.tag01, "Categorise", onCategorize)
        BarAction(HugeIcons.delete02, "Forget", onForget, destructive = true)
    }
}

@Composable
private fun BarAction(icon: Int, label: String, onClick: () -> Unit, destructive: Boolean = false) {
    val tint = if (destructive) GeocentTheme.colors.dataWarning else GeocentTheme.colors.accent
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .combinedClickable(onClick = onClick)
            .padding(horizontal = 18.dp, vertical = 6.dp),
    ) {
        Icon(painterResource(icon), null, tint = tint, modifier = Modifier.size(22.dp))
        Text(label, style = GeocentTheme.typography.caption, color = tint)
    }
}

@Composable
private fun EmptyState(searching: Boolean, filter: MessageFilter) {
    val colors = GeocentTheme.colors
    val composition by rememberLottieComposition(
        LottieCompositionSpec.Asset(if (searching) "lottie/empty.json" else "lottie/done.json"),
    )
    Column(
        Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        LottieAnimation(composition, iterations = 1, modifier = Modifier.size(160.dp))
        Text(
            when {
                searching -> "No messages found"
                filter == MessageFilter.ALL -> "No messages yet"
                else -> "All caught up"
            },
            style = GeocentTheme.typography.title,
            color = colors.textPrimary,
        )
        Spacer(Modifier.height(6.dp))
        Text(
            when {
                searching -> "Try a different search or time range."
                filter == MessageFilter.ALL -> "M-PESA and bank SMS appear here as they arrive."
                else -> "Every message has a location and a category."
            },
            style = GeocentTheme.typography.body,
            color = colors.textSecondary,
            textAlign = TextAlign.Center,
        )
    }
}

private fun formatAmount(tx: TransactionEntity) =
    if (tx.currency == "KES") Notifier.formatKes(tx.amount) else "${tx.currency} ${"%.2f".format(tx.amount)}"

/** Bolds every case-insensitive occurrence of [query] in [text]. */
private fun highlight(text: String, query: String, color: androidx.compose.ui.graphics.Color): AnnotatedString {
    val q = query.trim()
    if (q.isEmpty()) return AnnotatedString(text)
    return buildAnnotatedString {
        append(text)
        var start = text.indexOf(q, ignoreCase = true)
        while (start >= 0) {
            addStyle(SpanStyle(color = color, fontWeight = FontWeight.SemiBold), start, start + q.length)
            start = text.indexOf(q, start + q.length, ignoreCase = true)
        }
    }
}
