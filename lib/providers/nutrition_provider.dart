import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/ai_service.dart';
import '../services/firebase_service.dart';
import '../services/tdee_calculator.dart';
import '../models/meal_model.dart';
import '../models/food_item_model.dart';
import '../models/user_model.dart';
import '../models/weight_entry_model.dart';
import 'package:uuid/uuid.dart';

class NutritionProvider extends ChangeNotifier {
  final AIService _aiService = AIService();
  final FirebaseService _firebaseService = FirebaseService();
  final Uuid _uuid = const Uuid();

  List<Meal> _todayMeals = [];
  List<Meal> _selectedDateMeals = [];
  final Map<String, List<Meal>> _mealsCache = {};
  FoodItem? _detectedFood;
  bool _isAnalyzing = false;
  String? _error;
  double _dailyCalorieGoal = 2000;
  double _bmr = 0;
  double _tdee = 0;
  Map<String, double> _macroGoals = {};
  String _activityLevel = 'moderate';
  bool _tdeeCalculated = false;

  WeightEntry? _todayWeight;
  List<WeightEntry> _weightHistory = [];

  List<Meal> get todayMeals => _todayMeals;
  List<Meal> get selectedDateMeals => _selectedDateMeals;
  List<Meal> _dateRangeMeals = [];
  List<Meal> get dateRangeMeals => _dateRangeMeals;
  FoodItem? get detectedFood => _detectedFood;
  WeightEntry? get todayWeight => _todayWeight;
  List<WeightEntry> get weightHistory => _weightHistory;
  bool get isAnalyzing => _isAnalyzing;
  String? get error => _error;
  double get dailyCalorieGoal => _dailyCalorieGoal;
  double get bmr => _bmr;
  double get tdee => _tdee;
  Map<String, double> get macroGoals => _macroGoals;
  String get activityLevel => _activityLevel;
  bool get tdeeCalculated => _tdeeCalculated;
  double get totalCaloriesToday =>
      _todayMeals.fold(0, (total, meal) => total + meal.calories);
  double get totalProtein =>
      _todayMeals.fold(0, (total, meal) => total + meal.protein);
  double get totalCarbs => _todayMeals.fold(0, (total, meal) => total + meal.carbs);
  double get totalFat => _todayMeals.fold(0, (total, meal) => total + meal.fat);

  Map<String, double> _weeklyCalories = {};
  Map<String, double> get weeklyCalories => _weeklyCalories;
  double get weeklyAverage {
    if (_weeklyCalories.isEmpty) return 0;
    return _weeklyCalories.values.fold(0.0, (a, b) => a + b) / _weeklyCalories.length;
  }

  Future<void> loadWeeklyCalories(String userId) async {
    final meals = await _firebaseService.getMeals(userId);
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final filtered = meals.where((m) => m.dateTime.isAfter(cutoff)).toList();
    final Map<String, double> dailyTotals = {};
    for (final meal in filtered) {
      final key = '${meal.dateTime.year}-${meal.dateTime.month.toString().padLeft(2, '0')}-${meal.dateTime.day.toString().padLeft(2, '0')}';
      dailyTotals[key] = (dailyTotals[key] ?? 0) + meal.calories;
    }
    _weeklyCalories = dailyTotals;
    notifyListeners();
  }

  set dailyCalorieGoal(double goal) {
    _dailyCalorieGoal = goal;
    notifyListeners();
  }

  /// Load saved calorie goal from user profile (if any)
  void initDailyCalorieGoal(AppUser user) {
    if (user.dailyCalorieTarget != null && user.dailyCalorieTarget! > 0) {
      _dailyCalorieGoal = user.dailyCalorieTarget!;
      _tdeeCalculated = true;
      notifyListeners();
    }
  }

