import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

import '../../core/constants.dart';
import 'auth_controller.dart';

/// Mobile authentication via the native Spotify SDK. `getAccessToken` drives the
/// Spotify app's auth flow and returns a token we use for Web API browsing;
/// playback control is handled separately by the App Remote connection.
class MobileAuthController extends AuthController {
  AuthStatus _status = AuthStatus.unknown;
  String? _error;

  String? _accessToken;
  DateTime? _expiresAt;

  @override
  AuthStatus get status => _status;
  @override
  String? get error => _error;

  static const _kAccess = 'sp_m_access_token';
  static const _kExpires = 'sp_m_expires_at';

  @override
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_kAccess);
    final exp = prefs.getInt(_kExpires);
    _expiresAt = exp != null ? DateTime.fromMillisecondsSinceEpoch(exp) : null;

    final valid = _accessToken != null &&
        _expiresAt != null &&
        DateTime.now().isBefore(_expiresAt!);
    _status = valid ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    notifyListeners();
  }

  @override
  Future<void> login() async {
    try {
      final token = await SpotifySdk.getAccessToken(
        clientId: SpotifyConfig.clientId,
        redirectUrl: SpotifyConfig.mobileRedirectUri,
        scope: SpotifyConfig.mobileScopeString,
      );
      if (token.isEmpty) {
        _error = 'Spotify did not return an access token.';
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }
      await _store(token);
      _error = null;
      _status = AuthStatus.authenticated;
      notifyListeners();
    } catch (e) {
      _error = 'Login failed: $e\n\nMake sure the Spotify app is installed and '
          'this app is registered in your Spotify dashboard.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  @override
  Future<void> logout() async {
    _accessToken = null;
    _expiresAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccess);
    await prefs.remove(_kExpires);
    try {
      await SpotifySdk.disconnect();
    } catch (_) {}
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  @override
  Future<String?> getValidAccessToken({bool forceRefresh = false}) async {
    final valid = _accessToken != null &&
        _expiresAt != null &&
        DateTime.now().isBefore(
          _expiresAt!.subtract(const Duration(seconds: 30)),
        );
    if (valid && !forceRefresh) return _accessToken;

    // The native SDK has no silent refresh; re-request a token.
    try {
      final token = await SpotifySdk.getAccessToken(
        clientId: SpotifyConfig.clientId,
        redirectUrl: SpotifyConfig.mobileRedirectUri,
        scope: SpotifyConfig.mobileScopeString,
      );
      if (token.isEmpty) return null;
      await _store(token);
      return _accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<void> _store(String token) async {
    _accessToken = token;
    // Spotify access tokens last ~1 hour.
    _expiresAt = DateTime.now().add(const Duration(minutes: 55));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccess, token);
    await prefs.setInt(_kExpires, _expiresAt!.millisecondsSinceEpoch);
  }
}

AuthController createAuthController() => MobileAuthController();
