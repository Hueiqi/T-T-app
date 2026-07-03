import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/exercise_model.dart';

class ExerciseDatabase {
  static List<ExerciseDb> _allExercises = [];
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    final jsonString = await rootBundle.loadString('assets/exercises.json');
    final List data = json.decode(jsonString);
    _allExercises = data.map((e) => ExerciseDb.fromJson(e)).toList();
    _loaded = true;
  }

  static void loadWithData(List<ExerciseDb> exercises) {
    _allExercises = exercises;
    _loaded = true;
  }

  static List<ExerciseDb> get all => _allExercises;

  static ExerciseDb? findById(String id) {
    try {
      return _allExercises.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  static ExerciseDb? findByName(String name) {
    final lower = name.toLowerCase().trim();
    try {
      return _allExercises.firstWhere(
        (e) => e.name.toLowerCase().trim() == lower,
        orElse: () => _allExercises.firstWhere(
          (e) => e.name.toLowerCase().contains(lower),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static List<ExerciseDb> search({
    String query = '',
    String? muscle,
    String? level,
    String? equipment,
  }) {
    final lowerQuery = query.toLowerCase().trim();
    return _allExercises.where((e) {
      if (query.isNotEmpty && !e.name.toLowerCase().contains(lowerQuery)) {
        return false;
      }
      if (muscle != null && !e.primaryMuscles.contains(muscle)) {
        return false;
      }
      if (level != null && e.level != level) {
        return false;
      }
      if (equipment != null && e.equipment != equipment) {
        return false;
      }
      return true;
    }).toList();
  }

  static List<ExerciseDb> getByMuscle(String muscle) {
    return _allExercises.where((e) => e.primaryMuscles.contains(muscle)).toList();
  }

  static List<String> getMuscleGroups() {
    final Set<String> muscles = {};
    for (final e in _allExercises) {
      muscles.addAll(e.primaryMuscles);
    }
    return muscles.toList()..sort();
  }

  static List<String> getEquipmentTypes() {
    final Set<String> equipment = {};
    for (final e in _allExercises) {
      if (e.equipment.isNotEmpty) {
        equipment.add(e.equipment);
      }
    }
    return equipment.toList()..sort();
  }

  static List<String> getLevels() {
    final Set<String> levels = {};
    for (final e in _allExercises) {
      if (e.level.isNotEmpty) {
        levels.add(e.level);
      }
    }
    return levels.toList()..sort();
  }
}
