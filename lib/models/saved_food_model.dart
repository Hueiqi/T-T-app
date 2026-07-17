import 'package:cloud_firestore/cloud_firestore.dart';

class SavedFood {
  final String id;
  final String userId;
  final String foodName;
  final String servingSize;
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
  final DateTime createdAt;

  SavedFood({
    required this.id,
    required this.userId,
    required this.foodName,
    this.servingSize = '1 serving',
    this.calories = 0,
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
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'foodName': foodName,
        'servingSize': servingSize,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
        'sugar': sugar,
        'sodium': sodium,
        'vitaminA': vitaminA,
        'vitaminB': vitaminB,
        'vitaminC': vitaminC,
        'vitaminD': vitaminD,
        'vitaminE': vitaminE,
        'vitaminK': vitaminK,
        'calcium': calcium,
        'iron': iron,
        'magnesium': magnesium,
        'potassium': potassium,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory SavedFood.fromMap(Map<String, dynamic> map, String id) => SavedFood(
        id: id,
        userId: map['userId'] ?? '',
        foodName: map['foodName'] ?? '',
        servingSize: map['servingSize'] ?? '1 serving',
        calories: (map['calories'] as num?)?.toDouble() ?? 0,
        protein: (map['protein'] as num?)?.toDouble() ?? 0,
        carbs: (map['carbs'] as num?)?.toDouble() ?? 0,
        fat: (map['fat'] as num?)?.toDouble() ?? 0,
        fiber: (map['fiber'] as num?)?.toDouble() ?? 0,
        sugar: (map['sugar'] as num?)?.toDouble() ?? 0,
        sodium: (map['sodium'] as num?)?.toDouble() ?? 0,
        vitaminA: (map['vitaminA'] as num?)?.toDouble() ?? 0,
        vitaminB: (map['vitaminB'] as num?)?.toDouble() ?? 0,
        vitaminC: (map['vitaminC'] as num?)?.toDouble() ?? 0,
        vitaminD: (map['vitaminD'] as num?)?.toDouble() ?? 0,
        vitaminE: (map['vitaminE'] as num?)?.toDouble() ?? 0,
        vitaminK: (map['vitaminK'] as num?)?.toDouble() ?? 0,
        calcium: (map['calcium'] as num?)?.toDouble() ?? 0,
        iron: (map['iron'] as num?)?.toDouble() ?? 0,
        magnesium: (map['magnesium'] as num?)?.toDouble() ?? 0,
        potassium: (map['potassium'] as num?)?.toDouble() ?? 0,
        createdAt: map['createdAt'] is Timestamp
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
}
