import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/screens/cron_screen.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/theme/hermes_theme.dart';
import 'package:hermes_android/l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final paused in [true, false]) {
    for (final manual in [true, false]) {
      testWidgets(
        'card paused=$paused manual=$manual preserves independent running state',
        (tester) async {
          final writes = <http.Request>[];
          final client = MockClient((r) async {
            if (r.method != 'GET') writes.add(r);
            if (r.url.path == '/') {
              return http.Response(
                '<html>window.__HERMES_SESSION_TOKEN__="token";</html>',
                200,
              );
            }
            return http.Response(
              jsonEncode([
                {
                  'id': 'job',
                  'name': 'Work',
                  'enabled': !paused,
                  'state': paused ? 'paused' : 'scheduled',
                  'schedule': {
                    'kind': manual ? 'manual' : 'cron',
                    'expr': '0 9 * * *',
                  },
                  'fire_claim': {
                    'at': DateTime.now().toUtc().toIso8601String(),
                  },
                  'execution_running': true,
                },
              ]),
              200,
            );
          });
          addTearDown(client.close);
          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: hermesTheme(Brightness.light),
              home: CronScreen(
                connection: SavedConnection(
                  id: 'pause',
                  label: 'test',
                  host: 'pause.invalid',
                  port: 8642,
                  apiKey: 'unused',
                ),
                testDashboardHttpClient: client,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(paused ? '暂停' : '正常'), findsOneWidget);
          expect(find.text('正在运行'), findsOneWidget);
          await tester.tap(find.byType(PopupMenuButton<String>));
          await tester.pumpAndSettle();
          expect(find.text('触发与执行'), findsNothing);
          expect(find.text('开启新一轮'), findsNothing);
          expect(find.text('Resume'), findsNothing);
          final trigger = tester.widget<PopupMenuItem<String>>(
            find.byWidgetPredicate(
              (w) => w is PopupMenuItem<String> && w.value == 'trigger',
            ),
          );
          expect(trigger.enabled, !paused);
          expect(find.text(manual ? '立即执行' : '启动计划'), findsOneWidget);
          expect(find.text(paused ? '恢复' : '暂停'), findsWidgets);
          expect(writes, isEmpty);
          await tester.tapAt(const Offset(10, 10));
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.add));
          await tester.pumpAndSettle();
          final limit = tester.widget<TextField>(
            find.byKey(const ValueKey('cron-create-limit')),
          );
          expect(limit.enabled, false);
          expect(limit.controller?.text ?? '', isEmpty);
        },
      );
    }
  }
}
