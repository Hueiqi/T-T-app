import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/nutrition_provider.dart';
import '../providers/planning_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/auth_provider.dart';
import '../models/planning_model.dart';
import '../config/theme.dart';
import '../config/routes.dart';

class PlanDetailScreen extends StatefulWidget {
  final FitnessPlan plan;

  const PlanDetailScreen({super.key, required this.plan});

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> {
  late FitnessPlan _plan;
  final Set<int> _completedScheduleItems = {};
  int _currentWeek = 1;
  int _streak = 0;
  int _totalWorkoutsDone = 0;
  double _totalCaloriesBurned = 0;

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProgressData();
    });
  }

  void _loadProgressData() {
    final workoutProv = context.read<WorkoutProvider>();
    final auth = context.read<AuthProvider>();
    final planning = context.read<PlanningProvider>();

    if (auth.user != null) {
      workoutProv.loadDashboardData(auth.user!.uid);
    }

    final workouts = workoutProv.workouts;
    _totalWorkoutsDone = workouts.length;
    _totalCaloriesBurned =
        workouts.fold<double>(0, (sum, w) => sum + w.caloriesBurned);

    if (workouts.length >= 2) {
      int streak = 0;
      final now = DateTime.now();
      for (int i = 0; i < workouts.length; i++) {
        if (workouts[i].endTime != null &&
            now.difference(workouts[i].endTime!).inDays <= streak + 1) {
          streak++;
        } else {
          break;
        }
      }
      _streak = streak;
    }

    if (planning.planStartDate != null) {
      _currentWeek = (DateTime.now().difference(planning.planStartDate!).inDays ~/ 7) + 1;
      _currentWeek = _currentWeek.clamp(1, _plan.estimatedGoalWeeks);
    }

    if (mounted) setState(() {});
  }

  WorkoutDay? get _todayWorkout {
    final now = DateTime.now();
    final days = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    final todayAbbr = days[now.weekday - 1];
    for (final w in _plan.weeklyWorkouts) {
      if (w.day.contains(todayAbbr)) return w;
    }
    return null;
  }

  String? get _nextWorkoutFocus {
    final now = DateTime.now();
    final days = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    final todayIdx = now.weekday - 1;
    for (int i = 1; i <= 7; i++) {
      final idx = (todayIdx + i) % 7;
      for (final w in _plan.weeklyWorkouts) {
        if (w.day.contains(days[idx])) return w.focus;
      }
    }
    return null;
  }

  List<String> get _workoutDays {
    final names = <String>[];
    for (final w in _plan.weeklyWorkouts) {
      names.add(w.day.split(' - ').first.split(',').first.trim());
    }
    return names;
  }

  void _showHighlightDetail(String title, String detail) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(detail),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nutrition = context.watch<NutritionProvider>();
    final plan = _plan;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          plan.title.replaceAll(RegExp(r'[^\w\s]'), '').trim(),
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Plan',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share coming soon')),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildProgressHeader(plan)),
          SliverToBoxAdapter(child: _buildDescriptionCard(plan)),
          SliverToBoxAdapter(child: _buildStatsRow(plan, nutrition)),
          SliverToBoxAdapter(child: _buildMacroSection(plan, nutrition)),
          SliverToBoxAdapter(child: _buildTodaysFocus(plan)),
          SliverToBoxAdapter(child: _buildScheduleTimeline(plan)),
          SliverToBoxAdapter(child: _buildWeeklyCalendar(plan)),
          SliverToBoxAdapter(child: _buildHighlightsSection(plan)),
          SliverToBoxAdapter(child: _buildNextUpSection(plan)),
          SliverToBoxAdapter(child: _buildMealPlanPreview(plan)),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.nutrition, (_) => false,
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.restaurant_menu),
        label: const Text('Log Meal'),
      ),
    );
  }

  Widget _buildProgressHeader(FitnessPlan plan) {
    final progress = plan.estimatedGoalWeeks > 0 ? _currentWeek / plan.estimatedGoalWeeks : 0.0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Week $_currentWeek of ${plan.estimatedGoalWeeks}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    plan.tagline,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.white, size: 28),
                  Text(
                    '$_streak',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'day streak',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDifficultyChip(plan.difficulty),
                    const SizedBox(width: 8),
                    _buildChip(
                      '${plan.workoutsPerWeek}/wk',
                      Colors.white.withValues(alpha: 0.2),
                      Colors.white,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '$_totalWorkoutsDone workouts · ${_totalCaloriesBurned.toInt()} kcal',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(FitnessPlan plan) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              plan.description,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(FitnessPlan plan, NutritionProvider nutrition) {
    final calCurrent = nutrition.totalCaloriesToday;
    final calGoal = plan.dailyCalories.toDouble();
    final double calRatio = calGoal > 0 ? (calCurrent / calGoal).clamp(0, 1) : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(child: _buildStatCard(
            icon: Icons.local_fire_department,
            iconColor: Colors.orangeAccent,
            value: '${plan.dailyCalories}',
            label: 'kcal/day',
            child: SizedBox(
              width: 36,
              height: 36,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      value: calRatio,
                      strokeWidth: 3,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        calRatio >= 1 ? Colors.green : Colors.orangeAccent,
                      ),
                    ),
                  ),
                  Text(
                    '${calCurrent.toInt()}',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ),
          )),
          const SizedBox(width: 10),
          Expanded(child: _buildStatCard(
            icon: Icons.fitness_center,
            iconColor: AppTheme.primaryColor,
            value: '$_totalWorkoutsDone',
            label: 'workouts',
            child: Text(
              'done',
              style: TextStyle(fontSize: 10, color: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : AppTheme.textSecondary),
            ),
          )),
          const SizedBox(width: 10),
          Expanded(child: _buildStatCard(
            icon: Icons.whatshot,
            iconColor: Colors.deepOrange,
            value: '$_streak',
            label: 'day streak',
            child: Text(
              '$_totalCaloriesBurned kcal',
              style: TextStyle(fontSize: 9, color: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : AppTheme.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : AppTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

Widget _buildMacroSection(FitnessPlan plan, NutritionProvider nutrition) {
  final currentProtein = nutrition.totalProtein;
  final currentCarbs = nutrition.totalCarbs;
  final currentFat = nutrition.totalFat;
  final goalProtein = plan.proteinG;
  final goalCarbs = plan.carbsG;
  final goalFat = plan.fatG;
  final totalG = goalProtein + goalCarbs + goalFat;

  return Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.pie_chart_outline, size: 18, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              'Daily Macros',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Conditional: macro bar OR fallback text ──
        if (totalG > 0) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Expanded(
                    flex: (goalProtein / totalG * 1000).round(),
                    child: Container(color: Colors.blue.shade400),
                  ),
                  Expanded(
                    flex: (goalCarbs / totalG * 1000).round(),
                    child: Container(color: Colors.orange.shade400),
                  ),
                  Expanded(
                    flex: (goalFat / totalG * 1000).round(),
                    child: Container(color: Colors.pink.shade400),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _macroRow('Protein', currentProtein, goalProtein, Colors.blue.shade400),
          const SizedBox(height: 10),
          _macroRow('Carbs', currentCarbs, goalCarbs, Colors.orange.shade400),
          const SizedBox(height: 10),
          _macroRow('Fat', currentFat, goalFat, Colors.pink.shade400),
        ] else ...[
          Text(
            'No macro goals set for this plan.',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : AppTheme.textSecondary,
            ),
          ),
        ],
      ],
    ),
  );
}

  Widget _macroRow(String label, double current, double goal, Color color) {
    final ratio = (goal > 0 ? (current / goal).clamp(0, 1) : 0.0) as double;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : AppTheme.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${current.toInt()} / ${goal.toInt()}g',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildTodaysFocus(FitnessPlan plan) {
    final today = _todayWorkout;
    if (today == null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bedtime, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rest Day',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Recover and get ready for tomorrow',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.08),
            AppTheme.primaryColor.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.play_circle_fill, color: AppTheme.primaryColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Today's Workout",
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      today.focus,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${today.durationMinutes} min',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: today.exercises.take(5).map((e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                e,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryColor.withValues(alpha: 0.8),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context, AppRoutes.workout, (_) => false,
              ),
              icon: const Icon(Icons.play_arrow, size: 20),
              label: const Text('Start Workout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTimeline(FitnessPlan plan) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Daily Schedule',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(plan.dailySchedule.length, (i) {
            final activity = plan.dailySchedule[i];
            final isChecked = _completedScheduleItems.contains(i);
            final isLast = i == plan.dailySchedule.length - 1;
            final isNext = !isChecked && (i == 0 || _completedScheduleItems.contains(i - 1));
            return _buildTimelineItem(activity, i, isChecked, isLast, isNext);
          }),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
    DailyActivity activity,
    int index,
    bool isChecked,
    bool isLast,
    bool isNext,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              activity.time,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isNext ? AppTheme.primaryColor : Colors.grey,
              ),
            ),
          ),
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: isChecked ? 18 : 14,
                  height: isChecked ? 18 : 14,
                  decoration: BoxDecoration(
                    color: isChecked ? AppTheme.successColor : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isChecked ? AppTheme.successColor : (isNext ? AppTheme.primaryColor : Colors.grey.shade300),
                      width: isChecked ? 0 : 2,
                    ),
                  ),
                  child: isChecked
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isChecked ? AppTheme.successColor.withValues(alpha: 0.3) : Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (isChecked) {
                    _completedScheduleItems.remove(index);
                  } else {
                    _completedScheduleItems.add(index);
                  }
                });
              },
              child: Container(
                margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isNext
                      ? AppTheme.primaryColor.withValues(alpha: 0.05)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isNext
                      ? Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2))
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isChecked
                            ? Colors.grey
                            : (isNext
                                ? AppTheme.primaryColor
                                : (Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : AppTheme.textPrimary)),
                        decoration: isChecked ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    Text(
                      activity.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyCalendar(FitnessPlan plan) {
    final workoutDays = _workoutDays;
    final now = DateTime.now();
    final dayNames = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    final todayAbbr = dayNames[now.weekday - 1];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Weekly Plan',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: dayNames.map((day) {
              final isWorkoutDay = workoutDays.contains(day);
              final isToday = day == todayAbbr;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 56,
                  decoration: BoxDecoration(
                    color: isToday
                        ? AppTheme.primaryColor
                        : (isWorkoutDay
                            ? AppTheme.primaryColor.withValues(alpha: 0.1)
                            : Colors.transparent),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        day,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                          color: isToday ? Colors.white : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        isWorkoutDay ? Icons.fitness_center : Icons.bedtime,
                        size: 14,
                        color: isToday ? Colors.white70 : (isWorkoutDay ? AppTheme.primaryColor : Colors.grey.shade300),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightsSection(FitnessPlan plan) {
    final highlightDetails = [
      {
        'icon': Icons.speed,
        'iconColor': Colors.orangeAccent,
        'title': 'Rapid Results',
        'desc': plan.highlights.isNotEmpty ? plan.highlights[0] : 'Achieve your fitness goals faster with optimized workouts',
      },
      {
        'icon': Icons.restaurant,
        'iconColor': Colors.green,
        'title': 'Smart Nutrition',
        'desc': plan.highlights.length > 1 ? plan.highlights[1] : 'Balanced meal plans designed for your body type',
      },
      {
        'icon': Icons.auto_awesome,
        'iconColor': AppTheme.primaryColor,
        'title': 'AI Optimized',
        'desc': plan.highlights.length > 2 ? plan.highlights[2] : 'Personalized routines that adapt to your progress',
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_outlined, size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Highlights',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          ...highlightDetails.map((h) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showHighlightDetail(
                  h['title'] as String,
                  h['desc'] as String,
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (h['iconColor'] as Color).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          h['icon'] as IconData,
                          color: h['iconColor'] as Color,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              h['title'] as String,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              h['desc'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildNextUpSection(FitnessPlan plan) {
    final next = _nextWorkoutFocus;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.trending_up, color: Colors.green, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What\'s Next',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  next != null ? 'Tomorrow: $next' : 'Check back tomorrow',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 14, color: Colors.green),
                SizedBox(width: 4),
                Text(
                  'On Track',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealPlanPreview(FitnessPlan plan) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.restaurant_menu, size: 18, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Meal Plan',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context, AppRoutes.nutrition, (_) => false,
                ),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('Full Plan', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...plan.meals.take(4).map((m) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    m.meal,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : AppTheme.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${m.calories} kcal',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          )),
          if (plan.mealTips.isNotEmpty) ...[
            const Divider(height: 16),
            ...plan.mealTips.take(2).map((tip) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 14, color: AppTheme.warningColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildDifficultyChip(String difficulty) {
    Color color;
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        color = Colors.green;
        break;
      case 'intermediate':
        color = Colors.orange;
        break;
      case 'advanced':
        color = Colors.redAccent;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        difficulty,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
