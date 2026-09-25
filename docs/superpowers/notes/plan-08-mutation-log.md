# Plan 08 mutation log -- M-08a..z3, M-08snap, M-08sn, M-08pin and the tasks' extras

**Tally, after Task 16's first commit: 214 mutants fired, 207 killed, 0
survived, 7 equivalent (fired, and they survive as argued); 8 N/A (not
re-fired).** After Task 14 fix round 1 it stood at 213 fired, 206
killed; Task 16's first commit added `own-defaultMovable` (the Task 14
review's Minor 1), killed by the new `SG6`. Two controls were fired as well and survive, as the spec
says they must; they are not counted. The first run (commit `b1b4c98`)
stood at 204 killed, 1 survived, 8 equivalent; the fix round (below)
closed both findings, and three re-fires show it.

- **The spec's 37 named mutants:** 50 fires, one per site or form
  (Ruling 08-21), M-08a's structural fire on a scratch copy included.
  - M-08b at four sites (the wall's reader, the tools' writer, the slide
    grip's writer, and the Opening section's writer, which the grep
    found); M-08h at four (the symbol, the tool preview's symbol and its
    jambs, and the slide grip's preview jambs, found by the grep); M-08i
    at four (the render capture, the render `rotatable`, the app's
    composite, and `OpeningGrips.movable`, found by the grep); M-08sn at
    three (the geometry, the tool, the grip); M-08u at two (window, gap);
    M-08q2 in two forms; M-08pin once, against `OS2` and 07's two `WS7`
    tests, which share `_commit`.
  - **All 50 killed.** In the first run M-08i's fourth site,
    `OpeningGrips.movable`, was unreachable and survived (F2); after the
    fix round the composite delegates to it, and `SG2` kills it there.
  - Every killer the spec names went red, at every site.
- **The tasks' extras:** 155 fired (Tasks 1-13, implementers' and
  reviewers', from the ledger; 07's three band-joining mutants whose
  sites moved to `wall_bands.dart` in Task 9; the Task 14 review's
  `own-defaultMovable`, in Task 16), **all 155 killed.** In
  the first run the slide grip's copy of the aperture divisor
  (`t11-apertureDir-grip`) survived (F1); the fix round's new
  `SG1 (t11-apertureDir, the grip's site)` kills it.
- **Equivalents:** 9 fired against their files; **7 survive** as argued
  in their tasks. **Two do not, and are reclassified killed:**
  `rv7-invOrder` (the engine's `CS1`, `CS10`, `CS11`, `CS12` kill it;
  it is equivalent only at the app level, where the Task 7 review fired
  it) and `rv8-addForm` (Task 13's `EP8` and `EP9` pin the rewrite's
  exact form). Their red lines are in their entries.
- **N/A, not re-fired: 8.** Six reviewer mutants whose edits were never
  written down (Task 4 review `RV-2`, `RV-3`, `RV-6`, `RV-8`; Task 5
  review `RV5-clampedCut`; Task 9 review `rv9-toolNaive`), and two
  superseded ones (`X2-fillskip`, `X5-lowest`), whose rules no longer
  exist; their successors are fired. See "N/A".
- **No mutant the ledger records as killed goes green on this tree,**
  with one qualification: the Task 2 re-review's `non-fill-first` was
  never written down, and its first reconstruction survives `CS10`, the
  test that killed it then. `CS12` (Task 3) kills it; see its entry.

**Findings of the first run, and their dispositions** (controller
rulings; Task 14 fix round 1):

- **F1 -- a multi-site mutant survived at its second site.** The Task 10
  review's m2 made the tool divide the edge-snap aperture by
  `|toWorld · d|` and pinned it with `OT3 (t11-apertureDir)`. The slide
  grip computes the same divisor in `_Slide.place`
  (`opening_grips.dart`), and reverting it there to `scaleMagnitude`
  survived the whole app suite (232 tests). Only a non-uniformly scaled
  host tells the two apart, and only a file can make one. **Fixed by a
  fixture:** `SG1 (t11-apertureDir, the grip's site)` drags a door by the
  provider on a `scale(2, 0.5)` host along a rotated centreline, and the
  edge snap engages at 19.9 mm (world) from the window's edge and not at
  20.1 mm. The mutant at the grip's site is red (fix round 1 entry).
- **F2 -- a duplicated, unreachable rule.** `OpeningGrips.movable`
  repeated `ObjectGrips.movable`'s rule, but the composite never
  delegated to it and nothing else constructs an `OpeningGrips`;
  replacing it with `true` survived the whole app suite. **Fixed:**
  `ObjectGrips.movable` now asks the dispatched provider
  (`_of(d, group)?.movable(d, group) ?? true`), so the rule lives once,
  in `OpeningGrips.movable`. M-08i re-fired there and at the composite's
  new line: `SG2` red at both.
- **Two "equivalent" mutants are killed** on this tree (`rv7-invOrder`,
  `rv8-addForm`); see above. Not defects: the ledger's equivalence was
  judged on a narrower fixture set.

**Tree.** Everything was fired against `plan-08/openings` at `3d1713f`
(Task 13 minors on top of `645a969`). During the two batches the
worktree held one untracked throwaway file,
`apps/floor_planner/test/t14_control_test.dart` (the controls), and
nothing else; it was deleted afterwards. `git status --short` is empty
now, and was empty before and after M-08a's second run. Fix round 1's
three re-fires ran on `b1b4c98` with the round's two edits
(`object_grips.dart`, `opening_grips_test.dart`) staged, so each
restore's `git diff --quiet` compares against them.
**Line numbers in `opening_grips_test.dart` (Task 14 review Minor 2):**
nine first-run entries cite that file's lines as they were at `3d1713f`,
and fix round 1 inserted 45 lines at line 278, so at `de66cd2` each is
45 lower in the file: 308 → 353 (`M-08b-grip`, `M-08sn-grip`), 323 →
368 (`X11-gate`), 370 → 415 (`M-08i-rotatable`, `M-08i-composite`),
373 → 418 (`M-08i-capture`), 424 → 469 (`rv12-gripNoFit`), 452 → 497
and 505 → 550 (`t12-gripOld`), 549 → 594 (`rv11-fillMovable`); the
assertions and the values are unchanged (the review counted the first
five). Lines up to 276, and the fix round's own entries (320, 415), are
at `de66cd2` already; Task 16's `SG6` sits at the file's end and moves
none of them.

**Procedure, per mutant.** The driver is `t14-fire.py` in the session
scratchpad (`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/plan08/t14/`);
the mutants are defined in `t14-mutants.py` to `t14-mutants4.py`
beside it (`t14-mutants4.py` is fix round 1's). For each mutant it does the following, in order:

1. `cp` every file the mutant touches to `t14-<id>-<basename>`, and
   refuses to run if such a backup already exists.
2. Apply each edit. Each `old` string must occur exactly once, or
   nothing is written.
3. Print `diff <backup> <file>`. That diff is the edit, pasted below.
4. Run each command with `CI=true`: `dart test` for
   `packages/jet_cad_2d`, `flutter test` otherwise. A command names one
   test file and one test by `--plain-name`, or names whole files where
   the ledger does not say which test killed the mutant.
5. Save each run's whole output to `t14-<id>-run<n>.log`.
6. `cp` every backup back, then `diff` it against the file and run
   `git diff --quiet -- <file>`.

Every restore below printed `diff` exit 0 and `git diff --quiet` exit 0
(222 restores, none other). The red lines are copied from the run's
output by the driver: the failing test's `[E]` line, the matcher's
`Expected` / `Actual` / `Which` lines, the failing assertion's location,
and the run's last summary line, at most sixteen lines per command,
re-read from each run's saved log (`t14-tomd.py`). A line longer than
240 characters is cut, and says so; the full text is in the log.

**Baselines.** Each of the 115 distinct commands was first run on the
clean tree (with the control file in place), from `t14-baseline.txt`.
All 115 exited 0; every narrowed command matched exactly one test
(`+1: All tests passed!`), and every whole-file command passed whole.
Fix round 1's two commands were baselined the same way on the fixed
tree: `--plain-name 'SG1 (t11-apertureDir'` `00:00 +1: All tests
passed!` and `--plain-name 'SG2 (M-08i)'` `00:01 +1: All tests passed!`.
So each red below is the mutant's doing. The two whole-suite commands
added in the second batch (`dart test test` in the engine, `flutter test
test` in the app) were not baselined here; the app suite is the gate
line's (green at `3d1713f`, +230), and the engine suite's only red on
the clean tree is its two standing Linux failures (Ruling 08-20). For
example:

```
(cd packages/jet_cad_2d && CI=true dart test test/parametric/references_test.dart --plain-name 'RF2 ') exit 0 | 00:00 +1: All tests passed!
(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OG1 one cut') exit 0 | 00:00 +1: All tests passed!
(cd apps/floor_planner && CI=true flutter test test/t14_control_test.dart --plain-name 'Q3d1 control') exit 0 | 00:00 +1: All tests passed!
```

**How the edits were recovered.** The tasks' reports were not kept in
the ledger, only its one-line summaries, so each edit was taken, in this
order of preference, from:

- the scratchpad fragments the tasks left (`plan08/*.old` / `*.new`,
  `t12-e-*.py`, `rv12-o-*` / `rv12-n-*`, `rv11-e-*.py`, `t7/`, `rv7/`,
  `rv6-m/`), re-applied unchanged where they still match;
- the task's own driver log where it printed the diff (Task 9's
  `t9-final2-mutants.log`, Task 8's `rv8-mut.py`);
- the plan's one-line definition, or the spec's, written against the
  current code. These are marked "reconstructed" where the name leaves
  room: `RV5-orphanAlways`, `RV5-diagOwnCut` (Task 5 review), the four
  near-face variants and the three frame mutants of the Task 3 reviews,
  `RV5-overlapStored`,
  the Task 2 re-review's `non-fill-first`, and the Task 13 review's six.

**Rulings and choices that change where or how a mutant is fired:**

- **M-08p2** is the condition swapped alone, as the spec defines it
  ("rewritten when the end moves, kept when the start moves"). Task 8
  also replaced the rewrite by the identity; that second edit is not
  needed to kill it.
- **M-08e** is the right face carried across each gap, as the spike
  expressed it with regions: the start piece's and each middle piece's
  right corner at a cut's start move to that cut's end.
- **M-08s**'s grep: `placeCut` is the only clamp of a cut; the grip's and
  `storedCentreOf`'s clamps clamp a centre into a stretch that
  `stretchesOf` gives, so the one mutant site is `stretchesOf`'s span.
- **Task 12 and 13 renamed or rewrote** some Task 8-11 sites; those
  mutants are fired at their current sites (`t11-exactNull` against
  Task 12's no-change rule, X8's at `_keptPut`).
- **X13-order** builds bed 1 (one furniture region) before the walls;
  the plan's "the furniture" is one block of the same order.

**M-08a (structural, R3; Ruling 08-19).** See its section below.

---

## M-08a -- the opening stores its world centre (structural, on a scratch copy)

`OpeningParams.position` is swapped for a world centre `(x, y)`.
`generate`, the wall's cut and `diagnose` project it onto the host's
frame; the tools, the slide grip and the panel write it. The positional
constructor keeps its shape as construction sugar for the plan and the
tests: a NaN `y` means `x` is still a distance along the host, which
`placedOn` resolves to the world centre before it is stored (the fixture's
`addOpening` and the plan's `_Pen.opening` do so). What is stored, and
what everything reads, is the world centre.

- **scratch:** `S=<scratchpad>/plan08/t14/m08a; mkdir -p "$S" && git archive --format=tar HEAD | tar -x -C "$S"`
  at `3d1713f`, then `cd "$S/apps/floor_planner" && flutter pub get`.
- **edit:** `t14-m08a-edit.py` (scratchpad), nine files. `flutter analyze
  lib test/opening_object_test.dart test/support`: `No issues found!`.
  The other test files do not compile against the swap and are not run.
  The diff against the worktree (`t14-M-08a.diff`, 434 lines) is pasted
  at the end of this log.
- **command:** `cd "$S/apps/floor_planner" && CI=true flutter test test/opening_object_test.dart --plain-name 'OR1 (M-08r'` (exit 1, both runs; `t14-M-08a-OR1.log`, `t14-M-08a-OR1-run2.log`)

  ```
  00:00 +0 -1: OR1 (M-08r, M-08r2, M-08h) the host's group moved 75 m, its reach disjoint before and after: the door's leaf moves by exactly that vector, door and window stay on the oracle, three pieces tile; one undo step; undo and redo exact; drift() empty; then a rotate about a point off the wall keeps the symbols on the oracle [E]
    Expected: a value less than <0.000001>
      Actual: <950.0000000003943>
       Which: is not a value less than <0.000001>
    test/opening_object_test.dart 124:5                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **worktree:** `git status --short` before and after the second run:
  empty, empty.
- **result:** KILLED by `OR1`, line 124 (the hinge): the placement passes
  its oracles (line 105), and after the host's 75 m move the leaf is
  950 mm from where the move puts it. The door's world centre stayed
  behind; projected onto the moved host it no longer lands where the
  door was.

---

## The named mutants

### M-08d — the referent direction dropped from the closure

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-M-08d-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  173,174d172
  <     for (final s in seeds) ...?before.references[s],
  <     for (final s in seeds) ...?after.references[s],
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/references_test.dart --plain-name 'RF2 ')` (exit 1; log `t14-M-08d-run1.log`)

  ```
  00:00 +0 -1: RF2 editing a Pin regenerates its Post in the same undo step: the tick moves; undo and redo are exact [E]
    Expected: empty
      Actual: [1000]
    test/parametric/references_test.dart 155:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OR3 editing')` (exit 1; log `t14-M-08d-run2.log`)

  ```
  00:00 +0 -1: OR3 editing the door's position regenerates its wall in the same undo step: the pieces move by coordinates; undo and redo are exact [E]
    Expected: empty
      Actual: [1300]
    test/opening_cut_test.dart 38:3                     run
    test/opening_cut_test.dart 47:3                     doorWall
    test/opening_cut_test.dart 512:17                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

### M-08r — references dropped from the closure entirely (06's closure)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-M-08r-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  173,174d172
  <     for (final s in seeds) ...?before.references[s],
  <     for (final s in seeds) ...?after.references[s],
  178,179d175
  <     for (final x in core) ...?before.referrers[x],
  <     for (final x in core) ...?after.referrers[x],
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/references_test.dart --plain-name 'RF2 ')` (exit 1; log `t14-M-08r-run1.log`)

  ```
  00:00 +0 -1: RF2 editing a Pin regenerates its Post in the same undo step: the tick moves; undo and redo are exact [E]
    Expected: empty
      Actual: [1000]
    test/parametric/references_test.dart 155:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/references_test.dart --plain-name 'RF3 ')` (exit 1; log `t14-M-08r-run2.log`)

  ```
  00:00 +0 -1: RF3 moving a Post 60 m away regenerates its Pin: the line moves by exactly the move vector, in one undo step [E]
    Expected: empty
      Actual: [3000]
    test/parametric/references_test.dart 197:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_object_test.dart --plain-name 'OR1 (M-08r')` (exit 1; log `t14-M-08r-run3.log`)

  ```
  00:00 +0 -1: OR1 (M-08r, M-08r2, M-08h) the host's group moved 75 m, its reach disjoint before and after: the door's leaf moves by exactly that vector, door and window stay on the oracle, three pieces tile; one undo step; undo and redo exac [cut; the full line is in the log]
    Expected: empty
      Actual: [1300]
    test/opening_object_test.dart 39:3                  run
    test/opening_object_test.dart 80:3                  hostWithTwo
    test/opening_object_test.dart 101:17                main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OR3 editing')` (exit 1; log `t14-M-08r-run4.log`)

  ```
  00:00 +0 -1: OR3 editing the door's position regenerates its wall in the same undo step: the pieces move by coordinates; undo and redo are exact [E]
    Expected: empty
      Actual: [1300]
    test/opening_cut_test.dart 38:3                     run
    test/opening_cut_test.dart 47:3                     doorWall
    test/opening_cut_test.dart 512:17                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (4 of 4 commands red).

### M-08r2 — the referrer direction dropped

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-M-08r2-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  178,179d177
  <     for (final x in core) ...?before.referrers[x],
  <     for (final x in core) ...?after.referrers[x],
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/references_test.dart --plain-name 'RF3 ')` (exit 1; log `t14-M-08r2-run1.log`)

  ```
  00:00 +0 -1: RF3 moving a Post 60 m away regenerates its Pin: the line moves by exactly the move vector, in one undo step [E]
    Expected: empty
      Actual: [3000]
    test/parametric/references_test.dart 197:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_object_test.dart --plain-name 'OR1 (M-08r')` (exit 1; log `t14-M-08r2-run2.log`)

  ```
  00:00 +0 -1: OR1 (M-08r, M-08r2, M-08h) the host's group moved 75 m, its reach disjoint before and after: the door's leaf moves by exactly that vector, door and window stay on the oracle, three pieces tile; one undo step; undo and redo exac [cut; the full line is in the log]
    Expected: empty
      Actual: [4000, 4100]
    test/opening_object_test.dart 39:3                  run
    test/opening_object_test.dart 114:5                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_object_test.dart --plain-name 'OR4 (M-08t')` (exit 1; log `t14-M-08r2-run3.log`)

  ```
  00:00 +0 -1: OR4 (M-08t, M-08r2, X7-dirty) the two-hop shape: A 200 centre into a node, B 115 left out of it at 67°, a door in A stored at 2,700 and drawn clamped at A's mitre; swinging B's far end to 40° moves the door's leaf by more than  [cut; the full line is in the log]
    Expected: empty
      Actual: [4000]
    test/opening_object_test.dart 39:3                  run
    test/opening_object_test.dart 238:5                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (3 of 3 commands red).

### M-08t — referrers of the seeds only

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-M-08t-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  178,179c178,179
  <     for (final x in core) ...?before.referrers[x],
  <     for (final x in core) ...?after.referrers[x],
  ---
  >     for (final x in seeds) ...?before.referrers[x],
  >     for (final x in seeds) ...?after.referrers[x],
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/references_test.dart --plain-name 'RF4 ')` (exit 1; log `t14-M-08t-run1.log`)

  ```
  00:00 +0 -1: RF4 the two-hop shape: B, a neighbour of Post A, moves away; A's Pin regenerates and its copy of A's clipped edge grows [E]
    Expected: empty
      Actual: [3000]
    test/parametric/references_test.dart 217:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_object_test.dart --plain-name 'OR4 (M-08t')` (exit 1; log `t14-M-08t-run2.log`)

  ```
  00:00 +0 -1: OR4 (M-08t, M-08r2, X7-dirty) the two-hop shape: A 200 centre into a node, B 115 left out of it at 67°, a door in A stored at 2,700 and drawn clamped at A's mitre; swinging B's far end to 40° moves the door's leaf by more than  [cut; the full line is in the log]
    Expected: empty
      Actual: [4000]
    test/opening_object_test.dart 39:3                  run
    test/opening_object_test.dart 238:5                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

### M-08n — `referrers` built by a scan over every object per referent (O(n²))

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-M-08n-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  136,137c136,141
  <     for (final x in live) {
  <       (referrers[x] ??= []).add(h);
  ---
  >   }
  >   for (final x in {for (final l in references.values) ...l}) {
  >     for (final o in order) {
  >       if (objects[o]!.referencesOf(t, o).contains(x) && o != x) {
  >         (referrers[x] ??= []).add(o);
  >       }
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/reference_cost_test.dart --plain-name 'RC1 ')` (exit 1; log `t14-M-08n-run1.log`)

  ```
  00:00 +0 -1: RC1 a root line drawn among 300 Posts and 300 Pins makes exactly 2 × 600 references calls and no overlap test [E]
    Expected: <1200>
      Actual: <361200>
    test/parametric/reference_cost_test.dart 60:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08f — the cascade executed as a separate command after the edit (a post-edit listener)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-M-08f-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  553c553
  <   final r = _cascade(t, types, before, r0, edit.label);
  ---
  >   final r = r0;
  ```
- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t14-M-08f-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  8a9
  > import '../document/doc_change.dart';
  222a224,245
  >     // M-08f: the cascade as its own command, after the edit.
  >     document.changes.listen((c) {
  >       if (c is! CommandApplied) return;
  >       final s = _survey(document, _types);
  >       final doomed = [
  >         for (final h in s.objects.keys)
  >           if (s.objects[h]!.type.referencePolicy == ReferencePolicy.cascade &&
  >               (s.declared[h] ?? const <Handle>[])
  >                   .any((x) => !s.objects.containsKey(x)))
  >             h,
  >       ];
  >       if (doomed.isEmpty) return;
  >       document.commands.execute(CompoundCommand([
  >         for (final d in doomed) ...[
  >           for (final k in s.children[d] ?? const <Handle>[])
  >             if (document.entities.kindAt(document.entities.slotOf(k)!) !=
  >                 EntityKind.fill)
  >               RemoveEntityCommand(k),
  >           RemoveNodeCommand(d),
  >         ],
  >       ], label: 'Delete referrers'));
  >     });
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/cascade_test.dart --plain-name 'CS1 ')` (exit 1; log `t14-M-08f-run1.log`)

  ```
  00:00 +0 -1: CS1 deleting Post A with the select tool's compound cascades P1 and P2 in the same edit: one undo step; undo, redo, and undo then purge restore the state and every child handle [E]
    Expected: <5>
      Actual: <6>
    test/parametric/cascade_test.dart 226:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_object_test.dart --plain-name 'OR5 (M-08f')` (exit 1; log `t14-M-08f-run2.log`)

  ```
  00:00 +0 -1: OR5 (M-08f, M-08f0, M-08f2) deleting wall A, which carries a door and a window and is joined to C at 110°, with the select tool's compound: A, the door and the window go (nodes, components, children); C's end is square; one und [cut; the full line is in the log]
    Expected: <5>
      Actual: <6>
    test/opening_object_test.dart 296:5                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

### M-08f0 — no cascade

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-M-08f0-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  553c553
  <   final r = _cascade(t, types, before, r0, edit.label);
  ---
  >   final r = r0;
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/cascade_test.dart --plain-name 'CS1 ')` (exit 1; log `t14-M-08f0-run1.log`)

  ```
  00:00 +0 -1: CS1 deleting Post A with the select tool's compound cascades P1 and P2 in the same edit: one undo step; undo, redo, and undo then purge restore the state and every child handle [E]
    Expected: null
      Actual: GroupNode:<GroupNode(BB8, 0 children)>
    test/parametric/cascade_test.dart 110:3  expectGone
    test/parametric/cascade_test.dart 217:7  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_object_test.dart --plain-name 'OR5 (M-08f')` (exit 1; log `t14-M-08f0-run2.log`)

  ```
  00:00 +0 -1: OR5 (M-08f, M-08f0, M-08f2) deleting wall A, which carries a door and a window and is joined to C at 110°, with the select tool's compound: A, the door and the window go (nodes, components, children); C's end is square; one und [cut; the full line is in the log]
    Expected: null
      Actual: GroupNode:<GroupNode(FA0, 0 children)>
    test/opening_object_test.dart 288:7                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

### M-08f2 — the cascade's inverse not folded into `r`

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-M-08f2-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  419,420c419
  <     inverse: CompoundCommand([...inverses.reversed, r0.inverse],
  <         label: r0.inverse.label),
  ---
  >     inverse: r0.inverse,
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/cascade_test.dart --plain-name 'CS1 ')` (exit 1; log `t14-M-08f2-run1.log`)

  ```
  00:00 +0 -1: CS1 deleting Post A with the select tool's compound cascades P1 and P2 in the same edit: one undo step; undo, redo, and undo then purge restore the state and every child handle [E]
    Expected: '{"schemaVersion":6,"header":{"units":"unitless","scale":1.0,"globalLinetypeScale":1.0,"importedExtents":null,"customVariables":{}},"tables":{"layers":[{"handle":1,"name":"0","color":7,"linetype":4,"lineweight":-3,"transparency" [cut; the full line is in the log]
      Actual: '{"schemaVersion":6,"header":{"units":"unitless","scale":1.0,"globalLinetypeScale":1.0,"importedExtents":null,"customVariables":{}},"tables":{"layers":[{"handle":1,"name":"0","color":7,"linetype":4,"lineweight":-3,"transparency" [cut; the full line is in the log]
       Which: is different.
              Expected: ... [1000,2000,3000,3100 ...
                Actual: ... [1000,2000],"exportA ...
    test/parametric/cascade_test.dart 230:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/cascade_test.dart --plain-name 'CS5 ')` (exit 1; log `t14-M-08f2-run2.log`)

  ```
  00:00 +0 -1: CS5 a neighbour whose generate throws after the cascade: the delete is refused, and the bytes, the Pins' children, the undo depth and doc.changes are unchanged [E]
    Expected: '{"schemaVersion":6,"header":{"units":"unitless","scale":1.0,"globalLinetypeScale":1.0,"importedExtents":null,"customVariables":{}},"tables":{"layers":[{"handle":1,"name":"0","color":7,"linetype":4,"lineweight":-3,"transparency" [cut; the full line is in the log]
      Actual: '{"schemaVersion":6,"header":{"units":"unitless","scale":1.0,"globalLinetypeScale":1.0,"importedExtents":null,"customVariables":{}},"tables":{"layers":[{"handle":1,"name":"0","color":7,"linetype":4,"lineweight":-3,"transparency" [cut; the full line is in the log]
       Which: is different.
              Expected: ... [1000,2000,3000,3100 ...
                Actual: ... [1000,2000],"exportA ...
    test/parametric/cascade_test.dart 374:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_object_test.dart --plain-name 'OR5 (M-08f')` (exit 1; log `t14-M-08f2-run3.log`)

  ```
  00:00 +0 -1: OR5 (M-08f, M-08f0, M-08f2) deleting wall A, which carries a door and a window and is joined to C at 110°, with the select tool's compound: A, the door and the window go (nodes, components, children); C's end is square; one und [cut; the full line is in the log]
    Expected: '{"schemaVersion":6,"header":{"units":"unitless","scale":1.0,"globalLinetypeScale":1.0,"importedExtents":null,"customVariables":{}},"tables":{"layers":[{"handle":1,"name":"0","color":7,"linetype":4,"lineweight":-3,"transparency" [cut; the full line is in the log]
      Actual: '{"schemaVersion":6,"header":{"units":"unitless","scale":1.0,"globalLinetypeScale":1.0,"importedExtents":null,"customVariables":{}},"tables":{"layers":[{"handle":1,"name":"0","color":7,"linetype":4,"lineweight":-3,"transparency" [cut; the full line is in the log]
       Which: is different.
              Expected: ... [1300,2700,4000,4100 ...
                Actual: ... [1300,2700],"exportA ...
    test/opening_object_test.dart 301:5                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (3 of 3 commands red).

### M-08v — the policy ignored: every referrer cascades

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-M-08v-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  389,391c389
  <               if (before.objects[d]!.type.referencePolicy ==
  <                       ReferencePolicy.cascade &&
  <                   _isObject(t, types, d))
  ---
  >               if (_isObject(t, types, d))
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/cascade_test.dart --plain-name 'CS3 ')` (exit 1; log `t14-M-08v-run1.log`)

  ```
  00:00 +0 -1: CS3 an orphan-policy Tag on A is kept when A goes, regenerates to its marker in the same edit, and is reported parametric.orphan once [E]
    Expected: <Instance of 'GroupNode'>
      Actual: <null>
       Which: is not an instance of 'GroupNode'
    test/parametric/cascade_test.dart 288:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08l — the dangling-reference refusal removed

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-M-08l-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  581d580
  <     _checkDangling(seeds, after);
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/cascade_test.dart --plain-name 'DR1 ')` (exit 1; log `t14-M-08l-run1.log`)

  ```
  00:00 +0 -1: DR1 an edit naming a root LINE, a plain group or a deleted object as a Pin's host is refused, and nothing changes; the same edit on a Tag is accepted and reported parametric.orphan [E]
    Expected: throws <Instance of 'DanglingReferenceError'> with `object`: <3000> and `referent`: <3302>
      Actual: <Closure: () => void>
       Which: returned <null>
    test/parametric/cascade_test.dart 456:7  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08y — `parametric.dangling` not reported

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t14-M-08y-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  313c313
  <         if (!s.objects.containsKey(x))
  ---
  >         if (!cascade && !s.objects.containsKey(x))
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/cascade_test.dart --plain-name 'DR2 ')` (exit 1; log `t14-M-08y-run1.log`)

  ```
  00:00 +0 -1: DR2 a file whose P1 names a missing host loads unchanged; diagnostics() reports parametric.dangling; drift() names P1; an unrelated edit is not refused [E]
    Expected: an object with length of <1>
      Actual: []
       Which: has length of <0>
    test/parametric/cascade_test.dart 512:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08b-wall — position from the wrong end (`L − p`), site 1: the wall's reader (`_hostCuts`, shared by the wall's pieces and each opening's symbol and diagnostics)

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-M-08b-wall-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  588c588
  <     for (final (_, o) in openings) (o.position, o.width),
  ---
  >     for (final (_, o) in openings) (layout.frame.len - o.position, o.width),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OG1 one cut')` (exit 1; log `t14-M-08b-wall-run1.log`)

  ```
  00:00 +0 -1: OG1 one cut, both faces, by coordinates: a door at 1,400 in a 5,000 wall at 23° gives two pieces whose gap corners are the oracle's; a window at 3,600 gives three; a gap clamped against the free start cap drops the start piece; [cut; the full line is in the log]
    Expected: true
      Actual: <false>
    test/opening_cut_test.dart 112:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OG2 the 67')` (exit 1; log `t14-M-08b-wall-run2.log`)

  ```
  00:00 +0 -1: OG2 the 67° L (A 200, B 115), all nine justification pairs: two openings in A, one stored past the node and clamped at the mitre, one in B: 0 tiling violations, every piece triangulates and is simple and anticlockwise, three pi [cut; the full line is in the log]
    Expected: an object with length of <3>
      Actual: [
       Which: has length of <2>
    test/opening_cut_test.dart 208:9                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_object_test.dart --plain-name 'OR1 (M-08r')` (exit 1; log `t14-M-08b-wall-run3.log`)

  ```
  00:00 +0 -1: OR1 (M-08r, M-08r2, M-08h) the host's group moved 75 m, its reach disjoint before and after: the door's leaf moves by exactly that vector, door and window stay on the oracle, three pieces tile; one undo step; undo and redo exac [cut; the full line is in the log]
    Expected: a value less than <0.000001>
      Actual: <2199.9999999989127>
       Which: is not a value less than <0.000001>
    test/opening_object_test.dart 64:7                  expectOnOracles
    test/opening_object_test.dart 105:5                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OG9 the random')` (exit 1; log `t14-M-08b-wall-run4.log`)

  ```
  00:11 +0 -1: OG9 the random property run: 2–4-way nodes, a T stem and an X crossing wall, 0–3 openings per wall, every wall in its own rotated group at the far origin: 0 refused, 0 tiling violations, drift() empty, every stored piece triang [cut; the full line is in the log]
    Expected: <0>
      Actual: <1634353>
    test/opening_cut_test.dart 495:5                    main.<fn>
  00:11 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (4 of 4 commands red).

### M-08b-tool — position from the wrong end, site 2: the tools' writer

- **file:** `apps/floor_planner/lib/parametric/opening_tool.dart`; backup `t14-M-08b-tool-opening_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  337c337
  <         : f.uOf(toLocal.transformPoint(resolved));
  ---
  >         : f.len - f.uOf(toLocal.transformPoint(resolved));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT1 (M-08b, X9-raw')` (exit 1; log `t14-M-08b-tool-run1.log`)

  ```
  Expected: a numeric value within <0.000001> of <1297.190536458946>
    Actual: <3702.809463542237>
     Which:  differs by <2405.618927083291>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_tool_test.dart:271:5)
  00:02 +0 -1: OT1 (M-08b, X9-raw, X9-unclamped) D, N and G each place one opening with one click and one undo step, centred at the resolved click projected onto the host, at the tool's width; a click near a mitre stores the clamped centre an [cut; the full line is in the log]
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08b-grip — position from the wrong end, site 3: the slide grip's writer

- **file:** `apps/floor_planner/lib/parametric/opening_grips.dart`; backup `t14-M-08b-grip-opening_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  77c77
  <         group, p.copyWith(position: placed.centre));
  ---
  >         group, p.copyWith(position: s.layout.frame.len - placed.centre));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart --plain-name 'SG1 (X11-stored')` (exit 1; log `t14-M-08b-grip-run1.log`)

  ```
  00:00 +0 -1: SG1 (X11-stored, M-08sn, M-08b, rv11-selfCand) the provider: a clamped door's grip sits at its cut's centre, a no-fit's at its stored centre; a drag projects, edge-snaps to an obstacle edge, and stores the placed centre, the cl [cut; the full line is in the log]
    Expected: a numeric value within <1e-9> of <2017.6326980715676>
      Actual: <4882.36730192916>
       Which:  differs by <2864.7346038575924>
    test/opening_grips_test.dart 221:5                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart --plain-name 'SG1 (shell)')` (exit 1; log `t14-M-08b-grip-run2.log`)

  ```
  Expected: a numeric value within <0.000001> of <2017.6326980706485>
    Actual: <4882.36730192916>
     Which:  differs by <2864.7346038585115>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_grips_test.dart:308:5)
  00:02 +0 -1: SG1 (shell) the slide grip is shown at the drawn centre; a drag edge-snaps while object snap is on and is one undo step; with F3 off it stores the grid point projected; under runtime permissions the grip is not hit [E]
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

