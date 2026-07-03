import 'package:flutter/material.dart';
import '../config/theme.dart';

class OnboardingTargetScreen extends StatefulWidget {
  const OnboardingTargetScreen({super.key});

  @override
  State<OnboardingTargetScreen> createState() => _OnboardingTargetScreenState();
}

class _OnboardingTargetScreenState extends State<OnboardingTargetScreen> {
  final _weightController = TextEditingController(text: '70');
  double _targetWeight = 70;

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  void _continue() {
    final args = ModalRoute.of(context)?.settings.arguments is Map
        ? ModalRoute.of(context)!.settings.arguments as Map
        : <String, dynamic>{};

    Navigator.pushNamed(
      context,
      '/onboarding-plan',
      arguments: {
        ...args,
        'targetWeightKg': _targetWeight,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments is Map
        ? ModalRoute.of(context)!.settings.arguments as Map
        : <String, dynamic>{};
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: 0.66,
                backgroundColor: Colors.grey.shade200,
                color: AppTheme.primaryColor,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 40),
              Text(
                'Your target weight',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Set a goal weight so we can track your progress',
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
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${_targetWeight.toInt()}',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'kg',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Text(
                'Your current weight: ${(args['weight'] as num?)?.toInt() ?? 65} kg',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              Slider(
                value: _targetWeight,
                min: 30,
                max: 200,
                divisions: 170,
                activeColor: AppTheme.primaryColor,
                inactiveColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                label: '${_targetWeight.toInt()} kg',
                onChanged: (v) {
                  setState(() => _targetWeight = v);
                },
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '30 kg',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    '200 kg',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Or type your target weight',
                  hintText: 'Enter weight in kg',
                  prefixIcon: const Icon(Icons.monitor_weight),
                  suffixText: 'kg',
                ),
                onChanged: (v) {
                  final parsed = double.tryParse(v);
                  if (parsed != null && parsed >= 30 && parsed <= 200) {
                    setState(() => _targetWeight = parsed);
                  }
                },
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
