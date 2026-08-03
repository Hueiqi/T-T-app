import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/health_service.dart';
import '../services/spotify_service.dart';
import '../services/firebase_service.dart';
import '../services/motion_service.dart';
import '../models/workout_model.dart';
import '../models/sleep_model.dart';
import '../models/music_track_model.dart';
import '../config/constants.dart';
import 'package:uuid/uuid.dart';

class WorkoutProvider extends ChangeNotifier {
  final HealthService _healthService = HealthService();
  final SpotifyService _spotifyService = SpotifyService();
  final FirebaseService _firebaseService = FirebaseService();
  final MotionService _motionService = MotionService();
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

  /// A WorkoutMusicProvider condition id: 'chill', 'slow_run' or 'sprint_run'.
  String _workoutType = 'chill';
  double _distance = 0.0;
  int _workoutSteps = 0;
  final List<Map<String, double>> _routePoints = [];

  // ── GPS route tracking ──
  StreamSubscription<Position>? _gpsSub;
  Position? _lastGpsFix;
  String? _gpsError;

  // ── Pedometer step tracking ──
  // Pedometer.stepCountStream reports a cumulative count since last device
  // reboot, not since workout start, so a baseline is captured on the first
  // reading and every later reading is a delta from it. This is what lets
  // indoor workouts (treadmill, weights) register steps at all — GPS-derived
  // steps stay 0 whenever there is no positional displacement.
  StreamSubscription<int>? _pedometerSub;
  int? _stepBaseline;

  String? get gpsError => _gpsError;

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
  int get workoutSteps => _workoutSteps;
  List<Map<String, double>> get routePoints => _routePoints;

  /// Latest GPS fix, or null before the first one arrives.
  ///
  /// Route points are stored as {'lat','lng'} (that shape is persisted to
  /// Firestore, so it must not change), but callers read {'latitude',
  /// 'longitude'}. Both spellings are exposed here so a mismatched key can't
  /// produce a null that blows up on a `!` at the call site.
  Map<String, double>? get currentPosition {
    if (_routePoints.isEmpty) return null;
    final last = _routePoints.last;
    final lat = last['lat'];
    final lng = last['lng'];
    if (lat == null || lng == null) return null;
    return {
      'lat': lat,
      'lng': lng,
      'latitude': lat,
      'longitude': lng,
    };
  }

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

  /// [workoutType] is one of the [WorkoutMusicProvider] condition ids
  /// ('chill', 'slow_run', 'sprint_run'), so the saved workout and the music
  /// playlists assigned to that condition stay in sync.
  bool _spotifyReady = false;

  /// Whether music can actually play right now. Derived from a live Spotify
  /// token rather than [AppUser.spotifyConnected], which is never set to
  /// 'connected' anywhere and so always reported "no Spotify".
  bool get spotifyReady => _spotifyReady;

  /// Loads the saved Spotify token into this provider's own [SpotifyService].
  /// Each SpotifyService instance keeps the token in memory separately, so
  /// without this the workout flow stays disconnected even when the user is
  /// logged in elsewhere in the app.
  Future<bool> refreshSpotifyStatus() async {
    if (!_spotifyService.isConnected) {
      try {
        await _spotifyService.restoreSession();
      } catch (_) {}
    }
    final ready = _spotifyService.isConnected;
    if (ready != _spotifyReady) {
      _spotifyReady = ready;
      notifyListeners();
    }
    return ready;
  }

