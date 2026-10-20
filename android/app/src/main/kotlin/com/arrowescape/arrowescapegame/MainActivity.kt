package com.arrowescape.arrowescapegame

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var updateHandler: InAppUpdateHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                else -> result.notImplemented()
            }
        }

        val handler = InAppUpdateHandler(this)
        updateHandler = handler
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            InAppUpdateHandler.METHOD_CHANNEL,
        ).setMethodCallHandler(handler)
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            InAppUpdateHandler.EVENT_CHANNEL,
        ).setStreamHandler(handler)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        updateHandler?.dispose()
        updateHandler = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    // FlutterActivity is not a ComponentActivity, so the Play update flow
    // reports back through the classic request-code callback.
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        updateHandler?.onActivityResult(requestCode, resultCode)
    }

    private companion object {
        const val DEVICE_CHANNEL = "com.arrowescape.arrowescapegame/device"
    }
}
