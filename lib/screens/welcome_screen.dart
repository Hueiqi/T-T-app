import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';
import '../config/routes.dart';
import '../providers/auth_provider.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments is Map
        ? ModalRoute.of(context)!.settings.arguments as Map
        : <String, dynamic>{};
    final name = args['name'] as String? ?? 'there';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.celebration,
                  size: 60,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Welcome, $name!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Enjoy your workout journey!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your personalized AI plan is ready.\nLet\'s get started!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  // Registration ends here, so this is the one moment every
                  // new user passes through: show the guide once, then go to
                  // Home when they finish or skip it.
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final auth = context.read<AuthProvider>();

                    await navigator.pushNamed(AppRoutes.userGuide);

                    // The guide already covers what the live Quick Tour
                    // shows, so mark the tour as seen — without this it
                    // auto-starts on Home seconds later and the user gets two
                    // walkthroughs back to back. Still available on demand
                    // from the ? button on Home.
                    try {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('quick_tour_done', true);
                      if (auth.user != null) {
                        await auth.updateProfile(
                          auth.user!.copyWith(hasSeenQuickTour: true),
                        );
                      }
                    } catch (_) {
                      // Never block reaching Home over a preference write.
                    }

                    navigator.pushReplacementNamed('/home');
                  },
                  child: const Text('Start Your Journey'),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tip: Use the bottom menu to navigate\nWorkout, Diet, Sleep & Profile',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
