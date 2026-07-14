import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/exercise_db.dart';
import '../models/exercise_model.dart';

class ExerciseFavoritesProvider extends ChangeNotifier {
  Set<String> _favoriteIds = {};

  Set<String> get favoriteIds => _favoriteIds;

  bool isFavorite(String id) => _favoriteIds.contains(id);

  ExerciseFavoritesProvider() {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('exercise_favorites') ?? [];
    _favoriteIds = list.toSet();
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
    } else {
      _favoriteIds.add(id);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('exercise_favorites', _favoriteIds.toList());
    notifyListeners();
  }

  List<ExerciseDb> get favoriteExercises {
    return ExerciseDatabase.all.where((e) => _favoriteIds.contains(e.id)).toList();
  }
}
