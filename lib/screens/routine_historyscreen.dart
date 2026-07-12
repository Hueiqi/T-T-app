import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/routes.dart';
import '../providers/auth_provider.dart';
import '../providers/planning_provider.dart';
import '../providers/user_progress_provider.dart';
import '../services/firebase_service.dart';
import '../widgets/custom_header.dart';

class RoutineHistoryScreen extends StatefulWidget {
  const RoutineHistoryScreen({super.key});

  @override
  State<RoutineHistoryScreen> createState() => _RoutineHistoryScreenState();
}

class _RoutineHistoryScreenState extends State<RoutineHistoryScreen> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBookmarks());
  }

  void _loadBookmarks() {
    final planning = context.read<PlanningProvider>();
    final auth = context.read<AuthProvider>();
    if (auth.user != null) {
      planning.loadBookmarks(auth.user!.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // ─── CUSTOM HEADER ──────────────────────────────────
            CustomHeader(
              title: 'Activity',
              showBack: true,
              onBack: () {
                // Navigate to Planning screen
                Navigator.pushReplacementNamed(context, AppRoutes.planning);
              },
              actions: [
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  tooltip: 'Add activity',
                  onPressed: () {
                    // Navigate to Popular Workouts screen
                    Navigator.pushNamed(context, AppRoutes.popularWorkouts);
                  },
                ),
              ],
            ),
            // ─── TABS ───────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 244, 244, 249).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _buildTabButton('History', 0),
                    _buildTabButton('Love Plan', 1),
                    _buildTabButton('Achievement', 2),
                  ],
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedTab,
                children: const [
                  _HistoryTab(),
                  _LovePlanTab(),
                  _AchievementsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Activity',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.fitness_center),
            title: const Text('Planning'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.planning);
            },
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Exercise Library'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.exerciseLibrary);
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.profile);
            },
          ),
        ],
      ),
    );
  }
}

