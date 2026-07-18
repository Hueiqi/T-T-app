import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../spotify/core/constants.dart';
import '../config/constants.dart';
import '../models/music_track_model.dart';

class SpotifyService {
  String? _accessToken;
  DateTime? _tokenExpiry;
  bool _isPlaying = false;
  MusicTrack? _currentTrack;

  static const String _prefAccessToken = 'spotify_svc_access_token';
  static const String _prefTokenExpiry = 'spotify_svc_token_expiry';

  static const Duration _tokenLifetime = Duration(minutes: 55);

  bool get isConnected => _accessToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!);
  bool get isPlaying => _isPlaying;
  MusicTrack? get currentTrack => _currentTrack;

  void setAccessToken(String token) {
    _accessToken = token;
    _tokenExpiry = DateTime.now().add(_tokenLifetime);
    _saveSession();
  }

  Future<bool> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_prefAccessToken);
      final expiryMs = prefs.getInt(_prefTokenExpiry);

      if (token == null || expiryMs == null) return false;

      _accessToken = token;
      _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);

      if (DateTime.now().isBefore(_tokenExpiry!)) {
        return true;
      }

      return await _refreshToken();
    } catch (e) {
      debugPrint('Spotify restore session error: $e');
      return false;
    }
  }

  Future<void> _saveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_accessToken != null) {
        await prefs.setString(_prefAccessToken, _accessToken!);
      }
      if (_tokenExpiry != null) {
        await prefs.setInt(_prefTokenExpiry, _tokenExpiry!.millisecondsSinceEpoch);
      }
    } catch (e) {
      debugPrint('Spotify save session error: $e');
    }
  }

  Future<bool> authenticate() async {
    try {
      final token = await SpotifySdk.getAccessToken(
        clientId: SpotifyConfig.clientId,
        redirectUrl: SpotifyConfig.mobileRedirectUri,
        scope: SpotifyConfig.mobileScopeString,
      );
      if (token.isEmpty) {
        debugPrint('Spotify SDK returned empty token');
        return false;
      }
      _accessToken = token;
      _tokenExpiry = DateTime.now().add(_tokenLifetime);
      await _saveSession();
      return true;
    } catch (e) {
      debugPrint('Spotify native auth error: $e');
      return false;
    }
  }

  Future<bool> _refreshToken() async {
    try {
      final token = await SpotifySdk.getAccessToken(
        clientId: SpotifyConfig.clientId,
        redirectUrl: SpotifyConfig.mobileRedirectUri,
        scope: SpotifyConfig.mobileScopeString,
      );
      if (token.isEmpty) return false;
      _accessToken = token;
      _tokenExpiry = DateTime.now().add(_tokenLifetime);
      await _saveSession();
      return true;
    } catch (e) {
      debugPrint('Spotify token refresh error: $e');
      return false;
    }
  }

  Future<bool> _ensureValidToken() async {
    if (_accessToken == null) return false;
    if (_tokenExpiry != null && DateTime.now().isAfter(_tokenExpiry!)) {
      return await _refreshToken();
    }
    return true;
  }

  Future<Map<String, String>> _authHeaders() async {
    final valid = await _ensureValidToken();
    if (!valid) return {};
    return {'Authorization': 'Bearer $_accessToken'};
  }

  Future<String?> _getActiveDeviceId() async {
    try {
      final headers = await _authHeaders();
      if (headers.isEmpty) return null;

      final response = await http.get(
        Uri.parse('https://api.spotify.com/v1/me/player/devices'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final devices = data['devices'] as List;
        if (devices.isNotEmpty) {
          return devices[0]['id'] as String?;
        }
      }
    } catch (e) {
      debugPrint('Get devices error: $e');
    }
    return null;
  }

  Future<List<MusicTrack>> searchTracks(String query) async {
    final headers = await _authHeaders();
    if (headers.isEmpty) return [];
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.spotify.com/v1/search?q=$query&type=track&limit=20',
        ),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tracks = data['tracks']['items'] as List;
        return tracks
            .map(
              (t) => MusicTrack(
                id: t['id'],
                name: t['name'],
                artist: t['artists'][0]['name'],
                albumArtUrl: t['album']['images'].isNotEmpty
                    ? t['album']['images'][0]['url']
                    : '',
                previewUrl: t['preview_url'] ?? '',
                spotifyUri: t['uri'],
              ),
            )
            .toList();
      }
    } catch (e) {
      debugPrint('Search error: $e');
    }
    return [];
  }

  static String _bpmToSearchQuery(int targetBpm) {
    if (targetBpm < 80) return 'chill relaxing ambient';
    if (targetBpm < 100) return 'pop indie chill';
    if (targetBpm < 120) return 'dance pop electronic';
    if (targetBpm < 140) return 'workout running EDM';
    if (targetBpm < 160) return 'hiit cardio intense workout';
    return 'hardcore intense metal workout';
  }

  Future<List<MusicTrack>> getTracksByBpm(int targetBpm) async {
    final query = _bpmToSearchQuery(targetBpm);
    final encodedQuery = Uri.encodeQueryComponent(query);
    final headers = await _authHeaders();
    if (headers.isEmpty) return [];
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.spotify.com/v1/search?q=$encodedQuery&type=track&limit=20',
        ),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tracks = data['tracks']['items'] as List;
        return tracks
            .map(
              (t) => MusicTrack(
                id: t['id'],
                name: t['name'],
                artist: t['artists'][0]['name'],
                albumArtUrl: t['album']['images'].isNotEmpty
                    ? t['album']['images'][0]['url']
                    : '',
                bpm: targetBpm,
                spotifyUri: t['uri'],
              ),
            )
            .toList();
      }
    } catch (e) {
      debugPrint('BPM search error: $e');
    }
    return [];
  }

  Future<void> playTrack(String spotifyUri) async {
    final headers = await _authHeaders();
    if (headers.isEmpty) return;
    try {
      final deviceId = await _getActiveDeviceId();
      final url = deviceId != null
          ? 'https://api.spotify.com/v1/me/player/play?device_id=$deviceId'
          : 'https://api.spotify.com/v1/me/player/play';

      final response = await http.put(
        Uri.parse(url),
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'uris': [spotifyUri]}),
      );

      if (response.statusCode == 204 || response.statusCode == 202) {
        _isPlaying = true;
      } else if (response.statusCode == 404) {
        throw SpotifyNoDeviceException(
          'No active Spotify device. Open the Spotify app and start playing a song first.',
        );
      }
    } on SpotifyNoDeviceException {
      rethrow;
    } catch (e) {
      debugPrint('Play error: $e');
      rethrow;
    }
  }

  Future<void> pausePlayback() async {
    final headers = await _authHeaders();
    if (headers.isEmpty) return;
    try {
      final response = await http.put(
        Uri.parse('https://api.spotify.com/v1/me/player/pause'),
        headers: headers,
      );
      if (response.statusCode == 204) {
        _isPlaying = false;
      }
    } catch (e) {
      debugPrint('Pause error: $e');
      rethrow;
    }
  }

  Future<void> resumePlayback() async {
    final headers = await _authHeaders();
    if (headers.isEmpty) return;
    try {
      final response = await http.put(
        Uri.parse('https://api.spotify.com/v1/me/player/play'),
        headers: headers,
      );
      if (response.statusCode == 204) {
        _isPlaying = true;
      }
    } catch (e) {
      debugPrint('Resume error: $e');
      rethrow;
    }
  }

  Future<void> queueTrack(String spotifyUri) async {
    final headers = await _authHeaders();
    if (headers.isEmpty) return;
    try {
      await http.post(
        Uri.parse(
          'https://api.spotify.com/v1/me/player/queue?uri=$spotifyUri',
        ),
        headers: headers,
      );
    } catch (e) {
      debugPrint('Queue error: $e');
      rethrow;
    }
  }

  Future<void> adjustMusicToHeartRate(int heartRate) async {
    final targetBpm = AppConstants.calculateTargetBpm(heartRate);
    final tracks = await getTracksByBpm(targetBpm);
    if (tracks.isNotEmpty) {
      await playTrack(tracks.first.spotifyUri);
      _currentTrack = tracks.first;
    }
  }

  Future<bool> disconnect() async {
    _accessToken = null;
    _tokenExpiry = null;
    _isPlaying = false;
    _currentTrack = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefAccessToken);
      await prefs.remove(_prefTokenExpiry);
    } catch (_) {}
    try {
      await SpotifySdk.disconnect();
    } catch (_) {}
    return true;
  }

  /// Clears cached tokens and re-authenticates. Call this after scope changes.
  Future<bool> forceReauthorize() async {
    await disconnect();
    return await authenticate();
  }
}

class SpotifyNoDeviceException implements Exception {
  final String message;
  const SpotifyNoDeviceException(this.message);
  @override
  String toString() => message;
}
