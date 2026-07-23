import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/workout_model.dart';
import '../models/meal_model.dart';
import '../models/sleep_model.dart';
import '../models/notification_settings_model.dart';
import '../models/notification_log_model.dart';
import '../models/weight_entry_model.dart';
import '../models/place_model.dart';
import '../models/planning_model.dart';
import '../models/user_model.dart';
import 'package:intl/intl.dart';
import '../models/saved_food_model.dart'; 


bool _firestoreAvailable() {
  try {
    Firebase.app();
    return true;
  } catch (_) {
    return false;
  }
}

class _CacheEntry<T> {
  final T data;
  final DateTime expiresAt;
  _CacheEntry(this.data, this.expiresAt);
}

class FirebaseService {
  FirebaseFirestore? _firestore;
  FirebaseStorage? _storage;
  final bool _demoMode;
  final Map<String, _CacheEntry<dynamic>> _cache = {};
  static const Duration _cacheTtl = Duration(seconds: 30);

  FirebaseService() : _demoMode = !_firestoreAvailable() {
    if (!_demoMode) {
      _firestore = FirebaseFirestore.instance;
      _storage = FirebaseStorage.instance;
    }
  }

  dynamic _getCached(String key) {
    final entry = _cache[key];
    if (entry != null && DateTime.now().isBefore(entry.expiresAt)) {
      return entry.data;
    }
    _cache.remove(key);
    return null;
  }

  void _setCache(String key, dynamic data) {
    _cache[key] = _CacheEntry(data, DateTime.now().add(_cacheTtl));
  }

  void invalidateCache() {
    _cache.clear();
  }

