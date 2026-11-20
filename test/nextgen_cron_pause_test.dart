import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/l10n/app_localizations.dart';
import 'package:hermes_android/nextgen/data/nextgen_gateway.dart';
import 'package:hermes_android/nextgen/nextgen_preferences.dart';
import 'package:hermes_android/nextgen/nextgen_l10n.dart';
import 'package:hermes_android/nextgen/theme/nextgen_theme.dart';
import 'package:hermes_android/nextgen/ui/nextgen_scope.dart';
import 'package:hermes_android/nextgen/ui/scheduled_page.dart';
import 'package:hermes_android/nextgen/ui/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('NextGen list ignores the old gateway response after a switch', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final held = Completer<http.Response>();
    final prefs = await SharedPreferences.getInstance();
    NextGenGateway gateway(
      String id,
      Future<http.Response> Function(http.Request) respond,
    ) {
      final c = SavedConnection(
        id: id,
        label: id,
        host: '$id.invalid',
        port: 8642,
        apiKey: '',
        dashboardProxied: true,
        desktopGatewayUrl: 'https://$id.invalid',
      );
      return NextGenGateway(
        c,
        dashboard: DashboardClient.fromConnection(
          c,
          httpClient: MockClient(respond),
        ),
      );
    }

    final old = gateway('old', (_) => held.future);
    final next = gateway('next', (_) async => http.Response('[]', 200));
    addTearDown(old.dispose);
    addTearDown(next.dispose);
    Widget app(NextGenGateway g) => MaterialApp(
      builder: (_, child) => NgScope(
        connManager: ConnectionManager(prefs),
        gateway: g,
        connections: [g.connection],
        switchTo: (_) async {},
        addGateway: () async {},
        signOut: (_) async {},
        reload: () async {},
        signInAgain: () async {},
        child: child!,
      ),
      home: NgScheduledPage(onOpenSession: (_) {}),
    );
    await tester.pumpWidget(app(old));
    await tester.pump();
    await tester.pumpWidget(app(next));
    await tester.pump();
    held.complete(
      http.Response('[{"id":"old-job","name":"Old gateway task"}]', 200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Old gateway task'), findsNothing);
  });
  for (final paused in [true, false]) {
    for (final manual in [true, false]) {
      testWidgets(
        'NextGen paused=$paused manual=$manual gates start and resume',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final writes = <http.Request>[];
          final job = <String, dynamic>{
            'id': 'job',
            'name': 'Work',
            'enabled': !paused,
            'state': paused ? 'paused' : 'scheduled',
            'schedule': {
              'kind': manual ? 'manual' : 'cron',
              'expr': '0 9 * * *',
            },
            'fire_claim': {'at': DateTime.now().toUtc().toIso8601String()},
            'execution_running': true,
          };
          final transport = MockClient((r) async {
            if (r.method != 'GET') writes.add(r);
            if (r.url.path.endsWith('/resume')) {
              job.addAll({'enabled': true, 'state': 'scheduled'});
            }
            return http.Response(
              jsonEncode(
                r.url.path.endsWith('/runs')
                    ? []
                    : r.url.path.endsWith('/jobs')
                    ? [job]
                    : job,
              ),
              200,
            );
          });
          final connection = SavedConnection(
            id: 'ng',
            label: 'test',
            host: 'ng.invalid',
            port: 8642,
            apiKey: '',
            dashboardProxied: true,
            desktopGatewayUrl: 'https://ng.invalid',
          );
          final dashboard = DashboardClient.fromConnection(
            connection,
            httpClient: transport,
          );
          final gateway = NextGenGateway(connection, dashboard: dashboard);
          addTearDown(gateway.dispose);
          final prefs = await SharedPreferences.getInstance();
          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: nextGenTheme(Brightness.light, NextGenLook.instance),
              builder: (context, child) => NgLocalizationScope(
                child: NgScope(
                  connManager: ConnectionManager(prefs),
                  gateway: gateway,
                  connections: [connection],
                  switchTo: (_) async {},
                  addGateway: () async {},
                  signOut: (_) async {},
                  reload: () async {},
                  signInAgain: () async {},
                  child: child!,
                ),
              ),
              home: NgScheduledPage(onOpenSession: (_) {}),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(paused ? '暂停' : '正常'), findsOneWidget);
          expect(find.text('正在运行'), findsOneWidget);
          await tester.tap(find.text('Work'));
          await tester.pumpAndSettle();
          expect(find.byTooltip('开启新一轮'), findsNothing);
          var start = tester.widget<NgPrimaryButton>(
            find.byType(NgPrimaryButton),
          );
          expect(start.label, manual ? '立即执行' : '启动计划');
          expect(start.onPressed == null, paused);
          if (paused) {
            await tester.tap(find.text('恢复'));
            await tester.pumpAndSettle();
            expect(writes.map((r) => r.url.path), [
              '/api/cron/jobs/job/resume',
            ]);
            start = tester.widget<NgPrimaryButton>(
              find.byType(NgPrimaryButton),
            );
            expect(start.onPressed, isNotNull);
            writes.clear();
          }
          await tester.tap(find.text(manual ? '立即执行' : '启动计划'));
          await tester.pumpAndSettle();
          expect(writes.map((r) => r.url.path), ['/api/cron/jobs/job/trigger']);
          Navigator.of(tester.element(find.byType(NgPrimaryButton))).pop();
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.add));
          await tester.pumpAndSettle();
          final limit = tester.widget<TextField>(
            find.byKey(const ValueKey('cron-create-limit')),
          );
          expect(limit.enabled, false);
          expect(limit.controller?.text ?? '', isEmpty);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
