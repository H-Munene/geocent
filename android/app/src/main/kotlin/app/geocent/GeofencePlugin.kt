package app.geocent

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class GeofencePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null
    private var geofencingClient: GeofencingClient? = null
    private val TAG = "GeofencePlugin"

    private val geofencePendingIntent: PendingIntent by lazy {
        val intent = Intent(context, GeofenceBroadcastReceiver::class.java)
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        PendingIntent.getBroadcast(context!!, 0, intent, flags)
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        geofencingClient = LocationServices.getGeofencingClient(context!!)
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel?.setMethodCallHandler(this)
        
        activeChannels.add(channel!!)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        activeChannels.remove(channel!!)
        channel?.setMethodCallHandler(null)
        channel = null
        geofencingClient = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "addGeofences" -> {
                val geofencesData = call.argument<List<Map<String, Any>>>("geofences")
                if (geofencesData != null) {
                    addGeofences(geofencesData, result)
                } else {
                    result.error("INVALID_ARGUMENT", "Geofences data is null", null)
                }
            }
            "removeGeofences" -> {
                val ids = call.argument<List<String>>("ids")
                if (ids != null) {
                    removeGeofences(ids, result)
                } else {
                    result.error("INVALID_ARGUMENT", "IDs are null", null)
                }
            }
            "removeAllGeofences" -> {
                removeAllGeofences(result)
            }
            "getActiveGeofenceId" -> {
                val prefs = context?.getSharedPreferences("geocent_geofence", Context.MODE_PRIVATE)
                result.success(prefs?.getString("active_geofence", null))
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun addGeofences(geofencesData: List<Map<String, Any>>, result: MethodChannel.Result) {
        val geofenceList = mutableListOf<Geofence>()

        for (data in geofencesData) {
            val id = data["id"] as String
            val latitude = data["latitude"] as Double
            val longitude = data["longitude"] as Double
            val radius = (data["radius"] as Number).toFloat()

            geofenceList.add(
                Geofence.Builder()
                    .setRequestId(id)
                    .setCircularRegion(latitude, longitude, radius)
                    .setExpirationDuration(Geofence.NEVER_EXPIRE)
                    .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_DWELL or Geofence.GEOFENCE_TRANSITION_EXIT)
                    .setLoiteringDelay(300000) // 5 minutes DWELL
                    .build()
            )
        }

        if (geofenceList.isEmpty()) {
            result.success(true)
            return
        }

        val request = GeofencingRequest.Builder().apply {
            setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_DWELL)
            addGeofences(geofenceList)
        }.build()

        geofencingClient?.addGeofences(request, geofencePendingIntent)?.run {
            addOnSuccessListener {
                Log.d(TAG, "Geofences added successfully")
                result.success(true)
            }
            addOnFailureListener { e ->
                Log.e(TAG, "Failed to add geofences", e)
                result.error("GEOFENCE_FAILURE", e.message, null)
            }
        }
    }

    private fun removeGeofences(ids: List<String>, result: MethodChannel.Result) {
        geofencingClient?.removeGeofences(ids)?.run {
            addOnSuccessListener {
                result.success(true)
            }
            addOnFailureListener { e ->
                result.error("GEOFENCE_FAILURE", e.message, null)
            }
        }
    }

    private fun removeAllGeofences(result: MethodChannel.Result) {
        geofencingClient?.removeGeofences(geofencePendingIntent)?.run {
            addOnSuccessListener {
                result.success(true)
            }
            addOnFailureListener { e ->
                result.error("GEOFENCE_FAILURE", e.message, null)
            }
        }
    }

    companion object {
        const val CHANNEL_NAME = "app.geocent/geofence"
        private val activeChannels = mutableListOf<MethodChannel>()

        fun onGeofenceTransition(geofenceId: String, transitionType: String, context: Context) {
            // Persist state for rehydration
            val prefs = context.getSharedPreferences("geocent_geofence", Context.MODE_PRIVATE)
            if (transitionType == "DWELL") {
                prefs.edit().putString("active_geofence", geofenceId).apply()
            } else if (transitionType == "EXIT") {
                prefs.edit().remove("active_geofence").apply()
            }

            Handler(Looper.getMainLooper()).post {
                for (ch in activeChannels) {
                    ch.invokeMethod(
                        "onGeofenceTransition",
                        mapOf("id" to geofenceId, "transition" to transitionType)
                    )
                }
            }
        }
    }
}
