// TDEE (Total Daily Energy Expenditure) Calculator
// Calculates daily calorie needs based on user profile

class TDEECalculator {
  /// Activity level multipliers
  static const double sedentary = 1.2; // Little or no exercise
  static const double lightlyActive = 1.375; // Light exercise 1-3 days/week
  static const double moderatelyActive =
      1.55; // Moderate exercise 3-5 days/week
  static const double veryActive = 1.725; // Hard exercise 6-7 days/week
  static const double extremelyActive = 1.9; // Very hard exercise/sports

  /// Calculate Basal Metabolic Rate using Mifflin-St Jeor equation
  /// More accurate for modern populations than Harris-Benedict
  static double calculateBMR({
    required int age,
    required double weight, // in kg
    required double height, // in cm
    required bool isMale,
  }) {
    if (isMale) {
      return (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      return (10 * weight) + (6.25 * height) - (5 * age) - 161;
    }
  }

  /// Calculate TDEE based on BMR and activity level
  static double calculateTDEE({
    required double bmr,
    required double activityMultiplier,
  }) {
    return bmr * activityMultiplier;
  }

  /// Get activity multiplier from activity level string
  static double getActivityMultiplier(String activityLevel) {
    switch (activityLevel.toLowerCase()) {
      case 'sedentary':
        return sedentary;
      case 'light':
        return lightlyActive;
      case 'moderate':
        return moderatelyActive;
      case 'very_active':
        return veryActive;
      case 'extremely_active':
        return extremelyActive;
      default:
        return moderatelyActive; // Default to moderate
    }
  }

  /// Calculate calorie goal based on fitness goal
  /// TDEE adjustment based on goal
  static double calculateCalorieGoal({
    required double tdee,
    required String fitnessGoal,
  }) {
    switch (fitnessGoal.toLowerCase()) {
      case 'weight_loss':
        return tdee * 0.85; // 15% deficit for safe weight loss
      case 'lean_gain':
        return tdee * 1.1; // 10% surplus for lean muscle gain
      case 'muscle_gain':
        return tdee * 1.15; // 15% surplus for muscle building
      case 'maintenance':
      case 'general_fitness':
      default:
        return tdee; // Maintenance calories
    }
  }

  /// Comprehensive TDEE calculation
  static Map<String, double> calculateComprehensive({
    required int age,
    required double weight, // kg
    required double height, // cm
    required bool isMale,
    required String activityLevel,
    required String fitnessGoal,
  }) {
    final bmr = calculateBMR(
      age: age,
      weight: weight,
      height: height,
      isMale: isMale,
    );

    final activityMultiplier = getActivityMultiplier(activityLevel);
    final tdee = calculateTDEE(
      bmr: bmr,
      activityMultiplier: activityMultiplier,
    );
    final calorieGoal = calculateCalorieGoal(
      tdee: tdee,
      fitnessGoal: fitnessGoal,
    );

    return {'bmr': bmr, 'tdee': tdee, 'calorieGoal': calorieGoal};
  }

  /// Macro recommendations based on calorie goal
  static Map<String, double> calculateMacros({
    required double calorieGoal,
    required String fitnessGoal,
  }) {
    double proteinRatio = 0.3; // 30% of calories
    double carbRatio = 0.45; // 45% of calories
    double fatRatio = 0.25; // 25% of calories

    // Adjust macros based on fitness goal
    if (fitnessGoal.toLowerCase() == 'muscle_gain') {
      proteinRatio = 0.35; // Higher protein for muscle building
      carbRatio = 0.45;
      fatRatio = 0.2;
    } else if (fitnessGoal.toLowerCase() == 'weight_loss') {
      proteinRatio = 0.35; // Higher protein to preserve muscle
      carbRatio = 0.4;
      fatRatio = 0.25;
    }

    return {
      'protein': (calorieGoal * proteinRatio) / 4, // 4 cal/g
      'carbs': (calorieGoal * carbRatio) / 4, // 4 cal/g
      'fat': (calorieGoal * fatRatio) / 9, // 9 cal/g
    };
  }
}
