import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/nutrition_provider.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';
import '../data/food_database.dart';
import '../services/food_library.dart';
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
  String _selectedFilter = 'My Foods';
  String _query = '';
  bool _isLoading = false;
  String? _onlineError;

  static const List<String> _filters = ['My Foods', 'Meals', 'Online'];

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    await FoodLibrary.load();
  }

  // ─── Local data (full library) ─────────────────────────────
  List<FoodItemDisplay> get _allFoods =>
      FoodLibrary.all.map((f) => FoodItemDisplay(
            f.name, f.calories, f.servingSize,
            f.protein, f.carbs, f.fat,
            fiber: f.fiber, sugar: f.sugar, sodium: f.sodium,
            vitaminA: f.vitaminA, vitaminB: f.vitaminB, vitaminC: f.vitaminC,
            vitaminD: f.vitaminD, vitaminE: f.vitaminE, vitaminK: f.vitaminK,
            calcium: f.calcium, iron: f.iron, magnesium: f.magnesium,
            potassium: f.potassium, water: f.water,
          )).toList();

  List<FoodItemDisplay> get _myFoods {
    final nutrition = context.read<NutritionProvider>();
    final seen = <String>{};
    return nutrition.todayMeals
        .where((m) => seen.add(m.foodName))
        .map((m) => FoodItemDisplay(m.foodName, m.calories, '1 serving', m.protein, m.carbs, m.fat))
        .toList();
  }

  List<ComboDisplay> get _mealCombos => mealCombos.map((m) => ComboDisplay(m.name, m.calories.toDouble(), m.items)).toList();

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
      case 'Online':
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
  Future<Meal> _addMeal(String name, double calories, double protein, double carbs, double fat, {
    String? imageUrl,
    double fiber = 0,
    double sodium = 0,
    double vitaminA = 0,
    double vitaminB = 0,
    double vitaminC = 0,
    double vitaminD = 0,
    double vitaminE = 0,
    double vitaminK = 0,
    double calcium = 0,
    double iron = 0,
    double magnesium = 0,
    double potassium = 0,
    double water = 0,
  }) async {
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
      fiber: fiber,
      sodium: sodium,
      vitaminA: vitaminA,
      vitaminB: vitaminB,
      vitaminC: vitaminC,
      vitaminD: vitaminD,
      vitaminE: vitaminE,
      vitaminK: vitaminK,
      calcium: calcium,
      iron: iron,
      magnesium: magnesium,
      potassium: potassium,
      water: water,
    );
  }

  // ─── Add local food ──────────────────────────────────────────
  Future<void> _selectFood(FoodItemDisplay food) async {
    final meal = await _addMeal(food.name, food.calories, food.protein, food.carbs, food.fat,
      fiber: food.fiber,
      sodium: food.sodium,
      vitaminA: food.vitaminA,
      vitaminB: food.vitaminB,
      vitaminC: food.vitaminC,
      vitaminD: food.vitaminD,
      vitaminE: food.vitaminE,
      vitaminK: food.vitaminK,
      calcium: food.calcium,
      iron: food.iron,
      magnesium: food.magnesium,
      potassium: food.potassium,
      water: food.water,
    );
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

  // ─── Show food detail bottom sheet ───────────────────────────
  void _showFoodDetail(FoodItemDisplay food) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                food.name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                food.servingSize,
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
              const SizedBox(height: 20),

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
              const SizedBox(height: 20),

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
              const SizedBox(height: 20),

              // ── Minerals ──
              const Text('Minerals', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 10),
              _nutrientRow('Calcium', '${food.calcium.toStringAsFixed(1)} mg', Colors.white70, Icons.circle),
              const SizedBox(height: 6),
              _nutrientRow('Iron', '${food.iron.toStringAsFixed(1)} mg', Colors.red.shade700, Icons.circle),
              const SizedBox(height: 6),
              _nutrientRow('Magnesium', '${food.magnesium.toStringAsFixed(1)} mg', Colors.purple, Icons.circle),
              const SizedBox(height: 6),
              _nutrientRow('Potassium', '${food.potassium.toStringAsFixed(1)} mg', Colors.blue, Icons.circle),
              const SizedBox(height: 28),

              // ── Buttons ──
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Back'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _selectFood(food);
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Add Meal'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
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

  // ─── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Library'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Search bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (v) {
                  setState(() => _query = v);
                  if (_selectedFilter == 'Online') {
                    if (v.trim().isEmpty) {
                      setState(() { _onlineResults = []; _onlineError = null; });
                    } else {
                      _searchOnline(v);
                    }
                  }
                },
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
                          } else if (_query.trim().isNotEmpty) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _searchOnline(_query);
                            });
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
            onTap: () => _showFoodDetail(item),
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
  final double fiber;
  final double sugar;
  final double sodium;
  final double vitaminA;
  final double vitaminB;
  final double vitaminC;
  final double vitaminD;
  final double vitaminE;
  final double vitaminK;
  final double calcium;
  final double iron;
  final double magnesium;
  final double potassium;
  final double water;

  FoodItemDisplay(
    this.name,
    this.calories,
    this.servingSize,
    this.protein,
    this.carbs,
    this.fat, {
    this.imageUrl,
    this.barcode,
    this.fiber = 0,
    this.sugar = 0,
    this.sodium = 0,
    this.vitaminA = 0,
    this.vitaminB = 0,
    this.vitaminC = 0,
    this.vitaminD = 0,
    this.vitaminE = 0,
    this.vitaminK = 0,
    this.calcium = 0,
    this.iron = 0,
    this.magnesium = 0,
    this.potassium = 0,
    this.water = 0,
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
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 24),
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