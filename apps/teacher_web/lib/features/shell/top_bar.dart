import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/navigation.dart';
import '../../providers/core_providers.dart';
import '../../providers/dashboard_providers.dart';
import '../../providers/data_providers.dart';

/// Title block used at the top of Classes, Students, Reports, etc.
/// (the Dashboard has its own greeting header).
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.leading,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// e.g. a back button on the class page.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final titleBlock = Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Icon(icon, size: 34, color: AppColors.amber),
        const SizedBox(width: 14),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: AppText.greeting, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (subtitle != null)
                Text(subtitle!,
                    style: AppText.meta.copyWith(fontSize: 13.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 560) return titleBlock;
      return Row(children: [Expanded(child: titleBlock), const TopBarControls()]);
    });
  }
}

/// Notification bell + profile chip.
class TopBarControls extends StatelessWidget {
  const TopBarControls({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [NotificationBell(), SizedBox(width: 6), ProfileMenu(child: _ProfileChip())],
    );
  }
}

class _ProfileChip extends ConsumerWidget {
  const _ProfileChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacher = ref.watch(teacherProvider).valueOrNull;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TeacherAvatar(teacher: teacher, size: 40),
          const SizedBox(width: 10),
          Text(teacher?.title ?? 'Teacher',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
          const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.inkSoft),
        ],
      ),
    );
  }
}

class TeacherAvatar extends StatelessWidget {
  const TeacherAvatar({super.key, required this.teacher, this.size = 40, this.light = false});

  final Teacher? teacher;
  final double size;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final url = teacher?.photoUrl;
    if (url != null) {
      return CircleAvatar(radius: size / 2, backgroundImage: NetworkImage(url));
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: light ? Colors.white : AppColors.amberSoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        teacher?.initials ?? 'T',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: size * 0.36,
          color: light ? AppColors.sidebar : AppColors.amber,
        ),
      ),
    );
  }
}

enum _ProfileAction { profile, notificationSettings, accountSettings, help, signOut }

class ProfileMenu extends ConsumerWidget {
  const ProfileMenu({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_ProfileAction>(
      tooltip: 'Account',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      onSelected: (action) async {
        switch (action) {
          case _ProfileAction.profile:
          case _ProfileAction.notificationSettings:
          case _ProfileAction.accountSettings:
            context.go(NavSection.settings.path);
          case _ProfileAction.help:
            showDialog<void>(
              context: context,
              builder: (ctx) => const AppDialog(
                maxWidth: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PanelHeader(title: 'Help'),
                    SizedBox(height: 8),
                    Text(
                      'Use Quick Create on the Dashboard to add lessons, quests, quizzes and '
                      'announcements. Open a class from Classes to see its work, students and '
                      'reports. For account or class-code issues, contact your school administrator.',
                      style: TextStyle(height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          case _ProfileAction.signOut:
            ref.read(selectedClassIdProvider.notifier).state = null;
            await ref.read(authRepositoryProvider).signOut();
        }
      },
      itemBuilder: (_) => [
        menuItem(_ProfileAction.profile, Icons.person_outline_rounded, 'My Profile'),
        menuItem(_ProfileAction.notificationSettings, Icons.notifications_none_rounded,
            'Notification Settings'),
        menuItem(_ProfileAction.accountSettings, Icons.settings_outlined, 'Account Settings'),
        menuItem(_ProfileAction.help, Icons.help_outline_rounded, 'Help'),
        const PopupMenuDivider(),
        menuItem(_ProfileAction.signOut, Icons.logout_rounded, 'Sign Out', destructive: true),
      ],
      child: child,
    );
  }
}

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    return Builder(
      builder: (anchor) => IconButton(
        tooltip: 'Notifications',
        onPressed: () => showAnchoredPopover<void>(
          context: anchor,
          width: 370,
          builder: (_) => const NotificationsPanel(),
        ),
        icon: Badge(
          isLabelVisible: unread > 0,
          smallSize: 9,
          backgroundColor: AppColors.red,
          child: const Icon(Icons.notifications_none_rounded, size: 26, color: AppColors.ink),
        ),
      ),
    );
  }
}

class NotificationsPanel extends ConsumerStatefulWidget {
  const NotificationsPanel({super.key, this.expanded = false});

  final bool expanded;

  @override
  ConsumerState<NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends ConsumerState<NotificationsPanel> {
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(notificationsProvider);
    final repo = ref.read(dashboardRepositoryProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Notifications',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              TextButton(
                onPressed: () => repo.markAllNotificationsRead(items.valueOrNull ?? const []),
                child: const Text('Mark all as read'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _tab('All', !_unreadOnly, () => setState(() => _unreadOnly = false))),
              const SizedBox(width: 8),
              Expanded(child: _tab('Unread', _unreadOnly, () => setState(() => _unreadOnly = true))),
            ],
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.expanded ? 520 : 340),
            child: AsyncValueView<List<AppNotification>>(
              value: items,
              data: (list) {
                final shown = _unreadOnly ? list.where((n) => !n.read).toList() : list;
                if (shown.isEmpty) return const EmptyNote("You're all caught up.");
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: shown.length,
                  separatorBuilder: (_, i) => const Divider(),
                  itemBuilder: (_, i) => _NotificationTile(item: shown[i]),
                );
              },
            ),
          ),
          if (!widget.expanded) ...[
            const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: LinkButton(
                label: 'View all notifications',
                onTap: () {
                  Navigator.of(context).pop();
                  showDialog<void>(
                    context: rootContext,
                    builder: (_) => const AppDialog(
                      maxWidth: 460,
                      child: NotificationsPanel(expanded: true),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) => Material(
        color: selected ? AppColors.blueSoft : AppColors.chip,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.link : AppColors.inkSoft)),
            ),
          ),
        ),
      );
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.item});

  final AppNotification item;

  String get _target => switch (item.kind) {
        NotificationKind.submissions => NavSection.submissions.path,
        NotificationKind.missingWork => Routes.students(),
        NotificationKind.schedule => NavSection.classwork.path,
        NotificationKind.general => Routes.dashboard,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(dashboardRepositoryProvider);
    return InkWell(
      onTap: () {
        if (!item.read) repo.markNotificationRead(item.id);
        Navigator.of(context).pop();
        goTo(_target);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            ToneIcon(item.kind.icon, tone: item.kind.tone, size: 42, circle: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: item.read ? FontWeight.w500 : FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(timeAgo(item.createdAt), style: AppText.meta),
                ],
              ),
            ),
            MoreMenu<String>(
              items: [
                menuItem('read', Icons.mark_email_read_outlined,
                    item.read ? 'Mark as unread' : 'Mark as read'),
                menuItem('delete', Icons.delete_outline_rounded, 'Delete', destructive: true),
              ],
              onSelected: (v) => v == 'read'
                  ? repo.markNotificationRead(item.id, read: !item.read)
                  : repo.deleteNotification(item.id),
            ),
          ],
        ),
      ),
    );
  }
}
