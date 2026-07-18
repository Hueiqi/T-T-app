import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../services/spotify_api.dart';
import '../state/player_provider.dart';
import '../widgets/collection_app_bar.dart';
import '../widgets/media_cards.dart';
import '../widgets/track_tile.dart';

class ArtistScreen extends StatefulWidget {
  const ArtistScreen({super.key, required this.artistId, this.preloaded});

  final String artistId;
  final Artist? preloaded;

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  late final SpotifyApi _api;
  Artist? _artist;
  List<Track> _topTracks = [];
  List<Album> _albums = [];
  bool _loading = true;
  String? _error;
  bool _showAllTracks = false;

  @override
  void initState() {
    super.initState();
    _api = context.read<SpotifyApi>();
    _artist = widget.preloaded;
    _load();
  }

  Future<void> _load() async {
    try {
      final artist = await _api.getArtist(widget.artistId);
      final top = await _api.getArtistTopTracks(widget.artistId);
      final albums = await _api.getArtistAlbums(widget.artistId);
      if (!mounted) return;
      setState(() {
        _artist = artist;
        _topTracks = top;
        _albums = albums;
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

  @override
  Widget build(BuildContext context) {
    final artist = _artist;
    final visibleTracks =
        _showAllTracks ? _topTracks : _topTracks.take(5).toList();

    return Scaffold(
      backgroundColor: SpotifyColors.base,
      body: CustomScrollView(
        slivers: [
          CollectionSliverAppBar(
            title: artist?.name ?? 'Artist',
            imageUrl: artist?.imageUrl,
            circleImage: true,
          ),
          if (artist != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        artist.name,
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (artist.followers != null)
                      Text(
                        '${_formatCount(artist.followers!)} followers',
                        style: const TextStyle(
                            color: SpotifyColors.textSecondary, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ),
          if (artist != null)
            SliverToBoxAdapter(
              child: PlayActionRow(
                onPlay: () =>
                    context.read<PlayerProvider>().playContext(artist.uri),
                onShuffle: () {
                  context.read<PlayerProvider>().toggleShuffle();
                  context.read<PlayerProvider>().playContext(artist.uri);
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
                child: Text('Could not load artist.\n$_error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: SpotifyColors.textSecondary)),
              ),
            )
          else ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Popular',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
            ),
            SliverList.builder(
              itemCount: visibleTracks.length,
              itemBuilder: (context, i) {
                final t = visibleTracks[i];
                return TrackTile(
                  track: t,
                  leadingNumber: i + 1,
                  showArt: true,
                  onTap: () => context
                      .read<PlayerProvider>()
                      .playTracks(_topTracks.map((e) => e.uri).toList(), offset: i),
                );
              },
            ),
            if (_topTracks.length > 5)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextButton(
                    onPressed: () =>
                        setState(() => _showAllTracks = !_showAllTracks),
                    child: Text(
                      _showAllTracks ? 'Show less' : 'See more',
                      style: const TextStyle(
                          color: SpotifyColors.textSecondary,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            if (_albums.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: HorizontalShelf(
                    title: 'Discography',
                    children: [
                      for (final a in _albums) AlbumCard(album: a),
                    ],
                  ),
                ),
              ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
