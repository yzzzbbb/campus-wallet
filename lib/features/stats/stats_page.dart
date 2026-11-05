import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/logic/finance_math.dart';
import '../../core/theme/app_theme.dart';
import '../../state/budget_provider.dart';
import '../../state/category_provider.dart';
import '../../state/transaction_provider.dart';
import '../../widgets/amount_text.dart';
import 'stats_data.dart';

/// 统计页：本月分类占比 + 近 6 个月收支趋势 + 年度视图 + 月结复盘。
class StatsPage extends StatelessWidget {
  const StatsPage({super.key, this.monthKey});

  /// 统计月份（'YYYY-MM'）；null 时使用当前月。
  final String? monthKey;

  @override
  Widget build(BuildContext context) {
    final month = monthKey ?? FinanceMath.monthKey(DateTime.now());
    return _StatsBody(monthKey: month);
  }
}

class _MonthlyPoint {
  const _MonthlyPoint({
    required this.month,
    required this.expenseCents,
    required this.incomeCents,
  });

  final DateTime month;
  final int expenseCents;
  final int incomeCents;
}

class _StatsData {
  const _StatsData({
    required this.pieEntries,
    required this.monthlyPoints,
    required this.totalExpenseCents,
    required this.budgetCents,
    required this.overruns,
    required this.yearMonthly,
    required this.yearCells,
  });

  final List<PieEntry> pieEntries;
  final List<_MonthlyPoint> monthlyPoints;
  final int totalExpenseCents;
  final int budgetCents;
  final List<OverrunEntry> overruns;
  final List<MonthTotal> yearMonthly;
  final List<DayCell> yearCells;
}

class _StatsBody extends StatefulWidget {
  const _StatsBody({required this.monthKey});

  final String monthKey;

  @override
  State<_StatsBody> createState() => _StatsBodyState();
}

