package com.example.test_dart

import android.app.Application
import com.pravera.flutter_foreground_task.FlutterForegroundTaskLifecycleListener
import com.pravera.flutter_foreground_task.FlutterForegroundTaskPlugin
import com.pravera.flutter_foreground_task.FlutterForegroundTaskStarter
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor

class FocusKnightApplication : Application(), FlutterForegroundTaskLifecycleListener {
    override fun onCreate() {
        super.onCreate()
        FlutterForegroundTaskPlugin.addTaskLifecycleListener(this)
    }

    override fun onEngineCreate(flutterEngine: FlutterEngine?) {
        if (flutterEngine == null) return
        FocusKnightChannels.register(this, flutterEngine)
        // The overlay plugin normally prepares this only when an Activity opens.
        // A service restarted after process death has no Activity.
        val cache = FlutterEngineCache.getInstance()
        if (cache.get("myCachedEngine") == null) {
            val entry = DartExecutor.DartEntrypoint(
                FlutterInjector.instance().flutterLoader().findAppBundlePath(), "overlayMain"
            )
            cache.put("myCachedEngine", FlutterEngineGroup(this).createAndRunEngine(this, entry))
        }
    }

    override fun onTaskStart(starter: FlutterForegroundTaskStarter) {}
    override fun onTaskRepeatEvent() {}
    override fun onTaskDestroy() {}
    override fun onEngineWillDestroy() {}
}
