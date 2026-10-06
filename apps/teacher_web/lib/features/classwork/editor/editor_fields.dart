import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation.dart';
import '../../../data/stream_repository.dart';
import '../../../providers/classes_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/data_providers.dart';
import '../../stream/stream_composer.dart' show askForUrl;
import '../../stream/stream_widgets.dart';

/// A card with a bold title ("Quest details", "Classwork settings").
class EditorCard extends StatelessWidget {
  const EditorCard({super.key, required this.title, required this.children, this.tint});

  final String title;
  final List<Widget> children;

  /// Friday Boss uses a warm tint.
  final Color? tint;

  @override
  Widget build(BuildContext context) => Container(
        decoration: AppDecorations.card.copyWith(color: tint),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppText.sectionTitle.copyWith(fontSize: 17)),
            const Divider(height: 24),
            ...children,
          ],
        ),
      );
}

/// Label with a red * for required fields.
class RequiredLabel extends StatelessWidget {
  const RequiredLabel(this.text, {super.key, this.isRequired = true});

  final String text;
  final bool isRequired;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
          if (isRequired) const TextSpan(text: ' *', style: TextStyle(color: AppColors.red)),
        ])),
      );
}

/// Multi-line text with the B / I / U / • / 1. / link toolbar (same marks
/// as stream posts: **bold**, *italic*, __underline__, "• ", [text](url)).
class RichTextBox extends StatefulWidget {
  const RichTextBox({super.key, required this.controller, this.hint = '', this.minLines = 5, this.validator});

  final TextEditingController controller;
  final String hint;
  final int minLines;
  final FormFieldValidator<String>? validator;

  @override
  State<RichTextBox> createState() => _RichTextBoxState();
}

class _RichTextBoxState extends State<RichTextBox> {
  final _focus = FocusNode();

  TextEditingController get _c => widget.controller;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _wrap(String mark) {
    final t = _c.text;
    var sel = _c.selection;
    if (!sel.isValid) sel = TextSelection.collapsed(offset: t.length);
    final picked = sel.textInside(t);
    final out = '$mark$picked$mark';
    _c.value = TextEditingValue(
      text: t.replaceRange(sel.start, sel.end, out),
      selection: picked.isEmpty
          ? TextSelection.collapsed(offset: sel.start + mark.length)
          : TextSelection(baseOffset: sel.start, extentOffset: sel.start + out.length),
    );
    _focus.requestFocus();
  }

  void _prefixLines({required bool numbered}) {
    final t = _c.text;
    var sel = _c.selection;
    if (!sel.isValid) sel = TextSelection.collapsed(offset: t.length);
    final start = t.lastIndexOf('\n', sel.start == 0 ? 0 : sel.start - 1) + 1;
    var end = t.indexOf('\n', sel.end);
    if (end < 0) end = t.length;
    final lines = t.substring(start, end).split('\n');
    final numberRe = RegExp(r'^\d+\. ');
    var n = 0;
    final next = lines.map((l) {
      final bare = l.startsWith('• ') ? l.substring(2) : l.replaceFirst(numberRe, '');
      n++;
      return numbered ? '$n. $bare' : '• $bare';
    }).join('\n');
    _c.value = TextEditingValue(
      text: t.replaceRange(start, end, next),
      selection: TextSelection.collapsed(offset: start + next.length),
    );
    _focus.requestFocus();
  }

