import 'dart:async';
import '../models/sleep_model.dart';
import '../models/workout_model.dart';

class HealthService {
  Timer? _hrTimer;
  int _currentHeartRate = 75;
  List<int> _heartRateHistory = [];

  int get currentHeartRate => _currentHeartRate;
  List<int> get heartRateHistory => _heartRateHistory;

  Future<bool> authorize() async {
    return true;
  }

  Future<int> getCurrentHeartRate() async {
    _currentHeartRate = 60 + (DateTime.now().millisecondsSinceEpoch % 40).toInt();
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
    return null;
  }

  Future<List<Workout>> getWorkoutSessions(DateTime start, DateTime end) async {
    return [];
  }

  Future<double> getCaloriesBurnedToday() async {
    return 0;
  }

  Future<int> getStepsToday() async {
    return 0;
  }

  Future<Map<String, int>> getStepsHistory({int days = 7}) async {
    return {};
  }

  void dispose() {
    _hrTimer?.cancel();
  }
}
