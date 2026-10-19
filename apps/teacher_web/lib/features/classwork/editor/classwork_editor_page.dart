import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/navigation.dart';
import '../../../providers/classwork_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../shell/top_bar.dart';
import '../../stream/stream_composer.dart' show showScheduleDialog;
import '../classwork_dialogs.dart';
import 'editor_fields.dart';
import 'question_builder.dart';
import 'type_widgets.dart';

/// `/classwork/new?type=&classId=&studentId=` and `/classwork/edit/:id` —
/// Create / Edit lesson, quest, activity, quiz, Friday Boss or material.
class ClassworkEditorPage extends ConsumerWidget {
  const ClassworkEditorPage({super.key, this.type, this.classId, this.studentId, this.itemId});

  final ClassworkType? type;
  final String? classId;
  final String? studentId;
  final String? itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = itemId;
    if (id == null) {
      final t = type ?? ClassworkType.quest;
      return _EditorShell(
        type: t,
        editing: false,
        child: _EditorForm(
          key: ValueKey('new-${t.name}-$classId'),
          type: t,
          classId: classId ?? ref.watch(selectedClassIdProvider),
          studentId: studentId,
        ),
      );
    }
    return AsyncValueView<ClassworkItem?>(
      value: ref.watch(classworkItemProvider(id)),
      data: (item) {
        if (item == null) {
          return const PageScaffold(
            header: PageHeader(icon: Icons.wb_sunny_rounded, title: 'Classwork'),
            children: [EmptyNote('This classwork no longer exists.')],
          );
        }
        return _EditorShell(
          type: item.type,
          editing: true,
          child: _QuestionsLoader(item: item),
        );
      },
    );
  }
}

class _EditorShell extends StatelessWidget {
  const _EditorShell({required this.type, required this.editing, required this.child});

  final ClassworkType type;
  final bool editing;
  final Widget child;

  static String subtitle(ClassworkType t) => switch (t) {
        ClassworkType.lesson => 'Create an instructional lesson with content, media, and learning objectives.',
        ClassworkType.quest => 'Create a quest with instructions, points, and game settings.',
        ClassworkType.activity => 'Create a class activity with submission settings and a rubric.',
        ClassworkType.quiz => 'Create a quiz with questions, choices, and automatic grading.',
        ClassworkType.boss => 'Create a Friday Boss assessment with questions, points, and game settings.',
        ClassworkType.material => 'Create a class material with content, media, and learning resources.',
      };

  @override
  Widget build(BuildContext context) {
    final noun = type == ClassworkType.boss ? 'Friday Boss Assessment' : type.label.toLowerCase();
    return PageScaffold(
      header: PageHeader(
        icon: Icons.wb_sunny_rounded,
        title: '${editing ? 'Edit' : 'Create'} $noun',
        subtitle: subtitle(type),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : goTo(Routes.classwork()),
            icon: const Icon(Icons.arrow_back_rounded, size: 19),
            label: const Text('Back to classwork'),
          ),
        ),
        child,
      ],
    );
  }
}

/// Loads a quiz / boss answer key before showing the form.
class _QuestionsLoader extends ConsumerStatefulWidget {
  const _QuestionsLoader({required this.item});

  final ClassworkItem item;

  @override
  ConsumerState<_QuestionsLoader> createState() => _QuestionsLoaderState();
}

class _QuestionsLoaderState extends ConsumerState<_QuestionsLoader> {
  late final Future<List<QuizQuestion>> _questions = widget.item.type.hasQuestions
      ? ref.read(classworkRepositoryProvider).loadQuestions(widget.item.id)
      : Future.value(const <QuizQuestion>[]);

  @override
  Widget build(BuildContext context) => FutureBuilder<List<QuizQuestion>>(
        future: _questions,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()));
          }
          return _EditorForm(
            key: ValueKey('edit-${widget.item.id}'),
            type: widget.item.type,
            existing: widget.item,
            questions: snap.data!,
            classId: widget.item.classId,
          );
        },
      );
}

enum _Primary { now, schedule, draft }

