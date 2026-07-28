// Public auth API. FitSync is Android-only.
//
// We use the PKCE browser flow rather than the native Spotify SDK: the SDK's
// app-to-app handshake fails with AUTHENTICATION_SERVICE_UNKNOWN_ERROR on some
// Android builds, and the browser flow additionally gives us a refresh token
// for silent renewal. `mobile_auth_controller.dart` is kept for reference.
import 'auth_controller.dart';
import 'pkce_auth_controller.dart';

export 'auth_controller.dart';
export 'pkce_auth_controller.dart' show PkceAuthController;

AuthController createAuthController() => PkceAuthController();
