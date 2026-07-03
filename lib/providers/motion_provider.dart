import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../services/motion_service.dart';

class MotionProvider extends ChangeNotifier {
  final MotionService _service = MotionService();
  StreamSubscription<int>? _stepSub;
  StreamSubscription<Map<String, double>>? _motionSub;

  int _stepsToday = 0;
  double _currentMotionIntensity = 0.0;
  bool _isTracking = false;

  int get stepsToday => _stepsToday;
  double get motionIntensity => _currentMotionIntensity;
  bool get isTracking => _isTracking;

  MotionProvider() {
    _stepSub = _service.stepStream.listen((steps) {
      if (_stepsToday == steps) return;
      _stepsToday = steps;
      notifyListeners();
    });

    _motionSub = _service.motionStream.listen((data) {
      final x = data['gyroX'] ?? 0;
      final y = data['gyroY'] ?? 0;
      final z = data['gyroZ'] ?? 0;
      final magnitude = (sqrt(x * x + y * y + z * z) / 10.0).clamp(0.0, 1.0);
      if ((magnitude - _currentMotionIntensity).abs() < 0.05) return;
      _currentMotionIntensity = magnitude;
      notifyListeners();
    });
  }

  void startTracking() {
    _isTracking = true;
    _service.startListening();
    notifyListeners();
  }

  void stopTracking() {
    _isTracking = false;
    _service.stopListening();
    notifyListeners();
  }

  @override
  void dispose() {
    _stepSub?.cancel();
    _motionSub?.cancel();
    _service.dispose();
    super.dispose();
  }
}
