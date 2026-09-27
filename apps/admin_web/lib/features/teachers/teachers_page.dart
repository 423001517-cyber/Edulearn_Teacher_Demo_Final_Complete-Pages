import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../providers/admin_providers.dart';
import '../classes/class_dialogs.dart';
import '../common/admin_widgets.dart';
import '../shell/top_bar.dart';
import 'teacher_dialogs.dart';

enum _StatusFilter { all, active, disabled }

/// `/teachers?teacher=` — teacher accounts and their classes.
class TeachersPage extends ConsumerStatefulWidget {
  const TeachersPage({super.key, this.openTeacherId});

  /// Opens this teacher's drawer on arrival (links from other pages).
  final String? openTeacherId;

  @override
  ConsumerState<TeachersPage> createState() => _TeachersPageState();
}

class _TeachersPageState extends ConsumerState<TeachersPage> {
  String _query = '';
  _StatusFilter _status = _StatusFilter.all;
  String? _opened;

  void _maybeOpen(Map<String, Teacher> byId) {
    final id = widget.openTeacherId;
    final t = id == null ? null : byId[id];
    if (t == null || _opened == id) return;
    _opened = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showTeacherPanel(context, t);
    });
  }

  @override
  Widget build(BuildContext context) {
    final teachers = ref.watch(teachersProvider);
    final classesBy = ref.watch(classesByTeacherProvider);
    _maybeOpen(ref.watch(teacherByIdProvider));
    final all = teachers.valueOrNull ?? const <Teacher>[];
    final q = _query.trim().toLowerCase();
    final shown = all.where((t) {
      if (_status == _StatusFilter.active && t.isDisabled) return false;
      if (_status == _StatusFilter.disabled && !t.isDisabled) return false;
      return q.isEmpty || '${t.displayName} ${t.email ?? ''}'.toLowerCase().contains(q);
    }).toList();
    final withoutClass = all.where((t) => !t.isDisabled && (classesBy[t.uid]?.isEmpty ?? true)).length;

    return PageScaffold(
      header: const AdminPageHeader(
        icon: Icons.badge_outlined,
        title: 'Teachers',
        subtitle: 'Teacher accounts and the classes assigned to them.',
      ),
      children: [
        ResponsiveGrid(
          children: [
            StatCard(
              icon: Icons.badge_outlined,
              tone: Tone.green,
              label: 'Active Teachers',
              value: teachers.whenData((l) => '${l.where((t) => !t.isDisabled).length}'),
              caption: 'Can sign in',
            ),
            StatCard(
              icon: Icons.menu_book_outlined,
              tone: Tone.amber,
              label: 'Without a Class',
              value: teachers.whenData((_) => '$withoutClass'),
              caption: 'Active teachers with no class yet',
            ),
            StatCard(
              icon: Icons.block_rounded,
              tone: Tone.red,
              label: 'Disabled',
              value: teachers.whenData((l) => '${l.where((t) => t.isDisabled).length}'),
              caption: 'Accounts turned off',
            ),
          ],
        ),
        Container(
          decoration: AppDecorations.card,
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(builder: (context, box) {
            final search = SearchField(
              hint: 'Search teachers by name or email...',
              onChanged: (v) => setState(() => _query = v),
            );
            final tools = Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilterDropdown<_StatusFilter>(
                  value: _status,
                  options: _StatusFilter.values,
                  labelOf: (s) => switch (s) {
                    _StatusFilter.all => 'All Statuses',
                    _StatusFilter.active => 'Active',
                    _StatusFilter.disabled => 'Disabled',
                  },
                  onChanged: (s) => setState(() => _status = s),
                ),
                FilledButton.icon(
                  onPressed: () => showAddTeacherDialog(context),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
                  label: const Text('Add Teacher'),
                ),
              ],
            );
            if (box.maxWidth < 760) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [search, const SizedBox(height: 10), tools],
              );
            }
            return Row(children: [Expanded(child: search), const SizedBox(width: 12), tools]);
          }),
        ),
        AsyncValueView<List<Teacher>>(
          value: teachers,
          loadingHeight: 240,
          data: (_) => AdminTable<Teacher>(
            noun: 'teachers',
            emptyMessage: all.isEmpty ? 'No teachers yet. Add your first teacher.' : 'No teachers match.',
            items: shown,
            columns: const [
              TableCol('Teacher', flex: 26),
              TableCol('Classes', flex: 26),
              TableCol('Students', flex: 9),
              TableCol('Joined', flex: 11),
              TableCol('Status', flex: 10),
              TableCol('', flex: 14),
            ],
            cells: (t) {
              final classes = classesBy[t.uid] ?? const <ClassRoom>[];
              return [
                PersonCell(name: t.displayName, subtitle: t.email ?? ''),
                classes.isEmpty
                    ? Text('No classes', style: AppText.meta)
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [for (final c in classes) Pill(c.name, tone: Tone.blue)],
                      ),
                Text('${classes.fold<int>(0, (n, c) => n + c.studentCount)}', style: AppText.body),
                Text(t.createdAt == null ? '—' : fullDate(t.createdAt!), style: AppText.meta),
                t.isDisabled
                    ? const Pill('Disabled', tone: Tone.red, dot: true)
                    : const Pill('Active', tone: Tone.green, dot: true),
                _TeacherActions(teacher: t),
              ];
            },
            compact: (t) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: PersonCell(name: t.displayName, subtitle: t.email ?? '')),
                    t.isDisabled
                        ? const Pill('Disabled', tone: Tone.red)
                        : const Pill('Active', tone: Tone.green),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  (classesBy[t.uid] ?? const <ClassRoom>[]).map((c) => c.name).join(', ').ifEmpty('No classes'),
                  style: AppText.meta,
                ),
                Align(alignment: Alignment.centerRight, child: _TeacherActions(teacher: t)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

class _TeacherActions extends ConsumerWidget {
  const _TeacherActions({required this.teacher});

  final Teacher teacher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = teacher;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(onPressed: () => showTeacherPanel(context, t), child: const Text('View')),
        const SizedBox(width: 6),
        MoreMenu<String>(
          items: [
            menuItem('class', Icons.add_rounded, 'Create class for teacher'),
            menuItem('link', Icons.key_rounded, 'Password setup link'),
            const PopupMenuDivider(),
            t.isDisabled
                ? menuItem('toggle', Icons.check_circle_outline, 'Enable account')
                : menuItem('toggle', Icons.block_rounded, 'Disable account', destructive: true),
          ],
          onSelected: (v) {
            switch (v) {
              case 'class':
                if (t.isDisabled) {
                  showToast('Enable ${t.firstName}’s account first.');
                } else {
                  showCreateClassDialog(context, teacherId: t.uid);
                }
              case 'link':
                sendPasswordLink(context, ref, t);
              case 'toggle':
                toggleTeacher(context, ref, t);
            }
          },
        ),
      ],
    );
  }
}
