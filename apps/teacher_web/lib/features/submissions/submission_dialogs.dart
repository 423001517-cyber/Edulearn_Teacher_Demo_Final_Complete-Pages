import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../providers/core_providers.dart';
import '../../providers/submissions_providers.dart';
import '../stream/stream_widgets.dart';

enum ReminderKind {
  missing('Missing work reminder'),
  dueSoon('Due soon reminder'),
  encouragement('Encouragement'),
  general('General message');

  const ReminderKind(this.label);
  final String label;

  String message(ClassworkItem item) => switch (this) {
        ReminderKind.missing =>
          'Hi! Hindi pa naipapasa ang “${item.title}”. Paki-submit sa lalong madaling panahon.',
        ReminderKind.dueSoon => 'Paalala: ang “${item.title}” ay due sa ${fullDate(item.dueDate)}.',
        ReminderKind.encouragement => 'Kaya mo ’yan! Tapusin natin ang “${item.title}”.',
        ReminderKind.general => 'Mensahe tungkol sa “${item.title}”.',
      };
}

/// "Send reminder notification" side panel for one student.
Future<void> showReminderPanel(
  BuildContext context, {
  required Student student,
  required ClassworkItem item,
  required String className,
}) =>
    showSidePanel<void>(
      context: context,
      width: 440,
      builder: (_) => _ReminderPanel(student: student, item: item, className: className),
    );

class _ReminderPanel extends ConsumerStatefulWidget {
  const _ReminderPanel({required this.student, required this.item, required this.className});

  final Student student;
  final ClassworkItem item;
  final String className;

  @override
  ConsumerState<_ReminderPanel> createState() => _ReminderPanelState();
}

class _ReminderPanelState extends ConsumerState<_ReminderPanel> {
  late ReminderKind _kind = widget.item.dueDate.isBefore(DateTime.now()) ? ReminderKind.missing : ReminderKind.dueSoon;
  final _note = TextEditingController();
  bool _guardian = false;
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    final note = _note.text.trim();
    try {
      await ref.read(dashboardRepositoryProvider).sendReminder(
            studentId: widget.student.id,
            classId: widget.item.classId,
            classworkId: widget.item.id,
            message: note.isEmpty ? _kind.message(widget.item) : '${_kind.message(widget.item)}\n$note',
            kind: _kind.name,
            notifyGuardian: _guardian,
          );
      if (!mounted) return;
      Navigator.pop(context);
      showToast('Reminder sent to ${widget.student.name}');
    } catch (e) {
      if (mounted) setState(() => _sending = false);
      showToast('Couldn’t send: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget readOnly(String value) => InputDecorator(
          decoration: const InputDecoration(filled: true, fillColor: AppColors.chip),
          child: Text(value),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Row(children: [
                Expanded(child: Text('Send reminder notification', style: AppText.dialogTitle.copyWith(fontSize: 20))),
                IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                PersonAvatar(name: widget.student.name, size: 52),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.student.name, style: AppText.itemTitle.copyWith(fontSize: 17)),
                  Text(widget.className, style: AppText.meta),
                ]),
              ]),
              const SizedBox(height: 20),
              const FieldLabel('Notification type'),
              DropdownMenu<ReminderKind>(
                initialSelection: _kind,
                expandedInsets: EdgeInsets.zero,
                requestFocusOnTap: false,
                dropdownMenuEntries: [for (final k in ReminderKind.values) DropdownMenuEntry(value: k, label: k.label)],
                onSelected: (k) => setState(() => _kind = k ?? _kind),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Classwork'),
              readOnly(widget.item.title),
              const SizedBox(height: 14),
              const FieldLabel('Due date'),
              readOnly(fullDate(widget.item.dueDate)),
              const SizedBox(height: 14),
              TextField(
                controller: _note,
                minLines: 4,
                maxLines: 6,
                maxLength: 500,
                decoration: const InputDecoration(hintText: 'Add a short reminder note...'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _guardian,
                onChanged: (v) => setState(() => _guardian = v ?? false),
                title: const Text('Also notify parent/guardian'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(onPressed: _sending ? null : _send, child: const Text('Send reminder')),
            ),
          ]),
        ),
      ],
    );
  }
}

/// Reminders for every missing student of [item] at once.
Future<void> remindAllMissing(BuildContext context, WidgetRef ref, ClassworkItem item, List<SubmissionRow> rows) async {
  final missing = rows.where((r) => r.state == WorkState.missing).toList();
  if (missing.isEmpty) {
    showToast('Nobody is missing this one. 🎉');
    return;
  }
  final repo = ref.read(dashboardRepositoryProvider);
  final ok = await confirmAction(
    context,
    title: 'Remind ${missing.length} student${missing.length == 1 ? '' : 's'}?',
    message: 'Each one gets a missing-work reminder for “${item.title}”.',
    confirmLabel: 'Send reminders',
  );
  if (!ok) return;
  for (final r in missing) {
    await repo.sendReminder(
      studentId: r.student.id,
      classId: item.classId,
      classworkId: item.id,
      message: ReminderKind.missing.message(item),
      kind: ReminderKind.missing.name,
    );
  }
  showToast('Reminders sent to ${missing.length} student${missing.length == 1 ? '' : 's'}');
}

/// "Edit score": returns the new score or null.
Future<int?> showEditScoreDialog(BuildContext context, Submission s, int maxScore) {
  final c = TextEditingController(text: '${s.score ?? ''}');
  return showDialog<int>(
    context: context,
    builder: (ctx) => AppDialog(
      maxWidth: 380,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PanelHeader(title: 'Edit score', subtitle: s.studentName),
        const SizedBox(height: 14),
        TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(suffixText: '/ $maxScore'),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () {
                final n = int.tryParse(c.text);
                if (n == null || n < 0 || n > maxScore) {
                  showToast('Enter a score from 0 to $maxScore.');
                  return;
                }
                Navigator.pop(ctx, n);
              },
              child: const Text('Save'),
            ),
          ),
        ]),
      ]),
    ),
  );
}

/// "View submission history": what happened, in order.
Future<void> showHistoryDialog(BuildContext context, ClassworkItem item, SubmissionRow row) {
  final s = row.submission;
  final events = <(IconData, String, DateTime?)>[
    (Icons.assignment_outlined, 'Assigned', item.createdAt),
    (Icons.event_rounded, 'Due', item.dueDate),
    if (s != null) (Icons.upload_rounded, s.submittedAt.isAfter(item.dueDate) ? 'Turned in late' : 'Turned in', s.submittedAt),
    if (s != null && s.score != null && s.status == SubmissionStatus.pending) (Icons.edit_note_rounded, 'Draft grade ${s.score}/${s.maxScore}', null),
    if (s?.status == SubmissionStatus.returned) (Icons.check_circle_rounded, 'Returned${s!.score == null ? '' : ' · ${s.score}/${s.maxScore}'}', s.returnedAt),
  ]..sort((a, b) => (a.$3 ?? DateTime(2100)).compareTo(b.$3 ?? DateTime(2100)));
  return showDialog<void>(
    context: context,
    builder: (ctx) => AppDialog(
      maxWidth: 440,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PanelHeader(title: 'Submission history', subtitle: '${row.student.name} · ${item.title}'),
        const SizedBox(height: 10),
        for (final e in events)
          ListTile(
            leading: Icon(e.$1, color: AppColors.primary),
            title: Text(e.$2),
            subtitle: e.$3 == null ? null : Text(postTime(e.$3!)),
          ),
        if (s == null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('${row.student.name} hasn’t turned this in yet.', style: AppText.meta),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ),
      ]),
    ),
  );
}
