import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../services/spotify_api.dart';
import '../state/player_provider.dart';
import '../widgets/collection_app_bar.dart';
import '../widgets/track_tile.dart';

class LikedSongsScreen extends StatefulWidget {
  const LikedSongsScreen({super.key});

  @override
  State<LikedSongsScreen> createState() => _LikedSongsScreenState();
}

class _LikedSongsScreenState extends State<LikedSongsScreen> {
  late final SpotifyApi _api;
  List<Track> _tracks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = context.read<SpotifyApi>();
    _load();
  }

  Future<void> _load() async {
    try {
      final tracks = await _api.getSavedTracks(limit: 50);
      if (!mounted) return;
      setState(() {
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

  static const String _likedSongsContextUri = 'spotify:collection:tracks';

  void _playFrom(int index) {
    context
        .read<PlayerProvider>()
        .playContext(_likedSongsContextUri, offsetIndex: index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyColors.base,
      body: CustomScrollView(
        slivers: [
          const CollectionSliverAppBar(
            title: 'Liked Songs',
            imageUrl: null,
            accentColor: Color(0xFF4B2E83),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Liked Songs',
                      style: TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('${_tracks.length} liked songs',
                      style: const TextStyle(
                          color: SpotifyColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          ),
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
                child: Text('Could not load liked songs.\n$_error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: SpotifyColors.textSecondary)),
              ),
            )
          else if (_tracks.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text('Songs you like will appear here.',
                    style: TextStyle(color: SpotifyColors.textSecondary)),
              ),
            )
          else
            SliverList.builder(
              itemCount: _tracks.length,
              itemBuilder: (context, i) => TrackTile(
                track: _tracks[i],
                onTap: () => _playFrom(i),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
