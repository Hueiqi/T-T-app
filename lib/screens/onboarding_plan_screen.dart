import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../config/routes.dart';
import '../services/tdee_calculator.dart';

class OnboardingPlanScreen extends StatefulWidget {
  const OnboardingPlanScreen({super.key});

  @override
  State<OnboardingPlanScreen> createState() => _OnboardingPlanScreenState();
}

class _OnboardingPlanScreenState extends State<OnboardingPlanScreen> {
  String _activityLevel = 'moderate';
  String _gender = 'male';
  String _dietPreference = 'none';

  final List<Map<String, String>> _activityLevels = [
    {'value': 'sedentary', 'label': 'Little or no exercise'},
    {'value': 'light', 'label': 'Light exercise 1-3 days/week'},
    {'value': 'moderate', 'label': 'Moderate exercise 3-5 days/week'},
    {'value': 'very_active', 'label': 'Hard exercise 6-7 days/week'},
    {'value': 'extremely_active', 'label': 'Very hard exercise / athlete'},
  ];

  final List<Map<String, String>> _dietPreferences = [
    {'value': 'none', 'label': 'No specific diet'},
    {'value': 'vegetarian', 'label': 'Vegetarian'},
    {'value': 'vegan', 'label': 'Vegan'},
    {'value': 'keto', 'label': 'Ketogenic'},
    {'value': 'paleo', 'label': 'Paleo'},
    {'value': 'mediterranean', 'label': 'Mediterranean'},
    {'value': 'halal', 'label': 'Halal'},
    {'value': 'gluten_free', 'label': 'Gluten-free'},
    {'value': 'low_carb', 'label': 'Low-carb'},
  ];

  Map<String, dynamic> _calculatePlan(Map args) {
    final age = args['age'] as int? ?? 25;
    final weight = (args['weight'] as num?)?.toDouble() ?? 65;
    final height = (args['height'] as num?)?.toDouble() ?? 170;
    final goal = args['goal'] as String? ?? 'general_fitness';
    final isMale = _gender == 'male';

    final result = TDEECalculator.calculateComprehensive(
      age: age,
      weight: weight,
      height: height,
      isMale: isMale,
      activityLevel: _activityLevel,
      fitnessGoal: goal,
    );

    final macros = TDEECalculator.calculateMacros(
      calorieGoal: result['calorieGoal']!,
      fitnessGoal: goal,
    );

    return {
      'bmr': result['bmr']!.toInt(),
      'tdee': result['tdee']!.toInt(),
      'calorieGoal': result['calorieGoal']!.toInt(),
      'protein': macros['protein']!.toInt(),
      'carbs': macros['carbs']!.toInt(),
      'fat': macros['fat']!.toInt(),
    };
  }

  String _goalLabel(String goal) {
    switch (goal) {
      case 'lose_weight':
        return 'Lose Weight';
      case 'build_muscle':
        return 'Build Muscle';
      case 'endurance':
        return 'Increase Endurance';
      case 'strength':
        return 'Get Stronger';
      default:
        return 'Build Confidence';
    }
  }

  String _workoutTip(String goal) {
    switch (goal) {
      case 'lose_weight':
        return 'Cardio + HIIT 4-5x/week\nStrength training 2-3x/week';
      case 'build_muscle':
        return 'Strength training 4-5x/week\nRest days for muscle recovery';
      case 'endurance':
        return 'Long cardio 3-4x/week\nInterval training 2x/week';
      case 'strength':
        return 'Heavy lifting 4x/week\nProgressive overload each week';
      default:
        return 'Mixed workouts 3-4x/week\nFocus on consistency';
    }
  }

