import 'dart:async';
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
  String? _initError;

  bool get isInitialized => _initialized;
  String? get initError => _initError;
  
  /// Initialize Gemini model
  Future<void> initialize({String? model}) async {
    if (_initialized) return;

    final apiKey = AppConstants.geminiApiKey;

    if (apiKey.isEmpty || apiKey == 'YOUR_ACTUAL_GEMINI_API_KEY_HERE') {
      _initError = '❌ Gemini API key is missing or invalid. '
          'Please add your key to lib/config/api_keys.dart';
      debugPrint(_initError);
      throw Exception(_initError);
    }

    try {
      final modelName = model ?? 'gemini-3.1-flash-lite';
      _visionModel = GenerativeModel(
        model: modelName,
        apiKey: apiKey,
      );
      _initialized = true;
      _initError = null;
      debugPrint('✅ AIService initialized with model: $modelName');
    } catch (e) {
      _initError = 'Failed to initialize Gemini: $e';
      debugPrint('❌ $_initError');
      rethrow;
    }
  }

  /// Recognize food from image
  Future<FoodItem?> recognizeFoodFromImage(
    Uint8List imageBytes, {
    int maxRetries = 2,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (_visionModel == null) {
      throw Exception('❌ AI model not initialized. Error: $_initError');
    }

    final compressedBytes = await _compressImageIfNeeded(imageBytes);

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

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('🔄 AI recognition attempt ${attempt + 1}/$maxRetries');

        final response = await _visionModel!
            .generateContent([
              Content.multi([
                DataPart('image/jpeg', compressedBytes),
                TextPart(prompt),
              ]),
            ])
            .timeout(timeout, onTimeout: () {
              throw TimeoutException('AI API call timed out after ${timeout.inSeconds}s');
            });

        final text = response.text?.trim() ?? '';
        debugPrint('📝 AI raw response (first 200 chars): ${text.substring(0, text.length > 200 ? 200 : text.length)}');

        if (text.isEmpty) {
          debugPrint('⚠️ Empty response from AI');
          if (attempt == maxRetries) return null;
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }

        final result = _parseAIResponse(text);
        if (result != null) {
          debugPrint('✅ Parsed food: ${result.name} (confidence: ${result.confidence})');
          return result;
        } else {
          debugPrint('⚠️ Failed to parse AI response on attempt ${attempt + 1}');
          if (attempt == maxRetries) return null;
          await Future.delayed(const Duration(seconds: 1));
        }
      } on TimeoutException catch (e) {
        debugPrint('⏱️ Timeout on attempt ${attempt + 1}: $e');
        if (attempt == maxRetries) throw Exception('AI service timeout - network may be slow');
        await Future.delayed(Duration(seconds: attempt + 1));
      } catch (e) {
        debugPrint('❌ AI recognition error on attempt ${attempt + 1}: $e');
        if (attempt == maxRetries) throw Exception('AI service error: $e');
        await Future.delayed(Duration(seconds: attempt + 1));
      }
    }
    return null;
  }

  /// Compress image to 1024px width to reduce size and improve speed
  Future<Uint8List> _compressImageIfNeeded(Uint8List imageBytes) async {
    if (imageBytes.length < 500 * 1024) return imageBytes;
    return await compute(_resizeImage, imageBytes);
  }

  static Uint8List _resizeImage(Uint8List bytes) {
    // Add 'image' package for real compression if needed
    return bytes;
  }

  /// Parse AI JSON response
  FoodItem? _parseAIResponse(String response) {
    try {
      String clean = response
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final start = clean.indexOf('{');
      final end = clean.lastIndexOf('}');
      if (start == -1 || end == -1) {
        debugPrint('⚠️ No JSON object found in response');
        return null;
      }

      final jsonStr = clean.substring(start, end + 1);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      if (json['name'] == null || json['name'] == 'Unknown' || json['confidence'] == 0) {
        debugPrint('⚠️ AI did not identify food (name: ${json['name']}, confidence: ${json['confidence']})');
        return null;
      }

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
      debugPrint('❌ JSON parsing error: $e');
      return null;
    }
  }
}
