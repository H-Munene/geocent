package com.example.mapbox_tut

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        try {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            if (messages.isNullOrEmpty()) return

            val sender = messages[0].originatingAddress ?: ""
            val body = messages.joinToString(separator = "") { it.messageBody ?: "" }

            Log.d("SmsReceiver", "Routing SMS from $sender to Flutter engines...")
            
            // Fires to both the Background Isolate and the UI Isolate
            SmsPlugin.onSmsReceived(sender = sender, body = body)

        } catch (e: Exception) {
            Log.e("SmsReceiver", "Failed to process incoming SMS", e)
        }
    }
}