### M-08b-panel — position from the wrong end, site 4 (found by the grep): the Opening section's Position writer

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t14-M-08b-panel-selection_panel.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  349c349,353
  <             : p.copyWith(position: value);
  ---
  >             : p.copyWith(
  >                 position: (doc.components.get<WallParams>(p.host)!.end -
  >                             doc.components.get<WallParams>(p.host)!.start)
  >                         .length -
  >                     value);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_panel_test.dart --plain-name 'OS1 the section shows')` (exit 1; log `t14-M-08b-panel-run1.log`)

  ```
  Expected: <2>
    Actual: <3>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_panel_test.dart:224:5)
  00:02 +0 -1: OS1 the section shows for one opening and hides for none, two, a wall and a box; width and position commit one step each; invalid values revert; the flips are a door's, one step each, and take the focus as the justification tog [cut; the full line is in the log]
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08c — the cut at the centre with zero width

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-M-08c-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  235c235
  <   return (a: x, b: x + w, clamped: x != want);
  ---
  >   return (a: c, b: c, clamped: x != want);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OG1 one cut')` (exit 1; log `t14-M-08c-run1.log`)

  ```
  00:00 +0 -1: OG1 one cut, both faces, by coordinates: a door at 1,400 in a 5,000 wall at 23° gives two pieces whose gap corners are the oracle's; a window at 3,600 gives three; a gap clamped against the free start cap drops the start piece; [cut; the full line is in the log]
    Expected: true
      Actual: <false>
    test/opening_cut_test.dart 112:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OG2 the 67')` (exit 1; log `t14-M-08c-run2.log`)

  ```
  00:00 +0 -1: OG2 the 67° L (A 200, B 115), all nine justification pairs: two openings in A, one stored past the node and clamped at the mitre, one in B: 0 tiling violations, every piece triangulates and is simple and anticlockwise, three pi [cut; the full line is in the log]
    test/opening_cut_test.dart 37:16                                 run
    test/opening_cut_test.dart 79:3                                  lPlan
    test/opening_cut_test.dart 191:21                                main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OG9 the random')` (exit 1; log `t14-M-08c-run3.log`)

  ```
  00:13 +0 -1: OG9 the random property run: 2–4-way nodes, a T stem and an X crossing wall, 0–3 openings per wall, every wall in its own rotated group at the far origin: 0 refused, 0 tiling violations, drift() empty, every stored piece triang [cut; the full line is in the log]
    Expected: <0>
      Actual: <61>
    test/opening_cut_test.dart 494:5                    main.<fn>
  00:13 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (3 of 3 commands red).

### M-08e — only one face cut: the right face carried across each gap

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-M-08e-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  403c403
  <     if (!on(f.startCap.last, a0)) f.right(a0),
  ---
  >     if (!on(f.startCap.last, a0)) f.right(merged.first.$2),
  409c409
  <     add([f.right(a), f.left(a), f.left(b), f.right(b)], a - b, f.at(b, 0),
  ---
  >     add([f.right(merged[i + 1].$2), f.left(a), f.left(b), f.right(b)], a - b, f.at(b, 0),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OG1 one cut')` (exit 1; log `t14-M-08e-run1.log`)

  ```
  00:00 +0 -1: OG1 one cut, both faces, by coordinates: a door at 1,400 in a 5,000 wall at 23° gives two pieces whose gap corners are the oracle's; a window at 3,600 gives three; a gap clamped against the free start cap drops the start piece; [cut; the full line is in the log]
    Expected: true
      Actual: <false>
    test/opening_cut_test.dart 112:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OG2 the 67')` (exit 1; log `t14-M-08e-run2.log`)

  ```
  00:00 +0 -1: OG2 the 67° L (A 200, B 115), all nine justification pairs: two openings in A, one stored past the node and clamped at the mitre, one in B: 0 tiling violations, every piece triangulates and is simple and anticlockwise, three pi [cut; the full line is in the log]
    Expected: true
      Actual: <false>
    test/opening_cut_test.dart 214:9                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OG9 the random')` (exit 1; log `t14-M-08e-run3.log`)

  ```
  00:11 +0 -1: OG9 the random property run: 2–4-way nodes, a T stem and an X crossing wall, 0–3 openings per wall, every wall in its own rotated group at the far origin: 0 refused, 0 tiling violations, drift() empty, every stored piece triang [cut; the full line is in the log]
    Expected: <0>
      Actual: <833452>
    test/opening_cut_test.dart 495:5                    main.<fn>
  00:11 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (3 of 3 commands red).

### M-08s — clamp into `[0, L]`, not the straight span (the stretches start from 0 and end at `len`)

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-M-08s-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  189c189
  <   var from = frame.uS;
  ---
  >   var from = 0.0;
  191,192c191,192
  <     if (!(from < frame.uE)) break;
  <     if (o.a > from) add(from, o.a < frame.uE ? o.a : frame.uE);
  ---
  >     if (!(from < frame.len)) break;
  >     if (o.a > from) add(from, o.a < frame.len ? o.a : frame.len);
  195c195
  <   if (from < frame.uE) add(from, frame.uE);
  ---
  >   if (from < frame.len) add(from, frame.len);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OG2 the 67')` (exit 1; log `t14-M-08s-run1.log`)

  ```
  00:00 +0 -1: OG2 the 67° L (A 200, B 115), all nine justification pairs: two openings in A, one stored past the node and clamped at the mitre, one in B: 0 tiling violations, every piece triangulates and is simple and anticlockwise, three pi [cut; the full line is in the log]
    Expected: an object with length of <3>
      Actual: [
       Which: has length of <2>
    test/opening_cut_test.dart 208:9                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OG9 the random')` (exit 1; log `t14-M-08s-run2.log`)

  ```
  00:11 +0 -1: OG9 the random property run: 2–4-way nodes, a T stem and an X crossing wall, 0–3 openings per wall, every wall in its own rotated group at the far origin: 0 refused, 0 tiling violations, drift() empty, every stored piece triang [cut; the full line is in the log]
    Expected: <0>
      Actual: <136>
    test/opening_cut_test.dart 494:5                    main.<fn>
  00:11 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

### M-08snap — the cap-vertex snap removed

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-M-08snap-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  398c398
  <       (f.uOf(capVertex) - u).abs() <= wallJoin.linear;
  ---
  >       false;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OG9 the random')` (exit 1; log `t14-M-08snap-run1.log`)

  ```
  00:11 +0 -1: OG9 the random property run: 2–4-way nodes, a T stem and an X crossing wall, 0–3 openings per wall, every wall in its own rotated group at the far origin: 0 refused, 0 tiling violations, drift() empty, every stored piece triang [cut; the full line is in the log]
    Expected: <0>
      Actual: <72>
    test/opening_cut_test.dart 494:5                    main.<fn>
  00:11 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08k — the centreline not split (one centreline across the gaps)

- **file:** `apps/floor_planner/lib/parametric/wall.dart`; backup `t14-M-08k-wall.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  221c221,223
  <       for (final line in centrelinePieces(frame, cuts.merged))
  ---
  >       for (final line in [
  >         [frame.s, frame.e]
  >       ])
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OG8 the split')` (exit 1; log `t14-M-08k-run1.log`)

  ```
  00:00 +0 -1: OG8 the split centreline: one open two-point polyline per piece, at [0, a₀] and [b₀, L], from the stored start and to the stored end exactly; none enters the gap; a pick in the doorway on the centreline misses the wall, the sam [cut; the full line is in the log]
    Expected: an object with length of <2>
      Actual: [1303]
       Which: has length of <1>
    test/opening_cut_test.dart 269:5                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08u-window — the no-fit window drawn over the band (not translated), site 1: the window

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-M-08u-window-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  491c491
  <           : [f.lOff + t, f.lOff + t / 2, f.lOff];
  ---
  >           : [f.lOff, (f.lOff + f.rOff) / 2, f.rOff];
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_symbol_test.dart --plain-name 'OG7 (M-08u')` (exit 1; log `t14-M-08u-window-run1.log`)

  ```
  00:00 +0 -1: OG7 (M-08u, X6-nofitdoor) no-fit, per kind, on a rotated 200 left-justified 800 wall: the wall is 07's, bit for bit the twin's; the window's lines lie at lOff + t, lOff + t/2 and lOff over the stored interval, the gap's at lOff [cut; the full line is in the log]
    Expected: a value less than <0.000001>
      Actual: <200.00000000027794>
       Which: is not a value less than <0.000001>
    test/opening_symbol_test.dart 106:5                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08u-gap — the no-fit gap drawn over the band (not translated), site 2: the gap

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-M-08u-gap-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  495c495
  <       return [line(x1 + m, x2 - m, fits ? 0 : f.lOff + t / 2)];
  ---
  >       return [line(x1 + m, x2 - m, 0)];
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_symbol_test.dart --plain-name 'OG7 (M-08u')` (exit 1; log `t14-M-08u-gap-run1.log`)

  ```
  00:00 +0 -1: OG7 (M-08u, X6-nofitdoor) no-fit, per kind, on a rotated 200 left-justified 800 wall: the wall is 07's, bit for bit the twin's; the window's lines lie at lOff + t, lOff + t/2 and lOff over the stored interval, the gap's at lOff [cut; the full line is in the log]
    Expected: a value less than <0.000001>
      Actual: <300.00000000005303>
       Which: is not a value less than <0.000001>
    test/opening_symbol_test.dart 119:5                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08g — the symbol ignores its own group transform

- **file:** `apps/floor_planner/lib/parametric/opening.dart`; backup `t14-M-08g-opening.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  146c146
  <     final toOwn = view.toWorld(self).invert().multiply(view.toWorld(o.host));
  ---
  >     final toOwn = view.toWorld(o.host);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_symbol_test.dart --plain-name 'OR7 (M-08g')` (exit 1; log `t14-M-08g-run1.log`)

  ```
  00:00 +0 -1: OR7 (M-08g, M-08h) the openings' own groups rotated and translated, the host in another rotated group: the world symbols are the oracle's; a TransformNodeCommand on the door's group leaves its world symbol unchanged, is one und [cut; the full line is in the log]
    Expected: a value less than <0.000001>
      Actual: <4653454.22168929>
       Which: is not a value less than <0.000001>
    test/opening_symbol_test.dart 314:5                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08h-symbol — the symbol ignores the host's transform, site 1: `OpeningType.generate`

- **file:** `apps/floor_planner/lib/parametric/opening.dart`; backup `t14-M-08h-symbol-opening.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  146c146
  <     final toOwn = view.toWorld(self).invert().multiply(view.toWorld(o.host));
  ---
  >     final toOwn = view.toWorld(self).invert();
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OG1 one cut')` (exit 1; log `t14-M-08h-symbol-run1.log`)

  ```
  00:00 +0 -1: OG1 one cut, both faces, by coordinates: a door at 1,400 in a 5,000 wall at 23° gives two pieces whose gap corners are the oracle's; a window at 3,600 gives three; a gap clamped against the free start cap drops the start piece; [cut; the full line is in the log]
    Expected: a value less than <0.000001>
      Actual: <4655285.414272157>
       Which: is not a value less than <0.000001>
    test/opening_cut_test.dart 128:5                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_object_test.dart --plain-name 'OR1 (M-08r')` (exit 1; log `t14-M-08h-symbol-run2.log`)

  ```
  00:00 +0 -1: OR1 (M-08r, M-08r2, M-08h) the host's group moved 75 m, its reach disjoint before and after: the door's leaf moves by exactly that vector, door and window stay on the oracle, three pieces tile; one undo step; undo and redo exac [cut; the full line is in the log]
    Expected: a value less than <0.000001>
      Actual: <4655285.414272157>
       Which: is not a value less than <0.000001>
    test/opening_object_test.dart 64:7                  expectOnOracles
    test/opening_object_test.dart 105:5                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_symbol_test.dart --plain-name 'OR7 (M-08g')` (exit 1; log `t14-M-08h-symbol-run3.log`)

  ```
  00:00 +0 -1: OR7 (M-08g, M-08h) the openings' own groups rotated and translated, the host in another rotated group: the world symbols are the oracle's; a TransformNodeCommand on the door's group leaves its world symbol unchanged, is one und [cut; the full line is in the log]
    Expected: a value less than <0.000001>
      Actual: <4655703.967687204>
       Which: is not a value less than <0.000001>
    test/opening_symbol_test.dart 314:5                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (3 of 3 commands red).

### M-08h-preview — the host's transform ignored, site 2: the tool preview's symbol

- **file:** `apps/floor_planner/lib/parametric/opening_tool.dart`; backup `t14-M-08h-preview-opening_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  383c383
  <       for (final g in symbolOf(f, placed.params, cut, toWorld))
  ---
  >       for (final g in symbolOf(f, placed.params, cut, Transform2.identity()))
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT4 (X9-cache, M-08h')` (exit 1; log `t14-M-08h-preview-run1.log`)

  ```
  00:00 +0 -1: OT4 (X9-cache, M-08h at the preview) with no wall under the pointer no preview is built and no frame computed, and a click commits nothing; over a wall the preview is the symbol the click commits and its cut's two jamb lines, i [cut; the full line is in the log]
    Expected: a numeric value within <1e-9> of <4500731.898045339>
      Actual: <601.9256763495164>
       Which:  differs by <4500129.972368989>
    test/opening_tool_test.dart 952:9                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08h-jambs — the host's transform ignored, site 3: the tool preview's jamb lines

- **file:** `apps/floor_planner/lib/parametric/opening_tool.dart`; backup `t14-M-08h-jambs-opening_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  389c389
  <             linePayload(world(u, f.lOff), world(u, f.rOff)),
  ---
  >             linePayload(f.at(u, f.lOff), f.at(u, f.rOff)),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT4 (X9-cache, M-08h')` (exit 1; log `t14-M-08h-jambs-run1.log`)

  ```
  00:00 +0 -1: OT4 (X9-cache, M-08h at the preview) with no wall under the pointer no preview is built and no frame computed, and a click commits nothing; over a wall the preview is the symbol the click commits and its cut's two jamb lines, i [cut; the full line is in the log]
    Expected: a value less than <0.000001>
      Actual: <4657392.705751694>
       Which: is not a value less than <0.000001>
    test/opening_tool_test.dart 960:7                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08h-gripjambs — the host's transform ignored, site 4 (found by the grep): the slide grip's preview jambs

- **file:** `apps/floor_planner/lib/parametric/opening_grips.dart`; backup `t14-M-08h-gripjambs-opening_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  92c92
  <           linePayload(s.world(u, f.lOff), s.world(u, f.rOff)),
  ---
  >           linePayload(f.at(u, f.lOff), f.at(u, f.rOff)),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart --plain-name 'SG1 (X11-stored')` (exit 1; log `t14-M-08h-gripjambs-run1.log`)

  ```
  00:00 +0 -1: SG1 (X11-stored, M-08sn, M-08b, rv11-selfCand) the provider: a clamped door's grip sits at its cut's centre, a no-fit's at its stored centre; a drag projects, edge-snaps to an obstacle edge, and stores the placed centre, the cl [cut; the full line is in the log]
    Expected: a value less than <0.000001>
      Actual: <4657423.244729417>
       Which: is not a value less than <0.000001>
    test/opening_grips_test.dart 214:7                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart --plain-name 'SG1 (shell)')` (exit 0; log `t14-M-08h-gripjambs-run2.log`)

  ```
  00:01 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** PARTIAL (1 of 2 commands red). KILLED by `SG1`'s provider test (line 214); `SG1 (shell)` never reads the preview's jamb coordinates, so it stays green, and it was never a named killer.

### M-08j — the gap generates no line

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-M-08j-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  495c495
  <       return [line(x1 + m, x2 - m, fits ? 0 : f.lOff + t / 2)];
  ---
  >       return const [];
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_symbol_test.dart --plain-name 'OR8 (M-08j')` (exit 1; log `t14-M-08j-run1.log`)

  ```
  Expected: [EntityKind:EntityKind.line]
    Actual: []
     Which: at location [0] is [] which shorter than expected
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_symbol_test.dart:387:7)
  00:00 +0 -1: OR8 (M-08j, M-08j2) gaps on a 250 centre wall at 23° at the far origin: A (180 < t, m = w/4 = 45) and B (1,100 > t, m = t/4 = 62.5) each draw one ByLayer LINE on the centreline from x₁ + m to x₂ − m; a click at A's line end sel [cut; the full line is in the log]
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08j2 — the threshold line not inset (`m = 0`)

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-M-08j2-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  494c494
  <       final m = math.min(t / 4, w / 4);
  ---
  >       const m = 0.0;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_symbol_test.dart --plain-name 'OR8 (M-08j')` (exit 1; log `t14-M-08j2-run1.log`)

  ```
  Expected: a numeric value within <0.000001> of <3555.0>
    Actual: <3510.0000000003965>
     Which:  differs by <44.99999999960346>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_symbol_test.dart:394:7)
  00:00 +0 -1: OR8 (M-08j, M-08j2) gaps on a 250 centre wall at 23° at the far origin: A (180 < t, m = w/4 = 45) and B (1,100 > t, m = t/4 = 62.5) each draw one ByLayer LINE on the centreline from x₁ + m to x₂ − m; a click at A's line end sel [cut; the full line is in the log]
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08p — the end grip does not rewrite openings' positions

- **file:** `apps/floor_planner/lib/parametric/wall_grips.dart`; backup `t14-M-08p-wall_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  59d58
  <       ..._keptPut(d, moved),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_end_drag_test.dart --plain-name 'EP1 (M-08p')` (exit 1; log `t14-M-08p-run1.log`)

  ```
  00:00 +0 -1: EP1 (M-08p, M-08p2, X8-first) A and C collinear, back to back, sharing their starts at N; N dragged 700 mm along the line: every opening on both walls stays put in world within 1e-6 (centre and symbol), the stored positions are [cut; the full line is in the log]
    Expected: a value less than <0.000001>
      Actual: <700.0000000001216>
       Which: is not a value less than <0.000001>
    test/opening_end_drag_test.dart 169:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08p2 — the anchored end reversed: positions rewritten when the end moves, kept when the start moves

- **file:** `apps/floor_planner/lib/parametric/wall_grips.dart`; backup `t14-M-08p2-wall_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  74c74
  <       if (p.start != old.start && p.end == old.end) {
  ---
  >       if (p.end != old.end && p.start == old.start) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_end_drag_test.dart --plain-name 'EP1 (M-08p')` (exit 1; log `t14-M-08p2-run1.log`)

  ```
  00:00 +0 -1: EP1 (M-08p, M-08p2, X8-first) A and C collinear, back to back, sharing their starts at N; N dragged 700 mm along the line: every opening on both walls stays put in world within 1e-6 (centre and symbol), the stored positions are [cut; the full line is in the log]
    Expected: a value less than <0.000001>
      Actual: <700.0000000001216>
       Which: is not a value less than <0.000001>
    test/opening_end_drag_test.dart 169:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_end_drag_test.dart --plain-name 'EP2 (M-08p2)')` (exit 1; log `t14-M-08p2-run2.log`)

  ```
  00:00 +0 -1: EP2 (M-08p2) the end of a lone wall with two openings dragged off its line: the stored positions are unchanged, exactly, and the compound holds no SetComponentCommand<OpeningParams> [E]
    Expected: an object with length of <1>
      Actual: [
       Which: has length of <3>
    test/opening_end_drag_test.dart 216:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_end_drag_test.dart --plain-name 'EP3 (M-08p2)')` (exit 1; log `t14-M-08p2-run3.log`)

  ```
  00:00 +0 -1: EP3 (M-08p2) an L whose corner is A's start and B's end, dragged off the line so both walls swing: A's positions are L′ − (L − p) within 1e-9 and keep their world distance from A's unmoved end; B's are unchanged, exactly [E]
    Expected: a numeric value within <1e-9> of <1266.566156604079>
      Actual: <1500.0>
       Which:  differs by <233.43384339592103>
    test/opening_end_drag_test.dart 297:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (3 of 3 commands red).

### M-08o — T obstacles ignored

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-M-08o-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  143a144
  >       if (tee) continue; // M-08o
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart --plain-name 'OG3 (M-08o)')` (exit 1; log `t14-M-08o-run1.log`)

  ```
  00:00 +0 -1: OG3 (M-08o) a T obstacle: 07's 58° T, a 115 stem onto a 200 right-justified host; a door stored over the stem's butt is drawn in the nearest wide-enough stretch, by coordinates the oracle's cut; tiling 0; opening.clamped names  [cut; the full line is in the log]
    Expected: true
      Actual: <false>
    test/opening_obstacle_test.dart 82:5                expectGapAt
    test/opening_obstacle_test.dart 148:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08x — crossings ignored

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-M-08x-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  150c150
  <     if (tee) continue;
  ---
  >     if (tee || true) continue; // M-08x
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart --plain-name 'OG4 (M-08x)')` (exit 1; log `t14-M-08x-run1.log`)

  ```
  00:00 +0 -1: OG4 (M-08x) an X obstacle: a 150 wall crossing a 200 left host at 71°; a door stored over the crossing is drawn in the nearest wide-enough stretch, by coordinates the oracle's cut; tiling 0; opening.clamped names [door, crossin [cut; the full line is in the log]
    Expected: true
      Actual: <false>
    test/opening_obstacle_test.dart 82:5                expectGapAt
    test/opening_obstacle_test.dart 206:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08w — the nearest stretch chosen without regard to width

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-M-08w-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  222d221
  <     if (!(w <= b - a)) continue;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_geometry_test.dart --plain-name 'OG5 (M-08w)')` (exit 1; log `t14-M-08w-run1.log`)

  ```
  00:00 +0 -1: OG5 (M-08w) a T splits the span: the stretch nearest the centre is too narrow and a farther one fits, so the farther one holds it; with both too narrow there is no fit [E]
    Expected: <986.3232996181903>
      Actual: <-333.2334611296478>
    test/opening_geometry_test.dart 339:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08m — cuts not merged

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-M-08m-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  275c275
  <     if (out.isNotEmpty && c.$1 <= out.last.$2 + wallJoin.linear) {
  ---
  >     if (false && c.$1 <= out.last.$2 + wallJoin.linear) { // M-08m
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart --plain-name 'OG6 (M-08m')` (exit 1; log `t14-M-08m-run1.log`)

  ```
  00:00 +0 -1: OG6 (M-08m, M-08q, M-08q2) a door [1,150, 2,050] and a window [1,500, 2,700] overlap: one merged gap, two pieces, tiling 0, one opening.overlap from the lower handle [lower, higher], whichever kind it is; both symbols drawn ove [cut; the full line is in the log]
    Expected: true
      Actual: <false>
    test/opening_obstacle_test.dart 82:5                expectGapAt
    test/opening_obstacle_test.dart 268:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08q — overlap reported by each opening (twice per pair)

- **file:** `apps/floor_planner/lib/parametric/opening.dart`; backup `t14-M-08q-opening.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  250c250
  <       for (var j = i + 1; j < all.openings.length; j++)
  ---
  >       for (var j = 0; j < all.openings.length; j++) // M-08q
  252c252
  <             when overlaps((cut.a, cut.b), (other.a, other.b)))
  ---
  >             when j != i && overlaps((cut.a, cut.b), (other.a, other.b)))
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart --plain-name 'OG6 (M-08m')` (exit 1; log `t14-M-08q-run1.log`)

  ```
  00:00 +0 -1: OG6 (M-08m, M-08q, M-08q2) a door [1,150, 2,050] and a window [1,500, 2,700] overlap: one merged gap, two pieces, tiling 0, one opening.overlap from the lower handle [lower, higher], whichever kind it is; both symbols drawn ove [cut; the full line is in the log]
    Expected: ['opening.overlap [4000, 4100]', 'opening.nofit [4050]']
      Actual: [
       Which: at location [2] is [
    test/opening_obstacle_test.dart 252:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08q2 — overlap reported by the higher handle

- **file:** `apps/floor_planner/lib/parametric/opening.dart`; backup `t14-M-08q2-opening.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  250c250
  <       for (var j = i + 1; j < all.openings.length; j++)
  ---
  >       for (var j = 0; j < i; j++) // M-08q2
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart --plain-name 'OG6 (M-08m')` (exit 1; log `t14-M-08q2-run1.log`)

  ```
  00:00 +0 -1: OG6 (M-08m, M-08q, M-08q2) a door [1,150, 2,050] and a window [1,500, 2,700] overlap: one merged gap, two pieces, tiling 0, one opening.overlap from the lower handle [lower, higher], whichever kind it is; both symbols drawn ove [cut; the full line is in the log]
    Expected: ['opening.overlap [4000, 4100]', 'opening.nofit [4050]']
      Actual: ['opening.nofit [4050]', 'opening.overlap [4100, 4000]']
       Which: at location [0] is 'opening.nofit [4050]' instead of 'opening.overlap [4000, 4100]'
    test/opening_obstacle_test.dart 252:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08q2-swapped — overlap reported by the higher handle, handles swapped too (M-08q2's second form)

- **file:** `apps/floor_planner/lib/parametric/opening.dart`; backup `t14-M-08q2-swapped-opening.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  250c250
  <       for (var j = i + 1; j < all.openings.length; j++)
  ---
  >       for (var j = 0; j < i; j++) // M-08q2b
  258c258
  <             handles: [self, all.openings[j]],
  ---
  >             handles: [all.openings[j], self],
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart --plain-name 'OG6 (M-08m')` (exit 1; log `t14-M-08q2-swapped-run1.log`)

  ```
  00:00 +0 -1: OG6 (M-08m, M-08q, M-08q2) a door [1,150, 2,050] and a window [1,500, 2,700] overlap: one merged gap, two pieces, tiling 0, one opening.overlap from the lower handle [lower, higher], whichever kind it is; both symbols drawn ove [cut; the full line is in the log]
    Expected: ['opening.overlap [4000, 4100]', 'opening.nofit [4050]']
      Actual: ['opening.nofit [4050]', 'opening.overlap [4000, 4100]']
       Which: at location [0] is 'opening.nofit [4050]' instead of 'opening.overlap [4000, 4100]'
    test/opening_obstacle_test.dart 252:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08i-capture — `movable` ignored, site 1: the render layer's capture (`GripDrag`)

- **file:** `packages/jet_cad_2d_flutter/lib/src/grip_drag.dart`; backup `t14-M-08i-capture-grip_drag.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  152c152
  <         if (!movableKey(document, key, objects)) continue;
  ---
  >
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart --plain-name 'SG2 (M-08i)')` (exit 1; log `t14-M-08i-capture-run1.log`)

  ```
  Expected: <0>
    Actual: <1>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_grips_test.dart:373:5)
  00:02 +0 -1: SG2 (M-08i) a body drag on a selected door starts nothing and adds nothing to the history, and no rotation grip is drawn for it; a wall selected with its door moves, and the door follows through regeneration with its stored pos [cut; the full line is in the log]
  00:02 +0 -1: Some tests failed.
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/object_grips_test.dart --plain-name 'MV1 (M-08i)')` (exit 1; log `t14-M-08i-capture-run2.log`)

  ```
  00:00 +0 -1: MV1 (M-08i) GripDrag.move and rotate skip a root-level group the provider calls immovable: alone nothing is captured; in a mixed selection the rest moves and rotates and the group stays [E]
    Expected: null
      Actual: <Instance of 'GripDrag'>
    test/object_grips_test.dart 406:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/grip_drag.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

### M-08i-rotatable — `movable` ignored, site 2: the render layer's `rotatable`

- **file:** `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; backup `t14-M-08i-rotatable-grip_cache.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  249c249
  <   bool get rotatable => _box != null && _movable;
  ---
  >   bool get rotatable => _box != null;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart --plain-name 'SG2 (M-08i)')` (exit 1; log `t14-M-08i-rotatable-run1.log`)

  ```
  Expected: false
    Actual: <true>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_grips_test.dart:370:5)
  00:01 +0 -1: SG2 (M-08i) a body drag on a selected door starts nothing and adds nothing to the history, and no rotation grip is drawn for it; a wall selected with its door moves, and the door follows through regeneration with its stored pos [cut; the full line is in the log]
  00:01 +0 -1: Some tests failed.
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/object_grips_test.dart --plain-name 'MV2 (X11-rotgrip')` (exit 1; log `t14-M-08i-rotatable-run2.log`)

  ```
  00:00 +0 -1: MV2 (X11-rotgrip, M-08i) the rotation grip needs a movable key: an immovable group alone has a box but is not rotatable, and its grip is neither hit nor pressed; beside a movable key it is [E]
    Expected: false
      Actual: <true>
    test/object_grips_test.dart 459:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

### M-08i-composite — `movable` ignored, site 3: the app's composite (`ObjectGrips.movable`)

- **file:** `apps/floor_planner/lib/parametric/object_grips.dart`; backup `t14-M-08i-composite-object_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  49,50c49
  <   bool movable(DraftDocument d, Handle group) =>
  <       d.components.get<OpeningParams>(group) == null;
  ---
  >   bool movable(DraftDocument d, Handle group) => true;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart --plain-name 'SG2 (M-08i)')` (exit 1; log `t14-M-08i-composite-run1.log`)

  ```
  Expected: false
    Actual: <true>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_grips_test.dart:370:5)
  00:01 +0 -1: SG2 (M-08i) a body drag on a selected door starts nothing and adds nothing to the history, and no rotation grip is drawn for it; a wall selected with its door moves, and the door follows through regeneration with its stored pos [cut; the full line is in the log]
  00:01 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/object_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08i-openinggrips — `movable` ignored, site 4 (found by the grep): `OpeningGrips.movable`

- **file:** `apps/floor_planner/lib/parametric/opening_grips.dart`; backup `t14-M-08i-openinggrips-opening_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  99,100c99
  <   bool movable(DraftDocument d, Handle group) =>
  <       d.components.get<OpeningParams>(group) == null;
  ---
  >   bool movable(DraftDocument d, Handle group) => true;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart)` (exit 0; log `t14-M-08i-openinggrips-run1.log`)

  ```
  00:02 +7: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** SURVIVED (0 of 1 commands red). SURVIVED `opening_grips_test.dart` whole, in the first run; see the next entry. **Superseded by fix round 1:** the composite now delegates to this rule, and the re-fire is killed (`fr1-M-08i-openinggrips`).

### M-08i-openinggrips-full — site 4 against the whole app suite

