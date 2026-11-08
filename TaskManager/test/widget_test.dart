
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Hiển thị giao diện Flutter cơ bản', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Task Manager'),
        ),
      ),
    );

    expect(find.text('Task Manager'), findsOneWidget);
  });
}
