# Implementer instructions (sub-project 2b)

Where this fits: sub-project 2b of jet-cad's kit architecture — the service mode of `packages/jet_cad_2d_plan` (units instead of tables, statuses, groups, the service copy and record, the service tool and view), plus the engine seam E5 (Tasks 1-2, done) and contract additions in `packages/jet_cad_2d_kit`.

Work from: `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2b` (branch `feat/plan-library-2b`). Run commands one at a time (no bash loops, no `$VAR` pipelines).

## Read first, in this order
1. Your task brief (path in your dispatch) — your requirements, with exact values to use verbatim.
2. Global constraints (bind every task): `.superpowers/sdd/2026-10-14-plan-library-2b/global-constraints.md`
3. File structure and shared interfaces (the names other tasks rely on): `.superpowers/sdd/2026-10-14-plan-library-2b/shared-interfaces.md`
4. `CLAUDE.md` at the worktree root. The spec is `docs/superpowers/specs/2026-10-14-plan-library-service-mode-design.md`; read the sections your brief cites when a step is unclear. Never read the whole plan file.

Earlier tasks are committed; their code is in the tree. Line numbers the brief cites in files earlier tasks touched may have shifted — find code by content. Where the brief and the committed code disagree on a name or signature, the committed code of an earlier task plus the shared interfaces win; report the mismatch in your report.

## Rules
- Ported tests keep their assertions (A12). A ported or existing test whose assertion must change is a finding: stop and report NEEDS_CONTEXT, unless your dispatch names a ruling that covers it.
- Today's code (`packages/jet_cad_floor_plan`) is the oracle; port by copying and adapting, never import it. Never change the old packages (A12).
- Compare test failures against `tool/ci/standing_failures.txt`; never fix standing failures; report anything new.
- Never commit `analysis_options.yaml`. Stage by explicit path only (never `git add -A`/`.`). Run `git status --short` after any pub operation.
- Run the Commit step before the Mutation step. Mutations only on committed files; revert each with `git checkout -- <file>` and confirm `git diff --quiet -- <file>` exits 0. Never `git checkout --` a file with uncommitted work.
- Never synthesize test output; quote what commands print.
- Commit messages in English, ending with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Never push, tag, merge, or run `dart pub publish` without `--dry-run`.
- Gates, for every package you touched (run `dart format .` first):
  - `cd packages/<pkg> && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` (engine: `dart test && dart analyze && …`);
  - `cd tool/ci && dart test` when `tool/ci` or `.github/` changed; `dart run tool/ci/check_kit_deps.dart` when a pubspec or `jet_cad_2d_kit` changed.

## Before you begin
If anything in the brief is unclear or contradicts the code, report NEEDS_CONTEXT with specifics rather than guess.

## Your job
Implement exactly what the brief specifies (TDD per its steps); focused tests while iterating; full gates once before committing; commit; run every named mutation; self-review your diff (completeness, names, YAGNI, tests that go red under their named mutation, non-degenerate fixtures, pristine output).

## You do not dispatch subagents
Do all of the work yourself. Never spawn a subagent, above all never a reviewer — review is the controller's job after you report.

## When you're in over your head
Stop and report BLOCKED or NEEDS_CONTEXT: what you're stuck on, what you tried, what help you need. Bad work is worse than no work.

## Report
Write the full report to the report path in your dispatch: what you implemented; files changed; tests and TDD evidence (RED: command + quoted failing output + why expected; GREEN: command + quoted passing output); gate commands with quoted output tails; each mutation (edit, test, quoted failing line, reverted, `git diff --quiet` exit 0); self-review findings; concerns.

Then reply with ONLY (under 15 lines): Status (DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT), commits (short SHA + subject), a one-line test summary, concerns, the report path. If BLOCKED or NEEDS_CONTEXT, put the specifics in the reply itself.

## Fix rounds
If resumed with review findings: fix them, re-run the tests covering the amended code, append a fix report (what changed, covering tests, commands, quoted output, mutations) to the same report file, and reply with the same short contract.

## Known trap: escapes in string literals
The file-writing tool has turned ` `-style escapes into literal characters (seen in Task 6: a ported test's NBSP became a space). After writing any file whose brief or oracle has `\u…`/`\x…` escapes or non-ASCII characters, compare those literals byte for byte against the brief/oracle (e.g. `grep -nP '[^\x00-\x7F]'` on your files) and restore escapes where the source writes them.
