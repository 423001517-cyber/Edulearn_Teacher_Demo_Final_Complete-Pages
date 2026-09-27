import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../providers/admin_providers.dart';
import 'top_bar.dart';

/// Sidebar + page. Full sidebar on desktop, icon rail on tablets, drawer on
/// phones — the same breakpoints as the teacher website.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final current = AdminSection.fromPath(location);
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < Breakpoints.compact) {
        return Scaffold(
          drawer: Drawer(
            width: 240,
            backgroundColor: AppColors.sidebar,
            shape: const RoundedRectangleBorder(),
            child: Builder(
              builder: (drawerContext) => AdminSidebar(
                current: current,
                onNavigate: () => Navigator.of(drawerContext).pop(),
              ),
            ),
          ),
          appBar: AppBar(
            backgroundColor: AppColors.sidebar,
            foregroundColor: Colors.white,
            titleSpacing: 0,
            title: Text('EduLearn Admin',
                style: AppTheme.font(size: 18, weight: FontWeight.w800, color: AppColors.gold)),
          ),
          body: child,
        );
      }
      return Scaffold(
        body: Row(
          children: [
            AdminSidebar(current: current, compact: c.maxWidth < Breakpoints.wide),
            Expanded(child: child),
          ],
        ),
      );
    });
  }
}

class AdminSidebar extends ConsumerWidget {
  const AdminSidebar({super.key, required this.current, this.compact = false, this.onNavigate});

  final AdminSection current;
  final bool compact;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(currentAdminProvider);
    final pending = ref.watch(pendingRequestCountProvider);
    return Container(
      width: compact ? 84 : 232,
      color: AppColors.sidebar,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 22),
            Icon(Icons.school_rounded, color: AppColors.gold, size: compact ? 36 : 48),
            if (!compact) ...[
              const SizedBox(height: 6),
              Text('EDULEARN',
                  style: AppTheme.font(size: 21, weight: FontWeight.w800, color: AppColors.gold)
                      .copyWith(letterSpacing: 0.6)),
              Text('ADMIN DASHBOARD',
                  style: AppTheme.font(
                          size: 9.5, weight: FontWeight.w700, color: AppColors.gold.withValues(alpha: 0.85))
                      .copyWith(letterSpacing: 0.8)),
            ],
            const SizedBox(height: 22),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final s in AdminSection.values)
                    _NavTile(
                      section: s,
                      selected: s == current,
                      compact: compact,
                      badge: s == AdminSection.requests ? pending : 0,
                      onTap: () {
                        onNavigate?.call();
                        context.go(s.path);
                      },
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            AdminProfileMenu(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 14),
                child: Row(
                  mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
                  children: [
                    InitialsAvatar(initials: admin?.initials ?? 'A', tone: Tone.amber, size: 38),
                    if (!compact) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(admin?.displayName ?? 'Administrator',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                            const Text('Administrator',
                                style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                          ],
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.section,
    required this.selected,
    required this.compact,
    required this.badge,
    required this.onTap,
  });

  final AdminSection section;
  final bool selected;
  final bool compact;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Colors.white.withValues(alpha: 0.86);
    final icon = Badge(
      isLabelVisible: badge > 0,
      label: Text('$badge'),
      backgroundColor: AppColors.red,
      child: Icon(section.icon, size: 21, color: color),
    );
    final tile = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? Colors.white.withValues(alpha: 0.13) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 12, vertical: 11),
            child: Row(
              mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                icon,
                if (!compact) ...[
                  const SizedBox(width: 12),
                  Text(section.label,
                      style: TextStyle(
                          color: color,
                          fontSize: 13.5,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return compact ? Tooltip(message: section.label, child: tile) : tile;
  }
}
