/// A Spotify image (album art, artist photo, playlist cover, etc.).
class SpotifyImage {
  final String url;
  final int? width;
  final int? height;

  const SpotifyImage({required this.url, this.width, this.height});

  factory SpotifyImage.fromJson(Map<String, dynamic> json) {
    return SpotifyImage(
      url: json['url'] as String? ?? '',
      width: json['width'] as int?,
      height: json['height'] as int?,
    );
  }

  static List<SpotifyImage> listFrom(dynamic json) {
    if (json is! List) return const [];
    return json
        .whereType<Map<String, dynamic>>()
        .map(SpotifyImage.fromJson)
        .where((i) => i.url.isNotEmpty)
        .toList();
  }
}

extension ImageListX on List<SpotifyImage> {
  /// Largest available image url, or null when the list is empty.
  String? get largest {
    if (isEmpty) return null;
    final sorted = [...this]
      ..sort((a, b) => (b.width ?? 0).compareTo(a.width ?? 0));
    return sorted.first.url;
  }

  /// Smallest available image url (handy for tiny thumbnails).
  String? get smallest {
    if (isEmpty) return null;
    final sorted = [...this]
      ..sort((a, b) => (a.width ?? 0).compareTo(b.width ?? 0));
    return sorted.first.url;
  }

  /// A medium-ish image url; falls back to the largest.
  String? get medium {
    if (isEmpty) return null;
    if (length == 1) return first.url;
    return this[length ~/ 2].url;
  }
}
