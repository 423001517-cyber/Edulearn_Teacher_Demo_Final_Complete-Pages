import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../data/storage_repository.dart';
import '../../providers/core_providers.dart';
import '../../providers/dashboard_providers.dart';
import '../../providers/data_providers.dart';

/// Create or edit a lesson, quest, quiz, activity or Friday Boss Assessment.
/// Pass [assignTo] to create a remedial quest for a single student.
Future<bool?> showClassworkForm(
  BuildContext context, {
  required ClassworkType type,
  ClassworkItem? existing,
  String? classId,
  Student? assignTo,
}) =>
    showDialog<bool>(
      context: context,
      builder: (_) => ClassworkFormDialog(
        type: existing?.type ?? type,
        existing: existing,
        initialClassId: existing?.classId ?? assignTo?.classId ?? classId,
        assignTo: assignTo,
      ),
    );

class ClassworkFormDialog extends ConsumerStatefulWidget {
  const ClassworkFormDialog({
    super.key,
    required this.type,
    this.existing,
    this.initialClassId,
    this.assignTo,
  });

  final ClassworkType type;
  final ClassworkItem? existing;
  final String? initialClassId;
  final Student? assignTo;

  @override
  ConsumerState<ClassworkFormDialog> createState() => _ClassworkFormDialogState();
}