  /// Calculate TDEE based on user profile and update calorie goals
  Future<void> calculateAndSetTDEE({
    required AppUser user,
    required String activityLevel,
    Future<void> Function(double goal)? onSave,
  }) async {
    try {
      _activityLevel = activityLevel;

      final isMale = user.gender.toLowerCase() == 'male';

      // Calculate TDEE using user's profile
      final calculations = TDEECalculator.calculateComprehensive(
        age: user.age,
        weight: user.weight,
        height: user.height,
        isMale: isMale,
        activityLevel: activityLevel,
        fitnessGoal: user.fitnessGoal,
      );

      _bmr = calculations['bmr']!;
      _tdee = calculations['tdee']!;
      _dailyCalorieGoal = calculations['calorieGoal']!;

      // Calculate macro goals
      final macros = TDEECalculator.calculateMacros(
        calorieGoal: _dailyCalorieGoal,
        fitnessGoal: user.fitnessGoal,
      );
      _macroGoals = macros;
      _tdeeCalculated = true;
      _error = null;

      if (onSave != null) {
        await onSave(_dailyCalorieGoal);
      }

      notifyListeners();
    } catch (e) {
      _error = 'Failed to calculate TDEE: $e';
      notifyListeners();
    }
  }

  /// Update activity level and recalculate TDEE
  Future<void> updateActivityLevel(
    String newActivityLevel,
    AppUser user,
  ) async {
    await calculateAndSetTDEE(user: user, activityLevel: newActivityLevel);
  }

  /// Get protein goal
  double getProteinGoal() => _macroGoals['protein'] ?? 150;

  /// Get carbs goal
  double getCarbsGoal() => _macroGoals['carbs'] ?? 250;

  /// Get fat goal
  double getFatGoal() => _macroGoals['fat'] ?? 65;