class _EditorForm extends ConsumerStatefulWidget {
  const _EditorForm({
    super.key,
    required this.type,
    this.existing,
    this.questions = const [],
    this.classId,
    this.studentId,
  });

  final ClassworkType type;
  final ClassworkItem? existing;
  final List<QuizQuestion> questions;
  final String? classId;
  final String? studentId;

  @override
  ConsumerState<_EditorForm> createState() => _EditorFormState();
}

class _EditorFormState extends ConsumerState<_EditorForm> {
  final _formKey = GlobalKey<FormState>();
  late final ClassworkItem? _e = widget.existing;
  ClassworkType get _type => widget.type;

  late final _title = TextEditingController(text: _e?.title ?? '');
  late final _description = TextEditingController(text: _e?.description ?? '');
  late final _objectives = TextEditingController(text: _e?.objectives ?? '');
  late final _content = TextEditingController(text: _e?.content ?? '');
  /// Settings › Classwork defaults (already loaded by the sidebar).
  TeacherPreferences get _prefs => ref.read(preferencesProvider);

  late final _points = TextEditingController(text: '${_e?.points ?? _prefs.pointsFor(_type) ?? _type.defaultPoints}');
  late final _xp = TextEditingController(text: '${_e?.xpReward ?? (_type == ClassworkType.boss ? 75 : 100)}');
  late final _coins = TextEditingController(text: '${_e?.coinReward ?? 25}');
  late final _timeLimit = TextEditingController(
      text: '${_e?.timeLimitMinutes ?? (_type == ClassworkType.boss ? 30 : (_type == ClassworkType.quiz ? 20 : ''))}');
  late final _passing = TextEditingController(text: '${_e?.passingScore ?? 70}');
  late final _bossHp = TextEditingController(text: '${_e?.bossHp ?? 100}');

  late String? _classId = _e?.classId ?? widget.classId;
  late List<String> _students = _e?.assignedStudentIds ?? (widget.studentId == null ? const [] : [widget.studentId!]);
  late String? _topicId = _e?.topicId;
  late int _quarter = _e?.quarter ?? schoolQuarter(DateTime.now());
  late DateTime _date = _e?.dueDate ?? _defaultDate();
  late TimeOfDay _time = _e == null
      ? TimeOfDay(hour: _prefs.dueHour, minute: _prefs.dueMinute)
      : TimeOfDay(hour: _e.dueDate.hour, minute: _e.dueDate.minute);
  late int _attempts = _e?.attempts ?? (_type == ClassworkType.quest ? 3 : 1);
  late Difficulty _difficulty = _e?.difficulty ?? (_type == ClassworkType.boss ? Difficulty.hard : Difficulty.medium);
  late bool _allowLate = _e?.allowLate ?? _prefs.allowLate;
  late bool _postToStream = _e?.postToStream ?? _prefs.postToStream;
  late bool _notify = _e?.notifyStudents ?? true;
  late SubmissionType _submission = _e?.submissionType ?? SubmissionType.file;
  late bool _groupWork = _e?.groupWork ?? false;
  late List<RubricCriterion> _rubric = _e?.rubric ?? const [];
  late bool _shuffleQ = _e?.shuffleQuestions ?? true;
  late bool _shuffleC = _e?.shuffleChoices ?? true;
  late bool _showScore = _e?.showScoreImmediately ?? true;
  late bool _autoGrade = _e?.autoGrade ?? true;
  late String _bossId = _e?.bossId ?? 'kapuluan';
  late String _badge = (_e?.rewardBadge.isNotEmpty ?? false) ? _e!.rewardBadge : rewardBadges.first;
  late bool _explanations = _e?.showExplanations ?? true;
  late List<PostAttachment> _attachments = _e?.allAttachments ?? const [];
  late List<QuizQuestion> _questions = widget.questions;
  bool _saving = false;
  bool _pointsTouched = false;

  DateTime _defaultDate() {
    final today = startOfDay(DateTime.now());
    return switch (_type) {
      ClassworkType.boss => nextWeekday(today, DateTime.friday),
      ClassworkType.lesson || ClassworkType.material => today,
      _ => addDays(today, 1),
    };
  }

