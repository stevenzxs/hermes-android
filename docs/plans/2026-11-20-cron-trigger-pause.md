# Cron Trigger Settings and Pause Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Simplify Cron editing and make pause an explicit gate on all new execution.

**Architecture:** Preserve canonical manual/automatic schedules and existing lifecycle/claim records. Android Classic and NextGen share editing and status semantics; the backend's locked fire admission rejects paused jobs even for explicit fires. An automatic dashboard trigger arms the existing schedule without an extra execution.

**Tech Stack:** Flutter/Dart, Python Cron store and FastAPI dashboard, widget and isolated Python contract tests.

## Approved design / scope

- Remove trigger-settings and new-round action entries (retain compatibility APIs).
- Shared editor: task content and Trigger settings; dropdown Manual trigger / Automatic trigger. Manual has no schedule time or rule; automatic shows rule and timezone. Add 16px field gaps / 24px section separation, scrolling on narrow windows.
- Execution limit is disabled/read-only, blank means unlimited. Preserve actual existing finite limits and consumed counts; editing never resets, runs, or resurrects a terminal job.
- Show Normal / Paused badge independently of execution status. Pause blocks all new claims, never cancels an already claimed run; its completion must not unpause the task.
- Explicit Resume restores normal only; automatic resumes to the next rule time without replaying paused slots. Manual waits for a user trigger. Normal automatic trigger does not execute immediately; normal manual trigger executes once.
- Keep model routing, minimal patches, profile guards, terminal limits, history, authentication and at-most-once claims.
- No config/workflow/release/governance changes, no packaging, deployment, device install or production mutations. Existing GOV and Windows failures remain separate.

## Task 1 — Backend admission and dashboard mode semantics

Files: hermes-agent `cron/jobs.py`, `hermes_cli/web_routers/cron.py`, new sibling if required; tests `tests/cron/test_pause_trigger_gate.py`, `tests/hermes_cli/test_cron_trigger_modes.py`.

1. Add parametrized manual/automatic tests: paused force/manual/ordinary claims fail, live claim survives pause and completion remains disabled; trigger rejects paused and auto trigger never calls execution; resume does not fire missed slots.
2. Run `scripts/run_tests.sh` with those files via existing PM test Python; record expected red assertions before implementation.
3. Update locked admission and dashboard routing without removing claims or resetting counters. Preserve external scheduler at-most-once and current profile scope.
4. Run focused new and existing claim, manual, refusal and lifecycle tests. Update old expectations only where the approved contract changed.

## Task 2 — Editor and read-only limits

Files: `lib/core/widgets/cron_job_editor.dart`, tests `test/cron_unified_editor_test.dart`, `test/cron_trigger_controls_test.dart`.

1. Add failing widget tests for dropdown, conditional rule, disabled limit, unchanged finite limit, small viewport overflow and content-only minimal save.
2. Run `flutter test --no-pub` on those tests; record red.
3. Replace manual switch with dropdown; use outlined, spaced inputs and sections; keep capabilities fail-closed and draft/read-back validation.
4. Re-run focused widget tests and draft/model regressions.

## Task 3 — Card states and action integration

Files: `lib/core/screens/cron_screen.dart`, `lib/nextgen/ui/scheduled_page.dart`, shared status widget/helper; tests `test/cron_pause_ui_test.dart` and related existing model/navigation tests.

1. Test paused trigger disabled/no writes, normal mode action routing, Normal / Paused badge independent of running, absence of removed actions and Chinese Resume label.
2. Implement shared mode-aware operation and visible labels, preserve connection guards and refresh authoritative results after mutations.
3. Run scoped Flutter tests; strict `flutter analyze --no-pub --fatal-infos`; `git diff --check` and finite secret-pattern review.

## Task 4 — Source closure and audit

