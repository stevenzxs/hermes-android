import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/screens/cron_screen.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/theme/hermes_theme.dart';
import 'package:hermes_android/l10n/app_localizations.dart';
import 'package:hermes_android/nextgen/data/nextgen_gateway.dart';
import 'package:hermes_android/nextgen/nextgen_l10n.dart';
import 'package:hermes_android/nextgen/nextgen_preferences.dart';
import 'package:hermes_android/nextgen/theme/nextgen_theme.dart';
import 'package:hermes_android/nextgen/ui/nextgen_scope.dart';
import 'package:hermes_android/nextgen/ui/scheduled_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  MockClient classicTransport(
    List<http.Request> writes, {
    required bool supportsManual,
  }) {
    return MockClient((r) async {
      if (r.method != 'GET') {
        writes.add(r);
        return http.Response('{"id":"created"}', 200);
      }
      if (r.url.path == '/') {
        return http.Response(
          '<html>window.__HERMES_SESSION_TOKEN__="token";</html>',
          200,
        );
      }
      if (r.url.path.endsWith('/capabilities')) {
        return http.Response(
          jsonEncode({'manual_schedule': supportsManual}),
          200,
        );
      }
      return http.Response('[]', 200);
    });
  }

  Future<void> openClassicCreateDialog(
    WidgetTester tester,
    MockClient client,
  ) async {
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: hermesTheme(Brightness.light),
        home: CronScreen(
          connection: SavedConnection(
            id: 'create',
            label: 'test',
            host: 'create.invalid',
            port: 8642,
            apiKey: 'unused',
          ),
          testDashboardHttpClient: client,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
  }

  Future<void> selectManualMode(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('cron-create-trigger-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('手动触发'));
    await tester.pumpAndSettle();
  }

  testWidgets('capable server: manual mode hides schedule and creates a '
      'manual job', (tester) async {
    final writes = <http.Request>[];
    await openClassicCreateDialog(
      tester,
      classicTransport(writes, supportsManual: true),
    );
    expect(find.byType(TextField), findsNWidgets(4));
    await selectManualMode(tester);
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('仅在主动触发时执行，没有调度计划时间。'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Job');
    await tester.enterText(find.byType(TextField).at(1), 'do it');
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    expect(writes, hasLength(1));
    expect(writes.single.url.path, '/api/cron/jobs');
    expect(jsonDecode(writes.single.body), {
      'prompt': 'do it',
      'schedule': 'manual',
      'name': 'Job',
      'deliver': 'local',
    });
  });

  testWidgets('capability missing: dropdown disabled, schedule text passes '
      'through', (tester) async {
    final writes = <http.Request>[];
    await openClassicCreateDialog(
      tester,
      classicTransport(writes, supportsManual: false),
    );
    final dropdown = tester.widget<DropdownButtonFormField<bool>>(
      find.byKey(const ValueKey('cron-create-trigger-mode')),
    );
    expect(dropdown.onChanged, isNull);
    expect(find.text('无法确认服务端支持创建仅手动任务'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(4));
    await tester.enterText(find.byType(TextField).at(0), 'Job');
    await tester.enterText(find.byType(TextField).at(1), 'do it');
    await tester.enterText(find.byType(TextField).at(2), 'every 2h');
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    expect(writes, hasLength(1));
    expect(jsonDecode(writes.single.body)['schedule'], 'every 2h');
  });

  testWidgets('automatic mode still requires a schedule; manual does not', (
    tester,
  ) async {
    final writes = <http.Request>[];
    await openClassicCreateDialog(
      tester,
      classicTransport(writes, supportsManual: true),
    );
    await tester.enterText(find.byType(TextField).at(0), 'Job');
    await tester.enterText(find.byType(TextField).at(1), 'do it');
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    expect(writes, isEmpty);
    expect(find.text('添加 Cron 任务'), findsOneWidget);
    await selectManualMode(tester);
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    expect(writes, hasLength(1));
    expect(jsonDecode(writes.single.body)['schedule'], 'manual');
  });

  testWidgets('NextGen sheet: capable server creates a manual job', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final writes = <http.Request>[];
    final transport = MockClient((r) async {
      if (r.method != 'GET') {
        writes.add(r);
        return http.Response('{"id":"created"}', 200);
      }
      if (r.url.path.endsWith('/capabilities')) {
        return http.Response('{"manual_schedule":true}', 200);
      }
      return http.Response('[]', 200);
    });
    final connection = SavedConnection(
      id: 'ng',
      label: 'test',
      host: 'ng-create.invalid',
      port: 8642,
      apiKey: '',
      dashboardProxied: true,
      desktopGatewayUrl: 'https://ng-create.invalid',
    );
    final gateway = NextGenGateway(
      connection,
      dashboard: DashboardClient.fromConnection(
        connection,
        httpClient: transport,
      ),
    );
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
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(4));
    await selectManualMode(tester);
    expect(find.byType(TextField), findsNWidgets(3));
    final prompt = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == '提示词',
    );
    await tester.enterText(prompt, 'do it');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();
    expect(writes, hasLength(1));
    expect(writes.single.url.path, '/api/cron/jobs');
    expect(jsonDecode(writes.single.body), {
      'prompt': 'do it',
      'schedule': 'manual',
      'name': '',
      'deliver': 'local',
    });
  });
}
