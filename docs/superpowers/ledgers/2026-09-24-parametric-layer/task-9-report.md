# Task 9 report — Plan 06 mutation sweep

## Tally

26 fired: 26 killed, 0 survived, M-06e N/A (no iteration exists to mutate,
spec D4 step 6 — recorded, not fired).

Full per-mutant detail (file, edit, test, exact failing-test output and
summary line) is in `docs/superpowers/notes/plan-06-mutation-log.md`.

## The one survivor, and what was done

M-06b' (drop the closure's own `..sort(_byValue)` in
`packages/jet_cad_2d/lib/src/parametric/regeneration.dart`'s `_closure`)
first fired against N6's original fixture and **survived**:
`dart test test/parametric/neighbourhood_test.dart` printed
`00:00 +14: All tests passed!`.

Root cause: N6's original geometry was the standard `atA`/`atB`
pierce-and-swallow pair (A gains one child, B only loses one). Since only
one side of the compound move ever needs a freshly reserved handle,
`_plan`'s shared `reserved` counter always lands on the same value
regardless of which object an unsorted closure visits first — the mutation
had nothing to disturb. This is exactly CLAUDE.md's "dominant failure mode":
a degenerate fixture, not a code defect. Per the task's rule, this required
fixing the *fixture*, never weakening an assertion and never touching
production code.

Fix (test-only, in `packages/jet_cad_2d/test/parametric/neighbourhood_test.dart`):
replaced N6's geometry with a genuine cross overlap — B (200 × 1600,
A-local x:[900,1100], y:[-300,1300]) passes fully through A (2000 × 1000)
top to bottom, so *both* objects gain two children each (4 → 6) and neither
swallows the other. With both seeds needing new handles inside the same
`_plan` call, an unsorted closure hands the first two reserved handles to
whichever object the compound touched first, so `hA` and `hB` trade owners
on a fixed handle value depending on `bFirst`. Confirmed green on clean
code first, then re-fired the identical mutation: KILLED (byte divergence
at handle 2005's owner). Both fires and the re-fire are logged in full.

## Anything surprising

- Two mutants (M-06f, M-06n) were killed by a thrown `GeneratedGeometryError`
  or a wrong call count rather than a value mismatch — both are still
  faithful kills of the named tests, just via an exception path instead of
  an `expect` mismatch.
- M-06s (the `_applying` reentrancy guard) turned a clean `StateError` into
  unbounded recursion terminating in a stack-overflow error under the
  mutant — G8's `throwsStateError` matcher correctly rejects that, so it
  still counts as killed, but the failure mode is more dramatic than a
  typical assertion diff.
- M-06g (app) is the one case where the controller's ruling mattered:
  BT3 (the exact-outline assertion) survives that mutant *by design* — a
  wrong `reach` only changes which boxes count as neighbours, and neither
  box in BT3's fixture needs a neighbour it would lose, so `generate`'s own
  clipping still produces the same 5/3 split. BT6 (the reach oracle) is the
  correct, and only, kill; confirmed both ways.
- No other survivor turned up. The whole-branch gate (engine, render layer,
  app) was re-run once at the end against the fully-restored tree and is
  green except the five `text_ladder_golden_test.dart` rungs, the documented
  standing exception.

## Files touched

- Created: `docs/superpowers/notes/plan-06-mutation-log.md` (this task's
  deliverable).
- Changed (kept, test-only): `packages/jet_cad_2d/test/parametric/neighbourhood_test.dart`
  (N6's fixture, for the M-06b' survivor).
- Every other file touched during the sweep (`regeneration.dart`,
  `parametric_system.dart`, `component.dart`, `commands.dart`, `undo.dart`,
  `apps/floor_planner/lib/parametric/box.dart`,
  `apps/floor_planner/lib/selection_panel.dart`,
  `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart`) was
  restored from its `cp` backup and diffed empty; none of them appear in
  `git status --short` at the end of this task.
- Mutation backups: `.superpowers/sdd/2026-09-24-parametric-layer/mutation-backups/`
  (git-ignored, one entry per mutant fired, plus the two extra backups for
  M-06b's re-fire).
