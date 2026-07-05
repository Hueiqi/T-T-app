import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class HealthConnectService {
  static const _channel = MethodChannel('health_connect');

  Future<bool> get isAvailable async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final available = await _channel.invokeMethod<bool>('getHealthConnectAvailability');
      return available ?? false;
    } catch (e) {
      debugPrint('HealthConnect availability check failed: $e');
      return false;
    }
  }

  Future<int> getStepsToday() async {
    if (defaultTargetPlatform != TargetPlatform.android) return 0;
    try {
      final steps = await _channel.invokeMethod<int>('getStepsToday');
      return steps ?? 0;
    } catch (e) {
      debugPrint('HealthConnect getStepsToday failed: $e');
      return 0;
    }
  }

  Future<bool> requestPermissions() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final result = await _channel.invokeMethod<bool>('requestPermissions');
      return result ?? false;
    } catch (e) {
      debugPrint('HealthConnect requestPermissions failed: $e');
      return false;
    }
  }
}
