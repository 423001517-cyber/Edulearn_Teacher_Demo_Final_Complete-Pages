import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';

Future<void> showAnnouncementForm(BuildContext context, {Announcement? existing, String? classId}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _AnnouncementForm(existing: existing, classId: existing?.classId ?? classId),
    );

class _AnnouncementForm extends ConsumerStatefulWidget {
  const _AnnouncementForm({this.existing, this.classId});

  final Announcement? existing;
  final String? classId;

  @override
  ConsumerState<_AnnouncementForm> createState() => _AnnouncementFormState();
}

class _AnnouncementFormState extends ConsumerState<_AnnouncementForm> {
  static const _allClasses = '';
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _body = TextEditingController(text: widget.existing?.body ?? '');
  late String _classId = widget.classId ?? _allClasses;
  late bool _pinned = widget.existing?.pinned ?? false;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(dashboardRepositoryProvider).saveAnnouncement(Announcement(
            id: widget.existing?.id ?? '',
            classId: _classId == _allClasses ? null : _classId,
            title: _title.text.trim(),
            body: _body.text.trim(),
            pinned: _pinned,
          ));
      if (!mounted) return;
      Navigator.pop(context);
      showToast(widget.existing == null ? 'Announcement posted' : 'Announcement updated');
    } catch (e) {
      setState(() => _saving = false);
      showToast("Couldn't save: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(activeClassesProvider).valueOrNull ?? const <ClassRoom>[];
    return AppDialog(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PanelHeader(
              title: widget.existing == null ? 'New Announcement' : 'Edit Announcement',
              subtitle: 'Post an update to the class stream',
              leading: const ToneIcon(Icons.campaign_outlined, tone: Tone.red, size: 46),
            ),
            const SizedBox(height: 18),
            const FieldLabel('Post to'),
            DropdownMenu<String>(
              initialSelection: _classId,
              expandedInsets: EdgeInsets.zero,
              requestFocusOnTap: false,
              dropdownMenuEntries: [
                const DropdownMenuEntry(value: _allClasses, label: 'All my classes'),
                for (final c in classes) DropdownMenuEntry(value: c.id, label: c.name),
              ],
              onSelected: (v) => setState(() => _classId = v ?? _allClasses),
            ),
            const SizedBox(height: 14),
            const FieldLabel('Title'),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(hintText: 'e.g. Field trip forms are now available'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Add a title.' : null,
            ),
            const SizedBox(height: 14),
            const FieldLabel('Message'),
            TextFormField(
              controller: _body,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(hintText: 'Please submit the signed forms by…'),
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _pinned,
              onChanged: (v) => setState(() => _pinned = v),
              title: const Text('Pin to the top', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                      onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(widget.existing == null ? 'Post' : 'Save changes'),
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

/// One announcement row with the View / Edit / Pin / Delete menu.
class AnnouncementTile extends ConsumerWidget {
  const AnnouncementTile({super.key, required this.announcement, this.compact = false});

  final Announcement announcement;

  /// Stacked title/body with a megaphone icon (class page style).
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = announcement;
    final date = a.createdAt == null ? 'Just now' : dayMonth(a.createdAt!);
    final menu = MoreMenu<String>(
      items: [
        menuItem('view', Icons.visibility_outlined, 'View'),
        menuItem('edit', Icons.edit_outlined, 'Edit'),
        menuItem('pin', Icons.push_pin_outlined, a.pinned ? 'Unpin' : 'Pin'),
        menuItem('delete', Icons.delete_outline_rounded, 'Delete', destructive: true),
      ],
      onSelected: (v) async {
        final repo = ref.read(dashboardRepositoryProvider);
        switch (v) {
          case 'view':
            _view(context, a);
          case 'edit':
            showAnnouncementForm(context, existing: a);
          case 'pin':
            await repo.setAnnouncementPinned(a.id, !a.pinned);
            showToast(a.pinned ? 'Unpinned' : 'Pinned to the top');
          case 'delete':
            final ok = await confirmAction(
              context,
              title: 'Delete this announcement?',
              message: '"${a.title}" will be removed from the class stream.',
              confirmLabel: 'Delete',
              destructive: true,
            );
            if (ok) await repo.deleteAnnouncement(a.id);
        }
      },
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ToneIcon(a.pinned ? Icons.push_pin_rounded : Icons.campaign_outlined,
                tone: a.pinned ? Tone.amber : Tone.blue, size: 36, circle: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  Text(
                    a.createdAt == null
                        ? 'Just now'
                        : 'Posted on $date · ${timeAgo(a.createdAt!)}',
                    style: AppText.meta.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            menu,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          if (a.pinned)
            const Icon(Icons.push_pin_rounded, size: 16, color: AppColors.amber)
          else
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            ),
          const SizedBox(width: 14),
          SizedBox(width: 56, child: Text(date, style: AppText.meta.copyWith(fontSize: 13))),
          Container(width: 1, height: 20, color: AppColors.border),
          const SizedBox(width: 16),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              final title = Text(a.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5));
              final body = Text(a.body,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.meta);
              if (c.maxWidth < 420) {
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, body]);
              }
              return Row(children: [
                Flexible(flex: 5, child: title),
                const SizedBox(width: 24),
                Expanded(flex: 6, child: body),
              ]);
            }),
          ),
          const SizedBox(width: 8),
          menu,
        ],
      ),
    );
  }

  static void _view(BuildContext context, Announcement a) => showDialog<void>(
        context: context,
        builder: (_) => AppDialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PanelHeader(
                title: a.title,
                subtitle: a.createdAt == null ? null : longDate(a.createdAt!),
              ),
              const SizedBox(height: 12),
              Text(a.body.isEmpty ? 'No message.' : a.body, style: const TextStyle(height: 1.5)),
            ],
          ),
        ),
      );
}
