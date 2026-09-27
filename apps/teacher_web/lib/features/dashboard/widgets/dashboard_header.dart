import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/core_providers.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../providers/data_providers.dart';
import '../../shell/top_bar.dart';

class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacher = ref.watch(teacherProvider).valueOrNull;
    final now = DateTime.now();
    final greeting = Row(
      children: [
        Icon(now.hour < 18 ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
            color: const Color(0xFFF6B524), size: 36),
        const SizedBox(width: 14),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${greetingFor(now)}, ${teacher?.title ?? 'Teacher'}', style: AppText.greeting),
              const SizedBox(height: 2),
              Text("Here's what's happening in your classes today.",
                  style: AppText.meta.copyWith(fontSize: 13.5)),
            ],
          ),
        ),
      ],
    );
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 820) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            greeting,
            const SizedBox(height: 14),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [ClassSelector(), TopBarControls()],
            ),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: greeting),
          const ClassSelector(),
          const SizedBox(width: 12),
          const TopBarControls(),
        ],
      );
    });
  }
}

/// "Changes all dashboard data to the selected class."
class ClassSelector extends ConsumerWidget {
  const ClassSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(activeClassesProvider).valueOrNull ?? const <ClassRoom>[];
    final selected = ref.watch(selectedClassIdProvider);
    final options = <ClassRoom?>[null, ...classes];
    ClassRoom? current;
    for (final c in classes) {
      if (c.id == selected) current = c;
    }
    return Tooltip(
      message: 'Changes all dashboard data to the selected class',
      child: FilterDropdown<ClassRoom?>(
        value: current,
        options: options,
        icon: Icons.groups_outlined,
        labelOf: (c) => c?.name ?? 'All Classes',
        onChanged: (c) => ref.read(selectedClassIdProvider.notifier).state = c?.id,
      ),
    );
  }
}
