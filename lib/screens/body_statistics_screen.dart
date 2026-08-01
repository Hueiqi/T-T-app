import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/nutrition_provider.dart';
import '../providers/sleep_provider.dart';
import '../config/theme.dart';
import '../services/firebase_service.dart';
import '../models/meal_model.dart';
import '../models/user_model.dart';
import '../models/sleep_model.dart';

class BodyStatisticsScreen extends StatefulWidget {
  final bool showAppBar;
  const BodyStatisticsScreen({super.key, this.showAppBar = true});

  @override
  State<BodyStatisticsScreen> createState() => _BodyStatisticsScreenState();
}

enum _StatsPeriod { day, month, year }

class _BodyStatisticsScreenState extends State<BodyStatisticsScreen> {
  int _selectedTab = 0;
  bool _isLoading = true;
  String? _loadError;
  _StatsPeriod _period = _StatsPeriod.day;

  // Macro breakdown works off its own date-range fetch: the provider only ever
  // holds today's meals, which cannot answer a month/year question.
  final FirebaseService _firebaseService = FirebaseService();
  List<Meal> _periodMeals = [];
  bool _loadingMacros = false;

  /// (rangeStart, daysElapsed, caption) for the macro breakdown. Totals are
  /// divided by [daysElapsed] so month/year stay comparable to the *daily*
  /// macro goals; summing a whole year against a one-day target is meaningless.
  (DateTime, int, String) _macroPeriod() {
    final now = DateTime.now();
    switch (_period) {
      case _StatsPeriod.day:
        return (DateTime(now.year, now.month, now.day), 1, 'Today');
      case _StatsPeriod.month:
        return (
          DateTime(now.year, now.month, 1),
          now.day,
          'Total · ${DateFormat('MMMM yyyy').format(now)}',
        );
      case _StatsPeriod.year:
        final start = DateTime(now.year, 1, 1);
        return (
          start,
          now.difference(start).inDays + 1,
          'Total · ${now.year}',
        );
    }
  }

