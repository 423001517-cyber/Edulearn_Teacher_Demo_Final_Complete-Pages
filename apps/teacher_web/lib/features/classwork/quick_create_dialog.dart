import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';

import '../../core/navigation.dart';
import '../announcements/announcement_widgets.dart';
import 'classwork_form_dialog.dart';
import 'reuse_activity_dialog.dart';

enum QuickCreateOption {
  lesson('Lesson', 'Upload a manuscript or learning material', Icons.description_outlined, Tone.green),
  quest('Quest', 'Create a Monday–Thursday learning quest', Icons.bolt_rounded, Tone.blue),
  quiz('Quiz', 'Create an automatically graded quiz', Icons.description_outlined, Tone.amber),
  boss('Friday Boss Assessment', 'Create the weekly major assessment', Icons.emoji_events_rounded,
      Tone.amber),
  announcement('Announcement', 'Post an update to the class stream', Icons.campaign_outlined,
      Tone.red),
  reuse('Reuse Activity', 'Copy an existing classwork item', Icons.insert_drive_file_outlined,
      Tone.blue);

  const QuickCreateOption(this.title, this.description, this.icon, this.tone);
  final String title;
  final String description;
  final IconData icon;
  final Tone tone;
}

/// Opens the Quick Create picker, then the matching form. Used by the
/// Dashboard banner and the class page's "Create Classwork" button
/// ([classId] preselects the class).
Future<void> showQuickCreate(BuildContext context, {String? classId}) async {
  final choice = await showDialog<QuickCreateOption>(
    context: context,
    builder: (_) => const _QuickCreateDialog(),
  );
  if (choice == null) return;
  // The picker has closed; open the form from the app's root, if still open.
  final ctx = rootNavigatorKey.currentContext;
  if (ctx == null || !ctx.mounted) return;
  switch (choice) {
    case QuickCreateOption.lesson:
      await showClassworkForm(ctx, type: ClassworkType.lesson, classId: classId);
    case QuickCreateOption.quest:
      await showClassworkForm(ctx, type: ClassworkType.quest, classId: classId);
    case QuickCreateOption.quiz:
      await showClassworkForm(ctx, type: ClassworkType.quiz, classId: classId);
    case QuickCreateOption.boss:
      await showClassworkForm(ctx, type: ClassworkType.boss, classId: classId);
    case QuickCreateOption.announcement:
      await showAnnouncementForm(ctx, classId: classId);
    case QuickCreateOption.reuse:
      await showReuseActivity(ctx, targetClassId: classId);
  }
}

class _QuickCreateDialog extends StatelessWidget {
  const _QuickCreateDialog();

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      maxWidth: 640,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(
            title: 'Quick Create',
            subtitle: 'What would you like to create?',
            leading: Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
              child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 30),
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth > 480 ? 2 : 1;
            final w = ((c.maxWidth - 14 * (cols - 1)) / cols).floorToDouble();
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final o in QuickCreateOption.values) SizedBox(width: w, child: _Tile(option: o)),
              ],
            );
          }),
          const SizedBox(height: 18),
          OutlinedButton(
            style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.option});

  final QuickCreateOption option;

  @override
  Widget build(BuildContext context) {
    final tone = option.tone;
    return Material(
      color: tone.bg.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: tone.bg),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pop(context, option),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 108),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ToneIconCircle(icon: option.icon, tone: tone),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(option.title,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(option.description, style: AppText.meta.copyWith(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ToneIconCircle extends StatelessWidget {
  const ToneIconCircle({super.key, required this.icon, required this.tone, this.size = 58});

  final IconData icon;
  final Tone tone;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: tone.bg, shape: BoxShape.circle),
        child: Icon(icon, color: tone.fg, size: size * 0.45),
      );
}
