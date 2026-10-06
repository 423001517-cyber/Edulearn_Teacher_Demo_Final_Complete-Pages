import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../data/stream_repository.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import 'stream_widgets.dart';

/// "Announce something to your class" → the full editor.
///
/// With [existing] it edits that post (used in the Edit post dialog).
class StreamComposer extends ConsumerStatefulWidget {
  const StreamComposer({
    super.key,
    required this.classId,
    this.existing,
    this.startExpanded = false,
    this.pickFileOnOpen = false,
    this.onDone,
    this.trailing,
  });

  final String classId;
  final Announcement? existing;
  final bool startExpanded;

  /// Opened from the 📎 button: expand and pick a file straight away.
  final bool pickFileOnOpen;

  /// Called after posting / saving / cancelling (e.g. to close a dialog).
  final VoidCallback? onDone;

  /// Widgets beside the collapsed bar (the "All posts" filter, 📎).
  final List<Widget>? trailing;

  @override
  ConsumerState<StreamComposer> createState() => StreamComposerState();
}

class StreamComposerState extends ConsumerState<StreamComposer> {
  static const _allClasses = '';

  late bool _expanded = widget.startExpanded || widget.existing != null;
  final _text = TextEditingController();
  final _focus = FocusNode();
  late String _target = widget.existing == null
      ? widget.classId
      : (widget.existing!.classId ?? _allClasses);
  final List<PostAttachment> _attachments = [];

  /// Files uploaded in this session (deleted again if the teacher cancels).
  final List<PostAttachment> _uploadedNow = [];
  int _uploading = 0;
  bool _saving = false;

  /// Matches the security rules (attachments.size() <= 10).
  static const _maxAttachments = 10;

