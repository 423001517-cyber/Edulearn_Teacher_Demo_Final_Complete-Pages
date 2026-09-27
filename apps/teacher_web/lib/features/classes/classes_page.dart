import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../providers/classes_providers.dart';
import '../../providers/data_providers.dart';
import '../shell/top_bar.dart';
import 'widgets/class_actions.dart';
import 'widgets/class_card.dart';
import 'widgets/class_dialogs.dart';

/// `/classes` — every class assigned to the teacher.
class ClassesPage extends ConsumerWidget {
  const ClassesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const PageScaffold(
      header: PageHeader(
        icon: Icons.menu_book_outlined,
        title: 'Classes',
        subtitle: 'View and manage your assigned classes.',
      ),
      children: [_ClassesStats(), _Toolbar(), _ClassesBody(), _ArchivedSection()],
    );
  }
}

class _ClassesStats extends ConsumerWidget {
  const _ClassesStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeClassesProvider);
    final activeIds = {for (final c in active.valueOrNull ?? const <ClassRoom>[]) c.id};
    final missing = ref.watch(missingByClassProvider);
    final missingTotal =
        missing.entries.where((e) => activeIds.contains(e.key)).fold<int>(0, (a, e) => a + e.value);

    return ResponsiveGrid(
      children: [
        StatCard(
          icon: Icons.menu_book_outlined,
          tone: Tone.green,
          label: 'Active Classes',
          value: active.whenData((l) => '${l.length}'),
          caption: 'Classes currently active',
          watermark: Icons.groups_outlined,
        ),
        StatCard(
          icon: Icons.groups_rounded,
          tone: Tone.blue,
          label: 'Total Students',
          value: active.whenData((l) => '${l.fold<int>(0, (a, c) => a + c.studentCount)}'),
          caption: 'Across all classes',
          watermark: Icons.groups_outlined,
          onTap: () => context.go(Routes.students()),
        ),
        StatCard(
          icon: Icons.bar_chart_rounded,
          tone: Tone.amber,
          label: 'Average Completion',
          value: active.whenData((l) => l.isEmpty
              ? '—'
              : percent(l.fold<double>(0, (a, c) => a + c.completionRate) / l.length)),
          caption: 'Average across all classes',
          watermark: Icons.bar_chart_rounded,
        ),
        StatCard(
          icon: Icons.priority_high_rounded,
          tone: Tone.red,
          label: 'Missing Work',
          value: active.whenData((_) => '$missingTotal'),
          caption: 'Students behind',
          watermark: Icons.person_outline_rounded,
          onTap: () => context.go(Routes.students()),
        ),
      ],
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(classesFilterProvider);
    final grades = ref.watch(gradeLevelsProvider);
    void update(ClassesFilter Function(ClassesFilter) change) =>
        ref.read(classesFilterProvider.notifier).update(change);

    final filters = Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilterDropdown<int?>(
          value: f.grade,
          options: [null, ...grades],
          labelOf: (g) => g == null ? 'All Grades' : 'Grade $g',
          onChanged: (g) => update((x) => x.copyWith(grade: () => g)),
        ),
        FilterDropdown<ClassListStatus>(
          value: f.status,
          options: ClassListStatus.values,
          labelOf: (s) => s.label,
          onChanged: (s) => update((x) => x.copyWith(status: s)),
        ),
        FilterDropdown<ClassSort>(
          value: f.sort,
          options: ClassSort.values,
          prefix: 'Sort: ',
          labelOf: (s) => s.label,
          onChanged: (s) => update((x) => x.copyWith(sort: s)),
        ),
        _ViewToggle(
          value: f.view,
          onChanged: (v) => update((x) => x.copyWith(view: v)),
        ),
        FilledButton.icon(
          onPressed: () => showRequestClassDialog(context),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('Request New Class'),
        ),
      ],
    );

    return Container(
      decoration: AppDecorations.card,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(builder: (context, c) {
            final search = SearchField(
              hint: 'Search classes...',
              initialValue: f.query,
              onChanged: (q) => update((x) => x.copyWith(query: q)),
            );
            if (c.maxWidth < 1100) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [search, const SizedBox(height: 10), filters],
              );
            }
            return Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: 12),
                filters,
              ],
            );
          }),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Official classes and class codes are approved by the administrator.',
                    style: AppText.meta.copyWith(fontSize: 12.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.value, required this.onChanged});

  final ClassViewMode value;
  final ValueChanged<ClassViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget button(ClassViewMode mode, IconData icon, String tip) {
      final selected = value == mode;
      return Tooltip(
        message: tip,
        child: Material(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onChanged(mode),
            child: SizedBox(
              width: 40,
              height: 36,
              child: Icon(icon, size: 20, color: selected ? Colors.white : AppColors.inkSoft),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.buttonBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(ClassViewMode.grid, Icons.grid_view_rounded, 'Grid view'),
          button(ClassViewMode.list, Icons.view_list_rounded, 'List view'),
        ],
      ),
    );
  }
}

