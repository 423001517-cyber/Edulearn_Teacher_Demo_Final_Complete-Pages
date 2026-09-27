import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/dashboard_providers.dart';
import '../../../providers/data_providers.dart';

/// Dashboard version: follows the header's class selector.
class DashboardPerformanceCard extends ConsumerWidget {
  const DashboardPerformanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PerformanceCard(
      range: ref.watch(performanceRangeProvider),
      data: ref.watch(dashboardPerformanceProvider),
      onRangeChanged: (r) => ref.read(performanceRangeProvider.notifier).state = r,
    );
  }
}

/// Class page version: one class, its own range.
class ClassPerformanceCard extends ConsumerStatefulWidget {
  const ClassPerformanceCard({super.key, required this.classId});

  final String classId;

  @override
  ConsumerState<ClassPerformanceCard> createState() => _ClassPerformanceCardState();
}

class _ClassPerformanceCardState extends ConsumerState<ClassPerformanceCard> {
  PerformanceRange _range = const PerformanceRange(RangeKind.week);

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(
      performanceChartProvider(PerformanceQuery(classId: widget.classId, range: _range)),
    );
    return PerformanceCard(
      range: _range,
      data: data,
      showLegend: false,
      onRangeChanged: (r) => setState(() => _range = r),
    );
  }
}

class PerformanceCard extends StatelessWidget {
  const PerformanceCard({
    super.key,
    required this.range,
    required this.data,
    required this.onRangeChanged,
    this.showLegend = true,
  });

  final PerformanceRange range;
  final AsyncValue<PerformanceChartData> data;
  final ValueChanged<PerformanceRange> onRangeChanged;
  final bool showLegend;

  Future<void> _select(BuildContext context, RangeKind kind) async {
    if (kind != RangeKind.custom) {
      onRangeChanged(PerformanceRange(kind));
      return;
    }
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: range.customStart != null && range.customEnd != null
          ? DateTimeRange(start: range.customStart!, end: range.customEnd!)
          : DateTimeRange(start: now.subtract(const Duration(days: 13)), end: now),
    );
    if (picked != null) {
      onRangeChanged(
          PerformanceRange(RangeKind.custom, customStart: picked.start, customEnd: picked.end));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.bar_chart_rounded,
      title: 'Class Performance',
      showDivider: false,
      trailing: FilterDropdown<RangeKind>(
        value: range.kind,
        options: RangeKind.values,
        labelOf: (k) => k == range.kind ? range.label : PerformanceRange.labelFor(k),
        onChanged: (k) => _select(context, k),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: AsyncValueView<PerformanceChartData>(
          value: data,
          loadingHeight: 250,
          data: (d) {
            if (!d.hasData) {
              return EmptyNote('No scores recorded for ${range.label.toLowerCase()} yet.',
                  icon: Icons.insights_outlined);
            }
            return TrendLineChart(
              labels: d.labels,
              showLegend: showLegend,
              lines: [
                for (final s in d.series)
                  ChartLine(name: s.name, color: AppColors.forClass(s.colorIndex), values: s.values),
              ],
            );
          },
        ),
      ),
    );
  }
}
