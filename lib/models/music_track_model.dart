class MusicTrack {
  final String id;
  final String name;
  final String artist;
  final String albumArtUrl;
  final String previewUrl;
  final int bpm;
  final String genre;
  final String spotifyUri;

  MusicTrack({
    required this.id,
    required this.name,
    required this.artist,
    this.albumArtUrl = '',
    this.previewUrl = '',
    this.bpm = 120,
    this.genre = 'pop',
    this.spotifyUri = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'artist': artist,
    'albumArtUrl': albumArtUrl,
    'previewUrl': previewUrl,
    'bpm': bpm,
    'genre': genre,
    'spotifyUri': spotifyUri,
  };

  factory MusicTrack.fromMap(Map<String, dynamic> map) => MusicTrack(
    id: map['id'] as String,
    name: map['name'] as String,
    artist: map['artist'] as String,
    albumArtUrl: map['albumArtUrl'] as String? ?? '',
    previewUrl: map['previewUrl'] as String? ?? '',
    bpm: (map['bpm'] as num?)?.toInt() ?? 120,
    genre: map['genre'] as String? ?? 'pop',
    spotifyUri: map['spotifyUri'] as String? ?? '',
  );
}
