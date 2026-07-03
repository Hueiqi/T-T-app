class Exercise {
  final String name;
  final String reps;
  final int sets;
  final int? durationSeconds;
  final String? notes;

  const Exercise({
    required this.name,
    required this.reps,
    this.sets = 1,
    this.durationSeconds,
    this.notes,
  });

  int get durationInSeconds {
    if (durationSeconds != null) return durationSeconds!;
    final r = reps.trim().toLowerCase();
    if (r.endsWith('s')) {
      final s = int.tryParse(r.replaceAll('s', ''));
      if (s != null) return s;
    } else if (r.contains('min')) {
      final m = int.tryParse(r.replaceAll(RegExp(r'[^0-9]'), ''));
      if (m != null) return m * 60;
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
  final String icon;
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
    required this.icon,
    required this.exercises,
    this.description,
  });
}
