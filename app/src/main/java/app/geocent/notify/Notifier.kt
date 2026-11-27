package app.geocent.notify

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import app.geocent.MainActivity
import app.geocent.R
import dagger.hilt.android.qualifiers.ApplicationContext
import java.text.NumberFormat
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton

/** All user-facing notifications and their channels. */
@Singleton
class Notifier @Inject constructor(@ApplicationContext private val context: Context) {

    object Channels {
        const val TRANSACTIONS = "transactions"
        const val BUDGETS = "budgets"
        const val HOTSPOTS = "hotspots"
        const val SYNC = "sync"
    }

    fun createChannels() {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannels(
            listOf(
                NotificationChannel(Channels.TRANSACTIONS, "Transactions", NotificationManager.IMPORTANCE_HIGH)
                    .apply { description = "New expense tracked from an SMS" },
                NotificationChannel(Channels.BUDGETS, "Budget alerts", NotificationManager.IMPORTANCE_HIGH)
                    .apply { description = "When a budget reaches 50%, 80% or 100%" },
                NotificationChannel(Channels.HOTSPOTS, "Spending hotspots", NotificationManager.IMPORTANCE_DEFAULT)
                    .apply { description = "When you linger where you usually spend" },
                NotificationChannel(Channels.SYNC, "Background work", NotificationManager.IMPORTANCE_MIN)
                    .apply { description = "Shown briefly while an SMS is processed" },
            ),
        )
    }

    fun transaction(id: String, merchant: String, amount: String) =
        post(Channels.TRANSACTIONS, id.hashCode(), "New expense tracked", "$amount at $merchant")

    fun budget(budgetId: String, category: String, percent: Int, amountLeft: Double, nearHotspot: Boolean) {
        val title = if (percent >= 100) "$category budget exceeded" else "$category budget at $percent%"
        val left = if (amountLeft > 0) "${formatKes(amountLeft)} left this period" else "You're over budget"
        val body = if (nearHotspot) "$left. You're at one of your spending hotspots." else "$left."
        post(Channels.BUDGETS, budgetId.hashCode(), title, body)
    }

    fun hotspot(hotspotId: String, averageSpend: Double) = post(
        Channels.HOTSPOTS, hotspotId.hashCode(), "Spending alert",
        "You've spent an average of ${formatKes(averageSpend)} in this area.",
    )

    /** Small silent notification for expedited work on Android 11 and below. */
    fun syncNotification() = NotificationCompat.Builder(context, Channels.SYNC)
        .setSmallIcon(R.drawable.ic_tab_map_active)
        .setContentTitle("Processing transaction")
        .setPriority(NotificationCompat.PRIORITY_MIN)
        .build()

    private fun post(channel: String, id: Int, title: String, body: String) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) return
        val open = PendingIntent.getActivity(
            context, 0, Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notification = NotificationCompat.Builder(context, channel)
            .setSmallIcon(R.drawable.ic_tab_map_active)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        NotificationManagerCompat.from(context).notify(id, notification)
    }

    companion object {
        private val kes = NumberFormat.getNumberInstance(Locale.US).apply { maximumFractionDigits = 0 }
        fun formatKes(amount: Double) = "KES ${kes.format(amount)}"
    }
}
