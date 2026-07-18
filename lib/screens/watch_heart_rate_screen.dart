import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/routes.dart';
import '../config/theme.dart';
import '../providers/health_provider.dart';
import '../services/watch_heart_rate_service.dart';
import '../widgets/custom_header.dart';

/// Displays live heart rate from either of two sources:
///
///  1. **Wear OS Data Layer** — the companion Wear OS app streaming BPM over
///     [WatchHeartRateService]'s EventChannel (if the user has a Wear OS watch).
///  2. **Simulation** — a demo BPM stream (random or GPS-driven) started from
///     the Workout screen, for when no real watch is available.
///
/// Whichever source delivers a reading updates the display; the most recent
/// reading wins. If nothing arrives for a while the card dims and the waiting
/// state is shown again.
class WatchHeartRateScreen extends StatefulWidget {
  const WatchHeartRateScreen({super.key});

  @override
  State<WatchHeartRateScreen> createState() => _WatchHeartRateScreenState();
}

class _WatchHeartRateScreenState extends State<WatchHeartRateScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription<int>? _wearOsSub;
  StreamSubscription<int>? _simSub;
  late final AnimationController _pulse;

  int? _bpm;
  String? _source; // 'Wear OS' or 'Simulated'
  DateTime? _lastUpdate;

  // A reading older than this is considered stale (watch out of range, taken
  // off the wrist, broadcast stopped...).
  static const _staleAfter = Duration(seconds: 10);
  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      lowerBound: 0.85,
      upperBound: 1.15,
    );

    // Source 1: Wear OS companion app over the Data Layer.
    _wearOsSub = WatchHeartRateService.instance.heartRateStream.listen(
      (bpm) => _onReading(bpm, 'Wear OS'),
      onError: (_) {},
    );

    // Source 2: simulated heart rate (demo mode, for vendor-locked watches).
    _simSub = context.read<HealthProvider>().simulatedHeartRateStream.listen(
          (bpm) => _onReading(bpm, 'Simulated'),
          onError: (_) {},
        );

    // Refresh once a second so staleness/"last updated" stay accurate.
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onReading(int bpm, String source) {
    if (bpm <= 0) return;
    setState(() {
      _bpm = bpm;
      _source = source;
      _lastUpdate = DateTime.now();
    });
    _pulse.forward(from: 0.85).then((_) => _pulse.reverse());
  }

  bool get _isStale {
    final last = _lastUpdate;
    if (last == null) return true;
    return DateTime.now().difference(last) > _staleAfter;
  }

  @override
  void dispose() {
    _wearOsSub?.cancel();
    _simSub?.cancel();
    _uiTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasReading = _bpm != null && !_isStale;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child:
                  CustomHeader(title: 'Live Watch Heart Rate', showBack: true),
            ),
            Expanded(
              child: hasReading
                  ? Center(child: _liveReading())
                  : Center(child: _waitingPanel()),
            ),
          ],
        ),
      ),
    );
  }

  // ── Live reading ──────────────────────────────────────────────────────────

  Widget _liveReading() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _pulse,
          child: const Icon(Icons.favorite, size: 96, color: Color(0xFFE53935)),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$_bpm',
              style: const TextStyle(
                fontSize: 88,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'BPM',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _source == 'Simulated'
              ? (context.watch<HealthProvider>().isGpsSimulation
                  ? 'Simulated from your movement (GPS)'
                  : 'Simulated — demo mode')
              : 'Live via $_source',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.successColor,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _source == 'Simulated' ? 'Simulated (demo)' : 'Connected',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (_source == 'Simulated') ...[
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () {
              context.read<HealthProvider>().stopHeartRateSimulation();
              setState(() {
                _bpm = null;
                _source = null;
                _lastUpdate = null;
              });
            },
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Stop simulation'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
          ),
        ],
      ],
    );
  }

  // ── Waiting state ─────────────────────────────────────────────────────────

  Widget _waitingPanel() {
    final lostReading = _bpm != null; // had data before, went stale
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite,
              size: 96, color: Colors.grey.withValues(alpha: 0.4)),
          const SizedBox(height: 24),
          Text(
            lostReading ? 'Reading lost' : 'No live heart rate yet',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            lostReading
                ? 'No reading for a few seconds. Check the watch is on your '
                    'wrist and heart-rate broadcast is still on.'
                : 'Pair a Wear OS watch, or start a workout with the '
                    '"Simulate heart rate" switch to see live BPM here.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.workout),
              icon: const Icon(Icons.fitness_center),
              label: const Text('Go to Workout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
