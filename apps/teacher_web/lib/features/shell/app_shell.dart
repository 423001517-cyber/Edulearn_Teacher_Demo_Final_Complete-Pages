import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';

import '../../app/routes.dart';
import 'sidebar.dart';

/// Sidebar + page. Wide screens get the full sidebar, tablets an icon rail,
/// phones a drawer.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final current = NavSection.fromPath(location);
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < Breakpoints.compact) {
        return Scaffold(
          drawer: Drawer(
            width: 240,
            backgroundColor: AppColors.sidebar,
            shape: const RoundedRectangleBorder(),
            child: Builder(
              builder: (drawerContext) => Sidebar(
                current: current,
                onNavigate: () => Navigator.of(drawerContext).pop(),
              ),
            ),
          ),
          appBar: AppBar(
            backgroundColor: AppColors.sidebar,
            foregroundColor: Colors.white,
            elevation: 0,
            titleSpacing: 0,
            title: Row(
              children: [
                const Icon(Icons.school_rounded, color: AppColors.gold),
                const SizedBox(width: 8),
                Text('EduLearn',
                    style: AppTheme.font(size: 18, weight: FontWeight.w800, color: AppColors.gold)),
              ],
            ),
          ),
          body: child,
        );
      }
      return Scaffold(
        body: Row(
          children: [
            Sidebar(current: current, compact: c.maxWidth < Breakpoints.wide),
            Expanded(child: child),
          ],
        ),
      );
    });
  }
}
