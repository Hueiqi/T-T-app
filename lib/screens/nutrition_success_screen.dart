import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/nutrition_provider.dart';
import '../config/theme.dart';
import '../models/meal_model.dart';

class NutritionSuccessScreen extends StatelessWidget {
  final Meal meal;

  const NutritionSuccessScreen({super.key, required this.meal});

  @override
  Widget build(BuildContext context) {
    final nutrition = context.watch<NutritionProvider>();
    final todayCalories = nutrition.totalCaloriesToday;
    final goal = nutrition.dailyCalorieGoal;
    final progress = (todayCalories / goal).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Custom Header (close button) ────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Meal Logged',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  // Placeholder to balance the row
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // ─── Scrollable Content ──────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // ─── Success Animation (GIF) ──────────────
                    SizedBox(
                      width: 150,
                      height: 150,
                      child: Image.asset(
                        'lib/assets/diet/logSuccess.gif',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.check_circle,
                          color: AppTheme.successColor,
                          size: 120,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Meal Logged Successfully!',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 32),

                    // ─── Meal Details Card ──────────────────
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Image.asset(
                                    'lib/assets/diet/${meal.mealType}.png',
                                    width: 24,
                                    height: 24,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Icon(
                                      meal.mealType == 'breakfast'
                                          ? Icons.wb_sunny
                                          : meal.mealType == 'lunch'
                                              ? Icons.wb_cloudy
                                              : meal.mealType == 'dinner'
                                                  ? Icons.nightlight_round
                                                  : Icons.restaurant,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        meal.foodName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        meal.mealType[0].toUpperCase() +
                                            meal.mealType.substring(1),
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _NutrientColumn(
                                  label: 'Calories',
                                  value: meal.calories.toStringAsFixed(0),
                                  unit: 'kcal',
                                  color: AppTheme.warningColor,
                                  icon: Icons.local_fire_department,
                                ),
                                _NutrientColumn(
                                  label: 'Protein',
                                  value: meal.protein > 0
                                      ? meal.protein.toStringAsFixed(1)
                                      : '--',
                                  unit: 'g',
                                  color: AppTheme.accentColor,
                                  icon: Icons.fitness_center,
                                ),
                                _NutrientColumn(
                                  label: 'Carbs',
                                  value: meal.carbs > 0
                                      ? meal.carbs.toStringAsFixed(1)
                                      : '--',
                                  unit: 'g',
                                  color: AppTheme.successColor,
                                  icon: Icons.grain,
                                ),
                                _NutrientColumn(
                                  label: 'Fat',
                                  value: meal.fat > 0
                                      ? meal.fat.toStringAsFixed(1)
                                      : '--',
                                  unit: 'g',
                                  color: AppTheme.secondaryColor,
                                  icon: Icons.opacity,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    Text(
                      'Today\'s Overall Nutrition',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),

                    // ─── Nutrition Overview ──────────────────
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Daily Calories',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${todayCalories.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)} kcal',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 10,
                                backgroundColor: AppTheme.indigo100,
                                valueColor: AlwaysStoppedAnimation(
                                  progress > 1
                                      ? AppTheme.errorColor
                                      : progress > 0.8
                                          ? AppTheme.warningColor
                                          : AppTheme.successColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              progress > 1
                                  ? 'You\'ve exceeded your daily goal'
                                  : '${(progress * 100).toStringAsFixed(0)}% of daily goal',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: _MacroProgress(
                                    label: 'Protein',
                                    current: nutrition.totalProtein,
                                    goal: nutrition.getProteinGoal(),
                                    color: AppTheme.accentColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _MacroProgress(
                                    label: 'Carbs',
                                    current: nutrition.totalCarbs,
                                    goal: nutrition.getCarbsGoal(),
                                    color: AppTheme.successColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _MacroProgress(
                                    label: 'Fat',
                                    current: nutrition.totalFat,
                                    goal: nutrition.getFatGoal(),
                                    color: AppTheme.secondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24), // space before buttons
                  ],
                ),
              ),
            ),

            // ─── Fixed Bottom Buttons ─────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Back'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/nutrition',
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.restaurant, size: 18),
                      label: const Text('View All Meals'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Nutrient Column ──────────────────────────────────────────
class _NutrientColumn extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final IconData icon;

  const _NutrientColumn({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ─── Macro Progress ────────────────────────────────────────────
class _MacroProgress extends StatelessWidget {
  final String label;
  final double current;
  final double goal;
  final Color color;

  const _MacroProgress({
    required this.label,
    required this.current,
    required this.goal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = (current / goal).clamp(0.0, 1.0);
    return Column(
      children: [
        Text(
          '${current.toStringAsFixed(0)}g',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: p,
            minHeight: 6,
            backgroundColor: AppTheme.indigo100,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$label / ${goal.toStringAsFixed(0)}g',
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}