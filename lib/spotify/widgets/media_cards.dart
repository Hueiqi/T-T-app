import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../screens/album_screen.dart';
import '../screens/artist_screen.dart';
import '../screens/playlist_screen.dart';
import 'art_image.dart';

const double _cardWidth = 150;

void openAlbum(BuildContext context, Album album) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => AlbumScreen(albumId: album.id, preloaded: album),
  ));
}

void openPlaylist(BuildContext context, Playlist playlist) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => PlaylistScreen(playlistId: playlist.id, preloaded: playlist),
  ));
}

void openArtist(BuildContext context, Artist artist) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ArtistScreen(artistId: artist.id, preloaded: artist),
  ));
}

class AlbumCard extends StatelessWidget {
  const AlbumCard({super.key, required this.album, this.width = _cardWidth});
  final Album album;
  final double width;

  @override
  Widget build(BuildContext context) {
    return _VerticalCard(
      width: width,
      imageUrl: album.imageUrl,
      title: album.name,
      subtitle: album.releaseYear != null
          ? '${album.releaseYear} • ${album.artistNames}'
          : album.artistNames,
      onTap: () => openAlbum(context, album),
    );
  }
}

class PlaylistCard extends StatelessWidget {
  const PlaylistCard({super.key, required this.playlist, this.width = _cardWidth});
  final Playlist playlist;
  final double width;

  @override
  Widget build(BuildContext context) {
    return _VerticalCard(
      width: width,
      imageUrl: playlist.imageUrl,
      title: playlist.name,
      subtitle: playlist.description.isNotEmpty
          ? playlist.description
          : 'By ${playlist.ownerName}',
      onTap: () => openPlaylist(context, playlist),
    );
  }
}

class ArtistCard extends StatelessWidget {
  const ArtistCard({super.key, required this.artist, this.width = _cardWidth});
  final Artist artist;
  final double width;

  @override
  Widget build(BuildContext context) {
    return _VerticalCard(
      width: width,
      imageUrl: artist.imageUrl,
      title: artist.name,
      subtitle: 'Artist',
      circle: true,
      centerText: true,
      onTap: () => openArtist(context, artist),
    );
  }
}

class _VerticalCard extends StatelessWidget {
  const _VerticalCard({
    required this.width,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.circle = false,
    this.centerText = false,
  });

  final double width;
  final String? imageUrl;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool circle;
  final bool centerText;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment:
              centerText ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            ArtImage(
              url: imageUrl,
              size: width,
              circle: circle,
              borderRadius: 6,
              icon: circle ? Icons.person : Icons.music_note,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: centerText ? TextAlign.center : TextAlign.start,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: centerText ? TextAlign.center : TextAlign.start,
              style: const TextStyle(
                color: SpotifyColors.textSecondary,
                fontSize: 12,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A titled horizontal carousel ("shelf") of cards.
class HorizontalShelf extends StatelessWidget {
  const HorizontalShelf({
    super.key,
    required this.title,
    required this.children,
    this.height = 220,
  });

  final String title;
  final List<Widget> children;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: children.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, i) => children[i],
          ),
        ),
      ],
    );
  }
}
