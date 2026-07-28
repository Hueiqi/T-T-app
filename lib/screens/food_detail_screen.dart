import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../utils/food_icon_matcher.dart';
import 'food_search_screen.dart' show FoodItemDisplay;

/// Full detail page for a single food library item, replacing the old
/// bottom-sheet preview with a dedicated scrollable screen.
class FoodDetailScreen extends StatelessWidget {
  final FoodItemDisplay food;
  final Future<void> Function() onAddMeal;

  const FoodDetailScreen({
    super.key,
    required this.food,
    required this.onAddMeal,
  });

  @override
  Widget build(BuildContext context) {
    final category = FoodIconMatcher.categoryFor(food.name);

    return Scaffold(
      appBar: AppBar(
        title: Text(food.name, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(category.icon, color: category.color, size: 48),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              food.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              food.servingSize,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),

            // ── Calories highlight ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_fire_department, color: AppTheme.warningColor, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    '${food.calories.toInt()} kcal',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Macros ──
            const Text('Macronutrients', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 10),
            _nutrientRow('Protein', '${food.protein.toStringAsFixed(1)} g', AppTheme.accentColor, Icons.fitness_center),
            const SizedBox(height: 6),
            _nutrientRow('Carbs', '${food.carbs.toStringAsFixed(1)} g', AppTheme.successColor, Icons.grain),
            const SizedBox(height: 6),
            _nutrientRow('Fat', '${food.fat.toStringAsFixed(1)} g', AppTheme.errorColor, Icons.water_drop),
            const SizedBox(height: 6),
            _nutrientRow('Fiber', '${food.fiber.toStringAsFixed(1)} g', Colors.teal, Icons.eco),
            const SizedBox(height: 6),
            _nutrientRow('Sugar', '${food.sugar.toStringAsFixed(1)} g', Colors.orange, Icons.cookie),
            const SizedBox(height: 6),
            _nutrientRow('Sodium', '${food.sodium.toStringAsFixed(1)} mg', Colors.blueGrey, Icons.science),
            const SizedBox(height: 24),

            // ── Vitamins ──
            const Text('Vitamins', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 10),
            _nutrientRow('Vitamin A', '${food.vitaminA.toStringAsFixed(1)} mcg', Colors.orange, Icons.circle),
            const SizedBox(height: 6),
            _nutrientRow('Vitamin B', '${food.vitaminB.toStringAsFixed(1)} mg', Colors.yellow.shade700, Icons.circle),
            const SizedBox(height: 6),
            _nutrientRow('Vitamin C', '${food.vitaminC.toStringAsFixed(1)} mg', Colors.green, Icons.circle),
            const SizedBox(height: 6),
            _nutrientRow('Vitamin D', '${food.vitaminD.toStringAsFixed(1)} mcg', Colors.amber, Icons.circle),
            const SizedBox(height: 6),
            _nutrientRow('Vitamin E', '${food.vitaminE.toStringAsFixed(1)} mg', Colors.teal, Icons.circle),
            const SizedBox(height: 6),
            _nutrientRow('Vitamin K', '${food.vitaminK.toStringAsFixed(1)} mcg', Colors.brown, Icons.circle),
            const SizedBox(height: 24),

            // ── Minerals ──
            const Text('Minerals', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 10),
            _nutrientRow('Calcium', '${food.calcium.toStringAsFixed(1)} mg', Colors.grey, Icons.circle),
            const SizedBox(height: 6),
            _nutrientRow('Iron', '${food.iron.toStringAsFixed(1)} mg', Colors.red.shade700, Icons.circle),
            const SizedBox(height: 6),
            _nutrientRow('Magnesium', '${food.magnesium.toStringAsFixed(1)} mg', Colors.purple, Icons.circle),
            const SizedBox(height: 6),
            _nutrientRow('Potassium', '${food.potassium.toStringAsFixed(1)} mg', Colors.blue, Icons.circle),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await onAddMeal();
                },
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Add Meal'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nutrientRow(String label, String value, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
