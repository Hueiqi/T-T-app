import 'spotify_image.dart';

class Artist {
  final String id;
  final String name;
  final String uri;
  final List<SpotifyImage> images;
  final List<String> genres;
  final int? followers;
  final int? popularity;

  const Artist({
    required this.id,
    required this.name,
    required this.uri,
    this.images = const [],
    this.genres = const [],
    this.followers,
    this.popularity,
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown Artist',
      uri: json['uri'] as String? ?? '',
      images: SpotifyImage.listFrom(json['images']),
      genres: (json['genres'] as List?)?.whereType<String>().toList() ?? const [],
      followers: (json['followers'] as Map<String, dynamic>?)?['total'] as int?,
      popularity: json['popularity'] as int?,
    );
  }

  String? get imageUrl => images.largest;

  static List<Artist> listFrom(dynamic json) {
    if (json is! List) return const [];
    return json.whereType<Map<String, dynamic>>().map(Artist.fromJson).toList();
  }

  /// Comma-separated artist names, used widely in track/album subtitles.
  static String namesOf(List<Artist> artists) =>
      artists.map((a) => a.name).join(', ');
}
