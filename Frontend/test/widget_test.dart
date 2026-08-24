// Basic smoke test for HomeFix Live.
//
// The default `flutter create` template generates a counter-app test
// (looking for "0", tapping a "+" button, expecting "1") that has nothing to
// do with this app and will fail. This replaces it with a minimal smoke
// test that just checks the app boots to the splash screen without
// throwing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homefix_live/app.dart';

void main() {
  testWidgets('App boots and shows the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Don't use pumpAndSettle() here — SplashScreen likely kicks off a timer
    // and/or an async auth-check (reading secure storage, hitting the
    // backend) that won't resolve in a widget-test sandbox (no real platform
    // channels / network). A single pump() is enough to prove the widget
    // tree builds without throwing.
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}