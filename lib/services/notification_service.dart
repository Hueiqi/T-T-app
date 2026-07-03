import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/notification_settings_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const String _channelId = 'fit_sync_notifications';
  static const String _channelName = 'Reminders & Alerts';
  static const String _channelDescription = 'Fitness reminders and calorie alerts';

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      _onTapCallback?.call(response.payload!);
    }
  }

  void Function(String)? _onTapCallback;

  void setOnTapCallback(void Function(String payload) callback) {
    _onTapCallback = callback;
  }

  Future<void> scheduleAllNotifications(NotificationSettings settings) async {
    await cancelAllNotifications();

    if (!_initialized) await initialize();

    final now = DateTime.now();

    if (settings.workoutReminderEnabled) {
      await _scheduleDaily(
        id: _nextId(),
        type: 'workout_reminder',
        title: 'Workout Reminder',
        body: "You haven't worked out yet today. Time to get moving!",
        time: settings.workoutReminderTime,
        now: now,
      );
    }

    if (settings.calorieAlertEnabled) {
      await _scheduleDaily(
        id: _nextId(),
        type: 'calorie_alert',
        title: 'Calorie Alert',
        body: 'Check your daily calorie balance and stay on track!',
        time: settings.calorieAlertTime,
        now: now,
      );
    }

    if (settings.sleepReminderEnabled) {
      await _scheduleDaily(
        id: _nextId(),
        type: 'sleep_reminder',
        title: 'Sleep Reminder',
        body: 'Time to wind down and get some rest. Consistency is key!',
        time: settings.sleepReminderTime,
        now: now,
      );
    }

    if (settings.logReminderEnabled) {
      await _scheduleDaily(
        id: _nextId(),
        type: 'log_reminder_lunch',
        title: 'Log Reminder',
        body: 'Don\'t forget to log your meals! You\'re doing great.',
        time: settings.logReminderLunchTime,
        now: now,
      );
      await _scheduleDaily(
        id: _nextId(),
        type: 'log_reminder_dinner',
        title: 'Log Reminder',
        body: 'Have you logged all your meals today? Stay consistent!',
        time: settings.logReminderDinnerTime,
        now: now,
      );
    }
  }

  Future<void> _scheduleDaily({
    required int id,
    required String type,
    required String title,
    required String body,
    required TimeOfDay time,
    required DateTime now,
  }) async {
    final location = tz.local;
    final scheduledDate = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    final scheduleDate = scheduledDate.isAfter(tz.TZDateTime.from(now, location))
        ? scheduledDate
        : scheduledDate.add(const Duration(days: 1));

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = '$type|${scheduleDate.toIso8601String()}';

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduleDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  int _idCounter = 1000;
  int _nextId() {
    _idCounter++;
    return _idCounter;
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }
}
