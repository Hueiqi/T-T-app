import 'package:flutter/material.dart';

class NotificationSettings {
  final String userId;
  final bool workoutReminderEnabled;
  final TimeOfDay workoutReminderTime;
  final bool calorieAlertEnabled;
  final TimeOfDay calorieAlertTime;
  final bool sleepReminderEnabled;
  final TimeOfDay sleepReminderTime;
  final bool logReminderEnabled;
  final TimeOfDay logReminderLunchTime;
  final TimeOfDay logReminderDinnerTime;

  const NotificationSettings({
    required this.userId,
    this.workoutReminderEnabled = false,
    this.workoutReminderTime = const TimeOfDay(hour: 7, minute: 0),
    this.calorieAlertEnabled = false,
    this.calorieAlertTime = const TimeOfDay(hour: 20, minute: 0),
    this.sleepReminderEnabled = false,
    this.sleepReminderTime = const TimeOfDay(hour: 22, minute: 0),
    this.logReminderEnabled = false,
    this.logReminderLunchTime = const TimeOfDay(hour: 13, minute: 0),
    this.logReminderDinnerTime = const TimeOfDay(hour: 20, minute: 0),
  });

  NotificationSettings copyWith({
    String? userId,
    bool? workoutReminderEnabled,
    TimeOfDay? workoutReminderTime,
    bool? calorieAlertEnabled,
    TimeOfDay? calorieAlertTime,
    bool? sleepReminderEnabled,
    TimeOfDay? sleepReminderTime,
    bool? logReminderEnabled,
    TimeOfDay? logReminderLunchTime,
    TimeOfDay? logReminderDinnerTime,
  }) {
    return NotificationSettings(
      userId: userId ?? this.userId,
      workoutReminderEnabled: workoutReminderEnabled ?? this.workoutReminderEnabled,
      workoutReminderTime: workoutReminderTime ?? this.workoutReminderTime,
      calorieAlertEnabled: calorieAlertEnabled ?? this.calorieAlertEnabled,
      calorieAlertTime: calorieAlertTime ?? this.calorieAlertTime,
      sleepReminderEnabled: sleepReminderEnabled ?? this.sleepReminderEnabled,
      sleepReminderTime: sleepReminderTime ?? this.sleepReminderTime,
      logReminderEnabled: logReminderEnabled ?? this.logReminderEnabled,
      logReminderLunchTime: logReminderLunchTime ?? this.logReminderLunchTime,
      logReminderDinnerTime: logReminderDinnerTime ?? this.logReminderDinnerTime,
    );
  }

  static String _timeToString(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static TimeOfDay _stringToTime(String value) {
    final parts = value.split(':');
    if (parts.length == 2) {
      return TimeOfDay(hour: int.tryParse(parts[0]) ?? 7, minute: int.tryParse(parts[1]) ?? 0);
    }
    return const TimeOfDay(hour: 7, minute: 0);
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'workoutReminderEnabled': workoutReminderEnabled,
      'workoutReminderTime': _timeToString(workoutReminderTime),
      'calorieAlertEnabled': calorieAlertEnabled,
      'calorieAlertTime': _timeToString(calorieAlertTime),
      'sleepReminderEnabled': sleepReminderEnabled,
      'sleepReminderTime': _timeToString(sleepReminderTime),
      'logReminderEnabled': logReminderEnabled,
      'logReminderLunchTime': _timeToString(logReminderLunchTime),
      'logReminderDinnerTime': _timeToString(logReminderDinnerTime),
    };
  }

  factory NotificationSettings.fromMap(Map<String, dynamic> map, String userId) {
    return NotificationSettings(
      userId: userId,
      workoutReminderEnabled: map['workoutReminderEnabled'] as bool? ?? false,
      workoutReminderTime: map['workoutReminderTime'] != null
          ? _stringToTime(map['workoutReminderTime'] as String)
          : const TimeOfDay(hour: 7, minute: 0),
      calorieAlertEnabled: map['calorieAlertEnabled'] as bool? ?? false,
      calorieAlertTime: map['calorieAlertTime'] != null
          ? _stringToTime(map['calorieAlertTime'] as String)
          : const TimeOfDay(hour: 20, minute: 0),
      sleepReminderEnabled: map['sleepReminderEnabled'] as bool? ?? false,
      sleepReminderTime: map['sleepReminderTime'] != null
          ? _stringToTime(map['sleepReminderTime'] as String)
          : const TimeOfDay(hour: 22, minute: 0),
      logReminderEnabled: map['logReminderEnabled'] as bool? ?? false,
      logReminderLunchTime: map['logReminderLunchTime'] != null
          ? _stringToTime(map['logReminderLunchTime'] as String)
          : const TimeOfDay(hour: 13, minute: 0),
      logReminderDinnerTime: map['logReminderDinnerTime'] != null
          ? _stringToTime(map['logReminderDinnerTime'] as String)
          : const TimeOfDay(hour: 20, minute: 0),
    );
  }
}
