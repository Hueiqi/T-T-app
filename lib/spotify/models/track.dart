import 'album.dart';
import 'artist.dart';
import 'spotify_image.dart';

class Track {
  final String id;
  final String name;
  final String uri;
  final List<Artist> artists;
  final Album? album;
  final int durationMs;
  final bool explicit;
  final int trackNumber;
  final String? previewUrl;
  final int popularity;
  final bool isPlayable;

  const Track({
    required this.id,
    required this.name,
    required this.uri,
    this.artists = const [],
    this.album,
    this.durationMs = 0,
    this.explicit = false,
    this.trackNumber = 0,
    this.previewUrl,
    this.popularity = 0,
    this.isPlayable = true,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    // Some endpoints (e.g. playlist items) wrap the track under a "track" key.
    final t = json['track'] is Map<String, dynamic>
        ? json['track'] as Map<String, dynamic>
        : json;
    return Track(
      id: t['id'] as String? ?? '',
      name: t['name'] as String? ?? 'Unknown Track',
      uri: t['uri'] as String? ?? '',
      artists: Artist.listFrom(t['artists']),
      album: t['album'] is Map<String, dynamic>
          ? Album.fromJson(t['album'] as Map<String, dynamic>)
          : null,
      durationMs: t['duration_ms'] as int? ?? 0,
      explicit: t['explicit'] as bool? ?? false,
      trackNumber: t['track_number'] as int? ?? 0,
      previewUrl: t['preview_url'] as String?,
      popularity: t['popularity'] as int? ?? 0,
      isPlayable: t['is_playable'] as bool? ?? true,
    );
  }

  String get artistNames => Artist.namesOf(artists);

  /// Album art (falls back through the track's album images).
  String? get imageUrl => album?.images.largest;
  String? get thumbnailUrl => album?.images.smallest ?? album?.images.largest;

  /// mm:ss formatted duration.
  String get durationLabel => _formatMs(durationMs);

  static String _formatMs(int ms) {
    final totalSeconds = (ms / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static List<Track> listFrom(dynamic json) {
    if (json is! List) return const [];
    return json
        .whereType<Map<String, dynamic>>()
        .map(Track.fromJson)
        .where((t) => t.id.isNotEmpty)
        .toList();
  }
}
