import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/motion_provider.dart';
import '../widgets/custom_header.dart';

class MovementScreen extends StatefulWidget {
  const MovementScreen({super.key});

  @override
  State<MovementScreen> createState() => _MovementScreenState();
}

class _MovementScreenState extends State<MovementScreen> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (await Permission.activityRecognition.isDenied) {
      await Permission.activityRecognition.request();
    }
  }

  @override
  Widget build(BuildContext context) {
    final motion = context.watch<MotionProvider>();
    return Scaffold(
      appBar: null,
      body: SafeArea(
        child: Column(
        children: [
          const CustomHeader(title: 'Movement Tracker', showBack: true),
          Expanded(
            child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.directions_walk, color: Colors.green),
                title: const Text('Steps Today'),
                trailing: Text(
                  '${motion.stepsToday}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.speed, color: Colors.orange),
                title: const Text('Activity Intensity'),
                trailing: Text(
                  '${(motion.motionIntensity * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed:
                    motion.isTracking ? motion.stopTracking : motion.startTracking,
                icon: Icon(motion.isTracking ? Icons.stop : Icons.play_arrow),
                label: Text(motion.isTracking
                    ? 'Stop Tracking'
                    : 'Start Motion Tracking'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    ],
  ),
  ),
);
  }
}
