import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/services/cron_operations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('concurrent triggers share one profiled POST and retain refusal body', () async {
    var posts = 0;
    final gate = Completer<http.Response>();
    final client = DashboardClient(host: 'cron.invalid', gatewayProfile: 'worker',
        httpClient: MockClient((request) async {
      if (request.method == 'POST') {
        posts++;
        expect(request.url.queryParameters['profile'], 'worker');
        return gate.future;
      }
      return http.Response('<html>window.__HERMES_SESSION_TOKEN__="token";</html>', 200);
    }));
    final first = client.triggerJob('completed');
    final second = client.triggerJob('completed');
    final expected = isA<CronRequestException>().having((e) => e.code,
        'reason', 'execution_limit_reached');
    final checks = Future.wait([
      expectLater(first, throwsA(expected)), expectLater(second, throwsA(expected)),
    ]);
    gate.complete(http.Response(jsonEncode({'code': 'execution_limit_reached',
        'detail': 'Execution limit reached'}), 409));
    await checks;
    expect(posts, 1);
    client.close();
  });
}
