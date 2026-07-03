import 'package:flutter/material.dart';
import '../config/theme.dart';

class OnboardingBodyScreen extends StatefulWidget {
  const OnboardingBodyScreen({super.key});

  @override
  State<OnboardingBodyScreen> createState() => _OnboardingBodyScreenState();
}

class _OnboardingBodyScreenState extends State<OnboardingBodyScreen> {
  final _weightController = TextEditingController(text: '65');
  final _heightController = TextEditingController(text: '170');
  double _weight = 65;
  double _height = 170;

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _continue() {
    final args = ModalRoute.of(context)?.settings.arguments is Map
        ? ModalRoute.of(context)!.settings.arguments as Map
        : <String, dynamic>{};

    Navigator.pushNamed(
      context,
      '/onboarding-target',
      arguments: {
        ...args,
        'weight': _weight,
        'height': _height,
      },
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
                value: 0.5,
                backgroundColor: Colors.grey.shade200,
                color: AppTheme.primaryColor,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 40),
              Text(
                'Your body stats',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tell us your weight and height for accurate tracking',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 48),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${_weight.toInt()}',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Weight (kg)',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${_height.toInt()}',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.secondaryColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Height (cm)',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'Weight: ${_weight.toInt()} kg',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              Slider(
                value: _weight,
                min: 30,
                max: 200,
                divisions: 170,
                activeColor: AppTheme.primaryColor,
                inactiveColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                label: '${_weight.toInt()} kg',
                onChanged: (v) {
                  setState(() {
                    _weight = v;
                    _weightController.text = v.toInt().toString();
                  });
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Height: ${_height.toInt()} cm',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              Slider(
                value: _height,
                min: 100,
                max: 220,
                divisions: 120,
                activeColor: AppTheme.secondaryColor,
                inactiveColor: AppTheme.secondaryColor.withValues(alpha: 0.2),
                label: '${_height.toInt()} cm',
                onChanged: (v) {
                  setState(() {
                    _height = v;
                    _heightController.text = v.toInt().toString();
                  });
                },
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                  prefixIcon: Icon(Icons.monitor_weight),
                ),
                onChanged: (v) {
                  final p = double.tryParse(v);
                  if (p != null && p >= 30 && p <= 200) {
                    setState(() => _weight = p);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Height (cm)',
                  prefixIcon: Icon(Icons.height),
                ),
                onChanged: (v) {
                  final p = double.tryParse(v);
                  if (p != null && p >= 100 && p <= 220) {
                    setState(() => _height = p);
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
