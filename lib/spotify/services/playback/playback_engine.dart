import '../../models/playback_state.dart';

/// Platform-agnostic playback engine used by [PlayerProvider].
///
/// - Web: Spotify Web Playback SDK (streams audio in the browser).
/// - Mobile: native Spotify App Remote (controls the installed Spotify app).
abstract class PlaybackEngine {
  Stream<PlaybackState?> get onStateChanged;
  Stream<bool> get onReady;
  Stream<String> get onError;

  bool get isReady;

  Future<void> initialize();

  Future<void> playContext(String contextUri, {int? offsetIndex});
  Future<void> playUris(List<String> uris, {int offset = 0});

  Future<void> resume();
  Future<void> pause();
  Future<void> next();
  Future<void> previous();
  Future<void> seek(int positionMs);

  Future<void> setShuffle(bool state);
  Future<void> setRepeat(LoopMode mode);
  Future<void> setVolume(double volume);

  void dispose();
}
