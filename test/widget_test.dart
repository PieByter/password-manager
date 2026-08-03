import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/app.dart';

void main() {
  testWidgets('App launches', (tester) async {
    await tester.pumpWidget(const PasswordManagerApp());
    // Pump one frame to trigger post-frame callback
    await tester.pump();
    // App should be rendering something
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