  Future<void> _link() async {
    final sel = _c.selection;
    final picked = sel.isValid ? sel.textInside(_c.text) : '';
    final link = await askForUrl(context, title: 'Add link', withName: false);
    if (link == null) return;
    final t = _c.text;
    final s = sel.isValid ? sel : TextSelection.collapsed(offset: t.length);
    final md = '[${picked.trim().isEmpty ? link.url : picked}](${link.url})';
    _c.value = TextEditingValue(
      text: t.replaceRange(s.start, s.end, md),
      selection: TextSelection.collapsed(offset: s.start + md.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget tool(IconData icon, String tip, VoidCallback onTap) => IconButton(
          tooltip: tip,
          visualDensity: VisualDensity.compact,
          onPressed: onTap,
          icon: Icon(icon, size: 20, color: AppColors.ink),
        );
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.chip.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Wrap(children: [
              tool(Icons.format_bold_rounded, 'Bold', () => _wrap('**')),
              tool(Icons.format_italic_rounded, 'Italic', () => _wrap('*')),
              tool(Icons.format_underline_rounded, 'Underline', () => _wrap('__')),
              tool(Icons.format_list_bulleted_rounded, 'Bulleted list', () => _prefixLines(numbered: false)),
              tool(Icons.format_list_numbered_rounded, 'Numbered list', () => _prefixLines(numbered: true)),
              tool(Icons.link_rounded, 'Link selected text', _link),
            ]),
          ),
          TextFormField(
            controller: _c,
            focusNode: _focus,
            minLines: widget.minLines,
            maxLines: widget.minLines + 10,
            maxLength: 8000,
            validator: widget.validator,
            decoration: InputDecoration(
              hintText: widget.hint,
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }
}

/// File · Link · Video · From library, plus the list of attachments.
class AttachmentsField extends ConsumerStatefulWidget {
  const AttachmentsField({super.key, required this.value, required this.onChanged, required this.classId});

  final List<PostAttachment> value;
  final ValueChanged<List<PostAttachment>> onChanged;
  final String? classId;

  @override
  ConsumerState<AttachmentsField> createState() => _AttachmentsFieldState();
}

class _AttachmentsFieldState extends ConsumerState<AttachmentsField> {
  int _uploading = 0;

  bool _room() {
    if (widget.value.length + _uploading < 10) return true;
    showToast('Up to 10 attachments per item.');
    return false;
  }

  Future<void> _file() async {
    final result = await FilePicker.platform.pickFiles(withData: true, allowMultiple: true);
    if (result == null) return;
    final repo = ref.read(streamRepositoryProvider);
    var list = [...widget.value];
    for (final f in result.files) {
      final bytes = f.bytes;
      if (bytes == null || !_room()) continue;
      if (bytes.length > StreamRepository.maxBytes) {
        showToast('${f.name} is larger than 25 MB.');
        continue;
      }
      setState(() => _uploading++);
      try {
        final a = await repo.uploadFile(fileName: f.name, bytes: bytes);
        list = [...list, a];
        widget.onChanged(list);
      } catch (e) {
        showToast('Couldn’t upload ${f.name}: $e');
      } finally {
        if (mounted) setState(() => _uploading--);
      }
    }
  }

  Future<void> _link({required bool video}) async {
    if (!_room()) return;
    final r = await askForUrl(context, title: video ? 'Add video' : 'Add link', withName: true, video: video);
    if (r == null) return;
    widget.onChanged([
      ...widget.value,
      PostAttachment(
        name: r.name.isNotEmpty ? r.name : (Uri.tryParse(r.url)?.host ?? r.url),
        url: r.url,
        kind: video ? AttachmentKind.video : AttachmentKind.link,
      ),
    ]);
  }

  /// Files already used on this class's classwork.
  Future<void> _library() async {
    final classId = widget.classId;
    if (classId == null) {
      showToast('Choose a class first.');
      return;
    }
    final items = ref.read(classClassworkProvider(classId)).valueOrNull ?? const <ClassworkItem>[];
    final seen = <String>{};
    final files = [
      for (final w in items)
        for (final a in w.allAttachments)
          if (a.url != null && seen.add(a.url!)) a,
    ];
    final picked = await showDialog<PostAttachment>(
      context: context,
      builder: (ctx) => AppDialog(
        maxWidth: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PanelHeader(title: 'From library', subtitle: 'Files and links used in this class'),
            const SizedBox(height: 10),
            if (files.isEmpty)
              const EmptyNote('Nothing yet — files you attach to classwork appear here.')
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final f in files)
                      ListTile(
                        leading: Icon(switch (f.kind) {
                          AttachmentKind.link => Icons.link_rounded,
                          AttachmentKind.video => Icons.smart_display_rounded,
                          AttachmentKind.file => Icons.insert_drive_file_rounded,
                        }),
                        title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: f.sizeLabel.isEmpty ? null : Text(f.sizeLabel),
                        onTap: () => Navigator.pop(ctx, f),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    if (picked != null && _room()) widget.onChanged([...widget.value, picked]);
  }

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String label, VoidCallback onTap) => OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48), padding: const EdgeInsets.symmetric(horizontal: 16)),
          onPressed: onTap,
          icon: Icon(icon, size: 19),
          label: Text(label),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(spacing: 10, runSpacing: 10, children: [
          button(Icons.insert_drive_file_outlined, 'File', _file),
          button(Icons.link_rounded, 'Link', () => _link(video: false)),
          button(Icons.smart_display_outlined, 'Video', () => _link(video: true)),
          button(Icons.folder_open_rounded, 'From library', _library),
        ]),
        if (widget.value.isNotEmpty || _uploading > 0) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final a in widget.value)
              AttachmentChip(
                attachment: a,
                onRemove: () => widget.onChanged([...widget.value]..remove(a)),
              ),
            if (_uploading > 0)
              const Chip(
                avatar: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                label: Text('Uploading…'),
              ),
          ]),
        ],
      ],
    );
  }
}

