import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../data/gradebook_repository.dart';
import '../../providers/core_providers.dart';
import '../classwork/editor/editor_fields.dart' show DateField;

int? _int(TextEditingController c) => int.tryParse(c.text.trim());

/// "Grade settings".
Future<void> showGradeSettingsDialog(BuildContext context, ClassRoom c, GradebookSettings s) =>
    showDialog<void>(context: context, builder: (_) => _SettingsDialog(classRoom: c, initial: s));

class _SettingsDialog extends ConsumerStatefulWidget {
  const _SettingsDialog({required this.classRoom, required this.initial});

  final ClassRoom classRoom;
  final GradebookSettings initial;

  @override
  ConsumerState<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<_SettingsDialog> {
  late GradebookSettings _s = widget.initial;
  late bool _showOverall = widget.classRoom.showOverallGrade;
  late final Map<String, TextEditingController> _w = {
    for (final k in const ['quest', 'activity', 'quiz', 'boss']) k: TextEditingController(text: '${_s.weights[k] ?? 0}'),
  };
  late final _passing = TextEditingController(text: '${_s.passingGrade}');
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [..._w.values, _passing]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _total => _w.values.fold(0, (n, c) => n + (_int(c) ?? 0));

  Future<void> _save() async {
    if (_s.calculation == GradeCalculation.weighted && _total != 100) {
      showToast('Category weights must add up to 100% (now $_total%).');
      return;
    }
    final passing = _int(_passing);
    if (passing == null || passing > 100) {
      showToast('Default passing grade must be 0–100%.');
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(gradebookRepositoryProvider);
    try {
      await repo.saveSettings(
        widget.classRoom.id,
        _s.copyWith(weights: {for (final e in _w.entries) e.key: _int(e.value) ?? 0}, passingGrade: passing),
      );
      if (_showOverall != widget.classRoom.showOverallGrade) {
        await repo.setShowOverallGrade(widget.classRoom.id, _showOverall);
      }
      if (!mounted) return;
      Navigator.pop(context);
      showToast('Grade settings saved');
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      showToast('Couldn’t save: $e');
    }
  }

  Widget _radio<T>(T value, T group, String label, String hint, ValueChanged<T> onTap) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onTap(value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(value == group ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                color: value == group ? AppColors.primary : AppColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(hint, style: AppText.meta.copyWith(fontSize: 12)),
              ]),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final weighted = _s.calculation == GradeCalculation.weighted;
    final left = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Grade calculation', style: AppText.itemTitle),
      for (final c in GradeCalculation.values)
        _radio(c, _s.calculation, c.label, c.hint, (v) => setState(() => _s = _s.copyWith(calculation: v))),
      const SizedBox(height: 14),
      Text('Missing work', style: AppText.itemTitle),
      _radio(true, _s.missingAsZero, 'Count as zero', 'Missing assignments are counted as zero points.',
          (v) => setState(() => _s = _s.copyWith(missingAsZero: v))),
      _radio(false, _s.missingAsZero, 'Exclude from calculation', 'Missing assignments are not included in grade calculation.',
          (v) => setState(() => _s = _s.copyWith(missingAsZero: v))),
    ]);
    const labels = {'quest': ('Quests', Icons.emoji_events_rounded, Tone.green), 'activity': ('Activities', Icons.auto_stories_rounded, Tone.amber),
        'quiz': ('Quizzes', Icons.quiz_rounded, Tone.purple), 'boss': ('Friday Boss', Icons.workspace_premium_rounded, Tone.amber)};
    final right = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Category weights${weighted ? '' : ' (preview)'}', style: AppText.itemTitle),
      const SizedBox(height: 6),
      for (final e in labels.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Icon(e.value.$2, color: e.value.$3.fg, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(e.value.$1)),
            SizedBox(
              width: 90,
              child: TextField(
                controller: _w[e.key],
                enabled: weighted,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(suffixText: '%', isDense: true),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ]),
        ),
      Row(children: [
        const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w700))),
        Text('$_total%', style: TextStyle(fontWeight: FontWeight.w700, color: _total == 100 ? AppColors.primary : AppColors.red)),
      ]),
      const Divider(height: 24),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Show overall grade to students'),
        value: _showOverall,
        onChanged: (v) => setState(() => _showOverall = v),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Round grades to nearest whole number'),
        value: _s.roundGrades,
        onChanged: (v) => setState(() => _s = _s.copyWith(roundGrades: v)),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Automatically update grades'),
        subtitle: const Text('Recalculate as soon as a score changes'),
        value: _s.autoUpdate,
        onChanged: (v) => setState(() => _s = _s.copyWith(autoUpdate: v)),
      ),
      Row(children: [
        const Expanded(child: Text('Default passing grade')),
        SizedBox(
          width: 90,
          child: TextField(
            controller: _passing,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(suffixText: '%', isDense: true),
          ),
        ),
      ]),
    ]);
    return AppDialog(
      maxWidth: 820,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('Grade settings', style: AppText.dialogTitle)),
          IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
        ]),
        const SizedBox(height: 10),
        Flexible(
          child: SingleChildScrollView(
            child: LayoutBuilder(builder: (context, box) => box.maxWidth < 620
                ? Column(children: [left, const Divider(height: 28), right])
                : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: left),
                    const SizedBox(width: 24),
                    Expanded(child: right),
                  ])),
          ),
        ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          const SizedBox(width: 12),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Save settings')),
        ]),
      ]),
    );
  }
}

