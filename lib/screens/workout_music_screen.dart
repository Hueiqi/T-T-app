import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/routes.dart';
import '../config/theme.dart';
import '../providers/workout_music_provider.dart';
import '../spotify/services/auth/auth.dart';
import '../spotify/services/spotify_api.dart';
import '../spotify/state/mini_player_visibility.dart';
import '../spotify/state/player_provider.dart';
import '../spotify/widgets/art_image.dart';
import '../widgets/custom_header.dart';

/// Lets the user attach their own Spotify playlists to workout conditions
/// (Chill / Slow Run / Sprint Run) and start the right music with one tap.
/// Playback runs through the app-root PlayerProvider, so the global floating
/// player picks it up — no need to open the Spotify section.
class WorkoutMusicScreen extends StatefulWidget {
  const WorkoutMusicScreen({super.key});

  @override
  State<WorkoutMusicScreen> createState() => _WorkoutMusicScreenState();
}

class _WorkoutMusicScreenState extends State<WorkoutMusicScreen> {
  String _selectedCondition = WorkoutMusicProvider.conditions.first.id;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkoutMusicProvider>().load();
    });
  }

  WorkoutCondition get _condition => WorkoutMusicProvider.conditions
      .firstWhere((c) => c.id == _selectedCondition);

  Future<void> _playUri(String uri, String name) async {
    final player = context.read<PlayerProvider>();
    setState(() => _starting = true);
    try {
      // Connect the App Remote first if the Spotify section was never opened
      // this session (the engine lives at the app root but connects lazily).
      if (!player.isReady) await player.initialize();
      await player.playContext(uri);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playing "$name" — ${_condition.label} mode')),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _playCondition() async {
    final music = context.read<WorkoutMusicProvider>();
    final pick = music.pickForCondition(_selectedCondition);
    if (pick == null) return;
    await _playUri(pick.uri, pick.name);
  }

  void _openPlaylistPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PlaylistPickerSheet(
        conditionId: _selectedCondition,
        conditionLabel: _condition.label,
        // The sheet lives outside this screen's context; hand it the providers.
        api: context.read<SpotifyApi>(),
        music: context.read<WorkoutMusicProvider>(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authStatus = context.watch<AuthController>().status;
    final music = context.watch<WorkoutMusicProvider>();
    final assigned = music.playlistsFor(_selectedCondition);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CustomHeader(
                title: 'Workout Music',
                showBack: true,
                actions: [
                  ValueListenableBuilder<bool>(
                    valueListenable: MiniPlayerVisibility.instance.visible,
                    builder: (_, visible, _) => IconButton(
                      icon: Icon(visible
                          ? Icons.picture_in_picture_alt
                          : Icons.picture_in_picture_outlined),
                      tooltip: visible
                          ? 'Hide floating bar'
                          : 'Show floating bar',
                      onPressed: MiniPlayerVisibility.instance.toggle,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: authStatus != AuthStatus.authenticated
                  ? _connectPrompt()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        const Text(
                          'Pick a workout condition, assign your Spotify '
                          'playlists to it, then hit play.',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        _conditionBar(),
                        const SizedBox(height: 20),
                        _playButton(assigned.isNotEmpty),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_condition.label} playlists',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _openPlaylistPicker,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (assigned.isEmpty)
                          _emptyState()
                        else
                          ...assigned.map((p) => _playlistTile(p)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _connectPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.music_off,
                size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'Connect Spotify first to set up your workout playlists.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.spotify),
              icon: const Icon(Icons.music_note),
              label: const Text('Connect Spotify'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conditionBar() {
    return Row(
      children: [
        for (final c in WorkoutMusicProvider.conditions) ...[
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedCondition = c.id),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: c.id == _selectedCondition
                      ? AppTheme.primaryColor
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: c.id == _selectedCondition
                        ? AppTheme.primaryColor
                        : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  children: [
                    Text(c.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 4),
                    Text(
                      c.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.id == _selectedCondition
                            ? Colors.white
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (c != WorkoutMusicProvider.conditions.last)
            const SizedBox(width: 10),
        ],
      ],
    );
  }

  Widget _playButton(bool enabled) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: enabled && !_starting ? _playCondition : null,
        icon: _starting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.play_arrow),
        label: Text(_starting
            ? 'Starting...'
            : 'Play ${_condition.label} ${_condition.emoji}'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1DB954),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Column(
        children: [
          Icon(Icons.queue_music, size: 36, color: AppTheme.textSecondary),
          SizedBox(height: 8),
          Text(
            'No playlists yet. Tap "Add" to pick playlists from your '
            'Spotify library for this condition.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _playlistTile(SavedPlaylist p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: ArtImage(url: p.imageUrl, size: 44, borderRadius: 6),
        title: Text(p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_circle_fill,
                  color: Color(0xFF1DB954), size: 28),
              onPressed: _starting ? null : () => _playUri(p.uri, p.name),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppTheme.textSecondary, size: 22),
              onPressed: () => context
                  .read<WorkoutMusicProvider>()
                  .removePlaylist(_selectedCondition, p.uri),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet listing the user's Spotify playlists with checkboxes to
/// assign/unassign them to the selected condition.
class _PlaylistPickerSheet extends StatefulWidget {
  const _PlaylistPickerSheet({
    required this.conditionId,
    required this.conditionLabel,
    required this.api,
    required this.music,
  });

  final String conditionId;
  final String conditionLabel;
  final SpotifyApi api;
  final WorkoutMusicProvider music;

  @override
  State<_PlaylistPickerSheet> createState() => _PlaylistPickerSheetState();
}

class _PlaylistPickerSheetState extends State<_PlaylistPickerSheet> {
  late Future<List<SavedPlaylist>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadPlaylists();
  }

  Future<List<SavedPlaylist>> _loadPlaylists() async {
    final page = await widget.api.getMyPlaylists(limit: 50);
    return [
      for (final p in page.items)
        SavedPlaylist(uri: p.uri, name: p.name, imageUrl: p.imageUrl),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (ctx, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add playlists to ${widget.conditionLabel}',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tick one or more playlists from your Spotify library.',
                style:
                    TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<SavedPlaylist>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF1DB954)));
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Could not load your playlists.\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      );
                    }
                    final playlists = snapshot.data!;
                    if (playlists.isEmpty) {
                      return const Center(
                        child: Text('Your Spotify library has no playlists.',
                            style: TextStyle(color: AppTheme.textSecondary)),
                      );
                    }
                    // Listen to the provider so ticks update immediately.
                    return AnimatedBuilder(
                      animation: widget.music,
                      builder: (_, _) => ListView.builder(
                        controller: scrollController,
                        itemCount: playlists.length,
                        itemBuilder: (_, i) {
                          final p = playlists[i];
                          final checked = widget.music
                              .isAssigned(widget.conditionId, p.uri);
                          return CheckboxListTile(
                            value: checked,
                            activeColor: const Color(0xFF1DB954),
                            controlAffinity:
                                ListTileControlAffinity.trailing,
                            contentPadding: EdgeInsets.zero,
                            secondary: ArtImage(
                                url: p.imageUrl, size: 40, borderRadius: 6),
                            title: Text(p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14)),
                            onChanged: (_) => widget.music
                                .togglePlaylist(widget.conditionId, p),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
