import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../providers/stream_providers.dart';
import '../classwork/classwork_details_popover.dart';
import 'stream_widgets.dart';

/// "Upcoming" — graded work due soon, with "View all →" to Classwork.
class StreamUpcomingCard extends ConsumerWidget {
  const StreamUpcomingCard({super.key, required this.classId});

  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      icon: Icons.calendar_month_outlined,
      title: 'Upcoming',
      actionLabel: 'View all',
      onAction: () => goTo(Routes.classDetail(classId, ClassTab.classwork)),
      child: AsyncValueView<List<ClassworkItem>>(
        value: ref.watch(upcomingWorkProvider(classId)),
        data: (items) {
          if (items.isEmpty) return const EmptyNote('No work due soon. 🎉');
          final shown = items.take(4).toList();
          return Column(
            children: [
              for (var i = 0; i < shown.length; i++) ...[
                if (i > 0) const Divider(),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => showClassworkPreview(context, shown[i]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        ToneIcon(StreamWorkKind.of(shown[i].type).icon,
                            tone: StreamWorkKind.of(shown[i].type).tone, size: 48, circle: true),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(shown[i].title,
                                  maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.itemTitle),
                              const SizedBox(height: 2),
                              Text('Due ${fullDate(shown[i].dueDate)}', style: AppText.meta),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (items.length > shown.length)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('+${items.length - shown.length} more', style: AppText.meta),
                ),
            ],
          );
        },
      ),
    );
  }
}