  Future<void> startWorkout(
    String userId, {
    String? workoutType,
  }) async {
    if (workoutType != null) _workoutType = workoutType;

    // 1. Check smartwatch connection
    bool hrAvailable = false;
    if (!_isWeb) {
      try {
        hrAvailable = await _healthService.authorize();
      } catch (_) {
        hrAvailable = false;
      }
    }
    _smartwatchConnected = hrAvailable;

    // 2. Create workout session
    _isWorkoutActive = true;
    _workoutStartTime = DateTime.now();
    _heartRateHistory = [];
    _workoutSteps = 0;
    _currentTrackName = '';
    _currentTrackArtist = '';
    _currentMusicZone = '';
    _spotifyError = null;
    _manualOverrideActive = false;
    _manualOverrideTimer?.cancel();
    _currentWorkout = Workout(
      id: _uuid.v4(),
      userId: userId,
      startTime: _workoutStartTime!,
      sleepReadiness: _sleepReadiness,
      type: _workoutType,
    );

    try {
      await _firebaseService.saveWorkout(_currentWorkout!);
    } catch (_) {}

    // 3. Start GPS so the live map has a route/position to display.
    _startGpsTracking();
    // 3b. Start the pedometer so indoor workouts (no GPS displacement) still
    // register steps.
    _startPedometerTracking();

    // 4. Start HR streaming every 5 seconds (if smartwatch available)
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

    // 5. Check Spotify, restoring the saved session first so being logged in
    // from a previous run still counts. Music itself is not started here: the
    // caller plays the playlist assigned to the chosen status, falling back to
    // [startBpmMusic] when that status has none.
    if (!await refreshSpotifyStatus()) {
      _spotifyError = 'Music not connected. Please log in via Spotify first.';
    }

    _bpmAdjustTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_heartRateHistory.isEmpty) return;
      if (_manualOverrideActive) return;
      final latestHr = _heartRateHistory.last;
      await _adjustMusicForHeartRate(latestHr);
    });

    notifyListeners();
  }

  /// Feeds heart rate from a source outside this provider — the simulated
  /// stream on HealthProvider, or a BLE strap it owns.
  ///
  /// Without this, `_heartRateHistory` is only ever filled inside the
  /// `if (_smartwatchConnected)` branch of [startWorkout], so a user with no
  /// paired watch sees Avg HR / Max HR / Zone stuck at 0 for the whole
  /// session and the workout saves with no HR data.
  void attachExternalHeartRate(Stream<int> source) {
    _extHrSub?.cancel();
    _extHrSub = source.listen((hr) {
      if (!_isWorkoutActive || hr <= 0) return;
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

  void addRoutePoint(double latitude, double longitude, double distanceDelta) {
    _routePoints.add({'lat': latitude, 'lng': longitude});
    _distance += distanceDelta;
    // Steps from GPS distance are an estimate for outdoor cardio; the
    // pedometer listener in _startPedometerTracking is the real count and
    // takes priority whenever it's higher, so neither source undercounts.
    _reportSteps((_distance * 1312).toInt());
  }

  /// Takes the higher of the current and newly reported step count, since
  /// GPS-distance and pedometer readings are independent estimates of the
  /// same quantity and neither should undercount the other.
  void _reportSteps(int candidate) {
    if (candidate <= _workoutSteps) return;
    _workoutSteps = candidate;
    notifyListeners();
  }

  /// Starts the phone's step-counter sensor for the workout. This is what
  /// makes indoor sessions (treadmill, weights, HIIT) register steps at all —
  /// [addRoutePoint]'s distance-based estimate stays 0 with no GPS movement.
  Future<void> _startPedometerTracking() async {
    if (_isWeb) return;
    if (await Permission.activityRecognition.isDenied) {
      final result = await Permission.activityRecognition.request();
      if (!result.isGranted) return;
    }
    _pedometerSub?.cancel();
    // Steps-only: the gyroscope/accelerometer streams MotionService can also
    // provide have no consumer during a workout.
    _motionService.startListening(includeMotionSensors: false);
    _pedometerSub = _motionService.stepStream.listen((cumulative) {
      _stepBaseline ??= cumulative;
      _reportSteps(cumulative - _stepBaseline!);
    });
  }

  void _stopPedometerTracking() {
    _pedometerSub?.cancel();
    _pedometerSub = null;
    _stepBaseline = null;
    _motionService.stopListening();
  }

  /// Subscribes to GPS for the duration of the workout, feeding the route that
  /// the live map draws. Without this nothing ever calls addRoutePoint, so
  /// currentPosition stays null and the map has no location to show.
  Future<void> _startGpsTracking() async {
    if (_isWeb) return;
    _gpsError = null;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _gpsError = 'Location services are off. Enable GPS to map your route.';
        notifyListeners();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _gpsError = 'Location permission denied. Route mapping is unavailable.';
        notifyListeners();
        return;
      }

      // Seed an immediate fix so the map can centre without waiting for the
      // first stream event (which only fires after `distanceFilter` metres).
      try {
        final first = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        _lastGpsFix = first;
        addRoutePoint(first.latitude, first.longitude, 0);
      } catch (_) {
        // Non-fatal: the stream below may still deliver a fix.
      }

      _gpsSub?.cancel();
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(
        (pos) {
          final prev = _lastGpsFix;
          var deltaKm = 0.0;
          if (prev != null) {
            final metres = Geolocator.distanceBetween(
              prev.latitude,
              prev.longitude,
              pos.latitude,
              pos.longitude,
            );
            // Ignore GPS jitter while standing still.
            if (metres < 5) return;
            deltaKm = metres / 1000.0;
          }
          _lastGpsFix = pos;
          addRoutePoint(pos.latitude, pos.longitude, deltaKm);
        },
        onError: (e) {
          _gpsError = 'Location error: $e';
          notifyListeners();
        },
      );
    } catch (e) {
      _gpsError = 'Could not start location tracking: $e';
      notifyListeners();
    }
  }

  void _stopGpsTracking() {
    _gpsSub?.cancel();
    _gpsSub = null;
    _lastGpsFix = null;
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

  /// Starts heart-rate-driven track selection. Used as the fallback when the
  /// chosen workout status has no playlist assigned to it.
  Future<void> startBpmMusic() async {
    if (_spotifyError != null || !_spotifyService.isConnected) return;
    final initialHr = _currentHeartRate > 0 ? _currentHeartRate : 90;
    await _adjustMusicForHeartRate(initialHr);
  }

  /// Hands music control to something the user picked deliberately — a
  /// workout-status playlist — and stops the BPM timer from replacing it.
  /// Unlike [playSelectedTrack]'s 30-second override this holds for the rest
  /// of the session: a playlist the user chose should not be swapped out for
  /// a keyword-searched track ten seconds later. Cleared when the workout ends.
  void holdMusicSelection({required String label, String subtitle = ''}) {
    _manualOverrideActive = true;
    _manualOverrideTimer?.cancel();
    _currentTrackName = label;
    _currentTrackArtist = subtitle;
    notifyListeners();
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

  /// MET (metabolic equivalent) values per workout type, used to estimate
  /// calories when no heart-rate data is available. Values follow the
  /// Compendium of Physical Activities for light effort, jogging, and running.
  static const Map<String, double> _metByWorkoutType = {
    'chill': 3.5,
    'slow_run': 7.0,
    'sprint_run': 11.0,
  };
  static const double _defaultMet = 5.0;

  Future<Map<String, dynamic>> endWorkout({
    required String gender,
    double? manualCalories,
    double? weightKg,
  }) async {
    _isWorkoutActive = false;
    _healthService.stopHeartRateMonitoring();
    _extHrSub?.cancel();
    _extHrSub = null;
    _stopGpsTracking();
    _stopPedometerTracking();
    _currentTrackName = '';
    _currentTrackArtist = '';
    _currentMusicZone = '';
    _bpmAdjustTimer?.cancel();
    _manualOverrideTimer?.cancel();
    _manualOverrideActive = false;

    // Stop the music and release the Spotify connection now the workout is
    // over, rather than leaving playback paused mid-track.
    try {
      await _spotifyService.endPlaybackSession();
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
    } else if (hasHrData && durationMinutes > 0) {
      final factor = gender == 'female' ? 0.045 : 0.05;
      caloriesBurned = avgHr * durationMinutes * factor;
    } else {
      // No heart-rate source — the phone has no HR sensor, so this is the
      // normal case unless a wearable is paired through Health Connect.
      // Estimate from MET rather than recording zero, which previously made
      // every calorie chart read empty. Uses seconds so that sub-minute
      // sessions (durationMinutes == 0) still produce a value.
      final met = _metByWorkoutType[_workoutType] ?? _defaultMet;
      caloriesBurned = met * (weightKg ?? 70) * (durationSeconds / 3600);
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
    // Refresh the cached history so the finished workout shows up in the
    // dashboard and statistics charts without needing an app restart.
    await loadDashboardData(_currentWorkout!.userId);
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

  Future<void> loadDashboardData(String userId, {int workoutLimit = 30}) async {
    _workouts = await _firebaseService.getWorkouts(userId, limit: workoutLimit);
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
    _spotifyError = null;
    _manualOverrideActive = false;
    _searchResults = [];
    _isSearching = false;
    _workoutType = 'chill';
    _distance = 0.0;
    _workoutSteps = 0;
    _stopGpsTracking();
    _stopPedometerTracking();
    _gpsError = null;
    _routePoints.clear();
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
    _stopGpsTracking();
    _stopPedometerTracking();
    _motionService.dispose();
    _healthService.stopHeartRateMonitoring();
    super.dispose();
  }
}
