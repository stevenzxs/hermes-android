import 'package:flutter/material.dart';
import '../services/connection_manager.dart';
import 'cron_job_draft.dart';
import 'cron_job_editor.dart';

/// NextGen shortcut to the same editor used by Classic. No second settings form.
Future<bool> showCronTriggerSettings(
  BuildContext context,
  DashboardClient client,
  Map<String, dynamic> job, {
  bool focusTrigger = true,
  bool Function()? isCurrent,
}) async {
  final patch = await showCronJobEditor(
    context,
    client,
    job,
    focusTrigger: focusTrigger,
  );
  if (patch == null ||
      patch.isEmpty ||
      !context.mounted ||
      isCurrent?.call() == false) {
    return false;
  }
  final response = await client.updateJob(job['id'].toString(), patch);
  if (response['ok'] == false) {
    throw const FormatException('Cron update rejected');
  }
  if (!context.mounted || isCurrent?.call() == false) return false;
  final saved = await client.getCronJob(job['id'].toString());
  if (saved['id'] != job['id'] || !cronPatchMatches(saved, patch)) {
    throw const FormatException('Cron update read-back did not match');
  }
  return true;
}

/// Separate lifecycle action; only saved settings can be copied to a new round.
Future<bool> showCronNewRound(
  BuildContext context,
  DashboardClient client,
  Map<String, dynamic> job, {
  bool Function()? isCurrent,
}) async {
  if (!{'completed', 'error'}.contains(job['state'])) return false;
  if (!context.mounted || isCurrent?.call() == false) return false;
  final caps = await client.cronCapabilities();
  if (!context.mounted || isCurrent?.call() == false) return false;
  final zh = Localizations.localeOf(context).languageCode == 'zh';
  if (caps['new_round'] != true) {
    throw StateError(zh ? '服务端不支持开启新一轮' : 'Server does not support new rounds');
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(zh ? '开启新一轮？' : 'Open a new round?'),
      content: Text(
        zh
            ? '复制已保存的设置，保留原任务和历史，创建暂停的新任务。不会自动执行。'
            : 'Copy saved settings, keep the original and history, and create a paused successor. It will not run.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(zh ? '取消' : 'Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(zh ? '确认' : 'Confirm'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted || isCurrent?.call() == false) {
    return false;
  }
  final successor = await client.openCronRound(
    job['id'].toString(),
    client.cronRoundRequestId(job['id'].toString()),
  );
  final repeat = successor['repeat'];
  if (successor['ok'] == false ||
      successor['id'] is! String ||
      (successor['id'] as String).isEmpty ||
      successor['id'] == job['id'] ||
      successor['round_parent_id'] != job['id'] ||
      successor['state'] != 'paused' ||
      successor['enabled'] != false ||
      repeat is! Map ||
      repeat['completed'] != 0) {
    throw const FormatException(
      'New round response did not contain a paused successor',
    );
  }
  return true;
}
