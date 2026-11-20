# Cron Trigger Controls Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deliver precise cron rejection reasons, editable scheduled/manual modes and execution limits, explicit new rounds, and duplicate-click protection without replaying production jobs.

**Architecture:** Extend the existing locked cron admission and Dashboard routes, keeping new behavior in small topical siblings. Share Android trigger coordination and error decoding across Classic/NextGen; gate new behavior on explicit backend capabilities. New rounds preserve the completed original and create an idempotent, initially disabled successor.

**Tech Stack:** Python cron store/provider, FastAPI Dashboard, Flutter/Dart, existing native test runners.

---

## Scope and prerequisites

- Approved design: `docs/plans/2026-11-20-cron-trigger-controls-design.md`.
- Android branch: `stevenzxs/cron-trigger-controls`, forked from clean `stevenzxs/independent-release`.
- Backend checkout: `../hermes-agent`, clean auxiliary-fix branch at initial inspection. Before edits create a separate cron feature branch preserving that fix; never switch to floating upstream main or discard work. Record exact SHAs before implementation.
- Read relevant backend AGENTS.md: root, cron, hermes_cli, web, tests; retain approved v0.23.1 baseline. Use @test-driven-development and @verification-before-completion.
- No production mutations, model calls, full builds, Actions dispatch, push or deployment are implied. Local focused tests do not satisfy Actions delivery acceptance.

### Task 1: Atomic admission refusal contract

**Files:**
- Create `../hermes-agent/cron/fire_admission.py`.
- Modify `../hermes-agent/cron/jobs.py` (claim seam), `cron/scheduler_provider.py`, `hermes_cli/web_routers/cron.py`, `hermes_cli/web_server_cron.py`.
- Create `../hermes-agent/tests/cron/test_fire_admission_reasons.py`.
- Extend `../hermes-agent/tests/hermes_cli/test_web_server_cron_profiles.py`.

1. Add failing behavior tests with temporary HERMES_HOME for completed/exhausted, paused, live claim, race loss, and unsupported provider. Assert state is unchanged on refusal and no execution is launched.
2. Run via backend native runner: `bash scripts/run_tests.sh tests/cron/test_fire_admission_reasons.py tests/hermes_cli/test_web_server_cron_profiles.py`; require expected red assertions, not import/environment failures. Provision only an isolated PM test environment per repo instructions if needed.
3. Introduce typed admission result at the locked claim boundary while preserving existing bool/dict consumers. Define stable reason codes; do not classify a later reread as atomic evidence. Map Dashboard responses to `{code, message, detail: message}` with existing status behavior; retain a generic claim-conflict fallback for legacy providers.
4. Re-run targeted tests; assert forced paused fire still works, completed fire remains refused, and profile ownership is preserved.
5. Review diff and commit only this task: `fix(cron): expose atomic trigger refusal reasons`.

### Task 2: Durable scheduled/manual mode

**Files:**
- Create `../hermes-agent/cron/trigger_policy.py`.
- Modify `../hermes-agent/cron/jobs.py`, `cron/job_definition.py`, `cron/scheduler_provider.py`, `cron/scheduler.py` only at existing policy seams.
- Modify `../hermes-agent/hermes_cli/web_routers/cron.py` request models/capabilities.
- Create `../hermes-agent/tests/cron/test_manual_trigger_policy.py`.
- Extend `../hermes-agent/tests/hermes_cli/test_web_server_cron_repeat.py`.

1. Write red tests: legacy defaults scheduled; manual has no due instant; tick and external scheduled fire refuse manual; explicit manual fire succeeds; mode edits preserve pause/terminal state and never dispatch.
2. Run `bash scripts/run_tests.sh tests/cron/test_manual_trigger_policy.py tests/hermes_cli/test_web_server_cron_repeat.py`.
3. Persist optional `trigger_mode`, validate enum and schedule requirements, include it in authored definitions and provider reconciliation. Explicitly distinguish authorized manual fire from timed callback. Keep old readers safe by leaving manual jobs without next_run_at; audit all existing due-repair/fill-next-run paths.
4. Add tests for finite 1/N budgets and manual off-tick semantics in `cron/extra_fire.py`; adopt one explicit per-round budget rule without silently changing legacy extra-fire behavior. Editing upper limit preserves consumed count; exhausted jobs cannot reactivate through PUT.
5. Re-run focused suites and existing timezone/extra-fire/claim concurrency tests; commit `feat(cron): support explicit manual trigger policy`.

### Task 3: Explicit idempotent new round

**Files:**
- Create `../hermes-agent/cron/job_rounds.py`.
- Modify `../hermes-agent/hermes_cli/web_routers/cron.py` for capability and `POST /api/cron/jobs/{id}/new-round`.
- Create `../hermes-agent/tests/cron/test_job_rounds.py`.
- Extend `../hermes-agent/tests/hermes_cli/test_web_server_cron_profiles.py`.

