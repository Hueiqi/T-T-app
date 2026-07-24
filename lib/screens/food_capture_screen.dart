import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../providers/nutrition_provider.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';
import '../models/food_item_model.dart';
import 'nutrition_success_screen.dart';

final _uuid = Uuid();

enum _CaptureState { capture, result, edit }

class FoodCaptureScreen extends StatefulWidget {
  final DateTime? initialDate;

  const FoodCaptureScreen({super.key, this.initialDate});

  @override
  State<FoodCaptureScreen> createState() => _FoodCaptureScreenState();
}

class _FoodCaptureScreenState extends State<FoodCaptureScreen> {
  _CaptureState _state = _CaptureState.capture;
  Uint8List? _imageBytes;
  String _selectedMealType = 'lunch';
  FoodItem? _detectedFood;
  late DateTime _selectedDate;
  bool _isUploading = false;

  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _servingAmountController = TextEditingController(text: '1');
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

  String _servingUnit = 'g';
  bool _showVitamins = false;
  bool _showMinerals = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _servingAmountController.dispose();
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

  // ─── Image Upload ──────────────────────────────────────────────
  Future<String?> _uploadImage(String userId) async {
    if (_imageBytes == null) return null;
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('meals/$userId/${_uuid.v4()}.jpg');
      await ref.putData(_imageBytes!);
      return await ref.getDownloadURL();
    } catch (e) {
      _showError('Failed to upload image: $e');
      return null;
    }
  }

  // ─── Save Meal ─────────────────────────────────────────────────
  Future<void> _saveMeal() async {
    final nutrition = context.read<NutritionProvider>();
    final auth = context.read<AuthProvider>();
    if (auth.user == null) {
      _showError('User not authenticated');
      return;
    }

    final name = _nameController.text.trim();
    final calories = double.tryParse(_caloriesController.text.trim()) ?? 0;
    final protein = double.tryParse(_proteinController.text.trim()) ?? 0;
    final carbs = double.tryParse(_carbsController.text.trim()) ?? 0;
    final fat = double.tryParse(_fatController.text.trim()) ?? 0;
    if (name.isEmpty || calories <= 0) {
      _showError('Please enter food name and valid calories.');
      return;
    }

    setState(() => _isUploading = true);

    String? imageUrl;
    if (_imageBytes != null) {
      imageUrl = await _uploadImage(auth.user!.uid);
      if (imageUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image upload failed, but meal will be saved.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    final fiber = double.tryParse(_fiberController.text.trim()) ?? 0;
    final sodium = double.tryParse(_sodiumController.text.trim()) ?? 0;

    final meal = await nutrition.saveMeal(
      userId: auth.user!.uid,
      mealType: _selectedMealType,
      foodName: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      sodium: sodium,
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
      dateTime: _selectedDate,
      imageUrl: imageUrl,
    );

    if (mounted) {
      setState(() => _isUploading = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => NutritionSuccessScreen(meal: meal)),
      );
    }
  }

  // ─── Camera / Gallery ──────────────────────────────────────────
  Future<void> _takePhoto() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
    );
    if (photo != null) await _processImage(photo);
  }

  Future<void> _pickFromGallery() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (photo != null) await _processImage(photo);
  }

  Future<void> _processImage(XFile file) async {
    setState(() {
      _detectedFood = null;
    });
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _imageBytes = bytes);

    final nutrition = context.read<NutritionProvider>();
    final detected = await nutrition.analyzeFoodImage(bytes);
    if (!mounted) return;

    setState(() {
      if (detected != null) {
        _detectedFood = detected;
        _nameController.text = detected.name;
        _caloriesController.text = detected.totalCalories.toStringAsFixed(0);
        _proteinController.text = detected.totalProtein.toStringAsFixed(1);
        _carbsController.text = detected.totalCarbs.toStringAsFixed(1);
        _fatController.text = detected.totalFat.toStringAsFixed(1);
        _servingAmountController.text = detected.servingSizeGrams.toInt().toString();
        _servingUnit = 'g';
        _selectedMealType = ['breakfast', 'lunch', 'dinner', 'snack']
                .contains(detected.category)
            ? detected.category
            : _selectedMealType;
        _state = _CaptureState.result;
      } else {
        _state = _CaptureState.edit;
      }
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static const List<String> _servingUnits = [
    'serving', 'g', 'set', 'cup', 'piece', 'ml', 'oz', 'bowl',
    'slice', 'can', 'plate', 'stick', 'tbsp', 'tsp', 'pack', 'bag',
    'bottle', 'litre', 'kg', 'scoop', 'wedge', 'handful', 'bunch',
    'dash', 'pinch', 'fl oz', 'ear', 'fillet', 'drumstick', 'square',
    'strip', 'sprig',
  ];

  void _openEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => StatefulBuilder(
          builder: (context, setSheetState) => SingleChildScrollView(
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
                Row(
                  children: [
                    Icon(Icons.edit_note, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Edit Meal Details',
                      style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Food name ──
                _buildEditField(
                  controller: _nameController,
                  label: 'Food Name', icon: Icons.restaurant, required: true,
                ),
                const SizedBox(height: 12),

                // ── Meal type dropdown ──
                DropdownButtonFormField<String>(
                  initialValue: _selectedMealType,
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
                  onChanged: (v) => setSheetState(() => _selectedMealType = v ?? _selectedMealType),
                ),
                const SizedBox(height: 12),

                // ── Serving amount ──
                _buildEditField(
                  controller: _servingAmountController,
                  label: 'Serving Amount (e.g. 1, 100, 0.5)',
                  icon: Icons.straighten,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),

                // ── Serving unit dropdown ──
                DropdownButtonFormField<String>(
                  initialValue: _servingUnit,
                  decoration: const InputDecoration(
                    labelText: 'Serving Unit',
                    prefixIcon: Icon(Icons.straighten),
                  ),
                  items: _servingUnits
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) => setSheetState(() => _servingUnit = v ?? _servingUnit),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // ── Macros (single row each) ──
                Text('Macros', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 10),
                _buildEditField(controller: _caloriesController, label: 'Calories (kcal)', icon: Icons.local_fire_department, keyboardType: TextInputType.number, required: true),
                const SizedBox(height: 8),
                _buildEditField(controller: _proteinController, label: 'Protein (g)', icon: Icons.fitness_center, keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                _buildEditField(controller: _carbsController, label: 'Carbs (g)', icon: Icons.grain, keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                _buildEditField(controller: _fatController, label: 'Fat (g)', icon: Icons.water_drop, keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                _buildEditField(controller: _fiberController, label: 'Fiber (g)', icon: Icons.eco, keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                _buildEditField(controller: _sugarController, label: 'Sugar (g)', icon: Icons.cookie, keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                _buildEditField(controller: _sodiumController, label: 'Sodium (mg)', icon: Icons.science, keyboardType: TextInputType.number),
                const SizedBox(height: 16),

                // ── Vitamins (expandable) ──
                _expandableSection(
                  title: 'Vitamins',
                  expanded: _showVitamins,
                  onToggle: () => setSheetState(() => _showVitamins = !_showVitamins),
                  child: Column(
                    children: [
                      _buildEditField(controller: _vitaminAController, label: 'Vitamin A (mcg)', icon: Icons.circle, keyboardType: TextInputType.number),
                      const SizedBox(height: 8),
                      _buildEditField(controller: _vitaminBController, label: 'Vitamin B (mg)', icon: Icons.circle, keyboardType: TextInputType.number),
                      const SizedBox(height: 8),
                      _buildEditField(controller: _vitaminCController, label: 'Vitamin C (mg)', icon: Icons.circle, keyboardType: TextInputType.number),
                      const SizedBox(height: 8),
                      _buildEditField(controller: _vitaminDController, label: 'Vitamin D (mcg)', icon: Icons.circle, keyboardType: TextInputType.number),
                      const SizedBox(height: 8),
                      _buildEditField(controller: _vitaminEController, label: 'Vitamin E (mg)', icon: Icons.circle, keyboardType: TextInputType.number),
                      const SizedBox(height: 8),
                      _buildEditField(controller: _vitaminKController, label: 'Vitamin K (mcg)', icon: Icons.circle, keyboardType: TextInputType.number),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Minerals (expandable) ──
                _expandableSection(
                  title: 'Minerals',
                  expanded: _showMinerals,
                  onToggle: () => setSheetState(() => _showMinerals = !_showMinerals),
                  child: Column(
                    children: [
                      _buildEditField(controller: _calciumController, label: 'Calcium (mg)', icon: Icons.circle, keyboardType: TextInputType.number),
                      const SizedBox(height: 8),
                      _buildEditField(controller: _ironController, label: 'Iron (mg)', icon: Icons.circle, keyboardType: TextInputType.number),
                      const SizedBox(height: 8),
                      _buildEditField(controller: _magnesiumController, label: 'Magnesium (mg)', icon: Icons.circle, keyboardType: TextInputType.number),
                      const SizedBox(height: 8),
                      _buildEditField(controller: _potassiumController, label: 'Potassium (mg)', icon: Icons.circle, keyboardType: TextInputType.number),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Save button ──
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _saveMeal();
                    },
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Save Meal'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
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
            Padding(padding: const EdgeInsets.all(12), child: child),
          ],
        ],
      ),
    );
  }

  Widget _buildEditField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        prefixIcon: Icon(icon, size: 20),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nutrition = context.watch<NutritionProvider>();
    final isAnalyzing = nutrition.isAnalyzing;
    final error = nutrition.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Meal'),
        centerTitle: true,
        actions: [
          if (_imageBytes != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset',
              onPressed: () {
                setState(() {
                  _imageBytes = null;
                  _detectedFood = null;
                  _state = _CaptureState.capture;
                });
                nutrition.clearDetectedFood();
                nutrition.clearError();
              },
            ),
        ],
      ),
      body: _isUploading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    if (isAnalyzing)
                      _buildAnalyzingView()
                    else if (error != null)
                      _buildErrorView(error)
                    else ...[
                      if (_state == _CaptureState.capture)
                        _buildCaptureView(),
                      if (_state == _CaptureState.result)
                        _buildResultView(),
                      if (_state == _CaptureState.edit)
                        _buildEditView(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

 // ─── Beautiful Capture View ────────────────────────────────────
Widget _buildCaptureView() {
  return Column(
    children: [
      const SizedBox(height: 12),
      Stack(
        children: [
          // Decorative blurred circle
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    blurRadius: 60,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          // Main card
          Container(
            height: 340,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.95),
                  Colors.grey.shade50.withValues(alpha: 0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated camera icon
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 1.0, end: 1.05),
                    duration: const Duration(milliseconds: 1500),
                    curve: Curves.easeInOut,
                    builder: (context, scale, _) => Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor.withValues(alpha: 0.12),
                              AppTheme.primaryColor.withValues(alpha: 0.04),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset(
                          'lib/assets/diet/camera.png',
                          width: 48,
                          height: 48,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.camera_alt_rounded,
                            size: 44,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Take photo of your meal',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Position your plate in the frame',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary.withValues(alpha: 0.7),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildPillButton(
                        label: 'Camera',
                        onTap: _takePhoto,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                        ),
                        icon: Icons.camera_alt_rounded,
                      ),
                      const SizedBox(width: 14),
                      _buildPillButton(
                        label: 'Gallery',
                        onTap: _pickFromGallery,
                        gradient: LinearGradient(
                          colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                        ),
                        icon: Icons.photo_library_rounded,
                        iconColor: const Color(0xFF92400E),
                        textColor: const Color(0xFF92400E),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 28),
      // Optional: alternative options (if you have _buildAlternativeOptions())
      _buildAlternativeOptions(),
    ],
  );
}

  Widget _buildPillButton({
    required String label,
    required VoidCallback onTap,
    required Gradient gradient,
    required IconData icon,
    Color iconColor = Colors.white,
    Color textColor = Colors.white,
  }) {
    return Material(
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: 150,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlternativeOptions() {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Divider(thickness: 1, color: Color(0xFFE8ECF4)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'or',
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.4),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Expanded(
              child: Divider(thickness: 1, color: Color(0xFFE8ECF4)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.06),
                  AppTheme.primaryColor.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () =>
                    Navigator.pushNamed(context, '/food-search', arguments: 'lunch'),
                borderRadius: BorderRadius.circular(30),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_rounded, size: 22, color: AppTheme.primaryColor),
                      SizedBox(width: 10),
                      Text(
                        'Search food database',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Result View ─────────────────────────────────────────────────
  Widget _buildResultView() {
    final food = _detectedFood;
    if (food == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        if (_imageBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Image.memory(
                  _imageBytes!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${(food.confidence * 100).toStringAsFixed(0)}% match',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Image.asset(
                      'lib/assets/diet/${_selectedMealType}.png',
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        _mealTypeIcon(_selectedMealType),
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          food.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedMealType[0].toUpperCase() +
                              _selectedMealType.substring(1),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.successColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'AI Detected',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.successColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_fire_department,
                      color: AppTheme.warningColor, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    '${food.totalCalories.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'kcal',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildMacroBar(
                label: 'Protein',
                value: food.totalProtein,
                unit: 'g',
                color: AppTheme.accentColor,
                icon: Icons.fitness_center,
              ),
              const SizedBox(height: 12),
              _buildMacroBar(
                label: 'Carbs',
                value: food.totalCarbs,
                unit: 'g',
                color: AppTheme.successColor,
                icon: Icons.grain,
              ),
              const SizedBox(height: 12),
              _buildMacroBar(
                label: 'Fat',
                value: food.totalFat,
                unit: 'g',
                color: AppTheme.secondaryColor,
                icon: Icons.opacity,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() => _state = _CaptureState.edit);
                  _openEditSheet();
                },
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Edit Details'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _saveMeal,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add Meal'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildMacroBar({
    required String label,
    required double value,
    required String unit,
    required Color color,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        SizedBox(
          width: 55,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (value / 50).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 48,
          child: Text(
            '${value.toStringAsFixed(1)}$unit',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // ── Edit View ──────────────────────────────────────────────────
  Widget _buildEditView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        if (_imageBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.memory(
              _imageBytes!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        const SizedBox(height: 20),
        Text(
          'Enter Meal Details',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 16),

        // ── Food name ──
        _buildEditField(controller: _nameController, label: 'Food Name', icon: Icons.restaurant, required: true),
        const SizedBox(height: 12),

        // ── Meal type dropdown ──
        DropdownButtonFormField<String>(
          initialValue: _selectedMealType,
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
          onChanged: (v) => setState(() => _selectedMealType = v ?? _selectedMealType),
        ),
        const SizedBox(height: 12),

        // ── Serving amount ──
        _buildEditField(
          controller: _servingAmountController,
          label: 'Serving Amount (e.g. 1, 100, 0.5)',
          icon: Icons.straighten,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),

        // ── Serving unit dropdown ──
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
        const Divider(),
        const SizedBox(height: 8),

        // ── Macros (single row each) ──
        Text('Macros', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 10),
        _buildEditField(controller: _caloriesController, label: 'Calories (kcal)', icon: Icons.local_fire_department, keyboardType: TextInputType.number, required: true),
        const SizedBox(height: 8),
        _buildEditField(controller: _proteinController, label: 'Protein (g)', icon: Icons.fitness_center, keyboardType: TextInputType.number),
        const SizedBox(height: 8),
        _buildEditField(controller: _carbsController, label: 'Carbs (g)', icon: Icons.grain, keyboardType: TextInputType.number),
        const SizedBox(height: 8),
        _buildEditField(controller: _fatController, label: 'Fat (g)', icon: Icons.water_drop, keyboardType: TextInputType.number),
        const SizedBox(height: 8),
        _buildEditField(controller: _fiberController, label: 'Fiber (g)', icon: Icons.eco, keyboardType: TextInputType.number),
        const SizedBox(height: 8),
        _buildEditField(controller: _sugarController, label: 'Sugar (g)', icon: Icons.cookie, keyboardType: TextInputType.number),
        const SizedBox(height: 8),
        _buildEditField(controller: _sodiumController, label: 'Sodium (mg)', icon: Icons.science, keyboardType: TextInputType.number),
        const SizedBox(height: 16),

        // ── Vitamins (expandable) ──
        _expandableSection(
          title: 'Vitamins',
          expanded: _showVitamins,
          onToggle: () => setState(() => _showVitamins = !_showVitamins),
          child: Column(
            children: [
              _buildEditField(controller: _vitaminAController, label: 'Vitamin A (mcg)', icon: Icons.circle, keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              _buildEditField(controller: _vitaminBController, label: 'Vitamin B (mg)', icon: Icons.circle, keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              _buildEditField(controller: _vitaminCController, label: 'Vitamin C (mg)', icon: Icons.circle, keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              _buildEditField(controller: _vitaminDController, label: 'Vitamin D (mcg)', icon: Icons.circle, keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              _buildEditField(controller: _vitaminEController, label: 'Vitamin E (mg)', icon: Icons.circle, keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              _buildEditField(controller: _vitaminKController, label: 'Vitamin K (mcg)', icon: Icons.circle, keyboardType: TextInputType.number),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Minerals (expandable) ──
        _expandableSection(
          title: 'Minerals',
          expanded: _showMinerals,
          onToggle: () => setState(() => _showMinerals = !_showMinerals),
          child: Column(
            children: [
              _buildEditField(controller: _calciumController, label: 'Calcium (mg)', icon: Icons.circle, keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              _buildEditField(controller: _ironController, label: 'Iron (mg)', icon: Icons.circle, keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              _buildEditField(controller: _magnesiumController, label: 'Magnesium (mg)', icon: Icons.circle, keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              _buildEditField(controller: _potassiumController, label: 'Potassium (mg)', icon: Icons.circle, keyboardType: TextInputType.number),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // ── Save button ──
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saveMeal,
            icon: const Icon(Icons.check_circle),
            label: const Text('Save Meal'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Analyzing View ────────────────────────────────────────────
  Widget _buildAnalyzingView() {
    return Container(
      height: 400,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_imageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.memory(
                _imageBytes!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 32),
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'AI is analyzing your meal',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Identifying food and calculating nutrition...',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  // ── Error View ──────────────────────────────────────────────────
  Widget _buildErrorView(String error) {
    return Column(
      children: [
        const SizedBox(height: 12),
        if (_imageBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.memory(
              _imageBytes!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.errorColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.errorColor.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: AppTheme.errorColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detection failed',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.errorColor,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      error,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _openEditSheet(),
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Enter Details Manually'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _imageBytes = null;
                _state = _CaptureState.capture;
              });
              context.read<NutritionProvider>().clearError();
            },
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Try Again'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _mealTypeIcon(String type) {
    switch (type) {
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

// ─── Frame Painter (Enhanced) ───────────────────────────────────
class _FramePainter extends CustomPainter {
  final Color color;
  final Color glowColor;

  _FramePainter({required this.color, this.glowColor = Colors.transparent});

  @override
  void paint(Canvas canvas, Size size) {
    // Glow
    if (glowColor != Colors.transparent) {
      final glowPaint = Paint()
        ..color = glowColor
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(20),
        ),
        glowPaint,
      );
    }

    // Main frame
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final cornerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    const cornerLen = 28.0;
    const gap = 0.0;

    // Rounded rect frame
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(gap, gap, size.width - gap * 2, size.height - gap * 2),
      const Radius.circular(20),
    );
    canvas.drawRRect(rect, paint);

    // Corner accents
    final corners = [
      Offset(gap, gap),
      Offset(size.width - gap, gap),
      Offset(gap, size.height - gap),
      Offset(size.width - gap, size.height - gap),
    ];

    for (final corner in corners) {
      final isTop = corner.dy == gap;
      final isLeft = corner.dx == gap;
      final isRight = corner.dx == size.width - gap;
      final isBottom = corner.dy == size.height - gap;

      // Horizontal line
      final hStart = isLeft ? corner.dx : corner.dx - cornerLen;
      final hEnd = isLeft ? corner.dx + cornerLen : corner.dx;
      canvas.drawLine(Offset(hStart, corner.dy), Offset(hEnd, corner.dy), cornerPaint);

      // Vertical line
      final vStart = isTop ? corner.dy : corner.dy - cornerLen;
      final vEnd = isTop ? corner.dy + cornerLen : corner.dy;
      canvas.drawLine(Offset(corner.dx, vStart), Offset(corner.dx, vEnd), cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}