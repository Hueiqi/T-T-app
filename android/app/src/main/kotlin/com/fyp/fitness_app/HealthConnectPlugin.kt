package com.fyp.fitness_app

import android.content.Context
import androidx.annotation.NonNull
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.embedding.engine.plugins.FlutterPlugin
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

class HealthConnectPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var healthConnectClient: HealthConnectClient? = null
    private val coroutineScope = CoroutineScope(Dispatchers.Main)

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        // IMPORTANT: Ensure this string matches the channel name in your Flutter Dart code.
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "health_connect_plugin")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        if (healthConnectClient == null) {
            try {
                healthConnectClient = HealthConnectClient.getOrCreate(context)
            } catch (e: Exception) {
                // Handle cases where Health Connect is not installed
            }
        }

        when (call.method) {
            "checkAvailability" -> checkAvailability(result)
            "getSteps" -> coroutineScope.launch { getSteps(result) }
            "getHeartRate" -> coroutineScope.launch { getHeartRate(result) }
            "getSleep" -> coroutineScope.launch { getSleep(result) }
            "getCalories" -> coroutineScope.launch { getCalories(result) }
            else -> result.notImplemented()
        }
    }

    // ==========================================
    // 1. FIXED SDK STATUS CHECKS
    // ==========================================
    private fun checkAvailability(result: Result) {
        val status = HealthConnectClient.getSdkStatus(context)
        when (status) {
            HealthConnectClient.SDK_AVAILABLE -> result.success(true)
            HealthConnectClient.SDK_UNAVAILABLE -> result.success(false)
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> result.success(false)
            else -> result.success(false)
        }
    }

    // ==========================================
    // 2. FIXED TIME RANGE & READ RECORDS REQUEST (STEPS)
    // ==========================================
    private suspend fun getSteps(result: Result) {
        try {
            val client = healthConnectClient ?: return result.error("UNAVAILABLE", "Health Connect Client is null", null)
            val todayStart = ZonedDateTime.now().truncatedTo(ChronoUnit.DAYS).toInstant()
            val now = Instant.now()

            val request = ReadRecordsRequest(
                recordType = StepsRecord::class,
                timeRangeFilter = TimeRangeFilter.between(todayStart, now)
            )

            val response = client.readRecords(request)
            var totalSteps = 0L
            for (record in response.records) {
                totalSteps += record.count
            }
            result.success(totalSteps)
        } catch (e: Exception) {
            result.error("ERROR", e.localizedMessage, null)
        }
    }

    // ==========================================
    // 3. FIXED LAMBDA SCOPE & HEART RATE SAMPLES
    // ==========================================
    private suspend fun getHeartRate(result: Result) {
        try {
            val client = healthConnectClient ?: return result.error("UNAVAILABLE", "Health Connect Client is null", null)
            val todayStart = ZonedDateTime.now().truncatedTo(ChronoUnit.DAYS).toInstant()
            val now = Instant.now()

            val request = ReadRecordsRequest(
                recordType = HeartRateRecord::class,
                timeRangeFilter = TimeRangeFilter.between(todayStart, now)
            )

            val response = client.readRecords(request)
            
            // Fixed the implicit "it" errors by explicitly naming variables
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

    // ==========================================
    // 4. FIXED SLEEP SESSION RECORDS
    // ==========================================
    private suspend fun getSleep(result: Result) {
        try {
            val client = healthConnectClient ?: return result.error("UNAVAILABLE", "Health Connect Client is null", null)
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

    // ==========================================
    // 5. FIXED ACTIVE CALORIES RECORDS
    // ==========================================
    private suspend fun getCalories(result: Result) {
        try {
            val client = healthConnectClient ?: return result.error("UNAVAILABLE", "Health Connect Client is null", null)
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