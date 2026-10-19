import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_web/app/routes.dart';

/// The URLs that connect the homepage, Classes, Students and Reports.
void main() {
  group('routes (how the homepage links into Classes, Students, Reports)', () {
    test('builds class, students and reports URLs', () {
      expect(Routes.classDetail('rizal-4a'), '/classes/rizal-4a');
      expect(Routes.classDetail('rizal-4a', ClassTab.classwork), '/classes/rizal-4a?tab=classwork');
      expect(Routes.students(), '/students');
      expect(Routes.students(classId: 'rizal-4a', studentId: 's1'),
          '/students?classId=rizal-4a&student=s1');
      expect(Routes.reports(classId: 'rizal-4a', panel: 'missing'),
          '/reports?classId=rizal-4a&panel=missing');
    });

    test('builds URLs for Analytics, Attendance, Rewards, Messages, Settings', () {
      expect(Routes.analytics(), '/analytics');
      expect(Routes.analytics(classId: 'rizal-4a', range: 'week'), '/analytics?classId=rizal-4a&range=week');
      expect(Routes.attendance(classId: 'rizal-4a', date: DateTime(2026, 10, 9)),
          '/attendance?classId=rizal-4a&date=2026-10-09');
      expect(Routes.rewards(classId: 'boni-5b'), '/rewards?classId=boni-5b');
      expect(Routes.messages(studentId: 's1'), '/messages?student=s1');
      expect(Routes.messages(groupClassId: 'rizal-4a'), '/messages?group=rizal-4a');
      expect(Routes.settings(section: 'notifications'), '/settings?section=notifications');
      for (final s in NavSection.values) {
        expect(s.isBuilt, isTrue, reason: '${s.label} has a page');
      }
      expect(NavSection.fromPath('/messages'), NavSection.messages);
      expect(NavSection.fromPath('/settings'), NavSection.settings);
    });

    test('sidebar highlights the right section for nested URLs', () {
      expect(NavSection.fromPath('/'), NavSection.dashboard);
      expect(NavSection.fromPath('/classes'), NavSection.classes);
      expect(NavSection.fromPath('/classes/rizal-4a'), NavSection.classes);
      expect(NavSection.fromPath('/reports'), NavSection.reports);
      expect(NavSection.fromPath('/nope'), NavSection.dashboard);
      expect(ClassTab.parse('students'), ClassTab.students);
      expect(ClassTab.parse(null), ClassTab.overview);
    });
  });
}
