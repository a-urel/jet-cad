# Implementer: standing instructions (Plan 05)

**Worktree:** /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/quizzical-jemison-7537de
(branch `plan-05/drawing-tools`). Work only here. Session Ruling P-1: the
plan's named worktree was replaced by this one.

## Requirements
- **Your brief is your requirements.** Its path is in your dispatch. It
  carries the exact values, code and tests to use verbatim.
- **The spec** is docs/superpowers/specs/2026-09-23-drawing-tools-design.md
  (revision 2). Read the decisions your brief cites.
- **From the plan,** read only docs/superpowers/plans/2026-09-23-drawing-tools.md
  lines 95–324: the Rulings, the Global Constraints and the Review Focus.
  Nothing else of the plan.
- **If anything is unclear,** or the brief contradicts the code you read,
  ask before starting: reply NEEDS_CONTEXT with the specific question.
- **If the brief's code must change** to compile or to pass, make the
  smallest change. Record exactly what changed and why in your report.

## House rules (binding)
- `packages/jet_cad_2d` is pure Dart: no Flutter, no `dart:ui`.
- In `jet_cad_2d_flutter` and the app, `unused_import` and
  `unused_element` are errors, test files included.
- Use `Tolerance` for geometric decisions and exact `==` for stored
  values. Never compare `Transform2` with `==`. Never read or write the
  root's transform.
- Prefix every test command with `CI=true`. Never synthesize test output:
  paste what the command printed, with the summary line and the exit code.
- Never commit `analysis_options.yaml`. Run `git status --short` before
  every commit. If `pub get` rewrote one, `git checkout -- <that yaml
  path>`, the yaml only. Never `git checkout --` a `.dart` file.
- Run `dart format <files you touched>` before the gate line.
- End every commit message with a `Co-Authored-By: Claude <your model>
  <noreply@anthropic.com>` trailer naming the model that actually wrote
  the commit. Write the message to a file and use `git commit -F <file>`.
- **Shell:** the sandbox may refuse compound shell commands that mention
  git.
  - Run git as plain separate commands from the worktree root:
    `git status --short`, `git add <files>`, `git commit -F <file>`.
  - Never run git inside `cd … &&` chains or pipes.
  - Test, analyze and format commands may use `cd <package> && …`.
- **The standing failures:** the render layer's `flutter test` exits 1 on
  exactly five `test/golden/text_ladder_golden_test.dart` failures. Any
  other failure is yours.
- **Branch-point counts,** at `7dac3b5`:
  - engine: 894;
  - render layer: 854 + 1 skip + the five goldens;
  - harness: 82;
  - app: 26.

## Your job
1. Do TDD as the brief prescribes. See each new test fail first and paste
   the RED output, then make it pass.
2. Run the focused tests while iterating. Run the task's gate lines once
   before committing.
3. Commit.
4. Self-review your diff for completeness, names, YAGNI, pristine output,
   and whether each test would go red under the named mutants the brief
   lists. Fix what you find.
5. Do not dispatch subagents: never a helper, never a reviewer.
6. If stuck, report BLOCKED or NEEDS_CONTEXT with specifics. Bad work is
   worse than none.

## Report
**Write the full report** to the report path in your dispatch. It covers:
- what you implemented, and the tests and their results;
- TDD evidence: the RED command, the failing output and why it was
  expected; the GREEN command and the passing output;
- the gate line output: summary lines and exit codes;
- the files changed and your self-review findings;
- your concerns, and every deviation from the brief's code with the
  reason.

**Then reply with ONLY this** (under 15 lines):
- Status: DONE, DONE_WITH_CONCERNS, BLOCKED or NEEDS_CONTEXT;
- commits (short SHA and subject);
- a one-line test summary;
- concerns;
- the report path.

## If resumed with review findings
Fix them. Re-run the tests covering the amended code. Append a fix report
to the same report file: what changed, the covering tests, the command and
its output. Commit, and reply with the same short contract.
