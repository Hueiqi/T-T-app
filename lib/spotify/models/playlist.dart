import 'spotify_image.dart';

class Playlist {
  final String id;
  final String name;
  final String uri;
  final String description;
  final List<SpotifyImage> images;
  final String ownerName;
  final String ownerId;
  final int totalTracks;
  final bool isPublic;
  final bool collaborative;

  const Playlist({
    required this.id,
    required this.name,
    required this.uri,
    this.description = '',
    this.images = const [],
    this.ownerName = '',
    this.ownerId = '',
    this.totalTracks = 0,
    this.isPublic = true,
    this.collaborative = false,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'] as Map<String, dynamic>?;
    final tracks = json['tracks'] as Map<String, dynamic>?;
    return Playlist(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled Playlist',
      uri: json['uri'] as String? ?? '',
      description: _stripTags(json['description'] as String? ?? ''),
      images: SpotifyImage.listFrom(json['images']),
      ownerName: owner?['display_name'] as String? ?? owner?['id'] as String? ?? '',
      ownerId: owner?['id'] as String? ?? '',
      totalTracks: tracks?['total'] as int? ?? 0,
      isPublic: json['public'] as bool? ?? true,
      collaborative: json['collaborative'] as bool? ?? false,
    );
  }

  String? get imageUrl => images.largest;

  // Spotify playlist descriptions can contain HTML entities/tags.
  static String _stripTags(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&#x27;', "'")
        .replaceAll('&quot;', '"')
        .trim();
  }

  static List<Playlist> listFrom(dynamic json) {
    if (json is! List) return const [];
    return json
        .whereType<Map<String, dynamic>>()
        .map(Playlist.fromJson)
        .where((p) => p.id.isNotEmpty)
        .toList();
  }
}
