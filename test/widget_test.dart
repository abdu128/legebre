// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:legebre/main.dart';
import 'package:legebre/state/app_state.dart';

void main() {
  testWidgets('Legebere splash renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const LegebereApp(),
      ),
    );

    await tester.pump();

    expect(find.text('Legebere'), findsWidgets);
  });
}
