import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../providers/nutrition_provider.dart';
import '../providers/auth_provider.dart';
import '../models/weight_entry_model.dart';

class WeightProgressScreen extends StatefulWidget {
  const WeightProgressScreen({super.key});

  @override
  State<WeightProgressScreen> createState() => _WeightProgressScreenState();
}

class _WeightProgressScreenState extends State<WeightProgressScreen> {
  String _selectedRange = 'All';
  static const _ranges = ['All', '1M', '6M', '1Y'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.user != null) {
        context.read<NutritionProvider>().loadWeightHistory(auth.user!.uid);
      }
    });
  }

  List<WeightEntry> _filteredEntries(List<WeightEntry> all) {
    final now = DateTime.now();
    switch (_selectedRange) {
      case '1M':
        return all.where((e) => e.date.isAfter(now.subtract(const Duration(days: 30)))).toList();
      case '6M':
        return all.where((e) => e.date.isAfter(now.subtract(const Duration(days: 180)))).toList();
      case '1Y':
        return all.where((e) => e.date.isAfter(now.subtract(const Duration(days: 365)))).toList();
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weight Progress'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Log Weight',
            onPressed: () => _showWeightDialog(context),
          ),
        ],
      ),
      body: Consumer<NutritionProvider>(
        builder: (context, nutrition, _) {
          final allEntries = nutrition.weightHistory;
          final filtered = _filteredEntries(allEntries);
          final targetWeight = context.read<AuthProvider>().user?.targetWeightKg;

          return SafeArea(
            child: Column(
              children: [
                // ── Range chips ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: _ranges.map((range) {
                      final selected = _selectedRange == range;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Text(range),
                          selected: selected,
                          onSelected: (_) => setState(() => _selectedRange = range),
                          selectedColor: AppTheme.primaryColor,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : AppTheme.textSecondary,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // ── Summary stats ──
                if (filtered.length >= 2)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildSummaryCards(filtered, targetWeight),
                  ),
                const SizedBox(height: 8),

                // ── Chart ──
                if (filtered.isNotEmpty)
                  Container(
                    height: 220,
                    padding: const EdgeInsets.all(16),
                    child: _buildLineChart(filtered, targetWeight),
                  )
                else
                  SizedBox(
                    height: 220,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.show_chart, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text(
                            'No weight entries yet',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap + to log your first weight',
                            style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),

                const Divider(height: 1),

                // ── Entry list ──
                Expanded(
                  child: filtered.isEmpty
                      ? const SizedBox.shrink()
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                          itemBuilder: (ctx, i) {
                            final entry = filtered[i];
                            final dateStr = DateFormat('d MMM yyyy').format(entry.date);

                            // Compute change from previous entry
                            String? changeStr;
                            Color? changeColor;
                            if (i < filtered.length - 1) {
                              final prev = filtered[i + 1];
                              final change = entry.weight - prev.weight;
                              if (change != 0) {
                                changeStr = '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)} kg';
                                changeColor = change > 0 ? AppTheme.errorColor : AppTheme.successColor;
                              }
                            }

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                                child: Text(
                                  entry.weight.toStringAsFixed(0),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              title: Text(dateStr),
                              subtitle: entry.notes != null && entry.notes!.isNotEmpty
                                  ? Text(entry.notes!, style: const TextStyle(fontSize: 12), maxLines: 1)
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (changeStr != null) ...[
                                    Text(
                                      changeStr,
                                      style: TextStyle(fontSize: 12, color: changeColor, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    '${entry.weight.toStringAsFixed(1)} kg',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards(List<WeightEntry> entries, double? targetWeight) {
    final first = entries.last;
    final last = entries.first;
    final change = last.weight - first.weight;
    final lowest = entries.map((e) => e.weight).reduce((a, b) => a < b ? a : b);
    final highest = entries.map((e) => e.weight).reduce((a, b) => a > b ? a : b);

    return Row(
      children: [
        _statItem(
          '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)} kg',
          'Change',
          color: change > 0 ? AppTheme.errorColor : AppTheme.successColor,
        ),
        const SizedBox(width: 8),
        _statItem(
          '${lowest.toStringAsFixed(1)} kg',
          'Lowest',
          color: AppTheme.successColor,
        ),
        const SizedBox(width: 8),
        _statItem(
          '${highest.toStringAsFixed(1)} kg',
          'Highest',
          color: AppTheme.warningColor,
        ),
        if (targetWeight != null) ...[
          const SizedBox(width: 8),
          _statItem(
            '${targetWeight.toStringAsFixed(1)} kg',
            'Goal',
            color: AppTheme.primaryColor,
          ),
        ],
      ],
    );
  }

  Widget _statItem(String value, String label, {required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            ),
            Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart(List<WeightEntry> entries, double? targetWeight) {
    final weights = entries.map((e) => e.weight).toList();
    var minWeight = (weights.reduce((a, b) => a < b ? a : b) - 2).floorToDouble();
    var maxWeight = (weights.reduce((a, b) => a > b ? a : b) + 2).ceilToDouble();

    // Include target weight in Y axis range
    if (targetWeight != null) {
      if (targetWeight < minWeight) minWeight = targetWeight - 2;
      if (targetWeight > maxWeight) maxWeight = targetWeight + 2;
    }

    // Build horizontal interval
    final range = maxWeight - minWeight;
    final interval = range > 20 ? 5.0 : range > 10 ? 2.0 : 1.0;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withValues(alpha: 0.2),
            strokeWidth: 0.5,
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) return const SizedBox.shrink();
                // Show first, middle, and last
                if (index == 0 || index == entries.length - 1 || index == entries.length ~/ 2) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      DateFormat('d MMM').format(entries[index].date),
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: interval,
              getTitlesWidget: (value, meta) => Text(
                '${value.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (entries.length - 1).toDouble(),
        minY: minWeight,
        maxY: maxWeight,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppTheme.primaryColor,
            getTooltipItems: (spots) => spots.map((spot) {
              final idx = spot.x.toInt();
              final weight = entries[idx].weight;
              final date = DateFormat('d MMM yyyy').format(entries[idx].date);
              return LineTooltipItem(
                '${weight.toStringAsFixed(1)} kg\n$date',
                const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          // Target weight dashed line
          if (targetWeight != null)
            LineChartBarData(
              spots: [
                FlSpot(0, targetWeight),
                FlSpot((entries.length - 1).toDouble(), targetWeight),
              ],
              isCurved: false,
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              dashArray: [8, 4],
            ),
          // Weight line
          LineChartBarData(
            spots: entries.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value.weight);
            }).toList(),
            isCurved: true,
            color: AppTheme.primaryColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: AppTheme.primaryColor,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }

  void _showWeightDialog(BuildContext context) {
    final nutrition = context.read<NutritionProvider>();
    final controller = TextEditingController(
      text: nutrition.todayWeight != null
          ? nutrition.todayWeight!.weight.toStringAsFixed(1)
          : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Today\'s Weight'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Weight (kg)',
            prefixIcon: Icon(Icons.monitor_weight),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final w = double.tryParse(controller.text.trim());
              if (w == null || w <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid weight.')),
                );
                return;
              }
              final auth = context.read<AuthProvider>();
              if (auth.user == null) return;
              await nutrition.saveWeight(userId: auth.user!.uid, weight: w);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
