package id.beekas.beekas

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    // lib/data/camera.dart: opens this app's page in Settings after a camera refusal, and
    // turns a listing photo image_picker kept as PNG (alpha) into a JPEG (K-05).
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "beekas/settings")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openAppSettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null)),
                        )
                        result.success(null)
                    }
                    // ponytail: runs on the main thread; image_picker caps it at 1600 px.
                    "toJpeg" -> try {
                        val bytes = call.arguments as ByteArray
                        val image = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                            ?: return@setMethodCallHandler result.error("undecodable", null, null)
                        // JPEG has no alpha: transparent parts become white.
                        val flat = Bitmap.createBitmap(image.width, image.height, Bitmap.Config.ARGB_8888)
                        Canvas(flat).apply {
                            drawColor(Color.WHITE)
                            drawBitmap(image, 0f, 0f, null)
                        }
                        val out = ByteArrayOutputStream()
                        flat.compress(Bitmap.CompressFormat.JPEG, 85, out)
                        image.recycle()
                        flat.recycle()
                        result.success(out.toByteArray())
                    } catch (e: Throwable) {
                        // Out of memory or a broken file: the app shows "format not supported".
                        result.error("convert_failed", e.message, null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
