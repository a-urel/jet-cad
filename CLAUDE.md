# jet-cad — project instructions

Read [STATUS.md](STATUS.md) first. It carries where the project stands, what is
done, what is in flight and the exact resume point.

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

- **The frame path allocates nothing in steady state.** `packages/jet_cad_2d/test/invariants/query_allocation_test.dart` measures it.
- **Draw order is ascending handle value**, stable across undo, save, load and purge.
- **Geometric *decisions* use `Tolerance`; *stored value* comparisons are exact `==`.**
- **Never commit `analysis_options.yaml`** — `flutter pub get` rewrites three of them in this workspace.
- **Never synthesize test output.** Reviewers verify claims independently; a fabricated transcript invalidates the task.
- Code, comments and commit messages in English.

## Every task ends green

```sh
cd packages/jet_cad_2d       && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

## Testing bar

Defects in this codebase surface through **mutation testing and differential
testing**, not through reading. The dominant failure mode is the **degenerate
fixture** — a test that passes because every fixture sits at the identity
transform, the origin, or a default attribute. A new test is only worth landing
if a named mutation makes it go red.
