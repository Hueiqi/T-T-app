// lib/services/bluetooth_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

/// Minimal representation of a discovered BLE device.
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

/// Stub Bluetooth service – replace with real BLE implementation later.
class BluetoothService {
  bool get isConnected => false;
  String? get connectedDeviceName => null;

  // Stream that emits discovered devices during scanning.
  Stream<List<BluetoothDeviceInfo>> get scanStream =>
      Stream.empty(); // no devices discovered

  void startScan() {
    debugPrint('BluetoothService.startScan() called (stub)');
  }

  void stopScan() {
    debugPrint('BluetoothService.stopScan() called (stub)');
  }

  Future<bool> connectToDevice(String deviceId) async {
    debugPrint('BluetoothService.connectToDevice($deviceId) called (stub)');
    return false;
  }

  void disconnect() {
    debugPrint('BluetoothService.disconnect() called (stub)');
  }

  // Heart rate stream – emits integer BPM values.
  Stream<int> get heartRateStream => Stream.empty();

  void dispose() {
    debugPrint('BluetoothService.dispose() called (stub)');
  }
}