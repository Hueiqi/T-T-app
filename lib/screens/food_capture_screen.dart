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
  final _servingController = TextEditingController();
  final _vitaminsController = TextEditingController();
  final _mineralsController = TextEditingController();
  final _waterController = TextEditingController();
  final _fiberController = TextEditingController();

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
    _servingController.dispose();
    _vitaminsController.dispose();
    _mineralsController.dispose();
    _waterController.dispose();
    _fiberController.dispose();
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

    // Show loading overlay
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

    final water = double.tryParse(_waterController.text.trim()) ?? 0;
    final fiber = double.tryParse(_fiberController.text.trim()) ?? 0;

    await nutrition.saveMeal(
      userId: auth.user!.uid,
      mealType: _selectedMealType,
      foodName: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      water: water,
      fiber: fiber,
      dateTime: _selectedDate,
      imageUrl: imageUrl,
    );

    if (mounted) {
      setState(() => _isUploading = false);
      Navigator.pop(context, true);
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
        _servingController.text = '${detected.servingSizeGrams.toInt()}g';
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
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
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
              Row(
                children: [
                  Icon(Icons.edit_note, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Edit Meal Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildEditField(
                controller: _nameController,
                label: 'Food Name',
                icon: Icons.restaurant,
                required: true,
              ),
              const SizedBox(height: 12),
              _buildEditField(
                controller: _caloriesController,
                label: 'Calories (kcal)',
                icon: Icons.local_fire_department,
                keyboardType: TextInputType.number,
                required: true,
              ),
              const SizedBox(height: 12),
              _buildEditField(
                controller: _servingController,
                label: 'Serving Size',
                icon: Icons.scale,
              ),
              const SizedBox(height: 16),
              Text(
                'Meal Type',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: ['breakfast', 'lunch', 'dinner', 'snack']
                    .map((type) => ChoiceChip(
                          label: Text(type[0].toUpperCase() + type.substring(1)),
                          selected: _selectedMealType == type,
                          selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                          onSelected: (_) =>
                              setState(() => _selectedMealType = type),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Macronutrients (g)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildEditField(
                      controller: _proteinController,
                      label: 'Protein',
                      icon: Icons.fitness_center,
                      keyboardType: TextInputType.number,
                      small: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildEditField(
                      controller: _carbsController,
                      label: 'Carbs',
                      icon: Icons.grain,
                      keyboardType: TextInputType.number,
                      small: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildEditField(
                      controller: _fatController,
                      label: 'Fat',
                      icon: Icons.opacity,
                      keyboardType: TextInputType.number,
                      small: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Additional Nutrients',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildEditField(
                      controller: _vitaminsController,
                      label: 'Vitamins (mg)',
                      icon: Icons.spa,
                      keyboardType: TextInputType.number,
                      small: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildEditField(
                      controller: _mineralsController,
                      label: 'Minerals (mg)',
                      icon: Icons.blur_on,
                      keyboardType: TextInputType.number,
                      small: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildEditField(
                      controller: _fiberController,
                      label: 'Fiber (g)',
                      icon: Icons.linear_scale,
                      keyboardType: TextInputType.number,
                      small: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildEditField(
                      controller: _waterController,
                      label: 'Water (ml)',
                      icon: Icons.water_drop,
                      keyboardType: TextInputType.number,
                      small: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    bool small = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        prefixIcon: Icon(icon, size: small ? 18 : 20),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: small ? 12 : 14,
        ),
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
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Glowing frame
                  CustomPaint(
                    size: const Size(260, 260),
                    painter: _FramePainter(
                      color: AppTheme.primaryColor,
                      glowColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                    ),
                  ),
                  // Content
                  Column(
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
                            child: Icon(
                              Icons.camera_alt_rounded,
                              size: 44,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Take a photo of your meal',
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
                          _buildActionChip(
                            icon: Icons.camera_alt_rounded,
                            label: 'Camera',
                            onTap: _takePhoto,
                            filled: true,
                          ),
                          const SizedBox(width: 14),
                          _buildActionChip(
                            icon: Icons.photo_library_rounded,
                            label: 'Gallery',
                            onTap: _pickFromGallery,
                            filled: false,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _buildAlternativeOptions(),
      ],
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool filled,
  }) {
    return Material(
      elevation: filled ? 4 : 0,
      shadowColor: filled ? AppTheme.primaryColor.withValues(alpha: 0.3) : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: filled
                ? AppTheme.primaryColor
                : AppTheme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: filled
                ? null
                : Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: filled ? Colors.white : AppTheme.primaryColor,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: filled ? Colors.white : AppTheme.primaryColor,
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
          child: OutlinedButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, '/food-search', arguments: 'lunch'),
            icon: const Icon(Icons.search_rounded, size: 22),
            label: const Text(
              'Search food database',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              side: BorderSide(color: Colors.grey.shade300),
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
              flex: 2,
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
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        _buildEditField(
          controller: _nameController,
          label: 'Food Name',
          icon: Icons.restaurant,
          required: true,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildEditField(
                controller: _caloriesController,
                label: 'Calories (kcal)',
                icon: Icons.local_fire_department,
                keyboardType: TextInputType.number,
                required: true,
                small: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildEditField(
                controller: _servingController,
                label: 'Serving Size',
                icon: Icons.scale,
                small: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Meal Type',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: ['breakfast', 'lunch', 'dinner', 'snack']
              .map((type) => ChoiceChip(
                    label: Text(type[0].toUpperCase() + type.substring(1)),
                    selected: _selectedMealType == type,
                    selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                    onSelected: (_) =>
                        setState(() => _selectedMealType = type),
                  ))
              .toList(),
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          'Macronutrients (g)',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildEditField(
                controller: _proteinController,
                label: 'Protein',
                icon: Icons.fitness_center,
                keyboardType: TextInputType.number,
                small: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildEditField(
                controller: _carbsController,
                label: 'Carbs',
                icon: Icons.grain,
                keyboardType: TextInputType.number,
                small: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildEditField(
                controller: _fatController,
                label: 'Fat',
                icon: Icons.opacity,
                keyboardType: TextInputType.number,
                small: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          'Additional Nutrients',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildEditField(
                controller: _vitaminsController,
                label: 'Vitamins (mg)',
                icon: Icons.spa,
                keyboardType: TextInputType.number,
                small: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildEditField(
                controller: _mineralsController,
                label: 'Minerals (mg)',
                icon: Icons.blur_on,
                keyboardType: TextInputType.number,
                small: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildEditField(
                controller: _fiberController,
                label: 'Fiber (g)',
                icon: Icons.linear_scale,
                keyboardType: TextInputType.number,
                small: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildEditField(
                controller: _waterController,
                label: 'Water (ml)',
                icon: Icons.water_drop,
                keyboardType: TextInputType.number,
                small: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saveMeal,
            icon: const Icon(Icons.check_circle),
            label: const Text('Save Meal'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
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