class _StatsBodyState extends State<_StatsBody> {
  late Future<_StatsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _StatsBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.monthKey != widget.monthKey) {
      _future = _load();
    }
  }

  Future<_StatsData> _load() async {
    final transactions = context.read<TransactionProvider>();
    final categoriesProvider = context.read<CategoryProvider>();
    final budgetsProvider = context.read<BudgetProvider>();

    if (!budgetsProvider.loaded) {
      await budgetsProvider.load();
    }

    final categories = await categoriesProvider.categories();
    final byCategory = await transactions.expenseByCategory(widget.monthKey);
    final totalExpense = await transactions.monthExpenseCents(widget.monthKey);
    final budgets = await budgetsProvider.budgetsOfMonth(widget.monthKey);

    // 近 6 个月（含当前月），从最早到最新。
    final now = DateTime.now();
    final points = <_MonthlyPoint>[];
    for (var i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final key = FinanceMath.monthKey(month);
      points.add(_MonthlyPoint(
        month: month,
        expenseCents: await transactions.monthExpenseCents(key),
        incomeCents: await transactions.monthIncomeCents(key),
      ));
    }

    // 年度视图：全年月度支出 + 每日热力图
    final year = now.year;
    final expenseByMonth = await transactions.expenseByMonthOfYear(year);
    final expenseByDay = await transactions.expenseByDayOfYear(year);

    return _StatsData(
      pieEntries: buildPieEntries(
        byCategory: byCategory,
        categories: categories,
      ),
      monthlyPoints: points,
      totalExpenseCents: totalExpense,
      budgetCents: budgetsProvider.effectiveMonthlyBudgetCents,
      overruns: buildOverrunTop3(
        byCategory: byCategory,
        categories: categories,
        budgets: budgets,
      ),
      yearMonthly: buildYearMonthly(year: year, expenseByMonth: expenseByMonth),
      yearCells: buildCalendarCells(year: year, expenseByDay: expenseByDay),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('统计')),
      body: FutureBuilder<_StatsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('统计加载失败'));
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _SectionCard(
                title: '本月支出构成',
                child: _PieSection(entries: data.pieEntries),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: '近 6 个月收支',
                child: _TrendSection(points: data.monthlyPoints),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: '${DateTime.now().year}年 每月支出',
                child: _YearBarSection(months: data.yearMonthly),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: '${DateTime.now().year}年 日历热力图',
                child: _HeatmapSection(cells: data.yearCells),
              ),
              const SizedBox(height: 16),
              _ReviewCard(data: data),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _PieSection extends StatelessWidget {
  const _PieSection({required this.entries});

  final List<PieEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            '本月还没有支出',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).hintColor),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 42,
              sections: [
                for (final entry in entries)
                  PieChartSectionData(
                    value: entry.cents.toDouble(),
                    color: Color(entry.color),
                    radius: 58,
                    title: entry.name,
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final entry in entries)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Color(entry.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${entry.name} ${AmountText.formatCents(entry.cents)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _TrendSection extends StatelessWidget {
  const _TrendSection({required this.points});

  final List<_MonthlyPoint> points;

  @override
  Widget build(BuildContext context) {
    var maxCents = 0;
    for (final point in points) {
      maxCents = math.max(maxCents, math.max(point.expenseCents, point.incomeCents));
    }
    final maxY = maxCents <= 0 ? 100.0 : maxCents / 100.0 * 1.2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            _LegendDot(color: AppColors.expense, label: '支出'),
            SizedBox(width: 16),
            _LegendDot(color: AppColors.income, label: '收入'),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              barGroups: [
                for (var i = 0; i < points.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 3,
                    barRods: [
                      BarChartRodData(
                        toY: points[i].expenseCents / 100.0,
                        color: AppColors.expense,
                        width: 7,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      BarChartRodData(
                        toY: points[i].incomeCents / 100.0,
                        color: AppColors.income,
                        width: 7,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                  ),
              ],
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(
                        '¥${value.round()}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (value, meta) {
                      final index = value.round();
                      if ((value - index).abs() > 0.001 ||
                          index < 0 ||
                          index >= points.length) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          '${points[index].month.month}月',
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: const FlGridData(drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final point = points[group.x];
                    final isExpense = rodIndex == 0;
                    final cents =
                        isExpense ? point.expenseCents : point.incomeCents;
                    return BarTooltipItem(
                      '${isExpense ? '支出' : '收入'}\n'
                      '${AmountText.formatCents(cents)}',
                      const TextStyle(color: Colors.white, fontSize: 11),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 全年 12 个月支出柱状图
class _YearBarSection extends StatelessWidget {
  const _YearBarSection({required this.months});

  final List<MonthTotal> months;

  @override
  Widget build(BuildContext context) {
    var maxCents = 0;
    for (final m in months) {
      maxCents = math.max(maxCents, m.cents);
    }
    final maxY = maxCents <= 0 ? 100.0 : maxCents / 100.0 * 1.2;
    final allZero = maxCents <= 0;
    return SizedBox(
      height: 180,
      child: allZero
          ? Center(
              child: Text(
                '今年还没有支出记录',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).hintColor),
              ),
            )
          : BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                barGroups: [
                  for (final m in months)
                    BarChartGroupData(
                      x: m.month - 1,
                      barRods: [
                        BarChartRodData(
                          toY: m.cents / 100.0,
                          color: AppColors.primary,
                          width: 10,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                    ),
                ],
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(
                          '¥${value.round()}',
                          style: const TextStyle(fontSize: 9),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if ((value - index).abs() > 0.001 ||
                            index < 0 ||
                            index >= 12) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            '${months[index].month}月',
                            style: const TextStyle(fontSize: 9),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(drawVerticalLine: false),
                borderData: FlBorderData(show: false),
              ),
            ),
    );
  }
}

/// 日历热力图（GitHub 风格，周一起始）
class _HeatmapSection extends StatelessWidget {
  const _HeatmapSection({required this.cells});

  final List<DayCell> cells;

  Color _cellColor(BuildContext context, int level) {
    final primary = AppColors.primary;
    switch (level) {
      case 1:
        return primary.withValues(alpha: 0.3);
      case 2:
        return primary.withValues(alpha: 0.6);
      case 3:
        return primary;
      default:
        return Theme.of(context).colorScheme.surfaceContainerHighest;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 3,
          crossAxisSpacing: 3,
          children: [
            for (final c in cells)
              Container(
                decoration: BoxDecoration(
                  color: c.level < 0 ? Colors.transparent : _cellColor(context, c.level),
                  borderRadius: BorderRadius.circular(3),
                ),
                height: 14,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            _legend(context, 0, '无'),
            _legend(context, 1, '少'),
            _legend(context, 2, '中'),
            _legend(context, 3, '多'),
          ],
        ),
      ],
    );
  }

  Widget _legend(BuildContext context, int level, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: level == 0
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : _cellColor(context, level),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.data});

  final _StatsData data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final mutedStyle = textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).hintColor,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '本月复盘',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('总支出', style: mutedStyle),
                AmountText(
                  cents: data.totalExpenseCents,
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('预算完成率', style: mutedStyle),
                Text(
                  _completionText(),
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '超支分类 Top3',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (data.overruns.isEmpty)
              Text('本月没有超支分类', style: mutedStyle)
            else
              for (final overrun in data.overruns)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(overrun.name, style: textTheme.bodyMedium),
                      Text(
                        '+${AmountText.formatCents(overrun.overspentCents)}',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.over,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  /// spent / effectiveBudget，保留一位小数；未设置预算时提示。
  String _completionText() {
    if (data.budgetCents <= 0) return '未设置预算';
    final tenths =
        (data.totalExpenseCents * 1000 + data.budgetCents ~/ 2) ~/
            data.budgetCents;
    return '${tenths ~/ 10}.${tenths % 10}%';
  }
}