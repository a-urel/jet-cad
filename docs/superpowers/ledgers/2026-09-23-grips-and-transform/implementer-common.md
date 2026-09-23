# Implementer — standing instructions (Plan 03)

Worktree: /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-03-grips-and-transform (branch plan-03/grips-and-transform). Work only here.

## Requirements
Your task brief (path in your dispatch) is your requirements, with the exact values, code and tests to use verbatim. The spec it argues from is docs/superpowers/specs/2026-09-23-grips-and-transform-design.md (read the decisions your brief cites). The plan's Rulings and Global Constraints are docs/superpowers/plans/2026-09-23-grips-and-transform.md lines 71–327 — read those, and nothing else of the plan.

If anything in the brief is unclear or contradicts the code you read, ask before starting (reply NEEDS_CONTEXT with the specific question). If the brief's code must change to compile or to pass, make the smallest change and record exactly what and why in your report.

## House rules (binding)
- `packages/jet_cad_2d` is pure Dart: no Flutter, no dart:ui.
- In `jet_cad_2d_flutter`, `unused_import` and `unused_element` are errors, test files included.
- `Tolerance` for geometric decisions, exact `==` for stored values; never compare `Transform2` with `==`. World is root space: never read or write the root's transform.
- `CI=true` prefix on every test command. Never synthesize test output: paste what the command printed (summary line + exit code).
- Never commit `analysis_options.yaml`: `git status --short` before every commit; if `pub get` rewrote one, `git checkout -- <that yaml path>` (yaml only). Never `git checkout --` a .dart file.
- Run `dart format <files you touched>` before the gate line.
- Every commit message ends with a `Co-Authored-By: Claude <your model> <noreply@anthropic.com>` trailer naming the model that actually wrote the commit (Ruling T2-a: attribution must be truthful; the plan's `grep -c "Opus 5.5"` check becomes `grep -c "Co-Authored-By: Claude"`). Write the message to a file and `git commit -F <file>`.
- Shell: the sandbox refuses compound shell commands that mention git. Run git as plain separate commands from the worktree root (`git status --short`, `git add <files>`, `git commit -F <file>`), never inside `cd … &&` chains or pipes. Test/analyze/format commands may use `cd <package> && …`.
- The render layer's `flutter test` exits 1 on exactly five standing `test/golden/text_ladder_golden_test.dart` failures; any other failure is yours.

## Your job
1. TDD as the brief prescribes: see each new test fail first (paste the RED output), then pass.
2. Run the focused tests while iterating; run the task's gate line(s) once before committing.
3. Commit. 4. Self-review your diff (completeness, names, YAGNI, tests that would go red under the named mutants the brief lists, pristine output). Fix what you find.
5. Do not dispatch subagents — never a helper, never a reviewer. Review is the controller's job.
6. If you are stuck, report BLOCKED or NEEDS_CONTEXT with specifics; bad work is worse than none.

## Report
Write the full report to the report path in your dispatch: what you implemented; tests and results; TDD evidence (RED command + failing output + why expected; GREEN command + passing output); the gate line output (summary lines, exit codes); files changed; self-review findings; concerns; every deviation from the brief's code with why.
Then reply with ONLY (under 15 lines): Status (DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT), commits (short SHA + subject), one-line test summary, concerns, the report path.

## If resumed with review findings
Fix them, re-run the tests covering the amended code, append a fix report (what changed, covering tests, command, output) to the same report file, commit, and reply with the same short contract.
