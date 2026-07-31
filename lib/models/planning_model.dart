class DailyActivity {
  final String time;
  final String title;
  final String description;
  final String type;

  DailyActivity({
    required this.time,
    required this.title,
    required this.description,
    required this.type,
  });

  factory DailyActivity.fromJson(Map<String, dynamic> json) => DailyActivity(
        time: json['time'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        type: json['type'] as String? ?? '',
      );
}

class MealPlan {
  final String meal;
  final String time;
  final String description;
  final int calories;
  final List<String> options;

  MealPlan({
    required this.meal,
    required this.time,
    required this.description,
    required this.calories,
    required this.options,
  });

  factory MealPlan.fromJson(Map<String, dynamic> json) => MealPlan(
        meal: json['meal'] as String? ?? '',
        time: json['time'] as String? ?? '',
        description: json['description'] as String? ?? '',
        calories: (json['calories'] as num?)?.toInt() ?? 0,
        options: (json['options'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
}

class WorkoutDay {
  final String day;
  final String focus;
  final int durationMinutes;
  final List<String> exercises;

  WorkoutDay({
    required this.day,
    required this.focus,
    required this.durationMinutes,
    required this.exercises,
  });

  factory WorkoutDay.fromJson(Map<String, dynamic> json) => WorkoutDay(
        day: json['day'] as String? ?? '',
        focus: json['focus'] as String? ?? '',
        durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 30,
        exercises: (json['exercises'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
}

/// Monday..Sunday, matching DateTime.weekday (1..7) and WorkoutDay.day.
const List<String> kWeekdayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

class FitnessPlan {
  final String id;
  final String title;
  final String tagline;
  final String difficulty;
  final String description;
  final int dailyCalories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final String workoutStyle;
  final int workoutsPerWeek;
  final int workoutDurationMinutes;
  final List<String> sampleExercises;
  final List<String> mealTips;
  final List<String> highlights;
  final String intensity;
  final int estimatedGoalWeeks;
  final int sleepHours;
  final String sleepBedtime;
  final List<DailyActivity> dailySchedule;
  final List<MealPlan> meals;
  final List<WorkoutDay> weeklyWorkouts;
  final bool isSelected;

  FitnessPlan({
    required this.id,
    required this.title,
    required this.tagline,
    required this.difficulty,
    required this.description,
    required this.dailyCalories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.workoutStyle,
    required this.workoutsPerWeek,
    required this.workoutDurationMinutes,
    required this.sampleExercises,
    required this.mealTips,
    required this.highlights,
    required this.intensity,
    required this.estimatedGoalWeeks,
    required this.sleepHours,
    required this.sleepBedtime,
    required this.dailySchedule,
    required this.meals,
    required this.weeklyWorkouts,
    this.isSelected = false,
  });

  /// Rest-day version of the 'workout' slot in [dailySchedule], for days
  /// with no [WorkoutDay] entry in [weeklyWorkouts]. Slotted at the same
  /// time as whichever workout activity it replaces, so the rest of the
  /// day's timing is undisturbed.
  static DailyActivity _restDayActivity(String time) => DailyActivity(
        time: time,
        title: 'Rest Day',
        description:
            'No scheduled training — light stretching or a walk is fine, '
            'but let your body recover today.',
        type: 'rest',
      );

  /// [dailySchedule] for a specific date, built from the plan's base daily
  /// template with the main 'workout' slot swapped for that day's actual
  /// [WorkoutDay] (or a rest day, if [weeklyWorkouts] has none scheduled).
  ///
  /// Without this, every day of the plan showed the exact same generic
  /// "Workout" entry from [dailySchedule] regardless of what [weeklyWorkouts]
  /// — which already varies per weekday — actually says, and a rest day had
  /// no way to show up in the schedule at all.
  ///
  /// Some templates have two 'workout' entries in one day (e.g. a morning
  /// cardio slot plus a main evening session). Only the first is treated as
  /// the "main" slot that reflects [weeklyWorkouts]/rest; a second slot is
  /// left as its generic description on a training day, and dropped
  /// entirely on a rest day rather than duplicating the rest message.
  List<DailyActivity> scheduleForDate(DateTime date) {
    if (dailySchedule.isEmpty) return dailySchedule;
    if (weeklyWorkouts.isEmpty) return dailySchedule;

    final dayName = kWeekdayNames[date.weekday - 1];
    final todayWorkout =
        weeklyWorkouts.where((w) => w.day == dayName).firstOrNull;
    final isRestDay = todayWorkout == null;

    var sawMainWorkoutSlot = false;
    final result = <DailyActivity>[];
    for (final activity in dailySchedule) {
      if (activity.type != 'workout') {
        result.add(activity);
        continue;
      }

      if (!sawMainWorkoutSlot) {
        sawMainWorkoutSlot = true;
        result.add(isRestDay
            ? _restDayActivity(activity.time)
            : DailyActivity(
                time: activity.time,
                title: todayWorkout.focus,
                description: todayWorkout.exercises.isEmpty
                    ? activity.description
                    : '${todayWorkout.durationMinutes} min · '
                        '${todayWorkout.exercises.take(3).join(', ')}',
                type: 'workout',
              ));
        continue;
      }

      // Secondary workout slot: keep as-is on a training day, drop on rest.
      if (!isRestDay) result.add(activity);
    }
    return result;
  }

  FitnessPlan copyWith({bool? isSelected}) => FitnessPlan(
        id: id,
        title: title,
        tagline: tagline,
        difficulty: difficulty,
        description: description,
        dailyCalories: dailyCalories,
        proteinG: proteinG,
        carbsG: carbsG,
        fatG: fatG,
        workoutStyle: workoutStyle,
        workoutsPerWeek: workoutsPerWeek,
        workoutDurationMinutes: workoutDurationMinutes,
        sampleExercises: sampleExercises,
        mealTips: mealTips,
        highlights: highlights,
        intensity: intensity,
        estimatedGoalWeeks: estimatedGoalWeeks,
        sleepHours: sleepHours,
        sleepBedtime: sleepBedtime,
        dailySchedule: dailySchedule,
        meals: meals,
        weeklyWorkouts: weeklyWorkouts,
        isSelected: isSelected ?? this.isSelected,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'tagline': tagline,
        'difficulty': difficulty,
        'description': description,
        'daily_calories': dailyCalories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'workout_style': workoutStyle,
        'workouts_per_week': workoutsPerWeek,
        'workout_duration_minutes': workoutDurationMinutes,
        'sample_exercises': sampleExercises,
        'meal_tips': mealTips,
        'highlights': highlights,
        'intensity': intensity,
        'estimated_goal_weeks': estimatedGoalWeeks,
        'sleep_hours': sleepHours,
        'sleep_bedtime': sleepBedtime,
        'daily_schedule': dailySchedule
            .map((a) => {
                  'time': a.time,
                  'title': a.title,
                  'description': a.description,
                  'type': a.type,
                })
            .toList(),
        'meals': meals
            .map((m) => {
                  'meal': m.meal,
                  'time': m.time,
                  'description': m.description,
                  'calories': m.calories,
                  'options': m.options,
                })
            .toList(),
        'weekly_workouts': weeklyWorkouts
            .map((w) => {
                  'day': w.day,
                  'focus': w.focus,
                  'duration_minutes': w.durationMinutes,
                  'exercises': w.exercises,
                })
            .toList(),
        'is_selected': isSelected,
      };

  factory FitnessPlan.fromJson(Map<String, dynamic> json, String id) =>
      FitnessPlan(
        id: id,
        title: json['title'] as String? ?? 'Plan',
        tagline: json['tagline'] as String? ?? '',
        difficulty: json['difficulty'] as String? ?? 'intermediate',
        description: json['description'] as String? ?? '',
        
        dailyCalories: (json['daily_calories'] as num?)?.toInt() ?? 2000,
        proteinG: (json['protein_g'] as num?)?.toDouble() ?? 100,
        carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 200,
        fatG: (json['fat_g'] as num?)?.toDouble() ?? 50,
        workoutStyle: json['workout_style'] as String? ?? '',
        workoutsPerWeek:
            (json['workouts_per_week'] as num?)?.toInt() ?? 3,
        workoutDurationMinutes:
            (json['workout_duration_minutes'] as num?)?.toInt() ?? 30,
        sampleExercises: (json['sample_exercises'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        mealTips: (json['meal_tips'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        highlights: (json['highlights'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        intensity: json['intensity'] as String? ?? 'medium',
        estimatedGoalWeeks:
            (json['estimated_goal_weeks'] as num?)?.toInt() ?? 12,
        sleepHours: (json['sleep_hours'] as num?)?.toInt() ?? 8,
        sleepBedtime: json['sleep_bedtime'] as String? ?? '10:00 PM',
        dailySchedule: (json['daily_schedule'] as List<dynamic>?)
                ?.map((e) =>
                    DailyActivity.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        meals: (json['meals'] as List<dynamic>?)
                ?.map(
                    (e) => MealPlan.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        weeklyWorkouts: (json['weekly_workouts'] as List<dynamic>?)
                ?.map((e) =>
                    WorkoutDay.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
