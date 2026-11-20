import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'cron_unified_editor_test.dart' as editor;

void main() {
  testWidgets('trigger settings scroll on a narrow window with large text', (
    tester,
  ) async {
    await editor.open(
      tester,
      job: {
        'schedule': {'kind': 'cron', 'expr': '0 9 * * *'},
      },
      focusTrigger: true,
      onResult: (_) {},
    );
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('cron-limit')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
  testWidgets('manual mode has no rule and unlimited limit is disabled', (
    tester,
  ) async {
    await editor.open(
      tester,
      job: {
        'schedule': {'kind': 'manual'},
      },
      focusTrigger: true,
      onResult: (_) {},
    );
    expect(find.byType(DropdownButtonFormField<bool>), findsOneWidget);
    expect(find.byKey(const ValueKey('cron-schedule')), findsNothing);
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('cron-limit')),
    );
    expect(field.enabled, false);
    expect(field.controller!.text, isEmpty);
    expect(find.text('Unlimited'), findsOneWidget);
  });

  testWidgets('changing mode keeps stored finite budget without running', (
    tester,
  ) async {
    Map<String, dynamic>? result;
    await editor.open(
      tester,
      job: {
        'schedule': {'kind': 'cron', 'expr': '0 9 * * *'},
        'repeat': {'times': 3, 'completed': 2},
      },
      focusTrigger: true,
      onResult: (v) => result = v,
    );
    final limit = tester.widget<TextField>(
      find.byKey(const ValueKey('cron-limit')),
    );
    expect(limit.enabled, false);
    expect(limit.controller!.text, '3');
    await tester.tap(find.byType(DropdownButtonFormField<bool>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manual trigger').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cron-schedule')), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result, {'schedule': 'manual', 'repeat': 3});
  });
}
