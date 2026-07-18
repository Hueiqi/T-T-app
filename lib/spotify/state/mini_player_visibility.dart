import 'package:flutter/foundation.dart';

/// Shared visibility flag for the global floating mini-player.
///
/// The floating pill lives at the app root while controls that toggle it (e.g.
/// the Spotify now-playing bar) live inside the nested Spotify `MaterialApp`,
/// so they can't share a Provider scope. This lightweight singleton bridges
/// them: the pill's × sets [visible] to false, and the "show pill" button sets
/// it back to true.
class MiniPlayerVisibility {
  MiniPlayerVisibility._();

  static final MiniPlayerVisibility instance = MiniPlayerVisibility._();

  /// True when the floating pill is allowed to show (a track must also be
  /// playing for it to actually appear).
  final ValueNotifier<bool> visible = ValueNotifier<bool>(true);

  void show() => visible.value = true;
  void hide() => visible.value = false;
  void toggle() => visible.value = !visible.value;
}
