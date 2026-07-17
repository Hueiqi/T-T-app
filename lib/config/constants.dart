import 'api_keys.dart';

class AppConstants {
  static const String appName = 'T&T Fitness';
  static const String appVersion = '1.0.0';

  static const String baseUrl = 'https://api.tandt.ai/v1';

  // ---- Configurable HR zone thresholds ----
  // User can modify these in profile settings
  static int warmUpHrMax = 100;
  static int fatBurnHrMax = 120;
  static int cardioHrMax = 140;
  // Anything above cardioHrMax is Peak

  static const int sleepHoursRecommended = 7;

  static const List<String> hrZones = [
    'Warm up',
    'Fat Burn',
    'Cardio',
    'Peak',
  ];

  // ---- BPM formula ----
  // targetBPM = currentHR * bpmFactor, capped between bpmMin and bpmMax
  static double bpmFactor = 0.6;
  static int bpmMin = 60;
  static int bpmMax = 150;

  /// Calculate target music BPM from heart rate
  static int calculateTargetBpm(int heartRate) {
    final raw = (heartRate * bpmFactor).round();
    return raw.clamp(bpmMin, bpmMax);
  }

  /// Determine HR zone name from heart rate
  static String getHrZone(int heartRate) {
    if (heartRate < warmUpHrMax) return 'Warm up';
    if (heartRate < fatBurnHrMax) return 'Fat Burn';
    if (heartRate < cardioHrMax) return 'Cardio';
    return 'Peak';
  }

  static const String geminiApiKey = ApiKeys.gemini;

  static const List<String> musicGenres = [
    'Pop',
    'Rock',
    'Electronic',
    'Hip Hop',
    'R&B',
    'Jazz',
    'Classical',
    'Lo-fi',
  ];
}
