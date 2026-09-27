import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../providers/core_providers.dart';
import 'classwork_form_dialog.dart';
import 'reuse_activity_dialog.dart';

/// The popover from the Upcoming list (Class / Date / Status / Points,
/// Edit, Preview, Open Classwork).
class ClassworkDetailsPopover extends StatelessWidget {
  const ClassworkDetailsPopover({super.key, required this.item});

  final ClassworkItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(
            title: item.headline,
            subtitle: item.title,
            leading: Icon(item.type.icon, color: item.type.tone.fg, size: 32),
          ),
          const SizedBox(height: 10),
          DetailRow(
            label: 'Class',
            child: Row(children: [
              const Icon(Icons.groups_outlined, size: 18, color: AppColors.inkSoft),
              const SizedBox(width: 8),
              Flexible(child: Text(item.className, style: AppText.body)),
            ]),
          ),
          DetailRow(
            label: 'Date',
            child: Row(children: [
              const Icon(Icons.event_outlined, size: 18, color: AppColors.inkSoft),
              const SizedBox(width: 8),
              Text(dayMonth(item.dueDate), style: AppText.body),
            ]),
          ),
          DetailRow(
            label: 'Status',
            child: Pill(item.status.displayLabel, tone: item.status.tone, large: true),
          ),
          if (item.type.isGraded)
            DetailRow(
              label: 'Points',
              child: Row(children: [
                const Icon(Icons.emoji_events_rounded, size: 18, color: AppColors.amber),
                const SizedBox(width: 6),
                Text('${item.points}', style: AppText.itemTitle),
              ]),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    showClassworkForm(rootContext, type: item.type, existing: item);
                  },
                  child: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    showClassworkPreview(rootContext, item);
                  },
                  child: const Text('Preview'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              goTo(Routes.classDetail(item.classId, ClassTab.classwork));
            },
            child: const Text('Open Classwork'),
          ),
        ],
      ),
    );
  }
}

Future<void> showClassworkPreview(BuildContext context, ClassworkItem item) => showDialog<void>(
      context: context,
      builder: (ctx) => AppDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PanelHeader(
              title: item.title,
              subtitle: '${item.headline} · ${item.className}',
              leading: ToneIcon(item.type.icon, tone: item.type.tone, size: 46),
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              Pill('Due ${longDate(item.dueDate)}', tone: Tone.neutral),
              if (item.type.isGraded) Pill('${item.points} points', tone: Tone.amber),
              Pill(item.status.displayLabel, tone: item.status.tone),
            ]),
            const SizedBox(height: 16),
            Text(item.description.isEmpty ? 'No instructions added.' : item.description,
                style: const TextStyle(height: 1.5)),
            if (item.attachmentUrl != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(item.attachmentUrl!)),
                icon: const Icon(Icons.attach_file_rounded),
                label: Text(item.attachmentName ?? 'Open attachment'),
              ),
            ],
          ],
        ),
      ),
    );

/// ⋮ menu for a classwork row.
class ClassworkMenu extends ConsumerWidget {
  const ClassworkMenu({super.key, required this.item});

  final ClassworkItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MoreMenu<String>(
      items: [
        menuItem('edit', Icons.edit_outlined, 'Edit'),
        menuItem('preview', Icons.visibility_outlined, 'Preview'),
        menuItem('copy', Icons.content_copy_outlined, 'Copy to another class'),
        const PopupMenuDivider(),
        menuItem('delete', Icons.delete_outline_rounded, 'Delete', destructive: true),
      ],
      onSelected: (v) async {
        switch (v) {
          case 'edit':
            showClassworkForm(context, type: item.type, existing: item);
          case 'preview':
            showClassworkPreview(context, item);
          case 'copy':
            showReuseActivity(context, source: item);
          case 'delete':
            final repo = ref.read(dashboardRepositoryProvider);
            final ok = await confirmAction(
              context,
              title: 'Delete "${item.title}"?',
              message: 'Students will no longer see it. Submissions already turned in are kept.',
              confirmLabel: 'Delete',
              destructive: true,
            );
            if (ok) {
              await repo.deleteClasswork(item.id);
              showToast('Deleted "${item.title}"');
            }
        }
      },
    );
  }
}
