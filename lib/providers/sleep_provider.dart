import 'package:flutter/foundation.dart';
import '../services/health_service.dart';
import '../services/firebase_service.dart';
import '../models/sleep_model.dart';

class SleepProvider extends ChangeNotifier {
  final HealthService _healthService = HealthService();
  final FirebaseService _firebaseService = FirebaseService();
  final bool _isWeb = kIsWeb;

  SleepData? _lastNightSleep;
  List<SleepData> _sleepHistory = [];
  List<SleepData> _allRecords = [];
  bool _isLoading = false;
  String? _syncMessage;
  DateTime? _selectedDate;
  SleepData? _selectedDateSleep;

  SleepData? get lastNightSleep => _lastNightSleep;
  List<SleepData> get sleepHistory => _sleepHistory;
  List<SleepData> get allRecords => _allRecords;
  bool get isLoading => _isLoading;
  String? get syncMessage => _syncMessage;
  DateTime? get selectedDate => _selectedDate;
  SleepData? get selectedDateSleep => _selectedDateSleep;

  void clearSyncMessage() {
    _syncMessage = null;
    notifyListeners();
  }

  Future<void> loadSleepData(String userId) async {
    _isLoading = true;
    _syncMessage = null;
    notifyListeners();

    _allRecords = await _firebaseService.getSleepHistory(userId);
    final now = DateTime.now();
    final last7 = now.subtract(const Duration(days: 7));
    _sleepHistory = _allRecords
        .where((r) => r.date.isAfter(last7) || r.date.isAtSameMomentAs(last7))
        .toList();

    if (!_isWeb) {
      final deviceSleep = await _healthService.getLastNightSleep(userId);
      if (deviceSleep != null) {
        final lastNightDate = deviceSleep.date;
        final existingRecords =
            await _firebaseService.getSleepRecordsForDate(userId, lastNightDate);
        final hasManualEntry =
            existingRecords.any((r) => r.source == 'manual');

        if (hasManualEntry) {
          _syncMessage = 'Manual data preserved. To replace, delete manual entry first.';
          _lastNightSleep = existingRecords.firstWhere((r) => r.source == 'manual');
        } else {
          await _firebaseService.saveSleepData(deviceSleep);
          _lastNightSleep = deviceSleep;
          _allRecords = await _firebaseService.getSleepHistory(userId);
          final last7b = now.subtract(const Duration(days: 7));
          _sleepHistory = _allRecords
              .where((r) => r.date.isAfter(last7b) || r.date.isAtSameMomentAs(last7b))
              .toList();
        }
      } else {
        _lastNightSleep = _allRecords.isNotEmpty ? _allRecords.first : null;
      }
    } else {
      _lastNightSleep = _allRecords.isNotEmpty ? _allRecords.first : null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadSleepDataForDate(String userId, DateTime date) async {
    _selectedDate = date;
    final records =
        await _firebaseService.getSleepRecordsForDate(userId, date);
    _selectedDateSleep = records.isNotEmpty ? records.first : null;
    notifyListeners();
  }

  Future<void> logManualSleep({
    required String userId,
    required DateTime date,
    required double hours,
    double deepSleepMinutes = 0,
  }) async {
    final sleepData = SleepData(
      id: 'sleep_manual_${userId}_${date.toIso8601String()}_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      date: date,
      hoursSlept: hours,
      deepSleepMinutes: deepSleepMinutes.round(),
      quality: hours >= 7
          ? 'good'
          : hours >= 5
          ? 'moderate'
          : 'poor',
      source: 'manual',
    );
    await _firebaseService.saveSleepData(sleepData);
    _allRecords.insert(0, sleepData);
    final last7 = DateTime.now().subtract(const Duration(days: 7));
    _sleepHistory = _allRecords
        .where((r) => r.date.isAfter(last7) || r.date.isAtSameMomentAs(last7))
        .toList();
    _lastNightSleep = sleepData;
    _syncMessage = null;
    notifyListeners();
  }

  SleepData? findRecordByDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    return _allRecords.cast<SleepData?>().firstWhere(
      (r) =>
          r!.date.year == startOfDay.year &&
          r.date.month == startOfDay.month &&
          r.date.day == startOfDay.day,
      orElse: () => null,
    );
  }

  Future<void> deleteSleepRecord(String userId, SleepData sleepData) async {
    await _firebaseService.deleteSleepData(userId, sleepData.id);
    _allRecords.removeWhere((r) => r.id == sleepData.id);
    _sleepHistory.removeWhere((r) => r.id == sleepData.id);
    if (_lastNightSleep?.id == sleepData.id) {
      _lastNightSleep = _allRecords.isNotEmpty ? _allRecords.first : null;
    }
    if (_selectedDateSleep?.id == sleepData.id) {
      _selectedDateSleep = null;
    }
    notifyListeners();
  }
}
