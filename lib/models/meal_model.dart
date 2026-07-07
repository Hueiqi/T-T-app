import 'package:cloud_firestore/cloud_firestore.dart';

class Meal {
  final String id;
  final String userId;
  final DateTime dateTime;
  final String mealType;
  final String foodName;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String? imageUrl; // ← ADD THIS

  // Vitamins
  final double vitaminA;
  final double vitaminB;
  final double vitaminC;
  final double vitaminD;
  final double vitaminE;
  final double vitaminK;

  // Minerals
  final double calcium;
  final double iron;
  final double magnesium;
  final double potassium;
  final double sodium;

  // Other nutrients
  final double fiber;
  final double water;

  Meal({
    required this.id,
    required this.userId,
    required this.dateTime,
    this.mealType = 'snack',
    this.foodName = 'Unknown',
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.imageUrl, // ← ADD THIS
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
    this.sodium = 0,
    this.fiber = 0,
    this.water = 0,
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'dateTime': Timestamp.fromDate(dateTime),
        'mealType': mealType,
        'foodName': foodName,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'imageUrl': imageUrl, // ← ADD THIS
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
        'sodium': sodium,
        'fiber': fiber,
        'water': water,
      };

  factory Meal.fromMap(Map<String, dynamic> map, String id) => Meal(
        id: id,
        userId: map['userId'] ?? '',
        dateTime: map['dateTime'] is Timestamp
            ? (map['dateTime'] as Timestamp).toDate()
            : DateTime.parse(map['dateTime'] as String),
        mealType: map['mealType'] as String? ?? 'snack',
        foodName: map['foodName'] as String? ?? 'Unknown',
        calories: (map['calories'] as num?)?.toDouble() ?? 0,
        protein: (map['protein'] as num?)?.toDouble() ?? 0,
        carbs: (map['carbs'] as num?)?.toDouble() ?? 0,
        fat: (map['fat'] as num?)?.toDouble() ?? 0,
        imageUrl: map['imageUrl'] as String?, // ← ADD THIS
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
        sodium: (map['sodium'] as num?)?.toDouble() ?? 0,
        fiber: (map['fiber'] as num?)?.toDouble() ?? 0,
        water: (map['water'] as num?)?.toDouble() ?? 0,
      );
}