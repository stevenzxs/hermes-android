import 'package:flutter/material.dart';
import '../utils/cron_schedule.dart';

bool cronManual(Map<String, dynamic> job) {
  final schedule = job['schedule'];
  return schedule == 'manual' ||
      schedule is Map && schedule['kind'] == 'manual';
}

bool cronEnded(Map<String, dynamic> job) =>
    {'completed', 'error', 'deleted'}.contains(job['state']);

String cronText(BuildContext context, String zh, String en) =>
    Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

String cronStartLabel(BuildContext context, Map<String, dynamic> job) =>
    cronManual(job)
    ? cronText(context, '立即执行', 'Run now')
    : cronText(context, '启动计划', 'Start plan');

/// Admission status is separate from execution: pausing never stops a live run.
class CronJobStatus extends StatelessWidget {
  const CronJobStatus({super.key, required this.job});
  final Map<String, dynamic> job;

  @override
  Widget build(BuildContext context) {
    final paused = cronJobPaused(job);
    // Only the server knows claim TTLs and owner liveness. Raw claims can be stale.
    final running = job.containsKey('execution_running')
        ? job['execution_running'] == true
        : job['state'] == 'running';
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        Chip(
          avatar: Icon(
            paused ? Icons.pause_circle_outline : Icons.check_circle_outline,
            size: 18,
          ),
          label: Text(
            paused
                ? cronText(context, '暂停', 'Paused')
                : cronText(context, '正常', 'Normal'),
          ),
        ),
        if (running) Chip(label: Text(cronText(context, '正在运行', 'Running'))),
        if (cronEnded(job))
          Chip(label: Text(cronText(context, '已结束', 'Ended'))),
      ],
    );
  }
}
