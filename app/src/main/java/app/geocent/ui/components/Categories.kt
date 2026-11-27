package app.geocent.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.input.maxLengthTrim
import androidx.compose.foundation.text.input.setTextAndPlaceCursorAtEnd
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import app.geocent.data.db.CategoryEntity
import app.geocent.domain.CategoryCatalog
import app.geocent.ui.theme.GeocentTheme
import app.geocent.ui.theme.HugeIcons
import app.geocent.ui.theme.categoryIcon

/** ARGB long (e.g. 0xFFFF9500) to a Compose colour; the low 32 bits hold the ARGB value. */
fun CategoryEntity.color() = Color(colorArgb.toInt())

/** Category icon on a soft tint of its colour; a grey initial when uncategorised. */
@Composable
fun CategoryAvatar(category: CategoryEntity?, fallbackLabel: String, size: Dp = 40.dp) {
    val colors = GeocentTheme.colors
    Box(
        Modifier
            .size(size)
            .clip(CircleShape)
            .background(category?.color()?.copy(alpha = 0.15f) ?: colors.line),
        contentAlignment = Alignment.Center,
    ) {
        if (category != null) {
            Icon(
                painterResource(categoryIcon(category.iconKey)),
                contentDescription = category.name,
                tint = category.color().copy(alpha = 1f),
                modifier = Modifier.size(size * 0.5f),
            )
        } else {
            Text(
                fallbackLabel.take(1).uppercase(),
                style = GeocentTheme.typography.headline,
                color = colors.textSecondary,
            )
        }
    }
}

/**
 * Pick (or create) a category. Used for single and bulk categorisation.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CategorySheet(
    title: String,
    categories: List<CategoryEntity>,
    current: String?,
    onSelect: (String) -> Unit,
    onCreate: (name: String, iconKey: Int, colorArgb: Long) -> Unit,
    onDismiss: () -> Unit,
) {
    val colors = GeocentTheme.colors
    var creating by remember { mutableStateOf(false) }
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberFullSheetState(),
        containerColor = colors.surface,
    ) {
        Column(Modifier.navigationBarsPadding().padding(horizontal = 20.dp)) {
            Text(title, style = GeocentTheme.typography.title, color = colors.textPrimary)
            Spacer(Modifier.height(16.dp))
            LazyVerticalGrid(
                columns = GridCells.Fixed(4),
                verticalArrangement = Arrangement.spacedBy(16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                contentPadding = PaddingValues(bottom = 24.dp),
                modifier = Modifier.heightIn(max = 520.dp),
            ) {
                items(categories, key = { it.name }) { category ->
                    CategoryCell(category.name, selected = category.name == current, onClick = { onSelect(category.name) }) {
                        CategoryAvatar(category, category.name, size = 52.dp)
                    }
                }
                item(key = "__new") {
                    CategoryCell("New", selected = false, onClick = { creating = true }) {
                        Box(
                            Modifier
                                .size(52.dp)
                                .clip(CircleShape)
                                .border(1.dp, colors.line, CircleShape),
                            contentAlignment = Alignment.Center,
                        ) {
                            Icon(painterResource(HugeIcons.add01), null, tint = colors.accent)
                        }
                    }
                }
            }
        }
    }
    if (creating) {
        NewCategoryDialog(
            taken = categories.map { it.name.lowercase() }.toSet(),
            usedIcons = categories.map { it.iconKey }.toSet(),
            onDismiss = { creating = false },
            onCreate = { name, icon, color ->
                creating = false
                onCreate(name, icon, color)
            },
        )
    }
}

@Composable
private fun CategoryCell(label: String, selected: Boolean, onClick: () -> Unit, icon: @Composable () -> Unit) {
    val colors = GeocentTheme.colors
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .then(if (selected) Modifier.background(colors.accent.copy(alpha = 0.1f)) else Modifier)
            .padding(vertical = 6.dp),
    ) {
        icon()
        Spacer(Modifier.height(6.dp))
        Text(
            label,
            style = GeocentTheme.typography.caption,
            color = if (selected) colors.accent else colors.textPrimary,
            textAlign = TextAlign.Center,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

/** Colours offered for new categories (Apple system palette, as in the Flutter app). */
private val palette = listOf(
    0xFFFF9500, 0xFFFFCC00, 0xFF34C759, 0xFF00C7BE, 0xFF5AC8FA, 0xFF0A84FF,
    0xFF5856D6, 0xFFAF52DE, 0xFFFF2D55, 0xFFFF3B30, 0xFFA2845E, 0xFF8E8E93,
)

