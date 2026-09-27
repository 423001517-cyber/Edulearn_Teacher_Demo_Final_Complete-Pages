import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

class ChartLine {
  const ChartLine({required this.name, required this.color, required this.values, this.fill = true});

  final String name;
  final Color color;

  /// 0.0 – 1.0 per x label; null draws a gap.
  final List<double?> values;
  final bool fill;
}

/// 0–100% line chart with a dotted legend, matching the mockups.
class TrendLineChart extends StatelessWidget {
  const TrendLineChart({
    super.key,
    required this.labels,
    required this.lines,
    this.height = 230,
    this.legendOnTop = false,
    this.showLegend = true,
  });

  final List<String> labels;
  final List<ChartLine> lines;
  final double height;
  final bool legendOnTop;
  final bool showLegend;

  @override
  Widget build(BuildContext context) {
    final legend = Wrap(
      alignment: WrapAlignment.center,
      spacing: 20,
      runSpacing: 6,
      children: [
        for (final l in lines)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: l.color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(l.name, style: AppText.meta),
            ],
          ),
      ],
    );

    final single = labels.length <= 1;
    const axis = TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w500);

    final chart = SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          minX: single ? -0.5 : 0,
          maxX: single ? 0.5 : (labels.length - 1).toDouble(),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            horizontalInterval: 25,
            verticalInterval: 1,
            getDrawingHorizontalLine: (v) => FlLine(color: AppColors.divider, strokeWidth: 1),
            getDrawingVerticalLine: (v) => FlLine(color: AppColors.divider, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: 25,
                getTitlesWidget: (v, meta) => Text('${v.toInt()}%', style: axis),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (v, meta) {
                  final i = v.round();
                  if ((v - i).abs() > 0.01 || i < 0 || i >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(labels[i], style: axis),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => AppColors.ink,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${lines[s.barIndex].name}: ${s.y.round()}%',
                    const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            for (final l in lines)
              LineChartBarData(
                spots: [
                  for (var i = 0; i < l.values.length; i++)
                    l.values[i] == null
                        ? FlSpot.nullSpot
                        : FlSpot(i.toDouble(), l.values[i]! * 100),
                ],
                color: l.color,
                barWidth: 2.5,
                isCurved: false,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, pct, bar, index) => FlDotCirclePainter(
                    radius: 4,
                    color: l.color,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(show: l.fill, color: l.color.withValues(alpha: 0.07)),
              ),
          ],
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showLegend && legendOnTop) ...[legend, const SizedBox(height: 14)],
        chart,
        if (showLegend && !legendOnTop) ...[const SizedBox(height: 12), legend],
      ],
    );
  }
}
