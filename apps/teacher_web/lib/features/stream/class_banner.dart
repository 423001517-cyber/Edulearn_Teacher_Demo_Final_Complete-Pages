import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../classes/widgets/class_actions.dart';
import '../classes/widgets/class_dialogs.dart';

/// The cover banner at the top of the Stream page.
class ClassBanner extends StatelessWidget {
  const ClassBanner({super.key, required this.classRoom});

  final ClassRoom classRoom;

  @override
  Widget build(BuildContext context) {
    final c = classRoom;
    return LayoutBuilder(builder: (context, box) {
      final narrow = box.maxWidth < 600;
      final white = Colors.white;
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: narrow ? 190 : 220,
          child: Stack(
            children: [
              Positioned.fill(child: ClassThumbnail(classRoom: c, height: 220, radius: 0)),
              // Darken the left side so the white text stays readable on any cover.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withValues(alpha: 0.62), Colors.black.withValues(alpha: 0.0)],
                      stops: const [0.0, 0.75],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: narrow ? 18 : 26,
                right: 18,
                bottom: narrow ? 16 : 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (c.isArchived) ...[
                      const Pill('Archived', tone: Tone.neutral, dot: true),
                      const SizedBox(height: 8),
                    ],
                    Text(c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.font(size: narrow ? 26 : 34, weight: FontWeight.w800, color: white)),
                    Text(c.subject,
                        style: AppTheme.font(size: narrow ? 16 : 20, weight: FontWeight.w600, color: white)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 22,
                      runSpacing: 4,
                      children: [
                        _Fact(icon: Icons.groups_rounded, text: '${c.studentCount} students'),
                        _Fact(icon: Icons.qr_code_2_rounded, text: c.classCode),
                        if (c.room.isNotEmpty) _Fact(icon: Icons.meeting_room_outlined, text: c.room),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: Row(
                  children: [
                    _WhiteButton(
                      onTap: () => copyCode(c),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.content_copy_rounded, size: 18, color: AppColors.primary),
                          if (!narrow) ...[
                            const SizedBox(width: 8),
                            const Text('Copy code',
                                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    ClassControlsMenu(classRoom: c),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// "Class code copied: RIZAL-4A"
Future<void> copyCode(ClassRoom c) async {
  await Clipboard.setData(ClipboardData(text: c.classCode));
  showToast('Class code copied: ${c.classCode}');
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 7),
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14.5)),
        ],
      );
}

class _WhiteButton extends StatelessWidget {
  const _WhiteButton({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        elevation: 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: child,
          ),
        ),
      );
}

enum _Control { settings, edit, archive, restore }

/// ⋮ on the banner: Class settings · Edit class details · Archive class.
class ClassControlsMenu extends ConsumerWidget {
  const ClassControlsMenu({super.key, required this.classRoom});

  final ClassRoom classRoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = classRoom;
    return PopupMenuButton<_Control>(
      tooltip: 'Class controls',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      onSelected: (v) {
        switch (v) {
          case _Control.settings:
            goTo(Routes.classSettings(c.id));
          case _Control.edit:
            showEditClassDetails(context, c);
          case _Control.archive:
            runClassAction(context, ref, c, ClassAction.archive);
          case _Control.restore:
            runClassAction(context, ref, c, ClassAction.restore);
        }
      },
      itemBuilder: (_) => [
        menuItem(_Control.settings, Icons.settings_outlined, 'Class settings'),
        menuItem(_Control.edit, Icons.edit_outlined, 'Edit class details'),
        c.isArchived
            ? menuItem(_Control.restore, Icons.unarchive_outlined, 'Restore class')
            : menuItem(_Control.archive, Icons.archive_outlined, 'Archive class'),
      ],
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        elevation: 1,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.more_vert_rounded, color: AppColors.ink),
        ),
      ),
    );
  }
}
