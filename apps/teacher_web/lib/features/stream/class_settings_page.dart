import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../providers/core_providers.dart';
import '../../providers/stream_providers.dart';
import '../shell/top_bar.dart';
import 'class_banner.dart';
import 'stream_page.dart';

/// `/stream/settings?classId=` — "Class settings".
class ClassSettingsPage extends ConsumerWidget {
  const ClassSettingsPage({super.key, this.classId});

  final String? classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<ClassRoom?>(
      value: ref.watch(streamClassProvider(classId)),
      data: (c) {
        if (c == null) {
          return const PageScaffold(
            header: PageHeader(icon: Icons.wb_sunny_rounded, title: 'Class settings'),
            children: [EmptyNote('No classes yet.')],
          );
        }
        return PageScaffold(
          header: PageHeader(
            icon: Icons.wb_sunny_rounded,
            title: 'Class settings',
            subtitle: 'Manage your class information and preferences.',
            actions: PageClassSelector(current: c, onChanged: (x) => goTo(Routes.classSettings(x.id))),
          ),
          // A fresh form per class, filled once from the saved settings.
          children: [_SettingsForm(key: ValueKey(c.id), classRoom: c)],
        );
      },
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({super.key, required this.classRoom});

  final ClassRoom classRoom;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final _subject = TextEditingController(text: widget.classRoom.subject);
  late final _room = TextEditingController(text: widget.classRoom.room);
  late final _points = TextEditingController(text: '${widget.classRoom.totalPoints}');
  late StreamPermission _permission = widget.classRoom.streamPermission;
  late ClassworkNotices _notices = widget.classRoom.classworkNotices;
  late bool _showGrade = widget.classRoom.showOverallGrade;
  bool _saving = false;
  bool _resetting = false;

  @override
  void dispose() {
    _subject.dispose();
    _room.dispose();
    _points.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(classesRepositoryProvider).saveClassSettings(
            widget.classRoom.id,
            subject: _subject.text,
            room: _room.text,
            streamPermission: _permission,
            classworkNotices: _notices,
            totalPoints: int.parse(_points.text),
            showOverallGrade: _showGrade,
          );
      showToast('Class settings saved');
    } catch (e) {
      showToast('Couldn’t save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetCode(ClassRoom c) async {
    final repo = ref.read(classesRepositoryProvider);
    final ok = await confirmAction(
      context,
      title: 'Reset the class code?',
      message: '${c.classCode} will stop working for new students. Students already in the class '
          'stay enrolled. Share the new code with anyone who still needs to join.',
      confirmLabel: 'Reset code',
    );
    if (!ok) return;
    setState(() => _resetting = true);
    try {
      final code = await repo.resetClassCode(c.id);
      showToast(code.isEmpty ? 'Class code reset' : 'New class code: $code');
    } catch (e) {
      showToast('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Live copy (the code changes after a reset).
    final c = ref.watch(streamClassProvider(widget.classRoom.id)).valueOrNull ?? widget.classRoom;

    final general = _Card(
      icon: Icons.settings_outlined,
      title: 'General',
      subtitle: 'Basic information about your class.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Pair(
            left: _ReadOnly(label: 'Class name', value: c.name),
            right: _ReadOnly(label: 'Section', value: c.section),
          ),
          const SizedBox(height: 14),
          _Pair(
            left: _Field(
              label: 'Subject',
              child: TextFormField(
                controller: _subject,
                maxLength: 80,
                decoration: const InputDecoration(counterText: ''),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Add a subject.' : null,
              ),
            ),
            right: _Field(
              label: 'Room',
              child: TextFormField(
                controller: _room,
                maxLength: 60,
                decoration: const InputDecoration(hintText: 'e.g. Grade 4 Room', counterText: ''),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const FieldLabel('Class code'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                width: 220,
                height: 48,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(10)),
                child: Text(c.classCode, style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.4)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
                onPressed: () => copyCode(c),
                icon: const Icon(Icons.content_copy_rounded, size: 18),
                label: const Text('Copy code'),
              ),
              OutlinedButton(
                onPressed: _resetting ? null : () => _resetCode(c),
                child: Text(_resetting ? 'Resetting…' : 'Reset code'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Class name and section are official and set by your administrator.',
                    style: AppText.meta.copyWith(fontSize: 12.5)),
              ),
            ],
          ),
        ],
      ),
    );

    final permissions = _Card(
      icon: Icons.forum_outlined,
      title: 'Stream permissions',
      subtitle: 'Control who can post and comment in the class stream.',
      child: Column(
        children: [
          for (final p in StreamPermission.values)
            _Choice(label: p.label, selected: _permission == p, onTap: () => setState(() => _permission = p)),
        ],
      ),
    );

    final notices = _Card(
      icon: Icons.notifications_none_rounded,
      title: 'Classwork notifications',
      subtitle: 'Choose how classwork notifications appear to students.',
      child: DropdownMenu<ClassworkNotices>(
        initialSelection: _notices,
        expandedInsets: EdgeInsets.zero,
        requestFocusOnTap: false,
        dropdownMenuEntries: [
          for (final n in ClassworkNotices.values) DropdownMenuEntry(value: n, label: n.label),
        ],
        onSelected: (n) => setState(() => _notices = n ?? _notices),
      ),
    );

    final grading = _Card(
      icon: Icons.bar_chart_rounded,
      title: 'Grading',
      subtitle: 'Manage grading preferences for this class.',
      child: Wrap(
        spacing: 24,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Total points', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 14),
              SizedBox(
                width: 96,
                child: TextFormField(
                  controller: _points,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return n == null || n < 1 || n > 1000 ? '1–1000' : null;
                  },
                ),
              ),
            ],
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(value: _showGrade, onChanged: (v) => setState(() => _showGrade = v)),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Show overall grade to students', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('Students can see their overall grade in Gradebook.',
                          style: AppText.meta.copyWith(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Text('Total points is the default for new graded classwork in this class.',
              style: AppText.meta.copyWith(fontSize: 12)),
        ],
      ),
    );

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TwoColumn(
            leftFlex: 1,
            rightFlex: 1,
            left: [
              Container(
                decoration: AppDecorations.card,
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: AppText.greeting.copyWith(fontSize: 26)),
                    const SizedBox(height: 4),
                    Text('Update your class settings, permissions, and preferences.', style: AppText.meta),
                  ],
                ),
              ),
              general,
            ],
            right: [permissions, notices, grading],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => goTo(Routes.stream(classId: c.id)),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              FilledButton(onPressed: _saving ? null : _save, child: const Text('Save changes')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.title, required this.subtitle, required this.child});

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: AppDecorations.card,
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 26, color: AppColors.ink),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: AppText.itemTitle.copyWith(fontSize: 16)),
                  Text(subtitle, style: AppText.meta.copyWith(fontSize: 13)),
                  const SizedBox(height: 14),
                  child,
                ],
              ),
            ),
          ],
        ),
      );
}

/// Two fields side by side, stacked on narrow screens.
class _Pair extends StatelessWidget {
  const _Pair({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 420) {
          return Column(children: [left, const SizedBox(height: 14), right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: left), const SizedBox(width: 14), Expanded(child: right)],
        );
      });
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [FieldLabel(label), child],
      );
}

class _ReadOnly extends StatelessWidget {
  const _ReadOnly({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => _Field(
        label: label,
        child: Tooltip(
          message: 'Set by your administrator',
          child: InputDecorator(
            decoration: const InputDecoration(
              suffixIcon: Icon(Icons.lock_outline_rounded, size: 18),
              filled: true,
              fillColor: AppColors.chip,
            ),
            child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      );
}

/// A radio-style choice row.
class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        inMutuallyExclusiveGroup: true,
        checked: selected,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                  color: selected ? AppColors.primary : AppColors.muted,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
              ],
            ),
          ),
        ),
      );
}
