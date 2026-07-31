import 'package:flutter/material.dart';
import '../config/theme.dart';

/// A swipeable, page-by-page walkthrough of what each part of the app does.
/// Content lives here as plain data (_GuideSection / _GuideItem) rather than
/// scattered across screens, so it stays accurate without needing a
/// screenshot or a live tour.
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
      icon: Icons.dashboard,
      color: AppTheme.primaryColor,
      title: 'Home',
      items: [
        _GuideItem(
          'Today\'s Overview',
          'Shows steps, calories eaten, and sleep for today at a glance. '
              'Steps and heart rate come from Health Connect once connected; '
              'otherwise heart rate is simulated so the gauge always has data.',
        ),
        _GuideItem(
          'Heart rate gauge',
          'Live reading with a colour-coded zone (resting, light, moderate, '
              'vigorous, max). Tap the Health Connect card to link a real '
              'source — without one, the value is simulated.',
        ),
        _GuideItem(
          'Quick Add (+ button)',
          'The fastest way to log something from anywhere in the app: scan '
              'or type in a meal, start a workout, log your weight, or jump to '
              'Meal / Workout / Sleep history.',
        ),
        _GuideItem(
          'AI Assistant (✨ icon)',
          'Ask fitness or nutrition questions in a chat, answered by the '
              'app\'s AI service.',
        ),
      ],
    ),
    _GuideSection(
      icon: Icons.auto_awesome,
      color: Color(0xFF8B5CF6),
      title: 'Planning',
      items: [
        _GuideItem(
          'AI fitness plans',
          'Generates plans personalised to your goal, activity level, diet '
              'preference and profile. Each plan has a daily schedule, weekly '
              'workout split, and macro targets.',
        ),
        _GuideItem(
          'Daily schedule & rest days',
          'The schedule reflects the actual day of the week: if your plan\'s '
              'weekly workout list has nothing scheduled for today, it shows '
              'as a Rest Day instead of a generic workout.',
        ),
        _GuideItem(
          'Exercise Library',
          'Browse and search exercises by muscle group or equipment, '
              'independent of any specific plan.',
        ),
        _GuideItem(
          'Activity History',
          'Every completed routine, with duration and estimated calories.',
        ),
      ],
    ),
    _GuideSection(
      icon: Icons.fitness_center,
      color: AppTheme.primaryColor,
      title: 'Workout',
      items: [
        _GuideItem(
          'Workout type',
          'Chill, Slow Run, or Sprint Run — this also decides which '
              'Workout Playlist plays if you\'ve assigned one to that mode.',
        ),
        _GuideItem(
          'Live tracking',
          'Once started: elapsed time, live heart rate (Avg/Max/Zone), '
              'distance and steps from GPS, and a map showing your route. '
              'Distance only updates once you move roughly 10 m or more — it '
              'stays at 0.00 km indoors or standing still, correctly.',
        ),
        _GuideItem(
          'Map controls',
          'Pinch to zoom, or use the +/− buttons. The ⌖ button recentres on '
              'your position and resumes auto-follow after you\'ve panned '
              'around.',
        ),
        _GuideItem(
          'Workout Playlist',
          'Assign your own Spotify playlists to each workout type (Chill / '
              'Slow Run / Sprint Run) so Play starts the right mood of music. '
              'Only playlists you created or follow appear — liked songs and '
              'algorithmic mixes like Discover Weekly are not returned by '
              'Spotify\'s API.',
        ),
        _GuideItem(
          'Workout History',
          'Past sessions with calories, heart rate, distance and — if GPS '
              'was on — the route map. Tap a session for full detail.',
        ),
      ],
    ),
    _GuideSection(
      icon: Icons.restaurant,
      color: Color(0xFFEC4899),
      title: 'Diet',
      items: [
        _GuideItem(
          'Logging a meal',
          'Three ways in via Quick Add: Scan Food (camera, auto-detects '
              'nutrition), Add Food Manually (type it in), or Food Library '
              '(search saved foods, your own meal history, or search online).',
        ),
        _GuideItem(
          'Food Library tabs',
          '"My Foods" is your saved library, "Meals" is what you\'ve already '
              'logged, and "Online" searches Open Food Facts for packaged '
              'products by name.',
        ),
        _GuideItem(
          'Daily calendar strip',
          'Jump between days to see or edit past meals. Editing recalculates '
              'that day\'s totals.',
        ),
        _GuideItem(
          'Meal History',
          'Every meal ever logged, searchable, with full nutrition detail.',
        ),
      ],
    ),
    _GuideSection(
      icon: Icons.bedtime,
      color: Color(0xFF3F51B5),
      title: 'Sleep',
      items: [
        _GuideItem(
          'Last night\'s sleep',
          'Hours slept, deep sleep minutes, and a readiness score used '
              'elsewhere in the app (e.g. workout recommendations on Home).',
        ),
        _GuideItem(
          '7-Day Overview',
          'A bar chart of the last week\'s sleep, colour-coded by how close '
              'each night was to a healthy amount.',
        ),
        _GuideItem(
          'All Records',
          'Full history of every night logged, oldest to newest.',
        ),
      ],
    ),
    _GuideSection(
      icon: Icons.person,
      color: Color(0xFF7C3AED),
      title: 'Profile',
      items: [
        _GuideItem(
          'Recent Activity',
          'Sleep, most recent workout, and today\'s calorie balance '
              '(eaten vs. burned), each tappable for more detail.',
        ),
        _GuideItem(
          'Reports & Statistics',
          'Nutrition Reports break down intake over time; Body Statistics '
              'covers weight, and toggles between day / month / year views.',
        ),
        _GuideItem(
          'Health Connect',
          'Tap to connect your device\'s health data (steps, heart rate) so '
              'Home shows real numbers instead of simulated ones. Android '
              'only — this has no equivalent on iOS.',
        ),
        _GuideItem(
          'Notification Settings',
          'Turn on/off and time reminders for workouts, meals, sleep, and '
              'weigh-ins.',
        ),
      ],
    ),
    _GuideSection(
      icon: Icons.lightbulb_outline,
      color: AppTheme.warningColor,
      title: 'Good to know',
      items: [
        _GuideItem(
          'Simulated vs. real heart rate',
          'If no smartwatch or strap is connected, heart rate is simulated '
              'so every screen that shows it always has data. A note under '
              'the gauge says "Simulated" when this is the case.',
        ),
        _GuideItem(
          'GPS needs the outdoors',
          'Distance, steps-from-GPS, and the route map all depend on a real '
              'location fix — they will not populate meaningfully indoors.',
        ),
        _GuideItem(
          'Spotify playback needs login',
          'Playlists and playback require signing in to Spotify from '
              'Profile or the Workout Playlist screen first.',
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
  final List<_GuideItem> items;

  const _GuideSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.items,
  });
}

class _GuideItem {
  final String title;
  final String description;

  const _GuideItem(this.title, this.description);
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
          const SizedBox(height: 24),
          for (final item in section.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
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
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.45,
                      ),
                    ),
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
