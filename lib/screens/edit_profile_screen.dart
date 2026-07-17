import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/nutrition_provider.dart';
import '../models/user_model.dart';
import '../config/theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _ageController;
  late TextEditingController _goalWeightController;

  String _workoutGoal = 'general_fitness';
  String _activityLevel = 'moderate';
  String _gender = 'male';
  String _dietPreference = 'none';
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  File? _pickedImage;
  String? _photoUrl;

  final List<Map<String, String>> _workoutGoals = [
    {'value': 'general_fitness', 'label': 'Build Confidence'},
    {'value': 'lose_weight', 'label': 'Lose Weight'},
    {'value': 'build_muscle', 'label': 'Build Muscle'},
    {'value': 'endurance', 'label': 'Increase Endurance'},
    {'value': 'strength', 'label': 'Get Stronger'},
  ];

  final List<Map<String, String>> _activityLevels = [
    {'value': 'sedentary', 'label': 'Little or no exercise'},
    {'value': 'light', 'label': 'Light exercise 1-3 days/week'},
    {'value': 'moderate', 'label': 'Moderate exercise 3-5 days/week'},
    {'value': 'very_active', 'label': 'Hard exercise 6-7 days/week'},
    {'value': 'extremely_active', 'label': 'Very hard exercise / athlete'},
  ];

  final List<Map<String, String>> _genders = [
    {'value': 'male', 'label': 'Male'},
    {'value': 'female', 'label': 'Female'},
  ];

  final List<Map<String, String>> _dietPreferences = [
    {'value': 'none', 'label': 'No specific diet'},
    {'value': 'vegetarian', 'label': 'Vegetarian'},
    {'value': 'vegan', 'label': 'Vegan'},
    {'value': 'keto', 'label': 'Keto'},
    {'value': 'paleo', 'label': 'Paleo'},
    {'value': 'mediterranean', 'label': 'Mediterranean'},
    {'value': 'halal', 'label': 'Halal'},
    {'value': 'gluten_free', 'label': 'Gluten-free'},
    {'value': 'low_carb', 'label': 'Low-carb'},
  ];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _weightController = TextEditingController(
      text: user?.weight.toString() ?? '65',
    );
    _heightController = TextEditingController(
      text: user?.height.toString() ?? '170',
    );
    _ageController = TextEditingController(text: user?.age.toString() ?? '25');
    _goalWeightController = TextEditingController(
      text: user?.targetWeightKg?.toString() ?? '',
    );
    _workoutGoal = user?.workoutGoal ?? user?.fitnessGoal ?? 'general_fitness';
    _activityLevel = user?.activityLevel ?? 'moderate';
    _gender = user?.gender ?? 'male';
    _dietPreference = user?.dietPreference ?? 'none';
    _photoUrl = user?.photoUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    _goalWeightController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('You have unsaved changes. Discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result == 'discard';
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;

    setState(() => _isSaving = true);

    try {
      final uploadedUrl = await _uploadAvatar(auth.user!.uid);

      final updatedUser = auth.user!.copyWith(
        displayName: _nameController.text.trim(),
        weight: double.tryParse(_weightController.text) ?? auth.user!.weight,
        height: double.tryParse(_heightController.text) ?? auth.user!.height,
        age: int.tryParse(_ageController.text) ?? auth.user!.age,
        fitnessGoal: _workoutGoal,
        workoutGoal: _workoutGoal,
        activityLevel: _activityLevel,
        gender: _gender,
        dietPreference: _dietPreference,
        targetWeightKg: _goalWeightController.text.isNotEmpty
            ? double.tryParse(_goalWeightController.text.trim())
            : null,
        photoUrl: uploadedUrl,
      );

      await auth.updateProfile(updatedUser);

      final nutrition = context.read<NutritionProvider>();
      await nutrition.calculateAndSetTDEE(
        user: updatedUser,
        activityLevel: _activityLevel,
        onSave: (goal) async {
          final saved = updatedUser.copyWith(dailyCalorieTarget: goal);
          await auth.updateProfile(saved);
        },
      );

      if (!mounted) return;
      setState(() {
        _hasUnsavedChanges = false;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    }
  }

  void _markChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Change Profile Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppTheme.primaryColor),
                title: const Text('Take Photo'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppTheme.primaryColor),
                title: const Text('Choose from Gallery'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              if (_photoUrl != null || _pickedImage != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: AppTheme.errorColor),
                  title: const Text('Remove Photo'),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _pickedImage = null;
                      _photoUrl = null;
                      _hasUnsavedChanges = true;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 512, maxHeight: 512, imageQuality: 80);
    if (picked == null) return;

    setState(() {
      _pickedImage = File(picked.path);
      _hasUnsavedChanges = true;
    });
  }

  Future<String?> _uploadAvatar(String uid) async {
    if (_pickedImage == null) return _photoUrl;

    setState(() => _isUploadingPhoto = true);

    try {
      final ref = FirebaseStorage.instance.ref().child('avatars/$uid/avatar.jpg');
      await ref.putFile(_pickedImage!, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload photo: $e')),
        );
      }
      return _photoUrl;
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Profile'),
          actions: [
            TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          onChanged: _markChanged,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildAvatarSection(user),
              const SizedBox(height: 24),
              _buildSectionTitle('Personal Information'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person_outline,
                validator: (v) =>
                    v?.trim().isEmpty ?? true ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _ageController,
                      label: 'Age',
                      icon: Icons.cake_outlined,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v?.isEmpty ?? true) return 'Required';
                        final age = int.tryParse(v!);
                        if (age == null || age < 10 || age > 100) {
                          return '10-100';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown<String>(
                      value: _gender,
                      label: 'Gender',
                      icon: Icons.person_outline,
                      items: _genders,
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _gender = v);
                          _markChanged();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Body Measurements'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _weightController,
                      label: 'Weight (kg)',
                      icon: Icons.monitor_weight_outlined,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v?.isEmpty ?? true) return 'Required';
                        final w = double.tryParse(v!);
                        if (w == null || w < 20 || w > 300) return '20-300';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _heightController,
                      label: 'Height (cm)',
                      icon: Icons.height,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v?.isEmpty ?? true) return 'Required';
                        final h = double.tryParse(v!);
                        if (h == null || h < 50 || h > 250) return '50-250';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _goalWeightController,
                label: 'Target Weight (kg)',
                icon: Icons.track_changes_outlined,
                keyboardType: TextInputType.number,
                hint: 'Optional',
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Fitness Settings'),
              const SizedBox(height: 12),
              _buildDropdown<String>(
                value: _workoutGoal,
                label: 'Workout Goal',
                icon: Icons.flag_outlined,
                items: _workoutGoals,
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _workoutGoal = v);
                    _markChanged();
                  }
                },
              ),
              const SizedBox(height: 16),
              _buildDropdown<String>(
                value: _activityLevel,
                label: 'Activity Level',
                icon: Icons.directions_run,
                items: _activityLevels,
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _activityLevel = v);
                    _markChanged();
                  }
                },
              ),
              const SizedBox(height: 16),
              _buildDropdown<String>(
                value: _dietPreference,
                label: 'Diet Preference',
                icon: Icons.restaurant_menu_outlined,
                items: _dietPreferences,
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _dietPreference = v);
                    _markChanged();
                  }
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveProfile,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? 'Saving...' : 'Save Profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(dynamic user) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _isUploadingPhoto ? null : _pickImage,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                  backgroundImage: _pickedImage != null
                      ? FileImage(_pickedImage!)
                      : (_photoUrl != null && _photoUrl!.isNotEmpty)
                          ? NetworkImage(_photoUrl!)
                          : null,
                  child: (_pickedImage == null &&
                          (_photoUrl == null || _photoUrl!.isEmpty))
                      ? Icon(
                          Icons.person,
                          size: 48,
                          color: AppTheme.primaryColor,
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: _isUploadingPhoto
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user?.displayName ?? 'User',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            user?.email ?? '',
            style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap photo to change',
            style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            title.contains('Personal')
                ? Icons.person_outline
                : title.contains('Body')
                    ? Icons.monitor_weight_outlined
                    : Icons.fitness_center,
            size: 16,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required String label,
    required IconData icon,
    required List<Map<String, String>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      items: items
          .map((item) => DropdownMenuItem<T>(
                value: item['value'] as T,
                child: Text(item['label']!),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}
