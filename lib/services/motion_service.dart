import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:pedometer/pedometer.dart';

class MotionService {
  final StreamController<int> _stepController = StreamController<int>.broadcast();
  Stream<int> get stepStream => _stepController.stream;

  final StreamController<Map<String, double>> _motionController =
      StreamController<Map<String, double>>.broadcast();
  Stream<Map<String, double>> get motionStream => _motionController.stream;

  final StreamController<double> _accelMagnitudeController =
      StreamController<double>.broadcast();
  Stream<double> get accelMagnitudeStream => _accelMagnitudeController.stream;

  StreamSubscription<StepCount>? _pedometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;

  bool _isListening = false;

  /// [includeMotionSensors] controls whether the gyroscope/accelerometer
  /// streams also start. A caller that only wants [stepStream] (e.g. a
  /// workout that just needs a step count) can skip them, since otherwise
  /// they'd run for the whole session with nothing subscribed to consume them.
  void startListening({bool includeMotionSensors = true}) {
    if (_isListening) return;
    _isListening = true;

    _pedometerSubscription = Pedometer.stepCountStream.listen(
      (stepCount) => _stepController.add(stepCount.steps),
      onError: (e) => debugPrint('Pedometer error: $e'),
    );

    if (!includeMotionSensors) return;

    _gyroSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
      _motionController.add({
        'gyroX': event.x,
        'gyroY': event.y,
        'gyroZ': event.z,
      });
    });

    _accelSubscription =
        userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
      final magnitude =
          (event.x * event.x + event.y * event.y + event.z * event.z).clamp(0.0, 100.0);
      _accelMagnitudeController.add(magnitude);
    });
  }

  void stopListening() {
    _pedometerSubscription?.cancel();
    _gyroSubscription?.cancel();
    _accelSubscription?.cancel();
    _pedometerSubscription = null;
    _gyroSubscription = null;
    _accelSubscription = null;
    _isListening = false;
  }

  void dispose() {
    stopListening();
    _stepController.close();
    _motionController.close();
    _accelMagnitudeController.close();
  }
}
