import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/health_service.dart';
import '../services/bluetooth_service.dart';

class HealthProvider extends ChangeNotifier {
  final HealthService _healthService = HealthService();
  final BluetoothService _bluetoothService = BluetoothService();

  // ── Heart-rate simulation (demo mode) ──
  // Produces a realistic live BPM when no real HR source is available (e.g. a
  // vendor-locked watch, or Health Connect not sharing HR yet). Two modes:
  //   • random  — gentle baseline wander (startHeartRateSimulation)
  //   • gps     — target BPM derived from your movement speed, so walking/
  //               running raises HR and standing still lowers it
  //               (startGpsHeartRateSimulation)
  // Both feed the same fields/stream as real data, so the dashboard card and
  // the workout screen update together.
  Timer? _simTimer;
  StreamSubscription<Position>? _gpsSub;
  final _random = Random();
  bool _simulating = false;
  bool _gpsMode = false;
  double _simCurrent = 78; // eased current bpm (double for smooth ramping)
  double _targetHr = 78; // bpm the current value eases toward
  Position? _lastPos;
  DateTime? _lastPosTime;
  final StreamController<int> _simController =
      StreamController<int>.broadcast();

  bool get isSimulating => _simulating;
  bool get isGpsSimulation => _gpsMode;

  /// Emits simulated BPM values (~1 Hz) while a simulation is running.
  Stream<int> get simulatedHeartRateStream => _simController.stream;

  /// Random-wander demo heart rate.
  void startHeartRateSimulation() => _beginSimulation(gps: false);

