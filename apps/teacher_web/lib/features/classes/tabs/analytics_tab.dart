import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../reports/widgets/report_overview.dart';

/// The Class Reports overview, embedded. "Open full report" jumps to
/// /reports?classId=… with the same numbers.
class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({super.key, required this.classRoom});

  final ClassRoom classRoom;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () => context.go(Routes.reports(classId: classRoom.id)),
            child: ArrowLabel('Open full report'),
          ),
        ),
        const SizedBox(height: 16),
        ReportStatsGrid(classId: classRoom.id, period: ReportPeriod.thisQuarter),
        const SizedBox(height: 20),
        ReportTrendCard(classId: classRoom.id, period: ReportPeriod.thisQuarter),
      ],
    );
  }
}
