package app.geocent.ui.analytics

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import app.geocent.domain.Breakdown
import app.geocent.domain.Bucket
import app.geocent.notify.Notifier
import app.geocent.ui.theme.GeocentTheme

/** Grows from 0 to 1 whenever [key] changes, for chart entry animations. */
@Composable
private fun rememberGrowth(key: Any): Float {
    val anim = remember { Animatable(0f) }
    LaunchedEffect(key) {
        anim.snapTo(0f)
        anim.animateTo(1f, tween(600))
    }
    return anim.value
}

/** Bars stacked by category colour, one per bucket, with labels underneath. */
@Composable
fun StackedBarChart(buckets: List<Bucket>, colorFor: (String?) -> Color, modifier: Modifier = Modifier) {
    val colors = GeocentTheme.colors
    val max = buckets.maxOfOrNull { it.total }?.takeIf { it > 0 } ?: 1.0
    val growth = rememberGrowth(buckets)
    // Labels get crowded on 30-day months: show every 5th day.
    val labelEvery = if (buckets.size > 12) 5 else 1
    Column(modifier) {
        Canvas(Modifier.fillMaxWidth().height(180.dp)) {
            val slot = size.width / buckets.size
            val barWidth = (slot * 0.6f).coerceAtMost(28.dp.toPx())
            // Faint guide lines at 50% and 100% of the tallest bar.
            listOf(0f, 0.5f).forEach { f ->
                drawLine(colors.line, Offset(0f, size.height * f), Offset(size.width, size.height * f), 1.dp.toPx())
            }
            buckets.forEachIndexed { i, bucket ->
                val x = slot * i + (slot - barWidth) / 2
                var top = size.height
                // Biggest category at the bottom so the stack reads consistently.
                bucket.byCategory.entries.sortedByDescending { it.value }.forEach { (category, amount) ->
                    val h = (amount / max * size.height * growth).toFloat()
                    drawRoundRect(colorFor(category), Offset(x, top - h), Size(barWidth, h), CornerRadius(3.dp.toPx()))
                    top -= h
                }
                if (bucket.total == 0.0) {
                    drawRoundRect(colors.line, Offset(x, size.height - 3.dp.toPx()), Size(barWidth, 3.dp.toPx()), CornerRadius(2.dp.toPx()))
                }
            }
        }
        Row(Modifier.fillMaxWidth().padding(top = 6.dp)) {
            buckets.forEachIndexed { i, bucket ->
                Text(
                    if (i % labelEvery == 0) bucket.label else "",
                    style = GeocentTheme.typography.tabLabel,
                    color = colors.textSecondary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.weight(1f),
                    maxLines = 1,
                )
            }
        }
    }
}

/** Running line of bucket totals with a soft fill. */
@Composable
fun SpendLineChart(buckets: List<Bucket>, modifier: Modifier = Modifier) {
    val colors = GeocentTheme.colors
    val max = buckets.maxOfOrNull { it.total }?.takeIf { it > 0 } ?: 1.0
    val growth = rememberGrowth(buckets)
    val labelEvery = if (buckets.size > 12) 5 else 1
    Column(modifier) {
        Canvas(Modifier.fillMaxWidth().height(180.dp)) {
            if (buckets.isEmpty()) return@Canvas
            val step = size.width / (buckets.size - 1).coerceAtLeast(1)
            val points = buckets.mapIndexed { i, b ->
                Offset(step * i, size.height - (b.total / max * size.height * 0.92 * growth).toFloat())
            }
            drawLine(colors.line, Offset(0f, size.height), Offset(size.width, size.height), 1.dp.toPx())
            val line = Path().apply { points.forEachIndexed { i, p -> if (i == 0) moveTo(p.x, p.y) else lineTo(p.x, p.y) } }
            val fill = Path().apply {
                addPath(line)
                lineTo(points.last().x, size.height)
                lineTo(points.first().x, size.height)
                close()
            }
            drawPath(fill, colors.accent.copy(alpha = 0.12f))
            drawPath(line, colors.accent, style = Stroke(2.5.dp.toPx(), cap = StrokeCap.Round))
            points.filterIndexed { i, _ -> buckets[i].total > 0 }.forEach { drawCircle(colors.accent, 3.dp.toPx(), it) }
        }
        Row(Modifier.fillMaxWidth().padding(top = 6.dp)) {
            buckets.forEachIndexed { i, bucket ->
                Text(
                    if (i % labelEvery == 0) bucket.label else "",
                    style = GeocentTheme.typography.tabLabel,
                    color = colors.textSecondary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.weight(1f),
                    maxLines = 1,
                )
            }
        }
    }
}

/** Category shares as a donut, total in the middle. */
@Composable
fun DonutChart(categories: List<Breakdown>, total: Double, colorFor: (String) -> Color, modifier: Modifier = Modifier) {
    val colors = GeocentTheme.colors
    val growth = rememberGrowth(categories)
    Box(modifier.fillMaxWidth().height(200.dp), contentAlignment = Alignment.Center) {
        Canvas(Modifier.size(180.dp)) {
            val stroke = 26.dp.toPx()
            val inset = stroke / 2
            val arcSize = Size(size.width - stroke, size.height - stroke)
            if (categories.isEmpty()) {
                drawArc(colors.line, 0f, 360f, false, Offset(inset, inset), arcSize, style = Stroke(stroke))
                return@Canvas
            }
            var start = -90f
            categories.forEach { c ->
                val sweep = (c.share * 360 * growth).toFloat()
                // Small gap between slices reads better than touching arcs.
                drawArc(colorFor(c.name), start, (sweep - 1.5f).coerceAtLeast(0.5f), false, Offset(inset, inset), arcSize, style = Stroke(stroke))
                start += sweep
            }
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text("TOTAL", style = GeocentTheme.typography.tabLabel, color = colors.textSecondary)
            Text(Notifier.formatKes(total), style = GeocentTheme.typography.amount, color = colors.textPrimary)
        }
    }
}
