import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../providers/dashboard_providers.dart';
import '../../classwork/classwork_details_popover.dart';
import '../../classwork/quick_create_dialog.dart';
import '../../students/student_support_panel.dart';
import '../../submissions/review_submission_popover.dart';

class QuickCreateBanner extends StatelessWidget {
  const QuickCreateBanner({super.key, this.classId});

  final String? classId;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryDeep,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showQuickCreate(context, classId: classId),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: const Icon(Icons.add_rounded, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quick Create',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                    const SizedBox(height: 2),
                    Text('Add a lesson, activity, quiz or announcement',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82), fontSize: 12.5)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keeps the row highlighted (blue outline) while its popover is open.
mixin _ActiveRow<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  String? activeId;

  Future<void> openPopover(BuildContext anchor, String id, WidgetBuilder builder, {double width = 340}) async {
    setState(() => activeId = id);
    await showAnchoredPopover<void>(context: anchor, width: width, builder: builder);
    if (mounted) setState(() => activeId = null);
  }
}

class _RowShell extends StatelessWidget {
  const _RowShell({required this.active, required this.onTap, required this.child});

  final bool active;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? AppColors.link : Colors.transparent, width: 1.4),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8), child: child),
        ),
      ),
    );
  }
}

class DateChip extends StatelessWidget {
  const DateChip(this.date, {super.key});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Text(monthAbbr(date).toUpperCase(),
              style: const TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.muted)),
          Text('${date.day}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class UpcomingCard extends ConsumerStatefulWidget {
  const UpcomingCard({super.key});

  @override
  ConsumerState<UpcomingCard> createState() => _UpcomingCardState();
}

class _UpcomingCardState extends ConsumerState<UpcomingCard> with _ActiveRow<UpcomingCard> {
  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.event_note_outlined,
      title: 'Upcoming',
      actionLabel: 'View calendar',
      onAction: () => context.go(NavSection.calendar.path),
      child: AsyncValueView<List<ClassworkItem>>(
        value: ref.watch(upcomingProvider),
        data: (list) {
          if (list.isEmpty) {
            return EmptyNote('Nothing scheduled. Plan your next quest.',
                actionLabel: 'Quick Create', onAction: () => showQuickCreate(context));
          }
          return Column(
            children: [
              for (final item in list.take(5))
                Builder(
                  builder: (rowContext) => _RowShell(
                    active: activeId == item.id,
                    onTap: () => openPopover(
                        rowContext, item.id, (_) => ClassworkDetailsPopover(item: item)),
                    child: LayoutBuilder(builder: (context, c) {
                      return Row(
                        children: [
                          DateChip(item.dueDate),
                          const SizedBox(width: 12),
                          ToneIcon(item.type.icon, tone: item.type.tone, size: 38),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.headline,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.itemTitle),
                                Text(item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.meta),
                              ],
                            ),
                          ),
                          if (c.maxWidth > 380) ...[
                            const SizedBox(width: 8),
                            Text(item.className, style: AppText.meta.copyWith(fontSize: 12)),
                          ],
                          const SizedBox(width: 8),
                          ClassworkMenu(item: item),
                        ],
                      );
                    }),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class ToReviewCard extends ConsumerStatefulWidget {
  const ToReviewCard({super.key});

  @override
  ConsumerState<ToReviewCard> createState() => _ToReviewCardState();
}

class _ToReviewCardState extends ConsumerState<ToReviewCard> with _ActiveRow<ToReviewCard> {
  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.assignment_outlined,
      title: 'To Review',
      actionLabel: 'View all',
      onAction: () => context.go(NavSection.submissions.path),
      child: AsyncValueView<List<Submission>>(
        value: ref.watch(visiblePendingSubmissionsProvider),
        data: (list) {
          if (list.isEmpty) return const EmptyNote('All caught up — nothing waiting for review.');
          return Column(
            children: [
              for (final s in list.take(4))
                Builder(
                  builder: (rowContext) {
                    void review() => openPopover(
                        rowContext, s.id, (_) => ReviewSubmissionPopover(submission: s),
                        width: 380);
                    return _RowShell(
                      active: activeId == s.id,
                      onTap: review,
                      child: LayoutBuilder(builder: (context, c) {
                        final wide = c.maxWidth > 400;
                        return Row(
                          children: [
                            const ToneIcon(Icons.description_outlined, tone: Tone.blue, size: 36),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.studentName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.itemTitle.copyWith(fontSize: 13.5)),
                                  Text(s.displayTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.meta.copyWith(fontSize: 12)),
                                ],
                              ),
                            ),
                            if (wide) ...[
                              Text(s.gradeLabel, style: AppText.meta.copyWith(fontSize: 12)),
                              const SizedBox(width: 10),
                            ],
                            const Pill('Pending', tone: Tone.amber),
                            if (wide) ...[
                              const SizedBox(width: 10),
                              Text(dayMonth(s.submittedAt),
                                  style: AppText.meta.copyWith(fontSize: 12)),
                            ],
                            const SizedBox(width: 8),
                            MoreMenu<String>(
                              items: [
                                menuItem('review', Icons.rate_review_outlined, 'Review'),
                                menuItem('student', Icons.person_outline_rounded, 'View student'),
                              ],
                              onSelected: (v) => v == 'review'
                                  ? review()
                                  : context.go(Routes.students(
                                      classId: s.classId, studentId: s.studentId)),
                            ),
                          ],
                        );
                      }),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class StudentsSupportCard extends ConsumerWidget {
  const StudentsSupportCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedClassIdProvider);
    return SectionCard(
      icon: Icons.groups_outlined,
      title: 'Students Needing Support',
      actionLabel: 'View all',
      onAction: () => context.go(Routes.students(classId: selected)),
      child: AsyncValueView<List<FlaggedStudent>>(
        value: ref.watch(studentsNeedingSupportProvider),
        data: (list) {
          if (list.isEmpty) return const EmptyNote('Everyone is on track right now.');
          const avatarTones = [Tone.red, Tone.blue, Tone.green];
          return Column(
            children: [
              for (var i = 0; i < list.length && i < 3; i++)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => showStudentPanel(context, list[i].student),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: LayoutBuilder(builder: (context, c) {
                      final s = list[i].student;
                      final flag = list[i].flag;
                      return Row(
                        children: [
                          InitialsAvatar(initials: s.initials, tone: avatarTones[i % 3], size: 38),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(s.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.itemTitle.copyWith(fontSize: 13.5)),
                          ),
                          Flexible(child: Pill(flag.label, tone: flag.level.tone)),
                          if (c.maxWidth > 380) ...[
                            const SizedBox(width: 12),
                            Text(s.gradeLabel, style: AppText.meta.copyWith(fontSize: 12)),
                          ],
                          const SizedBox(width: 8),
                          MoreMenu<String>(
                            items: [
                              menuItem('details', Icons.visibility_outlined, 'View details'),
                              menuItem('remind', Icons.send_outlined, 'Send reminder'),
                              menuItem('class', Icons.menu_book_outlined, 'Open class'),
                            ],
                            onSelected: (v) {
                              switch (v) {
                                case 'details':
                                  showStudentPanel(context, s);
                                case 'remind':
                                  showSendReminder(context, s);
                                case 'class':
                                  context.go(Routes.classDetail(s.classId, ClassTab.students));
                              }
                            },
                          ),
                        ],
                      );
                    }),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
