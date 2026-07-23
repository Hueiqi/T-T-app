// lib/services/ai_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/constants.dart';   // ✅ correct file
import '../models/food_item_model.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  GenerativeModel? _model;
  GenerativeModel? _visionModel;
  bool _initialized = false;
  String? _initError;

  bool get isInitialized => _initialized;
  String? get initError => _initError;

  // ──────────────────────────────────────────────────────────────
  // INITIALIZATION
  // ──────────────────────────────────────────────────────────────
  Future<void> initialize({String? model, String? visionModel}) async {
    if (_initialized) return;

    final apiKey = AppConstants.geminiApiKey;   // ✅ now works
    if (apiKey.isEmpty || apiKey == 'YOUR_ACTUAL_GEMINI_API_KEY_HERE') {
      _initError = '❌ Gemini API key is missing.';
      debugPrint(_initError);
      throw Exception(_initError);
    }

    try {
      final chatModelName = model ?? 'gemini-3.5-flash';
      _model = GenerativeModel(
        model: chatModelName,
        apiKey: apiKey,
        systemInstruction: Content.text('''
You are a Fitness AI Assistant.

Your expertise:
- Personalised workout plans (strength, cardio, flexibility)
- Exercise suggestions for specific muscle groups and fitness levels
- Meal plans and nutrition advice
- Food analysis (calories, macros)
- General fitness and wellness Q&A

Rules:
- Be helpful, encouraging, and concise.
- Use simple, clear language.
- When asked for structured data, return **only valid JSON** – no markdown, no backticks, no extra text.
- Always base recommendations on the user's profile if provided.
'''),
      );

      final visionModelName = visionModel ?? 'gemini-3.1-flash-lite';
      _visionModel = GenerativeModel(
        model: visionModelName,
        apiKey: apiKey,
      );

      _initialized = true;
      _initError = null;
      debugPrint('✅ Fitness AI initialized');
    } catch (e) {
      _initError = 'Failed to initialize Gemini: $e';
      debugPrint('❌ $_initError');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // 1. GENERAL CHAT
  // ──────────────────────────────────────────────────────────────
  Future<String> chat(String message) async {
    if (_model == null) throw Exception('AI not initialized.');
    try {
      final response = await _model!.generateContent([Content.text(message)]);
      return response.text ?? 'No response generated.';
    } catch (e) {
      throw Exception('Chat failed: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // 2. GENERATE WORKOUT PLAN
  // ──────────────────────────────────────────────────────────────
  Future<WorkoutPlan> generateWorkoutPlan({
    required String goal,
    required String level,
    required int daysPerWeek,
    required int durationMinutes,
    String? equipment,
    String? focus,
  }) async {
    if (_model == null) throw Exception('AI not initialized.');

    final prompt = '''
Create a personalised workout plan.

User profile:
- Goal: $goal
- Level: $level
- Days per week: $daysPerWeek
- Session duration: $durationMinutes minutes
- Equipment available: ${equipment ?? 'none specified'}
- Focus area: ${focus ?? 'full body'}

Return ONLY this JSON (no markdown, no backticks):
{
  "plan_name": "short, descriptive name for the plan",
  "description": "brief overview of the plan (1-2 sentences)",
  "weekly_schedule": [
    {
      "day": 1,
      "focus": "upper body",
      "exercises": [
        {
          "name": "Push-ups",
          "sets": 3,
          "reps": "10-12",
          "rest": "60 seconds",
          "notes": "modify with knee push-ups if needed"
        }
      ]
    }
  ],
  "warm_up": "2-3 dynamic stretches or light cardio",
  "cool_down": "static stretches for worked muscles",
  "tips": ["extra tip 1", "extra tip 2"]
}

Rules:
- Include 4-6 exercises per session.
- Reps and sets should match the user's level.
- Ensure variety and avoid overtraining.
- Return ONLY the JSON, nothing else.
''';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      final raw = response.text ?? '{}';
      final json = jsonDecode(raw) as Map<String, dynamic>;   // ✅ decode first
      return WorkoutPlan.fromJson(json);
    } catch (e) {
      throw Exception('Workout plan generation failed: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // 3. SUGGEST EXERCISES
  // ──────────────────────────────────────────────────────────────
  Future<List<ExerciseSuggestion>> suggestExercises({
    required String muscleGroup,
    required String level,
    String? equipment,
    int count = 6,
  }) async {
    if (_model == null) throw Exception('AI not initialized.');

    final prompt = '''
Suggest $count exercises for the muscle group: "$muscleGroup".
User level: $level.
Equipment available: ${equipment ?? 'none specified'}.

Return ONLY this JSON array (no markdown, no backticks):
[
  {
    "name": "exercise name",
    "muscle_group": "$muscleGroup",
    "primary_muscles": ["muscle1", "muscle2"],
    "level": "$level",
    "equipment": "required equipment",
    "instructions": "brief step-by-step, 1-2 sentences",
    "tips": ["tip 1", "tip 2"]
  }
]

Rules:
- Choose exercises suitable for the given level.
- Include variations when appropriate.
- Provide clear, safe instructions.
- Return ONLY the JSON array, nothing else.
''';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      final list = _parseExerciseSuggestions(response.text ?? '[]');
      return list;
    } catch (e) {
      throw Exception('Exercise suggestion failed: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // 4. CREATE MEAL PLAN
  // ──────────────────────────────────────────────────────────────
  Future<AIMealPlan> createMealPlan({
    required String dietPreference,
    required int dailyCalories,
    required String goal,
    List<String>? restrictions,
    int mealsPerDay = 4,
  }) async {
    if (_model == null) throw Exception('AI not initialized.');

    final prompt = '''
Create a daily meal plan.

User details:
- Diet preference: $dietPreference
- Daily calorie target: $dailyCalories kcal
- Goal: $goal
- Restrictions: ${restrictions?.join(', ') ?? 'none'}
- Meals per day: $mealsPerDay

Return ONLY this JSON (no markdown, no backticks):
{
  "plan_name": "descriptive name",
  "total_calories": $dailyCalories,
  "meals": [
    {
      "type": "breakfast",
      "time": "8:00 AM",
      "name": "Oatmeal with berries",
      "ingredients": ["rolled oats", "mixed berries", "almond milk"],
      "calories": 350,
      "protein_g": 12,
      "carbs_g": 50,
      "fat_g": 8,
      "prep_time": "5 minutes",
      "instructions": "Mix oats and milk, microwave for 2 minutes, top with berries."
    }
  ],
  "daily_tips": ["Drink 2L water", "Eat protein within 1 hour of workout"]
}

Rules:
- Balance macros according to the goal.
- Provide realistic, easy-to-follow recipes.
- Include vegetarian/vegan/keto options if specified.
- Return ONLY the JSON, nothing else.
''';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      final raw = response.text ?? '{}';
      final json = jsonDecode(raw) as Map<String, dynamic>;   // ✅ decode
      return AIMealPlan.fromJson(json);
    } catch (e) {
      throw Exception('Meal plan creation failed: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // 5. FOOD ANALYSIS (used by NutritionProvider)
  // ──────────────────────────────────────────────────────────────
  Future<FoodItem?> analyzeFoodImage(
    Uint8List imageBytes, {
    int maxRetries = 2,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (_visionModel == null) {
      throw Exception('Vision model not initialized.');
    }

    const prompt = '''
Analyse this food image and return ONLY this JSON (no markdown, no backticks):
{
  "name": "food name",
  "calories": estimated calories per 100g (number),
  "protein": protein in grams per 100g (number),
  "carbs": carbohydrates in grams per 100g (number),
  "fat": fat in grams per 100g (number),
  "fiber": dietary fiber in grams per 100g (number, default 0),
  "sugar": sugar in grams per 100g (number, default 0),
  "sodium": sodium in milligrams per 100g (number, default 0),
  "servingSize": typical serving size in grams (number),
  "category": one of: breakfast, lunch, dinner, snack, drinks,
  "confidence": number between 0 and 1
}

If you cannot identify the food, return an empty object: {}
''';

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await _visionModel!
            .generateContent([
              Content.multi([
                DataPart('image/jpeg', imageBytes),
                TextPart(prompt),
              ]),
            ])
            .timeout(timeout);

        final text = response.text?.trim() ?? '';
        if (text.isEmpty) {
          if (attempt == maxRetries) return null;
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }

        final result = _parseFoodItem(text);
        if (result != null) return result;
      } catch (e) {
        if (attempt == maxRetries) throw Exception('Food analysis failed: $e');
        await Future.delayed(Duration(seconds: attempt + 1));
      }
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────────
  // 6. WRAPPER for compatibility (keeps NutritionProvider happy)
  // ──────────────────────────────────────────────────────────────
  Future<FoodItem?> recognizeFoodFromImage(
    Uint8List imageBytes, {
    int maxRetries = 2,
    Duration timeout = const Duration(seconds: 15),
  }) {
    return analyzeFoodImage(imageBytes, maxRetries: maxRetries, timeout: timeout);
  }

  // ──────────────────────────────────────────────────────────────
  // 7. GENERAL FITNESS Q&A
  // ──────────────────────────────────────────────────────────────
  Future<String> answerFitnessQuestion(String question) async {
    final prompt = '''
You are a friendly fitness coach.
The user asks: "$question"

Provide a clear, helpful, and actionable answer.
If it's about workouts, mention proper form and safety.
If it's about nutrition, give evidence-based advice.
Keep it concise but complete.
''';
    return await chat(prompt);
  }
    // ──────────────────────────────────────────────────────────────
  // 8. AUTO‑FILL NUTRITION FROM FOOD NAME
  // ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> autoFillNutritionFromName(String foodName) async {
    if (_model == null) throw Exception('AI not initialized.');
    final prompt = '''
  You are a nutrition expert. Given the food name "$foodName", return a JSON object with ALL of the following fields.
  IMPORTANT: You MUST include EVERY field listed below. If you cannot determine a value for any nutrient, use 0. Do NOT skip any field.

  Macros:
  - calories (kcal per 100g, number)
  - protein (g per 100g, number)
  - carbs (g per 100g, number)
  - fat (g per 100g, number)
  - fiber (g per 100g, number)
  - sugar (g per 100g, number)
  - sodium (mg per 100g, number)

  Vitamins (ALL must be included, use 0 if unknown):
  - vitaminA (mcg per 100g, number)
  - vitaminB (mg per 100g, number - total B vitamins)
  - vitaminC (mg per 100g, number)
  - vitaminD (mcg per 100g, number)
  - vitaminE (mg per 100g, number)
  - vitaminK (mcg per 100g, number)

  Minerals (ALL must be included, use 0 if unknown):
  - calcium (mg per 100g, number)
  - iron (mg per 100g, number)
  - magnesium (mg per 100g, number)
  - potassium (mg per 100g, number)

  Other:
  - servingSize (common serving description, string)

  Return ONLY the JSON object with ALL fields above. No extra text, no markdown, no backticks.
  Every single field must be present in the JSON. If you don't know the exact value, use 0.
  ''';
    final response = await chat(prompt);
    final clean = response.replaceAll(RegExp(r'```json|```'), '').trim();
    return jsonDecode(clean) as Map<String, dynamic>;
  }

  // ──────────────────────────────────────────────────────────────
  // PRIVATE HELPERS
  // ──────────────────────────────────────────────────────────────

  FoodItem? _parseFoodItem(String response) {
    try {
      String clean = response
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final start = clean.indexOf('{');
      final end = clean.lastIndexOf('}');
      if (start == -1 || end == -1) return null;

      final json = jsonDecode(clean.substring(start, end + 1))
          as Map<String, dynamic>;

      if (json['name'] == null || json['name'] == 'Unknown') return null;

      return FoodItem(
        name: json['name'] as String? ?? 'Unknown',
        caloriesPer100g: (json['calories'] as num?)?.toDouble() ?? 0,
        proteinPer100g: (json['protein'] as num?)?.toDouble() ?? 0,
        carbsPer100g: (json['carbs'] as num?)?.toDouble() ?? 0,
        fatPer100g: (json['fat'] as num?)?.toDouble() ?? 0,
        servingSizeGrams: (json['servingSize'] as num?)?.toDouble() ?? 100,
        category: json['category'] as String? ?? 'general',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (e) {
      debugPrint('Food parse error: $e');
      return null;
    }
  }

  List<ExerciseSuggestion> _parseExerciseSuggestions(String response) {
    try {
      String clean = response
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final list = jsonDecode(clean) as List<dynamic>;
      return list.map((e) => ExerciseSuggestion.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Exercise parse error: $e');
      return [];
    }
  }
}

// ══════════════════════════════════════════════
// DATA CLASSES
// ══════════════════════════════════════════════

class WorkoutPlan {
  final String planName;
  final String description;
  final List<WorkoutDay> weeklySchedule;
  final String warmUp;
  final String coolDown;
  final List<String> tips;

  WorkoutPlan({
    required this.planName,
    required this.description,
    required this.weeklySchedule,
    required this.warmUp,
    required this.coolDown,
    required this.tips,
  });

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    final schedule = (json['weekly_schedule'] as List<dynamic>?)
            ?.map((d) => WorkoutDay.fromJson(d as Map<String, dynamic>))
            .toList() ??
        [];
    return WorkoutPlan(
      planName: json['plan_name'] as String? ?? 'My Plan',
      description: json['description'] as String? ?? '',
      weeklySchedule: schedule,
      warmUp: json['warm_up'] as String? ?? '',
      coolDown: json['cool_down'] as String? ?? '',
      tips: (json['tips'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class WorkoutDay {
  final int day;
  final String focus;
  final List<ExerciseDetail> exercises;

  WorkoutDay({
    required this.day,
    required this.focus,
    required this.exercises,
  });

  factory WorkoutDay.fromJson(Map<String, dynamic> json) {
    final exs = (json['exercises'] as List<dynamic>?)
            ?.map((e) => ExerciseDetail.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return WorkoutDay(
      day: json['day'] as int? ?? 1,
      focus: json['focus'] as String? ?? '',
      exercises: exs,
    );
  }
}

class ExerciseDetail {
  final String name;
  final int sets;
  final String reps;
  final String rest;
  final String notes;

  ExerciseDetail({
    required this.name,
    required this.sets,
    required this.reps,
    required this.rest,
    required this.notes,
  });

  factory ExerciseDetail.fromJson(Map<String, dynamic> json) {
    return ExerciseDetail(
      name: json['name'] as String? ?? '',
      sets: (json['sets'] as num?)?.toInt() ?? 3,
      reps: json['reps'] as String? ?? '10-12',
      rest: json['rest'] as String? ?? '60 seconds',
      notes: json['notes'] as String? ?? '',
    );
  }
}

class ExerciseSuggestion {
  final String name;
  final String muscleGroup;
  final List<String> primaryMuscles;
  final String level;
  final String equipment;
  final String instructions;
  final List<String> tips;

  ExerciseSuggestion({
    required this.name,
    required this.muscleGroup,
    required this.primaryMuscles,
    required this.level,
    required this.equipment,
    required this.instructions,
    required this.tips,
  });

  factory ExerciseSuggestion.fromJson(Map<String, dynamic> json) {
    return ExerciseSuggestion(
      name: json['name'] as String? ?? '',
      muscleGroup: json['muscle_group'] as String? ?? '',
      primaryMuscles: (json['primary_muscles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      level: json['level'] as String? ?? '',
      equipment: json['equipment'] as String? ?? '',
      instructions: json['instructions'] as String? ?? '',
      tips: (json['tips'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

/// AI‑generated meal plan (avoids name clash with app's Meal model)
class AIMealPlan {
  final String planName;
  final int totalCalories;
  final List<AIMeal> meals;
  final List<String> dailyTips;

  AIMealPlan({
    required this.planName,
    required this.totalCalories,
    required this.meals,
    required this.dailyTips,
  });

  factory AIMealPlan.fromJson(Map<String, dynamic> json) {
    final meals = (json['meals'] as List<dynamic>?)
            ?.map((m) => AIMeal.fromJson(m as Map<String, dynamic>))
            .toList() ??
        [];
    return AIMealPlan(
      planName: json['plan_name'] as String? ?? 'My Meal Plan',
      totalCalories: (json['total_calories'] as num?)?.toInt() ?? 2000,
      meals: meals,
      dailyTips: (json['daily_tips'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class AIMeal {
  final String type;
  final String time;
  final String name;
  final List<String> ingredients;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final String prepTime;
  final String instructions;

  AIMeal({
    required this.type,
    required this.time,
    required this.name,
    required this.ingredients,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.prepTime,
    required this.instructions,
  });

  factory AIMeal.fromJson(Map<String, dynamic> json) {
    return AIMeal(
      type: json['type'] as String? ?? '',
      time: json['time'] as String? ?? '',
      name: json['name'] as String? ?? '',
      ingredients: (json['ingredients'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0,
      carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0,
      fatG: (json['fat_g'] as num?)?.toDouble() ?? 0,
      prepTime: json['prep_time'] as String? ?? '',
      instructions: json['instructions'] as String? ?? '',
    );
  }
}