import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'art_image.dart';

/// A collapsing header used by Album / Playlist / Artist detail screens:
/// a large centered cover fading into the page background, with the title
/// pinned once the header collapses.
class CollectionSliverAppBar extends StatelessWidget {
  const CollectionSliverAppBar({
    super.key,
    required this.title,
    required this.imageUrl,
    this.accentColor = const Color(0xFF454545),
    this.circleImage = false,
    this.coverSize = 220,
  });

  final String title;
  final String? imageUrl;
  final Color accentColor;
  final bool circleImage;
  final double coverSize;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 340,
      backgroundColor: accentColor,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: const EdgeInsets.symmetric(horizontal: 56, vertical: 16),
        title: LayoutBuilder(
          builder: (context, constraints) {
            // Only show the title text once the bar is mostly collapsed.
            final collapsed = constraints.maxHeight <= kToolbarHeight + 40;
            return AnimatedOpacity(
              opacity: collapsed ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          },
        ),
        background: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [accentColor, SpotifyColors.base],
              stops: const [0.0, 1.0],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12, top: 40),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ArtImage(
                    url: imageUrl,
                    size: coverSize,
                    circle: circleImage,
                    borderRadius: 6,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The big green circular play button + shuffle, used under a collection header.
class PlayActionRow extends StatelessWidget {
  const PlayActionRow({
    super.key,
    required this.onPlay,
    required this.onShuffle,
    this.liked = false,
    this.onToggleLike,
  });

  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final bool liked;
  final VoidCallback? onToggleLike;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (onToggleLike != null)
            IconButton(
              iconSize: 30,
              icon: Icon(
                liked ? Icons.favorite : Icons.favorite_border,
                color: liked ? SpotifyColors.green : SpotifyColors.textSecondary,
              ),
              onPressed: onToggleLike,
            ),
          IconButton(
            iconSize: 28,
            icon: const Icon(Icons.shuffle, color: SpotifyColors.textSecondary),
            onPressed: onShuffle,
          ),
          const Spacer(),
          GestureDetector(
            onTap: onPlay,
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: SpotifyColors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow, color: SpotifyColors.black, size: 36),
            ),
          ),
        ],
      ),
    );
  }
}
