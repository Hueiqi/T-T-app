import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'services/auth/auth.dart';
import 'services/spotify_api.dart';
import 'state/player_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'widgets/loading_splash.dart';

/// Embedded Spotify experience inside FitSync.
///
/// The Spotify services (auth / API / player) live at the **app root** (see
/// `app.dart`) so playback survives across every screen and the global floating
/// mini-player can hover over the fitness parts of the app. This screen simply
/// re-exposes those existing providers to its own nested [MaterialApp] (kept for
/// the Spotify dark theme + isolated navigator) and switches between login and
/// the main shell.
///
/// ```dart
/// Navigator.pushNamed(context, AppRoutes.spotify);
/// ```
class SpotifySection extends StatelessWidget {
  const SpotifySection({super.key});

  @override
  Widget build(BuildContext context) {
    // Grab the root-level Spotify providers and re-provide them to the nested
    // MaterialApp below (which has its own provider scope).
    final auth = context.read<AuthController>();
    final api = context.read<SpotifyApi>();
    final player = context.read<PlayerProvider>();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: auth),
        Provider<SpotifyApi>.value(value: api),
        ChangeNotifierProvider<PlayerProvider>.value(value: player),
      ],
      child: MaterialApp(
        title: 'Spotify',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const _AuthGate(),
      ),
    );
  }
}

/// Switches between login and the main shell based on auth status.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthController>().status;
    switch (status) {
      case AuthStatus.unknown:
        return const LoadingSplash();
      case AuthStatus.authenticated:
        return const MainShell();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}
