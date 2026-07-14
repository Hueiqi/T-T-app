import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/music_provider.dart';
import '../providers/health_provider.dart';
import '../providers/nutrition_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/sleep_provider.dart';
import '../providers/notification_provider.dart';
import '../widgets/bottom_nav_shell.dart';
import '../providers/planning_provider.dart';
import '../services/bluetooth_service.dart';
import '../services/tdee_calculator.dart';
import '../config/theme.dart';
import '../config/routes.dart';
import '../models/user_model.dart';
import '../models/workout_model.dart';
import 'nutrition_reports_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool showBottomNav;

  const ProfileScreen({super.key, this.showBottomNav = true});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _ageController;
  late TextEditingController _goalWeightController;

  String _workoutGoal = 'general_fitness';
  String _activityLevel = 'moderate';
  bool _hasUnsavedChanges = false;
  bool _isEditing = false;

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
    _activityLevel = context.read<NutritionProvider>().activityLevel;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboard());
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

  Future<void> _loadDashboard() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    context.read<SleepProvider>().loadSleepData(auth.user!.uid);
    context.read<NutritionProvider>().loadTodayMeals(auth.user!.uid);
    context.read<WorkoutProvider>().loadDashboardData(auth.user!.uid);
    context.read<PlanningProvider>().loadBookmarks(auth.user!.uid);
  }

  Future<void> _saveProfile() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    final updatedUser = auth.user!.copyWith(
      displayName: _nameController.text,
      weight: double.tryParse(_weightController.text) ?? auth.user!.weight,
      height: double.tryParse(_heightController.text) ?? auth.user!.height,
      age: int.tryParse(_ageController.text) ?? auth.user!.age,
      fitnessGoal: _workoutGoal,
      workoutGoal: _workoutGoal,
      activityLevel: _activityLevel,
      targetWeightKg: _goalWeightController.text.isNotEmpty
          ? double.tryParse(_goalWeightController.text.trim())
          : null,
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
      _isEditing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated')),
    );
  }

  Future<void> _connectSpotify() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    final music = context.read<MusicProvider>();
    final success = await music.connect();
    if (success && mounted) {
      await _onSpotifyConnected();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spotify connection failed')),
      );
    }
  }

  Future<void> _onSpotifyConnected() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    final updatedUser = auth.user!.copyWith(spotifyConnected: 'connected');
    await auth.updateProfile(updatedUser);
  }

  Future<void> _disconnectSpotify() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    final music = context.read<MusicProvider>();
    await music.disconnect();
    if (!mounted) return;
    final updatedUser = auth.user!.copyWith(spotifyConnected: 'disconnected');
    await auth.updateProfile(updatedUser);
  }

  Future<void> _toggleSmartwatch(BuildContext context) async {
    final health = context.read<HealthProvider>();
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;

    if (health.smartwatchConnected) {
      health.disconnectSmartwatch();
      final updatedUser = auth.user!.copyWith(smartwatchConnected: 'disconnected');
      await auth.updateProfile(updatedUser);
    } else {
      _showBleScannerSheet(context);
    }
  }

  void _showBleScannerSheet(BuildContext context) {
    final health = context.read<HealthProvider>();
    health.startScan();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _BleDeviceScannerSheet(
        onDeviceSelected: (deviceId) async {
          Navigator.pop(ctx);
          final auth = context.read<AuthProvider>();
          final health = context.read<HealthProvider>();
          final success = await health.connectToDevice(deviceId);
          if (success && mounted) {
            final updatedUser = auth.user!.copyWith(smartwatchConnected: 'connected');
            await auth.updateProfile(updatedUser);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Connected to ${health.connectedDeviceName ?? "Smartwatch"}'),
              ),
            );
          } else if (mounted) {
            _tryHealthConnect(context);
          }
        },
        onUseHealthConnect: () {
          Navigator.pop(ctx);
          _tryHealthConnect(context);
        },
      ),
    ).then((_) {
      if (health.isScanning) health.stopScan();
    });
  }

  Future<void> _tryHealthConnect(BuildContext context) async {
    final health = context.read<HealthProvider>();
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;

    final success = await health.connectSmartwatch();
    if (success && mounted) {
      final updatedUser = auth.user!.copyWith(smartwatchConnected: 'connected');
      await auth.updateProfile(updatedUser);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connected via Health Connect')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(health.error ?? 'Smartwatch connection failed')),
      );
    }
  }

  Future<void> _toggleSpotify() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    if (auth.user!.spotifyConnected == 'connected') {
      await _disconnectSpotify();
    } else {
      await _connectSpotify();
    }
  }

  double _calculateBmr(AppUser user) {
    if (user.weight <= 0 || user.height <= 0 || user.age <= 0) return 0;
    return TDEECalculator.calculateBMR(
      age: user.age,
      weight: user.weight,
      height: user.height,
      isMale: user.gender.toLowerCase() == 'male',
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final sleep = context.watch<SleepProvider>();
    final nutrition = context.watch<NutritionProvider>();
    final workout = context.watch<WorkoutProvider>();

    return Scaffold(
      appBar: null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboard,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildProfileHeader(user),
                const SizedBox(height: 16),
                _buildQuickActions(),
                const SizedBox(height: 20),
                if (_isEditing) _buildEditForm(),
                if (!_isEditing) _buildViewSections(user, sleep, nutrition, workout),
                if (!_isEditing) _buildSignOutButton(auth),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: widget.showBottomNav ? buildBottomNavBar(context) : null,
    );
  }

  Widget _buildProfileHeader(dynamic user) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
              child: Icon(
                Icons.person,
                size: 50,
                color: AppTheme.primaryColor,
              ),
            ),
            Positioned(
              bottom: -4,
              right: -4,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isEditing = !_isEditing;
                    if (!_isEditing && _hasUnsavedChanges) {
                      _showDiscardDialog();
                    }
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primaryColor,
                    child: Icon(
                      _isEditing ? Icons.close : Icons.edit,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            if (!_isEditing) {
              setState(() => _isEditing = true);
            }
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  user?.displayName ?? 'User',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                _isEditing ? Icons.edit_off : Icons.edit,
                size: 20,
                color: AppTheme.primaryColor,
              ),
            ],
          ),
        ),
        Text(
          user?.email ?? '',
          style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _QuickActionItem(Icons.restaurant, 'Log Meal', () => Navigator.pushNamed(context, AppRoutes.foodCapture), const Color(0xFF059669)),
      _QuickActionItem(Icons.fitness_center, 'Workout', () => Navigator.pushNamed(context, AppRoutes.activity), AppTheme.primaryColor),
      _QuickActionItem(Icons.bar_chart, 'Statistics', () => Navigator.pushNamed(context, AppRoutes.statistics), const Color(0xFF7C3AED)),
      _QuickActionItem(Icons.notifications, 'Alerts', () => Navigator.pushNamed(context, AppRoutes.notificationSettings), const Color(0xFFF59E0B)),
    ];

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final a = actions[i];
          return InkWell(
            onTap: a.onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 80,
              decoration: BoxDecoration(
                color: a.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: a.color.withValues(alpha: 0.15)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(a.icon, color: a.color, size: 22),
                  const SizedBox(height: 4),
                  Text(a.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: a.color)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEditForm() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _sectionHeader(Icons.edit, 'Edit Profile'),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person)),
              onChanged: (_) => _hasUnsavedChanges = true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Age', prefixIcon: Icon(Icons.cake)),
                    onChanged: (_) => _hasUnsavedChanges = true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Weight (kg)', prefixIcon: Icon(Icons.monitor_weight)),
                    onChanged: (_) => _hasUnsavedChanges = true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _heightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Height (cm)', prefixIcon: Icon(Icons.height)),
              onChanged: (_) => _hasUnsavedChanges = true,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _workoutGoal,
              decoration: const InputDecoration(labelText: 'Workout Goal', prefixIcon: Icon(Icons.flag_outlined)),
              items: _workoutGoals.map((g) => DropdownMenuItem(value: g['value'], child: Text(g['label']!))).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _workoutGoal = v);
                  _hasUnsavedChanges = true;
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _activityLevel,
              decoration: const InputDecoration(labelText: 'Activity Level', prefixIcon: Icon(Icons.directions_run)),
              items: _activityLevels.map((a) => DropdownMenuItem(value: a['value'], child: Text(a['label']!))).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _activityLevel = v);
                  _hasUnsavedChanges = true;
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _goalWeightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target Weight (kg)', hintText: 'e.g. 70', prefixIcon: Icon(Icons.track_changes)),
              onChanged: (_) => _hasUnsavedChanges = true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      if (_hasUnsavedChanges) {
                        _showDiscardDialog();
                      } else {
                        setState(() => _isEditing = false);
                      }
                    },
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _hasUnsavedChanges ? _saveProfile : null,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Profile'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('You have unsaved changes. Discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _isEditing = false;
                _hasUnsavedChanges = false;
                final user = context.read<AuthProvider>().user;
                if (user != null) {
                  _nameController.text = user.displayName ?? '';
                  _weightController.text = user.weight.toString();
                  _heightController.text = user.height.toString();
                  _ageController.text = user.age.toString();
                  _goalWeightController.text = user.targetWeightKg?.toString() ?? '';
                  _workoutGoal = user.fitnessGoal ?? 'general_fitness';
                  _activityLevel = context.read<NutritionProvider>().activityLevel;
                }
              });
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  Widget _buildViewSections(dynamic user, dynamic sleep, dynamic nutrition, dynamic workout) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.timeline, 'Recent Activity'),
        const SizedBox(height: 8),
        _buildSleepCard(sleep),
        const SizedBox(height: 12),
        _buildWorkoutCard(workout.recentWorkout),
        const SizedBox(height: 12),
        _buildCalorieBalanceCard(nutrition, workout, user),
        const SizedBox(height: 20),
        _sectionHeader(Icons.assessment, 'Reports'),
        const SizedBox(height: 8),
        _buildReportsTile(),
        const SizedBox(height: 20),
        _sectionHeader(Icons.link, 'Connections & Settings'),
        const SizedBox(height: 8),
        _buildConnectionsSettings(user, workout),
      ],
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600, color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  // ── Sleep Card ──
  Widget _buildSleepCard(dynamic sleep) {
    if (sleep.lastNightSleep == null) {
      return _buildPlaceholderCard(Icons.bedtime, 'Sleep', 'No sleep data yet');
    }

    final hours = sleep.lastNightSleep!.hoursSlept;
    final deepMin = sleep.lastNightSleep!.deepSleepMinutes;
    final targetHours = 8.0;
    final sleepProgress = (hours / targetHours).clamp(0.0, 1.0);

    final readinessScore = hours >= 7 ? 5 : hours >= 5 ? 3 : 1;
    final Color scoreColor = readinessScore >= 5
        ? AppTheme.successColor
        : readinessScore >= 3
            ? AppTheme.warningColor
            : AppTheme.errorColor;
    final String readinessEmoji = readinessScore >= 5 ? '🟢' : readinessScore >= 3 ? '🟡' : '🔴';
    final deepPercent = hours > 0 ? (deepMin / (hours * 60) * 100) : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, AppRoutes.sleep),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.bedtime, size: 18, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(width: 10),
                  const Text('Sleep', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$readinessEmoji $readinessScore/5',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scoreColor),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 18),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  SizedBox(
                    width: 64, height: 64,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 64, height: 64,
                          child: CircularProgressIndicator(
                            value: sleepProgress,
                            strokeWidth: 5,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${hours.toStringAsFixed(1)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: scoreColor)),
                            Text('hrs', style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.nightlight_round, size: 14, color: AppTheme.primaryColor.withValues(alpha: 0.7)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: deepPercent / 100,
                                  minHeight: 6,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 32,
                              child: Text('${deepPercent.toStringAsFixed(0)}%',
                                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.bed, size: 14, color: AppTheme.successColor.withValues(alpha: 0.7)),
                            const SizedBox(width: 6),
                            Expanded(child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: ((hours * 60 - deepMin) / (hours * 60)).clamp(0, 1),
                                minHeight: 6,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.successColor),
                              ),
                            )),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 32,
                              child: Text('${(hours * 60 - deepMin).round()}m',
                                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Workout Card ──
  Widget _buildWorkoutCard(Workout? recent) {
    if (recent == null) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fitness_center, size: 22, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Workout', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('Start your first workout today!', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.activity),
                style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                child: const Text('Start'),
              ),
            ],
          ),
        ),
      );
    }

    final isToday = recent.endTime != null &&
        recent.endTime!.day == DateTime.now().day &&
        recent.endTime!.month == DateTime.now().month &&
        recent.endTime!.year == DateTime.now().year;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, AppRoutes.workout),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.favorite, size: 18, color: AppTheme.errorColor),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(isToday ? "Today's Workout" : 'Most Recent Workout',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 18),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _BpmGauge(label: 'Avg HR', bpm: recent.avgHeartRate),
                  _BpmGauge(label: 'Max HR', bpm: recent.maxHeartRate),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Calorie Balance Card ──
  Widget _buildCalorieBalanceCard(NutritionProvider nutrition, WorkoutProvider workout, dynamic user) {
    final eaten = nutrition.totalCaloriesToday;
    final burned = workout.todayCaloriesBurned;
    final balance = eaten - burned;
    final goal = nutrition.dailyCalorieGoal;
    final remaining = goal - eaten;
    final balanceColor = balance > 0 ? Colors.orange : balance < 0 ? AppTheme.successColor : AppTheme.textSecondary;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_fire_department, size: 18, color: AppTheme.warningColor),
                ),
                const SizedBox(width: 10),
                const Text('Calorie Balance', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _CalStat('Eaten', eaten.toStringAsFixed(0), Colors.orange),
                _CalStat('Burned', burned.toStringAsFixed(0), AppTheme.successColor),
                _CalStat('Balance', balance.toStringAsFixed(0), balanceColor),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text('Remaining', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        overflow: TextOverflow.ellipsis, maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text('${remaining.toStringAsFixed(0)} kcal',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: remaining >= 0 ? AppTheme.successColor : AppTheme.errorColor),
                        overflow: TextOverflow.ellipsis, maxLines: 1, textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (eaten / goal).clamp(0, 1),
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      eaten > goal ? AppTheme.errorColor : AppTheme.successColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Reports Tile ──
  Widget _buildReportsTile() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NutritionReportsScreen()),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nutrition Reports',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'View detailed nutrition breakdown and trends',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Placeholder ──
  Widget _buildPlaceholderCard(IconData icon, String title, String message) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 22, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(message, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sign Out Button ──
  Widget _buildSignOutButton(AuthProvider auth) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Sign Out'),
                content: const Text('Are you sure you want to sign out?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            );
            if (confirm != true) return;

            if (_hasUnsavedChanges) {
              final action = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Unsaved Changes'),
                  content: const Text('Do you want to save changes before logging out?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: const Text('Discard')),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Save')),
                  ],
                ),
              );
              if (action == 'save') await _saveProfile();
              if (action == 'cancel') return;
            }

            await auth.logout();
            if (mounted) Navigator.pushReplacementNamed(context, '/login');
          },
          icon: const Icon(Icons.logout, color: AppTheme.errorColor),
          label: const Text('Sign Out', style: TextStyle(color: AppTheme.errorColor)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: const BorderSide(color: AppTheme.errorColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  // ─── Connections & Settings ──
  Widget _buildConnectionsSettings(dynamic user, dynamic workout) {
    final health = context.watch<HealthProvider>();
    final notifications = context.watch<NotificationProvider>();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _ServiceSwitchTile(
                    icon: Icons.music_note,
                    iconColor: const Color(0xFF1DB954),
                    label: 'Spotify',
                    connected: user?.spotifyConnected == 'connected',
                    onToggle: (_) => _toggleSpotify(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ServiceSwitchTile(
                    icon: Icons.watch,
                    iconColor: AppTheme.primaryColor,
                    label: 'Smartwatch',
                    connected: health.smartwatchConnected,
                    onToggle: (_) => _toggleSmartwatch(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionChipButton(
                    icon: Icons.tune,
                    label: 'Notification Settings',
                    subtitle: 'Configure alerts',
                    onTap: () async {
                      if (user != null) {
                        await notifications.loadSettings(user.uid);
                      }
                      if (context.mounted) {
                        Navigator.pushNamed(context, AppRoutes.notificationSettings);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionChipButton(
                    icon: Icons.history,
                    label: 'Notification History',
                    subtitle: 'View past alerts',
                    onTap: () => Navigator.pushNamed(context, AppRoutes.notificationHistory),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Static Widgets ────────────────────────────────────────────

class _QuickActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _QuickActionItem(this.icon, this.label, this.onTap, this.color);
}

class _CalStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _CalStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const Text('kcal', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _BpmGauge extends StatelessWidget {
  final String label;
  final int bpm;
  const _BpmGauge({required this.label, required this.bpm});

  Color get _color {
    if (bpm <= 0) return AppTheme.textSecondary;
    if (bpm < 60) return AppTheme.warningColor;
    if (bpm < 100) return AppTheme.successColor;
    if (bpm < 130) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _color.withValues(alpha: 0.15),
            border: Border.all(color: _color.withValues(alpha: 0.5), width: 2),
          ),
          child: Center(
            child: Text('$bpm', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _color)),
          ),
        ),
        const SizedBox(height: 4),
        Text('bpm', style: TextStyle(fontSize: 11, color: _color)),
      ],
    );
  }
}

class _ServiceSwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool connected;
  final ValueChanged<bool> onToggle;

  const _ServiceSwitchTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.connected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Switch(
            value: connected,
            onChanged: onToggle,
            activeThumbColor: iconColor,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionChipButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 24),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── BLE Scanner Sheet ──────────────────────────────────────────

class _BleDeviceScannerSheet extends StatefulWidget {
  final void Function(String deviceId) onDeviceSelected;
  final VoidCallback onUseHealthConnect;

  const _BleDeviceScannerSheet({
    required this.onDeviceSelected,
    required this.onUseHealthConnect,
  });

  @override
  State<_BleDeviceScannerSheet> createState() => _BleDeviceScannerSheetState();
}

class _BleDeviceScannerSheetState extends State<_BleDeviceScannerSheet> {
  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthProvider>();

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.5,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.bluetooth_searching, color: AppTheme.primaryColor, size: 24),
                  const SizedBox(width: 12),
                  const Text('Scan for Smartwatches', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const Spacer(),
                  if (health.isScanning) SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor)),
                ],
              ),
              const SizedBox(height: 4),
              const Text('Devices advertising Heart Rate service will appear below', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              if (health.isScanning && health.discoveredDevices.isEmpty) _scanningIndicator(),
              if (health.discoveredDevices.isNotEmpty) ...health.discoveredDevices.map((d) => _deviceCard(d)),
              if (!health.isScanning && health.discoveredDevices.isEmpty) _noDevicesFound(),
              const SizedBox(height: 16),
              _dividerWithText('or'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.onUseHealthConnect,
                  icon: const Icon(Icons.phone_android),
                  label: const Text('Use Health Connect'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(child: Text('For Android smartwatches without BLE support', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary))),
            ],
          ),
        );
      },
    );
  }

  Widget _scanningIndicator() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AppTheme.indigo50, borderRadius: BorderRadius.circular(16)),
      child: const Column(
        children: [
          Icon(Icons.bluetooth_searching, size: 48, color: AppTheme.primaryColor),
          SizedBox(height: 16),
          Text('Searching for devices...', style: TextStyle(fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
          SizedBox(height: 4),
          Text('Make sure your smartwatch is discoverable', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _noDevicesFound() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          const Icon(Icons.bluetooth_disabled, size: 40, color: AppTheme.textSecondary),
          const SizedBox(height: 12),
          const Text('No devices found', style: TextStyle(fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          const Text('Try turning Bluetooth off/on or use Health Connect', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () { context.read<HealthProvider>().startScan(); },
            icon: const Icon(Icons.refresh),
            label: const Text('Scan Again'),
          ),
        ],
      ),
    );
  }

  Widget _deviceCard(BluetoothDeviceInfo device) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onDeviceSelected(device.deviceId),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.watch, color: AppTheme.primaryColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 2),
                      Text(device.deviceId, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: device.rssi > -60
                        ? AppTheme.successColor.withValues(alpha: 0.1)
                        : AppTheme.warningColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${device.rssi} dBm',
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: device.rssi > -60 ? AppTheme.successColor : AppTheme.warningColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dividerWithText(String text) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(text, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }
}