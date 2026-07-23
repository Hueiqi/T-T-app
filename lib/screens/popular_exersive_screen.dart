// lib/screens/popular_workouts_screen.dart
import 'package:fitness_app/config/routes.dart';
import 'package:fitness_app/data/activity/activity_repository.dart' as ActivityRepository;
import 'package:flutter/material.dart';
import '../data/activity/activity_repository.dart';
import '../config/theme.dart';
import 'follow_routine_screen.dart';

class PopularWorkoutsScreen extends StatefulWidget {
  const PopularWorkoutsScreen({super.key});

  @override
  State<PopularWorkoutsScreen> createState() => _PopularWorkoutsScreenState();
}

class _PopularWorkoutsScreenState extends State<PopularWorkoutsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ActivityRoutine> _filtered = ActivityRepository.allRoutines;
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
      'beginner' => const Color.fromARGB(255, 101, 197, 167),
      'intermediate' => const Color.fromARGB(255, 242, 197, 120),
      'advanced' => const Color.fromARGB(255, 248, 155, 155),
      _ => const Color.fromARGB(255, 150, 152, 245),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Popular Routines'),
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
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
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
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final routine = _filtered[index];
                        final isDone = _completedIds.contains(routine.id);
                        final doneCount = _completionCount[routine.id] ?? 0;
                        return _RoutineRowCard(
                          routine: routine,
                          isDone: isDone,
                          doneCount: doneCount,
                          difficultyColor: _difficultyColor(routine.difficulty),
                          estimatedCalories: _estimateCalories(routine),
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.routineDetail,
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
      ),
    );
  }
}

class _RoutineRowCard extends StatelessWidget {
  final ActivityRoutine routine;
  final bool isDone;
  final int doneCount;
  final Color difficultyColor;
  final int estimatedCalories;
  final VoidCallback onTap;
  final VoidCallback onQuickStart;

  const _RoutineRowCard({
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
    final imageAsset = routine.imageAsset;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 170,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: isDone
              ? Border.all(
                  color: AppTheme.successColor.withValues(alpha: 0.4),
                  width: 1.5,
                )
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ─── Background Image ──────────────────────────
              Image.asset(
                imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Color(routine.colorValue).withValues(alpha: 0.2),
                ),
              ),
              // ─── Dark Overlay ──────────────────────────────
              Container(
                color: Colors.black.withValues(alpha: 0.45),
              ),
              // ─── Row Content ───────────────────────────────
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // ─── Middle: Info ───────────────────────
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Difficulty badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: difficultyColor.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              routine.difficulty,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Title
                          Text(
                            routine.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 4,
                                  color: Colors.black38,
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          // Duration + Calories row
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer_outlined, size: 13, color: Colors.white70),
                              const SizedBox(width: 3),
                              Text(
                                routine.duration,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_fire_department, size: 13, color: Colors.white70),
                              const SizedBox(width: 2),
                              Text(
                                '~$estimatedCalories cal',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fitness_center, size: 13, color: Colors.white70),
                              const SizedBox(width: 2),
                              Text(
                                '${routine.exercises.length} exercises',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                          const SizedBox(height: 8),
                          // Description
                          Text(
                            routine.description ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // ─── Right: Button + Badge ──────────────
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 38,
                          child: ElevatedButton.icon(
                            onPressed: onQuickStart,
                            icon: Icon(
                              isDone ? Icons.replay : Icons.play_arrow,
                              size: 16,
                            ),
                            label: Text(
                              isDone ? 'Again' : 'Start',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        if (isDone) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 11,
                                  color: Colors.white,
                                ),
                                if (doneCount > 1) ...[
                                  const SizedBox(width: 2),
                                  Text(
                                    '${doneCount}x',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
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
      ),
    );
  }
}
