import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sleep_provider.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/sleep_model.dart';
import '../widgets/custom_header.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.user != null) {
        context.read<SleepProvider>().loadSleepData(auth.user!.uid);
      }
    });
  }

  void _showManualSleepDialog({SleepData? existing}) {
    final isEditing = existing != null;
    DateTime selectedDate = existing?.date ?? DateTime.now();
    final totalCtrl = TextEditingController(
      text: existing != null ? existing.hoursSlept.toStringAsFixed(1) : '',
    );
    final deepCtrl = TextEditingController(
      text: existing != null ? existing.deepSleepMinutes.toString() : '',
    );
    final formKey = GlobalKey<FormState>();
    String? totalError;
    String? deepError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> pickDate() async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: selectedDate,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setDialogState(() => selectedDate = picked);
            }
          }

          Future<void> handleSave() async {
            totalError = null;
            deepError = null;
            final messenger = ScaffoldMessenger.of(context);

            final totalText = totalCtrl.text.trim();
            if (totalText.isEmpty) {
              setDialogState(() => totalError = 'Please enter total sleep hours.');
              return;
            }
            final total = double.tryParse(totalText);
            if (total == null) {
              setDialogState(() => totalError = 'Please enter a valid number.');
              return;
            }
            if (total < 0 || total > 24) {
              setDialogState(() => totalError = 'Hours must be between 0 and 24.');
              return;
            }

            final deepText = deepCtrl.text.trim();
            double deep = 0;
            if (deepText.isNotEmpty) {
              final parsed = double.tryParse(deepText);
              if (parsed == null) {
                setDialogState(() => deepError = 'Please enter a valid number.');
                return;
              }
              deep = parsed;
              if (deep < 0) {
                setDialogState(() => deepError = 'Deep sleep cannot be negative.');
                return;
              }
              if (deep > total) {
                setDialogState(() => deepError = 'Deep sleep cannot be more than total sleep.');
                return;
              }
            }

            final auth = context.read<AuthProvider>();
            if (auth.user == null) return;

            final sleepProvider = context.read<SleepProvider>();

            if (!isEditing) {
              final existingRecord = sleepProvider.findRecordByDate(selectedDate);
              if (existingRecord != null) {
                final replace = await showDialog<bool>(
                  context: ctx,
                  builder: (ctx2) => AlertDialog(
                    title: const Text('Replace Record'),
                    content: const Text(
                      'A record already exists for this date. Do you want to replace it?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx2, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx2, true),
                        child: const Text('Replace'),
                      ),
                    ],
                  ),
                );
                if (replace != true) return;
                await sleepProvider.deleteSleepRecord(auth.user!.uid, existingRecord);
              }
            } else {
              await sleepProvider.deleteSleepRecord(auth.user!.uid, existing);
            }

            await sleepProvider.logManualSleep(
              userId: auth.user!.uid,
              date: selectedDate,
              hours: total,
              deepSleepMinutes: deep,
            );

            if (ctx.mounted) {
              Navigator.pop(ctx);
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Sleep data saved.'),
                  backgroundColor: AppTheme.successColor,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }

          return AlertDialog(
            title: Text(isEditing ? 'Edit Sleep' : 'Log Sleep Manually'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Date',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: pickDate,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 18, color: AppTheme.primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                              style: const TextStyle(fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: totalCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Total Sleep Hours *',
                        prefixIcon: const Icon(Icons.bedtime, size: 20),
                        errorText: totalError,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: deepCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Deep Sleep Hours',
                        prefixIcon:
                            const Icon(Icons.nightlight_round, size: 20),
                        errorText: deepError,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: handleSave,
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    final sleepProvider = context.read<SleepProvider>();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: sleepProvider.selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (picked != null) {
      if (!mounted) return;
      sleepProvider.loadSleepDataForDate(auth.user!.uid, picked);
    }
  }

  Color _sleepColor(double hours) {
    if (hours >= 7) return AppTheme.successColor;
    if (hours >= 5) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  String _readinessTip(SleepData data) {
    if (data.hoursSlept >= 7 && data.deepSleepMinutes >= 90) {
      return 'Excellent rest – ready for high intensity workout';
    } else if (data.hoursSlept >= 7) {
      return 'Well rested – good for moderate exercise';
    } else if (data.hoursSlept >= 5) {
      return 'Moderate recovery – light activity recommended';
    } else {
      return 'Low energy – rest and recover today';
    }
  }

  void _showRecordDetails(BuildContext context, SleepData record) {
    final isManual = record.source == 'manual';
    final color = _sleepColor(record.hoursSlept);
    final deepPercent = record.hoursSlept > 0
        ? (record.deepSleepMinutes / (record.hoursSlept * 60) * 100)
        : 0.0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${record.date.day}/${record.date.month}/${record.date.year}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (isManual)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, size: 14,
                              color: AppTheme.warningColor),
                          SizedBox(width: 4),
                          Text('Manual',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.warningColor,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    Text(
                      record.hoursSlept.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text('hours slept',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _DetailMetric(
                      label: 'Deep Sleep',
                      value: '${record.deepSleepMinutes}',
                      unit: 'min',
                      color: AppTheme.primaryColor),
                  _DetailMetric(
                      label: 'Deep %',
                      value: deepPercent.toStringAsFixed(0),
                      unit: '%',
                      color: AppTheme.accentColor),
                  _DetailMetric(
                      label: 'Light',
                      value: '${record.lightSleepMinutes}',
                      unit: 'min',
                      color: AppTheme.secondaryColor),
                  _DetailMetric(
                      label: 'REM',
                      value: '${record.remSleepMinutes}',
                      unit: 'min',
                      color: AppTheme.textSecondary),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tips_and_updates, color: color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _readinessTip(record),
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (isManual)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showEditSleepDialog(record);
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _confirmDelete(record);
                        },
                        icon: const Icon(Icons.delete, size: 18,
                            color: AppTheme.errorColor),
                        label: const Text('Delete',
                            style: TextStyle(color: AppTheme.errorColor)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.errorColor),
                        ),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmDelete(record);
                    },
                    icon: const Icon(Icons.delete, size: 18,
                        color: AppTheme.errorColor),
                    label: const Text('Delete Record',
                        style: TextStyle(color: AppTheme.errorColor)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.errorColor),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(SleepData record) {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record'),
        content: Text(
            'Remove sleep record for ${record.date.day}/${record.date.month}/${record.date.year}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<SleepProvider>()
                  .deleteSleepRecord(auth.user!.uid, record);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditSleepDialog(SleepData existing) {
    _showManualSleepDialog(existing: existing);
  }

  @override
  Widget build(BuildContext context) {
    final sleep = context.watch<SleepProvider>();

    return Scaffold(
      body: SafeArea(
        child: sleep.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                CustomHeader(
                  title: 'Sleep',
                  showBack: true,
                  actions: [
                    if (context.watch<AuthProvider>().user == null)
                      IconButton(
                        icon: const Icon(Icons.login, color: Colors.white),
                        tooltip: 'Login',
                        onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: _showManualSleepDialog,
                      tooltip: 'Log sleep manually',
                    ),
                  ],
                ),
                if (sleep.syncMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color: AppTheme.warningColor.withValues(alpha: 0.15),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: AppTheme.warningColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sleep.syncMessage!,
                            style: const TextStyle(
                              color: AppTheme.warningColor,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => sleep.clearSyncMessage(),
                          child: const Icon(Icons.close,
                              size: 16, color: AppTheme.warningColor),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: sleep.allRecords.isEmpty
                      ? _buildEmptyState()
                      : _buildContent(sleep),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.nightlight_round,
                size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'No sleep data yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sync your watch or manually add your sleep.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                final auth = context.read<AuthProvider>();
                if (auth.user != null) {
                  context.read<SleepProvider>().loadSleepData(auth.user!.uid);
                }
              },
              icon: const Icon(Icons.sync),
              label: const Text('Sync Now'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(SleepProvider sleep) {
    final recent7 = sleep.allRecords.take(7).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sleep.lastNightSleep != null)
            _SleepSummaryCard(
              data: sleep.lastNightSleep!,
              sleepColor: _sleepColor(sleep.lastNightSleep!.hoursSlept),
              readinessTip: _readinessTip(sleep.lastNightSleep!),
              onTap: () => _showRecordDetails(context, sleep.lastNightSleep!),
            ),
          const SizedBox(height: 20),

          if (sleep.selectedDateSleep != null) ...[
            _SelectedDateCard(
              data: sleep.selectedDateSleep!,
              date: sleep.selectedDate!,
              sleepColor: _sleepColor(sleep.selectedDateSleep!.hoursSlept),
              readinessTip: _readinessTip(sleep.selectedDateSleep!),
              onTap: () =>
                  _showRecordDetails(context, sleep.selectedDateSleep!),
            ),
            const SizedBox(height: 20),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('7-Day Overview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
              TextButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: const Text('Pick Date'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (recent7.isNotEmpty)
            _SleepBarChart(
              records: recent7,
              sleepColor: _sleepColor,
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text('No sleep data available',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ),
              ),
            ),
          const SizedBox(height: 20),

          Text('All Records',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
          const SizedBox(height: 8),

          if (sleep.allRecords.isNotEmpty)
            ...sleep.allRecords.map(
              (record) => _SleepRecordTile(
                data: record,
                sleepColor: _sleepColor(record.hoursSlept),
                readinessTip: _readinessTip(record),
                onTap: () => _showRecordDetails(context, record),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text('No records found',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SleepSummaryCard extends StatelessWidget {
  final SleepData data;
  final Color sleepColor;
  final String readinessTip;
  final VoidCallback onTap;

  const _SleepSummaryCard({
    required this.data,
    required this.sleepColor,
    required this.readinessTip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final deepPercent = data.hoursSlept > 0
        ? (data.deepSleepMinutes / (data.hoursSlept * 60) * 100)
        : 0.0;
    final isManual = data.source == 'manual';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('Last Night',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      if (isManual) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.edit,
                            size: 16, color: AppTheme.warningColor),
                      ],
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sleepColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _qualityLabel(data.quality),
                      style: TextStyle(
                        color: sleepColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    Text(
                      data.hoursSlept.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        color: sleepColor,
                      ),
                    ),
                    const Text('hours slept',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _DetailMetric(
                      label: 'Deep Sleep',
                      value: '${data.deepSleepMinutes}',
                      unit: 'min',
                      color: AppTheme.primaryColor),
                  _DetailMetric(
                      label: 'Deep %',
                      value: deepPercent.toStringAsFixed(0),
                      unit: '%',
                      color: AppTheme.accentColor),
                  _DetailMetric(
                      label: 'Light',
                      value: '${data.lightSleepMinutes}',
                      unit: 'min',
                      color: AppTheme.secondaryColor),
                  _DetailMetric(
                      label: 'REM',
                      value: '${data.remSleepMinutes}',
                      unit: 'min',
                      color: AppTheme.textSecondary),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: sleepColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tips_and_updates,
                        color: sleepColor, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        readinessTip,
                        style: TextStyle(
                          color: sleepColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _qualityLabel(String q) {
    switch (q) {
      case 'good':
        return 'Good';
      case 'moderate':
        return 'Moderate';
      case 'poor':
        return 'Poor';
      default:
        return q;
    }
  }
}

class _SelectedDateCard extends StatelessWidget {
  final SleepData data;
  final DateTime date;
  final Color sleepColor;
  final String readinessTip;
  final VoidCallback onTap;

  const _SelectedDateCard({
    required this.data,
    required this.date,
    required this.sleepColor,
    required this.readinessTip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: sleepColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: sleepColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${date.day}/${date.month}/${date.year}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${data.hoursSlept.toStringAsFixed(1)} hrs',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: sleepColor,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Deep: ${data.deepSleepMinutes}min',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      readinessTip,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SleepRecordTile extends StatelessWidget {
  final SleepData data;
  final Color sleepColor;
  final String readinessTip;
  final VoidCallback onTap;

  const _SleepRecordTile({
    required this.data,
    required this.sleepColor,
    required this.readinessTip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isManual = data.source == 'manual';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: sleepColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${data.date.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: sleepColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${data.date.day}/${data.date.month}/${data.date.year}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        if (isManual) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.edit,
                              size: 14, color: AppTheme.warningColor),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      readinessTip,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${data.hoursSlept.toStringAsFixed(1)} h',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: sleepColor,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Deep: ${data.deepSleepMinutes}min',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  size: 18, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _DetailMetric({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        Text(unit,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _SleepBarChart extends StatelessWidget {
  final List<SleepData> records;
  final Color Function(double hours) sleepColor;

  const _SleepBarChart({
    required this.records,
    required this.sleepColor,
  });

  @override
  Widget build(BuildContext context) {
    final reversed = records.reversed.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 2,
                getDrawingHorizontalLine: (value) =>
                    FlLine(color: Colors.grey.withValues(alpha: 0.2), strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) => Text(
                      '${value.toInt()}h',
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.textSecondary),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < reversed.length) {
                        final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                        return Text(
                          days[reversed[idx].date.weekday - 1],
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.textSecondary),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              minY: 0,
              maxY: 12,
              barGroups: reversed
                  .asMap()
                  .entries
                  .map((e) => BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: e.value.hoursSlept,
                            color: sleepColor(e.value.hoursSlept),
                            width: 20,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}
