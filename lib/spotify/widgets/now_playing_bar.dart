import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../screens/player_screen.dart';
import '../state/mini_player_visibility.dart';
import '../state/player_provider.dart';
import 'art_image.dart';

/// The compact "now playing" bar pinned above the bottom navigation, mirroring
/// Spotify's mini-player.
class NowPlayingBar extends StatelessWidget {
  const NowPlayingBar({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final state = player.state;
    final track = state.track;

    if (track == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        PageRouteBuilder(
          opaque: true,
          transitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (_, _, _) => const PlayerScreen(),
          transitionsBuilder: (_, animation, _, child) {
            return SlideTransition(
              position: Tween(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: ArtImage(url: track.imageUrl, size: 40, borderRadius: 4),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        track.artistNames,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: SpotifyColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.picture_in_picture_alt, size: 20),
                  color: SpotifyColors.textSecondary,
                  tooltip: 'Show floating player',
                  onPressed: MiniPlayerVisibility.instance.show,
                ),
                IconButton(
                  iconSize: 30,
                  icon: Icon(
                    player.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: SpotifyColors.textPrimary,
                  ),
                  onPressed: player.togglePlay,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: state.progress,
                  minHeight: 2,
                  backgroundColor: SpotifyColors.textTertiary,
                  valueColor: const AlwaysStoppedAnimation(SpotifyColors.textPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