  @override
  void initState() {
    super.initState();
    // New quests and quizzes start at the class's "Total points".
    if (_e == null && (_type == ClassworkType.quest || _type == ClassworkType.quiz)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final cls = ref.read(classByIdProvider)[_classId];
        if (mounted && cls != null && !_pointsTouched) _points.text = '${cls.totalPoints}';
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _objectives, _content, _points, _xp, _coins, _timeLimit, _passing, _bossHp]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _hasTime => _type != ClassworkType.lesson && _type != ClassworkType.material;

  DateTime get _when => _hasTime
      ? DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute)
      : DateTime(_date.year, _date.month, _date.day);

  String get _detailsTitle => switch (_type) {
        ClassworkType.boss => 'Boss details',
        _ => '${_type.label} details',
      };

  String get _titleLabel => switch (_type) {
        ClassworkType.boss => 'Boss title',
        _ => '${_type.label} title',
      };

  // ------------------------------------------------------------------ save
  Future<void> _save(_Primary how) async {
    if (_title.text.trim().isEmpty) {
      showToast('Add a title first.');
      return;
    }
    final cls = ref.read(classByIdProvider)[_classId];
    if (cls == null) {
      showToast('Choose a class.');
      return;
    }
    final assigning = how != _Primary.draft;
    if (assigning) {
      if (!_formKey.currentState!.validate()) return;
      if (_type.hasQuestions) {
        if (_questions.isEmpty) {
          showToast('Add at least one question.');
          return;
        }
        for (var i = 0; i < _questions.length; i++) {
          final p = _questions[i].problem(i + 1);
          if (p != null) {
            showToast(p);
            return;
          }
        }
      }
    }
    DateTime? publishAt;
    if (how == _Primary.schedule) {
      publishAt = await showScheduleDialog(context, initial: _e?.publishAt);
      if (publishAt == null) return;
    }
    final status = switch (how) {
      _Primary.now => ClassworkStatus.published,
      _Primary.schedule => ClassworkStatus.scheduled,
      _Primary.draft => ClassworkStatus.draft,
    };
    int n(TextEditingController c, int fallback) => int.tryParse(c.text) ?? fallback;
    final item = ClassworkItem(
      id: _e?.id ?? '',
      classId: cls.id,
      className: cls.name,
      type: _type,
      title: _title.text.trim(),
      description: _description.text.trim(),
      dueDate: _when,
      status: status,
      points: _type.isGraded ? n(_points, _type.defaultPoints) : 0,
      assignedStudentIds: _students,
      topicId: _topicId,
      quarter: _quarter,
      position: _e?.position ?? DateTime.now().millisecondsSinceEpoch / 1e12,
      attachments: _attachments,
      publishAt: publishAt,
      objectives: _objectives.text.trim(),
      content: _content.text.trim(),
      postToStream: _postToStream,
      notifyStudents: _notify,
      allowLate: _allowLate,
      xpReward: n(_xp, 0),
      coinReward: _type == ClassworkType.quest ? n(_coins, 0) : 0,
      attempts: _attempts,
      difficulty: _difficulty,
      submissionType: _submission,
      groupWork: _groupWork,
      rubric: _rubric,
      timeLimitMinutes: int.tryParse(_timeLimit.text),
      shuffleQuestions: _shuffleQ,
      shuffleChoices: _shuffleC,
      showScoreImmediately: _showScore,
      autoGrade: _autoGrade,
      questionCount: _questions.length,
      passingScore: n(_passing, 70),
      bossId: _bossId,
      bossHp: n(_bossHp, 100),
      rewardBadge: _type == ClassworkType.boss ? _badge : '',
      showExplanations: _explanations,
    );
    setState(() => _saving = true);
    try {
      await ref.read(classworkRepositoryProvider).save(item, questions: _type.hasQuestions ? _questions : null);
      showToast(switch (status) {
        ClassworkStatus.published => _type.isGraded ? 'Assigned to ${cls.name}' : 'Published to ${cls.name}',
        ClassworkStatus.scheduled => 'Scheduled for ${fullDate(publishAt!)}',
        _ => 'Draft saved',
      });
      goTo(Routes.classwork(classId: cls.id));
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      showToast('Couldn’t save: $e');
    }
  }

