/// Repeat modes matching the Web Playback SDK (0=off, 1=context, 2=track).
enum LoopMode { off, context, track }

/// A lightweight track representation as reported by the player.
class PlayerTrack {
  final String id;
  final String uri;
  final String name;
  final String artistNames;
  final String albumName;
  final String? imageUrl;
  final int durationMs;

  const PlayerTrack({
    required this.id,
    required this.uri,
    required this.name,
    required this.artistNames,
    required this.albumName,
    required this.imageUrl,
    required this.durationMs,
  });
}

/// Snapshot of the player at a point in time. Immutable; the player service
/// emits a fresh instance on every change.
class PlaybackState {
  final bool isActive;
  final bool isPaused;
  final int positionMs;
  final int durationMs;
  final bool shuffle;
  final LoopMode repeatMode;
  final PlayerTrack? track;

  const PlaybackState({
    this.isActive = false,
    this.isPaused = true,
    this.positionMs = 0,
    this.durationMs = 0,
    this.shuffle = false,
    this.repeatMode = LoopMode.off,
    this.track,
  });

  static const PlaybackState empty = PlaybackState();

  bool get hasTrack => track != null;

  double get progress {
    if (durationMs <= 0) return 0;
    return (positionMs / durationMs).clamp(0.0, 1.0);
  }

  PlaybackState copyWith({
    bool? isActive,
    bool? isPaused,
    int? positionMs,
    int? durationMs,
    bool? shuffle,
    LoopMode? repeatMode,
    PlayerTrack? track,
  }) {
    return PlaybackState(
      isActive: isActive ?? this.isActive,
      isPaused: isPaused ?? this.isPaused,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      shuffle: shuffle ?? this.shuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      track: track ?? this.track,
    );
  }
}