  /// Movement-driven demo heart rate: reads GPS speed and maps it to a target
  /// BPM (still ≈ resting, walking ≈ moderate, running ≈ high).
  Future<void> startGpsHeartRateSimulation() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _error = 'Location permission is needed to simulate from movement.';
      notifyListeners();
      return;
    }

    _beginSimulation(gps: true);

    _gpsSub?.cancel();
    _lastPos = null;
    _lastPosTime = null;
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).listen(
      (pos) {
        final speed = _speedFrom(pos); // m/s
        // ~70 bpm at rest, rising ~20 bpm per m/s of pace.
        _targetHr = (70 + speed * 20).clamp(65, 175);
      },
      onError: (_) {},
    );
  }

  /// Best-effort speed in m/s: trust the OS speed when valid, else derive it
  /// from the distance between consecutive fixes.
  double _speedFrom(Position pos) {
    double speed = (pos.speed.isFinite && pos.speed > 0) ? pos.speed : 0;
    final now = DateTime.now();
    if (speed == 0 && _lastPos != null && _lastPosTime != null) {
      final meters = Geolocator.distanceBetween(
        _lastPos!.latitude,
        _lastPos!.longitude,
        pos.latitude,
        pos.longitude,
      );
      final secs = now.difference(_lastPosTime!).inMilliseconds / 1000.0;
      if (secs > 0) speed = meters / secs;
    }
    _lastPos = pos;
    _lastPosTime = now;
    return speed.clamp(0, 8); // cap absurd GPS jumps
  }

  void _beginSimulation({required bool gps}) {
    _gpsMode = gps;
    if (_simulating) {
      notifyListeners();
      return;
    }
    _simulating = true;
    _simCurrent = 78;
    _targetHr = 78;
    _simTimer?.cancel();
    _simTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_gpsMode) {
        // Random mode: drift the target gently.
        _targetHr = (_targetHr + _random.nextInt(3) - 1).clamp(62, 150);
      }
      // Ease the current value toward the target (~15%/s) so HR ramps and
      // recovers naturally instead of jumping.
      _simCurrent += (_targetHr - _simCurrent) * 0.15;
      final bpm = (_simCurrent + _random.nextInt(3) - 1).round().clamp(50, 185);

      _currentHeartRate = bpm;
      _heartRateHistory.add(bpm);
      if (_heartRateHistory.length > 100) {
        _heartRateHistory =
            _heartRateHistory.sublist(_heartRateHistory.length - 100);
      }
      if (!_simController.isClosed) _simController.add(bpm);
      notifyListeners();
    });
    notifyListeners();
  }

  void stopHeartRateSimulation() {
    _simulating = false;
    _gpsMode = false;
    _simTimer?.cancel();
    _simTimer = null;
    _gpsSub?.cancel();
    _gpsSub = null;
    notifyListeners();
  }

  int _currentHeartRate = 75;
  List<int> _heartRateHistory = [];
  int _stepsToday = 0;
  Map<String, int> _stepsHistory = {};
  bool _isMonitoring = false;
  bool _isAuthorized = false;
  bool _smartwatchConnected = false;
  bool _isScanning = false;
  bool _isConnecting = false;
  String? _error;
  String? _connectedDeviceName;
  List<BluetoothDeviceInfo> _discoveredDevices = [];
  StreamSubscription? _bleHrSubscription;
  StreamSubscription? _bleScanSubscription;

  int get currentHeartRate => _currentHeartRate;
  List<int> get heartRateHistory => _heartRateHistory;
  int get stepsToday => _stepsToday;
  Map<String, int> get stepsHistory => _stepsHistory;
  bool get isMonitoring => _isMonitoring;
  bool get isAuthorized => _isAuthorized;
  bool get smartwatchConnected => _smartwatchConnected;
  bool get isScanning => _isScanning;
  bool get isConnecting => _isConnecting;
  String? get error => _error;
  String? get connectedDeviceName => _connectedDeviceName;
  List<BluetoothDeviceInfo> get discoveredDevices => _discoveredDevices;

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

  void startScan() {
    _isScanning = true;
    _discoveredDevices = [];
    _error = null;
    notifyListeners();

    _bleScanSubscription = _bluetoothService.scanStream.listen(
      (devices) {
        _discoveredDevices = devices;
        notifyListeners();
      },
      onError: (e) {
        _error = 'Scan error: $e';
        _isScanning = false;
        notifyListeners();
      },
    );

    _bluetoothService.startScan();
  }

  void stopScan() {
    _isScanning = false;
    _bleScanSubscription?.cancel();
    _bleScanSubscription = null;
    _bluetoothService.stopScan();
    notifyListeners();
  }

  Future<bool> connectToDevice(String deviceId) async {
    _isConnecting = true;
    _error = null;
    notifyListeners();

    final success = await _bluetoothService.connectToDevice(deviceId);
    if (success) {
      _smartwatchConnected = true;
      _connectedDeviceName = _bluetoothService.connectedDeviceName;
      _isConnecting = false;
      _isScanning = false;
      _bleScanSubscription?.cancel();
      _bleScanSubscription = null;

      _bleHrSubscription = _bluetoothService.heartRateStream.listen(
        (hr) {
          _currentHeartRate = hr;
          _heartRateHistory.add(hr);
          if (_heartRateHistory.length > 100) {
            _heartRateHistory = _heartRateHistory.sublist(-100);
          }
          notifyListeners();
        },
        onError: (e) {
          _error = 'Heart rate stream error';
          notifyListeners();
        },
      );

      notifyListeners();
    } else {
      _isConnecting = false;
      _error = 'Failed to connect to device';
      notifyListeners();
    }
    return success;
  }

  Future<bool> connectSmartwatch() async {
    try {
      final authorized = await _healthService.authorize();
      if (authorized) {
        _smartwatchConnected = true;
        _isAuthorized = true;
        _error = null;
        await updateHeartRate();
      } else {
        _error = 'Smartwatch permission denied. Try BLE connection instead.';
      }
      notifyListeners();
      return _smartwatchConnected;
    } catch (e) {
      _error = 'Failed to connect smartwatch: $e';
      notifyListeners();
      return false;
    }
  }

  void disconnectSmartwatch() {
    _bleHrSubscription?.cancel();
    _bleHrSubscription = null;
    _bleScanSubscription?.cancel();
    _bleScanSubscription = null;

    _bluetoothService.disconnect();

    _smartwatchConnected = false;
    _isAuthorized = false;
    _isScanning = false;
    _isConnecting = false;
    _connectedDeviceName = null;
    _discoveredDevices = [];
    _error = null;

    stopMonitoring();
    notifyListeners();
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
      // Don't overwrite a live BLE reading or a running simulation with a
      // (possibly stale/empty) Health Connect read.
      if (_simulating) return _currentHeartRate;
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
    if (_smartwatchConnected && _bluetoothService.isConnected) {
      _isMonitoring = true;
      notifyListeners();
      return;
    }
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
    if (_isMonitoring && !_bluetoothService.isConnected) {
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
    _simTimer?.cancel();
    _gpsSub?.cancel();
    _simController.close();
    _bluetoothService.dispose();
    super.dispose();
  }
}
