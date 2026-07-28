import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import 'auth_controller.dart';

/// Authorization Code + PKCE login through the system browser.
///
/// Replaces the native Spotify SDK handshake, which fails with
/// AUTHENTICATION_SERVICE_UNKNOWN_ERROR on some Android builds. This flow only
/// depends on Spotify's public OAuth endpoints, so it works without the Spotify
/// app being installed — and unlike the native SDK it gets a refresh token,
/// enabling silent renewal instead of re-prompting the user every hour.
class PkceAuthController extends AuthController {
  AuthStatus _status = AuthStatus.unknown;
  String? _error;

  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiresAt;

  @override
  AuthStatus get status => _status;
  @override
  String? get error => _error;

  static const _kAccess = 'sp_pkce_access_token';
  static const _kRefresh = 'sp_pkce_refresh_token';
  static const _kExpires = 'sp_pkce_expires_at';

  @override
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_kAccess);
    _refreshToken = prefs.getString(_kRefresh);
    final exp = prefs.getInt(_kExpires);
    _expiresAt = exp != null ? DateTime.fromMillisecondsSinceEpoch(exp) : null;

    if (_accessToken == null && _refreshToken == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    if (_isTokenUsable) {
      _status = AuthStatus.authenticated;
      notifyListeners();
      return;
    }

    // Access token expired but we have a refresh token — renew silently.
    final renewed = await _refresh();
    _status = renewed ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    notifyListeners();
  }

  bool get _isTokenUsable =>
      _accessToken != null &&
      _expiresAt != null &&
      DateTime.now().isBefore(_expiresAt!.subtract(const Duration(seconds: 30)));

  @override
  Future<void> login() async {
    try {
      final verifier = _createCodeVerifier();
      final challenge = _deriveCodeChallenge(verifier);
      final state = _randomString(16);

      final authUrl = Uri.parse(SpotifyConfig.authorizeUrl).replace(
        queryParameters: {
          'client_id': SpotifyConfig.clientId,
          'response_type': 'code',
          'redirect_uri': SpotifyConfig.pkceRedirectUri,
          'code_challenge_method': 'S256',
          'code_challenge': challenge,
          'state': state,
          // The browser flow uses space-separated scopes (unlike the native
          // SDK's comma-separated string) and supports 'streaming'.
          'scope': SpotifyConfig.scopeString,
        },
      ).toString();

      debugPrint('Spotify PKCE authorize URL: $authUrl');
      debugPrint('Spotify PKCE client_id: ${SpotifyConfig.clientId}');
      debugPrint('Spotify PKCE redirect_uri: ${SpotifyConfig.pkceRedirectUri}');

      final result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: SpotifyConfig.pkceCallbackScheme,
      );

      final returned = Uri.parse(result);
      final returnedError = returned.queryParameters['error'];
      if (returnedError != null) {
        _fail('Spotify denied the login request: $returnedError');
        return;
      }
      if (returned.queryParameters['state'] != state) {
        _fail('Login failed: state mismatch (possible interception).');
        return;
      }
      final code = returned.queryParameters['code'];
      if (code == null || code.isEmpty) {
        _fail('Spotify did not return an authorization code.');
        return;
      }

      final exchanged = await _exchangeCode(code, verifier);
      if (!exchanged) return;

      _error = null;
      _status = AuthStatus.authenticated;
      notifyListeners();
    } catch (e) {
      // User dismissing the browser tab also lands here.
      _fail('Login failed or was cancelled: $e');
    }
  }

  @override
  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _expiresAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
    await prefs.remove(_kExpires);
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  @override
  Future<String?> getValidAccessToken({bool forceRefresh = false}) async {
    if (_isTokenUsable && !forceRefresh) return _accessToken;
    final renewed = await _refresh();
    if (!renewed) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return null;
    }
    return _accessToken;
  }

  Future<bool> _exchangeCode(String code, String verifier) async {
    try {
      final response = await http.post(
        Uri.parse(SpotifyConfig.tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': SpotifyConfig.clientId,
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': SpotifyConfig.pkceRedirectUri,
          'code_verifier': verifier,
        },
      );
      if (response.statusCode != 200) {
        _fail('Token exchange failed (${response.statusCode}): ${response.body}');
        return false;
      }
      await _storeTokenResponse(response.body);
      return true;
    } catch (e) {
      _fail('Token exchange failed: $e');
      return false;
    }
  }

  Future<bool> _refresh() async {
    final token = _refreshToken;
    if (token == null) return false;
    try {
      final response = await http.post(
        Uri.parse(SpotifyConfig.tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': SpotifyConfig.clientId,
          'grant_type': 'refresh_token',
          'refresh_token': token,
        },
      );
      if (response.statusCode != 200) {
        debugPrint('Spotify refresh failed (${response.statusCode}): ${response.body}');
        return false;
      }
      await _storeTokenResponse(response.body);
      return true;
    } catch (e) {
      debugPrint('Spotify refresh error: $e');
      return false;
    }
  }

  Future<void> _storeTokenResponse(String body) async {
    final data = jsonDecode(body) as Map<String, dynamic>;
    _accessToken = data['access_token'] as String?;
    // Spotify omits refresh_token on some refresh responses; keep the old one.
    final newRefresh = data['refresh_token'] as String?;
    if (newRefresh != null && newRefresh.isNotEmpty) {
      _refreshToken = newRefresh;
    }
    final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;
    _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) {
      await prefs.setString(_kAccess, _accessToken!);
    }
    if (_refreshToken != null) {
      await prefs.setString(_kRefresh, _refreshToken!);
    }
    await prefs.setInt(_kExpires, _expiresAt!.millisecondsSinceEpoch);
  }

  void _fail(String message) {
    _error = message;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  static const _verifierChars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  String _createCodeVerifier() => _randomString(96);

  String _randomString(int length) {
    final rnd = Random.secure();
    return List.generate(
      length,
      (_) => _verifierChars[rnd.nextInt(_verifierChars.length)],
    ).join();
  }

  /// S256 challenge: base64url(sha256(verifier)), padding stripped.
  String _deriveCodeChallenge(String verifier) {
    final digest = sha256.convert(ascii.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}
