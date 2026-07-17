import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../state/player_provider.dart';
import '../widgets/now_playing_bar.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';

/// The signed-in app shell: bottom navigation between Home, Search and Library,
/// with the Now-Playing bar pinned above the nav bar.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _tabs = [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Connect the playback SDK now that we're authenticated. The player is an
    // app-root provider that persists across screens, so only connect if it
    // isn't already ready (avoids reconnecting each time we re-enter Spotify).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = context.read<PlayerProvider>();
      if (!player.isReady) player.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyColors.base,
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _PlayerErrorListener(),
          const NowPlayingBar(),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xCC000000), SpotifyColors.black],
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _index,
              onTap: (i) => setState(() => _index = i),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home_filled),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.search),
                  activeIcon: Icon(Icons.search),
                  label: 'Search',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.library_music_outlined),
                  activeIcon: Icon(Icons.library_music),
                  label: 'Your Library',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Surfaces player errors (e.g. Premium required) as a snackbar, once each.
class _PlayerErrorListener extends StatelessWidget {
  const _PlayerErrorListener();

  @override
  Widget build(BuildContext context) {
    final error = context.select<PlayerProvider, String?>((p) => p.error);
    if (error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(SnackBar(content: Text(error)));
        context.read<PlayerProvider>().clearError();
      });
    }
    return const SizedBox.shrink();
  }
}
