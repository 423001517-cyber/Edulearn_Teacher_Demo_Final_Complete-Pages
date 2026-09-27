import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/classes_providers.dart';
import '../../classwork/classwork_details_popover.dart';
import '../../classwork/quick_create_dialog.dart';

/// Every lesson, quest, quiz and assessment in the class, with live
/// completion (submitted / assigned).
class ClassworkTab extends ConsumerStatefulWidget {
  const ClassworkTab({super.key, required this.classRoom});

  final ClassRoom classRoom;

  @override
  ConsumerState<ClassworkTab> createState() => _ClassworkTabState();
}

class _ClassworkTabState extends ConsumerState<ClassworkTab> {
  ClassworkType? _type; // null = all

  @override
  Widget build(BuildContext context) {
    final c = widget.classRoom;
    final today = startOfDay(DateTime.now());
    return SectionCard(
      icon: Icons.description_outlined,
      title: 'Classwork',
      trailing: Wrap(
        spacing: 10,
        children: [
          FilterDropdown<ClassworkType?>(
            value: _type,
            options: [null, ...ClassworkType.values],
            labelOf: (t) => t == null ? 'All types' : t.label,
            onChanged: (t) => setState(() => _type = t),
          ),
          if (!c.isArchived)
            FilledButton.icon(
              onPressed: () => showQuickCreate(context, classId: c.id),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create'),
            ),
        ],
      ),
      child: AsyncValueView<List<ClassworkItem>>(
        value: ref.watch(classClassworkProvider(c.id)),
        data: (all) {
          final items = _type == null ? all : all.where((w) => w.type == _type).toList();
          if (items.isEmpty) return const EmptyNote('No classwork yet.');
          final upcoming = items.where((w) => !w.dueDate.isBefore(today)).toList()
            ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
          final past = items.where((w) => w.dueDate.isBefore(today)).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (upcoming.isNotEmpty) ...[
                _GroupLabel('Upcoming (${upcoming.length})'),
                for (final w in upcoming) _ClassworkRow(item: w, classSize: c.studentCount),
              ],
              if (past.isNotEmpty) ...[
                _GroupLabel('Past (${past.length})'),
                for (final w in past) _ClassworkRow(item: w, classSize: c.studentCount),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(text, style: AppText.label),
      );
}

class _ClassworkRow extends StatelessWidget {
  const _ClassworkRow({required this.item, required this.classSize});

  final ClassworkItem item;
  final int classSize;

  @override
  Widget build(BuildContext context) {
    final rate = item.completionRate(classSize);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => showClassworkPreview(context, item),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth > 640;
          return Row(
            children: [
              ToneIcon(item.type.icon, tone: item.type.tone, size: 42),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.itemTitle),
                    Text(
                      '${item.headline} · Due ${shortDate(item.dueDate)}'
                      '${item.isRemedial ? ' · Remedial' : ''}',
                      style: AppText.meta.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              if (wide && item.type.isGraded) ...[
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${percent(rate)} submitted', style: AppText.meta.copyWith(fontSize: 12)),
                      const SizedBox(height: 4),
                      ProgressBar(value: rate, height: 7),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 70,
                  child: Text(item.averageScore == null ? '—' : 'Avg ${percent(item.averageScore)}',
                      style: AppText.meta.copyWith(fontSize: 12)),
                ),
              ],
              Pill(item.status.displayLabel, tone: item.status.tone),
              const SizedBox(width: 8),
              ClassworkMenu(item: item),
            ],
          );
        }),
      ),
    );
  }
}
