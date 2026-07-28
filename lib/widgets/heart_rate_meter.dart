import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/health_provider.dart';
import '../config/theme.dart';


// ─── Live heart rate meter ──────────────────────────────────────
//
// Reads HealthProvider, which defaults to the simulated heart rate when no
// live source (BLE strap / watch sync) is available, so this stays animated
// during a workout instead of sitting on a placeholder value.
class HeartRateMeterCard extends StatelessWidget {
  const HeartRateMeterCard({super.key});

  static const _minBpm = 40.0;
  static const _maxBpm = 200.0;

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthProvider>();
    final bpm = health.currentHeartRate;
    final zone = health.heartRateCategory;
    final color = _zoneColor(zone);
    final fraction =
        ((bpm - _minBpm) / (_maxBpm - _minBpm)).clamp(0.0, 1.0).toDouble();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.favorite, color: color, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Heart Rate',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    zone.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Gauge ──
            SizedBox(
              height: 110,
              width: double.infinity,
              child: CustomPaint(
                painter: _GaugePainter(
                  fraction: fraction,
                  color: color,
                  trackColor: Colors.grey.shade200,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 18),
                      Text(
                        '$bpm',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: color,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        'bpm',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Scale labels + avg ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_minBpm.toInt()}',
                    style: TextStyle(
                        fontSize: 10, color: AppTheme.textSecondary)),
                Text(
                  'avg ${health.averageHeartRate} bpm',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text('${_maxBpm.toInt()}',
                    style: TextStyle(
                        fontSize: 10, color: AppTheme.textSecondary)),
              ],
            ),

            if (health.isSimulating) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline,
                      size: 13, color: AppTheme.textSecondary),
                  const SizedBox(width: 5),
                  Text(
                    'Simulated — connect a strap for live data',
                    style: TextStyle(
                        fontSize: 10.5, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Color _zoneColor(String zone) {
    switch (zone) {
      case 'resting':
        return const Color(0xFF3B82F6);
      case 'light':
        return const Color(0xFF22C55E);
      case 'moderate':
        return const Color(0xFFF59E0B);
      case 'vigorous':
        return const Color(0xFFF97316);
      default:
        return const Color(0xFFEF4444);
    }
  }
}

/// 180° arc gauge with a needle-style cap at the current value.
class _GaugePainter extends CustomPainter {
  final double fraction;
  final Color color;
  final Color trackColor;

  const _GaugePainter({
    required this.fraction,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final radius = (size.width.clamp(0.0, 260.0) / 2) - stroke;
    final center = Offset(size.width / 2, size.height - stroke / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = 3.1415927; // 180° — left side
    const sweepFull = 3.1415927; // half circle

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, sweepFull, false, track);

    final progress = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, sweepFull * fraction, false, progress);

    // Cap dot at the current value
    final angle = startAngle + sweepFull * fraction;
    final dot = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
    canvas.drawCircle(dot, stroke / 2 + 3, Paint()..color = Colors.white);
    canvas.drawCircle(dot, stroke / 2 - 1, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.fraction != fraction || old.color != color;
}
