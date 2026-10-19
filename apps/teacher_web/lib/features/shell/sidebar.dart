import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../providers/core_providers.dart';
import '../../providers/messages_providers.dart';
import 'top_bar.dart';

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key, required this.current, this.compact = false, this.onNavigate});

  final NavSection current;
  final bool compact;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacher = ref.watch(teacherProvider).valueOrNull;
    final unread = ref.watch(unreadMessageCountProvider);
    // Keep Settings defaults loaded so other pages can use them right away.
    ref.watch(teacherPreferencesProvider);
    return Container(
      width: compact ? 84 : 232,
      color: AppColors.sidebar,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 22),
            _Brand(compact: compact),
            const SizedBox(height: 22),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final s in NavSection.values)
                    _NavTile(
                      section: s,
                      selected: s == current,
                      compact: compact,
                      badge: s == NavSection.messages ? unread : 0,
                      onTap: () {
                        onNavigate?.call();
                        context.go(s.path);
                      },
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            ProfileMenu(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 14),
                child: Row(
                  mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
                  children: [
                    TeacherAvatar(teacher: teacher, size: 38, light: true),
                    if (!compact) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(teacher?.title ?? 'Teacher',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                            const Text('Teacher',
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

class _Brand extends StatelessWidget {
  const _Brand({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.school_rounded, color: AppColors.gold, size: compact ? 36 : 48),
        if (!compact) ...[
          const SizedBox(height: 6),
          Text('EDULEARN',
              style: AppTheme.font(size: 21, weight: FontWeight.w800, color: AppColors.gold)
                  .copyWith(letterSpacing: 0.6)),
          Text('TEACHER DASHBOARD',
              style: AppTheme.font(
                      size: 9.5, weight: FontWeight.w700, color: AppColors.gold.withValues(alpha: 0.85))
                  .copyWith(letterSpacing: 0.8)),
        ],
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.section,
    required this.selected,
    required this.compact,
    required this.onTap,
    this.badge = 0,
  });

  final NavSection section;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  /// Unread count (Messages).
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Colors.white.withValues(alpha: 0.86);
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
                Badge(
                  isLabelVisible: compact && badge > 0,
                  backgroundColor: AppColors.gold,
                  textColor: const Color(0xFF3B2A00),
                  label: Text('$badge'),
                  child: Icon(section.icon, size: 21, color: color),
                ),
                if (!compact) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(section.label,
                        style: TextStyle(
                            color: color,
                            fontSize: 13.5,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                  ),
                  if (badge > 0)
                    Container(
                      constraints: const BoxConstraints(minWidth: 22),
                      height: 22,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(11)),
                      child: Text('$badge',
                          style: const TextStyle(color: Color(0xFF3B2A00), fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return compact
        ? Tooltip(message: badge > 0 ? '${section.label} ($badge unread)' : section.label, child: tile)
        : tile;
  }
}
