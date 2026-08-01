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

  /// Every heart rate reading this provider produces, whichever source is
  /// live — the simulation or a connected BLE strap. Consumers that just want
  /// "the current HR" (e.g. WorkoutProvider recording a session) should use
  /// this rather than [simulatedHeartRateStream], which stops emitting the
  /// moment a real strap takes over.
  Stream<int> get heartRateStream => _hrController.stream;

  final StreamController<int> _hrController =
      StreamController<int>.broadcast();

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
      // Delegates to updateStepsToday so step-source precedence lives in
      // exactly one place (see the note there about double-counting).
      await updateStepsToday();
    } catch (e) {
      debugPrint('Health Connect sync error: $e');
    }
  }

  // ── Initialisation (existing) ──
  Future<bool> initializeHealthAccess() async {
    try {
      // Our custom Health Connect plugin only reads steps; heart rate, sleep,
      // and workout data are read via the `health` package (HealthService),
      // filtered to Mi Fitness's records. Both must be authorized so Home
      // shows real data instead of falling back to the simulated default.
      // Authorize the Mi-Fitness-filtered service FIRST: authorizeHealthConnect()
      // triggers a step sync, and if this hasn't been authorized by then the
      // filtered read returns 0 and the sync falls back to the inflated
      // unfiltered total, briefly showing a wrong step count on Home.
      final legacyOk = await _healthService.authorize();

      await checkAvailability();
      bool healthConnectOk = false;
      if (_isHealthConnectAvailable) {
        healthConnectOk = await authorizeHealthConnect();
      }

      _isAuthorized = healthConnectOk || legacyOk;
      if (_isAuthorized) {
        _error = null;
        await Future.wait([
          updateHeartRate(),
          updateStepsToday(),
        ]);
      } else {
        _error = 'Health permission denied';
      }

      // Heart rate defaults to the simulation: Health Connect only receives
      // periodic HR syncs from the watch (often none at all), so without this
      // the display would sit on a static placeholder. A connected BLE
      // smartwatch is a genuine live source, so never override that.
      _startSimulationIfNoLiveSource();

      notifyListeners();
      return _isAuthorized;
    } catch (e) {
      _error = 'Failed to initialize health access: $e';
      // Still give the UI a live heart rate even if health init failed.
      _startSimulationIfNoLiveSource();
      notifyListeners();
      return false;
    }
  }

  void _startSimulationIfNoLiveSource() {
    if (_simulating) return;
    if (_smartwatchConnected && _bluetoothService.isConnected) return;
    _beginSimulation(gps: false);
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
      if (!_hrController.isClosed) _hrController.add(bpm);
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

      // A real BLE heart rate source takes over from the default simulation —
      // otherwise the sim timer keeps overwriting _currentHeartRate every
      // second and would fight the live readings below.
      stopHeartRateSimulation();

      _bleHrSubscription = _bluetoothService.heartRateStream.listen(
        (hr) {
          _currentHeartRate = hr;
          _heartRateHistory.add(hr);
          if (_heartRateHistory.length > 100) {
            _heartRateHistory =
                _heartRateHistory.sublist(_heartRateHistory.length - 100);
          }
          if (!_hrController.isClosed) _hrController.add(hr);
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
    // The live source is gone — fall back to the default simulation so the
    // heart rate display stays active rather than freezing on the last value.
    _startSimulationIfNoLiveSource();
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
      // Prefer the Mi-Fitness-filtered source. Health Connect is a shared
      // store: the watch, the phone's built-in pedometer, and any other
      // fitness app all write their own StepsRecords for the same walk.
      // Summing every record (as the raw Health Connect read does) counts
      // the same steps two or three times over, so filter to the watch.
      final watchSteps = await _healthService.getStepsToday();
      final rawTotal = _isHealthConnectAuthorized
          ? await _healthConnectService.getStepsToday()
          : -1;
      debugPrint('STEPS DEBUG: miFitnessFiltered=$watchSteps unfilteredHealthConnect=$rawTotal');
      if (watchSteps > 0) {
        _stepsToday = watchSteps;
        notifyListeners();
        return;
      }
      // Nothing from the watch (not worn / not synced yet) — fall back to
      // the unfiltered Health Connect total rather than showing zero.
      if (_isHealthConnectAuthorized) {
        _stepsToday = await _healthConnectService.getStepsToday();
        notifyListeners();
      }
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

  /// Resets per-account readings so a newly signed-in user starts at zero
  /// steps with no inherited heart-rate history, rather than seeing whatever
  /// the previous session left in memory.
  ///
  /// Device-level state (Health Connect authorisation, a paired BLE strap) is
  /// deliberately left alone — that belongs to the phone, not to the account.
  void clear() {
    _stepsToday = 0;
    _stepsHistory = {};
    _heartRateHistory = [];
    _error = null;
    notifyListeners();
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
    _hrController.close();
    _bluetoothService.dispose();
    super.dispose();
  }
}