import 'package:flutter/services.dart';

/// Streams live heart-rate readings pushed from a paired Wear OS watch.
///
/// The native [HeartRatePlugin] (Android) receives each BPM value over the
/// Google Play Services Data Layer and forwards it on this [EventChannel].
/// Every event is a single integer BPM. The stream only stays active while it
/// has a listener — subscribing registers the watch listener natively, and
/// cancelling removes it.
class WatchHeartRateService {
  WatchHeartRateService._();
  static final WatchHeartRateService instance = WatchHeartRateService._();

  static const EventChannel _channel =
      EventChannel('com.fyp.fitness_app/heartrate');

  Stream<int>? _stream;

  /// A broadcast stream of live BPM values from the watch.
  Stream<int> get heartRateStream {
    _stream ??= _channel
        .receiveBroadcastStream()
        .map((event) => (event as num).toInt());
    return _stream!;
  }
}
