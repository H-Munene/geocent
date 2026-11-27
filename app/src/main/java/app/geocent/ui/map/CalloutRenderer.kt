package app.geocent.ui.map

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import androidx.core.content.res.ResourcesCompat
import app.geocent.R
import kotlin.math.ceil

/**
 * Draws the price-tag callout used for map markers (port of the Flutter
 * createCalloutImage): a white name block, a coloured price block, a black
 * outline, then a stem and dot in the category colour.
 *
 * The bitmap is vertically symmetric around the dot, so the symbol layer can
 * anchor it at its centre and the dot lands exactly on the coordinate.
 */
class CalloutRenderer(context: Context) {
    private val density = context.resources.displayMetrics.density
    private val densityDpi = context.resources.displayMetrics.densityDpi
    private fun dp(v: Float) = v * density

    private val namePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = ResourcesCompat.getFont(context, R.font.space_grotesk)
        textSize = dp(11f)
        isFakeBoldText = true
        letterSpacing = 0.05f
        color = Color.parseColor("#1D1D1F")
    }
    private val pricePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = ResourcesCompat.getFont(context, R.font.inter)
        textSize = dp(11f)
        fontFeatureSettings = "tnum"
        letterSpacing = 0.04f
        color = Color.WHITE
    }

    fun render(name: String, price: String, accent: Int): Bitmap {
        val cardHeight = dp(24f)
        val padH = dp(8f)
        val stemHeight = dp(11f)
        val dotRadius = dp(3f)
        val border = dp(1f)
        val shadow = dp(5f)

        val label = name.uppercase().let { if (it.length > 22) it.take(21) + "…" else it }
        val nameW = ceil(padH * 2 + namePaint.measureText(label))
        val priceW = ceil(padH * 2 + pricePaint.measureText(price))
        val cardWidth = nameW + priceW
        val width = cardWidth + shadow * 2
        val dotCentreY = shadow + cardHeight + stemHeight + dotRadius
        val height = dotCentreY * 2

        val bitmap = Bitmap.createBitmap(ceil(width).toInt(), ceil(height).toInt(), Bitmap.Config.ARGB_8888)
        bitmap.density = densityDpi
        val canvas = Canvas(bitmap)
        val left = shadow
        val top = shadow

        // Soft shadow under the card.
        canvas.drawRect(
            RectF(left + dp(1.5f), top + dp(1.5f), left + cardWidth + dp(1.5f), top + cardHeight + dp(1.5f)),
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.argb(40, 0, 0, 0)
                maskFilter = BlurMaskFilter(dp(3f), BlurMaskFilter.Blur.NORMAL)
            },
        )

        // Name block, then price block in the category colour.
        canvas.drawRect(RectF(left, top, left + nameW, top + cardHeight), Paint().apply { color = Color.WHITE })
        val accentPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = accent or (0xFF shl 24) }
        canvas.drawRect(RectF(left + nameW, top, left + cardWidth, top + cardHeight), accentPaint)

        val baseline = { p: Paint -> top + cardHeight / 2 - (p.descent() + p.ascent()) / 2 }
        canvas.drawText(label, left + padH, baseline(namePaint), namePaint)
        canvas.drawText(price, left + nameW + padH, baseline(pricePaint), pricePaint)

        // Outline.
        canvas.drawRect(
            RectF(left, top, left + cardWidth, top + cardHeight),
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = border
                color = Color.BLACK
            },
        )

        // Stem and dot, centred under the card.
        val cx = left + cardWidth / 2
        canvas.drawRect(RectF(cx - dp(0.75f), top + cardHeight, cx + dp(0.75f), top + cardHeight + stemHeight), accentPaint)
        canvas.drawCircle(cx, dotCentreY, dotRadius, accentPaint)
        return bitmap
    }
}
