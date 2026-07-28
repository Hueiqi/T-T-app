package com.fyp.fitness_app

import androidx.health.connect.client.PermissionController
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    private val healthConnectPlugin = HealthConnectPlugin()

    private val permissionLauncher = registerForActivityResult(
        PermissionController.createRequestPermissionResultContract()
    ) { grantedPermissions ->
        healthConnectPlugin.onPermissionResult(grantedPermissions)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        healthConnectPlugin.permissionLauncher = permissionLauncher
        flutterEngine.plugins.add(healthConnectPlugin)
    }
}
