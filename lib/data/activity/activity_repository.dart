// lib/data/activity/activity_repository.dart
export 'activity_model.dart';
export 'activity_routines.dart';

import 'activity_model.dart';
import 'activity_routines.dart';

class ActivityRepository {
  static final List<ActivityRoutine> allRoutines = [
    workoutAbs10Min,
    workoutBeginnerAbs10Min,
    workoutFullBody20MinBeginner,
    workoutCoreStability10Min,  
    workoutFullBody20MinIntense,
  ];

  static ActivityRoutine? findRoutineById(String id) {
    try {
      return allRoutines.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }
}