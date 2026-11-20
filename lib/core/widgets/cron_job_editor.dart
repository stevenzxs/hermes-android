import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../services/connection_manager.dart';
import 'cron_job_draft.dart';
import 'cron_model_picker.dart';

/// Both edit entry points open this form; the shortcut expands the trigger area.
/// Returns a minimal patch. Transport stays with the caller's profile guard.
Future<Map<String, dynamic>?> showCronJobEditor(
  BuildContext context,
  DashboardClient client,
  Map<String, dynamic> job, {
  bool focusTrigger = false,
}) async {
  final route = DialogRoute<Map<String, dynamic>>(
    context: context,
    builder: (_) =>
        _CronJobEditor(client: client, job: job, focusTrigger: focusTrigger),
  );
  final result = await Navigator.of(context).push(route);
  await route.completed;
  return result;
}

class _CronJobEditor extends StatefulWidget {
  const _CronJobEditor({
    required this.client,
    required this.job,
    required this.focusTrigger,
  });
  final DashboardClient client;
  final Map<String, dynamic> job;
  final bool focusTrigger;
  @override
  State<_CronJobEditor> createState() => _CronJobEditorState();
}

class _CronJobEditorState extends State<_CronJobEditor> {
  late final name = TextEditingController(
    text: widget.job['name']?.toString() ?? '',
  );
  late final prompt = TextEditingController(
    text: widget.job['prompt']?.toString() ?? '',
  );
  late final schedule = TextEditingController(
    text: cronScheduleInput(widget.job),
  );
  late final limit = TextEditingController(
    text: cronExecutionLimit(widget.job)?.toString() ?? '',
  );
  late bool manual = schedule.text == 'manual';
  late bool noAgent = widget.job['no_agent'] == true;
  late String model = widget.job['model']?.toString() ?? '';
  late String provider = widget.job['provider']?.toString() ?? '';
  late String baseUrl = widget.job['base_url']?.toString() ?? '';
  bool manualSupported = false;
  String? error;
  String text(String cn, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? cn : en;

  @override
  void initState() {
    super.initState();
    _capabilities();
  }

  Future<void> _capabilities() async {
    try {
      final capabilities = await widget.client.cronCapabilities();
      if (mounted) {
        setState(
          () => manualSupported = capabilities['manual_schedule'] == true,
        );
      }
    } catch (_) {
      // Legacy servers can still edit task content and existing schedules.
    }
  }

  @override
  void dispose() {
    for (final controller in [name, prompt, schedule, limit]) {
      controller.dispose();
    }
    super.dispose();
  }

  void save() {
    final rule = manual ? 'manual' : schedule.text.trim();
    final n = cronExecutionLimit(widget.job);
    final originalRule = cronScheduleInput(widget.job);
    if ((name.text.trim().isEmpty && name.text != (widget.job['name'] ?? '')) ||
        (prompt.text.trim().isEmpty &&
            widget.job['script'] == null &&
            prompt.text != (widget.job['prompt'] ?? '')) ||
        (rule != originalRule &&
            (!cronEditableSchedule(rule) ||
                (rule == 'manual' && !manualSupported)))) {
      setState(
        () => error = text(
          '请输入有效任务内容和触发规则：Cron、every 2h 或带时区的 ISO 时间。',
          'Enter valid content and a cron, every 2h or ISO timestamp with timezone.',
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      cronJobPatch(
        widget.job,
        name: name.text == (widget.job['name'] ?? '')
            ? name.text
            : name.text.trim(),
        prompt: prompt.text == (widget.job['prompt'] ?? '')
            ? prompt.text
            : prompt.text.trim(),
        noAgent: noAgent,
        schedule: rule,
        limit: n,
        model: model,
        provider: provider,
        baseUrl: baseUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repeat = widget.job['repeat'];
    final consumed = repeat is Map ? repeat['completed'] as int? ?? 0 : 0;
    final maximum = cronExecutionLimit(widget.job);
    final remaining = maximum == null
        ? null
        : (maximum - consumed).clamp(0, maximum);
    return AlertDialog(
      title: Text(context.l10n.edit_cron_job),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExpansionTile(
                key: const ValueKey('cron-content-section'),
                initiallyExpanded: !widget.focusTrigger,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 12, bottom: 16),
                title: Text(text('任务内容', 'Task content')),
                children: [
                  TextField(
                    key: const ValueKey('cron-name'),
                    controller: name,
                    decoration: InputDecoration(labelText: context.l10n.name),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('cron-prompt'),
                    controller: prompt,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: context.l10n.prompt),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: noAgent,
                    title: Text(context.l10n.script_only_no_agent),
                    onChanged: (v) => setState(() => noAgent = v),
                  ),
                  const SizedBox(height: 16),
                  CronModelPicker(
                    client: widget.client,
                    model: model,
                    provider: provider,
                    baseUrl: baseUrl,
                    enabled: !noAgent,
                    onChanged: (m, p) => setState(() {
                      model = m;
                      provider = p;
                      baseUrl = '';
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ExpansionTile(
                key: const ValueKey('cron-trigger-section'),
                initiallyExpanded: widget.focusTrigger,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 12, bottom: 16),
                title: Text(text('触发设置', 'Trigger settings')),
                children: [
                  DropdownButtonFormField<bool>(
                    key: const ValueKey('cron-trigger-mode'),
                    initialValue: manual,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: text('触发方式', 'Trigger mode'),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: true,
                        child: Text(text('手动触发', 'Manual trigger')),
                      ),
                      DropdownMenuItem(
                        value: false,
                        child: Text(text('自动触发', 'Automatic trigger')),
                      ),
                    ],
                    onChanged: manualSupported
                        ? (v) => setState(() {
                            manual = v!;
                            if (!manual && schedule.text == 'manual') {
                              schedule.clear();
                            }
                          })
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    text(
                      manual ? '仅在主动触发时执行，没有调度计划时间。' : '按触发规则执行，启动计划不会额外执行一次。',
                      manual
                          ? 'Runs only on an explicit trigger; no scheduled time.'
                          : 'Runs at rule times; starting the plan does not add an immediate run.',
                    ),
                  ),
                  if (!manualSupported)
                    Text(
                      text(
                        '无法确认服务端支持切换仅手动模式',
                        'Manual mode changes unavailable: server capability not confirmed',
                      ),
                    ),
                  if (!manual) ...[
                    const SizedBox(height: 16),
                    TextField(
                      key: const ValueKey('cron-schedule'),
                      controller: schedule,
                      decoration: InputDecoration(
                        labelText: text('触发规则', 'Trigger rule'),
                        border: const OutlineInputBorder(),
                        hintText:
                            'every 1h / 0 9 * * * / 2026-12-01T09:00:00+08:00',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('cron-limit'),
                    controller: limit,
                    enabled: false,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: text('最多执行次数', 'Execution limit'),
                      helperText: maximum == null
                          ? text('不限次数', 'Unlimited')
                          : text(
                              '只读，保留已有上限',
                              'Read-only; existing limit preserved',
                            ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    text(
                      '已执行：$consumed；剩余：${remaining ?? '不限'}',
                      'Consumed: $consumed; remaining: ${remaining ?? 'unlimited'}',
                    ),
                  ),
                  if (!manual && widget.job['next_run_at'] != null)
                    Text(
                      text(
                        '下次执行：${widget.job['next_run_at']}',
                        'Next run: ${widget.job['next_run_at']}',
                      ),
                    ),
                  if (!manual)
                    Text(
                      text(
                        '时区：${widget.job['timezone'] ?? '服务端时区'}',
                        'Timezone: ${widget.job['timezone'] ?? 'server timezone'}',
                      ),
                    ),
                ],
              ),
              Text(
                text(
                  '保存不会立即执行、重置已执行次数或恢复已结束任务。',
                  'Saving never runs, resets consumed counts or reactivates an ended task.',
                ),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(onPressed: save, child: Text(context.l10n.save)),
      ],
    );
  }
}
