import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Full-screen Spotify-style loading splash.
class LoadingSplash extends StatelessWidget {
  const LoadingSplash({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyColors.base,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SpotifyMark(size: 64),
            const SizedBox(height: 28),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(SpotifyColors.green),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 20),
              Text(
                message!,
                style: const TextStyle(color: SpotifyColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The circular Spotify logo glyph drawn with three "sound wave" arcs.
class _SpotifyMark extends StatelessWidget {
  const _SpotifyMark({this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: SpotifyColors.green,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.music_note, color: SpotifyColors.black, size: size * 0.6),
    );
  }
}
