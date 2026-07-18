// Public auth API. The concrete controller is chosen at compile time:
// web uses PKCE redirect; mobile (dart:io) uses the native Spotify SDK.
// FitSync is Android-only, so we export the native (mobile) controller directly.
export 'auth_controller.dart';
export 'mobile_auth_controller.dart' show createAuthController;
