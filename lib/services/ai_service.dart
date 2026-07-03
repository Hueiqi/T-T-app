import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/constants.dart';
import '../models/food_item_model.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  GenerativeModel? _visionModel;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    final apiKey = AppConstants.geminiApiKey;
    _visionModel = GenerativeModel(
      model: 'gemini-1.5-flash-lite',
      apiKey: apiKey,
    );
    _initialized = true;
  }

  Future<FoodItem?> recognizeFoodFromImage(Uint8List imageBytes) async {
    if (_visionModel == null) throw Exception('AI model not initialized.');

    const prompt = '''
Analyze this food image and return a JSON object with the following keys:
- "name": the most likely food name (string)
- "calories": estimated calories per 100g (number)
- "protein": protein in grams per 100g (number)
- "carbs": carbohydrates in grams per 100g (number)
- "fat": fat in grams per 100g (number)
- "servingSize": typical serving size in grams (number)
- "category": one of: breakfast, lunch, dinner, snack, drinks (string)
- "confidence": a number between 0 and 1 indicating your certainty

Return ONLY the JSON object, no markdown, no backticks, no extra text.
If you cannot identify the food, return an empty object: {}
''';

    try {
      final response = await _visionModel!.generateContent([
        Content.multi([
          DataPart('image/jpeg', imageBytes),
          TextPart(prompt),
        ]),
      ]);

      final text = response.text?.trim() ?? '';
      if (text.isEmpty || text == '{}') return null;

      String clean = text.replaceAll(RegExp(r'```json|```'), '').trim();
      final start = clean.indexOf('{');
      final end = clean.lastIndexOf('}');
      if (start == -1 || end == -1) return null;

      final json = jsonDecode(clean.substring(start, end + 1)) as Map<String, dynamic>;

      return FoodItem(
        name: json['name'] ?? 'Unknown',
        caloriesPer100g: (json['calories'] as num?)?.toDouble() ?? 0,
        proteinPer100g: (json['protein'] as num?)?.toDouble() ?? 0,
        carbsPer100g: (json['carbs'] as num?)?.toDouble() ?? 0,
        fatPer100g: (json['fat'] as num?)?.toDouble() ?? 0,
        servingSizeGrams: (json['servingSize'] as num?)?.toDouble() ?? 100,
        category: json['category'] ?? 'general',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (e) {
      debugPrint('Food recognition error: $e');
      return null;
    }
  }
}