/// "Edit grading scale".
Future<void> showScaleDialog(BuildContext context, String classId, GradebookSettings s) =>
    showDialog<void>(context: context, builder: (_) => _ScaleDialog(classId: classId, initial: s));

class _ScaleDialog extends ConsumerStatefulWidget {
  const _ScaleDialog({required this.classId, required this.initial});

  final String classId;
  final GradebookSettings initial;

  @override
  ConsumerState<_ScaleDialog> createState() => _ScaleDialogState();
}

class _ScaleDialogState extends ConsumerState<_ScaleDialog> {
  static const _palette = [0xFF1B6D47, 0xFF4CC38A, 0xFF3B82F6, 0xFF8B5CF6, 0xFFF6C443, 0xFFF08A3C, 0xFFE5484D, 0xFF6B7280];
  late List<(TextEditingController, TextEditingController, TextEditingController, int)> _rows = _from(widget.initial.scale);
  late bool _showLetters = widget.initial.showLetters;
  String? _error;

  List<(TextEditingController, TextEditingController, TextEditingController, int)> _from(List<GradeLevel> scale) => [
        for (final g in scale)
          (TextEditingController(text: g.letter), TextEditingController(text: '${g.min}'), TextEditingController(text: '${g.max}'), g.color),
      ];

  void _disposeRows() {
    for (final r in _rows) {
      r.$1.dispose();
      r.$2.dispose();
      r.$3.dispose();
    }
  }

  @override
  void dispose() {
    _disposeRows();
    super.dispose();
  }

  List<GradeLevel> get _scale => [
        for (final r in _rows) GradeLevel(r.$1.text.trim(), _int(r.$2) ?? -1, _int(r.$3) ?? -1, r.$4),
      ];

