import 'dart:async';

import 'package:spotify_sdk/enums/repeat_mode_enum.dart' as sdk;
import 'package:spotify_sdk/models/player_state.dart' as sdk;
import 'package:spotify_sdk/spotify_sdk.dart';

import '../../core/constants.dart';
import '../../models/playback_state.dart';
import '../auth/auth.dart';
import '../spotify_api.dart';
import 'playback_engine.dart';

/// Mobile engine: drives the native Spotify App Remote. Requires the official
/// Spotify app installed and signed-in (Premium for full playback).
class MobilePlaybackEngine implements PlaybackEngine {
  MobilePlaybackEngine(this._api, this._auth);

  // Kept for parity with the web engine; browsing uses [SpotifyApi] elsewhere.
  // ignore: unused_field
  final SpotifyApi _api;
  // ignore: unused_field
  final AuthController _auth;

  final _stateCtrl = StreamController<PlaybackState?>.broadcast();
  final _readyCtrl = StreamController<bool>.broadcast();
  final _errorCtrl = StreamController<String>.broadcast();
  StreamSubscription<sdk.PlayerState>? _sub;
  bool _ready = false;

  @override
  Stream<PlaybackState?> get onStateChanged => _stateCtrl.stream;
  @override
  Stream<bool> get onReady => _readyCtrl.stream;
  @override
  Stream<String> get onError => _errorCtrl.stream;

  @override
  bool get isReady => _ready;

  @override
  Future<void> initialize() async {
    try {
      final connected = await SpotifySdk.connectToSpotifyRemote(
        clientId: SpotifyConfig.clientId,
        redirectUrl: SpotifyConfig.mobileRedirectUri,
        scope: SpotifyConfig.mobileScopeString,
      );
      _ready = connected;
      _readyCtrl.add(connected);
      if (connected) {
        _sub = SpotifySdk.subscribePlayerState().listen(
          (s) => _stateCtrl.add(_map(s)),
          onError: (Object e) => _errorCtrl.add('$e'),
        );
      } else {
        _errorCtrl.add('Could not connect to the Spotify app.');
      }
    } catch (e) {
      _errorCtrl.add('Could not connect to Spotify: $e');
    }
  }

  @override
  Future<void> playContext(String contextUri, {int? offsetIndex}) async {
    if (offsetIndex != null && offsetIndex > 0) {
      await SpotifySdk.skipToIndex(spotifyUri: contextUri, trackIndex: offsetIndex);
    } else {
      await SpotifySdk.play(spotifyUri: contextUri);
    }
  }

  @override
  Future<void> playUris(List<String> uris, {int offset = 0}) async {
    if (uris.isEmpty) return;
    final index = offset.clamp(0, uris.length - 1);
    // App Remote can't take an ad-hoc list; play the chosen track directly.
    await SpotifySdk.play(spotifyUri: uris[index]);
  }

  @override
  Future<void> resume() => SpotifySdk.resume();
  @override
  Future<void> pause() => SpotifySdk.pause();
  @override
  Future<void> next() => SpotifySdk.skipNext();
  @override
  Future<void> previous() => SpotifySdk.skipPrevious();
  @override
  Future<void> seek(int positionMs) =>
      SpotifySdk.seekTo(positionedMilliseconds: positionMs);

  @override
  Future<void> setShuffle(bool state) => SpotifySdk.setShuffle(shuffle: state);

  @override
  Future<void> setRepeat(LoopMode mode) {
    final repeat = switch (mode) {
      LoopMode.off => sdk.RepeatMode.off,
      LoopMode.track => sdk.RepeatMode.track,
      LoopMode.context => sdk.RepeatMode.context,
    };
    return SpotifySdk.setRepeatMode(repeatMode: repeat);
  }

  @override
  Future<void> setVolume(double volume) async {
    // App Remote has no volume control; the device volume is used instead.
  }

  @override
  void dispose() {
    _sub?.cancel();
    _stateCtrl.close();
    _readyCtrl.close();
    _errorCtrl.close();
    SpotifySdk.disconnect();
  }

  PlaybackState _map(sdk.PlayerState s) {
    final t = s.track;
    PlayerTrack? track;
    if (t != null) {
      final raw = t.imageUri.raw;
      // A Spotify image uri ("spotify:image:<id>") maps to the CDN url.
      final imageUrl =
          raw.isNotEmpty ? 'https://i.scdn.co/image/${raw.split(':').last}' : null;
      track = PlayerTrack(
        id: t.uri.split(':').last,
        uri: t.uri,
        name: t.name,
        artistNames: t.artists
            .map((a) => a.name ?? '')
            .where((x) => x.isNotEmpty)
            .join(', '),
        albumName: t.album.name ?? '',
        imageUrl: imageUrl,
        durationMs: t.duration,
      );
    }
    // playbackOptions.repeatMode is a *different* RepeatMode type than the one
    // setRepeatMode wants, so map by name to avoid the type clash.
    final repeat = switch (s.playbackOptions.repeatMode.name) {
      'track' => LoopMode.track,
      'context' => LoopMode.context,
      _ => LoopMode.off,
    };
    return PlaybackState(
      isActive: t != null,
      isPaused: s.isPaused,
      positionMs: s.playbackPosition,
      durationMs: t?.duration ?? 0,
      shuffle: s.playbackOptions.isShuffling,
      repeatMode: repeat,
      track: track,
    );
  }
}

PlaybackEngine createPlaybackEngine(SpotifyApi api, AuthController auth) =>
    MobilePlaybackEngine(api, auth);
