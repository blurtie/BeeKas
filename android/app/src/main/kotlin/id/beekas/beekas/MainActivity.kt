package id.beekas.beekas

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // lib/data/camera.dart: opens this app's page in Settings after a camera refusal.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "beekas/settings")
            .setMethodCallHandler { call, result ->
                if (call.method != "openAppSettings") return@setMethodCallHandler result.notImplemented()
                startActivity(
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null)),
                )
                result.success(null)
            }
    }
}
