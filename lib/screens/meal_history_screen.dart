import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/nutrition_provider.dart';
import '../models/meal_model.dart';
import '../config/theme.dart';

class MealHistoryScreen extends StatefulWidget {
  const MealHistoryScreen({super.key});

  @override
  State<MealHistoryScreen> createState() => _MealHistoryScreenState();
}

class _MealHistoryScreenState extends State<MealHistoryScreen> {
  List<Meal> _allMeals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMeals();
  }

  Future<void> _loadMeals() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    setState(() => _loading = true);
    final meals = await context.read<NutritionProvider>().loadRecentMeals(auth.user!.uid, days: 30);
    setState(() {
      _allMeals = meals;
      _loading = false;
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _allMeals.isEmpty
              ? _buildEmptyState()
              : _buildGroupedList(),
    );
  }

  Widget _buildGroupedList() {
    final grouped = <String, List<Meal>>{};
    for (final meal in _allMeals) {
      final key = DateFormat('yyyy-MM-dd').format(meal.dateTime);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(meal);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedKeys.length,
      itemBuilder: (ctx, index) {
        final key = sortedKeys[index];
        final meals = grouped[key]!;
        final date = DateTime.parse(key);
        final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(date);
        final totalCal = meals.fold<double>(0, (s, m) => s + m.calories);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
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
            ...meals.map((meal) => _HistoryMealCard(meal: meal)),
            const SizedBox(height: 8),
          ],
        );
      },
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
    final hasNetworkImage = meal.imageUrl.isNotEmpty;
    final hasBytesImage = meal.imageBytes != null;
    final hasImage = hasNetworkImage || hasBytesImage;
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
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: hasNetworkImage
                  ? Image.network(
                      meal.imageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey.shade100,
                        child: Icon(Icons.broken_image, color: Colors.grey.shade400),
                      ),
                    )
                  : hasBytesImage
                      ? Image.memory(
                          meal.imageBytes!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey.shade100,
                            child: Icon(Icons.broken_image, color: Colors.grey.shade400),
                          ),
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          color: _mealTypeColor(meal.mealType).withOpacity(0.15),
                          child: Icon(
                            _mealTypeIcon(meal.mealType),
                            color: _mealTypeColor(meal.mealType),
                            size: 32,
                      ),
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

  Widget _typeChip(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _mealTypeColor(type).withOpacity(0.12),
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

  IconData _mealTypeIcon(String type) {
    switch (type) {
      case 'breakfast': return Icons.wb_sunny;
      case 'lunch': return Icons.wb_cloudy;
      case 'dinner': return Icons.nightlight_round;
      default: return Icons.restaurant;
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
            if (meal.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  meal.imageUrl,
                  height: 250,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 250,
                    color: Colors.grey.shade100,
                    child: const Icon(Icons.broken_image, size: 64),
                  ),
                ),
              )
            else if (meal.imageBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  meal.imageBytes!,
                  height: 250,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 250,
                    color: Colors.grey.shade100,
                    child: const Icon(Icons.broken_image, size: 64),
                  ),
                ),
              ),
            const SizedBox(height: 16),
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
            if (meal.vitamins > 0 || meal.minerals > 0 || meal.fiber > 0) ...[
              const Divider(),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                children: [
                  if (meal.vitamins > 0) _nutrientChip('Vitamins', '${meal.vitamins.toStringAsFixed(0)}g', Colors.purple),
                  if (meal.minerals > 0) _nutrientChip('Minerals', '${meal.minerals.toStringAsFixed(0)}g', Colors.teal),
                  if (meal.fiber > 0) _nutrientChip('Fiber', '${meal.fiber.toStringAsFixed(0)}g', Colors.brown),
                ],
              ),
            ],
            const SizedBox(height: 16),
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
}
