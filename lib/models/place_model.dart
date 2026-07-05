class Place {
  final String id;
  final String userId;
  final double latitude;
  final double longitude;
  final DateTime visitedAt;
  final String? address;
  final String? name;

  Place({
    required this.id,
    this.userId = '',
    required this.latitude,
    required this.longitude,
    required this.visitedAt,
    this.address,
    this.name,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'latitude': latitude,
        'longitude': longitude,
        'visitedAt': visitedAt.toIso8601String(),
        'address': address,
        'name': name,
      };

  factory Place.fromMap(Map<String, dynamic> map) => Place(
        id: map['id'] as String,
        userId: map['userId'] as String? ?? '',
        latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
        visitedAt: DateTime.parse(map['visitedAt'] as String),
        address: map['address'] as String?,
        name: map['name'] as String?,
      );
}
