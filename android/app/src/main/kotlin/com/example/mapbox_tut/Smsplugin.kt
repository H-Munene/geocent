
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