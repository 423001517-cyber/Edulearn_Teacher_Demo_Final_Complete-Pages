import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import 'class_actions.dart';
import 'quick_view_panel.dart';

/// Grid card from the Classes mockup.
class ClassCard extends ConsumerWidget {
  const ClassCard({super.key, required this.classRoom, required this.missing});

  final ClassRoom classRoom;
  final int missing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = classRoom;
    return Container(
      decoration: AppDecorations.card,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 150,
            child: Stack(
            fit: StackFit.expand,
            children: [
              InkWell(
                onTap: () => context.go(Routes.classDetail(c.id)),
                child: ClassThumbnail(classRoom: c, width: double.infinity, height: 150, radius: 0),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: ClassStatusBadge(classRoom: c),
                ),
              ),
            ],
          ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(c.name, style: AppText.sectionTitle.copyWith(fontSize: 18)),
                Text(c.subject, style: AppText.meta.copyWith(fontSize: 13.5)),
                const SizedBox(height: 10),
                ClassMetaRow(classRoom: c, missing: missing),
                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                _Metric(value: c.completionRate, label: 'completion'),
                const SizedBox(height: 12),
                _Metric(value: c.averageScore, label: 'average score'),
                const SizedBox(height: 14),
                ClassCodeChip(classRoom: c),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => context.go(Routes.classDetail(c.id)),
                        child: ArrowLabel('Open Class'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => showQuickView(context, c),
                        child: const Text('Quick View'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ClassActionsMenu(classRoom: c),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "20 students · 12 active quests · [2 missing]"
class ClassMetaRow extends StatelessWidget {
  const ClassMetaRow({super.key, required this.classRoom, required this.missing});

  final ClassRoom classRoom;
  final int missing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _IconText(Icons.groups_outlined, '${classRoom.studentCount} students'),
        _IconText(Icons.description_outlined, '${classRoom.questCount} active quests'),
        if (missing > 0) Pill('$missing missing', tone: Tone.amber, icon: Icons.error_rounded),
      ],
    );
  }
}

class _IconText extends StatelessWidget {
  const _IconText(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: AppColors.inkSoft),
          const SizedBox(width: 6),
          Text(text, style: AppText.meta.copyWith(fontSize: 13)),
        ],
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(TextSpan(children: [
          TextSpan(
              text: percent(value), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          TextSpan(text: ' $label', style: AppText.meta.copyWith(fontSize: 13)),
        ])),
        const SizedBox(height: 6),
        ProgressBar(value: value),
      ],
    );
  }
}

/// List-view row (grid/list toggle).
class ClassListTile extends StatelessWidget {
  const ClassListTile({super.key, required this.classRoom, required this.missing});

  final ClassRoom classRoom;
  final int missing;

  @override
  Widget build(BuildContext context) {
    final c = classRoom;
    return Container(
      decoration: AppDecorations.card,
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth > 820;
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(c.name, style: AppText.itemTitle.copyWith(fontSize: 16)),
                ClassStatusBadge(classRoom: c),
              ],
            ),
            Text(c.subject, style: AppText.meta),
            const SizedBox(height: 6),
            ClassMetaRow(classRoom: c, missing: missing),
          ],
        );
        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
                onPressed: () => context.go(Routes.classDetail(c.id)),
                child: const Text('Open Class')),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: () => showQuickView(context, c), child: const Text('Quick View')),
            const SizedBox(width: 8),
            ClassActionsMenu(classRoom: c),
          ],
        );
        return Row(
          crossAxisAlignment: wide ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            ClassThumbnail(classRoom: c, width: 120, height: 84),
            const SizedBox(width: 16),
            Expanded(
              child: wide
                  ? Row(
                      children: [
                        Expanded(flex: 5, child: info),
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              _Metric(value: c.completionRate, label: 'completion'),
                              const SizedBox(height: 8),
                              _Metric(value: c.averageScore, label: 'average score'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(c.classCode, style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(width: 16),
                        actions,
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        info,
                        const SizedBox(height: 10),
                        _Metric(value: c.completionRate, label: 'completion'),
                        const SizedBox(height: 10),
                        SingleChildScrollView(scrollDirection: Axis.horizontal, child: actions),
                      ],
                    ),
            ),
          ],
        );
      }),
    );
  }
}
