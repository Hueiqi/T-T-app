import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/routes.dart';
import '../providers/auth_provider.dart';
import '../providers/planning_provider.dart';
import '../services/firebase_service.dart';
import '../widgets/custom_header.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
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
            CustomHeader(
              title: 'Activity',
              showBack: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add activity',
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.workoutDetail),
                ),
              ],
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _buildTabButton('History', 0),
                    _buildTabButton('Love Plan', 1),
                    _buildTabButton('Achievements', 2),
                  ],
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedTab,
                children: [
                  const _HistoryTab(),
                  const _LovePlanTab(),
                  const _AchievementsTab(),
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

// ─── History Tab with auto‑refresh ─────────────────────────────
class _HistoryTab extends StatefulWidget {
  const _HistoryTab();

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab>
    with AutomaticKeepAliveClientMixin {
  final FirebaseService _firebaseService = FirebaseService();
  int _refreshCounter = 0; // used to force refresh

  @override
  bool get wantKeepAlive => false; // always rebuild when visible

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Increment counter to trigger refresh when tab becomes visible
    setState(() {
      _refreshCounter++;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchActivities() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) return [];
    return await _firebaseService.getActivities(auth.user!.uid);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required for AutomaticKeepAliveClientMixin

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _refreshCounter++);
      },
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
                  Text('Error loading history: ${snapshot.error}'),
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

          if (activities.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final a = activities[index];
              final title = a['title'] as String? ?? 'Workout';
              final duration = a['durationSeconds'] as int? ?? 0;
              final completedAt = a['completedAt'] as String? ?? '';
              final dateStr = completedAt.isNotEmpty
                  ? completedAt.substring(0, 10)
                  : '';

              final mins = duration ~/ 60;
              final secs = duration % 60;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.fitness_center,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '$mins:${secs.toString().padLeft(2, '0')}${dateStr.isNotEmpty ? ' · $dateStr' : ''}',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  trailing: Text(
                    '$mins min',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
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
          Icon(
            Icons.history,
            size: 80,
            color: AppTheme.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 24),
          Text(
            'Planning History',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Your planning and activities are recorded here.\n'
            'Tap the + button to manually add any activities\n'
            'completed outside of the application.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
              height: 1.5,
            ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
            Icon(
              Icons.favorite,
              size: 80,
              color: AppTheme.warningColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Your Favorite Plans',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Save your favorite exercise plans here.\n'
              'Bookmark exercises from the planning screen\n'
              'to see them listed here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.planning),
                icon: const Icon(Icons.explore),
                label: const Text('Browse exercises'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.fitness_center,
                        size: 36,
                        color: color.withValues(alpha: 0.5),
                      ),
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
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              if (difficulty.isNotEmpty)
                                _miniTag(difficulty, AppTheme.primaryColor),
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
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Achievements Tab ──────────────────────────────────────────
class _AchievementsTab extends StatelessWidget {
  const _AchievementsTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.local_fire_department,
                color: AppTheme.warningColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Continuous Records',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Weekly Milestones',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(6, (i) {
              final weeks = i + 2;
              return _Badge(
                icon: Icons.fitness_center,
                label: '$weeks weeks',
                unlocked: false,
              );
            }),
          ),
          const SizedBox(height: 32),
          Text(
            'Monthly Milestones',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(6, (i) {
              final months = i + 2;
              return _Badge(
                icon: Icons.emoji_events,
                label: '$months months',
                unlocked: false,
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── Badge Widget ──────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool unlocked;

  const _Badge({
    required this.icon,
    required this.label,
    this.unlocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 36,
            color: unlocked ? AppTheme.warningColor : Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: unlocked ? AppTheme.textPrimary : Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}