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
    if (context.read<AuthController>().status != AuthStatus.authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect Spotify first to browse your playlists.'),
        ),
      );
      return;
    }
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
      // Real AppBar so the purple reaches the status bar, consistent with the
      // rest of the app (the old CustomHeader sat inside a padded body).
      appBar: AppBar(
        title: const Text('Workout Music'),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: MiniPlayerVisibility.instance.visible,
            builder: (_, visible, _) => IconButton(
              icon: Icon(visible
                  ? Icons.picture_in_picture_alt
                  : Icons.picture_in_picture_outlined),
              tooltip: visible ? 'Hide floating bar' : 'Show floating bar',
              onPressed: MiniPlayerVisibility.instance.toggle,
            ),
          ),
        ],
      ),
      // The condition picker is always usable — assigning playlists needs
      // Spotify, but choosing a condition and seeing what is already saved
      // does not. Gating the whole body on auth is what made this screen
      // render blank when the status was wrong.
      body: authStatus == AuthStatus.unauthenticated
          ? _connectPrompt()
          : ListView(
              // Extra bottom room so the last tile clears the global
              // floating mini-player.
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                24 + MediaQuery.of(context).padding.bottom + 72,
              ),
              children: [
                _conditionBar(),
                const SizedBox(height: 18),
                _heroCard(assigned),
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
                    if (assigned.isNotEmpty)
                      Text(
                        '${assigned.length}',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    const SizedBox(width: 8),
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
    );
  }

  Widget _connectPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF1DB954).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.music_off,
                  size: 34, color: Color(0xFF1DB954)),
            ),
            const SizedBox(height: 18),
            const Text(
              'Connect Spotify',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Link your account to assign playlists to Chill, Slow Run '
              'and Sprint Run.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.spotify),
              icon: const Icon(Icons.music_note),
              label: const Text('Connect Spotify'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Segmented selector. The hero card below carries the emoji and colour, so
  /// this stays deliberately quiet — a white pill sliding across a grey track.
  Widget _conditionBar() {
    final music = context.watch<WorkoutMusicProvider>();

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final c in WorkoutMusicProvider.conditions)
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _selectedCondition = c.id),
                borderRadius: BorderRadius.circular(11),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(
                    color: c.id == _selectedCondition
                        ? Colors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: c.id == _selectedCondition
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Labels like "Sprint Run" clip on narrow phones and at
                      // large system text scales, so shrink to fit instead.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          c.label,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: c.id == _selectedCondition
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      // A dot marks conditions that already have playlists, so
                      // it's obvious at a glance which modes are set up.
                      const SizedBox(height: 4),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: music.playlistsFor(c.id).isEmpty
                              ? Colors.transparent
                              : (c.id == _selectedCondition
                                  ? AppTheme.primaryColor
                                  : AppTheme.textSecondary
                                      .withValues(alpha: 0.5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The selected condition's headline card: what it is, how many playlists
  /// are assigned, and the primary Play action. Replaces the bare pill button
  /// so the chosen mode reads as the subject of the page.
  Widget _heroCard(List<SavedPlaylist> assigned) {
    final enabled = assigned.isNotEmpty;
    final trackTotal =
        assigned.fold<int>(0, (sum, p) => sum + p.totalTracks);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_condition.emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_condition.label} mode',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      enabled
                          ? '${assigned.length} playlist'
                              '${assigned.length == 1 ? '' : 's'}'
                              '${trackTotal > 0 ? ' · $trackTotal tracks' : ''}'
                          : 'No playlists assigned yet',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
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
              label: Text(
                _starting
                    ? 'Starting...'
                    : enabled
                        ? 'Play ${_condition.label}'
                        : 'Add a playlist to play',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.25),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.queue_music,
                size: 28, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 14),
          Text(
            'No playlists for ${_condition.label}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pick playlists from your Spotify library and they will be '
            'saved to this mode.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          // The "Add" link above is easy to miss when the list is empty, so
          // repeat the action here where the user is already looking.
          ElevatedButton.icon(
            onPressed: _openPlaylistPicker,
            icon: const Icon(Icons.add, size: 18),
            label: Text('Add to ${_condition.label}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ],
      ),
    );
  }

  /// Full detail for one assigned playlist — cover art, track count, owner and
  /// the Spotify description, which is too long for the list subtitle.
  void _showPlaylistDetail(SavedPlaylist p) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ArtImage(url: p.imageUrl, size: 72, borderRadius: 10),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      if (p.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          p.subtitle,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'Assigned to ${_condition.label} ${_condition.emoji}',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (p.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                p.description,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _playUri(p.uri, p.name);
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context
                        .read<WorkoutMusicProvider>()
                        .removePlaylist(_selectedCondition, p.uri);
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Remove'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _playlistTile(SavedPlaylist p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        // Remove moved into the detail sheet — two icon buttons crowded the
        // row and made an accidental delete easy next to Play.
        onTap: () => _showPlaylistDetail(p),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: ArtImage(url: p.imageUrl, size: 48, borderRadius: 8),
        title: Text(p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: p.subtitle.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  p.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
        trailing: IconButton(
          icon: const Icon(Icons.play_circle_fill,
              color: Color(0xFF1DB954), size: 32),
          tooltip: 'Play this playlist',
          onPressed: _starting ? null : () => _playUri(p.uri, p.name),
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
    debugPrint(
      'WorkoutMusic: /me/playlists returned ${page.items.length} of '
      '${page.total}',
    );
    // Playlists with a blank uri can't be played or stored meaningfully, and
    // would render as empty rows.
    return [
      for (final p in page.items)
        if (p.uri.isNotEmpty)
          SavedPlaylist(
            uri: p.uri,
            name: p.name.isEmpty ? 'Untitled Playlist' : p.name,
            imageUrl: p.imageUrl,
            totalTracks: p.totalTracks,
            ownerName: p.ownerName,
            description: p.description,
          ),
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
          // Keep the Done button clear of the system gesture bar.
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            12 + MediaQuery.of(ctx).padding.bottom,
          ),
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppTheme.textSecondary, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              'Could not load your playlists.\n${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => setState(() {
                                _future = _loadPlaylists();
                              }),
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }
                    final playlists = snapshot.data!;
                    if (playlists.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'No playlists found in your Spotify account.\n\n'
                            'Spotify only returns playlists you created or '
                            'follow — liked songs and algorithmic mixes like '
                            'Discover Weekly are not included. Save one in the '
                            'Spotify app, then reopen this sheet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ),
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
                            subtitle: p.subtitle.isEmpty
                                ? null
                                : Text(
                                    p.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12),
                                  ),
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
