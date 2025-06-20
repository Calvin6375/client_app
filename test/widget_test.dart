// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pretium/app/app.dart';

void main() {
  testWidgets('App loads splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(PretiumApp());

    // Wait for splash screen to build
    await tester.pumpAndSettle();

    // Replace 'Splash' with actual text or key from your SplashPage if needed
    expect(find.byType(Scaffold), findsOneWidget);
    // Optionally, check for a widget or text unique to your splash screen:
    // expect(find.text('Splash'), findsOneWidget);
  });
}
