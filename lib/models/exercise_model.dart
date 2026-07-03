class ExerciseDb {
  final String id;
  final String name;
  final String force;
  final String level;
  final String mechanic;
  final String equipment;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> instructions;
  final String category;
  final List<String> images;

  ExerciseDb({
    required this.id,
    required this.name,
    required this.force,
    required this.mechanic,
    required this.equipment,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.instructions,
    required this.category,
    required this.images,
    this.level = 'beginner',
  });

  factory ExerciseDb.fromJson(Map<String, dynamic> json) => ExerciseDb(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        force: json['force'] ?? '',
        level: json['level'] ?? 'beginner',
        mechanic: json['mechanic'] ?? '',
        equipment: json['equipment'] ?? '',
        primaryMuscles: List<String>.from(json['primaryMuscles'] ?? []),
        secondaryMuscles: List<String>.from(json['secondaryMuscles'] ?? []),
        instructions: List<String>.from(json['instructions'] ?? []),
        category: json['category'] ?? '',
        images: List<String>.from(json['images'] ?? []),
      );

  String get imageUrl {
    final base =
        'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises';
    if (images.isNotEmpty) {
      return '$base/${images[0]}';
    }
    return '$base/$id/0.jpg';
  }

  String? get gifUrl => null;
}
