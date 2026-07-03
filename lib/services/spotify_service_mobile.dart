import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
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
  static const String _redirectUrl = ApiKeys.spotifyRedirectMobile;

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

  bool get isPlaying => _isPlaying;
  MusicTrack? get currentTrack => _currentTrack;

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

      final result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: 'myfitnessTTapp',
      );

      final code = Uri.parse(result).queryParameters['code'];
      if (code == null) return false;

      return await _exchangeCodeForToken(code, codeVerifier);
    } catch (e) {
      debugPrint('Spotify auth error: $e');
      return false;
    }
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

  Future<List<MusicTrack>> getTracksByBpm(int targetBpm) async {
    final headers = await _authHeaders();
    if (headers.isEmpty) return [];
    try {
      final bpmRange = 10;
      final minBpm = targetBpm - bpmRange;
      final maxBpm = targetBpm + bpmRange;
      final query = 'tempo:[${minBpm}_TO_$maxBpm]';
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
        debugPrint('No active Spotify device found. Open Spotify and play a song first.');
      }
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
  }
}
