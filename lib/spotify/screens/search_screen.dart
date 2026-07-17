import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/spotify_api.dart';
import '../state/player_provider.dart';
import '../widgets/media_cards.dart';
import '../widgets/track_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final SpotifyApi _api;
  final _controller = TextEditingController();
  Timer? _debounce;

  SearchResults _results = SearchResults.empty;
  bool _loading = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _api = context.read<SpotifyApi>();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _query = value;
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = SearchResults.empty;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(value));
  }

  Future<void> _run(String value) async {
    try {
      final res = await _api.search(value);
      if (!mounted || value != _query) return;
      setState(() {
        _results = res;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Text('Search',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                  color: SpotifyColors.black, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Artists, songs, or podcasts',
                hintStyle: const TextStyle(
                    color: Color(0xFF6A6A6A), fontWeight: FontWeight.w500),
                prefixIcon: const Icon(Icons.search, color: SpotifyColors.black),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, color: SpotifyColors.black),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: SpotifyColors.green),
      );
    }
    if (_query.trim().isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Search for your favourite songs, artists, albums and playlists.',
            textAlign: TextAlign.center,
            style: TextStyle(color: SpotifyColors.textSecondary),
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text('No results for "$_query"',
            style: const TextStyle(color: SpotifyColors.textSecondary)),
      );
    }

    final r = _results;
    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      children: [
        if (r.artists.isNotEmpty)
          HorizontalShelf(
            title: 'Artists',
            children: [for (final a in r.artists) ArtistCard(artist: a)],
          ),
        if (r.tracks.isNotEmpty) ...[
          const _SectionTitle('Songs'),
          for (var i = 0; i < r.tracks.length; i++)
            TrackTile(
              track: r.tracks[i],
              onTap: () => context.read<PlayerProvider>().playTracks(
                    r.tracks.map((e) => e.uri).toList(),
                    offset: i,
                  ),
            ),
        ],
        if (r.albums.isNotEmpty)
          HorizontalShelf(
            title: 'Albums',
            children: [for (final a in r.albums) AlbumCard(album: a)],
          ),
        if (r.playlists.isNotEmpty)
          HorizontalShelf(
            title: 'Playlists',
            children: [for (final p in r.playlists) PlaylistCard(playlist: p)],
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
    );
  }
}
