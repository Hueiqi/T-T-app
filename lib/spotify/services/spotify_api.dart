import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/models.dart';
import 'auth/auth.dart';

class SpotifyApiException implements Exception {
  final int statusCode;
  final String message;
  SpotifyApiException(this.statusCode, this.message);

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => 'SpotifyApiException($statusCode): $message';
}

/// Thin wrapper over the Spotify Web API.
///
/// Note: this app deliberately avoids endpoints that Spotify restricted for
/// newly-created apps (Featured Playlists, Categories, Recommendations,
/// Related Artists, Audio Features). The Home screen is instead built from
/// the authenticated user's own data (recently played, top items, library)
/// plus New Releases, which remain available.
class SpotifyApi {
  final AuthController auth;
  final http.Client _client;

  SpotifyApi(this.auth) : _client = http.Client();

  // ---------------------------------------------------------------------------
  // Low-level request plumbing
  // ---------------------------------------------------------------------------

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    bool retry = true,
  }) async {
    final token = await auth.getValidAccessToken(forceRefresh: !retry);
    if (token == null) {
      throw SpotifyApiException(401, 'Not authenticated');
    }

    final uri = path.startsWith('http')
        ? Uri.parse(path)
        : Uri.parse('${SpotifyConfig.apiBase}$path').replace(
            queryParameters: query?.map(
              (k, v) => MapEntry(k, v?.toString()),
            ),
          );

    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };
    final encoded = body != null ? jsonEncode(body) : null;

    http.Response resp;
    switch (method) {
      case 'POST':
        resp = await _client.post(uri, headers: headers, body: encoded);
      case 'PUT':
        resp = await _client.put(uri, headers: headers, body: encoded);
      case 'DELETE':
        resp = await _client.delete(uri, headers: headers, body: encoded);
      case 'GET':
      default:
        resp = await _client.get(uri, headers: headers);
    }

    if (resp.statusCode == 401 && retry) {
      // Token may have been revoked server-side; force a refresh and retry once.
      return _send(method, path, query: query, body: body, retry: false);
    }

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.body.isEmpty) return null;
      return jsonDecode(resp.body);
    }

    throw SpotifyApiException(resp.statusCode, _errorMessage(resp));
  }

  String _errorMessage(http.Response resp) {
    try {
      final body = jsonDecode(resp.body);
      if (body is Map && body['error'] is Map) {
        return body['error']['message']?.toString() ?? resp.reasonPhrase ?? '';
      }
      if (body is Map && body['error'] is String) {
        return body['error'] as String;
      }
    } catch (_) {}
    return resp.reasonPhrase ?? 'Request failed';
  }

  Future<Map<String, dynamic>> _get(String path, {Map<String, dynamic>? query}) async {
    final res = await _send('GET', path, query: query);
    return (res as Map<String, dynamic>?) ?? <String, dynamic>{};
  }

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------

  Future<SpotifyUser> getMe() async {
    return SpotifyUser.fromJson(await _get('/me'));
  }

  // ---------------------------------------------------------------------------
  // Home data
  // ---------------------------------------------------------------------------

  Future<List<Track>> getRecentlyPlayedTracks({int limit = 20}) async {
    final res = await _get('/me/player/recently-played', query: {'limit': limit});
    final items = (res['items'] as List?) ?? const [];
    final tracks = <Track>[];
    final seen = <String>{};
    for (final item in items.whereType<Map<String, dynamic>>()) {
      final track = item['track'];
      if (track is Map<String, dynamic>) {
        final t = Track.fromJson(track);
        if (t.id.isNotEmpty && seen.add(t.id)) tracks.add(t);
      }
    }
    return tracks;
  }

  Future<List<Track>> getTopTracks({int limit = 20, String timeRange = 'medium_term'}) async {
    final res = await _get('/me/top/tracks', query: {'limit': limit, 'time_range': timeRange});
    return Track.listFrom(res['items']);
  }

  Future<List<Artist>> getTopArtists({int limit = 20, String timeRange = 'medium_term'}) async {
    final res = await _get('/me/top/artists', query: {'limit': limit, 'time_range': timeRange});
    return Artist.listFrom(res['items']);
  }

  Future<List<Album>> getNewReleases({int limit = 20}) async {
    final res = await _get('/browse/new-releases', query: {'limit': limit});
    final albums = res['albums'] as Map<String, dynamic>?;
    return Album.listFrom(albums?['items']);
  }

  // ---------------------------------------------------------------------------
  // Library
  // ---------------------------------------------------------------------------

  Future<Paging<Playlist>> getMyPlaylists({int limit = 50, int offset = 0}) async {
    final res = await _get('/me/playlists', query: {'limit': limit, 'offset': offset});
    return Paging.fromJson(res, Playlist.fromJson);
  }

  Future<List<Album>> getSavedAlbums({int limit = 50}) async {
    final res = await _get('/me/albums', query: {'limit': limit});
    final items = (res['items'] as List?) ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => Album.fromJson(e['album'] as Map<String, dynamic>))
        .toList();
  }

  Future<List<Track>> getSavedTracks({int limit = 50, int offset = 0}) async {
    final res = await _get('/me/tracks', query: {'limit': limit, 'offset': offset});
    return Track.listFrom(res['items']);
  }

  Future<List<Artist>> getFollowedArtists({int limit = 50}) async {
    final res = await _get('/me/following', query: {'type': 'artist', 'limit': limit});
    final artists = res['artists'] as Map<String, dynamic>?;
    return Artist.listFrom(artists?['items']);
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  Future<SearchResults> search(
    String query, {
    List<String> types = const ['track', 'artist', 'album', 'playlist'],
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) return SearchResults.empty;
    final res = await _get('/search', query: {
      'q': query,
      'type': types.join(','),
      'limit': limit,
    });
    return SearchResults.fromJson(res);
  }

  // ---------------------------------------------------------------------------
  // Detail pages
  // ---------------------------------------------------------------------------

  Future<Playlist> getPlaylist(String id) async {
    return Playlist.fromJson(await _get('/playlists/$id'));
  }

  Future<List<Track>> getPlaylistTracks(String id, {int limit = 100, int offset = 0}) async {
    final res = await _get('/playlists/$id/tracks', query: {'limit': limit, 'offset': offset});
    return Track.listFrom(res['items']);
  }

  Future<Album> getAlbum(String id) async {
    return Album.fromJson(await _get('/albums/$id'));
  }

  Future<List<Track>> getAlbumTracks(String id, {int limit = 50}) async {
    final res = await _get('/albums/$id/tracks', query: {'limit': limit});
    // Album tracks don't embed the album object — attach it for art/navigation.
    return Track.listFrom(res['items']);
  }

  Future<Artist> getArtist(String id) async {
    return Artist.fromJson(await _get('/artists/$id'));
  }

  Future<List<Track>> getArtistTopTracks(String id, {String market = 'from_token'}) async {
    final res = await _get('/artists/$id/top-tracks', query: {'market': market});
    return Track.listFrom(res['tracks']);
  }

  Future<List<Album>> getArtistAlbums(String id, {int limit = 20}) async {
    final res = await _get('/artists/$id/albums',
        query: {'limit': limit, 'include_groups': 'album,single'});
    return Album.listFrom(res['items']);
  }

  // ---------------------------------------------------------------------------
  // Library mutations
  // ---------------------------------------------------------------------------

  Future<List<bool>> areTracksSaved(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final res = await _send('GET', '/me/tracks/contains', query: {'ids': ids.join(',')});
    return (res as List).map((e) => e == true).toList();
  }

  Future<void> saveTracks(List<String> ids) async {
    await _send('PUT', '/me/tracks', body: {'ids': ids});
  }

  Future<void> removeSavedTracks(List<String> ids) async {
    await _send('DELETE', '/me/tracks', body: {'ids': ids});
  }

  // ---------------------------------------------------------------------------
  // Playback control (Spotify Connect Web API)
  // ---------------------------------------------------------------------------

  Future<void> transferPlayback(String deviceId, {bool play = false}) async {
    await _send('PUT', '/me/player', body: {
      'device_ids': [deviceId],
      'play': play,
    });
  }

  Future<void> play({
    required String deviceId,
    String? contextUri,
    List<String>? uris,
    int? offsetIndex,
    int? positionMs,
  }) async {
    final body = <String, dynamic>{};
    if (contextUri != null) body['context_uri'] = contextUri;
    if (uris != null) body['uris'] = uris;
    if (offsetIndex != null) body['offset'] = {'position': offsetIndex};
    if (positionMs != null) body['position_ms'] = positionMs;
    await _send('PUT', '/me/player/play',
        query: {'device_id': deviceId}, body: body.isEmpty ? null : body);
  }

  Future<void> pause(String deviceId) async {
    await _send('PUT', '/me/player/pause', query: {'device_id': deviceId});
  }

  Future<void> setShuffle(bool state, String deviceId) async {
    await _send('PUT', '/me/player/shuffle',
        query: {'state': state, 'device_id': deviceId});
  }

  Future<void> setRepeat(String state, String deviceId) async {
    // state: off | context | track
    await _send('PUT', '/me/player/repeat',
        query: {'state': state, 'device_id': deviceId});
  }
}

/// Bundled search results across the requested item types.
class SearchResults {
  final List<Track> tracks;
  final List<Artist> artists;
  final List<Album> albums;
  final List<Playlist> playlists;

  const SearchResults({
    this.tracks = const [],
    this.artists = const [],
    this.albums = const [],
    this.playlists = const [],
  });

  static const SearchResults empty = SearchResults();

  bool get isEmpty =>
      tracks.isEmpty && artists.isEmpty && albums.isEmpty && playlists.isEmpty;

  factory SearchResults.fromJson(Map<String, dynamic> json) {
    return SearchResults(
      tracks: Track.listFrom((json['tracks'] as Map<String, dynamic>?)?['items']),
      artists: Artist.listFrom((json['artists'] as Map<String, dynamic>?)?['items']),
      albums: Album.listFrom((json['albums'] as Map<String, dynamic>?)?['items']),
      playlists:
          Playlist.listFrom((json['playlists'] as Map<String, dynamic>?)?['items']),
    );
  }
}
