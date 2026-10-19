import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../classwork/classwork_form_dialog.dart';

/// Opens the student drawer (Overview / Recent Activity, reminders,
/// remedial quests). Used from the Dashboard, class page, Quick View,
/// Students table and report panels.
Future<void> showStudentPanel(BuildContext context, Student student) => showSidePanel<void>(
      context: context,
      width: 400,
      builder: (_) => StudentSupportPanel(studentId: student.id, fallback: student),
    );

class StudentSupportPanel extends ConsumerWidget {
  const StudentSupportPanel({super.key, required this.studentId, required this.fallback});

  final String studentId;
  final Student fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Re-read from the live stream so numbers update while the panel is open.
    Student student = fallback;
    for (final s in ref.watch(studentsProvider).valueOrNull ?? const <Student>[]) {
      if (s.id == studentId) student = s;
    }
    final flag = student.supportFlag(DateTime.now());

    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PanelHeader(
              title: student.name,
              subtitle: [student.gradeLabel, student.numberLabel].where((s) => s.isNotEmpty).join(' · '),
              leading: InitialsAvatar(
                initials: student.initials,
                tone: flag?.level.tone ?? toneForName(student.name),
                size: 64,
                imageUrl: student.photoUrl,
              ),
            ),
            if (flag != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 78),
                  child: Pill(flag.label, tone: flag.level.tone, large: true),
                ),
              ),
            ],
            const SizedBox(height: 14),
            const TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.muted,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: AppColors.divider,
              tabs: [Tab(text: 'Overview'), Tab(text: 'Recent Activity')],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                children: [
                  SingleChildScrollView(child: _Overview(student: student)),
                  _RecentActivity(studentId: student.id),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => showSendReminder(context, student),
                    child: const Text('Send Reminder'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      goTo(Routes.messages(studentId: student.id));
                    },
                    child: const Text('Message'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                showClassworkForm(rootContext, type: ClassworkType.quest, assignTo: student);
              },
              child: const Text('Assign Remedial Quest'),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                goTo(Routes.students(classId: student.classId, studentId: student.id));
              },
              child: const Text('View Student Profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    final score = student.recentScore;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _Metric(
            icon: Icons.trending_up_rounded,
            tone: Tone.green,
            label: 'Quest Progress',
            value: student.questProgress,
          ),
          const SizedBox(height: 16),
          _Metric(
            icon: Icons.event_available_outlined,
            tone: Tone.blue,
            label: 'Attendance Rate',
            value: student.attendanceRate,
          ),
          const SizedBox(height: 16),
          _Metric(
            icon: Icons.bar_chart_rounded,
            tone: Tone.amber,
            label: 'Recent Score',
            value: score,
            barColor: score != null && score < Student.lowScoreThreshold
                ? const Color(0xFFF2A91E)
                : AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.tone,
    required this.label,
    required this.value,
    this.barColor = AppColors.primary,
  });

  final IconData icon;
  final Tone tone;
  final String label;
  final double? value;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ToneIcon(icon, tone: tone, size: 50, circle: true),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.meta.copyWith(fontSize: 13)),
              const SizedBox(height: 4),
              Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(percent(value),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: ProgressBar(value: value ?? 0, color: barColor)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentActivity extends ConsumerWidget {
  const _RecentActivity({required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<List<Submission>>(
      value: ref.watch(studentSubmissionsProvider(studentId)),
      data: (subs) {
        if (subs.isEmpty) return const EmptyNote('No submissions yet.');
        return ListView.separated(
          itemCount: subs.length,
          separatorBuilder: (_, i) => const Divider(),
          itemBuilder: (_, i) {
            final s = subs[i];
            final returned = s.status == SubmissionStatus.returned;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  ToneIcon(s.classworkType.icon, tone: s.classworkType.tone, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                        Text('Submitted ${dayMonth(s.submittedAt)}', style: AppText.meta),
                      ],
                    ),
                  ),
                  Pill(
                    returned && s.score != null ? '${s.score}/${s.maxScore}' : s.status.label,
                    tone: returned ? Tone.green : Tone.amber,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Reminder composer, delivered by the `deliverReminder` Cloud Function.
Future<void> showSendReminder(BuildContext context, Student student, {String? message}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final controller = TextEditingController(
    text: message ??
        (student.missingCount > 0
            ? 'Hi ${student.firstName}! You have ${student.missingCount} '
                '${student.missingCount == 1 ? 'quest' : 'quests'} waiting. Let’s finish them this week!'
            : 'Hi ${student.firstName}! Just checking in — keep up the good work this week.'),
  );
  final send = await showDialog<bool>(
    context: context,
    builder: (ctx) => AppDialog(
      maxWidth: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(title: 'Send Reminder', subtitle: 'To ${student.name}'),
          const SizedBox(height: 14),
          TextField(controller: controller, minLines: 3, maxLines: 5),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true), child: const Text('Send Reminder')),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  final text = controller.text.trim();
  controller.dispose();
  if (send != true || text.isEmpty) return;
  await container.read(dashboardRepositoryProvider).sendReminderTo(student, text);
  showToast('Reminder sent to ${student.name}');
}
