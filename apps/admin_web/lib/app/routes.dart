import 'package:flutter/material.dart';

/// Sidebar sections of the admin website.
enum AdminSection {
  dashboard('Dashboard', Icons.home_outlined, '/'),
  teachers('Teachers', Icons.badge_outlined, '/teachers'),
  classes('Classes', Icons.menu_book_outlined, '/classes'),
  requests('Class Requests', Icons.move_to_inbox_outlined, '/requests'),
  students('Students', Icons.groups_outlined, '/students'),
  reports('Reports', Icons.assessment_outlined, '/reports'),
  settings('Settings', Icons.settings_outlined, '/settings');

  const AdminSection(this.label, this.icon, this.path);
  final String label;
  final IconData icon;
  final String path;

  static AdminSection fromPath(String path) {
    for (final s in values) {
      if (s == AdminSection.dashboard) continue;
      if (path == s.path || path.startsWith('${s.path}/')) return s;
    }
    return AdminSection.dashboard;
  }
}

/// Every admin URL is built here.
abstract final class AdminRoutes {
  static const login = '/login';
  static const notAuthorized = '/not-authorized';
  static const dashboard = '/';
  static const requests = '/requests';
  static const settings = '/settings';

  static String teachers({String? teacherId}) => _q('/teachers', {'teacher': teacherId});
  static String classes({String? teacherId}) => _q('/classes', {'teacher': teacherId});
  static String students({String? classId}) => _q('/students', {'classId': classId});
  static String reports({String? period}) => _q('/reports', {'period': period});
}

String _q(String path, Map<String, String?> params) {
  final q = {
    for (final e in params.entries)
      if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
  };
  return q.isEmpty ? path : Uri(path: path, queryParameters: q).toString();
}
