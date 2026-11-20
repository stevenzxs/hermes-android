# Cron unified editor implementation plan

**Goal:** Remove duplicate schedule editing while preserving task lifecycle and model routing.

**Approved design:** One shared editor with Task content and Trigger & execution sections. Classic Edit and its trigger shortcut, and NextGen's editor use the same form. Open new round is a separate, confirmed action that copies saved settings, preserves history and creates a paused successor. Only changed fields are submitted; a schedule edit explicitly carries the existing/new execution limit so backend kind changes cannot silently replace it. Read-only schedule summaries never become editable source values. Saving does not trigger, enable, reset consumed counts, or open a round.

**Architecture:** A shared draft maps canonical schedule data to editable text and computes patches. A shared dialog uses the existing model picker, capability-gated manual switch and schedule/limit controls. Creation retains its existing full-payload form; dead editing/model arguments are removed from that create-only form. Exact per-job read-back verifies changed fields and normalized schedules. Existing profile-switch guards remain in place. No backend/API schema changes, build, release, install or production mutation.

**Tech stack:** Flutter/Dart; existing DashboardClient; Flutter widget and unit tests.

## Execution

1. Add regression tests in `test/cron_trigger_controls_test.dart` and `test/cron_model_selection_test.dart`: content-only changes omit schedule/repeat; no-op sends no writes; canonical once/interval/cron/manual fields; separate round action; trigger-only changes preserve counts and model pin. Run targeted tests and capture failures before implementation.
2. Implement `lib/core/widgets/cron_job_editor.dart` and draft helpers. Reuse `CronModelPicker`; provide keyed fields and shared tab selection. Preserve raw timezone-bearing run_at, interval minutes, cron expr. Capability failure blocks unsupported manual changes but not content edits. Show consumed/remaining/next-run/timezone summaries.
3. Replace duplicate edit form in `lib/core/screens/cron_screen.dart`, retain existing add behavior, use common patch verification. Refactor `cron_trigger_settings.dart` into the trigger-section shortcut and separate new-round confirmation; wire Classic/NextGen actions.
4. Run Cron model, operations, transport, schedule, prompt and navigation-related targeted regressions plus strict Flutter analysis. Review diff and sensitive content, inspect push automation, commit/push/merge main and verify remote SHA; delete this task branch. Record evidence and unrun full suite in central knowledgebase via its own task branch.

## Acceptance / scope

- One schedule input in the shared trigger section; content-only save never rewrites schedule, repeat or model route.
- No-op and Cancel make no mutation. Save failures or mismatched read-back never announce success.
- Explicit limits preserve consumed counters, including schedule kind changes and terminal tasks.
- New round is separate from editing and never consumes unsaved form state.
- GOV-01/02: existing baseline and independent delivery config unchanged. GOV-03/04/05: no build/deploy acceptance claim. Branch lifecycle and central ledger evidence required.

## Verification checkpoint (2026-11-20)

- Regression was red before implementation: a name-only edit submitted name/prompt/schedule/no_agent rather than only name. Additional red tests caught null timestamp equality, zero interval acceptance and malformed new-round success.
- Flutter 3.44.0: 14 Cron/transport/model/list/history/navigation test files, **135 passed**. Command: `flutter test --no-pub test/cron_job_draft_test.dart test/cron_unified_editor_test.dart test/cron_trigger_controls_test.dart test/cron_model_selection_test.dart test/cron_model_wire_test.dart test/cron_operations_test.dart test/cron_schedule_test.dart test/cron_trigger_transport_test.dart test/cron_task_prompt_test.dart test/crons_upcoming_history_test.dart test/cron_shell_listing_test.dart test/cron_upcoming_l10n_test.dart test/chats_crons_navigation_test.dart test/crons_archive_scopes_test.dart`.
- `flutter analyze --no-pub --fatal-infos`: no issues. Existing archive-scope test emits a missed-tap warning; assertions pass, warning is not suppressed or fixed in this task.
- Schedule edits accept canonical cron expressions, positive `every Nm/h/d`, explicit timezone-bearing ISO timestamps, or the capability-gated manual mode. Existing untouched legacy strings remain intact. Relative/natural phrases are not offered because exact normalized read-back cannot verify them without duplicating backend parsing.
- Full Windows suite not rerun; previously recorded unrelated failures remain open. No APK/image build, signing, release, deployment or device installation. No claim of cloud delivery/GOV closure or live-device visual acceptance.
