# jet-cad — project instructions

Read [STATUS.md](STATUS.md) first. It carries where the project stands, what is
done, what is in flight and the exact resume point. Then
[roadmap/00-README.md](roadmap/00-README.md): the product target (a parametric
floor planner) decomposed into sub-projects. A roadmap file is an input to
brainstorming, never something to implement from.

## Workflow

This repo is built with the **superpowers SDD workflow**: a design spec is
approved, an implementation plan is written from it, then the plan is executed
task-by-task with a fresh implementer and an independent reviewer per task.

- Specs (binding authority): `docs/superpowers/specs/`
- Plans (what the implementer follows): `docs/superpowers/plans/`
- Measurement and mutation notes (results of record): `docs/superpowers/notes/`
- Per-task ledger, briefs and reports, **while a plan is in flight**:
  `.superpowers/sdd/<plan-slug>/` (git-ignored, lives in the worktree)
- The same material for a **merged** plan: `docs/superpowers/ledgers/` —
  archived on merge, never appended to afterwards

**Read the current plan before touching code.** It carries the technologies,
the file structure, the global constraints and the exit gate for the work in
flight.

## Non-negotiables

- **The frame path allocates nothing per entity in steady state, and O(1) per flush.** `packages/jet_cad_2d/test/invariants/query_allocation_test.dart` and `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart` measure it.
- **Draw order is ascending handle value**, stable across undo, save, load and purge.
- **Geometric *decisions* use `Tolerance`; *stored value* comparisons are exact `==`.**
- **Never commit `analysis_options.yaml`** — `flutter pub get` rewrites three of them in this workspace.
- **Never synthesize test output.** Reviewers verify claims independently; a fabricated transcript invalidates the task.
- Code, comments and commit messages in English.

## Every task ends green

```sh
cd packages/jet_cad_2d       && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd packages/jet_cad_2d_gpu     && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

## Testing bar

Defects in this codebase surface through **mutation testing and differential
testing**, not through reading. The dominant failure mode is the **degenerate
fixture** — a test that passes because every fixture sits at the identity
transform, the origin, or a default attribute. A new test is only worth landing
if a named mutation makes it go red.

## Rules for every agent session

These bind every coding agent (OpenCode, Copilot, Claude and others), whatever
the prompt says.

- Work only in a worktree cut by hand from local `main`
  (`git worktree add .claude/worktrees/<slug> -b <branch> main`); never edit
  the main checkout.
- Never run `dart pub publish` or `flutter pub publish`; `--dry-run` is fine
  and must show 0 warnings. Never merge, push or tag: the human does.
- Before every commit run `git status --short` and unstage any
  `analysis_options.yaml`.
- Never weaken, skip or delete an assertion to make a test pass. A failing
  test you cannot fix honestly is reported, not hidden.
- Never claim a command ran unless it did; paste its real last lines.
- Small commits, one concern each. End each commit message with a
  `Co-Authored-By: <model name> <noreply@...>` line naming the model.
- Before finishing, in every package you touched: its tests, analyze and
  `dart format --output=none --set-exit-if-changed .`; then
  `cd tool/ci && dart test`. Known failures that are not yours are listed in
  `tool/ci/standing_failures.txt`.
- Finish with a clean tree and a report file (the path the task names, else
  `docs/superpowers/notes/<date>-<slug>-report.md`): the commits, every
  command with its real last lines, what you could not do, open questions.