1. Red tests: completed original stays byte-equivalent, original history stays readable, successor has new ID and source-round association, copied authored fields, new budget, no inherited claim/output/runtime state, disabled state and no dispatch.
2. Add concurrent duplicate request-ID tests, ambiguous network replay, cross-profile isolation and stale original mutation rejection. Never persist request identity in a way that permits arbitrary cross-profile reuse.
3. Run `bash scripts/run_tests.sh tests/cron/test_job_rounds.py tests/hermes_cli/test_web_server_cron_profiles.py` and confirm red.
4. Implement under existing store transaction/locks with idempotency identity and validation. Copy authored fields via shared schema, not a raw entire record; do not call trigger/resume. Return authoritative successor plus original ID.
5. Green tests, diff review and commit `feat(cron): open explicit history-preserving job rounds`.

### Task 4: Shared Android transport and trigger coordinator

**Files:**
- Modify `lib/core/services/connection_manager.dart`, `lib/core/services/dashboard_api_client.dart`.
- Create `lib/core/services/cron_trigger_controller.dart` and `lib/core/models/cron_trigger_result.dart`.
- Create `test/cron_trigger_controller_test.dart`, `test/cron_trigger_transport_test.dart`.
- Extend `test/connection_manager_test.dart`.

1. Red mocked HTTP tests for structured code/message, legacy detail string/map, malformed body, HTML fallback, profile query, no automatic POST retry, explicit capability refusal, new-round idempotent identity.
2. Red controller tests: simultaneous same identity => one POST; different job unaffected; connection/profile switch discards stale UI result; timeout => unknown outcome and status reconciliation, not automatic trigger replay; known success survives failed list refresh.
3. Run `flutter test test/cron_trigger_controller_test.dart test/cron_trigger_transport_test.dart test/connection_manager_test.dart` and record expected failures.
4. Implement a connection/profile/job-keyed coordinator shared by surfaces, typed safe exception decoding, cron-local long-operation timeout and independently bounded reconciliation. Keep unrelated API timeouts unchanged; preserve 401 auth behavior without retrying ambiguous accepted operations.
5. Green tests, formatter/diff check and commit `fix(android): preserve cron errors and coalesce trigger requests`.

### Task 5: UI editing, explicit new rounds, both surfaces

**Files:**
- Modify `lib/core/screens/cron_screen.dart`, `lib/nextgen/ui/scheduled_page.dart`.
- Review `lib/core/widgets/crons_pane.dart`, `cron_upcoming_pane.dart` for entry-point routing.
- Create `lib/core/widgets/cron_trigger_settings.dart` and `lib/core/models/cron_trigger_settings.dart`.
- Modify `lib/core/utils/cron_schedule.dart` and localization source ARB files (regenerate outputs with `flutter gen-l10n`).
- Create `test/cron_trigger_controls_test.dart`; extend `test/cron_schedule_test.dart`, `test/crons_upcoming_history_test.dart`.

1. Red widget tests: trigger becomes busy immediately; double tap sends once; completed row explains refusal and offers new round; cancel confirmation sends nothing; new round does not trigger/resume; supported mode/limit controls load and save without losing model/script/timezone fields.
2. Test authoritative readback of mode, schedule and repeat.times, not just name/model; test 1/N validation, disabled legacy-backend controls, manual/no-next-run labels and retained original history navigation.
3. Run `flutter test test/cron_trigger_controls_test.dart test/cron_schedule_test.dart test/crons_upcoming_history_test.dart` and confirm red.
4. Wire shared coordinator into both surfaces, split trigger mode and execution budget controls, explicit new-round confirmation and separate enable/run actions. Localize known reasons, keep safe unknown server messages, and preserve mounted/current-client guards.
5. `flutter gen-l10n`, format only touched Dart files, repeat tests; commit `feat(android): edit cron trigger settings and open explicit rounds`.

### Task 6: Regression evidence and handoff

**Files:**
- Update this plan with actual evidence and residual gaps.
- Backend developer/user cron docs under `website/docs/`.
- Unique governance register `D:/knowledgebase/audits/project-register.md` only through its short-lived branch lifecycle, preserving concurrent edits.

1. Run all focused suites plus existing cron claim, extra-fire, repeat, profile, timezone tests through `scripts/run_tests.sh`; run Android focused cron and transport suites. Determine exact existing extra-fire suite filenames via glob before invoking; never invent successful results.
2. Test old record/new server and old-server/new-app fixtures. Verify scheduled normal behavior, manual tick refusal, no implicit task restart and retained original execution ledger.
3. Run backend native targeted checks and `git diff --check` in both repos. No full local product build without separate approval.
4. Document exact source SHAs, commands/results, red-to-green evidence, limitations, and no-production-mutation boundary. Keep GOV-03/04/05 and existing AUD gaps open pending real delivery evidence.
5. Review and commit task changes. Request separate authorization for push/cloud build/deployment; controlled Actions live in hermes-config, fixed source/config SHA and artifact digests mandatory. Do not run unreviewed upstream workflows.

## Execution choice

Plan is ready for task-by-task execution in this session, or a separate session using executing-plans. No subagents are needed unless the user selects delegated execution. This document is a plan, not implementation or passing-test evidence.
