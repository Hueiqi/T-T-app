import 'package:flutter/foundation.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Platform-agnostic authentication surface used by the rest of the app.
///
/// - Web: Authorization Code + PKCE via a full-page redirect.
/// - Mobile: the native Spotify SDK supplies an access token.
abstract class AuthController extends ChangeNotifier {
  AuthStatus get status;
  String? get error;
  bool get isAuthenticated => status == AuthStatus.authenticated;

  /// Restore a saved session / complete a pending login on startup.
  Future<void> init();

  /// Begin an interactive login.
  Future<void> login();

  /// Clear the session.
  Future<void> logout();

  /// A currently-valid access token for Web API calls, refreshing if needed.
  Future<String?> getValidAccessToken({bool forceRefresh = false});
}
