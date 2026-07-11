import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/nutrition_provider.dart';
import '../models/meal_model.dart';
import '../config/theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MealHistoryScreen extends StatefulWidget {
  const MealHistoryScreen({super.key});

  @override
  State<MealHistoryScreen> createState() => _MealHistoryScreenState();
}

class _MealHistoryScreenState extends State<MealHistoryScreen> {
  List<Meal> _allMeals = [];
  List<Meal> _filteredMeals = [];
  bool _loading = true;
  DateTime _selectedDate = DateTime.now();
  final ScrollController _calendarScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMeals();
  }

  @override
  void dispose() {
    _calendarScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMeals() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    setState(() => _loading = true);
    final meals = await context.read<NutritionProvider>().loadRecentMeals(auth.user!.uid, days: 30);
    if (!mounted) return;
    setState(() {
      _allMeals = meals;
      _filterByDate(_selectedDate);
      _loading = false;
    });
  }

  void _filterByDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(hours: 24));
      _filteredMeals = _allMeals.where((m) =>
          m.dateTime.isAfter(startOfDay) && m.dateTime.isBefore(endOfDay)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMeals,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCalendarStrip(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMeals.isEmpty
                    ? _buildEmptyState()
                    : _buildGroupedList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList() {
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate);
    final totalCal = _filteredMeals.fold<double>(0, (s, m) => s + m.calories);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Row(
            children: [
              Text(
                dateStr,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Text(
                '${totalCal.toStringAsFixed(0)} kcal',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppTheme.warningColor,
                ),
              ),
            ],
          ),
        ),
        ..._filteredMeals.map((meal) => _HistoryMealCard(meal: meal)),
      ],
    );
  }

  Widget _buildCalendarStrip() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
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
                : () => _filterByDate(date),
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

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fastfood, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No meals logged yet', style: TextStyle(fontSize: 18)),
          SizedBox(height: 8),
          Text('Start logging your meals to see them here'),
        ],
      ),
    );
  }
}



class _HistoryMealCard extends StatelessWidget {
  final Meal meal;

  const _HistoryMealCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('hh:mm a').format(meal.dateTime);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetail(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
              // ─── REPLACE THE ICON WITH THIS ───
              child: meal.imageUrl != null && meal.imageUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: meal.imageUrl!,
                        fit: BoxFit.cover,
                        width: 80,
                        height: 80,
                        placeholder: (context, url) => Icon(
                          _mealIcon(meal.mealType),
                          color: AppTheme.primaryColor,
                          size: 32,
                        ),
                        errorWidget: (context, url, error) => Icon(
                          _mealIcon(meal.mealType),
                          color: AppTheme.primaryColor,
                          size: 32,
                        ),
                      ),
                    )
                  : Icon(
                      _mealIcon(meal.mealType),
                      color: AppTheme.primaryColor,
                      size: 32,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.foodName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _typeChip(meal.mealType),
                        const SizedBox(width: 8),
                        Text(
                          '${meal.calories.toStringAsFixed(0)} kcal',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.warningColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.chevron_right, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // ─── All the helper methods remain unchanged ───
  Widget _typeChip(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _mealTypeColor(type).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        type[0].toUpperCase() + type.substring(1),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: _mealTypeColor(type),
        ),
      ),
    );
  }

  Color _mealTypeColor(String type) {
    switch (type) {
      case 'breakfast': return const Color(0xFFF59E0B);
      case 'lunch': return const Color(0xFF059669);
      case 'dinner': return const Color(0xFF7C3AED);
      default: return const Color(0xFFEC4899);
    }
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
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
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _typeChip(meal.mealType),
                const SizedBox(width: 12),
                Text(
                  DateFormat('MMM d, yyyy – hh:mm a').format(meal.dateTime),
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _nutrientChip('Calories', '${meal.calories.toStringAsFixed(0)} kcal', AppTheme.warningColor),
                if (meal.protein > 0) _nutrientChip('Protein', '${meal.protein.toStringAsFixed(1)}g', AppTheme.accentColor),
                if (meal.carbs > 0) _nutrientChip('Carbs', '${meal.carbs.toStringAsFixed(1)}g', AppTheme.successColor),
                if (meal.fat > 0) _nutrientChip('Fat', '${meal.fat.toStringAsFixed(1)}g', AppTheme.secondaryColor),
              ],
            ),
            const SizedBox(height: 16),
            _microNutrientsSection(meal),
          ],
        ),
      ),
    );
  }

  Widget _nutrientChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _microNutrientsSection(Meal meal) {
    final totalVitamins = meal.vitaminA + meal.vitaminB + meal.vitaminC + meal.vitaminD + meal.vitaminE + meal.vitaminK;
    final totalMinerals = meal.calcium + meal.iron + meal.magnesium + meal.potassium + meal.sodium;
    if (totalVitamins <= 0 && totalMinerals <= 0 && meal.fiber <= 0) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          children: [
            if (totalVitamins > 0) _nutrientChip('Vitamins', '${totalVitamins.toStringAsFixed(0)}g', Colors.purple),
            if (totalMinerals > 0) _nutrientChip('Minerals', '${totalMinerals.toStringAsFixed(0)}g', Colors.teal),
            if (meal.fiber > 0) _nutrientChip('Fiber', '${meal.fiber.toStringAsFixed(0)}g', Colors.brown),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  IconData _mealIcon(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return Icons.wb_sunny;
      case 'lunch':
        return Icons.wb_cloudy;
      case 'dinner':
        return Icons.nightlight_round;
      default:
        return Icons.restaurant;
    }
  }
}
