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

  void clear() {
    _plans = [];
    _selectedPlan = null;
    _activePlan = null;
    _isGenerating = false;
    _isLoading = false;
    _error = null;
    _bookmarkedWorkouts = [];
    _planStartDate = null;
    notifyListeners();
  }

  Future<void> generatePlans(AppUser user, {double? averageSleepHours}) async {
    _isGenerating = true;
    _error = null;
    _plans = [];
    _selectedPlan = null;
    notifyListeners();

    try {
      final response = await _callGroqApi(user, averageSleepHours: averageSleepHours);
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

  Future<List<FitnessPlan>> _callGroqApi(AppUser user, {double? averageSleepHours}) async {
    const maxRetries = 2;
    for (int i = 0; i <= maxRetries; i++) {
      try {
        return await _callGroqApiOnce(user, averageSleepHours: averageSleepHours);
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

  Future<List<FitnessPlan>> _callGroqApiOnce(AppUser user, {double? averageSleepHours}) async {
    final systemPrompt = _buildSystemPrompt(user, averageSleepHours: averageSleepHours);

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

  String _buildSystemPrompt(AppUser user, {double? averageSleepHours}) {
    final goalLabels = {
      'lose_weight': 'lose weight',
      'build_muscle': 'build muscle',
      'general_fitness': 'improve general fitness',
      'endurance': 'build endurance',
      'strength': 'increase strength',
    };

    final activityLabels = {
      'sedentary': 'Sedentary (little or no exercise)',
      'light': 'Lightly active (light exercise 1-3 days/week)',
      'moderate': 'Moderately active (moderate exercise 3-5 days/week)',
      'very_active': 'Very active (hard exercise 6-7 days/week)',
      'extremely_active': 'Extremely active (very hard exercise / athlete)',
    };

    final dietLabels = {
      'none': 'No specific diet preference',
      'vegetarian': 'Vegetarian (no meat, eggs/dairy OK)',
      'vegan': 'Vegan (no animal products)',
      'keto': 'Ketogenic (high fat, very low carb)',
      'paleo': 'Paleo (whole foods, no grains/processed)',
      'mediterranean': 'Mediterranean diet',
      'halal': 'Halal diet',
      'gluten_free': 'Gluten-free diet',
      'low_carb': 'Low-carb diet',
    };

    final goal = goalLabels[user.fitnessGoal] ?? 'improve fitness';
    final activity = activityLabels[user.activityLevel] ?? user.activityLevel;
    final diet = dietLabels[user.dietPreference] ?? user.dietPreference;
    final bmi = user.bmi.toStringAsFixed(1);
    final weightDiff = user.targetWeightKg != null
        ? (user.weight - user.targetWeightKg!).toStringAsFixed(1)
        : null;
    final weightDirection = weightDiff != null
        ? (double.parse(weightDiff) > 0 ? 'lose' : 'gain')
        : null;
    final absWeightDiff = weightDiff != null ? double.parse(weightDiff).abs().toStringAsFixed(1) : null;

    String timelineInfo = '';
    if (user.workoutEndDate != null) {
      final weeksLeft = user.workoutEndDate!.difference(DateTime.now()).inDays / 7;
      if (weeksLeft > 0) {
        timelineInfo = '- Target Timeline: ${weeksLeft.toStringAsFixed(0)} weeks until deadline (${user.workoutEndDate!.day}/${user.workoutEndDate!.month}/${user.workoutEndDate!.year})';
      }
    }

    return '''You are an expert fitness and nutrition planner. Generate a JSON response with exactly 4 different personalized fitness plans for a user with this profile:

USER PROFILE:
- Name: ${user.displayName}
- Age: ${user.age} years old
- Gender: ${user.gender}
- Current Weight: ${user.weight} kg
- Height: ${user.height} cm
- BMI: $bmi
- Primary Goal: $goal
- Activity Level: $activity
${user.targetWeightKg != null ? '- Target Weight: ${user.targetWeightKg} kg ($weightDirection ${absWeightDiff ?? ''} kg)' : ''}
${user.dailyCalorieTarget != null ? '- Daily Calorie Target: ${user.dailyCalorieTarget!.toInt()} kcal (calculated from TDEE)' : ''}
${user.dietPreference != 'none' ? '- Diet Preference: $diet' : ''}
${averageSleepHours != null ? '- Average Sleep: ${averageSleepHours.toStringAsFixed(1)} hours/night' : ''}
${user.workoutGoal != null && user.workoutGoal!.isNotEmpty ? '- Specific Workout Goal: ${user.workoutGoal}' : ''}
$timelineInfo

PERSONALIZATION RULES (CRITICAL):
1. EXERCISE SELECTION by age:
   - Under 20: Focus on bodyweight, learning proper form, fun dynamic movements
   - 20-35: Full range of exercises including heavy compound lifts, HIIT, plyometrics
   - 35-50: Moderate joint impact, include mobility work, focus on functional strength
   - Over 50: Low-impact exercises, emphasis on balance, flexibility, joint-friendly movements

2. INTENSITY by activity level:
   - Sedentary/Light: Start with 3 workouts/week, 25-30 min, bodyweight-focused
   - Moderate: 4 workouts/week, 35-45 min, mix of cardio and weights
   - Very Active: 5-6 workouts/week, 45-55 min, progressive overload
   - Extremely Active: 6 workouts/week, 50-60 min, advanced techniques

3. CALORIE & MACRO targets:
   - Weight loss: deficit of 300-500 kcal, higher protein (1.6-2.2g/kg bodyweight)
   - Muscle gain: surplus of 200-400 kcal, high protein (1.8-2.4g/kg), higher carbs
   - General fitness: maintenance calories, balanced macros
   - Protein = based on ${user.weight} kg bodyweight

4. MEAL PLANS must respect diet preference. NO exceptions.
   - Vegan: zero animal products
   - Vegetarian: no meat/fish
   - Halal: only halal protein sources
   - Keto: <50g carbs/day
   - Match meals to the daily calorie target

5. DAILY SCHEDULE must be realistic and personalized:
   - Workout timing should reflect a typical day (morning or evening workout)
   - Meal times should be spaced 3-4 hours apart
   - Include wind-down and sleep routine
   - If sleep data shows < 7 hours, add sleep hygiene tips

6. TIMELINE: If a target deadline is provided, estimate goal_weeks realistically. Don't promise impossible timelines.

7. WEEKLY WORKOUTS: Assign specific focus days (e.g., Upper Body, Lower Body, Cardio, Core, Rest). Include actual exercise names. For strength goals, include progressive overload guidance. For endurance, include running/cycling distances.

The 4 plans should have different approaches:
1. "Intensive" - aggressive plan for fastest results
2. "Balanced" - moderate plan for steady sustainable progress
3. "Gentle" - low-intensity plan for beginners or older users
4. "Custom" - specifically tailored to their goal and timeline

Return ONLY valid JSON with this exact structure. No markdown, no explanation:
{
  "plans": [
    {
      "title": "Plan name with emoji",
      "tagline": "Short catchy description (mention the user's name)",
      "difficulty": "beginner/intermediate/advanced",
      "description": "2-3 sentence personalized description mentioning their specific goal, current weight, and what they can expect",
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

Make calorie and macro targets realistic and personalized to the user's ${user.weight}kg bodyweight. Ensure daily_schedule times make sense with the meals. Only return valid JSON.''';
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
    final isStrength = user.fitnessGoal == 'strength';
    final isEndurance = user.fitnessGoal == 'endurance';
    final isSedentary = user.activityLevel == 'sedentary' || user.activityLevel == 'light';
    final isVegan = user.dietPreference == 'vegan';
    final isVegetarian = user.dietPreference == 'vegetarian' || isVegan;
    final baseCalories = user.dailyCalorieTarget?.toInt() ?? 2200;
    final isOlder = user.age >= 45;
    final proteinPerKg = isBuildMuscle ? 2.0 : 1.6;
    final targetProtein = (user.weight * proteinPerKg).roundToDouble();

    int goalWeeks = 12;
    if (user.workoutEndDate != null) {
      final weeks = user.workoutEndDate!.difference(DateTime.now()).inDays / 7;
      if (weeks > 0) goalWeeks = weeks.round().clamp(4, 24);
    }

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
        proteinG: targetProtein,
        carbsG: isLoseWeight ? 150 : 250,
        fatG: 45,
        workoutStyle: 'HIIT + Strength Training',
        workoutsPerWeek: isSedentary ? 4 : 6,
        workoutDurationMinutes: isOlder ? 40 : 50,
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
        estimatedGoalWeeks: goalWeeks,
        sleepHours: 8,
        sleepBedtime: '9:30 PM',
        dailySchedule: [
          DailyActivity(time: isOlder ? '7:00 AM' : '6:00 AM', title: 'Wake Up', description: 'Drink water with lemon, light stretching', type: 'general'),
          DailyActivity(time: isOlder ? '7:30 AM' : '6:30 AM', title: 'Morning Cardio', description: isOlder ? '15-min brisk walk' : '20-min fasted cardio', type: 'workout'),
          DailyActivity(time: isOlder ? '8:30 AM' : '7:30 AM', title: 'Breakfast', description: 'High-protein breakfast', type: 'meal'),
          DailyActivity(time: '12:00 PM', title: 'Lunch', description: 'Lean protein + complex carbs', type: 'meal'),
          DailyActivity(time: isOlder ? '5:00 PM' : '4:00 PM', title: 'Main Workout', description: isStrength ? 'Compound lifts: squats, deadlifts, bench' : 'Strength training session', type: 'workout'),
          DailyActivity(time: '6:30 PM', title: 'Dinner', description: 'High protein, moderate carbs', type: 'meal'),
          DailyActivity(time: '9:00 PM', title: 'Wind Down', description: 'No screens, meditation', type: 'general'),
          DailyActivity(time: '9:30 PM', title: 'Sleep', description: 'Full recovery sleep', type: 'sleep'),
        ],
        meals: [
          MealPlan(meal: 'Breakfast', time: '7:30 AM', description: isVegan ? 'Tofu scramble, oats, banana' : isVegetarian ? 'Egg whites, oatmeal, banana' : 'Egg whites, oatmeal, banana', calories: 400, options: isVegan ? ['Tofu scramble + oats', 'Protein smoothie'] : ['Scrambled eggs + oats', 'Protein smoothie']),
          MealPlan(meal: 'Lunch', time: '12:00 PM', description: isVegan ? 'Quinoa bowl with beans and veggies' : isVegetarian ? 'Paneer/chickpea bowl with rice' : 'Grilled chicken, brown rice, broccoli', calories: 550, options: isVegan ? ['Quinoa bowl', 'Bean wrap'] : ['Chicken bowl', 'Turkey wrap']),
          MealPlan(meal: 'Snack', time: '3:30 PM', description: isVegan ? 'Plant protein shake + almonds' : 'Protein shake + almonds', calories: 250, options: isVegan ? ['Plant protein shake', 'Trail mix'] : ['Whey shake', 'Greek yogurt']),
          MealPlan(meal: 'Dinner', time: '6:30 PM', description: isVegan ? 'Tempeh with sweet potato, asparagus' : isVegetarian ? 'Grilled halloumi, sweet potato, veggies' : 'Salmon, sweet potato, asparagus', calories: 500, options: isVegan ? ['Tempeh plate', 'Lentil curry'] : ['Salmon plate', 'Lean beef bowl']),
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
        proteinG: (targetProtein * 0.85).roundToDouble(),
        carbsG: 200,
        fatG: 55,
        workoutStyle: 'Mixed Cardio + Weights',
        workoutsPerWeek: isSedentary ? 3 : 4,
        workoutDurationMinutes: isOlder ? 35 : 40,
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
        estimatedGoalWeeks: goalWeeks,
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
          MealPlan(meal: 'Breakfast', time: '8:00 AM', description: isVegan ? 'Avocado toast with seeds, fruit' : isVegetarian ? 'Whole grain toast, eggs, fruit' : 'Whole grain toast, eggs, fruit', calories: 380, options: isVegan ? ['Avocado toast + seeds', 'Oatmeal + berries'] : ['Avocado toast + eggs', 'Oatmeal + berries']),
          MealPlan(meal: 'Lunch', time: '12:30 PM', description: isVegan ? 'Buddha bowl with tofu and veggies' : isVegetarian ? 'Quinoa bowl with cheese and veggies' : 'Mixed protein bowl with veggies', calories: 500, options: isVegan ? ['Buddha bowl', 'Veggie wrap'] : ['Quinoa bowl', 'Whole grain wrap']),
          MealPlan(meal: 'Snack', time: '4:00 PM', description: 'Fruit + nuts', calories: 200, options: ['Apple + peanut butter', 'Berries + yogurt']),
          MealPlan(meal: 'Dinner', time: '7:00 PM', description: isVegan ? 'Lentil curry with brown rice' : isVegetarian ? 'Cheese and vegetable stir-fry' : 'Lean protein + vegetables', calories: 450, options: isVegan ? ['Lentil curry', 'Veggie stir-fry'] : ['Grilled fish + salad', 'Chicken stir-fry']),
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
        proteinG: (targetProtein * 0.7).roundToDouble(),
        carbsG: 220,
        fatG: 60,
        workoutStyle: isOlder ? 'Walking + Gentle Movement' : 'Walking + Bodyweight',
        workoutsPerWeek: isSedentary ? 3 : 3,
        workoutDurationMinutes: isOlder ? 20 : (isSedentary ? 25 : 30),
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
        estimatedGoalWeeks: (goalWeeks * 1.3).round(),
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
          MealPlan(meal: 'Breakfast', time: '8:30 AM', description: isVegan ? 'Oatmeal with plant milk and fruit' : isVegetarian ? 'Oatmeal with yogurt and fruit' : 'Simple oatmeal or toast with fruit', calories: 300, options: isVegan ? ['Oatmeal + banana', 'Toast + peanut butter'] : ['Oatmeal + banana', 'Toast + peanut butter']),
          MealPlan(meal: 'Lunch', time: '1:00 PM', description: isVegan ? 'Hummus veggie wrap or bean salad' : isVegetarian ? 'Cheese sandwich or salad' : 'Light sandwich or salad', calories: 450, options: isVegan ? ['Vegan wrap', 'Bean salad'] : ['Turkey sandwich', 'Garden salad + protein']),
          MealPlan(meal: 'Snack', time: '4:00 PM', description: 'Fresh fruit or veggies', calories: 150, options: ['Apple', 'Carrot sticks + hummus']),
          MealPlan(meal: 'Dinner', time: '7:30 PM', description: isVegan ? 'Stir-fried tofu with rice and veggies' : isVegetarian ? 'Pasta with vegetables' : 'Simple home-cooked meal', calories: 400, options: isVegan ? ['Tofu stir-fry', 'Veggie curry + rice'] : ['Grilled chicken + veggies', 'Fish + rice']),
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
                : isStrength
                    ? '🏋️ Strength Max'
                    : isEndurance
                        ? '🏃 Endurance Engine'
                        : '🎯 Goal Crusher',
        tagline: isBuildMuscle
            ? 'Optimized for muscle growth'
            : isLoseWeight
                ? 'Targeted fat loss strategy'
                : isStrength
                    ? 'Maximum strength gains'
                    : isEndurance
                        ? 'Build unstoppable stamina'
                        : 'Customized for your goals',
        difficulty: 'intermediate',
        description: isBuildMuscle
            ? 'Specialized hypertrophy program with progressive overload and targeted nutrition for muscle growth.'
            : isLoseWeight
                ? 'Strategic calorie cycling with metabolic conditioning to maximize fat oxidation.'
                : isStrength
                    ? 'Heavy compound lifts with progressive overload to maximize your ${user.weight}kg frame strength.'
                    : isEndurance
                        ? 'Cardiovascular training plan to build endurance and stamina over ${goalWeeks} weeks.'
                        : 'Purpose-built plan combining the best elements for your specific fitness goal.',
        dailyCalories: isBuildMuscle
            ? baseCalories + 400
            : isLoseWeight
                ? baseCalories - 400
                : baseCalories + 100,
        proteinG: isBuildMuscle ? (user.weight * 2.2).roundToDouble() : targetProtein,
        carbsG: isBuildMuscle ? 280 : 170,
        fatG: isBuildMuscle ? 50 : 50,
        workoutStyle: isBuildMuscle
            ? 'Progressive Overload Split'
            : isStrength
                ? 'Powerlifting Focused'
                : isEndurance
                    ? 'Progressive Running + Cross Training'
                    : 'Metabolic Conditioning',
        workoutsPerWeek: isSedentary ? 4 : 5,
        workoutDurationMinutes: isOlder ? 40 : 45,
        sampleExercises: isBuildMuscle
            ? ['Bench Press', 'Squats', 'Deadlifts', 'Pull-ups', 'OHP']
            : isStrength
                ? ['Back Squat', 'Deadlift', 'Bench Press', 'Barbell Row', 'Overhead Press']
                : isEndurance
                    ? ['Running Intervals', 'Cycling', 'Rowing', 'Jump Rope', 'Swimming']
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
        estimatedGoalWeeks: goalWeeks,
        sleepHours: 8,
        sleepBedtime: '9:45 PM',
        dailySchedule: [
          DailyActivity(time: isOlder ? '7:30 AM' : '6:30 AM', title: 'Wake Up', description: 'Hydrate, light mobility work', type: 'general'),
          DailyActivity(time: isOlder ? '8:00 AM' : '7:00 AM', title: 'Breakfast', description: isBuildMuscle ? 'High carb/protein breakfast' : 'Light protein breakfast', type: 'meal'),
          DailyActivity(time: '12:00 PM', title: 'Lunch', description: 'Targeted macro lunch', type: 'meal'),
          DailyActivity(time: isOlder ? '5:00 PM' : '4:30 PM', title: 'Workout', description: isBuildMuscle ? 'Strength training' : isStrength ? 'Compound lifts' : isEndurance ? 'Cardio session' : 'Metabolic conditioning', type: 'workout'),
          DailyActivity(time: '6:30 PM', title: 'Dinner', description: 'Recovery meal', type: 'meal'),
          DailyActivity(time: '9:15 PM', title: 'Wind Down', description: 'Stretch, plan tomorrow', type: 'general'),
          DailyActivity(time: '9:45 PM', title: 'Sleep', description: 'Deep recovery sleep', type: 'sleep'),
        ],
        meals: isBuildMuscle
            ? [
                MealPlan(meal: 'Breakfast', time: '7:00 AM', description: isVegan ? 'Tofu scramble, oats, banana, plant protein shake' : 'Eggs, oatmeal, banana, protein shake', calories: 600, options: isVegan ? ['Mass gainer smoothie', 'Tofu + oat bowl'] : ['Mass gainer smoothie', 'Egg + oat bowl']),
                MealPlan(meal: 'Lunch', time: '12:00 PM', description: isVegan ? 'Tempeh, quinoa, veggies, avocado' : 'Chicken, rice, veggies, avocado', calories: 700, options: isVegan ? ['Tempeh rice bowl', 'Bean + potato'] : ['Chicken rice bowl', 'Beef + potato']),
                MealPlan(meal: 'Snack', time: '3:30 PM', description: 'Pre-workout: banana + PB', calories: 350, options: isVegan ? ['Rice cakes + PB', 'Fruit + plant protein'] : ['Rice cakes + PB', 'Fruit + whey']),
                MealPlan(meal: 'Dinner', time: '6:30 PM', description: isVegan ? 'Lentil stew, sweet potato, greens' : 'Steak, sweet potato, greens', calories: 650, options: isVegan ? ['Lentil stew', 'Tofu plate'] : ['Beef bowl', 'Salmon plate']),
              ]
            : [
                MealPlan(meal: 'Breakfast', time: '7:00 AM', description: isVegan ? 'Plant protein smoothie, grapefruit' : 'Egg whites, grapefruit, green tea', calories: 300, options: isVegan ? ['Plant protein smoothie', 'Avocado toast'] : ['Egg white omelette', 'Protein smoothie']),
                MealPlan(meal: 'Lunch', time: '12:00 PM', description: isVegan ? 'Large vegan salad with chickpeas' : 'Lean protein + large salad', calories: 450, options: isVegan ? ['Chickpea salad', 'Veggie wraps'] : ['Grilled chicken salad', 'Turkey lettuce wraps']),
                MealPlan(meal: 'Snack', time: '3:30 PM', description: 'Celery + almond butter', calories: 200, options: ['Veggie sticks', 'Protein water']),
                MealPlan(meal: 'Dinner', time: '6:30 PM', description: isVegan ? 'Stir-fried tofu with steamed vegetables' : 'Fish + steamed vegetables', calories: 400, options: isVegan ? ['Tofu stir-fry', 'Veggie curry'] : ['Grilled fish + greens', 'Chicken + broccoli']),
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
            : isStrength
                ? [
                    WorkoutDay(day: 'Monday', focus: 'Squat Day', durationMinutes: 55, exercises: ['Back Squat', 'Front Squat', 'Leg Press', 'Leg Curl']),
                    WorkoutDay(day: 'Tuesday', focus: 'Bench Press Day', durationMinutes: 50, exercises: ['Bench Press', 'Close-grip Bench', 'Dips', 'Tricep Extensions']),
                    WorkoutDay(day: 'Wednesday', focus: 'Rest/Recovery', durationMinutes: 20, exercises: ['Light Walk', 'Stretching', 'Foam Rolling']),
                    WorkoutDay(day: 'Thursday', focus: 'Deadlift Day', durationMinutes: 55, exercises: ['Deadlift', 'Barbell Row', 'Rack Pulls', 'Shrugs']),
                    WorkoutDay(day: 'Friday', focus: 'Overhead Press Day', durationMinutes: 45, exercises: ['Overhead Press', 'Push Press', 'Lateral Raises', 'Face Pulls']),
                    WorkoutDay(day: 'Saturday', focus: 'Accessory Work', durationMinutes: 35, exercises: ['Hammer Curls', 'Skull Crushers', 'Abs Circuit', 'Farmer Walks']),
                  ]
                : isEndurance
                    ? [
                        WorkoutDay(day: 'Monday', focus: 'Easy Run', durationMinutes: 35, exercises: ['Easy Pace Run 5K', 'Dynamic Stretching', 'Cool Down Walk']),
                        WorkoutDay(day: 'Tuesday', focus: 'Cross Training', durationMinutes: 30, exercises: ['Cycling', 'Swimming', 'Core Work']),
                        WorkoutDay(day: 'Wednesday', focus: 'Tempo Run', durationMinutes: 40, exercises: ['Warm Up 1K', 'Tempo 3K', 'Cool Down 1K', 'Stretching']),
                        WorkoutDay(day: 'Thursday', focus: 'Strength for Runners', durationMinutes: 35, exercises: ['Squats', 'Lunges', 'Planks', 'Hip Strength']),
                        WorkoutDay(day: 'Friday', focus: 'Rest', durationMinutes: 15, exercises: ['Foam Rolling', 'Yoga Flow', 'Deep Breathing']),
                        WorkoutDay(day: 'Saturday', focus: 'Long Run', durationMinutes: 50, exercises: ['Long Slow Distance Run', 'Post-run Stretching', 'Hydration Focus']),
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
