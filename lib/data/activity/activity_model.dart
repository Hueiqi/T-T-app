class Exercise {
  final String name;
  final String reps;
  final int sets;
  final int? durationSeconds;
  final String? notes;
  final List<String> images;

  const Exercise({
    required this.name,
    required this.reps,
    this.sets = 1,
    this.durationSeconds,
    this.notes,
    this.images = const [],
  });

  int get durationInSeconds {
    if (durationSeconds != null) return durationSeconds!;
    final r = reps.trim().toLowerCase();
    final numberStr = RegExp(r'(\d+)').firstMatch(r)?.group(1);
    if (numberStr != null) {
      final n = int.tryParse(numberStr);
      if (n != null) {
        if (r.contains('min')) return n * 60;
        return n;
      }
    }
    return 30;
  }
}

class ActivityRoutine {
  final String id;
  final String title;
  final String duration;
  final String difficulty;
  final String focus;
  final String equipment;
  final int colorValue;
  final List<Exercise> exercises;
  final String? description;

  const ActivityRoutine({
    required this.id,
    required this.title,
    required this.duration,
    required this.difficulty,
    required this.focus,
    required this.equipment,
    required this.colorValue,
    required this.exercises,
    this.description,
  });
}