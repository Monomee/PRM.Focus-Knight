package com.example.test_dart

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.BasicMessageChannel
import io.flutter.plugin.common.JSONMessageCodec
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FocusKnightChannels.register(this, flutterEngine)
    }
}

/** Available to both the Activity and the foreground worker engine. */
object FocusKnightChannels {
    fun register(context: Context, flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "focusknight/overlay")
            .setMethodCallHandler { call, result ->
                if (call.method == "closeOverlay") {
                    // The plugin replies to showOverlay before its service is running.
                    context.stopService(Intent(context, flutter.overlay.window.flutter_overlay_window.OverlayService::class.java))
                    result.success(null)
                } else if (call.method == "shareData") {
                    // Bypass the plugin's static messenger shared by all three engines.
                    val overlay = FlutterEngineCache.getInstance().get("myCachedEngine")
                    if (overlay == null) {
                        result.error("OVERLAY_NOT_READY", "Overlay engine is unavailable", null)
                    } else {
                        BasicMessageChannel<Any?>(overlay.dartExecutor.binaryMessenger,
                            "x-slayer/overlay_messenger", JSONMessageCodec.INSTANCE)
                            .send(call.arguments) { result.success(null) }
                    }
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "focusknight/alerts")
            .setMethodCallHandler { call, result ->
                if (call.method == "show") {
                    showAlert(
                        context,
                        call.argument<Int>("id") ?: 1,
                        call.argument<String>("title") ?: "",
                        call.argument<String>("body") ?: "",
                    )
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    /** Heads-up alert on its own high-importance channel (the session timer channel is silent). */
    private fun showAlert(context: Context, id: Int, title: String, body: String) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(ALERT_CHANNEL, "FocusKnight – cảnh báo", NotificationManager.IMPORTANCE_HIGH)
                    .apply { description = "Bắt đầu/kết thúc phiên, vi phạm, lên hạng" }
            )
        }
        val open = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notification = NotificationCompat.Builder(context, ALERT_CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_focusknight)
            .setColor(0xFF2F8F91.toInt())
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(open)
            .build()
        try {
            manager.notify(ALERT_ID_BASE + id, notification)
        } catch (_: SecurityException) {
            // Notification permission not granted: nothing to show.
        }
    }

    private const val ALERT_CHANNEL = "focusknight_alerts"
    private const val ALERT_ID_BASE = 7000
}
