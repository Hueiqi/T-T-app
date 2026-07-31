import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/routes.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/nutrition_provider.dart';
import '../screens/food_capture_screen.dart';
import '../screens/manual_food_entry_screen.dart';
import '../screens/meal_history_screen.dart';
import '../screens/workout_history_screen.dart';

/// The single Quick Add sheet used by every main page.
///
/// Home and Diet each had their own sheet with a different, partly
/// overlapping set of actions ("Log a Meal" vs "Scan Food", weight logging in
/// both, history only on Diet). This is the union of the two, so the same
/// actions are reachable from anywhere instead of depending on which page you
/// happened to be on.
Future<void> showQuickAddSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _QuickAddSheet(),
  );
}

class _QuickAddSheet extends StatelessWidget {
  const _QuickAddSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Quick Add',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),

              // ── Food ──
              // Each tile grabs the NavigatorState *before* dismissing the
              // sheet: popping tears this context down, so reusing it to push
              // afterwards would be operating on a defunct element.
              _QuickAddTile(
                icon: Icons.camera_alt,
                color: const Color(0xFFFF9800),
                label: 'Scan Food',
                subtitle: 'Photograph a meal to log it',
                onTap: () {
                  final nav = Navigator.of(context);
                  nav.pop();
                  nav.push(MaterialPageRoute(
                    builder: (_) => const FoodCaptureScreen(),
                  ));
                },
              ),
              _QuickAddTile(
                icon: Icons.edit_note,
                color: const Color(0xFF4CAF50),
                label: 'Add Food Manually',
                subtitle: 'Type in the nutrition yourself',
                onTap: () {
                  final nav = Navigator.of(context);
                  nav.pop();
                  nav.push(MaterialPageRoute(
                    builder: (_) =>
                        const ManualFoodEntryScreen(mealType: 'snack'),
                  ));
                },
              ),
              _QuickAddTile(
                icon: Icons.library_books,
                color: const Color(0xFF2196F3),
                label: 'Food Library',
                subtitle: 'Search saved and online foods',
                onTap: () {
                  final nav = Navigator.of(context);
                  nav.pop();
                  nav.pushNamed(AppRoutes.foodSearch, arguments: 'snack');
                },
              ),

              const Divider(height: 20, indent: 20, endIndent: 20),

              // ── Activity ──
              _QuickAddTile(
                icon: Icons.fitness_center,
                color: AppTheme.primaryColor,
                label: 'Start Workout',
                subtitle: 'Begin a tracked session',
                onTap: () {
                  final nav = Navigator.of(context);
                  nav.pop();
                  nav.pushNamed(AppRoutes.workout);
                },
              ),
              _QuickAddTile(
                icon: Icons.monitor_weight,
                color: AppTheme.secondaryColor,
                label: 'Log Weight',
                subtitle: 'Record today\'s weigh-in',
                onTap: () {
                  final nav = Navigator.of(context);
                  nav.pop();
                  // nav.context outlives the sheet, unlike this build context.
                  _showWeightDialog(nav.context);
                },
              ),

              const Divider(height: 20, indent: 20, endIndent: 20),

              // ── History ──
              _QuickAddTile(
                icon: Icons.restaurant_menu,
                color: const Color(0xFF9C27B0),
                label: 'Meal History',
                subtitle: 'Everything you have logged',
                onTap: () {
                  final nav = Navigator.of(context);
                  nav.pop();
                  nav.push(MaterialPageRoute(
                      builder: (_) => const MealHistoryScreen()));
                },
              ),
              _QuickAddTile(
                icon: Icons.history,
                color: AppTheme.textSecondary,
                label: 'Workout History',
                subtitle: 'Past sessions and routes',
                onTap: () {
                  final nav = Navigator.of(context);
                  nav.pop();
                  nav.push(MaterialPageRoute(
                      builder: (_) => const WorkoutHistoryScreen()));
                },
              ),
              // SleepScreen already shows the 7-day chart plus the full
              // record list, so this routes there rather than duplicating it.
              _QuickAddTile(
                icon: Icons.bedtime,
                color: const Color(0xFF3F51B5),
                label: 'Sleep History',
                subtitle: 'Nightly hours and trends',
                onTap: () {
                  final nav = Navigator.of(context);
                  nav.pop();
                  nav.pushNamed(AppRoutes.sleep);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Weight entry, duplicated from the per-page sheets so the shared version is
/// self-contained. Saves to NutritionProvider and opens the progress chart.
void _showWeightDialog(BuildContext context) {
  final nutrition = context.read<NutritionProvider>();
  final controller = TextEditingController(
    text: nutrition.todayWeight != null
        ? nutrition.todayWeight!.weight.toStringAsFixed(1)
        : '',
  );

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Log Today\'s Weight'),
      content: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Weight (kg)',
          prefixIcon: Icon(Icons.monitor_weight),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final w = double.tryParse(controller.text.trim());
            if (w == null || w <= 0) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('Please enter a valid weight.'),
                  duration: Duration(seconds: 2),
                ),
              );
              return;
            }
            final auth = ctx.read<AuthProvider>();
            if (auth.user == null) return;
            // Resolved before the await so the navigation below is the only
            // thing that has to survive the async gap.
            final navigator = Navigator.of(ctx);
            await ctx
                .read<NutritionProvider>()
                .saveWeight(userId: auth.user!.uid, weight: w);
            navigator.pop();
            navigator.pushNamed(AppRoutes.weightProgress);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

class _QuickAddTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickAddTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
    );
  }
}
