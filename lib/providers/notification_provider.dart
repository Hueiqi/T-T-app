import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../models/notification_settings_model.dart';

class NotificationProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final NotificationService _notificationService = NotificationService();

  NotificationSettings? _settings;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  NotificationSettings? get settings => _settings;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  bool get anyEnabled =>
      _settings != null &&
      (_settings!.workoutReminderEnabled ||
          _settings!.calorieAlertEnabled ||
          _settings!.sleepReminderEnabled ||
          _settings!.logReminderEnabled);

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Reminders are scheduled by the OS on this device, so the device copy is
  // the source of truth. Firestore is a sync/backup layer — if it is
  // unreachable or rejects the write, the user's chosen times must survive.
  static String _prefsKey(String userId) => 'notification_settings_$userId';

  Future<void> _saveLocal(NotificationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey(settings.userId), jsonEncode(settings.toMap()));
  }

  Future<NotificationSettings?> _loadLocal(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey(userId));
      if (raw == null) return null;
      return NotificationSettings.fromMap(
          Map<String, dynamic>.from(jsonDecode(raw) as Map), userId);
    } catch (e) {
      debugPrint('NotificationProvider: local read failed: $e');
      return null;
    }
  }

  Future<void> loadSettings(String userId) async {
    _isLoading = true;
    notifyListeners();

    final local = await _loadLocal(userId);
    if (local != null) _settings = local;

    try {
      final remote = await _firebaseService.getNotificationSettings(userId);
      // Only adopt the cloud copy when this device has none of its own;
      // otherwise a stale document would overwrite times just saved here.
      if (remote != null && local == null) {
        _settings = remote;
        await _saveLocal(remote);
      }
    } catch (e) {
      debugPrint('NotificationProvider: cloud load failed: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> saveSettings(NotificationSettings newSettings) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    // Persist and reschedule first — these are what actually make the reminder
    // fire, and must not be lost to a failed upload.
    try {
      await _saveLocal(newSettings);
      await _notificationService.initialize();
      await _notificationService.scheduleAllNotifications(newSettings);
      _settings = newSettings;
    } catch (e) {
      debugPrint('NotificationProvider: save failed: $e');
      _error = 'Failed to save settings. Please try again.';
      _isSaving = false;
      notifyListeners();
      return false;
    }

    // Best-effort cloud sync: the reminder is already saved and scheduled, so a
    // Firestore failure here must not be reported to the user as a lost save.
    try {
      await _firebaseService.saveNotificationSettings(newSettings);
    } catch (e) {
      debugPrint('NotificationProvider: cloud sync failed (kept on device): $e');
    }

    _isSaving = false;
    notifyListeners();
    return true;
  }
}
