import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/services/cron_operations.dart';

void main() {
  test('same scoped job coalesces concurrent requests', () async {
    final operations = CronOperations();
    final gate = Completer<Map<String, dynamic>>();
    var calls = 0;
    Future<Map<String, dynamic>> action() { calls++; return gate.future; }
    final first = operations.run('connection/profile/job', action);
    final second = operations.run('connection/profile/job', action);
    gate.complete({'ok': true});
    expect(await first, await second);
    expect(calls, 1);
  });
  test('safe legacy detail preserved, HTML replaced', () {
    expect(cronErrorMessage(409, '{"detail":"Execution limit reached"}'),
        'Execution limit reached');
    expect(cronErrorMessage(502, '<html>upstream</html>'), 'HTTP 502');
  });
  test('structured codes and legacy nested detail are preserved', () {
    final error = cronRequestError(409,
        '{"code":"execution_limit_reached","message":"Spent","detail":"Spent"}');
    expect(error.code, 'execution_limit_reached');
    expect(cronFailureLabel(error, chinese: true), contains('次数已用尽'));
    expect(cronErrorMessage(409, '{"detail":{"message":"Paused"}}'), 'Paused');
    expect(cronErrorMessage(502, 'null'), 'HTTP 502');
  });
  test('failed operations release their key and different jobs run independently', () async {
    final operations = CronOperations();
    final gate = Completer<Map<String, dynamic>>();
    final first = operations.run('a', () => gate.future);
    expect(await operations.run('b', () async => {'ok': true}), {'ok': true});
    final failed = expectLater(first, throwsStateError);
    gate.completeError(StateError('lost'));
    await failed;
    expect(await operations.run('a', () async => {'retried': true}), {'retried': true});
  });
}
