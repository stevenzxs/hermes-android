# Hermes Android fork governance

This repository (`stevenzxs/hermes-android`) follows knowledgebase delivery policy
**1.3**, including **开发任务分支闭环**. Before work, read:

- `D:/knowledgebase/README.md`
- `D:/knowledgebase/standards/project-delivery.md`
- This project's entries in `D:/knowledgebase/audits/project-register.md`

Outside this machine, use the same paths relative to the fixed knowledgebase:
https://github.com/stevenzxs/knowledgebase/tree/663f0e5c04e25ca2bad3081a83981d79274013f5
If it cannot be read, report the blocker rather than claiming compliance.

## Task lifecycle

1. Check worktree state and fetch latest `origin/main`; create a short-lived task
   branch before editing. Do not edit main directly or reuse unrelated old branches.
2. Edit, run applicable checks, review the diff and sensitive information, commit
   and push the task branch. Report unrun/failed checks honestly; do not bypass hooks.
3. Merge and push main using permitted review/local merge paths. Verify remote main
   SHA and inclusion of this task's commits; a branch push or PR alone is not closure.
4. Delete this task's merged local and remote branches without another user prompt.
   Return the main working tree to main and report its state. Preserve other work,
   occupied worktree files and directories; never force-push or delete unmerged work.
5. Record verification, merge and cleanup evidence in the central audit register.
   Explicit plan-only/branch-only instructions stop at that endpoint. Conflicts,
   failed gates, protection rules or permissions are blockers, not bypass authority.

Check main-push automation before pushing. This lifecycle does not authorize product
release, signing, deployment or device installation. Product delivery configuration
belongs in the independent `stevenzxs/hermes-config` repository. Policy files do not
prove CI enforcement, passing Flutter tests or loading by an existing agent session.
