import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../providers/dashboard_providers.dart';

/// Homepage → Classes link #1: "View all classes" opens /classes and each
/// row's "Open Class" opens /classes/:classId.
class MyClassesCard extends ConsumerWidget {
  const MyClassesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      icon: Icons.menu_book_outlined,
      title: 'My Classes',
      actionLabel: 'View all classes',
      onAction: () => context.go(Routes.classes),
      child: AsyncValueView<List<ClassRoom>>(
        value: ref.watch(visibleClassesProvider),
        data: (list) {
          if (list.isEmpty) {
            return EmptyNote(
              'No active classes yet. Your administrator assigns classes and class codes.',
              actionLabel: 'Go to Classes',
              onAction: () => context.go(Routes.classes),
            );
          }
          return Column(
            children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) const Divider(),
                _ClassRow(classRoom: list[i]),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({required this.classRoom});

  final ClassRoom classRoom;

  @override
  Widget build(BuildContext context) {
    final c = classRoom;
    void open() => context.go(Routes.classDetail(c.id));

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(c.name, style: AppText.itemTitle.copyWith(fontSize: 15)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _Meta(Icons.groups_outlined, '${c.studentCount} students'),
            _Meta(Icons.description_outlined, '${c.questCount} quests'),
          ],
        ),
      ],
    );
    final completion = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(TextSpan(children: [
          TextSpan(
              text: percent(c.completionRate),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const TextSpan(text: ' completion', style: AppText.meta),
        ])),
        const SizedBox(height: 8),
        ProgressBar(value: c.completionRate),
      ],
    );
    final button = OpenClassChip(onTap: open);

    return InkWell(
      onTap: open,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: LayoutBuilder(builder: (context, box) {
          if (box.maxWidth < 520) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClassThumbnail(classRoom: c, width: 86, height: 64),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      info,
                      const SizedBox(height: 10),
                      completion,
                      const SizedBox(height: 10),
                      Align(alignment: Alignment.centerLeft, child: button),
                    ],
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [
              ClassThumbnail(classRoom: c, width: 112, height: 72),
              const SizedBox(width: 18),
              Expanded(flex: 5, child: info),
              Expanded(flex: 4, child: completion),
              const SizedBox(width: 18),
              button,
            ],
          );
        }),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.inkSoft),
          const SizedBox(width: 6),
          Text(text, style: AppText.meta),
        ],
      );
}

/// Soft green "Open Class →" pill.
class OpenClassChip extends StatelessWidget {
  const OpenClassChip({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Open Class',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
              SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
