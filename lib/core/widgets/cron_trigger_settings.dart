import 'package:flutter/material.dart';
import '../services/connection_manager.dart';

/// Shared by Classic and NextGen. Saving never enables or triggers a task.
Future<void> showCronTriggerSettings(
  BuildContext context,
  DashboardClient client,
  Map<String, dynamic> job,
) async {
  Map<String, dynamic> capabilities;
  try {
    capabilities = await client.cronCapabilities();
  } on DashboardHttpException catch (e) {
    if (e.statusCode != 404 && e.statusCode != 501) rethrow;
    capabilities = {};
  }
  if (!context.mounted) return;
  final zh = Localizations.localeOf(context).languageCode == 'zh';
  String text(String cn, String en) => zh ? cn : en;
  final schedule = job['schedule'];
  var manual = schedule is Map && schedule['kind'] == 'manual';
  final rule = TextEditingController(text: manual ? '' :
      schedule is Map ? (schedule['expr'] ?? schedule['run_at'] ??
          (schedule['minutes'] != null ? 'every ${schedule['minutes']}m' :
              job['schedule_display']) ?? '').toString() : schedule?.toString());
  final repeat = job['repeat'];
  final limit = TextEditingController(text: repeat is Map ?
      repeat['times']?.toString() ?? '' : '');
  final terminal = {'completed', 'error'}.contains(job['state']);
  var busy = false;
  String? error;
  final requestId = client.cronRoundRequestId(job['id'].toString());
  final route = DialogRoute<void>(context: context, builder: (ctx) =>
    StatefulBuilder(builder: (ctx, update) => PopScope(canPop: !busy, child: AlertDialog(
      title: Text(text('触发设置', 'Trigger settings')),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(contentPadding: EdgeInsets.zero,
            title: Text(text('仅手动触发', 'Manual triggers only')),
            value: manual,
            onChanged: busy || capabilities['manual_schedule'] != true ? null :
                (v) => update(() => manual = v)),
          if (capabilities['manual_schedule'] != true)
            Text(text('当前服务端不支持仅手动模式', 'Server does not support manual schedules')),
          if (!manual) TextField(controller: rule, enabled: !busy,
            decoration: InputDecoration(labelText: text('调度规则', 'Schedule'),
              hintText: 'every 1h / 0 9 * * * / 2026-12-01T09:00:00+08:00')),
          TextField(controller: limit, enabled: !busy,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: text('最多执行次数（留空不限）', 'Execution limit (blank: unlimited)'))),
          Text(text('已执行：${repeat is Map ? repeat['completed'] ?? 0 : 0}。保存不会立即执行，也不会恢复已完成的任务。',
              'Consumed: ${repeat is Map ? repeat['completed'] ?? 0 : 0}. Saving never runs or reactivates a completed task.')),
          if (error != null) Text(error!, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
        ])),
      actions: [
        TextButton(onPressed: busy ? null : () => Navigator.pop(ctx),
          child: Text(text('取消', 'Cancel'))),
        if (terminal && capabilities['new_round'] == true)
          TextButton(onPressed: busy ? null : () async {
            final confirmed = await showDialog<bool>(context: ctx, builder: (confirm) => AlertDialog(
              title: Text(text('开启新一轮？', 'Open a new round?')),
              content: Text(text('保留原任务和历史，创建暂停的新任务。不会自动执行。请先保存需要的设置。',
                  'Keep the original and history, create a paused successor. It will not run. Save desired settings first.')),
              actions: [TextButton(onPressed: () => Navigator.pop(confirm, false), child: Text(text('取消', 'Cancel'))),
                FilledButton(onPressed: () => Navigator.pop(confirm, true), child: Text(text('确认', 'Confirm')))]));
            if (confirmed != true || !ctx.mounted) return;
            update(() { busy = true; error = null; });
            try {
              await client.openCronRound(job['id'].toString(), requestId);
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) { if (ctx.mounted) update(() { busy = false; error = '$e'; }); }
          }, child: Text(text('开启新一轮', 'Open new round'))),
        FilledButton(onPressed: busy ? null : () async {
          final value = limit.text.trim();
          final n = int.tryParse(value);
          if ((!manual && rule.text.trim().isEmpty) ||
              (value.isNotEmpty && (n == null || n < 1))) {
            update(() => error = text('请填写有效规则和正整数次数', 'Enter a schedule and a positive limit'));
            return;
          }
          update(() { busy = true; error = null; });
          try {
            final saved = await client.updateJob(job['id'].toString(),
                {'schedule': manual ? 'manual' : rule.text.trim(), 'repeat': n});
            final actual = saved['job'] is Map ? saved['job'] as Map : saved;
            final actualSchedule = actual['schedule'];
            final actualRepeat = actual['repeat'];
            if (actualSchedule is! Map || actualRepeat is! Map ||
                (actualSchedule['kind'] == 'manual') != manual ||
                actualRepeat['times'] != n) {
              throw StateError(text('服务端未确认所保存的触发设置，请刷新核对。',
                  'Server did not confirm the requested settings. Refresh and verify.'));
            }
            if (ctx.mounted) Navigator.pop(ctx);
          } catch (e) { if (ctx.mounted) update(() { busy = false; error = '$e'; }); }
        }, child: Text(text('保存', 'Save'))),
      ],
    ))));
  await Navigator.of(context).push(route);
  await route.completed;
  rule.dispose();
  limit.dispose();
}
