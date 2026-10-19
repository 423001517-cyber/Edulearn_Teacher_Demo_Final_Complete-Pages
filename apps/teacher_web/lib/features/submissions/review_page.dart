import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../providers/classwork_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/submissions_providers.dart';
import '../shell/top_bar.dart';
import '../stream/stream_widgets.dart';
import 'submission_dialogs.dart';
import 'submissions_page.dart' show StatePill;

/// `/submissions/review?item=&student=` — one student's work, scored and
/// returned with feedback.
class ReviewSubmissionPage extends ConsumerWidget {
  const ReviewSubmissionPage({super.key, required this.itemId, required this.studentId});

  final String itemId;
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<ClassworkItem?>(
      value: ref.watch(classworkItemProvider(itemId)),
      data: (item) {
        if (item == null) {
          return const PageScaffold(
            header: PageHeader(icon: Icons.wb_sunny_rounded, title: 'Submissions'),
            children: [EmptyNote('This classwork no longer exists.')],
          );
        }
        final rowsValue = ref.watch(itemRowsProvider((item.classId, item)));
        return AsyncValueView<List<SubmissionRow>>(
          value: rowsValue,
          data: (rows) {
            final i = rows.indexWhere((r) => r.student.id == studentId);
            if (i < 0) {
              return const PageScaffold(
                header: PageHeader(icon: Icons.wb_sunny_rounded, title: 'Submissions'),
                children: [EmptyNote('This student isn’t assigned this classwork.')],
              );
            }
            // Previous / Next move between students who turned something in.
            final handedIn = [for (final r in rows) if (r.submission != null) r.student.id];
            final at = handedIn.indexOf(studentId);
            String? prev = at > 0 ? handedIn[at - 1] : null;
            String? next = at >= 0 && at < handedIn.length - 1 ? handedIn[at + 1] : null;
            if (at < 0 && handedIn.isNotEmpty) next = handedIn.first;
            return _ReviewView(
              key: ValueKey('$itemId-$studentId'),
              item: item,
              row: rows[i],
              prevStudent: prev,
              nextStudent: next,
            );
          },
        );
      },
    );
  }
}

class _ReviewView extends ConsumerStatefulWidget {
  const _ReviewView({super.key, required this.item, required this.row, this.prevStudent, this.nextStudent});

  final ClassworkItem item;
  final SubmissionRow row;
  final String? prevStudent;
  final String? nextStudent;

