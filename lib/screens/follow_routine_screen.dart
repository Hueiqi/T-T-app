import 'dart:async';
import 'package:fitness_app/providers/auth_provider.dart';
import 'package:fitness_app/services/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../data/activity/activity_repository.dart';
import '../services/exercise_db.dart';
import '../models/exercise_model.dart';
import 'workout_complete_summary_screen.dart';

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
    final r = findRoutineById(widget.routineId);
    _routine = r ?? allRoutines.first;
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

    
  // ─── SAVE TO FIREBASE ──────────────────────────────────────────
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
        builder: (_) => WorkoutCompleteSummaryScreen(
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
        toolbarHeight: 72, // ✅ taller app bar for more space
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
           padding: const EdgeInsets.only(top: 8), // ✅ adds breathing room below status bar
        child: Column(
          children: [
            // ── Progress bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0, 1),
                      backgroundColor: Colors.grey.shade800,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 5,
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

  // ─── Exercise Screen (fixed overflow) ──────────────────────
  Widget _buildExerciseScreen(Exercise exercise, int total) {
    final db = _dbFor(exercise.name);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Image ──
          if (db != null && db.images.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: db.gifUrl != null
                  ? CachedNetworkImage(
                      imageUrl: db.gifUrl!,
                      height: 140,
                      width: 200,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const SizedBox.shrink(),
                      errorWidget: (_, __, ___) => _buildFallbackImage(db),
                    )
                  : _buildFallbackImage(db),
            ),
          if (db != null && db.images.isNotEmpty) const SizedBox(height: 12),

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
          const SizedBox(height: 6),
          Text(
            '${exercise.reps} · ${exercise.sets} set${exercise.sets > 1 ? 's' : ''}',
            style: const TextStyle(color: Colors.white60, fontSize: 16),
          ),
          if (db != null && db.instructions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              db.instructions.first,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),

          // ── Timer circle ──
          _buildTimerCircle(
            secondsLeft: _exerciseSecondsLeft,
            totalSeconds: exercise.durationInSeconds,
            label: 'seconds',
            color: Colors.white,
          ),
          const SizedBox(height: 12),

          // ── Motivational message ──
          Text(
            _motivationalMessage(),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // ── Thumbnail list (now takes remaining space) ──
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 8, top: 4),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: total,
                itemBuilder: (ctx, i) {
                  final ex = _routine.exercises[i];
                  final isDone = _completedNames.contains(ex.name);
                  final isCurr = i == _currentIndex;
                  return Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDone
                          ? Colors.green.withValues(alpha: 0.2)
                          : isCurr
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
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
                          size: 18,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ex.name,
                          style: TextStyle(
                            color: isDone ? Colors.greenAccent : Colors.white54,
                            fontSize: 10,
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
          ),
        ],
      ),
    );
  }

  // ─── Rest Screen (with circular timer) ──────────────────────
  Widget _buildRestScreen() {
    final nextIdx = _currentIndex + 1;
    final nextEx = nextIdx < _routine.exercises.length ? _routine.exercises[nextIdx] : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timer_outlined, color: Colors.orangeAccent, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Rest',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildTimerCircle(
              secondsLeft: _restSecondsLeft,
              totalSeconds: _defaultRestSecs,
              label: 's',
              color: Colors.orangeAccent,
            ),
            const SizedBox(height: 24),
            if (nextEx != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_upward, color: Colors.white38, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Next: ${nextEx.name}',
                      style: const TextStyle(color: Colors.white60, fontSize: 16),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _advanceToNextExercise,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
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

  // ─── Shared timer circle ─────────────────────────────────────
  Widget _buildTimerCircle({
    required int secondsLeft,
    required int totalSeconds,
    required String label,
    required Color color,
  }) {
    final progress = totalSeconds > 0 ? secondsLeft / totalSeconds : 0.0;
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 150,
            height: 150,
            child: CircularProgressIndicator(
              value: progress.clamp(0, 1),
              strokeWidth: 6,
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
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Bottom Controls ──────────────────────────────────────────
  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0), Colors.black],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _skipExercise,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Skip'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _completeExerciseEarly,
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: const Text('Done', style: TextStyle(color: Colors.white, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
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

  // ─── Fallback image ───────────────────────────────────────────
  Widget _buildFallbackImage(ExerciseDb db) {
    return Image.network(
      db.imageUrl,
      height: 140,
      width: 200,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}