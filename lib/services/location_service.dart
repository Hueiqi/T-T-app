import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();
  static Stream<Position> get positionStream => _positionController.stream;

  StreamSubscription<Position>? _positionSubscription;

  Future<bool> requestPermissions() async {
    final permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<bool> requestAlwaysPermission() async {
    final permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always;
  }

  void startTracking({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilterMeters = 10,
  }) {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilterMeters,
      ),
    ).listen(
      (Position position) => _positionController.add(position),
      onError: (e) => print('Location error: $e'),
    );
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  double distanceBetween(Position from, Position to) {
    return Geolocator.distanceBetween(
      from.latitude, from.longitude,
      to.latitude, to.longitude,
    );
  }

  void dispose() {
    stopTracking();
    _positionController.close();
  }
}
