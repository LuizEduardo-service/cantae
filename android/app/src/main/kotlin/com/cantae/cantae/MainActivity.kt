package com.cantae.cantae

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// audio_service requires the launcher Activity to extend AudioServiceActivity
// (not plain FlutterActivity) so it can bind the FlutterEngine the background
// AudioService needs for lock-screen / notification transport controls
// (BG-01, BG-02). Using FlutterActivity here throws:
// "The Activity class declared in your AndroidManifest.xml is wrong or has
// not provided the correct FlutterEngine."
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // "Abrir ajustes" on the room screens (ROOM-20, ROOM-37).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cantae/system_settings")
            .setMethodCallHandler { call, result ->
                if (call.method != "openAppSettings") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val intent = Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.fromParts("package", packageName, null),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                result.success(null)
            }
    }
}
