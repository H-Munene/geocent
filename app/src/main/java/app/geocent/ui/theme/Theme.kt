package app.geocent.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf

private val LocalColors = staticCompositionLocalOf { LightColors }
private val LocalTypography = staticCompositionLocalOf { GeocentTypography() }

/** Access point for design tokens: `GeocentTheme.colors.accent`. */
object GeocentTheme {
    val colors: GeocentColors
        @Composable @ReadOnlyComposable get() = LocalColors.current
    val typography: GeocentTypography
        @Composable @ReadOnlyComposable get() = LocalTypography.current
}

@Composable
fun GeocentTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val colors = if (darkTheme) DarkColors else LightColors
    val typography = GeocentTypography()

    // Material 3 components (sheets, sliders, text fields) are still used for
    // behaviour, so map our tokens onto its scheme to keep them on-brand.
    val scheme = if (darkTheme) {
        darkColorScheme(
            primary = colors.accent, background = colors.background,
            surface = colors.surface, onBackground = colors.textPrimary,
            onSurface = colors.textPrimary, outline = colors.line,
            onSurfaceVariant = colors.textSecondary,
        )
    } else {
        lightColorScheme(
            primary = colors.accent, background = colors.background,
            surface = colors.surface, onBackground = colors.textPrimary,
            onSurface = colors.textPrimary, outline = colors.line,
            onSurfaceVariant = colors.textSecondary,
        )
    }

    CompositionLocalProvider(
        LocalColors provides colors,
        LocalTypography provides typography,
    ) {
        MaterialTheme(colorScheme = scheme, content = content)
    }
}