  // ------------------------------------------------------------------ UI
  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(activeClassesProvider).valueOrNull ?? const <ClassRoom>[];
    final topics = _classId == null ? const <ClassTopic>[] : (ref.watch(classTopicsProvider(_classId!)).valueOrNull ?? const <ClassTopic>[]);
    final boss = _type == ClassworkType.boss;

    final details = EditorCard(
      title: _detailsTitle,
      tint: boss ? const Color(0xFFFFFBEF) : null,
      children: [
        RequiredLabel(_titleLabel),
        TextFormField(controller: _title, maxLength: 160, decoration: const InputDecoration(counterText: '')),
        const SizedBox(height: 16),
        ..._typeBody(),
      ],
    );

    final settings = EditorCard(
      title: switch (_type) {
        ClassworkType.quiz => 'Quiz settings',
        ClassworkType.boss => 'Battle settings',
        _ => 'Classwork settings',
      },
      children: [
        const RequiredLabel('Class'),
        DropdownMenu<String>(
          key: ValueKey('class-$_classId-${classes.length}'),
          initialSelection: _classId,
          expandedInsets: EdgeInsets.zero,
          requestFocusOnTap: false,
          hintText: 'Choose a class',
          dropdownMenuEntries: [for (final c in classes) DropdownMenuEntry(value: c.id, label: c.name)],
          onSelected: (v) => setState(() {
            _classId = v;
            _topicId = null;
            _students = const [];
          }),
        ),
        const SizedBox(height: 14),
        const RequiredLabel('Students'),
        StudentsPicker(classId: _classId, value: _students, onChanged: (v) => setState(() => _students = v)),
        const SizedBox(height: 14),
        ..._settingsBody(topics),
      ],
    );

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TwoColumn(leftFlex: 7, rightFlex: 4, left: [details], right: [settings]),
          const SizedBox(height: 18),
          _ActionsRow(
            type: _type,
            saving: _saving,
            onCancel: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : goTo(Routes.classwork(classId: _classId)),
            onDraft: () => _save(_Primary.draft),
            onNow: () => _save(_Primary.now),
            onSchedule: () => _save(_Primary.schedule),
            onPreview: _type.hasQuestions
                ? () => showQuizPreview(context, title: _title.text, questions: _questions)
                : null,
          ),
        ],
      ),
    );
  }

  List<Widget> _typeBody() {
    String? requiredText(String? v) => (v == null || v.trim().isEmpty) ? 'This is required.' : null;
    final attachments = [
      const RequiredLabel('Attachments (optional)', isRequired: false),
      AttachmentsField(value: _attachments, classId: _classId, onChanged: (v) => setState(() => _attachments = v)),
    ];
    switch (_type) {
      case ClassworkType.lesson:
        return [
          const RequiredLabel('Learning objectives'),
          RichTextBox(controller: _objectives, minLines: 4, hint: '• What students will be able to do', validator: requiredText),
          const SizedBox(height: 16),
          const RequiredLabel('Lesson content'),
          RichTextBox(controller: _content, minLines: 6, validator: requiredText),
          const SizedBox(height: 16),
          ...attachments,
        ];
      case ClassworkType.quest:
        return [
          const RequiredLabel('Instructions'),
          RichTextBox(controller: _description, validator: requiredText),
          const SizedBox(height: 16),
          const RequiredLabel('Learning objective'),
          RichTextBox(controller: _objectives, minLines: 3, validator: requiredText),
          const SizedBox(height: 16),
          ...attachments,
        ];
      case ClassworkType.activity:
        return [
          const RequiredLabel('Instructions'),
          RichTextBox(controller: _description, validator: requiredText),
          const SizedBox(height: 16),
          ...attachments,
          const SizedBox(height: 18),
          const RequiredLabel('Submission type'),
          SubmissionTypePicker(value: _submission, onChanged: (v) => setState(() => _submission = v)),
          const SizedBox(height: 14),
          ToggleRow(
            label: 'Allow group work',
            hint: 'Let students work in groups for this activity.',
            value: _groupWork,
            onChanged: (v) => setState(() => _groupWork = v),
          ),
        ];
      case ClassworkType.quiz:
        return [
          const RequiredLabel('Description'),
          RichTextBox(controller: _description, minLines: 3, validator: requiredText),
          const SizedBox(height: 20),
          Text('Questions', style: AppText.sectionTitle.copyWith(fontSize: 16)),
          const SizedBox(height: 10),
          QuestionsEditor(questions: _questions, onChanged: (q) => setState(() => _questions = q)),
        ];
      case ClassworkType.boss:
        return [
          const RequiredLabel('Description'),
          RichTextBox(controller: _description, minLines: 3, validator: requiredText),
          const SizedBox(height: 18),
          Text('Boss character', style: AppText.itemTitle.copyWith(color: AppColors.amber)),
          const SizedBox(height: 10),
          BossCharacterCard(bossId: _bossId, onChanged: (v) => setState(() => _bossId = v)),
          const SizedBox(height: 20),
          QuestionsEditor(
            questions: _questions,
            compact: true,
            withExplanations: true,
            onChanged: (q) => setState(() => _questions = q),
          ),
        ];
      case ClassworkType.material:
        return [
          const RequiredLabel('Description'),
          RichTextBox(controller: _description, validator: requiredText),
          const SizedBox(height: 18),
          Text('Attachments', style: AppText.itemTitle),
          const SizedBox(height: 8),
          AttachmentsField(value: _attachments, classId: _classId, onChanged: (v) => setState(() => _attachments = v)),
        ];
    }
  }

  List<Widget> _settingsBody(List<ClassTopic> topics) {
    final boss = _type == ClassworkType.boss;
    Widget half(Widget a, Widget b) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: a),
          const SizedBox(width: 10),
          Expanded(child: b),
        ]);
    Widget labeled(String label, Widget field, {bool req = true}) =>
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [RequiredLabel(label, isRequired: req), field]);

    final topic = labeled(
      boss ? 'Week' : 'Topic',
      DropdownMenu<String>(
        key: ValueKey('topic-$_classId-$_topicId-${topics.length}'),
        initialSelection: _topicId ?? '',
        expandedInsets: EdgeInsets.zero,
        requestFocusOnTap: false,
        dropdownMenuEntries: [
          for (final t in topics) DropdownMenuEntry(value: t.id, label: t.name),
          const DropdownMenuEntry(value: '', label: 'No topic'),
          const DropdownMenuEntry(value: '__new', label: '+ Create topic'),
        ],
        onSelected: (v) async {
          if (v == '__new') {
            final name = await showTopicNameDialog(context);
            if (name == null || _classId == null) return;
            final id = await ref
                .read(classworkRepositoryProvider)
                .createTopic(_classId!, name, (topics.isEmpty ? 0 : topics.last.position) + 1);
            setState(() => _topicId = id);
          } else {
            setState(() => _topicId = (v == null || v.isEmpty) ? null : v);
          }
        },
      ),
      req: false,
    );
    final quarter = labeled(
      'Quarter',
      DropdownMenu<int>(
        initialSelection: _quarter,
        expandedInsets: EdgeInsets.zero,
        requestFocusOnTap: false,
        dropdownMenuEntries: [for (var q = 1; q <= 4; q++) DropdownMenuEntry(value: q, label: 'Quarter $q')],
        onSelected: (q) => setState(() => _quarter = q ?? _quarter),
      ),
    );
    final date = labeled(_hasTime ? 'Due date' : 'Publish date', DateField(value: _date, onChanged: (d) => setState(() => _date = d)));
    final points = labeled(
      _type.hasQuestions ? 'Total points' : 'Points',
      Focus(
        onFocusChange: (_) => _pointsTouched = true,
        child: NumberField(controller: _points, icon: Icons.bar_chart_rounded, min: 1),
      ),
    );
    final attempts = labeled(
      'Attempts',
      DropdownMenu<int>(
        initialSelection: _attempts,
        expandedInsets: EdgeInsets.zero,
        requestFocusOnTap: false,
        dropdownMenuEntries: [for (var a = 1; a <= 5; a++) DropdownMenuEntry(value: a, label: '$a')],
        onSelected: (a) => setState(() => _attempts = a ?? _attempts),
      ),
      req: false,
    );
    final difficulty = SegmentedButton<Difficulty>(
      segments: [for (final d in Difficulty.values) ButtonSegment(value: d, label: Text(d.label))],
      selected: {_difficulty},
      showSelectedIcon: false,
      onSelectionChanged: (s) => setState(() => _difficulty = s.first),
    );
    final gap = const SizedBox(height: 14);

    switch (_type) {
      case ClassworkType.lesson:
      case ClassworkType.material:
        return [
          topic, gap, quarter, gap, date, gap,
          ToggleRow(label: 'Post to Stream', hint: 'Make this visible in class stream.', value: _postToStream,
              onChanged: (v) => setState(() => _postToStream = v)),
          ToggleRow(label: 'Notify students', hint: 'Send a notification to students.', value: _notify,
              onChanged: (v) => setState(() => _notify = v)),
        ];
      case ClassworkType.quest:
        return [
          points, gap,
          half(date, labeled('Due time', TimeField(value: _time, onChanged: (t) => setState(() => _time = t)))),
          gap, topic, gap, quarter, gap,
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.primarySoft.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Gamification settings', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
              const SizedBox(height: 10),
              half(labeled('XP reward', NumberField(controller: _xp, icon: Icons.star_outline_rounded, suffix: 'XP'), req: false),
                  labeled('Coin reward', NumberField(controller: _coins, icon: Icons.monetization_on_outlined), req: false)),
              const SizedBox(height: 10),
              attempts,
              const SizedBox(height: 10),
              const RequiredLabel('Difficulty', isRequired: false),
              difficulty,
            ]),
          ),
          gap,
          ToggleRow(label: 'Allow late submissions', value: _allowLate, onChanged: (v) => setState(() => _allowLate = v)),
          ToggleRow(label: 'Post to Stream', value: _postToStream, onChanged: (v) => setState(() => _postToStream = v)),
        ];
      case ClassworkType.activity:
        return [
          points, gap, date, gap, topic, gap, quarter, gap,
          RubricField(
            value: _rubric,
            onChanged: (r) => setState(() {
              _rubric = r;
              final total = r.fold<int>(0, (n, c) => n + c.points);
              if (total > 0) _points.text = '$total';
            }),
          ),
          gap,
          ToggleRow(label: 'Allow late submissions', value: _allowLate, onChanged: (v) => setState(() => _allowLate = v)),
          ToggleRow(label: 'Post to Stream', value: _postToStream, onChanged: (v) => setState(() => _postToStream = v)),
        ];
      case ClassworkType.quiz:
        return [
          points,
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Questions add up to ${totalQuestionPoints(_questions)} points.', style: AppText.meta.copyWith(fontSize: 12)),
          ),
          gap, date, gap, topic, gap, quarter, gap,
          half(labeled('Time limit', NumberField(controller: _timeLimit, icon: Icons.timer_outlined, suffix: 'min', min: 1, max: 180), req: false),
              attempts),
          gap,
          ToggleRow(label: 'Shuffle questions', value: _shuffleQ, onChanged: (v) => setState(() => _shuffleQ = v)),
          ToggleRow(label: 'Shuffle choices', value: _shuffleC, onChanged: (v) => setState(() => _shuffleC = v)),
          ToggleRow(label: 'Show score immediately', value: _showScore, onChanged: (v) => setState(() => _showScore = v)),
          ToggleRow(label: 'Automatic grading', value: _autoGrade, onChanged: (v) => setState(() => _autoGrade = v)),
          ToggleRow(label: 'Post to Stream', value: _postToStream, onChanged: (v) => setState(() => _postToStream = v)),
        ];
      case ClassworkType.boss:
        return [
          topic, gap, date, gap, points, gap,
          half(labeled('Passing score', NumberField(controller: _passing, icon: Icons.emoji_events_outlined, suffix: '%', min: 1, max: 100)),
              labeled('Time limit', NumberField(controller: _timeLimit, icon: Icons.timer_outlined, suffix: 'min', min: 1, max: 180), req: false)),
          gap,
          half(attempts, labeled('Difficulty', DropdownMenu<Difficulty>(
            initialSelection: _difficulty,
            expandedInsets: EdgeInsets.zero,
            requestFocusOnTap: false,
            dropdownMenuEntries: [for (final d in Difficulty.values) DropdownMenuEntry(value: d, label: d.label)],
            onSelected: (d) => setState(() => _difficulty = d ?? _difficulty),
          ), req: false)),
          gap,
          half(labeled('Boss HP', NumberField(controller: _bossHp, icon: Icons.favorite_border_rounded, min: 1, max: 10000)),
              labeled('XP reward', NumberField(controller: _xp, icon: Icons.star_outline_rounded))),
          gap,
          labeled('Reward badge', DropdownMenu<String>(
            initialSelection: _badge,
            expandedInsets: EdgeInsets.zero,
            requestFocusOnTap: false,
            leadingIcon: const Icon(Icons.workspace_premium_rounded, color: AppColors.amber),
            dropdownMenuEntries: [for (final b in rewardBadges) DropdownMenuEntry(value: b, label: b)],
            onSelected: (b) => setState(() => _badge = b ?? _badge),
          )),
          gap, quarter, gap,
          ToggleRow(label: 'Randomize questions', value: _shuffleQ, onChanged: (v) => setState(() => _shuffleQ = v)),
          ToggleRow(label: 'Show explanations after attempt', value: _explanations,
              onChanged: (v) => setState(() => _explanations = v)),
          ToggleRow(label: 'Post to Stream', value: _postToStream, onChanged: (v) => setState(() => _postToStream = v)),
        ];
    }
  }
}

