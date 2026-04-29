// package com.example.mapbox_tut

// import android.util.Log
// import io.flutter.embedding.engine.plugins.FlutterPlugin
// import io.flutter.plugin.common.MethodChannel

// class SmsPlugin : FlutterPlugin {

//     private var channel: MethodChannel? = null

//     // ── FlutterPlugin lifecycle ────────────────────────────────────────────

//     override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
//         channel = MethodChannel(
//             binding.binaryMessenger,
//             CHANNEL_NAME,
//         )
//         // No MethodCallHandler needed — we only call Dart, never the other way
//         channel?.setMethodCallHandler(null)
//         instance = this
//         Log.d("SmsPlugin", "Attached to Flutter engine")
//     }

//     override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
//         channel?.setMethodCallHandler(null)
//         channel = null
//         if (instance === this) instance = null
//         Log.d("SmsPlugin", "Detached from Flutter engine")
//     }

//     // ── Called by SmsReceiver ──────────────────────────────────────────────

//     private fun forwardToFlutter(sender: String, body: String) {
//         channel?.invokeMethod(
//             METHOD_ON_SMS_RECEIVED,
//             mapOf(
//                 KEY_SENDER to sender,
//                 KEY_BODY   to body,
//             ),
//         )
//     }

//     // ── Companion (static) ─────────────────────────────────────────────────

//     companion object {
//         const val CHANNEL_NAME          = "com.mapbox_tut/sms"
//         const val METHOD_ON_SMS_RECEIVED = "onSmsReceived"
//         const val KEY_SENDER            = "sender"
//         const val KEY_BODY              = "body"

//         // Singleton reference set when the engine attaches.
//         // SmsReceiver is a plain BroadcastReceiver (no engine access),
//         // so it reaches the channel through this reference.
//         private var instance: SmsPlugin? = null

//         fun onSmsReceived(sender: String, body: String) {
//             val plugin = instance
//             if (plugin == null) {
//                 Log.w("SmsPlugin", "SMS arrived but Flutter engine not attached — dropped")
//                 return
//             }
//             // MethodChannel.invokeMethod must run on the platform (main) thread.
//             // BroadcastReceiver.onReceive is already on the main thread, so this
//             // is safe. If you ever call from a background thread, post to mainLooper.
//             plugin.forwardToFlutter(sender = sender, body = body)
//         }
//     }
// }


package com.example.mapbox_tut

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

class SmsPlugin : FlutterPlugin {

    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel?.setMethodCallHandler(null)
        
        // Add this engine's channel to our active pool
        channel?.let { activeChannels.add(it) }
        Log.d("SmsPlugin", "Attached to Flutter engine. Active channels: ${activeChannels.size}")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.let { activeChannels.remove(it) }
        channel?.setMethodCallHandler(null)
        channel = null
        Log.d("SmsPlugin", "Detached from Flutter engine.")
    }

    companion object {
        const val CHANNEL_NAME = "com.spendmap/sms" // Updated to match your Dart code
        
        // Holds references to both the UI Engine and the Background Service Engine
        private val activeChannels = mutableListOf<MethodChannel>()

        fun onSmsReceived(sender: String, body: String) {
            if (activeChannels.isEmpty()) {
                Log.w("SmsPlugin", "SMS arrived but no Flutter engines are running.")
                return
            }

            // MethodChannels MUST be invoked on the main Android thread
            Handler(Looper.getMainLooper()).post {
                for (ch in activeChannels) {
                    ch.invokeMethod(
                        "onSmsReceived",
                        mapOf("sender" to sender, "body" to body)
                    )
                }
            }
        }
    }
}