  @override
  ConsumerState<_ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends ConsumerState<_ReviewView> {
  Submission? get _s => widget.row.submission;
  ClassworkItem get _item => widget.item;

  late final _score = TextEditingController(text: '${_s?.score ?? ''}');
  late final _feedback = TextEditingController(text: _s?.privateFeedback ?? '');
  late final Map<String, int> _rubric = {
    for (final c in _item.rubric) c.title: _s?.rubricScores[c.title] ?? c.points,
  };
  /// Starts from Settings › "Tell students when a grade is returned".
  late bool _notify = ref.read(preferencesProvider).notifyOnGrade;
  bool _saving = false;

  @override
  void dispose() {
    _score.dispose();
    _feedback.dispose();
    super.dispose();
  }

  int? get _scoreValue => int.tryParse(_score.text);

  void _bump(int by) {
    final n = ((_scoreValue ?? 0) + by).clamp(0, _item.points);
    setState(() => _score.text = '$n');
  }

  void _rubricChanged(String title, int v) => setState(() {
        _rubric[title] = v;
        _score.text = '${_rubric.values.fold<int>(0, (n, x) => n + x).clamp(0, _item.points)}';
      });

  Future<void> _save({required bool returnIt, bool next = false}) async {
    final s = _s;
    if (s == null) return;
    final score = _scoreValue;
    if (_score.text.isNotEmpty && (score == null || score > _item.points)) {
      showToast('Enter a score from 0 to ${_item.points}.');
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(submissionsRepositoryProvider);
    try {
      if (returnIt) {
        await repo.returnWork(s, score: score, feedback: _feedback.text.trim(), rubric: _rubric, notifyStudent: _notify);
      } else {
        await repo.saveDraft(s, score: score, feedback: _feedback.text.trim(), rubric: _rubric);
      }
      showToast(returnIt ? 'Returned to ${widget.row.student.name}' : 'Draft grade saved');
      if (next && widget.nextStudent != null) {
        goTo(Routes.reviewSubmission(_item.id, widget.nextStudent!));
      } else if (mounted) {
        setState(() => _saving = false);
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      showToast('Couldn’t save: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.row.student;
    final s = _s;
    return PageScaffold(
      header: PageHeader(
        icon: Icons.wb_sunny_rounded,
        title: 'Review submission',
        subtitle: 'Submissions / ${_item.title} / ${st.name}',
        leading: IconButton(
          tooltip: 'Back to submissions',
          onPressed: () => goTo(Routes.submissions(classId: _item.classId, item: _item.id)),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 10,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              PersonAvatar(name: st.name, size: 56),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(st.name, style: AppText.greeting.copyWith(fontSize: 22)),
                  const SizedBox(width: 10),
                  StatePill(widget.row.state),
                ]),
                Text(s == null ? 'Not turned in yet' : 'Submitted ${postTime(s.submittedAt)}', style: AppText.meta),
              ]),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              OutlinedButton.icon(
                onPressed: widget.prevStudent == null
                    ? null
                    : () => goTo(Routes.reviewSubmission(_item.id, widget.prevStudent!)),
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('Previous student'),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: widget.nextStudent == null
                    ? null
                    : () => goTo(Routes.reviewSubmission(_item.id, widget.nextStudent!)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Next student'),
                  SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded),
                ]),
              ),
            ]),
          ],
        ),
        TwoColumn(
          leftFlex: 7,
          rightFlex: 4,
          left: [_WorkViewer(submission: s, item: _item, studentName: st.name)],
          right: [s == null ? _missingCard(context) : _gradingCard()],
        ),
      ],
    );
  }

  Widget _missingCard(BuildContext context) => Container(
        decoration: AppDecorations.card,
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_item.title, style: AppText.itemTitle.copyWith(fontSize: 16)),
          Text('${_item.className} • ${_item.points} points', style: AppText.meta),
          const SizedBox(height: 16),
          const EmptyNote('Nothing to grade yet.', icon: Icons.hourglass_empty_rounded),
          FilledButton.icon(
            onPressed: () => showReminderPanel(context, student: widget.row.student, item: _item, className: _item.className),
            icon: const Icon(Icons.notifications_none_rounded),
            label: const Text('Send reminder'),
          ),
        ]),
      );

  Widget _gradingCard() {
    const radius = Radius.circular(10);
    return Container(
      decoration: AppDecorations.card,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_item.title, style: AppText.itemTitle.copyWith(fontSize: 16)),
          Text('${_item.className} • ${_item.points} points', style: AppText.meta),
          const Divider(height: 26),
          Row(children: [
            const Expanded(child: Text('Total score', style: TextStyle(fontWeight: FontWeight.w700))),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _score,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Text('/ ${_item.points}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Column(mainAxisSize: MainAxisSize.min, children: [
              InkWell(onTap: () => _bump(1), child: const Icon(Icons.keyboard_arrow_up_rounded)),
              InkWell(onTap: () => _bump(-1), child: const Icon(Icons.keyboard_arrow_down_rounded)),
            ]),
          ]),
          if (_item.rubric.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Rubric', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final c in _item.rubric)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Expanded(child: Text(c.title)),
                  DropdownButton<int>(
                    value: (_rubric[c.title] ?? c.points).clamp(0, c.points),
                    underline: const SizedBox.shrink(),
                    items: [for (var v = c.points; v >= 0; v--) DropdownMenuItem(value: v, child: Text('$v / ${c.points}'))],
                    onChanged: (v) => _rubricChanged(c.title, v ?? 0),
                  ),
                ]),
              ),
          ],
          const SizedBox(height: 14),
          const Text('Private feedback', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextField(
            controller: _feedback,
            minLines: 3,
            maxLines: 6,
            maxLength: 500,
            decoration: const InputDecoration(hintText: 'e.g. Magaling! Kumpleto at malinaw ang iyong mga sagot.'),
          ),
          Row(children: [
            Switch(value: _notify, onChanged: (v) => setState(() => _notify = v)),
            const SizedBox(width: 8),
            const Text('Notify student'),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(onPressed: _saving ? null : () => _save(returnIt: false), child: const Text('Save draft')),
            const SizedBox(width: 10),
            FilledButton(
              style: FilledButton.styleFrom(
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(left: radius)),
              ),
              onPressed: _saving ? null : () => _save(returnIt: true),
              child: const Text('Return'),
            ),
            Container(width: 1, height: 44, color: Colors.white.withValues(alpha: 0.4)),
            PopupMenuButton<String>(
              enabled: !_saving,
              tooltip: 'More return options',
              position: PopupMenuPosition.under,
              onSelected: (v) => _save(returnIt: true, next: v == 'next'),
              itemBuilder: (_) => [
                menuItem('return', Icons.undo_rounded, 'Return'),
                if (widget.nextStudent != null) menuItem('next', Icons.arrow_forward_rounded, 'Return & next'),
              ],
              child: Container(
                height: 44,
                width: 42,
                decoration: BoxDecoration(
                  color: _saving ? AppColors.buttonGrey : AppColors.primary,
                  borderRadius: const BorderRadius.horizontal(right: radius),
                ),
                child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

/// The student's work: an uploaded file, a typed answer, or nothing yet.
class _WorkViewer extends StatelessWidget {
  const _WorkViewer({required this.submission, required this.item, required this.studentName});

  final Submission? submission;
  final ClassworkItem item;
  final String studentName;

  @override
  Widget build(BuildContext context) {
    final s = submission;
    final url = s?.attachmentUrl;
    final name = s?.attachmentName ?? (url == null ? null : Uri.parse(url).pathSegments.lastOrNull ?? 'Attachment');
    final isImage = name != null && RegExp(r'\.(png|jpe?g|gif|webp)$', caseSensitive: false).hasMatch(name);
    return Container(
      decoration: AppDecorations.card,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (url != null) ...[
            Row(children: [
              Icon(isImage ? Icons.image_rounded : Icons.picture_as_pdf_rounded, color: isImage ? AppColors.purple : AppColors.red),
              const SizedBox(width: 10),
              Expanded(child: Text(name!, style: AppText.itemTitle, maxLines: 1, overflow: TextOverflow.ellipsis)),
              OutlinedButton.icon(
                onPressed: () => openUrl(url),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Open in new tab'),
              ),
            ]),
            const SizedBox(height: 14),
            if (isImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(url, fit: BoxFit.contain, errorBuilder: (context, error, stack) => const EmptyNote('Couldn’t load the image.')),
              )
            else
              Container(
                height: 320,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(10)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.description_outlined, size: 56, color: AppColors.muted),
                  const SizedBox(height: 10),
                  Text('$studentName’s file opens in a new tab.', style: AppText.meta),
                  const SizedBox(height: 12),
                  FilledButton.tonal(onPressed: () => openUrl(url), child: const Text('Open file')),
                ]),
              ),
          ],
          if ((s?.textResponse ?? '').isNotEmpty) ...[
            if (url != null) const SizedBox(height: 16),
            Text('Typed answer', style: AppText.itemTitle),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(10)),
              child: SelectableText(s!.textResponse, style: const TextStyle(height: 1.5)),
            ),
          ],
          if (s == null)
            EmptyNote('$studentName hasn’t turned in “${item.title}” yet.', icon: Icons.hourglass_empty_rounded)
          else if (url == null && s.textResponse.isEmpty)
            const EmptyNote(
              'No file or typed answer is attached to this submission (demo data). '
              'Students’ uploads appear here once the student app is in use.',
              icon: Icons.insert_drive_file_outlined,
            ),
        ],
      ),
    );
  }
}
