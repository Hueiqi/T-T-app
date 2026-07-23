import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/health_service.dart';
import '../services/health_connect_service.dart';
import '../services/bluetooth_service.dart';

class HealthProvider extends ChangeNotifier {
  final HealthService _healthService = HealthService();
  final HealthConnectService _healthConnectService = HealthConnectService();
  final BluetoothService _bluetoothService = BluetoothService();

  // ── Health Connect state ──
  bool _isHealthConnectAvailable = false;
  bool _isHealthConnectAuthorized = false;

  // ── Heart-rate simulation (demo mode) ──
  Timer? _simTimer;
  StreamSubscription<Position>? _gpsSub;
  final _random = Random();
  bool _simulating = false;
  bool _gpsMode = false;
  double _simCurrent = 78;
  double _targetHr = 78;
  Position? _lastPos;
  DateTime? _lastPosTime;
  final StreamController<int> _simController =
      StreamController<int>.broadcast();

  bool get isSimulating => _simulating;
  bool get isGpsSimulation => _gpsMode;
  Stream<int> get simulatedHeartRateStream => _simController.stream;

  // ── Public state ──
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

  // ── Getters ──
  bool get isHealthConnectAvailable => _isHealthConnectAvailable;
  bool get isHealthConnectAuthorized => _isHealthConnectAuthorized;
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

  // ── Health Connect methods ──
  Future<bool> checkAvailability() async {
    try {
      _isHealthConnectAvailable = await _healthConnectService.isAvailable;
      notifyListeners();
      return _isHealthConnectAvailable;
    } catch (e) {
      _isHealthConnectAvailable = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> authorizeHealthConnect() async {
    try {
      _isHealthConnectAuthorized = await _healthConnectService.requestPermissions();
      if (_isHealthConnectAuthorized) {
        await syncHealthData();
      }
      notifyListeners();
      return _isHealthConnectAuthorized;
    } catch (e) {
      _error = 'Health Connect authorization failed: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> syncHealthData() async {
    if (!_isHealthConnectAuthorized) return;
    try {
      final steps = await _healthConnectService.getStepsToday();
      if (steps > 0) {
        _stepsToday = steps;
      }
      // Optionally sync heart rate from Health Connect
      // final hr = await _healthConnectService.getHeartRateToday();
      // if (hr.isNotEmpty) { ... }
      notifyListeners();
    } catch (e) {
      debugPrint('Health Connect sync error: $e');
    }
  }

  // ── Initialisation (existing) ──
  Future<bool> initializeHealthAccess() async {
    try {
      // First check Health Connect
      await checkAvailability();
      if (_isHealthConnectAvailable) {
        final authorized = await authorizeHealthConnect();
        if (authorized) {
          _isAuthorized = true;
          _error = null;
          await syncHealthData();
          notifyListeners();
          return true;
        }
      }
      // Fallback to legacy health service (if any)
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

  // ── Heart-rate simulation ──
  void startHeartRateSimulation() => _beginSimulation(gps: false);

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
        final speed = _speedFrom(pos);
        _targetHr = (70 + speed * 20).clamp(65, 175);
      },
      onError: (_) {},
    );
  }

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
    return speed.clamp(0, 8);
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
        _targetHr = (_targetHr + _random.nextInt(3) - 1).clamp(62, 150);
      }
      _simCurrent += (_targetHr - _simCurrent) * 0.15;
      final bpm = (_simCurrent + _random.nextInt(3) - 1).round().clamp(50, 185);
      _currentHeartRate = bpm;
      _heartRateHistory.add(bpm);
      if (_heartRateHistory.length > 100) {
        _heartRateHistory = _heartRateHistory.sublist(_heartRateHistory.length - 100);
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

  // ── Bluetooth / Smartwatch ──
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

  // ── Legacy health service (fallback) ──
  Future<int> updateHeartRate() async {
    try {
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
      // Prefer Health Connect if available
      if (_isHealthConnectAuthorized) {
        final steps = await _healthConnectService.getStepsToday();
        if (steps > 0) {
          _stepsToday = steps;
          notifyListeners();
          return;
        }
      }
      // Fallback to legacy
      _stepsToday = await _healthService.getStepsToday();
      notifyListeners();
    } catch (e) {
      // silent fail
    }
  }

  Future<void> updateStepsHistory() async {
    try {
      _stepsHistory = await _healthService.getStepsHistory();
      notifyListeners();
    } catch (e) {
      // silent fail
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