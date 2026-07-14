// lib/screens/routine_detail_screen.dart
import 'package:flutter/material.dart';
import '../data/activity/activity_repository.dart';
import '../config/theme.dart';
import 'follow_routine_screen.dart';

class RoutineDetailScreen extends StatefulWidget {
  final String routineId;
  const RoutineDetailScreen({super.key, required this.routineId});

  @override
  State<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends State<RoutineDetailScreen> {
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

  String _musicSuggestion(String difficulty) {
    return switch (difficulty.toLowerCase()) {
      'beginner' => 'Chill Lo-Fi · 100-120 BPM',
      'intermediate' => 'Pop Hits · 120-140 BPM',
      'advanced' => 'High Energy · 140-160 BPM',
      _ => 'Workout Mix · 120-140 BPM',
    };
  }

  IconData _exerciseIcon(int index) {
    final icons = [
      Icons.fitness_center,
      Icons.directions_run,
      Icons.accessibility_new,
      Icons.self_improvement,
      Icons.sports_gymnastics,
      Icons.sports_kabaddi,
    ];
    return icons[index % icons.length];
  }

  @override
  Widget build(BuildContext context) {
    final routine = ActivityRepository.findRoutineById(widget.routineId);
    if (routine == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Routine')),
        body: const Center(child: Text('Routine not found')),
      );
    }

    final similarRoutines = ActivityRepository.allRoutines
        .where((r) => r.id != routine.id && r.focus == routine.focus)
        .take(3)
        .toList();

    final calories = _estimateCalories(routine);
    final totalExercises = routine.exercises.length;

    final baseColor = Color(routine.colorValue);
    final lightColor = baseColor.withValues(alpha: 0.1);

    return Scaffold(
      appBar: AppBar(
        title: Text(routine.title),
        backgroundColor: baseColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Main content (scrollable) ──────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                physics: const BouncingScrollPhysics(),
                children: [
                  // ── Hero header (soft gradient) ──
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          baseColor,
                          baseColor.withValues(alpha: 0.6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routine.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (routine.description != null)
                          Text(
                            routine.description!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                          ),
                        const SizedBox(height: 12),
                        // Rating row
                        Row(
                          children: [
                            Row(
                              children: List.generate(5, (i) {
                                return Icon(
                                  i < 4 ? Icons.star : Icons.star_half,
                                  color: Colors.yellow,
                                  size: 16,
                                );
                              }),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '~4.0',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                routine.difficulty,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _pill(routine.duration, Icons.timer_outlined),
                            _pill('~$calories kcal', Icons.local_fire_department),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Progress preview ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: lightColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.pie_chart_outline,
                            color: baseColor, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '0 / $totalExercises exercises completed',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: 0,
                              backgroundColor: baseColor.withValues(alpha: 0.1),
                              color: baseColor,
                              minHeight: 6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Music suggestion ──
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          baseColor.withValues(alpha: 0.08),
                          baseColor.withValues(alpha: 0.02),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: baseColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.music_note,
                              color: baseColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Recommended Music',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _musicSuggestion(routine.difficulty),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.headphones, size: 20,
                            color: AppTheme.textSecondary),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Exercises header ──
                  const Text(
                    'Exercises',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Exercise list ──
                  ...routine.exercises.asMap().entries.map((entry) {
                    final i = entry.key;
                    final e = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: lightColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _exerciseIcon(i),
                              color: baseColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${e.reps}${e.sets > 1 ? ' · ${e.sets} sets' : ''}',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (e.sets > 1)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: lightColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${e.sets}x',
                                style: TextStyle(
                                  color: baseColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),

                  // ── Similar routines ──
                  if (similarRoutines.isNotEmpty) ...[
                    const Text(
                      'Similar Routines',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: similarRoutines.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) {
                          final similar = similarRoutines[i];
                          final simColor = Color(similar.colorValue);
                          return GestureDetector(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      RoutineDetailScreen(routineId: similar.id),
                                ),
                              );
                            },
                            child: Container(
                              width: 160,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: simColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: simColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: simColor.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          similar.duration,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: simColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    similar.title,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // ─── Bottom button (no grey background) ────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FollowRoutineScreen(routineId: routine.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow, color: Colors.white),
                  label: const Text(
                    'Start Routine',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: baseColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}