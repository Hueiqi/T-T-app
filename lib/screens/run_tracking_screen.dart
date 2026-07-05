import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/health_provider.dart';
import '../config/theme.dart';
import '../models/workout_model.dart';

class RunTrackingScreen extends StatefulWidget {
  const RunTrackingScreen({super.key});

  @override
  State<RunTrackingScreen> createState() => _RunTrackingScreenState();
}

class _RunTrackingScreenState extends State<RunTrackingScreen> {
  final Location _location = Location();
  MapLibreMapController? _mapController;
  LatLng? _currentLocation;
  bool _isTracking = false;
  bool _isPaused = false;
  double _distance = 0.0;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  Timer? _locationTimer;
  final List<LatLng> _routePoints = [];
  double _caloriesBurned = 0.0;
  bool _isSaving = false;
  List<Workout> _runHistory = [];
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadHistory();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final userId = context.read<AuthProvider>().user?.uid;
    if (userId == null) return;
    final workouts = context.read<WorkoutProvider>().workouts;
    setState(() {
      _runHistory = workouts.where((w) => w.type == 'running').toList()
        ..sort((a, b) => b.startTime.compareTo(a.startTime));
      _loadingHistory = false;
    });
  }

  Future<void> _initLocation() async {
    final permission = await _location.requestPermission();
    if (permission != PermissionStatus.granted) return;
    final loc = await _location.getLocation();
    if (!mounted) return;
    setState(() {
      _currentLocation = LatLng(loc.latitude!, loc.longitude!);
    });
  }

  void _startTracking() {
    setState(() {
      _isTracking = true;
      _isPaused = false;
      _routePoints.clear();
      _distance = 0.0;
      _elapsed = Duration.zero;
      _caloriesBurned = 0.0;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsed = _elapsed + const Duration(seconds: 1);
      });
    });

    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!_isTracking || _isPaused) return;
      final newLoc = await _location.getLocation();
      if (newLoc.latitude != null && newLoc.longitude != null) {
        final newPos = LatLng(newLoc.latitude!, newLoc.longitude!);
        setState(() {
          if (_routePoints.isNotEmpty) {
            _distance += _calculateDistance(_routePoints.last, newPos);
          }
          _routePoints.add(newPos);
          _currentLocation = newPos;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(newPos),
        );
      }
    });
  }

  double _calculateDistance(LatLng from, LatLng to) {
    const R = 6371;
    final dLat = (to.latitude - from.latitude) * pi / 180;
    final dLon = (to.longitude - from.longitude) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(from.latitude * pi / 180) *
            cos(to.latitude * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  void _pauseTracking() {
    setState(() => _isPaused = !_isPaused);
  }

  Future<void> _stopTracking() async {
    _timer?.cancel();
    _locationTimer?.cancel();
    setState(() {
      _isTracking = false;
      _isSaving = true;
    });

    final auth = context.read<AuthProvider>();
    final weight = auth.user?.weight ?? 70.0;
    final hours = _elapsed.inSeconds / 3600.0;
    const met = 8.0;
    _caloriesBurned = met * weight * hours;

    final workoutProvider = context.read<WorkoutProvider>();
    final userId = auth.user?.uid;
    if (userId != null) {
      final workout = Workout(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        startTime: DateTime.now().subtract(_elapsed),
        endTime: DateTime.now(),
        type: 'running',
        caloriesBurned: _caloriesBurned,
        distance: _distance,
      );
      await workoutProvider.saveWorkout(workout);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    _showSummaryDialog();
    await _loadHistory();
  }

  void _showSummaryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Run Completed!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Distance: ${_distance.toStringAsFixed(2)} km'),
            const SizedBox(height: 4),
            Text('Time: ${_elapsed.inMinutes} min ${_elapsed.inSeconds % 60} sec'),
            const SizedBox(height: 4),
            Text('Calories: ${_caloriesBurned.toStringAsFixed(0)} kcal'),
            if (_distance > 0)
              Text(
                'Avg Pace: ${(_elapsed.inSeconds / _distance ~/ 60)}:${(_elapsed.inSeconds / _distance % 60).toInt().toString().padLeft(2, '0')} min/km',
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showRunDetail(Workout run) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              run.type.toUpperCase(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${run.startTime.day}/${run.startTime.month}/${run.startTime.year} \u00b7 ${run.startTime.hour}:${run.startTime.minute.toString().padLeft(2, '0')}',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _detailChip('Distance', '${run.distance.toStringAsFixed(2)} km', AppTheme.primaryColor),
                _detailChip('Time', '${run.duration.inMinutes} min', AppTheme.accentColor),
                _detailChip('Calories', '${run.caloriesBurned.toStringAsFixed(0)} kcal', AppTheme.warningColor),
                if (run.avgHeartRate > 0) _detailChip('Avg HR', '${run.avgHeartRate} bpm', AppTheme.errorColor),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _detailChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color)),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthProvider>();
    final hr = health.currentHeartRate;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Run & Walk Tracker'),
        actions: [
          if (_isTracking)
            IconButton(
              icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
              onPressed: _pauseTracking,
              tooltip: _isPaused ? 'Resume' : 'Pause',
            ),
          if (_isTracking)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopTracking,
              tooltip: 'Stop',
            ),
        ],
      ),
      body: Stack(
        children: [
          _isTracking ? _buildTrackingUI(hr) : _buildHistoryUI(),
          if (_isSaving)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text('Saving run...', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrackingUI(int hr) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.05),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statColumn('Distance', '${_distance.toStringAsFixed(2)} km'),
              _statColumn('Time', '${_elapsed.inMinutes}:${(_elapsed.inSeconds % 60).toString().padLeft(2, '0')}'),
              _statColumn('HR', hr > 0 ? '$hr bpm' : '--', color: hr > 0 ? AppTheme.errorColor : null),
              _statColumn('Status', _isPaused ? 'Paused' : 'Running', color: _isPaused ? Colors.orange : Colors.green),
            ],
          ),
        ),
        Expanded(
          child: _currentLocation == null
              ? const Center(child: CircularProgressIndicator())
              : MapLibreMap(
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  styleString: 'https://tiles.openfreemap.org/styles/positron',
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation!,
                    zoom: 15,
                  ),
                  myLocationEnabled: !kIsWeb,
                  myLocationTrackingMode: !kIsWeb ? MyLocationTrackingMode.tracking : MyLocationTrackingMode.none,
                  compassEnabled: false,
                  rotateGesturesEnabled: false,
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryUI() {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startTracking,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Run'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
        Expanded(
          child: _runHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'No runs yet',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Start your first run!',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _runHistory.length,
                  itemBuilder: (ctx, i) {
                    final run = _runHistory[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showRunDetail(run),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.directions_run, color: AppTheme.primaryColor, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${run.distance.toStringAsFixed(2)} km',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${run.duration.inMinutes} min \u00b7 ${run.caloriesBurned.toStringAsFixed(0)} kcal',
                                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                    ),
                                    Text(
                                      '${run.startTime.day}/${run.startTime.month}/${run.startTime.year} ${run.startTime.hour}:${run.startTime.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _statColumn(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color ?? AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}
