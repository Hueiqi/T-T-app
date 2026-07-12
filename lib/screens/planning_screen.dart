import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../providers/planning_provider.dart';
import '../providers/health_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/nutrition_provider.dart';
import '../models/planning_model.dart';
import '../models/exercise_model.dart';
import '../config/theme.dart';
import '../config/routes.dart';
import '../services/exercise_db.dart';
import '../widgets/bottom_nav_shell.dart';
import 'plan_detail_screen.dart';

class PlanningScreen extends StatefulWidget {
  final bool showBottomNav;
  const PlanningScreen({super.key, this.showBottomNav = true});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {


  String _selectedFilter = 'All';
  ExerciseDb? _dailyExercise;
  ExerciseDb? _gifExercise;
  final _random = Random();
  int _totalWorkouts = 0;
  double _totalCaloriesBurned = 0;
  int _currentStreak = 0;
  double _todayCalories = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPlans();
      _loadBookmarks();
      _loadExercises();
      _loadProgressData();
    });
  }

  void _loadProgressData() {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;

    final workoutProv = context.read<WorkoutProvider>();
    workoutProv.loadDashboardData(auth.user!.uid).then((_) {
      final workouts = workoutProv.workouts;
      _totalWorkouts = workouts.length;
      _totalCaloriesBurned =
          workouts.fold<double>(0, (sum, w) => sum + w.caloriesBurned);
      _todayCalories = workoutProv.todayCaloriesBurned;

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
        _currentStreak = streak;
      }
      if (mounted) setState(() {});
    });

    final nutritionProv = context.read<NutritionProvider>();
    nutritionProv.loadWeeklyCalories(auth.user!.uid);
  }

  void _loadExercises() {
    ExerciseDatabase.load().then((_) {
      final all = ExerciseDatabase.all;
      if (all.isNotEmpty) {
        setState(() {
          _dailyExercise = all[_random.nextInt(all.length)];
          final withGif = all.where((e) => e.gifUrl != null).toList();
          _gifExercise = withGif.isNotEmpty
              ? withGif[_random.nextInt(withGif.length)]
              : _dailyExercise;
        });
      }
    });
  }

  void _loadPlans() async {
    final planning = context.read<PlanningProvider>();
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;

    await planning.loadPlans(auth.user!.uid);
    await planning.loadActivePlan(auth.user!.uid);
    if (planning.activePlan == null &&
        planning.plans.isEmpty &&
        !planning.isGenerating) {
      planning.generatePlans(auth.user!);
    }
  }

  void _loadBookmarks() {
    final planning = context.read<PlanningProvider>();
    final auth = context.read<AuthProvider>();
    if (auth.user != null) {
      planning.loadBookmarks(auth.user!.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final planning = context.watch<PlanningProvider>();
    final auth = context.watch<AuthProvider>();

    return _buildMainScreen(planning, auth);
  }

  Widget _buildMainScreen(PlanningProvider planning, AuthProvider auth) {
    return Scaffold(
      appBar: null,
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Training',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.history, color: AppTheme.primaryColor),
                      tooltip: 'Activity History',
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.activity),
                    ),
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: InkWell(
                onTap: () => Navigator.pushNamed(context, AppRoutes.exerciseLibrary),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: const Color.fromARGB(255, 207, 200, 200), size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Search exercises...',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Quick filter chips
            _buildFilterChips(),
            // Active Plan card (when plan is selected)
            if (planning.activePlan != null)
              _buildActivePlanCard(planning.activePlan!, planning),
            if (planning.isGenerating) _buildGeneratingIndicator(),
            if (planning.error != null && planning.plans.isEmpty)
              _buildErrorBanner(planning, auth),
            _buildAiPlanningButton(planning, auth),
            const SizedBox(height: 8),
            _buildPopularPromoCard(),
            // Bookmarked workouts
            if (planning.bookmarkedWorkouts.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildBookmarkedWorkouts(planning),
            ],
            const SizedBox(height: 8),
            // Exercise Instruction Card
            _buildExerciseInstructionCard(),

            // Workout Progress Card
            _buildWorkoutProgressCard(),
            // Calorie History Card
            _buildCalorieHistoryCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: widget.showBottomNav
          ? buildBottomNavBar(context)
          : null,
    );
  }

  // ── Quick Filter Chips ──
  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: ['All', 'Abs', 'Full Body', 'Cardio', 'Strength']
            .map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedFilter = filter);
                Navigator.pushNamed(
                  context,
                  AppRoutes.exerciseLibrary,
                  arguments: filter == 'All' ? null : filter,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Active Plan / In Progress Card ──
  Widget _buildActivePlanCard(FitnessPlan plan, PlanningProvider planning) {
    final totalWeeks = plan.estimatedGoalWeeks;
    final currentWk = planning.currentWeek;
    final progress = ((currentWk - 1) / totalWeeks).clamp(0.0, 1.0);
    final nextWorkout = plan.weeklyWorkouts.isNotEmpty
        ? plan.weeklyWorkouts.first
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.play_circle_fill,
                      color: AppTheme.successColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Week $currentWk of $totalWeeks · ${plan.difficulty}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: AppTheme.successColor),
                        SizedBox(width: 4),
                        Text(
                          'In Progress',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.successColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Progress bar
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppTheme.successColor.withValues(alpha: 0.1),
                        color: AppTheme.successColor,
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              if (nextWorkout != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.fitness_center, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Next: ${nextWorkout.focus}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${nextWorkout.durationMinutes} min',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlanDetailScreen(plan: plan),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('Continue'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final auth = context.read<AuthProvider>();
                        final planProv = context.read<PlanningProvider>();
                        await planProv.abortPlan();
                        await auth.updateSelectedPlan(null);
                        if (auth.user != null) {
                          await planProv.generatePlans(auth.user!);
                        }
                      },
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Change Plan'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: const BorderSide(color: AppTheme.errorColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bookmarked Workouts ──
  Widget _buildBookmarkedWorkouts(PlanningProvider planning) {
    final bookmarks = planning.bookmarkedWorkouts;
    final show = bookmarks.length > 3 ? bookmarks.sublist(0, 3) : bookmarks;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bookmark, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              const Text(
                'Your Saved Routines',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              if (bookmarks.length > 3)
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.activity),
                  child: Text(
                    'View All (${bookmarks.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...show.map((w) {
            final title = w['title'] as String? ?? '';
            final duration = w['durationMinutes'] as int? ?? 0;
            final difficulty = w['difficulty'] as String? ?? '';
            final colorValue = w['color'] as int? ?? 0xFF818CF8;
            final color = Color(colorValue);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.pushNamed(context, AppRoutes.workoutDetail),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.fitness_center, color: color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (difficulty.isNotEmpty) ...[
                                  Text(
                                    difficulty,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Icon(Icons.timer_outlined, size: 12, color: AppTheme.textSecondary),
                                const SizedBox(width: 2),
                                Text(
                                  '${duration}min',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.workoutDetail),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Resume',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Workout Progress Card ──
  Widget _buildWorkoutProgressCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.show_chart,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Your Progress',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _progressStat(
                    Icons.fitness_center,
                    '$_totalWorkouts',
                    'Workouts',
                    AppTheme.primaryColor,
                  ),
                  _progressStat(
                    Icons.local_fire_department,
                    '${_totalCaloriesBurned.toInt()}',
                    'Total kcal',
                    Colors.orangeAccent,
                  ),
                  _progressStat(
                    Icons.whatshot,
                    '$_currentStreak',
                    'Day streak',
                    Colors.deepOrange,
                  ),
                  _progressStat(
                    Icons.today,
                    '${_todayCalories.toInt()}',
                    'Today kcal',
                    AppTheme.successColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressStat(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Calorie History Card ──
  Widget _buildCalorieHistoryCard() {
    final nutrition = context.watch<NutritionProvider>();
    final weekly = nutrition.weeklyCalories;
    final weekAvg = nutrition.weeklyAverage;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.bar_chart,
                      color: Colors.orangeAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Weekly Calories',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Avg ${weekAvg.toInt()}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.orangeAccent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (weekly.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'No calorie data yet. Start logging meals!',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                )
              else
                ...weekly.entries.map((entry) {
                  final parts = entry.key.split('-');
                  final day = parts.length == 3
                      ? '${int.parse(parts[1])}/${int.parse(parts[2])}'
                      : entry.key;
                  final maxCal = weekly.values
                      .fold<double>(0, (a, b) => a > b ? a : b);
                  final raw = maxCal > 0 ? entry.value / maxCal : 0.0;
                  final ratio = raw < 0.0 ? 0.0 : (raw > 1.0 ? 1.0 : raw);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          child: Text(
                            day,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ratio,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                entry.value >= 2000
                                    ? Colors.orangeAccent
                                    : AppTheme.successColor,
                              ),
                              minHeight: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 48,
                          child: Text(
                            '${entry.value.toInt()}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper UI widgets ──
  Widget _buildGeneratingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.indigo50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'AI is creating your personalized plans...',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(PlanningProvider planning, AuthProvider auth) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              planning.error ?? 'Could not generate plans',
              style: const TextStyle(fontSize: 13, color: AppTheme.errorColor),
            ),
          ),
          TextButton(
            onPressed: () {
              if (auth.user != null) planning.generatePlans(auth.user!);
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showAiPlans(PlanningProvider planning) {
    if (planning.plans.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
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
              const Text(
                'Your AI Plans',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${planning.plans.length} personalized plans generated',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              ...planning.plans.map(
                (plan) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PlanCard(
                    plan: plan,
                    isSelected: plan.isSelected,
                    onTap: () async {
                      final currentAuth = context.read<AuthProvider>();
                      if (currentAuth.user != null) {
                        await planning.selectPlan(
                            plan.id, currentAuth.user!.uid);
                        await currentAuth.updateSelectedPlan(plan.id);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPopularPromoCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, AppRoutes.popularWorkouts),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF472B6), Color(0xFFFB923C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF472B6).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🧘', style: TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Popular 10-Min Routines',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Abs · Beginner Abs · Full Body',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiPlanningButton(PlanningProvider planning, AuthProvider auth) {
    final hasPlans = planning.plans.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: () {
          if (auth.user != null) {
            if (hasPlans) {
              _showAiPlans(planning);
            } else {
              planning.generatePlans(auth.user!);
            }
          } else {
            Navigator.pushReplacementNamed(context, '/login');
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Smart Planning',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasPlans
                            ? '${planning.plans.length} plans ready — tap to view'
                            : 'Get personalized plans based on your goals & preferences',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Exercise Instruction Card ──
  Widget _buildExerciseInstructionCard() {
    final ex = _dailyExercise;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.menu_book,
                      color: AppTheme.warningColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ex != null ? 'Today\'s Exercise' : 'Exercise Library',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (ex != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ex.level,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.warningColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (ex != null) ...[
                Text(
                  ex.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildTagChip(ex.equipment, AppTheme.primaryColor),
                    ...ex.primaryMuscles.map(
                      (m) => _buildTagChip(m, AppTheme.successColor),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Instructions',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                ...List.generate(ex.instructions.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ex.instructions[i],
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.fitness_center, size: 32, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                        const SizedBox(height: 8),
                        Text(
                          'Browse exercises from the library',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }


  Widget _buildExerciseImageFallback(ExerciseDb? ex) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppTheme.indigo50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, color: AppTheme.primaryColor.withValues(alpha: 0.4), size: 28),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                ex != null ? ex.name : 'Start a workout to see exercise demos',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.primaryColor.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final FitnessPlan plan;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.tagline,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.85)
                          : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildChip(
                        plan.difficulty,
                        isSelected
                            ? Colors.white.withValues(alpha: 0.2)
                            : AppTheme.indigo100,
                        isSelected ? Colors.white : AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      _buildChip(
                        '${plan.dailyCalories} kcal',
                        isSelected
                            ? Colors.white.withValues(alpha: 0.2)
                            : AppTheme.indigo100,
                        isSelected ? Colors.white : AppTheme.primaryColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                Text(
                  '${plan.workoutsPerWeek}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppTheme.primaryColor,
                  ),
                ),
                Text(
                  ' workouts',
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.75)
                        : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${plan.workoutDurationMinutes} min',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}
