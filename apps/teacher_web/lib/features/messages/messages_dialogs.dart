import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/classes_providers.dart';
import '../../providers/data_providers.dart';

/// "New message": choose a student from any active class.
Future<Student?> pickStudentDialog(BuildContext context) =>
    showDialog<Student>(context: context, builder: (_) => const _StudentPicker());

class _StudentPicker extends ConsumerStatefulWidget {
  const _StudentPicker();

  @override
  ConsumerState<_StudentPicker> createState() => _StudentPickerState();
}

class _StudentPickerState extends ConsumerState<_StudentPicker> {
  String _query = '';
  String? _classId;

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(activeClassesProvider).valueOrNull ?? const <ClassRoom>[];
    final names = {for (final c in classes) c.id: c.name};
    final q = _query.trim().toLowerCase();
    final students = (ref.watch(studentsProvider).valueOrNull ?? const <Student>[])
        .where((s) => names.containsKey(s.classId))
        .where((s) => _classId == null || s.classId == _classId)
        .where((s) => q.isEmpty || s.name.toLowerCase().contains(q))
        .toList();
    ClassRoom? current;
    for (final c in classes) {
      if (c.id == _classId) current = c;
    }

    return AppDialog(
      maxWidth: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHeader(title: 'New message', subtitle: 'Choose a student'),
          const SizedBox(height: 14),
          SearchField(hint: 'Search students', onChanged: (v) => setState(() => _query = v)),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilterDropdown<ClassRoom?>(
              value: current,
              options: [null, ...classes],
              labelOf: (c) => c?.name ?? 'All classes',
              onChanged: (c) => setState(() => _classId = c?.id),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: students.isEmpty
                ? const EmptyNote('No students match.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: students.length,
                    separatorBuilder: (_, i) => const Divider(),
                    itemBuilder: (_, i) {
                      final s = students[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: InitialsAvatar(initials: s.initials, tone: toneForName(s.name), size: 38, imageUrl: s.photoUrl),
                        title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        subtitle: Text(names[s.classId] ?? '', style: AppText.meta.copyWith(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.pop(context, s),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// "Share classwork": choose an item from the class to link in the chat.
Future<ClassworkItem?> pickClassworkDialog(BuildContext context, {required String classId}) =>
    showDialog<ClassworkItem>(context: context, builder: (_) => _ClassworkPicker(classId: classId));

class _ClassworkPicker extends ConsumerWidget {
  const _ClassworkPicker({required this.classId});

  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(classClassworkProvider(classId));
    return AppDialog(
      maxWidth: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHeader(title: 'Share classwork', subtitle: 'Students can open it from the chat'),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: AsyncValueView<List<ClassworkItem>>(
              value: items,
              data: (all) {
                final list = all.where((w) => w.status != ClassworkStatus.draft).take(30).toList();
                if (list.isEmpty) return const EmptyNote('No classwork in this class yet.');
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: list.length,
                  separatorBuilder: (_, i) => const Divider(),
                  itemBuilder: (_, i) {
                    final w = list[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ToneIcon(w.type.icon, tone: w.type.tone, size: 36),
                      title: Text(w.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      subtitle: Text('${w.type.shortLabel} · due ${dayMonth(w.dueDate)}',
                          style: AppText.meta.copyWith(fontSize: 12)),
                      onTap: () => Navigator.pop(context, w),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
