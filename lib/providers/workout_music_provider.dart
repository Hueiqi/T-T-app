import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A workout condition users can attach Spotify playlists to.
class WorkoutCondition {
  final String id;
  final String label;
  final String emoji;
  const WorkoutCondition(this.id, this.label, this.emoji);
}

/// Minimal snapshot of a Spotify playlist saved against a condition.
/// (We store our own copy so assignments survive app restarts without
/// needing a Spotify API call to render the list.)
class SavedPlaylist {
  final String uri;
  final String name;
  final String? imageUrl;

  const SavedPlaylist({required this.uri, required this.name, this.imageUrl});

  Map<String, dynamic> toJson() =>
      {'uri': uri, 'name': name, 'imageUrl': imageUrl};

  factory SavedPlaylist.fromJson(Map<String, dynamic> json) => SavedPlaylist(
        uri: json['uri'] as String,
        name: json['name'] as String? ?? 'Playlist',
        imageUrl: json['imageUrl'] as String?,
      );
}

/// Maps workout conditions (chill / slow run / sprint run) to the user's own
/// Spotify playlists, persisted locally. The UI picks a condition and plays a
/// random playlist assigned to it through the app-root PlayerProvider.
class WorkoutMusicProvider extends ChangeNotifier {
  static const String _prefsKey = 'workout_music_playlists_v1';

  static const List<WorkoutCondition> conditions = [
    WorkoutCondition('chill', 'Chill', '😌'),
    WorkoutCondition('slow_run', 'Slow Run', '🏃'),
    WorkoutCondition('sprint_run', 'Sprint Run', '💨'),
  ];

  final Map<String, List<SavedPlaylist>> _byCondition = {};
  bool _loaded = false;
  final _random = Random();

  bool get isLoaded => _loaded;

  List<SavedPlaylist> playlistsFor(String conditionId) =>
      List.unmodifiable(_byCondition[conditionId] ?? const []);

  bool isAssigned(String conditionId, String uri) =>
      (_byCondition[conditionId] ?? const []).any((p) => p.uri == uri);

  /// Random pick among the playlists assigned to a condition, or null if none.
  SavedPlaylist? pickForCondition(String conditionId) {
    final list = _byCondition[conditionId];
    if (list == null || list.isEmpty) return null;
    return list[_random.nextInt(list.length)];
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        decoded.forEach((condition, list) {
          _byCondition[condition] = [
            for (final item in (list as List))
              SavedPlaylist.fromJson(item as Map<String, dynamic>),
          ];
        });
      }
    } catch (e) {
      debugPrint('WorkoutMusic: failed to load saved playlists: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          for (final e in _byCondition.entries)
            e.key: [for (final p in e.value) p.toJson()],
        }),
      );
    } catch (e) {
      debugPrint('WorkoutMusic: failed to save playlists: $e');
    }
  }

  /// Adds the playlist to the condition if missing, removes it if present.
  Future<void> togglePlaylist(String conditionId, SavedPlaylist playlist) async {
    final list = _byCondition.putIfAbsent(conditionId, () => []);
    final existing = list.indexWhere((p) => p.uri == playlist.uri);
    if (existing >= 0) {
      list.removeAt(existing);
    } else {
      list.add(playlist);
    }
    notifyListeners();
    await _save();
  }

  Future<void> removePlaylist(String conditionId, String uri) async {
    _byCondition[conditionId]?.removeWhere((p) => p.uri == uri);
    notifyListeners();
    await _save();
  }
}
