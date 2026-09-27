import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../providers/admin_providers.dart';
import '../../providers/core_providers.dart';

/// Title block for every admin page, with the requests bell and profile.
class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({super.key, required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final titleBlock = Row(
      children: [
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.meta.copyWith(fontSize: 13.5)),
            ],
          ),
        ),
      ],
    );
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 560) return titleBlock;
      return Row(children: [Expanded(child: titleBlock), const AdminTopBarControls()]);
    });
  }
}

class AdminTopBarControls extends ConsumerWidget {
  const AdminTopBarControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingRequestCountProvider);
    final admin = ref.watch(currentAdminProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: pending == 0 ? 'No pending class requests' : '$pending pending class requests',
          onPressed: () => context.go(AdminRoutes.requests),
          icon: Badge(
            isLabelVisible: pending > 0,
            label: Text('$pending'),
            backgroundColor: AppColors.red,
            child: const Icon(Icons.notifications_none_rounded, size: 26, color: AppColors.ink),
          ),
        ),
        const SizedBox(width: 6),
        AdminProfileMenu(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InitialsAvatar(initials: admin?.initials ?? 'A', tone: Tone.amber, size: 40),
                const SizedBox(width: 10),
                Text(admin?.firstName ?? 'Admin',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.inkSoft),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class AdminProfileMenu extends ConsumerWidget {
  const AdminProfileMenu({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Account',
      position: PopupMenuPosition.under,
      onSelected: (v) {
        if (v == 'settings') context.go(AdminRoutes.settings);
        if (v == 'signout') ref.read(adminSessionProvider).signOut();
      },
      itemBuilder: (_) => [
        menuItem('settings', Icons.settings_outlined, 'School Settings'),
        const PopupMenuDivider(),
        menuItem('signout', Icons.logout_rounded, 'Sign Out', destructive: true),
      ],
      child: child,
    );
  }
}
