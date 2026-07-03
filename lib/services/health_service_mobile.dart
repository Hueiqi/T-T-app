import 'dart:async';
import 'package:health/health.dart';
import '../models/sleep_model.dart';
import '../models/workout_model.dart';

extension HealthValueX on HealthValue {
  num? get numericValue {
    if (this is NumericHealthValue) {
      return (this as NumericHealthValue).numericValue;
    }
    return null;
  }
}

class HealthService {
  final Health _health = Health();
  bool _isAuthorized = false;
  bool _configured = false;
  Timer? _hrTimer;
  int _currentHeartRate = 0;
  List<int> _heartRateHistory = [];

  int get currentHeartRate => _currentHeartRate;
  List<int> get heartRateHistory => _heartRateHistory;

  Future<bool> authorize() async {
    // 1. Configure once
    if (!_configured) {
      await _health.configure();
      _configured = true;
    }

    final types = [
      HealthDataType.HEART_RATE,
      HealthDataType.STEPS,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_REM,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.ACTIVE_ENERGY_BURNED,
    ];
    _isAuthorized = await _health.requestAuthorization(types);
    return _isAuthorized;
  }

  Future<int> getCurrentHeartRate() async {
    if (!_isAuthorized) return 75;
    final now = DateTime.now();
    final data = await _health.getHealthDataFromTypes(
      types: [HealthDataType.HEART_RATE],
      startTime: now.subtract(const Duration(minutes: 5)),
      endTime: now,
    );
    if (data.isNotEmpty) {
      final latest = data.last;
      _currentHeartRate = latest.value.numericValue?.toInt() ?? 75;
    }
    return _currentHeartRate;
  }

  void startHeartRateMonitoring(void Function(int) onHeartRateChanged) {
    _hrTimer?.cancel();
    _hrTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final hr = await getCurrentHeartRate();
      _currentHeartRate = hr;
      _heartRateHistory.add(hr);
      if (_heartRateHistory.length > 100) {
        _heartRateHistory = _heartRateHistory.sublist(-100);
      }
      onHeartRateChanged(hr);
    });
  }

  void stopHeartRateMonitoring() {
    _hrTimer?.cancel();
    _hrTimer = null;
  }

  Future<SleepData?> getLastNightSleep(String userId) async {
    if (!_isAuthorized) return null;
    final now = DateTime.now();
    final lastNight = DateTime(now.year, now.month, now.day - 1);
    final today = DateTime(now.year, now.month, now.day);
    final data = await _health.getHealthDataFromTypes(
      types: [
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_REM,
        HealthDataType.SLEEP_AWAKE,
      ],
      startTime: lastNight,
      endTime: today,
    );
    if (data.isEmpty) return null;
    double totalHours = 0;
    double deepMin = 0, lightMin = 0, remMin = 0, awakeMin = 0;
    for (final point in data) {
      final durationHours =
          (point.dateTo.difference(point.dateFrom).inSeconds) / 3600;
      totalHours += durationHours;
      if (point.type == HealthDataType.SLEEP_DEEP) {
        deepMin += (durationHours * 60);
      } else if (point.type == HealthDataType.SLEEP_LIGHT) {
        lightMin += (durationHours * 60);
      } else if (point.type == HealthDataType.SLEEP_REM) {
        remMin += (durationHours * 60);
      } else if (point.type == HealthDataType.SLEEP_AWAKE) {
        awakeMin += (durationHours * 60);
      }
    }
    return SleepData(
      id: 'sleep_${userId}_${today.toIso8601String()}',
      userId: userId,
      date: lastNight,
      hoursSlept: totalHours,
      deepSleepMinutes: deepMin.toInt(),
      lightSleepMinutes: lightMin.toInt(),
      remSleepMinutes: remMin.toInt(),
      awakeMinutes: awakeMin.toInt(),
      quality: totalHours >= 7
          ? 'good'
          : totalHours >= 5
          ? 'moderate'
          : 'poor',
      source: 'smartwatch',
    );
  }

  Future<List<Workout>> getWorkoutSessions(DateTime start, DateTime end) async {
    if (!_isAuthorized) return [];
    try {
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: start,
        endTime: end,
      );
      return data.map((point) {
        return Workout(
          id: 'os_workout_${point.dateFrom.millisecondsSinceEpoch}_${point.dateTo.millisecondsSinceEpoch}',
          userId: '',
          startTime: point.dateFrom,
          endTime: point.dateTo,
          caloriesBurned: point.value.numericValue?.toDouble() ?? 0,
          type: 'os_sync',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<double> getCaloriesBurnedToday() async {
    if (!_isAuthorized) return 0;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final data = await _health.getHealthDataFromTypes(
      types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      startTime: startOfDay,
      endTime: now,
    );
    double total = 0;
    for (final point in data) {
      total += point.value.numericValue?.toDouble() ?? 0;
    }
    return total;
  }

  Future<int> getStepsToday() async {
    if (!_isAuthorized) return 0;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final data = await _health.getHealthDataFromTypes(
      types: [HealthDataType.STEPS],
      startTime: startOfDay,
      endTime: now,
    );
    int total = 0;
    for (final point in data) {
      total += point.value.numericValue?.toInt() ?? 0;
    }
    return total;
  }

  Future<Map<String, int>> getStepsHistory({int days = 7}) async {
    if (!_isAuthorized) return {};
    final now = DateTime.now();
    final result = <String, int>{};
    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(hours: 24));
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: startOfDay,
        endTime: endOfDay,
      );
      int total = 0;
      for (final point in data) {
        total += point.value.numericValue?.toInt() ?? 0;
      }
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      result[key] = total;
    }
    return result;
  }

  void dispose() {
    _hrTimer?.cancel();
  }
}
