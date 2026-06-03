import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_edge_tts_example/main.dart';

void main() {
  testWidgets('example app renders demo shell', (WidgetTester tester) async {
    await tester.pumpWidget(const EdgeTtsExampleApp());

    expect(find.text('Voice Studio'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Voice Settings'), findsOneWidget);
  });

  testWidgets('example app renders on narrow mobile widths', (
    WidgetTester tester,
  ) async {
    final binding = tester.binding;
    await binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() async {
      await binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(const EdgeTtsExampleApp());
    await tester.pump();

    expect(find.text('Voice Studio'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