// ─── History Tab ──────────────────────────────────────────────
class _HistoryTab extends StatefulWidget {
  const _HistoryTab();
  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab>
    with AutomaticKeepAliveClientMixin {
  final FirebaseService _firebaseService = FirebaseService();
  int _refreshCounter = 0;

  @override
  bool get wantKeepAlive => false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() => _refreshCounter++);
  }

  Future<List<Map<String, dynamic>>> _fetchActivities() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) return [];
    return await _firebaseService.getActivities(auth.user!.uid);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: () async => setState(() => _refreshCounter++),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchActivities(),
        key: ValueKey(_refreshCounter),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() => _refreshCounter++),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final activities = snapshot.data ?? [];
          if (activities.isEmpty) return _buildEmptyState(context);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final a = activities[index];
              final title = a['title'] as String? ?? 'Workout';
              final duration = a['durationSeconds'] as int? ?? 0;
              final completedAt = a['completedAt'] as String? ?? '';
              final dateStr = completedAt.length >= 10 ? completedAt.substring(0, 10) : completedAt;
              final mins = duration ~/ 60;
              final secs = duration % 60;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.fitness_center, color: AppTheme.primaryColor),
                  ),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '$mins:${secs.toString().padLeft(2, '0')}${dateStr.isNotEmpty ? ' · $dateStr' : ''}',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  trailing: Text(
                    '$mins min',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                  ),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.workoutDetail),
                ),
              );
            },
          );
        },
      ),
    );
  }


  Widget _buildEmptyState(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Icon(Icons.history, size: 80, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 24),
          Text(
            'Planning History',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Your planning and activities are recorded here.\n'
            'Tap the + button to manually add any activities\n'
            'completed outside of the application.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.planning),
              icon: const Icon(Icons.search),
              label: const Text('Find a training plan'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Love Plan Tab ─────────────────────────────────────────────
class _LovePlanTab extends StatelessWidget {
  const _LovePlanTab();
  @override
  Widget build(BuildContext context) {
    final planning = context.watch<PlanningProvider>();
    final bookmarks = planning.bookmarkedWorkouts;

    if (bookmarks.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 32),
            Icon(Icons.favorite, size: 80, color: AppTheme.warningColor.withValues(alpha: 0.5)),
            const SizedBox(height: 24),
            Text(
              'Your Favorite Plans',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Save your favorite exercise plans here.\n'
              'Bookmark exercises from the planning screen\n'
              'to see them listed here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.planning),
                icon: const Icon(Icons.explore),
                label: const Text('Browse exercises'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: bookmarks.length,
        itemBuilder: (context, index) {
          final w = bookmarks[index];
          final color = Color(w['color'] as int? ?? 0xFF818CF8);
          final title = w['title'] as String? ?? '';
          final difficulty = w['difficulty'] as String? ?? '';
          final duration = w['durationMinutes'] as int? ?? 0;
          return GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.workoutDetail),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Center(
                      child: Icon(Icons.fitness_center, size: 36, color: color.withValues(alpha: 0.5)),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              if (difficulty.isNotEmpty) _miniTag(difficulty, AppTheme.primaryColor),
                              const SizedBox(width: 4),
                              _miniTag('$duration m', AppTheme.warningColor),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _miniTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Achievements Tab ──────────────────────────────────────────
class _AchievementsTab extends StatelessWidget {
  const _AchievementsTab();
  @override
  Widget build(BuildContext context) {
    final userProgress = context.watch<UserProgressProvider>();

    final totalWorkouts = userProgress.totalWorkouts;
    final totalSteps = userProgress.totalSteps;
    final totalDistanceKm = userProgress.totalDistanceKm;
    final totalWorkoutMinutes = userProgress.totalWorkoutMinutes;
    final dietDaysCompleted = userProgress.dietDaysCompleted;
    final planningWeeksCompleted = userProgress.planningWeeksCompleted;

    final dietAchievements = [
      {'label': 'Day 3 Diet', 'image': 'FinishDay3Diet.png', 'unlock': dietDaysCompleted >= 3},
      {'label': 'Week 5 Diet', 'image': 'FinishWeek5Diet.png', 'unlock': dietDaysCompleted >= 35},
      {'label': '14-Week Diet', 'image': 'Finish14weekDiet.png', 'unlock': dietDaysCompleted >= 98},
      {'label': 'Whole Planning', 'image': 'FinishWholePlanning.png', 'unlock': planningWeeksCompleted >= 1},
    ];

    final planningAchievements = [
      {'label': 'Planning Week 5', 'image': 'planningWeek5.png', 'unlock': planningWeeksCompleted >= 5},
      {'label': 'Planning Week 10', 'image': 'PlanningWeek10.png', 'unlock': planningWeeksCompleted >= 10},
    ];

    final specialAchievements = [
      {'label': 'Quarter Century', 'image': 'QuarterCenturyClub.png', 'unlock': totalWorkouts >= 25},
      {'label': 'Halfway Hero', 'image': 'HalfwayHero.png', 'unlock': totalWorkouts >= 50},
      {'label': 'The Centurion', 'image': 'TheCenturion.png', 'unlock': totalWorkouts >= 100},
    ];

    final activityAchievements = [
      {'label': 'High Steps', 'image': 'HightStep.png', 'unlock': totalSteps >= 10000},
      {'label': 'High Distance', 'image': 'highDistance.png', 'unlock': totalDistanceKm >= 100.0},
      {'label': 'High Workout Time', 'image': 'HigtWorkoutTime.png', 'unlock': totalWorkoutMinutes >= 5000},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.emoji_events, color: AppTheme.warningColor, size: 24),
              const SizedBox(width: 8),
              Text('Achievements', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Diet Milestones'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: dietAchievements.map((a) {
              return _Badge(
                icon: Icons.restaurant,
                label: a['label'] as String,
                unlocked: a['unlock'] as bool,
                assetPath: 'lib/assets/achievement/${a['image']}',
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle('Planning Progress'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: planningAchievements.map((a) {
              return _Badge(
                icon: Icons.calendar_today,
                label: a['label'] as String,
                unlocked: a['unlock'] as bool,
                assetPath: 'lib/assets/achievement/${a['image']}',
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle('Special Medals'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: specialAchievements.map((a) {
              return _Badge(
                icon: Icons.star,
                label: a['label'] as String,
                unlocked: a['unlock'] as bool,
                assetPath: 'lib/assets/achievement/${a['image']}',
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle('Activity Records'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: activityAchievements.map((a) {
              return _Badge(
                icon: Icons.fitness_center,
                label: a['label'] as String,
                unlocked: a['unlock'] as bool,
                assetPath: 'lib/assets/achievement/${a['image']}',
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600));
  }
}

// ─── Badge Widget ──────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool unlocked;
  final String? assetPath;

  const _Badge({required this.icon, required this.label, this.unlocked = false, this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: unlocked ? Colors.amber.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: unlocked ? AppTheme.warningColor : Colors.grey.shade300, width: unlocked ? 2 : 1),
        boxShadow: unlocked ? [BoxShadow(color: AppTheme.warningColor.withAlpha(30), blurRadius: 8)] : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          assetPath != null
              ? Image.asset(
                  assetPath!,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(icon, size: 36, color: unlocked ? AppTheme.warningColor : Colors.grey.shade400),
                )
              : Icon(icon, size: 36, color: unlocked ? AppTheme.warningColor : Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: unlocked ? AppTheme.textPrimary : Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,   
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}