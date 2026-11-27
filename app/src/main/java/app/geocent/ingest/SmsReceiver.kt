package app.geocent.ingest

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.OutOfQuotaPolicy
import androidx.work.WorkManager
import app.geocent.domain.SmsParser

/**
 * Receives every incoming SMS. Financial ones are handed to [IngestSmsWorker],
 * which runs even if the app isn't open; everything else is ignored.
 */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val parts = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (parts.isNullOrEmpty()) return

        // Long messages arrive in several parts; join them back together.
        val body = parts.joinToString("") { it.messageBody.orEmpty() }
        val parsed = SmsParser.parse(body) ?: return
        Log.d(TAG, "Financial SMS ${parsed.id} from ${parts[0].originatingAddress}")

        val request = OneTimeWorkRequestBuilder<IngestSmsWorker>()
            .setInputData(Data.Builder().putString(IngestSmsWorker.KEY_BODY, body).build())
            .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
            .build()
        // Keyed by transaction id so a duplicate broadcast can't double-process.
        WorkManager.getInstance(context)
            .enqueueUniqueWork("sms-${parsed.id}", ExistingWorkPolicy.KEEP, request)
    }

    private companion object {
        const val TAG = "SmsReceiver"
    }
}
