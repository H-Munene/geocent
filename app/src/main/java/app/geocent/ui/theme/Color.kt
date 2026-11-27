package app.geocent.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color

/** Colour tokens from DESIGN.md. */
@Immutable
data class GeocentColors(
    /** Main canvas. */
    val background: Color,
    /** Elevated cards, lists and sheets. */
    val surface: Color,
    val textPrimary: Color,
    /** Muted labels, timestamps, inactive icons. */
    val textSecondary: Color,
    /** 1px borders and dividers. */
    val line: Color,
    /** The only chromatic colour allowed for interactive UI. */
    val accent: Color = Accent,
    val dataPositive: Color = DataPositive,
    val dataSelected: Color = DataSelected,
    val dataWarning: Color = DataWarning,
    val isDark: Boolean,
)

val Accent = Color(0xFF0071E3)
val DataPositive = Color(0xFF00CC96) // Energy Green
val DataSelected = Color(0xFF00B3E6) // Transition Teal
val DataWarning = Color(0xFFC25100) // Commodity Rust

val LightColors = GeocentColors(
    background = Color(0xFFF5F5F7),
    surface = Color(0xFFFFFFFF),
    textPrimary = Color(0xFF1D1D1F),
    textSecondary = Color(0xFF747780),
    line = Color(0xFFE9ECEF),
    isDark = false,
)

val DarkColors = GeocentColors(
    background = Color(0xFF000000),
    surface = Color(0xFF1C1C1E),
    textPrimary = Color(0xFFFFFFFF),
    textSecondary = Color(0xFF747780),
    line = Color(0x1AFFFFFF),
    isDark = true,
)