  Future<void> _save() async {
    final err = validateScale(_scale);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    await ref.read(gradebookRepositoryProvider).saveSettings(
          widget.classId,
          widget.initial.copyWith(scale: [..._scale]..sort((a, b) => b.min.compareTo(a.min)), showLetters: _showLetters),
        );
    if (!mounted) return;
    Navigator.pop(context);
    showToast('Grading scale saved');
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      maxWidth: 640,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Edit grading scale', style: AppText.dialogTitle),
              Text('Set the letter grade ranges and colors for this class.', style: AppText.meta),
            ]),
          ),
          IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
        ]),
        const SizedBox(height: 14),
        Row(children: const [
          SizedBox(width: 90, child: Text('Letter grade', style: TextStyle(fontWeight: FontWeight.w600))),
          SizedBox(width: 12),
          Expanded(child: Text('Minimum', style: TextStyle(fontWeight: FontWeight.w600))),
          SizedBox(width: 12),
          Expanded(child: Text('Maximum', style: TextStyle(fontWeight: FontWeight.w600))),
          SizedBox(width: 12),
          SizedBox(width: 120, child: Text('Color', style: TextStyle(fontWeight: FontWeight.w600))),
          SizedBox(width: 40),
        ]),
        const SizedBox(height: 8),
        for (var i = 0; i < _rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _rows[i].$1,
                  textAlign: TextAlign.center,
                  maxLength: 3,
                  style: TextStyle(fontWeight: FontWeight.w800, color: Color(_rows[i].$4)),
                  decoration: InputDecoration(
                    counterText: '',
                    isDense: true,
                    filled: true,
                    fillColor: Color(_rows[i].$4).withValues(alpha: 0.12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _numberField(_rows[i].$2)),
              const SizedBox(width: 12),
              Expanded(child: _numberField(_rows[i].$3)),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: DropdownButton<int>(
                  value: _palette.contains(_rows[i].$4) ? _rows[i].$4 : _palette.first,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final c in _palette)
                      DropdownMenuItem(
                        value: c,
                        child: Container(height: 22, decoration: BoxDecoration(color: Color(c), borderRadius: BorderRadius.circular(6))),
                      ),
                  ],
                  onChanged: (c) => setState(() => _rows[i] = (_rows[i].$1, _rows[i].$2, _rows[i].$3, c ?? _rows[i].$4)),
                ),
              ),
              IconButton(
                tooltip: 'Remove level',
                onPressed: _rows.length <= 1
                    ? null
                    : () => setState(() {
                          final r = _rows.removeAt(i);
                          r.$1.dispose();
                          r.$2.dispose();
                          r.$3.dispose();
                        }),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ]),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _rows.length >= 12
                ? null
                : () => setState(() => _rows.add((TextEditingController(), TextEditingController(), TextEditingController(), _palette.last))),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add grade level'),
          ),
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show letter grades in Gradebook'),
          value: _showLetters,
          onChanged: (v) => setState(() => _showLetters = v),
        ),
        Row(children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(_error ?? 'Ranges must not overlap and must cover whole number values (0 – 100).',
                style: AppText.meta.copyWith(color: _error == null ? null : AppColors.red)),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          OutlinedButton(
            onPressed: () => setState(() {
              _disposeRows();
              _rows = _from(GradeLevel.defaults);
              _error = null;
            }),
            child: const Text('Reset to default'),
          ),
          const Spacer(),
          OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          const SizedBox(width: 12),
          FilledButton(onPressed: _save, child: const Text('Save scale')),
        ]),
      ]),
    );
  }

  Widget _numberField(TextEditingController c) => TextField(
        controller: c,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(isDense: true),
      );
}

/// Click a grade cell: score, status, feedback.
Future<void> showGradeCellDialog(
  BuildContext context, {
  required ClassworkItem item,
  required Student student,
  required Submission? existing,
}) =>
    showDialog<void>(context: context, builder: (_) => _CellDialog(item: item, student: student, existing: existing));

class _CellDialog extends ConsumerStatefulWidget {
  const _CellDialog({required this.item, required this.student, required this.existing});

  final ClassworkItem item;
  final Student student;
  final Submission? existing;

  @override
  ConsumerState<_CellDialog> createState() => _CellDialogState();
}

class _CellDialogState extends ConsumerState<_CellDialog> {
  late final _score = TextEditingController(text: '${widget.existing?.score ?? ''}');
  late final _feedback = TextEditingController(text: widget.existing?.privateFeedback ?? '');
  late GradeEntry _entry = widget.existing == null
      ? GradeEntry.graded
      : (widget.existing!.status == SubmissionStatus.returned ? GradeEntry.graded : GradeEntry.draft);
  bool _saving = false;

