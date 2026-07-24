class NotificationLog {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final DateTime sentAt;
  final bool tapped;
  final String? tappedAt;

  const NotificationLog({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.sentAt,
    this.tapped = false,
    this.tappedAt,
  });

  NotificationLog copyWith({
    String? id,
    String? userId,
    String? type,
    String? title,
    String? body,
    DateTime? sentAt,
    bool? tapped,
    String? tappedAt,
  }) {
    return NotificationLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      sentAt: sentAt ?? this.sentAt,
      tapped: tapped ?? this.tapped,
      tappedAt: tappedAt ?? this.tappedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'title': title,
      'body': body,
      'sentAt': sentAt.toIso8601String(),
      'tapped': tapped,
      'tappedAt': tappedAt,
    };
  }

  factory NotificationLog.fromMap(Map<String, dynamic> map) {
    return NotificationLog(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      type: map['type'] as String? ?? 'general',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      sentAt: map['sentAt'] != null
          ? DateTime.parse(map['sentAt'] as String)
          : DateTime.now(),
      tapped: map['tapped'] as bool? ?? false,
      tappedAt: map['tappedAt'] as String?,
    );
  }
}
