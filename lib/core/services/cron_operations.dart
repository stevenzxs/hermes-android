import 'dart:async';
import 'dart:convert';

class CronRequestException implements Exception {
  const CronRequestException(this.status, this.message, {this.code});
  final int status;
  final String message;
  final String? code;
  @override
  String toString() => message;
}

CronRequestException cronRequestError(int status, String body) {
  String? code;
  try {
    final data = jsonDecode(body);
    if (data is Map && data['code'] is String) code = data['code'] as String;
  } on FormatException {
    // Legacy proxies need not return JSON.
  }
  return CronRequestException(status, cronErrorMessage(status, body), code: code);
}

String cronFailureLabel(Object error, {required bool chinese}) {
  if (!chinese || error is! CronRequestException) return '$error';
  return switch (error.code) {
    'execution_limit_reached' => '本轮执行次数已用尽，请显式开启新一轮。',
    'job_completed' => '任务已完成，请显式开启新一轮。',
    'job_terminal' => '任务已结束，不能直接触发。',
    'job_running' => '任务已有活跃执行，请查看运行历史。',
    'job_paused' => '任务已暂停或禁用。',
    'manual_only' => '此任务仅允许手动触发。',
    'occurrence_completed' => '当前调度批次已经执行完成。',
    'provider_unsupported' => '当前调度器不支持此触发操作。',
    'claim_conflict' => '未取得执行权，请查看任务状态和历史后再决定。',
    _ => error.message,
  };
}

/// One in-flight operation per connection/profile/job, shared across surfaces.
class CronOperations {
  final Map<String, Future<Map<String, dynamic>>> _pending = {};

  Future<Map<String, dynamic>> run(
    String key,
    Future<Map<String, dynamic>> Function() action,
  ) {
    final existing = _pending[key];
    if (existing != null) return existing;
    final completer = Completer<Map<String, dynamic>>();
    _pending[key] = completer.future;
    Future.sync(action).then((value) {
      _pending.remove(key);
      completer.complete(value);
    }, onError: (Object error, StackTrace stack) {
      _pending.remove(key);
      completer.completeError(error, stack);
    });
    return completer.future;
  }
}

String cronErrorMessage(int status, String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      final detail = decoded['detail'] ?? decoded['message'] ?? decoded['error'];
      final message = detail is Map ? detail['message'] : detail;
      if (message is String && message.trim().isNotEmpty &&
          !message.contains('<html') && message.length <= 1000) {
        return message.trim();
      }
    }
  } on FormatException {
    // Proxies may return HTML; never put that body in the UI.
  }
  return 'HTTP $status';
}