- **file:** `apps/floor_planner/lib/parametric/opening_grips.dart`; backup `t14-M-08i-openinggrips-full-opening_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  99,100c99
  <   bool movable(DraftDocument d, Handle group) =>
  <       d.components.get<OpeningParams>(group) == null;
  ---
  >   bool movable(DraftDocument d, Handle group) => true;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test)` (exit 0; log `t14-M-08i-openinggrips-full-run1.log`)

  ```
  00:45 +232: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** SURVIVED (0 of 1 commands red). SURVIVED the whole app suite, in the first run: `ObjectGrips.movable` answered for openings itself and never delegated to `OpeningGrips.movable`, and nothing else constructs an `OpeningGrips` (only `object_grips.dart:23`). Finding F2; fixed in fix round 1.

### M-08z — the door's swing side from the opposite side of the click

- **file:** `apps/floor_planner/lib/parametric/opening_tool.dart`; backup `t14-M-08z-opening_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  351c351
  <           swing: side >= 0 ? SwingSide.left : SwingSide.right),
  ---
  >           swing: side < 0 ? SwingSide.left : SwingSide.right),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT2 (M-08z, M-08z2, M-08z3)')` (exit 1; log `t14-M-08z-run1.log`)

  ```
  00:00 +0 -1: OT2 (M-08z, M-08z2, M-08z3) a door swings out of the clicked side of the band's midline and hangs on the nearer end's jamb: on a centred 200 host, clicks 30 mm either side at 0.3·L and 0.7·L; on a right-justified 200 host, clic [cut; the full line is in the log]
    Expected: (HingeEnd, SwingSide):<(HingeEnd.start, SwingSide.left)>
      Actual: (HingeEnd, SwingSide):<(HingeEnd.start, SwingSide.right)>
    test/opening_tool_test.dart 437:7                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08z2 — the hinge on the farther end's jamb

- **file:** `apps/floor_planner/lib/parametric/opening_tool.dart`; backup `t14-M-08z2-opening_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  350c350
  <           hinge: c <= f.len / 2 ? HingeEnd.start : HingeEnd.end,
  ---
  >           hinge: c > f.len / 2 ? HingeEnd.start : HingeEnd.end,
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT2 (M-08z, M-08z2, M-08z3)')` (exit 1; log `t14-M-08z2-run1.log`)

  ```
  00:00 +0 -1: OT2 (M-08z, M-08z2, M-08z3) a door swings out of the clicked side of the band's midline and hangs on the nearer end's jamb: on a centred 200 host, clicks 30 mm either side at 0.3·L and 0.7·L; on a right-justified 200 host, clic [cut; the full line is in the log]
    Expected: (HingeEnd, SwingSide):<(HingeEnd.start, SwingSide.left)>
      Actual: (HingeEnd, SwingSide):<(HingeEnd.end, SwingSide.left)>
    test/opening_tool_test.dart 437:7                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08z3 — the swing side from the centreline, not the band's midline

- **file:** `apps/floor_planner/lib/parametric/opening_tool.dart`; backup `t14-M-08z3-opening_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  347c347
  <         (toLocal.transformPoint(raw) - f.s).dot(f.n) - (f.lOff + f.rOff) / 2;
  ---
  >         (toLocal.transformPoint(raw) - f.s).dot(f.n);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT2 (M-08z, M-08z2, M-08z3)')` (exit 1; log `t14-M-08z3-run1.log`)

  ```
  00:00 +0 -1: OT2 (M-08z, M-08z2, M-08z3) a door swings out of the clicked side of the band's midline and hangs on the nearer end's jamb: on a centred 200 host, clicks 30 mm either side at 0.3·L and 0.7·L; on a right-justified 200 host, clic [cut; the full line is in the log]
    Expected: (HingeEnd, SwingSide):<(HingeEnd.start, SwingSide.left)>
      Actual: (HingeEnd, SwingSide):<(HingeEnd.start, SwingSide.right)>
    test/opening_tool_test.dart 449:7                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08sn-geometry — edge snaps removed, site 1: `edgeSnap` (shared by the tool and the grip)

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-M-08sn-geometry-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  368c368
  <   return best;
  ---
  >   return best == best ? null : null;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT3 (M-08sn, pure)')` (exit 1; log `t14-M-08sn-geometry-run1.log`)

  ```
  00:00 +0 -1: OT3 (M-08sn, pure) edgeSnap: an edge within the aperture of a stretch end or another opening's cut edge moves the centre to put it there; the nearest pair wins, ties go to the lower centre, nothing in range gives null [E]
    Expected: <537.25>
      Actual: <null>
    test/opening_tool_test.dart 641:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT3 (M-08sn, X10-gate)')` (exit 1; log `t14-M-08sn-geometry-run2.log`)

  ```
  00:00 +0 -1: OT3 (M-08sn, X10-gate) a door's edge snaps to a T obstacle's edges, to a window's drawn edges and to the span's end, the nearer candidate winning; with F3 off it stores the chain's projected point [E]
    Expected: a numeric value within <1e-11> of <2134.4067584377062>
      Actual: <2147.4067584373147>
       Which:  differs by <12.999999999608463>
    test/opening_tool_test.dart 727:7                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart --plain-name 'SG1 (X11-stored')` (exit 1; log `t14-M-08sn-geometry-run3.log`)

  ```
  00:00 +0 -1: SG1 (X11-stored, M-08sn, M-08b, rv11-selfCand) the provider: a clamped door's grip sits at its cut's centre, a no-fit's at its stored centre; a drag projects, edge-snaps to an obstacle edge, and stores the placed centre, the cl [cut; the full line is in the log]
    Expected: a value less than <0.000001>
      Actual: <8.999999999939593>
       Which: is not a value less than <0.000001>
    test/opening_grips_test.dart 214:7                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (3 of 3 commands red).

### M-08sn-tool — edge snaps removed, site 2: the tools' `selfSnap`

- **file:** `apps/floor_planner/lib/parametric/opening_tool.dart`; backup `t14-M-08sn-tool-opening_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  185a186
  >     if (_edgeSnapped == false) return null;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT3 (M-08sn, X10-gate)')` (exit 1; log `t14-M-08sn-tool-run1.log`)

  ```
  00:00 +0 -1: OT3 (M-08sn, X10-gate) a door's edge snaps to a T obstacle's edges, to a window's drawn edges and to the span's end, the nearer candidate winning; with F3 off it stores the chain's projected point [E]
    Expected: a numeric value within <1e-11> of <2134.4067584377062>
      Actual: <2147.4067584373147>
       Which:  differs by <12.999999999608463>
    test/opening_tool_test.dart 727:7                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### M-08sn-grip — edge snaps removed, site 3: the slide grip

- **file:** `apps/floor_planner/lib/parametric/opening_grips.dart`; backup `t14-M-08sn-grip-opening_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  153c153
  <     if (apertureWorld != null) {
  ---
  >     if (apertureWorld != null && false) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart --plain-name 'SG1 (X11-stored')` (exit 1; log `t14-M-08sn-grip-run1.log`)

  ```
  00:00 +0 -1: SG1 (X11-stored, M-08sn, M-08b, rv11-selfCand) the provider: a clamped door's grip sits at its cut's centre, a no-fit's at its stored centre; a drag projects, edge-snaps to an obstacle edge, and stores the placed centre, the cl [cut; the full line is in the log]
    Expected: a value less than <0.000001>
      Actual: <8.999999999939593>
       Which: is not a value less than <0.000001>
    test/opening_grips_test.dart 214:7                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart --plain-name 'SG1 (shell)')` (exit 1; log `t14-M-08sn-grip-run2.log`)

  ```
  Expected: a numeric value within <0.000001> of <2017.6326980706485>
    Actual: <1994.0724543174035>
     Which:  differs by <23.560243753245004>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_grips_test.dart:308:5)
  00:01 +0 -1: SG1 (shell) the slide grip is shown at the drawn centre; a drag edge-snaps while object snap is on and is one undo step; with F3 off it stores the grid point projected; under runtime permissions the grip is not hit [E]
  00:01 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

### M-08pin — the section's target read at focus loss (`_commit`, shared with 07's Wall and Box sections)

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t14-M-08pin-selection_panel.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  400c400
  <     final target = f.pinned;
  ---
  >     final target = _targetOf(f.kind);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_panel_test.dart --plain-name 'OS2 (M-08pin)')` (exit 1; log `t14-M-08pin-run1.log`)

  ```
  Expected: OpeningParams:<OpeningParams(door on 12 at 1730.0, 870.0, end, right)>
    Actual: OpeningParams:<OpeningParams(door on 12 at 1730.0, 900.0, end, right)>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_panel_test.dart:371:7)
  00:01 +0 -1: OS2 (M-08pin) the commit target is pinned at focus gain: select A, type in Width, select B without taking the focus, blur: A changes, B does not; the same for Position; a pinned opening that dies drops the text [E]
  00:02 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/selection_panel_test.dart --plain-name 'WS7 (Wall)')` (exit 1; log `t14-M-08pin-run2.log`)

  ```
  Expected: WallParams:<WallParams((589.5107255699113, 444.89701554295607) -> (-2120.8749622078612,
    Actual: WallParams:<WallParams((589.5107255699113, 444.89701554295607) -> (-2120.8749622078612,
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/selection_panel_test.dart:557:5)
  00:02 +0 -1: WS7 (Wall) the commit target is pinned at focus gain: a selection change while a field has focus does not redirect its commit (M-07p); a pinned wall that dies drops the text [E]
  00:02 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/selection_panel_test.dart --plain-name 'WS7 (Box)')` (exit 1; log `t14-M-08pin-run3.log`)

  ```
  Expected: [150, 70.0]
    Actual: [120.0, 70.0]
     Which: at location [0] is <120.0> instead of <150>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/selection_panel_test.dart:646:5)
  00:02 +0 -1: WS7 (Box) the commit target is pinned at focus gain: a selection change while a field has focus does not redirect its commit (M-07p) [E]
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (3 of 3 commands red).

## Controls (throwaway test, never committed)

`apps/floor_planner/test/t14_control_test.dart` held the two recorded controls of Task 4 (`Q3d1`, `Q3d2`), copied from the scratchpad's `zz_control_test.dart`; it was deleted after the run. Both passed on the clean tree (Baselines).

### CTL-M-08b-Q3d1 — control: M-08b's edit against a centred door in a free, symmetric wall (throwaway test)

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-CTL-M-08b-Q3d1-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  588c588
  <     for (final (_, o) in openings) (o.position, o.width),
  ---
  >     for (final (_, o) in openings) (layout.frame.len - o.position, o.width),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/t14_control_test.dart --plain-name 'Q3d1 control')` (exit 0; log `t14-CTL-M-08b-Q3d1-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** CONTROL-GREEN (0 of 1 commands red). CONTROL: survives, as the spec says. A centred door in a free, symmetric wall: `L − p = p`, so the degenerate fixture cannot see the mutant.

