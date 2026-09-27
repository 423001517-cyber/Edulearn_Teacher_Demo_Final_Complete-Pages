import 'package:admin_web/features/common/admin_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Widget tests that don't need Firebase. (This file also stops
// `flutter create .` from adding its default counter-app test.)
void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('class code chip shows the official code', (tester) async {
    await tester.pumpWidget(host(const CodeChip('RIZAL-4A')));
    expect(find.text('RIZAL-4A'), findsOneWidget);
    expect(find.byIcon(Icons.content_copy_outlined), findsOneWidget);
  });

  testWidgets('empty class code shows a dash', (tester) async {
    await tester.pumpWidget(host(const CodeChip('')));
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('rate cell shows a percentage', (tester) async {
    await tester.pumpWidget(host(const SizedBox(width: 160, child: RateCell(0.75))));
    expect(find.text('75%'), findsOneWidget);
  });
}
