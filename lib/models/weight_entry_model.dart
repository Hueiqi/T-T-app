class WeightEntry {
  final String id;
  final String userId;
  final DateTime date;
  final double weight;
  final String? notes;

  WeightEntry({
    required this.id,
    required this.userId,
    required this.date,
    required this.weight,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'date': DateTime(date.year, date.month, date.day).toIso8601String(),
        'weight': weight,
        if (notes != null) 'notes': notes,
      };

  factory WeightEntry.fromMap(Map<String, dynamic> map) => WeightEntry(
        id: map['id'] as String,
        userId: map['userId'] as String,
        date: DateTime.parse(map['date'] as String),
        weight: (map['weight'] as num).toDouble(),
        notes: map['notes'] as String?,
      );
}