/// Number box with an icon (points, XP, HP…).
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.controller,
    this.icon,
    this.suffix,
    this.min = 0,
    this.max = 1000,
    this.enabled = true,
  });

  final TextEditingController controller;
  final IconData? icon;
  final String? suffix;
  final int min;
  final int max;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          prefixIcon: icon == null ? null : Icon(icon, size: 19),
          suffixText: suffix,
        ),
        validator: (v) {
          final n = int.tryParse(v ?? '');
          return n == null || n < min || n > max ? '$min–$max' : null;
        },
      );
}

/// A toggle row: label (+ hint) on the left, switch on the right.
class ToggleRow extends StatelessWidget {
  const ToggleRow({super.key, required this.label, this.hint, required this.value, required this.onChanged});

  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Switch(value: value, onChanged: onChanged),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                if (hint != null) Text(hint!, style: AppText.meta.copyWith(fontSize: 12)),
              ],
            ),
          ),
        ]),
      );
}

/// "All students" or a hand-picked list (remedial work).
class StudentsPicker extends ConsumerWidget {
  const StudentsPicker({super.key, required this.classId, required this.value, required this.onChanged});

  final String? classId;
  final List<String> value;
  final ValueChanged<List<String>> onChanged;

  Future<void> _choose(BuildContext context, List<Student> roster) async {
    final picked = {...value};
    final result = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AppDialog(
          maxWidth: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PanelHeader(title: 'Assign to', subtitle: 'Leave everyone unticked for all students'),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: ListView(shrinkWrap: true, children: [
                  for (final s in roster)
                    CheckboxListTile(
                      value: picked.contains(s.id),
                      title: Text(s.name),
                      subtitle: Text(s.numberLabel),
                      onChanged: (v) => setLocal(() => v == true ? picked.add(s.id) : picked.remove(s.id)),
                    ),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(onPressed: () => Navigator.pop(ctx, picked.toList()), child: const Text('Done')),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = classId == null
        ? const <Student>[]
        : (ref.watch(classStudentsProvider(classId!)).valueOrNull ?? const <Student>[]);
    final label = value.isEmpty ? 'All students' : '${value.length} student${value.length == 1 ? '' : 's'}';
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        alignment: Alignment.centerLeft,
        foregroundColor: AppColors.ink,
      ),
      onPressed: roster.isEmpty ? null : () => _choose(context, roster),
      icon: const Icon(Icons.groups_rounded, size: 19),
      label: Row(children: [Expanded(child: Text(label)), const Icon(Icons.keyboard_arrow_down_rounded)]),
    );
  }
}

/// Date box that opens a date picker.
class DateField extends StatelessWidget {
  const DateField({super.key, required this.value, required this.onChanged});

  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final now = DateTime.now();
          final d = await showDatePicker(
            context: context,
            initialDate: value,
            firstDate: DateTime(now.year - 1),
            lastDate: DateTime(now.year + 2),
          );
          if (d != null) onChanged(DateTime(d.year, d.month, d.day, value.hour, value.minute));
        },
        child: InputDecorator(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.calendar_today_outlined, size: 19)),
          child: Text(fullDate(value)),
        ),
      );
}

/// Due time in 30-minute steps (plus 11:59 PM).
class TimeField extends StatelessWidget {
  const TimeField({super.key, required this.value, required this.onChanged});

  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;

  static final _slots = [
    for (var m = 0; m < 24 * 60; m += 30) TimeOfDay(hour: m ~/ 60, minute: m % 60),
    const TimeOfDay(hour: 23, minute: 59),
  ];

  @override
  Widget build(BuildContext context) => DropdownMenu<TimeOfDay>(
        initialSelection: _slots.firstWhere((t) => t == value, orElse: () => _slots.last),
        expandedInsets: EdgeInsets.zero,
        requestFocusOnTap: false,
        menuHeight: 300,
        leadingIcon: const Icon(Icons.schedule_rounded, size: 19),
        dropdownMenuEntries: [for (final t in _slots) DropdownMenuEntry(value: t, label: clockTime(t))],
        onSelected: (t) => onChanged(t ?? value),
      );
}
