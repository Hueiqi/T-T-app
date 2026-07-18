import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../services/spotify_api.dart';
import '../state/player_provider.dart';
import '../widgets/collection_app_bar.dart';
import '../widgets/track_tile.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key, required this.playlistId, this.preloaded});

  final String playlistId;
  final Playlist? preloaded;

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  late final SpotifyApi _api;
  Playlist? _playlist;
  List<Track> _tracks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = context.read<SpotifyApi>();
    _playlist = widget.preloaded;
    _load();
  }

  Future<void> _load() async {
    try {
      final playlist = await _api.getPlaylist(widget.playlistId);
      final tracks = await _api.getPlaylistTracks(widget.playlistId);
      if (!mounted) return;
      setState(() {
        _playlist = playlist;
        _tracks = tracks;
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
    final playlist = _playlist;
    if (playlist == null) return;
    context.read<PlayerProvider>().playContext(playlist.uri, offsetIndex: index);
  }

  @override
  Widget build(BuildContext context) {
    final playlist = _playlist;
    return Scaffold(
      backgroundColor: SpotifyColors.base,
      body: CustomScrollView(
        slivers: [
          CollectionSliverAppBar(
            title: playlist?.name ?? 'Playlist',
            imageUrl: playlist?.imageUrl,
          ),
          if (playlist != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(playlist.name,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800)),
                    if (playlist.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        playlist.description,
                        style: const TextStyle(
                            color: SpotifyColors.textSecondary, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '${playlist.ownerName} • ${playlist.totalTracks} songs',
                      style: const TextStyle(
                          color: SpotifyColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          if (playlist != null)
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
                child: Text('Could not load playlist.\n$_error',
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
