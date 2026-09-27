import 'dart:typed_data';

import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation.dart';
import '../../../providers/core_providers.dart';

/// "Archive Grade 4 – Rizal?" — the red button stays disabled until the
/// teacher ticks "I understand this class can be restored later."
Future<bool> showArchiveClassDialog(BuildContext context, ClassRoom c) async {
  final ok = await showDialog<bool>(context: context, builder: (_) => _ArchiveDialog(classRoom: c));
  return ok ?? false;
}

class _ArchiveDialog extends StatefulWidget {
  const _ArchiveDialog({required this.classRoom});

  final ClassRoom classRoom;

  @override
  State<_ArchiveDialog> createState() => _ArchiveDialogState();
}

class _ArchiveDialogState extends State<_ArchiveDialog> {
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      maxWidth: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(context, false),
              icon: const Icon(Icons.close_rounded, color: AppColors.inkSoft),
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: AppColors.redSoft, shape: BoxShape.circle),
            child: const Icon(Icons.error_rounded, color: AppColors.red, size: 36),
          ),
          const SizedBox(height: 16),
          Text('Archive ${widget.classRoom.name}?',
              textAlign: TextAlign.center, style: AppText.dialogTitle),
          const SizedBox(height: 10),
          Text(
            'Students and teachers will no longer see this class under Active Classes. '
            'Existing lessons, submissions, grades, and reports will be preserved.',
            textAlign: TextAlign.center,
            style: AppText.meta.copyWith(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _understood = !_understood),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: _understood,
                  onChanged: (v) => setState(() => _understood = v ?? false),
                ),
                const Flexible(
                  child: Text('I understand this class can be restored later.',
                      style: TextStyle(fontSize: 13.5)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.red,
                    disabledBackgroundColor: AppColors.red.withValues(alpha: 0.35),
                    disabledForegroundColor: Colors.white,
                  ),
                  onPressed: _understood ? () => Navigator.pop(context, true) : null,
                  child: const Text('Archive Class'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Subject and cover image. Grade, section and class code are official and
/// can only be changed by the administrator.
Future<void> showClassSettings(BuildContext context, ClassRoom c) =>
    showDialog<void>(context: context, builder: (_) => _ClassSettingsDialog(classRoom: c));

class _ClassSettingsDialog extends ConsumerStatefulWidget {
  const _ClassSettingsDialog({required this.classRoom});

  final ClassRoom classRoom;

  @override
  ConsumerState<_ClassSettingsDialog> createState() => _ClassSettingsDialogState();
}

class _ClassSettingsDialogState extends ConsumerState<_ClassSettingsDialog> {
  late final _subject = TextEditingController(text: widget.classRoom.subject);
  Uint8List? _cover;
  String? _coverName;
  bool _saving = false;

  @override
  void dispose() {
    _subject.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final file = result?.files.single;
    if (file?.bytes == null) return;
    if (file!.size > 5 * 1024 * 1024) {
      showToast('Choose an image under 5 MB.');
      return;
    }
    setState(() {
      _cover = file.bytes;
      _coverName = file.name;
    });
  }

  Future<void> _save() async {
    if (_subject.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(classesRepositoryProvider).updateClassSettings(
            widget.classRoom.id,
            subject: _subject.text,
            coverBytes: _cover,
            coverFileName: _coverName,
          );
      if (!mounted) return;
      Navigator.pop(context);
      showToast('Class settings saved');
    } catch (e) {
      setState(() => _saving = false);
      showToast("Couldn't save: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.classRoom;
    return AppDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(title: 'Class Settings', subtitle: c.name),
          const SizedBox(height: 16),
          const FieldLabel('Cover image'),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 140,
              child: _cover != null
                  ? Image.memory(_cover!, fit: BoxFit.cover)
                  : ClassThumbnail(classRoom: c, height: 140, radius: 12),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _saving ? null : _pickCover,
              icon: const Icon(Icons.image_outlined),
              label: const Text('Change cover'),
            ),
          ),
          const SizedBox(height: 14),
          const FieldLabel('Subject'),
          TextField(controller: _subject),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.blueSoft, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.link),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Grade ${c.gradeLevel}, section ${c.section} and class code '
                    '${c.classCode} are managed by your administrator.',
                    style: AppText.meta.copyWith(color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                    onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                    onPressed: _saving ? null : _save, child: const Text('Save changes')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "+ Request New Class" — sends a request to the administrator.
Future<void> showRequestClassDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _RequestClassDialog());

class _RequestClassDialog extends ConsumerStatefulWidget {
  const _RequestClassDialog();

  @override
  ConsumerState<_RequestClassDialog> createState() => _RequestClassDialogState();
}

class _RequestClassDialogState extends ConsumerState<_RequestClassDialog> {
  final _formKey = GlobalKey<FormState>();
  final _section = TextEditingController();
  final _subject = TextEditingController(text: 'Araling Panlipunan');
  final _note = TextEditingController();
  int _grade = 4;
  bool _saving = false;

  @override
  void dispose() {
    _section.dispose();
    _subject.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(classesRepositoryProvider).requestNewClass(
            gradeLevel: _grade,
            section: _section.text,
            subject: _subject.text,
            note: _note.text,
          );
      if (!mounted) return;
      Navigator.pop(context);
      showToast('Request sent. Your administrator will create the class and its code.');
    } catch (e) {
      setState(() => _saving = false);
      showToast("Couldn't send the request: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      maxWidth: 480,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PanelHeader(
              title: 'Request New Class',
              subtitle: 'Official classes and class codes are approved by the administrator',
              leading: ToneIcon(Icons.add_rounded, tone: Tone.green, size: 46),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FieldLabel('Grade'),
                      DropdownMenu<int>(
                        initialSelection: _grade,
                        expandedInsets: EdgeInsets.zero,
                        requestFocusOnTap: false,
                        dropdownMenuEntries: [
                          for (var g = 1; g <= 12; g++) DropdownMenuEntry(value: g, label: 'Grade $g'),
                        ],
                        onSelected: (v) => setState(() => _grade = v ?? _grade),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FieldLabel('Section'),
                      TextFormField(
                        controller: _section,
                        decoration: const InputDecoration(hintText: 'e.g. Luna'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Add a section name.' : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const FieldLabel('Subject'),
            TextFormField(
              controller: _subject,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Add a subject.' : null,
            ),
            const SizedBox(height: 14),
            const FieldLabel('Note to administrator (optional)'),
            TextFormField(controller: _note, minLines: 2, maxLines: 4),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                      onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                      onPressed: _saving ? null : _submit, child: const Text('Send request')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