/// Cancel · (Preview) · Save draft · [Publish / Assign / Schedule Boss ▾].
class _ActionsRow extends StatelessWidget {
  const _ActionsRow({
    required this.type,
    required this.saving,
    required this.onCancel,
    required this.onDraft,
    required this.onNow,
    required this.onSchedule,
    this.onPreview,
  });

  final ClassworkType type;
  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onDraft;
  final VoidCallback onNow;
  final VoidCallback onSchedule;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final boss = type == ClassworkType.boss;
    final label = boss ? 'Schedule Boss' : (type.isGraded ? 'Assign' : 'Publish');
    final nowLabel = boss ? 'Publish now' : (type.isGraded ? 'Assign now' : 'Publish now');
    const radius = Radius.circular(10);
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 12,
      runSpacing: 10,
      children: [
        OutlinedButton(onPressed: saving ? null : onCancel, child: const Text('Cancel')),
        if (onPreview != null)
          OutlinedButton(onPressed: onPreview, child: Text(boss ? 'Preview battle' : 'Preview')),
        OutlinedButton(onPressed: saving ? null : onDraft, child: const Text('Save draft')),
        Row(mainAxisSize: MainAxisSize.min, children: [
          FilledButton(
            style: FilledButton.styleFrom(
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(left: radius)),
              minimumSize: const Size(110, 46),
            ),
            onPressed: saving ? null : (boss ? onSchedule : onNow),
            child: Text(label),
          ),
          Container(width: 1, height: 46, color: Colors.white.withValues(alpha: 0.4)),
          PopupMenuButton<String>(
            enabled: !saving,
            tooltip: 'More options',
            position: PopupMenuPosition.under,
            onSelected: (v) {
              switch (v) {
                case 'now':
                  onNow();
                case 'schedule':
                  onSchedule();
                case 'draft':
                  onDraft();
              }
            },
            itemBuilder: (_) => [
              menuItem('now', Icons.send_outlined, nowLabel),
              if (!boss) menuItem('schedule', Icons.calendar_month_outlined, 'Schedule'),
              if (boss) menuItem('draft', Icons.description_outlined, 'Save as draft'),
            ],
            child: Container(
              height: 46,
              width: 44,
              decoration: BoxDecoration(
                color: saving ? AppColors.buttonGrey : AppColors.primary,
                borderRadius: const BorderRadius.horizontal(right: radius),
              ),
              child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
            ),
          ),
        ]),
      ],
    );
  }
}
