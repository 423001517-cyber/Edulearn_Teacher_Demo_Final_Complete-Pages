import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../providers/dashboard_providers.dart';
import '../../announcements/announcement_widgets.dart';

class AnnouncementsCard extends ConsumerWidget {
  const AnnouncementsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      icon: Icons.campaign_outlined,
      title: 'Recent Announcements',
      actionLabel: 'View all',
      onAction: () => context.go(NavSection.stream.path),
      child: AsyncValueView<List<Announcement>>(
        value: ref.watch(visibleAnnouncementsProvider),
        data: (list) {
          if (list.isEmpty) {
            return EmptyNote('No announcements yet.',
                actionLabel: 'Post an announcement', onAction: () => showAnnouncementForm(context));
          }
          return Column(
            children: [
              for (var i = 0; i < list.length && i < 3; i++) ...[
                if (i > 0) const Divider(),
                AnnouncementTile(announcement: list[i]),
              ],
            ],
          );
        },
      ),
    );
  }
}
