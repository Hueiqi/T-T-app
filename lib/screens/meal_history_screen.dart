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
      body: SafeArea(
        child: Column(
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
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.72,
          children: _filteredMeals.map((meal) => _HistoryMealCard(meal: meal)).toList(),
        ),
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
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _buildImage(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.foodName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${meal.calories.toStringAsFixed(0)} kcal',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warningColor,
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

  Widget _buildImage() {
    if (meal.imageUrl != null && meal.imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: meal.imageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => _placeholderWidget(),
        errorWidget: (context, url, error) => _placeholderWidget(),
      );
    }
    return _placeholderWidget();
  }

  Widget _placeholderWidget() {
    return Container(
      color: Colors.grey.withValues(alpha: 0.15),
      child: const Center(
        child: Icon(
          Icons.restaurant,
          color: Colors.grey,
          size: 40,
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final totalVitamins = meal.vitaminA + meal.vitaminB + meal.vitaminC +
        meal.vitaminD + meal.vitaminE + meal.vitaminK;
    final totalMinerals = meal.calcium + meal.iron + meal.magnesium +
        meal.potassium + meal.sodium;
    final hasMicros = totalVitamins > 0 || totalMinerals > 0 || meal.fiber > 0 || meal.water > 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => ListView(
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
            // Food image
            if (meal.imageUrl != null && meal.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: meal.imageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (ctx, url) => _detailPlaceholder(),
                  errorWidget: (ctx, url, error) => _detailPlaceholder(),
                ),
              )
            else
              _detailPlaceholder(),
            const SizedBox(height: 20),
            Text(
              meal.foodName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _typeChip(meal.mealType),
                const SizedBox(width: 12),
                Text(
                  DateFormat('MMM d, yyyy – hh:mm a').format(meal.dateTime),
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Macros
            const Text(
              'Macronutrients',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _nutrientCard('Calories', '${meal.calories.toStringAsFixed(0)} kcal', AppTheme.warningColor, Icons.local_fire_department)),
                const SizedBox(width: 8),
                Expanded(child: _nutrientCard('Protein', '${meal.protein.toStringAsFixed(1)}g', AppTheme.accentColor, Icons.fitness_center)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _nutrientCard('Carbs', '${meal.carbs.toStringAsFixed(1)}g', AppTheme.successColor, Icons.grain)),
                const SizedBox(width: 8),
                Expanded(child: _nutrientCard('Fat', '${meal.fat.toStringAsFixed(1)}g', AppTheme.secondaryColor, Icons.water_drop)),
              ],
            ),
            if (hasMicros) ...[
              const SizedBox(height: 20),
              const Text(
                'Micronutrients',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (totalVitamins > 0) ...[
                const Text('Vitamins', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (meal.vitaminA > 0) _microTag('A', '${meal.vitaminA.toStringAsFixed(1)}mg'),
                    if (meal.vitaminB > 0) _microTag('B', '${meal.vitaminB.toStringAsFixed(1)}mg'),
                    if (meal.vitaminC > 0) _microTag('C', '${meal.vitaminC.toStringAsFixed(1)}mg'),
                    if (meal.vitaminD > 0) _microTag('D', '${meal.vitaminD.toStringAsFixed(1)}mg'),
                    if (meal.vitaminE > 0) _microTag('E', '${meal.vitaminE.toStringAsFixed(1)}mg'),
                    if (meal.vitaminK > 0) _microTag('K', '${meal.vitaminK.toStringAsFixed(1)}mg'),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (totalMinerals > 0) ...[
                const Text('Minerals', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (meal.calcium > 0) _microTag('Calcium', '${meal.calcium.toStringAsFixed(1)}mg'),
                    if (meal.iron > 0) _microTag('Iron', '${meal.iron.toStringAsFixed(1)}mg'),
                    if (meal.magnesium > 0) _microTag('Magnesium', '${meal.magnesium.toStringAsFixed(1)}mg'),
                    if (meal.potassium > 0) _microTag('Potassium', '${meal.potassium.toStringAsFixed(1)}mg'),
                    if (meal.sodium > 0) _microTag('Sodium', '${meal.sodium.toStringAsFixed(1)}mg'),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (meal.fiber > 0 || meal.water > 0) ...[
                const Text('Other', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (meal.fiber > 0) _microTag('Fiber', '${meal.fiber.toStringAsFixed(1)}g'),
                    if (meal.water > 0) _microTag('Water', '${meal.water.toStringAsFixed(0)}ml'),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _detailPlaceholder() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Icon(
          Icons.restaurant,
          color: Colors.grey,
          size: 56,
        ),
      ),
    );
  }

  Widget _nutrientCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _microTag(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $value', style: const TextStyle(fontSize: 12)),
    );
  }

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
}
