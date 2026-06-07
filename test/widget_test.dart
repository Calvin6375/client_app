import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pretium/features/auth/widgets/welcome_text_section.dart';

void main() {
  testWidgets('Welcome text section builds', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WelcomeTextSection())),
    );

    expect(find.text('Welcome Back!'), findsOneWidget);
  });
}
