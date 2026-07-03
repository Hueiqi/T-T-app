import 'activity__abs_10min.dart';
import 'activity_beginner_abs_10min.dart';
import 'activity__fullbody_20min_beginner.dart';
import 'activity_sixpack_10min.dart';
import 'activity_fullbody_20min_intense.dart';
import 'activity_model.dart';
export 'activity_model.dart';

final List<ActivityRoutine> allRoutines = [
  workoutAbs10Min,
  workoutBeginnerAbs10Min,
  workoutFullBody20MinBeginner,
  workoutSixpack10Min,
  workoutFullBody20MinIntense,
];

ActivityRoutine? findRoutineById(String id) {
  try {
    return allRoutines.firstWhere((w) => w.id == id);
  } catch (_) {
    return null;
  }
}
