import 'package:flutter/material.dart';
import 'package:edulearn_ui/edulearn_ui.dart';

import 'widgets/announcements_card.dart';
import 'widgets/class_performance_card.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_stats.dart';
import 'widgets/my_classes_card.dart';
import 'widgets/right_column.dart';

/// Homepage: `/`
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      header: DashboardHeader(),
      children: [
        DashboardStats(),
        TwoColumn(
          left: [MyClassesCard(), DashboardPerformanceCard(), AnnouncementsCard()],
          right: [QuickCreateBanner(), UpcomingCard(), ToReviewCard(), StudentsSupportCard()],
          narrowOrder: [
            QuickCreateBanner(),
            MyClassesCard(),
            UpcomingCard(),
            ToReviewCard(),
            StudentsSupportCard(),
            DashboardPerformanceCard(),
            AnnouncementsCard(),
          ],
        ),
      ],
    );
  }
}
