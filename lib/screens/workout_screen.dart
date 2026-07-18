import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../providers/workout_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/health_provider.dart';
import '../config/theme.dart';
import '../config/routes.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/bottom_nav_shell.dart';

class WorkoutScreen extends StatefulWidget {
  final bool showBottomNav;

  const WorkoutScreen({super.key, this.showBottomNav = true});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final spotifyConnected = auth.user?.spotifyConnected == 'connected';
    return Scaffold(
      appBar: null,
      body: SafeArea(
        child: Consumer<WorkoutProvider>(
          builder: (context, workout, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (workout.spotifyError != null && workout.isWorkoutActive)
                    _WarningBanner(
                      icon: Icons.error_outline,
                      message: workout.spotifyError!,
                      color: AppTheme.errorColor,
                    ),

                  _HeartRateMonitor(workout: workout),
                  const SizedBox(height: 20),
                  if (workout.isWorkoutActive)
                    _ActiveWorkoutPanel(
                      workout: workout,
                      spotifyConnected: spotifyConnected,
                    )
                  else
                    _WorkoutStartPanel(
                      workout: workout,
                      spotifyConnected: spotifyConnected,
                    ),
                  const SizedBox(height: 20),
                  _HeartRateChart(heartRates: workout.heartRateHistory),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: widget.showBottomNav ? buildBottomNavBar(context) : null,
    );
  }
}

// ─── Warning Banner ─────────────────────────────────────────────
class _WarningBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _WarningBanner({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: color, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Heart Rate Monitor ──────────────────────────────────────────
class _HeartRateMonitor extends StatelessWidget {
  final WorkoutProvider workout;

  const _HeartRateMonitor({required this.workout});

  @override
  Widget build(BuildContext context) {
    final zoneColors = <String, Color>{
      'Warm up': Colors.green,
      'Fat Burn': AppTheme.warningColor,
      'Cardio': AppTheme.accentColor,
      'Peak': AppTheme.errorColor,
    };

    final hr = workout.currentHeartRate;
    final zone = workout.currentHrZone;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Current Heart Rate',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$hr',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: zoneColors[zone] ?? AppTheme.primaryColor,
                      ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 16, left: 4),
                  child: Text(
                    'bpm',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (workout.isWorkoutActive || hr > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (zoneColors[zone] ?? AppTheme.primaryColor)
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  zone,
                  style: TextStyle(
                    color: zoneColors[zone] ?? AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            const SizedBox(height: 12),
            if (workout.lastNightSleep != null)
              Text(
                'Sleep Readiness: ${workout.sleepReadiness.toUpperCase()}',
                style: TextStyle(
                  color: workout.sleepReadiness == 'high'
                      ? AppTheme.successColor
                      : workout.sleepReadiness == 'moderate'
                          ? AppTheme.warningColor
                          : AppTheme.errorColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Workout Start Panel ─────────────────────────────────────────
class _WorkoutStartPanel extends StatefulWidget {
  final WorkoutProvider workout;
  final bool spotifyConnected;

  const _WorkoutStartPanel({
    required this.workout,
    required this.spotifyConnected,
  });

  @override
  State<_WorkoutStartPanel> createState() => _WorkoutStartPanelState();
}

class _WorkoutStartPanelState extends State<_WorkoutStartPanel> {
  String _selectedType = 'cardio';

  IconData _iconForType(String type) {
    switch (type) {
      case 'running':
        return Icons.directions_run;
      case 'walking':
        return Icons.directions_walk;
      default:
        return Icons.fitness_center;
    }
  }

  String _labelForType(String type) {
    switch (type) {
      case 'running':
        return 'Run';
      case 'walking':
        return 'Walk';
      default:
        return 'General';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.fitness_center,
              size: 48,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Ready to Exercise?',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a workout to begin real-time heart rate tracking\nand adaptive music playback.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            Text(
              'Workout Type',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final type in ['running', 'walking', 'cardio']) ...[
                  if (type != 'running') const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedType = type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _selectedType == type
                              ? AppTheme.primaryColor
                              : AppTheme.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedType == type
                                ? AppTheme.primaryColor
                                : AppTheme.primaryColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _iconForType(type),
                              size: 24,
                              color: _selectedType == type
                                  ? Colors.white
                                  : AppTheme.primaryColor,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _labelForType(type),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _selectedType == type
                                    ? Colors.white
                                    : AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite, size: 16, color: AppTheme.accentColor),
                const SizedBox(width: 4),
                Text(
                  'Heart rate monitoring',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(width: 16),
                Icon(
                  widget.spotifyConnected
                      ? Icons.music_note
                      : Icons.music_note_outlined,
                  size: 16,
                  color: widget.spotifyConnected
                      ? const Color(0xFF1DB954)
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.spotifyConnected ? 'Spotify ready' : 'No Spotify',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.spotifyConnected
                        ? const Color(0xFF1DB954)
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final auth = context.read<AuthProvider>();
                  if (auth.user == null) return;

                  // Check smartwatch connection before starting
                  final healthProvider = context.read<HealthProvider>();
                  if (!healthProvider.smartwatchConnected) {
                    final action = await showDialog<String>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('No Smartwatch'),
                        content: const Text(
                          'Please pair your smartwatch in Settings for heart rate tracking. '
                          'Without it, dynamic BPM matching and calorie calculation will not work. '
                          'You can still start the workout and log calories manually later.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, 'settings'),
                            child: const Text('Go to Settings'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, 'start'),
                            child: const Text('Start Anyway'),
                          ),
                        ],
                      ),
                    );
                    if (action == null) return;
                    if (action == 'settings') {
                      if (context.mounted) {
                        Navigator.pushNamed(context, '/profile');
                      }
                      return;
                    }
                  }

                  try {
                    // ✅ Fix: use widget.workout and widget.spotifyConnected
                    await widget.workout.startWorkout(
                      auth.user!.uid,
                      spotifyConnected: widget.spotifyConnected,
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error starting workout: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Workout'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Active Workout Panel ────────────────────────────────────────
class _ActiveWorkoutPanel extends StatefulWidget {
  final WorkoutProvider workout;
  final bool spotifyConnected;

  const _ActiveWorkoutPanel({
    required this.workout,
    required this.spotifyConnected,
  });

  @override
  State<_ActiveWorkoutPanel> createState() => _ActiveWorkoutPanelState();
}

class _ActiveWorkoutPanelState extends State<_ActiveWorkoutPanel> {
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;
  bool _isSaving = false;
  MapLibreMapController? _mapController;
  int _lastRouteCount = 0;

  @override
  void initState() {
    super.initState();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.workout.currentWorkout?.startTime != null) {
        setState(() {
          _elapsed = DateTime.now().difference(
            widget.workout.currentWorkout!.startTime,
          );
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant _ActiveWorkoutPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newCount = widget.workout.routePoints.length;
    if (newCount != _lastRouteCount && _mapController != null) {
      _lastRouteCount = newCount;
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateMapRoute());
    }
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    _lastRouteCount = widget.workout.routePoints.length;
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateMapRoute());
  }

  Future<void> _updateMapRoute() async {
    if (_mapController == null) return;
    final routePoints = widget.workout.routePoints;
    if (routePoints.isEmpty) return;

    final coordinates = routePoints
        .map((p) => LatLng(p['lat']!, p['lng']!))
        .toList();

    // Clear previous annotations
    await _mapController!.clearSymbols();
    await _mapController!.clearLines();
    await _mapController!.clearCircles();

    // Draw route polyline
    if (coordinates.length >= 2) {
      await _mapController!.addLine(
        LineOptions(
          geometry: coordinates,
          lineColor: '#6366F1',
          lineWidth: 4.0,
        ),
      );

      // Start marker (green)
      await _mapController!.addCircle(
        CircleOptions(
          geometry: coordinates.first,
          circleRadius: 8,
          circleColor: '#22C55E',
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2,
        ),
      );
    }

    // Current position marker (red)
    final currentPos = widget.workout.currentPosition;
    if (currentPos != null) {
      await _mapController!.addCircle(
        CircleOptions(
          geometry: LatLng(currentPos.latitude, currentPos.longitude),
          circleRadius: 10,
          circleColor: '#EF4444',
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3,
        ),
      );
    }

    // Animate camera to show full route
    if (coordinates.length >= 2) {
      var minLat = coordinates.first.latitude;
      var maxLat = coordinates.first.latitude;
      var minLng = coordinates.first.longitude;
      var maxLng = coordinates.first.longitude;
      for (final c in coordinates) {
        if (c.latitude < minLat) minLat = c.latitude;
        if (c.latitude > maxLat) maxLat = c.latitude;
        if (c.longitude < minLng) minLng = c.longitude;
        if (c.longitude > maxLng) maxLng = c.longitude;
      }
      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, left: 60, top: 60, right: 60, bottom: 60),
      );
    } else if (coordinates.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(coordinates.first, 15),
      );
    }
  }

  String get _pace {
    final dist = widget.workout.distance;
    final secs = _elapsed.inSeconds;
    if (dist <= 0 || secs <= 0) return '--';
    final paceSeconds = (secs / dist).round();
    final pMin = paceSeconds ~/ 60;
    final pSec = paceSeconds % 60;
    return '$pMin:${pSec.toString().padLeft(2, '0')}/km';
  }

  Future<void> _endWorkout(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final bool isFemale = user?.displayName.toLowerCase() == 'female';
    final genderStr = isFemale ? 'female' : 'male';

    final workout = widget.workout;
    final hasHrData = workout.heartRateHistory.isNotEmpty;

    double? manualCalories;
    if (!hasHrData) {
      final manualResult = await showDialog<double>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _ManualCalorieDialog(),
      );
      if (manualResult == null) return;
      manualCalories = manualResult;
    }

    setState(() => _isSaving = true);

    final result = await workout.endWorkout(
      gender: genderStr,
      manualCalories: manualCalories,
    );

    if (!context.mounted) return;

    setState(() => _isSaving = false);

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.workoutComplete,
      arguments: result,
    );
  }

  void _showSongPicker(BuildContext context) {
    final workout = widget.workout;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SongPickerSheet(workout: workout),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workout = widget.workout;
    final avgHr = workout.heartRateHistory.isNotEmpty
        ? workout.heartRateHistory.reduce((a, b) => a + b) ~/
            workout.heartRateHistory.length
        : 0;
    final maxHr = workout.heartRateHistory.isNotEmpty
        ? workout.heartRateHistory.reduce((a, b) => a > b ? a : b)
        : 0;

    if (_isSaving) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Saving workout...', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Live Map
        if (!kIsWeb)
          Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: MapLibreMap(
                onMapCreated: _onMapCreated,
                styleString: 'https://tiles.openfreemap.org/styles/positron',
                initialCameraPosition: CameraPosition(
                  target: workout.currentPosition != null
                      ? LatLng(
                          workout.currentPosition!.latitude,
                          workout.currentPosition!.longitude,
                        )
                      : const LatLng(0, 0),
                  zoom: 15,
                ),
                compassEnabled: false,
                rotateGesturesEnabled: false,
                myLocationEnabled: false,
                myLocationTrackingMode: MyLocationTrackingMode.none,
              ),
            ),
          ),
        const SizedBox(height: 12),

        // Stats Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(
                      Icons.fitness_center,
                      color: AppTheme.primaryColor,
                      size: 32,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.fiber_manual_record,
                            color: AppTheme.successColor,
                            size: 12,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: AppTheme.successColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  '${_elapsed.inMinutes.toString().padLeft(2, '0')}:${(_elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: Theme.of(
                    context,
                  ).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Elapsed Time',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _MetricColumn(label: 'Avg HR', value: '$avgHr'),
                    _MetricColumn(label: 'Max HR', value: '$maxHr'),
                    _MetricColumn(
                      label: 'Zone',
                      value: workout.currentHrZone,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _MetricColumn(
                      label: 'Distance',
                      value: workout.distance.toStringAsFixed(2) + ' km',
                    ),
                    _MetricColumn(
                      label: 'Steps',
                      value: workout.workoutSteps.toString(),
                    ),
                    _MetricColumn(
                      label: 'Pace',
                      value: _pace,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (workout.currentTrackName.isNotEmpty)
                  Card(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1DB954).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.music_note,
                              color: Color(0xFF1DB954),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  workout.currentTrackName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  workout.currentTrackArtist,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next, size: 20),
                            tooltip: 'Skip track',
                            color: const Color(0xFF1DB954),
                            onPressed: () => workout.skipToNextMusic(),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Card(
                    color: AppTheme.textSecondary.withValues(alpha: 0.05),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.textSecondary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.music_note_outlined,
                              color: AppTheme.textSecondary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            !widget.spotifyConnected
                                ? 'Spotify not connected'
                                : workout.currentMusicZone.isNotEmpty
                                    ? workout.currentMusicZone
                                    : 'No music playing',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                if (widget.spotifyConnected && workout.spotifyError == null)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showSongPicker(context),
                      icon: const Icon(Icons.library_music, size: 20),
                      label: Text(
                        workout.manualOverrideActive
                            ? 'Manual override active (30s)'
                            : 'Choose Song',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        foregroundColor: const Color(0xFF1DB954),
                        side: const BorderSide(color: Color(0xFF1DB954)),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : () => _endWorkout(context),
                    icon: const Icon(Icons.stop),
                    label: Text(_isSaving ? 'Saving...' : 'End Workout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorColor,
                      disabledBackgroundColor: AppTheme.errorColor.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Song Picker Sheet ──────────────────────────────────────────
class _SongPickerSheet extends StatefulWidget {
  final WorkoutProvider workout;

  const _SongPickerSheet({required this.workout});

  @override
  State<_SongPickerSheet> createState() => _SongPickerSheetState();
}

class _SongPickerSheetState extends State<_SongPickerSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query.trim().isNotEmpty) {
        widget.workout.searchSongs(query.trim());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose a Song',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search songs...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  widget.workout.searchSongs('');
                  setState(() {});
                },
              ),
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 12),
          Consumer<WorkoutProvider>(
            builder: (context, workout, _) {
              if (workout.isSearching) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (workout.searchResults.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Search for a song to play',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                );
              }
              return SizedBox(
                height: 300,
                child: ListView.separated(
                  itemCount: workout.searchResults.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final track = workout.searchResults[i];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: track.albumArtUrl.isNotEmpty
                            ? Image.network(
                                track.albumArtUrl,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 40,
                                height: 40,
                                color: const Color(
                                  0xFF1DB954,
                                ).withValues(alpha: 0.15),
                                child: const Icon(
                                  Icons.music_note,
                                  color: Color(0xFF1DB954),
                                  size: 20,
                                ),
                              ),
                      ),
                      title: Text(
                        track.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.play_circle_fill,
                          color: Color(0xFF1DB954),
                        ),
                        onPressed: () {
                          workout.playSelectedTrack(track);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Manual Calorie Dialog ──────────────────────────────────────
class _ManualCalorieDialog extends StatefulWidget {
  @override
  State<_ManualCalorieDialog> createState() => _ManualCalorieDialogState();
}

class _ManualCalorieDialogState extends State<_ManualCalorieDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter Calories'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'No heart rate data available. Please enter an estimated calorie value:',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Calories burned',
              hintText: 'e.g. 250',
              prefixIcon: Icon(Icons.local_fire_department),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final val = double.tryParse(_controller.text.trim());
            if (val != null && val > 0) {
              Navigator.pop(context, val);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ─── Metric Column ──────────────────────────────────────────────
class _MetricColumn extends StatelessWidget {
  final String label;
  final String value;

  const _MetricColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ],
    );
  }
}

// ─── Heart Rate Chart ───────────────────────────────────────────
class _HeartRateChart extends StatelessWidget {
  final List<int> heartRates;

  const _HeartRateChart({required this.heartRates});

  @override
  Widget build(BuildContext context) {
    if (heartRates.isEmpty) return const SizedBox.shrink();

    final minY = _getMinY(heartRates) - 10;
    final maxY = _getMaxY(heartRates) + 10;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Heart Rate History',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withValues(alpha: 0.2),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: heartRates
                          .asMap()
                          .entries
                          .map(
                            (e) => FlSpot(e.key.toDouble(), e.value.toDouble()),
                          )
                          .toList(),
                      isCurved: true,
                      color: AppTheme.primaryColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getMinY(List<int> rates) {
    var min = rates.isNotEmpty ? rates[0] : 0;
    for (final r in rates) {
      if (r < min) min = r;
    }
    return min.toDouble();
  }

  double _getMaxY(List<int> rates) {
    var max = rates.isNotEmpty ? rates[0] : 0;
    for (final r in rates) {
      if (r > max) max = r;
    }
    return max.toDouble();
  }
}