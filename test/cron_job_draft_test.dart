import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/widgets/cron_job_draft.dart';

Map<String, dynamic> patch(
  Map<String, dynamic> job, {
  String? schedule,
  int? limit = 3,
}) => cronJobPatch(
  job,
  name: '${job['name'] ?? ''}',
  prompt: '${job['prompt'] ?? ''}',
  noAgent: job['no_agent'] == true,
  schedule: schedule ?? cronScheduleInput(job),
  limit: limit,
  model: '',
  provider: '',
  baseUrl: '',
);

void main() {
  test(
    'canonical sources preserve once timezone, interval, cron and manual',
    () {
      for (final (schedule, input) in [
        (
          {'kind': 'once', 'run_at': '2026-12-01T09:00:00+08:00'},
          '2026-12-01T09:00:00+08:00',
        ),
        ({'kind': 'interval', 'minutes': 90}, 'every 90m'),
        ({'kind': 'cron', 'expr': '0 9 * * *'}, '0 9 * * *'),
        ({'kind': 'manual'}, 'manual'),
      ]) {
        final job = <String, dynamic>{
          'schedule': schedule,
          'schedule_display': 'not input',
          'repeat': {'times': 3, 'completed': 2},
        };
        expect(cronScheduleInput(job), input);
        expect(patch(job), isEmpty);
      }
    },
  );

  test(
    'kind changes explicitly retain limit without lifecycle or consumed writes',
    () {
      final job = <String, dynamic>{
        'schedule': {'kind': 'once', 'run_at': '2026-12-01T09:00:00Z'},
        'repeat': {'times': 1, 'completed': 1},
        'state': 'completed',
        'enabled': false,
      };
      expect(patch(job, schedule: 'every 1h', limit: 1), {
        'schedule': 'every 1h',
        'repeat': 1,
      });
      expect(patch(job, schedule: 'manual', limit: null), {
        'schedule': 'manual',
        'repeat': null,
      });
    },
  );

  test(
    'readback compares normalized schedules and rejects wrong or invalid values',
    () {
      expect(
        cronPatchMatches(
          {
            'schedule': {'kind': 'interval', 'minutes': 120},
          },
          {'schedule': 'every 2h'},
        ),
        isTrue,
      );
      expect(
        cronPatchMatches(
          {
            'schedule': {'kind': 'interval', 'minutes': 120},
          },
          {'schedule': '30m'},
        ),
        isFalse,
      );
      expect(
        cronPatchMatches(
          {
            'schedule': {'kind': 'once', 'run_at': '2026-12-01T01:00:00Z'},
          },
          {'schedule': '2026-12-01T09:00:00+08:00'},
        ),
        isTrue,
      );
      expect(
        cronPatchMatches(
          {
            'schedule': {'kind': 'once', 'run_at': 'bad'},
          },
          {'schedule': 'bad'},
        ),
        isFalse,
      );
      expect(
        cronPatchMatches(
          {
            'repeat': {'times': 5, 'completed': 2},
          },
          {'repeat': 5},
        ),
        isTrue,
      );
      expect(
        cronPatchMatches(
          {
            'repeat': {'times': 3},
          },
          {'repeat': 5},
        ),
        isFalse,
      );
    },
  );

  test('untouched whitespace content does not become a hidden edit', () {
    final job = <String, dynamic>{
      'name': ' name ',
      'prompt': ' prompt ',
      'schedule': {'kind': 'manual'},
      'repeat': {'times': 3},
    };
    expect(patch(job), isEmpty);
  });

  test('editable rules use verifiable canonical syntax', () {
    for (final rule in [
      'every 2h',
      '0 9 * * *',
      '2026-12-01T09:00:00+08:00',
      'manual',
    ]) {
      expect(cronEditableSchedule(rule), isTrue, reason: rule);
    }
    for (final rule in [
      '',
      'every monday 9am',
      'in 30m',
      '2026-12-01T09:00:00',
      'every 0m',
    ]) {
      expect(cronEditableSchedule(rule), isFalse, reason: rule);
    }
  });
}
