import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/firebase_service.dart';
import '../models/place_model.dart';

class PlaceProvider extends ChangeNotifier {
  final LocationService _service = LocationService();
  final FirebaseService _firebaseService = FirebaseService();
  final List<Place> _visitedPlaces = [];
  StreamSubscription<Position>? _positionSub;
  Position? _currentPosition;
  Timer? _geofenceTimer;
  Position? _potentialPlaceCenter;
  String _userId = '';
  bool _isTracking = false;
  bool _hasPermission = false;
  bool _isLoading = false;

  List<Place> get visitedPlaces =>
      List.unmodifiable(_visitedPlaces);
  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  bool get hasPermission => _hasPermission;
  bool get isLoading => _isLoading;

  PlaceProvider() {
    _positionSub = LocationService.positionStream.listen((Position pos) {
      _currentPosition = pos;
      if (_isTracking) {
        _checkGeofence(pos);
      }
    });
    _service.startTracking();
  }

  void setUserId(String uid) {
    _userId = uid;
  }

  Future<bool> requestPermissions() async {
    _hasPermission = await _service.requestPermissions();
    notifyListeners();
    return _hasPermission;
  }

  Future<void> loadPlaces(String userId) async {
    _userId = userId;
    _isLoading = true;
    notifyListeners();
    try {
      _visitedPlaces.clear();
      final places = await _firebaseService.getPlaces(userId);
      _visitedPlaces.addAll(places);
    } catch (e, stack) {
      debugPrint('PlaceProvider.loadPlaces error: $e\n$stack');
    }
    _isLoading = false;
    notifyListeners();
  }

  void startTracking() {
    if (_isTracking) return;
    _isTracking = true;
    notifyListeners();
  }

  void stopTracking() {
    _isTracking = false;
    _geofenceTimer?.cancel();
    _geofenceTimer = null;
    _potentialPlaceCenter = null;
    notifyListeners();
  }

  void _checkGeofence(Position pos) {
    if (_potentialPlaceCenter == null) {
      _potentialPlaceCenter = pos;
      _geofenceTimer?.cancel();
      _geofenceTimer = Timer(const Duration(minutes: 15), () async {
        await _logPlace(_potentialPlaceCenter!);
        _potentialPlaceCenter = null;
        _geofenceTimer = null;
      });
    } else {
      final distance = Geolocator.distanceBetween(
        pos.latitude, pos.longitude,
        _potentialPlaceCenter!.latitude, _potentialPlaceCenter!.longitude,
      );
      if (distance > 100) {
        _potentialPlaceCenter = null;
        _geofenceTimer?.cancel();
        _geofenceTimer = null;
      }
    }
  }

  Future<void> _logPlace(Position center) async {
    final place = Place(
      id: 'place_${DateTime.now().millisecondsSinceEpoch}',
      userId: _userId,
      latitude: center.latitude,
      longitude: center.longitude,
      visitedAt: DateTime.now(),
    );
    _visitedPlaces.add(place);
    if (_userId.isNotEmpty) {
      await _firebaseService.savePlace(place);
    }
    notifyListeners();
  }

  Future<void> refresh(String userId) async {
    await loadPlaces(userId);
  }

  @override
  void dispose() {
    _geofenceTimer?.cancel();
    _positionSub?.cancel();
    _service.dispose();
    super.dispose();
  }
}
