class FoodItem {
  final String name;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double servingSizeGrams;
  final String category;
  final double confidence;

  FoodItem({
    required this.name,
    this.caloriesPer100g = 0,
    this.proteinPer100g = 0,
    this.carbsPer100g = 0,
    this.fatPer100g = 0,
    this.servingSizeGrams = 100,
    this.category = 'general',
    this.confidence = 0.0,
  });

  double get totalCalories => (caloriesPer100g / 100) * servingSizeGrams;
  double get totalProtein => (proteinPer100g / 100) * servingSizeGrams;
  double get totalCarbs => (carbsPer100g / 100) * servingSizeGrams;
  double get totalFat => (fatPer100g / 100) * servingSizeGrams;

  Map<String, dynamic> toMap() => {
    'name': name,
    'caloriesPer100g': caloriesPer100g,
    'proteinPer100g': proteinPer100g,
    'carbsPer100g': carbsPer100g,
    'fatPer100g': fatPer100g,
    'servingSizeGrams': servingSizeGrams,
    'category': category,
    'confidence': confidence,
  };

  factory FoodItem.fromMap(Map<String, dynamic> map) => FoodItem(
    name: map['name'] as String,
    caloriesPer100g: (map['caloriesPer100g'] as num?)?.toDouble() ?? 0,
    proteinPer100g: (map['proteinPer100g'] as num?)?.toDouble() ?? 0,
    carbsPer100g: (map['carbsPer100g'] as num?)?.toDouble() ?? 0,
    fatPer100g: (map['fatPer100g'] as num?)?.toDouble() ?? 0,
    servingSizeGrams: (map['servingSizeGrams'] as num?)?.toDouble() ?? 100,
    category: map['category'] as String? ?? 'general',
    confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
  );
}