Review diff and current remote automation before push. Commit/push both task branches, merge current origin/main with no force or bypass, verify remote SHAs and commit inclusion, delete only this task's merged branches. Update `D:/knowledgebase/audits/project-register.md` on its own short branch with actual verification and remaining gaps, merge and clean up. No cloud packaging is authorized by this task.

## Verification / stop conditions

Use `C:/Users/ZL/AppData/Local/Temp/opencode/flutter-3.44.0/bin/flutter.bat` for targeted tests/analyze; Python always uses `scripts/run_tests.sh` and isolated existing PM test interpreter. Stop on dirty/unrelated work, hook/toolchain blockage, three failed approaches, unexpected contract expansion, workflow publishing risk or required production changes. Local tests are not GOV-03/04/05 delivery evidence.

## Execution evidence — 2026-11-20

- Tasks 1–3 implemented on `feat/cron-trigger-pause` in both source repositories.
  Removed action shortcuts only; compatibility/new-round APIs and history remain.
  New-job limits are disabled and blank; existing finite limits remain unchanged.
- Running status is an additive, read-derived `execution_running` boolean (no
  backfill or stored schema migration). The server checks live fire/run claims
  with existing TTL/owner rules and the profile-scoped scheduler running set.
  A failed runtime probe does not itself prove running. Android treats this
  field as authoritative, including false; older servers fall back only to
  explicit `state=running`, never raw claim presence.
- Red/green evidence: stale claims initially rendered Running and backend
  readback lacked the field; old-gateway list responses leaked into the new
  connection; new-job read-only fields were absent. Tests reproduced these
  before their fixes. Final added probes also reproduced missing long-running
  status and legacy state overriding authoritative false before correction.
- Flutter 3.44.0: `flutter test --no-pub --reporter=expanded` on every top-level
  `test/*cron*.dart` file: **150 passed, 0 failed**. Local log:
  `C:/Users/ZL/AppData/Local/Temp/opencode/cron-pause-flutter-final.log`.
  Includes editor narrow-window/1.5x text, mode/limit/model/minimal-patch,
  Classic/NextGen action combinations, old-connection response isolation,
  navigation, history and transport regressions. Existing archive missed-tap
  warning remains visible and is not suppressed.
- `flutter analyze --no-pub --fatal-infos`: **No issues found**.
- Backend: `scripts/run_tests.sh` through the existing isolated
  `hermes-aux-test-env-20261119` interpreter, `-j 4`, **244 passed, 0 failed**:
  `tests/cron/{test_jobs,test_pause_trigger_gate,test_manual_trigger_policy,
  test_claim_job_for_fire,test_manual_run_extra_fire,test_misfire_catchup,
  test_fire_admission_reasons,test_atomic_paused_creation}.py` and
  `tests/hermes_cli/{test_cron_trigger_modes,test_cron_trigger_refusal,
  test_web_server_cron_profiles,test_cron_dashboard_off_loop,
  test_cron_round_routes,test_web_server_cron_repeat}.py`.
  Log: `C:/Users/ZL/AppData/Local/Temp/opencode/cron-pause-python-final.log`.
  Separate `test_cron_multiplex_liveness_and_pools.py`: **3 passed**.
- Fixed Ruff runner / `ruff.pre-commit.toml` on all ten changed Python files:
  **All checks passed** (existing preview-selection warnings remain).
- Remote main was fetched before closure; Android base remains `db09a1838cfd`,
  Agent base `6eba7f1859c6`. Main-push workflows inspected: Android release is
  tag/manual only; Agent docker/site/canary/stable publication remain disabled,
  desktop release is call/manual only. No manual upstream workflow dispatch.
- Scope remains source verification/merge/central audit only: no new revision,
  config change, APK/image build, signing, release, deployment, live-session
  loading or device installation. Existing Windows full-suite failures and
  GOV-03/04/05, persistence and rollback gaps are not closed by these checks.
  Actual remote SHA/merge and branch cleanup are recorded in the central audit.
