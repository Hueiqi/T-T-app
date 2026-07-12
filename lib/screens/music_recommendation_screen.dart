import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/health_provider.dart';
import '../providers/music_provider.dart';
import '../providers/auth_provider.dart';
import '../services/music_recommendation_service.dart';
import '../config/theme.dart';
import '../widgets/custom_header.dart';

class MusicRecommendationScreen extends StatefulWidget {
  const MusicRecommendationScreen({super.key});

  @override
  State<MusicRecommendationScreen> createState() =>
      _MusicRecommendationScreenState();
}

class _MusicRecommendationScreenState extends State<MusicRecommendationScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecommendations();
    });
  }

  Future<void> _loadRecommendations() async {
    final health = context.read<HealthProvider>();

    // Update heart rate if available
    await health.updateHeartRate();

    // Load recommendations based on current heart rate
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadPlaylistForRecommendation(String query) async {
    final music = context.read<MusicProvider>();
    setState(() => _isLoading = true);

    try {
      await music.search(query);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load tracks: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthProvider>();
    final music = context.watch<MusicProvider>();
    final auth = context.watch<AuthProvider>();

    final recommendation =
        MusicRecommendationService.getRecommendationByHeartRate(
          health.currentHeartRate,
          auth.user?.fitnessGoal ?? 'general_fitness',
        );

    final zoneColor = MusicRecommendationService.getZoneColor(
      recommendation['zone'] as String,
    );
    final zoneEmoji = MusicRecommendationService.getZoneEmoji(
      recommendation['zone'] as String,
    );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomHeader(title: 'Music Recommendations', showBack: true),
            // Heart Rate Card
            Card(
              elevation: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: Color(int.parse(zoneColor.replaceFirst('#', '0xff'))),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(zoneEmoji, style: const TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text(
                      '${health.currentHeartRate} BPM',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recommendation['zone'] as String,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _HeartRateStat(
                          label: 'Average',
                          value: '${health.averageHeartRate}',
                        ),
                        _HeartRateStat(
                          label: 'Min',
                          value: health.heartRateHistory.isEmpty
                              ? 'N/A'
                              : '${health.heartRateHistory.reduce((a, b) => a < b ? a : b)}',
                        ),
                        _HeartRateStat(
                          label: 'Max',
                          value: health.heartRateHistory.isEmpty
                              ? 'N/A'
                              : '${health.heartRateHistory.reduce((a, b) => a > b ? a : b)}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Recommendation Text
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommendation',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      recommendation['recommendations'] as String,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      MusicRecommendationService.getDetailedRecommendation(
                        health.currentHeartRate,
                        recommendation['zone'] as String,
                        auth.user?.fitnessGoal ?? 'general_fitness',
                      ),
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Suggested Genres
            Text(
              'Recommended Genres',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (recommendation['genres'] as List<String>)
                  .map(
                    (genre) => ActionChip(
                      onPressed: () => _loadPlaylistForRecommendation(genre),
                      label: Text(genre),
                      avatar: Icon(
                        Icons.music_note,
                        size: 18,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),

            // Loading or Tracks List
            if (_isLoading)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Loading music recommendations...'),
                  ],
                ),
              )
            else if (music.searchResults.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Now Playing',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: music.searchResults.length,
                    itemBuilder: (context, index) {
                      final track = music.searchResults[index];
                      return Card(
                        child: ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.music_note,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          title: Text(track.name),
                          subtitle: Text(track.artist),
                          trailing: IconButton(
                            icon: Icon(
                              music.currentTrack?.id == track.id
                                  ? Icons.pause_circle
                                  : Icons.play_circle,
                              color: AppTheme.primaryColor,
                            ),
                            onPressed: () {
                              if (music.currentTrack?.id == track.id) {
                                music.togglePlayback();
                              } else {
                                music.playTrack(track);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            const SizedBox(height: 24),

            // Control Buttons
            if (!health.isMonitoring)
              ElevatedButton.icon(
                onPressed: () => health.startMonitoring(),
                icon: const Icon(Icons.favorite),
                label: const Text('Start Heart Rate Monitoring'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () => health.stopMonitoring(),
                icon: const Icon(Icons.stop_circle),
                label: const Text('Stop Monitoring'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: Colors.red,
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }
}

class _HeartRateStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeartRateStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }
}
