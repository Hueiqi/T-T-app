class Workout {
  final String id;
  final String userId;
  final DateTime startTime;
  final DateTime? endTime;
  final String type;
  final List<int> heartRateReadings;
  final int avgHeartRate;
  final int maxHeartRate;
  final int minHeartRate;
  final double caloriesBurned;
  final String musicPlaylistId;
  final String sleepReadiness;
  final String notes;
  final double distance;
  final List<Map<String, double>> routePoints;

  Workout({
    required this.id,
    required this.userId,
    required this.startTime,
    this.endTime,
    this.type = 'cardio',
    List<int>? heartRateReadings,
    this.avgHeartRate = 0,
    this.maxHeartRate = 0,
    this.minHeartRate = 0,
    this.caloriesBurned = 0,
    this.musicPlaylistId = '',
    this.sleepReadiness = 'moderate',
    this.notes = '',
    this.distance = 0,
    List<Map<String, double>>? routePoints,
  })  : heartRateReadings = heartRateReadings ?? [],
        routePoints = routePoints ?? [];

  Duration get duration =>
      endTime != null ? endTime!.difference(startTime) : Duration.zero;

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'type': type,
        'heartRateReadings': heartRateReadings,
        'avgHeartRate': avgHeartRate,
        'maxHeartRate': maxHeartRate,
        'minHeartRate': minHeartRate,
        'caloriesBurned': caloriesBurned,
        'musicPlaylistId': musicPlaylistId,
        'sleepReadiness': sleepReadiness,
        'notes': notes,
        'distance': distance,
        'routePoints': routePoints,
      };

  factory Workout.fromMap(Map<String, dynamic> map) => Workout(
        id: map['id'] as String,
        userId: map['userId'] as String,
        startTime: DateTime.parse(map['startTime'] as String),
        endTime: map['endTime'] != null
            ? DateTime.parse(map['endTime'] as String)
            : null,
        type: map['type'] as String? ?? 'cardio',
        heartRateReadings: (map['heartRateReadings'] as List<dynamic>?)
                ?.cast<int>() ??
            [],
        avgHeartRate: (map['avgHeartRate'] as num?)?.toInt() ?? 0,
        maxHeartRate: (map['maxHeartRate'] as num?)?.toInt() ?? 0,
        minHeartRate: (map['minHeartRate'] as num?)?.toInt() ?? 0,
        caloriesBurned: (map['caloriesBurned'] as num?)?.toDouble() ?? 0,
        musicPlaylistId: map['musicPlaylistId'] as String? ?? '',
        sleepReadiness: map['sleepReadiness'] as String? ?? 'moderate',
        notes: map['notes'] as String? ?? '',
        distance: (map['distance'] as num?)?.toDouble() ?? 0,
        routePoints: (map['routePoints'] as List<dynamic>?)
                ?.map((e) => Map<String, double>.from(e as Map))
                .toList() ??
            [],
      );
}
