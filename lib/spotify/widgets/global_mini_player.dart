import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../screens/player_screen.dart';
import '../state/mini_player_visibility.dart';
import '../state/player_provider.dart';
import 'art_image.dart';

/// A full-width horizontal player bar that floats on top of the ENTIRE app
/// (fitness screens included), painted via [MaterialApp.builder].
///
/// It reads the app-root [PlayerProvider], so it appears on any screen whenever
/// something is playing. Drag it vertically to reposition (it spans the full
/// width), tap the track info to open the full [PlayerScreen], use the
/// previous / play-pause / next controls, and the × to dismiss it for the
/// session.
class GlobalMiniPlayer extends StatefulWidget {
  const GlobalMiniPlayer({super.key, required this.navigatorKey});

  /// Root navigator, used to push the full player over whatever screen is up.
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<GlobalMiniPlayer> createState() => _GlobalMiniPlayerState();
}

class _GlobalMiniPlayerState extends State<GlobalMiniPlayer> {
  // Vertical position (top offset) of the full-width bar. Null until first
  // laid out, then seeded near the bottom of the screen.
  double? _top;
  bool _dragging = false;

  final _visibility = MiniPlayerVisibility.instance;

  static const double _height = 64;
  static const double _hMargin = 8;
  static const double _vMargin = 8;

  @override
  void initState() {
    super.initState();
    // Rebuild when the shared visibility flag flips (× hides, button re-shows).
    _visibility.visible.addListener(_onVisibilityChanged);
  }

  @override
  void dispose() {
    _visibility.visible.removeListener(_onVisibilityChanged);
    super.dispose();
  }

  void _onVisibilityChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_visibility.visible.value) return const SizedBox.shrink();

    // The provider may not exist yet on very first frame; guard defensively.
    final player = context.watch<PlayerProvider?>();
    final track = player?.state.track;
    if (player == null || track == null) return const SizedBox.shrink();

    final media = MediaQuery.of(context);
    final size = media.size;
    final safe = media.padding;

    final top = _clampTop(
      _top ?? (size.height - _height - safe.bottom - 96),
      size,
      safe,
    );

    return Positioned(
      left: _hMargin,
      right: _hMargin,
      top: top,
      child: GestureDetector(
        // Vertical drag only, since the bar spans the full width.
        onVerticalDragStart: (_) => setState(() => _dragging = true),
        onVerticalDragUpdate: (d) => setState(() {
          _top = _clampTop((_top ?? top) + d.delta.dy, size, safe);
        }),
        onVerticalDragEnd: (_) => setState(() => _dragging = false),
        child: AnimatedScale(
          scale: _dragging ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: _bar(player, track.name, track.artistNames, track.imageUrl),
        ),
      ),
    );
  }

  Widget _bar(
    PlayerProvider player,
    String title,
    String subtitle,
    String? imageUrl,
  ) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: _height,
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  // Tapping the artwork / title area opens the full player.
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _openPlayer,
                      child: Row(
                        children: [
                          ArtImage(url: imageUrl, size: 44, borderRadius: 8),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: SpotifyColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: SpotifyColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Transport controls: previous / play-pause / next.
                  IconButton(
                    iconSize: 26,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 38, height: 44),
                    icon: const Icon(Icons.skip_previous,
                        color: SpotifyColors.textPrimary),
                    onPressed: player.previous,
                  ),
                  IconButton(
                    iconSize: 34,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 44, height: 44),
                    icon: Icon(
                      player.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                      color: SpotifyColors.green,
                    ),
                    onPressed: player.togglePlay,
                  ),
                  IconButton(
                    iconSize: 26,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 38, height: 44),
                    icon: const Icon(Icons.skip_next,
                        color: SpotifyColors.textPrimary),
                    onPressed: player.next,
                  ),
                  IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 30, height: 44),
                    icon: const Icon(Icons.close,
                        color: SpotifyColors.textSecondary),
                    onPressed: _visibility.hide,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
              child: LinearProgressIndicator(
                value: player.state.progress,
                minHeight: 2,
                backgroundColor: SpotifyColors.textTertiary,
                valueColor: const AlwaysStoppedAnimation(SpotifyColors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPlayer() {
    final nav = widget.navigatorKey.currentState;
    if (nav == null) return;
    nav.push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, _, _) => const PlayerScreen(),
        transitionsBuilder: (_, animation, _, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
    );
  }

  // Keep the bar's top offset within the visible, non-obscured area.
  double _clampTop(double y, Size screen, EdgeInsets safe) {
    final minY = safe.top + _vMargin;
    final maxY = screen.height - _height - safe.bottom - _vMargin;
    return y.clamp(minY, maxY < minY ? minY : maxY);
  }
}