class _ClassesBody extends ConsumerWidget {
  const _ClassesBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(classesFilterProvider);
    final missing = ref.watch(missingByClassProvider);
    return AsyncValueView<List<ClassRoom>>(
      value: ref.watch(filteredClassesProvider),
      loadingHeight: 300,
      data: (list) {
        if (list.isEmpty) {
          return Container(
            decoration: AppDecorations.card,
            child: EmptyNote(
              f.query.isNotEmpty || f.grade != null
                  ? 'No classes match your filters.'
                  : f.status == ClassListStatus.archived
                      ? 'No archived classes.'
                      : 'No classes assigned yet. Ask your administrator, or send a request.',
              icon: Icons.menu_book_outlined,
              actionLabel: f.query.isNotEmpty || f.grade != null ? 'Clear filters' : 'Request New Class',
              onAction: () {
                if (f.query.isNotEmpty || f.grade != null) {
                  ref.read(classesFilterProvider.notifier).state =
                      ClassesFilter(view: f.view, status: f.status);
                } else {
                  showRequestClassDialog(context);
                }
              },
            ),
          );
        }
        if (f.view == ClassViewMode.list) {
          return Column(
            children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                ClassListTile(classRoom: list[i], missing: missing[list[i].id] ?? 0),
              ],
            ],
          );
        }
        return ResponsiveGrid(
          minItemWidth: 330,
          maxColumns: 3,
          children: [
            for (final c in list) ClassCard(classRoom: c, missing: missing[c.id] ?? 0),
          ],
        );
      },
    );
  }
}

/// "Archived Classes (1)" collapsible at the bottom (hidden when the status
/// filter already shows archived classes).
class _ArchivedSection extends ConsumerStatefulWidget {
  const _ArchivedSection();

  @override
  ConsumerState<_ArchivedSection> createState() => _ArchivedSectionState();
}

class _ArchivedSectionState extends ConsumerState<_ArchivedSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(classesFilterProvider.select((f) => f.status));
    final archived = ref.watch(archivedClassesProvider).valueOrNull ?? const <ClassRoom>[];
    if (status != ClassListStatus.active || archived.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: AppDecorations.card,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const Icon(Icons.archive_outlined, color: AppColors.ink),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Archived Classes (${archived.length})',
                        style: AppText.sectionTitle.copyWith(fontSize: 15.5)),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            for (final c in archived) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Opacity(
                      opacity: 0.7,
                      child: ClassThumbnail(classRoom: c, width: 72, height: 48),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name, style: AppText.itemTitle),
                          Text('${c.subject} · ${c.studentCount} students · ${c.classCode}',
                              style: AppText.meta),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => context.go(Routes.classDetail(c.id)),
                      child: const Text('View'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => runClassAction(context, ref, c, ClassAction.restore),
                      child: const Text('Restore'),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}
