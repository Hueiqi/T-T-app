package com.fyp.fitness_app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class HealthConnectPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private lateinit var applicationContext: android.content.Context
    private var activity: Activity? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var healthConnectClient: HealthConnectClient? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "health_connect")
        channel.setMethodCallHandler(this)
        applicationContext = binding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onReattachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getStepsToday" -> getStepsToday(result)
            "getHealthConnectAvailability" -> getAvailability(result)
            "requestPermissions" -> requestPermissions(result)
            else -> result.notImplemented()
        }
    }

    private fun getStepsToday(result: Result) {
        scope.launch {
            try {
                val client = getClient()
                if (client == null) {
                    result.success(0)
                    return@launch
                }
                val response = client.readRecords(
                    ReadRecordsRequest(
                        recordType = StepsRecord::class,
                        timeRangeFilter = TimeRangeFilter.today()
                    )
                )
                val totalSteps = response.records.sumOf { it.count }
                result.success(totalSteps.toInt())
            } catch (e: Exception) {
                Log.e("HealthConnect", "getStepsToday error", e)
                result.error("HEALTH_CONNECT_ERROR", e.message, 0)
            }
        }
    }

    private fun getAvailability(result: Result) {
        try {
            val client = getClient()
            val available = client?.availability?.healthConnectAvailable ?: false
            result.success(available)
        } catch (e: Exception) {
            Log.e("HealthConnect", "getAvailability error", e)
            result.success(false)
        }
    }

    private fun requestPermissions(result: Result) {
        val activity = activity
        if (activity == null) {
            result.error("NO_ACTIVITY", "No activity available to start permission request", null)
            return
        }
        try {
            val permissions = setOf(
                HealthPermission.getReadPermission(StepsRecord::class)
            )
            val intent = Intent(
                HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS
            ).apply {
                data = Uri.parse("package:com.fyp.fitness_app")
            }
            activity.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("PERMISSION_ERROR", e.message, null)
        }
    }

    private fun getClient(): HealthConnectClient? {
        if (healthConnectClient == null) {
            try {
                healthConnectClient = HealthConnectClient.getOrCreate(applicationContext)
            } catch (e: Exception) {
                Log.e("HealthConnect", "Failed to create client", e)
                return null
            }
        }
        return healthConnectClient
    }
}
