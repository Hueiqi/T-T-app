import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothDeviceInfo {
  final String deviceId;
  final String name;
  final int rssi;

  BluetoothDeviceInfo({
    required this.deviceId,
    required this.name,
    required this.rssi,
  });
}

class BluetoothService {
  static const String _heartRateServiceUuid = '0000180d-0000-1000-8000-00805f9b34fb';
  static const String _heartRateMeasurementUuid = '00002a37-0000-1000-8000-00805f9b34fb';

  BluetoothDevice? _connectedDevice;
  StreamSubscription? _hrSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _scanSubscription;
  int _currentHeartRate = 0;
  bool _isScanning = false;
  bool _isConnected = false;

  int get currentHeartRate => _currentHeartRate;
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  String? get connectedDeviceName => _connectedDevice?.platformName;

  final StreamController<List<BluetoothDeviceInfo>> _devicesController =
      StreamController<List<BluetoothDeviceInfo>>.broadcast();
  Stream<List<BluetoothDeviceInfo>> get scanStream => _devicesController.stream;

  final StreamController<int> _heartRateController =
      StreamController<int>.broadcast();
  Stream<int> get heartRateStream => _heartRateController.stream;

  Future<bool> requestPermission() async {
    try {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      final scanOk = statuses[Permission.bluetoothScan]?.isGranted ?? false;
      final connectOk = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
      final locationOk = statuses[Permission.locationWhenInUse]?.isGranted ?? false;

      if ((scanOk && connectOk) || locationOk) {
        await FlutterBluePlus.turnOn();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void startScan() {
    if (_isScanning) return;
    _isScanning = true;
    _devicesController.add([]);

    _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      final scanned = <String, BluetoothDeviceInfo>{};
      for (final result in results) {
        final name = result.device.platformName;
        if (name.isNotEmpty) {
          scanned[result.device.remoteId.str] = BluetoothDeviceInfo(
            deviceId: result.device.remoteId.str,
            name: name,
            rssi: result.rssi,
          );
        }
      }
      _devicesController.add(scanned.values.toList());
    });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 30));
  }

  void stopScan() {
    _isScanning = false;
    _scanSubscription?.cancel();
    _scanSubscription = null;
    try {
      FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  Future<bool> connectToDevice(String deviceId) async {
    try {
      stopScan();

      final device = BluetoothDevice(remoteId: DeviceIdentifier(deviceId));
      _connectedDevice = device;

      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _isConnected = false;
          _currentHeartRate = 0;
          _connectedDevice = null;
        }
      });

      await device.connect(license: License.nonprofit, timeout: const Duration(seconds: 15));
      _isConnected = true;

      await _discoverAndSubscribe(device);
      return true;
    } catch (e) {
      _isConnected = false;
      _connectedDevice = null;
      return false;
    }
  }

  Future<void> _discoverAndSubscribe(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();

      for (final service in services) {
        if (service.uuid.str.toLowerCase() == _heartRateServiceUuid) {
          for (final characteristic in service.characteristics) {
            if (characteristic.uuid.str.toLowerCase() ==
                _heartRateMeasurementUuid) {
              await characteristic.setNotifyValue(true);

              _hrSubscription = characteristic.onValueReceived.listen(
                (value) {
                  _parseHeartRate(value);
                },
                onError: (e) {},
              );
              return;
            }
          }
        }
      }
    } catch (_) {}
  }

  void _parseHeartRate(List<int> data) {
    if (data.isEmpty) return;

    final flags = data[0];
    final isUint16 = (flags & 0x01) != 0;

    int hr;
    if (isUint16 && data.length >= 3) {
      hr = (data[1] << 8) | data[2];
    } else if (data.length >= 2) {
      hr = data[1];
    } else {
      return;
    }

    _currentHeartRate = hr;
    _heartRateController.add(hr);
  }

  Future<void> disconnect() async {
    _hrSubscription?.cancel();
    _hrSubscription = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    stopScan();

    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (_) {}
    }

    _isConnected = false;
    _connectedDevice = null;
    _currentHeartRate = 0;
  }

  void dispose() {
    _hrSubscription?.cancel();
    _connectionSubscription?.cancel();
    _scanSubscription?.cancel();
    _devicesController.close();
    _heartRateController.close();
    try {
      FlutterBluePlus.stopScan();
    } catch (_) {}
  }
}