  Future<void> _loadPeriodMeals() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    final (start, _, _) = _macroPeriod();
    setState(() => _loadingMacros = true);
    final meals = await _firebaseService.getMealsForDateRange(
      auth.user!.uid,
      start,
      DateTime.now(),
    );
    if (!mounted) return;
    setState(() {
      _periodMeals = meals;
      _loadingMacros = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final auth = context.read<AuthProvider>();
      if (auth.user == null) {
        if (mounted) setState(() { _isLoading = false; });
        return;
      }
      await Future.wait([
        // The charts bucket by month (6) and year (5); the 30-workout default
        // cannot cover those ranges, so older buckets read as empty.
        context
            .read<WorkoutProvider>()
            .loadDashboardData(auth.user!.uid, workoutLimit: 1000),
        context.read<NutritionProvider>().loadTodayMeals(auth.user!.uid),
        context.read<NutritionProvider>().loadWeightHistory(auth.user!.uid),
        context.read<NutritionProvider>().loadTodayWeight(auth.user!.uid),
        context.read<SleepProvider>().loadSleepData(auth.user!.uid),
      ]);
    } catch (e) {
      if (mounted) {
        setState(() { _loadError = e.toString(); });
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();

    if (!widget.showAppBar) return body;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Body Statistics'),
        backgroundColor: AppTheme.appBarColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
            tooltip: 'Profile',
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 48),
              const SizedBox(height: 16),
              const Text('Something went wrong', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () { setState(() { _isLoading = true; _loadError = null; }); _loadData(); },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final workout = context.watch<WorkoutProvider>();
    final nutrition = context.watch<NutritionProvider>();
    final sleep = context.watch<SleepProvider>();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── BMI CARD ────────────────────────────────────
            if (user != null && user.height > 0) ...[
              Builder(
                builder: (context) {
                  final nutrition = context.watch<NutritionProvider>();
                  final latestWt = nutrition.latestWeight ?? user.weight;
                  final latestBmi = latestWt / ((user.height / 100) * (user.height / 100));
                  return _buildMetricCard(
                    title: 'Body Mass Index (BMI)',
                    value: latestBmi.toStringAsFixed(1),
                    subtitle: _getBmiCategory(latestBmi),
                    icon: Icons.monitor_heart,
                    color: _getBmiColor(latestBmi),
                  );
                },
              ),
            ],
            const SizedBox(height: 16),

            // ─── TABS ────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTabButton('Overview', 0),
                      _buildTabButton('Workout', 1),
                      _buildTabButton('Nutrition', 2),
                      _buildTabButton('Sleep', 3),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ─── PERIOD TOGGLE (Nutrition / Sleep charts) ──
            // Overview no longer has a period-aware chart, so showing the
            // toggle there would be a control that does nothing.
            if (_selectedTab == 2 || _selectedTab == 3) ...[
              _buildPeriodToggle(),
              const SizedBox(height: 16),
            ],

            // ─── TAB CONTENT ────────────────────────────────
            if (_selectedTab == 0)
              _buildOverviewTab(user, workout, nutrition, sleep),
            if (_selectedTab == 1) _buildWorkoutTab(workout, user),
            if (_selectedTab == 2) _buildNutritionTab(nutrition, user),
            if (_selectedTab == 3) _buildSleepTab(sleep),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTab == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedTab = index);
          // Nutrition tab needs its own date-range meal fetch.
          if (index == 2) _loadPeriodMeals();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _StatsPeriod.values.map((p) {
        final isSelected = _period == p;
        final label = switch (p) {
          _StatsPeriod.day => 'Day',
          _StatsPeriod.month => 'Month',
          _StatsPeriod.year => 'Year',
        };
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ChoiceChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (_) {
              setState(() => _period = p);
              if (_selectedTab == 2) _loadPeriodMeals();
            },
            selectedColor: AppTheme.primaryColor,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 12,
            ),
            backgroundColor: Colors.grey.shade100,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide.none,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getBmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal weight';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  Color _getBmiColor(double bmi) {
    if (bmi < 18.5) return Colors.orange;
    if (bmi < 25) return AppTheme.successColor;
    if (bmi < 30) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  // ─── OVERVIEW TAB ────────────────────────────────────────────
  Widget _buildOverviewTab(
    AppUser? user,
    WorkoutProvider workout,
    NutritionProvider nutrition,
    SleepProvider sleep,
  ) {
    return Column(
      children: [
        // Row 1: Avg Heart Rate + Today Calories
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.favorite,
                label: 'Avg Heart Rate',
                value: workout.heartRateHistory.isNotEmpty
                    ? '${(workout.heartRateHistory.reduce((a, b) => a + b) ~/ workout.heartRateHistory.length)} bpm'
                    : workout.workouts.isNotEmpty
                        ? '${workout.workouts.first.avgHeartRate} bpm'
                        : '-- bpm',
                color: AppTheme.accentColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.local_fire_department,
                label: 'Today Calories',
                value: '${nutrition.totalCaloriesToday.toStringAsFixed(0)} kcal',
                color: AppTheme.warningColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 2: Last Sleep + Workouts
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.bedtime,
                label: 'Last Sleep',
                value: sleep.lastNightSleep?.hoursSlept.toStringAsFixed(1) ?? '-- hrs',
                color: AppTheme.secondaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.fitness_center,
                label: 'Workouts',
                value: '${workout.workouts.length} sessions',
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Body Stats Summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Builder(
              builder: (context) {
                final nutrition = context.watch<NutritionProvider>();
                final latestWt = nutrition.latestWeight ?? user?.weight;
                final heightM = user != null ? user.height / 100.0 : 0;
                final latestBmi = (latestWt != null && heightM > 0)
                    ? latestWt / (heightM * heightM)
                    : null;
                final goalProgress = _calculateWeightGoalProgress(user, nutrition);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Body Stats Summary',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildRow('Weight', latestWt != null ? '${latestWt.toStringAsFixed(1)} kg' : '-- kg'),
                    _buildRow('Height', '${user?.height.toStringAsFixed(0) ?? '--'} cm'),
                    _buildRow('BMI', latestBmi != null ? latestBmi.toStringAsFixed(1) : '--'),
                    _buildRow('Target Weight', user?.targetWeightKg != null ? '${user!.targetWeightKg!.toStringAsFixed(1)} kg' : 'Not set'),
                    if (goalProgress != null) ...[
                      const SizedBox(height: 8),
                      _buildWeightGoalProgressIndicator(goalProgress, user),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Buckets [startTimes]-tagged values by the selected period, returning
  /// (labels, totals) with the most recent bucket last.
  (List<String>, List<double>) _bucketByPeriod(
    List<DateTime> timestamps,
    List<double> values,
  ) {
    final now = DateTime.now();
    switch (_period) {
      case _StatsPeriod.day:
        final days = List.generate(7, (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i)));
        const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final labels = days.map((d) => weekdays[d.weekday - 1]).toList();
        final totals = days.map((day) {
          final dayEnd = day.add(const Duration(hours: 24));
          double sum = 0;
          for (var i = 0; i < timestamps.length; i++) {
            if (!timestamps[i].isBefore(day) && timestamps[i].isBefore(dayEnd)) {
              sum += values[i];
            }
          }
          return sum;
        }).toList();
        return (labels, totals);
      case _StatsPeriod.month:
        final months = List.generate(6, (i) {
          final m = DateTime(now.year, now.month - (5 - i), 1);
          return m;
        });
        const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final labels = months.map((m) => monthNames[m.month - 1]).toList();
        final totals = months.map((m) {
          final monthEnd = DateTime(m.year, m.month + 1, 1);
          double sum = 0;
          for (var i = 0; i < timestamps.length; i++) {
            if (!timestamps[i].isBefore(m) && timestamps[i].isBefore(monthEnd)) {
              sum += values[i];
            }
          }
          return sum;
        }).toList();
        return (labels, totals);
      case _StatsPeriod.year:
        final years = List.generate(5, (i) => now.year - (4 - i));
        final labels = years.map((y) => y.toString()).toList();
        final totals = years.map((y) {
          double sum = 0;
          for (var i = 0; i < timestamps.length; i++) {
            if (timestamps[i].year == y) sum += values[i];
          }
          return sum;
        }).toList();
        return (labels, totals);
    }
  }

  // ─── WORKOUT TAB ──────────────────────────────────────────────
  Widget _buildWorkoutTab(WorkoutProvider workout, AppUser? user) {
    final workouts = workout.workouts;

    return Column(
      children: [
        if (workout.heartRateHistory.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Last Workout Stats',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildRow('Max HR', '${workout.heartRateHistory.reduce((a, b) => a > b ? a : b)} bpm'),
                  _buildRow('Min HR', '${workout.heartRateHistory.reduce((a, b) => a < b ? a : b)} bpm'),
                  _buildRow('Avg HR', '${(workout.heartRateHistory.reduce((a, b) => a + b) ~/ workout.heartRateHistory.length)} bpm'),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history, size: 20, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    const Text(
                      'Workout History',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text('${workouts.length} total', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                if (workouts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text('No workouts yet. Start your first workout!', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  )
                else
                  SizedBox(
                    height: workouts.length > 5 ? 300 : workouts.length * 60.0,
                    child: ListView.builder(
                      physics: workouts.length > 5 ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: workouts.length > 20 ? 20 : workouts.length,
                      itemBuilder: (context, index) {
                        final w = workouts[index];
                        final dateStr = DateFormat('MMM dd, HH:mm').format(w.startTime);
                        final dur = w.endTime != null
                            ? '${w.endTime!.difference(w.startTime).inMinutes} min'
                            : 'In progress';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                                      Text(dur, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('${w.caloriesBurned.toStringAsFixed(0)} kcal', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.warningColor)),
                                      Text('HR: ${w.avgHeartRate} bpm', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── NUTRITION TAB ──────────────────────────────────────────
  Widget _buildNutritionTab(NutritionProvider nutrition, AppUser? user) {
    final meals = nutrition.todayMeals;
    final (_, daysElapsed, periodCaption) = _macroPeriod();
    final days = daysElapsed < 1 ? 1 : daysElapsed;

    // Actual intake is the true total across the selected period.
    final protein = _periodMeals.fold(0.0, (t, m) => t + m.protein);
    final carbs = _periodMeals.fold(0.0, (t, m) => t + m.carbs);
    final fat = _periodMeals.fold(0.0, (t, m) => t + m.fat);
    final periodCalories = _periodMeals.fold(0.0, (t, m) => t + m.calories);

    // Goals are daily targets, so scale them over the same number of days.
    // Left unscaled, a month or year of intake would tower over a one-day
    // goal bar and make the comparison meaningless.
    final proteinGoal = nutrition.getProteinGoal() * days;
    final carbsGoal = nutrition.getCarbsGoal() * days;
    final fatGoal = nutrition.getFatGoal() * days;
    final calorieGoal = nutrition.dailyCalorieGoal * days;

    // Ensure maxY is never 0
    final List<double> values = [
      protein,
      proteinGoal,
      carbs,
      carbsGoal,
      fat,
      fatGoal,
    ];
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final maxY = maxVal > 0 ? maxVal * 1.3 : 1.0;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Macronutrient Breakdown',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  periodCaption,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
                if (_loadingMacros) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        // Hidden: yearly totals run into five/six figures, and
                        // the axis labels were unreadable. Exact values are in
                        // the rows below the chart and in the bar tooltips.
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, m) {
                              const labels = ['Protein', 'Carbs', 'Fat'];
                              return Text(labels[v.toInt()], style: const TextStyle(fontSize: 12));
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      barGroups: [
                        BarChartGroupData(x: 0, barRods: [
                          BarChartRodData(
                            toY: protein,
                            color: AppTheme.accentColor,
                            width: 24,
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                          ),
                          BarChartRodData(
                            toY: proteinGoal,
                            color: AppTheme.accentColor.withValues(alpha: 0.2),
                            width: 24,
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                          ),
                        ]),
                        BarChartGroupData(x: 1, barRods: [
                          BarChartRodData(
                            toY: carbs,
                            color: AppTheme.warningColor,
                            width: 24,
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                          ),
                          BarChartRodData(
                            toY: carbsGoal,
                            color: AppTheme.warningColor.withValues(alpha: 0.2),
                            width: 24,
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                          ),
                        ]),
                        BarChartGroupData(x: 2, barRods: [
                          BarChartRodData(
                            toY: fat,
                            color: AppTheme.primaryColor,
                            width: 24,
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                          ),
                          BarChartRodData(
                            toY: fatGoal,
                            color: AppTheme.primaryColor.withValues(alpha: 0.2),
                            width: 24,
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                          ),
                        ]),
                      ],
                      minY: 0,
                      maxY: maxY,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final labels = ['Protein', 'Carbs', 'Fat'];
                            final label = rodIndex == 0 ? 'Current' : 'Goal';
                            return BarTooltipItem(
                              '${labels[group.x.toInt()]} $label: ${rod.toY.toStringAsFixed(0)}g',
                              const TextStyle(color: Colors.white, fontSize: 12),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildRow('Protein', '${protein.toStringAsFixed(0)}g / ${proteinGoal.toInt()}g'),
                _buildRow('Carbs', '${carbs.toStringAsFixed(0)}g / ${carbsGoal.toInt()}g'),
                _buildRow('Fat', '${fat.toStringAsFixed(0)}g / ${fatGoal.toInt()}g'),
                _buildRow('Calories', '${periodCalories.toStringAsFixed(0)} / ${calorieGoal.toStringAsFixed(0)} kcal'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.restaurant, size: 20, color: AppTheme.warningColor),
                    const SizedBox(width: 8),
                    const Text(
                      "Today's Meals",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text('${meals.length} items', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                if (meals.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text('No meals logged today. Tap the camera to log your meal!', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  )
                else
                  ...meals.map((meal) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(meal.foodName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                                Text(meal.mealType, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${meal.calories.toStringAsFixed(0)} kcal', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.warningColor)),
                                Text('P:${meal.protein.toStringAsFixed(0)} C:${meal.carbs.toStringAsFixed(0)} F:${meal.fat.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String get _sleepChartTitle => switch (_period) {
        _StatsPeriod.day => 'Sleep Overview (Last 7 Days)',
        _StatsPeriod.month => 'Sleep Overview (Last 6 Months)',
        _StatsPeriod.year => 'Sleep Overview (Last 5 Years)',
      };

  Widget _buildSleepChart(List<SleepData> allRecords) {
    final (labels, totals) = _bucketByPeriod(
      allRecords.map((r) => r.date).toList(),
      allRecords.map((r) => r.hoursSlept).toList(),
    );
    // Day view sums a single night's hours per bucket; month/year view
    // instead needs an average across the nights that fall in each bucket.
    List<double> values = totals;
    if (_period != _StatsPeriod.day) {
      final now = DateTime.now();
      final counts = List.generate(labels.length, (i) {
        if (_period == _StatsPeriod.month) {
          final m = DateTime(now.year, now.month - (labels.length - 1 - i), 1);
          final monthEnd = DateTime(m.year, m.month + 1, 1);
          return allRecords.where((r) => !r.date.isBefore(m) && r.date.isBefore(monthEnd)).length;
        } else {
          final y = now.year - (labels.length - 1 - i);
          return allRecords.where((r) => r.date.year == y).length;
        }
      });
      values = List.generate(totals.length, (i) => counts[i] > 0 ? totals[i] / counts[i] : 0.0);
    }

    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, m) => Text('${v.toInt()}', style: const TextStyle(fontSize: 10)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, m) {
                final idx = v.toInt();
                if (idx < 0 || idx >= labels.length) return const Text('');
                return Text(labels[idx], style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: List.generate(values.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: values[i],
                color: AppTheme.secondaryColor,
                width: 20,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ],
          );
        }),
        minY: 0,
        maxY: 12,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${values[group.x.toInt()].toStringAsFixed(1)} hrs',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── SLEEP TAB ──────────────────────────────────────────────
  Widget _buildSleepTab(SleepProvider sleep) {
    final history = sleep.sleepHistory;
    final allRecords = sleep.allRecords;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  _sleepChartTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: allRecords.isEmpty
                      ? const Center(child: Text('No sleep data', style: TextStyle(color: AppTheme.textSecondary)))
                      : _buildSleepChart(allRecords),
                ),
                const SizedBox(height: 16),
                if (history.isNotEmpty) ...[
                  _buildRow('Avg Sleep (7d)', '${(history.map((e) => e.hoursSlept).fold(0.0, (a, b) => a + b) / history.length).toStringAsFixed(1)} hrs'),
                  _buildRow('Last night', '${sleep.lastNightSleep?.hoursSlept.toStringAsFixed(1) ?? '0'} hrs'),
                  _buildRow('Deep sleep', '${sleep.lastNightSleep?.deepSleepMinutes ?? 0} min'),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history, size: 20, color: AppTheme.secondaryColor),
                    const SizedBox(width: 8),
                    const Text(
                      'Sleep History',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text('${history.length} records', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                if (history.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text('No sleep data recorded yet.', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  )
                else
                  SizedBox(
                    height: history.length > 5 ? 300 : history.length * 60.0,
                    child: ListView.builder(
                      physics: history.length > 5 ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: history.length > 20 ? 20 : history.length,
                      itemBuilder: (context, index) {
                        final s = history[index];
                        final dateStr = DateFormat('MMM dd').format(s.date);
                        final deepPercent = s.hoursSlept > 0 ? (s.deepSleepMinutes / (s.hoursSlept * 60) * 100) : 0.0;
                        final qualityColor = s.quality == 'good'
                            ? AppTheme.successColor
                            : s.quality == 'moderate'
                                ? AppTheme.warningColor
                                : AppTheme.errorColor;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                                      Row(
                                        children: [
                                          Text('${s.hoursSlept.toStringAsFixed(1)} hrs', style: const TextStyle(fontSize: 12)),
                                          const SizedBox(width: 4),
                                          Icon(Icons.circle, size: 8, color: qualityColor),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('${deepPercent.toStringAsFixed(0)}% deep', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: AppTheme.secondaryColor)),
                                      Text(s.quality, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── WEIGHT GOAL PROGRESS ─────────────────────────────────────
  double? _calculateWeightGoalProgress(AppUser? user, NutritionProvider nutrition) {
    if (user == null || user.targetWeightKg == null || user.targetWeightKg == 0) return null;
    final currentWeight = nutrition.latestWeight ?? user.weight;
    if (currentWeight == 0) return null;

    final startWeight = user.weight;
    final target = user.targetWeightKg!;
    final totalDiff = (startWeight - target).abs();
    if (totalDiff == 0) return 1.0;

    final currentDiff = (startWeight - currentWeight).abs();
    final progress = (currentDiff / totalDiff).clamp(0.0, 1.0);
    return progress;
  }

  Widget _buildWeightGoalProgressIndicator(double progress, AppUser? user) {
    final startWeight = user?.weight ?? 0;
    final target = user?.targetWeightKg ?? 0;
    final lost = (startWeight - (user != null ? (context.read<NutritionProvider>().latestWeight ?? startWeight) : startWeight));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Goal Progress', style: TextStyle(fontSize: 13)),
            Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            color: AppTheme.successColor,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          lost >= 0
              ? '${lost.toStringAsFixed(1)} kg lost of ${(startWeight - target).toStringAsFixed(1)} kg goal'
              : '${(-lost).toStringAsFixed(1)} kg gained, goal: ${target.toStringAsFixed(1)} kg',
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  // ─── HELPER: Row Builder ──────────────────────────────────────
  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

}

// ─── STAT CARD ──────────────────────────────────────────────────
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}