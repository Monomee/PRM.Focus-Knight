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
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "focusknight/alerts")
            .setMethodCallHandler { call, result ->
                if (call.method == "show") {
                    showAlert(
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
    private fun showAlert(id: Int, title: String, body: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(ALERT_CHANNEL, "FocusKnight – cảnh báo", NotificationManager.IMPORTANCE_HIGH)
                    .apply { description = "Bắt đầu/kết thúc phiên, vi phạm, lên hạng" }
            )
        }
        val open = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notification = NotificationCompat.Builder(this, ALERT_CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
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

    companion object {
        private const val ALERT_CHANNEL = "focusknight_alerts"
        private const val ALERT_ID_BASE = 7000
    }
}
