class SleepData {
  final String id;
  final String userId;
  final DateTime date;
  final double hoursSlept;
  final int deepSleepMinutes;
  final int lightSleepMinutes;
  final int remSleepMinutes;
  final int awakeMinutes;
  final String quality;
  final String source;

  SleepData({
    required this.id,
    required this.userId,
    required this.date,
    this.hoursSlept = 0,
    this.deepSleepMinutes = 0,
    this.lightSleepMinutes = 0,
    this.remSleepMinutes = 0,
    this.awakeMinutes = 0,
    this.quality = 'moderate',
    this.source = 'smartwatch',
  });

  String get readinessLevel {
    if (hoursSlept >= 7 && deepSleepMinutes >= 90) return 'high';
    if (hoursSlept >= 6 && deepSleepMinutes >= 60) return 'moderate';
    return 'low';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'date': date.toIso8601String(),
    'hoursSlept': hoursSlept,
    'deepSleepMinutes': deepSleepMinutes,
    'lightSleepMinutes': lightSleepMinutes,
    'remSleepMinutes': remSleepMinutes,
    'awakeMinutes': awakeMinutes,
    'quality': quality,
    'source': source,
  };

  factory SleepData.fromMap(Map<String, dynamic> map) => SleepData(
    id: map['id'] as String,
    userId: map['userId'] as String,
    date: DateTime.parse(map['date'] as String),
    hoursSlept: (map['hoursSlept'] as num?)?.toDouble() ?? 0,
    deepSleepMinutes: (map['deepSleepMinutes'] as num?)?.toInt() ?? 0,
    lightSleepMinutes: (map['lightSleepMinutes'] as num?)?.toInt() ?? 0,
    remSleepMinutes: (map['remSleepMinutes'] as num?)?.toInt() ?? 0,
    awakeMinutes: (map['awakeMinutes'] as num?)?.toInt() ?? 0,
    quality: map['quality'] as String? ?? 'moderate',
    source: map['source'] as String? ?? 'smartwatch',
  );
}
