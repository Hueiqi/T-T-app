import 'package:flutter/material.dart';
import 'dart:math';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../models/notification_settings_model.dart';
import '../models/notification_log_model.dart';

class NotificationProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final NotificationService _notificationService = NotificationService();

  NotificationSettings? _settings;
  List<NotificationLog> _history = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  NotificationSettings? get settings => _settings;
  List<NotificationLog> get history => _history;
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

  Future<void> loadSettings(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _settings = await _firebaseService.getNotificationSettings(userId);
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadHistory(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _history = await _firebaseService.getNotificationHistory(userId);
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> saveSettings(NotificationSettings newSettings) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await _firebaseService.saveNotificationSettings(newSettings);

      await _notificationService.initialize();
      await _notificationService.scheduleAllNotifications(newSettings);

      _settings = newSettings;
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to save settings. Please try again.';
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logSentNotification(String userId, String title, String body) async {
    final log = NotificationLog(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
      userId: userId,
      title: title,
      body: body,
      sentAt: DateTime.now(),
    );
    try {
      await _firebaseService.logSentNotification(log);
      _history.insert(0, log);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markTapped(String userId, String logId) async {
    try {
      await _firebaseService.markNotificationTapped(userId, logId);
      final idx = _history.indexWhere((l) => l.id == logId);
      if (idx != -1) {
        _history[idx] = _history[idx].copyWith(tapped: true, tappedAt: DateTime.now().toIso8601String());
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> clearHistory(String userId) async {
    try {
      await _firebaseService.clearNotificationHistory(userId);
      _history.clear();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> removeFromHistory(String userId, String logId) async {
    try {
      await _firebaseService.markNotificationTapped(userId, logId);
      _history.removeWhere((l) => l.id == logId);
      notifyListeners();
    } catch (_) {}
  }
}
