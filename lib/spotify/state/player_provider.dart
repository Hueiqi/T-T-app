import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/playback_state.dart';
import '../services/playback/playback.dart';
import '../services/spotify_api.dart';

/// UI-facing playback controller. Delegates to a platform [PlaybackEngine]
/// (Web Playback SDK on web, native App Remote on mobile) and keeps a local
/// progress ticker so the seek bar animates smoothly between SDK updates.
class PlayerProvider extends ChangeNotifier {
  PlayerProvider(this._engine) {
    _stateSub = _engine.onStateChanged.listen(_onState);
    _readySub = _engine.onReady.listen(_onReady);
    _errorSub = _engine.onError.listen(_onError);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  final PlaybackEngine _engine;

  late final StreamSubscription _stateSub;
  late final StreamSubscription _readySub;
  late final StreamSubscription _errorSub;
  late final Timer _ticker;

  PlaybackState _state = PlaybackState.empty;
  PlaybackState get state => _state;

  bool _ready = false;
  bool get isReady => _ready;

  String? _error;
  String? get error => _error;

  double _volume = 0.8;
  double get volume => _volume;

  final Completer<void> _readyCompleter = Completer<void>();

  Future<void> initialize() => _engine.initialize();

  bool get hasTrack => _state.hasTrack;
  bool get isPlaying => _state.isActive && !_state.isPaused;

  // ---- event handlers -------------------------------------------------------

  void _onReady(bool ready) {
    _ready = ready;
    if (ready && !_readyCompleter.isCompleted) _readyCompleter.complete();
    notifyListeners();
  }

  void _onState(PlaybackState? s) {
    if (s == null) {
      _state = _state.copyWith(isActive: false, isPaused: true);
    } else {
      _state = s;
    }
    notifyListeners();
  }

  void _onError(String message) {
    _error = message;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _tick() {
    if (!_state.isActive || _state.isPaused || !_state.hasTrack) return;
    final next = _state.positionMs + 1000;
    if (next <= _state.durationMs) {
      _state = _state.copyWith(positionMs: next);
      notifyListeners();
    }
  }

  Future<void> _ensureReady() async {
    if (_engine.isReady) return;
    try {
      await _readyCompleter.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      _error = 'Player is not ready yet. Try again in a moment.';
      notifyListeners();
    }
  }

  // ---- playback commands ----------------------------------------------------

  Future<void> playContext(String contextUri, {int? offsetIndex}) async {
    await _ensureReady();
    try {
      await _engine.playContext(contextUri, offsetIndex: offsetIndex);
    } on SpotifyApiException catch (e) {
      _onError(_friendlyPlayError(e));
    } catch (e) {
      _onError('Playback failed: $e');
    }
  }

  Future<void> playTracks(List<String> uris, {int offset = 0}) async {
    if (uris.isEmpty) return;
    await _ensureReady();
    try {
      await _engine.playUris(uris, offset: offset);
    } on SpotifyApiException catch (e) {
      _onError(_friendlyPlayError(e));
    } catch (e) {
      _onError('Playback failed: $e');
    }
  }

  Future<void> playTrack(String uri) => playTracks([uri]);

  Future<void> togglePlay() async {
    final wasPlaying = isPlaying;
    if (_state.hasTrack) {
      _state = _state.copyWith(isPaused: !_state.isPaused);
      notifyListeners();
    }
    if (wasPlaying) {
      await _engine.pause();
    } else {
      await _engine.resume();
    }
  }

  /// Unconditionally pauses playback (used by the "No music" workout status).
  Future<void> pause() async {
    if (_state.hasTrack && !_state.isPaused) {
      _state = _state.copyWith(isPaused: true);
      notifyListeners();
    }
    await _engine.pause();
  }

  Future<void> next() => _engine.next();
  Future<void> previous() => _engine.previous();

  Future<void> seek(int positionMs) async {
    _state = _state.copyWith(positionMs: positionMs);
    notifyListeners();
    await _engine.seek(positionMs);
  }

  Future<void> toggleShuffle() async {
    final target = !_state.shuffle;
    _state = _state.copyWith(shuffle: target);
    notifyListeners();
    try {
      await _engine.setShuffle(target);
    } catch (_) {}
  }

  Future<void> cycleRepeat() async {
    final next = switch (_state.repeatMode) {
      LoopMode.off => LoopMode.context,
      LoopMode.context => LoopMode.track,
      LoopMode.track => LoopMode.off,
    };
    _state = _state.copyWith(repeatMode: next);
    notifyListeners();
    try {
      await _engine.setRepeat(next);
    } catch (_) {}
  }

  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _engine.setVolume(_volume);
  }

  String _friendlyPlayError(SpotifyApiException e) {
    if (e.isForbidden) return 'Playback failed — Spotify Premium is required.';
    if (e.isNotFound) {
      return 'No active device found. Reloading the player may help.';
    }
    return 'Playback failed: ${e.message}';
  }

  @override
  void dispose() {
    _ticker.cancel();
    _stateSub.cancel();
    _readySub.cancel();
    _errorSub.cancel();
    _engine.dispose();
    super.dispose();
  }
}
