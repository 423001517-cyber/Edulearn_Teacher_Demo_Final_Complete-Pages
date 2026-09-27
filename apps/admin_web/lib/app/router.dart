import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/navigation.dart';
import '../data/admin_session.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/not_authorized_screen.dart';
import '../features/classes/classes_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/reports/school_reports_page.dart';
import '../features/requests/requests_page.dart';
import '../features/settings/settings_page.dart';
import '../features/shell/admin_shell.dart';
import '../features/students/students_page.dart';
import '../features/teachers/teachers_page.dart';
import '../providers/core_providers.dart';
import 'routes.dart';

/// URL map:
///   /login · /not-authorized
///   /                       Dashboard
///   /teachers?teacher=      Teachers (optionally opens one teacher)
///   /classes?teacher=       Classes (optionally filtered by teacher)
///   /requests               Class Requests
///   /students?classId=      Students (optionally filtered by class)
///   /reports?period=        School Reports
///   /settings               School profile + administrators
final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(adminSessionProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AdminRoutes.dashboard,
    refreshListenable: session,
    redirect: (context, state) {
      final at = state.matchedLocation;
      switch (session.access) {
        case AdminAccess.unknown:
          return null;
        case AdminAccess.signedOut:
          if (at == AdminRoutes.login) return null;
          final from = state.uri.toString();
          return at == AdminRoutes.notAuthorized || from == AdminRoutes.dashboard
              ? AdminRoutes.login
              : Uri(path: AdminRoutes.login, queryParameters: {'from': from}).toString();
        case AdminAccess.notAdmin:
          return at == AdminRoutes.notAuthorized ? null : AdminRoutes.notAuthorized;
        case AdminAccess.admin:
          if (at == AdminRoutes.login || at == AdminRoutes.notAuthorized) {
            return state.uri.queryParameters['from'] ?? AdminRoutes.dashboard;
          }
          return null;
      }
    },
    routes: [
      GoRoute(path: AdminRoutes.login, builder: (context, state) => const AdminLoginScreen()),
      GoRoute(path: AdminRoutes.notAuthorized, builder: (context, state) => const NotAuthorizedScreen()),
      ShellRoute(
        builder: (context, state, child) => AdminShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: AdminSection.dashboard.path,
            pageBuilder: (context, state) => _page(state, const AdminDashboardPage()),
          ),
          GoRoute(
            path: AdminSection.teachers.path,
            pageBuilder: (context, state) =>
                _page(state, TeachersPage(openTeacherId: state.uri.queryParameters['teacher'])),
          ),
          GoRoute(
            path: AdminSection.classes.path,
            pageBuilder: (context, state) =>
                _page(state, AdminClassesPage(teacherId: state.uri.queryParameters['teacher'])),
          ),
          GoRoute(
            path: AdminSection.requests.path,
            pageBuilder: (context, state) => _page(state, const RequestsPage()),
          ),
          GoRoute(
            path: AdminSection.students.path,
            pageBuilder: (context, state) =>
                _page(state, AdminStudentsPage(classId: state.uri.queryParameters['classId'])),
          ),
          GoRoute(
            path: AdminSection.reports.path,
            pageBuilder: (context, state) => _page(
              state,
              SchoolReportsPage(period: ReportPeriod.parse(state.uri.queryParameters['period'])),
            ),
          ),
          GoRoute(
            path: AdminSection.settings.path,
            pageBuilder: (context, state) => _page(state, const SettingsPage()),
          ),
        ],
      ),
    ],
  );
});

Page<void> _page(GoRouterState state, Widget child) =>
    NoTransitionPage<void>(key: state.pageKey, child: child);
