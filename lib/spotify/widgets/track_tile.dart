import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../state/player_provider.dart';
import 'art_image.dart';

/// A single track row, matching Spotify's list style. Highlights the row in
/// green when it is the currently-playing track.
class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    this.onTap,
    this.leadingNumber,
    this.showArt = true,
    this.trailing,
  });

  final Track track;
  final VoidCallback? onTap;
  final int? leadingNumber;
  final bool showArt;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final currentId = context.select<PlayerProvider, String?>(
      (p) => p.state.track?.id,
    );
    final isCurrent = currentId != null && currentId == track.id;
    final titleColor =
        isCurrent ? SpotifyColors.green : SpotifyColors.textPrimary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (leadingNumber != null)
              SizedBox(
                width: 28,
                child: Text(
                  '$leadingNumber',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isCurrent
                        ? SpotifyColors.green
                        : SpotifyColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
              ),
            if (showArt) ...[
              ArtImage(url: track.thumbnailUrl, size: 48, borderRadius: 4),
              const SizedBox(width: 12),
            ] else if (leadingNumber != null)
              const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (track.explicit) ...[
                        const _ExplicitBadge(),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          track.artistNames,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: SpotifyColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            trailing ??
                IconButton(
                  icon: const Icon(Icons.more_vert,
                      color: SpotifyColors.textSecondary),
                  onPressed: () {},
                ),
          ],
        ),
      ),
    );
  }
}

class _ExplicitBadge extends StatelessWidget {
  const _ExplicitBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: SpotifyColors.textTertiary,
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.center,
      child: const Text(
        'E',
        style: TextStyle(
          color: SpotifyColors.base,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
