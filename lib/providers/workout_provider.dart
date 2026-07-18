import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../services/health_service.dart';
import '../services/health_connect_service.dart';
import '../services/spotify_service.dart';
import '../services/firebase_service.dart';
import '../models/workout_model.dart';
import '../models/sleep_model.dart';
import '../models/music_track_model.dart';
import '../config/constants.dart';
import 'package:uuid/uuid.dart';

class WorkoutProvider extends ChangeNotifier {
  final HealthService _healthService = HealthService();
  final HealthConnectService _hcService = HealthConnectService();
  final SpotifyService _spotifyService = SpotifyService();
  final FirebaseService _firebaseService = FirebaseService();
  final Uuid _uuid = const Uuid();
  final bool _isWeb = kIsWeb;

  bool _isWorkoutActive = false;
  int _currentHeartRate = 0;
  List<int> _heartRateHistory = [];
  DateTime? _workoutStartTime;
  Workout? _currentWorkout;
  String _currentHrZone = 'Warm up';
  String _currentTrackName = '';
  String _currentTrackArtist = '';
  String _currentMusicZone = '';
  String _sleepReadiness = 'moderate';
  SleepData? _lastNightSleep;
  Timer? _bpmAdjustTimer;
  Timer? _manualOverrideTimer;
  StreamSubscription? _extHrSub;
  bool _smartwatchConnected = false;
  String? _spotifyError;
  bool _manualOverrideActive = false;
  List<MusicTrack> _searchResults = [];
  bool _isSearching = false;

  String _workoutType = 'cardio';
  double _distance = 0.0;
  final List<Map<String, double>> _routePoints = [];
  StreamSubscription<Position>? _positionSub;
  Timer? _stepPollTimer;
  int _workoutSteps = 0;
  Position? _currentPosition;
  DateTime? _workoutStartDate;

  bool get isWorkoutActive => _isWorkoutActive;
  int get currentHeartRate => _currentHeartRate;
  List<int> get heartRateHistory => _heartRateHistory;
  String get currentHrZone => _currentHrZone;
  String get sleepReadiness => _sleepReadiness;
  SleepData? get lastNightSleep => _lastNightSleep;
  Workout? get currentWorkout => _currentWorkout;
  String get currentTrackName => _currentTrackName;
  String get currentTrackArtist => _currentTrackArtist;
  String get currentMusicZone => _currentMusicZone;
  String? get spotifyError => _spotifyError;
  bool get manualOverrideActive => _manualOverrideActive;
  List<MusicTrack> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  String get workoutType => _workoutType;
  double get distance => _distance;
  List<Map<String, double>> get routePoints => _routePoints;
  int get workoutSteps => _workoutSteps;
  Position? get currentPosition => _currentPosition;

  String _hrZoneToMusicZone(String zone) {
    switch (zone) {
      case 'Warm up':
        return 'Chill vibes';
      case 'Fat Burn':
        return 'Dance energy';
      case 'Cardio':
        return 'Rock power';
      case 'Peak':
        return 'Maximum intensity';
      default:
        return 'Workout mix';
    }
  }

  Future<void> loadSleepData(String userId) async {
    _lastNightSleep =
        await _healthService.getLastNightSleep(userId) ??
        await _firebaseService.getLatestSleep(userId);
    _sleepReadiness = _lastNightSleep?.readinessLevel ?? 'moderate';
    notifyListeners();
  }

