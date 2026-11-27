package app.geocent.ingest

import android.content.Context
import android.content.pm.ServiceInfo
import android.os.Build
import android.provider.Telephony
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.ForegroundInfo
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import app.geocent.data.settings.SettingsStore
import app.geocent.domain.toEpochMillis
import app.geocent.notify.Notifier
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import kotlinx.coroutines.flow.first
import java.time.LocalDateTime

/** Processes one live SMS: store, notify, check budget, attach GPS. */
@HiltWorker
class IngestSmsWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val ingestor: TransactionIngestor,
    private val notifier: Notifier,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val body = inputData.getString(KEY_BODY) ?: return Result.failure()
        ingestor.ingestLive(body)
        return Result.success()
    }

    /** Needed for expedited work on Android 11 and below. */
    override suspend fun getForegroundInfo(): ForegroundInfo {
        val id = 7001
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ForegroundInfo(id, notifier.syncNotification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            ForegroundInfo(id, notifier.syncNotification())
        }
    }

    companion object {
        const val KEY_BODY = "body"
    }
}

/** Imports past SMS from the inbox, back to the range chosen in onboarding. */
@HiltWorker
class ImportInboxWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val ingestor: TransactionIngestor,
    private val settings: SettingsStore,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val range = settings.importRange.first() ?: return Result.success()
        if (range == app.geocent.data.settings.ImportRange.NONE) return Result.success()
        val since = range.since(LocalDateTime.now())

        var imported = 0
        val selection = since?.let { "${Telephony.Sms.DATE} >= ?" }
        val args = since?.let { arrayOf(it.toEpochMillis().toString()) }
        applicationContext.contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            arrayOf(Telephony.Sms.BODY),
            selection,
            args,
            "${Telephony.Sms.DATE} ASC",
        )?.use { cursor ->
            val bodyColumn = cursor.getColumnIndexOrThrow(Telephony.Sms.BODY)
            while (cursor.moveToNext()) {
                val body = cursor.getString(bodyColumn) ?: continue
                // The parser decides what counts, so sender names don't matter.
                if (ingestor.ingestHistorical(body)) imported++
            }
        } ?: return Result.retry()

        settings.markImported(System.currentTimeMillis())
        return Result.success(androidx.work.Data.Builder().putInt(KEY_IMPORTED, imported).build())
    }

    companion object {
        const val KEY_IMPORTED = "imported"
        const val UNIQUE_NAME = "inbox-import"

        fun enqueue(context: Context) {
            WorkManager.getInstance(context).enqueueUniqueWork(
                UNIQUE_NAME,
                ExistingWorkPolicy.REPLACE,
                OneTimeWorkRequestBuilder<ImportInboxWorker>().build(),
            )
        }
    }
}
