import 'spotify_image.dart';

class SpotifyUser {
  final String id;
  final String displayName;
  final String? email;
  final String? country;
  final String product; // "premium" or "free"
  final List<SpotifyImage> images;
  final int? followers;

  const SpotifyUser({
    required this.id,
    required this.displayName,
    this.email,
    this.country,
    this.product = 'free',
    this.images = const [],
    this.followers,
  });

  factory SpotifyUser.fromJson(Map<String, dynamic> json) {
    return SpotifyUser(
      id: json['id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? json['id'] as String? ?? 'You',
      email: json['email'] as String?,
      country: json['country'] as String?,
      product: json['product'] as String? ?? 'free',
      images: SpotifyImage.listFrom(json['images']),
      followers: (json['followers'] as Map<String, dynamic>?)?['total'] as int?,
    );
  }

  bool get isPremium => product == 'premium';
  String? get imageUrl => images.largest;

  /// First letter for the avatar fallback.
  String get initial =>
      displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : '?';
}
