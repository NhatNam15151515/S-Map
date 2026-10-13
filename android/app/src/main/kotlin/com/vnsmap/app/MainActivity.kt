package com.vnsmap.app

import android.content.Intent
import android.util.Log
import com.baseflow.geolocator.GeolocatorLocationService
import com.vnsmap.app.routing.RoutingConstants
import com.vnsmap.app.routing.RoutingMethodChannelHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var routingMethodChannelHandler: RoutingMethodChannelHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Đăng ký MethodChannel cho module định tuyến GraphHopper
        val routingChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            RoutingConstants.CHANNEL_NAME
        )
        val handler = RoutingMethodChannelHandler(context = applicationContext)
        routingMethodChannelHandler = handler
        routingChannel.setMethodCallHandler(handler)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        routingMethodChannelHandler?.close()
        routingMethodChannelHandler = null
    }

    override fun onDestroy() {
        // Removing the app task does not reliably set isFinishing on every
        // Android/OEM build. Preserve tracking only for configuration changes.
        val stopBackgroundLocation = !isChangingConfigurations
        Log.i("MainActivity", "onDestroy: stopBackgroundLocation=$stopBackgroundLocation")
        super.onDestroy()

        // The geolocator foreground service can outlive Flutter's activity.
        // Explicitly stop it when the user finishes/removes the app task.
        if (stopBackgroundLocation) {
            val stopped = stopService(
                Intent(applicationContext, GeolocatorLocationService::class.java),
            )
            Log.i("MainActivity", "Geolocator foreground service stop requested: $stopped")
        }
    }
}

