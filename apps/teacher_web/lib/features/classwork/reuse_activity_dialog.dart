import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';

/// "Reuse Activity": copy an existing item into a class as a draft.
Future<void> showReuseActivity(BuildContext context, {String? targetClassId, ClassworkItem? source}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _ReuseActivityDialog(targetClassId: targetClassId, source: source),
    );

class _ReuseActivityDialog extends ConsumerStatefulWidget {
  const _ReuseActivityDialog({this.targetClassId, this.source});

  final String? targetClassId;
  final ClassworkItem? source;

  @override
  ConsumerState<_ReuseActivityDialog> createState() => _ReuseActivityDialogState();
}

class _ReuseActivityDialogState extends ConsumerState<_ReuseActivityDialog> {
  ClassworkItem? _source;
  String? _targetId;
  DateTime _due = addDays(startOfDay(DateTime.now()), 1);
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _source = widget.source;
    _targetId = widget.targetClassId;
  }

  Future<void> _copy(List<ClassRoom> classes) async {
    final source = _source;
    ClassRoom? target;
    for (final c in classes) {
      if (c.id == _targetId) target = c;
    }
    if (source == null || target == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(dashboardRepositoryProvider)
          .duplicateClasswork(source, target: target, dueDate: _due);
      if (!mounted) return;
      Navigator.pop(context);
      showToast('Copied to ${target.name} as a draft');
    } catch (e) {
      setState(() => _saving = false);
      showToast("Couldn't copy: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(activeClassesProvider).valueOrNull ?? const <ClassRoom>[];
    final recent = ref.watch(recentClassworkProvider);

    return AppDialog(
      maxWidth: 560,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHeader(
            title: 'Reuse Activity',
            subtitle: 'Copy an existing classwork item',
            leading: ToneIcon(Icons.insert_drive_file_outlined, tone: Tone.blue, size: 46),
          ),
          const SizedBox(height: 16),
          const FieldLabel('Choose an item'),
          Container(
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.buttonBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            child: AsyncValueView<List<ClassworkItem>>(
              value: recent,
              data: (items) {
                if (items.isEmpty) return const EmptyNote('Nothing to reuse yet.');
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, i) => const Divider(),
                  itemBuilder: (_, i) {
                    final item = items[i];
                    final selected = _source?.id == item.id;
                    return ListTile(
                      selected: selected,
                      selectedTileColor: AppColors.blueSoft,
                      leading: ToneIcon(item.type.icon, tone: item.type.tone, size: 36),
                      title: Text(item.title,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text('${item.type.label} · ${item.className}', style: AppText.meta),
                      trailing: selected
                          ? const Icon(Icons.check_circle_rounded, color: AppColors.link)
                          : null,
                      onTap: () => setState(() => _source = item),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FieldLabel('Copy to'),
                    DropdownMenu<String>(
                      initialSelection: _targetId,
                      expandedInsets: EdgeInsets.zero,
                      requestFocusOnTap: false,
                      hintText: 'Choose a class',
                      dropdownMenuEntries: [
                        for (final c in classes) DropdownMenuEntry(value: c.id, label: c.name),
                      ],
                      onSelected: (v) => setState(() => _targetId = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FieldLabel('New due date'),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        final now = DateTime.now();
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _due,
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 2),
                        );
                        if (d != null) setState(() => _due = d);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            suffixIcon: Icon(Icons.calendar_month_outlined, size: 20)),
                        child: Text(longDate(_due)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                    onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving || _source == null || _targetId == null
                      ? null
                      : () => _copy(classes),
                  child: const Text('Copy to class'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