@Composable
private fun NewCategoryDialog(
    taken: Set<String>,
    usedIcons: Set<Int>,
    onDismiss: () -> Unit,
    onCreate: (String, Int, Long) -> Unit,
) {
    val colors = GeocentTheme.colors
    val nameState = androidx.compose.foundation.text.input.rememberTextFieldState()
    val name = nameState.text.toString()
    val icons = remember(usedIcons) { CategoryCatalog.icons.filter { it.key !in usedIcons } }
    var iconKey by remember { mutableStateOf(icons.firstOrNull()?.key ?: 0) }
    var color by remember { mutableLongStateOf(palette.first()) }
    val trimmed = name.trim()
    val valid = trimmed.isNotEmpty() && trimmed.lowercase() !in taken

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = colors.surface,
        title = { Text("New category", style = GeocentTheme.typography.title, color = colors.textPrimary) },
        text = {
            Column {
                BasicTextField(
                    state = nameState,
                    inputTransformation = androidx.compose.foundation.text.input.InputTransformation.maxLengthTrim(24),
                    lineLimits = androidx.compose.foundation.text.input.TextFieldLineLimits.SingleLine,
                    textStyle = GeocentTheme.typography.body.copy(color = colors.textPrimary),
                    cursorBrush = SolidColor(colors.accent),
                    decorator = { inner ->
                        Box(
                            Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(10.dp))
                                .background(colors.background)
                                .padding(12.dp),
                        ) {
                            if (name.isEmpty()) Text("Name", style = GeocentTheme.typography.body, color = colors.textSecondary)
                            inner()
                        }
                    },
                )
                Spacer(Modifier.height(16.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    palette.take(6).forEach { swatch -> Swatch(swatch, swatch == color) { color = swatch } }
                }
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    palette.drop(6).forEach { swatch -> Swatch(swatch, swatch == color) { color = swatch } }
                }
                Spacer(Modifier.height(16.dp))
                LazyVerticalGrid(
                    columns = GridCells.Fixed(6),
                    modifier = Modifier.height(180.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    items(icons, key = { it.key }) { icon ->
                        val selected = icon.key == iconKey
                        Box(
                            Modifier
                                .size(40.dp)
                                .clip(CircleShape)
                                .background(if (selected) Color(color.toInt()).copy(alpha = 0.18f) else Color.Transparent)
                                .clickable {
                                    iconKey = icon.key
                                    if (name.isBlank()) nameState.setTextAndPlaceCursorAtEnd(icon.defaultName)
                                },
                            contentAlignment = Alignment.Center,
                        ) {
                            Icon(
                                painterResource(categoryIcon(icon.key)), icon.defaultName,
                                tint = if (selected) Color(color.toInt()) else colors.textSecondary,
                                modifier = Modifier.size(22.dp),
                            )
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton("Add", { onCreate(trimmed, iconKey, color) }, enabled = valid)
        },
        dismissButton = { TextButton("Cancel", onDismiss) },
    )
}

@Composable
private fun Swatch(argb: Long, selected: Boolean, onClick: () -> Unit) {
    Box(
        Modifier
            .size(30.dp)
            .clip(CircleShape)
            .background(Color(argb.toInt()))
            .border(if (selected) 3.dp else 0.dp, GeocentTheme.colors.surface.copy(alpha = 0.9f), CircleShape)
            .clickable(onClick = onClick),
    )
}
