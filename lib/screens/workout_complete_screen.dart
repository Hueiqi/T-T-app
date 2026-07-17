import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/workout_model.dart';

class WorkoutCompleteScreen extends StatefulWidget {
  final Map<String, dynamic> result;

  const WorkoutCompleteScreen({super.key, required this.result});

  @override
  State<WorkoutCompleteScreen> createState() => _WorkoutCompleteScreenState();
}

class _WorkoutCompleteScreenState extends State<WorkoutCompleteScreen>
    with SingleTickerProviderStateMixin {
  MapLibreMapController? _mapController;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  double get _distance => (widget.result['distance'] as double?) ?? 0;
  double get _calories => (widget.result['caloriesBurned'] as double?) ?? 0;
  int get _durationSeconds =>
      (widget.result['durationSeconds'] as int?) ?? 0;
  int get _avgHr => (widget.result['avgHr'] as int?) ?? 0;
  int get _maxHr => (widget.result['maxHr'] as int?) ?? 0;
  bool get _hasHrData => (widget.result['hasHrData'] as bool?) ?? false;
  Workout? get _workout => widget.result['workout'] as Workout?;
  List<Map<String, double>> get _routePoints =>
      (widget.result['routePoints'] as List<Map<String, double>>?) ?? [];

  String get _formattedDuration {
    final h = _durationSeconds ~/ 3600;
    final m = (_durationSeconds % 3600) ~/ 60;
    final s = _durationSeconds % 60;
    if (h > 0) {
      return '${h}h ${m}m ${s}s';
    }
    return '${m}m ${s}s';
  }

  String get _timeRange {
    if (_workout == null) return '';
    final start = DateFormat('h:mm a').format(_workout!.startTime);
    final end = _workout!.endTime != null
        ? DateFormat('h:mm a').format(_workout!.endTime!)
        : '';
    return '$start - $end';
  }

  String get _workoutTypeLabel {
    switch (_workout?.type) {
      case 'running':
        return 'Run';
      case 'walking':
        return 'Walk';
      default:
        return 'Workout';
    }
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    if (_routePoints.length >= 2) {
      _drawRoute();
    }
  }

  Future<void> _drawRoute() async {
    if (_mapController == null || _routePoints.length < 2) return;

    final coordinates = _routePoints
        .map((p) => LatLng(p['lat']!, p['lng']!))
        .toList();

    await _mapController!.addLine(
      LineOptions(
        geometry: coordinates,
        lineColor: '#6366F1',
        lineWidth: 4.0,
      ),
    );

    await _mapController!.addCircle(
      CircleOptions(
        geometry: coordinates.first,
        circleRadius: 8,
        circleColor: '#22C55E',
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 2,
      ),
    );

    await _mapController!.addCircle(
      CircleOptions(
        geometry: coordinates.last,
        circleRadius: 8,
        circleColor: '#EF4444',
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 2,
      ),
    );

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
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, left: 60, top: 60, right: 60, bottom: 60));
  }

  @override
  Widget build(BuildContext context) {
    final hasRoute = _routePoints.length >= 2;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppTheme.successColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle,
                                color: AppTheme.successColor,
                                size: 48,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '$_workoutTypeLabel Complete!',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            if (_workout?.endTime != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _timeRange,
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (hasRoute)
                        SlideTransition(
                          position: _slideAnim,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: SizedBox(
                                height: 220,
                                width: double.infinity,
                                child: MapLibreMap(
                                  onMapCreated: _onMapCreated,
                                  styleString:
                                      'https://tiles.openfreemap.org/styles/positron',
                                  initialCameraPosition: CameraPosition(
                                    target: LatLng(
                                      _routePoints.first['lat']!,
                                      _routePoints.first['lng']!,
                                    ),
                                    zoom: 14,
                                  ),
                                  compassEnabled: false,
                                  rotateGesturesEnabled: false,
                                  zoomGesturesEnabled: false,
                                  dragEnabled: false,
                                  scrollGesturesEnabled: false,
                                  tiltGesturesEnabled: false,
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.straighten,
                                  label: 'Distance',
                                  value: '${_distance.toStringAsFixed(2)} km',
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.timer,
                                  label: 'Duration',
                                  value: _formattedDuration,
                                  color: AppTheme.accentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.local_fire_department,
                                  label: 'Calories',
                                  value: '${_calories.toStringAsFixed(0)} kcal',
                                  color: AppTheme.warningColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (_hasHrData)
                                Expanded(
                                  child: _StatCard(
                                    icon: Icons.favorite,
                                    label: 'Avg HR',
                                    value: '$_avgHr bpm',
                                    color: AppTheme.errorColor,
                                  ),
                                )
                              else
                                const Expanded(child: SizedBox()),
                            ],
                          ),
                        ),
                      ),
                      if (_hasHrData && _maxHr > 0) ...[
                        const SizedBox(height: 12),
                        FadeTransition(
                          opacity: _fadeAnim,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    icon: Icons.favorite,
                                    label: 'Max HR',
                                    value: '$_maxHr bpm',
                                    color: AppTheme.errorColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (_distance > 0)
                                  Expanded(
                                    child: _StatCard(
                                      icon: Icons.speed,
                                      label: 'Avg Pace',
                                      value: _pace,
                                      color: AppTheme.successColor,
                                    ),
                                  )
                                else
                                  const Expanded(child: SizedBox()),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/home');
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _pace {
    if (_distance <= 0 || _durationSeconds <= 0) return '--';
    final totalSeconds = _durationSeconds;
    final paceSeconds = (totalSeconds / _distance).round();
    final pMin = paceSeconds ~/ 60;
    final pSec = paceSeconds % 60;
    return '$pMin:${pSec.toString().padLeft(2, '0')} /km';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
