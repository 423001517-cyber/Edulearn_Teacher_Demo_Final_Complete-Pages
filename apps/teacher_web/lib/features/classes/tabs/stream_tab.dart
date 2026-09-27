import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/data_providers.dart';
import '../../announcements/announcement_widgets.dart';

class StreamTab extends ConsumerWidget {
  const StreamTab({super.key, required this.classRoom});

  final ClassRoom classRoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      icon: Icons.forum_outlined,
      title: 'Class Stream',
      trailing: classRoom.isArchived
          ? null
          : FilledButton.icon(
              onPressed: () => showAnnouncementForm(context, classId: classRoom.id),
              icon: const Icon(Icons.campaign_outlined, size: 18),
              label: const Text('New announcement'),
            ),
      child: AsyncValueView<List<Announcement>>(
        value: ref.watch(classAnnouncementsProvider(classRoom.id)),
        data: (items) {
          if (items.isEmpty) return const EmptyNote('No announcements in this class yet.');
          return Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(),
                AnnouncementTile(announcement: items[i]),
              ],
            ],
          );
        },
      ),
    );
  }
}
