import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';
import '../models/workout_model.dart';
import '../config/theme.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Workout> _allWorkouts = [];
  bool _loading = true;
  DateTime? _selectedDate;
  final ScrollController _calendarScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  @override
  void dispose() {
    _calendarScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkouts() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    setState(() => _loading = true);
    final workouts = await _firebaseService.getWorkouts(auth.user!.uid);
    if (!mounted) return;
    setState(() {
      _allWorkouts = workouts.where((w) => w.endTime != null).toList();
      _loading = false;
    });
  }

  List<Workout> get _displayedWorkouts {
    if (_selectedDate == null) return _allWorkouts;
    final startOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
    final endOfDay = startOfDay.add(const Duration(hours: 24));
    return _allWorkouts
        .where((w) => w.startTime.isAfter(startOfDay) && w.startTime.isBefore(endOfDay))
        .toList();
  }

  Map<String, List<Workout>> get _groupedWorkouts {
    final map = <String, List<Workout>>{};
    for (final w in _displayedWorkouts) {
      final key = DateFormat('yyyy-MM-dd').format(w.startTime);
      map.putIfAbsent(key, () => []).add(w);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSummaryRow(),
            _buildCalendarStrip(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _displayedWorkouts.isEmpty
                      ? _buildEmptyState()
                      : _buildWorkoutList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: AppTheme.appBarColor),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          const Text(
            'Workout History',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadWorkouts,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    final workouts = _displayedWorkouts;
    final totalDistance = workouts.fold<double>(0, (s, w) => s + w.distance);
    final totalCalories = workouts.fold<double>(0, (s, w) => s + w.caloriesBurned);
    final totalMinutes = workouts.fold<int>(0, (s, w) => s + w.duration.inMinutes);
    final count = workouts.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          _SummaryItem(
            icon: Icons.fitness_center,
            value: '$count',
            label: 'Workouts',
            color: AppTheme.primaryColor,
          ),
          _SummaryItem(
            icon: Icons.straighten,
            value: '${totalDistance.toStringAsFixed(1)} km',
            label: 'Distance',
            color: AppTheme.successColor,
          ),
          _SummaryItem(
            icon: Icons.local_fire_department,
            value: '${totalCalories.toStringAsFixed(0)}',
            label: 'Calories',
            color: AppTheme.warningColor,
          ),
          _SummaryItem(
            icon: Icons.timer,
            value: '${totalMinutes}m',
            label: 'Duration',
            color: AppTheme.accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarStrip() {
    final now = DateTime.now();
    final dates = List.generate(30, (i) => now.subtract(Duration(days: 29 - i)));

    return SizedBox(
      height: 72,
      child: ListView.builder(
        controller: _calendarScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = _selectedDate != null &&
              date.year == _selectedDate!.year &&
              date.month == _selectedDate!.month &&
              date.day == _selectedDate!.day;
          final hasWorkout = _allWorkouts.any((w) =>
              w.startTime.year == date.year &&
              w.startTime.month == date.month &&
              w.startTime.day == date.day);

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = isSelected ? null : date;
              });
            },
            child: Container(
              width: 48,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : Colors.grey.shade200,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(date),
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.white70 : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  if (hasWorkout) ...[
                    const SizedBox(height: 2),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : AppTheme.successColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.fitness_center,
            size: 64,
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedDate != null ? 'No workouts on this day' : 'No workouts yet',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedDate != null
                ? 'Try selecting a different date'
                : 'Complete a workout to see your history here',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutList() {
    final grouped = _groupedWorkouts;
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: _loadWorkouts,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: sortedKeys.length,
        itemBuilder: (context, index) {
          final dateKey = sortedKeys[index];
          final dayWorkouts = grouped[dateKey]!;
          final date = DateTime.parse(dateKey);
          final dateLabel = _isToday(date)
              ? 'Today'
              : _isYesterday(date)
                  ? 'Yesterday'
                  : DateFormat('EEEE, MMMM d').format(date);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  dateLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              ...dayWorkouts.map((w) => _WorkoutCard(workout: w)),
            ],
          );
        },
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _SummaryItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final Workout workout;

  const _WorkoutCard({required this.workout});

  String _typeLabel(String type) {
    switch (type) {
      case 'running':
        return 'Run';
      case 'walking':
        return 'Walk';
      default:
        return 'Workout';
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'running':
        return Icons.directions_run;
      case 'walking':
        return Icons.directions_walk;
      default:
        return Icons.fitness_center;
    }
  }

  String _formattedDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final timeRange =
        '${DateFormat('h:mm a').format(workout.startTime)} - ${workout.endTime != null ? DateFormat('h:mm a').format(workout.endTime!) : '--'}';
    final pace = _pace;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _WorkoutDetailScreen(workout: workout),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _typeIcon(workout.type),
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _typeLabel(workout.type),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          timeRange,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _WorkoutMetric(
                    icon: Icons.straighten,
                    value: '${workout.distance.toStringAsFixed(2)} km',
                    color: AppTheme.primaryColor,
                  ),
                  _WorkoutMetric(
                    icon: Icons.timer,
                    value: _formattedDuration(workout.duration),
                    color: AppTheme.accentColor,
                  ),
                  _WorkoutMetric(
                    icon: Icons.local_fire_department,
                    value: '${workout.caloriesBurned.toStringAsFixed(0)} kcal',
                    color: AppTheme.warningColor,
                  ),
                  if (workout.avgHeartRate > 0)
                    _WorkoutMetric(
                      icon: Icons.favorite,
                      value: '${workout.avgHeartRate} bpm',
                      color: AppTheme.errorColor,
                    ),
                ],
              ),
              if (pace != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.speed, size: 14, color: AppTheme.successColor),
                    const SizedBox(width: 4),
                    Text(
                      'Avg pace: $pace',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? get _pace {
    if (workout.distance <= 0 || workout.duration.inSeconds <= 0) return null;
    final paceSeconds = (workout.duration.inSeconds / workout.distance).round();
    final pMin = paceSeconds ~/ 60;
    final pSec = paceSeconds % 60;
    return '$pMin:${pSec.toString().padLeft(2, '0')} /km';
  }
}

class _WorkoutMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _WorkoutMetric({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Workout Detail Screen ──────────────────────────────────────────

class _WorkoutDetailScreen extends StatefulWidget {
  final Workout workout;

  const _WorkoutDetailScreen({required this.workout});

  @override
  State<_WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<_WorkoutDetailScreen> {
  MapLibreMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    if (widget.workout.routePoints.length >= 2) {
      _drawRoute();
    }
  }

  Future<void> _drawRoute() async {
    if (_mapController == null || widget.workout.routePoints.length < 2) return;

    final coordinates = widget.workout.routePoints
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
    _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, left: 60, top: 60, right: 60, bottom: 60));
  }

  String _formattedDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    return '${m}m ${s}s';
  }

  String get _pace {
    if (widget.workout.distance <= 0 || widget.workout.duration.inSeconds <= 0) return '--';
    final paceSeconds =
        (widget.workout.duration.inSeconds / widget.workout.distance).round();
    final pMin = paceSeconds ~/ 60;
    final pSec = paceSeconds % 60;
    return '$pMin:${pSec.toString().padLeft(2, '0')} /km';
  }

  String get _workoutTypeLabel {
    switch (widget.workout.type) {
      case 'running':
        return 'Run';
      case 'walking':
        return 'Walk';
      default:
        return 'Workout';
    }
  }

  @override
  Widget build(BuildContext context) {
    final workout = widget.workout;
    final hasRoute = workout.routePoints.length >= 2;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(color: AppTheme.appBarColor),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_workoutTypeLabel - ${DateFormat('MMM d, yyyy').format(workout.startTime)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (workout.endTime != null)
                      Text(
                        '${DateFormat('h:mm a').format(workout.startTime)} - ${DateFormat('h:mm a').format(workout.endTime!)}',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (hasRoute)
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
                            styleString:
                                'https://tiles.openfreemap.org/styles/positron',
                            initialCameraPosition: CameraPosition(
                              target: LatLng(
                                workout.routePoints.first['lat']!,
                                workout.routePoints.first['lng']!,
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.straighten,
                            label: 'Distance',
                            value: '${workout.distance.toStringAsFixed(2)} km',
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.timer,
                            label: 'Duration',
                            value: _formattedDuration(workout.duration),
                            color: AppTheme.accentColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.local_fire_department,
                            label: 'Calories',
                            value: '${workout.caloriesBurned.toStringAsFixed(0)} kcal',
                            color: AppTheme.warningColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (workout.avgHeartRate > 0)
                          Expanded(
                            child: _StatCard(
                              icon: Icons.favorite,
                              label: 'Avg HR',
                              value: '${workout.avgHeartRate} bpm',
                              color: AppTheme.errorColor,
                            ),
                          )
                        else
                          const Expanded(child: SizedBox()),
                      ],
                    ),
                    if (workout.maxHeartRate > 0) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.favorite,
                              label: 'Max HR',
                              value: '${workout.maxHeartRate} bpm',
                              color: AppTheme.errorColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (workout.distance > 0)
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
                    ],
                    if (workout.heartRateReadings.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Heart Rate Readings',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 100,
                                child: _HrMiniChart(
                                    readings: workout.heartRateReadings),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

class _HrMiniChart extends StatelessWidget {
  final List<int> readings;

  const _HrMiniChart({required this.readings});

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < readings.length; i++) {
      spots.add(FlSpot(i.toDouble(), readings[i].toDouble()));
    }

    final minHr = readings.reduce((a, b) => a < b ? a : b).toDouble();
    final maxHr = readings.reduce((a, b) => a > b ? a : b).toDouble();
    final range = (maxHr - minHr).clamp(1.0, double.infinity);

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: minHr - range * 0.1,
        maxY: maxHr + range * 0.1,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.errorColor,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.errorColor.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}
