import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/nutrition_provider.dart';
import '../providers/sleep_provider.dart';
import '../providers/motion_provider.dart';
import '../providers/place_provider.dart';
import '../config/theme.dart';
import '../models/user_model.dart';
import '../models/workout_model.dart';
import '../widgets/custom_header.dart';

class BodyStatisticsScreen extends StatefulWidget {
  const BodyStatisticsScreen({super.key});

  @override
  State<BodyStatisticsScreen> createState() => _BodyStatisticsScreenState();
}

class _BodyStatisticsScreenState extends State<BodyStatisticsScreen> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    context.read<WorkoutProvider>().loadDashboardData(auth.user!.uid);
    context.read<NutritionProvider>().loadTodayMeals(auth.user!.uid);
    context.read<SleepProvider>().loadSleepData(auth.user!.uid);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final workout = context.watch<WorkoutProvider>();
    final nutrition = context.watch<NutritionProvider>();
    final sleep = context.watch<SleepProvider>();
    final motion = context.watch<MotionProvider>();
    final place = context.watch<PlaceProvider>();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── APP BAR (FIXED COLOR) ────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Body Statistics',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (auth.user == null)
                      IconButton(
                        icon: const Icon(Icons.login, color: Colors.white),
                        onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.person_outline, color: Colors.white),
                      onPressed: () => Navigator.pushNamed(context, '/profile'),
                      tooltip: 'Profile',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (user != null && user.height > 0)
                _buildMetricCard(
                  title: 'Body Mass Index (BMI)',
                  value: user.bmi.toStringAsFixed(1),
                  subtitle: _getBmiCategory(user.bmi),
                  icon: Icons.monitor_heart,
                  color: _getBmiColor(user.bmi),
                ),
              const SizedBox(height: 16),

              // ─── TABS ─────────────────────────────────────────
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
                        _buildTabButton('Movement', 4),
                        _buildTabButton('Places', 5),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ─── TABS CONTENT ──────────────────────────────
              if (_selectedTab == 0)
                _buildOverviewTab(user, workout, nutrition, sleep),
              if (_selectedTab == 1) _buildWorkoutTab(workout, user),
              if (_selectedTab == 2) _buildNutritionTab(nutrition, user),
              if (_selectedTab == 3) _buildSleepTab(sleep),
              if (_selectedTab == 4) _buildMovementTab(motion),
              if (_selectedTab == 5) _buildPlacesTab(place),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTab == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
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

  // ─── OVERVIEW TAB (FIXED ROW LAYOUT) ─────────────────────────
  Widget _buildOverviewTab(
    AppUser? user,
    WorkoutProvider workout,
    NutritionProvider nutrition,
    SleepProvider sleep,
  ) {
    return Column(
      children: [
        // ─── Row 1: Avg Heart Rate + Today Calories ──────────
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            Flexible(
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
            Flexible(
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

        // ─── Row 2: Last Sleep + Workouts ─────────────────────
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            Flexible(
              child: _StatCard(
                icon: Icons.bedtime,
                label: 'Last Sleep',
                value: sleep.lastNightSleep?.hoursSlept.toStringAsFixed(1) ?? '-- hrs',
                color: AppTheme.secondaryColor,
              ),
            ),
            Flexible(
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

        if (workout.workouts.length >= 2)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weekly Calories Burned',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _buildWeeklyCaloriesChart(workout.workouts),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),

        // ─── Body Stats Summary ──────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Body Stats Summary',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildRow('Weight', '${user?.weight.toStringAsFixed(1) ?? '--'} kg'),
                _buildRow('Height', '${user?.height.toStringAsFixed(0) ?? '--'} cm'),
                _buildRow('BMI', user != null ? user.bmi.toStringAsFixed(1) : '--'),
                _buildRow('Target Weight', user?.targetWeightKg != null ? '${user!.targetWeightKg!.toStringAsFixed(1)} kg' : 'Not set'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyCaloriesChart(List<Workout> allWorkouts) {
    final last7Days = List.generate(7, (i) {
      final d = DateTime.now().subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });

    final dayLabels = last7Days.map((d) {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[d.weekday - 1];
    }).toList();

    final dailyCalories = last7Days.map((day) {
      final dayEnd = day.add(const Duration(hours: 24));
      return allWorkouts
          .where((w) =>
              w.endTime != null &&
              w.endTime!.isAfter(day) &&
              w.endTime!.isBefore(dayEnd))
          .fold<double>(0, (sum, w) => sum + w.caloriesBurned);
    }).toList();

    final maxCals = dailyCalories.reduce((a, b) => a > b ? a : b);
    final chartMax = maxCals > 0 ? maxCals * 1.3 : 500.0;

    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
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
              getTitlesWidget: (v, m) => Text(dayLabels[v.toInt()], style: const TextStyle(fontSize: 10)),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: List.generate(7, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: dailyCalories[i],
                color: AppTheme.primaryColor,
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
        maxY: chartMax,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${dailyCalories[group.x.toInt()].toStringAsFixed(0)} kcal',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutTab(WorkoutProvider workout, AppUser? user) {
    final workouts = workout.workouts;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Heart Rate Zones Distribution',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: _buildHeartRatePieChart(workout.heartRateHistory),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
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

  Widget _buildNutritionTab(NutritionProvider nutrition, AppUser? user) {
    final meals = nutrition.todayMeals;
    final proteinGoal = nutrition.getProteinGoal();
    final carbsGoal = nutrition.getCarbsGoal();
    final fatGoal = nutrition.getFatGoal();

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
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (v, m) => Text('${v.toInt()}g', style: const TextStyle(fontSize: 10)),
                          ),
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
                            toY: nutrition.totalProtein,
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
                            toY: nutrition.totalCarbs,
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
                            toY: nutrition.totalFat,
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
                      maxY: [
                        nutrition.totalProtein,
                        proteinGoal,
                        nutrition.totalCarbs,
                        carbsGoal,
                        nutrition.totalFat,
                        fatGoal,
                      ].reduce((a, b) => a > b ? a : b) * 1.3,
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
                _buildRow('Protein', '${nutrition.totalProtein.toStringAsFixed(0)}g / ${proteinGoal.toInt()}g'),
                _buildRow('Carbs', '${nutrition.totalCarbs.toStringAsFixed(0)}g / ${carbsGoal.toInt()}g'),
                _buildRow('Fat', '${nutrition.totalFat.toStringAsFixed(0)}g / ${fatGoal.toInt()}g'),
                _buildRow('Calories', '${nutrition.totalCaloriesToday.toStringAsFixed(0)} / ${nutrition.dailyCalorieGoal.toStringAsFixed(0)} kcal'),
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

  Widget _buildSleepTab(SleepProvider sleep) {
    final history = sleep.sleepHistory;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Weekly Sleep Overview',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: history.isEmpty
                      ? const Center(child: Text('No sleep data', style: TextStyle(color: AppTheme.textSecondary)))
                      : LineChart(
                          LineChartData(
                            gridData: FlGridData(show: true, drawVerticalLine: false),
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
                                    if (idx < 0 || idx >= history.length) return const Text('');
                                    final dates = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                                    return Text(dates[history[idx].date.weekday - 1], style: const TextStyle(fontSize: 10));
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.hoursSlept)).toList(),
                                isCurved: true,
                                color: AppTheme.secondaryColor,
                                dotData: const FlDotData(show: true),
                                belowBarData: BarAreaData(show: true, color: AppTheme.secondaryColor.withValues(alpha: 0.1)),
                              ),
                            ],
                            minY: 0,
                            maxY: 12,
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipItems: (spots) => spots.map((s) {
                                  return LineTooltipItem('${s.y.toStringAsFixed(1)} hrs', const TextStyle(color: Colors.white, fontSize: 12));
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
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

  Widget _buildMovementTab(MotionProvider motion) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Today's Movement",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.directions_walk,
                    label: 'Steps',
                    value: '${motion.stepsToday}',
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.speed,
                    label: 'Intensity',
                    value: '${(motion.motionIntensity * 100).toInt()}%',
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Intensity is calculated from gyroscope rotation speed (0-1).',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlacesTab(PlaceProvider place) {
    final places = place.visitedPlaces;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Visited Places',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('${places.length} total',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            if (places.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'No places logged yet. Stay in one spot for 15 min!',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              )
            else
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: places.length > 10 ? 10 : places.length,
                  itemBuilder: (context, index) {
                    final p = places[index];
                    return ListTile(
                      leading: const Icon(Icons.location_on,
                          color: AppTheme.primaryColor),
                      title: Text(
                          '${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}'),
                      subtitle: Text('Visited: ${p.visitedAt.toLocal()}'),
                      dense: true,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

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

  Widget _buildHeartRatePieChart(List<int> hrHistory) {
    if (hrHistory.isEmpty) return const Center(child: Text('No HR data', style: TextStyle(color: AppTheme.textSecondary)));
    int resting = hrHistory.where((hr) => hr < 60).length;
    int normal = hrHistory.where((hr) => hr >= 60 && hr < 100).length;
    int fatBurn = hrHistory.where((hr) => hr >= 100 && hr < 130).length;
    int cardio = hrHistory.where((hr) => hr >= 130 && hr < 160).length;
    int peak = hrHistory.where((hr) => hr >= 160).length;
    final sections = [
      PieChartSectionData(value: resting.toDouble(), title: 'Resting', color: Colors.blue, radius: 60),
      PieChartSectionData(value: normal.toDouble(), title: 'Normal', color: Colors.green, radius: 60),
      PieChartSectionData(value: fatBurn.toDouble(), title: 'Fat Burn', color: AppTheme.warningColor, radius: 60),
      PieChartSectionData(value: cardio.toDouble(), title: 'Cardio', color: AppTheme.accentColor, radius: 60),
      PieChartSectionData(value: peak.toDouble(), title: 'Peak', color: AppTheme.errorColor, radius: 60),
    ].where((s) => s.value > 0).toList();
    return PieChart(PieChartData(sections: sections));
  }
}

// ─── STAT CARD (with overflow protection) ──────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}