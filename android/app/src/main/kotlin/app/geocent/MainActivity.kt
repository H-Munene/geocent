package app.geocent

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Register our native SMS plugin so the channel is available
        // as soon as the Flutter engine starts.
        flutterEngine.plugins.add(SmsPlugin())
    }
}