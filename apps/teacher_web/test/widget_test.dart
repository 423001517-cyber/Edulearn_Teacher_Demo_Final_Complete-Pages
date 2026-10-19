import 'package:edulearn_core/edulearn_core.dart';
import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_web/features/classes/widgets/class_dialogs.dart';

// Widget tests that don't need Firebase. (This file also stops
// `flutter create .` from adding its default counter-app test.)
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('Pill and ProgressBar render', (tester) async {
    await tester.pumpWidget(host(const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Pill('2 missing', tone: Tone.amber),
        SizedBox(width: 200, child: ProgressBar(value: 0.75)),
      ],
    )));
    expect(find.text('2 missing'), findsOneWidget);
    expect(find.byType(ProgressBar), findsOneWidget);
  });

  testWidgets('SegmentedPills reports the tapped option', (tester) async {
    String? picked;
    await tester.pumpWidget(host(SegmentedPills<String>(
      value: 'week',
      options: const ['week', 'month', 'quarter'],
      labelOf: (v) => 'This $v',
      onChanged: (v) => picked = v,
    )));
    await tester.tap(find.text('This month'));
    expect(picked, 'month');
  });

  testWidgets('Archive Class stays disabled until the checkbox is ticked', (tester) async {
    const rizal = ClassRoom(id: 'rizal-4a', teacherId: 't', gradeLevel: 4, section: 'Rizal', classCode: 'RIZAL-4A');
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showArchiveClassDialog(context, rizal),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Archive Grade 4 – Rizal?'), findsOneWidget);
    final archive = find.widgetWithText(FilledButton, 'Archive Class');
    expect(tester.widget<FilledButton>(archive).onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(tester.widget<FilledButton>(archive).onPressed, isNotNull);

    await tester.tap(archive);
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
