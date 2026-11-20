import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/widgets/cron_job_editor.dart';
import 'package:hermes_android/core/widgets/cron_trigger_settings.dart';
import 'package:hermes_android/l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<void> open(
  WidgetTester tester, {
  required Map<String, dynamic> job,
  required void Function(Map<String, dynamic>?) onResult,
  bool focusTrigger = false,
  bool supportsManual = true,
}) async {
  tester.view.physicalSize = const Size(650, 1500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final client = DashboardClient(
    host: 'editor.invalid',
    httpClient: MockClient((r) async {
      expect(r.method, 'GET');
      if (r.url.path.endsWith('capabilities')) {
        return http.Response(
          jsonEncode({'manual_schedule': supportsManual}),
          200,
        );
      }
      return http.Response('{"providers":[]}', 200);
    }),
  );
  addTearDown(client.close);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            child: const Text('Open'),
            onPressed: () async => onResult(
              await showCronJobEditor(
                context,
                client,
                job,
                focusTrigger: focusTrigger,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('trigger shortcut expands the shared trigger section only', (
    tester,
  ) async {
    Map<String, dynamic>? result;
    await open(
      tester,
      job: {
        'schedule': {'kind': 'interval', 'minutes': 90},
        'schedule_display': 'human display',
        'repeat': {'times': 3, 'completed': 2},
      },
      focusTrigger: true,
      onResult: (v) => result = v,
    );
    expect(find.byKey(const ValueKey('cron-name')), findsNothing);
    final field = find.byKey(const ValueKey('cron-schedule'));
    expect(tester.widget<TextField>(field).controller!.text, 'every 90m');
    expect(find.text('Consumed: 2; remaining: 1'), findsOneWidget);
    expect(find.text('Open new round'), findsNothing);
    await tester.enterText(field, 'every 2h');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result, {'schedule': 'every 2h', 'repeat': 3});
  });

  testWidgets(
    'once ISO timezone and whitespace content survive untouched save',
    (tester) async {
      Map<String, dynamic>? result;
      await open(
        tester,
        job: {
          'name': ' name ',
          'prompt': ' prompt ',
          'schedule': {'kind': 'once', 'run_at': '2026-12-01T09:00:00+08:00'},
          'repeat': {'times': 1, 'completed': 1},
          'state': 'completed',
        },
        onResult: (v) => result = v,
      );
      await tester.tap(find.text('Trigger & execution'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('cron-schedule')))
            .controller!
            .text,
        '2026-12-01T09:00:00+08:00',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(result, isEmpty);
    },
  );

  testWidgets('invalid limit and unsupported manual input cannot save', (
    tester,
  ) async {
    var returned = false;
    await open(
      tester,
      job: {
        'schedule': {'kind': 'cron', 'expr': '0 9 * * *'},
      },
      focusTrigger: true,
      supportsManual: false,
      onResult: (_) => returned = true,
    );
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNull,
    );
    await tester.enterText(find.byKey(const ValueKey('cron-limit')), '0');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(returned, isFalse);
    await tester.enterText(find.byKey(const ValueKey('cron-limit')), '');
    await tester.enterText(
      find.byKey(const ValueKey('cron-schedule')),
      'manual',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(returned, isFalse);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(returned, isTrue);
  });

  for (final confirm in [false, true]) {
    testWidgets('new round is separate and confirmed=$confirm', (tester) async {
      final writes = <http.Request>[];
      final client = DashboardClient(
        host: 'round.invalid',
        httpClient: MockClient((r) async {
          if (r.method == 'POST') writes.add(r);
          if (r.url.path.endsWith('capabilities')) {
            return http.Response('{"new_round":true}', 200);
          }
          if (r.url.path == '/') {
            return http.Response(
              '<html>window.__HERMES_SESSION_TOKEN__="token";</html>',
              200,
            );
          }
          return http.Response(
            '{"id":"successor","state":"paused","enabled":false,"round_parent_id":"old","repeat":{"completed":0}}',
            200,
          );
        }),
      );
      addTearDown(client.close);
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Round'),
                onPressed: () async {
                  result = await showCronNewRound(context, client, {
                    'id': 'old',
                    'state': 'completed',
                  });
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Round'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('paused successor'), findsOneWidget);
      await tester.tap(find.text(confirm ? 'Confirm' : 'Cancel'));
      await tester.pumpAndSettle();
      expect(result, confirm);
      expect(writes, hasLength(confirm ? 1 : 0));
      if (confirm) {
        expect(writes.single.url.path, '/api/cron/jobs/old/new-round');
        expect(jsonDecode(writes.single.body), {
          'request_id': client.cronRoundRequestId('old'),
        });
      }
    });
  }

  testWidgets('new round cannot claim success from a malformed successor', (
    tester,
  ) async {
    final client = DashboardClient(
      host: 'invalid-round.invalid',
      httpClient: MockClient((r) async {
        if (r.url.path == '/') {
          return http.Response(
            '<html>window.__HERMES_SESSION_TOKEN__="token";</html>',
            200,
          );
        }
        if (r.method == 'GET') return http.Response('{"new_round":true}', 200);
        return http.Response('{"ok":false}', 200);
      }),
    );
    addTearDown(client.close);
    Object? error;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Round'),
              onPressed: () async {
                try {
                  await showCronNewRound(context, client, {
                    'id': 'old',
                    'state': 'completed',
                  });
                } catch (e) {
                  error = e;
                }
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Round'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(error, isA<FormatException>());
  });

  testWidgets('stale profile cannot save settings or create a new round', (
    tester,
  ) async {
    final writes = <http.Request>[];
    final client = DashboardClient(
      host: 'stale.invalid',
      httpClient: MockClient((r) async {
        if (r.method != 'GET') writes.add(r);
        return http.Response('{"manual_schedule":true,"new_round":true}', 200);
      }),
    );
    addTearDown(client.close);
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  child: const Text('Settings'),
                  onPressed: () async {
                    result = await showCronTriggerSettings(context, client, {
                      'id': 'old',
                      'schedule': {'kind': 'manual'},
                    }, isCurrent: () => false);
                  },
                ),
                TextButton(
                  child: const Text('Round'),
                  onPressed: () async {
                    result = await showCronNewRound(context, client, {
                      'id': 'old',
                      'state': 'completed',
                    }, isCurrent: () => false);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('cron-limit')), '5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    await tester.tap(find.text('Round'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(find.text('Open a new round?'), findsNothing);
    expect(writes, isEmpty);
  });
}