class _ClassworkFormDialogState extends ConsumerState<ClassworkFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _points;
  String? _classId;
  late DateTime _due;
  PlatformFile? _file;
  bool _saving = false;
  String? _error;

  ClassworkType get _type => widget.type;
  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final remedial = widget.assignTo != null;
    _title = TextEditingController(
        text: e?.title ?? (remedial ? 'Remedial Quest for ${widget.assignTo!.firstName}' : ''));
    _description = TextEditingController(text: e?.description ?? '');
    _points = TextEditingController(text: '${e?.points ?? _type.defaultPoints}');
    _classId = widget.initialClassId;
    final today = startOfDay(DateTime.now());
    _due = e?.dueDate ??
        switch (_type) {
          ClassworkType.boss => nextWeekday(today, DateTime.friday),
          ClassworkType.lesson => today,
          _ => addDays(today, remedial ? 3 : 1),
        };
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _points.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'png', 'jpg', 'jpeg', 'mp4'],
    );
    final file = result?.files.single;
    if (file == null) return;
    if (file.size > StorageRepository.maxBytes) {
      setState(() => _error = 'That file is over 25 MB. Choose a smaller file.');
      return;
    }
    setState(() {
      _file = file;
      _error = null;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _due = picked);
  }

  Future<void> _save(ClassworkStatus status, List<ClassRoom> classes) async {
    if (!_formKey.currentState!.validate()) return;
    ClassRoom? cls;
    for (final c in classes) {
      if (c.id == _classId) cls = c;
    }
    if (cls == null) {
      setState(() => _error = 'Choose a class.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      var url = widget.existing?.attachmentUrl;
      var name = widget.existing?.attachmentName;
      final bytes = _file?.bytes;
      if (_file != null && bytes != null) {
        final upload = await ref
            .read(storageRepositoryProvider)
            .uploadLessonFile(fileName: _file!.name, bytes: bytes);
        url = upload.url;
        name = _file!.name;
      }
      final item = ClassworkItem(
        id: widget.existing?.id ?? '',
        classId: cls.id,
        className: cls.name,
        type: _type,
        title: _title.text.trim(),
        description: _description.text.trim(),
        dueDate: _due,
        status: status,
        points: _type.isGraded ? int.tryParse(_points.text) ?? _type.defaultPoints : 0,
        attachmentUrl: url,
        attachmentName: name,
        assignedStudentIds: widget.assignTo != null
            ? [widget.assignTo!.id]
            : (widget.existing?.assignedStudentIds ?? const []),
      );
      await ref.read(dashboardRepositoryProvider).saveClasswork(item);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      showToast(switch (status) {
        ClassworkStatus.draft => 'Draft saved',
        ClassworkStatus.scheduled => '${_type.label} scheduled for ${dayMonth(_due)}',
        _ => _editing ? 'Changes saved' : '${_type.label} published',
      });
    } catch (e) {
      setState(() {
        _saving = false;
        _error = "Couldn't save: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(activeClassesProvider).valueOrNull ?? const <ClassRoom>[];
    _classId ??= ref.read(selectedClassIdProvider) ?? (classes.isEmpty ? null : classes.first.id);
    final primaryStatus =
        _type == ClassworkType.boss ? ClassworkStatus.scheduled : ClassworkStatus.published;

    return AppDialog(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PanelHeader(
              title: '${_editing ? 'Edit' : 'New'} ${_type.label}',
              subtitle: widget.assignTo != null
                  ? 'Assigned only to ${widget.assignTo!.name}'
                  : _hint(_type),
              leading: ToneIcon(_type.icon, tone: _type.tone, size: 46),
            ),
            const SizedBox(height: 20),
            const FieldLabel('Class'),
            DropdownMenu<String>(
              initialSelection: _classId,
              expandedInsets: EdgeInsets.zero,
              requestFocusOnTap: false,
              enabled: widget.assignTo == null,
              hintText: 'Choose a class',
              dropdownMenuEntries: [
                for (final c in classes) DropdownMenuEntry(value: c.id, label: c.name),
              ],
              onSelected: (v) => setState(() => _classId = v),
            ),
            const SizedBox(height: 14),
            const FieldLabel('Title'),
            TextFormField(
              controller: _title,
              decoration: InputDecoration(hintText: _titleHint(_type)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Add a title.' : null,
            ),
            const SizedBox(height: 14),
            const FieldLabel('Instructions (optional)'),
            TextFormField(controller: _description, minLines: 2, maxLines: 4),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FieldLabel(_type == ClassworkType.lesson ? 'Publish date' : 'Due date'),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(10),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                              suffixIcon: Icon(Icons.calendar_month_outlined, size: 20)),
                          child: Text(longDate(_due)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_type.isGraded) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const FieldLabel('Points'),
                        TextFormField(
                          controller: _points,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (v) =>
                              (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter points' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (_type == ClassworkType.lesson) ...[
              const SizedBox(height: 14),
              const FieldLabel('Manuscript or learning material'),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white, alignment: Alignment.centerLeft),
                onPressed: _saving ? null : _pickFile,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(
                  _file?.name ?? widget.existing?.attachmentName ?? 'Upload a file (PDF, Word, slides…)',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
            ],
            const SizedBox(height: 22),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 10,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: AppColors.inkSoft),
                  child: const Text('Cancel'),
                ),
                OutlinedButton(
                  onPressed: _saving ? null : () => _save(ClassworkStatus.draft, classes),
                  child: const Text('Save draft'),
                ),
                FilledButton(
                  onPressed: _saving ? null : () => _save(primaryStatus, classes),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(primaryStatus == ClassworkStatus.scheduled ? 'Schedule' : 'Publish'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _hint(ClassworkType t) => switch (t) {
        ClassworkType.lesson => 'Upload a manuscript or learning material',
        ClassworkType.quest => 'A Monday–Thursday learning quest',
        ClassworkType.quiz => 'An automatically graded quiz',
        ClassworkType.boss => 'The weekly major assessment, published on its date',
        ClassworkType.activity => 'A short class activity',
      };

  static String _titleHint(ClassworkType t) => switch (t) {
        ClassworkType.lesson => 'e.g. Aralin 3: Mga Rehiyon ng Pilipinas',
        ClassworkType.quest => 'e.g. Ang Mga Rehiyon ng Pilipinas',
        ClassworkType.quiz => 'e.g. Kasaysayan ng Pilipinas',
        ClassworkType.boss => 'e.g. Kasaysayan ng Pilipinas',
        ClassworkType.activity => 'e.g. Mga Anyong Lupa at Tubig',
      };
}
