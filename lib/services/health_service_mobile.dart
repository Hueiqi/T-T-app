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
  // Singleton: several providers (health, sleep, workout) each construct a
  // HealthService, but authorization state must be shared — otherwise only
  // the instance that called authorize() can read, and the others silently
  // return empty results.
  HealthService._();
  static final HealthService _instance = HealthService._();
  factory HealthService() => _instance;

  final Health _health = Health();
  bool _isAuthorized = false;
  bool _configured = false;
  Timer? _hrTimer;
  int _currentHeartRate = 0;
  List<int> _heartRateHistory = [];

  // Mi Fitness's Android package name — used to filter Health Connect
  // records so only data written by Mi Fitness counts, ignoring any other
  // app (phone pedometer, Nike Run Club, Strava, etc.) sharing the same
  // Health Connect store.
  static const String _miFitnessSourceId = 'com.xiaomi.wearable';

  // Depending on plugin/Health Connect version the writing app's package
  // name arrives in sourceId or sourceName — accept either.
  bool _fromMiFitness(HealthDataPoint p) =>
      p.sourceId == _miFitnessSourceId || p.sourceName == _miFitnessSourceId;

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
      HealthDataType.WORKOUT,
    ];
    _isAuthorized = await _health.requestAuthorization(types);
    return _isAuthorized;
  }

  Future<int> getCurrentHeartRate() async {
    if (!_isAuthorized) return 75;
    final now = DateTime.now();
    // Health Connect data (e.g. synced from Mi Fitness) arrives periodically,
    // not live — the newest reading can be many minutes old. Look back a full
    // day and take the most recent sample so delayed data still shows up.
    final data = (await _health.getHealthDataFromTypes(
      types: [HealthDataType.HEART_RATE],
      startTime: now.subtract(const Duration(hours: 24)),
      endTime: now,
    )).where(_fromMiFitness).toList();
    if (data.isNotEmpty) {
      // getHealthDataFromTypes returns chronological order; last = most recent.
      data.sort((a, b) => a.dateTo.compareTo(b.dateTo));
      final latest = data.last;
      _currentHeartRate = latest.value.numericValue?.toInt() ?? _currentHeartRate;
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

  /// Returns the latest **wake day's** sleep, combining multiple sessions
  /// that end on the same calendar day (e.g. a nap plus overnight sleep, or a
  /// sleep session the watch split in two) into one summed total.
  ///
  /// Uses SLEEP_SESSION for true durations so overlapping stages (deep/light/
  /// REM live *inside* the asleep period) are never double-counted. Looks
  /// back 36h so last night's sleep is caught even though it crosses
  /// midnight, groups sessions by the day they ended (the "wake day"), and
  /// sums every session in the most recent group. Filtered to Mi Fitness
  /// records only.
  Future<SleepData?> getLastNightSleep(String userId) async {
    if (!_isAuthorized) return null;
    final now = DateTime.now();
    final windowStart = now.subtract(const Duration(hours: 36));

    // Prefer SLEEP_SESSION records (one per sleep bout, true duration).
    final sessions = (await _health.getHealthDataFromTypes(
      types: [HealthDataType.SLEEP_SESSION],
      startTime: windowStart,
      endTime: now,
    )).where(_fromMiFitness).toList();

    List<HealthDataPoint> source = sessions;
    if (source.isEmpty) {
      // Fallback: some sources only write SLEEP_ASLEEP, not a session.
      source = (await _health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_ASLEEP],
        startTime: windowStart,
        endTime: now,
      )).where(_fromMiFitness).toList();
    }
    if (source.isEmpty) return null;

    // Group by the calendar day each sleep bout ended on, then take the
    // most recent day's group — combining same-day bouts.
    final byWakeDate = <DateTime, List<HealthDataPoint>>{};
    for (final s in source) {
      final key = DateTime(s.dateTo.year, s.dateTo.month, s.dateTo.day);
      byWakeDate.putIfAbsent(key, () => []).add(s);
    }
    final latestKey = byWakeDate.keys.reduce((a, b) => a.isAfter(b) ? a : b);
    final group = byWakeDate[latestKey]!
      ..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));

    double totalHours = 0;
    double deepMin = 0, lightMin = 0, remMin = 0, awakeMin = 0;
    for (final bout in group) {
      totalHours += bout.dateTo.difference(bout.dateFrom).inSeconds / 3600.0;

      // Stage breakdown, read only within this bout's own time range.
      final stages = (await _health.getHealthDataFromTypes(
        types: [
          HealthDataType.SLEEP_DEEP,
          HealthDataType.SLEEP_LIGHT,
          HealthDataType.SLEEP_REM,
          HealthDataType.SLEEP_AWAKE,
        ],
        startTime: bout.dateFrom,
        endTime: bout.dateTo,
      )).where(_fromMiFitness);
      for (final point in stages) {
        final mins = point.dateTo.difference(point.dateFrom).inSeconds / 60.0;
        if (point.type == HealthDataType.SLEEP_DEEP) {
          deepMin += mins;
        } else if (point.type == HealthDataType.SLEEP_LIGHT) {
          lightMin += mins;
        } else if (point.type == HealthDataType.SLEEP_REM) {
          remMin += mins;
        } else if (point.type == HealthDataType.SLEEP_AWAKE) {
          awakeMin += mins;
        }
      }
    }

    return SleepData(
      id: 'sleep_${userId}_${group.first.dateFrom.toIso8601String()}',
      userId: userId,
      date: latestKey,
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
    try {
      // Sum raw STEPS records from Mi Fitness only, so steps from other apps
      // sharing Health Connect (phone pedometer, Nike Run Club, Strava...)
      // don't get counted in.
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: startOfDay,
        endTime: now,
      );
      return data
          .where(_fromMiFitness)
          .fold<int>(0, (sum, p) => sum + (p.value.numericValue?.toInt() ?? 0));
    } catch (_) {
      return 0;
    }
  }

  Future<Map<String, int>> getStepsHistory({int days = 7}) async {
    if (!_isAuthorized) return {};
    final now = DateTime.now();
    final result = <String, int>{};
    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(hours: 24));
      int total = 0;
      try {
        // Mi-Fitness-only sum (see getStepsToday).
        final data = await _health.getHealthDataFromTypes(
          types: [HealthDataType.STEPS],
          startTime: startOfDay,
          endTime: endOfDay,
        );
        total = data
            .where(_fromMiFitness)
            .fold<int>(0, (sum, p) => sum + (p.value.numericValue?.toInt() ?? 0));
      } catch (_) {
        total = 0;
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
