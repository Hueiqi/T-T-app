import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Album/artist/playlist artwork with a consistent placeholder + error tile.
class ArtImage extends StatelessWidget {
  const ArtImage({
    super.key,
    required this.url,
    this.size,
    this.borderRadius = 4,
    this.circle = false,
    this.icon = Icons.music_note,
  });

  final String? url;
  final double? size;
  final double borderRadius;
  final bool circle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final radius = circle
        ? BorderRadius.circular((size ?? 100))
        : BorderRadius.circular(borderRadius);

    Widget fallback() => Container(
          width: size,
          height: size,
          color: SpotifyColors.elevated,
          alignment: Alignment.center,
          child: Icon(icon, color: SpotifyColors.textTertiary, size: (size ?? 48) * 0.4),
        );

    final Widget child = (url == null || url!.isEmpty)
        ? fallback()
        : CachedNetworkImage(
            imageUrl: url!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 200),
            placeholder: (_, _) => Container(
              width: size,
              height: size,
              color: SpotifyColors.elevated,
            ),
            errorWidget: (_, _, _) => fallback(),
          );

    return ClipRRect(borderRadius: radius, child: child);
  }
}
