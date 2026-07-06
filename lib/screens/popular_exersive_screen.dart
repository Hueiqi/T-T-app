import 'package:flutter/material.dart';
import '../data/activity/activity_repository.dart';
import '../data/activity/activity_model.dart';
import '../config/theme.dart';
import 'follow_routine_screen.dart';

class PopularWorkoutsScreen extends StatefulWidget {
  const PopularWorkoutsScreen({super.key});

  @override
  State<PopularWorkoutsScreen> createState() => _PopularWorkoutsScreenState();
}

class _PopularWorkoutsScreenState extends State<PopularWorkoutsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ActivityRoutine> _filtered = allRoutines;
  final Set<String> _completedIds = {'abs_10min', 'beginner_abs_10min'};
  final Map<String, int> _completionCount = {
    'abs_10min': 3,
    'beginner_abs_10min': 1,
    'sixpack_10min': 2,
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filtered = allRoutines;
      } else {
        _filtered = allRoutines.where((r) {
          return r.title.toLowerCase().contains(query) ||
              r.difficulty.toLowerCase().contains(query) ||
              r.focus.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  int _parseMinutes(String duration) {
    final match = RegExp(r'(\d+)').firstMatch(duration);
    if (match != null) return int.parse(match.group(1)!);
    return 10;
  }

  int _estimateCalories(ActivityRoutine routine) {
    final minutes = _parseMinutes(routine.duration);
    final met = switch (routine.difficulty.toLowerCase()) {
      'beginner' => 3.0,
      'intermediate' => 4.0,
      'advanced' => 5.0,
      _ => 3.5,
    };
    return (met * 3.5 * minutes / 60 * 200).round();
  }

  Color _difficultyColor(String difficulty) {
    return switch (difficulty.toLowerCase()) {
      'beginner' => AppTheme.successColor,
      'intermediate' => AppTheme.warningColor,
      'advanced' => AppTheme.errorColor,
      _ => AppTheme.textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('10-Min Routines'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset history',
            onPressed: () => setState(() {
              _completedIds.clear();
              _completionCount.clear();
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF472B6), Color(0xFFFB923C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Text('🧘', style: TextStyle(fontSize: 32)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Popular 10-Min Routines',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Quick and effective home workouts',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Section header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${_filtered.length} routine${_filtered.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Grid
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No routines found',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.78,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final routine = _filtered[index];
                      final isDone = _completedIds.contains(routine.id);
                      final doneCount = _completionCount[routine.id] ?? 0;
                      return _RoutineGridCard(
                        routine: routine,
                        isDone: isDone,
                        doneCount: doneCount,
                        difficultyColor: _difficultyColor(routine.difficulty),
                        estimatedCalories: _estimateCalories(routine),
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/routine-detail',
                          arguments: routine.id,
                        ),
                        onQuickStart: () {
                          final nowCount =
                              (_completionCount[routine.id] ?? 0) + 1;
                          setState(() {
                            _completedIds.add(routine.id);
                            _completionCount[routine.id] = nowCount;
                          });
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  FollowRoutineScreen(routineId: routine.id),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RoutineGridCard extends StatelessWidget {
  final ActivityRoutine routine;
  final bool isDone;
  final int doneCount;
  final Color difficultyColor;
  final int estimatedCalories;
  final VoidCallback onTap;
  final VoidCallback onQuickStart;

  const _RoutineGridCard({
    required this.routine,
    required this.isDone,
    required this.doneCount,
    required this.difficultyColor,
    required this.estimatedCalories,
    required this.onTap,
    required this.onQuickStart,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Color(routine.colorValue).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: isDone
              ? Border.all(
                  color: AppTheme.successColor.withValues(alpha: 0.4),
                  width: 1.5,
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top section: icon + badge
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(routine.colorValue).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      routine.icon,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const Spacer(),
                  // Difficulty badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: difficultyColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      routine.difficulty,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: difficultyColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Bottom section: info + action
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    routine.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 12,
                        color: Color(routine.colorValue),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        routine.duration,
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(routine.colorValue),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.local_fire_department,
                        size: 12,
                        color: AppTheme.warningColor,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '~$estimatedCalories',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.warningColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 28,
                          child: ElevatedButton.icon(
                            onPressed: onQuickStart,
                            icon: const Icon(Icons.play_arrow, size: 14),
                            label: Text(
                              isDone ? 'Again' : 'Start',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isDone) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 11,
                                color: AppTheme.successColor,
                              ),
                              if (doneCount > 1) ...[
                                const SizedBox(width: 2),
                                Text(
                                  '${doneCount}x',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.successColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
