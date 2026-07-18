import 'dart:convert';
import 'package:flutter/services.dart';

class FoodItem {
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium;
  final double vitaminA;
  final double vitaminB;
  final double vitaminC;
  final double vitaminD;
  final double vitaminE;
  final double vitaminK;
  final double calcium;
  final double iron;
  final double magnesium;
  final double potassium;
  final double water;
  final String servingSize;

  const FoodItem({
    required this.name,
    required this.calories,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    this.sugar = 0,
    this.sodium = 0,
    this.vitaminA = 0,
    this.vitaminB = 0,
    this.vitaminC = 0,
    this.vitaminD = 0,
    this.vitaminE = 0,
    this.vitaminK = 0,
    this.calcium = 0,
    this.iron = 0,
    this.magnesium = 0,
    this.potassium = 0,
    this.water = 0,
    this.servingSize = '1 serving',
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
        name: json['name'] as String? ?? 'Unknown',
        calories: (json['calories'] as num?)?.toDouble() ?? 0,
        protein: (json['protein'] as num?)?.toDouble() ?? 0,
        carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
        fat: (json['fat'] as num?)?.toDouble() ?? 0,
        fiber: (json['fiber'] as num?)?.toDouble() ?? 0,
        sugar: (json['sugar'] as num?)?.toDouble() ?? 0,
        sodium: (json['sodium'] as num?)?.toDouble() ?? 0,
        vitaminA: (json['vitaminA'] as num?)?.toDouble() ?? 0,
        vitaminB: (json['vitaminB'] as num?)?.toDouble() ?? 0,
        vitaminC: (json['vitaminC'] as num?)?.toDouble() ?? 0,
        vitaminD: (json['vitaminD'] as num?)?.toDouble() ?? 0,
        vitaminE: (json['vitaminE'] as num?)?.toDouble() ?? 0,
        vitaminK: (json['vitaminK'] as num?)?.toDouble() ?? 0,
        calcium: (json['calcium'] as num?)?.toDouble() ?? 0,
        iron: (json['iron'] as num?)?.toDouble() ?? 0,
        magnesium: (json['magnesium'] as num?)?.toDouble() ?? 0,
        potassium: (json['potassium'] as num?)?.toDouble() ?? 0,
        water: (json['water'] as num?)?.toDouble() ?? 0,
        servingSize: json['servingSize'] as String? ?? '1 serving',
      );
}

class FoodLibrary {
  static List<FoodItem> _allFoods = [];
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    final jsonString =
        await rootBundle.loadString('assets/food_library_full.json');
    final List data = json.decode(jsonString);
    _allFoods = data.map((e) => FoodItem.fromJson(e)).toList();
    _loaded = true;
  }

  static List<FoodItem> get all => _allFoods;

  static List<FoodItem> search(String query) {
    final lower = query.toLowerCase().trim();
    if (lower.isEmpty) return _allFoods;
    return _allFoods
        .where((f) => f.name.toLowerCase().contains(lower))
        .toList();
  }
}
