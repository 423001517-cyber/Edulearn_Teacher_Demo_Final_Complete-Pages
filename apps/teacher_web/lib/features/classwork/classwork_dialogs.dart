import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../providers/classes_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';

/// Opens the full-page editor for a new or existing classwork item.
Future<void> openClassworkEditor(
  BuildContext context, {
  required ClassworkType type,
  String? classId,
  ClassworkItem? existing,
}) async {
  context.push(existing != null
      ? Routes.classworkEdit(existing.id)
      : Routes.classworkNew(type, classId: classId));
}

Future<void> copyClassworkLink({required String classId, String? itemId, String? topicId}) async {
  final url = Uri.base.resolve(Routes.classwork(classId: classId, item: itemId, topic: topicId));
  await Clipboard.setData(ClipboardData(text: url.toString()));
  showToast('Link copied');
}

/// "Create topic" / rename. Returns the name, or null when cancelled.
Future<String?> showTopicNameDialog(BuildContext context, {String? initial}) =>
    showDialog<String>(context: context, builder: (_) => _TopicNameDialog(initial: initial));

class _TopicNameDialog extends StatefulWidget {
  const _TopicNameDialog({this.initial});

  final String? initial;

  @override
  State<_TopicNameDialog> createState() => _TopicNameDialogState();
}

class _TopicNameDialogState extends State<_TopicNameDialog> {
  late final _name = TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _done() {
    final v = _name.text.trim();
    if (v.isEmpty) return;
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final renaming = widget.initial != null;
    return AppDialog(
      maxWidth: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(renaming ? 'Rename topic' : 'Create topic', style: AppText.dialogTitle)),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
            ),
          ]),
          const SizedBox(height: 10),
          const FieldLabel('Topic name'),
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 80,
            onSubmitted: (_) => _done(),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'e.g. Week 4: Yamang Likas', counterText: ''),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _name.text.trim().isEmpty ? null : _done,
                child: Text(renaming ? 'Save' : 'Create'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

/// "Move to topic": returns the chosen topic id ('' = No topic), or null.
Future<String?> showMoveToTopicDialog(BuildContext context, ClassworkItem item, List<ClassTopic> topics) =>
    showDialog<String>(
      context: context,
      builder: (ctx) => AppDialog(
        maxWidth: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PanelHeader(title: 'Move to topic', subtitle: item.title),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final t in [...topics.map((t) => (t.id, t.name)), ('', 'No topic')])
                    ListTile(
                      leading: Icon(
                        (item.topicId ?? '') == t.$1
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: (item.topicId ?? '') == t.$1 ? AppColors.primary : AppColors.muted,
                      ),
                      title: Text(t.$2),
                      onTap: () => Navigator.pop(ctx, t.$1),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

/// The design's "Delete classwork?" confirmation.
Future<bool> confirmDeleteClasswork(BuildContext context, ClassworkItem item) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        maxWidth: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(ctx, false),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: AppColors.redSoft, shape: BoxShape.circle),
              child: const Icon(Icons.delete_outline_rounded, color: AppColors.red, size: 32),
            ),
            const SizedBox(height: 14),
            Text('Delete classwork?', style: AppText.dialogTitle),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone. This will permanently delete “${item.title}” '
              'and all its submissions.',
              textAlign: TextAlign.center,
              style: AppText.meta.copyWith(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.red),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete'),
                ),
              ),
            ]),
          ],
        ),
      ),
    ) ??
    false;

/// "Reuse classwork": pick a class, tick items, copy them here as drafts.
Future<void> showReuseDialog(BuildContext context, {required ClassRoom target}) =>
    showDialog<void>(context: context, builder: (_) => _ReuseDialog(target: target));

class _ReuseDialog extends ConsumerStatefulWidget {
  const _ReuseDialog({required this.target});

  final ClassRoom target;

  @override
  ConsumerState<_ReuseDialog> createState() => _ReuseDialogState();
}

class _ReuseDialogState extends ConsumerState<_ReuseDialog> {
  late String _from = widget.target.id;
  final Set<String> _picked = {};
  String _query = '';
  bool _copyFiles = true;
  bool _saving = false;

