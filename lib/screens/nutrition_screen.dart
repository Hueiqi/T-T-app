import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/nutrition_provider.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';
import '../config/routes.dart';
import '../models/meal_model.dart';
import '../widgets/bottom_nav_shell.dart';
import 'meal_history_screen.dart';
class NutritionScreen extends StatefulWidget {
  final bool showBottomNav;
  final bool showBack;
  const NutritionScreen({super.key, this.showBottomNav = false, this.showBack = false});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  double _portionSlider = 1.0;
  String _selectedMealType = 'snack';
  DateTime _selectedDate = DateTime.now();
  List<Meal> _displayedMeals = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.user == null) return;
      _loadMealsForDate(auth.user!.uid, DateTime.now());
      context.read<NutritionProvider>().loadWeeklyCalories(auth.user!.uid);
    });
  }

  Future<void> _loadMealsForDate(String userId, DateTime date) async {
    await context.read<NutritionProvider>().loadMealsForDate(userId, date);
    setState(() {
      _selectedDate = date;
      _displayedMeals = context.read<NutritionProvider>().selectedDateMeals;
    });
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 16),
                  _QuickActionTile(
                    icon: Icons.wb_sunny,
                    color: const Color(0xFFF59E0B),
                    label: 'Add Breakfast',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(context, AppRoutes.foodSearch, arguments: 'breakfast');
                    },
                  ),
                  _QuickActionTile(
                    icon: Icons.wb_cloudy,
                    color: const Color(0xFF059669),
                    label: 'Add Lunch',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(context, AppRoutes.foodSearch, arguments: 'lunch');
                    },
                  ),
                  _QuickActionTile(
                    icon: Icons.nightlight_round,
                    color: const Color(0xFF7C3AED),
                    label: 'Add Dinner',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(context, AppRoutes.foodSearch, arguments: 'dinner');
                    },
                  ),
                  _QuickActionTile(
                    icon: Icons.restaurant,
                    color: const Color(0xFFEC4899),
                    label: 'Add Snack',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(context, AppRoutes.foodSearch, arguments: 'snack');
                    },
                  ),
                _QuickActionTile(
                  icon: Icons.camera_alt,
                  color: AppTheme.primaryColor,
                  label: 'Scan Food',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, AppRoutes.foodCapture);
                  },
                ),
                _QuickActionTile(
                  icon: Icons.monitor_weight,
                  color: AppTheme.textSecondary,
                  label: 'Log Weight',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showWeightDialog();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showWeightDialog() {
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
          keyboardType: TextInputType.numberWithOptions(decimal: true),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid weight.'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              final auth = context.read<AuthProvider>();
              if (auth.user == null) return;
              await context
                  .read<NutritionProvider>()
                  .saveWeight(userId: auth.user!.uid, weight: w);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showManualAddDialog({Meal? existingMeal, String? preselectedMealType}) {
    final nameController = TextEditingController(text: existingMeal?.foodName ?? '');
    final caloriesController = TextEditingController(
      text: existingMeal != null ? existingMeal.calories.toStringAsFixed(0) : '',
    );
    final servingController = TextEditingController(text: existingMeal?.servingSize ?? '');
    String selectedMealType = existingMeal?.mealType ?? preselectedMealType ?? 'snack';
    bool isEditing = existingMeal != null;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Meal' : 'Add Meal'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Food Name',
                        prefixIcon: Icon(Icons.restaurant),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: caloriesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Calories',
                        prefixIcon: Icon(Icons.local_fire_department, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: servingController,
                      decoration: const InputDecoration(
                        labelText: 'Serving Size',
                        prefixIcon: Icon(Icons.scale, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 4,
                      children: ['breakfast', 'lunch', 'dinner', 'snack'].map((type) {
                        final isSelected = selectedMealType == type;
                        return ChoiceChip(
                          label: Text(
                            type[0].toUpperCase() + type.substring(1),
                            style: TextStyle(fontSize: 11),
                          ),
                          selected: isSelected,
                          onSelected: (_) =>
                              setDialogState(() => selectedMealType = type),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final calories = double.tryParse(caloriesController.text.trim()) ?? 0;

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter food name.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    if (calories <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid calorie amount (greater than 0).'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }

                    final nutrition = context.read<NutritionProvider>();
                    final auth = context.read<AuthProvider>();
                    if (auth.user == null) return;

                    if (isEditing) {
                      await nutrition.updateMeal(
                        mealId: existingMeal.id,
                        foodName: name,
                        calories: calories,
                        mealType: selectedMealType,
                        protein: existingMeal.protein,
                        carbs: existingMeal.carbs,
                        fat: existingMeal.fat,
                        servingSize: servingController.text.trim().isEmpty
                            ? '1 serving'
                            : servingController.text.trim(),
                      );
                    } else {
                      await nutrition.saveMeal(
                        userId: auth.user!.uid,
                        mealType: selectedMealType,
                        foodName: name,
                        calories: calories,
                        protein: 0,
                        carbs: 0,
                        fat: 0,
                        servingSize: servingController.text.trim().isEmpty
                            ? '1 serving'
                            : servingController.text.trim(),
                        detectionMethod: 'manual',
                      );
                    }
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Meal logged successfully'),
                          backgroundColor: AppTheme.successColor,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addQuickFood(String name, double baseCalories,
      {double protein = 0, double carbs = 0, double fat = 0}) {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    final scale = _portionSlider;
    final cals = (baseCalories * scale).roundToDouble();
    context.read<NutritionProvider>().saveMeal(
      userId: auth.user!.uid,
      mealType: _selectedMealType,
      foodName: name,
      calories: cals,
      protein: (protein * scale).roundToDouble(),
      carbs: (carbs * scale).roundToDouble(),
      fat: (fat * scale).roundToDouble(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added $name (${cals.toInt()} kcal)'),
        backgroundColor: AppTheme.successColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nutrition = context.watch<NutritionProvider>();

    // Use displayed meals (for selected date) or fallback to today's meals
    final meals = _displayedMeals.isNotEmpty ? _displayedMeals : nutrition.todayMeals;
    final totalCalories = meals.fold<double>(0, (sum, m) => sum + m.calories);
    final totalProtein = meals.fold<double>(0, (sum, m) => sum + m.protein);
    final totalCarbs = meals.fold<double>(0, (sum, m) => sum + m.carbs);
    final totalFat = meals.fold<double>(0, (sum, m) => sum + m.fat);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showQuickActions,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: widget.showBottomNav ? buildBottomNavBar(context, currentIndex: 3) : null,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Date Picker Row ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios, size: 18),
                          onPressed: () {
                            final newDate = _selectedDate.subtract(const Duration(days: 1));
                            final auth = context.read<AuthProvider>();
                            if (auth.user != null) {
                              _loadMealsForDate(auth.user!.uid, newDate);
                            }
                          },
                        ),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020, 1, 1),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              final auth = context.read<AuthProvider>();
                              if (auth.user != null) {
                                _loadMealsForDate(auth.user!.uid, picked);
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  DateFormat('EEEE, MMM d').format(_selectedDate),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.calendar_today, size: 16, color: AppTheme.primaryColor),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios, size: 18),
                          onPressed: () {
                            final newDate = _selectedDate.add(const Duration(days: 1));
                            if (newDate.isAfter(DateTime.now())) return;
                            final auth = context.read<AuthProvider>();
                            if (auth.user != null) {
                              _loadMealsForDate(auth.user!.uid, newDate);
                            }
                          },
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.history),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const MealHistoryScreen()),
                          ),
                          tooltip: 'View meal history',
                        ),
                      ],
                    ),
                  ),
                  _DashboardHeader(
                    totalCalories: totalCalories,
                    dailyGoal: nutrition.dailyCalorieGoal,
                    onCameraTap: () => Navigator.pushNamed(context, AppRoutes.foodCapture),
                  ),
                  _buildCaloriesRemaining(totalCalories, nutrition.dailyCalorieGoal),
                  const SizedBox(height: 12),
                  _QuickAddCard(
                    portionSlider: _portionSlider,
                    selectedMealType: _selectedMealType,
                    remainingCalories: nutrition.dailyCalorieGoal - totalCalories,
                    onSliderChanged: (v) => setState(() => _portionSlider = v),
                    onMealTypeChanged: (t) => setState(() => _selectedMealType = t),
                    onAddFood: _addQuickFood,
                  ),
                  const SizedBox(height: 12),
                  _buildMacroBreakdown(totalProtein, totalCarbs, totalFat, nutrition),
                  const SizedBox(height: 12),
                  _buildWeeklyAverage(nutrition),
                  const SizedBox(height: 12),
                  _MealGroup(
                    mealType: 'breakfast',
                    meals: meals,
                    icon: Icons.wb_sunny,
                    color: const Color(0xFFF59E0B),
                    onAddFood: () => Navigator.pushNamed(context, AppRoutes.foodSearch, arguments: 'breakfast'),
                    onEdit: (meal) => _showManualAddDialog(existingMeal: meal),
                    onDelete: (meal) => _confirmDeleteMeal(meal),
                    onMealTap: _showMealDetail,
                  ),
                  const SizedBox(height: 12),
                  _MealGroup(
                    mealType: 'lunch',
                    meals: meals,
                    icon: Icons.wb_cloudy,
                    color: const Color(0xFF059669),
                    onAddFood: () => Navigator.pushNamed(context, AppRoutes.foodSearch, arguments: 'lunch'),
                    onEdit: (meal) => _showManualAddDialog(existingMeal: meal),
                    onDelete: (meal) => _confirmDeleteMeal(meal),
                    onMealTap: _showMealDetail,
                  ),
                  const SizedBox(height: 12),
                  _MealGroup(
                    mealType: 'dinner',
                    meals: meals,
                    icon: Icons.nightlight_round,
                    color: const Color(0xFF7C3AED),
                    onAddFood: () => Navigator.pushNamed(context, AppRoutes.foodSearch, arguments: 'dinner'),
                    onEdit: (meal) => _showManualAddDialog(existingMeal: meal),
                    onDelete: (meal) => _confirmDeleteMeal(meal),
                    onMealTap: _showMealDetail,
                  ),
                  const SizedBox(height: 12),
                  _MealGroup(
                    mealType: 'snack',
                    meals: meals,
                    icon: Icons.restaurant,
                    color: const Color(0xFFEC4899),
                    onAddFood: () => Navigator.pushNamed(context, AppRoutes.foodSearch, arguments: 'snack'),
                    onEdit: (meal) => _showManualAddDialog(existingMeal: meal),
                    onDelete: (meal) => _confirmDeleteMeal(meal),
                    onMealTap: _showMealDetail,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaloriesRemaining(double totalCalories, double dailyGoal) {
    final remaining = dailyGoal - totalCalories;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            remaining >= 0 ? Icons.flash_on : Icons.flash_off,
            size: 16,
            color: remaining >= 0 ? AppTheme.successColor : AppTheme.errorColor,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              remaining >= 0
                  ? 'Remaining: ${remaining.toStringAsFixed(0)} kcal'
                  : 'Over by ${(-remaining).toStringAsFixed(0)} kcal',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: remaining >= 0 ? AppTheme.textPrimary : AppTheme.errorColor,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Eaten: ${totalCalories.toStringAsFixed(0)} / ${dailyGoal.toStringAsFixed(0)} kcal',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBreakdown(double totalProtein, double totalCarbs, double totalFat, NutritionProvider nutrition) {
    final proteinGoal = nutrition.getProteinGoal();
    final carbsGoal = nutrition.getCarbsGoal();
    final fatGoal = nutrition.getFatGoal();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart, size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Macronutrients',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _macroBar(
              label: 'Protein',
              current: totalProtein,
              goal: proteinGoal,
              color: const Color(0xFF6366F1),
              unit: 'g',
            ),
            const SizedBox(height: 12),
            _macroBar(
              label: 'Carbs',
              current: totalCarbs,
              goal: carbsGoal,
              color: const Color(0xFFF59E0B),
              unit: 'g',
            ),
            const SizedBox(height: 12),
            _macroBar(
              label: 'Fat',
              current: totalFat,
              goal: fatGoal,
              color: const Color(0xFFEC4899),
              unit: 'g',
            ),
          ],
        ),
      ),
    );
  }

  Widget _macroBar({
    required String label,
    required double current,
    required double goal,
    required Color color,
    required String unit,
  }) {
    final rawProgress = goal > 0 ? (current / goal) : 0.0;
    final displayProgress = rawProgress.clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary.withValues(alpha: 0.8),
              ),
            ),
            Text(
              '${current.toStringAsFixed(1)}$unit / ${goal.toInt()}$unit',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: displayProgress,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(
              rawProgress > 1 ? AppTheme.errorColor : color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyAverage(NutritionProvider nutrition) {
    final avg = nutrition.weeklyAverage;
    final entries = nutrition.weeklyCalories.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxVal = entries.fold<double>(0, (m, e) => e.value > m ? e.value : m);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up, size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Weekly Average',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${avg.toStringAsFixed(0)} kcal/day',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 40,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: entries.map((e) {
                  final dayLabel = e.key.split('-').last;
                  final height = maxVal > 0 ? (e.value / maxVal) * 32 : 0.0;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: height.clamp(4, 40).toDouble(),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.6),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dayLabel,
                            style: TextStyle(
                              fontSize: 9,
                              color: AppTheme.textSecondary.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMealDetail(Meal meal) {
    final dateStr = DateFormat('MMM d, yyyy – hh:mm a').format(meal.dateTime);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
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
            const SizedBox(height: 20),
            if (meal.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  meal.imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: Colors.grey.shade100,
                    child: const Icon(Icons.broken_image, size: 64, color: Colors.grey),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              meal.foodName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _mealTypeChip(meal.mealType),
                const SizedBox(width: 12),
                Text(dateStr, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            _buildNutrientGrid(meal),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _mealTypeChip(String type) {
    final Color color;
    switch (type) {
      case 'breakfast': color = const Color(0xFFF59E0B); break;
      case 'lunch': color = const Color(0xFF059669); break;
      case 'dinner': color = const Color(0xFF7C3AED); break;
      default: color = const Color(0xFFEC4899);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        type[0].toUpperCase() + type.substring(1),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildNutrientGrid(Meal meal) {
    final nutrients = [
      _NutrientItem(Icons.local_fire_department, 'Calories', '${meal.calories.toStringAsFixed(0)} kcal', const Color(0xFFF59E0B)),
      _NutrientItem(Icons.fitness_center, 'Protein', '${meal.protein.toStringAsFixed(1)}g', const Color(0xFF6366F1)),
      _NutrientItem(Icons.grain, 'Carbs', '${meal.carbs.toStringAsFixed(1)}g', const Color(0xFFF59E0B)),
      _NutrientItem(Icons.water_drop, 'Fat', '${meal.fat.toStringAsFixed(1)}g', const Color(0xFFEC4899)),
      _NutrientItem(Icons.eco, 'Vitamins', '${meal.vitamins.toStringAsFixed(0)}g', const Color(0xFF8B5CF6)),
      _NutrientItem(Icons.science, 'Minerals', '${meal.minerals.toStringAsFixed(0)}g', const Color(0xFF14B8A6)),
      _NutrientItem(Icons.agriculture, 'Fiber', '${meal.fiber.toStringAsFixed(0)}g', const Color(0xFFA16207)),
      _NutrientItem(Icons.water, 'Water', '${meal.water.toStringAsFixed(0)}g', const Color(0xFF3B82F6)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: nutrients.length,
      itemBuilder: (_, i) {
        final n = nutrients[i];
        return Container(
          decoration: BoxDecoration(
            color: n.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: n.color.withOpacity(0.15)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(n.icon, color: n.color, size: 22),
              const SizedBox(height: 6),
              Text(
                n.value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: n.color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                n.label,
                style: TextStyle(
                  fontSize: 9,
                  color: n.color.withOpacity(0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteMeal(Meal meal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Meal'),
        content: Text('Remove "${meal.foodName}" from today\'s log?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<NutritionProvider>().deleteMeal(meal.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final double totalCalories;
  final double dailyGoal;
  final VoidCallback onCameraTap;

  const _DashboardHeader({
    required this.totalCalories,
    required this.dailyGoal,
    required this.onCameraTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Nutrition',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Track your daily intake',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Text('📷', style: TextStyle(fontSize: 22)),
                    onPressed: onCameraTap,
                    tooltip: 'Scan Food',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _CalorieRing(
              totalCalories: totalCalories,
              dailyGoal: dailyGoal,
            ),
          ],
        ),
      ),
    );
  }
}

class _CalorieRing extends StatelessWidget {
  final double totalCalories;
  final double dailyGoal;

  const _CalorieRing({
    required this.totalCalories,
    required this.dailyGoal,
  });

  @override
  Widget build(BuildContext context) {
    final progress = dailyGoal > 0 ? (totalCalories / dailyGoal).clamp(0, 1.2) : 0.0;
    final displayProgress = progress.clamp(0, 1).toDouble();

    Color ringColor;
    if (progress > 1) {
      ringColor = AppTheme.errorColor;
    } else if (progress > 0.8) {
      ringColor = AppTheme.warningColor;
    } else {
      ringColor = AppTheme.successColor;
    }

    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(180, 180),
            painter: _RingPainter(
              progress: displayProgress,
              color: ringColor,
              backgroundColor: Colors.grey.shade200,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                totalCalories.toStringAsFixed(0),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: ringColor,
                    ),
              ),
              Text(
                '${dailyGoal.toStringAsFixed(0)} kcal',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2;
    const strokeWidth = 14.0;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * 3.1415927 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.1415927 / 2,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _QuickAddCard extends StatelessWidget {
  final double portionSlider;
  final String selectedMealType;
  final double remainingCalories;
  final ValueChanged<double> onSliderChanged;
  final ValueChanged<String> onMealTypeChanged;
  final void Function(String name, double baseCalories,
      {double protein, double carbs, double fat}) onAddFood;

  const _QuickAddCard({
    required this.portionSlider,
    required this.selectedMealType,
    required this.remainingCalories,
    required this.onSliderChanged,
    required this.onMealTypeChanged,
    required this.onAddFood,
  });

  String get _portionLabel {
    if (portionSlider <= 0.7) return 'Small';
    if (portionSlider <= 1.3) return 'Medium';
    return 'Large';
  }

  double get _portionMultiplier => portionSlider;

  @override
  Widget build(BuildContext context) {
    final quickFoods = [
      _QuickFood('Apple', 95, Icons.apple, Colors.red.shade300,
          protein: 0.5, carbs: 25, fat: 0.3),
      _QuickFood('Chicken', 165, Icons.restaurant, Colors.brown,
          protein: 31, carbs: 0, fat: 3.6),
      _QuickFood('Rice', 130, Icons.grain, Colors.blueGrey,
          protein: 2.7, carbs: 28, fat: 0.3),
      _QuickFood('Eggs', 155, Icons.circle, Colors.orange.shade300,
          protein: 13, carbs: 1.1, fat: 11),
      _QuickFood('Banana', 105, Icons.eco, Color(0xFFFCD34D),
          protein: 1.3, carbs: 27, fat: 0.4),
    ];

    final mealTypes = [
      ('breakfast', Icons.wb_sunny, const Color(0xFFF59E0B)),
      ('lunch', Icons.wb_cloudy, const Color(0xFF059669)),
      ('dinner', Icons.nightlight_round, const Color(0xFF7C3AED)),
      ('snack', Icons.restaurant, const Color(0xFFEC4899)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_circle_outline, size: 18, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 8),
                Text(
                  'Quick Add',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: remainingCalories > 0
                        ? AppTheme.successColor.withValues(alpha: 0.1)
                        : AppTheme.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        remainingCalories > 0 ? Icons.flash_on : Icons.flash_off,
                        size: 12,
                        color: remainingCalories > 0 ? AppTheme.successColor : AppTheme.errorColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${(remainingCalories - _portionMultiplier * 200).toStringAsFixed(0)} left',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: remainingCalories > 0 ? AppTheme.successColor : AppTheme.errorColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text('Size:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: portionSlider,
                    min: 0.5,
                    max: 2.0,
                    divisions: 3,
                    onChanged: onSliderChanged,
                    activeColor: AppTheme.primaryColor,
                    label: _portionLabel,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _portionLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: mealTypes.map((m) {
                final isSelected = selectedMealType == m.$1;
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(m.$2, size: 14),
                      const SizedBox(width: 4),
                      Text(m.$1[0].toUpperCase() + m.$1.substring(1)),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: m.$3.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: isSelected ? m.$3 : AppTheme.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  onSelected: (_) => onMealTypeChanged(m.$1),
                  side: BorderSide(
                    color: isSelected ? m.$3 : Colors.grey.shade300,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: quickFoods.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final f = quickFoods[i];
                  final adjusted = (f.baseCalories * _portionMultiplier).round();
                  return InkWell(
                    onTap: () => onAddFood(f.name, f.baseCalories,
                        protein: f.protein, carbs: f.carbs, fat: f.fat),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 64,
                      decoration: BoxDecoration(
                        color: f.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: f.color.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.restaurant, color: f.color, size: 18),
                          const SizedBox(height: 2),
                          Text(
                            f.name,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: f.color,
                            ),
                          ),
                          Text(
                            '$adjusted kcal',
                            style: TextStyle(
                              fontSize: 9,
                              color: f.color.withValues(alpha: 0.7),
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
    );
  }
}

class _QuickFood {
  final String name;
  final double baseCalories;
  final double protein;
  final double carbs;
  final double fat;
  final IconData icon;
  final Color color;
  const _QuickFood(this.name, this.baseCalories, this.icon, this.color,
      {this.protein = 0, this.carbs = 0, this.fat = 0});
}

class _NutrientItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _NutrientItem(this.icon, this.label, this.value, this.color);
}

class _MealGroup extends StatelessWidget {
  final String mealType;
  final List<Meal> meals;
  final IconData icon;
  final Color color;
  final VoidCallback onAddFood;
  final void Function(Meal) onEdit;
  final void Function(Meal) onDelete;
  final void Function(Meal) onMealTap;

  const _MealGroup({
    required this.mealType,
    required this.meals,
    required this.icon,
    required this.color,
    required this.onAddFood,
    required this.onEdit,
    required this.onDelete,
    required this.onMealTap,
  });

  @override
  Widget build(BuildContext context) {
    final groupMeals = meals.where((m) => m.mealType == mealType).toList();
    final totalCalories = groupMeals.fold(0.0, (sum, m) => sum + m.calories);
    final label = mealType[0].toUpperCase() + mealType.substring(1);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${totalCalories.toStringAsFixed(0)} kcal',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            if (groupMeals.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No $mealType logged yet',
                    style: TextStyle(
                      color: AppTheme.textSecondary.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ),
              )
            else
              ...groupMeals.map((meal) => Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _FoodItemRow(
                      meal: meal,
                      onTap: () => onMealTap(meal),
                      onEdit: () => onEdit(meal),
                      onDelete: () => onDelete(meal),
                    ),
                  )),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAddFood,
                icon: const Icon(Icons.add, size: 18),
                label: Text('Add $label'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: color.withValues(alpha: 0.4)),
                  foregroundColor: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodItemRow extends StatelessWidget {
  final Meal meal;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FoodItemRow({
    required this.meal,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = meal.imageUrl.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 44,
              height: 44,
              child: hasImage
                  ? Image.network(
                      meal.imageUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallbackThumbnail(),
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return _fallbackThumbnail();
                      },
                    )
                  : _fallbackThumbnail(),
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
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  meal.servingSize,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _macroChip('P', meal.protein, const Color(0xFF6366F1)),
                    const SizedBox(width: 6),
                    _macroChip('C', meal.carbs, const Color(0xFFF59E0B)),
                    const SizedBox(width: 6),
                    _macroChip('F', meal.fat, const Color(0xFFEC4899)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${meal.calories.toStringAsFixed(0)} kcal',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            padding: EdgeInsets.zero,
            iconSize: 20,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: AppTheme.errorColor),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fallbackThumbnail() {
    Color bgColor;
    IconData icon;
    switch (meal.mealType) {
      case 'breakfast':
        bgColor = const Color(0xFFF59E0B).withOpacity(0.15);
        icon = Icons.wb_sunny;
        break;
      case 'lunch':
        bgColor = const Color(0xFF059669).withOpacity(0.15);
        icon = Icons.wb_cloudy;
        break;
      case 'dinner':
        bgColor = const Color(0xFF7C3AED).withOpacity(0.15);
        icon = Icons.nightlight_round;
        break;
      default:
        bgColor = const Color(0xFFEC4899).withOpacity(0.15);
        icon = Icons.restaurant;
    }
    return Container(
      width: 44,
      height: 44,
      color: bgColor,
      child: Icon(icon, size: 22, color: bgColor.withOpacity(0.8)),
    );
  }

  Widget _macroChip(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label ${value.toStringAsFixed(1)}g',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
