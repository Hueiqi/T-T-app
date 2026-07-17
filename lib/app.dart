import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/workout_screen.dart';
import 'screens/nutrition_screen.dart';
import 'screens/sleep_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/planning_screen.dart';
import 'screens/food_capture_screen.dart';
import 'screens/food_search_screen.dart';
import 'screens/body_statistics_screen.dart';
import 'screens/music_recommendation_screen.dart';
import 'screens/onboarding_goal_screen.dart';
import 'screens/onboarding_age_screen.dart';
import 'screens/onboarding_body_screen.dart';
import 'screens/onboarding_target_screen.dart';
import 'screens/onboarding_plan_screen.dart';
import 'screens/onboarding_duration_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/phone_login_screen.dart';
import 'screens/otp_verification_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/notification_history_screen.dart';
import 'screens/ai_chat_screen.dart';
import 'screens/routine_historyscreen.dart';
import 'screens/movement_screen.dart';
import 'screens/places_screen.dart';
import 'screens/popular_exersive_screen.dart';
import 'screens/routine_detail_screen.dart';
import 'screens/follow_routine_screen.dart';
import 'screens/exercise_library_screen.dart';
import 'spotify/spotify_section.dart';
import 'spotify/services/auth/auth.dart';
import 'spotify/services/playback/playback.dart';
import 'spotify/services/spotify_api.dart';
import 'spotify/state/player_provider.dart';
import 'spotify/widgets/global_mini_player.dart';
import 'screens/workout_music_screen.dart';
import 'screens/watch_heart_rate_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isInitializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (auth.user != null) {
      return const HomeScreen();
    }
    return const LoginScreen();
  }
}

class FitSyncApp extends StatefulWidget {
  const FitSyncApp({super.key});

  @override
  State<FitSyncApp> createState() => _FitSyncAppState();
}

class _FitSyncAppState extends State<FitSyncApp> {
  // App-root Spotify services so playback survives across every screen and
  // the floating mini-player can hover over the fitness parts of the app.
  // Separate from the existing SpotifyService/MusicProvider BPM-matching
  // flow — this powers the standalone Spotify browsing/playback feature
  // (Profile > Spotify, playlist customization) and doesn't touch the
  // existing auto-BPM music during an active workout.
  late final AuthController _spotifyAuth;
  late final SpotifyApi _spotifyApi;
  late final PlayerProvider _spotifyPlayer;

  // Root navigator so the floating player can open the full player screen
  // over whatever route is currently showing.
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _spotifyAuth = createAuthController();
    _spotifyApi = SpotifyApi(_spotifyAuth);
    _spotifyPlayer = PlayerProvider(createPlaybackEngine(_spotifyApi, _spotifyAuth));
    _spotifyAuth.init();
  }

  @override
  void dispose() {
    _spotifyPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: _spotifyAuth),
        Provider<SpotifyApi>.value(value: _spotifyApi),
        ChangeNotifierProvider<PlayerProvider>.value(value: _spotifyPlayer),
      ],
      child: MaterialApp(
      title: 'T&T AI',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      builder: (context, child) => Stack(
        children: [
          ?child,
          GlobalMiniPlayer(navigatorKey: _navigatorKey),
        ],
      ),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const AuthWrapper(),
      routes: {
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.register: (_) => const RegisterScreen(),
        AppRoutes.home: (_) => const HomeScreen(),
        AppRoutes.workout: (_) => const WorkoutScreen(),
        AppRoutes.nutrition: (_) => const NutritionScreen(showBottomNav: true),
        AppRoutes.sleep: (_) => const SleepScreen(),
        AppRoutes.profile: (_) => const ProfileScreen(),
        AppRoutes.foodSearch: (ctx) {
          final mealType =
              ModalRoute.of(ctx)?.settings.arguments as String? ?? 'snack';
          return FoodSearchScreen(mealType: mealType);
        },
        AppRoutes.foodCapture: (_) => const FoodCaptureScreen(),
        AppRoutes.statistics: (_) => const BodyStatisticsScreen(),
        '/music-recommendations': (_) => const MusicRecommendationScreen(),
        AppRoutes.onboardingGoal: (_) => const OnboardingGoalScreen(),
        AppRoutes.onboardingAge: (_) => const OnboardingAgeScreen(),
        AppRoutes.onboardingBody: (_) => const OnboardingBodyScreen(),
        AppRoutes.onboardingTarget: (_) => const OnboardingTargetScreen(),
        AppRoutes.onboardingPlan: (_) => const OnboardingPlanScreen(),
        AppRoutes.onboardingDuration: (_) => const OnboardingDurationScreen(),
        AppRoutes.welcome: (_) => const WelcomeScreen(),
        AppRoutes.forgotPassword: (_) => const ForgotPasswordScreen(),
        AppRoutes.phoneLogin: (_) => const PhoneLoginScreen(),
        AppRoutes.otpVerify: (_) => const OtpVerificationScreen(),
        AppRoutes.notificationSettings: (_) =>
            const NotificationSettingsScreen(),
        AppRoutes.notificationHistory: (_) => const NotificationHistoryScreen(),
        AppRoutes.planning: (_) => const PlanningScreen(),
        AppRoutes.popularWorkouts: (_) => PopularWorkoutsScreen(),
        AppRoutes.movement: (_) => const MovementScreen(),
        AppRoutes.places: (_) => const PlacesScreen(),
        AppRoutes.routineHistory: (_) => const RoutineHistoryScreen(),
        AppRoutes.routineDetail: (ctx) {
          final id = ModalRoute.of(ctx)?.settings.arguments as String? ?? '';
          return RoutineDetailScreen(routineId: id);
        },
        AppRoutes.followRoutine: (ctx) {
          final id = ModalRoute.of(ctx)?.settings.arguments as String? ?? '';
          return FollowRoutineScreen(routineId: id);
        },
        AppRoutes.aiChat: (_) => const AiChatScreen(),
        AppRoutes.exerciseLibrary: (_) => const ExerciseLibraryScreen(),
        AppRoutes.activity: (_) => const RoutineHistoryScreen(),
        AppRoutes.workoutDetail: (_) => const RoutineHistoryScreen(),
        AppRoutes.spotify: (_) => const SpotifySection(),
        AppRoutes.workoutMusic: (_) => const WorkoutMusicScreen(),
        AppRoutes.watchHeartRate: (_) => const WatchHeartRateScreen(),
      },
      ),
    );
  }
}