  Future<void> _reuse(List<ClassworkItem> items) async {
    final chosen = items.where((w) => _picked.contains(w.id)).toList();
    if (chosen.isEmpty) return;
    setState(() => _saving = true);
    try {
      final n = await ref.read(classworkRepositoryProvider).reuse(chosen, target: widget.target, copyFiles: _copyFiles);
      if (!mounted) return;
      Navigator.pop(context);
      showToast('$n item${n == 1 ? '' : 's'} copied to ${widget.target.name} as drafts');
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      showToast('Couldn’t reuse: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(classesProvider).valueOrNull ?? const <ClassRoom>[];
    final items = ref.watch(classClassworkProvider(_from));
    final q = _query.trim().toLowerCase();
    final list = (items.valueOrNull ?? const <ClassworkItem>[])
        .where((w) => q.isEmpty || w.title.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => (b.createdAt ?? b.dueDate).compareTo(a.createdAt ?? a.dueDate));

    final classPane = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Select a class', style: AppText.itemTitle),
        const SizedBox(height: 8),
        for (final c in classes)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Material(
              color: c.id == _from ? AppColors.primarySoft : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: Icon(Icons.groups_rounded, color: c.id == _from ? AppColors.primary : AppColors.ink),
                title: Text(c.isArchived ? '${c.name} (archived)' : c.name,
                    style: TextStyle(
                        fontWeight: c.id == _from ? FontWeight.w700 : FontWeight.w500,
                        color: c.id == _from ? AppColors.primary : AppColors.ink)),
                onTap: () => setState(() {
                  _from = c.id;
                  _picked.clear();
                }),
              ),
            ),
          ),
      ],
    );

    final itemPane = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Select a classwork item', style: AppText.itemTitle),
        const SizedBox(height: 8),
        SearchField(hint: 'Search classwork items...', onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 8),
        SizedBox(
          height: 300,
          child: AsyncValueView<List<ClassworkItem>>(
            value: items,
            data: (_) => list.isEmpty
                ? const EmptyNote('No classwork in this class.')
                : ListView(
                    children: [
                      for (final w in list)
                        CheckboxListTile(
                          value: _picked.contains(w.id),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          onChanged: (v) => setState(() => v == true ? _picked.add(w.id) : _picked.remove(w.id)),
                          secondary: Text(fullDate(w.createdAt ?? w.dueDate), style: AppText.meta),
                          title: Row(children: [
                            ToneIcon(w.type.icon, tone: w.type.tone, size: 36, circle: true),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(w.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.itemTitle),
                                  Text(w.type.shortLabel, style: AppText.meta.copyWith(fontSize: 12)),
                                ],
                              ),
                            ),
                          ]),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );

    return AppDialog(
      maxWidth: 860,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const ToneIcon(Icons.copy_all_rounded, tone: Tone.green, size: 40),
            const SizedBox(width: 12),
            Expanded(child: Text('Reuse classwork', style: AppText.dialogTitle)),
            IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
          ]),
          const SizedBox(height: 10),
          _Steps(step: _picked.isEmpty ? 1 : 2),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, box) {
            if (box.maxWidth < 620) {
              return Column(children: [classPane, const Divider(height: 24), itemPane]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 250, child: classPane),
                const SizedBox(width: 18),
                Expanded(child: itemPane),
              ],
            );
          }),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 10,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Checkbox(value: _copyFiles, onChanged: (v) => setState(() => _copyFiles = v ?? true)),
                const Text('Create new copies of attachments'),
                const SizedBox(width: 6),
                const Tooltip(
                  message: 'Copies uploaded files, so deleting the original later won’t affect the reused item.',
                  child: Icon(Icons.help_outline_rounded, size: 18, color: AppColors.muted),
                ),
              ]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _saving || _picked.isEmpty ? null : () => _reuse(list),
                  child: Text(_picked.length > 1 ? 'Reuse ${_picked.length}' : 'Reuse'),
                ),
              ]),
            ],
          ),
        ],
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    Widget dot(int n, String label) {
      final on = step >= n;
      return Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: on ? AppColors.primary : AppColors.chip,
          child: Text('$n', style: TextStyle(color: on ? Colors.white : AppColors.muted, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: on ? AppColors.primary : AppColors.muted)),
      ]);
    }

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      dot(1, 'Select class'),
      Container(width: 70, height: 1, margin: const EdgeInsets.symmetric(horizontal: 12), color: AppColors.border),
      dot(2, 'Select item'),
    ]);
  }
}
