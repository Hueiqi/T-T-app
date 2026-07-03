import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/nutrition_provider.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';
import '../models/meal_model.dart';

class NutritionReportsScreen extends StatefulWidget {
  const NutritionReportsScreen({super.key});

  @override
  State<NutritionReportsScreen> createState() => _NutritionReportsScreenState();
}

class _NutritionReportsScreenState extends State<NutritionReportsScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  late DateTime _today;
  bool _isLoading = true;

  List<Meal> _meals = [];
  double _totalCalories = 0;
  double _totalProtein = 0;
  double _totalCarbs = 0;
  double _totalFat = 0;
  double _totalFiber = 0;
  double _totalVitamins = 0;
  double _totalMinerals = 0;
  double _totalWater = 0;
  int _mealCount = 0;

  // Daily aggregated data for the bar chart
  List<_DayData> _dailyData = [];

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    if (auth.user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final nutrition = context.read<NutritionProvider>();
    await nutrition.loadMealsForDateRange(auth.user!.uid, _startDate, _endDate);
    _meals = nutrition.dateRangeMeals;

    _aggregateData();

    if (mounted) setState(() => _isLoading = false);
  }

  void _aggregateData() {
    _totalCalories = 0;
    _totalProtein = 0;
    _totalCarbs = 0;
    _totalFat = 0;
    _totalFiber = 0;
    _totalVitamins = 0;
    _totalMinerals = 0;
    _totalWater = 0;
    _mealCount = _meals.length;

    final Map<String, _DayData> dayMap = {};

    for (final m in _meals) {
      _totalCalories += m.calories;
      _totalProtein += m.protein;
      _totalCarbs += m.carbs;
      _totalFat += m.fat;
      _totalFiber += m.fiber;
      _totalVitamins += m.vitamins;
      _totalMinerals += m.minerals;
      _totalWater += m.water;

      final dayKey = DateFormat('yyyy-MM-dd').format(m.dateTime);
      dayMap.putIfAbsent(dayKey, () => _DayData(date: m.dateTime));
      dayMap[dayKey]!.calories += m.calories;
      dayMap[dayKey]!.protein += m.protein;
      dayMap[dayKey]!.carbs += m.carbs;
      dayMap[dayKey]!.fat += m.fat;
    }

    _dailyData = dayMap.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: _today.subtract(const Duration(days: 365)),
      lastDate: _today,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.primaryColor,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadData();
    }
  }

  void _applyPreset(int days) {
    setState(() {
      _endDate = _today;
      _startDate = _today.subtract(Duration(days: days - 1));
    });
    _loadData();
  }

  String get _dateRangeLabel {
    final fmt = DateFormat('MMM d');
    return '${fmt.format(_startDate)} - ${fmt.format(_endDate)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDateRange,
            tooltip: 'Custom range',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDateHeader(),
                    const SizedBox(height: 16),
                    _buildPresetChips(),
                    const SizedBox(height: 20),
                    _buildCaloriesCard(),
                    const SizedBox(height: 20),
                    _buildMacroSection(),
                    const SizedBox(height: 20),
                    _buildCalorieChart(),
                    const SizedBox(height: 20),
                    _buildNutrientSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDateHeader() {
    return Card(
      elevation: 0,
      color: AppTheme.primaryColor.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        onTap: _pickDateRange,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.date_range, color: AppTheme.primaryColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _dateRangeLabel,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_mealCount meals',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChips() {
    final presets = [
      ('7D', 7),
      ('14D', 14),
      ('30D', 30),
      ('90D', 90),
    ];
    final selectedDays = _endDate.difference(_startDate).inDays + 1;

    return Row(
      children: presets.map((p) {
        final isSelected = selectedDays == p.$2;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(p.$1),
            selected: isSelected,
            selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
            onSelected: (_) => _applyPreset(p.$2),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCaloriesCard() {
    final avgCalories = _mealCount > 0 ? _totalCalories / _dailyData.length.clamp(1, 9999) : 0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.warningColor.withValues(alpha: 0.15),
            AppTheme.warningColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.15)),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.local_fire_department, color: AppTheme.warningColor, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Calories',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_totalCalories.toStringAsFixed(0)} kcal',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Avg ${avgCalories.toStringAsFixed(0)} kcal / day',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '${_dailyData.length}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              Text(
                'days',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.pie_chart, size: 16, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 8),
            Text(
              'Macronutrients',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MacroCard(
                label: 'Protein',
                value: _totalProtein,
                unit: 'g',
                color: AppTheme.accentColor,
                icon: Icons.fitness_center,
                total: _totalProtein + _totalCarbs + _totalFat,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MacroCard(
                label: 'Carbs',
                value: _totalCarbs,
                unit: 'g',
                color: AppTheme.successColor,
                icon: Icons.grain,
                total: _totalProtein + _totalCarbs + _totalFat,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MacroCard(
                label: 'Fat',
                value: _totalFat,
                unit: 'g',
                color: AppTheme.secondaryColor,
                icon: Icons.opacity,
                total: _totalProtein + _totalCarbs + _totalFat,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCalorieChart() {
    if (_dailyData.isEmpty) {
      return Card(
        elevation: 0,
        color: Colors.grey.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text(
              'No meal data for this period',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ),
      );
    }

    final maxCal = _dailyData.fold<double>(0, (m, d) => d.calories > m ? d.calories : m);
    final ceiling = ((maxCal / 500).ceil() * 500).clamp(500, 99999);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.bar_chart, size: 16, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 8),
            Text(
              'Daily Calories',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: ceiling.toDouble(),
                  minY: 0,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final day = _dailyData[groupIndex];
                        return BarTooltipItem(
                          '${DateFormat('MMM d').format(day.date)}\n${rod.toY.toStringAsFixed(0)} kcal',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}',
                            style: TextStyle(
                              color: AppTheme.textSecondary.withValues(alpha: 0.5),
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= _dailyData.length) return const SizedBox.shrink();
                          final day = _dailyData[idx].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              DateFormat('d').format(day),
                              style: TextStyle(
                                color: AppTheme.textSecondary.withValues(alpha: 0.5),
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: ceiling / 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _dailyData.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.calories,
                          color: AppTheme.primaryColor.withValues(alpha: 0.8),
                          width: _dailyData.length > 14 ? 8 : 14,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNutrientSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.eco, size: 16, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 8),
            Text(
              'Additional Nutrients',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _NutrientRow(
                  label: 'Fiber',
                  value: _totalFiber,
                  unit: 'g',
                  color: Colors.brown,
                  maxValue: _totalFiber > 25 ? _totalFiber : 25,
                ),
                const SizedBox(height: 4),
                _NutrientRow(
                  label: 'Vitamins',
                  value: _totalVitamins,
                  unit: 'mg',
                  color: Colors.orange,
                  maxValue: _totalVitamins > 100 ? _totalVitamins : 100,
                ),
                const SizedBox(height: 4),
                _NutrientRow(
                  label: 'Minerals',
                  value: _totalMinerals,
                  unit: 'mg',
                  color: Colors.purple,
                  maxValue: _totalMinerals > 100 ? _totalMinerals : 100,
                ),
                const SizedBox(height: 4),
                _NutrientRow(
                  label: 'Water',
                  value: _totalWater,
                  unit: 'ml',
                  color: Colors.blue,
                  maxValue: _totalWater > 2000 ? _totalWater : 2000,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Helper data class ──
class _DayData {
  final DateTime date;
  double calories;
  double protein;
  double carbs;
  double fat;

  _DayData({
    required this.date,
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });
}

// ── Macro Card ──
class _MacroCard extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color color;
  final IconData icon;
  final double total;

  const _MacroCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.icon,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (value / total * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            '${value.toStringAsFixed(0)}$unit',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${pct.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nutrient Row ──
class _NutrientRow extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color color;
  final double maxValue;

  const _NutrientRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.maxValue,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (value / maxValue).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Text(
              '${value.toStringAsFixed(1)} $unit',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
