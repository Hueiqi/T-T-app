// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_keys.dart';
import '../config/constants.dart';
import '../models/music_track_model.dart';

class SpotifyService {
  String? _accessToken;
  String? _refreshToken;
  bool _isPlaying = false;
  MusicTrack? _currentTrack;
  DateTime? _tokenExpiry;

  static const String _clientId = ApiKeys.spotifyClientId;
  static const String _redirectUrl = ApiKeys.spotifyRedirectWeb;

  static const String _prefAccessToken = 'spotify_access_token';
  static const String _prefRefreshToken = 'spotify_refresh_token';
  static const String _prefTokenExpiry = 'spotify_token_expiry';

  static const List<String> _scopes = [
    'user-modify-playback-state',
    'user-read-currently-playing',
    'user-read-playback-state',
    'streaming',
    'user-read-private',
    'user-read-email',
    'playlist-read-private',
    'playlist-read-collaborative',
  ];

  bool get isConnected => _accessToken != null;
  bool get isPlaying => _isPlaying;
  MusicTrack? get currentTrack => _currentTrack;

  /// Try to restore a previously saved session from SharedPreferences.
  Future<bool> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString(_prefAccessToken);
      final refreshToken = prefs.getString(_prefRefreshToken);
      final expiryStr = prefs.getString(_prefTokenExpiry);

      if (accessToken == null || refreshToken == null) return false;

      _accessToken = accessToken;
      _refreshToken = refreshToken;
      if (expiryStr != null) {
        _tokenExpiry = DateTime.tryParse(expiryStr);
      }

      if (_tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
        return true;
      }

      return await _refreshAccessToken();
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
      if (_refreshToken != null) {
        await prefs.setString(_prefRefreshToken, _refreshToken!);
      }
      if (_tokenExpiry != null) {
        await prefs.setString(_prefTokenExpiry, _tokenExpiry!.toIso8601String());
      }
    } catch (e) {
      debugPrint('Spotify save session error: $e');
    }
  }

  String _generateCodeVerifier() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    final random = Random.secure();
    return List.generate(128, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  Future<bool> authenticate() async {
    try {
      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);

      final authUrl = Uri.https('accounts.spotify.com', '/authorize', {
        'response_type': 'code',
        'client_id': _clientId,
        'redirect_uri': _redirectUrl,
        'scope': _scopes.join(' '),
        'code_challenge_method': 'S256',
        'code_challenge': codeChallenge,
      }).toString();

      final popup = html.window.open(
        authUrl,
        'spotify-auth',
        'width=500,height=700,left=100,top=100',
      );

      if (popup.closed == true) {
        debugPrint('Popup blocked. Allow popups for this site.');
        return false;
      }

      final code = await _waitForCode();
      if (code == null) return false;

      return await _exchangeCodeForToken(code, codeVerifier);
    } catch (e) {
      debugPrint('Spotify auth error: $e');
      return false;
    }
  }

  Future<String?> _waitForCode() {
    final completer = Completer<String?>();
    StreamSubscription? sub;
    Timer? timer;

    sub = html.window.onMessage.listen((event) {
      if (event.data is Map) {
        final data = event.data as Map;
        if (data['type'] == 'spotify-auth') {
          timer?.cancel();
          sub?.cancel();
          completer.complete(data['code'] as String?);
        }
      }
    });

    timer = Timer(const Duration(minutes: 5), () {
      sub?.cancel();
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    return completer.future;
  }

  Future<bool> _exchangeCodeForToken(String code, String codeVerifier) async {
    try {
      final response = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': _redirectUrl,
          'client_id': _clientId,
          'code_verifier': codeVerifier,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        final expiresIn = data['expires_in'] as int;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
        await _saveSession();
        return true;
      }
      debugPrint('Token exchange failed: ${response.body}');
      return false;
    } catch (e) {
      debugPrint('Token exchange error: $e');
      return false;
    }
  }

  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) return false;
    try {
      final response = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': _refreshToken!,
          'client_id': _clientId,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        final expiresIn = data['expires_in'] as int;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
        if (data['refresh_token'] != null) {
          _refreshToken = data['refresh_token'];
        }
        await _saveSession();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Token refresh error: $e');
      return false;
    }
  }

  Future<bool> _ensureValidToken() async {
    if (_accessToken == null) return false;
    if (_tokenExpiry != null && DateTime.now().isAfter(_tokenExpiry!)) {
      return await _refreshAccessToken();
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

  Future<void> disconnect() async {
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = null;
    _isPlaying = false;
    _currentTrack = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefAccessToken);
      await prefs.remove(_prefRefreshToken);
      await prefs.remove(_prefTokenExpiry);
    } catch (_) {}
  }
}

class SpotifyNoDeviceException implements Exception {
  final String message;
  const SpotifyNoDeviceException(this.message);
  @override
  String toString() => message;
}
