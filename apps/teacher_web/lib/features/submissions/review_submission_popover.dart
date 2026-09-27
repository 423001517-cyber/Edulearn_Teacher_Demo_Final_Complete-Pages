import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../providers/core_providers.dart';

/// Quick grading from the "To Review" list: score, private feedback, return.
class ReviewSubmissionPopover extends ConsumerStatefulWidget {
  const ReviewSubmissionPopover({super.key, required this.submission});

  final Submission submission;

  @override
  ConsumerState<ReviewSubmissionPopover> createState() => _ReviewSubmissionPopoverState();
}

class _ReviewSubmissionPopoverState extends ConsumerState<ReviewSubmissionPopover> {
  late final _score = TextEditingController(text: widget.submission.score?.toString() ?? '');
  late final _feedback = TextEditingController(text: widget.submission.privateFeedback);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _score.dispose();
    _feedback.dispose();
    super.dispose();
  }

  Future<void> _return() async {
    final s = widget.submission;
    int? score;
    if (_score.text.trim().isNotEmpty) {
      score = int.tryParse(_score.text.trim());
      if (score == null || score < 0 || score > s.maxScore) {
        setState(() => _error = 'Enter a score from 0 to ${s.maxScore}.');
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(dashboardRepositoryProvider)
          .returnSubmission(s.id, score: score, feedback: _feedback.text.trim());
      if (!mounted) return;
      Navigator.pop(context);
      showToast('Returned to ${s.studentName}');
    } catch (e) {
      setState(() {
        _saving = false;
        _error = "Couldn't return it: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.submission;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(
            title: s.studentName,
            subtitle: s.gradeLabel,
            leading: InitialsAvatar(initials: s.studentInitials, size: 56),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const ToneIcon(Icons.description_outlined, tone: Tone.blue, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(s.displayTitle,
                    style: AppText.meta.copyWith(fontSize: 13.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Text(dayMonth(s.submittedAt), style: AppText.meta.copyWith(fontSize: 13.5)),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider()),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FieldLabel('Score'),
                    TextField(
                      controller: _score,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(hintText: '__', suffixText: '/ ${s.maxScore}'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FieldLabel('Status'),
                    Pill(s.status.label,
                        tone: s.status == SubmissionStatus.pending ? Tone.amber : Tone.green,
                        large: true),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const FieldLabel('Private Feedback'),
          TextField(
            controller: _feedback,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(hintText: 'Write feedback for this student…'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : _return,
                  child: const Text('Return'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    goTo(Routes.section(NavSection.submissions, classId: s.classId));
                  },
                  child: const Text('Open Full Review'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
