/// Editable schedules use canonical data, never the human display string.
String cronScheduleInput(Map<String, dynamic> job) {
  final schedule = job['schedule'];
  if (schedule is String) return schedule;
  if (schedule is! Map) return '';
  return switch (schedule['kind']) {
    'manual' => 'manual',
    'cron' => (schedule['expr'] ?? '').toString(),
    'once' => (schedule['run_at'] ?? '').toString(),
    'interval' =>
      schedule['minutes'] == null ? '' : 'every ${schedule['minutes']}m',
    _ => '',
  };
}

int? cronExecutionLimit(Map<String, dynamic> job) {
  final repeat = job['repeat'];
  return repeat is Map ? repeat['times'] as int? : null;
}

/// A patch, not a replacement: unrelated edits must not touch scheduling state.
Map<String, dynamic> cronJobPatch(
  Map<String, dynamic> job, {
  required String name,
  required String prompt,
  required bool noAgent,
  required String schedule,
  required int? limit,
  required String model,
  required String provider,
  required String baseUrl,
}) {
  final patch = <String, dynamic>{};
  for (final entry in {'name': name, 'prompt': prompt}.entries) {
    if (entry.value != (job[entry.key] ?? '')) patch[entry.key] = entry.value;
  }
  if (noAgent != (job['no_agent'] == true)) patch['no_agent'] = noAgent;
  if (schedule != cronScheduleInput(job)) {
    patch['schedule'] = schedule;
    // Explicitly preserve the limit when changing kind. Otherwise the server
    // may derive a different default for once -> recurring (or vice versa).
    patch['repeat'] = limit;
  } else if (limit != cronExecutionLimit(job)) {
    patch['repeat'] = limit;
  }
  if (!noAgent &&
      (model != (job['model'] ?? '') ||
          provider != (job['provider'] ?? '') ||
          baseUrl != (job['base_url'] ?? ''))) {
    patch.addAll({
      'model': model.isEmpty ? null : model,
      'provider': provider.isEmpty ? null : provider,
      'base_url': baseUrl.isEmpty ? null : baseUrl,
    });
  }
  return patch;
}

/// Check only fields we requested. Lifecycle and consumed counters are owned by
/// the server and must never be written back from a stale editor snapshot.
bool cronPatchMatches(Map saved, Map<String, dynamic> patch) {
  for (final entry in patch.entries) {
    if (entry.key == 'repeat') {
      if (saved['repeat'] is! Map || saved['repeat']['times'] != entry.value) {
        return false;
      }
    } else if (entry.key == 'schedule') {
      final value = saved['schedule'];
      if (value is! Map) return false;
      final rule = entry.value as String;
      final matches = switch (value['kind']) {
        'manual' => rule == 'manual',
        'cron' => value['expr'] == rule,
        'interval' => _intervalMinutes(rule) == value['minutes'],
        'once' =>
          DateTime.tryParse(rule) != null &&
              DateTime.tryParse(rule)!.toUtc() ==
                  DateTime.tryParse('${value['run_at']}')?.toUtc(),
        _ => false,
      };
      if (!matches) return false;
    } else if (entry.key == 'no_agent') {
      if ((saved[entry.key] == true) != entry.value) return false;
    } else if ((saved[entry.key] ?? '') != (entry.value ?? '')) {
      return false;
    }
  }
  return true;
}

/// The editor offers canonical expressions only; natural/relative phrases cannot
/// be compared reliably with a normalized read-back without duplicating parsing.
bool cronEditableSchedule(String rule) =>
    rule == 'manual' ||
    (_intervalMinutes(rule) ?? 0) > 0 ||
    RegExp(r'^[A-Za-z\d*\-,/]+(?:\s+[A-Za-z\d*\-,/]+){4,5}$').hasMatch(rule) ||
    (RegExp(r'^\d{4}-\d{2}-\d{2}T.*(?:Z|[+-]\d{2}:\d{2})$').hasMatch(rule) &&
        DateTime.tryParse(rule) != null);

num? _intervalMinutes(String rule) {
  final match = RegExp(
    r'^every\s+(\d+)\s*([mhd])$',
    caseSensitive: false,
  ).firstMatch(rule);
  if (match == null) return null;
  return num.parse(match[1]!) *
      switch (match[2]!.toLowerCase()) {
        'h' => 60,
        'd' => 1440,
        _ => 1,
      };
}