  void _continue() {
    final args = ModalRoute.of(context)?.settings.arguments is Map
        ? ModalRoute.of(context)!.settings.arguments as Map
        : <String, dynamic>{};

    Navigator.pushNamed(
      context,
      '/onboarding-duration',
      arguments: {
        ...args,
        'activityLevel': _activityLevel,
        'gender': _gender,
        'dietPreference': _dietPreference,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments is Map
        ? ModalRoute.of(context)!.settings.arguments as Map
        : <String, dynamic>{};
    final plan = _calculatePlan(args);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: 0.8,
                backgroundColor: Colors.grey.shade200,
                color: AppTheme.primaryColor,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 40),
              Text(
                'Your AI Plan',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Based on your info, here\'s your personalized plan',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.primaryColor.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Daily Calorie Goal',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${plan['calorieGoal']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'kcal / day',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _MacroCard(
                              label: 'Protein',
                              value: '${plan['protein']}g',
                              color: const Color(0xFFFF6584),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MacroCard(
                              label: 'Carbs',
                              value: '${plan['carbs']}g',
                              color: const Color(0xFFFDCB6E),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MacroCard(
                              label: 'Fat',
                              value: '${plan['fat']}g',
                              color: const Color(0xFF00B894),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.fitness_center,
                                    color: AppTheme.primaryColor, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Workout Plan',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _MiniStat(
                                  icon: Icons.local_fire_department,
                                  label: 'BMR',
                                  value: '${plan['bmr']}',
                                ),
                                _MiniStat(
                                  icon: Icons.directions_run,
                                  label: 'TDEE',
                                  value: '${plan['tdee']}',
                                ),
                                _MiniStat(
                                  icon: Icons.flag,
                                  label: 'Goal',
                                  value: _goalLabel(
                                    args['goal'] as String? ?? '',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Recommended:',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _workoutTip(args['goal'] as String? ?? ''),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Activity Level',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'How active are you currently?',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...List.generate(_activityLevels.length, (i) {
                              final level = _activityLevels[i];
                              final isSelected = _activityLevel == level['value'];
                              return Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _activityLevel = level['value']!),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppTheme.primaryColor.withValues(alpha: 0.1)
                                          : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelected
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_off,
                                          color: isSelected
                                              ? AppTheme.primaryColor
                                              : AppTheme.textSecondary,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          level['label']!,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: isSelected
                                                ? AppTheme.primaryColor
                                                : AppTheme.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  'Gender:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ChoiceChip(
                                  label: const Text('Male'),
                                  selected: _gender == 'male',
                                  onSelected: (_) =>
                                      setState(() => _gender = 'male'),
                                  selectedColor: AppTheme.primaryColor,
                                  labelStyle: TextStyle(
                                    color: _gender == 'male'
                                        ? Colors.white
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('Female'),
                                  selected: _gender == 'female',
                                  onSelected: (_) =>
                                      setState(() => _gender = 'female'),
                                  selectedColor: AppTheme.primaryColor,
                                  labelStyle: TextStyle(
                                    color: _gender == 'female'
                                        ? Colors.white
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.restaurant,
                                    color: AppTheme.primaryColor, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Diet Preference',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Any dietary restrictions?',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _dietPreferences.map((diet) {
                                final isSelected = _dietPreference == diet['value'];
                                return ChoiceChip(
                                  label: Text(diet['label']!),
                                  selected: isSelected,
                                  onSelected: (_) =>
                                      setState(() => _dietPreference = diet['value']!),
                                  selectedColor: AppTheme.primaryColor,
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.white : null,
                                    fontSize: 13,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _continue,
                          child: const Text('Continue'),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.textSecondary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: 'Planning'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Workout'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant), label: 'Diet'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
              break;
            case 1:
              Navigator.pushNamedAndRemoveUntil(context, AppRoutes.planning, (_) => false);
              break;
            case 2:
              Navigator.pushNamedAndRemoveUntil(context, AppRoutes.workout, (_) => false);
              break;
            case 3:
              Navigator.pushNamedAndRemoveUntil(context, AppRoutes.nutrition, (_) => false);
              break;
            case 4:
              Navigator.pushNamedAndRemoveUntil(context, AppRoutes.profile, (_) => false);
              break;
          }
        },
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
