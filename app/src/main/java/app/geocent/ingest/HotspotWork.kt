package app.geocent.ingest

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.Data
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import app.geocent.data.HotspotRepository
import app.geocent.data.settings.SettingsStore
import app.geocent.domain.Hotspots
import app.geocent.location.GeofenceManager
import app.geocent.location.LocationProvider
import app.geocent.notify.Notifier
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.first
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

/** Asks for hotspots to be recomputed and geofences re-registered. */
interface HotspotRefresher {
    /** Soon, batched: called after spending gains a location. */
    fun requestRefresh()
}

@Singleton
class WorkManagerHotspotRefresher @Inject constructor(@ApplicationContext private val context: Context) : HotspotRefresher {
    override fun requestRefresh() = HotspotScheduler.refreshSoon(context)
}

object HotspotScheduler {
    private const val SOON = "hotspot-refresh"
    private const val PERIODIC = "hotspot-refresh-periodic"

    /** Debounced: a burst of new locations triggers one refresh a minute later. */
    fun refreshSoon(context: Context) {
        WorkManager.getInstance(context).enqueueUniqueWork(
            SOON, ExistingWorkPolicy.REPLACE,
            OneTimeWorkRequestBuilder<HotspotRefreshWorker>().setInitialDelay(1, TimeUnit.MINUTES).build(),
        )
    }

    /** Twice a day, so geofences follow the user and survive Play Services resets. */
    fun schedulePeriodic(context: Context) {
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            PERIODIC, ExistingPeriodicWorkPolicy.KEEP,
            PeriodicWorkRequestBuilder<HotspotRefreshWorker>(12, TimeUnit.HOURS).build(),
        )
    }
}

/** Re-clusters spending and registers the hotspots nearest the user as geofences. */
@HiltWorker
class HotspotRefreshWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val hotspots: HotspotRepository,
    private val geofences: GeofenceManager,
    private val location: LocationProvider,
) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val all = hotspots.recompute()
        geofences.register(all, if (all.isEmpty()) null else location.currentLocation())
        return Result.success()
    }
}

/** Handles a dwell (alert, with cooldown) or exit for one hotspot. */
@HiltWorker
class HotspotTransitionWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val hotspots: HotspotRepository,
    private val settings: SettingsStore,
    private val notifier: Notifier,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val id = inputData.getString(KEY_ID) ?: return Result.failure()
        when (inputData.getString(KEY_TRANSITION)) {
            DWELL -> {
                settings.setActiveHotspot(id)
                val hotspot = hotspots.get(id) ?: return Result.success()
                val now = System.currentTimeMillis()
                if (Hotspots.isCoolingDown(hotspot.lastNotifiedAt, now)) return Result.success()
                notifier.hotspot(id, hotspot.avgSpend)
                hotspots.markNotified(id, now)
            }
            EXIT -> if (settings.activeHotspot.first() == id) settings.setActiveHotspot(null)
        }
        return Result.success()
    }

    companion object {
        const val KEY_ID = "id"
        const val KEY_TRANSITION = "transition"
        const val DWELL = "dwell"
        const val EXIT = "exit"
    }
}

/** Receives geofence transitions from Play Services. */
class GeofenceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError()) {
            Log.w("GeofenceReceiver", "Geofence error ${event.errorCode}")
            return
        }
        val transition = when (event.geofenceTransition) {
            Geofence.GEOFENCE_TRANSITION_DWELL -> HotspotTransitionWorker.DWELL
            Geofence.GEOFENCE_TRANSITION_EXIT -> HotspotTransitionWorker.EXIT
            else -> return
        }
        event.triggeringGeofences.orEmpty().forEach { fence ->
            val data = Data.Builder()
                .putString(HotspotTransitionWorker.KEY_ID, fence.requestId)
                .putString(HotspotTransitionWorker.KEY_TRANSITION, transition)
                .build()
            WorkManager.getInstance(context).enqueue(OneTimeWorkRequestBuilder<HotspotTransitionWorker>().setInputData(data).build())
        }
    }
}

/** Geofences are cleared on reboot; register them again. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) HotspotScheduler.refreshSoon(context)
    }
}
