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
import 'food_capture_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class NutritionScreen extends StatefulWidget {
  final bool showBottomNav;
  final bool showBack;
  final DateTime? initialDate;
  const NutritionScreen({
    super.key,
    this.showBottomNav = false,
    this.showBack = false,
    this.initialDate,
  });

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  double _portionSlider = 1.0;
  String _selectedMealType = 'snack';
  late DateTime _selectedDate;
  List<Meal> _displayedMeals = [];
  final ScrollController _calendarScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.user == null) return;
      _loadMealsForDate(auth.user!.uid, _selectedDate);
      context.read<NutritionProvider>().loadWeeklyCalories(auth.user!.uid);
    });
  }

  @override
  void dispose() {
    _calendarScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMealsForDate(String userId, DateTime date) async {
    final key = DateFormat('yyyy-MM-dd').format(date);
    context.read<NutritionProvider>().clearCacheForDate(key);
    await context.read<NutritionProvider>().loadMealsForDate(userId, date);
    setState(() {
      _selectedDate = date;
      _displayedMeals = context.read<NutritionProvider>().selectedDateMeals;
    });
    _scrollToDate(date);
  }

  void _scrollToDate(DateTime date) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_calendarScrollController.hasClients) return;
      final today = DateTime.now();
      final startDate =
          DateTime(today.year, today.month, today.day).subtract(const Duration(days: 7));
      final targetDate = DateTime(date.year, date.month, date.day);
      final index = targetDate.difference(startDate).inDays;
      if (index < 0) return;
      final tileWidth = 60.0;
      final screenWidth = context.size?.width ?? 400;
      final targetOffset = (index * tileWidth + tileWidth / 2) - screenWidth / 2;
      _calendarScrollController.animateTo(
        targetOffset.clamp(0, _calendarScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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
                  imagePath: 'lib/assets/diet/breakfast.png',
                  label: 'Add Breakfast',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, AppRoutes.foodSearch,
                        arguments: 'breakfast');
                  },
                ),
                _QuickActionTile(
                  imagePath: 'lib/assets/diet/lunch.png',
                  label: 'Add Lunch',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, AppRoutes.foodSearch,
                        arguments: 'lunch');
                  },
                ),
                _QuickActionTile(
                  imagePath: 'lib/assets/diet/dinner.png',
                  label: 'Add Dinner',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, AppRoutes.foodSearch,
                        arguments: 'dinner');
                  },
                ),
                _QuickActionTile(
                  imagePath: 'lib/assets/diet/snack.png',
                  label: 'Add Snack',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, AppRoutes.foodSearch,
                        arguments: 'snack');
                  },
                ),
                _QuickActionTile(
                  imagePath: 'lib/assets/diet/camera.png',
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
    final servingController = TextEditingController(text: '');
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
                      children: ['breakfast', 'lunch', 'dinner', 'snack']
                          .map((type) {
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
                        dateTime: _selectedDate,
                      );
                    }
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      final auth = context.read<AuthProvider>();
                      if (auth.user != null) {
                        await _loadMealsForDate(auth.user!.uid, _selectedDate);
                      }
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
      dateTime: _selectedDate,
    ).then((_) {
      _loadMealsForDate(auth.user!.uid, _selectedDate);
    });
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

    final meals = _displayedMeals;
    final totalCalories = meals.fold<double>(0, (sum, m) => sum + m.calories);
    final totalProtein = meals.fold<double>(0, (sum, m) => sum + m.protein);
    final totalCarbs = meals.fold<double>(0, (sum, m) => sum + m.carbs);
    final totalFat = meals.fold<double>(0, (sum, m) => sum + m.fat);

    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'history',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MealHistoryScreen()),
            ),
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.8),
            child: const Icon(Icons.history, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'add',
            onPressed: _showQuickActions,
            backgroundColor: AppTheme.primaryColor,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
      bottomNavigationBar:
          widget.showBottomNav ? buildBottomNavBar(context, currentIndex: 3) : null,
      body: SafeArea(
        child: Column(
          children: [
            _buildCalendarStrip(),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
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
                              final newDate =
                                  _selectedDate.subtract(const Duration(days: 1));
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
                                if (!context.mounted) return;
                                final auth = context.read<AuthProvider>();
                                if (auth.user != null) {
                                  _loadMealsForDate(auth.user!.uid, picked);
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      DateFormat('EEEE, MMM d').format(_selectedDate),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.calendar_today, size: 16,
                                      color: AppTheme.primaryColor),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, size: 18),
                            onPressed: () {
                              final newDate =
                                  _selectedDate.add(const Duration(days: 1));
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
                      onCameraTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                FoodCaptureScreen(initialDate: _selectedDate),
                          ),
                        );
                        if (result == true) {
                          final auth = context.read<AuthProvider>();
                          if (auth.user != null) {
                            await _loadMealsForDate(auth.user!.uid, _selectedDate);
                          }
                        }
                      },
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
                    _MealGroup(
                      mealType: 'breakfast',
                      meals: meals,
                      color: const Color(0xFFF59E0B),
                      onAddFood: () => Navigator.pushNamed(context, AppRoutes.foodSearch,
                          arguments: 'breakfast'),
                      onEdit: (meal) => _showManualAddDialog(existingMeal: meal),
                      onDelete: (meal) => _confirmDeleteMeal(meal),
                      onMealTap: _showMealDetail,
                    ),
                    const SizedBox(height: 12),
                    _MealGroup(
                      mealType: 'lunch',
                      meals: meals,
                      color: const Color(0xFF059669),
                      onAddFood: () => Navigator.pushNamed(context, AppRoutes.foodSearch,
                          arguments: 'lunch'),
                      onEdit: (meal) => _showManualAddDialog(existingMeal: meal),
                      onDelete: (meal) => _confirmDeleteMeal(meal),
                      onMealTap: _showMealDetail,
                    ),
                    const SizedBox(height: 12),
                    _MealGroup(
                      mealType: 'dinner',
                      meals: meals,
                      color: const Color(0xFF7C3AED),
                      onAddFood: () => Navigator.pushNamed(context, AppRoutes.foodSearch,
                          arguments: 'dinner'),
                      onEdit: (meal) => _showManualAddDialog(existingMeal: meal),
                      onDelete: (meal) => _confirmDeleteMeal(meal),
                      onMealTap: _showMealDetail,
                    ),
                    const SizedBox(height: 12),
                    _MealGroup(
                      mealType: 'snack',
                      meals: meals,
                      color: const Color(0xFFEC4899),
                      onAddFood: () => Navigator.pushNamed(context, AppRoutes.foodSearch,
                          arguments: 'snack'),
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
      ),
    );
  }

  Widget _buildCaloriesRemaining(double totalCalories, double dailyGoal) {
    final remaining = dailyGoal - totalCalories;
    final isOver = remaining < 0;

    if (!isOver) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flash_off, size: 16, color: AppTheme.errorColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Over by ${(-remaining).toStringAsFixed(0)} kcal',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.errorColor,
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

  Widget _buildCalendarStrip() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final selectedDate =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final auth = context.read<AuthProvider>();
    final userId = auth.user?.uid;
    final startDate = todayDate.subtract(const Duration(days: 7));
    const totalDays = 21;

    return SizedBox(
      height: 90,
      child: ListView.builder(
        controller: _calendarScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: totalDays,
        itemBuilder: (context, index) {
          final date = startDate.add(Duration(days: index));
          final dateDay = DateTime(date.year, date.month, date.day);
          final isSelected = dateDay == selectedDate;
          final isToday = dateDay == todayDate;
          final isFuture = dateDay.isAfter(todayDate);
          final dayName = DateFormat('E').format(date);
          final dayNum = date.day.toString();

          return GestureDetector(
            onTap: isFuture
                ? null
                : () {
                    if (userId != null) _loadMealsForDate(userId, date);
                  },
            child: Container(
              width: 52,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor
                    : isFuture
                        ? Colors.grey.shade100
                        : AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? null
                    : Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dayNum,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  if (isToday)
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMacroBreakdown(
      double totalProtein, double totalCarbs, double totalFat, NutritionProvider nutrition) {
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
          ],
        ),
      ),
    );
  }

  Widget _mealTypeChip(String type) {
    final Color color;
    switch (type) {
      case 'breakfast':
        color = const Color(0xFFF59E0B);
        break;
      case 'lunch':
        color = const Color(0xFF059669);
        break;
      case 'dinner':
        color = const Color(0xFF7C3AED);
        break;
      default:
        color = const Color(0xFFEC4899);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        type[0].toUpperCase() + type.substring(1),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildNutrientGrid(Meal meal) {
    final totalVitamins = meal.vitaminA + meal.vitaminB + meal.vitaminC +
        meal.vitaminD + meal.vitaminE + meal.vitaminK;
    final totalMinerals = meal.calcium + meal.iron + meal.magnesium +
        meal.potassium + meal.sodium;

    final nutrients = [
      _NutrientItem(Icons.local_fire_department, 'Calories',
          '${meal.calories.toStringAsFixed(0)} kcal', const Color(0xFFF59E0B)),
      _NutrientItem(Icons.fitness_center, 'Protein',
          '${meal.protein.toStringAsFixed(1)}g', const Color(0xFF6366F1)),
      _NutrientItem(Icons.grain, 'Carbs', '${meal.carbs.toStringAsFixed(1)}g',
          const Color(0xFFF59E0B)),
      _NutrientItem(Icons.water_drop, 'Fat', '${meal.fat.toStringAsFixed(1)}g',
          const Color(0xFFEC4899)),
      _NutrientItem(Icons.eco, 'Vitamins', '${totalVitamins.toStringAsFixed(0)}mg',
          const Color(0xFF8B5CF6)),
      _NutrientItem(Icons.science, 'Minerals', '${totalMinerals.toStringAsFixed(0)}mg',
          const Color(0xFF14B8A6)),
      _NutrientItem(Icons.agriculture, 'Fiber', '${meal.fiber.toStringAsFixed(0)}g',
          const Color(0xFFA16207)),
      _NutrientItem(Icons.water, 'Water', '${meal.water.toStringAsFixed(0)}g',
          const Color(0xFF3B82F6)),
    ];

    final filtered = nutrients.where((n) =>
        n.value != '0g' && n.value != '0mg' && n.value != '0 kcal').toList();

    if (filtered.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount;
        double spacing;

        if (width < 360) {
          crossAxisCount = 2;
          spacing = 8;
        } else if (width < 480) {
          crossAxisCount = 3;
          spacing = 10;
        } else {
          crossAxisCount = 4;
          spacing = 12;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: 0.9,
          ),
          itemCount: filtered.length,
          itemBuilder: (_, i) {
            final n = filtered[i];
            return Container(
              decoration: BoxDecoration(
                color: n.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: n.color.withValues(alpha: 0.15)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(n.icon, color: n.color, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    n.value,
                    style: TextStyle(
                      fontSize: 11,
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
                      fontSize: 8,
                      color: n.color.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
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

// ─── Top‑level classes ──────────────────────────────────────────

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
                    icon: Image.asset(
                      'lib/assets/diet/camera.png',
                      width: 28,
                      height: 28,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.camera_alt, size: 28),
                    ),
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
      _QuickFood('Apple', 95, Colors.red.shade300,
          protein: 0.5, carbs: 25, fat: 0.3),
      _QuickFood('Chicken', 165, Colors.brown,
          protein: 31, carbs: 0, fat: 3.6),
      _QuickFood('Rice', 130, Colors.blueGrey,
          protein: 2.7, carbs: 28, fat: 0.3),
      _QuickFood('Eggs', 155, Colors.orange.shade300,
          protein: 13, carbs: 1.1, fat: 11),
      _QuickFood('Banana', 105, const Color(0xFFFCD34D),
          protein: 1.3, carbs: 27, fat: 0.4),
    ];

    final mealTypes = [
      ('breakfast', 'lib/assets/diet/breakfast.png', const Color(0xFFF59E0B)),
      ('lunch', 'lib/assets/diet/lunch.png', const Color(0xFF059669)),
      ('dinner', 'lib/assets/diet/dinner.png', const Color(0xFF7C3AED)),
      ('snack', 'lib/assets/diet/snack.png', const Color(0xFFEC4899)),
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
                  child: const Icon(Icons.add_circle_outline, size: 18,
                      color: AppTheme.primaryColor),
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
                        color: remainingCalories > 0
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${(remainingCalories - _portionMultiplier * 200).toStringAsFixed(0)} left',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: remainingCalories > 0
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
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
                      Image.asset(m.$2, width: 14, height: 14,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.fastfood, size: 14)),
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
                separatorBuilder: (_, __) => const SizedBox(width: 8),
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
                        border: Border.all(color: f.color.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'lib/assets/diet/quickAdd.png',
                            width: 18,
                            height: 18,
                            color: f.color,
                            errorBuilder: (_, __, ___) =>
                                Icon(Icons.restaurant, color: f.color, size: 18),
                          ),
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
  final Color color;
  const _QuickFood(this.name, this.baseCalories, this.color,
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
  final Color color;
  final VoidCallback onAddFood;
  final void Function(Meal) onEdit;
  final void Function(Meal) onDelete;
  final void Function(Meal) onMealTap;

  const _MealGroup({
    required this.mealType,
    required this.meals,
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
                  child: Image.asset(
                    'lib/assets/diet/$mealType.png',
                    width: 20,
                    height: 20,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.fastfood, color: color, size: 20),
                  ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          _buildMealIcon(),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              meal.foodName,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

  Widget _buildMealIcon() {
    if (meal.imageUrl != null && meal.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: meal.imageUrl!,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          placeholder: (context, url) => _defaultIconContainer(),
          errorWidget: (context, url, error) => _defaultIconContainer(),
        ),
      );
    }
    return _defaultIconContainer();
  }

  Widget _defaultIconContainer() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.restaurant,
        color: Colors.grey,
        size: 22,
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final String? imagePath;
  final IconData? icon;
  final Color? color;
  final String label;
  final VoidCallback onTap;

  const _QuickActionTile({
    this.imagePath,
    this.icon,
    this.color,
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
          color: (color ?? AppTheme.primaryColor).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: imagePath != null
            ? Padding(
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  imagePath!,
                  width: 24,
                  height: 24,
                  errorBuilder: (_, __, ___) => Icon(
                    icon ?? Icons.fastfood,
                    color: color ?? AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
              )
            : Icon(icon, color: color ?? AppTheme.primaryColor, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}