import 'package:admin_web/app/routes.dart';
import 'package:admin_web/features/students/roster_csv.dart';
import 'package:admin_web/providers/admin_providers.dart';
import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('roster CSV import', () {
    test('header, quotes, padding and auto numbers', () {
      final r = parseRosterCsv(
        '\uFEFFName,Student Number\n'
        'Maria Santos,1\n'
        '"Dela Cruz, Juan",0002\n'
        'Carlo Reyes,\n'
        '\n'
        ',0009\n',
        firstNumber: 3,
      );
      expect(r.rows.map((x) => x.name), ['Maria Santos', 'Dela Cruz, Juan', 'Carlo Reyes']);
      expect(r.rows.map((x) => x.number), ['0001', '0002', '0003']);
      expect(r.errors.single, contains('missing name'));
    });

    test('names only, and numbers already in the class are skipped', () {
      final r = parseRosterCsv('Ana Lopez\nMiguel Torres', firstNumber: 5, takenNumbers: {'0005'});
      expect(r.rows.map((x) => x.number), ['0006', '0007']);
    });

    test('duplicate numbers get a new one with a warning', () {
      final r = parseRosterCsv('name,number\nA,0004\nB,0004', takenNumbers: {'0001'});
      expect(r.rows.map((x) => x.number), ['0004', '0002']);
      expect(r.errors.single, contains('already used'));
    });

    test('empty file', () {
      expect(parseRosterCsv('  \n').errors, ['The file is empty.']);
    });

    test('quoted cells with escaped quotes and semicolons', () {
      expect(splitCsvLine('"Rey, ""Junia""";0003'), ['Rey, "Junia"', '0003']);
    });
  });

  test('next student number', () {
    Student s(String n) => Student(id: n, name: 'S', classId: 'c', gradeLevel: 4, studentNumber: n);
    expect(nextStudentNumber([]), '0001');
    expect(nextStudentNumber([s('0001'), s('0020'), s('x')]), '0021');
  });

  test('admin URLs and sidebar sections', () {
    expect(AdminRoutes.classes(teacherId: 'rosa'), '/classes?teacher=rosa');
    expect(AdminRoutes.students(classId: 'rizal-4a'), '/students?classId=rizal-4a');
    expect(AdminRoutes.reports(), '/reports');
    expect(AdminSection.fromPath('/requests'), AdminSection.requests);
    expect(AdminSection.fromPath('/'), AdminSection.dashboard);
    expect(AdminSection.fromPath('/teachers'), AdminSection.teachers);
  });
}
