import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../classwork/editor/editor_fields.dart' show DateField, TimeField;

/// "Add event" (or edit an existing one).
Future<void> showEventDialog(BuildContext context, {CalendarEvent? existing, DateTime? date, String? classId}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _EventDialog(existing: existing, date: date, classId: classId),
    );

class _EventDialog extends ConsumerStatefulWidget {
  const _EventDialog({this.existing, this.date, this.classId});

  final CalendarEvent? existing;
  final DateTime? date;
  final String? classId;

  @override
  ConsumerState<_EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends ConsumerState<_EventDialog> {
  late final CalendarEvent? _e = widget.existing;
  late final _title = TextEditingController(text: _e?.title ?? '');
  late final _location = TextEditingController(text: _e?.location ?? '');
  late final _notes = TextEditingController(text: _e?.notes ?? '');
  late EventKind _kind = _e?.kind ?? (widget.classId == null ? EventKind.school : EventKind.classEvent);
  late String _classId = _e?.classId ?? widget.classId ?? '';
  late DateTime _date = _e?.start ?? widget.date ?? DateTime.now();
  late bool _allDay = _e?.allDay ?? true;
  late TimeOfDay _from = _e == null ? const TimeOfDay(hour: 8, minute: 0) : TimeOfDay.fromDateTime(_e.start);
  late TimeOfDay _to =
      _e == null || _e.end == null ? const TimeOfDay(hour: 9, minute: 0) : TimeOfDay.fromDateTime(_e.end!);
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  DateTime _at(TimeOfDay t) => DateTime(_date.year, _date.month, _date.day, t.hour, t.minute);

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      showToast('Give the event a title.');
      return;
    }
    if (!_allDay && !_at(_to).isAfter(_at(_from))) {
      showToast('The end time must be after the start time.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(calendarRepositoryProvider).save(CalendarEvent(
            id: _e?.id ?? '',
            title: _title.text,
            start: _allDay ? DateTime(_date.year, _date.month, _date.day) : _at(_from),
            end: _allDay ? null : _at(_to),
            allDay: _allDay,
            classId: _classId.isEmpty ? null : _classId,
            kind: _kind,
            location: _location.text,
            notes: _notes.text,
          ));
      if (!mounted) return;
      Navigator.pop(context);
      showToast(_e == null ? 'Event added' : 'Event updated');
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      showToast('Couldn’t save: $e');
    }
  }

  Future<void> _delete() async {
    final repo = ref.read(calendarRepositoryProvider);
    final ok = await confirmAction(
      context,
      title: 'Delete “${_e!.title}”?',
      message: 'It’s removed from your calendar.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await repo.delete(_e.id);
    if (mounted) Navigator.pop(context);
    showToast('Event deleted');
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(activeClassesProvider).valueOrNull ?? const <ClassRoom>[];
    Widget half(Widget a, Widget b) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: a),
          const SizedBox(width: 12),
          Expanded(child: b),
        ]);
    return AppDialog(
      maxWidth: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(_e == null ? 'Add event' : 'Edit event', style: AppText.dialogTitle)),
            IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
          ]),
          const SizedBox(height: 10),
          const FieldLabel('Title'),
          TextField(controller: _title, autofocus: _e == null, maxLength: 120,
              decoration: const InputDecoration(hintText: 'e.g. Faculty Meeting', counterText: '')),
          const SizedBox(height: 12),
          half(
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const FieldLabel('Type'),
              DropdownMenu<EventKind>(
                initialSelection: _kind,
                expandedInsets: EdgeInsets.zero,
                requestFocusOnTap: false,
                dropdownMenuEntries: [for (final k in EventKind.values) DropdownMenuEntry(value: k, label: k.label)],
                onSelected: (k) => setState(() => _kind = k ?? _kind),
              ),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const FieldLabel('Class'),
              DropdownMenu<String>(
                initialSelection: _classId,
                expandedInsets: EdgeInsets.zero,
                requestFocusOnTap: false,
                dropdownMenuEntries: [
                  const DropdownMenuEntry(value: '', label: 'All my classes'),
                  for (final c in classes) DropdownMenuEntry(value: c.id, label: c.name),
                ],
                onSelected: (v) => setState(() => _classId = v ?? ''),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          const FieldLabel('Date'),
          DateField(value: _date, onChanged: (d) => setState(() => _date = d)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('All day'),
            value: _allDay,
            onChanged: (v) => setState(() => _allDay = v),
          ),
          if (!_allDay)
            half(
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const FieldLabel('Starts'),
                TimeField(value: _from, onChanged: (t) => setState(() => _from = t)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const FieldLabel('Ends'),
                TimeField(value: _to, onChanged: (t) => setState(() => _to = t)),
              ]),
            ),
          const SizedBox(height: 12),
          const FieldLabel('Location (optional)'),
          TextField(controller: _location, maxLength: 120, decoration: const InputDecoration(counterText: '')),
          const SizedBox(height: 12),
          const FieldLabel('Notes (optional)'),
          TextField(controller: _notes, minLines: 2, maxLines: 4, maxLength: 1000),
          const SizedBox(height: 8),
          Row(children: [
            if (_e != null)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.red),
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete'),
              ),
            const Spacer(),
            OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: 12),
            FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
          ]),
        ],
      ),
    );
  }
}
