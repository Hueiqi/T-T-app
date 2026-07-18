// Public playback API. The concrete engine is chosen at compile time:
// web uses the Web Playback SDK; mobile (dart:io) uses the native App Remote.
// FitSync is Android-only, so we export the native (mobile) engine directly.
export 'playback_engine.dart';
export 'mobile_playback_engine.dart' show createPlaybackEngine;
