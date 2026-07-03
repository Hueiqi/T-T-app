import 'package:flutter/material.dart';
import '../config/theme.dart';

class OnboardingGoalScreen extends StatefulWidget {
  const OnboardingGoalScreen({super.key});

  @override
  State<OnboardingGoalScreen> createState() => _OnboardingGoalScreenState();
}

class _OnboardingGoalScreenState extends State<OnboardingGoalScreen> {
  String? _selectedGoal;
  int? _selectedIndex;

  final List<_GoalOption> _goals = [
    _GoalOption(
      value: 'general_fitness',
      title: 'Build Confidence',
      subtitle: 'Feel better, move better, live better',
      icon: Icons.auto_awesome,
      color: const Color(0xFF6C63FF),
    ),
    _GoalOption(
      value: 'lose_weight',
      title: 'Lose Weight',
      subtitle: 'Shed extra pounds and feel lighter',
      icon: Icons.trending_down,
      color: const Color(0xFFFF6584),
    ),
    _GoalOption(
      value: 'build_muscle',
      title: 'Build Muscle',
      subtitle: 'Gain strength and sculpt your body',
      icon: Icons.fitness_center,
      color: const Color(0xFF00B894),
    ),
    _GoalOption(
      value: 'endurance',
      title: 'Increase Endurance',
      subtitle: 'Go further, last longer, never quit',
      icon: Icons.directions_run,
      color: const Color(0xFFFDCB6E),
    ),
    _GoalOption(
      value: 'strength',
      title: 'Get Stronger',
      subtitle: 'Lift heavier and push your limits',
      icon: Icons.bolt,
      color: const Color(0xFFE17055),
    ),
  ];

  void _continue() {
    if (_selectedGoal == null) return;
    Navigator.pushNamed(
      context,
      '/onboarding-age',
      arguments: {'goal': _selectedGoal},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: 0.33,
                backgroundColor: Colors.grey.shade200,
                color: AppTheme.primaryColor,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 40),
              Text(
                'What\'s your goal?',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pick what you want to achieve — we\'ll tailor your plan',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView.separated(
                  itemCount: _goals.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final goal = _goals[index];
                    final isSelected = _selectedIndex == index;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                          _selectedGoal = goal.value;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? goal.color.withValues(alpha: 0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? goal.color : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: goal.color.withValues(alpha: 0.15),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? goal.color
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  goal.icon,
                                  color: isSelected
                                      ? Colors.white
                                      : AppTheme.textSecondary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      goal.title,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? goal.color
                                            : AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      goal.subtitle,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: goal.color,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selectedGoal != null ? _continue : null,
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

class _GoalOption {
  final String value;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _GoalOption({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
