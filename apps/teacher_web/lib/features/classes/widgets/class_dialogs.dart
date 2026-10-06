import 'dart:typed_data';

import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation.dart';
import '../../../providers/core_providers.dart';

/// "Archive Grade 4 – Rizal?" — the red button stays disabled until the
/// teacher ticks "I understand that this class will be archived".
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
            child: const Icon(Icons.inventory_2_rounded, color: AppColors.red, size: 32),
          ),
          const SizedBox(height: 16),
          Text('Archive ${widget.classRoom.name}?',
              textAlign: TextAlign.center, style: AppText.dialogTitle),
          const SizedBox(height: 10),
          Text(
            'The class will be removed from active classes. Students and teachers can still '
            'view archived classwork. You can restore it later.',
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
                  child: Text('I understand that this class will be archived',
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
                  child: const Text('Archive class'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('This does not permanently delete the class.',
              style: AppText.meta.copyWith(fontSize: 12.5)),
        ],
      ),
    );
  }
}

/// "Edit class details": cover, subject, room and description. Class name
/// and section are official and only the administrator changes them.
Future<void> showEditClassDetails(BuildContext context, ClassRoom c) =>
    showDialog<void>(context: context, builder: (_) => _EditClassDetailsDialog(classRoom: c));

class _EditClassDetailsDialog extends ConsumerStatefulWidget {
  const _EditClassDetailsDialog({required this.classRoom});

  final ClassRoom classRoom;

  @override
  ConsumerState<_EditClassDetailsDialog> createState() => _EditClassDetailsDialogState();
}

class _EditClassDetailsDialogState extends ConsumerState<_EditClassDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _subject = TextEditingController(text: widget.classRoom.subject);
  late final _room = TextEditingController(text: widget.classRoom.room);
  late final _description = TextEditingController(text: widget.classRoom.description);
  Uint8List? _cover;
  String? _coverName;
  bool _saving = false;

  @override
  void dispose() {
    _subject.dispose();
    _room.dispose();
    _description.dispose();
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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(classesRepositoryProvider).updateClassDetails(
            widget.classRoom.id,
            subject: _subject.text,
            room: _room.text,
            description: _description.text,
            coverBytes: _cover,
            coverFileName: _coverName,
          );
      if (!mounted) return;
      Navigator.pop(context);
      showToast('Class details saved');
    } catch (e) {
      setState(() => _saving = false);
      showToast("Couldn't save: $e");
    }
  }

  Widget _readOnly(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldLabel(label),
          Tooltip(
            message: 'Set by your administrator',
            child: InputDecorator(
              decoration: const InputDecoration(
                filled: true,
                fillColor: AppColors.chip,
                suffixIcon: Icon(Icons.lock_outline_rounded, size: 18),
              ),
              child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      );

  Widget _pair(Widget a, Widget b) => LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 420) return Column(children: [a, const SizedBox(height: 14), b]);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: a), const SizedBox(width: 14), Expanded(child: b)],
        );
      });

  @override
  Widget build(BuildContext context) {
    final c = widget.classRoom;
    return AppDialog(
      maxWidth: 640,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Edit class details', style: AppText.dialogTitle)),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 170,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _cover != null
                          ? Image.memory(_cover!, fit: BoxFit.cover)
                          : ClassThumbnail(classRoom: c, height: 170, radius: 0),
                    ),
                    Positioned(
                      right: 14,
                      bottom: 14,
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        elevation: 1,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: _saving ? null : _pickCover,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.photo_camera_rounded, size: 20, color: AppColors.ink),
                                SizedBox(width: 8),
                                Text('Change cover', style: TextStyle(fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _pair(_readOnly('Class name', c.name), _readOnly('Section', c.section)),
            const SizedBox(height: 14),
            _pair(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FieldLabel('Subject'),
                  TextFormField(
                    controller: _subject,
                    maxLength: 80,
                    decoration: const InputDecoration(counterText: ''),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Add a subject.' : null,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FieldLabel('Room'),
                  TextFormField(
                    controller: _room,
                    maxLength: 60,
                    decoration: const InputDecoration(hintText: 'e.g. Grade 4 Room', counterText: ''),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const FieldLabel('Description'),
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 5,
              maxLength: 1000,
              decoration: const InputDecoration(hintText: 'A short welcome or what the class is about'),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 12),
                FilledButton(onPressed: _saving ? null : _save, child: const Text('Save changes')),
              ],
            ),
          ],
        ),
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
