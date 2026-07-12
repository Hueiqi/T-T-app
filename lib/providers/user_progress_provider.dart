import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProgressProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId;

  int totalWorkouts = 0;
  int totalSteps = 0;
  double totalDistanceKm = 0.0;
  int totalWorkoutMinutes = 0;
  int dietDaysCompleted = 0;
  int planningWeeksCompleted = 0;
  int weeksActive = 0;
  DateTime? joinDate;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadUserProgress(String userId) async {
    if (_userId == userId && !_isLoading) return;
    _userId = userId;
    _isLoading = true;
    notifyListeners();

    try {
      final doc =
          await _firestore.collection('userProgress').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        totalWorkouts = data['totalWorkouts'] ?? 0;
        totalSteps = data['totalSteps'] ?? 0;
        totalDistanceKm = (data['totalDistanceKm'] ?? 0.0).toDouble();
        totalWorkoutMinutes = data['totalWorkoutMinutes'] ?? 0;
        dietDaysCompleted = data['dietDaysCompleted'] ?? 0;
        planningWeeksCompleted = data['planningWeeksCompleted'] ?? 0;
        if (data['joinDate'] != null) {
          joinDate = (data['joinDate'] as Timestamp).toDate();
          weeksActive = _calculateWeeksActive(joinDate!);
        } else {
          weeksActive = 0;
        }
      } else {
        await _createDefaultProgress(userId);
      }
    } catch (e) {
      debugPrint('Error loading user progress: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _createDefaultProgress(String userId) async {
    final now = DateTime.now();
    final data = {
      'totalWorkouts': 0,
      'totalSteps': 0,
      'totalDistanceKm': 0.0,
      'totalWorkoutMinutes': 0,
      'dietDaysCompleted': 0,
      'planningWeeksCompleted': 0,
      'joinDate': Timestamp.fromDate(now),
    };
    await _firestore.collection('userProgress').doc(userId).set(data);
    totalWorkouts = 0;
    totalSteps = 0;
    totalDistanceKm = 0.0;
    totalWorkoutMinutes = 0;
    dietDaysCompleted = 0;
    planningWeeksCompleted = 0;
    joinDate = now;
    weeksActive = 0;
  }

  int _calculateWeeksActive(DateTime join) {
    final now = DateTime.now();
    final diff = now.difference(join);
    return (diff.inDays / 7).floor();
  }

  Future<void> incrementWorkouts({int amount = 1}) async {
    if (_userId == null) return;
    totalWorkouts += amount;
    await _updateField('totalWorkouts', totalWorkouts);
    notifyListeners();
  }

  Future<void> addSteps(int steps) async {
    if (_userId == null || steps <= 0) return;
    totalSteps += steps;
    await _updateField('totalSteps', totalSteps);
    notifyListeners();
  }

  Future<void> addDistance(double km) async {
    if (_userId == null || km <= 0) return;
    totalDistanceKm += km;
    await _updateField('totalDistanceKm', totalDistanceKm);
    notifyListeners();
  }

  Future<void> addWorkoutMinutes(int minutes) async {
    if (_userId == null || minutes <= 0) return;
    totalWorkoutMinutes += minutes;
    await _updateField('totalWorkoutMinutes', totalWorkoutMinutes);
    notifyListeners();
  }

  Future<void> incrementDietDays() async {
    if (_userId == null) return;
    dietDaysCompleted += 1;
    await _updateField('dietDaysCompleted', dietDaysCompleted);
    notifyListeners();
  }

  Future<void> incrementPlanningWeeks() async {
    if (_userId == null) return;
    planningWeeksCompleted += 1;
    await _updateField('planningWeeksCompleted', planningWeeksCompleted);
    notifyListeners();
  }

  Future<void> _updateField(String field, dynamic value) async {
    try {
      await _firestore
          .collection('userProgress')
          .doc(_userId!)
          .update({field: value});
    } catch (e) {
      debugPrint('Error updating $field: $e');
    }
  }

  Future<void> updateAllStats({
    int? workouts,
    int? steps,
    double? distance,
    int? minutes,
    int? dietDays,
    int? planWeeks,
  }) async {
    if (_userId == null) return;
    final updates = <String, dynamic>{};
    if (workouts != null) {
      totalWorkouts = workouts;
      updates['totalWorkouts'] = workouts;
    }
    if (steps != null) {
      totalSteps = steps;
      updates['totalSteps'] = steps;
    }
    if (distance != null) {
      totalDistanceKm = distance;
      updates['totalDistanceKm'] = distance;
    }
    if (minutes != null) {
      totalWorkoutMinutes = minutes;
      updates['totalWorkoutMinutes'] = minutes;
    }
    if (dietDays != null) {
      dietDaysCompleted = dietDays;
      updates['dietDaysCompleted'] = dietDays;
    }
    if (planWeeks != null) {
      planningWeeksCompleted = planWeeks;
      updates['planningWeeksCompleted'] = planWeeks;
    }
    if (updates.isNotEmpty) {
      await _firestore
          .collection('userProgress')
          .doc(_userId!)
          .update(updates);
      notifyListeners();
    }
  }

  Future<void> resetProgress() async {
    if (_userId == null) return;
    await _createDefaultProgress(_userId!);
    notifyListeners();
  }

  void init(FirebaseAuth auth) {
    auth.authStateChanges().listen((User? user) {
      if (user != null) {
        loadUserProgress(user.uid);
      } else {
        _userId = null;
        totalWorkouts = 0;
        totalSteps = 0;
        totalDistanceKm = 0;
        totalWorkoutMinutes = 0;
        dietDaysCompleted = 0;
        planningWeeksCompleted = 0;
        weeksActive = 0;
        joinDate = null;
        notifyListeners();
      }
    });
  }
}
