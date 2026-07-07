import 'package:flutter/material.dart';
import '../data/activity/activity_repository.dart';
import '../data/activity/activity_model.dart';
import '../config/theme.dart';
import 'follow_routine_screen.dart';

class RoutineDetailScreen extends StatefulWidget {
  final String routineId;
  const RoutineDetailScreen({super.key, required this.routineId});

  @override
  State<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends State<RoutineDetailScreen> {
  bool _restTimerEnabled = true;

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
    final routine = findRoutineById(widget.routineId);
    if (routine == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Routine')),
        body: const Center(child: Text('Routine not found')),
      );
    }

    final similarRoutines = allRoutines
        .where((r) => r.id != routine.id && r.focus == routine.focus)
        .take(3)
        .toList();

    final calories = _estimateCalories(routine);
    final totalExercises = routine.exercises.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(routine.title),
        backgroundColor: AppTheme.textSecondary.withValues(alpha: 0.05),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ─── Main content (scrollable) ──────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              children: [
                // ── Hero header ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(routine.colorValue),
                        Color(routine.colorValue).withValues(alpha: 0.7),
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
                      // ── Rating row (FIXED overflow) ──
                      Row(
                        children: [
                          // Stars
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
                          // 🔥 FIX: Flexible + ellipsis prevents overflow
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
                          // Difficulty pill
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
                      // Pills: duration, calories
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
                    color: AppTheme.indigo50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pie_chart_outline,
                          color: AppTheme.primaryColor, size: 20),
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
                            backgroundColor:
                                AppTheme.primaryColor.withValues(alpha: 0.1),
                            color: AppTheme.primaryColor,
                            minHeight: 6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Rest timer toggle ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer, size: 20,
                          color: AppTheme.textSecondary),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Rest Timer (15s between exercises)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Switch(
                        value: _restTimerEnabled,
                        onChanged: (v) => setState(() => _restTimerEnabled = v),
                        activeColor: AppTheme.primaryColor,
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
                        AppTheme.primaryColor.withValues(alpha: 0.08),
                        AppTheme.secondaryColor.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.music_note,
                            color: AppTheme.primaryColor, size: 20),
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
                      const Icon(Icons.headphones, size: 20,
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
                            color: Color(routine.colorValue).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _exerciseIcon(i),
                            color: Color(routine.colorValue),
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
                              color: Color(routine.colorValue).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${e.sets}x',
                              style: TextStyle(
                                color: Color(routine.colorValue),
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
                              color: Color(similar.colorValue).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(similar.icon,
                                        style: const TextStyle(fontSize: 20)),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Color(similar.colorValue)
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        similar.duration,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Color(similar.colorValue),
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

          // ─── Bottom fixed button ────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.textSecondary.withValues(alpha: 0.05),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
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
                  backgroundColor: Color(routine.colorValue),
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