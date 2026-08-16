package com.vnsmap.app

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
        val handler = RoutingMethodChannelHandler()
        routingMethodChannelHandler = handler
        routingChannel.setMethodCallHandler(handler)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        routingMethodChannelHandler?.close()
        routingMethodChannelHandler = null
    }
}