  @override
  void dispose() {
    _score.dispose();
    _feedback.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final score = _int(_score);
    if (_entry != GradeEntry.missing && (score == null || score > widget.item.points)) {
      showToast('Enter a score from 0 to ${widget.item.points}.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(gradebookRepositoryProvider).setGrade(
            item: widget.item,
            student: widget.student,
            existing: widget.existing,
            entry: _entry,
            score: score,
            feedback: _feedback.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context);
      showToast('Grade saved');
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      showToast('Couldn’t save: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      maxWidth: 400,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PanelHeader(title: widget.student.name, subtitle: widget.item.title),
        const SizedBox(height: 14),
        Row(children: [
          const SizedBox(width: 70, child: Text('Score', style: TextStyle(fontWeight: FontWeight.w600))),
          SizedBox(
            width: 90,
            child: TextField(
              controller: _score,
              autofocus: true,
              enabled: _entry != GradeEntry.missing,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          Text('/ ${widget.item.points}'),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          const SizedBox(width: 70, child: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
          Expanded(
            child: DropdownMenu<GradeEntry>(
              initialSelection: _entry,
              expandedInsets: EdgeInsets.zero,
              requestFocusOnTap: false,
              dropdownMenuEntries: const [
                DropdownMenuEntry(value: GradeEntry.graded, label: 'Graded (returned)'),
                DropdownMenuEntry(value: GradeEntry.draft, label: 'Draft (not returned)'),
                DropdownMenuEntry(value: GradeEntry.missing, label: 'Missing'),
              ],
              onSelected: (v) => setState(() => _entry = v ?? _entry),
            ),
          ),
        ]),
        if (_entry == GradeEntry.missing && widget.existing != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('This removes the student’s submission and grade.', style: AppText.meta.copyWith(color: AppColors.red)),
          ),
        if (widget.existing == null && _entry != GradeEntry.missing)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Nothing was turned in online — this records a grade for work handed in on paper.',
                style: AppText.meta.copyWith(fontSize: 12)),
          ),
        const SizedBox(height: 12),
        const FieldLabel('Feedback (optional)'),
        TextField(controller: _feedback, minLines: 2, maxLines: 4, maxLength: 500, enabled: _entry != GradeEntry.missing),
        if (widget.existing != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                goTo(Routes.reviewSubmission(widget.item.id, widget.student.id));
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open submission'),
            ),
          ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          const SizedBox(width: 12),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
        ]),
      ]),
    );
  }
}

/// Column menu → "Edit points and due date".
Future<void> showPointsDueDialog(BuildContext context, ClassworkItem item) =>
    showDialog<void>(context: context, builder: (_) => _PointsDueDialog(item: item));

class _PointsDueDialog extends ConsumerStatefulWidget {
  const _PointsDueDialog({required this.item});

  final ClassworkItem item;

  @override
  ConsumerState<_PointsDueDialog> createState() => _PointsDueDialogState();
}

class _PointsDueDialogState extends ConsumerState<_PointsDueDialog> {
  late final _points = TextEditingController(text: '${widget.item.points}');
  late DateTime _due = widget.item.dueDate;

  @override
  void dispose() {
    _points.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
        maxWidth: 400,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PanelHeader(title: 'Points and due date', subtitle: widget.item.title),
          const SizedBox(height: 14),
          const FieldLabel('Points'),
          TextField(
            controller: _points,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 12),
          const FieldLabel('Due date'),
          DateField(value: _due, onChanged: (d) => setState(() => _due = d)),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () async {
                final p = _int(_points);
                if (p == null || p < 1 || p > 1000) {
                  showToast('Points must be 1–1000.');
                  return;
                }
                await ref.read(gradebookRepositoryProvider).updatePointsAndDue(widget.item, points: p, dueDate: _due);
                if (context.mounted) Navigator.pop(context);
                showToast('Saved');
              },
              child: const Text('Save'),
            ),
          ]),
        ]),
      );
}

/// Student menu → "Add private teacher note".
Future<void> showNoteDialog(BuildContext context, String classId, Student student, GradebookSettings s) =>
    showDialog<void>(context: context, builder: (_) => _NoteDialog(classId: classId, student: student, settings: s));

class _NoteDialog extends ConsumerStatefulWidget {
  const _NoteDialog({required this.classId, required this.student, required this.settings});

  final String classId;
  final Student student;
  final GradebookSettings settings;

  @override
  ConsumerState<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends ConsumerState<_NoteDialog> {
  late final _note = TextEditingController(text: widget.settings.notes[widget.student.id] ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
        maxWidth: 440,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PanelHeader(title: 'Private teacher note', subtitle: '${widget.student.name} · only you can see this'),
          const SizedBox(height: 12),
          TextField(controller: _note, autofocus: true, minLines: 3, maxLines: 6, maxLength: 500),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () async {
                final notes = {...widget.settings.notes};
                final text = _note.text.trim();
                if (text.isEmpty) {
                  notes.remove(widget.student.id);
                } else {
                  notes[widget.student.id] = text;
                }
                await ref.read(gradebookRepositoryProvider).saveSettings(widget.classId, widget.settings.copyWith(notes: notes));
                if (context.mounted) Navigator.pop(context);
                showToast('Note saved');
              },
              child: const Text('Save note'),
            ),
          ]),
        ]),
      );
}
