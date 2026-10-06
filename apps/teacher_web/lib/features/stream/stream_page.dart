import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../providers/data_providers.dart';
import '../../providers/stream_providers.dart';
import '../shell/top_bar.dart';
import 'class_banner.dart';
import 'stream_feed.dart';
import 'upcoming_card.dart';

/// `/stream?classId=&post=` — announcements and class updates.
class StreamPage extends ConsumerWidget {
  const StreamPage({super.key, this.classId, this.post});

  final String? classId;

  /// From a copied link: open this post's class comments.
  final String? post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<ClassRoom?>(
      value: ref.watch(streamClassProvider(classId)),
      data: (c) {
        if (c == null) {
          return const PageScaffold(
            header: PageHeader(icon: Icons.wb_sunny_rounded, title: 'Stream'),
            children: [EmptyNote('No classes yet — the stream appears once a class is assigned to you.')],
          );
        }
        return PageScaffold(
          header: PageHeader(
            icon: Icons.wb_sunny_rounded,
            title: 'Stream',
            subtitle: 'Share announcements and class updates.',
            actions: PageClassSelector(
              current: c,
              onChanged: (x) => goTo(Routes.stream(classId: x.id)),
            ),
          ),
          children: [
            ClassBanner(classRoom: c),
            TwoColumn(
              leftFlex: 4,
              rightFlex: 9,
              left: [StreamUpcomingCard(classId: c.id)],
              right: [StreamFeed(classRoom: c, openPost: post)],
            ),
          ],
        );
      },
    );
  }
}

/// "👥 Grade 4 – Rizal ▾" in the page header.
class PageClassSelector extends ConsumerWidget {
  const PageClassSelector({super.key, required this.current, required this.onChanged});

  final ClassRoom current;
  final ValueChanged<ClassRoom> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeClassesProvider).valueOrNull ?? const <ClassRoom>[];
    final options = [
      ...active,
      if (!active.any((x) => x.id == current.id)) current,
    ];
    return FilterDropdown<ClassRoom>(
      value: options.firstWhere((x) => x.id == current.id),
      options: options,
      labelOf: (x) => x.isArchived ? '${x.name} (archived)' : x.name,
      icon: Icons.groups_rounded,
      minWidth: 210,
      onChanged: onChanged,
    );
  }
}