### CTL-M-08e-Q3d2 — control: M-08e's edit against a probe of the left face only (throwaway test)

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-CTL-M-08e-Q3d2-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  403c403
  <     if (!on(f.startCap.last, a0)) f.right(a0),
  ---
  >     if (!on(f.startCap.last, a0)) f.right(merged.first.$2),
  409c409
  <     add([f.right(a), f.left(a), f.left(b), f.right(b)], a - b, f.at(b, 0),
  ---
  >     add([f.right(merged[i + 1].$2), f.left(a), f.left(b), f.right(b)], a - b, f.at(b, 0),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/t14_control_test.dart --plain-name 'Q3d2 control')` (exit 0; log `t14-CTL-M-08e-Q3d2-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** CONTROL-GREEN (0 of 1 commands red). CONTROL: survives, as the spec says. The probe samples only points just inside the left face across the gap; the carried right face is invisible to it.

## The tasks' extras

### Engine: references, closure, cascade, dangling (Tasks 1-2, their reviews, Task 3's first commit)

#### X1-self — self not excluded

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-X1-self-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  131c131
  <         if (x != h && objects.containsKey(x)) x,
  ---
  >         if (objects.containsKey(x)) x,
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/references_test.dart --plain-name 'RF1 ')` (exit 1; log `t14-X1-self-run1.log`)

  ```
  00:00 +0 -1: RF1 the survey's maps: referrers ascending and unmodifiable; a reference to a plain group, a root LINE, itself or nothing relates nothing [E]
    Expected: empty
      Actual: [5312]
    test/parametric/references_test.dart 142:7  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X1-dead — non-objects kept in the map

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-X1-dead-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  131c131
  <         if (x != h && objects.containsKey(x)) x,
  ---
  >         if (x != h) x,
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/references_test.dart --plain-name 'RF1 ')` (exit 1; log `t14-X1-dead-run1.log`)

  ```
  00:00 +0 -1: RF1 the survey's maps: referrers ascending and unmodifiable; a reference to a plain group, a root LINE, itself or nothing relates nothing [E]
    Expected: empty
      Actual: [5310]
    test/parametric/references_test.dart 142:7  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X1-sort — referrers unsorted (walked in registration order)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-X1-sort-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  124c124
  <   for (final h in order) {
  ---
  >   for (final h in found.keys) {
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/references_test.dart --plain-name 'RF1 ')` (exit 1; log `t14-X1-sort-run1.log`)

  ```
  00:00 +0 -1: RF1 the survey's maps: referrers ascending and unmodifiable; a reference to a plain group, a root LINE, itself or nothing relates nothing [E]
    Expected: [5100, 5150, 5200, 5300]
      Actual: [5100, 5200, 5300, 5150]
       Which: at location [1] is <5200> instead of <5150>
    test/parametric/references_test.dart 99:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X1-sort-rev — referrers built in descending order

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-X1-sort-rev-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  124c124
  <   for (final h in order) {
  ---
  >   for (final h in order.reversed) {
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/references_test.dart --plain-name 'RF1 ')` (exit 1; log `t14-X1-sort-rev-run1.log`)

  ```
  00:00 +0 -1: RF1 the survey's maps: referrers ascending and unmodifiable; a reference to a plain group, a root LINE, itself or nothing relates nothing [E]
    Expected: [5100, 5150, 5200, 5300]
      Actual: [5300, 5200, 5150, 5100]
       Which: at location [0] is <5300> instead of <5100>
    test/parametric/references_test.dart 99:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X1-over — the core adds `neighbours(references(seeds))`

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-X1-over-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  174a175,177
  >     for (final s in seeds)
  >       for (final x in after.references[s] ?? const <Handle>[])
  >         ...after.neighboursOf(x),
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/references_test.dart --plain-name 'RF5 ')` (exit 1; log `t14-X1-over-run1.log`)

  ```
  00:00 +0 -1: RF5 editing a Pin regenerates its Post but not the Post's neighbour: B is not generated, its children are unchanged [E]
    Expected: null
      Actual: <1>
    test/parametric/references_test.dart 240:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv1-mutable — (Task 1 review) the referrer lists handed out mutable

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-rv1-mutable-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  141c141
  <     for (final e in referrers.entries) e.key: List.unmodifiable(e.value),
  ---
  >     for (final e in referrers.entries) e.key: e.value,
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/references_test.dart --plain-name 'RF1 ')` (exit 1; log `t14-rv1-mutable-run1.log`)

  ```
  00:00 +0 -1: RF1 the survey's maps: referrers ascending and unmodifiable; a reference to a plain group, a root LINE, itself or nothing relates nothing [E]
    Expected: throws <Instance of 'UnsupportedError'>
      Actual: <Closure: () => void>
       Which: returned <null>
    test/parametric/references_test.dart 101:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### m1a-refsBefore — (Task 1 review m-1) the closure drops `before.references`

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-m1a-refsBefore-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  173d172
  <     for (final s in seeds) ...?before.references[s],
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/references_test.dart test/parametric/cascade_test.dart test/parametric/reference_cost_test.dart)` (exit 1; log `t14-m1a-refsBefore-run1.log`)

  ```
  00:00 +7 -1: test/parametric/references_test.dart: RF6 deleting a Pin regenerates its Post in the same edit: the Pin's tick goes, the other Pin's stays [E]
    Expected: empty
      Actual: [1000]
    test/parametric/references_test.dart 266:5  main.<fn>
  00:00 +9 -2: test/parametric/references_test.dart: RF7 re-pointing a Pin from Post A to Post C regenerates both in the same edit: the tick leaves A and appears on C [E]
    Expected: empty
      Actual: [1000]
    test/parametric/references_test.dart 285:5  main.<fn>
  00:00 +25 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### m1b-referrersAfter — (Task 1 review m-1) the closure drops `after.referrers`

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-m1b-referrersAfter-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  179d178
  <     for (final x in core) ...?after.referrers[x],
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/references_test.dart test/parametric/cascade_test.dart test/parametric/reference_cost_test.dart)` (exit 1; log `t14-m1b-referrersAfter-run1.log`)

  ```
  00:00 +8 -1: test/parametric/references_test.dart: RF8 a loaded Pin names a plain group; the group then becomes a Post, and the Pin regenerates in the same edit as the Post's referrer [E]
    Expected: empty
      Actual: [3000]
    test/parametric/references_test.dart 327:5  main.<fn>
  00:00 +26 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### m1c-referrersBefore — (Task 1 review m-1) the closure drops `before.referrers`

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-m1c-referrersBefore-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  178d177
  <     for (final x in core) ...?before.referrers[x],
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/references_test.dart test/parametric/cascade_test.dart test/parametric/reference_cost_test.dart)` (exit 1; log `t14-m1c-referrersBefore-run1.log`)

  ```
  00:00 +10 -1: test/parametric/cascade_test.dart: CS3 an orphan-policy Tag on A is kept when A goes, regenerates to its marker in the same edit, and is reported parametric.orphan once [E]
    Expected: <1>
      Actual: <null>
    test/parametric/cascade_test.dart 290:5  main.<fn>
  00:00 +10 -2: test/parametric/cascade_test.dart: LV1 (Task 1 I-1) the view hides a referent lost in this edit: an orphan Tag never sees its deleted Post, whose component is detached only after the plan, nor draws it at the world origin [E]
    Expected: true
      Actual: <false>
    test/parametric/cascade_test.dart 330:5  main.<fn>
  00:00 +22 -3: test/parametric/cascade_test.dart: LV2 (the broader paramsOf rule) a Post re-parented under a plain group is no object, and its orphan Tag sees it gone in drift() too: drift() is empty and parametric.orphan names it [E]
    Expected: true
      Actual: <false>
    test/parametric/cascade_test.dart 791:5  main.<fn>
  00:00 +24 -3: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### m2-dedup — (Task 1 review m-2) referents not deduplicated

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-m2-dedup-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  129c129
  <     final live = {
  ---
  >     final live = [
  132c132
  <     }.toList()
  ---
  >     ]
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/references_test.dart --plain-name 'RF1 ')` (exit 1; log `t14-m2-dedup-run1.log`)

  ```
  00:00 +0 -1: RF1 the survey's maps: referrers ascending and unmodifiable; a reference to a plain group, a root LINE, itself or nothing relates nothing [E]
    Expected: [5100, 5150, 5200, 5300]
      Actual: [5100, 5150, 5150, 5200, 5300]
       Which: at location [2] is <5150> instead of <5200>
    test/parametric/references_test.dart 99:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv1-noAfterRefs — (Task 1 review) the closure drops `after.references`

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-rv1-noAfterRefs-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  174d173
  <     for (final s in seeds) ...?after.references[s],
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/references_test.dart test/parametric/cascade_test.dart test/parametric/reference_cost_test.dart)` (exit 1; log `t14-rv1-noAfterRefs-run1.log`)

  ```
  00:00 +1 -1: test/parametric/cascade_test.dart: CS1 deleting Post A with the select tool's compound cascades P1 and P2 in the same edit: one undo step; undo, redo, and undo then purge restore the state and every child handle [E]
    Expected: empty
      Actual: [1000]
    test/parametric/cascade_test.dart 192:5  main.<fn>
  00:00 +1 -2: test/parametric/references_test.dart: RF2 editing a Pin regenerates its Post in the same undo step: the tick moves; undo and redo are exact [E]
    Expected: empty
      Actual: [1000]
    test/parametric/references_test.dart 155:5  main.<fn>
  00:00 +5 -3: test/parametric/references_test.dart: RF6 deleting a Pin regenerates its Post in the same edit: the Pin's tick goes, the other Pin's stays [E]
    Expected: true
      Actual: <false>
    test/parametric/references_test.dart 259:5  main.<fn>
  00:00 +6 -4: test/parametric/references_test.dart: RF7 re-pointing a Pin from Post A to Post C regenerates both in the same edit: the tick leaves A and appears on C [E]
    Expected: true
      Actual: <false>
    test/parametric/references_test.dart 281:5  main.<fn>
  ... (18 more kept lines in the log)
  00:00 +19 -8: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X2-node — the spike's rule: cascade only when the node is gone

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-X2-node-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  387c387
  <           if (!_isObject(t, types, e.key))
  ---
  >           if (t.tree[e.key] == null)
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/cascade_test.dart --plain-name 'CS6 ')` (exit 1; log `t14-X2-node-run1.log`)

  ```
  00:00 +0 -1: CS6 A's component detached: A stops being an object though its node stays, and P1 and P2 cascade in the same edit [E]
    Expected: null
      Actual: GroupNode:<GroupNode(BB8, 0 children)>
    test/parametric/cascade_test.dart 110:3  expectGone
    test/parametric/cascade_test.dart 397:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X2-allobjects — the D5 check on every object, not only seeds

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-X2-allobjects-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  506,507c506,507
  <   if (seeds.isEmpty || after.declared.isEmpty) return;
  <   for (final s in seeds.toList()..sort(_byValue)) {
  ---
  >   if (after.declared.isEmpty) return;
  >   for (final s in after.objects.keys) {
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/cascade_test.dart --plain-name 'DR2 ')` (exit 1; log `t14-X2-allobjects-run1.log`)

  ```
  00:00 +0 -1: DR2 a file whose P1 names a missing host loads unchanged; diagnostics() reports parametric.dangling; drift() names P1; an unrelated edit is not refused [E]
    DanglingReferenceError: BB8 references 1009, which is not a live parametric object
    test/parametric/cascade_test.dart 519:21                         main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X2-recall — the D5 check calls `referencesOf` again (the edit's site)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-X2-recall-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  580a581,584
  >     // X2-recall: the check asks each seed's type again.
  >     for (final s in seeds) {
  >       if (after.objects[s] case final o?) o.referencesOf(t, s);
  >     }
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/reference_cost_test.dart --plain-name 'RC1 ')` (exit 1; log `t14-X2-recall-run1.log`)

  ```
  00:00 +0 -1: RC1 a root line drawn among 300 Posts and 300 Pins makes exactly 2 × 600 references calls and no overlap test [E]
    Expected: <1200>
      Actual: <1201>
    test/parametric/reference_cost_test.dart 74:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X2-recall-diag — the same, at `diagnostics()`'s site

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t14-X2-recall-diag-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  296c296,300
  <         for (final h in s.objects.keys) ..._unresolved(s, h),
  ---
  >         for (final h in s.objects.keys)
  >           ...(() {
  >             s.objects[h]!.referencesOf(document, h);
  >             return _unresolved(s, h);
  >           })(),
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/reference_cost_test.dart --plain-name 'RC1 ')` (exit 1; log `t14-X2-recall-diag-run1.log`)

  ```
  00:00 +0 -1: RC1 a root line drawn among 300 Posts and 300 Pins makes exactly 2 × 600 references calls and no overlap test [E]
    Expected: <600>
      Actual: <1200>
    test/parametric/reference_cost_test.dart 80:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X2-diagdedup — `diagnostics()` reports a referent declared twice twice

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t14-X2-diagdedup-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  312c312
  <       for (final x in {...declared})
  ---
  >       for (final x in declared)
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/references_test.dart test/parametric/cascade_test.dart test/parametric/reference_cost_test.dart)` (exit 1; log `t14-X2-diagdedup-run1.log`)

  ```
  00:00 +10 -1: test/parametric/cascade_test.dart: CS3 an orphan-policy Tag on A is kept when A goes, regenerates to its marker in the same edit, and is reported parametric.orphan once [E]
    Expected: an object with length of <1>
      Actual: [
       Which: has length of <2>
    test/parametric/cascade_test.dart 302:5  main.<fn>
  00:00 +15 -2: test/parametric/cascade_test.dart: DR1 an edit naming a root LINE, a plain group or a deleted object as a Pin's host is refused, and nothing changes; the same edit on a Tag is accepted and reported parametric.orphan [E]
    Expected: an object with length of <1>
      Actual: [
       Which: has length of <2>
    test/parametric/cascade_test.dart 480:7  main.<fn>
  00:00 +22 -3: test/parametric/cascade_test.dart: LV2 (the broader paramsOf rule) a Post re-parented under a plain group is no object, and its orphan Tag sees it gone in drift() too: drift() is empty and parametric.orphan names it [E]
    Bad state: Too many elements
    test/parametric/cascade_test.dart 794:19  main.<fn>
  00:00 +24 -3: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### I1-direct — (Task 1 I-1) the view reads a component directly: a referent lost in this edit stays visible

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t14-I1-direct-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  163c163
  <       _survey.objects.containsKey(h) ? _target.components.get<U>(h) : null;
  ---
  >       _target.components.get<U>(h);
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/references_test.dart test/parametric/cascade_test.dart test/parametric/reference_cost_test.dart)` (exit 1; log `t14-I1-direct-run1.log`)

  ```
  00:00 +10 -1: test/parametric/cascade_test.dart: CS3 an orphan-policy Tag on A is kept when A goes, regenerates to its marker in the same edit, and is reported parametric.orphan once [E]
    Expected: [0.0, 0.0, 0.0, 250.0]
      Actual: [5690.972630189896, -2373.358490078879, 3977.195123452002, -1342.3557464359508]
       Which: at location [0] is <5690.972630189896> instead of <0.0>
    test/parametric/cascade_test.dart 293:5  main.<fn>
  00:00 +10 -2: test/parametric/cascade_test.dart: LV1 (Task 1 I-1) the view hides a referent lost in this edit: an orphan Tag never sees its deleted Post, whose component is detached only after the plan, nor draws it at the world origin [E]
    Expected: true
      Actual: <false>
    test/parametric/cascade_test.dart 330:5  main.<fn>
  00:00 +22 -3: test/parametric/cascade_test.dart: LV2 (the broader paramsOf rule) a Post re-parented under a plain group is no object, and its orphan Tag sees it gone in drift() too: drift() is empty and parametric.orphan names it [E]
    Expected: true
      Actual: <false>
    test/parametric/cascade_test.dart 791:5  main.<fn>
  00:00 +24 -3: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### narrower-rule — (Task 2 ruling) the narrower `paramsOf` rule: null only for an object lost in this edit

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t14-narrower-rule-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  150c150
  <   ParametricView._(this._target, this._survey);
  ---
  >   ParametricView._(this._target, this._survey, [this._before]);
  153a154
  >   final _Survey? _before;
  162,163c163,171
  <   U? paramsOf<U extends Component>(Handle h) =>
  <       _survey.objects.containsKey(h) ? _target.components.get<U>(h) : null;
  ---
  >   U? paramsOf<U extends Component>(Handle h) {
  >     final before = _before;
  >     if (before != null &&
  >         before.objects.containsKey(h) &&
  >         !_survey.objects.containsKey(h)) {
  >       return null;
  >     }
  >     return _target.components.get<U>(h);
  >   }
  ```
- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-narrower-rule-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  587c587
  <         t, _closure(seeds, before, after), after, ParametricView._(t, after));
  ---
  >         t, _closure(seeds, before, after), after, ParametricView._(t, after, before));
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/cascade_test.dart --plain-name 'LV2 ')` (exit 1; log `t14-narrower-rule-run1.log`)

  ```
  00:00 +0 -1: LV2 (the broader paramsOf rule) a Post re-parented under a plain group is no object, and its orphan Tag sees it gone in drift() too: drift() is empty and parametric.orphan names it [E]
    Expected: empty
      Actual: [3300]
    test/parametric/cascade_test.dart 792:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### I1-term — (Task 2 review I-1) `_geometryChanged` ignores the cascade

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-I1-term-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  594c594
  <   edit._geometryChanged = plan.isNotEmpty || !identical(r, r0);
  ---
  >   edit._geometryChanged = plan.isNotEmpty;
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/cascade_test.dart --plain-name 'CS8 ')` (exit 1; log `t14-I1-term-run1.log`)

  ```
  00:00 +0 -1: CS8 (Task 2 review I-1) a detached host with no neighbour: the plan is empty, but the cascade removed entities, so the edit reports geometry and the spatial index drops P1's children [E]
    Expected: not Capability:<Capability.components>
      Actual: Capability:<Capability.components>
    test/parametric/cascade_test.dart 550:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### RV-R1 — (Task 2 review I-2) the cascade's own rollback removed

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-RV-R1-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  406,408d405
  <       for (final i in inverses.reversed) {
  <         i.apply(t);
  <       }
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/cascade_test.dart --plain-name 'CS9 ')` (exit 1; log `t14-RV-R1-run1.log`)

  ```
  00:00 +0 -1: CS9 (Task 2 review I-2) a cascade command that throws after an earlier referrer's removals applied: the delete is refused, and the document, the history and doc.changes are as before [E]
    Expected: '{"schemaVersion":6,"header":{"units":"unitless","scale":1.0,"globalLinetypeScale":1.0,"importedExtents":null,"customVariables":{}},"tables":{"layers":[{"handle":1,"name":"0","color":7,"linetype":4,"lineweight":-3,"transparency" [cut; the full line is in the log]
      Actual: '{"schemaVersion":6,"header":{"units":"unitless","scale":1.0,"globalLinetypeScale":1.0,"importedExtents":null,"customVariables":{}},"tables":{"layers":[{"handle":1,"name":"0","color":7,"linetype":4,"lineweight":-3,"transparency" [cut; the full line is in the log]
       Which: is different.
              Expected: ... 000,2000,3000,3100], ...
                Actual: ... 000,2000,3100],"expo ...
    test/parametric/cascade_test.dart 583:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### RV-R1b — (Task 2 review I-2) `r0` not undone after a cascade failure

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-RV-R1b-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  414d413
  <     _undoInner(t, label, r0, error);
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/cascade_test.dart --plain-name 'CS9 ')` (exit 1; log `t14-RV-R1b-run1.log`)

  ```
  00:00 +0 -1: CS9 (Task 2 review I-2) a cascade command that throws after an earlier referrer's removals applied: the delete is refused, and the document, the history and doc.changes are as before [E]
    Expected: '{"schemaVersion":6,"header":{"units":"unitless","scale":1.0,"globalLinetypeScale":1.0,"importedExtents":null,"customVariables":{}},"tables":{"layers":[{"handle":1,"name":"0","color":7,"linetype":4,"lineweight":-3,"transparency" [cut; the full line is in the log]
      Actual: '{"schemaVersion":6,"header":{"units":"unitless","scale":1.0,"globalLinetypeScale":1.0,"importedExtents":null,"customVariables":{}},"tables":{"layers":[{"handle":1,"name":"0","color":7,"linetype":4,"lineweight":-3,"transparency" [cut; the full line is in the log]
       Which: is different.
              Expected: ... hildren":[1000,2000, ...
                Actual: ... hildren":[2000,3000, ...
    test/parametric/cascade_test.dart 583:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### RV-R2 — (Task 2 review m-2) the first dangling referent in declared order, not ascending

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-RV-R2-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  515,516c515
  <       if (!after.objects.containsKey(x) &&
  <           (first == null || x.value < first.value)) {
  ---
  >       if (!after.objects.containsKey(x) && first == null) {
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/cascade_test.dart --plain-name 'DR3 ')` (exit 1; log `t14-RV-R2-run1.log`)

  ```
  00:00 +0 -1: DR3 (Task 2 review m-2) Ruling 08-5's order: the lowest dead referent of the lowest seed is the one refused [E]
    Expected: throws <Instance of 'DanglingReferenceError'> with `object`: <6000> and `referent`: <18>
      Actual: <Closure: () => void>
       Which: threw DanglingReferenceError:<DanglingReferenceError: 1770 references 13, which is not a live parametric object>
                    test/parametric/cascade_test.dart 751:28                         main.<fn>.<fn>
                    test/parametric/cascade_test.dart 750:5                          main.<fn>
    test/parametric/cascade_test.dart 750:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### RV-R2b — (Task 2 review m-2) seeds checked unsorted

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-RV-R2b-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  507c507
  <   for (final s in seeds.toList()..sort(_byValue)) {
  ---
  >   for (final s in seeds) {
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/cascade_test.dart --plain-name 'DR3 ')` (exit 1; log `t14-RV-R2b-run1.log`)

  ```
  00:00 +0 -1: DR3 (Task 2 review m-2) Ruling 08-5's order: the lowest dead referent of the lowest seed is the one refused [E]
    Expected: throws <Instance of 'DanglingReferenceError'> with `object`: <6000> and `referent`: <19>
      Actual: <Closure: () => void>
       Which: threw DanglingReferenceError:<DanglingReferenceError: 17D4 references 12, which is not a live parametric object>
                    test/parametric/cascade_test.dart 757:28                         main.<fn>.<fn>
                    test/parametric/cascade_test.dart 756:5                          main.<fn>
    test/parametric/cascade_test.dart 756:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### reinstate-skip — (Task 2 review m-1) X2-fillskip reinstated: a fill whose boundary goes is left to the boundary

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-reinstate-skip-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  476c476,478
  <         if (isFill(c)) RemoveEntityCommand(c),
  ---
  >         if (isFill(c) &&
  >             !(leaves[g] ?? const <Handle>[]).contains(_boundaryOf(t, c)))
  >           RemoveEntityCommand(c),
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/cascade_test.dart --plain-name 'CS10 ')` (exit 1; log `t14-reinstate-skip-run1.log`)

  ```
  00:00 +0 -1: CS10 (Task 2 review m-1) a loaded region whose boundary cannot be filled (open), or whose fill names no boundary: the cascade removes the fill first, so deleting A lands; one step; undo is exact [E]
    Bad state: cannot remove boundary C1F: C1F is not a fillable boundary, so undo could not restore the pair; remove fill C1E first
    test/parametric/cascade_test.dart 607:20                         main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### non-fill-first — (Task 2 re-review) reconstruction 1: leaves removed in ascending order, fills not first

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-non-fill-first-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  473,477c473
  <   final out = <DraftCommand>[
  <     for (final g in groups)
  <       for (final c in leaves[g] ?? const <Handle>[])
  <         if (isFill(c)) RemoveEntityCommand(c),
  <   ];
  ---
  >   final out = <DraftCommand>[];
  480c476
  <       if (!isFill(c)) out.add(RemoveEntityCommand(c));
  ---
  >       out.add(RemoveEntityCommand(c));
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/cascade_test.dart --plain-name 'CS10 ')` (exit 0; log `t14-non-fill-first-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** SURVIVED (0 of 1 commands red). SURVIVED `CS10` (its killer in the Task 2 re-review, whose edit was not written down). This reconstruction removes each group's leaves in ascending handle order, and a planner-made region has fill < boundary, so ascending order is already fill-first there. The next two entries settle it: `CS12` kills this edit, and the other reading of the name (non-fills before fills) is killed by `CS10` and `CS12`.

#### non-fill-first-ascending — reconstruction 1 against the whole engine suite

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-non-fill-first-ascending-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  473,477c473
  <   final out = <DraftCommand>[
  <     for (final g in groups)
  <       for (final c in leaves[g] ?? const <Handle>[])
  <         if (isFill(c)) RemoveEntityCommand(c),
  <   ];
  ---
  >   final out = <DraftCommand>[];
  480c476
  <       if (!isFill(c)) out.add(RemoveEntityCommand(c));
  ---
  >       out.add(RemoveEntityCommand(c));
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test)` (exit 1; log `t14-non-fill-first-ascending-run1.log`)

  ```
  00:08 +680 -1: test/parametric/cascade_test.dart: CS12 (Task 2 re-review m2) a loaded region whose fill sits in a group nested under P2 and whose boundary is P2's own: every fill of the doomed subtree goes before any boundary, so deleting A [cut; the full line is in the log]
    Bad state: cannot remove boundary C1F: a region's two halves must share one owner, so undo could not restore the pair; remove fill C1E first
    test/parametric/cascade_test.dart 705:18                         main.<fn>
  00:09 +719 -2: test/testing/generate_document_test.dart: the default document is the one Plan 2 measured, byte for byte [E]
    Expected: <1593811103237081036>
      Actual: <7763566604490466414>
    test/testing/generate_document_test.dart 59:5  main.<fn>
  00:09 +750 -3: test/testing/generate_document_test.dart: both text fractions default to zero and change nothing [E]
    Expected: <1593811103237081036>
      Actual: <7763566604490466414>
    test/testing/generate_document_test.dart 240:5  main.<fn>
  00:12 +1013 -3: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red). KILLED by `CS12` (a fill in a nested group naming its owner's boundary: ascending order removes the boundary first). The two other red lines are the engine's standing Linux failures (Ruling 08-20).

#### non-fill-first-v2 — (Task 2 re-review) reconstruction 2: each group's non-fill leaves before its fills

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-non-fill-first-v2-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  473,477c473
  <   final out = <DraftCommand>[
  <     for (final g in groups)
  <       for (final c in leaves[g] ?? const <Handle>[])
  <         if (isFill(c)) RemoveEntityCommand(c),
  <   ];
  ---
  >   final out = <DraftCommand>[];
  480a477,479
  >     }
  >     for (final c in leaves[g] ?? const <Handle>[]) {
  >       if (isFill(c)) out.add(RemoveEntityCommand(c));
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/cascade_test.dart --plain-name 'CS10 ')` (exit 1; log `t14-non-fill-first-v2-run1.log`)

  ```
  00:00 +0 -1: CS10 (Task 2 review m-1) a loaded region whose boundary cannot be filled (open), or whose fill names no boundary: the cascade removes the fill first, so deleting A lands; one step; undo is exact [E]
    Bad state: cannot remove boundary C1F: C1F is not a fillable boundary, so undo could not restore the pair; remove fill C1E first
    test/parametric/cascade_test.dart 607:20                         main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/references_test.dart test/parametric/cascade_test.dart test/parametric/reference_cost_test.dart)` (exit 1; log `t14-non-fill-first-v2-run2.log`)

  ```
  00:00 +5 -1: test/parametric/cascade_test.dart: CS1 deleting Post A with the select tool's compound cascades P1 and P2 in the same edit: one undo step; undo, redo, and undo then purge restore the state and every child handle [E]
    Bad state: no entity with handle C1E
    test/parametric/cascade_test.dart 213:18                         main.<fn>
  00:00 +7 -2: test/parametric/cascade_test.dart: CS2 a transitive cascade: Q on P1 on A; deleting A removes P1 and then Q in the same edit; one step; undo restores all four [E]
    Bad state: no entity with handle C1E
    test/parametric/cascade_test.dart 258:18                         main.<fn>
  00:00 +8 -3: test/parametric/cascade_test.dart: CS3 an orphan-policy Tag on A is kept when A goes, regenerates to its marker in the same edit, and is reported parametric.orphan once [E]
    Bad state: no entity with handle C1E
    test/parametric/cascade_test.dart 286:18                         main.<fn>
  00:00 +9 -4: test/parametric/cascade_test.dart: CS4 a bare RemoveNodeCommand of A: P1's and P2's leaves and nodes are removed; A's own leaves remain (06's recorded debt) [E]
    Bad state: no entity with handle C1E
    test/parametric/cascade_test.dart 345:18                         main.<fn>
  00:00 +9 -5: test/parametric/cascade_test.dart: CS5 a neighbour whose generate throws after the cascade: the delete is refused, and the bytes, the Pins' children, the undo depth and doc.changes are unchanged [E]
    Expected: throws <Instance of 'StateError'> with `message`: 'tripwire'
      Actual: <Closure: () => void>
       Which: threw StateError:<Bad state: no entity with handle C1E>
  ... (31 more kept lines in the log)
  00:00 +15 -12: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### old-order — (Task 2 re-review m2) each group's fills first, not the whole subtree's

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-old-order-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  473,477c473
  <   final out = <DraftCommand>[
  <     for (final g in groups)
  <       for (final c in leaves[g] ?? const <Handle>[])
  <         if (isFill(c)) RemoveEntityCommand(c),
  <   ];
  ---
  >   final out = <DraftCommand>[];
  478a475,477
  >     for (final c in leaves[g] ?? const <Handle>[]) {
  >       if (isFill(c)) out.add(RemoveEntityCommand(c));
  >     }
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/cascade_test.dart --plain-name 'CS12 ')` (exit 1; log `t14-old-order-run1.log`)

  ```
  00:00 +0 -1: CS12 (Task 2 re-review m2) a loaded region whose fill sits in a group nested under P2 and whose boundary is P2's own: every fill of the doomed subtree goes before any boundary, so deleting A lands in one step, validate() shows  [cut; the full line is in the log]
    Bad state: cannot remove boundary C1F: a region's two halves must share one owner, so undo could not restore the pair; remove fill C1E first
    test/parametric/cascade_test.dart 705:18                         main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### no-recursion — (Task 2 review m-3) a nested group removed without its subtree

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-no-recursion-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  487c487
  <           remove(c);
  ---
  >           out.add(RemoveNodeCommand(c));
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/cascade_test.dart --plain-name 'CS11 ')` (exit 1; log `t14-no-recursion-run1.log`)

  ```
  00:00 +0 -1: CS11 (Task 2 review m-3; Task 2 re-review m1) the cascade removes a referrer's subtree as the select tool does: a nested group under P1, with its own leaf, and an instance under P1 go too; validate() stays clean; undo is exact  [cut; the full line is in the log]
    Expected: null
      Actual: <13>
    test/parametric/cascade_test.dart 660:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### no-instance — (Task 2 re-review m1) a nested instance not removed

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-no-instance-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  488,489d487
  <         } else if (child is InstanceNode) {
  <           out.add(RemoveNodeCommand(c));
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/cascade_test.dart --plain-name 'CS11 ')` (exit 1; log `t14-no-instance-run1.log`)

  ```
  00:00 +0 -1: CS11 (Task 2 review m-3; Task 2 re-review m1) the cascade removes a referrer's subtree as the select tool does: a nested group under P1, with its own leaf, and an instance under P1 go too; validate() stays clean; undo is exact  [cut; the full line is in the log]
    Expected: null
      Actual: InstanceNode:<InstanceNode(C22 of C21)>
    test/parametric/cascade_test.dart 659:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### Host frame, obstacles, stretches, placement (Task 3 and its reviews)

#### X3-span — `uS` from the min, `uE` from the max

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-X3-span-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  41,42c41,42
  <         uS = startCap.map((q) => (q - s).dot(d)).reduce(math.max),
  <         uE = endCap.map((q) => (q - s).dot(d)).reduce(math.min);
  ---
  >         uS = startCap.map((q) => (q - s).dot(d)).reduce(math.min),
  >         uE = endCap.map((q) => (q - s).dot(d)).reduce(math.max);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_geometry_test.dart --plain-name 'HF2 the 67')` (exit 1; log `t14-X3-span-run1.log`)

  ```
  00:00 +0 -1: HF2 the 67° L (A 200, B 115), all nine justification pairs: A's uE and B's uS are the u of the oracle's mitre corners; no cap vertex lies strictly inside a span [E]
    Expected: a value less than <0.000001>
      Actual: <209.82640664361134>
       Which: is not a value less than <0.000001>
    test/opening_geometry_test.dart 80:9                main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X3-tee — the T interval from the stem's centreline ± t/2

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-X3-tee-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  144c144,146
  <       out.add(span([
  ---
  >       final um = frame.uOf(toLocal.transformPoint(b.endpoint(k)));
  >       out.add((a: um - b.t / 2, b: um + b.t / 2, wall: b.handle));
  >       if (um.isNaN) out.add(span([
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_geometry_test.dart --plain-name 'HF3 T obstacles')` (exit 1; log `t14-X3-tee-run1.log`)

  ```
  00:00 +0 -1: HF3 T obstacles: 07's WG4 T at 58° butts the host's near face; a stem whose start tees in from the host's right; 07's WG19 shallow T covers its stem's whole footprint in the band, square end to where its faces leave the near fa [cut; the full line is in the log]
    Expected: a value less than <0.000001>
      Actual: <10.302758194262424>
       Which: is not a value less than <0.000001>
    test/opening_geometry_test.dart 111:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X3-xing — the X interval from the centrelines ± t/2

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-X3-xing-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  160c160,162
  <     out.add(span([
  ---
  >     final um = frame.uOf(toLocal.transformPoint(host.s + host.d * uh));
  >     out.add((a: um - b.t / 2, b: um + b.t / 2, wall: b.handle));
  >     if (um.isNaN) out.add(span([
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_geometry_test.dart --plain-name 'HF4 an X')` (exit 1; log `t14-X3-xing-run1.log`)

  ```
  00:00 +0 -1: HF4 an X at 71° (a 200 left host crossed by a 150 centre wall): the interval is the u-range of the four face crossings; a free end in the band and a collinear overlapping wall are no obstacles [E]
    Expected: a value less than <0.000001>
      Actual: <4.321551088787146>
       Which: is not a value less than <0.000001>
    test/opening_geometry_test.dart 186:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X3-sliver — a stretch ≤ `wallJoin.linear` kept

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-X3-sliver-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  186c186
  <     if (b - a > wallJoin.linear) out.add((a, b));
  ---
  >     if (b - a > 0) out.add((a, b));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_geometry_test.dart --plain-name 'HF5 stretches')` (exit 1; log `t14-X3-sliver-run1.log`)

  ```
  00:00 +0 -1: HF5 stretches: the span minus a T and an X is three sorted stretches whose ends are the obstacles' own bits; two obstacles half a tolerance apart leave no sliver; a nested obstacle does not reopen its outer one; an obstacle bey [cut; the full line is in the log]
    Expected: [
      Actual: [
       Which: at location [1] is (double, double):<(1400.5, 1400.5000005)> instead of (double, double):<(1900.75, 4999.999999999953)>
    test/opening_geometry_test.dart 243:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X3-tie — ties go to the higher `a`

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-X3-tie-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  224c224
  <     if (distance < bestDistance) {
  ---
  >     if (distance <= bestDistance) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_geometry_test.dart --plain-name 'HF6 placement')` (exit 1; log `t14-X3-tie-run1.log`)

  ```
  00:00 +0 -1: HF6 placement: an unclamped cut starts at c − w/2 bit for bit; a tie goes to the lower a; a degenerate width or position places nothing [E]
    Expected: <500.25>
      Actual: <2000.75>
    test/opening_geometry_test.dart 296:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X3r-capPointsOnly — (Task 3 S1) the T interval from 07's cap points only

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-X3r-capPointsOnly-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  147c147,148
  <           if (intersect(near, host.d, b.s + bn * bo, b.d) case final q?) q,
  ---
  >           if (intersect(near, host.d, b.s + bn * bo, b.d) case final q?)
  >             if (q.isNaN) q,
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_geometry_test.dart --plain-name 'HF3 T obstacles')` (exit 1; log `t14-X3r-capPointsOnly-run1.log`)

  ```
  00:00 +0 -1: HF3 T obstacles: 07's WG4 T at 58° butts the host's near face; a stem whose start tees in from the host's right; 07's WG19 shallow T covers its stem's whole footprint in the band, square end to where its faces leave the near fa [cut; the full line is in the log]
    Expected: a value less than <0.000001>
      Actual: <1171.836805507361>
       Which: is not a value less than <0.000001>
    test/opening_geometry_test.dart 154:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X3r-teeEndOnly — (Task 3 review m1) only a stem's end k = 1 checked

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-X3r-teeEndOnly-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  138c138
  <     for (final k in const [0, 1]) {
  ---
  >     for (final k in const [1]) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_geometry_test.dart --plain-name 'HF3 T obstacles')` (exit 1; log `t14-X3r-teeEndOnly-run1.log`)

  ```
  00:00 +0 -1: HF3 T obstacles: 07's WG4 T at 58° butts the host's near face; a stem whose start tees in from the host's right; 07's WG19 shallow T covers its stem's whole footprint in the band, square end to where its faces leave the near fa [cut; the full line is in the log]
    Expected: an object with length of <1>
      Actual: []
       Which: has length of <0>
    test/opening_geometry_test.dart 122:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X3r-nested — (Task 3 review m2) nested obstacles: `from` not kept at the max

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-X3r-nested-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  193c193
  <     if (o.b > from) from = o.b;
  ---
  >     from = o.b;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_geometry_test.dart --plain-name 'HF5 stretches')` (exit 1; log `t14-X3r-nested-run1.log`)

  ```
  00:00 +0 -1: HF5 stretches: the span minus a T and an X is three sorted stretches whose ends are the obstacles' own bits; two obstacles half a tolerance apart leave no sliver; a nested obstacle does not reopen its outer one; an obstacle bey [cut; the full line is in the log]
    Expected: [
      Actual: [
       Which: at location [1] is (double, double):<(2740.754332111867, 4999.9999999996635)> instead of (double, double):<(2819.175359259659, 4999.9999999996635)>
    test/opening_geometry_test.dart 257:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X3r-straddle — (Task 3 review m3) an obstacle beyond `uE` not clipped

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-X3r-straddle-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  192c192
  <     if (o.a > from) add(from, o.a < frame.uE ? o.a : frame.uE);
  ---
  >     if (o.a > from) add(from, o.a);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_geometry_test.dart --plain-name 'HF5 stretches')` (exit 1; log `t14-X3r-straddle-run1.log`)

  ```
  00:00 +0 -1: HF5 stretches: the span minus a T and an X is three sorted stretches whose ends are the obstacles' own bits; two obstacles half a tolerance apart leave no sliver; a nested obstacle does not reopen its outer one; an obstacle bey [cut; the full line is in the log]
    Expected: [(double, double):(-1.5512569007114507e-10, 2785.5493079501634)]
      Actual: [(double, double):(-1.5512569007114507e-10, 2869.2456678898025)]
       Which: at location [0] is (double, double):<(-1.5512569007114507e-10, 2869.2456678898025)> instead of (double, double):<(-1.5512569007114507e-10, 2785.5493079501634)>
    test/opening_geometry_test.dart 275:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X3r-frameLR — (Task 3 review) the frame's face offsets swapped

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-X3r-frameLR-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  92c92
  <       p.start, p.end, dv.normalized(), dv.length, l, r, ce, cs, fellBack);
  ---
  >       p.start, p.end, dv.normalized(), dv.length, r, l, ce, cs, fellBack);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_geometry_test.dart --plain-name 'HF1 a 3')` (exit 1; log `t14-X3r-frameLR-run1.log`)

  ```
  00:00 +0 -1: HF1 a 3,700 mm wall at 31°, each justification: s, d, n, len, lOff and rOff equal the oracle's; the free wall's span is [0, L] [E]
    Expected: <115.0>
      Actual: <0.0>
    test/opening_geometry_test.dart 53:7                main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X3r-frameS — (Task 3 review) the frame's `s` taken from the stored end

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-X3r-frameS-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  92c92
  <       p.start, p.end, dv.normalized(), dv.length, l, r, ce, cs, fellBack);
  ---
  >       p.end, p.end, dv.normalized(), dv.length, l, r, ce, cs, fellBack);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_geometry_test.dart --plain-name 'HF1 a 3')` (exit 1; log `t14-X3r-frameS-run1.log`)

  ```
  00:00 +0 -1: HF1 a 3,700 mm wall at 31°, each justification: s, d, n, len, lOff and rOff equal the oracle's; the free wall's span is [0, L] [E]
    Expected: a value less than <1e-8>
      Actual: <3699.9999999995293>
       Which: is not a value less than <1e-8>
    test/opening_geometry_test.dart 48:7                main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X3r-frameN — (Task 3 review) the frame's normal flipped

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-X3r-frameN-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  40c40
  <       : n = Vector2(-d.y, d.x),
  ---
  >       : n = Vector2(d.y, -d.x),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_geometry_test.dart --plain-name 'HF1 a 3')` (exit 1; log `t14-X3r-frameN-run1.log`)

  ```
  00:00 +0 -1: HF1 a 3,700 mm wall at 31°, each justification: s, d, n, len, lOff and rOff equal the oracle's; the free wall's span is [0, L] [E]
    Expected: a value less than <1e-8>
      Actual: <2.0>
       Which: is not a value less than <1e-8>
    test/opening_geometry_test.dart 50:7                main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv3-parallelSkip — (Task 3 review) the parallel skip removed

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-rv3-parallelSkip-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  134d133
  <     if (cross.abs() <= wallJoin.angular) continue;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_geometry_test.dart --plain-name 'HF4 an X')` (exit 1; log `t14-rv3-parallelSkip-run1.log`)

  ```
  00:00 +0 -1: HF4 an X at 71° (a 200 left host crossed by a 150 centre wall): the interval is the u-range of the four face crossings; a free end in the band and a collinear overlapping wall are no obstacles [E]
    Expected: empty
      Actual: [
    test/opening_geometry_test.dart 205:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv3-xStrict — (Task 3 review) an X judged with the crossing not strictly inside both walls

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-rv3-xStrict-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  156,157c156,157
  <     if (!(uh > wallJoin.linear && uh < hLen - wallJoin.linear) ||
  <         !(ub > wallJoin.linear && ub < bLen - wallJoin.linear)) {
  ---
  >     if (!(uh > -wallJoin.linear && uh < hLen + wallJoin.linear) ||
  >         !(ub > -wallJoin.linear && ub < bLen + wallJoin.linear)) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_geometry_test.dart)` (exit 1; log `t14-rv3-xStrict-run1.log`)

  ```
  00:00 +4 -1: HF5 stretches: the span minus a T and an X is three sorted stretches whose ends are the obstacles' own bits; two obstacles half a tolerance apart leave no sliver; a nested obstacle does not reopen its outer one; an obstacle bey [cut; the full line is in the log]
    Expected: an object with length of <1>
      Actual: [
       Which: has length of <2>
    test/opening_geometry_test.dart 272:5               main.<fn>
  00:00 +6 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv3-nearAlwaysL — (Task 3 re-review) the T's near face always the left face

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-rv3-nearAlwaysL-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  143c143
  <       final near = host.s + hn * (end.a.dot(hn) > 0 ? hl : hr);
  ---
  >       final near = host.s + hn * hl;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_geometry_test.dart --plain-name 'HF3 T obstacles')` (exit 1; log `t14-rv3-nearAlwaysL-run1.log`)

  ```
  00:00 +0 -1: HF3 T obstacles: 07's WG4 T at 58° butts the host's near face; a stem whose start tees in from the host's right; 07's WG19 shallow T covers its stem's whole footprint in the band, square end to where its faces leave the near fa [cut; the full line is in the log]
    Expected: a value less than <0.000001>
      Actual: <122.28610787785783>
       Which: is not a value less than <0.000001>
    test/opening_geometry_test.dart 134:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv3-nearAlwaysR — (Task 3 re-review) always the right face

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-rv3-nearAlwaysR-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  143c143
  <       final near = host.s + hn * (end.a.dot(hn) > 0 ? hl : hr);
  ---
  >       final near = host.s + hn * hr;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_geometry_test.dart --plain-name 'HF3 T obstacles')` (exit 1; log `t14-rv3-nearAlwaysR-run1.log`)

  ```
  00:00 +0 -1: HF3 T obstacles: 07's WG4 T at 58° butts the host's near face; a stem whose start tees in from the host's right; 07's WG19 shallow T covers its stem's whole footprint in the band, square end to where its faces leave the near fa [cut; the full line is in the log]
    Expected: a value less than <0.000001>
      Actual: <124.97387038135366>
       Which: is not a value less than <0.000001>
    test/opening_geometry_test.dart 111:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv3-nearSwapped — (Task 3 re-review) the near face swapped

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-rv3-nearSwapped-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  143c143
  <       final near = host.s + hn * (end.a.dot(hn) > 0 ? hl : hr);
  ---
  >       final near = host.s + hn * (end.a.dot(hn) > 0 ? hr : hl);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_geometry_test.dart --plain-name 'HF3 T obstacles')` (exit 1; log `t14-rv3-nearSwapped-run1.log`)

  ```
  00:00 +0 -1: HF3 T obstacles: 07's WG4 T at 58° butts the host's near face; a stem whose start tees in from the host's right; 07's WG19 shallow T covers its stem's whole footprint in the band, square end to where its faces leave the near fa [cut; the full line is in the log]
    Expected: a value less than <0.000001>
      Actual: <124.97387038135366>
       Which: is not a value less than <0.000001>
    test/opening_geometry_test.dart 111:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv3-nearFromBd — (Task 3 re-review) the near face from `b.d`, not from the end's direction

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-rv3-nearFromBd-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  143c143
  <       final near = host.s + hn * (end.a.dot(hn) > 0 ? hl : hr);
  ---
  >       final near = host.s + hn * (b.d.dot(hn) > 0 ? hl : hr);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_geometry_test.dart --plain-name 'HF3 T obstacles')` (exit 1; log `t14-rv3-nearFromBd-run1.log`)

  ```
  00:00 +0 -1: HF3 T obstacles: 07's WG4 T at 58° butts the host's near face; a stem whose start tees in from the host's right; 07's WG19 shallow T covers its stem's whole footprint in the band, square end to where its faces leave the near fa [cut; the full line is in the log]
    Expected: a value less than <0.000001>
      Actual: <124.97387038135366>
       Which: is not a value less than <0.000001>
    test/opening_geometry_test.dart 111:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### Pieces and the split centreline (Task 4)

#### X4-drop — a piece ≤ `wallJoin.linear` kept

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-X4-drop-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  393d392
  <     if (!(extent > wallJoin.linear)) return;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OG1 one cut')` (exit 1; log `t14-X4-drop-run1.log`)

  ```
  00:00 +0 -1: OG1 one cut, both faces, by coordinates: a door at 1,400 in a 5,000 wall at 23° gives two pieces whose gap corners are the oracle's; a window at 3,600 gives three; a gap clamped against the free start cap drops the start piece; [cut; the full line is in the log]
    test/opening_cut_test.dart 37:16                                 run
    test/opening_cut_test.dart 161:5                                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X4-order — pieces not in `u` order (reversed)

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-X4-order-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  418c418
  <   return out;
  ---
  >   return out.reversed.toList();
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OR6 deleting')` (exit 1; log `t14-X4-order-run1.log`)

  ```
  00:00 +0 -1: OR6 deleting only the door makes the wall whole: 07's three children, the ring bit for bit the twin's uncut outline, the start piece's handles kept and the surplus the highest; one undo restores the pieces with their handles [E [cut; the full line is in the log]
    Expected: [1301]
      Actual: [4001]
       Which: at location [0] is <4001> instead of <1301>
    test/opening_cut_test.dart 560:5                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X4-adapter — the view adapter sees no neighbours

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-X4-adapter-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  510c510
  <       for (final n in view.neighbours(host))
  ---
  >       for (final n in const <Handle>[])
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OG2 the 67')` (exit 1; log `t14-X4-adapter-run1.log`)

  ```
  00:00 +0 -1: OG2 the 67° L (A 200, B 115), all nine justification pairs: two openings in A, one stored past the node and clamped at the mitre, one in B: 0 tiling violations, every piece triangulates and is simple and anticlockwise, three pi [cut; the full line is in the log]
    Expected: an object with length of <3>
      Actual: [
       Which: has length of <2>
    test/opening_cut_test.dart 208:9                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### Admission, merge, diagnostics (Task 5 and its reviews)

#### X5-touch — touching counts as overlap

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-X5-touch-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  325c325
  <     x.$1 < y.$2 - wallJoin.linear && y.$1 < x.$2 - wallJoin.linear;
  ---
  >     x.$1 <= y.$2 && y.$1 <= x.$2; // X5-touch
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart --plain-name 'OG6 (M-08m')` (exit 1; log `t14-X5-touch-run1.log`)

  ```
  00:00 +0 -1: OG6 (M-08m, M-08q, M-08q2) a door [1,150, 2,050] and a window [1,500, 2,700] overlap: one merged gap, two pieces, tiling 0, one opening.overlap from the lower handle [lower, higher], whichever kind it is; both symbols drawn ove [cut; the full line is in the log]
    Expected: empty
      Actual: ['opening.overlap [4000, 4100]']
    test/opening_obstacle_test.dart 297:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X5-cause — `opening.clamped` names no obstacle wall

- **file:** `apps/floor_planner/lib/parametric/opening.dart`; backup `t14-X5-cause-opening.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  248c248
  <           handles: [self, ...walls],
  ---
  >           handles: [self], // X5-cause
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart --plain-name 'OG3 (M-08o)')` (exit 1; log `t14-X5-cause-run1.log`)

  ```
  00:00 +0 -1: OG3 (M-08o) a T obstacle: 07's 58° T, a 115 stem onto a 200 right-justified host; a door stored over the stem's butt is drawn in the nearest wide-enough stretch, by coordinates the oracle's cut; tiling 0; opening.clamped names  [cut; the full line is in the log]
    Expected: ['opening.clamped [4000, 2600]']
      Actual: ['opening.clamped [4000]']
       Which: at location [0] is 'opening.clamped [4000]' instead of 'opening.clamped [4000, 2600]'
    test/opening_obstacle_test.dart 153:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### keep-a-piece — (D8 amended) a zero-piece wall allowed

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-keep-a-piece-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  311c311
  <     if (_pieces(frame, trial).isEmpty) {
  ---
  >     if (false && _pieces(frame, trial).isEmpty) { // allow a zero-piece wall
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart --plain-name 'OG11 (a)')` (exit 1; log `t14-keep-a-piece-run1.log`)

  ```
  00:00 +0 -1: OG11 (a) a wall keeps a piece: a gap 2e-7 shorter than a free wall's whole span is no-fit (opening.nofit, not clamped); the wall is uncut [E]
    Expected: [
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/opening_obstacle_test.dart 62:3                expectUncut
    test/opening_obstacle_test.dart 319:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart --plain-name 'OG11 (b)')` (exit 1; log `t14-keep-a-piece-run2.log`)

  ```
  00:00 +0 -1: OG11 (b) a wall keeps a piece: two 1,000 windows at 500 and 1,500 on a free 2,000 wall each cut alone; together the higher-handle one is no-fit (opening.nofit, not clamped) and the lower one keeps its cut [E]
    Expected: an object with length of <3>
      Actual: []
       Which: has length of <0>
    test/opening_obstacle_test.dart 356:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart --plain-name 'OG11 (c)')` (exit 1; log `t14-keep-a-piece-run3.log`)

  ```
  00:00 +0 -1: OG11 (c) a wall keeps a piece: a gap 5e-7 shorter than a square T stem's span [100, 1500] leaves 2.5e-7 slivers: it is no-fit and the stem is uncut [E]
    Expected: [
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/opening_obstacle_test.dart 62:3                expectUncut
    test/opening_obstacle_test.dart 394:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart --plain-name 'OG11 (d)')` (exit 1; log `t14-keep-a-piece-run4.log`)

  ```
  00:00 +0 -1: OG11 (d) a wall keeps a piece, admitted in handle order: a whole-span gap then a 300 window: the gap is no-fit and the window cuts; windows [0, 1000] and [1000, 2000] then a door nested in the first: the second window is no-fit [cut; the full line is in the log]
    Expected: an object with length of <2>
      Actual: []
       Which: has length of <0>
    test/opening_obstacle_test.dart 551:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (4 of 4 commands red).

#### check-once — (Task 5 fix round) the keep-a-piece check yields at most once

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-check-once-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  305a306
  >   var yielded = false; // check only once (yield at most once)
  311c312,313
  <     if (_pieces(frame, trial).isEmpty) {
  ---
  >     if (!yielded && _pieces(frame, trial).isEmpty) {
  >       yielded = true;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart --plain-name 'OG11 (d)')` (exit 1; log `t14-check-once-run1.log`)

  ```
  00:00 +0 -1: OG11 (d) a wall keeps a piece, admitted in handle order: a whole-span gap then a 300 window: the gap is no-fit and the window cuts; windows [0, 1000] and [1000, 2000] then a door nested in the first: the second window is no-fit [cut; the full line is in the log]
    Bad state: Pattern matching error
    test/opening_obstacle_test.dart 579:7  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### check-final — (Task 5 fix round) the check made once, on the final merge

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-check-final-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  306c306
  <   var merged = const <(double, double)>[];
  ---
  >   // check only once: admit all, check the merged result once
  309,316c309,317
  <     if (c == null) continue;
  <     final trial = mergeCuts([...admitted, (c.a, c.b)]);
  <     if (_pieces(frame, trial).isEmpty) {
  <       cuts[i] = null;
  <     } else {
  <       admitted.add((c.a, c.b));
  <       merged = trial;
  <     }
  ---
  >     if (c != null) admitted.add((c.a, c.b));
  >   }
  >   var merged = mergeCuts(admitted);
  >   if (merged.isNotEmpty && _pieces(frame, merged).isEmpty) {
  >     cuts[cuts.lastIndexWhere((c) => c != null)] = null;
  >     merged = mergeCuts([
  >       for (final c in cuts)
  >         if (c != null) (c.a, c.b),
  >     ]);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart --plain-name 'OG11 (d)')` (exit 1; log `t14-check-final-run1.log`)

  ```
  00:00 +0 -1: OG11 (d) a wall keeps a piece, admitted in handle order: a whole-span gap then a 300 window: the gap is no-fit and the window cuts; windows [0, 1000] and [1000, 2000] then a door nested in the first: the second window is no-fit [cut; the full line is in the log]
    Expected: an object with length of <2>
      Actual: []
       Which: has length of <0>
    test/opening_obstacle_test.dart 551:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### highest-handle — (Task 5 fix round) the old rule: the highest handle yields

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-highest-handle-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  305,315c305,312
  <   final admitted = <(double, double)>[];
  <   var merged = const <(double, double)>[];
  <   for (var i = 0; i < cuts.length; i++) {
  <     final c = cuts[i];
  <     if (c == null) continue;
  <     final trial = mergeCuts([...admitted, (c.a, c.b)]);
  <     if (_pieces(frame, trial).isEmpty) {
  <       cuts[i] = null;
  <     } else {
  <       admitted.add((c.a, c.b));
  <       merged = trial;
  ---
  >   // yield the highest handle (the old rule)
  >   while (true) {
  >     final merged = mergeCuts([
  >       for (final c in cuts)
  >         if (c != null) (c.a, c.b),
  >     ]);
  >     if (merged.isEmpty || _pieces(frame, merged).isNotEmpty) {
  >       return (cuts: cuts, merged: merged);
  316a314
  >     cuts[cuts.lastIndexWhere((c) => c != null)] = null;
  317a316,317
  >   // ignore: dead_code
  >   final merged = const <(double, double)>[];
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart --plain-name 'OG11 (d)')` (exit 1; log `t14-highest-handle-run1.log`)

  ```
  00:00 +0 -1: OG11 (d) a wall keeps a piece, admitted in handle order: a whole-span gap then a 300 window: the gap is no-fit and the window cuts; windows [0, 1000] and [1000, 2000] then a door nested in the first: the second window is no-fit [cut; the full line is in the log]
    Expected: an object with length of <2>
      Actual: [
       Which: has length of <1>
    test/opening_obstacle_test.dart 551:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv5b-descending — (Task 5 re-review) admitted in descending handle order

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-rv5b-descending-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  307c307
  <   for (var i = 0; i < cuts.length; i++) {
  ---
  >   for (var i = cuts.length - 1; i >= 0; i--) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart --plain-name 'OG11 (b)')` (exit 1; log `t14-rv5b-descending-run1.log`)

  ```
  00:00 +0 -1: OG11 (b) a wall keeps a piece: two 1,000 windows at 500 and 1,500 on a free 2,000 wall each cut alone; together the higher-handle one is no-fit (opening.nofit, not clamped) and the lower one keeps its cut [E]
    Expected: a value greater than <999.999999>
      Actual: <-1.9288961539132288e-9>
       Which: is not a value greater than <999.999999>
    test/opening_obstacle_test.dart 360:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart --plain-name 'OG11 (d)')` (exit 1; log `t14-rv5b-descending-run2.log`)

  ```
  00:00 +0 -1: OG11 (d) a wall keeps a piece, admitted in handle order: a whole-span gap then a 300 window: the gap is no-fit and the window cuts; windows [0, 1000] and [1000, 2000] then a door nested in the first: the second window is no-fit [cut; the full line is in the log]
    Bad state: Pattern matching error
    test/opening_obstacle_test.dart 579:7  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### rv5b-checkAlone — (Task 5 re-review) each cut checked alone, not merged with the admitted

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-rv5b-checkAlone-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  311c311
  <     if (_pieces(frame, trial).isEmpty) {
  ---
  >     if (_pieces(frame, [(c.a, c.b)]).isEmpty) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart --plain-name 'OG11 (b)')` (exit 1; log `t14-rv5b-checkAlone-run1.log`)

  ```
  00:00 +0 -1: OG11 (b) a wall keeps a piece: two 1,000 windows at 500 and 1,500 on a free 2,000 wall each cut alone; together the higher-handle one is no-fit (opening.nofit, not clamped) and the lower one keeps its cut [E]
    Expected: an object with length of <3>
      Actual: []
       Which: has length of <0>
    test/opening_obstacle_test.dart 356:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart --plain-name 'OG11 (d)')` (exit 1; log `t14-rv5b-checkAlone-run2.log`)

  ```
  00:00 +0 -1: OG11 (d) a wall keeps a piece, admitted in handle order: a whole-span gap then a 300 window: the gap is no-fit and the window cuts; windows [0, 1000] and [1000, 2000] then a door nested in the first: the second window is no-fit [cut; the full line is in the log]
    Bad state: Pattern matching error
    test/opening_obstacle_test.dart 579:7  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### RV5-degHostSilent — (Task 5 review m-1) a degenerate host's openings report nothing

- **file:** `apps/floor_planner/lib/parametric/opening.dart`; backup `t14-RV5-degHostSilent-opening.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  216a217
  >     if (all == null) return const []; // RV5-degHostSilent
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart --plain-name 'OD1 only')` (exit 1; log `t14-RV5-degHostSilent-run1.log`)

  ```
  00:00 +0 -1: OD1 only the accepted cases are reported: a clean L with fitting openings reports nothing; OG5's no-fit exactly opening.nofit; a host that is a box opening.orphan; a degenerate host opening.nofit, drawing nothing; a loaded widt [cut; the full line is in the log]
    Expected: ['wall.degenerate [1300]', 'opening.nofit [4000]']
      Actual: ['wall.degenerate [1300]']
       Which: at location [1] is ['wall.degenerate [1300]'] which shorter than expected
    test/opening_obstacle_test.dart 487:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### tolerant-overlap — (Task 5 ruling S3) clamped walls named by a tolerant overlap

- **file:** `apps/floor_planner/lib/parametric/opening.dart`; backup `t14-tolerant-overlap-opening.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  232c232
  <         if (lo < ob.b && ob.a < hi) ob.wall,
  ---
  >         if (overlaps((lo, hi), (ob.a, ob.b))) ob.wall, // tolerant overlap
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart --plain-name 'OG3 (M-08o)')` (exit 1; log `t14-tolerant-overlap-run1.log`)

  ```
  00:00 +0 -1: OG3 (M-08o) a T obstacle: 07's 58° T, a 115 stem onto a 200 right-justified host; a door stored over the stem's butt is drawn in the nearest wide-enough stretch, by coordinates the oracle's cut; tiling 0; opening.clamped names  [cut; the full line is in the log]
    Expected: ['opening.clamped [4000, 2600]']
      Actual: ['opening.clamped [4000]']
       Which: at location [0] is 'opening.clamped [4000]' instead of 'opening.clamped [4000, 2600]'
    test/opening_obstacle_test.dart 173:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### RV-4 — (Task 4 review m2) the middle piece clockwise

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-RV-4-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  409c409
  <     add([f.right(a), f.left(a), f.left(b), f.right(b)], a - b, f.at(b, 0),
  ---
  >     add([f.right(b), f.left(b), f.left(a), f.right(a)], a - b, f.at(b, 0), // RV-4
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OG1 one cut')` (exit 1; log `t14-RV-4-run1.log`)

  ```
  00:00 +0 -1: OG1 one cut, both faces, by coordinates: a door at 1,400 in a 5,000 wall at 23° gives two pieces whose gap corners are the oracle's; a window at 3,600 gives three; a gap clamped against the free start cap drops the start piece; [cut; the full line is in the log]
    Expected: true
      Actual: <false>
    test/opening_cut_test.dart 155:5                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OG9 the random')` (exit 1; log `t14-RV-4-run2.log`)

  ```
  00:11 +0 -1: OG9 the random property run: 2–4-way nodes, a T stem and an X crossing wall, 0–3 openings per wall, every wall in its own rotated group at the far origin: 0 refused, 0 tiling violations, drift() empty, every stored piece triang [cut; the full line is in the log]
    Expected: <0>
      Actual: <192>
    test/opening_cut_test.dart 497:5                    main.<fn>
  00:11 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### RV-1 — (Task 4 review m3) the end centreline to a recomputed `s + len·d`

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-RV-1-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  417c417
  <   ], f.endCap.map(f.uOf).reduce(math.max) - bn, f.at(bn, 0), f.e);
  ---
  >   ], f.endCap.map(f.uOf).reduce(math.max) - bn, f.at(bn, 0), f.at(f.len, 0)); // RV-1
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OG9 the random')` (exit 1; log `t14-RV-1-run1.log`)

  ```
  00:11 +0 -1: OG9 the random property run: 2–4-way nodes, a T stem and an X crossing wall, 0–3 openings per wall, every wall in its own rotated group at the far origin: 0 refused, 0 tiling violations, drift() empty, every stored piece triang [cut; the full line is in the log]
    Expected: <0>
      Actual: <162>
    test/opening_cut_test.dart 498:5                    main.<fn>
  00:11 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### m5a — (Task 3 m5) `mergeCuts` joins only when `a ≤ last.b`, no `+ linear`

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-m5a-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  275c275
  <     if (out.isNotEmpty && c.$1 <= out.last.$2 + wallJoin.linear) {
  ---
  >     if (out.isNotEmpty && c.$1 <= out.last.$2) { // m5a
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart --plain-name 'OG6 (M-08m')` (exit 1; log `t14-m5a-run1.log`)

  ```
  00:00 +0 -1: OG6 (M-08m, M-08q, M-08q2) a door [1,150, 2,050] and a window [1,500, 2,700] overlap: one merged gap, two pieces, tiling 0, one opening.overlap from the lower handle [lower, higher], whichever kind it is; both symbols drawn ove [cut; the full line is in the log]
    Expected: an object with length of <1>
      Actual: [
       Which: has length of <2>
    test/opening_obstacle_test.dart 292:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### m5b — (Task 3 m5) `overlaps` without the `− linear`

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-m5b-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  325c325
  <     x.$1 < y.$2 - wallJoin.linear && y.$1 < x.$2 - wallJoin.linear;
  ---
  >     x.$1 < y.$2 && y.$1 < x.$2; // m5b
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart --plain-name 'OG6 (M-08m')` (exit 1; log `t14-m5b-run1.log`)

  ```
  00:00 +0 -1: OG6 (M-08m, M-08q, M-08q2) a door [1,150, 2,050] and a window [1,500, 2,700] overlap: one merged gap, two pieces, tiling 0, one opening.overlap from the lower handle [lower, higher], whichever kind it is; both symbols drawn ove [cut; the full line is in the log]
    Expected: empty
      Actual: ['opening.overlap [4000, 4100]']
    test/opening_obstacle_test.dart 297:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### RV5-orphanAlways — (Task 5 review, reconstructed from its name) `opening.orphan` reported whether or not the host is live

- **file:** `apps/floor_planner/lib/parametric/opening.dart`; backup `t14-RV5-orphanAlways-opening.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  196,198d195
  <       if (host != self && !view.referrers(host).contains(self)) {
  <         return const [];
  <       }
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart)` (exit 1; log `t14-RV5-orphanAlways-run1.log`)

  ```
  00:00 +6 -1: OD1 only the accepted cases are reported: a clean L with fitting openings reports nothing; OG5's no-fit exactly opening.nofit; a host that is a box opening.orphan; a degenerate host opening.nofit, drawing nothing; a loaded widt [cut; the full line is in the log]
    Expected: ['parametric.dangling [4000, 30583]']
      Actual: ['parametric.dangling [4000, 30583]', 'opening.orphan [4000, 30583]']
       Which: at location [1] is ['parametric.dangling [4000, 30583]', 'opening.orphan [4000, 30583]'] which longer than expected
    test/opening_obstacle_test.dart 521:7               main.<fn>
  00:00 +7 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_object_test.dart)` (exit 0; log `t14-RV5-orphanAlways-run2.log`)

  ```
  00:00 +5: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** PARTIAL (1 of 2 commands red). KILLED by `OD1` (line 521): a loaded opening whose host is missing reports `opening.orphan` beside `parametric.dangling`. `opening_object_test.dart` has no dangling case and stays green.

#### RV5-diagOwnCut — (Task 5 review, reconstructed from its name) `diagnose` places its own cut instead of reading the shared decision

- **file:** `apps/floor_planner/lib/parametric/opening.dart`; backup `t14-RV5-diagOwnCut-opening.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  224c224
  <     final cut = all.cuts[i];
  ---
  >     final cut = placeCut(all.layout.stretches, o.position, o.width);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart --plain-name 'OG11 (a)')` (exit 1; log `t14-RV5-diagOwnCut-run1.log`)

  ```
  00:00 +0 -1: OG11 (a) a wall keeps a piece: a gap 2e-7 shorter than a free wall's whole span is no-fit (opening.nofit, not clamped); the wall is uncut [E]
    Expected: ['opening.nofit [4000]']
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/opening_obstacle_test.dart 320:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart --plain-name 'OG11 (b)')` (exit 1; log `t14-RV5-diagOwnCut-run2.log`)

  ```
  00:00 +0 -1: OG11 (b) a wall keeps a piece: two 1,000 windows at 500 and 1,500 on a free 2,000 wall each cut alone; together the higher-handle one is no-fit (opening.nofit, not clamped) and the lower one keeps its cut [E]
    Expected: ['opening.nofit [4100]']
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/opening_obstacle_test.dart 363:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart --plain-name 'OG11 (d)')` (exit 1; log `t14-RV5-diagOwnCut-run3.log`)

  ```
  00:00 +0 -1: OG11 (d) a wall keeps a piece, admitted in handle order: a whole-span gap then a 300 window: the gap is no-fit and the window cuts; windows [0, 1000] and [1000, 2000] then a door nested in the first: the second window is no-fit [cut; the full line is in the log]
    Expected: ['opening.nofit [4000]']
      Actual: ['opening.overlap [4000, 4100]']
       Which: at location [0] is 'opening.overlap [4000, 4100]' instead of 'opening.nofit [4000]'
    test/opening_obstacle_test.dart 554:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (3 of 3 commands red).

#### RV5-overlapStored — (Task 5 review, reconstructed from its name) `opening.overlap` judged on the stored intervals, not the cuts

- **file:** `apps/floor_planner/lib/parametric/opening.dart`; backup `t14-RV5-overlapStored-opening.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  252c252,256
  <             when overlaps((cut.a, cut.b), (other.a, other.b)))
  ---
  >             when overlaps((lo, hi), (
  >                 view.paramsOf<OpeningParams>(all.openings[j])!.position -
  >                     view.paramsOf<OpeningParams>(all.openings[j])!.width / 2,
  >                 view.paramsOf<OpeningParams>(all.openings[j])!.position +
  >                     view.paramsOf<OpeningParams>(all.openings[j])!.width / 2)))
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_obstacle_test.dart)` (exit 0; log `t14-RV5-overlapStored-run1.log`)

  ```
  00:00 +8: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OG9 the random')` (exit 1; log `t14-RV5-overlapStored-run2.log`)

  ```
  00:11 +0 -1: OG9 the random property run: 2–4-way nodes, a T stem and an X crossing wall, 0–3 openings per wall, every wall in its own rotated group at the far origin: 0 refused, 0 tiling violations, drift() empty, every stored piece triang [cut; the full line is in the log]
    Expected: <0>
      Actual: <139>
    test/opening_cut_test.dart 500:5                    main.<fn>
  00:11 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** PARTIAL (1 of 2 commands red). KILLED by `OG9`, whose diagnostics are compared with the oracle per trial; `opening_obstacle_test.dart` stays green (its overlapping pairs overlap both ways).

### Symbols (Task 6 and its review)

#### X6-hinge — the hinge at the other jamb

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-X6-hinge-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  472c472
  <       final (uh, us) = o.hinge == HingeEnd.start ? (x1, x2) : (x2, x1);
  ---
  >       final (uh, us) = o.hinge == HingeEnd.start ? (x2, x1) : (x1, x2);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_symbol_test.dart --plain-name 'OG10 (X6')` (exit 1; log `t14-X6-hinge-run1.log`)

  ```
  00:00 +0 -1: OG10 (X6-hinge, X6-face, X6-sweep) four non-central 700 doors on a right-justified 200 wall at the far origin, one per hinge × swing: the hinge is the swing-face jamb corner; the leaf is perpendicular, off the band, of length w [cut; the full line is in the log]
    Expected: a value less than <0.000001>
      Actual: <700.0000000002126>
       Which: is not a value less than <0.000001>
    test/opening_symbol_test.dart 213:9                 main.<fn>.check
    test/opening_symbol_test.dart 263:5                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X6-face — the leaf on the other face

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-X6-face-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  474c474
  <           o.swing == SwingSide.left ? (f.lOff, w) : (f.rOff, -w);
  ---
  >           o.swing == SwingSide.left ? (f.rOff, w) : (f.lOff, -w);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_symbol_test.dart --plain-name 'OG10 (X6')` (exit 1; log `t14-X6-face-run1.log`)

  ```
  00:00 +0 -1: OG10 (X6-hinge, X6-face, X6-sweep) four non-central 700 doors on a right-justified 200 wall at the far origin, one per hinge × swing: the hinge is the swing-face jamb corner; the leaf is perpendicular, off the band, of length w [cut; the full line is in the log]
    Expected: a value less than <0.000001>
      Actual: <200.00000000006364>
       Which: is not a value less than <0.000001>
    test/opening_symbol_test.dart 213:9                 main.<fn>.check
    test/opening_symbol_test.dart 263:5                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X6-sweep — the arc clockwise

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-X6-sweep-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  486c486
  <                 hinge, toTip.length, math.atan2(from.y, from.x), math.pi / 2)),
  ---
  >                 hinge, toTip.length, math.atan2(from.y, from.x), -math.pi / 2)),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_symbol_test.dart --plain-name 'OG10 (X6')` (exit 1; log `t14-X6-sweep-run1.log`)

  ```
  00:00 +0 -1: OG10 (X6-hinge, X6-face, X6-sweep) four non-central 700 doors on a right-justified 200 wall at the far origin, one per hinge × swing: the hinge is the swing-face jamb corner; the leaf is perpendicular, off the band, of length w [cut; the full line is in the log]
    Expected: <1.5707963267948966>
      Actual: <-1.5707963267948966>
    test/opening_symbol_test.dart 213:9                 main.<fn>.check
    test/opening_symbol_test.dart 263:5                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X6-cover — the leaf drawn from the centreline, over the band

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-X6-cover-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  482c482
  <         Generated(EntityKind.line, linePayload(hinge, tip)),
  ---
  >         Generated(EntityKind.line, linePayload(own(uh, 0), tip)),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_paint_test.dart --plain-name 'RD1 (X6-cover)')` (exit 1; log `t14-X6-cover-run1.log`)

  ```
  Expected: a value greater than <0.6>
    Actual: <0.21541647058823532>
     Which: is not a value greater than <0.6>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_paint_test.dart:165:7)
  00:01 +0 -1: RD1 (X6-cover) on Blueprint, door D1 hinged at its end jamb, then a window added on its start side: the piece beside D1's hinge is rewritten into fresh handles above D1's leaf, and D1's leaf still shows light 3-10 px from the h [cut; the full line is in the log]
  00:01 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X6-nofitdoor — a no-fit door generates nothing

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-X6-nofitdoor-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  471a472
  >       if (!fits) return const [];
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_symbol_test.dart --plain-name 'OG7 (M-08u')` (exit 1; log `t14-X6-nofitdoor-run1.log`)

  ```
  00:00 +0 -1: OG7 (M-08u, X6-nofitdoor) no-fit, per kind, on a rotated 200 left-justified 800 wall: the wall is 07's, bit for bit the twin's; the window's lines lie at lOff + t, lOff + t/2 and lOff over the stored interval, the gap's at lOff [cut; the full line is in the log]
    Expected: [EntityKind:EntityKind.line, EntityKind:EntityKind.arc]
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/opening_symbol_test.dart 129:7                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv5b-cornerTol — (Task 5 re-review m-1) the corner judged with the tolerance

- **file:** `apps/floor_planner/lib/parametric/opening.dart`; backup `t14-rv5b-cornerTol-opening.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  236c236,237
  <       if (lo < frame.uS || hi > frame.uE) 'a corner of wall ${host.toHex()}',
  ---
  >       if (lo < frame.uS - wallJoin.linear || hi > frame.uE + wallJoin.linear)
  >         'a corner of wall ${host.toHex()}',
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OG2 the 67')` (exit 1; log `t14-rv5b-cornerTol-run1.log`)

  ```
  00:00 +0 -1: OG2 the 67° L (A 200, B 115), all nine justification pairs: two openings in A, one stored past the node and clamped at the mitre, one in B: 0 tiling violations, every piece triangulates and is simple and anticlockwise, three pi [cut; the full line is in the log]
    Expected: contains 'corner'
      Actual: 'opening 1004 is drawn off its stored position: its stretch moved it'
       Which: does not contain 'corner'
    test/opening_cut_test.dart 258:5                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv6-globalMemo — (Task 6 review) the cuts memo shared across views

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-rv6-globalMemo-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  577c577
  <   final memo = _hostCutsByView[view] ??= <Handle, HostCuts?>{};
  ---
  >   final memo = _hostCutsByView[_hostCutsByView] ??= <Handle, HostCuts?>{};
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OR3 editing')` (exit 1; log `t14-rv6-globalMemo-run1.log`)

  ```
  00:00 +0 -1: OR3 editing the door's position regenerates its wall in the same undo step: the pieces move by coordinates; undo and redo are exact [E]
    Bad state: Pattern matching error
    test/opening_cut_test.dart 520:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_object_test.dart --plain-name 'OR1 (M-08r')` (exit 1; log `t14-rv6-globalMemo-run2.log`)

  ```
  00:00 +0 -1: OR1 (M-08r, M-08r2, M-08h) the host's group moved 75 m, its reach disjoint before and after: the door's leaf moves by exactly that vector, door and window stay on the oracle, three pieces tile; one undo step; undo and redo exac [cut; the full line is in the log]
    Expected: an object with length of <3>
      Actual: [
       Which: has length of <1>
    test/opening_object_test.dart 104:5                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### rv6-clampedStored — (Task 6 review) a clamped symbol drawn over its stored interval

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-rv6-clampedStored-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  464,465c464,465
  <   final x1 = fits ? cut.a : o.position - w / 2;
  <   final x2 = fits ? cut.b : o.position + w / 2;
  ---
  >   final x1 = fits && !cut.clamped ? cut.a : o.position - w / 2;
  >   final x2 = fits && !cut.clamped ? cut.b : o.position + w / 2;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OG9 the random')` (exit 1; log `t14-rv6-clampedStored-run1.log`)

  ```
  00:11 +0 -1: OG9 the random property run: 2–4-way nodes, a T stem and an X crossing wall, 0–3 openings per wall, every wall in its own rotated group at the far origin: 0 refused, 0 tiling violations, drift() empty, every stored piece triang [cut; the full line is in the log]
    Expected: <0>
      Actual: <336>
    test/opening_cut_test.dart 502:5                    main.<fn>
  00:11 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv6-winOrder — (Task 6 review) the window's faces in the other order

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-rv6-winOrder-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  490c490
  <           ? [f.lOff, (f.lOff + f.rOff) / 2, f.rOff]
  ---
  >           ? [f.rOff, (f.lOff + f.rOff) / 2, f.lOff]
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_symbol_test.dart)` (exit 1; log `t14-rv6-winOrder-run1.log`)

  ```
  00:00 +2 -1: OR7 (M-08g, M-08h) the openings' own groups rotated and translated, the host in another rotated group: the world symbols are the oracle's; a TransformNodeCommand on the door's group leaves its world symbol unchanged, is one und [cut; the full line is in the log]
    Expected: a value less than <0.000001>
      Actual: <200.00000000027794>
       Which: is not a value less than <0.000001>
    test/opening_symbol_test.dart 315:5                 main.<fn>
  00:01 +3 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OG9 the random')` (exit 1; log `t14-rv6-winOrder-run2.log`)

  ```
  00:11 +0 -1: OG9 the random property run: 2–4-way nodes, a T stem and an X crossing wall, 0–3 openings per wall, every wall in its own rotated group at the far origin: 0 refused, 0 tiling violations, drift() empty, every stored piece triang [cut; the full line is in the log]
    Expected: <0>
      Actual: <1052>
    test/opening_cut_test.dart 503:5                    main.<fn>
  00:11 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

### The opening as an object (Task 7 and its review)

#### X7-json — `host` written as a hex string

- **file:** `apps/floor_planner/lib/parametric/opening.dart`; backup `t14-X7-json-opening.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  53c53
  <         'host': host.toJson(),
  ---
  >         'host': host.toHex(),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_object_test.dart --plain-name 'OR2 (X7-json')` (exit 1; log `t14-X7-json-run1.log`)

  ```
  00:00 +0 -1: OR2 (X7-json, rv7-posRound) save → load → save is byte-identical; a fractional position and width survive it; each typed OpeningParams compares equal; drift() is empty after the load; the same two edits (slide the door, move th [cut; the full line is in the log]
    test/opening_object_test.dart 173:20                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X7-dirty — the closure drops the referrers of neighbours only (takes them of seeds and references)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-X7-dirty-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  175a176,180
  >   final notNeighbours = {
  >     ...seeds,
  >     for (final s in seeds) ...?before.references[s],
  >     for (final s in seeds) ...?after.references[s],
  >   };
  178,179c183,184
  <     for (final x in core) ...?before.referrers[x],
  <     for (final x in core) ...?after.referrers[x],
  ---
  >     for (final x in notNeighbours) ...?before.referrers[x],
  >     for (final x in notNeighbours) ...?after.referrers[x],
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_object_test.dart --plain-name 'DF1 (X7-dirty')` (exit 1; log `t14-X7-dirty-run1.log`)

  ```
  00:00 +0 -1: DF1 (X7-dirty) a 24-wall plan with every opening kind, T and X obstacles, clamped, no-fit and overlapping openings, built one command at a time and edited (a wall move, a thickness change, an end drag, an opening slide): a docu [cut; the full line is in the log]
    Expected: empty
      Actual: [5060]
    test/opening_object_test.dart 39:3                  run
    test/opening_object_test.dart 452:5                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_object_test.dart --plain-name 'OR4 (M-08t')` (exit 1; log `t14-X7-dirty-run2.log`)

  ```
  00:00 +0 -1: OR4 (M-08t, M-08r2, X7-dirty) the two-hop shape: A 200 centre into a node, B 115 left out of it at 67°, a door in A stored at 2,700 and drawn clamped at A's mitre; swinging B's far end to 40° moves the door's leaf by more than  [cut; the full line is in the log]
    Expected: empty
      Actual: [4000]
    test/opening_object_test.dart 39:3                  run
    test/opening_object_test.dart 238:5                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### winMid — (Task 7) the window's midline on the centreline, not the band's midline

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-winMid-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  490c490
  <           ? [f.lOff, (f.lOff + f.rOff) / 2, f.rOff]
  ---
  >           ? [f.lOff, 0.0, f.rOff]
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_cut_test.dart --plain-name 'OG9 the random')` (exit 1; log `t14-winMid-run1.log`)

  ```
  00:11 +0 -1: OG9 the random property run: 2–4-way nodes, a T stem and an X crossing wall, 0–3 openings per wall, every wall in its own rotated group at the far origin: 0 refused, 0 tiling violations, drift() empty, every stored piece triang [cut; the full line is in the log]
    Expected: <0>
      Actual: <752>
    test/opening_cut_test.dart 503:5                    main.<fn>
  00:11 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv7-posRound — (Task 7 review minor 1) the position rounded in the JSON

