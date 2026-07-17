import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../services/spotify_api.dart';
import '../widgets/art_image.dart';
import '../widgets/media_cards.dart';
import 'liked_songs_screen.dart';

enum _Filter { all, playlists, artists, albums }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final SpotifyApi _api;
  Future<_LibraryData>? _future;
  _Filter _filter = _Filter.all;

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

  Future<_LibraryData> _load() async {
    final playlists = await _safe(
        () => _api.getMyPlaylists(limit: 50).then((p) => p.items), <Playlist>[]);
    final albums = await _safe(() => _api.getSavedAlbums(limit: 50), <Album>[]);
    final artists = await _safe(() => _api.getFollowedArtists(limit: 50), <Artist>[]);
    return _LibraryData(playlists: playlists, albums: albums, artists: artists);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('Your Library',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          ),
          _FilterChips(
            selected: _filter,
            onSelected: (f) => setState(() => _filter = f),
          ),
          Expanded(
            child: FutureBuilder<_LibraryData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: SpotifyColors.green),
                  );
                }
                final data = snapshot.data ?? _LibraryData.empty;
                return _LibraryList(data: data, filter: _filter);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});
  final _Filter selected;
  final ValueChanged<_Filter> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = {
      _Filter.all: 'All',
      _Filter.playlists: 'Playlists',
      _Filter.artists: 'Artists',
      _Filter.albums: 'Albums',
    };
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final entry in labels.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(entry.value),
                selected: selected == entry.key,
                onSelected: (_) => onSelected(entry.key),
                showCheckmark: false,
                backgroundColor: SpotifyColors.elevated,
                selectedColor: SpotifyColors.green,
                labelStyle: TextStyle(
                  color: selected == entry.key
                      ? SpotifyColors.black
                      : SpotifyColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
            ),
        ],
      ),
    );
  }
}

class _LibraryList extends StatelessWidget {
  const _LibraryList({required this.data, required this.filter});
  final _LibraryData data;
  final _Filter filter;

  @override
  Widget build(BuildContext context) {
    final showPlaylists = filter == _Filter.all || filter == _Filter.playlists;
    final showAlbums = filter == _Filter.all || filter == _Filter.albums;
    final showArtists = filter == _Filter.all || filter == _Filter.artists;

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      children: [
        if (showPlaylists)
          _LibraryRow(
            imageUrl: null,
            fallbackIcon: Icons.favorite,
            fallbackColor: const Color(0xFF4B2E83),
            title: 'Liked Songs',
            subtitle: 'Playlist',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LikedSongsScreen()),
            ),
          ),
        if (showPlaylists)
          for (final p in data.playlists)
            _LibraryRow(
              imageUrl: p.imageUrl,
              title: p.name,
              subtitle: 'Playlist • ${p.ownerName}',
              onTap: () => openPlaylist(context, p),
            ),
        if (showAlbums)
          for (final a in data.albums)
            _LibraryRow(
              imageUrl: a.imageUrl,
              title: a.name,
              subtitle: 'Album • ${a.artistNames}',
              onTap: () => openAlbum(context, a),
            ),
        if (showArtists)
          for (final a in data.artists)
            _LibraryRow(
              imageUrl: a.imageUrl,
              circle: true,
              fallbackIcon: Icons.person,
              title: a.name,
              subtitle: 'Artist',
              onTap: () => openArtist(context, a),
            ),
      ],
    );
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.circle = false,
    this.fallbackIcon = Icons.music_note,
    this.fallbackColor,
  });

  final String? imageUrl;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool circle;
  final IconData fallbackIcon;
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) {
    Widget leading;
    if (imageUrl == null && fallbackColor != null) {
      leading = Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [fallbackColor!, fallbackColor!.withValues(alpha: 0.6)],
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(fallbackIcon, color: Colors.white, size: 26),
      );
    } else {
      leading = ArtImage(
        url: imageUrl,
        size: 56,
        circle: circle,
        icon: fallbackIcon,
      );
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: SpotifyColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryData {
  final List<Playlist> playlists;
  final List<Album> albums;
  final List<Artist> artists;
  _LibraryData({
    required this.playlists,
    required this.albums,
    required this.artists,
  });

  static final empty = _LibraryData(playlists: [], albums: [], artists: []);
}
