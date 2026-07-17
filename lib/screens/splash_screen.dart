import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/nutrition_provider.dart';
import '../providers/sleep_provider.dart';
import '../providers/music_provider.dart';
import '../providers/planning_provider.dart';
import '../providers/news_provider.dart';
import '../providers/user_progress_provider.dart';
import '../providers/notification_provider.dart';
import '../services/notification_service.dart';
import '../services/ai_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  String _status = 'Initializing...';

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() => _status = 'Setting up services...');
      await _initializeServices();

      if (!mounted) return;
      _setupLogoutCallback();

      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;
      await _navigateNext();
    } catch (e) {
      debugPrint('Splash init error: $e');
      if (mounted) {
        await _navigateNext();
      }
    }
  }

  Future<void> _initializeServices() async {
    try {
      await NotificationService().initialize();
      NotificationService().setOnTapCallback(_handleNotificationTap);
      debugPrint('NotificationService initialized');
    } catch (e) {
      debugPrint('NotificationService init failed: $e');
    }

    try {
      await AIService().initialize(model: 'gemini-3.1-flash-lite');
      debugPrint('AIService initialized');
    } catch (e) {
      debugPrint('AIService init failed: $e');
    }
  }

  void _handleNotificationTap(String payload) {
    if (!mounted) return;
    final parts = payload.split('|');
    final type = parts.isNotEmpty ? parts.first : '';

    switch (type) {
      case 'workout_reminder':
        Navigator.pushNamed(context, '/workout');
        break;
      case 'calorie_alert':
      case 'log_reminder_lunch':
      case 'log_reminder_dinner':
        Navigator.pushNamed(context, '/nutrition');
        break;
      case 'sleep_reminder':
        Navigator.pushNamed(context, '/sleep');
        break;
      default:
        Navigator.pushNamed(context, '/home');
        break;
    }
  }

  void _setupLogoutCallback() {
    final auth = context.read<AuthProvider>();
    final workout = context.read<WorkoutProvider>();
    final nutrition = context.read<NutritionProvider>();
    final sleep = context.read<SleepProvider>();
    final music = context.read<MusicProvider>();
    final planning = context.read<PlanningProvider>();
    final news = context.read<NewsProvider>();

    auth.onLogout = () {
      workout.clear();
      nutrition.clear();
      sleep.clear();
      music.clear();
      planning.clear();
      news.clear();
    };
  }

  Future<void> _navigateNext() async {
    final auth = context.read<AuthProvider>();

    if (auth.isInitializing) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
    }

    if (!mounted) return;

    if (auth.user != null) {
      _loadUserData(auth.user!.uid);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _loadUserData(String userId) {
    context.read<WorkoutProvider>().loadDashboardData(userId);
    context.read<NutritionProvider>().loadTodayMeals(userId);
    context.read<NutritionProvider>().loadWeightHistory(userId);
    context.read<SleepProvider>().loadSleepData(userId);
    context.read<PlanningProvider>().loadActivePlan(userId);
    context.read<PlanningProvider>().loadPlans(userId);
    context.read<PlanningProvider>().loadBookmarks(userId);
    context.read<UserProgressProvider>().loadUserProgress(userId);
    _loadAndScheduleNotifications(userId);
  }

  Future<void> _loadAndScheduleNotifications(String userId) async {
    try {
      final notificationProvider = context.read<NotificationProvider>();
      await notificationProvider.loadSettings(userId);
      final settings = notificationProvider.settings;
      if (settings != null && notificationProvider.anyEnabled) {
        await NotificationService().scheduleAllNotifications(settings);
        debugPrint('Notifications scheduled from saved settings');
      }
    } catch (e) {
      debugPrint('Failed to schedule notifications: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFA5B4FC), // 👈 new background color
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ─── App icon (custom) ──────────────────────────
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Image.asset(
                    'lib/assets/icon/app_icon_foreground.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // ─── App name ────────────────────────────────────
              const Text(
                'T&T Fitness',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'AI-Powered Fitness',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 60),
              // ─── Loading indicator ───────────────────────────
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _status,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}