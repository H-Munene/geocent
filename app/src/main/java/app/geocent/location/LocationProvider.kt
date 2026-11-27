package app.geocent.location

import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.Manifest
import androidx.core.content.ContextCompat
import com.google.android.gms.location.CurrentLocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withTimeoutOrNull
import javax.inject.Inject
import javax.inject.Singleton

data class LatLng(val latitude: Double, val longitude: Double)

/** Where the device is right now; null if permission is missing or no fix arrives in time. */
interface LocationProvider {
    suspend fun currentLocation(): LatLng?
}

@Singleton
class FusedLocationProvider @Inject constructor(
    @ApplicationContext private val context: Context,
) : LocationProvider {

    private val client = LocationServices.getFusedLocationProviderClient(context)

    fun hasPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    @SuppressLint("MissingPermission") // checked by hasPermission()
    override suspend fun currentLocation(): LatLng? {
        if (!hasPermission()) return null
        return runCatching {
            // A fix from the last few minutes is good enough and much cheaper.
            val last = client.lastLocation.await()
            if (last != null && System.currentTimeMillis() - last.time < FRESH_MS) {
                return@runCatching LatLng(last.latitude, last.longitude)
            }
            val request = CurrentLocationRequest.Builder()
                .setPriority(Priority.PRIORITY_HIGH_ACCURACY)
                .setMaxUpdateAgeMillis(FRESH_MS)
                .build()
            val cancel = CancellationTokenSource()
            withTimeoutOrNull(TIMEOUT_MS) {
                client.getCurrentLocation(request, cancel.token).await()
            }?.let { LatLng(it.latitude, it.longitude) }
                .also { cancel.cancel() }
        }.getOrNull()
    }

    private companion object {
        const val FRESH_MS = 5 * 60 * 1000L
        const val TIMEOUT_MS = 30_000L
    }
}