- **file:** `apps/floor_planner/lib/parametric/opening.dart`; backup `t14-rv7-posRound-opening.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  54c54
  <         'position': position,
  ---
  >         'position': position.roundToDouble(),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_object_test.dart --plain-name 'OR2 (X7-json')` (exit 1; log `t14-rv7-posRound-run1.log`)

  ```
  00:00 +0 -1: OR2 (X7-json, rv7-posRound) save → load → save is byte-identical; a fractional position and width survive it; each typed OpeningParams compares equal; drift() is empty after the load; the same two edits (slide the door, move th [cut; the full line is in the log]
    Expected: OpeningParams:<OpeningParams(gap on 514 at 2600.37, 512.625, start, left)>
      Actual: OpeningParams:<OpeningParams(gap on 514 at 2600.0, 512.625, start, left)>
    test/opening_object_test.dart 178:7                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### End drags (Task 8 and its review)

#### X8-refuse — refuse a drag that pushes an opening past the span

- **file:** `apps/floor_planner/lib/parametric/wall_grips.dart`; backup `t14-X8-refuse-wall_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  56a57,62
  >     for (final (h, p, _) in moved) {
  >       for (final o in d.components.withComponent<OpeningParams>()) {
  >         final q = d.components.get<OpeningParams>(o)!;
  >         if (q.host == h && q.position + q.width / 2 > (p.end - p.start).length) return null;
  >       }
  >     }
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_end_drag_test.dart --plain-name 'EP5 (X8-refuse)')` (exit 1; log `t14-X8-refuse-run1.log`)

  ```
  00:00 +0 -1: EP5 (X8-refuse) an end drag that shortens a wall past its door keeps the stored position: nothing is refused, the door is clamped, then no-fit, and diagnosed; dragging the end back restores its children byte for byte [E]
    Expected: not null
      Actual: <null>
    test/opening_end_drag_test.dart 409:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X8-first — only the dragged wall's openings rewritten

- **file:** `apps/floor_planner/lib/parametric/wall_grips.dart`; backup `t14-X8-first-wall_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  59c59
  <       ..._keptPut(d, moved),
  ---
  >       ..._keptPut(d, [for (final m in moved) if (m.$1 == group) m]),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_end_drag_test.dart --plain-name 'EP1 (M-08p')` (exit 1; log `t14-X8-first-run1.log`)

  ```
  00:00 +0 -1: EP1 (M-08p, M-08p2, X8-first) A and C collinear, back to back, sharing their starts at N; N dragged 700 mm along the line: every opening on both walls stays put in world within 1e-6 (centre and symbol), the stored positions are [cut; the full line is in the log]
    Expected: a value less than <0.000001>
      Actual: <700.0000000002126>
       Which: is not a value less than <0.000001>
    test/opening_end_drag_test.dart 169:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv8-worldLen — (Task 8 review) the lengths measured in world, not local

- **file:** `apps/floor_planner/lib/parametric/wall_grips.dart`; backup `t14-rv8-worldLen-wall_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  75c75,77
  <         rewrite[h] = ((old.end - old.start).length, (p.end - p.start).length);
  ---
  >         final ow = WorldWall(h, old, d.tree.accumulatedTransform(h));
  >         final nw = WorldWall(h, p, d.tree.accumulatedTransform(h));
  >         rewrite[h] = ((ow.e - ow.s).length, (nw.e - nw.s).length);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_end_drag_test.dart)` (exit 1; log `t14-rv8-worldLen-run1.log`)

  ```
  00:00 +0 -1: EP1 (M-08p, M-08p2, X8-first) A and C collinear, back to back, sharing their starts at N; N dragged 700 mm along the line: every opening on both walls stays put in world within 1e-6 (centre and symbol), the stored positions are [cut; the full line is in the log]
    Expected: <600.0000000000418>
      Actual: <599.999999999879>
    test/opening_end_drag_test.dart 173:7               main.<fn>
  00:00 +4 -2: EP5 (start) a 5,000 wall shortened from its start to 1,500, with a door at 600.5 and a window at 3,900: nothing is refused, the positions are L′ − (L − p) (the door's negative: legal, D6), both are clamped and overlap, the wall [cut; the full line is in the log]
    Expected: <-2899.5000000002906>
      Actual: <-2899.5000000000236>
    test/opening_end_drag_test.dart 481:5               main.<fn>
  00:00 +4 -3: EP6 (rv8-noLive) a start drag rewrites only live openings: a stray OpeningParams naming the wall on a group nested under a plain root group, and one on a handle with no node, are left alone (Task 8 review m1) [E]
    Expected: <900.5000000006512>
      Actual: <900.5000000004029>
    test/opening_end_drag_test.dart 552:5               main.<fn>
  00:03 +4 -4: EP7 (t12-keptOld) 200 free walls, each with a door flush against its far end (stored with storedCentreOf, undiagnosed), each start grip dragged once: no door is left opening.clamped; a re-seated door is within wallJoin.linear o [cut; the full line is in the log]
    Expected: non-empty
      Actual: WhereIterable<Diagnostic>:[]
    test/opening_end_drag_test.dart 620:7               main.<fn>
  ... (9 more kept lines in the log)
  00:03 +4 -6: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv8-desc — (Task 8 review) openings rewritten in descending order

- **file:** `apps/floor_planner/lib/parametric/wall_grips.dart`; backup `t14-rv8-desc-wall_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  95c95
  <       openings.sort((a, b) => a.$1.value.compareTo(b.$1.value));
  ---
  >       openings.sort((a, b) => b.$1.value.compareTo(a.$1.value));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_end_drag_test.dart)` (exit 1; log `t14-rv8-desc-run1.log`)

  ```
  00:00 +0 -1: EP1 (M-08p, M-08p2, X8-first) A and C collinear, back to back, sharing their starts at N; N dragged 700 mm along the line: every opening on both walls stays put in world within 1e-6 (centre and symbol), the stored positions are [cut; the full line is in the log]
    Expected: [4000, 4100, 4200]
      Actual: [4100, 4000, 4200]
       Which: at location [0] is <4100> instead of <4000>
    test/opening_end_drag_test.dart 177:5               main.<fn>
  00:04 +9 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv8-noLive — (Task 8 review m1) the liveness check removed

- **file:** `apps/floor_planner/lib/parametric/wall_grips.dart`; backup `t14-rv8-noLive-wall_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  82d81
  <       if (node is! GroupNode || node.parent != d.tree.root) continue;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_end_drag_test.dart --plain-name 'EP6 (rv8-noLive)')` (exit 1; log `t14-rv8-noLive-run1.log`)

  ```
  00:00 +0 -1: EP6 (rv8-noLive) a start drag rewrites only live openings: a stray OpeningParams naming the wall on a group nested under a plain root group, and one on a handle with no node, are left alone (Task 8 review m1) [E]
    Expected: [4000]
      Actual: [4000, 5100, 5200]
       Which: at location [1] is [4000, 5100, 5200] which longer than expected
    test/opening_end_drag_test.dart 548:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### The tools and the shared band cache (Task 9; 07's band joining at its new sites)

#### X9-raw — the host taken from the resolved point

