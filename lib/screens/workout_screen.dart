import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Factory;
import 'package:flutter/gestures.dart'
    show ScaleGestureRecognizer, OneSequenceGestureRecognizer;
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../providers/workout_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/health_provider.dart';
import '../providers/workout_music_provider.dart';
import '../spotify/state/player_provider.dart';
import '../services/reverse_geocode_service.dart';
import '../widgets/heart_rate_meter.dart';
import '../config/theme.dart';
import '../config/routes.dart';
import '../widgets/bottom_nav_shell.dart';
import '../widgets/quick_add_sheet.dart';
import 'workout_history_screen.dart';

class WorkoutScreen extends StatefulWidget {
  final bool showBottomNav;

  /// Attached to the Workout Playlist icon so the User Guide tour can
  /// spotlight it after switching to this tab.
  final GlobalKey? playlistButtonKey;

  const WorkoutScreen({
    super.key,
    this.showBottomNav = true,
    this.playlistButtonKey,
  });

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  @override
  void initState() {
    super.initState();
    // Pull the saved Spotify token into WorkoutProvider's own service instance
    // so the status shown here reflects reality before a workout is started.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<WorkoutProvider>().refreshSpotifyStatus(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Live token state, not AppUser.spotifyConnected — that field is never set
    // to 'connected' anywhere, so it always reported "No Spotify".
    final spotifyConnected = context.watch<WorkoutProvider>().spotifyReady;
    // No AppBar — the title and actions live in the scrolling body instead,
    // as a plain row rather than a purple bar with its own status-bar tinting.
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'quickAddWorkout',
        onPressed: () => showQuickAddSheet(context),
        tooltip: 'Quick Add',
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Consumer<WorkoutProvider>(
          builder: (context, workout, _) {
            return SingleChildScrollView(
              // Always scrollable so the page still responds to a drag when
              // the content happens to fit, and so there's room to scroll
              // past the bottom nav during an active workout.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Workout',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // The only other way in is a button on the "Ready to
                      // Exercise?" card, which disappears once a workout
                      // starts — leaving the playlist screen unreachable
                      // mid-session. Keep it here so it's available in both
                      // states.
                      IconButton(
                        key: widget.playlistButtonKey,
                        icon: const Icon(Icons.queue_music),
                        tooltip: 'Workout Playlist',
                        onPressed: () => Navigator.pushNamed(
                            context, AppRoutes.workoutMusic),
                      ),
                      IconButton(
                        icon: const Icon(Icons.history),
                        tooltip: 'Workout History',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WorkoutHistoryScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (workout.spotifyError != null && workout.isWorkoutActive)
                    _WarningBanner(
                      icon: Icons.error_outline,
                      message: workout.spotifyError!,
                      color: AppTheme.errorColor,
                    ),

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
  /// Workout types mirror [WorkoutMusicProvider.conditions] so the type picked
  /// here is the same id the music screen assigns playlists to.
  String _selectedType = WorkoutMusicProvider.conditions.first.id;

  /// Starts the playlist assigned to the selected status as soon as the
  /// workout begins. Falls back to heart-rate-driven track selection when that
  /// status has no playlist, so the workout is never silent by accident.
  Future<void> _startMusicForStatus({
    required WorkoutMusicProvider music,
    required PlayerProvider player,
    required ScaffoldMessengerState messenger,
  }) async {
    if (!widget.workout.spotifyReady) return;

    // Assignments live on disk and the playlist screen may never have been
    // opened this session, so make sure they are loaded before picking.
    await music.load();

    final pick = music.pickForCondition(_selectedType);
    if (pick == null) {
      await widget.workout.startBpmMusic();
      return;
    }

    try {
      // The playback engine lives at the app root and connects lazily.
      if (!player.isReady) await player.initialize();
      await player.playContext(pick.uri);
      // Stop the 10s BPM timer replacing the playlist straight away.
      widget.workout.holdMusicSelection(
        label: pick.name,
        subtitle: '${WorkoutMusicProvider.labelForType(_selectedType)} mode',
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not start "${pick.name}": $e')),
      );
      await widget.workout.startBpmMusic();
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'slow_run':
        return Icons.directions_run;
      case 'sprint_run':
        return Icons.bolt;
      default:
        return Icons.self_improvement;
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
                for (final condition in WorkoutMusicProvider.conditions) ...[
                  if (condition != WorkoutMusicProvider.conditions.first)
                    const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _selectedType = condition.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 4),
                        decoration: BoxDecoration(
                          color: _selectedType == condition.id
                              ? AppTheme.primaryColor
                              : AppTheme.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedType == condition.id
                                ? AppTheme.primaryColor
                                : AppTheme.primaryColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _iconForType(condition.id),
                              size: 24,
                              color: _selectedType == condition.id
                                  ? Colors.white
                                  : AppTheme.primaryColor,
                            ),
                            const SizedBox(height: 6),
                            // "Sprint Run" clips on narrow phones and at large
                            // system text scales, so shrink to fit instead.
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                condition.label,
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedType == condition.id
                                      ? Colors.white
                                      : AppTheme.primaryColor,
                                ),
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.workoutMusic);
                },
                icon: const Icon(Icons.queue_music, color: Color(0xFF1DB954)),
                label: const Text('Workout Playlist'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFF1DB954)),
                  foregroundColor: const Color(0xFF1DB954),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final auth = context.read<AuthProvider>();
                  if (auth.user == null) return;

                  // Guarantee the heart rate meter has a ticking source for
                  // this session. No-ops when a real BLE strap is connected or
                  // the simulation is already running.
                  final health = context.read<HealthProvider>();
                  if (!health.isSimulating && !health.smartwatchConnected) {
                    health.startHeartRateSimulation();
                  }

                  final music = context.read<WorkoutMusicProvider>();
                  final player = context.read<PlayerProvider>();
                  final messenger = ScaffoldMessenger.of(context);

                  try {
                    await widget.workout.startWorkout(
                      auth.user!.uid,
                      workoutType: _selectedType,
                    );

                    // WorkoutProvider only records HR itself when a paired
                    // smartwatch is present. Feed it HealthProvider's stream
                    // (simulated or BLE strap) so Avg/Max HR and Zone have
                    // data for everyone else.
                    widget.workout.attachExternalHeartRate(
                      health.heartRateStream,
                    );

                    await _startMusicForStatus(
                      music: music,
                      player: player,
                      messenger: messenger,
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
  String? _lastPosKey;

  /// True once the user has zoomed or panned the map themselves. While set,
  /// [_updateMapRoute] keeps redrawing the route but leaves the camera alone,
  /// so a GPS update can't yank the view back. The recentre button clears it.
  bool _userAdjustedCamera = false;

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
    if (_mapController == null) return;
    final newCount = widget.workout.routePoints.length;
    // Also watch the raw position: before the first route point is logged the
    // count stays 0, so without this the map would never leave LatLng(0,0)
    // even once GPS has a fix.
    final pos = widget.workout.currentPosition;
    final posKey = pos == null
        ? null
        : '${pos['latitude']},${pos['longitude']}';
    if (newCount != _lastRouteCount || posKey != _lastPosKey) {
      _lastRouteCount = newCount;
      _lastPosKey = posKey;
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
          geometry: LatLng(currentPos['latitude'] ?? 0, currentPos['longitude'] ?? 0),
          circleRadius: 10,
          circleColor: '#EF4444',
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3,
        ),
      );
    }

    // Animate camera to show full route. Skipped once the user has taken
    // manual control of the camera, so their zoom/pan survives GPS updates.
    if (_userAdjustedCamera) return;

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
        CameraUpdate.newLatLngZoom(coordinates.first, 16),
      );
    } else if (currentPos != null) {
      // No route logged yet (GPS still warming up). Without this the camera
      // stays on the initial LatLng(0,0) at street zoom, which renders as
      // blank ocean and looks like the map failed to load.
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(currentPos['latitude'] ?? 0, currentPos['longitude'] ?? 0),
          16,
        ),
      );
    }
  }

  /// Steps the camera zoom by [delta] levels.
  ///
  /// Also sets [_userAdjustedCamera] so the auto-fit in [_updateMapRoute]
  /// stops overriding the user — otherwise the next GPS point would snap the
  /// zoom straight back to the route bounds.
  Future<void> _zoomBy(double delta) async {
    if (_mapController == null) return;
    _userAdjustedCamera = true;
    await _mapController!.animateCamera(
      delta > 0 ? CameraUpdate.zoomIn() : CameraUpdate.zoomOut(),
    );
  }

  /// Returns the camera to the runner's current position and re-enables
  /// automatic route following.
  Future<void> _recentre() async {
    if (_mapController == null) return;
    _userAdjustedCamera = false;
    final pos = widget.workout.currentPosition;
    if (pos == null) return;
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(pos['latitude'] ?? 0, pos['longitude'] ?? 0),
        16,
      ),
    );
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
    // Was comparing displayName against 'female', so the female calorie factor
    // effectively never applied. AppUser.gender is the actual field.
    final genderStr =
        user?.gender.toLowerCase() == 'female' ? 'female' : 'male';

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
      weightKg: user?.weight,
    );

    if (!context.mounted) return;

    setState(() => _isSaving = false);

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.workoutComplete,
      arguments: result,
    );
  }

  void _showStatusPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _StatusPickerSheet(
        workout: widget.workout,
        music: context.read<WorkoutMusicProvider>(),
        player: context.read<PlayerProvider>(),
      ),
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
        // Runner view — which street you're on
        if (!kIsWeb) ...[
          _RunnerStreetView(workout: widget.workout),
          const SizedBox(height: 12),
        ],

        // Live Map
        if (!kIsWeb)
          Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              height: 260,
              width: double.infinity,
              child: Stack(
                children: [
                  MapLibreMap(
                    onMapCreated: _onMapCreated,
                    styleString:
                        'https://tiles.openfreemap.org/styles/positron',
                    initialCameraPosition: CameraPosition(
                      target: workout.currentPosition != null
                          ? LatLng(
                              workout.currentPosition!['latitude'] ?? 0,
                              workout.currentPosition!['longitude'] ?? 0,
                            )
                          : const LatLng(0, 0),
                      // With no GPS fix yet the target is (0,0) — open zoomed
                      // out so it reads as a world map rather than a blank
                      // ocean close-up. _updateMapRoute() zooms in once a fix
                      // arrives.
                      zoom: workout.currentPosition != null ? 16 : 1,
                    ),
                    compassEnabled: false,
                    rotateGesturesEnabled: false,
                    zoomGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    // Claim ONLY the scale gesture, not every gesture: an
                    // EagerGestureRecognizer here swallows vertical drags too,
                    // which makes the whole page feel unscrollable wherever
                    // the map is. Pinch-to-zoom still reaches the map, while
                    // one-finger drags fall through to the page scroll. Use
                    // the +/- buttons to zoom without pinching.
                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                      Factory<OneSequenceGestureRecognizer>(
                        () => ScaleGestureRecognizer(),
                      ),
                    },
                    // Show the blue "you are here" dot. Tracking mode is NOT
                    // used here: it re-centres the camera on every fix, which
                    // would fight the user's own zoom/pan. _recentre() below
                    // puts them back on their location on demand.
                    myLocationEnabled: true,
                    myLocationTrackingMode: MyLocationTrackingMode.none,
                  ),
                  // Zoom / recentre controls, since pinch is awkward on a
                  // 260px map embedded in a scrolling page.
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MapButton(
                          icon: Icons.add,
                          tooltip: 'Zoom in',
                          onTap: () => _zoomBy(1),
                        ),
                        const SizedBox(height: 6),
                        _MapButton(
                          icon: Icons.remove,
                          tooltip: 'Zoom out',
                          onTap: () => _zoomBy(-1),
                        ),
                        const SizedBox(height: 6),
                        _MapButton(
                          icon: Icons.my_location,
                          tooltip: 'Recentre on me',
                          onTap: _recentre,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),

        // Live heart rate meter
        const HeartRateMeterCard(),
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
                      value: '${workout.distance.toStringAsFixed(2)} km',
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
                      onPressed: () => _showStatusPicker(context),
                      icon: const Icon(Icons.tune, size: 20),
                      label: Text(
                        workout.manualOverrideActive
                            ? 'Change Status'
                            : 'Choose Status',
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

// ─── Status Picker Sheet ────────────────────────────────────────
/// Picks a workout status (Chill / Slow Run / Sprint Run) and plays one of
/// the Spotify playlists assigned to it in Workout Playlists, instead of
/// choosing an individual song.
class _StatusPickerSheet extends StatelessWidget {
  final WorkoutProvider workout;
  final WorkoutMusicProvider music;
  final PlayerProvider player;

  const _StatusPickerSheet({
    required this.workout,
    required this.music,
    required this.player,
  });

  Future<void> _play(BuildContext context, WorkoutCondition condition) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final pick = music.pickForCondition(condition.id);

    if (pick == null) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('No playlist assigned to ${condition.label} yet.'),
          action: SnackBarAction(
            label: 'Assign',
            onPressed: () =>
                navigator.pushNamed(AppRoutes.workoutMusic),
          ),
        ),
      );
      return;
    }

    navigator.pop();
    try {
      // The playback engine lives at the app root and connects lazily, so it
      // may not be ready if the Spotify section was never opened this session.
      if (!player.isReady) await player.initialize();
      await player.playContext(pick.uri);
      // Stop the BPM timer swapping this out for a keyword-searched track.
      workout.holdMusicSelection(
        label: pick.name,
        subtitle: '${condition.label} mode',
      );
      messenger.showSnackBar(
        SnackBar(content: Text('Playing "${pick.name}" — ${condition.label} mode')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not start playlist: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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
            const SizedBox(height: 16),
            const Text('Choose Status',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Plays a playlist you assigned to that status.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            ...WorkoutMusicProvider.conditions.map((c) {
              final count = music.playlistsFor(c.id).length;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(c.emoji, style: const TextStyle(fontSize: 26)),
                title: Text(c.label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  count == 0
                      ? 'No playlist assigned'
                      : '$count ${count == 1 ? 'playlist' : 'playlists'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: count == 0
                        ? AppTheme.warningColor
                        : AppTheme.textSecondary,
                  ),
                ),
                trailing: const Icon(Icons.play_arrow),
                onTap: () => _play(context, c),
              );
            }),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.workoutMusic);
              },
              icon: const Icon(Icons.queue_music, size: 18),
              label: const Text('Manage Workout Playlists'),
            ),
          ],
        ),
      ),
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

