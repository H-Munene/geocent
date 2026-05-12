package app.geocent

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent

class GeofenceBroadcastReceiver : BroadcastReceiver() {
    private val TAG = "GeofenceReceiver"

    override fun onReceive(context: Context, intent: Intent) {
        val geofencingEvent = GeofencingEvent.fromIntent(intent) ?: return

        if (geofencingEvent.hasError()) {
            Log.e(TAG, "GeofencingEvent error: ${geofencingEvent.errorCode}")
            return
        }

        val geofenceTransition = geofencingEvent.geofenceTransition

        if (geofenceTransition == Geofence.GEOFENCE_TRANSITION_DWELL ||
            geofenceTransition == Geofence.GEOFENCE_TRANSITION_EXIT
        ) {
            val triggeringGeofences = geofencingEvent.triggeringGeofences ?: return

            for (geofence in triggeringGeofences) {
                val geofenceId = geofence.requestId
                val transitionType = if (geofenceTransition == Geofence.GEOFENCE_TRANSITION_DWELL) "DWELL" else "EXIT"
                
                Log.d(TAG, "Geofence $transitionType: $geofenceId")
                
                // Notify Flutter
                GeofencePlugin.onGeofenceTransition(geofenceId, transitionType, context)
            }
        }
    }
}
