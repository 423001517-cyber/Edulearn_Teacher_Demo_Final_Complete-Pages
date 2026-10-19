import 'dart:async';

import 'package:edulearn_core/edulearn_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/navigation.dart';
import '../features/analytics/analytics_page.dart';
import '../features/attendance/attendance_page.dart';
import '../features/auth/login_screen.dart';
import '../features/calendar/calendar_page.dart';
import '../features/classes/class_detail_page.dart';
import '../features/classes/classes_page.dart';
import '../features/classwork/classwork_page.dart';
import '../features/classwork/editor/classwork_editor_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/gradebook/gradebook_page.dart';
import '../features/messages/messages_page.dart';
import '../features/reports/reports_page.dart';
import '../features/rewards/rewards_page.dart';
import '../features/settings/settings_page.dart';
import '../features/shell/app_shell.dart';
import '../features/shell/placeholder_page.dart';
import '../features/stream/class_settings_page.dart';
import '../features/stream/stream_page.dart';
import '../features/students/students_page.dart';
import '../features/submissions/review_page.dart';
import '../features/submissions/submissions_page.dart';
import '../providers/core_providers.dart';
import 'routes.dart';

/// URL map (all pages inside the shell share the sidebar):
///
///   /login
///   /                               Dashboard (homepage)
///   /classes                        Classes grid/list
///   /classes/:classId?tab=…         Open Class page
///   /students?classId=&student=     Students, optionally filtered
///   /reports?classId=&period=&panel= Class Reports
///   /stream?classId=&post=         Stream (announcements, classwork, comments)
///   /stream/settings?classId=      Class settings
///   /classwork?classId=&topic=&item= Classwork (topics, filters, create, reuse)
///   /calendar, /submissions, /gradebook
///   /analytics?classId=&range=      Analytics (all classes or one)
///   /attendance?classId=&date=      Attendance for one school day
///   /rewards?classId=               Points, badges and the reward shop
///   /messages?c=&student=&group=    Messages
///   /settings?section=              Settings
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final refresh = _AuthRefresh(auth.authStateChanges());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.dashboard,
    refreshListenable: refresh,
    redirect: (context, state) {
      final signedIn = auth.currentUser != null;
      final atLogin = state.matchedLocation == Routes.login;
      if (!signedIn) {
        if (atLogin) return null;
        final from = state.uri.toString();
        return from == Routes.dashboard
            ? Routes.login
            : Uri(path: Routes.login, queryParameters: {'from': from}).toString();
      }
      if (atLogin) return state.uri.queryParameters['from'] ?? Routes.dashboard;
      return null;
    },
    routes: [
      GoRoute(path: Routes.login, builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: Routes.dashboard,
            pageBuilder: (context, state) => _page(state, const DashboardPage()),
          ),
          GoRoute(
            path: Routes.classes,
            pageBuilder: (context, state) => _page(state, const ClassesPage()),
            routes: [
              GoRoute(
                path: ':classId',
                pageBuilder: (context, state) => _page(
                  state,
                  ClassDetailPage(
                    classId: state.pathParameters['classId']!,
                    tab: ClassTab.parse(state.uri.queryParameters['tab']),
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: NavSection.stream.path,
            pageBuilder: (context, state) => _page(
              state,
              StreamPage(
                classId: state.uri.queryParameters['classId'],
                post: state.uri.queryParameters['post'],
              ),
            ),
            routes: [
              GoRoute(
                path: 'settings',
                pageBuilder: (context, state) =>
                    _page(state, ClassSettingsPage(classId: state.uri.queryParameters['classId'])),
              ),
            ],
          ),
          GoRoute(
            path: NavSection.classwork.path,
            pageBuilder: (context, state) => _page(
              state,
              ClassworkPage(
                classId: state.uri.queryParameters['classId'],
                topicId: state.uri.queryParameters['topic'],
                itemId: state.uri.queryParameters['item'],
              ),
            ),
            routes: [
              GoRoute(
                path: 'new',
                pageBuilder: (context, state) => _page(
                  state,
                  ClassworkEditorPage(
                    type: ClassworkType.parse(state.uri.queryParameters['type']),
                    classId: state.uri.queryParameters['classId'],
                    studentId: state.uri.queryParameters['studentId'],
                  ),
                ),
              ),
              GoRoute(
                path: 'edit/:id',
                pageBuilder: (context, state) =>
                    _page(state, ClassworkEditorPage(itemId: state.pathParameters['id'])),
              ),
            ],
          ),
          GoRoute(
            path: NavSection.gradebook.path,
            pageBuilder: (context, state) =>
                _page(state, GradebookPage(classId: state.uri.queryParameters['classId'])),
          ),
          GoRoute(
            path: NavSection.calendar.path,
            pageBuilder: (context, state) => _page(state, const CalendarPage()),
          ),
          GoRoute(
            path: NavSection.submissions.path,
            pageBuilder: (context, state) => _page(
              state,
              SubmissionsPage(
                classId: state.uri.queryParameters['classId'],
                itemId: state.uri.queryParameters['item'],
              ),
            ),
            routes: [
              GoRoute(
                path: 'review',
                pageBuilder: (context, state) => _page(
                  state,
                  ReviewSubmissionPage(
                    itemId: state.uri.queryParameters['item'] ?? '',
                    studentId: state.uri.queryParameters['student'] ?? '',
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: NavSection.students.path,
            pageBuilder: (context, state) => _page(
              state,
              StudentsPage(
                classId: state.uri.queryParameters['classId'],
                studentId: state.uri.queryParameters['student'],
              ),
            ),
          ),
          GoRoute(
            path: NavSection.reports.path,
            pageBuilder: (context, state) => _page(
              state,
              ReportsPage(
                classId: state.uri.queryParameters['classId'],
                period: ReportPeriod.parse(state.uri.queryParameters['period']),
                panel: state.uri.queryParameters['panel'],
              ),
            ),
          ),
          GoRoute(
            path: NavSection.analytics.path,
            pageBuilder: (context, state) => _page(
              state,
              AnalyticsPage(
                classId: state.uri.queryParameters['classId'],
                range: AnalyticsRange.parse(state.uri.queryParameters['range']),
              ),
            ),
          ),
          GoRoute(
            path: NavSection.attendance.path,
            pageBuilder: (context, state) => _page(
              state,
              AttendancePage(
                classId: state.uri.queryParameters['classId'],
                date: dateFromKey(state.uri.queryParameters['date'] ?? ''),
              ),
            ),
          ),
          GoRoute(
            path: NavSection.rewards.path,
            pageBuilder: (context, state) =>
                _page(state, RewardsPage(classId: state.uri.queryParameters['classId'])),
          ),
          GoRoute(
            path: NavSection.messages.path,
            pageBuilder: (context, state) => _page(
              state,
              MessagesPage(
                conversationId: state.uri.queryParameters['c'],
                studentId: state.uri.queryParameters['student'],
                groupClassId: state.uri.queryParameters['group'],
              ),
            ),
          ),
          GoRoute(
            path: NavSection.settings.path,
            pageBuilder: (context, state) =>
                _page(state, SettingsPage(section: SettingsSection.parse(state.uri.queryParameters['section']))),
          ),
          for (final section in NavSection.values.where((s) => !s.isBuilt))
            GoRoute(
              path: section.path,
              pageBuilder: (context, state) => _page(
                state,
                PlaceholderPage(section: section, classId: state.uri.queryParameters['classId']),
              ),
            ),
        ],
      ),
    ],
  );
});

Page<void> _page(GoRouterState state, Widget child) =>
    NoTransitionPage<void>(key: state.pageKey, child: child);

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<User?> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<User?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
