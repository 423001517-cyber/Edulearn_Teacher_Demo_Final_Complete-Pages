import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../students/student_support_panel.dart';
import 'messages_page.dart' show ConversationAvatar;

/// Right-hand details: the student's progress, or the class group's options.
class MessageInfoPane extends ConsumerWidget {
  const MessageInfoPane({super.key, required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = conversation;
    final cls = ref.watch(classByIdProvider)[c.classId];
    Student? student;
    for (final s in ref.watch(studentsProvider).valueOrNull ?? const <Student>[]) {
      if (s.id == c.studentId) student = s;
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: c.isGroup ? _group(ref, c, cls) : _student(context, ref, c, cls, student),
    );
  }

  Widget _heading(Conversation c, String subtitle) => Column(
        children: [
          ConversationAvatar(conversation: c, size: 64),
          const SizedBox(height: 10),
          Text(c.title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 2),
          Text(subtitle, textAlign: TextAlign.center, style: AppText.meta.copyWith(fontSize: 12.5)),
        ],
      );

  Widget _student(BuildContext context, WidgetRef ref, Conversation c, ClassRoom? cls, Student? s) {
    final recent = s == null ? null : ref.watch(studentSubmissionsProvider(s.id)).valueOrNull;
    Widget stat(String value, String label, {Color? color}) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color ?? AppColors.ink)),
                const SizedBox(height: 2),
                Text(label, style: AppText.meta.copyWith(fontSize: 11)),
              ],
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(c, '${cls?.name ?? 'Student'} · Student'),
        if (s != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              stat(percent(s.averageScore), 'Average'),
              const SizedBox(width: 8),
              stat('${s.missingCount}', 'Missing', color: s.missingCount > 0 ? AppColors.red : AppColors.primary),
              const SizedBox(width: 8),
              stat(percent(s.attendanceRate), 'Attendance'),
            ],
          ),
          if (s.supportFlag(DateTime.now()) case final flag?) ...[
            const SizedBox(height: 12),
            Center(child: Pill(flag.label, tone: flag.level.tone)),
          ],
          const SizedBox(height: 18),
          const Text('Recent work', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          const SizedBox(height: 4),
          if (recent == null || recent.isEmpty)
            const EmptyNote('Nothing turned in yet.')
          else
            for (final sub in recent.take(4))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(sub.displayTitle,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      sub.status == SubmissionStatus.returned && sub.score != null
                          ? '${sub.score}/${sub.maxScore}'
                          : sub.status.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: sub.status == SubmissionStatus.returned ? AppColors.primary : const Color(0xFF8A5700),
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 18),
          OutlinedButton(onPressed: () => showStudentPanel(context, s), child: const Text('View student profile')),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => goTo(Routes.gradebook(classId: s.classId)),
            child: const Text('Open in Gradebook'),
          ),
        ] else ...[
          const SizedBox(height: 16),
          const EmptyNote('This student is no longer on your class lists.'),
        ],
      ],
    );
  }

  Widget _group(WidgetRef ref, Conversation c, ClassRoom? cls) {
    final repo = ref.read(messagesRepositoryProvider);
    Future<void> update({bool? reply, bool? quiet}) async {
      try {
        await repo.updateGroup(c, studentsCanReply: reply, quietHours: quiet);
      } catch (e) {
        showToast('Couldn’t save: $e');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(c, 'Class group · ${cls?.studentCount ?? 0} students'),
        const SizedBox(height: 16),
        SwitchRow(
          label: 'Students can reply',
          hint: 'Off = only you can post here.',
          value: c.studentsCanReply,
          onChanged: (v) => update(reply: v),
        ),
        SwitchRow(
          label: 'Quiet hours',
          hint: 'Students can’t send messages from 8 PM to 6 AM.',
          value: c.quietHours,
          onChanged: (v) => update(quiet: v),
        ),
        const SizedBox(height: 10),
        Text(
          'Every student in the class sees these messages in the EduLearn app. '
          'For something students should find later, post it to the Stream instead.',
          style: AppText.meta.copyWith(fontSize: 12.5, height: 1.45),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => goTo(Routes.stream(classId: c.classId)),
          child: const Text('Post to Stream instead'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => goTo(Routes.students(classId: c.classId)),
          child: const Text('View students'),
        ),
      ],
    );
  }
}
