import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation.dart';
import '../../../providers/classes_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/data_providers.dart';

String newQuestionId() => 'q${DateTime.now().microsecondsSinceEpoch}';

QuizQuestion blankQuestion() => QuizQuestion(id: newQuestionId());

/// Quiz: every question as an editable card. Friday Boss ([compact]): a
/// numbered list; tap a row to edit it in a dialog.
class QuestionsEditor extends StatelessWidget {
  const QuestionsEditor({
    super.key,
    required this.questions,
    required this.onChanged,
    this.compact = false,
    this.withExplanations = false,
  });

  final List<QuizQuestion> questions;
  final ValueChanged<List<QuizQuestion>> onChanged;
  final bool compact;
  final bool withExplanations;

  void _replace(int i, QuizQuestion q) => onChanged([...questions]..[i] = q);

  void _move(int i, int by) {
    final list = [...questions];
    final q = list.removeAt(i);
    list.insert((i + by).clamp(0, list.length), q);
    onChanged(list);
  }

  /// Edits [start] in a dialog; returns the edited question or null.
  Future<QuizQuestion?> _questionDialog(BuildContext context, QuizQuestion start, int number) async {
    var draft = start;
    final saved = await showDialog<QuizQuestion>(
      context: context,
      builder: (ctx) => AppDialog(
        maxWidth: 680,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: QuestionCard(
                  question: draft,
                  number: number,
                  withExplanation: withExplanations,
                  onChanged: (q) => draft = q,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              const SizedBox(width: 12),
              FilledButton(onPressed: () => Navigator.pop(ctx, draft), child: const Text('Done')),
            ]),
          ],
        ),
      ),
    );
    return saved;
  }

  Future<void> _editInDialog(BuildContext context, int i) async {
    final saved = await _questionDialog(context, questions[i], i + 1);
    if (saved != null) _replace(i, saved);
  }

  Future<void> _add(BuildContext context) async {
    if (!compact) {
      onChanged([...questions, blankQuestion()]);
      return;
    }
    // Friday Boss list: write the new question first, add it on Done.
    final saved = await _questionDialog(context, blankQuestion(), questions.length + 1);
    if (saved != null) onChanged([...questions, saved]);
  }

  @override
  Widget build(BuildContext context) {
    final actions = Wrap(spacing: 12, runSpacing: 10, children: [
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          minimumSize: const Size(170, 50),
        ),
        onPressed: () => _add(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add question'),
      ),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size(170, 50)),
        onPressed: () async {
          final imported = await showImportQuestionsDialog(context);
          if (imported != null && imported.isNotEmpty) {
            onChanged([...questions, ...imported]);
            showToast('${imported.length} question${imported.length == 1 ? '' : 's'} imported');
          }
        },
        icon: Icon(compact ? Icons.account_balance_outlined : Icons.upload_file_outlined),
        label: Text(compact ? 'Import from quiz bank' : 'Import questions'),
      ),
    ]);

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text('Assessment questions', style: AppText.itemTitle)),
            Text('${questions.length} questions', style: AppText.meta),
          ]),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
            child: questions.isEmpty
                ? const Padding(padding: EdgeInsets.all(14), child: Text('No questions yet.'))
                : Column(children: [
                    for (var i = 0; i < questions.length; i++)
                      ListTile(
                        dense: true,
                        leading: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        title: Text(questions[i].text.isEmpty ? '(no question text yet)' : questions[i].text,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Pill('${questions[i].points} point${questions[i].points == 1 ? '' : 's'}', tone: Tone.neutral),
                          IconButton(
                            tooltip: 'Remove',
                            onPressed: () => onChanged([...questions]..removeAt(i)),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                        ]),
                        onTap: () => _editInDialog(context, i),
                      ),
                  ]),
          ),
          const SizedBox(height: 14),
          actions,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < questions.length; i++) ...[
          Container(
            decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.fromLTRB(16, 6, 6, 16),
            child: QuestionCard(
              key: ValueKey(questions[i].id),
              question: questions[i],
              number: i + 1,
              withExplanation: withExplanations,
              onChanged: (q) => _replace(i, q),
              menu: MoreMenu<String>(
                items: [
                  menuItem('dup', Icons.copy_rounded, 'Duplicate'),
                  if (i > 0) menuItem('up', Icons.arrow_upward_rounded, 'Move up'),
                  if (i < questions.length - 1) menuItem('down', Icons.arrow_downward_rounded, 'Move down'),
                  const PopupMenuDivider(),
                  menuItem('delete', Icons.delete_outline_rounded, 'Delete question', destructive: true),
                ],
                onSelected: (v) {
                  switch (v) {
                    case 'dup':
                      onChanged([...questions]..insert(i + 1, questions[i].copyWith().withId(newQuestionId())));
                    case 'up':
                      _move(i, -1);
                    case 'down':
                      _move(i, 1);
                    case 'delete':
                      onChanged([...questions]..removeAt(i));
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (questions.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: EmptyNote('No questions yet — add one or import from another quiz.', icon: Icons.quiz_outlined),
          ),
        actions,
      ],
    );
  }
}

extension on QuizQuestion {
  QuizQuestion withId(String newId) => QuizQuestion(
        id: newId,
        text: text,
        type: type,
        choices: choices,
        correctIndex: correctIndex,
        answer: answer,
        points: points,
        explanation: explanation,
      );
}

/// One question: text, type, choices (tap the circle to mark the correct
/// one), points, optional explanation.
class QuestionCard extends StatefulWidget {
  const QuestionCard({
    super.key,
    required this.question,
    required this.number,
    required this.onChanged,
    this.withExplanation = false,
    this.menu,
  });

  final QuizQuestion question;
  final int number;
  final ValueChanged<QuizQuestion> onChanged;
  final bool withExplanation;
  final Widget? menu;

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  late QuizQuestion _q = widget.question;
  late final _text = TextEditingController(text: _q.text);
  late final _answer = TextEditingController(text: _q.answer);
  late final _points = TextEditingController(text: '${_q.points}');
  late final _explanation = TextEditingController(text: _q.explanation);
  late List<TextEditingController> _choices = [for (final c in _q.choices) TextEditingController(text: c)];

  @override
  void dispose() {
    for (final c in [_text, _answer, _points, _explanation, ..._choices]) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit(QuizQuestion q) {
    _q = q;
    widget.onChanged(q);
  }

  void _setType(QuestionType t) {
    if (t == _q.type) return;
    for (final c in _choices) {
      c.dispose();
    }
    final choices = switch (t) {
      QuestionType.multipleChoice => _q.choices.length >= 2 && _q.type == QuestionType.multipleChoice
          ? _q.choices
          : const ['', '', '', ''],
      QuestionType.trueFalse => const ['Tama', 'Mali'],
      QuestionType.shortAnswer => const <String>[],
    };
    _choices = [for (final c in choices) TextEditingController(text: c)];
    setState(() => _emit(_q.copyWith(type: t, choices: choices, correctIndex: 0)));
  }

  void _choicesChanged() => _emit(_q.copyWith(choices: [for (final c in _choices) c.text]));

  @override
  Widget build(BuildContext context) {
    const letters = 'ABCDEFGH';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Icon(Icons.drag_handle_rounded, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(child: Text('Question ${widget.number}', style: AppText.itemTitle)),
          if (widget.menu != null) widget.menu!,
        ]),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, box) {
          final text = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const _Label('Question text', isRequired: true),
            TextField(
              controller: _text,
              maxLines: 3,
              minLines: 1,
              onChanged: (v) => _emit(_q.copyWith(text: v)),
            ),
          ]);
          final type = SizedBox(
            width: 190,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const _Label('Question type'),
              DropdownMenu<QuestionType>(
                initialSelection: _q.type,
                expandedInsets: EdgeInsets.zero,
                requestFocusOnTap: false,
                dropdownMenuEntries: [for (final t in QuestionType.values) DropdownMenuEntry(value: t, label: t.label)],
                onSelected: (t) => _setType(t ?? _q.type),
              ),
            ]),
          );
          if (box.maxWidth < 520) return Column(children: [text, const SizedBox(height: 10), type]);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: text),
            const SizedBox(width: 12),
            type,
          ]);
        }),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: _q.type == QuestionType.shortAnswer
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const _Label('Accepted answer', isRequired: true),
                    TextField(
                      controller: _answer,
                      decoration: const InputDecoration(hintText: 'e.g. pulo (not case-sensitive)'),
                      onChanged: (v) => _emit(_q.copyWith(answer: v)),
                    ),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    for (var i = 0; i < _choices.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          IconButton(
                            tooltip: 'Mark as the correct answer',
                            onPressed: () => setState(() => _emit(_q.copyWith(correctIndex: i))),
                            icon: Icon(
                              _q.correctIndex == i ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: _q.correctIndex == i ? AppColors.primary : AppColors.muted,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _choices[i],
                              readOnly: _q.type == QuestionType.trueFalse,
                              decoration: InputDecoration(prefixText: '${letters[i]}. ', isDense: true),
                              onChanged: (_) => _choicesChanged(),
                            ),
                          ),
                          if (_q.type == QuestionType.multipleChoice && _choices.length > 2)
                            IconButton(
                              tooltip: 'Remove choice',
                              onPressed: () => setState(() {
                                _choices.removeAt(i).dispose();
                                var correct = _q.correctIndex;
                                if (correct >= _choices.length || correct == i) correct = 0;
                                if (correct > i) correct--;
                                _emit(_q.copyWith(choices: [for (final c in _choices) c.text], correctIndex: correct));
                              }),
                              icon: const Icon(Icons.delete_outline_rounded, size: 20),
                            ),
                        ]),
                      ),
                    if (_q.type == QuestionType.multipleChoice && _choices.length < 6)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(() {
                            _choices.add(TextEditingController());
                            _choicesChanged();
                          }),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add choice'),
                        ),
                      ),
                  ]),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const _Label('Points', isRequired: true),
              TextField(
                controller: _points,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(prefixIcon: Icon(Icons.bar_chart_rounded, size: 18)),
                onChanged: (v) => _emit(_q.copyWith(points: int.tryParse(v) ?? 0)),
              ),
            ]),
          ),
        ]),
        if (widget.withExplanation) ...[
          const SizedBox(height: 6),
          const _Label('Explanation (shown after the attempt)'),
          TextField(
            controller: _explanation,
            maxLines: 2,
            minLines: 1,
            onChanged: (v) => _emit(_q.copyWith(explanation: v)),
          ),
        ],
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.isRequired = false});

  final String text;
  final bool isRequired;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          if (isRequired) const TextSpan(text: ' *', style: TextStyle(color: AppColors.red)),
        ])),
      );
}

