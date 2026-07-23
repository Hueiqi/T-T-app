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
        'date': date.toIso8601String(),
        'weight': weight,
        if (notes != null) 'notes': notes,
      };

  factory WeightEntry.fromMap(Map<String, dynamic> map) {
    final dateStr = map['date'] as String;
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(dateStr);
    } catch (_) {
      parsedDate = DateTime.now();
    }
    return WeightEntry(
      id: map['id'] as String,
      userId: map['userId'] as String,
      date: parsedDate,
      weight: (map['weight'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] as String?,
    );
  }
}