  bool _roomForMore() {
    if (_attachments.length + _uploading < _maxAttachments) return true;
    showToast('A post can have up to $_maxAttachments attachments.');
    return false;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _text.text = e.title.isEmpty ? e.body : '${e.title}\n${e.body}';
      _attachments.addAll(e.attachments);
    }
    if (widget.pickFileOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pickFile();
      });
    }
  }

  @override
  void didUpdateWidget(StreamComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Switching classes on the Stream page retargets a fresh composer.
    if (widget.existing == null && oldWidget.classId != widget.classId && !_expanded) {
      _target = widget.classId;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Opens the editor and asks for a file (the 📎 next to the filter).
  void openWithFile() {
    setState(() => _expanded = true);
    _pickFile();
  }

  // ------------------------------------------------------------ formatting
  void _wrap(String mark) {
    final t = _text.text;
    var sel = _text.selection;
    if (!sel.isValid) sel = TextSelection.collapsed(offset: t.length);
    final picked = sel.textInside(t);
    final replaced = '$mark$picked$mark';
    _text.value = TextEditingValue(
      text: t.replaceRange(sel.start, sel.end, replaced),
      selection: picked.isEmpty
          ? TextSelection.collapsed(offset: sel.start + mark.length)
          : TextSelection(baseOffset: sel.start, extentOffset: sel.start + replaced.length),
    );
    _focus.requestFocus();
  }

  /// Adds "• " to every selected line (or removes it if all have it).
  void _bullets() {
    final t = _text.text;
    var sel = _text.selection;
    if (!sel.isValid) sel = TextSelection.collapsed(offset: t.length);
    final lineStart = t.lastIndexOf('\n', sel.start == 0 ? 0 : sel.start - 1) + 1;
    var lineEnd = t.indexOf('\n', sel.end);
    if (lineEnd < 0) lineEnd = t.length;
    final lines = t.substring(lineStart, lineEnd).split('\n');
    final allBulleted = lines.every((l) => l.startsWith('• '));
    final next = lines.map((l) => allBulleted ? l.substring(2) : (l.startsWith('• ') ? l : '• $l')).join('\n');
    _text.value = TextEditingValue(
      text: t.replaceRange(lineStart, lineEnd, next),
      selection: TextSelection.collapsed(offset: lineStart + next.length),
    );
    _focus.requestFocus();
  }

  Future<void> _linkSelection() async {
    final sel = _text.selection;
    final picked = sel.isValid ? sel.textInside(_text.text) : '';
    final link = await askForUrl(context, title: 'Add link', withName: false);
    if (link == null) return;
    final t = _text.text;
    final s = sel.isValid ? sel : TextSelection.collapsed(offset: t.length);
    final label = picked.trim().isEmpty ? link.url : picked;
    final md = '[$label](${link.url})';
    _text.value = TextEditingValue(
      text: t.replaceRange(s.start, s.end, md),
      selection: TextSelection.collapsed(offset: s.start + md.length),
    );
  }

  // ------------------------------------------------------------ attachments
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true, allowMultiple: true);
    if (result == null || !mounted) return;
    final repo = ref.read(streamRepositoryProvider);
    for (final f in result.files) {
      final bytes = f.bytes;
      if (bytes == null) continue;
      if (!_roomForMore()) break;
      if (bytes.length > StreamRepository.maxBytes) {
        showToast('${f.name} is larger than 25 MB.');
        continue;
      }
      setState(() => _uploading++);
      try {
        final a = await repo.uploadFile(fileName: f.name, bytes: bytes);
        if (!mounted) {
          await repo.deleteFile(a);
          return;
        }
        setState(() {
          _attachments.add(a);
          _uploadedNow.add(a);
        });
      } catch (e) {
        showToast('Couldn’t upload ${f.name}: $e');
      } finally {
        if (mounted) setState(() => _uploading--);
      }
    }
  }

  Future<void> _addLink({required bool video}) async {
    if (!_roomForMore()) return;
    final r = await askForUrl(context, title: video ? 'Add video' : 'Add link', withName: true, video: video);
    if (r == null) return;
    setState(() => _attachments.add(PostAttachment(
          name: r.name.isNotEmpty ? r.name : (Uri.tryParse(r.url)?.host ?? r.url),
          url: r.url,
          kind: video ? AttachmentKind.video : AttachmentKind.link,
        )));
  }

  void _removeAttachment(PostAttachment a) {
    setState(() => _attachments.remove(a));
    if (_uploadedNow.remove(a)) ref.read(streamRepositoryProvider).deleteFile(a);
  }

  // ------------------------------------------------------------ actions
  void _cancel() {
    final repo = ref.read(streamRepositoryProvider);
    for (final a in _uploadedNow) {
      repo.deleteFile(a);
    }
    _uploadedNow.clear();
    _attachments
      ..clear()
      ..addAll(widget.existing?.attachments ?? const []);
    _text.clear();
    if (widget.onDone != null) {
      widget.onDone!();
    } else {
      setState(() => _expanded = false);
    }
  }

  bool get _isEmpty => _text.text.trim().isEmpty && _attachments.isEmpty;

  Future<void> _submit(PostStatus status, {DateTime? publishAt}) async {
    if (_isEmpty) {
      showToast('Write something or attach a file first.');
      return;
    }
    if (_uploading > 0) {
      showToast('Wait for the upload to finish.');
      return;
    }
    final parts = splitHeadline(_text.text);
    final e = widget.existing;
    final post = (e ?? const Announcement()).copyWith(
      classId: _target == _allClasses ? null : _target,
      clearClass: _target == _allClasses,
      title: parts.title,
      body: parts.body,
      status: status,
      publishAt: publishAt,
      clearPublishAt: publishAt == null,
      attachments: List.of(_attachments),
    );
    setState(() => _saving = true);
    try {
      await ref.read(streamRepositoryProvider).savePost(
            post,
            // Publishing a draft or scheduled post moves it to the top.
            bumpDate: e != null && e.status != PostStatus.published && status == PostStatus.published,
          );
      // Files removed from an existing post are deleted for good.
      if (e != null) {
        for (final old in e.attachments) {
          if (!_attachments.contains(old)) await ref.read(streamRepositoryProvider).deleteFile(old);
        }
      }
      _uploadedNow.clear();
      showToast(switch (status) {
        PostStatus.published => e != null && e.status == PostStatus.published ? 'Post updated' : 'Posted to the stream',
        PostStatus.scheduled => 'Scheduled for ${postTime(publishAt!)}',
        PostStatus.draft => 'Draft saved — find it under All posts → Drafts',
      });
      if (!mounted) return;
      _text.clear();
      _attachments.clear();
      setState(() => _saving = false);
      if (widget.onDone != null) {
        widget.onDone!();
      } else {
        setState(() => _expanded = false);
      }
    } catch (err) {
      if (mounted) setState(() => _saving = false);
      showToast('Couldn’t save the post: $err');
    }
  }

  Future<void> _schedule() async {
    final when = await showScheduleDialog(context, initial: widget.existing?.publishAt);
    if (when != null) await _submit(PostStatus.scheduled, publishAt: when);
  }

  // ------------------------------------------------------------ UI
  @override
  Widget build(BuildContext context) {
    final teacher = ref.watch(teacherProvider).valueOrNull;
    final name = teacher?.displayName ?? 'Teacher';
    final avatar = PersonAvatar(name: name, photoUrl: teacher?.photoUrl, size: 46);

    if (!_expanded) {
      return Container(
        decoration: AppDecorations.card,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 14),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    setState(() => _expanded = true);
                    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
                  },
                  child: Container(
                    height: 46,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('Announce something to your class',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.meta.copyWith(fontSize: 14)),
                  ),
                ),
              ),
            ),
            if (widget.trailing != null) ...[
              for (final w in widget.trailing!) ...[const SizedBox(width: 12), w],
            ],
          ],
        ),
      );
    }

    final classes = ref.watch(activeClassesProvider).valueOrNull ?? const <ClassRoom>[];
    final e = widget.existing;
    final editingLive = e != null && e.status == PostStatus.published;

    return Container(
      decoration: widget.onDone != null && e != null ? null : AppDecorations.card,
      padding: EdgeInsets.all(widget.onDone != null && e != null ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              avatar,
              const SizedBox(width: 14),
              FilterDropdown<String>(
                value: _target,
                options: {
                  for (final c in classes) c.id,
                  if (!classes.any((c) => c.id == _target)) _target,
                  _allClasses,
                }.toList(),
                labelOf: (id) => id == _allClasses
                    ? 'All my classes'
                    : (classes.where((c) => c.id == id).firstOrNull?.name ?? 'This class'),
                icon: Icons.groups_rounded,
                minWidth: 200,
                onChanged: (v) => setState(() => _target = v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            focusNode: _focus,
            minLines: 4,
            maxLines: 12,
            maxLength: 8000,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Share an announcement with your class...',
              counterText: '',
              helperText: 'Tip: a short first line becomes the bold headline.',
            ),
          ),
          if (_attachments.isNotEmpty || _uploading > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in _attachments) AttachmentChip(attachment: a, onRemove: () => _removeAttachment(a)),
                if (_uploading > 0)
                  const Chip(
                    avatar: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    label: Text('Uploading…'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 10,
            children: [
              Wrap(
                spacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Tool(icon: Icons.format_bold_rounded, tip: 'Bold', onTap: () => _wrap('**')),
                  _Tool(icon: Icons.format_italic_rounded, tip: 'Italic', onTap: () => _wrap('*')),
                  _Tool(icon: Icons.format_underline_rounded, tip: 'Underline', onTap: () => _wrap('__')),
                  _Tool(icon: Icons.format_list_bulleted_rounded, tip: 'Bulleted list', onTap: _bullets),
                  _Tool(icon: Icons.link_rounded, tip: 'Link selected text', onTap: _linkSelection),
                  Container(width: 1, height: 26, margin: const EdgeInsets.symmetric(horizontal: 10), color: AppColors.border),
                  _AttachButton(icon: Icons.attach_file_rounded, label: 'File', onTap: _pickFile),
                  const SizedBox(width: 8),
                  _AttachButton(icon: Icons.link_rounded, label: 'Link', onTap: () => _addLink(video: false)),
                  const SizedBox(width: 8),
                  _AttachButton(icon: Icons.smart_display_outlined, label: 'Video', onTap: () => _addLink(video: true)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(onPressed: _saving ? null : _cancel, child: const Text('Cancel')),
                  const SizedBox(width: 10),
                  if (editingLive)
                    FilledButton(
                      onPressed: _saving || _isEmpty ? null : () => _submit(PostStatus.published),
                      child: const Text('Save'),
                    )
                  else
                    _PostSplitButton(
                      enabled: !_saving && !_isEmpty,
                      onPost: () => _submit(PostStatus.published),
                      onSchedule: _schedule,
                      onDraft: () => _submit(PostStatus.draft),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({required this.icon, required this.tip, required this.onTap});

  final IconData icon;
  final String tip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tip,
        onPressed: onTap,
        icon: Icon(icon, color: AppColors.ink),
      );
}

class _AttachButton extends StatelessWidget {
  const _AttachButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
}

enum _PostChoice { now, schedule, draft }

/// [ Post | ▾ ] — Post now · Schedule · Save draft.
class _PostSplitButton extends StatelessWidget {
  const _PostSplitButton({
    required this.enabled,
    required this.onPost,
    required this.onSchedule,
    required this.onDraft,
  });

  final bool enabled;
  final VoidCallback onPost;
  final VoidCallback onSchedule;
  final VoidCallback onDraft;

  @override
  Widget build(BuildContext context) {
    const radius = Radius.circular(10);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton(
          style: FilledButton.styleFrom(
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(left: radius)),
            minimumSize: const Size(84, 46),
          ),
          onPressed: enabled ? onPost : null,
          child: const Text('Post'),
        ),
        Container(width: 1, height: 46, color: Colors.white.withValues(alpha: 0.4)),
        PopupMenuButton<_PostChoice>(
          enabled: enabled,
          tooltip: 'More posting options',
          position: PopupMenuPosition.under,
          offset: const Offset(0, 6),
          onSelected: (c) {
            switch (c) {
              case _PostChoice.now:
                onPost();
              case _PostChoice.schedule:
                onSchedule();
              case _PostChoice.draft:
                onDraft();
            }
          },
          itemBuilder: (_) => [
            menuItem(_PostChoice.now, Icons.send_outlined, 'Post now'),
            menuItem(_PostChoice.schedule, Icons.schedule_rounded, 'Schedule'),
            menuItem(_PostChoice.draft, Icons.description_outlined, 'Save draft'),
          ],
          child: Container(
            height: 46,
            width: 44,
            decoration: BoxDecoration(
              color: enabled ? AppColors.primary : AppColors.buttonGrey,
              borderRadius: const BorderRadius.horizontal(right: radius),
            ),
            child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// "Schedule announcement" — date + time; returns the chosen moment.
Future<DateTime?> showScheduleDialog(BuildContext context, {DateTime? initial}) =>
    showDialog<DateTime>(context: context, builder: (_) => _ScheduleDialog(initial: initial));

class _ScheduleDialog extends StatefulWidget {
  const _ScheduleDialog({this.initial});

  final DateTime? initial;

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  late DateTime _date;
  late TimeOfDay _time;
  String? _error;

  static final _slots = [
    for (var m = 0; m < 24 * 60; m += 30) TimeOfDay(hour: m ~/ 60, minute: m % 60),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final start = widget.initial != null && widget.initial!.isAfter(now)
        ? widget.initial!
        : DateTime(now.year, now.month, now.day + 1, 8);
    _date = DateTime(start.year, start.month, start.day);
    _time = TimeOfDay(hour: start.hour, minute: start.minute < 30 ? 0 : 30);
  }

  DateTime get _when => DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _date = d);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      maxWidth: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Schedule announcement', style: AppText.dialogTitle)),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const FieldLabel('Date'),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.calendar_month_outlined),
                suffixIcon: Icon(Icons.event_rounded),
              ),
              child: Text(fullDate(_date)),
            ),
          ),
          const SizedBox(height: 14),
          const FieldLabel('Time'),
          DropdownMenu<TimeOfDay>(
            initialSelection: _slots.firstWhere(
              (t) => t.hour == _time.hour && t.minute == _time.minute,
              orElse: () => _slots[16],
            ),
            expandedInsets: EdgeInsets.zero,
            requestFocusOnTap: false,
            menuHeight: 300,
            leadingIcon: const Icon(Icons.schedule_rounded),
            dropdownMenuEntries: [for (final t in _slots) DropdownMenuEntry(value: t, label: clockTime(t))],
            onSelected: (t) => setState(() => _time = t ?? _time),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.red)),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    if (!_when.isAfter(DateTime.now())) {
                      setState(() => _error = 'Pick a time in the future.');
                      return;
                    }
                    Navigator.pop(context, _when);
                  },
                  child: const Text('Schedule'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Link / video URL dialog. Returns null if cancelled.
Future<({String url, String name})?> askForUrl(
  BuildContext context, {
  required String title,
  required bool withName,
  bool video = false,
}) =>
    showDialog<({String url, String name})>(
      context: context,
      builder: (_) => _UrlDialog(title: title, withName: withName, video: video),
    );

class _UrlDialog extends StatefulWidget {
  const _UrlDialog({required this.title, required this.withName, required this.video});

  final String title;
  final bool withName;
  final bool video;

  @override
  State<_UrlDialog> createState() => _UrlDialogState();
}

class _UrlDialogState extends State<_UrlDialog> {
  final _formKey = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    _url.dispose();
    _name.dispose();
    super.dispose();
  }

  void _add() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, (url: _url.text.trim(), name: _name.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      maxWidth: 460,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: AppText.dialogTitle),
            const SizedBox(height: 14),
            FieldLabel(widget.video ? 'Video link (YouTube or other)' : 'Web address'),
            TextFormField(
              controller: _url,
              autofocus: true,
              keyboardType: TextInputType.url,
              onFieldSubmitted: (_) => _add(),
              decoration: InputDecoration(hintText: widget.video ? 'https://youtu.be/…' : 'https://…'),
              validator: (v) {
                final u = Uri.tryParse((v ?? '').trim());
                return u == null || !(u.isScheme('http') || u.isScheme('https')) || u.host.isEmpty
                    ? 'Enter a full link starting with https://'
                    : null;
              },
            ),
            if (widget.withName) ...[
              const SizedBox(height: 12),
              const FieldLabel('Title (optional)'),
              TextFormField(controller: _name, onFieldSubmitted: (_) => _add()),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(onPressed: _add, child: const Text('Add'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
