import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Dart bridge to the native [HealthConnectPlugin] on Android.
///
/// Uses MethodChannel `"health_connect_plugin"` — must match the Kotlin side exactly.
/// All methods are no-ops on non-Android platforms.
class HealthConnectService {
  static const _channel = MethodChannel('health_connect_plugin');

  // ═══════════════════════════════════════════
  // AVAILABILITY
  // ═══════════════════════════════════════════

  /// Returns `true` if Health Connect SDK is available on this device.
  Future<bool> get isAvailable async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final available = await _channel.invokeMethod<bool>('checkAvailability');
      return available ?? false;
    } catch (e) {
      debugPrint('HealthConnect: checkAvailability failed: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════
  // PERMISSIONS
  // ═══════════════════════════════════════════

  /// Requests all required Health Connect permissions (read + write).
  /// Returns `true` if all permissions were granted.
  Future<bool> requestPermissions() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final result = await _channel.invokeMethod<bool>('requestPermissions');
      return result ?? false;
    } catch (e) {
      debugPrint('HealthConnect: requestPermissions failed: $e');
      return false;
    }
  }

  /// Returns `true` if the app already holds all required Health Connect permissions.
  Future<bool> hasPermissions() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final result = await _channel.invokeMethod<bool>('hasPermissions');
      return result ?? false;
    } catch (e) {
      debugPrint('HealthConnect: hasPermissions failed: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════
  // READ: STEPS
  // ═══════════════════════════════════════════

  /// Total steps recorded today (since midnight).
  Future<int> getStepsToday() async {
    if (defaultTargetPlatform != TargetPlatform.android) return 0;
    try {
      final steps = await _channel.invokeMethod<int>('getSteps');
      return steps ?? 0;
    } catch (e) {
      debugPrint('HealthConnect: getSteps failed: $e');
      return 0;
    }
  }

  /// Steps recorded between [start] and [end].
  Future<int> getStepsBetween(DateTime start, DateTime end) async {
    if (defaultTargetPlatform != TargetPlatform.android) return 0;
    try {
      final steps = await _channel.invokeMethod<int>('getStepsBetween', {
        'startMs': start.millisecondsSinceEpoch,
        'endMs': end.millisecondsSinceEpoch,
      });
      return steps ?? 0;
    } catch (e) {
      debugPrint('HealthConnect: getStepsBetween failed: $e');
      return 0;
    }
  }

  // ═══════════════════════════════════════════
  // READ: HEART RATE
  // ═══════════════════════════════════════════

  /// Heart rate samples recorded today.
  Future<List<Map<String, dynamic>>> getHeartRateToday() async {
    if (defaultTargetPlatform != TargetPlatform.android) return [];
    try {
      final data = await _channel.invokeMethod<List>('getHeartRate');
      return data?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      debugPrint('HealthConnect: getHeartRate failed: $e');
      return [];
    }
  }

  /// Heart rate samples between [start] and [end].
  Future<List<Map<String, dynamic>>> getHeartRateBetween(
    DateTime start,
    DateTime end,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.android) return [];
    try {
      final data = await _channel.invokeMethod<List>('getHeartRateBetween', {
        'startMs': start.millisecondsSinceEpoch,
        'endMs': end.millisecondsSinceEpoch,
      });
      return data?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      debugPrint('HealthConnect: getHeartRateBetween failed: $e');
      return [];
    }
  }

  /// Latest heart rate BPM from Health Connect (most recent reading today).
  Future<int> getCurrentHeartRate() async {
    final samples = await getHeartRateToday();
    if (samples.isEmpty) return 0;
    // Last sample = most recent
    final last = samples.last;
    return (last['beatsPerMinute'] as num?)?.toInt() ?? 0;
  }

  // ═══════════════════════════════════════════
  // READ: CALORIES
  // ═══════════════════════════════════════════

  /// Active calories burned today (kcal).
  Future<double> getCaloriesToday() async {
    if (defaultTargetPlatform != TargetPlatform.android) return 0;
    try {
      final cal = await _channel.invokeMethod<double>('getCalories');
      return cal ?? 0;
    } catch (e) {
      debugPrint('HealthConnect: getCalories failed: $e');
      return 0;
    }
  }

  // ═══════════════════════════════════════════
  // READ: SLEEP
  // ═══════════════════════════════════════════

  /// Sleep sessions recorded today.
  Future<List<Map<String, dynamic>>> getSleepToday() async {
    if (defaultTargetPlatform != TargetPlatform.android) return [];
    try {
      final data = await _channel.invokeMethod<List>('getSleep');
      return data?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      debugPrint('HealthConnect: getSleep failed: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════
  // WRITE: EXERCISE SESSION
  // ═══════════════════════════════════════════

  /// Writes a complete workout session to Health Connect.
  ///
  /// [exerciseType]: 0 = other, 1 = running, 2 = walking, 3 = cardio
  Future<bool> writeExerciseSession({
    required DateTime startTime,
    required DateTime endTime,
    required String title,
    int exerciseType = 0,
    double caloriesBurned = 0,
    double distanceMeters = 0,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final result = await _channel.invokeMethod<bool>('writeExerciseSession', {
        'startMs': startTime.millisecondsSinceEpoch,
        'endMs': endTime.millisecondsSinceEpoch,
        'title': title,
        'exerciseType': exerciseType,
        'caloriesBurned': caloriesBurned,
        'distanceMeters': distanceMeters,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('HealthConnect: writeExerciseSession failed: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════
  // WRITE: STEPS
  // ═══════════════════════════════════════════

  /// Writes a step count record to Health Connect for the given time window.
  Future<bool> writeSteps({
    required DateTime startTime,
    required DateTime endTime,
    required int count,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final result = await _channel.invokeMethod<bool>('writeSteps', {
        'startMs': startTime.millisecondsSinceEpoch,
        'endMs': endTime.millisecondsSinceEpoch,
        'count': count,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('HealthConnect: writeSteps failed: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════
  // WRITE: CALORIES
  // ═══════════════════════════════════════════

  /// Writes an active calories burned record to Health Connect.
  Future<bool> writeCalories({
    required DateTime startTime,
    required DateTime endTime,
    required double caloriesBurned,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final result = await _channel.invokeMethod<bool>('writeCalories', {
        'startMs': startTime.millisecondsSinceEpoch,
        'endMs': endTime.millisecondsSinceEpoch,
        'caloriesBurned': caloriesBurned,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('HealthConnect: writeCalories failed: $e');
      return false;
    }
  }
}
