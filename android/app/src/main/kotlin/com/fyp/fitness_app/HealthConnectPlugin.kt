package com.fyp.fitness_app

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.annotation.NonNull
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
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
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZonedDateTime
import java.time.temporal.ChronoUnit

class HealthConnectPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var healthConnectClient: HealthConnectClient? = null
    private val coroutineScope = CoroutineScope(Dispatchers.Main)
    private var activity: android.app.Activity? = null

    private val requiredPermissions = setOf(
        "android.permission.health.READ_HEART_RATE",
        "android.permission.health.READ_STEPS",
        "android.permission.health.READ_SLEEP",
        "android.permission.health.READ_ACTIVE_CALORIES_BURNED",
        "android.permission.health.READ_TOTAL_CALORIES_BURNED",
        "android.permission.health.READ_EXERCISE",
        "android.permission.health.WRITE_HEART_RATE",
        "android.permission.health.WRITE_STEPS",
        "android.permission.health.WRITE_ACTIVE_CALORIES_BURNED",
        "android.permission.health.WRITE_TOTAL_CALORIES_BURNED",
        "android.permission.health.WRITE_EXERCISE"
    )

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "health_connect_plugin")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivity() { activity = null }

    private fun getClient(): HealthConnectClient? {
        if (healthConnectClient == null) {
            try {
                healthConnectClient = HealthConnectClient.getOrCreate(context)
            } catch (e: Exception) {
                return null
            }
        }
        return healthConnectClient
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "checkAvailability" -> checkAvailability(result)
            "requestPermissions" -> requestPermissions(result)
            "hasPermissions" -> hasPermissions(result)
            "getSteps" -> coroutineScope.launch { getSteps(result) }
            "getStepsBetween" -> {
                val startMs = call.argument<Long>("startMs")!!
                val endMs = call.argument<Long>("endMs")!!
                coroutineScope.launch { getStepsBetween(startMs, endMs, result) }
            }
            "getHeartRate" -> coroutineScope.launch { getHeartRate(result) }
            "getHeartRateBetween" -> {
                val startMs = call.argument<Long>("startMs")!!
                val endMs = call.argument<Long>("endMs")!!
                coroutineScope.launch { getHeartRateBetween(startMs, endMs, result) }
            }
            "getSleep" -> coroutineScope.launch { getSleep(result) }
            "getCalories" -> coroutineScope.launch { getCalories(result) }
            else -> result.notImplemented()
        }
    }

    // ── Availability ──
    private fun checkAvailability(result: Result) {
        val status = HealthConnectClient.getSdkStatus(context)
        when (status) {
            HealthConnectClient.SDK_AVAILABLE -> result.success(mapOf("available" to true, "needsUpdate" to false))
            HealthConnectClient.SDK_UNAVAILABLE -> result.success(mapOf("available" to false, "needsUpdate" to false))
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> result.success(mapOf("available" to false, "needsUpdate" to true))
            else -> result.success(mapOf("available" to false, "needsUpdate" to false))
        }
    }

    // ── Permissions ──
    private fun hasPermissions(result: Result) {
        val client = getClient() ?: return result.error("UNAVAILABLE", "Health Connect not available", null)
        coroutineScope.launch {
            try {
                val granted = client.permissionController.getGrantedPermissions()
                result.success(granted.containsAll(requiredPermissions))
            } catch (e: Exception) {
                result.success(false)
            }
        }
    }

    private fun requestPermissions(result: Result) {
        val currentActivity = activity
            ?: return result.error("NO_ACTIVITY", "No activity available for permission request", null)

        val sdkStatus = HealthConnectClient.getSdkStatus(context)
        when (sdkStatus) {
            HealthConnectClient.SDK_UNAVAILABLE -> {
                result.success(mapOf("granted" to false, "needsInstall" to true))
                return
            }
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> {
                try {
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        data = Uri.parse("market://details?id=com.google.android.apps.healthdata")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    currentActivity.startActivity(intent)
                } catch (_: Exception) {
                    try {
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            data = Uri.parse("https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        currentActivity.startActivity(intent)
                    } catch (_: Exception) {}
                }
                result.success(mapOf("granted" to false, "needsInstall" to true))
                return
            }
        }

        val client = getClient()
            ?: return result.error("UNAVAILABLE", "Health Connect not available", null)

        coroutineScope.launch {
            try {
                val granted = client.permissionController.getGrantedPermissions()
                if (granted.containsAll(requiredPermissions)) {
                    result.success(mapOf("granted" to true, "needsInstall" to false))
                    return@launch
                }
            } catch (_: Exception) {}

            try {
                val intent = Intent("androidx.health.ACTION_REQUEST_PERMISSIONS").apply {
                    setPackage("com.google.android.apps.healthdata")
                    putStringArrayListExtra("androidx.health.PERMISSION_LIST", ArrayList(requiredPermissions))
                    putExtra("androidx.health.PACKAGE_NAME", context.packageName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                currentActivity.startActivity(intent)
                result.success(mapOf("granted" to true, "needsInstall" to false))
            } catch (e: Exception) {
                val fallbackIntent = Intent(Intent.ACTION_VIEW).apply {
                    data = Uri.parse("package:${context.packageName}")
                    setClassName(
                        "com.google.android.apps.healthdata",
                        "com.google.android.healthconnect.controller.permissions.api.HealthConnectPermissionsActivity"
                    )
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                try {
                    currentActivity.startActivity(fallbackIntent)
                    result.success(mapOf("granted" to true, "needsInstall" to false))
                } catch (e2: Exception) {
                    result.error("PERMISSION_ERROR", "Could not open Health Connect permissions: ${e2.message}", null)
                }
            }
        }
    }

    // ── Read: Steps ──
    private suspend fun getSteps(result: Result) {
        val todayStart = ZonedDateTime.now().truncatedTo(ChronoUnit.DAYS).toInstant()
        getStepsBetween(todayStart.toEpochMilli(), System.currentTimeMillis(), result)
    }

    private suspend fun getStepsBetween(startMs: Long, endMs: Long, result: Result) {
        try {
            val client = getClient() ?: return result.error("UNAVAILABLE", "Health Connect Client is null", null)
            val start = Instant.ofEpochMilli(startMs)
            val end = Instant.ofEpochMilli(endMs)

            val request = ReadRecordsRequest(
                recordType = StepsRecord::class,
                timeRangeFilter = TimeRangeFilter.between(start, end)
            )
            val response = client.readRecords(request)
            var totalSteps = 0L
            for (record in response.records) {
                totalSteps += record.count
            }
            result.success(totalSteps.toInt())
        } catch (e: Exception) {
            result.error("ERROR", e.localizedMessage, null)
        }
    }

    // ── Read: Heart Rate ──
    private suspend fun getHeartRate(result: Result) {
        val todayStart = ZonedDateTime.now().truncatedTo(ChronoUnit.DAYS).toInstant()
        getHeartRateBetween(todayStart.toEpochMilli(), System.currentTimeMillis(), result)
    }

    private suspend fun getHeartRateBetween(startMs: Long, endMs: Long, result: Result) {
        try {
            val client = getClient() ?: return result.error("UNAVAILABLE", "Health Connect Client is null", null)
            val start = Instant.ofEpochMilli(startMs)
            val end = Instant.ofEpochMilli(endMs)

            val request = ReadRecordsRequest(
                recordType = HeartRateRecord::class,
                timeRangeFilter = TimeRangeFilter.between(start, end)
            )
            val response = client.readRecords(request)
            val heartRateData = response.records.flatMap { record ->
                record.samples.map { sample ->
                    mapOf(
                        "time" to sample.time.toString(),
                        "beatsPerMinute" to sample.beatsPerMinute
                    )
                }
            }
            result.success(heartRateData)
        } catch (e: Exception) {
            result.error("ERROR", e.localizedMessage, null)
        }
    }

    // ── Read: Sleep ──
    private suspend fun getSleep(result: Result) {
        try {
            val client = getClient() ?: return result.error("UNAVAILABLE", "Health Connect Client is null", null)
            val todayStart = ZonedDateTime.now().truncatedTo(ChronoUnit.DAYS).toInstant()
            val now = Instant.now()

            val request = ReadRecordsRequest(
                recordType = SleepSessionRecord::class,
                timeRangeFilter = TimeRangeFilter.between(todayStart, now)
            )
            val response = client.readRecords(request)
            val sleepData = response.records.map { record ->
                mapOf(
                    "startTime" to record.startTime.toString(),
                    "endTime" to record.endTime.toString()
                )
            }
            result.success(sleepData)
        } catch (e: Exception) {
            result.error("ERROR", e.localizedMessage, null)
        }
    }

    // ── Read: Calories ──
    private suspend fun getCalories(result: Result) {
        try {
            val client = getClient() ?: return result.error("UNAVAILABLE", "Health Connect Client is null", null)
            val todayStart = ZonedDateTime.now().truncatedTo(ChronoUnit.DAYS).toInstant()
            val now = Instant.now()

            val request = ReadRecordsRequest(
                recordType = ActiveCaloriesBurnedRecord::class,
                timeRangeFilter = TimeRangeFilter.between(todayStart, now)
            )
            val response = client.readRecords(request)
            var totalCalories = 0.0
            for (record in response.records) {
                totalCalories += record.energy.inKilocalories
            }
            result.success(totalCalories)
        } catch (e: Exception) {
            result.error("ERROR", e.localizedMessage, null)
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
