import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../services/auth/auth.dart';
import '../services/spotify_api.dart';
import '../state/player_provider.dart';
import '../widgets/art_image.dart';
import '../widgets/media_cards.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final SpotifyApi _api;
  Future<_HomeData>? _future;

  @override
  void initState() {
    super.initState();
    _api = context.read<SpotifyApi>();
    _future = _load();
  }

  Future<T> _safe<T>(Future<T> Function() fn, T fallback) async {
    try {
      return await fn();
    } catch (_) {
      return fallback;
    }
  }

  Future<_HomeData> _load() async {
    final me = await _api.getMe(); // essential — let this throw if it fails
    final recent = await _safe(() => _api.getRecentlyPlayedTracks(limit: 8), <Track>[]);
    final topArtists = await _safe(() => _api.getTopArtists(limit: 12), <Artist>[]);
    final topTracks = await _safe(() => _api.getTopTracks(limit: 12), <Track>[]);
    final newReleases = await _safe(() => _api.getNewReleases(limit: 12), <Album>[]);
    final playlists = await _safe(
      () => _api.getMyPlaylists(limit: 12).then((p) => p.items),
      <Playlist>[],
    );
    return _HomeData(
      user: me,
      recentlyPlayed: recent,
      topArtists: topArtists,
      topTracks: topTracks,
      newReleases: newReleases,
      playlists: playlists,
    );
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2E2E2E), SpotifyColors.base],
          stops: [0.0, 0.4],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: FutureBuilder<_HomeData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: SpotifyColors.green),
              );
            }
            if (snapshot.hasError) {
              return _ErrorView(
                error: snapshot.error.toString(),
                onRetry: () => setState(() => _future = _load()),
              );
            }
            return _HomeContent(data: snapshot.data!, greeting: _greeting);
          },
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.data, required this.greeting});

  final _HomeData data;
  final String greeting;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                color: SpotifyColors.textPrimary,
                tooltip: 'Back to T&T',
                // Pop the ROOT navigator (the Spotify section runs in its own
                // nested MaterialApp) to return to the fitness app.
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).maybePop(),
              ),
              Expanded(
                child: Text(
                  greeting,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800),
                ),
              ),
              _ProfileMenu(user: data.user),
            ],
          ),
        ),
        if (data.recentlyPlayed.isNotEmpty)
          _RecentGrid(tracks: data.recentlyPlayed),
        const SizedBox(height: 8),
        if (data.topArtists.isNotEmpty)
          HorizontalShelf(
            title: 'Your top artists',
            children: [for (final a in data.topArtists) ArtistCard(artist: a)],
          ),
        if (data.topTracks.isNotEmpty)
          HorizontalShelf(
            title: 'Your top tracks',
            children: [
              for (var i = 0; i < data.topTracks.length; i++)
                _TrackArtCard(tracks: data.topTracks, index: i),
            ],
          ),
        if (data.newReleases.isNotEmpty)
          HorizontalShelf(
            title: 'New releases',
            children: [for (final a in data.newReleases) AlbumCard(album: a)],
          ),
        if (data.playlists.isNotEmpty)
          HorizontalShelf(
            title: 'Your playlists',
            children: [
              for (final p in data.playlists) PlaylistCard(playlist: p)
            ],
          ),
      ],
    );
  }
}

/// The 2-column quick-access grid of recently played tracks at the top of Home.
class _RecentGrid extends StatelessWidget {
  const _RecentGrid({required this.tracks});
  final List<Track> tracks;

  @override
  Widget build(BuildContext context) {
    final uris = tracks.map((t) => t.uri).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: tracks.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 56,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (context, i) {
          final t = tracks[i];
          return InkWell(
            onTap: () =>
                context.read<PlayerProvider>().playTracks(uris, offset: i),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(4),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  ArtImage(url: t.thumbnailUrl, size: 56, borderRadius: 0),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        t.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A square card for a track that plays the track (within its list) on tap.
class _TrackArtCard extends StatelessWidget {
  const _TrackArtCard({required this.tracks, required this.index});
  final List<Track> tracks;
  final int index;

  @override
  Widget build(BuildContext context) {
    final t = tracks[index];
    return GestureDetector(
      onTap: () => context
          .read<PlayerProvider>()
          .playTracks(tracks.map((e) => e.uri).toList(), offset: index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ArtImage(url: t.imageUrl, size: 150, borderRadius: 6),
            const SizedBox(height: 8),
            Text(t.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 2),
            Text(t.artistNames,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: SpotifyColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({required this.user});
  final SpotifyUser user;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: SpotifyColors.elevated,
      onSelected: (value) {
        if (value == 'logout') context.read<AuthController>().logout();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.displayName,
                  style: const TextStyle(
                      color: SpotifyColors.textPrimary,
                      fontWeight: FontWeight.bold)),
              Text(
                user.isPremium ? 'Premium' : 'Free',
                style: const TextStyle(
                    color: SpotifyColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'logout',
          child: Text('Log out',
              style: TextStyle(color: SpotifyColors.textPrimary)),
        ),
      ],
      child: CircleAvatar(
        radius: 18,
        backgroundColor: SpotifyColors.green,
        backgroundImage:
            user.imageUrl != null ? NetworkImage(user.imageUrl!) : null,
        child: user.imageUrl == null
            ? Text(user.initial,
                style: const TextStyle(
                    color: SpotifyColors.black, fontWeight: FontWeight.bold))
            : null,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: SpotifyColors.textSecondary, size: 40),
            const SizedBox(height: 12),
            const Text("Couldn't load your Home",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: SpotifyColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _HomeData {
  final SpotifyUser user;
  final List<Track> recentlyPlayed;
  final List<Artist> topArtists;
  final List<Track> topTracks;
  final List<Album> newReleases;
  final List<Playlist> playlists;

  _HomeData({
    required this.user,
    required this.recentlyPlayed,
    required this.topArtists,
    required this.topTracks,
    required this.newReleases,
    required this.playlists,
  });
}
