import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/health_service.dart';

class HealthProvider extends ChangeNotifier {
  final HealthService _healthService = HealthService();
  final BluetoothService _bluetoothService = BluetoothService();

  int _currentHeartRate = 75;
  List<int> _heartRateHistory = [];
  int _stepsToday = 0;
  Map<String, int> _stepsHistory = {};
  bool _isMonitoring = false;
  bool _isAuthorized = false;
  String? _error;

  int get currentHeartRate => _currentHeartRate;
  List<int> get heartRateHistory => _heartRateHistory;
  int get stepsToday => _stepsToday;
  Map<String, int> get stepsHistory => _stepsHistory;
  bool get isMonitoring => _isMonitoring;
  bool get isAuthorized => _isAuthorized;
  String? get error => _error;

  int get averageHeartRate {
    if (_heartRateHistory.isEmpty) return _currentHeartRate;
    final sum = _heartRateHistory.fold<int>(0, (prev, hr) => prev + hr);
    return (sum / _heartRateHistory.length).toInt();
  }

  String get heartRateCategory {
    if (_currentHeartRate < 60) return 'resting';
    if (_currentHeartRate < 100) return 'light';
    if (_currentHeartRate < 130) return 'moderate';
    if (_currentHeartRate < 160) return 'vigorous';
    return 'max';
  }

  Future<bool> initializeHealthAccess() async {
    try {
      _isAuthorized = await _healthService.authorize();
      if (_isAuthorized) {
        _error = null;
        await Future.wait([
          updateHeartRate(),
          updateStepsToday(),
        ]);
      } else {
        _error = 'Health permission denied';
      }
      notifyListeners();
      return _isAuthorized;
    } catch (e) {
      _error = 'Failed to initialize health access: $e';
      notifyListeners();
      return false;
    }
  }

  Future<int> updateHeartRate() async {
    try {
      if (_smartwatchConnected && _bluetoothService.isConnected) {
        return _currentHeartRate;
      }
      _currentHeartRate = await _healthService.getCurrentHeartRate();
      _error = null;
      notifyListeners();
      return _currentHeartRate;
    } catch (e) {
      _error = 'Failed to get heart rate: $e';
      notifyListeners();
      return _currentHeartRate;
    }
  }

  Future<void> updateStepsToday() async {
    try {
      _stepsToday = await _healthService.getStepsToday();
      notifyListeners();
    } catch (e) {
      // silently fail
    }
  }

  Future<void> updateStepsHistory() async {
    try {
      _stepsHistory = await _healthService.getStepsHistory();
      notifyListeners();
    } catch (e) {
      // silently fail
    }
  }

  void startMonitoring() {
    if (_isAuthorized && !_isMonitoring) {
      _isMonitoring = true;
      _healthService.startHeartRateMonitoring((hr) {
        _currentHeartRate = hr;
        _heartRateHistory = _healthService.heartRateHistory;
        notifyListeners();
      });
      notifyListeners();
    }
  }

  void stopMonitoring() {
    if (_isMonitoring) {
      _healthService.stopHeartRateMonitoring();
    }
    _isMonitoring = false;
    notifyListeners();
  }

  Map<String, int> getHeartRateStats() {
    if (_heartRateHistory.isEmpty) {
      return {
        'current': _currentHeartRate,
        'average': _currentHeartRate,
        'min': _currentHeartRate,
        'max': _currentHeartRate,
      };
    }
    return {
      'current': _currentHeartRate,
      'average': averageHeartRate,
      'min': _heartRateHistory.reduce((a, b) => a < b ? a : b),
      'max': _heartRateHistory.reduce((a, b) => a > b ? a : b),
    };
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _bleHrSubscription?.cancel();
    _bleScanSubscription?.cancel();
    _bluetoothService.dispose();
    super.dispose();
  }
}
