package app.geocent.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import app.geocent.R

private fun variable(res: Int, weight: Int) = Font(
    resId = res,
    weight = FontWeight(weight),
    variationSettings = FontVariation.Settings(FontVariation.weight(weight)),
)

/** Text font: Space Grotesk (variable, weights 300-700). */
val SpaceGrotesk = FontFamily(
    variable(R.font.space_grotesk, 300),
    variable(R.font.space_grotesk, 400),
    variable(R.font.space_grotesk, 500),
    variable(R.font.space_grotesk, 600),
    variable(R.font.space_grotesk, 700),
)

/** Data font: Inter (variable), always with tabular figures. */
val Inter = FontFamily(
    variable(R.font.inter, 400),
    variable(R.font.inter, 500),
    variable(R.font.inter, 600),
    variable(R.font.inter, 700),
)

private const val TABULAR = "tnum"

/**
 * Type scale from DESIGN.md: tight negative tracking for text, tight line
 * heights for large headings, tabular Inter for every number.
 */
@Immutable
data class GeocentTypography(
    val largeTitle: TextStyle = TextStyle(
        fontFamily = SpaceGrotesk, fontWeight = FontWeight.Bold,
        fontSize = 32.sp, lineHeight = 1.07.em, letterSpacing = (-0.374).sp,
    ),
    val title: TextStyle = TextStyle(
        fontFamily = SpaceGrotesk, fontWeight = FontWeight.Bold,
        fontSize = 22.sp, lineHeight = 1.14.em, letterSpacing = (-0.33).sp,
    ),
    val headline: TextStyle = TextStyle(
        fontFamily = SpaceGrotesk, fontWeight = FontWeight.SemiBold,
        fontSize = 17.sp, letterSpacing = (-0.3).sp,
    ),
    val body: TextStyle = TextStyle(
        fontFamily = SpaceGrotesk, fontWeight = FontWeight.Normal,
        fontSize = 16.sp, letterSpacing = (-0.3).sp,
    ),
    val caption: TextStyle = TextStyle(
        fontFamily = SpaceGrotesk, fontWeight = FontWeight.Medium,
        fontSize = 12.sp, letterSpacing = (-0.28).sp,
    ),
    val tabLabel: TextStyle = TextStyle(
        fontFamily = SpaceGrotesk, fontWeight = FontWeight.Medium,
        fontSize = 10.sp, letterSpacing = (-0.1).sp,
    ),
    val amountLarge: TextStyle = TextStyle(
        fontFamily = Inter, fontWeight = FontWeight.Bold,
        fontSize = 28.sp, fontFeatureSettings = TABULAR,
    ),
    val amount: TextStyle = TextStyle(
        fontFamily = Inter, fontWeight = FontWeight.SemiBold,
        fontSize = 16.sp, fontFeatureSettings = TABULAR,
    ),
    val amountSmall: TextStyle = TextStyle(
        fontFamily = Inter, fontWeight = FontWeight.Medium,
        fontSize = 13.sp, fontFeatureSettings = TABULAR,
    ),
)
