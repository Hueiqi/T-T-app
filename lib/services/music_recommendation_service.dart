class MusicRecommendationService {
  /// Get music recommendations based on current heart rate
  /// BPM (beats per minute) recommendations based on heart rate zones
  static Map<String, dynamic> getRecommendationByHeartRate(
    int currentHeartRate,
    String fitnessGoal,
  ) {
    String zone;
    String recommendations;
    int targetBpm;
    List<String> genres;

    if (currentHeartRate < 60) {
      // Resting - Relaxation music
      zone = 'Resting';
      targetBpm = 60; // Slow tempo for relaxation
      recommendations =
          'Your heart rate is low. Listen to calm, ambient music to relax.';
      genres = ['ambient', 'chill', 'lo-fi', 'sleep'];
    } else if (currentHeartRate < 100) {
      // Light activity - Steady workout
      zone = 'Light Activity';
      targetBpm = 90; // Moderate tempo
      recommendations = 'Light activity detected. Perfect for steady cardio.';
      genres = ['pop', 'indie', 'alternative', 'electronic'];
    } else if (currentHeartRate < 130) {
      // Moderate intensity - Workout music
      zone = 'Moderate Intensity';
      targetBpm = 120; // Upbeat tempo
      recommendations =
          'You\'re in the moderate zone. Keep pushing with upbeat tracks!';
      genres = ['electronic', 'hip-hop', 'edm', 'dance-pop', 'rock'];
    } else if (currentHeartRate < 160) {
      // Vigorous intensity - High energy
      zone = 'Vigorous Intensity';
      targetBpm = 140; // High energy tempo
      recommendations = 'Vigorous effort! Time for high-energy tracks.';
      genres = ['edm', 'hardcore', 'drum-and-bass', 'trap', 'metal'];
    } else {
      // Maximum effort - Peak performance
      zone = 'Maximum Effort';
      targetBpm = 160; // Very fast tempo
      recommendations =
          'Maximum effort detected! Push harder with peak tracks.';
      genres = ['hardcore', 'psytrance', 'drum-and-bass', 'dubstep'];
    }

    // Adjust based on fitness goal
    if (fitnessGoal.contains('weight_loss')) {
      if (targetBpm < 130) {
        targetBpm += 10; // Push slightly higher for cardio
      }
    } else if (fitnessGoal.contains('muscle_gain')) {
      if (targetBpm > 90) {
        targetBpm -= 5; // Slightly slower for strength
      }
    }

    return {
      'zone': zone,
      'targetBpm': targetBpm,
      'recommendations': recommendations,
      'genres': genres,
      'heartRate': currentHeartRate,
    };
  }

  /// Search queries for music recommendations
  static List<String> getSearchQueries(
    int currentHeartRate,
    List<String> genres,
  ) {
    List<String> queries = [];

    // Add genre-based searches
    for (final genre in genres) {
      queries.add(genre);
      queries.add('$genre workout');
      queries.add('$genre energy');
    }

    // Add tempo-based searches
    if (currentHeartRate < 60) {
      queries.addAll([
        'relaxing',
        'calm',
        'chill vibes',
        'meditation',
        'sleep music',
      ]);
    } else if (currentHeartRate < 100) {
      queries.addAll([
        'feel good',
        'uplifting',
        'steady beat',
        'workout playlist',
      ]);
    } else if (currentHeartRate < 130) {
      queries.addAll(['pump up', 'motivational', 'high energy', 'cardio']);
    } else {
      queries.addAll(['intense', 'extreme', 'peak performance', 'max effort']);
    }

    return queries;
  }

  /// Get emoji/icon representation of heart rate zone
  static String getZoneEmoji(String zone) {
    switch (zone.toLowerCase()) {
      case 'resting':
        return '😴'; // Sleep
      case 'light activity':
        return '🚶'; // Walking
      case 'moderate intensity':
        return '🏃'; // Running
      case 'vigorous intensity':
        return '💨'; // Lightning
      case 'maximum effort':
        return '🔥'; // Fire
      default:
        return '❤️';
    }
  }

  /// Get color code for heart rate zone (for UI)
  static String getZoneColor(String zone) {
    switch (zone.toLowerCase()) {
      case 'resting':
        return '#4CAF50'; // Green - Rest
      case 'light activity':
        return '#FFC107'; // Amber - Light
      case 'moderate intensity':
        return '#FF9800'; // Orange - Moderate
      case 'vigorous intensity':
        return '#FF5722'; // Deep Orange - Vigorous
      case 'maximum effort':
        return '#F44336'; // Red - Max
      default:
        return '#2196F3';
    }
  }

  /// Get detailed recommendations for user
  static String getDetailedRecommendation(
    int currentHeartRate,
    String zone,
    String fitnessGoal,
  ) {
    final baseRecommendation = _getBaseRecommendation(zone);

    // Add personalized recommendation based on goal
    String goalSpecificAdvice = '';
    if (fitnessGoal.toLowerCase().contains('weight_loss')) {
      goalSpecificAdvice =
          'For weight loss, maintain this intensity for at least 20-30 minutes.';
    } else if (fitnessGoal.toLowerCase().contains('muscle_gain')) {
      goalSpecificAdvice =
          'For muscle building, focus on high-intensity intervals with recovery.';
    } else if (fitnessGoal.toLowerCase().contains('lean_gain')) {
      goalSpecificAdvice =
          'For lean gains, balance cardio with strength training.';
    }

    return '$baseRecommendation\n\n$goalSpecificAdvice';
  }

  static String _getBaseRecommendation(String zone) {
    switch (zone.toLowerCase()) {
      case 'resting':
        return 'Your heart rate is at rest level. Enjoy calming music to relax and recover. This is great for meditation or sleep preparation.';
      case 'light activity':
        return 'You\'re in the light activity zone. Good for warm-ups or recovery days. Music with steady, moderate tempo works best.';
      case 'moderate intensity':
        return 'You\'re working at moderate intensity. This is the sweet spot for fat burning and aerobic conditioning. Keep it up!';
      case 'vigorous intensity':
        return 'You\'re in vigorous intensity zone. Excellent effort for cardiovascular improvements. Stay hydrated and keep pushing!';
      case 'maximum effort':
        return 'You\'re at maximum effort! This is peak performance zone. Be careful not to overdo it. Consider cool-down after intense effort.';
      default:
        return 'Keep up the great work!';
    }
  }
}
