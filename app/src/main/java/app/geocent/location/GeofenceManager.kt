package app.geocent.location

import android.Manifest
import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.content.ContextCompat
import app.geocent.data.db.HotspotEntity
import app.geocent.domain.distanceMeters
import app.geocent.ingest.GeofenceReceiver
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Registers hotspots as Play Services geofences. Android allows 100 per app,
 * so the hotspots nearest the user are chosen.
 */
@Singleton
class GeofenceManager @Inject constructor(@ApplicationContext private val context: Context) {

    private val client = LocationServices.getGeofencingClient(context)

    private val pendingIntent: PendingIntent by lazy {
        PendingIntent.getBroadcast(
            context, 0, Intent(context, GeofenceReceiver::class.java),
            // Mutable: Play Services fills in the geofence event.
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
    }

    /** Geofences need precise location "all the time" on Android 10+. */
    fun canMonitor(): Boolean = listOf(
        Manifest.permission.ACCESS_FINE_LOCATION,
        Manifest.permission.ACCESS_BACKGROUND_LOCATION,
    ).all { ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED }

    /** Replaces all geofences with the [MAX] hotspots closest to [near] (or the first [MAX] if unknown). */
    @SuppressLint("MissingPermission") // checked by canMonitor()
    suspend fun register(hotspots: List<HotspotEntity>, near: LatLng?) {
        if (!canMonitor()) return
        runCatching { client.removeGeofences(pendingIntent).await() }
        if (hotspots.isEmpty()) return

        val chosen = if (near == null) hotspots.take(MAX)
        else hotspots.sortedBy { distanceMeters(near.latitude, near.longitude, it.latitude, it.longitude) }.take(MAX)

        val fences = chosen.map { h ->
            Geofence.Builder()
                .setRequestId(h.id)
                .setCircularRegion(h.latitude, h.longitude, h.radius.toFloat())
                .setExpirationDuration(Geofence.NEVER_EXPIRE)
                .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_DWELL or Geofence.GEOFENCE_TRANSITION_EXIT)
                .setLoiteringDelay(LOITER_MS)
                .build()
        }
        val request = GeofencingRequest.Builder()
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_DWELL)
            .addGeofences(fences)
            .build()
        runCatching { client.addGeofences(request, pendingIntent).await() }
            .onSuccess { Log.d(TAG, "Monitoring ${fences.size} hotspots") }
            .onFailure { Log.w(TAG, "Could not add geofences", it) }
    }

    private companion object {
        const val TAG = "GeofenceManager"
        const val MAX = 100
        const val LOITER_MS = 5 * 60 * 1000 // 5 minutes in a hotspot counts as a visit
    }
}
