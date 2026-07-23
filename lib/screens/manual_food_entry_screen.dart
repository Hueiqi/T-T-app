import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/nutrition_provider.dart';
import '../providers/auth_provider.dart';
import '../services/ai_service.dart';
import '../models/saved_food_model.dart';
import 'nutrition_success_screen.dart';

class ManualFoodEntryScreen extends StatefulWidget {
  final String mealType;
  final SavedFood? presetFood;
  const ManualFoodEntryScreen({super.key, required this.mealType, this.presetFood});

  @override
  State<ManualFoodEntryScreen> createState() => _ManualFoodEntryScreenState();
}

class _ManualFoodEntryScreenState extends State<ManualFoodEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _servingAmountController = TextEditingController(text: '1');
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _fiberController = TextEditingController();
  final _sugarController = TextEditingController();
  final _sodiumController = TextEditingController();
  final _vitaminAController = TextEditingController();
  final _vitaminBController = TextEditingController();
  final _vitaminCController = TextEditingController();
  final _vitaminDController = TextEditingController();
  final _vitaminEController = TextEditingController();
  final _vitaminKController = TextEditingController();
  final _calciumController = TextEditingController();
  final _ironController = TextEditingController();
  final _magnesiumController = TextEditingController();
  final _potassiumController = TextEditingController();

  String _mealType = '';
  String _servingUnit = 'serving';
  bool _isAILoading = false;
  bool _showVitamins = false;
  bool _showMinerals = false;
  bool _saveToLibrary = true;

  final AIService _ai = AIService();

  static const List<String> _servingUnits = [
    'serving',
    'g',
    'set',
    'cup',
    'piece',
    'ml',
    'oz',
    'bowl',
    'slice',
    'can',
    'plate',
    'stick',
    'tbsp',
    'tsp',
    'pack',
    'bag',
    'bottle',
    'litre',
    'kg',
    'scoop',
    'wedge',
    'handful',
    'bunch',
    'dash',
    'pinch',
    'fl oz',
    'ear',
    'fillet',
    'drumstick',
    'square',
    'strip',
    'sprig',
  ];

  @override
  void initState() {
    super.initState();
    _mealType = widget.mealType;
    final preset = widget.presetFood;
    if (preset != null) {
      _nameController.text = preset.foodName;
      _parseServingSize(preset.servingSize);
      _caloriesController.text = _numText(preset.calories);
      _proteinController.text = _numText(preset.protein);
      _carbsController.text = _numText(preset.carbs);
      _fatController.text = _numText(preset.fat);
      _fiberController.text = _numText(preset.fiber);
      _sugarController.text = _numText(preset.sugar);
      _sodiumController.text = _numText(preset.sodium);
      _vitaminAController.text = _numText(preset.vitaminA);
      _vitaminBController.text = _numText(preset.vitaminB);
      _vitaminCController.text = _numText(preset.vitaminC);
      _vitaminDController.text = _numText(preset.vitaminD);
      _vitaminEController.text = _numText(preset.vitaminE);
      _vitaminKController.text = _numText(preset.vitaminK);
      _calciumController.text = _numText(preset.calcium);
      _ironController.text = _numText(preset.iron);
      _magnesiumController.text = _numText(preset.magnesium);
      _potassiumController.text = _numText(preset.potassium);
    }
  }

  String _numText(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  void _parseServingSize(String size) {
    final match = RegExp(r'^([\d.]+)\s*(.*)$').firstMatch(size.trim());
    if (match != null) {
      _servingAmountController.text = match.group(1) ?? '1';
      final unit = match.group(2)?.trim().toLowerCase() ?? 'serving';
      _servingUnit = _servingUnits.contains(unit) ? unit : 'serving';
    } else {
      _servingAmountController.text = size;
    }
  }

  String get _fullServingSize => '${_servingAmountController.text.trim()} $_servingUnit';

  @override
  void dispose() {
    _nameController.dispose();
    _servingAmountController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _fiberController.dispose();
    _sugarController.dispose();
    _sodiumController.dispose();
    _vitaminAController.dispose();
    _vitaminBController.dispose();
    _vitaminCController.dispose();
    _vitaminDController.dispose();
    _vitaminEController.dispose();
    _vitaminKController.dispose();
    _calciumController.dispose();
    _ironController.dispose();
    _magnesiumController.dispose();
    _potassiumController.dispose();
    super.dispose();
  }

  Future<void> _aiAssist() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a food name first')),
      );
      return;
    }

    setState(() => _isAILoading = true);

    try {
      final data = await _ai.autoFillNutritionFromName(name);
      if (!mounted) return;

      setState(() {
        _caloriesController.text = _toDouble(data['calories']);
        _proteinController.text = _toDouble(data['protein']);
        _carbsController.text = _toDouble(data['carbs']);
        _fatController.text = _toDouble(data['fat']);
        _fiberController.text = _toDouble(data['fiber']);
        _sugarController.text = _toDouble(data['sugar']);
        _sodiumController.text = _toDouble(data['sodium']);
        _vitaminAController.text = _toDouble(data['vitaminA']);
        _vitaminBController.text = _toDouble(data['vitaminB']);
        _vitaminCController.text = _toDouble(data['vitaminC']);
        _vitaminDController.text = _toDouble(data['vitaminD']);
        _vitaminEController.text = _toDouble(data['vitaminE']);
        _vitaminKController.text = _toDouble(data['vitaminK']);
        _calciumController.text = _toDouble(data['calcium']);
        _ironController.text = _toDouble(data['iron']);
        _magnesiumController.text = _toDouble(data['magnesium']);
        _potassiumController.text = _toDouble(data['potassium']);
        final serving = data['servingSize'];
        if (serving != null && serving is String && serving.isNotEmpty) {
          _parseServingSize(serving);
        }
        _isAILoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nutrition data filled automatically (Gemini)')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAILoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI failed: $e')),
      );
    }
  }

  String _toDouble(dynamic v) {
    if (v == null) return '0';
    if (v is double) return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
    if (v is int) return v.toString();
    return v.toString();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;

    final nutrition = context.read<NutritionProvider>();

    final meal = await nutrition.saveMeal(
      userId: auth.user!.uid,
      mealType: _mealType,
      foodName: _nameController.text.trim(),
      calories: double.tryParse(_caloriesController.text) ?? 0,
      protein: double.tryParse(_proteinController.text) ?? 0,
      carbs: double.tryParse(_carbsController.text) ?? 0,
      fat: double.tryParse(_fatController.text) ?? 0,
      fiber: double.tryParse(_fiberController.text) ?? 0,
      sodium: double.tryParse(_sodiumController.text) ?? 0,
      vitaminA: double.tryParse(_vitaminAController.text) ?? 0,
      vitaminB: double.tryParse(_vitaminBController.text) ?? 0,
      vitaminC: double.tryParse(_vitaminCController.text) ?? 0,
      vitaminD: double.tryParse(_vitaminDController.text) ?? 0,
      vitaminE: double.tryParse(_vitaminEController.text) ?? 0,
      vitaminK: double.tryParse(_vitaminKController.text) ?? 0,
      calcium: double.tryParse(_calciumController.text) ?? 0,
      iron: double.tryParse(_ironController.text) ?? 0,
      magnesium: double.tryParse(_magnesiumController.text) ?? 0,
      potassium: double.tryParse(_potassiumController.text) ?? 0,
    );

    if (_saveToLibrary) {
      await nutrition.saveFoodToLibrary(
        userId: auth.user!.uid,
        foodName: _nameController.text.trim(),
        servingSize: _fullServingSize,
        calories: double.tryParse(_caloriesController.text) ?? 0,
        protein: double.tryParse(_proteinController.text) ?? 0,
        carbs: double.tryParse(_carbsController.text) ?? 0,
        fat: double.tryParse(_fatController.text) ?? 0,
        fiber: double.tryParse(_fiberController.text) ?? 0,
        sugar: double.tryParse(_sugarController.text) ?? 0,
        sodium: double.tryParse(_sodiumController.text) ?? 0,
        vitaminA: double.tryParse(_vitaminAController.text) ?? 0,
        vitaminB: double.tryParse(_vitaminBController.text) ?? 0,
        vitaminC: double.tryParse(_vitaminCController.text) ?? 0,
        vitaminD: double.tryParse(_vitaminDController.text) ?? 0,
        vitaminE: double.tryParse(_vitaminEController.text) ?? 0,
        vitaminK: double.tryParse(_vitaminKController.text) ?? 0,
        calcium: double.tryParse(_calciumController.text) ?? 0,
        iron: double.tryParse(_ironController.text) ?? 0,
        magnesium: double.tryParse(_magnesiumController.text) ?? 0,
        potassium: double.tryParse(_potassiumController.text) ?? 0,
      );
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => NutritionSuccessScreen(meal: meal)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Food Manually'),
        actions: [
          TextButton(
            onPressed: _isAILoading ? null : _save,
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Food name + AI button ──
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Food Name',
                      prefixIcon: Icon(Icons.restaurant),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isAILoading ? null : _aiAssist,
                    icon: _isAILoading
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('AI', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Type a food name, then tap AI to auto-fill nutrition info',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),

            // ── Meal type dropdown ──
            DropdownButtonFormField<String>(
              initialValue: _mealType.isNotEmpty ? _mealType : null,
              decoration: const InputDecoration(
                labelText: 'Meal Type',
                prefixIcon: Icon(Icons.schedule),
              ),
              items: const [
                DropdownMenuItem(value: 'breakfast', child: Text('Breakfast')),
                DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
                DropdownMenuItem(value: 'snack', child: Text('Snack')),
              ],
              onChanged: (v) => setState(() => _mealType = v ?? _mealType),
            ),
            const SizedBox(height: 12),

            // ── Serving size: amount + unit (stacked, full width) ──
            _numField(_servingAmountController, 'Serving Amount (e.g. 1, 100, 0.5)', Icons.straighten),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _servingUnit,
              decoration: const InputDecoration(
                labelText: 'Serving Unit',
                prefixIcon: Icon(Icons.straighten),
              ),
              items: _servingUnits
                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                  .toList(),
              onChanged: (v) => setState(() => _servingUnit = v ?? _servingUnit),
            ),
            const SizedBox(height: 16),

            // ── Save to library toggle ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.bookmark_add, size: 20, color: AppTheme.primaryColor),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Save to My Foods',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  Switch(
                    value: _saveToLibrary,
                    onChanged: (v) => setState(() => _saveToLibrary = v),
                    activeThumbColor: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Core macros (single row each) ──
            Text('Macros', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            _numField(_caloriesController, 'Calories (kcal)', Icons.local_fire_department),
            const SizedBox(height: 8),
            _numField(_proteinController, 'Protein (g)', Icons.fitness_center),
            const SizedBox(height: 8),
            _numField(_carbsController, 'Carbs (g)', Icons.grain),
            const SizedBox(height: 8),
            _numField(_fatController, 'Fat (g)', Icons.water_drop),
            const SizedBox(height: 8),
            _numField(_fiberController, 'Fiber (g)', Icons.eco),
            const SizedBox(height: 8),
            _numField(_sugarController, 'Sugar (g)', Icons.cookie),
            const SizedBox(height: 8),
            _numField(_sodiumController, 'Sodium (mg)', Icons.science),
            const SizedBox(height: 20),

            // ── Vitamins (expandable, single row each) ──
            _expandableSection(
              title: 'Vitamins',
              expanded: _showVitamins,
              onToggle: () => setState(() => _showVitamins = !_showVitamins),
              child: Column(
                children: [
                  _numField(_vitaminAController, 'Vitamin A (mcg)', Icons.circle, color: Colors.orange),
                  const SizedBox(height: 8),
                  _numField(_vitaminBController, 'Vitamin B (mg)', Icons.circle, color: Colors.yellow.shade700),
                  const SizedBox(height: 8),
                  _numField(_vitaminCController, 'Vitamin C (mg)', Icons.circle, color: Colors.green),
                  const SizedBox(height: 8),
                  _numField(_vitaminDController, 'Vitamin D (mcg)', Icons.circle, color: Colors.amber),
                  const SizedBox(height: 8),
                  _numField(_vitaminEController, 'Vitamin E (mg)', Icons.circle, color: Colors.teal),
                  const SizedBox(height: 8),
                  _numField(_vitaminKController, 'Vitamin K (mcg)', Icons.circle, color: Colors.brown),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Minerals (expandable, single row each) ──
            _expandableSection(
              title: 'Minerals',
              expanded: _showMinerals,
              onToggle: () => setState(() => _showMinerals = !_showMinerals),
              child: Column(
                children: [
                  _numField(_calciumController, 'Calcium (mg)', Icons.circle, color: Colors.white70),
                  const SizedBox(height: 8),
                  _numField(_ironController, 'Iron (mg)', Icons.circle, color: Colors.red.shade700),
                  const SizedBox(height: 8),
                  _numField(_magnesiumController, 'Magnesium (mg)', Icons.circle, color: Colors.purple),
                  const SizedBox(height: 8),
                  _numField(_potassiumController, 'Potassium (mg)', Icons.circle, color: Colors.blue),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Save button ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check, size: 20),
                label: const Text('Add Food', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _numField(TextEditingController ctrl, String label, IconData icon, {Color? color}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: color, size: 18),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _expandableSection({
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const Spacer(),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more, color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: child,
            ),
          ],
        ],
      ),
    );
  }
}
