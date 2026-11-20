import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/widgets/cron_trigger_settings.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('saving a manual limit sends only settings, never a trigger', (tester) async {
    final writes = <http.Request>[];
    final client = DashboardClient(host: 'settings.invalid',
      httpClient: MockClient((r) async {
        if (r.method == 'PUT' || r.method == 'POST') writes.add(r);
        if (r.url.path.endsWith('/capabilities')) {
          return http.Response('{"manual_schedule":true,"new_round":true}', 200);
        }
        if (r.url.path == '/') return http.Response(
            '<html>window.__HERMES_SESSION_TOKEN__="token";</html>', 200);
        if (r.method == 'PUT') return http.Response(
            '{"schedule":{"kind":"manual"},"repeat":{"times":5,"completed":1}}', 200);
        return http.Response('{}', 200);
      }));
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: TextButton(onPressed: () => showCronTriggerSettings(context, client, {
        'id': 'manual-job', 'schedule': {'kind': 'manual'},
        'repeat': {'times': 3, 'completed': 1}, 'state': 'scheduled',
      }), child: const Text('Settings'))))));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(writes, hasLength(1));
    expect(writes.single.method, 'PUT');
    expect(jsonDecode(writes.single.body), {
      'updates': {'schedule': 'manual', 'repeat': 5},
    });
    client.close();
  });
}