- **file:** `apps/floor_planner/lib/parametric/opening_tool.dart`; backup `t14-X9-raw-opening_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  235c235
  <     final host = _hostAt(doc, _raw);
  ---
  >     final host = _hostAt(doc, point);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT1 (M-08b, X9-raw')` (exit 1; log `t14-X9-raw-run1.log`)

  ```
  Expected: an object with length of <2>
    Actual: [26]
     Which: has length of <1>
  #4      main.<anonymous closure>.place (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_tool_test.dart:243:7)
  #5      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_tool_test.dart:291:16)
  00:02 +0 -1: OT1 (M-08b, X9-raw, X9-unclamped) D, N and G each place one opening with one click and one undo step, centred at the resolved click projected onto the host, at the tool's width; a click near a mitre stores the clamped centre an [cut; the full line is in the log]
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X9-unclamped — the projected `u` stored when clamped

- **file:** `apps/floor_planner/lib/parametric/opening_tool.dart`; backup `t14-X9-unclamped-opening_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  341,343c341
  <     final c = cut == null || !cut.clamped
  <         ? u
  <         : storedCentreOf(layout.stretches, cut, w);
  ---
  >     final c = u;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT1 (M-08b, X9-raw')` (exit 1; log `t14-X9-unclamped-run1.log`)

  ```
  Expected: empty
    Actual: [
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_tool_test.dart:324:5)
  00:02 +0 -1: OT1 (M-08b, X9-raw, X9-unclamped) D, N and G each place one opening with one click and one undo step, centred at the resolved click projected onto the host, at the tool's width; a click near a mitre stores the clamped centre an [cut; the full line is in the log]
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X9-naive — `storedCentreOf` without its ulp search

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-X9-naive-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  249c249
  <   for (var i = 0; i < 8; i++) {
  ---
  >   for (var i = 0; i < 0; i++) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT1 (stored centre, X9-naive)')` (exit 1; log `t14-X9-naive-run1.log`)

  ```
  00:00 +0 -1: OT1 (stored centre, X9-naive) a clamped click is stored where it is drawn and is never clamped from birth: 90 clicks by a mitre and on both sides of a T stem each store the oracle's clamped centre and are not diagnosed; storedC [cut; the full line is in the log]
    Expected: false
      Actual: <true>
    test/opening_tool_test.dart 363:7                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X9-cache — the frame never rebuilt on a document change

- **file:** `apps/floor_planner/lib/parametric/opening_tool.dart`; backup `t14-X9-cache-opening_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  288,290c288
  <     if (host == _frameHost &&
  <         identical(doc, _frameDocument) &&
  <         generation == _frameGeneration) {
  ---
  >     if (host == _frameHost && identical(doc, _frameDocument)) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT4 (X9-cache')` (exit 1; log `t14-X9-cache-run1.log`)

  ```
  00:00 +0 -1: OT4 (X9-cache, M-08h at the preview) with no wall under the pointer no preview is built and no frame computed, and a click commits nothing; over a wall the preview is the symbol the click commits and its cut's two jamb lines, i [cut; the full line is in the log]
    Expected: <2>
      Actual: <1>
    test/opening_tool_test.dart 971:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X9-cacheDoc — the band cache's listener marks stale without a new generation

- **file:** `apps/floor_planner/lib/parametric/wall_bands.dart`; backup `t14-X9-cacheDoc-wall_bands.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  117c117
  <       _changes = doc.changes.listen((_) => invalidate());
  ---
  >       _changes = doc.changes.listen((_) => _stale = true);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT4 (X9-cache')` (exit 1; log `t14-X9-cacheDoc-run1.log`)

  ```
  00:00 +0 -1: OT4 (X9-cache, M-08h at the preview) with no wall under the pointer no preview is built and no frame computed, and a click commits nothing; over a wall the preview is the symbol the click commits and its cut's two jamb lines, i [cut; the full line is in the log]
    Expected: <3>
      Actual: <2>
    test/opening_tool_test.dart 983:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall_bands.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X9-clickRebuild — no rebuild at the click

- **file:** `apps/floor_planner/lib/parametric/opening_tool.dart`; backup `t14-X9-clickRebuild-opening_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  174d173
  <       _bands.invalidate();
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT4 (X9-cache')` (exit 1; log `t14-X9-clickRebuild-run1.log`)

  ```
  00:00 +0 -1: OT4 (X9-cache, M-08h at the preview) with no wall under the pointer no preview is built and no frame computed, and a click commits nothing; over a wall the preview is the symbol the click commits and its cut's two jamb lines, i [cut; the full line is in the log]
    Expected: <2>
      Actual: <1>
    test/opening_tool_test.dart 971:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT4 (t10-scanMemo)')` (exit 1; log `t14-X9-clickRebuild-run2.log`)

  ```
  00:00 +0 -1: OT4 (t10-scanMemo) the host scan is shared by the edge snap and the preview, once per raw point, and never outlives a change: a wall moved away in the same task as a press where the pointer last hovered is not placed on [E]
    Expected: empty
      Actual: [22]
    test/opening_tool_test.dart 1012:5                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### X9-adapter — the document adapter sees no other wall

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-X9-adapter-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  630c630
  <     ],
  ---
  >     ].take(0).toList(),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'HF7 on OG9')` (exit 1; log `t14-X9-adapter-run1.log`)

  ```
  00:00 +0 -1: HF7 on OG9's random plans (50 trials), the document adapter agrees with the view adapter bit for bit: at every opening's gap, frame.at(a, 0) and frame.at(b, 0) are the stored centreline pieces' endpoints, and every wall's store [cut; the full line is in the log]
    Expected: <0>
      Actual: <371>
    test/opening_tool_test.dart 1152:5                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### 07-noend — 07's "no endpoint rule" at its new site in `wall_bands.dart`

- **file:** `apps/floor_planner/lib/parametric/wall_bands.dart`; backup `t14-07-noend-wall_bands.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  100c100
  <     if (along <= t || toEnd <= t) {
  ---
  >     if (false) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/wall_tool_test.dart --plain-name 'WT3 a click on a centreline')` (exit 1; log `t14-07-noend-run1.log`)

  ```
  Expected: [4503564.800075263, 1201839.075969993]
    Actual: [4503462.786708314, 1201786.4473995788]
     Which: at location [0] is <4503462.786708314> instead of <4503564.800075263>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/wall_tool_test.dart:340:5)
  00:02 +0 -1: WT3 a click on a centreline body makes a T whose stem butts the near face; a click on a centreline end makes a node [E]
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall_bands.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### 07-wrongside — 07's "wrong side" at its new site in `wall_bands.dart`

- **file:** `apps/floor_planner/lib/parametric/wall_bands.dart`; backup `t14-07-wrongside-wall_bands.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  62,63c62,63
  <       if (across > c[o + 7] + tol ||
  <           across < c[o + 8] - tol ||
  ---
  >       if (across > -c[o + 8] + tol ||
  >           across < -c[o + 7] - tol ||
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/wall_tool_test.dart --plain-name 'WT3 a click on a centreline')` (exit 1; log `t14-07-wrongside-run1.log`)

  ```
  Expected: a value less than <0.000001>
    Actual: <183.78780851798075>
     Which: is not a value less than <0.000001>
  #4      expectTee (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/wall_tool_test.dart:139:3)
  #5      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/wall_tool_test.dart:357:5)
  00:02 +0 -1: WT3 a click on a centreline body makes a T whose stem butts the near face; a click on a centreline end makes a node [E]
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall_bands.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### 07-highest — 07's "highest handle first" at its new site in `wall_bands.dart`

- **file:** `apps/floor_planner/lib/parametric/wall_bands.dart`; backup `t14-07-highest-wall_bands.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  55c55
  <     for (var i = 0, o = 0; i < _walls; i++, o += _stride) {
  ---
  >     for (var i = _walls - 1, o = (_walls - 1) * _stride; i >= 0; i--, o -= _stride) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/wall_tool_test.dart --plain-name 'WT13 a click inside two crossing bands')` (exit 1; log `t14-07-highest-run1.log`)

  ```
  00:00 +0 -1: WT13 a click inside two crossing bands joins the lower handle (review round 2, m4) [E]
    Expected: a value less than <0.000001>
      Actual: <39.82050807558234>
       Which: is not a value less than <0.000001>
    test/wall_tool_test.dart 661:5                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall_bands.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### Edge snaps and the marker (Task 10, Task 9's minors, the Task 10 review)

#### rv9-hingeRaw — (Task 9 review m1) the hinge from the raw projection, not the stored centre

- **file:** `apps/floor_planner/lib/parametric/opening_tool.dart`; backup `t14-rv9-hingeRaw-opening_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  350c350
  <           hinge: c <= f.len / 2 ? HingeEnd.start : HingeEnd.end,
  ---
  >           hinge: u <= f.len / 2 ? HingeEnd.start : HingeEnd.end,
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT2 (rv9-hingeRaw)')` (exit 1; log `t14-rv9-hingeRaw-run1.log`)

  ```
  00:00 +0 -1: OT2 (rv9-hingeRaw) the hinge follows the stored centre, not the click: a click at 2,400 on a 5,000 host runs into a T obstacle at [2,300, 2,420], is clamped past L/2 and hangs on the end jamb (Task 9 review m1) [E]
    Expected: HingeEnd:<HingeEnd.end>
      Actual: HingeEnd:<HingeEnd.start>
    test/opening_tool_test.dart 478:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv9-swingResolved — (Task 9 review m2) the swing from the resolved point

- **file:** `apps/floor_planner/lib/parametric/opening_tool.dart`; backup `t14-rv9-swingResolved-opening_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  347c347
  <         (toLocal.transformPoint(raw) - f.s).dot(f.n) - (f.lOff + f.rOff) / 2;
  ---
  >         (toLocal.transformPoint(resolved) - f.s).dot(f.n) - (f.lOff + f.rOff) / 2;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT2 (rv9-swingResolved)')` (exit 1; log `t14-rv9-swingResolved-run1.log`)

  ```
  00:00 +0 -1: OT2 (rv9-swingResolved) the swing follows the raw click, not the resolved point: at 0.15 px/mm, clicks 30 mm either side of a centred wall at 2,510 snap to its centreline's midpoint, and still swing left and right (Task 9 revie [cut; the full line is in the log]
    Expected: SwingSide:<SwingSide.left>
      Actual: SwingSide:<SwingSide.right>
    test/opening_tool_test.dart 505:7                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv9-selfFirst — (Task 9 review m3) the new opening admitted first

- **file:** `apps/floor_planner/lib/parametric/opening_tool.dart`; backup `t14-rv9-selfFirst-opening_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  244c244
  <         final placed = _place(host, _raw, point, h);
  ---
  >         final placed = _place(host, _raw, point, const Handle(1));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT1 (rv9-selfFirst)')` (exit 1; log `t14-rv9-selfFirst-run1.log`)

  ```
  00:00 +0 -1: OT1 (rv9-selfFirst) the new opening is admitted with the handle its commit allocates, after the host's openings: an 800 door clicked at 1,700 on a 2,000 wall whose 1,200 window cuts [0, 1,200] would leave no piece, so it is no- [cut; the full line is in the log]
    Expected: a numeric value within <0.000001> of <1700>
      Actual: <1600.0000000017133>
       Which:  differs by <99.99999999828674>
    test/opening_tool_test.dart 537:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv9-guardDNG — (Task 9 review m4) D, N, G missing from the text guard

- **file:** `apps/floor_planner/lib/shortcut_guard.dart`; backup `t14-rv9-guardDNG-shortcut_guard.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  12,14d11
  <   LogicalKeyboardKey.keyD,
  <   LogicalKeyboardKey.keyN,
  <   LogicalKeyboardKey.keyG,
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT1 (rv9-guardDNG)')` (exit 1; log `t14-rv9-guardDNG-run1.log`)

  ```
  Expected: false
    Actual: <true>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_tool_test.dart:608:7)
  00:01 +0 -1: OT1 (rv9-guardDNG) D, N and G typed into the Text tool's field and into the page panel's scale field are text, not shortcuts (as planner_draw_test.dart's A8 and A9) [E]
  00:01 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/shortcut_guard.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t10-noLive — (Task 9 review m5) `WallBands` caches non-live wall components

- **file:** `apps/floor_planner/lib/parametric/wall_bands.dart`; backup `t14-t10-noLive-wall_bands.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  130c130
  <       if (node is! GroupNode || node.parent != doc.tree.root) continue;
  ---
  >       if (node == node) {}
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT1 (liveness)')` (exit 1; log `t14-t10-noLive-run1.log`)

  ```
  00:00 +0 -1: OT1 (liveness) a stray WallParams on a handle with no node, or on a nested group, lying over a live wall at a lower handle, is not a host: D places on the live wall (Task 9 review m5) [E]
    Expected: an object with length of <1>
      Actual: []
       Which: has length of <0>
    test/opening_tool_test.dart 589:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall_bands.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t10-noParent — (Task 9 review m5) `WallBands` accepts a nested group

- **file:** `apps/floor_planner/lib/parametric/wall_bands.dart`; backup `t14-t10-noParent-wall_bands.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  130c130
  <       if (node is! GroupNode || node.parent != doc.tree.root) continue;
  ---
  >       if (node is! GroupNode) continue;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT1 (liveness)')` (exit 1; log `t14-t10-noParent-run1.log`)

  ```
  00:00 +0 -1: OT1 (liveness) a stray WallParams on a handle with no node, or on a nested group, lying over a live wall at a lower handle, is not a host: D places on the live wall (Task 9 review m5) [E]
    Expected: an object with length of <1>
      Actual: []
       Which: has length of <0>
    test/opening_tool_test.dart 589:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall_bands.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X10-gate — edge snaps ignore F3

- **file:** `apps/floor_planner/lib/parametric/opening_tool.dart`; backup `t14-X10-gate-opening_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  187c187
  <     if (ctx == null || !(ctx.snap?.objectSnap ?? true)) return null;
  ---
  >     if (ctx == null) return null;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT3 (M-08sn, X10-gate)')` (exit 1; log `t14-X10-gate-run1.log`)

  ```
  00:00 +0 -1: OT3 (M-08sn, X10-gate) a door's edge snaps to a T obstacle's edges, to a window's drawn edges and to the span's end, the nearer candidate winning; with F3 off it stores the chain's projected point [E]
    Expected: a numeric value within <0.000001> of <2447.4067584377062>
      Actual: <2434.4067584377062>
       Which:  differs by <13.0>
    test/opening_tool_test.dart 730:7                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X10-marker — `markerPoint` not overridden

- **file:** `apps/floor_planner/lib/parametric/opening_tool.dart`; backup `t14-X10-marker-opening_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  213c213
  <   Vector2 get markerPoint => _onHost ? _marker : super.markerPoint;
  ---
  >   Vector2 get markerPoint => super.markerPoint;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT5 (X10-marker)')` (exit 1; log `t14-X10-marker-run1.log`)

  ```
  00:00 +0 -1: OT5 (X10-marker) the snap marker is painted at the projected point on the host's centreline, not at the chain's point; off every wall, at the chain's point [E]
    Expected: a value less than <0.000001>
      Actual: <35.00000000001649>
       Which: is not a value less than <0.000001>
    test/opening_tool_test.dart 886:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t10-nearest — the first candidate wins, not the nearest

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-t10-nearest-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  348c348
  <     if (distance < bestDistance ||
  ---
  >     if (best == null ||
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT3 (M-08sn, pure)')` (exit 1; log `t14-t10-nearest-run1.log`)

  ```
  00:00 +0 -1: OT3 (M-08sn, pure) edgeSnap: an edge within the aperture of a stretch end or another opening's cut edge moves the centre to put it there; the nearest pair wins, ties go to the lower centre, nothing in range gives null [E]
    Expected: <1403>
      Actual: <1400.0>
    test/opening_tool_test.dart 654:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t10-tieHigh — ties go to the higher centre

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-t10-tieHigh-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  349c349
  <         (distance == bestDistance && centre < best!)) {
  ---
  >         (distance == bestDistance && centre > best!)) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT3 (M-08sn, pure)')` (exit 1; log `t14-t10-tieHigh-run1.log`)

  ```
  00:00 +0 -1: OT3 (M-08sn, pure) edgeSnap: an edge within the aperture of a stretch end or another opening's cut edge moves the centre to put it there; the nearest pair wins, ties go to the lower centre, nothing in range gives null [E]
    Expected: <1400>
      Actual: <1403.0>
    test/opening_tool_test.dart 657:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t10-strict — the aperture boundary excluded

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-t10-strict-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  347c347
  <     if (distance > aperture) return;
  ---
  >     if (distance >= aperture) return;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT3 (M-08sn, pure)')` (exit 1; log `t14-t10-strict-run1.log`)

  ```
  00:00 +0 -1: OT3 (M-08sn, pure) edgeSnap: an edge within the aperture of a stretch end or another opening's cut edge moves the centre to put it there; the nearest pair wins, ties go to the lower centre, nothing in range gives null [E]
    Expected: <537.25>
      Actual: <null>
    test/opening_tool_test.dart 648:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t10-noCuts — other openings' cuts not candidates

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-t10-noCuts-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  364c364
  <   for (final (a, b) in otherCuts) {
  ---
  >   for (final (a, b) in const <(double, double)>[]) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT3 (M-08sn, pure)')` (exit 1; log `t14-t10-noCuts-run1.log`)

  ```
  00:00 +0 -1: OT3 (M-08sn, pure) edgeSnap: an edge within the aperture of a stretch end or another opening's cut edge moves the centre to put it there; the nearest pair wins, ties go to the lower centre, nothing in range gives null [E]
    Expected: <2600.5>
      Actual: <null>
    test/opening_tool_test.dart 644:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t10-noStretch — stretch ends not candidates

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-t10-noStretch-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  360c360
  <   for (final (a, b) in stretches) {
  ---
  >   for (final (a, b) in const <(double, double)>[]) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT3 (M-08sn, pure)')` (exit 1; log `t14-t10-noStretch-run1.log`)

  ```
  00:00 +0 -1: OT3 (M-08sn, pure) edgeSnap: an edge within the aperture of a stretch end or another opening's cut edge moves the centre to put it there; the nearest pair wins, ties go to the lower centre, nothing in range gives null [E]
    Expected: <537.25>
      Actual: <null>
    test/opening_tool_test.dart 641:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t10-reproject — the snapped centre re-projected, not stored exactly

- **file:** `apps/floor_planner/lib/parametric/opening_tool.dart`; backup `t14-t10-reproject-opening_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  336c336
  <         ? _edgeU
  ---
  >         ? f.uOf(toLocal.transformPoint(resolved))
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT3 (M-08sn, X10-gate)')` (exit 1; log `t14-t10-reproject-run1.log`)

  ```
  00:00 +0 -1: OT3 (M-08sn, X10-gate) a door's edge snaps to a T obstacle's edges, to a window's drawn edges and to the span's end, the nearer candidate winning; with F3 off it stores the chain's projected point [E]
    Expected: a numeric value within <1e-11> of <2017.6326980715676>
      Actual: <2017.6326980712784>
       Which:  differs by <2.892193151637912e-10>
    test/opening_tool_test.dart 727:7                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t10-scanMemo — the host-scan memo ignores the generation

- **file:** `apps/floor_planner/lib/parametric/opening_tool.dart`; backup `t14-t10-scanMemo-opening_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  271c271
  <         _bands.generation == _scanGeneration &&
  ---
  >         _scanGeneration == _scanGeneration &&
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT4 (t10-scanMemo)')` (exit 1; log `t14-t10-scanMemo-run1.log`)

  ```
  00:00 +0 -1: OT4 (t10-scanMemo) the host scan is shared by the edge snap and the preview, once per raw point, and never outlives a change: a wall moved away in the same task as a press where the pointer last hovered is not placed on [E]
    Expected: empty
      Actual: [22]
    test/opening_tool_test.dart 1012:5                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t10-renderMarker — (render, B12) `paintOverlay` paints at `hoverPoint`, not `markerPoint`

- **file:** `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart`; backup `t14-t10-renderMarker-placement_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  276c276
  <     final p = markerPoint;
  ---
  >     final p = hoverPoint;
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/draw/placement_tool_test.dart --plain-name 'B12 the snap marker')` (exit 1; log `t14-t10-renderMarker-run1.log`)

  ```
  00:00 +0 -1: B12 the snap marker is drawn at markerPoint: the Line tool's is its hover point; a tool that overrides it is marked there, with the chain's kind (Ruling 08-14) [E]
    Expected: a numeric value within <0.000001> of <344.08190402794025>
      Actual: <339.62455877686625>
       Which:  differs by <4.457345251074003>
    test/draw/placement_tool_test.dart 274:7            main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT5 (X10-marker)')` (exit 1; log `t14-t10-renderMarker-run2.log`)

  ```
  00:00 +0 -1: OT5 (X10-marker) the snap marker is painted at the projected point on the host's centreline, not at the chain's point; off every wall, at the chain's point [E]
    Expected: a value less than <0.000001>
      Actual: <35.00000000001649>
       Which: is not a value less than <0.000001>
    test/opening_tool_test.dart 886:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### t10-apertureLocal-tool — the aperture in world units, not the host's local units

- **file:** `apps/floor_planner/lib/parametric/opening_tool.dart`; backup `t14-t10-apertureLocal-tool-opening_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  202c202
  <         apertureWorld / toWorld.transformDirection(f.d).length);
  ---
  >         apertureWorld);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT3 (M-08sn, X10-gate)')` (exit 1; log `t14-t10-apertureLocal-tool-run1.log`)

  ```
  00:00 +0 -1: OT3 (M-08sn, X10-gate) a door's edge snaps to a T obstacle's edges, to a window's drawn edges and to the span's end, the nearer candidate winning; with F3 off it stores the chain's projected point [E]
    Expected: a numeric value within <0.000001> of <1685.0>
      Actual: <1700.0000000004231>
       Which:  differs by <15.000000000423142>
    test/opening_tool_test.dart 752:7                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT3 (t11-apertureDir)')` (exit 1; log `t14-t10-apertureLocal-tool-run2.log`)

  ```
  00:00 +0 -1: OT3 (t11-apertureDir) on a host scaled non-uniformly the aperture is measured along its centreline: an edge within the world aperture snaps, one just beyond it does not [E]
    Expected: a numeric value within <0.000001> of <678.1742942920065>
      Actual: <688.9694131269387>
       Which:  differs by <10.795118834932168>
    test/opening_tool_test.dart 848:7                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### rv10-stickyEdge — (Task 10 review) the edge-snap flag never reset

- **file:** `apps/floor_planner/lib/parametric/opening_tool.dart`; backup `t14-rv10-stickyEdge-opening_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  185d184
  <     _edgeSnapped = false;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart)` (exit 1; log `t14-rv10-stickyEdge-run1.log`)

  ```
  00:02 +9 -1: OT3 (M-08sn, X10-gate) a door's edge snaps to a T obstacle's edges, to a window's drawn edges and to the span's end, the nearer candidate winning; with F3 off it stores the chain's projected point [E]
    Expected: a numeric value within <0.000001> of <2459.4067584377062>
      Actual: <2587.4067584377044>
       Which:  differs by <127.99999999999818>
    test/opening_tool_test.dart 734:5                   main.<fn>
  00:02 +9 -2: OT3 (rv10-storedCuts) another opening's candidates are its drawn edges: a clamped window's drawn edge attracts a door and its stored edge does not; a no-fit opening's stored edges attract nothing [E]
    Expected: a numeric value within <0.000001> of <3339.4067584377044>
      Actual: <3434.4067584377062>
       Which:  differs by <95.00000000000182>
    test/opening_tool_test.dart 808:7                   main.<fn>
  00:02 +9 -3: OT3 (t11-apertureDir) on a host scaled non-uniformly the aperture is measured along its centreline: an edge within the world aperture snaps, one just beyond it does not [E]
    Expected: a numeric value within <0.000001> of <678.1742942920065>
      Actual: <688.9694131269387>
       Which:  differs by <10.795118834932168>
    test/opening_tool_test.dart 848:7                   main.<fn>
  00:03 +14 -3: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv10-onHostStale — (Task 10 review) the marker flag not reset off a host

- **file:** `apps/floor_planner/lib/parametric/opening_tool.dart`; backup `t14-rv10-onHostStale-opening_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  223d222
  <       _onHost = false;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart)` (exit 1; log `t14-rv10-onHostStale-run1.log`)

  ```
  00:02 +12 -1: OT5 (X10-marker) the snap marker is painted at the projected point on the host's centreline, not at the chain's point; off every wall, at the chain's point [E]
    Expected: a value less than <0.000001>
      Actual: <450.00000000015433>
       Which: is not a value less than <0.000001>
    test/opening_tool_test.dart 891:5                   main.<fn>
  00:03 +16 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv10-scanNoGen — (Task 10 review) the scan memo without its generation check

- **file:** `apps/floor_planner/lib/parametric/opening_tool.dart`; backup `t14-rv10-scanNoGen-opening_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  271d270
  <         _bands.generation == _scanGeneration &&
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart)` (exit 1; log `t14-rv10-scanNoGen-run1.log`)

  ```
  00:02 +14 -1: OT4 (t10-scanMemo) the host scan is shared by the edge snap and the preview, once per raw point, and never outlives a change: a wall moved away in the same task as a press where the pointer last hovered is not placed on [E]
    Expected: empty
      Actual: [22]
    test/opening_tool_test.dart 1012:5                  main.<fn>
  00:03 +16 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### Grips and movable (Task 11, Task 10's minors, the Task 11 review)

#### rv10-storedCuts — (Task 10 review m1) other openings' stored, not drawn, edges

- **file:** `apps/floor_planner/lib/parametric/opening_tool.dart`; backup `t14-rv10-storedCuts-opening_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  311,314c311
  <             for (final c in cutsOf(layout.frame, layout.stretches, [
  <               for (final (_, c, w) in _others) (c, w),
  <             ]).cuts)
  <               if (c != null) (c.a, c.b),
  ---
  >             for (final (_, c, w) in _others) (c - w / 2, c + w / 2),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT3 (rv10-storedCuts)')` (exit 1; log `t14-rv10-storedCuts-run1.log`)

  ```
  00:00 +0 -1: OT3 (rv10-storedCuts) another opening's candidates are its drawn edges: a clamped window's drawn edge attracts a door and its stored edge does not; a no-fit opening's stored edges attract nothing [E]
    Expected: a numeric value within <0.000001> of <3434.4067584377044>
      Actual: <3446.4067584383356>
       Which:  differs by <12.00000000063119>
    test/opening_tool_test.dart 808:7                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t11-noFitStored — (Task 11) a no-fit neighbour's stored interval offered as edges

- **file:** `apps/floor_planner/lib/parametric/opening_tool.dart`; backup `t14-t11-noFitStored-opening_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  311c311
  <             for (final c in cutsOf(layout.frame, layout.stretches, [
  ---
  >             for (final (i, c) in cutsOf(layout.frame, layout.stretches, [
  313,314c313,318
  <             ]).cuts)
  <               if (c != null) (c.a, c.b),
  ---
  >             ]).cuts.indexed)
  >               if (c != null)
  >                 (c.a, c.b)
  >               else
  >                 (_others[i].$2 - _others[i].$3 / 2,
  >                   _others[i].$2 + _others[i].$3 / 2),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT3 (rv10-storedCuts)')` (exit 1; log `t14-t11-noFitStored-run1.log`)

  ```
  00:00 +0 -1: OT3 (rv10-storedCuts) another opening's candidates are its drawn edges: a clamped window's drawn edge attracts a door and its stored edge does not; a no-fit opening's stored edges attract nothing [E]
    Expected: a numeric value within <0.000001> of <3528.4067584377044>
      Actual: <3534.4067584377044>
       Which:  differs by <6.0>
    test/opening_tool_test.dart 808:7                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t11-apertureDir-tool — (Task 10 review m2) the aperture divided by `√|det|`, the tool's site

- **file:** `apps/floor_planner/lib/parametric/opening_tool.dart`; backup `t14-t11-apertureDir-tool-opening_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  202c202
  <         apertureWorld / toWorld.transformDirection(f.d).length);
  ---
  >         apertureWorld / toWorld.scaleMagnitude);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart --plain-name 'OT3 (t11-apertureDir)')` (exit 1; log `t14-t11-apertureDir-tool-run1.log`)

  ```
  00:00 +0 -1: OT3 (t11-apertureDir) on a host scaled non-uniformly the aperture is measured along its centreline: an edge within the world aperture snaps, one just beyond it does not [E]
    Expected: a numeric value within <0.000001> of <678.1742942920065>
      Actual: <688.9694131269387>
       Which:  differs by <10.795118834932168>
    test/opening_tool_test.dart 848:7                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t11-apertureDir-grip — (Task 10 review m2) the same at the slide grip's site

- **file:** `apps/floor_planner/lib/parametric/opening_grips.dart`; backup `t14-t11-apertureDir-grip-opening_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  163c163
  <           apertureWorld / toWorld.transformDirection(f.d).length);
  ---
  >           apertureWorld / toWorld.scaleMagnitude);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart)` (exit 0; log `t14-t11-apertureDir-grip-run1.log`)

  ```
  00:02 +7: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** SURVIVED (0 of 1 commands red). SURVIVED `opening_grips_test.dart` whole, in the first run. **Superseded by fix round 1** (`fr1-t11-apertureDir-grip`, killed).

#### t11-apertureDir-grip-full — the grip's site against the whole app suite

- **file:** `apps/floor_planner/lib/parametric/opening_grips.dart`; backup `t14-t11-apertureDir-grip-full-opening_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  163c163
  <           apertureWorld / toWorld.transformDirection(f.d).length);
  ---
  >           apertureWorld / toWorld.scaleMagnitude);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test)` (exit 0; log `t14-t11-apertureDir-grip-full-run1.log`)

  ```
  00:44 +232: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** SURVIVED (0 of 1 commands red). SURVIVED the whole app suite, in the first run: finding F1. The tool's copy of this divisor is killed by `OT3 (t11-apertureDir)`; the grip's copy had no test on a non-uniformly scaled host until fix round 1.

#### X11-rotgrip — `hitsRotationGrip` ignores `rotatable`

- **file:** `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; backup `t14-X11-rotgrip-grip_cache.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  299,300c299,300
  <     if (!rotatable) return false;
  <     final b = _box!;
  ---
  >     final b = _box;
  >     if (b == null) return false;
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/object_grips_test.dart --plain-name 'MV2 (X11-rotgrip')` (exit 1; log `t14-X11-rotgrip-run1.log`)

  ```
  00:00 +0 -1: MV2 (X11-rotgrip, M-08i) the rotation grip needs a movable key: an immovable group alone has a box but is not rotatable, and its grip is neither hit nor pressed; beside a movable key it is [E]
    Expected: false
      Actual: <true>
    test/object_grips_test.dart 461:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X11-cursor — the move cursor over an immovable key

- **file:** `packages/jet_cad_2d_flutter/lib/src/select_tool.dart`; backup `t14-X11-cursor-select_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  196,197c196
  <         ctx.selection.contains(key) &&
  <         movableKey(ctx.document, key, grips?.objects)) {
  ---
  >         ctx.selection.contains(key)) {
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/object_grips_test.dart --plain-name 'MV3 (X11-cursor')` (exit 1; log `t14-X11-cursor-run1.log`)

  ```
  00:00 +0 -1: MV3 (X11-cursor, M-08i) through the select tool, at all four of its call sites: a body drag on a selected or unselected immovable group stays a click with no command and hovering it shows no move cursor; a centre grip and the r [cut; the full line is in the log]
    Expected: not SystemMouseCursor:<SystemMouseCursor(move)>
      Actual: SystemMouseCursor:<SystemMouseCursor(move)>
    test/object_grips_test.dart 496:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/select_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X11-site1 — select tool call site 1 without `objects`

- **file:** `packages/jet_cad_2d_flutter/lib/src/select_tool.dart`; backup `t14-X11-site1-select_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  219,220c219
  <         final drag = GripDrag.move(ctx.document, ctx.selection.keys,
  <             objects: ctx.grips?.objects);
  ---
  >         final drag = GripDrag.move(ctx.document, ctx.selection.keys);
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/object_grips_test.dart --plain-name 'MV3 (X11-cursor')` (exit 1; log `t14-X11-site1-run1.log`)

  ```
  00:00 +0 -1: MV3 (X11-cursor, M-08i) through the select tool, at all four of its call sites: a body drag on a selected or unselected immovable group stays a click with no command and hovering it shows no move cursor; a centre grip and the r [cut; the full line is in the log]
    Expected: null
      Actual: DragKind:<DragKind.move>
    test/object_grips_test.dart 499:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/select_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X11-site2 — call site 2 without `objects`

- **file:** `packages/jet_cad_2d_flutter/lib/src/select_tool.dart`; backup `t14-X11-site2-select_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  233c233
  <             GripDrag.move(ctx.document, next, objects: ctx.grips?.objects);
  ---
  >             GripDrag.move(ctx.document, next);
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/object_grips_test.dart --plain-name 'MV3 (X11-cursor')` (exit 1; log `t14-X11-site2-run1.log`)

  ```
  00:00 +0 -1: MV3 (X11-cursor, M-08i) through the select tool, at all four of its call sites: a body drag on a selected or unselected immovable group stays a click with no command and hovering it shows no move cursor; a centre grip and the r [cut; the full line is in the log]
    Expected: null
      Actual: DragKind:<DragKind.move>
    test/object_grips_test.dart 509:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/select_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X11-site3 — call site 3 without `objects`

- **file:** `packages/jet_cad_2d_flutter/lib/src/select_tool.dart`; backup `t14-X11-site3-select_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  257c257
  <             ? GripDrag.move(ctx.document, ctx.selection.keys, objects: objects)
  ---
  >             ? GripDrag.move(ctx.document, ctx.selection.keys)
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/object_grips_test.dart --plain-name 'MV3 (X11-cursor')` (exit 1; log `t14-X11-site3-run1.log`)

  ```
  00:00 +0 -1: MV3 (X11-cursor, M-08i) through the select tool, at all four of its call sites: a body drag on a selected or unselected immovable group stays a click with no command and hovering it shows no move cursor; a centre grip and the r [cut; the full line is in the log]
    Expected: GroupNode:<GroupNode(19, 0 children)>
      Actual: GroupNode:<GroupNode(19, 0 children)>
    test/object_grips_test.dart 525:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/select_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X11-site4 — call site 4 (rotate) without `objects`

- **file:** `packages/jet_cad_2d_flutter/lib/src/select_tool.dart`; backup `t14-X11-site4-select_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  280,281c280
  <             ctx.document, ctx.selection.keys, pivot, _pressWorld,
  <             objects: ctx.grips?.objects);
  ---
  >             ctx.document, ctx.selection.keys, pivot, _pressWorld);
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/object_grips_test.dart --plain-name 'MV3 (X11-cursor')` (exit 1; log `t14-X11-site4-run1.log`)

  ```
  00:00 +0 -1: MV3 (X11-cursor, M-08i) through the select tool, at all four of its call sites: a body drag on a selected or unselected immovable group stays a click with no command and hovering it shows no move cursor; a centre grip and the r [cut; the full line is in the log]
    Expected: GroupNode:<GroupNode(19, 0 children)>
      Actual: GroupNode:<GroupNode(19, 0 children)>
    test/object_grips_test.dart 538:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/select_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X11-stored — the grip at the stored centre

- **file:** `apps/floor_planner/lib/parametric/opening_grips.dart`; backup `t14-X11-stored-opening_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  57c57
  <     final u = c == null ? s.params.position : (c.a + c.b) / 2;
  ---
  >     final u = s.params.position;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart --plain-name 'SG1 (X11-stored')` (exit 1; log `t14-X11-stored-run1.log`)

  ```
  00:00 +0 -1: SG1 (X11-stored, M-08sn, M-08b, rv11-selfCand) the provider: a clamped door's grip sits at its cut's centre, a no-fit's at its stored centre; a drag projects, edge-snaps to an obstacle edge, and stores the placed centre, the cl [cut; the full line is in the log]
    Expected: a value less than <0.000001>
      Actual: <150.00000000001032>
       Which: is not a value less than <0.000001>
    test/opening_grips_test.dart 196:5                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X11-gate — the grip's edge snaps ignore F3

- **file:** `apps/floor_planner/lib/main.dart`; backup `t14-X11-gate-main.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  233,235c233
  <           edgeAperture: () => _snap.objectSnap
  <               ? kSnapAperturePixels / _camera.value.scale
  <               : null));
  ---
  >           edgeAperture: () => kSnapAperturePixels / _camera.value.scale));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart --plain-name 'SG1 (shell)')` (exit 1; log `t14-X11-gate-run1.log`)

  ```
  Expected: a numeric value within <0.000001> of <1544.0724543170409>
    Actual: <1567.6326980715676>
     Which:  differs by <23.56024375452671>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_grips_test.dart:323:5)
  00:02 +0 -1: SG1 (shell) the slide grip is shown at the drawn centre; a drag edge-snaps while object snap is on and is one undo step; with F3 off it stores the grid point projected; under runtime permissions the grip is not hit [E]
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/main.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t11-clampNoFit — a no-fit drag not clamped to the wall

- **file:** `apps/floor_planner/lib/parametric/opening_grips.dart`; backup `t14-t11-clampNoFit-opening_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  168c168
  <       final c = u < 0 ? 0.0 : (u > f.len ? f.len : u);
  ---
  >       final c = u;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart --plain-name 'SG1 (X11-stored')` (exit 1; log `t14-t11-clampNoFit-run1.log`)

  ```
  00:00 +0 -1: SG1 (X11-stored, M-08sn, M-08b, rv11-selfCand) the provider: a clamped door's grip sits at its cut's centre, a no-fit's at its stored centre; a drag projects, edge-snaps to an obstacle edge, and stores the placed centre, the cl [cut; the full line is in the log]
    Expected: a numeric value within <0.000001> of <6000.000000000763>
      Actual: <6700.000000001053>
       Which:  differs by <700.0000000002901>
    test/opening_grips_test.dart 264:7                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t11-unclamped — a clamped drag stored unseated

