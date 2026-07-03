import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/planning_model.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';

import '../config/api_keys.dart';

class PlanningProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  static const String _apiKey = ApiKeys.groq;
  static const String _apiUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  List<FitnessPlan> _plans = [];
  FitnessPlan? _selectedPlan;
  FitnessPlan? _activePlan;
  bool _isGenerating = false;
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> _bookmarkedWorkouts = [];
  DateTime? _planStartDate;

  List<FitnessPlan> get plans => _plans;
  FitnessPlan? get selectedPlan => _selectedPlan;
  FitnessPlan? get activePlan => _activePlan;
  bool get isGenerating => _isGenerating;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get bookmarkedWorkouts => _bookmarkedWorkouts;
  DateTime? get planStartDate => _planStartDate;

  int get currentWeek {
    final target = _activePlan ?? _selectedPlan;
    if (_planStartDate == null || target == null) return 1;
    final weeksSince = DateTime.now().difference(_planStartDate!).inDays ~/ 7;
    return (weeksSince + 1).clamp(1, target.estimatedGoalWeeks);
  }

  bool isBookmarked(String workoutId) =>
      _bookmarkedWorkouts.any((w) => w['id'] == workoutId);

  Future<void> loadBookmarks(String userId) async {
    _bookmarkedWorkouts = await _firebaseService.getBookmarks(userId);
    notifyListeners();
  }

  Future<void> toggleBookmark(String userId, Map<String, dynamic> workout) async {
    final id = workout['id'] as String;
    if (isBookmarked(id)) {
      _bookmarkedWorkouts.removeWhere((w) => w['id'] == id);
      await _firebaseService.removeBookmark(userId, id);
    } else {
      _bookmarkedWorkouts.add(workout);
      await _firebaseService.saveBookmark(userId, workout);
    }
    notifyListeners();
  }

  Future<void> loadActivePlan(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final user = await _firebaseService.getUser(userId);
      if (user?.selectedPlanId != null) {
        final plan =
            await _firebaseService.getPlanById(userId, user!.selectedPlanId!);
        _activePlan = plan;
        _planStartDate ??= DateTime.now();
      } else {
        _activePlan = null;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectPlan(String planId, String userId) async {
    _selectedPlan = _plans.firstWhere((p) => p.id == planId);
    _plans = _plans.map((p) => p.copyWith(isSelected: p.id == planId)).toList();
    _planStartDate ??= DateTime.now();
    _activePlan = _selectedPlan;
    await _firebaseService.savePlan(userId, _selectedPlan!);
    notifyListeners();
  }

  Future<void> abortPlan() async {
    _activePlan = null;
    _selectedPlan = null;
    _planStartDate = null;
    notifyListeners();
  }

  Future<void> loadPlans(String userId) async {
    final saved = await _firebaseService.getPlans(userId);
    if (saved.isNotEmpty) {
      _plans = saved;
      _selectedPlan = saved.cast<FitnessPlan?>().firstWhere(
            (p) => p!.isSelected,
            orElse: () => null,
          );
      notifyListeners();
    }
  }

  Future<void> updatePlan(String userId, FitnessPlan plan) async {
    final index = _plans.indexWhere((p) => p.id == plan.id);
    if (index == -1) return;
    _plans[index] = plan;
    if (_selectedPlan?.id == plan.id) {
      _selectedPlan = plan;
    }
    notifyListeners();
    await _firebaseService.savePlan(userId, plan);
  }

  void clearSelection() {
    _selectedPlan = null;
    _activePlan = null;
    _planStartDate = null;
    _plans = _plans.map((p) => p.copyWith(isSelected: false)).toList();
    notifyListeners();
  }

  Future<void> generatePlans(AppUser user) async {
    _isGenerating = true;
    _error = null;
    _plans = [];
    _selectedPlan = null;
    notifyListeners();

    try {
      final response = await _callGroqApi(user);
      _plans = response;
      for (final plan in _plans) {
        await _firebaseService.savePlan(user.uid, plan);
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _plans = _fallbackPlans(user);
      notifyListeners();
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  Future<List<FitnessPlan>> _callGroqApi(AppUser user) async {
    const maxRetries = 2;
    for (int i = 0; i <= maxRetries; i++) {
      try {
        return await _callGroqApiOnce(user);
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('429') && i < maxRetries) {
          await Future.delayed(Duration(seconds: (i + 1) * 2));
          continue;
        }
        rethrow;
      }
    }
    throw Exception('Max retries exceeded');
  }

  Future<List<FitnessPlan>> _callGroqApiOnce(AppUser user) async {
    final systemPrompt = _buildSystemPrompt(user);

    final body = jsonEncode({
      'model': _model,
      'messages': [
        {
          'role': 'system',
          'content': systemPrompt,
        },
        {
          'role': 'user',
          'content':
              'Generate 4 personalized fitness plans for me based on my profile above. Return only valid JSON.',
        },
      ],
      'response_format': {'type': 'json_object'},
      'temperature': 0.7,
      'max_tokens': 3000,
    });

    final response = await http
        .post(
          Uri.parse(_apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return _parsePlansResponse(data);
  }

  String _buildSystemPrompt(AppUser user) {
    final goalLabels = {
      'lose_weight': 'lose weight',
      'build_muscle': 'build muscle',
      'general_fitness': 'improve general fitness',
      'endurance': 'build endurance',
    };

    final goal = goalLabels[user.fitnessGoal] ?? 'improve fitness';
    final bmi = user.bmi.toStringAsFixed(1);

    return '''You are an expert fitness and nutrition planner. Generate a JSON response with exactly 4 different personalized fitness plans for a user with this profile:

Profile:
- Age: ${user.age}
- Weight: ${user.weight} kg
- Height: ${user.height} cm
- BMI: $bmi
- Goal: $goal
${user.targetWeightKg != null ? '- Target Weight: ${user.targetWeightKg} kg' : ''}
${user.dailyCalorieTarget != null ? '- Daily Calorie Target: ${user.dailyCalorieTarget!.toInt()} kcal' : ''}

The 4 plans should have different approaches:
1. An "intensive" high-intensity plan for fastest results (aggressive)
2. A "balanced" moderate plan for steady progress
3. A "gentle" low-intensity sustainable plan
4. A "custom" plan tailored specifically to their goal

Return ONLY valid JSON with this exact structure. No markdown, no explanation:
{
  "plans": [
    {
      "title": "Plan name with emoji",
      "tagline": "Short catchy description",
      "difficulty": "beginner/intermediate/advanced",
      "description": "2-3 sentence detailed description of what this plan offers",
      "daily_calories": 2000,
      "protein_g": 150,
      "carbs_g": 200,
      "fat_g": 50,
      "workout_style": "e.g., HIIT + Strength Training",
      "workouts_per_week": 5,
      "workout_duration_minutes": 45,
      "sample_exercises": ["Exercise 1", "Exercise 2", "Exercise 3"],
      "meal_tips": ["Tip 1", "Tip 2", "Tip 3"],
      "highlights": ["Key benefit 1", "Key benefit 2", "Key benefit 3"],
      "intensity": "high/medium/low",
      "estimated_goal_weeks": 12,
      "sleep_hours": 8,
      "sleep_bedtime": "10:00 PM",
      "daily_schedule": [
        {"time": "7:00 AM", "title": "Morning Routine", "description": "Wake up, hydrate, light stretch", "type": "general"},
        {"time": "8:00 AM", "title": "Breakfast", "description": "High protein meal", "type": "meal"},
        {"time": "12:00 PM", "title": "Lunch", "description": "Balanced meal with lean protein", "type": "meal"},
        {"time": "5:00 PM", "title": "Workout", "description": "Training session", "type": "workout"},
        {"time": "7:00 PM", "title": "Dinner", "description": "Light dinner with veggies", "type": "meal"},
        {"time": "9:30 PM", "title": "Wind Down", "description": "No screens, read or meditate", "type": "general"},
        {"time": "10:00 PM", "title": "Sleep", "description": "Rest and recovery", "type": "sleep"}
      ],
      "meals": [
        {"meal": "Breakfast", "time": "8:00 AM", "description": "Oatmeal with protein powder and berries", "calories": 400, "options": ["Option 1", "Option 2"]},
        {"meal": "Lunch", "time": "12:00 PM", "description": "Grilled chicken salad with quinoa", "calories": 550, "options": ["Option 1", "Option 2"]},
        {"meal": "Snack", "time": "3:30 PM", "description": "Greek yogurt with nuts", "calories": 250, "options": ["Option 1", "Option 2"]},
        {"meal": "Dinner", "time": "7:00 PM", "description": "Salmon with roasted vegetables", "calories": 500, "options": ["Option 1", "Option 2"]}
      ],
      "weekly_workouts": [
        {"day": "Monday", "focus": "Upper Body", "duration_minutes": 45, "exercises": ["Exercise 1", "Exercise 2", "Exercise 3"]},
        {"day": "Tuesday", "focus": "Cardio", "duration_minutes": 30, "exercises": ["Exercise 1", "Exercise 2"]}
      ]
    }
  ]
}

Make calorie and macro targets realistic and personalized. Ensure daily_schedule times make sense with the meals. Only return valid JSON.''';
  }

  List<FitnessPlan> _parsePlansResponse(Map<String, dynamic> data) {
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('No response from AI');
    }

    final message = choices[0]['message'] as Map?;
    if (message == null) throw Exception('Invalid response format');

    final content = message['content'] as String?;
    if (content == null || content.isEmpty) {
      throw Exception('Empty response');
    }

    final parsed = jsonDecode(content) as Map<String, dynamic>;
    final plansJson = parsed['plans'] as List<dynamic>?;
    if (plansJson == null || plansJson.isEmpty) {
      throw Exception('No plans generated');
    }

    final plans = <FitnessPlan>[];
    for (int i = 0; i < plansJson.length; i++) {
      plans.add(
        FitnessPlan.fromJson(
          plansJson[i] as Map<String, dynamic>,
          'plan_$i',
        ),
      );
    }
    return plans;
  }

  List<FitnessPlan> _fallbackPlans(AppUser user) {
    final isLoseWeight = user.fitnessGoal == 'lose_weight';
    final isBuildMuscle = user.fitnessGoal == 'build_muscle';
    final baseCalories = user.dailyCalorieTarget?.toInt() ?? 2200;

    return [
      FitnessPlan(
        id: 'plan_0',
        title: '⚡ Intensive Transformation',
        tagline: 'Fastest results with maximum effort',
        difficulty: 'advanced',
        description: isLoseWeight
            ? 'Aggressive calorie deficit combined with high-intensity workouts for rapid fat loss.'
            : isBuildMuscle
                ? 'Intense progressive overload training with a caloric surplus for maximum muscle gain.'
                : 'High-intensity full-body workouts with strict nutrition for rapid fitness gains.',
        dailyCalories: isLoseWeight ? baseCalories - 500 : baseCalories + 300,
        proteinG: isBuildMuscle ? 180 : 140,
        carbsG: isLoseWeight ? 150 : 250,
        fatG: 45,
        workoutStyle: 'HIIT + Strength Training',
        workoutsPerWeek: 6,
        workoutDurationMinutes: 50,
        sampleExercises: [
          'Burpees',
          'Deadlifts',
          'Box Jumps',
          'Battle Ropes',
          'Pull-ups',
        ],
        mealTips: [
          'Meal prep all meals on Sunday',
          'Eat every 3 hours',
          'No processed foods or sugar',
        ],
        highlights: [
          'Fastest results',
          'Maximum calorie burn',
          'Builds discipline',
        ],
        intensity: 'high',
        estimatedGoalWeeks: isLoseWeight ? 8 : 10,
        sleepHours: 8,
        sleepBedtime: '9:30 PM',
        dailySchedule: [
          DailyActivity(time: '6:00 AM', title: 'Wake Up', description: 'Drink water with lemon, light stretching', type: 'general'),
          DailyActivity(time: '6:30 AM', title: 'Morning Cardio', description: '20-min fasted cardio', type: 'workout'),
          DailyActivity(time: '7:30 AM', title: 'Breakfast', description: 'High-protein breakfast', type: 'meal'),
          DailyActivity(time: '12:00 PM', title: 'Lunch', description: 'Lean protein + complex carbs', type: 'meal'),
          DailyActivity(time: '4:00 PM', title: 'Main Workout', description: 'Strength training session', type: 'workout'),
          DailyActivity(time: '6:30 PM', title: 'Dinner', description: 'High protein, moderate carbs', type: 'meal'),
          DailyActivity(time: '9:00 PM', title: 'Wind Down', description: 'No screens, meditation', type: 'general'),
          DailyActivity(time: '9:30 PM', title: 'Sleep', description: 'Full recovery sleep', type: 'sleep'),
        ],
        meals: [
          MealPlan(meal: 'Breakfast', time: '7:30 AM', description: 'Egg whites, oatmeal, banana', calories: 400, options: ['Scrambled eggs + oats', 'Protein smoothie']),
          MealPlan(meal: 'Lunch', time: '12:00 PM', description: 'Grilled chicken, brown rice, broccoli', calories: 550, options: ['Chicken bowl', 'Turkey wrap']),
          MealPlan(meal: 'Snack', time: '3:30 PM', description: 'Protein shake + almonds', calories: 250, options: ['Whey shake', 'Greek yogurt']),
          MealPlan(meal: 'Dinner', time: '6:30 PM', description: 'Salmon, sweet potato, asparagus', calories: 500, options: ['Salmon plate', 'Lean beef bowl']),
        ],
        weeklyWorkouts: [
          WorkoutDay(day: 'Monday', focus: 'Chest & Triceps', durationMinutes: 50, exercises: ['Bench Press', 'Incline Dumbbell', 'Tricep Pushdowns', 'Dips']),
          WorkoutDay(day: 'Tuesday', focus: 'Cardio & Core', durationMinutes: 40, exercises: ['HIIT Sprints', 'Planks', 'Russian Twists', 'Mountain Climbers']),
          WorkoutDay(day: 'Wednesday', focus: 'Back & Biceps', durationMinutes: 50, exercises: ['Deadlifts', 'Pull-ups', 'Barbell Rows', 'Curls']),
          WorkoutDay(day: 'Thursday', focus: 'HIIT Cardio', durationMinutes: 35, exercises: ['Burpees', 'Box Jumps', 'Battle Ropes', 'Sprint Intervals']),
          WorkoutDay(day: 'Friday', focus: 'Leg Day', durationMinutes: 50, exercises: ['Squats', 'Lunges', 'Leg Press', 'Calf Raises']),
          WorkoutDay(day: 'Saturday', focus: 'Full Body', durationMinutes: 45, exercises: ['Compound Circuit', 'Kettlebell Swings', 'Push Press', 'Rows']),
        ],
      ),
      FitnessPlan(
        id: 'plan_1',
        title: '⚖️ Balanced Lifestyle',
        tagline: 'Steady progress, sustainable habits',
        difficulty: 'intermediate',
        description: isLoseWeight
            ? 'Moderate calorie deficit with a mix of cardio and strength training for steady fat loss.'
            : isBuildMuscle
                ? 'Well-rounded strength program with adequate nutrition for consistent muscle growth.'
                : 'A balanced mix of cardio, strength, and flexibility training for overall fitness.',
        dailyCalories: isLoseWeight ? baseCalories - 300 : baseCalories + 150,
        proteinG: 120,
        carbsG: 200,
        fatG: 55,
        workoutStyle: 'Mixed Cardio + Weights',
        workoutsPerWeek: 4,
        workoutDurationMinutes: 40,
        sampleExercises: ['Squats', 'Push-ups', 'Running', 'Rows', 'Planks'],
        mealTips: [
          'Follow 80/20 rule',
          'Include protein with every meal',
          'Stay hydrated',
        ],
        highlights: [
          'Sustainable long-term',
          'Good variety',
          'Flexible diet',
        ],
        intensity: 'medium',
        estimatedGoalWeeks: 12,
        sleepHours: 8,
        sleepBedtime: '10:00 PM',
        dailySchedule: [
          DailyActivity(time: '7:00 AM', title: 'Wake Up', description: 'Hydrate, light stretch, plan day', type: 'general'),
          DailyActivity(time: '8:00 AM', title: 'Breakfast', description: 'Balanced breakfast', type: 'meal'),
          DailyActivity(time: '12:30 PM', title: 'Lunch', description: 'Protein-rich lunch', type: 'meal'),
          DailyActivity(time: '5:30 PM', title: 'Workout', description: 'Mixed cardio + weights', type: 'workout'),
          DailyActivity(time: '7:00 PM', title: 'Dinner', description: 'Light balanced dinner', type: 'meal'),
          DailyActivity(time: '9:30 PM', title: 'Wind Down', description: 'Read, stretch, prepare for bed', type: 'general'),
          DailyActivity(time: '10:00 PM', title: 'Sleep', description: 'Rest and recovery', type: 'sleep'),
        ],
        meals: [
          MealPlan(meal: 'Breakfast', time: '8:00 AM', description: 'Whole grain toast, eggs, fruit', calories: 380, options: ['Avocado toast + eggs', 'Oatmeal + berries']),
          MealPlan(meal: 'Lunch', time: '12:30 PM', description: 'Mixed protein bowl with veggies', calories: 500, options: ['Quinoa bowl', 'Whole grain wrap']),
          MealPlan(meal: 'Snack', time: '4:00 PM', description: 'Fruit + nuts', calories: 200, options: ['Apple + peanut butter', 'Berries + yogurt']),
          MealPlan(meal: 'Dinner', time: '7:00 PM', description: 'Lean protein + vegetables', calories: 450, options: ['Grilled fish + salad', 'Chicken stir-fry']),
        ],
        weeklyWorkouts: [
          WorkoutDay(day: 'Monday', focus: 'Upper Body', durationMinutes: 40, exercises: ['Bench Press', 'Rows', 'Shoulder Press', 'Curls']),
          WorkoutDay(day: 'Wednesday', focus: 'Cardio', durationMinutes: 35, exercises: ['Jogging 5K', 'Jump Rope', 'Rowing Machine', 'Cycling']),
          WorkoutDay(day: 'Friday', focus: 'Lower Body', durationMinutes: 40, exercises: ['Squats', 'Deadlifts', 'Lunges', 'Calf Raises']),
          WorkoutDay(day: 'Saturday', focus: 'Full Body + Core', durationMinutes: 35, exercises: ['Circuit Training', 'Planks', 'Yoga Flow', 'Stretching']),
        ],
      ),
      FitnessPlan(
        id: 'plan_2',
        title: '🌱 Gentle Start',
        tagline: 'Easy entry, lasting habits',
        difficulty: 'beginner',
        description: isLoseWeight
            ? 'Small calorie deficit with low-impact activities for gradual, comfortable weight loss.'
            : isBuildMuscle
                ? 'Foundation-building strength work with basic compound lifts and proper form focus.'
                : 'Beginner-friendly activities to build consistency and establish healthy habits.',
        dailyCalories: isLoseWeight ? baseCalories - 150 : baseCalories,
        proteinG: 100,
        carbsG: 220,
        fatG: 60,
        workoutStyle: 'Walking + Bodyweight',
        workoutsPerWeek: 3,
        workoutDurationMinutes: 30,
        sampleExercises: [
          'Brisk Walking',
          'Bodyweight Squats',
          'Wall Push-ups',
          'Stretching',
          'Yoga',
        ],
        mealTips: [
          'Start with breakfast improvements',
          'Reduce portion sizes',
          'Add vegetables to every meal',
        ],
        highlights: [
          'Very sustainable',
          'Low injury risk',
          'Builds confidence',
        ],
        intensity: 'low',
        estimatedGoalWeeks: 16,
        sleepHours: 9,
        sleepBedtime: '10:30 PM',
        dailySchedule: [
          DailyActivity(time: '7:30 AM', title: 'Wake Up', description: 'Wake up naturally, hydrate', type: 'general'),
          DailyActivity(time: '8:30 AM', title: 'Breakfast', description: 'Simple healthy breakfast', type: 'meal'),
          DailyActivity(time: '9:00 AM', title: 'Morning Walk', description: '15-20 min walk', type: 'workout'),
          DailyActivity(time: '1:00 PM', title: 'Lunch', description: 'Light nutritious lunch', type: 'meal'),
          DailyActivity(time: '6:00 PM', title: 'Evening Exercise', description: 'Bodyweight + stretching', type: 'workout'),
          DailyActivity(time: '7:30 PM', title: 'Dinner', description: 'Light dinner', type: 'meal'),
          DailyActivity(time: '10:00 PM', title: 'Wind Down', description: 'Relax, no screens', type: 'general'),
          DailyActivity(time: '10:30 PM', title: 'Sleep', description: 'Full night rest', type: 'sleep'),
        ],
        meals: [
          MealPlan(meal: 'Breakfast', time: '8:30 AM', description: 'Simple oatmeal or toast with fruit', calories: 300, options: ['Oatmeal + banana', 'Toast + peanut butter']),
          MealPlan(meal: 'Lunch', time: '1:00 PM', description: 'Light sandwich or salad', calories: 450, options: ['Turkey sandwich', 'Garden salad + protein']),
          MealPlan(meal: 'Snack', time: '4:00 PM', description: 'Fresh fruit or veggies', calories: 150, options: ['Apple', 'Carrot sticks + hummus']),
          MealPlan(meal: 'Dinner', time: '7:30 PM', description: 'Simple home-cooked meal', calories: 400, options: ['Grilled chicken + veggies', 'Fish + rice']),
        ],
        weeklyWorkouts: [
          WorkoutDay(day: 'Monday', focus: 'Full Body Basics', durationMinutes: 30, exercises: ['Brisk Walk', 'Bodyweight Squats', 'Wall Push-ups', 'Cat-Cow Stretch']),
          WorkoutDay(day: 'Wednesday', focus: 'Cardio Light', durationMinutes: 25, exercises: ['Brisk Walk', 'Jumping Jacks', 'March in Place', 'Arm Circles']),
          WorkoutDay(day: 'Friday', focus: 'Flexibility', durationMinutes: 30, exercises: ['Yoga Flow', 'Stretching Routine', 'Deep Breathing', 'Meditation']),
        ],
      ),
      FitnessPlan(
        id: 'plan_3',
        title: isBuildMuscle
            ? '💪 Muscle Builder Pro'
            : isLoseWeight
                ? '🔥 Fat Burner Focus'
                : '🎯 Goal Crusher',
        tagline: isBuildMuscle
            ? 'Optimized for muscle growth'
            : isLoseWeight
                ? 'Targeted fat loss strategy'
                : 'Customized for your goals',
        difficulty: 'intermediate',
        description: isBuildMuscle
            ? 'Specialized hypertrophy program with progressive overload and targeted nutrition for muscle growth.'
            : isLoseWeight
                ? 'Strategic calorie cycling with metabolic conditioning to maximize fat oxidation.'
                : 'Purpose-built plan combining the best elements for your specific fitness goal.',
        dailyCalories: isBuildMuscle
            ? baseCalories + 400
            : isLoseWeight
                ? baseCalories - 400
                : baseCalories + 100,
        proteinG: isBuildMuscle ? 200 : 130,
        carbsG: isBuildMuscle ? 280 : 170,
        fatG: isBuildMuscle ? 50 : 50,
        workoutStyle: isBuildMuscle
            ? 'Progressive Overload Split'
            : 'Metabolic Conditioning',
        workoutsPerWeek: 5,
        workoutDurationMinutes: 45,
        sampleExercises: isBuildMuscle
            ? ['Bench Press', 'Squats', 'Deadlifts', 'Pull-ups', 'OHP']
            : ['Jump Rope', 'Kettlebell Swings', 'Rowing', 'Mountain Climbers', 'Burpees'],
        mealTips: isBuildMuscle
            ? [
                'Eat in caloric surplus',
                'Post-workout protein shake',
                'Carbs around workouts',
              ]
            : [
                'Intermittent fasting option',
                'Green tea with meals',
                'Avoid liquid calories',
              ],
        highlights: isBuildMuscle
            ? ['Maximum hypertrophy', 'Strength gains', 'Targeted nutrition']
            : ['Efficient fat burn', 'Metabolism boost', 'Quick results'],
        intensity: 'high',
        estimatedGoalWeeks: isBuildMuscle ? 10 : 8,
        sleepHours: 8,
        sleepBedtime: '9:45 PM',
        dailySchedule: [
          DailyActivity(time: '6:30 AM', title: 'Wake Up', description: 'Hydrate, light mobility work', type: 'general'),
          DailyActivity(time: '7:00 AM', title: 'Breakfast', description: isBuildMuscle ? 'High carb/protein breakfast' : 'Light protein breakfast', type: 'meal'),
          DailyActivity(time: '12:00 PM', title: 'Lunch', description: 'Targeted macro lunch', type: 'meal'),
          DailyActivity(time: '4:30 PM', title: 'Workout', description: isBuildMuscle ? 'Strength training' : 'Metabolic conditioning', type: 'workout'),
          DailyActivity(time: '6:30 PM', title: 'Dinner', description: 'Recovery meal', type: 'meal'),
          DailyActivity(time: '9:15 PM', title: 'Wind Down', description: 'Stretch, plan tomorrow', type: 'general'),
          DailyActivity(time: '9:45 PM', title: 'Sleep', description: 'Deep recovery sleep', type: 'sleep'),
        ],
        meals: isBuildMuscle
            ? [
                MealPlan(meal: 'Breakfast', time: '7:00 AM', description: 'Eggs, oatmeal, banana, protein shake', calories: 600, options: ['Mass gainer smoothie', 'Egg + oat bowl']),
                MealPlan(meal: 'Lunch', time: '12:00 PM', description: 'Chicken, rice, veggies, avocado', calories: 700, options: ['Chicken rice bowl', 'Beef + potato']),
                MealPlan(meal: 'Snack', time: '3:30 PM', description: 'Pre-workout: banana + PB', calories: 350, options: ['Rice cakes + PB', 'Fruit + whey']),
                MealPlan(meal: 'Dinner', time: '6:30 PM', description: 'Steak, sweet potato, greens', calories: 650, options: ['Beef bowl', 'Salmon plate']),
              ]
            : [
                MealPlan(meal: 'Breakfast', time: '7:00 AM', description: 'Egg whites, grapefruit, green tea', calories: 300, options: ['Egg white omelette', 'Protein smoothie']),
                MealPlan(meal: 'Lunch', time: '12:00 PM', description: 'Lean protein + large salad', calories: 450, options: ['Grilled chicken salad', 'Turkey lettuce wraps']),
                MealPlan(meal: 'Snack', time: '3:30 PM', description: 'Celery + almond butter', calories: 200, options: ['Veggie sticks', 'Protein water']),
                MealPlan(meal: 'Dinner', time: '6:30 PM', description: 'Fish + steamed vegetables', calories: 400, options: ['Grilled fish + greens', 'Chicken + broccoli']),
              ],
        weeklyWorkouts: isBuildMuscle
            ? [
                WorkoutDay(day: 'Monday', focus: 'Chest & Triceps', durationMinutes: 50, exercises: ['Barbell Bench Press', 'Incline Dumbbell Press', 'Cable Flyes', 'Tricep Pushdowns']),
                WorkoutDay(day: 'Tuesday', focus: 'Back & Biceps', durationMinutes: 50, exercises: ['Deadlifts', 'Pull-ups', 'Barbell Rows', 'Dumbbell Curls']),
                WorkoutDay(day: 'Wednesday', focus: 'Shoulders & Abs', durationMinutes: 45, exercises: ['OHP', 'Lateral Raises', 'Face Pulls', 'Planks']),
                WorkoutDay(day: 'Thursday', focus: 'Rest/Active Recovery', durationMinutes: 20, exercises: ['Light Cardio', 'Stretching', 'Foam Rolling']),
                WorkoutDay(day: 'Friday', focus: 'Leg Day', durationMinutes: 55, exercises: ['Barbell Squats', 'Romanian Deadlifts', 'Leg Press', 'Calf Raises']),
                WorkoutDay(day: 'Saturday', focus: 'Arms & Core', durationMinutes: 40, exercises: ['EZ Bar Curls', 'Skull Crushers', 'Hammer Curls', 'Ab Wheel']),
              ]
            : [
                WorkoutDay(day: 'Monday', focus: 'HIIT Cardio', durationMinutes: 35, exercises: ['Jump Rope Intervals', 'Burpees', 'Kettlebell Swings', 'Mountain Climbers']),
                WorkoutDay(day: 'Tuesday', focus: 'Full Body Circuit', durationMinutes: 40, exercises: ['Circuit: Squats, Push-ups, Rows', 'Box Jumps', 'Plank to Row', 'Battleropes']),
                WorkoutDay(day: 'Wednesday', focus: 'LISS Cardio', durationMinutes: 45, exercises: ['Incline Walking', 'Cycling', 'Rowing Steady State', 'Swimming']),
                WorkoutDay(day: 'Thursday', focus: 'HIIT Cardio', durationMinutes: 35, exercises: ['Sprint Intervals', 'Jump Squats', 'Battle Ropes', 'Slams']),
                WorkoutDay(day: 'Friday', focus: 'Metabolic Circuit', durationMinutes: 40, exercises: ['Kettlebell Complex', 'Medicine Ball Slams', 'Rowing Sprints', 'Farmer Walks']),
              ],
      ),
    ];
  }
}
