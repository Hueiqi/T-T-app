import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../config/routes.dart';

class WorkoutCompleteSummaryScreen extends StatefulWidget {
  final String routineTitle;
  final int durationSeconds;
  final List<String> completedExercises;
  final List<String> pendingExercises;
  final String routineDifficulty;

  const WorkoutCompleteSummaryScreen({
    super.key,
    required this.routineTitle,
    required this.durationSeconds,
    required this.completedExercises,
    required this.pendingExercises,
    this.routineDifficulty = 'beginner',
  });

  @override
  State<WorkoutCompleteSummaryScreen> createState() =>
      _WorkoutCompleteSummaryScreenState();
}

class _WorkoutCompleteSummaryScreenState
    extends State<WorkoutCompleteSummaryScreen> {
  late List<String> _pending;
  late List<String> _completed;
  bool _completedExpanded = true;

  @override
  void initState() {
    super.initState();
    _pending = List.from(widget.pendingExercises);
    _completed = List.from(widget.completedExercises);
  }

  String _formatTime(int totalSeconds) {
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  int get _caloriesBurned {
    final calPerMin = _calPerMinute(widget.routineDifficulty);
    return ((widget.durationSeconds / 60) * calPerMin).round();
  }

  int get _avgHeartRate => _heartRateEstimate(widget.routineDifficulty);

  int _calPerMinute(String diff) {
    switch (diff.toLowerCase()) {
      case 'beginner':
        return 4;
      case 'intermediate':
        return 6;
      case 'advanced':
      case 'intense':
        return 8;
      default:
        return 5;
    }
  }

  int _heartRateEstimate(String diff) {
    switch (diff.toLowerCase()) {
      case 'beginner':
        return 110;
      case 'intermediate':
        return 130;
      case 'advanced':
      case 'intense':
        return 150;
      default:
        return 120;
    }
  }

  String get _motivationalText {
    final total = _completed.length + _pending.length;
    if (total == 0) return 'Great effort! Keep showing up!';
    final ratio = _completed.length / total;
    if (ratio >= 1) return 'Perfect workout! You crushed it!';
    if (ratio >= 0.8) return 'Almost perfect! Just a few more next time.';
    if (ratio >= 0.5) return 'Nice work! You\'re more than halfway there.';
    if (ratio >= 0.25) return 'Good start! Challenge yourself to finish more next session.';
    return 'Every rep counts! Keep pushing forward!';
  }

  void _completePending(int index) {
    setState(() {
      _completed.add(_pending[index]);
      _pending.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = _completed.length + _pending.length;
    final progress = total > 0 ? _completed.length / total : 1.0;
    final allDone = _pending.isEmpty;

    return Scaffold(
      body: SafeArea(
        child: SizedBox.expand(
          child: CustomScrollView(
            physics: const ClampingScrollPhysics(), // ✅ allows scrolling
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.only(top: 12),
                sliver: SliverToBoxAdapter(
                  child: _buildHeader(progress, total, allDone),
                  ),
              ),
              if (!allDone) SliverToBoxAdapter(child: const SizedBox(height: 8)),
              if (!allDone) SliverToBoxAdapter(child: _buildProgressBar(progress, total)),
              SliverToBoxAdapter(child: _buildStatsRow()),
              SliverToBoxAdapter(child: _buildCompletedSection()),
              if (!allDone) SliverToBoxAdapter(child: _buildPendingSection()),
              SliverToBoxAdapter(child: _buildMotivationalCard()),
              SliverToBoxAdapter(child: _buildActionButtons()),
              // ✅ extra bottom padding to prevent clipping
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 80),
                sliver: SliverToBoxAdapter(child: const SizedBox.shrink()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double progress, int total, bool allDone) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: allDone
                    ? [const Color(0xFF059669), const Color(0xFF10B981)]
                    : [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (allDone ? const Color(0xFF059669) : AppTheme.primaryColor).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            allDone ? Icons.celebration : Icons.fitness_center,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              allDone ? 'Workout Complete!' : 'Workout Finished',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.routineTitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 15,
                        ),
                      ),
                      if (!allDone)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.info_outline, size: 12, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Remaining exercises',
                                  style: TextStyle(color: Colors.white, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 1000),
                  builder: (ctx, value, _) => SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: CircularProgressIndicator(
                            value: value,
                            strokeWidth: 5,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(value * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '$_completed/$total',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double progress, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.pie_chart_outline, size: 18, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    '$_completed / $total exercises',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(progress * 100).round()}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1 ? AppTheme.successColor : AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.timer_outlined,
              label: 'Duration',
              value: _formatTime(widget.durationSeconds),
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              icon: Icons.local_fire_department,
              label: 'Calories',
              value: '$_caloriesBurned',
              color: AppTheme.warningColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              icon: Icons.favorite,
              label: 'Avg HR',
              value: '$_avgHeartRate bpm',
              color: AppTheme.errorColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              onTap: () => setState(() => _completedExpanded = !_completedExpanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppTheme.successColor, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Completed (${_completed.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _completedExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
            if (_completedExpanded && _completed.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _completed.length,
                  itemBuilder: (ctx, i) => Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      i == 0 ? 0 : 2,
                      16,
                      i == _completed.length - 1 ? 12 : 2,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: AppTheme.successColor,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _completed[i],
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_completed.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Text(
                  'No exercises completed yet.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingSection() {
    if (_pending.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: Colors.amber.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.hourglass_empty, color: Colors.amber, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Remaining (${_pending.length})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Complete these exercises for a full workout:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.amber.shade700,
                ),
              ),
              const SizedBox(height: 10),
              ...List.generate(_pending.length, (i) {
                final name = _pending[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.remove,
                          color: Colors.amber,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      SizedBox(
                        height: 34,
                        child: ElevatedButton.icon(
                          onPressed: () => _completePending(i),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Mark as done'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: AppTheme.successColor,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMotivationalCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _pending.isEmpty ? Icons.emoji_events : Icons.trending_up,
                color: AppTheme.primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _motivationalText,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        children: [
          if (_pending.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _completed.addAll(_pending);
                      _pending.clear();
                    });
                  },
                  icon: const Icon(Icons.skip_next, size: 20),
                  label: const Text('Skip All Remaining'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.warningColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: AppTheme.warningColor.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.activity,
                (route) => false,
              ),
              icon: const Icon(Icons.play_arrow, size: 20),
              label: const Text('Next Workout'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.home,
                    (route) => false,
                  ),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('View History'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Share coming soon')),
                    );
                  },
                  icon: const Icon(Icons.share),
                  color: AppTheme.primaryColor,
                  tooltip: 'Share',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}