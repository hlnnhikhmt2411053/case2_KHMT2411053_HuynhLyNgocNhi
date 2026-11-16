import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  testWidgets('Smoke test: Flutter giao diện cơ bản', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('TaskManager'))));
    expect(find.text('TaskManager'), findsOneWidget);
  });
}
