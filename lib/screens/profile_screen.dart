import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/music_provider.dart';
import '../providers/nutrition_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/sleep_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/health_provider.dart';
import '../widgets/bottom_nav_shell.dart';
import '../providers/planning_provider.dart';
import '../services/tdee_calculator.dart';
import '../config/theme.dart';
import '../config/routes.dart';
import '../models/user_model.dart';
import '../models/workout_model.dart';
import 'nutrition_reports_screen.dart';
import 'body_statistics_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool showBottomNav;

  const ProfileScreen({super.key, this.showBottomNav = true});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initProfile());
  }

  Future<void> _initProfile() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;

    if (auth.user!.spotifyConnected == 'connected') {
      final music = context.read<MusicProvider>();
      final restored = await music.restoreSession();
      if (!restored && mounted) {
        final updatedUser = auth.user!.copyWith(spotifyConnected: 'disconnected');
        await auth.updateProfile(updatedUser);
      }
    }

    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    context.read<SleepProvider>().loadSleepData(auth.user!.uid);
    context.read<NutritionProvider>().loadTodayMeals(auth.user!.uid);
    context.read<WorkoutProvider>().loadDashboardData(auth.user!.uid);
    context.read<PlanningProvider>().loadBookmarks(auth.user!.uid);
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
        SnackBar(content: Text(music.error ?? 'Spotify connection failed. Make sure you have a Spotify account.')),
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
                _buildViewSections(user, sleep, nutrition, workout),
                _buildSignOutButton(auth),
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
              backgroundImage: (user?.photoUrl != null && user!.photoUrl!.isNotEmpty)
                  ? NetworkImage(user.photoUrl!)
                  : null,
              child: (user?.photoUrl == null || user!.photoUrl!.isEmpty)
                  ? Icon(
                      Icons.person,
                      size: 50,
                      color: AppTheme.primaryColor,
                    )
                  : null,
            ),
            Positioned(
              bottom: -4,
              right: -4,
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppRoutes.editProfile),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primaryColor,
                    child: const Icon(
                      Icons.edit,
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
          onTap: () => Navigator.pushNamed(context, AppRoutes.editProfile),
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
              const Icon(
                Icons.edit,
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
      _QuickActionItem(Icons.bar_chart, 'Statistics', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BodyStatisticsScreen())), const Color(0xFF7C3AED)),
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

  // ─── Connections & Settings (with Health Connect) ──
  Widget _buildConnectionsSettings(dynamic user, dynamic workout) {
    final notifications = context.watch<NotificationProvider>();
    final health = context.watch<HealthProvider>();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Spotify ──
            _ServiceSwitchTile(
              icon: Icons.music_note,
              iconColor: const Color(0xFF1DB954),
              label: 'Spotify',
              connected: user?.spotifyConnected == 'connected',
              onToggle: (_) => _toggleSpotify(),
            ),
            const SizedBox(height: 12),

            // ── Health Connect ── NEW ──
            _ServiceSwitchTile(
              icon: Icons.health_and_safety,
              iconColor: AppTheme.primaryColor,
              label: 'Health Connect',
              connected: health.isHealthConnectAuthorized,
              onToggle: (_) async {
                if (health.isHealthConnectAuthorized) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Disconnect from Health Connect settings on your device.')),
                  );
                } else {
                  final available = await health.checkAvailability();
                  if (!available) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Health Connect not installed.')),
                    );
                    return;
                  }
                  final authorized = await health.authorizeHealthConnect();
                  if (authorized) {
                    await health.syncHealthData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Health Connect connected!')),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 12),

            // ── Action chips ──
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionChipButton(
                    icon: Icons.library_music,
                    label: 'Spotify Library',
                    subtitle: 'Browse playlists & albums',
                    onTap: () => Navigator.pushNamed(context, AppRoutes.spotify),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionChipButton(
                    icon: Icons.queue_music,
                    label: 'Workout Playlists',
                    subtitle: 'Set music per run status',
                    onTap: () => Navigator.pushNamed(context, AppRoutes.workoutMusic),
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