import 'dart:convert';

import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/admin_providers.dart';
import '../../providers/core_providers.dart';
import '../common/admin_widgets.dart';
import 'roster_csv.dart';

/// Add a student, or edit / move an existing one ([existing]).
Future<void> showStudentForm(BuildContext context, {Student? existing, String? classId}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _StudentForm(existing: existing, classId: existing?.classId ?? classId),
    );

class _StudentForm extends ConsumerStatefulWidget {
  const _StudentForm({this.existing, this.classId});

  final Student? existing;
  final String? classId;

  @override
  ConsumerState<_StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends ConsumerState<_StudentForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _number = TextEditingController(text: widget.existing?.studentNumber ?? '');
  late String? _classId = widget.classId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _suggestNumber();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  void _suggestNumber() {
    if (widget.existing != null || _classId == null) return;
    final inClass = ref.read(studentsByClassProvider)[_classId] ?? const <Student>[];
    _number.text = nextStudentNumber(inClass);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final cls = ref.read(classByIdProvider)[_classId];
    if (cls == null) return;
    setState(() => _saving = true);
    final repo = ref.read(adminRepositoryProvider);
    final existing = widget.existing;
    final ok = await attempt(
      () => existing == null
          ? repo.addStudent(cls, name: _name.text, number: _number.text)
          : repo.updateStudent(existing, cls, name: _name.text, number: _number.text),
      success: existing == null
          ? '${_name.text.trim()} added to ${cls.name}'
          : existing.classId != cls.id
              ? '${_name.text.trim()} moved to ${cls.name}'
              : 'Student updated',
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(activeClassesProvider).valueOrNull ?? const <ClassRoom>[];
    ref.watch(studentsByClassProvider); // keep rosters loaded for number suggestions
    final moving = widget.existing != null && _classId != widget.existing!.classId;
    return AppDialog(
      maxWidth: 480,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PanelHeader(
              title: widget.existing == null ? 'Add Student' : 'Edit ${widget.existing!.name}',
              subtitle: 'Students appear on their teacher’s dashboard right away',
              leading: const ToneIcon(Icons.person_add_alt_1_outlined, tone: Tone.green, size: 46),
            ),
            const SizedBox(height: 18),
            const FieldLabel('Full name'),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(hintText: 'e.g. Maria Santos'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the student’s name.' : null,
            ),
            const SizedBox(height: 14),
            const FieldLabel('Class'),
            ClassPicker(
              classes: classes,
              value: _classId,
              onChanged: (v) {
                setState(() => _classId = v);
                _suggestNumber();
              },
            ),
            const SizedBox(height: 14),
            const FieldLabel('Student number'),
            TextFormField(
              controller: _number,
              decoration: const InputDecoration(prefixText: '#'),
              validator: (v) => (v == null || v.trim().isEmpty || v.trim().length > 20) ? 'Enter a number.' : null,
            ),
            if (moving) ...[
              const SizedBox(height: 12),
              Text(
                'Moving keeps the student’s past submissions with their old class reports.',
                style: AppText.meta.copyWith(color: AppColors.amber),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving || _classId == null ? null : _save,
                    child: Text(widget.existing == null ? 'Add student' : 'Save changes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Import CSV": pick a class and a file, preview, then add everyone.
Future<void> showImportDialog(BuildContext context, {String? classId}) =>
    showDialog<void>(context: context, builder: (_) => _ImportDialog(classId: classId));

class _ImportDialog extends ConsumerStatefulWidget {
  const _ImportDialog({this.classId});

  final String? classId;

  @override
  ConsumerState<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<_ImportDialog> {
  late String? _classId = widget.classId;
  String? _fileName;
  String? _text;
  bool _saving = false;

  RosterParse? _parse() {
    final text = _text;
    if (text == null || _classId == null) return null;
    final inClass = ref.read(studentsByClassProvider)[_classId] ?? const <Student>[];
    final taken = {for (final s in inClass) s.studentNumber};
    return parseRosterCsv(text, firstNumber: int.parse(nextStudentNumber(inClass)), takenNumbers: taken);
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt'],
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    setState(() {
      _fileName = file.name;
      _text = utf8.decode(bytes, allowMalformed: true);
    });
  }

  Future<void> _import(RosterParse parse) async {
    final cls = ref.read(classByIdProvider)[_classId];
    if (cls == null || parse.rows.isEmpty) return;
    setState(() => _saving = true);
    final ok = await attempt(
      () => ref.read(adminRepositoryProvider).importStudents(cls, parse.rows),
      success: '${parse.rows.length} students added to ${cls.name}',
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(activeClassesProvider).valueOrNull ?? const <ClassRoom>[];
    ref.watch(studentsByClassProvider);
    final parse = _parse();
    return AppDialog(
      maxWidth: 560,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHeader(
            title: 'Import students',
            subtitle: 'CSV with a name column (and optionally studentNumber)',
            leading: ToneIcon(Icons.upload_file_outlined, tone: Tone.blue, size: 46),
          ),
          const SizedBox(height: 16),
          const FieldLabel('Class'),
          ClassPicker(classes: classes, value: _classId, onChanged: (v) => setState(() => _classId = v)),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _saving ? null : _pick,
            icon: const Icon(Icons.attach_file_rounded),
            label: Text(_fileName ?? 'Choose CSV file'),
          ),
          const SizedBox(height: 8),
          Text('Example:  name,studentNumber   ·   "Dela Cruz, Juan",0002',
              style: AppText.meta.copyWith(fontSize: 12)),
          if (parse != null) ...[
            const SizedBox(height: 14),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(12),
                children: [
                  Text('${parse.rows.length} students ready to import',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  for (final r in parse.rows.take(8))
                    Text('#${r.number}  ${r.name}', style: AppText.meta.copyWith(color: AppColors.ink)),
                  if (parse.rows.length > 8) Text('…and ${parse.rows.length - 8} more', style: AppText.meta),
                  for (final e in parse.errors) ...[
                    const SizedBox(height: 4),
                    Text(e, style: AppText.meta.copyWith(color: AppColors.amber)),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving || parse == null || parse.rows.isEmpty ? null : () => _import(parse),
                  child: Text(parse == null || parse.rows.isEmpty ? 'Import' : 'Import ${parse.rows.length}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
