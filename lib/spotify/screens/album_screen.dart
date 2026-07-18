import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../services/spotify_api.dart';
import '../state/player_provider.dart';
import '../widgets/collection_app_bar.dart';
import '../widgets/track_tile.dart';

class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key, required this.albumId, this.preloaded});

  final String albumId;
  final Album? preloaded;

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  late final SpotifyApi _api;
  Album? _album;
  List<Track> _tracks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = context.read<SpotifyApi>();
    _album = widget.preloaded;
    _load();
  }

  Future<void> _load() async {
    try {
      final album = await _api.getAlbum(widget.albumId);
      final tracks = await _api.getAlbumTracks(widget.albumId);
      // Album-track objects don't embed the album, so attach it for art.
      final withAlbum = tracks
          .map((t) => Track(
                id: t.id,
                name: t.name,
                uri: t.uri,
                artists: t.artists,
                album: album,
                durationMs: t.durationMs,
                explicit: t.explicit,
                trackNumber: t.trackNumber,
              ))
          .toList();
      if (!mounted) return;
      setState(() {
        _album = album;
        _tracks = withAlbum;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _playFrom(int index) {
    final album = _album;
    if (album == null) return;
    context.read<PlayerProvider>().playContext(album.uri, offsetIndex: index);
  }

  @override
  Widget build(BuildContext context) {
    final album = _album;
    return Scaffold(
      backgroundColor: SpotifyColors.base,
      body: CustomScrollView(
        slivers: [
          CollectionSliverAppBar(
            title: album?.name ?? 'Album',
            imageUrl: album?.imageUrl,
          ),
          if (album != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(album.name,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(
                      album.artistNames,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        album.albumType[0].toUpperCase() +
                            album.albumType.substring(1),
                        if (album.releaseYear != null) album.releaseYear!,
                      ].join(' • '),
                      style: const TextStyle(
                          color: SpotifyColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          if (album != null)
            SliverToBoxAdapter(
              child: PlayActionRow(
                onPlay: () => _playFrom(0),
                onShuffle: () {
                  context.read<PlayerProvider>().toggleShuffle();
                  _playFrom(0);
                },
              ),
            ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: SpotifyColors.green),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text('Could not load album.\n$_error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: SpotifyColors.textSecondary)),
              ),
            )
          else
            SliverList.builder(
              itemCount: _tracks.length,
              itemBuilder: (context, i) {
                final t = _tracks[i];
                return TrackTile(
                  track: t,
                  showArt: false,
                  leadingNumber: t.trackNumber > 0 ? t.trackNumber : i + 1,
                  onTap: () => _playFrom(i),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
