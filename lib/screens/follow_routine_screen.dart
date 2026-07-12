import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

// ✅ Only this import – it re‑exports the model and provides the repository.
import '../data/activity/activity_repository.dart';

import '../services/exercise_db.dart';
import '../models/exercise_model.dart';
import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';
import 'routine_complete_summary_screen.dart';

class FollowRoutineScreen extends StatefulWidget {
  final String routineId;
  const FollowRoutineScreen({super.key, required this.routineId});

  @override
  State<FollowRoutineScreen> createState() => _FollowRoutineScreenState();
}

class _FollowRoutineScreenState extends State<FollowRoutineScreen> {
  late ActivityRoutine _routine;
  int _currentIndex = 0;
  int _totalElapsed = 0;
  int _exerciseSecondsLeft = 0;
  int _restSecondsLeft = 0;
  bool _isResting = false;
  bool _isPaused = false;
  bool _isFinished = false;
  final List<String> _completedNames = [];
  final Map<String, ExerciseDb?> _exerciseCache = {};
  Timer? _timer;

  static const int _defaultRestSecs = 15;

  @override
  void initState() {
    super.initState();
    final r = ActivityRepository.findRoutineById(widget.routineId);
    _routine = r ?? ActivityRepository. allRoutines.first;
    _exerciseSecondsLeft = _routine.exercises.first.durationInSeconds;
    _loadExerciseDb();
    _startTimer();
  }

  Future<void> _loadExerciseDb() async {
    await ExerciseDatabase.load();
    for (final e in _routine.exercises) {
      _exerciseCache[e.name] = ExerciseDatabase.findByName(e.name);
    }
    if (mounted) setState(() {});
  }

