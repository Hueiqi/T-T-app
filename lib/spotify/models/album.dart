import 'artist.dart';
import 'spotify_image.dart';

class Album {
  final String id;
  final String name;
  final String uri;
  final String albumType; // album, single, compilation
  final List<SpotifyImage> images;
  final List<Artist> artists;
  final String? releaseDate;
  final int totalTracks;

  const Album({
    required this.id,
    required this.name,
    required this.uri,
    this.albumType = 'album',
    this.images = const [],
    this.artists = const [],
    this.releaseDate,
    this.totalTracks = 0,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown Album',
      uri: json['uri'] as String? ?? '',
      albumType: json['album_type'] as String? ?? 'album',
      images: SpotifyImage.listFrom(json['images']),
      artists: Artist.listFrom(json['artists']),
      releaseDate: json['release_date'] as String?,
      totalTracks: json['total_tracks'] as int? ?? 0,
    );
  }

  String? get imageUrl => images.largest;
  String get artistNames => Artist.namesOf(artists);

  /// Just the year portion of the release date, when present.
  String? get releaseYear {
    final d = releaseDate;
    if (d == null || d.isEmpty) return null;
    return d.length >= 4 ? d.substring(0, 4) : d;
  }

  static List<Album> listFrom(dynamic json) {
    if (json is! List) return const [];
    return json.whereType<Map<String, dynamic>>().map(Album.fromJson).toList();
  }
}