// ─── Map Control Button ─────────────────────────────────────────
class _MapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        elevation: 2,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 20, color: AppTheme.textPrimary),
          ),
        ),
      ),
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


// ─── Runner street view ─────────────────────────────────────────
//
// Reverse-geocodes the current GPS fix so the runner can see which street
// they're on without reading the map. Lookups are throttled and cached per
// ~110 m grid cell inside ReverseGeocodeService (Nominatim's usage policy),
// so this costs roughly one request per block.
class _RunnerStreetView extends StatefulWidget {
  final WorkoutProvider workout;
  const _RunnerStreetView({required this.workout});

  @override
  State<_RunnerStreetView> createState() => _RunnerStreetViewState();
}

class _RunnerStreetViewState extends State<_RunnerStreetView> {
  final _geocoder = ReverseGeocodeService();
  StreetInfo? _info;
  String? _lastCell;

  @override
  void initState() {
    super.initState();
    _maybeLookup();
  }

  @override
  void didUpdateWidget(covariant _RunnerStreetView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeLookup();
  }

  Future<void> _maybeLookup() async {
    final pos = widget.workout.currentPosition;
    if (pos == null) return;
    final lat = pos['latitude'];
    final lng = pos['longitude'];
    if (lat == null || lng == null) return;

    // Only re-query once the runner has moved to a new ~110 m cell.
    final cell = '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';
    if (cell == _lastCell && _info != null) return;

    final result = await _geocoder.lookup(lat, lng);
    if (!mounted || result == null || result.isEmpty) return;
    setState(() {
      _info = result;
      _lastCell = cell;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gpsError = widget.workout.gpsError;
    final pos = widget.workout.currentPosition;

    if (gpsError != null) {
      return _shell(
        icon: Icons.location_disabled,
        iconColor: AppTheme.errorColor,
        title: 'Location unavailable',
        subtitle: gpsError,
      );
    }

    if (pos == null) {
      return _shell(
        icon: Icons.gps_not_fixed,
        iconColor: AppTheme.textSecondary,
        title: 'Acquiring GPS…',
        subtitle: 'Move outdoors for a faster fix',
        showSpinner: true,
      );
    }

    final info = _info;
    return _shell(
      icon: Icons.navigation,
      iconColor: AppTheme.primaryColor,
      title: info?.primary ?? 'Locating street…',
      subtitle: (info != null && info.secondary.isNotEmpty)
          ? info.secondary
          : '${(pos['latitude'] ?? 0).toStringAsFixed(5)}, '
              '${(pos['longitude'] ?? 0).toStringAsFixed(5)}',
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.workout.distance.toStringAsFixed(2),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
              height: 1.0,
            ),
          ),
          Text(
            'km',
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _shell({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    bool showSpinner = false,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: showSpinner
                  ? Padding(
                      padding: const EdgeInsets.all(11),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(iconColor),
                      ),
                    )
                  : Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing,
            ],
          ],
        ),
      ),
    );
  }
}
