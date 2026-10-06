import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../providers/admin_providers.dart';
import '../../providers/core_providers.dart';
import '../classes/class_dialogs.dart';
import '../common/admin_widgets.dart';

/// One class request with Approve / Decline (used on the Dashboard and the
/// Class Requests page).
class RequestCard extends ConsumerWidget {
  const RequestCard({super.key, required this.request, this.dense = false});

  final ClassRequest request;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = request;
    final teacher = ref.watch(teacherByIdProvider)[r.teacherId];
    final createdClass = r.classId == null ? null : ref.watch(classByIdProvider)[r.classId];
    final name = teacher?.displayName ?? 'A teacher';

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(TextSpan(children: [
          TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.w700)),
          const TextSpan(text: ' requested '),
          TextSpan(text: r.className, style: const TextStyle(fontWeight: FontWeight.w700)),
        ])),
        const SizedBox(height: 2),
        Text(
          '${r.subject}${r.createdAt == null ? '' : ' · ${timeAgo(r.createdAt!)}'}',
          style: AppText.meta.copyWith(fontSize: 12.5),
        ),
        if (r.note.isNotEmpty && !dense) ...[
          const SizedBox(height: 6),
          Text('“${r.note}”', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
        ],
        if (r.status == RequestStatus.declined && r.decisionNote.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Reason: ${r.decisionNote}', style: AppText.meta.copyWith(color: AppColors.red)),
        ],
      ],
    );

    final trailing = switch (r.status) {
      RequestStatus.pending => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(onPressed: () => showDeclineDialog(context, r, name), child: const Text('Decline')),
            FilledButton(onPressed: () => showApproveDialog(context, r), child: const Text('Approve')),
          ],
        ),
      RequestStatus.approved => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Pill('Approved', tone: Tone.green, dot: true),
            if (createdClass != null) ...[const SizedBox(width: 8), CodeChip(createdClass.classCode)],
          ],
        ),
      RequestStatus.declined => const Pill('Declined', tone: Tone.red, dot: true),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(builder: (context, box) {
        final avatar = InitialsAvatar(
          initials: teacher?.initials ?? '?',
          tone: toneForName(name),
          size: dense ? 38 : 44,
        );
        if (box.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                avatar,
                const SizedBox(width: 12),
                Expanded(child: details),
              ]),
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerRight, child: trailing),
            ],
          );
        }
        return Row(
          children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(child: details),
            const SizedBox(width: 12),
            trailing,
          ],
        );
      }),
    );
  }
}

/// Approve — the admin can adjust the grade, section, subject or teacher.
Future<void> showApproveDialog(BuildContext context, ClassRequest r) =>
    showDialog<void>(context: context, builder: (_) => _ApproveDialog(request: r));

class _ApproveDialog extends ConsumerStatefulWidget {
  const _ApproveDialog({required this.request});

  final ClassRequest request;

  @override
  ConsumerState<_ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends ConsumerState<_ApproveDialog> {
  late final _section = TextEditingController(text: widget.request.section);
  late final _subject = TextEditingController(text: widget.request.subject);
  late int _grade = widget.request.gradeLevel;
  late String? _teacherId = widget.request.teacherId;
  bool _saving = false;

  @override
  void dispose() {
    _section.dispose();
    _subject.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    if (_section.text.trim().isEmpty || _subject.text.trim().isEmpty || _teacherId == null) {
      showToast('Fill in the section, subject and teacher.');
      return;
    }
    setState(() => _saving = true);
    final code = await runAdminAction(() => ref.read(adminFunctionsProvider).approveClassRequest(
          widget.request.id,
          gradeLevel: _grade,
          section: _section.text,
          subject: _subject.text,
          teacherId: _teacherId,
        ));
    if (!mounted) return;
    if (code == null) {
      setState(() => _saving = false);
      return;
    }
    Navigator.pop(context);
    showClassCreated('Grade $_grade – ${_section.text.trim()}', code);
  }

  @override
  Widget build(BuildContext context) {
    final teachers = ref.watch(teachersProvider).valueOrNull ?? const <Teacher>[];
    return AppDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHeader(
            title: 'Approve class request',
            subtitle: 'Creates the class and issues its official code',
            leading: ToneIcon(Icons.check_rounded, tone: Tone.green, size: 46, circle: true),
          ),
          if (widget.request.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(10)),
              child: Text('Teacher’s note: “${widget.request.note}”'),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FieldLabel('Grade'),
                    GradePicker(value: _grade, onChanged: (g) => setState(() => _grade = g)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [const FieldLabel('Section'), TextField(controller: _section)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const FieldLabel('Subject'),
          TextField(controller: _subject),
          const SizedBox(height: 14),
          const FieldLabel('Teacher'),
          TeacherPicker(teachers: teachers, value: _teacherId, onChanged: (v) => setState(() => _teacherId = v)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _approve,
                  child: const Text('Approve & create class'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Decline with an optional reason (sent to the teacher as a notification).
Future<void> showDeclineDialog(BuildContext context, ClassRequest r, String teacherName) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final note = await showDialog<String>(
    context: context,
    builder: (_) => _DeclineDialog(request: r, teacherName: teacherName),
  );
  if (note == null) return;
  await attempt(
    () => container.read(adminFunctionsProvider).declineClassRequest(r.id, note),
    success: 'Request declined — $teacherName has been notified',
  );
}

/// Returns the reason (possibly empty) or null when cancelled. Owns its text
/// field so it's disposed only after the closing animation.
class _DeclineDialog extends StatefulWidget {
  const _DeclineDialog({required this.request, required this.teacherName});

  final ClassRequest request;
  final String teacherName;

  @override
  State<_DeclineDialog> createState() => _DeclineDialogState();
}

class _DeclineDialogState extends State<_DeclineDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      maxWidth: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(
            title: 'Decline ${widget.request.className}?',
            subtitle: 'Requested by ${widget.teacherName}',
          ),
          const SizedBox(height: 14),
          const FieldLabel('Reason (sent to the teacher)'),
          TextField(
            controller: _reason,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'e.g. This section was merged with Rizal.'),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.red),
                  onPressed: () => Navigator.pop(context, _reason.text),
                  child: const Text('Decline request'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
