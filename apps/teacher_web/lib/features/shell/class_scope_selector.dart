import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/data_providers.dart';

/// "👥 All classes ▾" / "👥 Grade 4 – Rizal ▾" in a page header, for pages
/// that can show every class at once (Analytics, Students).
class ClassScopeSelector extends ConsumerWidget {
  const ClassScopeSelector({super.key, required this.classId, required this.onChanged, this.allLabel = 'All classes'});

  /// null = all active classes.
  final String? classId;
  final ValueChanged<String?> onChanged;
  final String allLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeClassesProvider).valueOrNull ?? const <ClassRoom>[];
    final archived = classId == null ? null : ref.watch(classByIdProvider)[classId];
    final options = <ClassRoom?>[
      null,
      ...active,
      if (archived != null && !active.any((c) => c.id == archived.id)) archived,
    ];
    ClassRoom? current;
    for (final c in options) {
      if (c != null && c.id == classId) current = c;
    }
    return FilterDropdown<ClassRoom?>(
      value: current,
      options: options,
      labelOf: (c) => c == null ? allLabel : (c.isArchived ? '${c.name} (archived)' : c.name),
      icon: Icons.groups_rounded,
      minWidth: 200,
      onChanged: (c) => onChanged(c?.id),
    );
  }
}
