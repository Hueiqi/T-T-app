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

class FitSyncApp extends StatelessWidget {
  const FitSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'T&T AI',
      debugShowCheckedModeBanner: false,
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
      },
    );
  }
}