  Future<void> saveWorkout(Workout workout) async {
    if (_demoMode) return;
    try {
      await _firestore!
          .collection('users')
          .doc(workout.userId)
          .collection('workouts')
          .doc(workout.id)
          .set(workout.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('saveWorkout error: $e');
    }
  }

  Future<void> saveWorkoutEndData(Workout workout, double caloriesBurned) async {
    if (_demoMode) return;
    try {
      final batch = _firestore!.batch();

      final workoutRef = _firestore!
          .collection('users')
          .doc(workout.userId)
          .collection('workouts')
          .doc(workout.id);

      batch.set(workoutRef, {
        ...workout.toMap(),
        'avgHeartRate': workout.avgHeartRate,
        'maxHeartRate': workout.maxHeartRate,
        'minHeartRate': workout.minHeartRate,
        'caloriesBurned': workout.caloriesBurned,
        'heartRateReadings': workout.heartRateReadings,
      }, SetOptions(merge: true));

      if (caloriesBurned > 0) {
        final dateKey = '${workout.startTime.year}-${workout.startTime.month.toString().padLeft(2, '0')}-${workout.startTime.day.toString().padLeft(2, '0')}';
        final dailyRef = _firestore!
            .collection('users')
            .doc(workout.userId)
            .collection('dailyTotals')
            .doc(dateKey);
        batch.set(dailyRef, {
          'date': dateKey,
          'caloriesBurned': FieldValue.increment(caloriesBurned),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
    } catch (e) {
      debugPrint('saveWorkoutEndData error: $e');
    }
  }

  Future<List<Workout>> getWorkouts(String userId) async {
    if (_demoMode) return [];
    final cacheKey = 'workouts_$userId';
    final cached = _getCached(cacheKey) as List<Workout>?;
    if (cached != null) return cached;
    try {
      final snapshot = await _firestore!
          .collection('users')
          .doc(userId)
          .collection('workouts')
          .orderBy('startTime', descending: true)
          .limit(30)
          .get();
      final result = snapshot.docs
          .map((doc) => Workout.fromMap(
              Map<String, dynamic>.from(doc.data() as Map)))
          .toList();
      _setCache(cacheKey, result);
      return result;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveMeal(Meal meal) async {
    if (_demoMode) return;
    try {
      await _firestore!
          .collection('meals')
          .doc(meal.id)
          .set(meal.toMap());
    } catch (e) {
      debugPrint('saveMeal error: $e');
    }
  }

  Future<List<Meal>> getMeals(String userId, {DateTime? date}) async {
    if (_demoMode) return [];
    final dateKey = date != null ? DateFormat('yyyy-MM-dd').format(date) : 'all';
    final cacheKey = 'meals_${userId}_$dateKey';
    final cached = _getCached(cacheKey) as List<Meal>?;
    if (cached != null) return cached;
    try {
      Query query = _firestore!
          .collection('meals')
          .where('userId', isEqualTo: userId)
          .orderBy('dateTime', descending: true)
          .limit(50);
          if (date != null) {
            final startOfDay = DateTime.utc(date.year, date.month, date.day);
            final endOfDay = startOfDay.add(const Duration(days: 1));
           query = query
              .where('dateTime', isGreaterThanOrEqualTo: startOfDay)
              .where('dateTime', isLessThan: endOfDay);
          }
      final snapshot = await query.get();
      final result = snapshot.docs
          .map(
            (doc) => Meal.fromMap(Map<String, dynamic>.from(doc.data() as Map), doc.id),
          )
          .toList();
      _setCache(cacheKey, result);
      return result;
    } catch (e) {
      debugPrint('getMeals error: $e');
      return [];
    }
  }

  Future<List<Meal>> getMealsForDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    if (_demoMode) return [];
    final cacheKey = 'meals_${userId}_${start.toIso8601String()}_${end.toIso8601String()}';
    final cached = _getCached(cacheKey) as List<Meal>?;
    if (cached != null) return cached;
    try {
      final query = _firestore!
          .collection('meals')
          .where('userId', isEqualTo: userId)
          .where('dateTime', isGreaterThanOrEqualTo: start)
          .where('dateTime', isLessThanOrEqualTo: end)
          .orderBy('dateTime', descending: true);
      final snapshot = await query.get();
      final result = snapshot.docs
          .map((doc) => Meal.fromMap(Map<String, dynamic>.from(doc.data() as Map), doc.id))
          .toList();
      _setCache(cacheKey, result);
      return result;
    } catch (e) {
      debugPrint('getMealsForDateRange error: $e');
      return [];
    }
  }

  Future<void> saveSleepData(SleepData sleep) async {
    if (_demoMode) return;
    try {
      await _firestore!
          .collection('users')
          .doc(sleep.userId)
          .collection('sleep')
          .doc(sleep.id)
          .set(sleep.toMap());
    } catch (e) {
      debugPrint('saveSleepData error: $e');
    }
  }

  Future<SleepData?> getLatestSleep(String userId) async {
    if (_demoMode) return null;
    try {
      final snapshot = await _firestore!
          .collection('users')
          .doc(userId)
          .collection('sleep')
          .orderBy('date', descending: true)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return SleepData.fromMap(snapshot.docs.first.data());
    } catch (_) {
      return null;
    }
  }

  Future<List<SleepData>> getSleepHistory(String userId, {int? days}) async {
    if (_demoMode) return [];
    final cacheKey = 'sleep_${userId}_${days ?? 0}';
    final cached = _getCached(cacheKey) as List<SleepData>?;
    if (cached != null) return cached;
    try {
      Query query = _firestore!
          .collection('users')
          .doc(userId)
          .collection('sleep')
          .orderBy('date', descending: true);
      if (days != null) {
        final startDate = DateTime.now().subtract(Duration(days: days));
        query = query.where('date', isGreaterThanOrEqualTo: startDate.toIso8601String());
      }
      final snapshot = await query.get();
      final result = snapshot.docs
          .map((doc) => SleepData.fromMap(
              Map<String, dynamic>.from(doc.data() as Map)))
          .toList();
      _setCache(cacheKey, result);
      return result;
    } catch (_) {
      return [];
    }
  }

  Future<List<SleepData>> getSleepRecordsForDate(String userId, DateTime date) async {
    if (_demoMode) return [];
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(hours: 24));
      final snapshot = await _firestore!
          .collection('users')
          .doc(userId)
          .collection('sleep')
          .where('date', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .where('date', isLessThan: endOfDay.toIso8601String())
          .get();
      return snapshot.docs
          .map((doc) => SleepData.fromMap(
              Map<String, dynamic>.from(doc.data() as Map)))
          .toList();
    } catch (e) {
      debugPrint('getSleepRecordsForDate error: $e');
      return [];
    }
  }

  Future<void> deleteSleepData(String userId, String sleepId) async {
    if (_demoMode) return;
    try {
      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('sleep')
          .doc(sleepId)
          .delete();
    } catch (e) {
      debugPrint('deleteSleepData error: $e');
    }
  }

  Future<void> deleteMeal(String userId, String mealId) async {
    if (_demoMode) return;
    try {
      await _firestore!
          .collection('meals')
          .doc(mealId)
          .delete();
    } catch (e) {
      debugPrint('deleteMeal error: $e');
    }
  }

  Future<void> updateMeal(Meal meal) async {
    if (_demoMode) return;
    try {
      await _firestore!
          .collection('meals')
          .doc(meal.id)
          .update(meal.toMap());
    } catch (e) {
      debugPrint('updateMeal error: $e');
    }
  }
  // ── Saved Foods ──

Future<void> saveSavedFood(SavedFood food) async {
  if (_demoMode) return;
  try {
    await _firestore!
        .collection('users')
        .doc(food.userId)
        .collection('savedFoods')
        .doc(food.id)
        .set(food.toMap());
  } catch (e) {
    debugPrint('saveSavedFood error: $e');
  }
}

Future<List<SavedFood>> getSavedFoods(String userId) async {
  if (_demoMode) return [];
  try {
    final snapshot = await _firestore!
        .collection('users')
        .doc(userId)
        .collection('savedFoods')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => SavedFood.fromMap(Map<String, dynamic>.from(doc.data() as Map), doc.id))
        .toList();
  } catch (e) {
    debugPrint('getSavedFoods error: $e');
    return [];
  }
}

  Future<void> deleteSavedFood(String userId, String foodId) async {
    if (_demoMode) return;
    try {
      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('savedFoods')
          .doc(foodId)
          .delete();
    } catch (e) {
      debugPrint('deleteSavedFood error: $e');
    }
  }

  Future<String> uploadImageBytes(Uint8List imageBytes, String userId, String fileName) async {
    if (_demoMode) return '';
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage!.ref().child('users/$userId/food_images/${timestamp}_$fileName');
      await ref.putData(imageBytes);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('uploadImageBytes error: $e');
      return '';
    }
  }

  /// Update daily calories burned from workouts
  Future<void> updateDailyCaloriesBurned(
    String userId,
    DateTime date,
    double calories,
  ) async {
    if (_demoMode) return;
    try {
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final docRef = _firestore!
          .collection('users')
          .doc(userId)
          .collection('dailyTotals')
          .doc(dateKey);
      await docRef.set({
        'date': dateKey,
        'caloriesBurned': FieldValue.increment(calories),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('updateDailyCaloriesBurned error: $e');
    }
  }

  /// Get daily calories burned for a specific date
  Future<double> getDailyCaloriesBurned(String userId, DateTime date) async {
    if (_demoMode) return 0;
    try {
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final doc = await _firestore!
          .collection('users')
          .doc(userId)
          .collection('dailyTotals')
          .doc(dateKey)
          .get();
      if (doc.exists) {
        return (doc.data()?['caloriesBurned'] as num?)?.toDouble() ?? 0;
      }
    } catch (e) {
      debugPrint('getDailyCaloriesBurned error: $e');
    }
    return 0;
  }

  Future<Map<String, double>> getDailyCalories(String userId) async {
    final today = DateTime.now();
    final meals = await getMeals(userId, date: today);
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    for (final meal in meals) {
      totalCalories += meal.calories;
      totalProtein += meal.protein;
      totalCarbs += meal.carbs;
      totalFat += meal.fat;
    }
    return {
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
    };
  }

  Future<void> saveDailyNutritionTotals(String userId, DateTime date, {
    required double totalCalories,
    required double totalProtein,
    required double totalCarbs,
    required double totalFat,
    double? calorieGoal,
  }) async {
    if (_demoMode) return;
    try {
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('dailyTotals')
          .doc(dateKey)
          .set({
        'userId': userId,
        'date': dateKey,
        'calorieGoal': ?calorieGoal,
        'totalCalories': FieldValue.increment(totalCalories),
        'totalProtein': FieldValue.increment(totalProtein),
        'totalCarbs': FieldValue.increment(totalCarbs),
        'totalFat': FieldValue.increment(totalFat),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('saveDailyNutritionTotals error: $e');
    }
  }

  // ── Notification Settings ──

  Future<void> saveNotificationSettings(NotificationSettings settings) async {
    if (_demoMode) return;
    try {
      await _firestore!
          .collection('users')
          .doc(settings.userId)
          .collection('notificationSettings')
          .doc('preferences')
          .set(settings.toMap());
    } catch (e) {
      debugPrint('saveNotificationSettings error: $e');
    }
  }

  Future<NotificationSettings?> getNotificationSettings(String userId) async {
    if (_demoMode) return null;
    try {
      final doc = await _firestore!
          .collection('users')
          .doc(userId)
          .collection('notificationSettings')
          .doc('preferences')
          .get();
      if (doc.exists) {
        return NotificationSettings.fromMap(
            Map<String, dynamic>.from(doc.data() as Map), userId);
      }
    } catch (_) {}
    return null;
  }

  // ── Notification History ──

  Future<void> logSentNotification(NotificationLog log) async {
    if (_demoMode) return;
    try {
      await _firestore!
          .collection('users')
          .doc(log.userId)
          .collection('notificationHistory')
          .doc(log.id)
          .set(log.toMap());
    } catch (e) {
      debugPrint('logSentNotification error: $e');
    }
  }

  Future<void> markNotificationTapped(String userId, String logId) async {
    if (_demoMode) return;
    try {
      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('notificationHistory')
          .doc(logId)
          .update({'tapped': true, 'tappedAt': DateTime.now().toIso8601String()});
    } catch (e) {
      debugPrint('markNotificationTapped error: $e');
    }
  }

  Future<List<NotificationLog>> getNotificationHistory(String userId) async {
    if (_demoMode) return [];
    try {
      final snapshot = await _firestore!
          .collection('users')
          .doc(userId)
          .collection('notificationHistory')
          .orderBy('sentAt', descending: true)
          .limit(100)
          .get();
      return snapshot.docs
          .map((doc) => NotificationLog.fromMap(
              Map<String, dynamic>.from(doc.data() as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clearNotificationHistory(String userId) async {
    if (_demoMode) return;
    try {
      final snapshot = await _firestore!
          .collection('users')
          .doc(userId)
          .collection('notificationHistory')
          .get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}
  }

  Future<void> deleteNotification(String userId, String logId) async {
    if (_demoMode) return;
    try {
      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('notificationHistory')
          .doc(logId)
          .delete();
    } catch (e) {
      debugPrint('deleteNotification error: $e');
    }
  }

  // ── Weight Entries ──

  Future<void> saveWeightEntry(WeightEntry entry) async {
    if (_demoMode) return;
    try {
      await _firestore!
          .collection('users')
          .doc(entry.userId)
          .collection('weightHistory')
          .doc(entry.id)
          .set(entry.toMap());
    } catch (e) {
      debugPrint('saveWeightEntry error: $e');
    }
  }

  Future<void> deleteWeightEntry(String userId, String entryId) async {
    if (_demoMode) return;
    try {
      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('weightHistory')
          .doc(entryId)
          .delete();
    } catch (e) {
      debugPrint('deleteWeightEntry error: $e');
    }
  }

  Future<WeightEntry?> getWeightForDate(String userId, DateTime date) async {
    if (_demoMode) return null;
    try {
      final dateKey = DateTime(date.year, date.month, date.day).toIso8601String();
      final snapshot = await _firestore!
          .collection('users')
          .doc(userId)
          .collection('weightHistory')
          .where('date', isEqualTo: dateKey)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return WeightEntry.fromMap(
          Map<String, dynamic>.from(snapshot.docs.first.data() as Map));
    } catch (_) {
      return null;
    }
  }

  // ── Bookmarks (Curated Workouts) ──

  Future<void> saveBookmark(String userId, Map<String, dynamic> workout) async {
    if (_demoMode) return;
    try {
      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('bookmarks')
          .doc(workout['id'] as String)
          .set(workout);
    } catch (e) {
      debugPrint('saveBookmark error: $e');
    }
  }

  Future<void> removeBookmark(String userId, String workoutId) async {
    if (_demoMode) return;
    try {
      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('bookmarks')
          .doc(workoutId)
          .delete();
    } catch (e) {
      debugPrint('removeBookmark error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getBookmarks(String userId) async {
    if (_demoMode) return [];
    try {
      final snapshot = await _firestore!
          .collection('users')
          .doc(userId)
          .collection('bookmarks')
          .get();
      return snapshot.docs
          .map((doc) => Map<String, dynamic>.from(doc.data() as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Places ──

  Future<void> savePlace(Place place) async {
    if (_demoMode) return;
    try {
      await _firestore!
          .collection('users')
          .doc(place.userId)
          .collection('places')
          .doc(place.id)
          .set(place.toMap());
    } catch (e) {
      debugPrint('savePlace error: $e');
    }
  }

  Future<List<Place>> getPlaces(String userId) async {
    if (_demoMode) return [];
    final cacheKey = 'places_$userId';
    final cached = _getCached(cacheKey) as List<Place>?;
    if (cached != null) return cached;
    try {
      final snapshot = await _firestore!
          .collection('users')
          .doc(userId)
          .collection('places')
          .orderBy('visitedAt', descending: true)
          .limit(50)
          .get();
      final result = snapshot.docs
          .map((doc) => Place.fromMap(
              Map<String, dynamic>.from(doc.data() as Map)))
          .toList();
      _setCache(cacheKey, result);
      return result;
    } catch (_) {
      return [];
    }
  }

  // ── Daily Steps ──

  Future<void> saveDailySteps(String userId, DateTime date, int steps) async {
    if (_demoMode) return;
    try {
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('dailySteps')
          .doc(dateKey)
          .set({
        'date': dateKey,
        'steps': steps,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('dailyTotals')
          .doc(dateKey)
          .set({
        'date': dateKey,
        'dailySteps': steps,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('saveDailySteps error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getDailySteps(String userId, {int days = 7}) async {
    if (_demoMode) return [];
    final cacheKey = 'dailysteps_${userId}_$days';
    final cached = _getCached(cacheKey) as List<Map<String, dynamic>>?;
    if (cached != null) return cached;
    try {
      final startDate = DateTime.now().subtract(Duration(days: days));
      final startKey =
          '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
      final snapshot = await _firestore!
          .collection('users')
          .doc(userId)
          .collection('dailySteps')
          .where('date', isGreaterThanOrEqualTo: startKey)
          .orderBy('date', descending: false)
          .get();
      final result = snapshot.docs
          .map((doc) => Map<String, dynamic>.from(doc.data() as Map))
          .toList();
      _setCache(cacheKey, result);
      return result;
    } catch (_) {
      return [];
    }
  }

  // ── Activity History ──

  Future<void> saveActivity(String userId, Map<String, dynamic> activity) async {
    if (_demoMode) return;
    try {
      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('activities')
          .doc(activity['id'] as String)
          .set(activity);
    } catch (e) {
      debugPrint('saveActivity error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getActivities(String userId) async {
    if (_demoMode) return [];
    try {
      final snapshot = await _firestore!
          .collection('users')
          .doc(userId)
          .collection('activities')
          .orderBy('completedAt', descending: true)
          .limit(50)
          .get();
      return snapshot.docs
          .map((doc) => Map<String, dynamic>.from(doc.data() as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Plan Persistence ──

  Future<void> savePlan(String userId, FitnessPlan plan) async {
    if (_demoMode) return;
    try {
      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('plans')
          .doc(plan.id)
          .set(plan.toMap());
    } catch (e) {
      debugPrint('savePlan error: $e');
    }
  }

  Future<List<FitnessPlan>> getPlans(String userId) async {
    if (_demoMode) return [];
    try {
      final snapshot = await _firestore!
          .collection('users')
          .doc(userId)
          .collection('plans')
          .get();
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        return FitnessPlan.fromJson(data, doc.id);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<AppUser?> getUser(String userId) async {
    if (_demoMode) return null;
    try {
      final doc = await _firestore!.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return AppUser.fromMap(Map<String, dynamic>.from(doc.data() as Map));
    } catch (e) {
      debugPrint('getUser error: $e');
      return null;
    }
  }

  Future<void> updateUser(AppUser user) async {
    if (_demoMode) return;
    try {
      await _firestore!.collection('users').doc(user.uid).update(user.toMap());
    } catch (e) {
      debugPrint('updateUser error: $e');
    }
  }

  Future<FitnessPlan?> getPlanById(String userId, String planId) async {
    if (_demoMode) return null;
    try {
      final doc = await _firestore!
          .collection('users')
          .doc(userId)
          .collection('plans')
          .doc(planId)
          .get();
      if (!doc.exists) return null;
      return FitnessPlan.fromJson(
          Map<String, dynamic>.from(doc.data() as Map), doc.id);
    } catch (e) {
      debugPrint('getPlanById error: $e');
      return null;
    }
  }

  Future<List<WeightEntry>> getWeightHistory(String userId, {int? limit}) async {
    if (_demoMode) return [];
    try {
      Query query = _firestore!
          .collection('users')
          .doc(userId)
          .collection('weightHistory')
          .orderBy('date', descending: true);
      if (limit != null) query = query.limit(limit);
      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => WeightEntry.fromMap(
              Map<String, dynamic>.from(doc.data() as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