- **file:** `apps/floor_planner/lib/parametric/opening_grips.dart`; backup `t14-t11-unclamped-opening_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  171c171
  <     if (!cut.clamped) return (centre: u, cut: cut);
  ---
  >     return (centre: u, cut: cut);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart --plain-name 'SG1 (X11-stored')` (exit 1; log `t14-t11-unclamped-run1.log`)

  ```
  00:00 +0 -1: SG1 (X11-stored, M-08sn, M-08b, rv11-selfCand) the provider: a clamped door's grip sits at its cut's centre, a no-fit's at its stored centre; a drag projects, edge-snaps to an obstacle edge, and stores the placed centre, the cl [cut; the full line is in the log]
    Expected: a numeric value within <0.000001> of <2584.4067584377044>
      Actual: <2334.40675843777>
       Which:  differs by <249.99999999993452>
    test/opening_grips_test.dart 251:5                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t11-exactNull — (adapted to Task 12's rule) the within-tolerance no-change rule removed

- **file:** `apps/floor_planner/lib/parametric/opening_grips.dart`; backup `t14-t11-exactNull-opening_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  72,75d71
  <     if ((placed.centre - p.position).abs() <= wallJoin.linear &&
  <         s.cut?.clamped != true) {
  <       return null;
  <     }
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart --plain-name 'SG1 (X11-stored')` (exit 1; log `t14-t11-exactNull-run1.log`)

  ```
  00:00 +0 -1: SG1 (X11-stored, M-08sn, M-08b, rv11-selfCand) the provider: a clamped door's grip sits at its cut's centre, a no-fit's at its stored centre; a drag projects, edge-snaps to an obstacle edge, and stores the placed centre, the cl [cut; the full line is in the log]
    Expected: null
      Actual: <Instance of 'SetComponentCommand<OpeningParams>'>
    test/opening_grips_test.dart 237:5                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv11-previewSnap — (Task 11 review) the preview without the edge snap

- **file:** `apps/floor_planner/lib/parametric/opening_grips.dart`; backup `t14-rv11-previewSnap-opening_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  85c85
  <     final cut = s.place(world, edgeAperture()).cut;
  ---
  >     final cut = s.place(world, null).cut;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart)` (exit 1; log `t14-rv11-previewSnap-run1.log`)

  ```
  00:00 +0 -1: SG1 (X11-stored, M-08sn, M-08b, rv11-selfCand) the provider: a clamped door's grip sits at its cut's centre, a no-fit's at its stored centre; a drag projects, edge-snaps to an obstacle edge, and stores the placed centre, the cl [cut; the full line is in the log]
    Expected: a value less than <0.000001>
      Actual: <8.999999999939593>
       Which: is not a value less than <0.000001>
    test/opening_grips_test.dart 214:7                  main.<fn>
  00:02 +6 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### The Opening section and the re-seat (Task 12, Task 11's I1 and minors)

#### t12-keptOld — (Task 11 I1) the D13 rewrite without the re-seat

- **file:** `apps/floor_planner/lib/parametric/wall_grips.dart`; backup `t14-t12-keptOld-wall_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  103c103
  <                     : _seated(stretches, p, params.width))));
  ---
  >                     : p)));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_end_drag_test.dart --plain-name 'EP7 (t12-keptOld)')` (exit 1; log `t14-t12-keptOld-run1.log`)

  ```
  00:03 +0 -1: EP7 (t12-keptOld) 200 free walls, each with a door flush against its far end (stored with storedCentreOf, undiagnosed), each start grip dragged once: no door is left opening.clamped; a re-seated door is within wallJoin.linear o [cut; the full line is in the log]
    Expected: an object with length of <0>
      Actual: [
       Which: has length of <97>
    test/opening_end_drag_test.dart 605:5               main.<fn>
  00:03 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t12-keptAll — (Task 11 I1) every clamped rewrite re-seated

- **file:** `apps/floor_planner/lib/parametric/wall_grips.dart`; backup `t14-t12-keptAll-wall_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  119c119
  <         !((cut.a - (c - w / 2)).abs() <= wallJoin.linear)) {
  ---
  >         false) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_end_drag_test.dart --plain-name 'EP5 (start)')` (exit 1; log `t14-t12-keptAll-run1.log`)

  ```
  00:00 +0 -1: EP5 (start) a 5,000 wall shortened from its start to 1,500, with a door at 600.5 and a window at 3,900: nothing is refused, the positions are L′ − (L − p) (the door's negative: legal, D6), both are clamped and overlap, the wall [cut; the full line is in the log]
    Expected: <-2899.5000000002906>
      Actual: <449.9999999997205>
    test/opening_end_drag_test.dart 481:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t12-gripOld — (Task 11 I1) the grip's old no-change rule

- **file:** `apps/floor_planner/lib/parametric/opening_grips.dart`; backup `t14-t12-gripOld-opening_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  69,75c69
  <     if (placed.centre == p.position) return null;
  <     // Within the tolerance a drag changes nothing, unless the opening is
  <     // drawn clamped now: then the drag re-seats it where it is drawn.
  <     if ((placed.centre - p.position).abs() <= wallJoin.linear &&
  <         s.cut?.clamped != true) {
  <       return null;
  <     }
  ---
  >     if ((placed.centre - p.position).abs() <= wallJoin.linear) return null;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart --plain-name 'SG3 (t12-gripOld) a door drawn')` (exit 1; log `t14-t12-gripOld-run1.log`)

  ```
  00:00 +0 -1: SG3 (t12-gripOld) a door drawn clamped by 1e-7 (by hand) is re-seated by a drag onto its own edge: after it, it is stored where it is drawn and not diagnosed (Task 11 review I1) [E]
    Expected: not null
      Actual: <null>
    test/opening_grips_test.dart 452:5                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart --plain-name 'SG3 (t12-gripOld, old D13)')` (exit 1; log `t14-t12-gripOld-run2.log`)

  ```
  00:00 +0 -1: SG3 (t12-gripOld, old D13) a door left an ulp outside its stretch by the old D13 rewrite L′ − (L − p) is re-seated by a drag onto its own edge: after it, it is stored where it is drawn and not diagnosed (Task 11 review I1) [E]
    Expected: not null
      Actual: <null>
    test/opening_grips_test.dart 505:7                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### rv11-selfCand — (Task 11 review m1) the grip offers its own cut as a candidate

- **file:** `apps/floor_planner/lib/parametric/opening_grips.dart`; backup `t14-rv11-selfCand-opening_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  158c158
  <               if (j != index && c != null) (c.a, c.b),
  ---
  >               if (c != null) (c.a, c.b),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart --plain-name 'SG1 (X11-stored')` (exit 1; log `t14-rv11-selfCand-run1.log`)

  ```
  00:00 +0 -1: SG1 (X11-stored, M-08sn, M-08b, rv11-selfCand) the provider: a clamped door's grip sits at its cut's centre, a no-fit's at its stored centre; a drag projects, edge-snaps to an obstacle edge, and stores the placed centre, the cl [cut; the full line is in the log]
    Expected: not null
      Actual: <null>
    test/opening_grips_test.dart 276:5                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv11-fillMovable — (Task 11 review m2) a boxless key counted as movable

- **file:** `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; backup `t14-rv11-fillMovable-grip_cache.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  323a324
  >       if (!_movable) _movable = movableKey(document, key, objects);
  326d326
  <         if (!_movable) _movable = movableKey(document, key, objects);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart --plain-name 'SG4 (rv11-fillMovable)')` (exit 1; log `t14-rv11-fillMovable-run1.log`)

  ```
  Expected: false
    Actual: <true>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_grips_test.dart:549:5)
  00:01 +0 -1: SG4 (rv11-fillMovable) a root fill and a door selected together draw no rotation grip: a fill has no outline, so it is not the movable key the grip needs; a fill and a wall do (Task 11 review m2) [E]
  00:01 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X12-gapmin — a gap takes a width of `2 × wallJoin.linear`

- **file:** `apps/floor_planner/lib/parametric/opening.dart`; backup `t14-X12-gapmin-opening.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  270c270
  <     w > (kind == OpeningKind.gap ? 4 * wallJoin.linear : wallJoin.linear);
  ---
  >     w > (kind == OpeningKind.gap ? 2 * wallJoin.linear : wallJoin.linear);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_panel_test.dart --plain-name 'OS1 the section shows')` (exit 1; log `t14-X12-gapmin-run1.log`)

  ```
  Expected: '800'
    Actual: '0.000003'
     Which: is different.
            Expected: 800
              Actual: 0.000003
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_panel_test.dart:264:7)
  00:02 +0 -1: OS1 the section shows for one opening and hides for none, two, a wall and a box; width and position commit one step each; invalid values revert; the flips are a door's, one step each, and take the focus as the justification tog [cut; the full line is in the log]
  00:02 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_panel_test.dart --plain-name 'OS3 tool mode')` (exit 1; log `t14-X12-gapmin-run2.log`)

  ```
  Expected: <900.0>
    Actual: <0.000003>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_panel_test.dart:484:7)
  00:02 +0 -1: OS3 tool mode: with D active the Width field edits the Door tool's settings keystroke by keystroke, even with an opening selected; a canvas click without Enter places a door with the typed width; N and G have their own settings [cut; the full line is in the log]
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### X12-enter — tool mode writes only on submit

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t14-X12-enter-selection_panel.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  534a535,536
  >           return;
  >           // ignore: dead_code
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_panel_test.dart --plain-name 'OS3 tool mode')` (exit 1; log `t14-X12-enter-run1.log`)

  ```
  Expected: <7.0>
    Actual: <900.0>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_panel_test.dart:441:7)
  00:01 +0 -1: OS3 tool mode: with D active the Width field edits the Door tool's settings keystroke by keystroke, even with an opening selected; a canvas click without Enter places a door with the typed width; N and G have their own settings [cut; the full line is in the log]
  00:01 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X12-catch-commit — `DanglingReferenceError` not caught, `_commit`'s site

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t14-X12-catch-commit-selection_panel.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  410,411d409
  <         } on DanglingReferenceError {
  <           // Refused (spec 08 D5): nothing changed; the field reverts below.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_panel_test.dart --plain-name 'OS4 (X12-catch)')` (exit 1; log `t14-X12-catch-commit-run1.log`)

  ```
  #19     enterAndSubmit (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_panel_test.dart:45:30)
  #20     main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_panel_test.dart:531:5)
  Expected: null
    Actual: 'Multiple exceptions (2) were detected during the running of the current test, and at
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_panel_test.dart:532:5)
  00:01 +0 -1: OS4 (X12-catch) a loaded opening whose host is missing: a width edit is refused with DanglingReferenceError and the field reverts to the model's value, by Enter and by the focus loss; the flips are refused alike; no exception e [cut; the full line is in the log]
  00:01 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X12-catch-flip — `DanglingReferenceError` not caught, the flips' site

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t14-X12-catch-flip-selection_panel.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  505,506d504
  <     } on DanglingReferenceError {
  <       // Refused: nothing changed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_panel_test.dart --plain-name 'OS4 (X12-catch)')` (exit 1; log `t14-X12-catch-flip-run1.log`)

  ```
  #37     main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_panel_test.dart:550:5)
  #37     main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_panel_test.dart:552:5)
  Expected: null
    Actual: 'Multiple exceptions (2) were detected during the running of the current test, and at
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_panel_test.dart:554:5)
  00:02 +0 -1: OS4 (X12-catch) a loaded opening whose host is missing: a width edit is refused with DanglingReferenceError and the field reverts to the model's value, by Enter and by the focus loss; the flips are refused alike; no exception e [cut; the full line is in the log]
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

### The sample plan (Task 13, Task 12's minors, the Task 13 review)

#### rv12-movedHostOnly — (Task 12 review m1) the re-seat reads only the host's new end

- **file:** `apps/floor_planner/lib/parametric/wall_grips.dart`; backup `t14-rv12-movedHostOnly-wall_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  94c94
  <       final stretches = layoutInDocument(d, h, moved: now)?.stretches;
  ---
  >       final stretches = layoutInDocument(d, h, moved: {h: now[h]!})?.stretches;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_end_drag_test.dart --plain-name 'EP9 (rv12-movedHostOnly)')` (exit 1; log `t14-rv12-movedHostOnly-run1.log`)

  ```
  00:00 +0 -1: EP9 (rv12-movedHostOnly) 24 Ls whose corner is A's start and B's end, A's door flush against the corner (stored with storedCentreOf, undiagnosed), the corner dragged out along A's line: every door is kept at L′ − (L − p) exactl [cut; the full line is in the log]
    Expected: <761.7770807081697>
      Actual: <761.7770807081718>
    test/opening_end_drag_test.dart 763:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv12-seatWide — (Task 12 review m2) the re-seat bound 1 mm

- **file:** `apps/floor_planner/lib/parametric/wall_grips.dart`; backup `t14-rv12-seatWide-wall_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  119c119
  <         !((cut.a - (c - w / 2)).abs() <= wallJoin.linear)) {
  ---
  >         !((cut.a - (c - w / 2)).abs() <= 1.0)) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_end_drag_test.dart --plain-name 'EP8 (rv12-seatWide)')` (exit 1; log `t14-rv12-seatWide-run1.log`)

  ```
  00:00 +0 -1: EP8 (rv12-seatWide) a door flush against its wall's START stretch end, the start dragged 0.5 mm inward along the line, on 12 walls: L′ − (L − p) clamps the door by 0.5 mm, far more than rounding, so it is kept there exactly and [cut; the full line is in the log]
    Expected: <349.5000000000855>
      Actual: <350.0000000007507>
    test/opening_end_drag_test.dart 676:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv12-posEnd — (Task 12 review m3) the position's upper end exclusive

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t14-rv12-posEnd-selection_panel.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  242c242
  <         return value.isFinite && value >= 0 && value <= l;
  ---
  >         return value.isFinite && value >= 0 && value < l;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_panel_test.dart --plain-name 'OS1 the section shows')` (exit 1; log `t14-rv12-posEnd-run1.log`)

  ```
  Expected: <6000.000000000728>
    Actual: <1812.5>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_panel_test.dart:232:7)
  00:02 +0 -1: OS1 the section shows for one opening and hides for none, two, a wall and a box; width and position commit one step each; invalid values revert; the flips are a door's, one step each, and take the focus as the justification tog [cut; the full line is in the log]
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv12-gripNoFit — (Task 12 review m4) no-fit counts as clamped for the grip's null rule

- **file:** `apps/floor_planner/lib/parametric/opening_grips.dart`; backup `t14-rv12-gripNoFit-opening_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  73c73
  <         s.cut?.clamped != true) {
  ---
  >         s.cut?.clamped == false) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart --plain-name 'SG5 (rv12-gripNoFit)')` (exit 1; log `t14-rv12-gripNoFit-run1.log`)

  ```
  00:00 +0 -1: SG5 (rv12-gripNoFit) a no-fit window dragged to within wallJoin.linear of its stored centre, either side, edge snaps on and off: no command, since no-fit is not drawn clamped; 2e-6 away it moves (Task 12 review m4) [E]
    Expected: null
      Actual: <Instance of 'SetComponentCommand<OpeningParams>'>
    test/opening_grips_test.dart 424:9                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X13-hinge — one door's hinge flipped in the table

- **file:** `apps/floor_planner/lib/startup_plan.dart`; backup `t14-X13-hinge-startup_plan.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  92c92
  <   p.opening(OpeningParams(p3, 2000, 800, OpeningKind.door));
  ---
  >   p.opening(OpeningParams(p3, 2000, 800, OpeningKind.door, hinge: HingeEnd.end));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart --plain-name 'SP5 the sample')` (exit 1; log `t14-X13-hinge-run1.log`)

  ```
  00:00 +0 -1: SP5 the sample plan is nine walls, seven doors and eight windows, exactly as spec 08 D18's tables say; no gap, no box; drift() and diagnostics() are empty [E]
    Expected: [
      Actual: [
       Which: at location [4] is OpeningParams:<OpeningParams(door on 2A at 2000.0, 800.0, end, left)> instead of OpeningParams:<OpeningParams(door on 2A at 2000.0, 800.0, start, left)>
    test/startup_plan_test.dart 373:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/startup_plan.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X13-dispose — the plan's system not disposed

- **file:** `apps/floor_planner/lib/startup_plan.dart`; backup `t14-X13-dispose-startup_plan.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  161d160
  <   system.dispose();
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/planner_shell_test.dart)` (exit 1; log `t14-X13-dispose-run1.log`)

  ```
  Bad state: the dispatcher already has an expander (spec 06 D2)
  #799    main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/planner_shell_test.dart:64:18)
  Expected: exactly one matching candidate
    Actual: _TypeWidgetFinder:<Found 0 widgets with type "DraftCanvas": []>
     Which: means none were found but one was expected
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/planner_shell_test.dart:67:5)
  00:00 +0 -1: the shell shows a canvas over a non-empty, off-origin plan [E]
  Bad state: the dispatcher already has an expander (spec 06 D2)
  #799    main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/planner_shell_test.dart:83:18)
  Bad state: No element
  #2      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/planner_shell_test.dart:85:25)
  00:01 +0 -2: the camera is fitted to the real viewport on first layout [E]
  Bad state: the dispatcher already has an expander (spec 06 D2)
  #799    main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/planner_shell_test.dart:98:18)
  Bad state: No element
  #2      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/planner_shell_test.dart:100:25)
  ... (53 more kept lines in the log)
  00:02 +0 -12: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/startup_plan.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X13-order — furniture (bed 1) built before the walls

- **file:** `apps/floor_planner/lib/startup_plan.dart`; backup `t14-X13-order-startup_plan.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  66a67
  >   p.rectRegion(x0 + 300, y0 + 6600, x0 + 1700, y0 + 8600); // bed
  128d128
  <   p.rectRegion(x0 + 300, y0 + 6600, x0 + 1700, y0 + 8600); // bed
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart --plain-name 'SP2 every')` (exit 1; log `t14-X13-order-run1.log`)

  ```
  00:00 +0 -1: SP2 every furniture fill draws over every floor-finish line (M-05r); the walls' pieces are built first, below both (08 D18) [E]
    Expected: a value greater than <576>
      Actual: <18>
       Which: is not a value greater than <576>
    test/startup_plan_test.dart 160:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/startup_plan.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv13-wallsMid — (Task 13 review m1) the kitchen tile grid built before the walls

- **file:** `apps/floor_planner/lib/startup_plan.dart`; backup `t14-rv13-wallsMid-startup_plan.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  66a67,69
  >   p.grid(x0 + 5000 + _partition, y0 + _wall, x0 + 9500 - _partition,
  >       y0 + 3500 - _partition,
  >       pitch: 200, both: true);
  107,110d109
  <   // Kitchen tiles, 200 mm, both ways: x 5000+p..9500-p, y wall..3500-p.
  <   p.grid(x0 + 5000 + _partition, y0 + _wall, x0 + 9500 - _partition,
  <       y0 + 3500 - _partition,
  <       pitch: 200, both: true);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart --plain-name 'SP2 every')` (exit 1; log `t14-rv13-wallsMid-run1.log`)

  ```
  00:00 +0 -1: SP2 every furniture fill draws over every floor-finish line (M-05r); the walls' pieces are built first, below both (08 D18) [E]
    Expected: a value less than <18>
      Actual: <184>
       Which: is not a value less than <18>
    test/startup_plan_test.dart 164:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/startup_plan.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv13-swing — (Task 13 review) one door's swing flipped

- **file:** `apps/floor_planner/lib/startup_plan.dart`; backup `t14-rv13-swing-startup_plan.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  85c85
  <   p.opening(OpeningParams(p1, 5875, 900, OpeningKind.door));
  ---
  >   p.opening(OpeningParams(p1, 5875, 900, OpeningKind.door, swing: SwingSide.right));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart --plain-name 'SP5 the sample')` (exit 1; log `t14-rv13-swing-run1.log`)

  ```
  00:00 +0 -1: SP5 the sample plan is nine walls, seven doors and eight windows, exactly as spec 08 D18's tables say; no gap, no box; drift() and diagnostics() are empty [E]
    Expected: [
      Actual: [
       Which: at location [0] is OpeningParams:<OpeningParams(door on 22 at 5875.0, 900.0, start, right)> instead of OpeningParams:<OpeningParams(door on 22 at 5875.0, 900.0, start, left)>
    test/startup_plan_test.dart 373:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/startup_plan.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv13-wrongWall — (Task 13 review) the front door in E3

- **file:** `apps/floor_planner/lib/startup_plan.dart`; backup `t14-rv13-wrongWall-startup_plan.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  95c95
  <   p.opening(OpeningParams(e1, 6375, 1000, OpeningKind.door));
  ---
  >   p.opening(OpeningParams(e3, 6375, 1000, OpeningKind.door));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart --plain-name 'SP5 the sample')` (exit 1; log `t14-rv13-wrongWall-run1.log`)

  ```
  00:00 +0 -1: SP5 the sample plan is nine walls, seven doors and eight windows, exactly as spec 08 D18's tables say; no gap, no box; drift() and diagnostics() are empty [E]
    Expected: [
      Actual: [
       Which: at location [6] is OpeningParams:<OpeningParams(door on 1A at 6375.0, 1000.0, start, left)> instead of OpeningParams:<OpeningParams(door on 12 at 6375.0, 1000.0, start, left)>
    test/startup_plan_test.dart 373:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/planner_shell_test.dart)` (exit 1; log `t14-rv13-wrongWall-run2.log`)

  ```
  Bad state: Pattern matching error
  #0      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/planner_shell_test.dart:259:5)
  00:04 +10 -1: cmd+Z undoes a Delete through the command log [E]
  Expected: an object with length of <5>
    Actual: [18, 30, 135, 142]
     Which: has length of <4>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/planner_shell_test.dart:334:5)
  00:04 +10 -2: ctrl+Z after deleting two walls brings both back in one step [E]
  00:05 +10 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/startup_plan.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### rv13-just — (Task 13 review) every wall left-justified

- **file:** `apps/floor_planner/lib/startup_plan.dart`; backup `t14-rv13-just-startup_plan.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  247c247
  <           h, WallParams(sx, sy, ex, ey, t, Justification.centre)),
  ---
  >           h, WallParams(sx, sy, ex, ey, t, Justification.left)),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart)` (exit 1; log `t14-rv13-just-run1.log`)

  ```
  00:00 +2 -1: the outer walls close: the extents are the outer rectangle [E]
    Expected: <12000.0>
      Actual: <12125.0>
    test/startup_plan_test.dart 66:5                    main.<fn>
  00:00 +6 -2: SP3 no door leaf or swing lies under a furniture fill (Ruling F-1, M-05aa) [E]
    Expected: false
      Actual: <true>
    test/startup_plan_test.dart 245:7                   main.<fn>
  00:01 +6 -3: SP4 every doorway is clear of furniture for 900 mm on both sides (Ruling F-8) [E]
    Expected: false
      Actual: <true>
    test/startup_plan_test.dart 314:11                  main.<fn>
  00:01 +6 -4: SP5 the sample plan is nine walls, seven doors and eight windows, exactly as spec 08 D18's tables say; no gap, no box; drift() and diagnostics() are empty [E]
    Expected: [
      Actual: [
       Which: at location [0] is WallParams:<WallParams((12125.0, 8125.0) -> (25875.0, 8125.0), 250.0, left)> instead of WallParams:<WallParams((12125.0, 8125.0) -> (25875.0, 8125.0), 250.0, centre)>
  ... (2 more kept lines in the log)
  00:01 +7 -4: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/startup_plan.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv13-bed2 — (Task 13 review) bed 2 widened into the hall/living swing

- **file:** `apps/floor_planner/lib/startup_plan.dart`; backup `t14-rv13-bed2-startup_plan.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  134c134
  <   p.rectRegion(x0 + 2750, y0 + 5200, x0 + 4000, y0 + 7200); // bed
  ---
  >   p.rectRegion(x0 + 2750, y0 + 5200, x0 + 4100, y0 + 7200); // bed
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart --plain-name 'SP3 no door')` (exit 1; log `t14-rv13-bed2-run1.log`)

  ```
  00:00 +0 -1: SP3 no door leaf or swing lies under a furniture fill (Ruling F-1, M-05aa) [E]
    Expected: false
      Actual: <true>
    test/startup_plan_test.dart 245:7                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart --plain-name 'SP4 every doorway')` (exit 1; log `t14-rv13-bed2-run2.log`)

  ```
  00:00 +0 -1: SP4 every doorway is clear of furniture for 900 mm on both sides (Ruling F-8) [E]
    Expected: false
      Actual: <true>
    test/startup_plan_test.dart 314:11                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/startup_plan.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### rv13-noClear — (Task 13 review) the history not cleared

- **file:** `apps/floor_planner/lib/startup_plan.dart`; backup `t14-rv13-noClear-startup_plan.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  170d169
  <   doc.commands.clearHistory();
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart --plain-name 'the startup plan carries an A4')` (exit 1; log `t14-rv13-noClear-run1.log`)

  ```
  00:00 +0 -1: the startup plan carries an A4 landscape page at 1:50 centred on the plan, in millimetres, with no history [E]
    Expected: false
      Actual: <true>
    test/startup_plan_test.dart 104:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/planner_shell_test.dart)` (exit 1; log `t14-rv13-noClear-run2.log`)

  ```
  Expected: <1>
    Actual: <200>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/planner_shell_test.dart:284:5)
  00:04 +10 -1: cmd+Z undoes a Delete through the command log [E]
  Expected: <1>
    Actual: <200>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/planner_shell_test.dart:361:5)
  00:05 +10 -2: ctrl+Z after deleting two walls brings both back in one step [E]
  00:05 +10 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/startup_plan.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### rv13-disposeEarly — (Task 13 review) the system disposed before the openings

- **file:** `apps/floor_planner/lib/startup_plan.dart`; backup `t14-rv13-disposeEarly-startup_plan.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  81a82
  >   system.dispose();
  161d161
  <   system.dispose();
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart)` (exit 1; log `t14-rv13-disposeEarly-run1.log`)

  ```
  00:00 +0 -1: is at the target scale: between 500 and 1,000 entities [E]
    Expected: be in range from 500 (inclusive) to 1000 (inclusive)
      Actual: <466>
    test/startup_plan_test.dart 46:5                    main.<fn>
  00:00 +4 -2: SP1 the furniture is eight root-owned filled regions with the furniture outline; the plan holds 549 entities [E]
    Expected: <549>
      Actual: <466>
    test/startup_plan_test.dart 128:5                   main.<fn>
  00:00 +5 -3: SP3 no door leaf or swing lies under a furniture fill (Ruling F-1, M-05aa) [E]
    Expected: an object with length of <7>
      Actual: []
       Which: has length of <0>
    test/startup_plan_test.dart 212:5                   main.<fn>
  00:00 +5 -4: SP4 every doorway is clear of furniture for 900 mm on both sides (Ruling F-8) [E]
    Expected: an object with length of <7>
      Actual: []
  ... (11 more kept lines in the log)
  00:00 +5 -6: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/startup_plan.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

## Task 14 fix round 1: the findings closed

The controller ruled both findings fixed in this round: F1 by a fixture, F2 by one rule. The three re-fires below ran on `b1b4c98` with the round's edits staged. They supersede the first run's verdicts on the same mutants (`t11-apertureDir-grip`, `M-08i-openinggrips`), whose entries stay above as the record of the finding.

### fr1-t11-apertureDir-grip — F1 re-fired: `t11-apertureDir` at the slide grip's site, against the fix round's new test

- **file:** `apps/floor_planner/lib/parametric/opening_grips.dart`; backup `t14-fr1-t11-apertureDir-grip-opening_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  163c163
  <           apertureWorld / toWorld.transformDirection(f.d).length);
  ---
  >           apertureWorld / toWorld.scaleMagnitude);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart --plain-name 'SG1 (t11-apertureDir')` (exit 1; log `t14-fr1-t11-apertureDir-grip-run1.log`)

  ```
  00:00 +0 -1: SG1 (t11-apertureDir, the grip's site) on a host scaled non-uniformly the slide grip's aperture is measured along its centreline: an edge 19.9 mm (in world) from a neighbour's edge snaps onto it, one 20.1 mm away does not (Task [cut; the full line is in the log]
    Expected: a numeric value within <0.000001> of <678.1742942920065>
      Actual: <688.9694131269387>
       Which:  differs by <10.795118834932168>
    test/opening_grips_test.dart 320:7                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red). KILLED by `SG1 (t11-apertureDir, the grip's site)`, line 320, at the 20.1 mm case: the grip's divisor `scaleMagnitude` (1 for this group) gives a 20 (local) aperture, about 37 mm in world here (`k ≈ 1.86`), so the drag snaps onto the window's edge (688.97) instead of staying where it was dragged (678.17, 10.8 local mm short).

### fr1-M-08i-openinggrips — F2 re-fired: M-08i at `OpeningGrips.movable`, now the one rule the composite delegates to

- **file:** `apps/floor_planner/lib/parametric/opening_grips.dart`; backup `t14-fr1-M-08i-openinggrips-opening_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  99,100c99
  <   bool movable(DraftDocument d, Handle group) =>
  <       d.components.get<OpeningParams>(group) == null;
  ---
  >   bool movable(DraftDocument d, Handle group) => true;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart --plain-name 'SG2 (M-08i)')` (exit 1; log `t14-fr1-M-08i-openinggrips-run1.log`)

  ```
  Expected: false
    Actual: <true>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_grips_test.dart:415:5)
  00:01 +0 -1: SG2 (M-08i) a body drag on a selected door starts nothing and adds nothing to the history, and no rotation grip is drawn for it; a wall selected with its door moves, and the door follows through regeneration with its stored pos [cut; the full line is in the log]
  00:01 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red). KILLED by `SG2`, line 415 ("no rotation grip"): the door alone is selected, and with the rule gone it counts as movable.

### fr1-M-08i-composite — M-08i re-fired at the composite's new line (the delegation replaced by `true`)

- **file:** `apps/floor_planner/lib/parametric/object_grips.dart`; backup `t14-fr1-M-08i-composite-object_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  52c52
  <       _of(d, group)?.movable(d, group) ?? true;
  ---
  >       true;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart --plain-name 'SG2 (M-08i)')` (exit 1; log `t14-fr1-M-08i-composite-run1.log`)

  ```
  Expected: false
    Actual: <true>
  #4      main.<anonymous closure> (file:///home/user/jet-cad/.claude/worktrees/plan-openings/apps/floor_planner/test/opening_grips_test.dart:415:5)
  00:01 +0 -1: SG2 (M-08i) a body drag on a selected door starts nothing and adds nothing to the history, and no rotation grip is drawn for it; a wall selected with its door moves, and the door follows through regeneration with its stored pos [cut; the full line is in the log]
  00:01 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/object_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red). KILLED by `SG2`, line 415.

## Task 16's first commit: the Task 14 review's Minor 1

The Task 14 review fired `own-defaultMovable` and it survived: no test
selected a group that is neither a wall nor an opening through the
composite. The controller ruled a test into Task 16's first commit.
`SG6 (own-defaultMovable)` (`opening_grips_test.dart`) builds a wall
with a door and a 06 box in its own rotated group at the far origin, and
asks the composite: the box and the wall are movable, the door is not;
`GripDrag.move` over the box and the door moves the box by the drag and
leaves the door's group and position untouched, and `GripDrag.rotate`
over the same keys is offered. Fired by hand on the Task 16 tree (the
first commit's two test edits in the worktree), backups under the
scratchpad's `plan08/` with the `t16-` prefix. Baseline: `--plain-name
'SG6 (own-defaultMovable)'` `00:00 +1: All tests passed!`, exit 0
(`t16-baseline-SG6.log`).

### own-defaultMovable — (Task 14 review Minor 1) the composite's default: a group neither wall nor opening is immovable

- **file:** `apps/floor_planner/lib/parametric/object_grips.dart`; backup `t16-own-defaultMovable-object_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  52c52
  <       _of(d, group)?.movable(d, group) ?? true;
  ---
  >       _of(d, group)?.movable(d, group) ?? false;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart --plain-name 'SG6 (own-defaultMovable)')` (exit 1; log `t16-own-defaultMovable-run1.log`)

  ```
  00:00 +0 -1: SG6 (own-defaultMovable) a 06 box is movable through the composite: selected with a door, a move takes the box and skips the door, and a rotate is offered; a wall is movable, a door is not (Task 14 review Minor 1) [E]
    Expected: true
      Actual: <false>
    test/opening_grips_test.dart 627:5                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/object_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red). KILLED by `SG6`, line 627 ("a box"). It survived the whole app suite in the Task 14 review.

## Equivalent mutants, fired

The ledger and the carry name these as equivalent. Each was fired against the whole file(s) its argument concerns. Seven survive; two are killed on this tree and are counted killed.

### EQ-X9-adapterDesc — the document adapter's walls in descending order

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-EQ-X9-adapterDesc-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  630c630
  <     ],
  ---
  >     ].reversed.toList(),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart)` (exit 0; log `t14-EQ-X9-adapterDesc-run1.log`)

  ```
  00:03 +17: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** CONTROL-GREEN (0 of 1 commands red). Survives, as argued in Task 9: the adapter's walls feed `capsOf` and `obstaclesOf`, which decide by handle and sort their output (obstacles by `a`, `b`, handle), never by list order.

