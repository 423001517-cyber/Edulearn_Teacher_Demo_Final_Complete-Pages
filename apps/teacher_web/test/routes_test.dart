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
