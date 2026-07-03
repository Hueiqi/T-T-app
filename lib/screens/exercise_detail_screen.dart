import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/exercise_model.dart';
import '../config/theme.dart';

class ExerciseDetailScreen extends StatelessWidget {
  final ExerciseDb exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.name, style: const TextStyle(fontSize: 16)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildExerciseImage(exercise),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _tag('Level: ${exercise.level}', Colors.blue),
                _tag('Equipment: ${exercise.equipment.isNotEmpty ? exercise.equipment : 'body only'}', Colors.green),
                _tag('Category: ${exercise.category}', Colors.purple),
                if (exercise.force.isNotEmpty) _tag('Force: ${exercise.force}', Colors.orange),
                if (exercise.mechanic.isNotEmpty && exercise.mechanic != 'null')
                  _tag('Mechanic: ${exercise.mechanic}', Colors.teal),
              ],
            ),
            const SizedBox(height: 20),
            if (exercise.primaryMuscles.isNotEmpty) ...[
              _sectionTitle('Primary Muscles'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: exercise.primaryMuscles.map((m) => Chip(
                  label: Text(m, style: const TextStyle(fontSize: 12)),
                  backgroundColor: AppTheme.indigo50,
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
              const SizedBox(height: 16),
            ],
            if (exercise.secondaryMuscles.isNotEmpty) ...[
              _sectionTitle('Secondary Muscles'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: exercise.secondaryMuscles.map((m) => Chip(
                  label: Text(m, style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.grey.shade100,
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
              const SizedBox(height: 16),
            ],
            if (exercise.instructions.isNotEmpty) ...[
              _sectionTitle('Instructions'),
              const SizedBox(height: 8),
              ...exercise.instructions.asMap().entries.map((entry) {
                final i = entry.key + 1;
                final step = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Center(
                          child: Text(
                            '$i',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          step,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildExerciseImage(ExerciseDb exercise) {
    final gif = exercise.gifUrl;
    final static = exercise.imageUrl;

    final imageWidget = gif != null
        ? CachedNetworkImage(
            imageUrl: gif,
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (_, __) => _placeholder(),
            errorWidget: (_, __, ___) => _buildStaticImage(static),
          )
        : _buildStaticImage(static);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: imageWidget,
    );
  }

  Widget _buildStaticImage(String url) {
    if (url.isEmpty) return _placeholder();

    return Image.network(
      url,
      height: 220,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return _placeholder();
      },
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppTheme.indigo100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Icon(Icons.fitness_center, size: 64, color: AppTheme.primaryColor),
      ),
    );
  }
}
