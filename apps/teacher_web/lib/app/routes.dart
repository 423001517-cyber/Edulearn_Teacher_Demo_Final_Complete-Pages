import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter/material.dart';

/// Sidebar sections. Each one owns a top-level URL.
enum NavSection {
  dashboard('Dashboard', Icons.home_outlined, '/'),
  classes('Classes', Icons.menu_book_outlined, '/classes'),
  stream('Stream', Icons.dynamic_feed_outlined, '/stream'),
  classwork('Classwork', Icons.description_outlined, '/classwork'),
  calendar('Calendar', Icons.calendar_month_outlined, '/calendar'),
  submissions('Submissions', Icons.inbox_outlined, '/submissions'),
  gradebook('Gradebook', Icons.table_chart_outlined, '/gradebook'),
  students('Students', Icons.groups_outlined, '/students'),
  analytics('Analytics', Icons.query_stats, '/analytics'),
  attendance('Attendance', Icons.fact_check_outlined, '/attendance'),
  rewards('Rewards', Icons.emoji_events_outlined, '/rewards'),
  messages('Messages', Icons.chat_bubble_outline, '/messages'),
  reports('Reports', Icons.assessment_outlined, '/reports'),
  settings('Settings', Icons.settings_outlined, '/settings');

  const NavSection(this.label, this.icon, this.path);
  final String label;
  final IconData icon;
  final String path;

  /// Sections that have a real page so far. The rest show a placeholder.
  bool get isBuilt => const {
        NavSection.dashboard,
        NavSection.classes,
        NavSection.stream,
        NavSection.classwork,
        NavSection.submissions,
        NavSection.calendar,
        NavSection.gradebook,
        NavSection.students,
        NavSection.reports,
      }.contains(this);

  static NavSection fromPath(String path) {
    for (final s in values) {
      if (s == NavSection.dashboard) continue;
      if (path == s.path || path.startsWith('${s.path}/')) return s;
    }
    return NavSection.dashboard;
  }
}

/// Tabs on the class page (/classes/:classId?tab=…).
enum ClassTab {
  overview('Overview', Icons.home_outlined),
  stream('Stream', Icons.forum_outlined),
  classwork('Classwork', Icons.description_outlined),
  students('Students', Icons.groups_outlined),
  gradebook('Gradebook', Icons.table_chart_outlined),
  analytics('Analytics', Icons.bar_chart_rounded);

  const ClassTab(this.label, this.icon);
  final String label;
  final IconData icon;

  static ClassTab parse(String? v) =>
      ClassTab.values.firstWhere((t) => t.name == v, orElse: () => ClassTab.overview);
}

/// Every URL in the app is built here, so links between pages stay in sync.
abstract final class Routes {
  static const login = '/login';
  static const dashboard = '/';
  static const classes = '/classes';

  static String classDetail(String classId, [ClassTab tab = ClassTab.overview]) =>
      _withQuery('/classes/$classId', {'tab': tab == ClassTab.overview ? null : tab.name});

  /// [post]: a PostRef.encode() value — opens that post's class comments.
  static String stream({String? classId, String? post}) =>
      _withQuery('/stream', {'classId': classId, 'post': post});

  /// [item] opens that item's preview; [topic] shows only that topic.
  static String classwork({String? classId, String? item, String? topic}) =>
      _withQuery('/classwork', {'classId': classId, 'item': item, 'topic': topic});

  /// Full-page "Create quest" etc. [studentId] pre-assigns a remedial item.
  static String classworkNew(ClassworkType type, {String? classId, String? studentId}) =>
      _withQuery('/classwork/new', {'type': type.name, 'classId': classId, 'studentId': studentId});

  static String classworkEdit(String itemId) => '/classwork/edit/$itemId';

  /// [item] opens that classwork's student table.
  static String submissions({String? classId, String? item}) =>
      _withQuery('/submissions', {'classId': classId, 'item': item});

  /// Full-page "Review submission" for one student.
  static String reviewSubmission(String itemId, String studentId) =>
      _withQuery('/submissions/review', {'item': itemId, 'student': studentId});

  static String gradebook({String? classId}) => _withQuery('/gradebook', {'classId': classId});

  static String classSettings(String classId) => _withQuery('/stream/settings', {'classId': classId});

  static String students({String? classId, String? studentId}) =>
      _withQuery('/students', {'classId': classId, 'student': studentId});

  /// [panel]: completion | score | attendance | missing — opens that
  /// detail panel on arrival.
  static String reports({String? classId, String? period, String? panel}) =>
      _withQuery('/reports', {'classId': classId, 'period': period, 'panel': panel});

  static String section(NavSection s, {String? classId}) =>
      _withQuery(s.path, {'classId': classId});
}

String _withQuery(String path, Map<String, String?> params) {
  final q = {
    for (final e in params.entries)
      if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
  };
  return q.isEmpty ? path : Uri(path: path, queryParameters: q).toString();
}
