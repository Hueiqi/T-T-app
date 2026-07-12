import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../models/notification_settings_model.dart';
import '../config/theme.dart';
import '../widgets/custom_header.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final Map<String, dynamic> _formState = {
    'workoutReminderEnabled': false,
    'workoutReminderTime': const TimeOfDay(hour: 7, minute: 0),
    'calorieAlertEnabled': false,
    'calorieAlertTime': const TimeOfDay(hour: 20, minute: 0),
    'sleepReminderEnabled': false,
    'sleepReminderTime': const TimeOfDay(hour: 22, minute: 0),
    'logReminderEnabled': false,
    'logReminderLunchTime': const TimeOfDay(hour: 13, minute: 0),
    'logReminderDinnerTime': const TimeOfDay(hour: 20, minute: 0),
  };

  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loadExistingSettings();
      _loaded = true;
    }
  }

  void _loadExistingSettings() {
    final provider = context.read<NotificationProvider>();
    final s = provider.settings;
    if (s != null) {
      _formState['workoutReminderEnabled'] = s.workoutReminderEnabled;
      _formState['workoutReminderTime'] = s.workoutReminderTime;
      _formState['calorieAlertEnabled'] = s.calorieAlertEnabled;
      _formState['calorieAlertTime'] = s.calorieAlertTime;
      _formState['sleepReminderEnabled'] = s.sleepReminderEnabled;
      _formState['sleepReminderTime'] = s.sleepReminderTime;
      _formState['logReminderEnabled'] = s.logReminderEnabled;
      _formState['logReminderLunchTime'] = s.logReminderLunchTime;
      _formState['logReminderDinnerTime'] = s.logReminderDinnerTime;
    }
  }

  Future<void> _pickTime(String key) async {
    final current = _formState[key] as TimeOfDay;
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
    );
    if (picked != null) {
      setState(() {
        _formState[key] = picked;
      });
    }
  }

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;

    final settings = NotificationSettings(
      userId: auth.user!.uid,
      workoutReminderEnabled: _formState['workoutReminderEnabled'] as bool,
      workoutReminderTime: _formState['workoutReminderTime'] as TimeOfDay,
      calorieAlertEnabled: _formState['calorieAlertEnabled'] as bool,
      calorieAlertTime: _formState['calorieAlertTime'] as TimeOfDay,
      sleepReminderEnabled: _formState['sleepReminderEnabled'] as bool,
      sleepReminderTime: _formState['sleepReminderTime'] as TimeOfDay,
      logReminderEnabled: _formState['logReminderEnabled'] as bool,
      logReminderLunchTime: _formState['logReminderLunchTime'] as TimeOfDay,
      logReminderDinnerTime: _formState['logReminderDinnerTime'] as TimeOfDay,
    );

    final provider = context.read<NotificationProvider>();
    final success = await provider.saveSettings(settings);

    if (!mounted) return;

    if (success) {
      if (!settings.workoutReminderEnabled &&
          !settings.calorieAlertEnabled &&
          !settings.sleepReminderEnabled &&
          !settings.logReminderEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications disabled.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification settings saved.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to save settings.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
        children: [
          CustomHeader(title: 'Notification Settings', showBack: true),
          Expanded(
            child: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTypeCard(
                  icon: Icons.fitness_center,
                  iconColor: AppTheme.successColor,
                  title: 'Workout Reminder',
                  subtitle: 'Remind to work out if none logged today',
                  enabledKey: 'workoutReminderEnabled',
                  timeKey: 'workoutReminderTime',
                ),
                const SizedBox(height: 12),
                _buildTypeCard(
                  icon: Icons.local_fire_department,
                  iconColor: AppTheme.warningColor,
                  title: 'Calorie Alert',
                  subtitle: 'Alert when calorie balance is off track',
                  enabledKey: 'calorieAlertEnabled',
                  timeKey: 'calorieAlertTime',
                ),
                const SizedBox(height: 12),
                _buildTypeCard(
                  icon: Icons.bedtime,
                  iconColor: AppTheme.primaryColor,
                  title: 'Sleep Reminder',
                  subtitle: 'Bedtime reminder for consistent sleep',
                  enabledKey: 'sleepReminderEnabled',
                  timeKey: 'sleepReminderTime',
                ),
                const SizedBox(height: 12),
                _buildLogReminderCard(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: provider.isSaving ? null : _save,
                    icon: provider.isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(provider.isSaving ? 'Saving...' : 'Save Settings'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: AppTheme.warningColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Please allow background activity for notifications to work reliably.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
        ),
      ],
      ),
      ),
    );
  }

  Widget _buildTypeCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String enabledKey,
    required String timeKey,
  }) {
    final enabled = _formState[enabledKey] as bool;
    final time = _formState[timeKey] as TimeOfDay;
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      Text(subtitle,
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.5),
                  activeThumbColor: AppTheme.primaryColor,
                  onChanged: (v) {
                    setState(() {
                      _formState[enabledKey] = v;
                    });
                  },
                ),
              ],
            ),
            if (enabled) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _pickTime(timeKey),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 18, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text('Reminder time: ',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                      Text(timeStr,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const Spacer(),
                      const Icon(Icons.edit,
                          size: 16, color: AppTheme.primaryColor),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogReminderCard() {
    final enabled = _formState['logReminderEnabled'] as bool;
    final lunchTime = _formState['logReminderLunchTime'] as TimeOfDay;
    final dinnerTime = _formState['logReminderDinnerTime'] as TimeOfDay;
    final lunchStr =
        '${lunchTime.hour.toString().padLeft(2, '0')}:${lunchTime.minute.toString().padLeft(2, '0')}';
    final dinnerStr =
        '${dinnerTime.hour.toString().padLeft(2, '0')}:${dinnerTime.minute.toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.restaurant_menu,
                    color: AppTheme.accentColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Log Reminder',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      Text('Remind to log meals if fewer than 3 logged',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.5),
                  activeThumbColor: AppTheme.primaryColor,
                  onChanged: (v) {
                    setState(() {
                      _formState['logReminderEnabled'] = v;
                    });
                  },
                ),
              ],
            ),
            if (enabled) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _pickTime('logReminderLunchTime'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wb_sunny,
                          size: 18, color: AppTheme.accentColor),
                      const SizedBox(width: 8),
                      Text('Lunch reminder: ',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                      Text(lunchStr,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const Spacer(),
                      const Icon(Icons.edit,
                          size: 16, color: AppTheme.accentColor),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _pickTime('logReminderDinnerTime'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.nights_stay,
                          size: 18, color: AppTheme.accentColor),
                      const SizedBox(width: 8),
                      Text('Dinner reminder: ',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                      Text(dinnerStr,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const Spacer(),
                      const Icon(Icons.edit,
                          size: 16, color: AppTheme.accentColor),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
