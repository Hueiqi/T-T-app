import 'package:flutter/material.dart';
import '../config/theme.dart';

/// A swipeable, page-by-page walkthrough of what each part of the app does.
/// Content lives here as plain data (_GuideSection / _GuideItem) rather than
/// scattered across screens, so it stays accurate without needing a
/// screenshot or a live tour.
///
/// Each item answers two questions in as few words as possible: what the
/// feature does, and where to tap to get to it.
class UserGuideScreen extends StatefulWidget {
  const UserGuideScreen({super.key});

  @override
  State<UserGuideScreen> createState() => _UserGuideScreenState();
}

class _UserGuideScreenState extends State<UserGuideScreen> {
  final _pageController = PageController();
  int _page = 0;

  static final List<_GuideSection> _sections = [
    _GuideSection(
      icon: Icons.waving_hand,
      color: AppTheme.primaryColor,
      title: 'Start here',
      subtitle: 'The app in 30 seconds',
      items: [
        _GuideItem(
          'Five tabs at the bottom',
          'Home shows today. Planning makes your plan. Workout tracks '
              'training. Diet logs food. Profile holds settings.',
        ),
        _GuideItem(
          'The + button logs anything',
          'Meals, workouts, weight and history are all behind it.',
          where: 'Any main page → +',
        ),
        _GuideItem(
          'Do these three first',
          '1. Finish your profile.  2. Generate a plan.  3. Connect Health '
              'Connect and Spotify.',
          where: 'Profile',
        ),
      ],
    ),
    _GuideSection(
      icon: Icons.dashboard,
      color: AppTheme.primaryColor,
      title: 'Home',
      subtitle: 'Everything about today',
      items: [
        _GuideItem(
          "Today's Overview",
          'Your steps, calories eaten and sleep, all on one screen.',
          where: 'Opens when you start the app',
        ),
        _GuideItem(
          'Heart rate gauge',
          'Your current heart rate, coloured by zone.',
          where: 'Home → top of screen',
        ),
        _GuideItem(
          'Sleep summary',
          'Last night\'s sleep, and the workout intensity suggested for '
              'today because of it.',
          where: 'Home → Sleep card',
        ),
        _GuideItem(
          'AI Assistant',
          'Ask any fitness or food question and get an answer.',
          where: 'Home → ✨ icon',
        ),
      ],
    ),
    _GuideSection(
      icon: Icons.auto_awesome,
      color: Color(0xFF8B5CF6),
      title: 'Planning',
      subtitle: 'Your long-term plan',
      items: [
        _GuideItem(
          'Make an AI plan',
          'Builds a plan around your goal, body and diet: what to eat, what '
              'to train, and for how long.',
          where: 'Planning → pick a plan',
        ),
        _GuideItem(
          "Today's schedule",
          'What to do today, hour by hour. Rest days appear on their own.',
          where: 'Planning → main screen',
        ),
        _GuideItem(
          'Exercise Library',
          'Look up any exercise by muscle group or equipment.',
          where: 'Planning → Exercise Library',
        ),
        _GuideItem(
          'Activity History',
          'Every routine you have finished.',
          where: 'Planning → history icon',
        ),
      ],
    ),
    _GuideSection(
      icon: Icons.fitness_center,
      color: AppTheme.primaryColor,
      title: 'Workout',
      subtitle: 'Train and track',
      items: [
        _GuideItem(
          'Pick your status first',
          'Chill, Slow Run or Sprint Run. This also decides which playlist '
              'plays.',
          where: 'Workout → three buttons at top',
        ),
        _GuideItem(
          'Start Workout',
          'Starts the timer, heart rate, GPS map and your music together.',
          where: 'Workout → Start Workout',
        ),
        _GuideItem(
          'While training',
          'Time, heart rate with zone, distance, steps and your route on a '
              'map.',
        ),
        _GuideItem(
          'Change the music',
          'Switch status mid-workout to change to a different playlist.',
          where: 'During workout → Choose Status',
        ),
        _GuideItem(
          'Workout Playlist',
          'Choose which of your Spotify playlists belongs to each status.',
          where: 'Workout → ♫ icon',
        ),
        _GuideItem(
          'Workout History',
          'Past sessions with calories, heart rate and route map.',
          where: 'Workout → 🕐 icon',
        ),
      ],
    ),
    _GuideSection(
      icon: Icons.restaurant,
      color: Color(0xFFEC4899),
      title: 'Diet',
      subtitle: 'Log what you eat',
      items: [
        _GuideItem(
          'Three ways to log a meal',
          'Photograph it, type it in, or find it in the Food Library.',
          where: 'Diet → + button',
        ),
        _GuideItem(
          'Scan Food',
          'Point the camera at a meal and the nutrition fills in for you.',
          where: '+ → Scan Food',
        ),
        _GuideItem(
          'Food Library',
          'My Foods is what you saved, Meals is what you logged before, '
              'Online searches packaged products by name.',
          where: '+ → Food Library',
        ),
        _GuideItem(
          'See another day',
          'Slide the date strip to view or fix earlier meals.',
          where: 'Diet → date strip',
        ),
      ],
    ),
    _GuideSection(
      icon: Icons.bedtime,
      color: Color(0xFF3F51B5),
      title: 'Sleep',
      subtitle: 'Rest and readiness',
      items: [
        _GuideItem(
          'Last night',
          'Hours slept, deep sleep, and a readiness score the app uses to '
              'suggest how hard to train.',
          where: '+ → Sleep History',
        ),
        _GuideItem(
          '7-Day Overview',
          'A bar for each of the last seven nights, coloured by how healthy '
              'that night was.',
        ),
        _GuideItem(
          'Add sleep yourself',
          'No watch? Type in how long you slept.',
          where: 'Sleep → + icon',
        ),
      ],
    ),
    _GuideSection(
      icon: Icons.person,
      color: Color(0xFF7C3AED),
      title: 'Profile',
      subtitle: 'Settings and reports',
      items: [
        _GuideItem(
          'Body Statistics',
          'Weight, workouts, nutrition and sleep over time. Switch between '
              'day, month and year.',
          where: 'Profile → Statistics',
        ),
        _GuideItem(
          'Health Connect',
          'Link your watch or band so steps, heart rate and sleep are real '
              'instead of simulated. Android only.',
          where: 'Profile → Health Connect',
        ),
        _GuideItem(
          'Spotify Library',
          'Log in to Spotify and browse your playlists.',
          where: 'Profile → Spotify Library',
        ),
        _GuideItem(
          'Notification Settings',
          'Choose which reminders you get, and set the time for each.',
          where: 'Profile → Notification Settings',
        ),
      ],
    ),
    _GuideSection(
      icon: Icons.lightbulb_outline,
      color: AppTheme.warningColor,
      title: 'Good to know',
      subtitle: 'Before you rely on the numbers',
      items: [
        _GuideItem(
          'Your heart rate is simulated',
          'Your phone has no heart-rate sensor. Unless a watch or chest '
              'strap is linked, the app makes the number up. A "Simulated" '
              'note appears under the gauge — do not treat it as a real '
              'health reading.',
        ),
        _GuideItem(
          'Why that still matters',
          'Heart rate decides your training zone, your calories burned, and '
              'the music that adapts as you train. Simulating it keeps all '
              'three working, so a workout is never left with a blank gauge, '
              'zero calories and silence. Connect a real device when you '
              'need the numbers to be accurate.',
        ),
        _GuideItem(
          'GPS only works outdoors',
          'Distance and the route map stay empty indoors or standing still. '
              'That is correct, not a fault.',
        ),
        _GuideItem(
          'Music needs Spotify login',
          'Playlists and playback only work after you sign in to Spotify.',
          where: 'Profile → Spotify Library',
        ),
      ],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _sections.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Guide'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _sections.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, index) =>
                  _SectionPage(section: _sections[index]),
            ),
          ),
          _PageIndicator(count: _sections.length, current: _page),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Row(
              children: [
                if (_page > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _goTo(_page - 1),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                if (_page > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed:
                        isLast ? () => Navigator.pop(context) : () => _goTo(_page + 1),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(isLast ? 'Done' : 'Next'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideSection {
  final IconData icon;
  final Color color;
  final String title;

  /// One line under the section title saying what the whole section is for.
  final String subtitle;
  final List<_GuideItem> items;

  const _GuideSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.items,
  });
}

class _GuideItem {
  final String title;

  /// What the feature does, in plain words.
  final String description;

  /// Where to tap to reach it, e.g. "Workout → ♫ icon". Omitted for items
  /// that are not a place you navigate to.
  final String? where;

  const _GuideItem(this.title, this.description, {this.where});
}

class _SectionPage extends StatelessWidget {
  final _GuideSection section;

  const _SectionPage({required this.section});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: section.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(section.icon, color: section.color, size: 34),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              section.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              section.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          for (final item in section.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.description,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppTheme.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    if (item.where != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: section.color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app,
                                size: 13, color: section.color),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                item.where!,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: section.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final int count;
  final int current;

  const _PageIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active
                ? AppTheme.primaryColor
                : AppTheme.primaryColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
