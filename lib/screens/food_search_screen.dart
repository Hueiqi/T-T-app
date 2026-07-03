import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/nutrition_provider.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';
import '../data/food_database.dart';
import '../models/meal_model.dart';
import 'nutrition_success_screen.dart';

class FoodSearchScreen extends StatefulWidget {
  final String mealType;
  const FoodSearchScreen({super.key, required this.mealType});

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  String _query = '';

  static const List<String> _filters = ['All', 'My Foods', 'Meals', 'Recipes'];

  List<FoodItemDisplay> get _allFoods =>
      commonFoods.map((f) => FoodItemDisplay(f.name, f.calories.toDouble(), f.servingSize, f.protein, f.carbs, f.fat)).toList();

  List<FoodItemDisplay> get _myFoods {
    final nutrition = context.read<NutritionProvider>();
    final seen = <String>{};
    return nutrition.todayMeals
        .where((m) => seen.add(m.foodName))
        .map((m) => FoodItemDisplay(m.foodName, m.calories, m.servingSize, m.protein, m.carbs, m.fat))
        .toList();
  }

  List<dynamic> get _filteredItems {
    final q = _query.toLowerCase().trim();
    switch (_selectedFilter) {
      case 'My Foods':
        var items = _myFoods;
        if (q.isNotEmpty) items = items.where((f) => f.name.toLowerCase().contains(q)).toList();
        return items;
      case 'Meals':
        var items = mealCombos.map((m) => ComboDisplay(m.name, m.calories.toDouble(), m.items)).toList();
        if (q.isNotEmpty) items = items.where((m) => m.name.toLowerCase().contains(q)).toList();
        return items;
      case 'Recipes':
        var items = sampleRecipes.map((r) => ComboDisplay(r.name, r.calories.toDouble(), r.ingredients)).toList();
        if (q.isNotEmpty) items = items.where((r) => r.name.toLowerCase().contains(q)).toList();
        return items;
      default:
        var items = _allFoods;
        if (q.isNotEmpty) items = items.where((f) => f.name.toLowerCase().contains(q)).toList();
        return items;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Meal> _addMeal(String name, double calories, double protein, double carbs, double fat, String servingSize) async {
    final nutrition = context.read<NutritionProvider>();
    final auth = context.read<AuthProvider>();
    if (auth.user == null) throw Exception('Not authenticated');

    return nutrition.saveMeal(
      userId: auth.user!.uid,
      mealType: widget.mealType,
      foodName: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      servingSize: servingSize,
      detectionMethod: 'manual',
    );
  }

  Future<void> _selectFood(FoodItemDisplay food) async {
    final meal = await _addMeal(food.name, food.calories, food.protein, food.carbs, food.fat, food.servingSize);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => NutritionSuccessScreen(meal: meal)),
    );
  }

  Future<void> _selectCombo(ComboDisplay combo) async {
    final calsPerItem = combo.calories / combo.items.length;
    if (combo.items.isEmpty) return;
    final meal = await _addMeal(combo.items.first, calsPerItem, 0, 0, 0, '1 serving');
    for (int i = 1; i < combo.items.length; i++) {
      await _addMeal(combo.items[i], calsPerItem, 0, 0, 0, '1 serving');
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => NutritionSuccessScreen(meal: meal)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;

    return Scaffold(
      appBar: AppBar(
        title: Text('Add ${widget.mealType[0].toUpperCase()}${widget.mealType.substring(1)}'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search foods...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: Row(
              children: _filters.map((filter) {
                final selected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedFilter = filter),
                    selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: selected ? AppTheme.primaryColor : AppTheme.textSecondary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                    ),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          _query.isNotEmpty ? 'No results for "$_query"' : 'No items found',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      if (item is FoodItemDisplay) {
                        return _FoodItemTile(
                          name: item.name,
                          calories: item.calories,
                          servingSize: item.servingSize,
                          protein: item.protein,
                          carbs: item.carbs,
                          fat: item.fat,
                          onTap: () => _selectFood(item),
                        );
                      } else if (item is ComboDisplay) {
                        return _ComboTile(
                          name: item.name,
                          calories: item.calories,
                          items: item.items,
                          onTap: () => _selectCombo(item),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class FoodItemDisplay {
  final String name;
  final double calories;
  final String servingSize;
  final double protein;
  final double carbs;
  final double fat;

  FoodItemDisplay(this.name, this.calories, this.servingSize, this.protein, this.carbs, this.fat);
}

class ComboDisplay {
  final String name;
  final double calories;
  final List<String> items;

  ComboDisplay(this.name, this.calories, this.items);
}

class _FoodItemTile extends StatelessWidget {
  final String name;
  final double calories;
  final String servingSize;
  final double protein;
  final double carbs;
  final double fat;
  final VoidCallback onTap;

  const _FoodItemTile({
    required this.name,
    required this.calories,
    required this.servingSize,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _calBadge('${calories.toInt()} kcal'),
                        const SizedBox(width: 8),
                        Text(servingSize, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withValues(alpha: 0.7))),
                      ],
                    ),
                  ],
                ),
              ),
              if (protein > 0 || carbs > 0 || fat > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (protein > 0) _macroBadge('P ${protein.toInt()}g', AppTheme.accentColor),
                    if (carbs > 0) _macroBadge('C ${carbs.toInt()}g', AppTheme.warningColor),
                    if (fat > 0) _macroBadge('F ${fat.toInt()}g', AppTheme.errorColor),
                  ],
                ),
              const SizedBox(width: 4),
              const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComboTile extends StatelessWidget {
  final String name;
  final double calories;
  final List<String> items;
  final VoidCallback onTap;

  const _ComboTile({
    required this.name,
    required this.calories,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.dashboard_customize, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      items.join(' · '),
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withValues(alpha: 0.7)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _calBadge('${calories.toInt()} kcal'),
              const SizedBox(width: 4),
              const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _calBadge(String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
  );
}

Widget _macroBadge(String label, Color color) {
  return Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color)),
    ),
  );
}
