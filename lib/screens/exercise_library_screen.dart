import 'dart:math';
import 'package:flutter/material.dart';
import '../services/exercise_db.dart';
import '../models/exercise_model.dart';
import '../config/theme.dart';
import 'exercise_detail_screen.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ExerciseDb> _filtered = [];
  String _selectedMuscle = 'All';
  String _selectedLevel = 'All';
  String _selectedEquipment = 'All';
  bool _isLoading = true;

  final List<ExerciseDb> _recentlyViewed = [];
  final Set<String> _favoriteIds = {};
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args != 'All' && _selectedMuscle != args) {
      setState(() => _selectedMuscle = args);
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyFilters());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await ExerciseDatabase.load();
    setState(() {
      _filtered = ExerciseDatabase.all;
      _isLoading = false;
    });
  }

  void _applyFilters() {
    setState(() {
      _filtered = ExerciseDatabase.search(
        query: _searchController.text,
        muscle: _selectedMuscle == 'All' ? null : _selectedMuscle,
        level: _selectedLevel == 'All' ? null : _selectedLevel,
        equipment: _selectedEquipment == 'All' ? null : _selectedEquipment,
      );
    });
  }

  void _addToRecent(ExerciseDb ex) {
    _recentlyViewed.removeWhere((e) => e.id == ex.id);
    _recentlyViewed.insert(0, ex);
    if (_recentlyViewed.length > 3) {
      _recentlyViewed.removeLast();
    }
  }

  void _toggleFavorite(String id) {
    setState(() {
      if (_favoriteIds.contains(id)) {
        _favoriteIds.remove(id);
      } else {
        _favoriteIds.add(id);
      }
    });
  }

  void _showQuickPreview(ExerciseDb ex) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ex.images.isNotEmpty
                        ? _buildQuickPreviewImage(ex)
                        : Container(
                            width: 80, height: 80,
                            color: AppTheme.indigo100,
                            child: const Icon(Icons.fitness_center, color: AppTheme.primaryColor),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ex.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ex.primaryMuscles.join(', '),
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: [
                            _smallChip(ex.level),
                            _smallChip(ex.equipment.isNotEmpty ? ex.equipment : 'body only'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Instructions',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ...ex.instructions.take(3).map((inst) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: AppTheme.textSecondary)),
                    Expanded(
                      child: Text(
                        inst,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.3),
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ExerciseDetailScreen(exercise: ex)),
                    );
                  },
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('View Full Details'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRandomExercise() {
    if (_filtered.isEmpty) return;
    final ex = _filtered[_random.nextInt(_filtered.length)];
    _showQuickPreview(ex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Library'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle),
            tooltip: 'Random Exercise',
            onPressed: _filtered.isNotEmpty ? _showRandomExercise : null,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search exercises...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _applyFilters();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (_) => _applyFilters(),
                  ),
                ),
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      _filterChip('Muscle', _selectedMuscle, ExerciseDatabase.getMuscleGroups(), (v) {
                        setState(() => _selectedMuscle = v);
                        _applyFilters();
                      }),
                      const SizedBox(width: 8),
                      _filterChip('Level', _selectedLevel, ExerciseDatabase.getLevels(), (v) {
                        setState(() => _selectedLevel = v);
                        _applyFilters();
                      }),
                      const SizedBox(width: 8),
                      _filterChip('Equipment', _selectedEquipment, ExerciseDatabase.getEquipmentTypes(), (v) {
                        setState(() => _selectedEquipment = v);
                        _applyFilters();
                      }),
                      const SizedBox(width: 8),
                      if (_favoriteIds.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedMuscle = 'All';
                              _selectedLevel = 'All';
                              _selectedEquipment = 'All';
                              _searchController.clear();
                              _filtered = ExerciseDatabase.all.where((e) => _favoriteIds.contains(e.id)).toList();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, size: 14, color: AppTheme.warningColor),
                                const SizedBox(width: 4),
                                Text(
                                  'Favorites (${_favoriteIds.length})',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.warningColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Results count + Clear
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        '${_filtered.length} exercise${_filtered.length == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const Spacer(),
                      if (_selectedMuscle != 'All' || _selectedLevel != 'All' || _selectedEquipment != 'All')
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedMuscle = 'All';
                              _selectedLevel = 'All';
                              _selectedEquipment = 'All';
                            });
                            _applyFilters();
                          },
                          child: const Text('Clear Filters'),
                        ),
                    ],
                  ),
                ),
                // Recently Viewed
                if (_recentlyViewed.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Row(
                      children: [
                        Icon(Icons.history, size: 16, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        const Text(
                          'Recently Viewed',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _recentlyViewed.clear()),
                          child: const Text(
                            'Clear',
                            style: TextStyle(fontSize: 12, color: AppTheme.primaryColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 64,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _recentlyViewed.length,
                      itemBuilder: (_, i) {
                        final ex = _recentlyViewed[i];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ExerciseDetailScreen(exercise: ex)),
                            );
                          },
                          child: Container(
                            width: 130,
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.indigo50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: ex.images.isNotEmpty
                                      ? _buildRecentImage(ex)
                                      : Container(
                                          width: 36, height: 36, color: AppTheme.indigo100,
                                          child: const Icon(Icons.fitness_center, size: 16, color: AppTheme.primaryColor),
                                        ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    ex.name,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                // Exercise list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) {
                      final ex = _filtered[i];
                      final isFav = _favoriteIds.contains(ex.id);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            _addToRecent(ex);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ExerciseDetailScreen(exercise: ex)),
                            );
                          },
                          onLongPress: () => _showQuickPreview(ex),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: ex.images.isNotEmpty
                                      ? _buildExerciseImage(ex)
                                      : Container(
                                          width: 60, height: 60,
                                          color: AppTheme.indigo100,
                                          child: const Icon(Icons.fitness_center, color: AppTheme.primaryColor),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ex.name,
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        ex.primaryMuscles.join(', '),
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 4,
                                        children: [
                                          _smallChip(ex.level),
                                          _smallChip(ex.equipment.isNotEmpty ? ex.equipment : 'body only'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    isFav ? Icons.star : Icons.star_border,
                                    color: isFav ? AppTheme.warningColor : Colors.grey.shade400,
                                    size: 22,
                                  ),
                                  onPressed: () => _toggleFavorite(ex.id),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _filterChip(String label, String selected, List<String> options, Function(String) onSelected) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (_) => options.map((o) => PopupMenuItem(
        value: o,
        child: Row(
          children: [
            Icon(
              o == selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: o == selected ? AppTheme.primaryColor : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(o, style: TextStyle(fontWeight: o == selected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      )).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected != 'All' ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected != 'All' ? AppTheme.primaryColor.withValues(alpha: 0.3) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: $selected',
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected != 'All' ? FontWeight.w600 : FontWeight.normal,
                color: selected != 'All' ? AppTheme.primaryColor : Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: selected != 'All' ? AppTheme.primaryColor : Colors.grey.shade500),
          ],
        ),
      ),
    );
  }

  Widget _smallChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.indigo50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: AppTheme.primaryColor),
      ),
    );
  }

  Widget _buildExerciseImage(ExerciseDb ex) {
    return _buildStaticImage(ex, 60, 60);
  }

  Widget _buildQuickPreviewImage(ExerciseDb ex) {
    return _buildStaticImage(ex, 80, 80);
  }

  Widget _buildRecentImage(ExerciseDb ex) {
    return _buildStaticImage(ex, 36, 36);
  }

  Widget _buildStaticImage(ExerciseDb ex, double width, double height) {
    return Image.network(
      ex.imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: width,
        height: height,
        color: AppTheme.indigo100,
        child: const Icon(Icons.fitness_center, color: AppTheme.primaryColor),
      ),
    );
  }
}
