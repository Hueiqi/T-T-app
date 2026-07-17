import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';   // ✅ added – fixes AppTheme

/// Simple data class for a weight entry.
class WeightEntry {
  final DateTime date;
  final double weight;
  final int caloriesGained;
  final int caloriesBurnt;

  WeightEntry({
    required this.date,
    required this.weight,
    required this.caloriesGained,
    required this.caloriesBurnt,
  });
}

class WeightProgressScreen extends StatefulWidget {
  const WeightProgressScreen({super.key});

  @override
  State<WeightProgressScreen> createState() => _WeightProgressScreenState();
}

class _WeightProgressScreenState extends State<WeightProgressScreen> {
  // ── Sample data (replace with real data from your provider) ──
  final List<WeightEntry> _allEntries = [
    WeightEntry(
      date: DateTime(2022, 3, 1),
      weight: 60,
      caloriesGained: 10582,
      caloriesBurnt: 3251,
    ),
    WeightEntry(
      date: DateTime(2022, 3, 15),
      weight: 61,
      caloriesGained: 5000,
      caloriesBurnt: 3000,
    ),
    WeightEntry(
      date: DateTime(2022, 4, 1),
      weight: 62,
      caloriesGained: 4000,
      caloriesBurnt: 3500,
    ),
    WeightEntry(
      date: DateTime(2022, 5, 1),
      weight: 63,
      caloriesGained: 6000,
      caloriesBurnt: 2800,
    ),
    WeightEntry(
      date: DateTime(2022, 6, 1),
      weight: 64,
      caloriesGained: 5500,
      caloriesBurnt: 3200,
    ),
    WeightEntry(
      date: DateTime(2022, 7, 18),
      weight: 65,
      caloriesGained: 7000,
      caloriesBurnt: 3300,
    ),
    // add more if needed
  ];

  // ── State ──
  String _selectedRange = 'All'; // All, 1M, 6M, 1Y
  List<String> get _ranges => ['All', '1M', '6M', '1Y'];

  List<WeightEntry> get _filteredEntries {
    final now = DateTime.now();
    final entries = _allEntries;
    switch (_selectedRange) {
      case '1M':
        return entries.where((e) => e.date.isAfter(now.subtract(const Duration(days: 30)))).toList();
      case '6M':
        return entries.where((e) => e.date.isAfter(now.subtract(const Duration(days: 180)))).toList();
      case '1Y':
        return entries.where((e) => e.date.isAfter(now.subtract(const Duration(days: 365)))).toList();
      default:
        return entries;
    }
  }

  double get _totalWeightChange {
    final filtered = _filteredEntries;
    if (filtered.length < 2) return 0;
    return filtered.last.weight - filtered.first.weight;
  }

  int get _totalCaloriesGained {
    return _filteredEntries.fold(0, (sum, e) => sum + e.caloriesGained);
  }

  int get _totalCaloriesBurnt {
    return _filteredEntries.fold(0, (sum, e) => sum + e.caloriesBurnt);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEntries;
    final weightChange = _totalWeightChange;
    final gained = _totalCaloriesGained;
    final burnt = _totalCaloriesBurnt;

    return Scaffold(
      appBar: AppBar(title: const Text('Weight Progress')),
      body: SafeArea(
        child: Column(
          children: [
            // ── Range buttons ──
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _statItem(
                    '${weightChange > 0 ? '+' : ''}${weightChange.toStringAsFixed(1)} kg',
                    '${weightChange > 0 ? '▲' : '▼'} Weight',
                    color: weightChange > 0 ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 16),
                  _statItem(
                    '${(gained - burnt).toStringAsFixed(0)} cals',
                    'Net',
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _statItem(
                    '${gained.toStringAsFixed(0)} cals',
                    'Gained',
                    color: AppTheme.warningColor,
                  ),
                  const SizedBox(width: 16),
                  _statItem(
                    '${burnt.toStringAsFixed(0)} cals',
                    'Burnt',
                    color: AppTheme.successColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Line chart ──
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              child: _buildLineChart(filtered),
            ),

            const Divider(height: 1),

            // ── Entries list ──
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No entries for this period'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final e = filtered[i];
                        final isLast = i == filtered.length - 1;
                        final dateStr = DateFormat('d MMMM yyyy').format(e.date);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                            child: Text(e.weight.toStringAsFixed(0), style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          title: Text(dateStr),
                          subtitle: Text(
                            '${e.caloriesGained} kcal gained · ${e.caloriesBurnt} kcal burnt',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Text(
                            '${e.weight.toStringAsFixed(1)} kg',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
            Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ─── FlChart ────────────────────────────────────────────────────
  Widget _buildLineChart(List<WeightEntry> entries) {
    if (entries.isEmpty) {
      return const Center(child: Text('No data to display'));
    }

    // Find min/max for Y axis
    final weights = entries.map((e) => e.weight).toList();
    final minWeight = (weights.reduce((a, b) => a < b ? a : b) - 2).floorToDouble();
    final maxWeight = (weights.reduce((a, b) => a > b ? a : b) + 2).ceilToDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.grey.shade300, strokeWidth: 0.5);
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                // Show only first and last date labels
                final index = value.toInt();
                if (index == 0 || index == entries.length - 1) {
                  final date = entries[index].date;
                  return Text(
                    DateFormat('d MMM').format(date),
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()} kg',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: entries.length - 1.toDouble(),
        minY: minWeight,
        maxY: maxWeight,
        lineBarsData: [
          LineChartBarData(
            spots: entries.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value.weight);
            }).toList(),
            isCurved: false,
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
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}