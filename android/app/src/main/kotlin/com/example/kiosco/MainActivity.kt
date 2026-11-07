package com.example.kiosco

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Kiosk activity: exposes the Android "screen pinning" (lock task) mode and a
 * way to bring the tablet back to the kiosk view.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "com.example.kiosco/kiosk"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startLockTask" -> {
                        try {
                            startLockTask()
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("lock_task_failed", error.message, null)
                        }
                    }
                    "stopLockTask" -> {
                        try {
                            stopLockTask()
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("lock_task_failed", error.message, null)
                        }
                    }
                    "isInLockTaskMode" -> result.success(isInLockTaskMode())
                    "bringToFront" -> {
                        try {
                            bringToFrontTask()
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("bring_to_front_failed", error.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun activityManager(): ActivityManager =
        getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager

    private fun isInLockTaskMode(): Boolean {
        val manager = activityManager()
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            manager.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
        } else {
            @Suppress("DEPRECATION")
            manager.isInLockTaskMode
        }
    }

    private fun bringToFrontTask() {
        activityManager().moveTaskToFront(taskId, ActivityManager.MOVE_TASK_WITH_HOME)
    }
}