/// "Import questions": copy the questions of any quiz or Friday Boss you made.
Future<List<QuizQuestion>?> showImportQuestionsDialog(BuildContext context) =>
    showDialog<List<QuizQuestion>>(context: context, builder: (_) => const _ImportDialog());

class _ImportDialog extends ConsumerStatefulWidget {
  const _ImportDialog();

  @override
  ConsumerState<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<_ImportDialog> {
  bool _loading = false;

  Future<void> _pick(ClassworkItem w) async {
    setState(() => _loading = true);
    final qs = await ref.read(classworkRepositoryProvider).loadQuestions(w.id);
    if (!mounted) return;
    Navigator.pop(context, [for (final q in qs) q.withId(newQuestionId())]);
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(classesProvider).valueOrNull ?? const <ClassRoom>[];
    final banks = <ClassworkItem>[
      for (final c in classes)
        ...(ref.watch(classClassworkProvider(c.id)).valueOrNull ?? const <ClassworkItem>[])
            .where((w) => w.type.hasQuestions && w.questionCount > 0),
    ];
    return AppDialog(
      maxWidth: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHeader(title: 'Import questions', subtitle: 'From your quizzes and Friday Boss assessments'),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (banks.isEmpty)
            const EmptyNote('No quizzes with questions yet.')
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: ListView(shrinkWrap: true, children: [
                for (final w in banks)
                  ListTile(
                    leading: ToneIcon(w.type.icon, tone: w.type.tone, size: 36, circle: true),
                    title: Text(w.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${w.className} · ${w.questionCount} questions'),
                    onTap: () => _pick(w),
                  ),
              ]),
            ),
        ],
      ),
    );
  }
}

/// "Preview": the questions as students will see them (no answers shown).
Future<void> showQuizPreview(BuildContext context, {required String title, required List<QuizQuestion> questions}) =>
    showDialog<void>(
      context: context,
      builder: (ctx) => AppDialog(
        maxWidth: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PanelHeader(title: title.isEmpty ? 'Preview' : title, subtitle: 'Student view · ${questions.length} questions'),
            const SizedBox(height: 10),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (var i = 0; i < questions.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${i + 1}. ${questions[i].text}', style: AppText.itemTitle),
                      const SizedBox(height: 6),
                      if (questions[i].type == QuestionType.shortAnswer)
                        const TextField(enabled: false, decoration: InputDecoration(hintText: 'Your answer'))
                      else
                        for (final c in questions[i].choices.where((c) => c.trim().isNotEmpty))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(children: [
                              const Icon(Icons.radio_button_unchecked_rounded, size: 20, color: AppColors.muted),
                              const SizedBox(width: 8),
                              Expanded(child: Text(c)),
                            ]),
                          ),
                    ]),
                  ),
              ]),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ),
          ],
        ),
      ),
    );
