import 'dart:typed_data';

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
  final double vitamins;
  final double minerals;
  final double water;
  final double fiber;
  final String servingSize;
  final String imageUrl;
  final Uint8List? imageBytes;
  final String detectionMethod;

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
    this.vitamins = 0,
    this.minerals = 0,
    this.water = 0,
    this.fiber = 0,
    this.servingSize = '1 serving',
    this.imageUrl = '',
    this.imageBytes,
    this.detectionMethod = 'manual',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'dateTime': dateTime.toIso8601String(),
        'mealType': mealType,
        'foodName': foodName,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'vitamins': vitamins,
        'minerals': minerals,
        'water': water,
        'fiber': fiber,
        'servingSize': servingSize,
        'imageUrl': imageUrl,
        if (imageBytes != null) 'imageBytes': imageBytes,
        'detectionMethod': detectionMethod,
      };

  factory Meal.fromMap(Map<String, dynamic> map) => Meal(
        id: map['id'] as String,
        userId: map['userId'] as String,
        dateTime: DateTime.parse(map['dateTime'] as String),
        mealType: map['mealType'] as String? ?? 'snack',
        foodName: map['foodName'] as String? ?? 'Unknown',
        calories: (map['calories'] as num?)?.toDouble() ?? 0,
        protein: (map['protein'] as num?)?.toDouble() ?? 0,
        carbs: (map['carbs'] as num?)?.toDouble() ?? 0,
        fat: (map['fat'] as num?)?.toDouble() ?? 0,
        vitamins: (map['vitamins'] as num?)?.toDouble() ?? 0,
        minerals: (map['minerals'] as num?)?.toDouble() ?? 0,
        water: (map['water'] as num?)?.toDouble() ?? 0,
        fiber: (map['fiber'] as num?)?.toDouble() ?? 0,
        servingSize: map['servingSize'] as String? ?? '1 serving',
        imageUrl: map['imageUrl'] as String? ?? '',
        imageBytes: map['imageBytes'] is Uint8List
            ? map['imageBytes'] as Uint8List
            : null,
        detectionMethod: map['detectionMethod'] as String? ?? 'manual',
      );
}
