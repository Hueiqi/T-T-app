import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/workout_provider.dart';
import 'providers/nutrition_provider.dart';
import 'providers/sleep_provider.dart';
import 'providers/music_provider.dart';
import 'providers/planning_provider.dart';
import 'providers/motion_provider.dart';
import 'providers/place_provider.dart';
import 'providers/news_provider.dart';
import 'providers/health_provider.dart';
import 'providers/notification_provider.dart';
import 'services/exercise_db.dart';
import 'services/ai_service.dart';
import 'app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await ExerciseDatabase.load();
  await AIService().initialize();

  final healthProvider = HealthProvider();
  await healthProvider.initializeHealthAccess();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WorkoutProvider()),
        ChangeNotifierProvider(create: (_) => NutritionProvider()),
        ChangeNotifierProvider(create: (_) => SleepProvider()),
        ChangeNotifierProvider(create: (_) => MusicProvider()),
        ChangeNotifierProvider(create: (_) => healthProvider),
        ChangeNotifierProvider(create: (_) => PlanningProvider()),
        ChangeNotifierProvider(create: (_) => MotionProvider()),
        ChangeNotifierProvider(create: (_) => PlaceProvider()),
        ChangeNotifierProvider(create: (_) => NewsProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const FitSyncApp(),
    ),
  );
}