  Future<void> loadTodayMeals(String userId) async {
    try {
      _todayMeals = await _firebaseService.getMeals(userId, date: DateTime.now());
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        _error = 'You don\'t have permission to view this data. Please sign out and sign back in.';
      } else {
        _error = 'Failed to load meals: ${e.message}';
      }
    }
    notifyListeners();
  }

  Future<void> loadMealsForDate(String userId, DateTime date) async {
    final key = DateFormat('yyyy-MM-dd').format(date);
    if (_mealsCache.containsKey(key)) {
      _selectedDateMeals = _mealsCache[key]!;
      notifyListeners();
      return;
    }
    try {
      _selectedDateMeals = await _firebaseService.getMeals(userId, date: date);
      _mealsCache[key] = _selectedDateMeals;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        _error = 'You don\'t have permission to view this data. Please sign out and sign back in.';
      } else {
        _error = 'Failed to load meals: ${e.message}';
      }
    }
    notifyListeners();
  }

  /// 🔥 Clear the cache for a specific date – forces fresh fetch next time.
  void clearCacheForDate(String dateKey) {
    _mealsCache.remove(dateKey);
    notifyListeners();
  }

  Future<List<Meal>> loadRecentMeals(String userId, {int days = 30}) async {
    final allMeals = await _firebaseService.getMeals(userId);
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final filtered = allMeals.where((m) => m.dateTime.isAfter(cutoff)).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return filtered;
  }

  Future<void> loadMealsForDateRange(String userId, DateTime start, DateTime end) async {
    try {
      _dateRangeMeals = await _firebaseService.getMealsForDateRange(userId, start, end);
    } catch (e) {
      _error = 'Failed to load meals: $e';
    }
    notifyListeners();
  }

  Future<FoodItem?> analyzeFoodImage(Uint8List imageBytes) async {
    _isAnalyzing = true;
    _error = null;
    _detectedFood = null;
    notifyListeners();

    try {
      _detectedFood = await _aiService.recognizeFoodFromImage(imageBytes);
      if (_detectedFood == null) {
        _error = 'AI could not identify the food. Please enter details manually.';
      } else {
        _error = null;
      }
      _isAnalyzing = false;
      notifyListeners();
      return _detectedFood;
    } catch (e) {
      _error = 'AI analysis failed: ${e.toString()}';
      _isAnalyzing = false;
      notifyListeners();
      return null;
    }
  }

  Future<Meal> saveMeal({
    required String userId,
    required String mealType,
    required String foodName,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    DateTime? dateTime,
    String? imageUrl,
    double water = 0,
    double fiber = 0,
    double vitaminA = 0,
    double vitaminB = 0,
    double vitaminC = 0,
    double vitaminD = 0,
    double vitaminE = 0,
    double vitaminK = 0,
    double calcium = 0,
    double iron = 0,
    double magnesium = 0,
    double potassium = 0,
    double sodium = 0,
  }) async {
    final meal = Meal(
      id: _uuid.v4(),
      userId: userId,
      dateTime: (dateTime ?? DateTime.now()).toUtc(),
      imageUrl: imageUrl,
      mealType: mealType,
      foodName: foodName,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      water: water,
      fiber: fiber,
      vitaminA: vitaminA,
      vitaminB: vitaminB,
      vitaminC: vitaminC,
      vitaminD: vitaminD,
      vitaminE: vitaminE,
      vitaminK: vitaminK,
      calcium: calcium,
      iron: iron,
      magnesium: magnesium,
      potassium: potassium,
      sodium: sodium,
    );

    await _firebaseService.saveMeal(meal);
    _todayMeals.insert(0, meal);
    _detectedFood = null;
    _firebaseService.saveDailyNutritionTotals(
      userId, DateTime.now(),
      totalCalories: calories,
      totalProtein: protein,
      totalCarbs: carbs,
      totalFat: fat,
      calorieGoal: _dailyCalorieGoal,
    );
    notifyListeners();
    return meal;
  }

  Future<void> deleteMeal(String mealId) async {
    final meal = _todayMeals.firstWhere((m) => m.id == mealId);
    await _firebaseService.deleteMeal(meal.userId, mealId);
    _todayMeals.removeWhere((m) => m.id == mealId);
    notifyListeners();
  }

  Future<void> updateMeal({
    required String mealId,
    required String foodName,
    required double calories,
    String mealType = 'snack',
    required double protein,
    required double carbs,
    required double fat,
    double water = 0,
    double fiber = 0,
  }) async {
    final index = _todayMeals.indexWhere((m) => m.id == mealId);
    if (index == -1) return;

    final updated = Meal(
      id: mealId,
      userId: _todayMeals[index].userId,
      dateTime: _todayMeals[index].dateTime,
      mealType: mealType,
      foodName: foodName,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      water: water,
      fiber: fiber,
    );
    await _firebaseService.updateMeal(updated);
    _todayMeals[index] = updated;
    notifyListeners();
  }

  void clearDetectedFood() {
    _detectedFood = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Weight Tracking ──

  Future<void> loadTodayWeight(String userId) async {
    _todayWeight = await _firebaseService.getWeightForDate(userId, DateTime.now());
    notifyListeners();
  }

  Future<void> loadWeightHistory(String userId) async {
    try {
      _weightHistory = await _firebaseService.getWeightHistory(userId, limit: 30);
    } catch (e, stack) {
      debugPrint('NutritionProvider.loadWeightHistory error: $e\n$stack');
      _weightHistory = [];
    }
    notifyListeners();
  }

  Future<void> saveWeight({
    required String userId,
    required double weight,
    String? notes,
  }) async {
    final entry = WeightEntry(
      id: _uuid.v4(),
      userId: userId,
      date: DateTime.now(),
      weight: weight,
      notes: notes,
    );
    await _firebaseService.saveWeightEntry(entry);
    _todayWeight = entry;
    _weightHistory.insert(0, entry);
    notifyListeners();
  }

  double? get latestWeight =>
      _todayWeight?.weight ?? (_weightHistory.isNotEmpty ? _weightHistory.first.weight : null);
}