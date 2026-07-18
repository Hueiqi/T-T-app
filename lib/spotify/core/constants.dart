/// App-wide constants for the Spotify client.
///
/// We use the Authorization Code flow with PKCE, which is the recommended flow
/// for browser/native clients. PKCE means the client secret is NOT needed (and
/// must never be embedded in client-side code), so only the client id and the
/// redirect URI are configured here.
class SpotifyConfig {
  SpotifyConfig._();

  /// Spotify application client id (from the Spotify Developer Dashboard).
  static const String clientId = '29085e1330524952b1d60fc3aa09eeb0';

  /// Must exactly match a Redirect URI registered in the Spotify Dashboard.
  /// The web app must therefore be served on 127.0.0.1:8888.
  static const String redirectUri = 'http://127.0.0.1:8080/callback';

  /// Redirect URI used by the native Android SDK (custom scheme). This must ALSO
  /// be added to the Spotify Dashboard's Redirect URIs, and is wired into the
  /// Android manifest. Keep the scheme in sync with android/.../AndroidManifest.xml.
  static const String mobileRedirectUri = 'myfitnessttapp://callback';
  static const String sdkRedirectUri = 'spotify-sdk://auth';
  static const String watchRedirectUri = 'watchspotify://callback';
  static const String authorizeUrl = 'https://accounts.spotify.com/authorize';
  static const String tokenUrl = 'https://accounts.spotify.com/api/token';
  static const String apiBase = 'https://api.spotify.com/v1';

  /// Name shown for our device in the Spotify Connect device list.
  static const String playerName = 'Flutter Spotify (Web)';

  /// Scopes requested during authorization. These cover playback control,
  /// reading the user's library/playlists, and the streaming permission
  /// required by the Web Playback SDK.
  static const List<String> scopes = [
    // Web Playback SDK / playback control
    'streaming',
    'user-read-playback-state',
    'user-modify-playback-state',
    'user-read-currently-playing',
    // Account
    'user-read-email',
    'user-read-private',
    // Library
    'user-library-read',
    'user-library-modify',
    // Playlists
    'playlist-read-private',
    'playlist-read-collaborative',
    'playlist-modify-public',
    'playlist-modify-private',
    // Listening history / personalization
    'user-top-read',
    'user-read-recently-played',
    // Follow
    'user-follow-read',
    'user-follow-modify',
  ];

  static String get scopeString => scopes.join(' ');

  /// Scopes for the native mobile SDK. 'streaming' is web-only and is replaced
  /// by 'app-remote-control' (required by the Spotify App Remote).
  static List<String> get mobileScopes => [
        'app-remote-control',
        ...scopes.where((s) => s != 'streaming'),
      ];

  /// The native SDK expects a comma-separated scope string.
  static String get mobileScopeString => mobileScopes.join(',');
}
