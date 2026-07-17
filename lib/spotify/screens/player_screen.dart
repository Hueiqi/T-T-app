import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/playback_state.dart';
import '../widgets/art_image.dart';
import '../state/player_provider.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final state = player.state;
    final track = state.track;

    return Scaffold(
      backgroundColor: SpotifyColors.base,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3A3A3A), SpotifyColors.base, SpotifyColors.black],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: track == null
              ? const Center(
                  child: Text('Nothing is playing',
                      style: TextStyle(color: SpotifyColors.textSecondary)),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _TopBar(),
                      const Spacer(flex: 1),
                      AspectRatio(
                        aspectRatio: 1,
                        child: ArtImage(url: track.imageUrl, borderRadius: 8),
                      ),
                      const Spacer(flex: 1),
                      _TrackInfo(track: track),
                      const SizedBox(height: 12),
                      _SeekBar(state: state),
                      const SizedBox(height: 8),
                      _Controls(player: player, state: state),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 32),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const Expanded(
          child: Column(
            children: [
              Text('PLAYING FROM',
                  style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      color: SpotifyColors.textSecondary)),
              SizedBox(height: 2),
              Text('Spotify',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {},
        ),
      ],
    );
  }
}

class _TrackInfo extends StatelessWidget {
  const _TrackInfo({required this.track});
  final PlayerTrack track;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                track.artistNames,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  color: SpotifyColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.add_circle_outline, color: SpotifyColors.textSecondary),
      ],
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.state});
  final PlaybackState state;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragValue;

  String _fmt(int ms) {
    final s = (ms / 1000).round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final duration = state.durationMs.toDouble().clamp(1, double.infinity);
    final position = (_dragValue ?? state.positionMs.toDouble()).clamp(0, duration);

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            min: 0,
            max: duration.toDouble(),
            value: position.toDouble(),
            onChanged: (v) => setState(() => _dragValue = v),
            onChangeEnd: (v) {
              context.read<PlayerProvider>().seek(v.round());
              setState(() => _dragValue = null);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(position.round()),
                  style: const TextStyle(
                      fontSize: 11, color: SpotifyColors.textSecondary)),
              Text(_fmt(state.durationMs),
                  style: const TextStyle(
                      fontSize: 11, color: SpotifyColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.player, required this.state});
  final PlayerProvider player;
  final PlaybackState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(Icons.shuffle,
              color: state.shuffle ? SpotifyColors.green : SpotifyColors.textSecondary),
          onPressed: player.toggleShuffle,
        ),
        IconButton(
          iconSize: 40,
          icon: const Icon(Icons.skip_previous, color: SpotifyColors.textPrimary),
          onPressed: player.previous,
        ),
        Container(
          width: 68,
          height: 68,
          decoration: const BoxDecoration(
            color: SpotifyColors.textPrimary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            iconSize: 38,
            icon: Icon(
              player.isPlaying ? Icons.pause : Icons.play_arrow,
              color: SpotifyColors.black,
            ),
            onPressed: player.togglePlay,
          ),
        ),
        IconButton(
          iconSize: 40,
          icon: const Icon(Icons.skip_next, color: SpotifyColors.textPrimary),
          onPressed: player.next,
        ),
        IconButton(
          icon: Icon(
            state.repeatMode == LoopMode.track
                ? Icons.repeat_one
                : Icons.repeat,
            color: state.repeatMode == LoopMode.off
                ? SpotifyColors.textSecondary
                : SpotifyColors.green,
          ),
          onPressed: player.cycleRepeat,
        ),
      ],
    );
  }
}