  ExerciseDb? _dbFor(String name) => _exerciseCache[name];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_isPaused || _isFinished) return;
      setState(() => _totalElapsed++);

      if (_isResting) {
        _tickRest();
      } else {
        _tickExercise();
      }
    });
  }

  void _tickRest() {
    if (_restSecondsLeft <= 0) {
      _timer?.cancel();
      _advanceToNextExercise();
    } else {
      if (!mounted) return;
      setState(() => _restSecondsLeft--);
    }
  }

  void _tickExercise() {
    if (_exerciseSecondsLeft <= 0) {
      if (_currentIndex < _routine.exercises.length) {
        _markCurrentComplete();
      }
      _startRest();
    } else {
      if (!mounted) return;
      setState(() => _exerciseSecondsLeft--);
    }
  }

  void _markCurrentComplete() {
    final name = _routine.exercises[_currentIndex].name;
    if (!_completedNames.contains(name)) {
      if (!mounted) return;
      setState(() => _completedNames.add(name));
    }
  }

  void _startRest() {
    if (_currentIndex >= _routine.exercises.length - 1) {
      _finishWorkout();
      return;
    }
    if (!mounted) return;
    setState(() {
      _isResting = true;
      _restSecondsLeft = _defaultRestSecs;
    });
  }

  void _advanceToNextExercise() {
    if (_currentIndex >= _routine.exercises.length - 1) {
      _finishWorkout();
      return;
    }
    if (!mounted) return;
    setState(() {
      _currentIndex++;
      _isResting = false;
      _exerciseSecondsLeft = _routine.exercises[_currentIndex].durationInSeconds;
    });
    _startTimer();
  }

  void _completeExerciseEarly() {
    _timer?.cancel();
    _markCurrentComplete();
    if (_currentIndex >= _routine.exercises.length - 1) {
      _finishWorkout();
    } else {
      _startRest();
      _startTimer();
    }
  }

  void _skipExercise() {
    _timer?.cancel();
    if (_currentIndex >= _routine.exercises.length - 1) {
      _finishWorkout();
    } else {
      _startRest();
      _startTimer();
    }
  }

  void _finishWorkout() {
    _timer?.cancel();
    if (!mounted) return;
    setState(() => _isFinished = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user != null) {
      final userId = auth.user!.uid;
      final data = {
        'title': _routine.title,
        'durationSeconds': _totalElapsed,
        'completedAt': DateTime.now().toIso8601String(),
        'difficulty': _routine.difficulty,
      };
      FirebaseService().saveActivity(userId, data);
    }

    final pending = _routine.exercises
        .map((e) => e.name)
        .where((n) => !_completedNames.contains(n))
        .toList();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RoutineCompleteSummaryScreen(
          routineTitle: _routine.title,
          durationSeconds: _totalElapsed,
          completedExercises: List.from(_completedNames),
          pendingExercises: pending,
          routineDifficulty: _routine.difficulty,
        ),
      ),
    );
  }

  void _confirmEnd() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('End Workout?', style: TextStyle(color: Colors.white)),
        content: const Text('Your progress will be lost.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('End'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      _timer?.cancel();
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  String _motivationalMessage() {
    final total = _routine.exercises.length;
    final done = _completedNames.length;
    final progress = total > 0 ? done / total : 0.0;
    if (progress < 0.25) return 'Great start! Keep going';
    if (progress < 0.5) return "You're doing amazing!";
    if (progress < 0.75) return "Almost there! Don't stop now";
    return 'Final push! You\'ve got this!';
  }

  @override
  Widget build(BuildContext context) {
    final total = _routine.exercises.length;
    final done = _completedNames.length;
    final progress = total > 0 ? done / total : 0.0;
    final currentEx = _currentIndex < total ? _routine.exercises[_currentIndex] : null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        toolbarHeight: 56,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _confirmEnd,
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isPaused ? Icons.play_arrow : Icons.pause,
              color: Colors.white,
            ),
            onPressed: () => setState(() => _isPaused = !_isPaused),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              // ── Progress bar ──
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$done of $total',
                          style: const TextStyle(color: Colors.white60, fontSize: 14),
                        ),
                        Text(
                          _isResting ? 'Rest' : 'Exercise ${_currentIndex + 1}',
                          style: TextStyle(
                            color: _isResting ? Colors.orangeAccent : Colors.lightGreenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0, 1),
                        backgroundColor: Colors.grey.shade800,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Main content ──
              Expanded(
                child: _isResting
                    ? _buildRestScreen()
                    : (currentEx != null
                        ? _buildExerciseScreen(currentEx, total)
                        : const Center(
                            child: Text('Complete!', style: TextStyle(color: Colors.white, fontSize: 24)),
                          )),
              ),

              // ── Bottom controls ──
              if (!_isResting && currentEx != null) _buildBottomControls(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Exercise Screen (no overflow) ──────────────────────
  Widget _buildExerciseScreen(Exercise exercise, int total) {
    final db = _dbFor(exercise.name);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Image ──
        if (db != null && db.images.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: db.gifUrl != null
                ? CachedNetworkImage(
                    imageUrl: db.gifUrl!,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const SizedBox.shrink(),
                    errorWidget: (_, __, ___) => _buildFallbackImage(db),
                  )
                : _buildFallbackImage(db),
          ),
        if (db != null && db.images.isNotEmpty) const SizedBox(height: 8),

        // ── Name ──
        Text(
          exercise.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '${exercise.reps} · ${exercise.sets} set${exercise.sets > 1 ? 's' : ''}',
          style: const TextStyle(color: Colors.white60, fontSize: 15),
        ),
        if (db != null && db.instructions.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            db.instructions.first,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 8),

        // ── Timer circle ──
        _buildTimerCircle(
          secondsLeft: _exerciseSecondsLeft,
          totalSeconds: exercise.durationInSeconds,
          label: 'seconds',
          color: Colors.white,
        ),
        const SizedBox(height: 8),

        // ── Motivational message ──
        Text(
          _motivationalMessage(),
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // ── Thumbnail list (fixed height) ──
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: total,
            itemBuilder: (ctx, i) {
              final ex = _routine.exercises[i];
              final isDone = _completedNames.contains(ex.name);
              final isCurr = i == _currentIndex;
              return Container(
                width: 70,
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isDone
                      ? Colors.green.withValues(alpha: 0.2)
                      : isCurr
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: isCurr
                      ? Border.all(color: Colors.white.withValues(alpha: 0.3))
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isDone ? Icons.check_circle : Icons.circle_outlined,
                      color: isDone ? Colors.greenAccent : Colors.white38,
                      size: 16,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ex.name,
                      style: TextStyle(
                        color: isDone ? Colors.greenAccent : Colors.white54,
                        fontSize: 9,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Rest Screen ──────────────────────────────────────────
  Widget _buildRestScreen() {
    final nextIdx = _currentIndex + 1;
    final nextEx = nextIdx < _routine.exercises.length ? _routine.exercises[nextIdx] : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timer_outlined, color: Colors.orangeAccent, size: 56),
            const SizedBox(height: 12),
            const Text(
              'Rest',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildTimerCircle(
              secondsLeft: _restSecondsLeft,
              totalSeconds: _defaultRestSecs,
              label: 's',
              color: Colors.orangeAccent,
            ),
            const SizedBox(height: 16),
            if (nextEx != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_upward, color: Colors.white38, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Next: ${nextEx.name}',
                      style: const TextStyle(color: Colors.white60, fontSize: 15),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _advanceToNextExercise,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text('Skip Rest'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Shared timer circle ─────────────────────────────────
  Widget _buildTimerCircle({
    required int secondsLeft,
    required int totalSeconds,
    required String label,
    required Color color,
  }) {
    final progress = totalSeconds > 0 ? secondsLeft / totalSeconds : 0.0;
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
              value: progress.clamp(0, 1),
              strokeWidth: 5,
              backgroundColor: Colors.grey.shade800,
              valueColor: AlwaysStoppedAnimation<Color>(
                secondsLeft <= 5 ? Colors.redAccent : color,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$secondsLeft',
                style: TextStyle(
                  color: secondsLeft <= 5 ? Colors.redAccent : Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Bottom Controls ──────────────────────────────────────
  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _skipExercise,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Skip'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _completeExerciseEarly,
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: const Text('Done', style: TextStyle(color: Colors.white, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Fallback image ───────────────────────────────────────
  Widget _buildFallbackImage(ExerciseDb db) {
    return Image.network(
      db.imageUrl,
      height: 120,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}