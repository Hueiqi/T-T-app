import 'package:flutter/material.dart';
import '../config/theme.dart';

class OnboardingDurationScreen extends StatefulWidget {
  const OnboardingDurationScreen({super.key});

  @override
  State<OnboardingDurationScreen> createState() =>
      _OnboardingDurationScreenState();
}

class _OnboardingDurationScreenState extends State<OnboardingDurationScreen> {
  int _weeks = 12;

  String _formatEndDate(int weeksFromNow) {
    final date = DateTime.now().add(Duration(days: weeksFromNow * 7));
    return '${date.day}/${date.month}/${date.year}';
  }

  String _motivationMessage(String goal) {
    switch (goal) {
      case 'lose_weight':
        return 'Consistency is key. With $_weeks weeks of dedication, you\'ll see amazing results!';
      case 'build_muscle':
        return 'Muscle growth takes time. Stay patient and trust the process for $_weeks weeks!';
      case 'endurance':
        return 'Every workout builds your endurance. $_weeks weeks to a new you!';
      case 'strength':
        return 'Strength comes from persistence. $_weeks weeks to reach new PRs!';
      default:
        return '$_weeks weeks to build a habit that lasts a lifetime!';
    }
  }

  void _continue() {
    final args = ModalRoute.of(context)?.settings.arguments is Map
        ? ModalRoute.of(context)!.settings.arguments as Map
        : <String, dynamic>{};

    final endDate = DateTime.now().add(Duration(days: _weeks * 7));

    Navigator.pushNamed(
      context,
      '/register',
      arguments: {
        ...args,
        'workoutEndDate': endDate.toIso8601String(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments is Map
        ? ModalRoute.of(context)!.settings.arguments as Map
        : <String, dynamic>{};
    final goal = args['goal'] as String? ?? 'general_fitness';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: 0.9,
                backgroundColor: Colors.grey.shade200,
                color: AppTheme.primaryColor,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 40),
              Text(
                'Your timeline',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'How long do you want to reach your goal?',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 48),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$_weeks',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentColor,
                              ),
                            ),
                            Text(
                              'weeks',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Target: ${_formatEndDate(_weeks)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Slider(
                value: _weeks.toDouble(),
                min: 4,
                max: 52,
                divisions: 48,
                activeColor: AppTheme.accentColor,
                inactiveColor: AppTheme.accentColor.withValues(alpha: 0.2),
                label: '$_weeks weeks',
                onChanged: (v) => setState(() => _weeks = v.toInt()),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('4 weeks', style: TextStyle(color: AppTheme.textSecondary)),
                  Text(
                    '12 months',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _motivationMessage(goal),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _continue,
                    child: const Text('Continue'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