### EQ-rv7-invOrder — the cascade's inverses in forward order

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t14-EQ-rv7-invOrder-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  419c419
  <     inverse: CompoundCommand([...inverses.reversed, r0.inverse],
  ---
  >     inverse: CompoundCommand([...inverses, r0.inverse],
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/references_test.dart test/parametric/cascade_test.dart test/parametric/reference_cost_test.dart)` (exit 1; log `t14-EQ-rv7-invOrder-run1.log`)

  ```
  00:00 +8 -1: test/parametric/cascade_test.dart: CS1 deleting Post A with the select tool's compound cascades P1 and P2 in the same edit: one undo step; undo, redo, and undo then purge restore the state and every child handle [E]
    Bad state: no entity with handle C1E
    test/parametric/cascade_test.dart 232:18                         main.<fn>
  00:00 +19 -2: test/parametric/cascade_test.dart: CS10 (Task 2 review m-1) a loaded region whose boundary cannot be filled (open), or whose fill names no boundary: the cascade removes the fill first, so deleting A lands; one step; undo is ex [cut; the full line is in the log]
    Bad state: cannot remove boundary C1F: C1F is not a fillable boundary, so undo could not restore the pair; remove fill C1E first
    test/parametric/cascade_test.dart 615:20                         main.<fn>
  00:00 +19 -3: test/parametric/cascade_test.dart: CS11 (Task 2 review m-3; Task 2 re-review m1) the cascade removes a referrer's subtree as the select tool does: a nested group under P1, with its own leaf, and an instance under P1 go too; va [cut; the full line is in the log]
    Expected: '{"schemaVersion":6,"header":{"units":"unitless","scale":1.0,"globalLinetypeScale":1.0,"importedExtents":null,"customVariables":{}},"tables":{"layers":[{"handle":1,"name":"0","color":7,"linetype":4,"lineweight":-3,"transparency" [cut; the full line is in the log]
      Actual: '{"schemaVersion":6,"header":{"units":"unitless","scale":1.0,"globalLinetypeScale":1.0,"importedExtents":null,"customVariables":{}},"tables":{"layers":[{"handle":1,"name":"0","color":7,"linetype":4,"lineweight":-3,"transparency" [cut; the full line is in the log]
       Which: is different.
              Expected: ... hildren":[3106,3107] ...
                Actual: ... hildren":[],"exportA ...
    test/parametric/cascade_test.dart 664:5  main.<fn>
  00:00 +19 -4: test/parametric/cascade_test.dart: CS12 (Task 2 re-review m2) a loaded region whose fill sits in a group nested under P2 and whose boundary is P2's own: every fill of the doomed subtree goes before any boundary, so deleting A  [cut; the full line is in the log]
    Expected: '{"schemaVersion":6,"header":{"units":"unitless","scale":1.0,"globalLinetypeScale":1.0,"importedExtents":null,"customVariables":{}},"tables":{"layers":[{"handle":1,"name":"0","color":7,"linetype":4,"lineweight":-3,"transparency" [cut; the full line is in the log]
      Actual: '{"schemaVersion":6,"header":{"units":"unitless","scale":1.0,"globalLinetypeScale":1.0,"importedExtents":null,"customVariables":{}},"tables":{"layers":[{"handle":1,"name":"0","color":7,"linetype":4,"lineweight":-3,"transparency" [cut; the full line is in the log]
  ... (5 more kept lines in the log)
  00:00 +23 -4: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_object_test.dart)` (exit 0; log `t14-EQ-rv7-invOrder-run2.log`)

  ```
  00:00 +5: All tests passed!
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** CONTROL-RED (1 of 2 commands red). **Not equivalent on the current tree:** the engine suite kills it (`CS1`, `CS10`, `CS11`, `CS12`); the app file stays green, which is where the Task 7 review fired it and judged it equivalent. Reclassified KILLED.

### EQ-rv8-addForm — the D13 rewrite as `p + (L′ − L)`

- **file:** `apps/floor_planner/lib/parametric/wall_grips.dart`; backup `t14-EQ-rv8-addForm-wall_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  97c97
  <         final p = l2 - (l - params.position);
  ---
  >         final p = params.position + (l2 - l);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_end_drag_test.dart)` (exit 1; log `t14-EQ-rv8-addForm-run1.log`)

  ```
  00:04 +8 -1: EP8 (rv12-seatWide) a door flush against its wall's START stretch end, the start dragged 0.5 mm inward along the line, on 12 walls: L′ − (L − p) clamps the door by 0.5 mm, far more than rounding, so it is kept there exactly and [cut; the full line is in the log]
    Expected: <349.5000000000855>
      Actual: <349.50000000008544>
    test/opening_end_drag_test.dart 676:7               main.<fn>
  00:04 +8 -2: EP9 (rv12-movedHostOnly) 24 Ls whose corner is A's start and B's end, A's door flush against the corner (stored with storedCentreOf, undiagnosed), the corner dragged out along A's line: every door is kept at L′ − (L − p) exactl [cut; the full line is in the log]
    Expected: <747.9415486116095>
      Actual: <747.9415486116098>
    test/opening_end_drag_test.dart 763:7               main.<fn>
  00:04 +8 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** CONTROL-RED (1 of 1 commands red). **Not equivalent on the current tree:** `EP8` and `EP9` (Task 13, from the Task 12 review) pin `L′ − (L − p)` bit for bit, and `p + (L′ − L)` rounds differently (349.5000000000855 against 349.50000000008544). Reclassified KILLED.

### EQ-rv8-startOnly — the D13 rewrite on any start move

- **file:** `apps/floor_planner/lib/parametric/wall_grips.dart`; backup `t14-EQ-rv8-startOnly-wall_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  74c74
  <       if (p.start != old.start && p.end == old.end) {
  ---
  >       if (p.start != old.start) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_end_drag_test.dart)` (exit 0; log `t14-EQ-rv8-startOnly-run1.log`)

  ```
  00:04 +10: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** CONTROL-GREEN (0 of 1 commands red). Survives, as argued in the Task 8 review: a start move with the end moved too is the both-ends case, which a grip drag cannot make (the drag of one node moves one end of a wall; a wall with both ends on the node is refused at length 0).

### EQ-rv8-before — the position rewrites before the wall writes

- **file:** `apps/floor_planner/lib/parametric/wall_grips.dart`; backup `t14-EQ-rv8-before-wall_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  58d57
  <       for (final (h, p, _) in moved) SetComponentCommand<WallParams>(h, p),
  59a59
  >       for (final (h, p, _) in moved) SetComponentCommand<WallParams>(h, p),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_end_drag_test.dart)` (exit 0; log `t14-EQ-rv8-before-run1.log`)

  ```
  00:04 +10: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** CONTROL-GREEN (0 of 1 commands red). Survives: the compound's commands write distinct components and none reads another's result; the regeneration runs once, after the whole edit. Cosmetic (Task 8 review m3).

### EQ-rv9-adapterSelf — the document adapter includes the host itself

- **file:** `apps/floor_planner/lib/parametric/opening_geometry.dart`; backup `t14-EQ-rv9-adapterSelf-opening_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  626c626
  <         if (h != host && _isLiveGroup(doc, h))
  ---
  >         if (_isLiveGroup(doc, h))
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart)` (exit 0; log `t14-EQ-rv9-adapterSelf-run1.log`)

  ```
  00:03 +17: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart)` (exit 0; log `t14-EQ-rv9-adapterSelf-run2.log`)

  ```
  00:02 +7: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_end_drag_test.dart)` (exit 0; log `t14-EQ-rv9-adapterSelf-run3.log`)

  ```
  00:04 +10: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** CONTROL-GREEN (0 of 3 commands red). Survives: `classify`, `capsOf` and `obstaclesOf` skip the host itself (`b.handle == host.handle`).

### EQ-rv10-edgeAnyHost — the edge-snapped centre used on any host

- **file:** `apps/floor_planner/lib/parametric/opening_tool.dart`; backup `t14-EQ-rv10-edgeAnyHost-opening_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  335c335
  <     final u = _edgeSnapped && host == _edgeHost
  ---
  >     final u = _edgeSnapped
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_tool_test.dart)` (exit 0; log `t14-EQ-rv10-edgeAnyHost-run1.log`)

  ```
  00:03 +17: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/opening_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** CONTROL-GREEN (0 of 1 commands red). Survives, as argued in the Task 10 review: `_edgeSnapped` is reset by every `selfSnap` and set only for the host that same scan returned, which is the host `_place` is then called with.

### EQ-rv11-nestedAsk — `movableKey` asks the provider about a nested group

- **file:** `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; backup `t14-EQ-rv11-nestedAsk-grip_cache.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  60c60
  <   if (node is! GroupNode || node.parent != d.rootHandle) return true;
  ---
  >   if (node is! GroupNode) return true;
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/object_grips_test.dart)` (exit 0; log `t14-EQ-rv11-nestedAsk-run1.log`)

  ```
  00:00 +11: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_grips_test.dart)` (exit 0; log `t14-EQ-rv11-nestedAsk-run2.log`)

  ```
  00:02 +7: All tests passed!
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** CONTROL-GREEN (0 of 2 commands red). Survives, as argued in the Task 11 review: a nested group is never a parametric object, and the provider answers true for anything that is not an opening object.

### EQ-rv12-chgCurrent — tool-mode `onChanged` writes to the current target

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t14-EQ-rv12-chgCurrent-selection_panel.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  538,539c538,540
  <           if (v != null && _validSetting(f.kind, target, v)) {
  <             _write(f.kind, target, v);
  ---
  >           final cur = _targetOf(f.kind) ?? target;
  >           if (v != null && _validSetting(f.kind, cur, v)) {
  >             _write(f.kind, cur, v);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_panel_test.dart)` (exit 0; log `t14-EQ-rv12-chgCurrent-run1.log`)

  ```
  00:04 +5: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/selection_panel_test.dart)` (exit 0; log `t14-EQ-rv12-chgCurrent-run2.log`)

  ```
  00:09 +26: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** CONTROL-GREEN (0 of 2 commands red). Survives, as argued in the Task 12 review: through the UI the target recorded at focus gain is the current target while the field keeps focus.

---

## Survivors and findings

None survive after fix round 1.

- **`t11-apertureDir-grip` (F1).** Survived `opening_grips_test.dart`
  and the whole app suite in the first run; the tool's copy
  (`t11-apertureDir-tool`) was killed by `OT3 (t11-apertureDir)`. This
  was Ruling 08-21's case: a rule at two sites, pinned at one. Fix round
  1 added `SG1 (t11-apertureDir, the grip's site)`; the re-fire is red.
- **`M-08i-openinggrips` (F2).** Survived the whole app suite in the
  first run, equivalent as the shell was wired: `ObjectGrips.movable`
  decided for openings itself. Fix round 1 made the composite delegate,
  so `OpeningGrips.movable` is the one rule; the re-fire is red, and so
  is M-08i at the composite's new line.
- **`non-fill-first`.** Its first reconstruction survives `CS10`, its
  Task 2 killer, because ascending order is already fill-first for a
  planner-made region; `CS12` kills it, and the other reading
  (`non-fill-first-v2`) is killed by `CS10` and `CS12`. Counted killed.

## N/A (not re-fired)

- **Edits never written down** (six). The ledger names them and says they
  were red; neither the ledger nor the scratchpad holds their edit, and
  their names do not determine one:
  - Task 4 review: `RV-2`, `RV-3`, `RV-6` ("pins `mergeCuts`'s use"),
    `RV-8`. `RV-4` and `RV-1` (Task 4 review m2, m3) are fired above.
  - Task 5 review: `RV5-clampedCut`. Its four siblings are fired
    (`RV5-degHostSilent` as recorded; `RV5-orphanAlways`,
    `RV5-diagOwnCut` and `RV5-overlapStored` reconstructed from their
    names).
  - Task 9 review: `rv9-toolNaive` (its log holds only the test output).
- **Superseded** (two): the code they mutated was replaced by a ruling.
  - `X2-fillskip` (Task 2): the Task 2 review's m-1 ruling removed the
    skip; reinstating it is `reinstate-skip`, killed above.
  - `X5-lowest` (Task 5): the "highest handle yields" loop it mutated was
    replaced by admission in ascending handle order (Task 5 review S1);
    the new rule's mutants are `check-once`, `check-final`,
    `highest-handle`, `rv5b-descending` and `rv5b-checkAlone`, all
    killed above.
- **"M-08f1b-h"** (named in Task 14's carry among the equivalents): no
  such mutant is in the ledger or in the spec. The scratchpad's
  `M-F1b-a`..`k` belong to fix/post-07, not to this plan.

## Gate at commit

**First run** (`b1b4c98`, this log's first version; the commit touched no
code), from `t14-gates.sh`:

```
engine   (packages/jet_cad_2d)          CI=true dart test          00:12 +1014 -2: Some tests failed.   (exit 1)
         the two standing failures: test/testing/generate_document_test.dart
           "the default document is the one Plan 2 measured, byte for byte"
           "both text fractions default to zero and change nothing"
         dart analyze                    No issues found!                      (exit 0)
         dart format --set-exit-if-changed   Formatted 147 files (0 changed)   (exit 0)
render   (packages/jet_cad_2d_flutter)  CI=true flutter test       00:43 +936 ~1 -7: Some tests failed. (exit 1)
         the seven standing failures: text ladder rungs 1-5, text lod ladder rungs 1-2
         flutter analyze                 No issues found! (ran in 1.1s)         (exit 0)
         dart format --set-exit-if-changed   Formatted 177 files (0 changed)   (exit 0)
harness  (apps/dev_harness_2d)          CI=true flutter test --concurrency=1   00:31 +82: All tests passed!   (exit 0)
         flutter analyze                 No issues found! (ran in 0.9s)         (exit 0)
         dart format --set-exit-if-changed   Formatted 22 files (0 changed)    (exit 0)
app      (apps/floor_planner)           CI=true flutter test       00:43 +230: All tests passed!        (exit 0)
         flutter analyze                 No issues found! (ran in 0.9s)         (exit 0)
         dart format --set-exit-if-changed   Formatted 52 files (0 changed)    (exit 0)
         flutter build web --release     ✓ Built build/web                      (exit 0)
```

**Fix round 1** touches the app only (`object_grips.dart`,
`opening_grips_test.dart`, this log), so the app line was run:

```
app      (apps/floor_planner)           CI=true flutter test       00:47 +231: All tests passed!        (exit 0)
         flutter analyze                 No issues found! (ran in 1.2s)         (exit 0)
         dart format --set-exit-if-changed   Formatted 52 files (0 changed)    (exit 0)
         flutter build web --release     ✓ Built build/web                      (exit 0)
```

`+231`: the new `SG1 (t11-apertureDir, the grip's site)`. Only the
standing Linux failures of Ruling 08-20 anywhere.

**Task 16's first commit** touches the app's tests only
(`opening_grips_test.dart`, `planner_shell_test.dart`'s comment) and
this log, so the app line's test, analyze and format were run:

```
app      (apps/floor_planner)           CI=true flutter test       00:44 +232: All tests passed!        (exit 0)
         flutter analyze                 No issues found! (ran in 1.2s)         (exit 0)
         dart format --set-exit-if-changed   Formatted 52 files (0 changed)    (exit 0)
```

`+232`: the new `SG6 (own-defaultMovable)`. The four gate lines and the
web build are run again on the final tree by Task 16 (the results note).

## Appendix: M-08a's scratch diff

`diff -u` of each adapted file, worktree against scratch (`t14-M-08a.diff`):

```diff
--- worktree/apps/floor_planner/lib/parametric/opening.dart
+++ scratch/apps/floor_planner/lib/parametric/opening.dart
@@ -2,6 +2,7 @@
 // import. The geometry they are drawn and cut with is pure Dart, in
 // `opening_geometry.dart`.
 import 'package:jet_cad_2d/jet_cad_2d.dart';
+import 'package:vector_math/vector_math_64.dart' show Vector2;
 
 import 'opening_geometry.dart';
 import 'wall.dart';
@@ -31,13 +32,32 @@
 /// accepts anything well-typed: a position outside the wall (drawn clamped,
 /// D8) or a degenerate width (D6: it cuts and generates nothing) loads.
 final class OpeningParams implements Component {
-  const OpeningParams(this.host, this.position, this.width, this.kind,
-      {this.hinge = HingeEnd.start, this.swing = SwingSide.left});
+  const OpeningParams(this.host, this.x, this.width, this.kind,
+      {this.y = double.nan,
+      this.hinge = HingeEnd.start,
+      this.swing = SwingSide.left});
 
   static const String componentTypeId = 'floor_planner.opening';
 
   final Handle host;
-  final double position;
+
+  /// M-08a: the opening's WORLD centre. A NaN [y] is construction sugar
+  /// only (a plan, a test): [x] is then a distance along the host, which
+  /// [placedOn] turns into the world centre before it is stored.
+  final double x, y;
+
+  /// M-08a: this opening with its world centre resolved on host [w],
+  /// whose group maps to world by [toWorld].
+  OpeningParams placedOn(WallParams w, Transform2 toWorld) {
+    if (!y.isNaN) return this;
+    final q = toWorld.transformPoint(w.start + (w.end - w.start).normalized() * x);
+    return copyWith(x: q.x, y: q.y);
+  }
+
+  /// M-08a: the stored world centre projected onto the host's frame [f];
+  /// [toWorld] is the host's group transform.
+  double uOn(HostFrame f, Transform2 toWorld) =>
+      f.uOf(toWorld.invert().transformPoint(Vector2(x, y)));
   final double width;
   final OpeningKind kind;
   final HingeEnd hinge;
@@ -51,7 +71,8 @@
   @override
   Map<String, Object?> toJson() => {
         'host': host.toJson(),
-        'position': position,
+        'x': x,
+        'y': y,
         'width': width,
         'kind': kind.name,
         'hinge': hinge.name,
@@ -62,39 +83,43 @@
   /// enum name.
   static OpeningParams fromJson(Map<String, Object?> json) => OpeningParams(
         Handle.fromJson(json['host']),
-        (json['position']! as num).toDouble(),
+        (json['x']! as num).toDouble(),
         (json['width']! as num).toDouble(),
         OpeningKind.values.byName(json['kind']! as String),
+        y: (json['y']! as num).toDouble(),
         hinge: HingeEnd.values.byName(json['hinge']! as String),
         swing: SwingSide.values.byName(json['swing']! as String),
       );
 
   OpeningParams copyWith(
           {Handle? host,
-          double? position,
+          double? x,
+          double? y,
           double? width,
           HingeEnd? hinge,
           SwingSide? swing}) =>
-      OpeningParams(host ?? this.host, position ?? this.position,
-          width ?? this.width, kind,
-          hinge: hinge ?? this.hinge, swing: swing ?? this.swing);
+      OpeningParams(host ?? this.host, x ?? this.x, width ?? this.width, kind,
+          y: y ?? this.y,
+          hinge: hinge ?? this.hinge,
+          swing: swing ?? this.swing);
 
   @override
   bool operator ==(Object other) =>
       other is OpeningParams &&
       other.host == host &&
-      other.position == position &&
+      other.x == x &&
+      other.y == y &&
       other.width == width &&
       other.kind == kind &&
       other.hinge == hinge &&
       other.swing == swing;
 
   @override
-  int get hashCode => Object.hash(host, position, width, kind, hinge, swing);
+  int get hashCode => Object.hash(host, x, y, width, kind, hinge, swing);
 
   @override
   String toString() => 'OpeningParams(${kind.name} on ${host.toHex()} at '
-      '$position, $width, ${hinge.name}, ${swing.name})';
+      '($x, $y), $width, ${hinge.name}, ${swing.name})';
 }
 
 /// The opening (spec 08 D1, D10): its own root-level group, at the identity
@@ -144,13 +169,17 @@
     final i = all.openings.indexOf(self);
     if (i < 0) return const [];
     final toOwn = view.toWorld(self).invert().multiply(view.toWorld(o.host));
-    return symbolOf(all.layout.frame, o, all.cuts[i], toOwn);
+    return symbolOf(all.layout.frame, o, all.cuts[i], toOwn,
+        u: o.uOn(all.layout.frame, view.toWorld(o.host)));
   }
 
   /// D6's degenerate opening: a width not greater than `wallJoin.linear`,
   /// or a non-finite position or width.
   static bool _degenerate(OpeningParams o) =>
-      !o.position.isFinite || !o.width.isFinite || !(o.width > wallJoin.linear);
+      !o.x.isFinite ||
+      !o.y.isFinite ||
+      !o.width.isFinite ||
+      !(o.width > wallJoin.linear);
 
   /// At most one entry of each code for [self] (spec 08 D17), warnings
   /// unless stated, except `opening.overlap`, one per overlapping pair:
@@ -186,7 +215,7 @@
           severity: DiagnosticSeverity.error,
           code: 'opening.degenerate',
           message: 'opening ${self.toHex()} has width ${o.width} at '
-              '${o.position}: it cuts and draws nothing',
+              '(${o.x}, ${o.y}): it cuts and draws nothing',
           handles: [self],
         ),
       ];
@@ -225,8 +254,9 @@
     if (cut == null) {
       return [nofit('it cuts nothing and is drawn outside the wall')];
     }
-    final lo = o.position - o.width / 2, hi = o.position + o.width / 2;
     final frame = all.layout.frame;
+    final u = o.uOn(frame, view.toWorld(host));
+    final lo = u - o.width / 2, hi = u + o.width / 2;
     final walls = {
       for (final ob in all.layout.obstacles)
         if (lo < ob.b && ob.a < hi) ob.wall,
--- worktree/apps/floor_planner/lib/parametric/opening_geometry.dart
+++ scratch/apps/floor_planner/lib/parametric/opening_geometry.dart
@@ -458,11 +458,12 @@
 ///
 /// [o] must not be degenerate (D6): it generates nothing.
 List<Generated> symbolOf(
-    HostFrame f, OpeningParams o, Cut? cut, Transform2 toOwn) {
+    HostFrame f, OpeningParams o, Cut? cut, Transform2 toOwn,
+    {required double u}) {
   final w = o.width;
   final fits = cut != null;
-  final x1 = fits ? cut.a : o.position - w / 2;
-  final x2 = fits ? cut.b : o.position + w / 2;
+  final x1 = fits ? cut.a : u - w / 2;
+  final x2 = fits ? cut.b : u + w / 2;
   final t = f.lOff - f.rOff;
   Vector2 own(double u, double off) => toOwn.transformPoint(f.at(u, off));
   Generated line(double u1, double u2, double off) =>
@@ -585,7 +586,8 @@
   final layout = layoutInView(view, host);
   if (layout == null) return null;
   final placed = cutsOf(layout.frame, layout.stretches, [
-    for (final (_, o) in openings) (o.position, o.width),
+    for (final (_, o) in openings)
+      (o.uOn(layout.frame, view.toWorld(host)), o.width),
   ]);
   return (
     layout: layout,
--- worktree/apps/floor_planner/lib/parametric/opening_tool.dart
+++ scratch/apps/floor_planner/lib/parametric/opening_tool.dart
@@ -303,7 +303,7 @@
         ? const []
         : [
             for (final (h, o) in openingsInDocument(doc, host))
-              (h, o.position, o.width),
+              (h, o.uOn(layout.frame, _toWorld!), o.width),
           ];
     _otherCuts = layout == null
         ? const []
@@ -345,11 +345,13 @@
     // 08-23): exactly on it swings left.
     final side =
         (toLocal.transformPoint(raw) - f.s).dot(f.n) - (f.lOff + f.rOff) / 2;
+    final wc = _toWorld!.transformPoint(f.at(c, 0));
     final params = switch (kind) {
-      OpeningKind.door => OpeningParams(host, c, w, kind,
+      OpeningKind.door => OpeningParams(host, wc.x, w, kind,
+          y: wc.y,
           hinge: c <= f.len / 2 ? HingeEnd.start : HingeEnd.end,
           swing: side >= 0 ? SwingSide.left : SwingSide.right),
-      _ => OpeningParams(host, c, w, kind),
+      _ => OpeningParams(host, wc.x, w, kind, y: wc.y),
     };
     return (params: params, cut: c == u ? cut : _cutAmong(layout, c, w, self));
   }
@@ -380,7 +382,8 @@
     final cut = placed.cut;
     Vector2 world(double u, double off) => toWorld.transformPoint(f.at(u, off));
     return [
-      for (final g in symbolOf(f, placed.params, cut, toWorld))
+      for (final g in symbolOf(f, placed.params, cut, toWorld,
+          u: placed.params.uOn(f, toWorld)))
         (g.kind, g.payload),
       if (cut != null)
         for (final u in [cut.a, cut.b])
--- worktree/apps/floor_planner/lib/parametric/opening_grips.dart
+++ scratch/apps/floor_planner/lib/parametric/opening_grips.dart
@@ -54,7 +54,7 @@
     final s = _Slide.of(d, group);
     if (s == null) return const [];
     final c = s.cut;
-    final u = c == null ? s.params.position : (c.a + c.b) / 2;
+    final u = c == null ? s.u : (c.a + c.b) / 2;
     if (!u.isFinite) return const [];
     final w = s.world(u, 0);
     return [Grip(GripRole.stretch, 0, w.x, w.y)];
@@ -66,15 +66,17 @@
     if (s == null) return null;
     final placed = s.place(world, edgeAperture());
     final p = s.params;
-    if (placed.centre == p.position) return null;
+    if (placed.centre == s.u) return null;
     // Within the tolerance a drag changes nothing, unless the opening is
     // drawn clamped now: then the drag re-seats it where it is drawn.
-    if ((placed.centre - p.position).abs() <= wallJoin.linear &&
+    if ((placed.centre - s.u).abs() <= wallJoin.linear &&
         s.cut?.clamped != true) {
       return null;
     }
     return SetComponentCommand<OpeningParams>(
-        group, p.copyWith(position: placed.centre));
+        group,
+        p.copyWith(
+            x: s.world(placed.centre, 0).x, y: s.world(placed.centre, 0).y));
   }
 
   @override
@@ -119,7 +121,8 @@
     final i = openings.indexWhere((o) => o.$1 == group);
     if (i < 0) return null;
     final placed = cutsOf(layout.frame, layout.stretches, [
-      for (final (_, o) in openings) (o.position, o.width),
+      for (final (_, o) in openings)
+        (o.uOn(layout.frame, walls.host.toWorld), o.width),
     ]);
     return _Slide._(p, layout, walls.host.toWorld, openings, i, placed.cuts);
   }
@@ -138,6 +141,9 @@
   /// This opening's cut as drawn now.
   Cut? get cut => cuts[index];
 
+  /// M-08a: the stored world centre along the host.
+  double get u => params.uOn(layout.frame, toWorld);
+
   /// The world point [u] along the host's centreline and [off] along its
   /// left normal.
   Vector2 world(double u, double off) =>
@@ -177,6 +183,6 @@
   /// they are, admitted in ascending handle order.
   Cut? _cutAt(double c) => cutsOf(layout.frame, layout.stretches, [
         for (final (j, (_, o)) in openings.indexed)
-          j == index ? (c, o.width) : (o.position, o.width),
+          j == index ? (c, o.width) : (o.uOn(layout.frame, toWorld), o.width),
       ]).cuts[index];
 }
--- worktree/apps/floor_planner/lib/parametric/wall_grips.dart
+++ scratch/apps/floor_planner/lib/parametric/wall_grips.dart
@@ -94,11 +94,11 @@
       final stretches = layoutInDocument(d, h, moved: now)?.stretches;
       openings.sort((a, b) => a.$1.value.compareTo(b.$1.value));
       for (final (o, params) in openings) {
-        final p = l2 - (l - params.position);
+        final p = l2 - (l - params.x); // M-08a: compiles only
         out.add(SetComponentCommand<OpeningParams>(
             o,
             params.copyWith(
-                position: stretches == null
+                x: stretches == null
                     ? p
                     : _seated(stretches, p, params.width))));
       }
--- worktree/apps/floor_planner/lib/selection_panel.dart
+++ scratch/apps/floor_planner/lib/selection_panel.dart
@@ -3,6 +3,7 @@
 import 'package:flutter/material.dart';
 import 'package:jet_cad_2d/jet_cad_2d.dart';
 import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
+import 'package:vector_math/vector_math_64.dart' show Vector2;
 
 import 'panel_focus.dart';
 import 'parametric/box.dart';
@@ -309,7 +310,7 @@
         }
         if (!_isObject<OpeningParams>(target)) return null;
         final o = widget.document.components.get<OpeningParams>(target)!;
-        return kind == _Kind.openingWidth ? o.width : o.position;
+        return kind == _Kind.openingWidth ? o.width : _uOf(o);
     }
   }
 
@@ -346,12 +347,31 @@
         final p = doc.components.get<OpeningParams>(target)!;
         final next = kind == _Kind.openingWidth
             ? p.copyWith(width: value)
-            : p.copyWith(position: value);
+            : _at(p, value);
         if (next == p) return;
         doc.commands.execute(SetComponentCommand<OpeningParams>(target, next));
     }
   }
 
+  /// M-08a: [o]'s stored world centre as a distance along its host.
+  double _uOf(OpeningParams o) {
+    final w = widget.document.components.get<WallParams>(o.host);
+    if (w == null) return double.nan;
+    final q = widget.document.tree
+        .accumulatedTransform(o.host)
+        .invert()
+        .transformPoint(Vector2(o.x, o.y));
+    return (q - w.start).dot((w.end - w.start).normalized());
+  }
+
+  /// M-08a: [o] with its world centre [u] along its host.
+  OpeningParams _at(OpeningParams o, double u) {
+    final w = widget.document.components.get<WallParams>(o.host)!;
+    final q = widget.document.tree.accumulatedTransform(o.host).transformPoint(
+        w.start + (w.end - w.start).normalized() * u);
+    return o.copyWith(x: q.x, y: q.y);
+  }
+
   /// Whether [target] is a tool's settings rather than an object.
   static bool _isToolTarget(Handle? target) =>
       target == _toolSettings ||
--- worktree/apps/floor_planner/lib/startup_plan.dart
+++ scratch/apps/floor_planner/lib/startup_plan.dart
@@ -259,7 +259,10 @@
           parent: doc.rootHandle,
           transform: Transform2.identity(),
           children: const [])),
-      SetComponentCommand<OpeningParams>(h, o),
+      SetComponentCommand<OpeningParams>(
+          h,
+          o.placedOn(doc.components.get<WallParams>(o.host)!,
+              doc.tree.accumulatedTransform(o.host))),
     ], label: 'Add ${o.kind.name}'));
   }
 
--- worktree/apps/floor_planner/test/support/opening_fixture.dart
+++ scratch/apps/floor_planner/test/support/opening_fixture.dart
@@ -140,7 +140,12 @@
           parent: doc.rootHandle,
           transform: at ?? Transform2.identity(),
           children: const [])),
-      SetComponentCommand<OpeningParams>(h, o),
+      SetComponentCommand<OpeningParams>(
+          h,
+          switch (doc.components.get<WallParams>(o.host)) {
+            final w? => o.placedOn(w, doc.tree.accumulatedTransform(o.host)),
+            null => o,
+          }),
     ], label: 'Add opening');
 
 /// The select tool's group delete (`select_tool.dart` `_groupCascade`):
@@ -157,6 +162,13 @@
 OracleFrame oracleFrameOf(DraftDocument doc, Handle h) => oracleFrame(
     doc.components.get<WallParams>(h)!, doc.tree.accumulatedTransform(h));
 
+/// M-08a: [o]'s stored world centre projected onto its host's oracle
+/// frame, as a distance along the centreline.
+double storedU(DraftDocument doc, OpeningParams o) {
+  final f = oracleFrameOf(doc, o.host);
+  return (Vector2(o.x, o.y) - f.s).dot(f.d);
+}
+
 /// [f]'s world point [u] along the centreline and [off] along `n`.
 Vector2 oracleAt(OracleFrame f, double u, double off) =>
     Vector2(f.s.x + f.d.x * u + f.n.x * off, f.s.y + f.d.y * u + f.n.y * off);
@@ -421,7 +433,7 @@
   /// width clamped into it. Null when none holds it, or for a degenerate
   /// width or position.
   OracleCut? cut(OpeningParams o) {
-    final c = o.position, w = o.width;
+    final c = storedU(doc, o), w = o.width;
     if (!c.isFinite || !w.isFinite || !(w > _tol)) return null;
     (double, double)? best;
     var bestD = double.infinity;
@@ -503,7 +515,7 @@
   /// its unclamped interval `[lo, hi]` exactly, ascending; and whether that
   /// interval leaves the [span] (a corner).
   ({List<Handle> walls, bool corner}) clampCause(OpeningParams o) {
-    final lo = o.position - o.width / 2, hi = o.position + o.width / 2;
+    final lo = storedU(doc, o) - o.width / 2, hi = storedU(doc, o) + o.width / 2;
     final (s, e) = span(o.host);
     final walls = {
       for (final (a, b, w) in obstacleWalls(o.host))
@@ -533,8 +545,8 @@
       if (h == o && c != null) return (a: c.a, b: c.b, fits: true);
     }
     return (
-      a: p.position - p.width / 2,
-      b: p.position + p.width / 2,
+      a: storedU(doc, p) - p.width / 2,
+      b: storedU(doc, p) + p.width / 2,
       fits: false,
     );
   }
--- worktree/apps/floor_planner/test/opening_object_test.dart
+++ scratch/apps/floor_planner/test/opening_object_test.dart
@@ -184,7 +184,7 @@
 
     List<DraftCommand> edits(DraftDocument d) => [
           SetComponentCommand<OpeningParams>(hD,
-              d.components.get<OpeningParams>(hD)!.copyWith(position: 1100.25)),
+              d.components.get<OpeningParams>(hD)!.copyWith(x: 1100.25) /* M-08a: compiles only */),
           TransformNodeCommand(
               hA,
               Transform2.translation(60000, -45000)
@@ -478,7 +478,7 @@
     run(
         doc,
         SetComponentCommand<OpeningParams>(slid,
-            doc.components.get<OpeningParams>(slid)!.copyWith(position: 2300)));
+            doc.components.get<OpeningParams>(slid)!.copyWith(x: 2300) /* M-08a: compiles only */));
     expect([for (final d in diagnosticsOf(doc)) '${d.code} ${d.handles}'],
         contains('opening.overlap [$slid, ${handles[20]}]'));
     expectOnOracles(doc, 'edited');
```
