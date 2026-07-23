import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
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
import 'providers/user_progress_provider.dart';
import 'providers/exercise_favorites_provider.dart';
import 'providers/workout_music_provider.dart';

// 👇 Add these imports
import 'spotify/services/auth/auth.dart'; // exports mobile_auth_controller
import 'providers/music_provider.dart';


import 'services/exercise_db.dart';
import 'app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await ExerciseDatabase.load();

  final healthProvider = HealthProvider();
  await healthProvider.initializeHealthAccess();

  // --- Spotify Native Auth ---
  final spotifyAuth = createAuthController();
  await spotifyAuth.init();

  // Create MusicProvider instance manually so we can set the token
  final musicProvider = MusicProvider();

  if (spotifyAuth.status == AuthStatus.authenticated) {
    final token = await spotifyAuth.getValidAccessToken();
    if (token != null) {
      musicProvider.setAccessToken(token);
    }
  }


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
        ChangeNotifierProvider(
          create: (_) => UserProgressProvider()..init(FirebaseAuth.instance),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ExerciseFavoritesProvider>(
          create: (_) => ExerciseFavoritesProvider(),
          update: (_, auth, fav) => fav!..setUserId(auth.user?.uid),
        ),
        ChangeNotifierProvider(create: (_) => WorkoutMusicProvider()),
      ],
      child: const FitSyncApp(),
    ),
  );
}
