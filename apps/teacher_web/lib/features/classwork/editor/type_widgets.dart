import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Activity → "Submission type": File upload · Text response · Photo · None.
class SubmissionTypePicker extends StatelessWidget {
  const SubmissionTypePicker({super.key, required this.value, required this.onChanged});

  final SubmissionType value;
  final ValueChanged<SubmissionType> onChanged;

  static IconData _icon(SubmissionType t) => switch (t) {
        SubmissionType.file => Icons.upload_file_rounded,
        SubmissionType.text => Icons.notes_rounded,
        SubmissionType.photo => Icons.image_outlined,
        SubmissionType.none => Icons.block_rounded,
      };

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final t in SubmissionType.values)
            SizedBox(
              width: 150,
              child: Material(
                color: t == value ? AppColors.primarySoft : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: t == value ? AppColors.primary : AppColors.border, width: t == value ? 1.6 : 1),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onChanged(t),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      Icon(_icon(t), color: t == value ? AppColors.primary : AppColors.ink),
                      const SizedBox(height: 6),
                      Text(t.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w700, color: t == value ? AppColors.primary : AppColors.ink)),
                      const SizedBox(height: 2),
                      Text(t.hint, textAlign: TextAlign.center, style: AppText.meta.copyWith(fontSize: 11.5)),
                    ]),
                  ),
                ),
              ),
            ),
        ],
      );
}

/// "Grading" box: + Add rubric / the rubric's criteria.
class RubricField extends StatelessWidget {
  const RubricField({super.key, required this.value, required this.onChanged});

  final List<RubricCriterion> value;
  final ValueChanged<List<RubricCriterion>> onChanged;

  @override
  Widget build(BuildContext context) {
    final total = value.fold<int>(0, (n, r) => n + r.points);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.primarySoft.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Grading', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
          const SizedBox(height: 10),
          if (value.isEmpty)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary)),
              onPressed: () => _edit(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add rubric'),
            )
          else ...[
            for (final r in value)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Expanded(child: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text('${r.points} pts', style: AppText.meta),
                ]),
              ),
            const Divider(),
            Row(children: [
              Expanded(child: Text('Total $total points', style: const TextStyle(fontWeight: FontWeight.w700))),
              TextButton(onPressed: () => _edit(context), child: const Text('Edit rubric')),
            ]),
          ],
          const SizedBox(height: 4),
          Text('Create a rubric to provide clear assessment criteria.', style: AppText.meta.copyWith(fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final result = await showDialog<List<RubricCriterion>>(
      context: context,
      builder: (_) => _RubricDialog(initial: value),
    );
    if (result != null) onChanged(result);
  }
}

class _RubricDialog extends StatefulWidget {
  const _RubricDialog({required this.initial});

  final List<RubricCriterion> initial;

  @override
  State<_RubricDialog> createState() => _RubricDialogState();
}

class _RubricDialogState extends State<_RubricDialog> {
  late final List<(TextEditingController, TextEditingController, TextEditingController)> _rows = [
    for (final r in widget.initial.isEmpty
        ? const [RubricCriterion(title: 'Content Accuracy', points: 4), RubricCriterion(title: 'Presentation', points: 3)]
        : widget.initial)
      (
        TextEditingController(text: r.title),
        TextEditingController(text: r.description),
        TextEditingController(text: '${r.points}'),
      ),
  ];

  @override
  void dispose() {
    for (final r in _rows) {
      r.$1.dispose();
      r.$2.dispose();
      r.$3.dispose();
    }
    super.dispose();
  }

  int get _total => _rows.fold(0, (n, r) => n + (int.tryParse(r.$3.text) ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      maxWidth: 620,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(title: 'Rubric', subtitle: 'Total $_total points'),
          const SizedBox(height: 10),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              for (var i = 0; i < _rows.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      flex: 4,
                      child: TextField(controller: _rows[i].$1, decoration: const InputDecoration(hintText: 'Criterion')),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: TextField(controller: _rows[i].$2, decoration: const InputDecoration(hintText: 'What earns full points')),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _rows[i].$3,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(suffixText: 'pts'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      onPressed: _rows.length == 1
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
            ]),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _rows.add(
                  (TextEditingController(), TextEditingController(), TextEditingController(text: '1')))),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add criterion'),
            ),
          ),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(
              onPressed: () => Navigator.pop(context, const <RubricCriterion>[]),
              child: const Text('Remove rubric', style: TextStyle(color: AppColors.red)),
            ),
            const Spacer(),
            OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context, [
                for (final r in _rows)
                  if (r.$1.text.trim().isNotEmpty)
                    RubricCriterion(
                      title: r.$1.text.trim(),
                      description: r.$2.text.trim(),
                      points: int.tryParse(r.$3.text) ?? 0,
                    ),
              ]),
              child: const Text('Save rubric'),
            ),
          ]),
        ],
      ),
    );
  }
}

/// "Boss character" card with Change Boss.
class BossCharacterCard extends StatelessWidget {
  const BossCharacterCard({super.key, required this.bossId, required this.onChanged});

  final String bossId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final boss = BossCharacter.byId(bossId);
    return LayoutBuilder(builder: (context, box) {
      final art = Container(
        width: 200,
        height: 150,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF8ED1F5), Color(0xFFF6D58E)],
          ),
        ),
        child: Text(boss.emoji, style: const TextStyle(fontSize: 72)),
      );
      final info = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Current boss', style: AppText.meta.copyWith(fontSize: 12)),
          Text(boss.name, style: AppText.itemTitle.copyWith(fontSize: 17)),
          const SizedBox(height: 4),
          Text(boss.tagline, style: AppText.meta),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary)),
            onPressed: () async {
              final picked = await showDialog<String>(
                context: context,
                builder: (ctx) => AppDialog(
                  maxWidth: 560,
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const PanelHeader(title: 'Choose a boss'),
                    const SizedBox(height: 10),
                    for (final b in BossCharacter.all)
                      ListTile(
                        leading: Text(b.emoji, style: const TextStyle(fontSize: 30)),
                        title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(b.tagline),
                        trailing: b.id == bossId ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                        onTap: () => Navigator.pop(ctx, b.id),
                      ),
                  ]),
                ),
              );
              if (picked != null) onChanged(picked);
            },
            icon: const Icon(Icons.image_outlined, size: 19),
            label: const Text('Change Boss'),
          ),
        ],
      );
      if (box.maxWidth < 440) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [art, const SizedBox(height: 12), info]);
      return Row(children: [art, const SizedBox(width: 18), Expanded(child: info)]);
    });
  }
}
