import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/widgets/cron_job_status.dart';

void main() {
  testWidgets('authoritative false overrides legacy running state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CronJobStatus(
            job: {'state': 'running', 'execution_running': false},
          ),
        ),
      ),
    );
    expect(find.text('Running'), findsNothing);
  });
  testWidgets('old server uses explicit state but never raw claims', (
    tester,
  ) async {
    for (final state in ['paused', 'running']) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CronJobStatus(
              job: {
                'state': state,
                'fire_claim': {'at': '2000-01-01T00:00:00Z'},
              },
            ),
          ),
        ),
      );
      expect(
        find.text('Running'),
        state == 'running' ? findsOneWidget : findsNothing,
      );
    }
  });
  testWidgets(
    'only authoritative live execution shows running; raw claims are not proof',
    (tester) async {
      for (final running in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CronJobStatus(
                job: {
                  'enabled': false,
                  'state': 'paused',
                  'execution_running': running,
                  'fire_claim': {'at': '2000-01-01T00:00:00Z'},
                },
              ),
            ),
          ),
        );
        expect(find.text('Paused'), findsOneWidget);
        expect(find.text('Running'), running ? findsOneWidget : findsNothing);
      }
    },
  );
}
