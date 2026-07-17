import 'package:flutter/foundation.dart';
import '../services/spotify_service.dart';
import '../models/music_track_model.dart';

class MusicProvider extends ChangeNotifier {
  final SpotifyService _spotifyService = SpotifyService();

  bool _isConnected = false;
  bool _isPlaying = false;
  MusicTrack? _currentTrack;
  List<MusicTrack> _searchResults = [];
  final List<MusicTrack> _queue = [];
  String? _error;

  bool get isConnected => _isConnected;
  bool get isPlaying => _isPlaying;
  MusicTrack? get currentTrack => _currentTrack;
  List<MusicTrack> get searchResults => _searchResults;
  List<MusicTrack> get queue => _queue;
  String? get error => _error;

  SpotifyService get spotifyService => _spotifyService;

  /// Try to restore a previously saved Spotify session (survives app restart).
  Future<bool> restoreSession() async {
    try {
      final restored = await _spotifyService.restoreSession();
      if (restored) {
        _isConnected = true;
        _error = null;
        notifyListeners();
      }
      return restored;
    } catch (e) {
      return false;
    }
  }

  Future<bool> connect() async {
    try {
      final success = await _spotifyService.authenticate();
      if (success) {
        _isConnected = true;
        _error = null;
      } else {
        _error = 'Failed to connect to Spotify';
      }
      notifyListeners();
      return success;
    } catch (e) {
      _error = 'Failed to connect to Spotify';
      notifyListeners();
      return false;
    }
  }

  Future<void> search(String query) async {
    _searchResults = await _spotifyService.searchTracks(query);
    notifyListeners();
  }

  Future<void> playTrack(MusicTrack track) async {
    try {
      await _spotifyService.playTrack(track.spotifyUri);
      _currentTrack = track;
      _isPlaying = true;
      _error = null;
      notifyListeners();
    } on SpotifyNoDeviceException catch (e) {
      _error = e.message;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to play track';
      notifyListeners();
    }
  }

  Future<void> togglePlayback() async {
    try {
      if (_isPlaying) {
        await _spotifyService.pausePlayback();
      } else {
        await _spotifyService.resumePlayback();
      }
      _isPlaying = !_isPlaying;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to toggle playback';
      notifyListeners();
    }
  }

  Future<void> queueTrack(MusicTrack track) async {
    try {
      await _spotifyService.queueTrack(track.spotifyUri);
      _queue.add(track);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to queue track';
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    await _spotifyService.disconnect();
    _isConnected = false;
    _isPlaying = false;
    _currentTrack = null;
    _queue.clear();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clear() {
    _isConnected = false;
    _isPlaying = false;
    _currentTrack = null;
    _searchResults = [];
    _queue.clear();
    _error = null;
    notifyListeners();
  }
}