  Future<void> startWorkout(String userId, {bool spotifyConnected = false}) async {
    // 1. Check smartwatch connection via health package
    bool hrAvailable = false;
    if (!_isWeb) {
      try {
        hrAvailable = await _healthService.authorize();
      } catch (_) {
        hrAvailable = false;
      }
    }
    _smartwatchConnected = hrAvailable;

    // 2. Request Health Connect permissions for reading + writing
    if (!_isWeb) {
      try {
        final hcAvailable = await _hcService.isAvailable;
        if (hcAvailable) {
          await _hcService.requestPermissions();
        }
      } catch (_) {}
    }

    // 2. Create workout session
    _isWorkoutActive = true;
    _workoutStartTime = DateTime.now();
    _workoutStartDate = _workoutStartTime;
    _heartRateHistory = [];
    _currentTrackName = '';
    _currentTrackArtist = '';
    _currentMusicZone = '';
    _spotifyError = null;
    _manualOverrideActive = false;
    _manualOverrideTimer?.cancel();
    _distance = 0.0;
    _routePoints.clear();
    _workoutSteps = 0;
    _currentPosition = null;
    _currentWorkout = Workout(
      id: _uuid.v4(),
      userId: userId,
      startTime: _workoutStartTime!,
      sleepReadiness: _sleepReadiness,
      type: workoutType,
    );

    try {
      await _firebaseService.saveWorkout(_currentWorkout!);
    } catch (_) {}

    // 3. Start GPS tracking for distance and route
    _startGpsTracking();

    // 4. Start step polling from Health Connect every 10 seconds
    _startStepPolling();

    // 5. Start HR streaming every 5 seconds (if smartwatch available)
    if (_smartwatchConnected) {
      _healthService.startHeartRateMonitoring((int hr) {
        _currentHeartRate = hr;
        _heartRateHistory.add(hr);
        final newZone = AppConstants.getHrZone(hr);
        if (newZone != _currentHrZone) {
          _currentMusicZone = _hrZoneToMusicZone(newZone);
        }
        _currentHrZone = newZone;
        notifyListeners();
      });
    }

    // 6. Start Spotify if connected
    if (spotifyConnected) {
      try {
        await _spotifyService.authenticate();
      } catch (_) {
        _spotifyError = 'Music unavailable. Workout continues without music.';
      }
    }

    if (spotifyConnected && _spotifyError == null) {
      final initialHr = _currentHeartRate > 0 ? _currentHeartRate : 90;
      await _adjustMusicForHeartRate(initialHr);
    }

    _bpmAdjustTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_heartRateHistory.isEmpty) return;
      if (_manualOverrideActive) return;
      final latestHr = _heartRateHistory.last;
      await _adjustMusicForHeartRate(latestHr);
    });

    notifyListeners();
  }

  void _startGpsTracking() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    // Get initial position
    try {
      final initialPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _currentPosition = initialPos;
      _routePoints.add({
        'lat': initialPos.latitude,
        'lng': initialPos.longitude,
      });
      notifyListeners();
    } catch (_) {}

    // Listen to position updates
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(
      (Position position) {
        if (!_isWorkoutActive) return;
        _currentPosition = position;

        if (_routePoints.isNotEmpty) {
          final lastPoint = _routePoints.last;
          final distanceDelta = Geolocator.distanceBetween(
            lastPoint['lat']!,
            lastPoint['lng']!,
            position.latitude,
            position.longitude,
          );

          // Only add point if moved more than 3 meters (filter GPS noise)
          if (distanceDelta > 3) {
            _routePoints.add({
              'lat': position.latitude,
              'lng': position.longitude,
            });
            _distance += distanceDelta / 1000.0; // convert meters to km
            notifyListeners();
          }
        }
      },
      onError: (e) {
        debugPrint('GPS tracking error: $e');
      },
    );
  }

  void _startStepPolling() {
    _stepPollTimer?.cancel();
    _stepPollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!_isWorkoutActive || _workoutStartDate == null) return;
      try {
        final steps = await _healthService.getStepsBetween(
          _workoutStartDate!,
          DateTime.now(),
        );
        if (steps > 0) {
          _workoutSteps = steps;
          notifyListeners();
        }
      } catch (_) {}
    });

    // Also fetch immediately
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_isWorkoutActive || _workoutStartDate == null) return;
      try {
        final steps = await _healthService.getStepsBetween(
          _workoutStartDate!,
          DateTime.now(),
        );
        if (steps > 0) {
          _workoutSteps = steps;
          notifyListeners();
        }
      } catch (_) {}
    });
  }

  void addRoutePoint(double latitude, double longitude, double distanceDelta) {
    _routePoints.add({'lat': latitude, 'lng': longitude});
    _distance += distanceDelta;
    notifyListeners();
  }

  /// Writes the completed workout session to Health Connect so it appears
  /// in the user's health data alongside data from other apps (Mi Fitness, etc.).
  Future<void> _writeWorkoutToHealthConnect({
    required DateTime startTime,
    required DateTime endTime,
    required double caloriesBurned,
    required double distanceMeters,
    required int steps,
  }) async {
    if (_isWeb) return;
    try {
      final hcAvailable = await _hcService.isAvailable;
      if (!hcAvailable) return;

      // Map workout type to HC exercise type: 0=other, 1=running, 2=walking, 3=cardio
      int exerciseType;
      switch (_workoutType) {
        case 'running':
          exerciseType = 1;
          break;
        case 'walking':
          exerciseType = 2;
          break;
        default:
          exerciseType = 3;
      }

      // Write exercise session (includes calories + estimated steps from distance)
      await _hcService.writeExerciseSession(
        startTime: startTime,
        endTime: endTime,
        title: 'T&T Fitness - ${_workoutType[0].toUpperCase()}${_workoutType.substring(1)}',
        exerciseType: exerciseType,
        caloriesBurned: caloriesBurned,
        distanceMeters: distanceMeters,
      );

      // Write actual step count if we have it (from Health Connect watch data)
      if (steps > 0) {
        await _hcService.writeSteps(
          startTime: startTime,
          endTime: endTime,
          count: steps,
        );
      }

      debugPrint('HealthConnect: Workout written successfully');
    } catch (e) {
      debugPrint('HealthConnect: Failed to write workout: $e');
    }
  }

  Future<void> _adjustMusicForHeartRate(int heartRate) async {
    if (_spotifyError != null) return;

    final targetBpm = AppConstants.calculateTargetBpm(heartRate);
    _currentMusicZone = _hrZoneToMusicZone(AppConstants.getHrZone(heartRate));

    try {
      _spotifyError = null;
      final tracks = await _spotifyService.getTracksByBpm(targetBpm);
      if (tracks.isNotEmpty) {
        await _spotifyService.playTrack(tracks.first.spotifyUri);
        _currentTrackName = tracks.first.name;
        _currentTrackArtist = tracks.first.artist;
      }
    } catch (e) {
      _spotifyError = 'Music unavailable. Workout continues without music.';
      debugPrint('Spotify BPM adjustment error: $e');
    }
    notifyListeners();
  }

  Future<void> playSelectedTrack(MusicTrack track) async {
    if (_spotifyError != null) return;

    try {
      await _spotifyService.playTrack(track.spotifyUri);
      _currentTrackName = track.name;
      _currentTrackArtist = track.artist;
      _manualOverrideActive = true;
      notifyListeners();

      _manualOverrideTimer?.cancel();
      _manualOverrideTimer = Timer(const Duration(seconds: 30), () {
        _manualOverrideActive = false;
        notifyListeners();
      });
    } catch (e) {
      _spotifyError = 'Music unavailable. Workout continues without music.';
      notifyListeners();
    }
  }

  Future<void> searchSongs(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }
    _isSearching = true;
    notifyListeners();
    try {
      _searchResults = await _spotifyService.searchTracks(query);
    } catch (_) {
      _searchResults = [];
    }
    _isSearching = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> endWorkout({
    required String gender,
    double? manualCalories,
  }) async {
    _isWorkoutActive = false;
    _healthService.stopHeartRateMonitoring();
    _extHrSub?.cancel();
    _extHrSub = null;
    _positionSub?.cancel();
    _positionSub = null;
    _stepPollTimer?.cancel();
    _stepPollTimer = null;
    _currentTrackName = '';
    _currentTrackArtist = '';
    _currentMusicZone = '';
    _bpmAdjustTimer?.cancel();
    _manualOverrideTimer?.cancel();
    _manualOverrideActive = false;

    try {
      await _spotifyService.pausePlayback();
    } catch (_) {}

    if (_currentWorkout == null) {
      notifyListeners();
      return {'caloriesBurned': 0.0, 'avgHr': 0, 'maxHr': 0, 'durationMinutes': 0};
    }

    final endTime = DateTime.now();
    final durationMinutes = endTime.difference(_currentWorkout!.startTime).inMinutes;
    final durationSeconds = endTime.difference(_currentWorkout!.startTime).inSeconds;

    final hasHrData = _heartRateHistory.isNotEmpty;
    final avgHr = hasHrData
        ? _heartRateHistory.reduce((a, b) => a + b) ~/ _heartRateHistory.length
        : 0;
    final maxHr = hasHrData
        ? _heartRateHistory.reduce((a, b) => a > b ? a : b)
        : 0;
    final minHr = hasHrData
        ? _heartRateHistory.reduce((a, b) => a < b ? a : b)
        : 0;

    double caloriesBurned;
    if (manualCalories != null) {
      caloriesBurned = manualCalories;
    } else if (!hasHrData || durationMinutes == 0) {
      caloriesBurned = 0;
    } else {
      final factor = gender == 'female' ? 0.045 : 0.05;
      caloriesBurned = avgHr * durationMinutes * factor;
    }

    final sampledReadings = _heartRateHistory.length > 100
        ? _heartRateHistory.asMap().entries.where((e) => e.key % 3 == 0).map((e) => e.value).toList()
        : _heartRateHistory;

    _currentWorkout = Workout(
      id: _currentWorkout!.id,
      userId: _currentWorkout!.userId,
      startTime: _currentWorkout!.startTime,
      endTime: endTime,
      type: _workoutType,
      heartRateReadings: sampledReadings,
      avgHeartRate: avgHr,
      maxHeartRate: maxHr,
      minHeartRate: minHr,
      caloriesBurned: caloriesBurned,
      musicPlaylistId: '',
      sleepReadiness: _sleepReadiness,
      notes: '',
      distance: _distance,
      routePoints: List<Map<String, double>>.from(_routePoints),
    );

    await _firebaseService.saveWorkoutEndData(_currentWorkout!, caloriesBurned);

    // Write workout data to Health Connect
    await _writeWorkoutToHealthConnect(
      startTime: _currentWorkout!.startTime,
      endTime: endTime,
      caloriesBurned: caloriesBurned,
      distanceMeters: _distance * 1000,
      steps: _workoutSteps,
    );

    notifyListeners();

    return {
      'caloriesBurned': caloriesBurned,
      'avgHr': avgHr,
      'maxHr': maxHr,
      'minHr': minHr,
      'durationMinutes': durationMinutes,
      'durationSeconds': durationSeconds,
      'hasHrData': hasHrData,
      'distance': _distance,
      'routePoints': List<Map<String, double>>.from(_routePoints),
      'workout': _currentWorkout!,
      'workoutSteps': _workoutSteps,
    };
  }

  Future<void> skipToNextMusic() async {
    if (_spotifyError != null) return;
    final currentHr = _currentHeartRate > 0 ? _currentHeartRate : 90;
    final targetBpm = AppConstants.calculateTargetBpm(currentHr);
    try {
      final tracks = await _spotifyService.getTracksByBpm(targetBpm);
      if (tracks.isNotEmpty) {
        _currentTrackName = tracks.first.name;
        _currentTrackArtist = tracks.first.artist;
        await _spotifyService.playTrack(tracks.first.spotifyUri);
        notifyListeners();
      }
    } catch (_) {}
  }

  List<Workout> _osWorkouts = [];

  List<Workout> get osWorkouts => _osWorkouts;

  Future<void> loadOSWorkoutSessions(String userId) async {
    if (_isWeb) return;
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    try {
      await _healthService.authorize();
      final data = await _healthService.getWorkoutSessions(weekAgo, now);
      for (final session in data) {
        if (!_workouts.any((w) => w.startTime == session.startTime)) {
          _workouts.add(session);
        }
      }
      _osWorkouts = data;
      notifyListeners();
    } catch (_) {}
  }

  Workout? _recentWorkout;
  double _todayCaloriesBurned = 0;
  List<Workout> _workouts = [];

  Workout? get recentWorkout => _recentWorkout;
  double get todayCaloriesBurned => _todayCaloriesBurned;
  List<Workout> get workouts => _workouts;

  Future<void> saveWorkout(Workout workout) async {
    await _firebaseService.saveWorkout(workout);
    await loadDashboardData(workout.userId);
  }

  Future<void> loadDashboardData(String userId) async {
    _workouts = await _firebaseService.getWorkouts(userId);
    await loadOSWorkoutSessions(userId);
    _recentWorkout = _workouts.isNotEmpty ? _workouts.first : null;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    _todayCaloriesBurned = _workouts
        .where((w) =>
            w.endTime != null &&
            w.endTime!.isAfter(todayStart))
        .fold<double>(0, (sum, w) => sum + w.caloriesBurned);
    notifyListeners();
  }

  void clear() {
    _isWorkoutActive = false;
    _currentHeartRate = 0;
    _heartRateHistory = [];
    _workoutStartTime = null;
    _currentWorkout = null;
    _currentHrZone = 'Warm up';
    _currentTrackName = '';
    _currentTrackArtist = '';
    _currentMusicZone = '';
    _sleepReadiness = 'moderate';
    _lastNightSleep = null;
    _bpmAdjustTimer?.cancel();
    _manualOverrideTimer?.cancel();
    _extHrSub?.cancel();
    _positionSub?.cancel();
    _positionSub = null;
    _stepPollTimer?.cancel();
    _stepPollTimer = null;
    _spotifyError = null;
    _manualOverrideActive = false;
    _searchResults = [];
    _isSearching = false;
    _workoutType = 'cardio';
    _distance = 0.0;
    _routePoints.clear();
    _workoutSteps = 0;
    _currentPosition = null;
    _workoutStartDate = null;
    _osWorkouts = [];
    _recentWorkout = null;
    _todayCaloriesBurned = 0;
    _workouts = [];
    _healthService.stopHeartRateMonitoring();
    notifyListeners();
  }

  @override
  void dispose() {
    _bpmAdjustTimer?.cancel();
    _manualOverrideTimer?.cancel();
    _extHrSub?.cancel();
    _positionSub?.cancel();
    _stepPollTimer?.cancel();
    _healthService.stopHeartRateMonitoring();
    super.dispose();
  }
}
