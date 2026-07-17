import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/nutrition_provider.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';
import '../data/food_database.dart';
import '../models/meal_model.dart';
import '../services/food_api_service.dart';
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
  bool _isLoading = false;
  String? _onlineError;

  static const List<String> _filters = ['All', 'My Foods', 'Meals', 'Recipes', 'Online'];

  // ─── Local data ───────────────────────────────────────────────
  List<FoodItemDisplay> get _allFoods =>
      commonFoods.map((f) => FoodItemDisplay(f.name, f.calories.toDouble(), f.servingSize, f.protein, f.carbs, f.fat)).toList();

  List<FoodItemDisplay> get _myFoods {
    final nutrition = context.read<NutritionProvider>();
    final seen = <String>{};
    return nutrition.todayMeals
        .where((m) => seen.add(m.foodName))
        .map((m) => FoodItemDisplay(m.foodName, m.calories, '1 serving', m.protein, m.carbs, m.fat))
        .toList();
  }

  List<ComboDisplay> get _mealCombos => mealCombos.map((m) => ComboDisplay(m.name, m.calories.toDouble(), m.items)).toList();
  List<ComboDisplay> get _recipes => sampleRecipes.map((r) => ComboDisplay(r.name, r.calories.toDouble(), r.ingredients)).toList();

  // ─── Online search ─────────────────────────────────────────────
  final FoodApiService _api = FoodApiService();
  List<FoodItemDisplay> _onlineResults = [];

  Future<void> _searchOnline(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _onlineResults = []; _onlineError = null; });
      return;
    }
    setState(() { _isLoading = true; _onlineError = null; });
    try {
      final results = await _api.searchProducts(query);
      final items = results.map((p) {
        return FoodItemDisplay(
          p['name'] ?? 'Unknown',
          0,                           // placeholder – fetched on add
          '100g',
          0, 0, 0,
          imageUrl: p['image'] ?? '',
          barcode: p['barcode'] ?? '',
        );
      }).toList();
      setState(() {
        _onlineResults = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _onlineError = 'Online search failed. Please try again.';
        _isLoading = false;
        _onlineResults = [];
      });
    }
  }

  // ─── Filtered items ────────────────────────────────────────────
  List<dynamic> get _filteredItems {
    final q = _query.toLowerCase().trim();

    switch (_selectedFilter) {
      case 'My Foods':
        var items = _myFoods;
        if (q.isNotEmpty) items = items.where((f) => f.name.toLowerCase().contains(q)).toList();
        return items;
      case 'Meals':
        var items = _mealCombos;
        if (q.isNotEmpty) items = items.where((m) => m.name.toLowerCase().contains(q)).toList();
        return items;
      case 'Recipes':
        var items = _recipes;
        if (q.isNotEmpty) items = items.where((r) => r.name.toLowerCase().contains(q)).toList();
        return items;
      case 'Online':
        if (q.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_isLoading) _searchOnline(q);
          });
        } else {
          setState(() { _onlineResults = []; });
        }
        return _onlineResults;
      default: // All
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

  // ─── Add meal (general) ───────────────────────────────────────
  Future<Meal> _addMeal(String name, double calories, double protein, double carbs, double fat, {String? imageUrl}) async {
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
      imageUrl: imageUrl,
    );
  }

  // ─── Add local food ──────────────────────────────────────────
  Future<void> _selectFood(FoodItemDisplay food) async {
    final meal = await _addMeal(food.name, food.calories, food.protein, food.carbs, food.fat);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => NutritionSuccessScreen(meal: meal)),
    );
  }

  // ─── Add combo (meals / recipes) ────────────────────────────
  Future<void> _selectCombo(ComboDisplay combo) async {
    if (combo.items.isEmpty) return;
    final calsPerItem = combo.calories / combo.items.length;
    final firstMeal = await _addMeal(combo.items.first, calsPerItem, 0, 0, 0);
    for (int i = 1; i < combo.items.length; i++) {
      await _addMeal(combo.items[i], calsPerItem, 0, 0, 0);
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => NutritionSuccessScreen(meal: firstMeal)),
    );
  }

  // ─── Add online food (fetches full nutrition by barcode) ───
  Future<void> _addOnlineFood(FoodItemDisplay food) async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;

    try {
      final data = await _api.getProductByBarcode(food.barcode!);
      final meal = await _addMeal(
        data['name'],
        data['calories'],
        data['protein'],
        data['carbs'],
        data['fat'],
        imageUrl: data['image'],
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => NutritionSuccessScreen(meal: meal)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch nutrition: $e')),
      );
    }
  }

  // ─── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;

    return Scaffold(
      appBar: AppBar(
        title: Text('Add ${widget.mealType[0].toUpperCase()}${widget.mealType.substring(1)}'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
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
            // Filters
            Container(
              color: Colors.white,
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filters.map((filter) {
                    final selected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: selected,
                        onSelected: (_) => setState(() {
                          _selectedFilter = filter;
                          if (filter != 'Online') {
                            _onlineResults = [];
                            _onlineError = null;
                          }
                        }),
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
            ),
            // Results
            Expanded(
              child: _buildResults(items),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(List<dynamic> items) {
    if (_selectedFilter == 'Online' && _query.isNotEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_selectedFilter == 'Online' && _onlineError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppTheme.errorColor, size: 48),
            const SizedBox(height: 12),
            Text(_onlineError!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.errorColor)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _searchOnline(_query),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              _query.isNotEmpty ? 'No results for "$_query"' : 'No items found',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            if (_selectedFilter == 'Online' && _query.isNotEmpty)
              TextButton(
                onPressed: () => _searchOnline(_query),
                child: const Text('Search again'),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is FoodItemDisplay) {
          if (item.barcode != null && item.barcode!.isNotEmpty) {
            // Online item
            return _OnlineFoodTile(
              name: item.name,
              imageUrl: item.imageUrl,
              onTap: () => _addOnlineFood(item),
            );
          }
          // Local food
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
    );
  }
}

// ─── Data classes ───────────────────────────────────────────────

class FoodItemDisplay {
  final String name;
  final double calories;
  final String servingSize;
  final double protein;
  final double carbs;
  final double fat;
  final String? imageUrl;   // for online items
  final String? barcode;    // for online items

  FoodItemDisplay(
    this.name,
    this.calories,
    this.servingSize,
    this.protein,
    this.carbs,
    this.fat, {
    this.imageUrl,
    this.barcode,
  });
}

class ComboDisplay {
  final String name;
  final double calories;
  final List<String> items;
  ComboDisplay(this.name, this.calories, this.items);
}

// ─── UI tiles ────────────────────────────────────────────────────

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

class _OnlineFoodTile extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final VoidCallback onTap;

  const _OnlineFoodTile({
    required this.name,
    this.imageUrl,
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
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl != null && imageUrl!.isNotEmpty
                    ? Image.network(
                        imageUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.food_bank, size: 48),
                      )
                    : const Icon(Icons.food_bank, size: 48),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('Online · Open Food Facts', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
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

// ─── Helper widgets ─────────────────────────────────────────────

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