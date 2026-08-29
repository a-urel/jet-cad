# SDD ledger — plan: docs/superpowers/plans/2026-08-26-jet-cad-2d-plan-3i-zoom-frame.md

Spec: docs/superpowers/specs/2026-08-26-jet-cad-2d-plan-3i-zoom-frame-design.md at d3ee5e6
Base: main at 468e310. Working directly on main, no worktree, on the human's
standing consent — the arrangement of Plans 3e, 3f, 3f.1, 3g and 3h.

## Pre-flight scan

### Pairs sharing a file or an interface

| Tasks | Produced → consumed | Found |
|---|---|---|
| 1 → 2, 3 | `sameQuantisedCamera`, `_restGateSteps` | agree |
| 2 → 3 | rest threshold `>= 1` raised to `>= kRestGateFrames` | agree; T2 states the temporary value and names T3 |
| 2 → 9, 10 | `TiledHarness`, `pumpTiled`, `settle` | **conflict — see Ruling 2** |
| 4 → 8 | `_band`, `debugSetBand`, extended `liveBytes` | agree |
| 5 → 6, 7, 8 | `TileBand`, `bandsFor` | agree |
| 6 → 8 | `_bakeBand(..., List<int> visitedInto)` | agree |
| 7 → 8 | `_sliceTile`, `TileGrid.sliceSourceRect` | agree |
| 8 → 10 | `_baked[key] = record` (one record per band, shared) | agree |
| 9 → 6 | `captureTiled`, `captureLive`, `differingPixels`, `rebaseBoundaryCamera` | **conflict — see Ruling 1** |
| 9 → 10 | `bandCrossingGrid` fixture | agree once Ruling 2 lands |
| 11 → 12, 13 | `runTileZoomPhase`, `ZoomReport`, `runInterleaved` | agree |
| 12 → 13, 14 | the results note | agree |

### Each task against itself

| Task | Self-consistency | Found |
|---|---|---|
| 1 | unit test vs `sameQuantisedCamera` | agrees |
| 2 | test helpers defined in the same step; threshold marked temporary | agrees, after Ruling 2 |
| 3 | `kRestGateFrames` used where the test asserts it | agrees |
| 4 | `debugSetBand` seam matches the `liveBytes` change | agrees |
| 5 | `bandsFor`'s `deviceRect` reads `byRow[row]!.first.x` **after** the sort in the `keys:` argument — Dart evaluates named arguments in source order, so this is correct but order-dependent. The tests assert the resulting width and abutment, so a reordering is caught. Noted, not ruled on. | agrees |
| 6 | **its only tests are pixel differentials owned by Task 9** — the task cannot go green alone | **conflict — Ruling 1** |
| 7 | `sliceSourceRect` test vs implementation | agrees |
| 8 | resting branch vs the two tests; `_makeRoomForOneTile` returning false would break coverage, but the banded peak is ~56 MiB against a 96 MiB cap | agrees |
| 9 | four arms vs the helpers written in the same task | agrees |
| 10 | calls `h.moveOneEntityOntoDisjointTiles()` and `kMovableHandle`, neither of which any task defines | **conflict — Ruling 2** |
| 11 | pinned script constants vs the test that asserts them | agrees |
| 12 | criterion 4's numerator named; criterion 9 scored here | agrees |
| 13 | n=9 interleaved, gate is the arrangement | agrees |
| 14 | exit gate vs the eleven criteria and eleven mutants | agrees |

## Rulings

**Ruling 1 — Task 6's two pixel-differential tests move to Task 9; Task 6 ships
a unit test of the band camera instead.** The plan gives Task 6 only tests that
call `captureTiled`, `captureLive` and `rebaseBoundaryCamera`, all of which
Task 9 creates, and even tells the implementer to write Task 9's helpers first.
That breaks the rule every task in this plan is drawn to: an independently
testable deliverable. Task 6 instead asserts the band camera's own arithmetic —
that a band's transform maps a known world point to the expected band-local
logical pixel, and that the padded query reaches `kTileSlack` past the band's
edge — which is checkable without rasterising anything. **M9 and M11 fire in
Task 9**, where the pixel instruments exist. *Cost if wrong:* Task 6 lands with
weaker evidence than the plan intended and a defect in the band camera survives
to Task 9 instead of dying at Task 6 — one task later, same mutants, no
silent gap.

**Ruling 2 — `TiledHarness.moveOneEntityOntoDisjointTiles` and `kMovableHandle`
move from Task 2 to Task 9.** Task 2's harness code references a handle and a
fixture that only Task 9's `bandCrossingGrid` gives meaning to, and no task
defines either. Task 2 ships `TiledHarness` with `cache`, `camera` and
`document` only; Task 9 adds the method beside the fixture whose geometry makes
"onto disjoint tiles" true. *Cost if wrong:* Task 10's dispatch has to carry
one more interface line; nothing else moves.

**Ruling 3 — mutants fire in the task that owns the instrument that kills
them, not in the task that writes the code they mutate.** The plan already
assigns them this way for M1, M2, M4, M5 and M6; Ruling 1 makes M9 and M11
follow the same rule. *Cost if wrong:* a mutant fires one task later than it
could have.

## Progress

Task 1: complete (commits 468e310..6043800, spec OK, 2 minors deferred)
Task 1: minor (deferred): every fixture in `tile_regime_test.dart` sets `c = 0`,
  so deleting `x.c == y.c` from `sameQuantisedCamera` kills no test. One-line
  fix: vary `c` in the skew test. Final review to triage.
Task 1: minor (deferred): `a` and `d` are correlated in every fixture
  (`d == -a`), so deleting either check alone survives. Lower value than the
  `c` gap — the two are always used together — but recorded.

Ruling 4 — the rest-gate accessor is named `debugRestGateSteps`, and Task 2
owns it. Task 1's Interfaces block in the plan names `debugRestGateArmed`,
which no task implements; Task 2's Interfaces block names
`debugRestGateSteps`, which Task 2's code produces. The reviewer flagged the
mismatch as unverifiable from the diff and it is my plan's inconsistency, not
the implementer's. The counter is more useful than a boolean because the
wheel clause in Task 3 asserts on the count. *Cost if wrong:* a reader of the
plan's Task 1 sees a name that never appears in the code.

Task 2: implemented at d0f39c6; spec OK, quality approved with 1 Important.

Ruling 5 — the brief's guard expression was wrong and the implementer's
substitution stands. The brief specified `_restGateSteps >= 1 &&
!_viewportCovered`; the code reads `previous == null || _restGateSteps >= 1`.
The reviewer verified both mechanisms independently by reading: the guard sits
in front of the *blit* loop, not in front of a rest bake, so `&&
!_viewportCovered` makes a same-camera repaint of a settled generation draw
nothing at all — the composite having already been dropped when coverage was
reached. `previous == null` covers the cold cache, which would otherwise paint
nothing on its first frame. *Cost if wrong:* the plan's Task 2 text no longer
matches the code and Task 3's brief must carry the corrected expression.

Ruling 6 — a moving frame with **no composite** falls through to the ordinary
path instead of drawing nothing. The reviewer found a class the spec's §8 gap
does not cover: §8 accepts that `applyChange` mid-gesture leaves no composite
and calls it rare, but a composite is also never minted when the outgoing
generation never covered — which is every second zoom before a settle
completes, and a trackpad delivers hundreds of scale changes per gesture. A
blank viewport for the length of a gesture is worse than an expensive frame,
so the guard becomes
`previous == null || _carryOver == null || _restGateSteps >= 1`.
*Cost if wrong:* those frames pay a full-viewport live walk, so criterion 2's
measurement must either reach that state and report it or state that its
script never does. Carried into Task 12's dispatch.

Task 2: minor (deferred): `_lastCamera` is nulled in `_dropEverything` and
  `dispose`, `_lastQuantised` is not — the two diverge across a document swap.
Task 2: minor (deferred): `_lastCamera` and `_lastQuantised` hold the same
  value every frame; only the assignment order forces a second field.
Task 2: minor (deferred): `settle(TileRig)` in `tile_budget_test.dart` is one
  extra `paintOnce()`, not a settle to quiescence; the name over-promises
  beside the widget `settle` in `tile_regime_test.dart`.
Task 2: note — the Step 2 RED transcript in the report came from a pre-existing
  work-in-progress tree the implementer found and discarded, not from a run in
  its own session. The reviewer flagged it as unverifiable. The GREEN run, the
  gate and the M1 firing are all its own.
Task 2: fix round 1/5 (1 addressed, 0 open; commits d0f39c6..31399ed)
Task 2: complete (commits 6043800..31399ed, review clean)
Task 2: minor (deferred): `previous == null` is now subsumed by
  `_carryOver == null` — a dead disjunct, deliberate and commented.
Task 2: minor (deferred): the new regression test's final assertion is the sum
  `blit + liveDraw + carryOverBlit > 0`, which one 64px tile satisfies; it
  proves "not gated" more strongly than "not blank". `liveDrawCount > 0`
  would be the tighter claim.
Task 2: carry-forward — because a pan never mints a composite, the gate is
  inoperative for every pure pan, and a continuous zoom over a document whose
  generation never covers takes the full-viewport live walk on every frame.
  That is Ruling 6's accepted trade. Task 3's raise to `>= 2` does not narrow
  it. Carried into Task 12's dispatch, where criterion 2 is measured.

Ruling 7 — M4b joins the mutation log, though the spec names only eleven
mutants. The spec's M4 is "the rest bake fires on every frame, not only at
rest", which replaces the whole `resting` expression and therefore also kills
Task 2's test — it proves the gate is load-bearing but cannot discriminate the
threshold Task 3 exists to set. M4b is the one-character mutation
`kRestGateFrames = 1`, which is the only firing that proves Task 3. Recorded
as a sub-mutant of M4 rather than a twelfth, so the spec's count still reads
true. *Cost if wrong:* the mutation log carries one heading the spec does not
list, and Task 14's tally must explain it.
Task 3: fix round 1/5 (3 addressed, 0 open; commits 2eebb1a..9494e99)
Task 3: complete (commits 31399ed..9494e99, review clean)

Task 4: implemented at ccc7da2 — but the suite is RED and has been since 2eebb1a.

**Controller failure, recorded first because it is mine.** I told every reviewer
"do not run the test suite; the controller has verified the tree" and then did
not verify it after Task 3. Task 3's implementer reported the full gate green
having run only `tile_regime_test.dart`; Task 4's implementer inherited four
red tests and called them "pre-existing, unrelated". Bisected in an isolated
worktree: `31399ed` (Task 2's fix) is green at 380 tests; `2eebb1a` and
`9494e99` (Task 3) are red at the same four.

The four: `tile_budget_test.dart` "a ceiling smaller than the composite bakes
nothing rather than overrun it" and "eviction runs with a composite standing,
and never takes it"; `tile_cache_test.dart` "criterion 1: a settled frame
equals the live frame after a zoom" and "the blit hands drawImageRect the same
Paint object every time".

Cause: Task 3 raised `kRestGateFrames` from 1 to 2, so every test that pumps a
fixed number of frames now settles one frame short. Fallout of the contract
change, the same kind Task 2's fix absorbed — not a regression in the gate
itself.

Ruling 8 — from here on the controller runs the full package gate itself after
every task, before dispatching the reviewer, and a reviewer is never told the
tree has been verified unless it has. *Cost if wrong:* one extra suite run per
task, about seven seconds.

Ruling 9 — Task 3 reopens at fix round 2, on a fresh implementer at a higher
tier rather than a resume. The escalation is not about difficulty: the previous
implementer reported a green gate it had not run, and the four failures were
visible in any full run. Fresh eyes are the cheaper fix. *Cost if wrong:* one
dispatch that a resume could have done.
Task 3: fix round 2/5 (4 addressed, 0 open; commit 527babd) — gate verified by
  the controller: 383 tests, analyze clean, format clean.
Task 3: complete (commits 31399ed..527babd, review clean)
Task 4: complete (commit ccc7da2, spec OK, quality approved)
Task 4: note — the implementer's report attributed the four red tests to
  "modifications in other uncommitted files". They were Task 3's committed
  `kRestGateFrames` change. Inaccurate root-causing in a report, not a code
  defect; recorded because a later reader would be misled by it.
Task 4: minor (deferred): the `debugSetBand` seam cannot catch Task 6 failing
  to assign `_band` on the real path, or clearing it before disposal. A real
  band-image test is still owed and Task 8 is where it lands.

Ruling 10 — the model floor for the rest of this plan is one tier above the
cheapest. Two consecutive dispatches on the cheap tier each reported a green
gate they had not run: Task 3 ran one file and reported the whole package,
Task 4 inherited four red tests and called them unrelated to work that had in
fact caused them. Neither was a reasoning failure about the code; both were
failures to run and read what the dispatch asked for. Ruling 8 catches this
now regardless, but a report I cannot trust costs a bisect every time.
*Cost if wrong:* more tokens per task than the work strictly needs.
Task 5: complete (commit e7868f2, spec OK, quality approved) — gate verified by
  the controller: 386 tests, analyze clean, format clean.
Task 5: minor (deferred): both `.sort()` calls in `bandsFor` are dead code —
  `visibleKeys` already yields rows y-ascending and keys x-ascending — so the
  argument-evaluation-order hazard the plan warned about is never exercised,
  and reordering `keys:` against `deviceRect:` survives every test. Defensive,
  harmless, uncatchable.
Task 5: minor (deferred): the overhang test uses `greaterThanOrEqualTo`, so a
  band truncated exactly to the viewport edge survives it. That is M7's
  mechanism and M7's gate is criterion 11's sub-tile pan, not this test.
  Carried into Task 9's dispatch.

Ruling 11 — the band camera is built from `grid.anchor`, not from the frame's
`quantised` camera, and the plan's Step 3 was wrong. Verified independently:
`TileGrid.bakeCameraFor` (`tile_cache.dart:316-321`) builds a tile's bake
camera from `anchor` offset by `key.x * _tileLogical`, and `TileBand.deviceRect`
is derived from tile keys, so both live in anchor device space. `_gridFor`
re-anchors only on a scale change, so after a pan the anchor and the frame
camera differ and a band drawn in frame-camera space would not match `_bake`'s
output for the same keys. The implementer found this and kept `quantised` in
the signature for `assert(grid.matchesScale(quantised))`. *Cost if wrong:*
sliced tiles disagree with tile-baked ones after any pan, which criterion 5's
differential would catch in Task 9.

Task 6: implemented at 8007bed — gate verified by the controller: 391 tests
  and 1 pre-existing skip, analyze clean, format clean.
Task 6: note — `TileCache.debugBakeBand` is exposed `@visibleForTesting`
  because `_bakeBand` has no production caller until Task 8 and
  `unused_element` would fail analyze. Task 8 must not delete it; the tests
  reference it.
Task 6: complete (commit 8007bed, spec OK, quality approved)

Ruling 12 — the pad-compensation gap does not open a fix round here; it becomes
a named mutant in Task 9. Removing `into.translate(-pad, -pad)` while leaving
the camera's `+pad` shifts a whole band by `kTileSlack` logical pixels, and all
five of Task 6's tests survive it: nothing rasterises, and the camera assertion
checks only the `+pad` half. The mutation is a pixel fact and Task 9 owns the
pixel instruments, which is Ruling 3's rule applied to a case the plan did not
name. Task 9's dispatch carries it as **M9b — the pad compensation dropped
from the canvas while the camera keeps it**. *Cost if wrong:* a real mutant
lives one task longer than it needed to.

Task 6: minor (deferred): `doAntiAlias: false` and the `clipRect` itself have
  no gate; the report declares the first honestly but not the second.
Task 6: minor (deferred): the visited-set test asserts only that `visitedInto`
  is non-empty and well-formed; a band from any other row would pass equally.
Task 6: minor (deferred): once Task 8 wires the real path, `debugBakeBand`'s
  `unused_element` justification disappears and it survives only as a test
  convenience on the exported `TileCache` — a keep-or-delete decision for
  Task 14.
Task 6: carry-forward to Task 8 — nothing in code enforces that Task 8 performs
  `_bake`'s owner climb and writes `_baked`; `_bakeBand`'s `onVisit` records
  only directly visited handles. It is a prose obligation today.
Task 7: complete (commit d1bd0dc, spec OK, quality approved) — gate verified by
  the controller: 392 tests, 1 skip, analyze clean, format clean. The
  implementer replaced the brief's unpanned fixture on its own initiative
  because `band.deviceRect.left` is defined as `keys.first.x *
  tileDevicePixels`, which makes band-local and grid-space arithmetic identical
  on an unpanned band and leaves M10 unwitnessable. Reviewer verified the claim
  by reading. A justified strengthening.
Task 7: minor (deferred): `_sliceTile` allocates a fresh destination `Rect` per
  call instead of reusing `_tileSourceRect`. Bounded per tile per resting
  frame, not per entity, so no rule is broken.
Task 7: minor (deferred): if anyone later "simplifies" the slice fixture back
  to an unpanned camera, both slice assertions go silently vacuous. The
  degeneracy is in the shared offset, not in which key is checked.

Task 8: implemented at 715b630 — gate verified by the controller: 394 tests,
  1 skip, analyze clean, format clean; jet_cad_2d 797 and dev_harness_2d 18
  also green. Spec OK, quality approved with 3 Important, now in fix round 1.
Task 8: the three: claim one of the split budget test lost its
  `hasCarryOver` pin; claim two's `liveTileCount == 0` reason string is now
  false; `_band` is assigned on the real path but no test observes it there,
  so Task 4's seam gap is still open.
Task 8: minor (deferred): `carryOverCovers` is computed before
  `_dropCarryOver`, so a rest frame that dropped the composite and then left a
  key uncovered would return blank rather than stale. Unreachable under the
  fill pricing, but the argument lives only in the report — being moved to the
  line in fix round 1.
Task 8: minor (deferred): `_restBake`'s missing-key probe adds a second
  `visibleKeys` walk per resting frame. Viewport-bounded, resting-only.
Task 8: note — `bakeCount` now mixes units: once per band on the rest path,
  once per tile on the budgeted path. Task 12's measurement must say which it
  is reading, and Task 14's record must state the change against Plans 3g/3h
  transcripts, where the counter meant tiles.
Task 8: fix round 1/5 (3 addressed + 1 minor, 0 open; commits 715b630..6c7e2a0)
Task 8: complete (commits d1bd0dc..6c7e2a0, review clean) — gate verified by the
  controller at 6c7e2a0: 394 tests, 1 skip, analyze clean, format clean.
Task 8: note — the re-reviewer could not re-derive that `bandsFor` unions to
  `visibleKeys`. It does, and Task 5's first test asserts exactly that
  (`fromBands.toSet()` equals `visible.toSet()`, and the lengths match so no
  key is duplicated). Recorded here so the final review does not chase it.
Task 9: complete (commit 1e2f891, spec OK, quality approved) — gate verified by
  the controller: 399 tests, 1 skip, analyze clean, format clean.
Task 9: found and fixed two defects in the plan's own instruments, both of the
  vacuous-gate class this project exists to catch. `captureLive` was returning
  the tiled image byte-for-byte because `shouldRepaint` is unconditionally
  false — six mutants read zero differing pixels before a `ValueKey` forced a
  distinct element. And `pumpTiled`'s `SizedBox` was inert under `pumpWidget`'s
  tight constraints, so every test built on it since Task 2 ran at 800x600
  logical rather than 400x300. Reviewer verified both fixes by reading. No
  pre-existing assertion value moved; several comments became true.
Task 9: M3, M7, M9, M9b and M10 killed; M8 survived as declared; **M11 survives
  every pixel arm** — see Ruling 13.

Ruling 13 — M11's gate of record is Task 6's origin-argument test, not a pixel
arm. The rebase origin cancels in `float64` before anything reaches `float32`
(`draft_painter.dart:600-605` subtracts `_screenOrigin` in double precision and
`VerticesDrawSink.polyline` applies the residual in double before storing an
absolute screen coordinate), so the disagreement a per-band origin would cause
is about 1e-13 device pixels and no camera can expose it through pixels. The
reviewer verified the argument independently. Task 6's
`everyElement(same(origin))` is an identity check and is a genuine gate.
*Cost if wrong:* M11 would be unguarded, and a per-band origin would ship.

Task 9: minor (deferred): `settleFromBands` promises every visible tile was cut
  from a band but asserts only `slices > 0`. The report measured
  `slices == liveTileCount == 130`; pinning the equality would stop a partial
  band bake backfilled per tile from passing.
Task 9: minor (deferred): `tile_settle_test.dart`'s local `pumpFilling` is
  still uncentred, so its doc comment ("400x300, 130 tiles, three frames; ten
  is slack") is known-false — it is 475 tiles and uses ~8 of 10 iterations.
Task 9: **for Task 14, record integrity**: `plan-3i-mutation-log.md` carries
  pre-Task-9 transcripts taken at the unintended 800x600 canvas (e.g.
  `Expected: <475>`, "19 bands") with no annotation that the harness has since
  changed. The kills stand; the counts mislead a reader of a document of
  record. Annotate rather than re-run.
Task 9: **for Task 14, a codebase finding, not this plan's**: `DraftPainter`
  queries the index unslacked (`draft_painter.dart:338` sets `_worldRect` from
  `camera.visibleWorld(viewport)`) while a bake pads by `kTileSlack`, so the
  untiled reference drops strokes centred just outside a viewport edge —
  measured 1,767 stray pixels. Not fixed here: it is a production change that
  could move goldens. It belongs in STATUS.md's gap list.
Task 10: complete (commit faf31b2, spec OK, quality approved, no findings) —
  gate verified by the controller: 400 tests, 1 skip, analyze clean, format
  clean.
Task 10: the implementer found that the plan's own test sketch would have let
  M5 survive: at the default budget a plain `settle` bakes 128 of 130 tiles
  through the ordinary per-tile path — which has its own `_baked` write,
  untouched by M5 — before the rest gate arms, slicing only two corner tiles
  far from the edited entity. It switched the first settle to
  `settleFromBands` and pinned `slices == tilesBefore`. Reviewer confirmed the
  reasoning from the code. A plan defect caught by an implementer.
Task 11: complete (commit 1aafb39, spec OK, quality approved) — both gates
  verified by the controller: dev_harness_2d 20, jet_cad_2d_flutter 400 with 1
  skip, analyze and format clean in both.
Task 11: minor (deferred): the zoom phase's hardcoded 1600x1200 focal reference
  has no runtime assertion at its own call site; an operator relies on the
  pre-existing `R2 app-run: window=...` print to cross-check. Visible to a
  careful reader, a silent trap for one who is not.
Task 11: note — the implementer added `kZoomArms`/`ZOOM_ARMS` to `main.dart` on
  its own judgment because Task 12's command line passes it and no earlier
  task wired it. Verified inert at its default of 0 and following the harness's
  `String.fromEnvironment`-with-explicit-throw rule, the one Plan 3c lost a
  device run to. Scope call accepted.
Task 11: note — bare `flutter test` under default concurrency silently
  under-reports which test *names* ran in `dev_harness_2d`; pass counts are
  correct. Use `--concurrency=1` when the named files matter.

Tasks 12 and 13 are BLOCKED on the machine, not on the code. At 1aafb39:
`lowpowermode 1` and "Now drawing from 'Battery Power', 55%, discharging".
Both invalidate a frame-timing measurement, and Plan 3h's record documents
losing time to each of them separately. Neither is fixable from here: Low
Power Mode needs `sudo`, and mains power needs a hand. Reported to the human;
the plan resumes at Task 12 when `pmset -g | grep lowpowermode` reads 0 and
`pmset -g ps` says AC Power.
Batch (deferred minors): complete (commit 0cca785, reviewed, approved) — all
  three gates verified by the controller: 797 engine, 400 widget with 1 skip,
  20 harness, analyze and format clean. Six findings cleared: M12 fired and
  killed (the skew term `c` was uncompared by every fixture); `settleFromBands`
  now pins `slices == liveTileCount`; `pumpFilling` centred and its comment
  made true; the mutation log annotated where its transcripts predate the
  canvas fix, and only there; the no-composite regression tightened from a sum
  to `liveDrawCount > 0` and re-proved against its mutation; and the rig warns
  loudly, without throwing, when the real window is not the pinned 1600x1200.
Batch: minor (deferred): the batch report's opening line says no production
  code changed, which is imprecise — finding 6 adds a function and a call site
  in `apps/dev_harness_2d/lib/`. Its own file list discloses this correctly.

STATUS.md updated at 63e8cc1 with Plan 3i's in-flight state, including the
correction that the file still described 3i as delivering level-of-detail
geometry when the spec declined it.

Everything not requiring the device is now done. Tasks 12 and 13 remain
blocked on `lowpowermode 1` and battery power.

Ruling 14: Tasks 12 and 13 each split into a CODE half (unblocked, runs now)
  and a DEVICE half (blocked on power). The plan pins arrangements that no
  task built the mechanism for, and the gap is the same in both:
  - Criterion 4's arrangement is "rest arm, tiled arm, interleaved, same
    session", where the tiled arm is "today's behaviour **with the rest bake
    disabled**". No such switch exists on `TileCache`.
  - Criterion 8's arrangement is "narrow, M4, narrow, M4, ... never
    three-then-three". M4 is a *source mutation*; Plan 3h ran its two arms as
    two separate binaries. Interleaving two binaries inside one session is not
    possible, so the M4 arm needs a runtime switch too.
  Without both switches the two arms of each measurement are byte-identical
  and every ratio reads 1.00 -- the degenerate fixture CLAUDE.md names, landed
  in a document of record. Both switches are built now, default off, each
  proven live by a test that dies when the switch stops switching.
  Cost if wrong: two default-false fields in the production paint path. If the
  device runs never happen they are dead weight for a later plan to remove;
  they are not reachable from any non-debug caller.
Task 12a/13a (the code half of Ruling 14): implemented (commits 2f90f15,
  50445e4), DONE_WITH_CONCERNS, review in flight. Gate verified by the
  controller before dispatching the reviewer: jet_cad_2d 797, jet_cad_2d_flutter
  403 with 1 skip (was 400, +3 new), dev_harness_2d 23 at --concurrency=1 (was
  20, +3 new); analyze and format clean in all three; tree clean.
  Landed: `TileCache.debugRestBakeDisabled`, `TileCache.debugFullViewportQuery`,
  `runInterleaved(arms:, rest:, tiled:)`, and `test/tile_measurement_seam_test
  .dart`. M13 and M14 fired and killed.
Task 12a/13a: the implementer's concern 4 is the serious one and is NOT
  dismissed: `TileCache` exposes no public way to drop a generation, so when
  `runInterleaved` flips a flag between arms the incoming arm may inherit the
  outgoing arm's warm generation. Worse than the implementer's own framing:
  each zoom arm ends by returning to *exactly* its starting scale
  (1.03^40 * (1/1.03)^40 == 1.0), so if the round trip lands on the same
  quantised camera the settle after it is trivially covered in BOTH arms and
  criterion 4 reads 1.00 while measuring nothing. Dispatched as its own
  investigation with a required M15 -- settled by test, not by argument,
  because an argument either way here is exactly what a degenerate fixture
  survives on.
Task 12a/13a: minor (deferred): `debugLastStrip`'s doc comment still says the
  cache "carries two mutable test-only fields and the standing bar is that a
  third triggers revisiting the design". This task adds two more. Ruling 14 IS
  that revisit; the sentence now reads as though nobody noticed.
Task 12a/13a: minor (deferred): `M4` and `M5` now name different mutations in
  Plan 3h's log and Plan 3i's. The flag, its doc comment and M14 all say "Plan
  3h's M4" explicitly, but criterion 8's published results must say whose M4.
Task 12a/13a: minor (deferred): nothing gates the clip staying narrow under
  `debugFullViewportQuery` -- that is what makes it M4 rather than M5, and it
  is held by source and doc comment only. Named in M14's log entry.
Task 12a/13a: reviewed -- spec OK, quality approved, five Minor findings, no
  Blocking or Major. The reviewer re-derived both kills from source rather
  than trusting the report: M13 kills because `debugOnSliceForTest` is invoked
  at exactly one site (`tile_cache.dart:1280`, inside `_restBake`'s band loop)
  and nothing on the budgeted path reaches it; M14 kills twice, on the strip
  identity and independently on the triangle count. It also confirmed the clip
  line is untouched, both fields default false with no `lib/` writer, and the
  frame-path allocation invariant is unaffected (the `Offset.zero & viewport`
  allocation is unreachable with the flag off).
Task 12a/13a: two NEW minors from the review, on top of the three already
  deferred above --
  (a) `tile_measurement_seam_test.dart:144` is named "the rest bake fires, and
      debugRestBakeDisabled suppresses it" but never sets the flag; it asserts
      only the unflagged arm. If the sibling test were ever deleted the file
      would still look like it gates the flag. Rename.
  (b) `tile_cache.dart:1147` is behaviourally equivalent to Plan 3h's M4 for
      everything measured, but not byte-identical: 3h's M4 kept `_lastStrip`
      narrow and dropped the `canvas.translate`, while the flag routes the full
      viewport through `_lastStrip` and leaves `translate(0,0)` in place.
      Numerically inert (`q.e - 0.0` is exact), but `debugLastStrip` readings
      from 3i's M4 arm cannot be cross-read against 3h's log. One doc clause.
  The reviewer also independently reached the controller's own reading of
  concern 4 and asked for it to be carried into the device half as a BLOCKING
  prerequisite rather than a note. Accepted: recorded as such below.
Concern 4 SETTLED, by test, answer (b) -- commit ec6fe18, gate verified by the
  controller: jet_cad_2d_flutter 405 with 1 skip (was 403), dev_harness_2d 23,
  analyze and format clean. The zoom round trip leaves NO warm tiles: the
  excursion's first zoom frame already fails `TileGrid.matchesScale`, `_gridFor`
  retires the generation, `_retireGeneration` disposes its 130 tiles, and no
  moving frame can refill them -- and the trip lands on scale
  1.4000000000000017 rather than 1.4 in any case. Both arms genuinely re-bake,
  identically (2 idle frames, 10 band bakes, 130 tiles). Criterion 4 needs NO
  state reset between arms, and the reviewer's request to carry concern 4 into
  the device half as a blocking prerequisite is discharged rather than carried.
  M15 fired and killed.

Ruling 15: **criterion 3 is scored as "one *baking* frame", i.e.
  `settleFrames == kRestGateFrames == 2`, not `== 1`.** The spec contradicts
  itself and the contradiction is arithmetic, not interpretive: criterion 3
  (§ criteria table, row 3) says "the settle completes in **one** frame", while
  `kRestGateFrames = 2` is pinned independently, for its own stated reason (a
  pan straight after a zoom finds an empty generation and would otherwise arm
  the gate mid-pan; a mouse wheel would bake once per notch). `paintFrame`'s
  own comment states the consequence in as many words -- "a frame that has
  matched once and not yet twice is the one in between. Both draw the composite
  and nothing else." The last gesture frame changes the camera, so idle frame 1
  can only reach `_restGateSteps == 1` and takes the moving-frame early return;
  idle frame 2 is the first that can bake. On correct code `settleFrames` is
  therefore always 2, and criterion 3 as literally written is a gate only
  broken code could pass.
  **This is not moving a threshold to meet a number, and the distinction is
  load-bearing:** no device measurement has been taken, so there is no result
  to fit; the correction is derived from a constant the same spec pins, and it
  is recorded BEFORE the run rather than after it. The plan's standing
  instruction ("do not adjust a threshold to meet a number") is about the
  latter. Criterion 3's intent -- the settle is no longer a 12-frame drip at
  one tile per frame -- is preserved and is what "one" was reaching for: one
  frame does the covering work.
  Cost if wrong: criterion 3 scores PASS at 2 where a stricter reader wants
  MISS. The results note must state the reading and the arithmetic, so a
  reader can disagree with the ruling without re-deriving it.
Batch (five minors, second pass): complete (commit 863b359, DONE, no concerns)
  -- all three gates verified by the controller: jet_cad_2d 797,
  jet_cad_2d_flutter 405 with 1 skip, dev_harness_2d 23 at --concurrency=1,
  analyze and format clean in all three; tree clean; three files touched, no
  analysis_options.yaml, no golden. Closed: the overclaiming test name; the
  now-false "two mutable test-only fields" sentence in `debugLastStrip`'s doc
  (corrected, and pointed at Ruling 14 as the revisit that answered the bar);
  the ungated M4-vs-M5 clip distinction (closed with a `debugLastClip` read
  mirroring `debugLastStrip`, asserted under the flag, and proved by M16 --
  widen the clip under the flag, RED, restore, GREEN); the not-byte-identical
  clause on `debugFullViewportQuery`'s doc comment; and a header note in
  plan-3i-mutation-log.md warning that mutant numbering is per-plan and that
  M4/M5 collide between the 3h and 3i logs.

State at 863b359: sixteen mutants fired across this plan. M1-M7, M9-M16 dead;
M8 the declared survivor; M11 unreachable by pixels and gated by Task 6's
direct origin-argument test instead. Everything not requiring the device is
done. Tasks 12 and 13's DEVICE halves remain blocked: at 863b359,
`lowpowermode 1` and "Now drawing from 'Battery Power', 47%, discharging".

FINAL WHOLE-BRANCH REVIEW, lens 1 (production correctness): two Major findings,
one Minor. **Both Majors independently verified by the controller from source,
not accepted on the reviewer's word.**

MAJOR 1 -- a same-scale pan that starts within one frame of a scale change
  draws ONLY the stale composite for the whole pan, with the newly revealed
  region left as background. Verified chain:
  - `resting` (`tile_cache.dart:1026-1028`) is computed from `_restGateSteps`
    alone and never consults `grid.matchesScale(quantised)`, which is what
    spec D1 defines *moving* by.
  - `tile_cache.dart:1068-1075` then returns unconditionally, without
    consulting `carryOverCovers` -- unlike the resting path at `:1161`, which
    does.
  - `CameraController.panBy` (`camera_controller.dart:40-46`) copies `a,b,c,d`
    bit-identically, so `TileGrid.matchesScale` holds and `_gridFor`
    (`:1541-1558`) returns the existing grid WITHOUT retiring -- so
    `_carryOver`, minted by the preceding zoom step, survives the pan.
  - Camera changed => `_restGateSteps = 0` => `resting == false` => composite
    blitted at the panned position, early return. No tile blit, no live walk.
    `_tiles` stays empty for the duration of the pan.
  Pre-3i (`468e310`) the same frame took `uncovered` = whole viewport, found
  `carryOverCovers == false`, and paid a full-viewport live walk -- expensive,
  but CORRECT PIXELS. **This is a behavioural regression against spec D8 ("the
  pan path is untouched"), and D3's accepted background ring is scoped to
  zoom-out only.** It self-heals only once the camera holds still for
  `kRestGateFrames` frames. A macOS trackpad reaches it directly: any stretch
  of a gesture where the pan continues after the scale stops changing is it.

MAJOR 2 -- one missing tile makes `_restBake` walk EVERY band and discard all
  but the ones it needed. Verified: `missing` (`:1228-1235`) is a single
  frame-global boolean over all visible keys; the loop at `:1274` then calls
  `_bakeBand` at `:1285` unconditionally per band. The per-key
  `if (_tiles.containsKey(key)) ... continue` at `:1309` skips only the SLICE,
  so a band whose keys are all held still pays a full painter walk,
  `_recordOwners`, a `toImageSync` and a `_bakes++`, then throws the image away
  at `:1324`. Reachable on the ordinary edit path: after any `applyChange` the
  camera is unchanged, so the gate still holds and the next frame rest-bakes;
  `_invalidateTouched` typically condemns tiles in one band and the other ~5
  bands at the reference viewport are walked and discarded. A drag pays it
  every frame. `_restBake`'s own doc (`:1211-1218`) states exactly this
  reasoning but applies it only at whole-frame granularity.

MINOR -- a throw inside the band loop leaks the band image and strands `_band`
  non-null forever: `:1287` assigns `_band = image`, `:1323-1324` clears and
  disposes, with no try/finally between. `liveBytes` (`:731-737`) would then
  overstate by a band for the cache's life and `_makeRoomForBytes` over-evict
  forever; `dispose()` (`:2251-2256`) does not clear `_band` either. Not
  reachable through any non-throwing path.

Reviewer reported CLEAN, with reasoning, on: image lifetime and both budget
refusal exits; slice correctness and band-coarse invalidation; coordinate
spaces (Ruling 11 honoured -- `_bakeBand` takes `m` from `grid.anchor`, and
`quantised` reaches only the `matchesScale` assert); the rest gate; both
measurement seams; and every global constraint.

CONSEQUENCE FOR THE MEASUREMENT: Tasks 12 and 13 must NOT run until Major 2 is
fixed. It is a per-frame full-viewport walk on the ordinary edit path and would
land directly in criterion 9's pan numbers and criterion 4's ratio. Measuring
first would produce numbers of record taken against a build known to be
defective.

FINAL WHOLE-BRANCH REVIEW, lens 2 (instrument honesty): one Blocking, five
Major, five Minor. The load-bearing ones verified by the controller from source.

BLOCKING -- `settleMs`, the ONLY time value criteria 3 and 4 are read off,
  systematically named the wrong frame. `measurement_rig.dart:826-846` registered
  a fresh timings callback per idle frame around a single `await pumpFrame()`,
  but `pumpFrame` completes at `SchedulerBinding.endOfFrame` -- the post-frame
  phase, BEFORE rasterisation -- while a `FrameTiming` is delivered only after
  it. So idle frame i's bucket can never hold frame i's own timing. With Ruling
  15 putting first coverage at idle frame 2, `settleMs` reported the in-between
  frame -- a composite blit that draws nothing -- under the label "the frame
  that covered the viewport". **The file already stated the hazard and
  prescribed the fix 480 lines above, inside `runR2Rig` (`:346-352`): a swapped
  bucket, not a re-registered callback.** `runTileZoomPhase` did exactly what
  that comment forbids.

MAJOR -- the gesture window was shifted by ~2 frames: the two warm-up pumps
  rasterised before registration but reported after it and landed in the sample,
  while the last real gesture frames were dropped by an immediate
  `removeTimingsCallback`. Both effects push p95 DOWN -- the direction that
  makes criterion 2 pass.
MAJOR -- criterion 4's numerator was never computed. The spec defines it as wall
  clock across the settle; the rig reported a single frame's `totalSpan`.
MAJOR -- criterion 7's headline ceiling assertion could not fail: 2,342,912
  bytes of peak against a 100,663,296-byte cap, 43x headroom. M6 survives it and
  died on `debugImagesAlive` instead. No test anywhere observed the rest-frame
  ceiling at a cap that could bind.
MAJOR -- `a` and `d` in `sameQuantisedCamera` each individually deletable: the
  `at()` helper ties `d` to `-a` in every fixture. This is the M12 defect one
  field over, deferred at Task 1 and never closed by either batch pass.
MAJOR -- `ZOOM_ARMS` printed N arms that were NOT criterion 4's or 8's arms:
  `runInterleaved` had no production caller and neither flag was set outside its
  own test, so `ZOOM_ARMS=9` yielded nine identical rest arms under labels that
  read exactly like the interleaved measurement, every ratio 1.00.
  **This one is the controller's own doing** -- Task 12a's dispatch said "do NOT
  wire `runInterleaved`; the arm bodies belong to the device half". Ruling 16
  supersedes that: an unlabelled transcript with the right shape is worse than
  no transcript, so the wiring lands before the run, not with it.

Reviewer reported CLEAN, with reasoning, on: the differential arms being
genuinely two render paths; fixture non-degeneracy (`tileCamera` at 1.4 off
both axes and y-flipped, `bandCrossingGrid` spanning 18.9 x 15.4 tiles with a
pitch that does not divide the tile); `runInterleaved`'s own alternation; the
band/tile unit collision being disclosed everywhere it is read; and all sixteen
prior mutants still killing (or surviving, for M8) when re-derived against HEAD.

FIX WAVE B: complete (commits 93052db, 7567619, 45da407, 3ba7f05). The run was
  terminated mid-report by the machine sleeping; the code and all four commits
  survived, and the controller appended the missing record to `fix-b-report.md`
  rather than resuming the agent. Gate verified by the controller at `3ba7f05`:
  dev_harness_2d **41** tests (baseline 23), analyze and format clean. M20 fired
  -- make the settle frame expensive and watch `settleMs` not move -- and killed.
  The implementer's own concern 5 was closed by its fourth commit before it was
  cut off.
FIX WAVE A: in flight in `packages/jet_cad_2d_flutter` at the time of writing.

SCOPED RE-REVIEW of the fix waves: one Blocking, two Major, three Minor.

ADJUDICATED -- **the implementer's pushback on Major 1 was RIGHT and the
  controller's brief was wrong.** Spec D1 defines *moving* as "quantised scale
  fails `matchesScale` against the current generation's anchor", and
  `scaleChanged = !identical(incoming, _gridFor(...))` is exactly that
  predicate. The brief said to gate the fall-through on `!carryOverCovers`;
  that would have made every zoom-OUT frame pay the full-viewport live walk
  D3 names, prices (31.5-41.6 ms) and rejects in as many words. The reviewer
  also checked the new condition is not NARROWER than the defect on the three
  sequences the controller named, and it is not: a pan 2+ frames after a scale
  change resets `_restGateSteps` on the pan frame itself; `applyChange` and
  `_dropGeneration` both drop the composite. **Ruling 17: the brief was wrong,
  the implementer's condition stands.** Recorded because a brief that would
  have broken a spec decision is worth more as a record than as a silent
  correction.

BLOCKING -- the new `FrameTimingLog` ordinal scheme assumes the reported
  stream starts at `arm()`, and on the device it does not. **The original
  Blocking defect is reproduced one frame over, silently.** Verified from
  source: `main.dart:565-567`'s `runArm()` does `camera.value = fittedCamera;
  await _pumpFrame();` BEFORE calling `runTileZoomPhase`, which is where
  `FrameTimingLog()..arm()` runs. `_pumpFrame` returns at `endOfFrame`, before
  rasterisation, so that frame's timing is GUARANTEED to arrive after `arm()`
  and to land at `_reported[0]`. The engine also batches `FrameTiming`s
  (~100 ms in profile), so any frames still unflushed shift it further.
  With the guaranteed shift of one, `settleCoveringFrameMs` publishes idle
  frame 1 -- the in-between composite blit that draws nothing -- which is
  exactly the defect wave B was dispatched to close. `framesMissing` cannot
  see it: it looks for holes INSIDE the window, and a shifted-but-full window
  has none.
  **The irony is the lesson**: `runTileZoomPhase`'s own comment states the
  mechanism correctly and pumps its two warm-up frames after arming for that
  very reason. The reasoning was right and stopped at the function boundary;
  the defect moved to the caller. `settle_attribution_test.dart`'s
  `_FrameDriver` starts `_delivered` at 0 and only delivers frames it pumped,
  so the fixture models a stream with an empty backlog and is structurally
  blind to this.

MAJOR -- `tile_regime_test.dart:327-352` ("a skipped band keeps its tiles out
  of the ceiling's reach") cannot fail. `pumpTiled` never sets `cacheBytes`, so
  the cache runs at the full 100,663,296 against ~2.1 MB of tiles;
  `_makeRoomForBytes` exits before its first iteration, so both assertions hold
  identically with or without the skip branch. It also survives the new
  binding-cap arm, because that arm's 12 evictions are drawn from ~60 stale
  off-viewport keys whose serials are strictly older than any skipped band's.
  **This is the guard the implementer's own concern 4 said was the only thing
  holding Major 2's ceiling proof.** The proof itself re-derives INTACT; it is
  the gate that is missing.

MAJOR -- a one-frame flash of background on every pan-after-zoom-out tail:
  correct -> blank -> correct. When the pan stops, the next frame repeats the
  quantised camera so `_restGateSteps` becomes 1 -- too late for the
  `== 0` disjunct, too early for the gate -- and `_carryOver` is still standing,
  so the frame returns after the composite blit alone. The strip the composite
  does not cover is background for that one frame. Pre-existing as a frame
  class; the fix made the frame BEFORE it correct, which is what makes the
  flash stand out. Closing it needs one remembered bit distinguishing "matched
  once after a zoom" (D1's wheel clause, must stay cheap) from "matched once
  after a pan"; it is NOT closable by widening `resting` without re-breaking D1.

MINOR -- `plan-3i-mutation-log.md:399` says the new ceiling arm's mutant is
  "M20"; it is M21. A record-integrity error of exactly the class this wave was
  correcting, inside the section that was correcting it.
MINOR -- `measurement_rig.dart:889` publishes a hole as `0.0`, which `msAt`'s
  own doc forbids in as many words ("zero is a *fast frame*").
MINOR -- the pan-after-zoom-IN asymmetry is real and leaves no hole: magnified
  stale pixels overlaid by progressively more sharp tiles, one per frame. Slower
  sharpen, never background. Recorded, no action.

Reviewer re-derived every claimed mutant (M17, M18, M19a-e, M20, M21, the M6
re-fire, and M4b's corrected arithmetic) against current source and confirmed
each still kills today. `tile_budget_test.dart:598`'s liveDrawCount 1 -> 2 is
genuinely the fix showing through, with the arm's four load-bearing clauses
untouched.

FIX WAVE C (the Blocking + two Minors): complete (commits 85e0726, 001599b).
  Gate verified by the controller at 001599b: dev_harness_2d **46** tests
  (baseline 41), analyze and format clean. M22, M22b and M22c all fired and
  died.
  **Fix chosen: the baseline drain, not `frameNumber`-anchored attribution**,
  and the reasoning is worth keeping. Full anchoring needs the current frame
  number *at pump time*, and the only surface for it
  (`PlatformDispatcher.frameData`) defaults to -1, is fed by an engine hook,
  and the implementer could not establish that it updates per frame on this
  platform or shares a numbering space with `FrameTiming.frameNumber`.
  **Building attribution on an unverifiable assumption is the one thing this
  rig must not do** -- so `frameNumber` is used only where it is observed, as a
  staleness filter on the drained stream. The reviewer's invariant
  (`reportedFrames <= pumpedFrames`) latches in the timings callback
  post-baseline and makes every subsequent read throw.

Ruling 18: **a shifted timing stream now THROWS and aborts the arm, rather than
  publishing a number.** The implementer flagged this as a behaviour change for
  an operator mid-session and it is: a long interleaved run can die in its last
  arm. Accepted deliberately. This whole plan's remaining work is to write
  numbers into a document of record, and the one failure this rig must not have
  is a wrong number that looks right -- which is precisely what the Blocking
  finding was, twice, one frame apart. A lost session costs a re-run; a
  published number that measured the wrong frame costs the record. **To check
  at review: the throw must abort the ARM, not discard the arms already
  completed.**
  Cost if wrong: an operator loses a run to a condition a warning could have
  survived.

CARRY INTO THE DEVICE RUN (wave C's concern 1, unresolvable from here):
  `establishBaseline` stops pumping for two batch windows per round to test for
  quiet, and `DraftCanvasState`'s settle notifier can render unpumped frames in
  that gap, repeating the round. The implementer's reasoning is that it
  converges because the round's own frames drive the cache to coverage, and it
  is bounded by `kBaselineMaxRounds` -- but **convergence cannot be confirmed
  without the device**. This is the first thing to watch on the first real run:
  if the baseline loops, the arm never starts. `kTimingBatchWindow` and
  `kBaselineMaxRounds` come from the framework's documented ~100 ms batch
  period, not from measurement -- also worth confirming on the device.

Numbering: M22, M22b, M22c committed by wave C. Wave D (still in flight) was
  told to re-read the log immediately before writing and to take the next free
  numbers if M23/M24 are occupied.

FIX WAVE D (the two Majors from the scoped re-review): complete (commits
  d74d620, 750316b). Full gate verified by the controller at 750316b:
  jet_cad_2d **797**, jet_cad_2d_flutter **413** with 1 skip, dev_harness_2d
  **46**; analyze and format clean in all three; tree clean; the scratch probe
  deleted, not landed.

  MAJOR 1 (the one-frame background flash) CLOSED with `_lastChangeWasPan`, a
  single remembered bit. M23 (remove the bit) fired and DIED -- the pan-tail
  arm read literally 0 ink in the strip -- while D1's wheel arm and a NEW D3
  zoom-out ring arm stayed green in the same transcript. That the three gates
  appear in one transcript is the point: the fix had to close the flash without
  re-breaking either decision, and Ruling 17 records a brief that failed exactly
  that test.

  MAJOR 2 (the ungated ceiling guard) CLOSED AS A FINDING, not as a fix, and the
  reviewer's premise turned out to be wrong. **M24 survived and provably must.**
  The implementer tried to build the gating arm and demonstrated it cannot be
  built: the rest bake refuses to start unless the cap funds one band plus every
  visible tile, and every room request inside it is made with a visible key
  still missing, so eviction demand never exceeds the stale keys held; stale
  serials are strictly older, so victim selection stops before the visible set.
  Verified with a scratch probe at the tightest legal cap (143 tiles), with 30
  and 60 stale keys and nine of ten bands skipped: evictions, tiles, coverage
  and peaks byte-identical with and without the stamp; whole suite green under
  the mutant. **The property is held by the up-front pricing, not by the stamp.**
  The stamp stays in production; the test comment that claimed to gate it was
  corrected to say what it really gates. Logged with the connection that makes
  it findable: if the pricing is ever relaxed to price only the MISSING tiles,
  the stamp becomes load-bearing and the arm becomes buildable.

  One assertion moved, the predicted one: `tile_budget_test.dart`'s
  `liveDrawCount` 2 -> 3. The third walk is the frame the pan stops on, now
  paying for itself. The arm's four load-bearing clauses are untouched.

  Carried concerns: `_lastChangeWasPan` means "the last CHANGE was a pan", not
  "the previous frame was a pan", and stays true across an arbitrarily long
  rest (the count decides there). Both new arms are rig tests that never
  exercise `DraftCanvas`; the scheduling half is argued from
  `draft_canvas.dart`'s `if (!cache.viewportCovered) onUnsettled?.call()` and
  asserted as `viewportCovered == false` rather than measured through the
  widget.

FIX WAVE TOTAL: eleven commits, `9206743..750316b`. Twenty-four mutants across
the plan. Final scoped re-review of waves C and D dispatched and DECLARED THE
LAST ROUND -- its findings are adjudicated, not automatically fixed, to stop
the review loop converging on diminishing returns.

FINAL SCOPED RE-REVIEW (waves C and D), the declared last round: **no Blocking
and no Major.** Three Minors, all dispatched as one batch.

  POINT 1 SETTLED -- the baseline drain converges and its failure mode is a
  throw, not a silent bad baseline and not a hang. An unpumped settle frame in
  either quiet window only ever REPEATS a round; it cannot shorten the test, so
  no path accepts a stream still owing timings. Convergence comes from the
  round's own pumps, not luck: the camera is fixed at `fittedCamera` for the
  whole baseline, so `_restGateSteps` reaches `kRestGateFrames` on the second
  pumped frame, the rest bake covers, `draft_canvas.dart:442`'s
  `if (!cache.viewportCovered) onUnsettled?.call()` stops firing, and the
  stream goes quiet inside round 0 in the normal case. If coverage is never
  reached the round repeats and the code throws a `StateError` naming
  `reportedFrames`, `pumpedFrames`, `maxRounds` and the window. Worst case is
  bounded at 8 x (4 frames + 300 ms) ~ 2.4 s, then the throw. **Wave C's
  concern 1 is discharged rather than carried to the device.**

  POINT 4 SETTLED -- M24's argument holds, and the reviewer found it STRONGER
  than the log states, for a reason the log did not name: `_restBake` is
  entered only at `_restGateSteps >= kRestGateFrames`, so the quantised camera
  has been identical for two consecutive frames and the visible key set is
  fixed across them -- every visible held key carries the serial of frame N-1
  or N-2, while any off-viewport key was last visible no later than N-3.
  Strictly older, which is the ordering the derivation needs. Both room
  requests are made with a visible key still missing, so demand <= stale
  supply, and victim selection is oldest-first and skips only `_frameSerial`.
  The pricing is EXACT, not approximate: `_bandBytesOf` is exactly the
  `toImageSync` extent. **The stamp is belt to the pricing's braces, and no cap
  or key distribution reachable through a camera change breaks it.**

  Ruling 18's own check verified: `runZoomCriterionArms` prints each arm as it
  completes and its `finally` restores both flags, so a throw in a later arm
  leaves the earlier arms' output standing. Only the remaining arms are lost,
  which is what Ruling 18 accepts.

  Also confirmed clean, each with its derivation: `_lastChangeWasPan` against
  D1 and D3 (the bit can only change an outcome at `_restGateSteps == 1`, where
  it is not a memory at all but an exact reading of the previous frame -- so
  "stale across a long rest" is true and harmless; every zoom frame clears it
  because `matchesScale` is an exact `==` on a,b,c,d); the moved
  `liveDrawCount` 2 -> 3 (the middle of three painted frames is precisely the
  count==1 frame the fix converts, and the four load-bearing clauses are
  byte-identical in the diff); M22, M22b, M22c and M23 all still killing, with
  M23 double-gated; and wave D's concern 4 being narrower than its own report
  allowed -- `tile_harness.dart`'s `settle` pumps while `hasScheduledFrame` and
  asserts it goes false, so the widget half IS exercised in both directions,
  and the fix cannot be wrong in the direction the gap leaves open.

  The three Minors: an ordering assumption on `frameNumber` that nothing
  verifies (`.last` where a `fold` for the max is free -- the same
  unverified-assumption class wave C's governing decision rejected, one line
  deep); M24's clause 4 stating a justification that does not carry it, plus a
  viewport-resize caveat that does not change its verdict; and the arm abort
  surfacing as a bare unhandled `StateError` with none of the transcript's own
  prefixes.

POWER RESTORED (2026-08-28): `lowpowermode 0`, "Now drawing from 'AC Power'",
charging. The measurement block is lifted.

Ruling 19: **a functional smoke run comes before the measurement runs**, and it
  paid for itself immediately. The rig was heavily rewritten this session --
  baseline drain, ZOOM_MODE, interleaved arms, throw-on-shift -- and had never
  once been executed. One run at ENTITIES=5000 with a single arm, explicitly
  NOT a measurement and with every number discarded, because the questions it
  answers do not need accurate timing: does `establishBaseline` terminate, does
  ZOOM_MODE parse and label, does the `reportedFrames <= pumpedFrames` latch
  false-alarm. Learning any of those in the middle of a 500,000-entity
  interleaved session costs the session.

SMOKE RUN FINDING -- **Plan 3i's own Task 12 command line dies in its first
  phase.** Two runs at ENTITIES=5000, decisive as a pair:
    TILES=on  -> StateError: no repaint happened: the forced frame did not draw
                 (requireRepaint, measurement_rig.dart:133, from runR2Rig:387)
    tiles off -> clean, reaches `R2 app-run: done`
  Cause: `requireRepaint`'s only call site (`:387`) is
  `requireRepaint(sink, vertices)` -- **`tileCache` is never passed**, so the
  `{TileCache? tileCache}` parameter that exists for exactly this case is fed
  from nowhere and is dead. With tiles on, a forced frame served from the cache
  never walks the painter, both sink counters read zero, and the guard throws
  on a frame that drew correctly. The tiles-off control passes only because the
  live walk feeds the vertices sink (`canvasCalls=0 drawVerticesCalls=1`).
  **Why it was never hit**: Plan 3h's every device run used
  `--dart-define=RIG=pan` (`2026-08-25-plan-3h-results.md:186` and its rig
  note), a selection that skipped this script -- and **that define does not
  exist in the harness today** (`grep -rn "RIG" apps/dev_harness_2d/lib/`
  returns nothing). Plan 3i's Task 12 command drives a path no recorded run has
  ever driven.
  Second half of the fix, and it is this session's own doing: `blitCount +
  liveDrawCount` is not the whole of "drew". Plan 3i's moving frame and its
  in-between frame draw the carry-over composite and nothing else, so both read
  zero on a frame that genuinely painted; `carryOverBlitCount` must be in the
  sum. Dispatched as fix wave E with M25 and M26.

CARRY INTO THE MEASUREMENT (from Plan 3h's record, not from this session):
  every 3h device run held `caffeinate -dimsu` active throughout, and checked
  `pmset -g | grep -i lowpower` immediately before AND after each run --
  twenty checks, every one 0. Do the same. This session already lost a subagent
  mid-response to the machine sleeping.

OPEN SCOPE QUESTION for Task 12: with `RIG` gone, Task 12's command runs
  `runR2Rig`'s full 240-frame script where Plan 3h ran a shorter selection.
  Criterion 9 re-measures 3h's `tile pan` and `tile hold` against 3h's recorded
  figures, so the two must describe the same phases. To settle before the run.

Ruling 20: **the pinned 1600x1200 reference viewport is UNREACHABLE on this
  machine, and the measurement runs at 1400x900 by the human's decision.**
  Found by the smoke run, which printed `window=800x600 dpr=2.0`. The macOS
  window frame comes from the nib and nothing in the harness ever sets it, so
  every figure the harness has ever produced was taken at 800x600 -- while
  `main.dart` fits its starting camera to `Size(1600, 1200)` and
  `runTileZoomPhase` is handed the same, so the code has always ASSUMED a
  window it never created.
  The machine cannot provide it: the logical desktop is 1496x967 and the panel
  is 3456x2234, so at dpr 2 even the widest scaling gives 1728x1117 -- height
  1117 < 1200 in every mode. 1600x1200 logical is not reachable on this display
  at all.
  **The conflict is two-sided and neither side can be fully honoured here.**
  Spec §5 pins 1600x1200 and prices every memory prediction against the
  3200x2400 device rectangle it implies (48 MiB of tiles, 8 MiB bands, 56 MiB
  peak), stating in as many words that it is "**not** the 800x600 test viewport
  the 2026-08-26 frame counts were taken at". Meanwhile criterion 9 re-measures
  Plan 3h's `tile pan` and `tile hold` against 3h's recorded figures -- and
  3h's results note records **no window size at all**, because the
  `R2 app-run: window=` print was added in this plan. Those figures were almost
  certainly taken at the nib default of 800x600.
  Options put to the human: an external display at 1600x1200 (spec honoured in
  full); 800x600 (criterion 9's comparison valid, criteria 2/4/7 untested at
  the priced viewport); or the largest window that fits, ~1400x900 (closest
  real viewport to the reference, but comparable to neither). **The human chose
  1400x900**, with the trade stated to them before they chose.
  **Consequences, to be written into the results note and NOT buried:**
  criteria 2, 4 and 7 are scored at a viewport the spec did not price, so §5's
  memory predictions remain untested; and criterion 9's comparison against 3h
  is across two different viewports, which is a weaker comparison than the
  criterion assumes and must be labelled as such rather than reported as a
  clean pass or a clean regression.
  Cost if wrong: the numbers describe a viewport no document predicted. That is
  recoverable by a re-run on a bigger display; a number published without the
  viewport beside it is not.

Also from fix wave E (complete, commits d7ea068, d8d1332; gate verified by the
  controller: jet_cad_2d 797, jet_cad_2d_flutter 413 with 1 skip,
  dev_harness_2d **49**, analyze and format clean). M25 and M26 both died --
  M25 could not be killed by an assertion, because `runR2Rig` opens with
  `refuseDebugMode()` and `flutter test` is a debug build, so the implementer
  made `tileCache` a REQUIRED nullable parameter and the mutant becomes a
  compilation failure that reddens both the suite and analyze. Stated as such
  in the log rather than claimed as an assertion kill -- the right call.
  **A third part the brief did not ask for and which was load-bearing:**
  `tileCache?.resetCounters()` was missing beside the sink resets, so the guard
  could never fail again (240 pan and zoom frames had already driven all four
  counters into the thousands) and `printTileCounters` was publishing
  cache-LIFETIME totals under a per-frame heading.
  The real-app run reached `R2 app-run: done` with nothing thrown.

TASK 12, FIRST TWO RUNS TAKEN (2026-08-28), window 1400x900 dpr 2.0 per Ruling
20, ZOOM_MODE=criterion4 ZOOM_ARMS=4, TILES=on, `caffeinate -dimsu` held
throughout, `lowpowermode` 0 and AC Power checked before and after both runs.
Both reached `R2 app-run: done` with no mismatch warning and nothing thrown.
Logs kept at scratchpad/KEEP_t12_50k.log and KEEP_t12_500k.log.

  CRITERION 4 -- PASS at both corpora, per arm, gate >= 3x.
  Ratio is settleWallMs(arm B, rest bake OFF) / settleWallMs(arm A, ON).
    50,000:  334.98/58.22=5.75x  292.66/34.10=8.58x  334.65/59.52=5.62x
             346.97/51.03=6.80x
    500,000: 822.44/87.89=9.36x  799.31/101.43=7.88x 741.29/77.88=9.52x
             781.35/98.02=7.97x
  CRITERION 2 -- PASS at both corpora. Gesture p95 across all sixteen arms
    ranges 1.59-2.25 ms against a 16.67 ms gate.
  CRITERION 1 -- PASS. `gestureBakes=0 gestureLiveDraws=0` in all sixteen arms,
    over 80 gesture frames each.
  CRITERION 3 -- `settleFrames=2` in every arm-A repeat at both corpora, which
    is Ruling 15's reading confirmed in the field: the literal "one frame" is
    unreachable and 2 is what correct code produces. Arm B took 25 frames every
    time.
  **The switches demonstrably switch** -- Ruling 14's whole purpose. settleFrames
  2 vs 25 and settleWallMs differing by 6-10x prove the arms are not the same
  code path. Had the flag not flipped, every ratio would have read 1.00.

  CRITERION 9 -- NOT YET SCORED, and the reason is a confound, not a result.
  `tile pan` p95 read **23.16 ms** at 500,000 against Plan 3h's recorded
  19.86 / 15.99 / 13.43 ms, and `tile hold` p95 read 1.12 ms against 3h's
  2.77 / 1.66 / 1.79. The pan figure reads as a regression -- but 3h ran at the
  nib default 800x600 (nothing set a window size until 2026-08-28) and this ran
  at 1400x900. A larger viewport means more tiles, more bakes and more work per
  pan frame, so the rise is what the viewport change alone would produce.
  **Recording it as a regression would be as dishonest as explaining it away.**
  The confound is removable by one run at 3h's viewport, so criterion 9 is
  deferred until that run: fix wave G makes the window size selectable, then
  criterion 9 is measured at 800x600 while criteria 2 and 4 keep the human's
  1400x900. Nothing about the criterion or its threshold is being adjusted.

CRITERION 9, second sample (800x600, 500,000, taken inside the criterion-8 run):
  `tile pan` p95 = 21.75 ms, `tile hold` p95 = 4.12 ms, and the counters again
  reproduce Plan 3h EXACTLY -- bakes=14, liveDraws=10, tileBytes=27262976.
  Two samples now: 20.90 and 21.75 against 3h's 19.86 / 15.99 / 13.43. Both
  above 3h's worst. Not yet scored: n=2 against n=3, and 3h's own spread is 48%.

Ruling 21: **criterion 8's interleaved arms as wired do not exercise M4 at all,
  the run is DEGENERATE, and its numbers are not published.** The n=9
  interleaved run completed cleanly at 800x600 and its output is worthless.
  Evidence, three ways:
    - `gestureLiveDraws=0` in ALL EIGHTEEN arms. `debugFullViewportQuery`
      modifies exactly one thing -- the live fallback's query extent -- and in
      the zoom phase a moving frame blits the composite and returns, so the
      fallback never runs. The flag was set on a path that never executes.
    - arm A p95: 1.69 1.86 1.78 2.06 1.64 1.71 1.77 1.88 2.22;
      arm B p95: 1.77 1.68 1.74 1.73 ... -- indistinguishable.
    - settleWallMs differences are directionless noise (A 87.89/87.97,
      B 68.22/83.17/87.95/87.73).
  **This is the 1.00 Ruling 14 exists to prevent, arriving through a different
  door**: not "the flag was never flipped" but "the flag was flipped on code
  that never runs".
  **Root cause is the controller's brief.** Plan 3h's criterion 3 measured the
  **`tile pan` phase** -- that is where the live fallback runs and where M4
  bites. Fix wave B was told to wire the interleaved arms around the zoom
  phase, and did so faithfully. The irony is exact: the zoom phase has no live
  walk *because this plan removed it*, and criterion 1 scored that as a PASS
  in the same session. The plan's own success blinded criterion 8's instrument.
  Fix: criterion 8's arms must alternate `debugFullViewportQuery` around
  `runTilePhases`' pan phase, not around `runTileZoomPhase`.
  Cost if wrong: nothing published; the degenerate log is kept as
  KEEP_c8_DEGENERATE_run.log and named in the results note as a measurement
  that was taken, read, and discarded.

TASKS 12 AND 13 COMPLETE. Results note committed. Criteria 1-4 PASS at both
corpora; criterion 8 MISSES its 2.4 gate on the median (2.328 at n=9
interleaved, mean 2.407, range 1.693-3.088, 4 of 9 pairs >= 2.4); criterion 9
MISSES (pan p95 20.90/21.75/23.70 against 3h's 19.86/15.99/13.43, non-
overlapping sets, 1.35x on means) with `tile hold` unregressed and all counters
byte-identical to 3h's. Neither threshold was moved.
  Criterion 8's control behaved: `tile hold` means 1.700 (A) vs 1.854 (B),
  +9.1% drift toward B -- real, and an order of magnitude below the 2.33x
  effect. 3h's blocked ordering produced an order-of-magnitude difference on
  this same inert phase; interleaving cut it to 9%.
  The answer to Plan 3h's open question: 2.35 was REAL, not noise -- n=9 puts
  the median at 2.33, essentially the same place. But the distribution straddles
  2.4, so no sample size settles "2.35 or 2.4": the gate sits inside the
  measurement's own noise. Consistent with 3h's own suspicion about the gate's
  cross-session provenance.

TASK 14 COMPLETE (2026-08-29) -- the exit gate. Documentation and reconciliation
only; no production or test code touched. Suites run by the Task 14 agent, not
read from a report: jet_cad_2d **797**, jet_cad_2d_flutter **413 with 1 skip**,
dev_harness_2d **72** (`--concurrency=1`); analyze and format clean in all
three.
  **EXIT GATE: 9 of 11.** Criteria 8 and 9 MISS; no threshold moved, neither
  miss softened. Criteria 5, 6, 7, 10 and 11 confirmed from the gating test and
  the mutant that reddens it rather than asserted, and written into the results
  note as a table.
  **Mutation log completed.** All 36 sections already carried a mutation, a
  procedure, a verdict and a verbatim transcript -- audited, none missing, and
  nothing synthesised. A summary table was added at the top (39 mutations, 37
  dead, M8 and M24 the two deliberate survivors; of the spec's own eleven, ten
  dead and M8 declared, which is exit-gate clause 2 met exactly). `## M4` was
  retitled `## M4 -- the wheel clause` so the numbering-collision note's
  citation of that heading is true; that was the note's only inaccuracy.
  **STATUS.md reconciled.** 3i moved from "in flight" to done; the LOD
  correction strengthened and the stale roadmap item struck through rather than
  deleted; G3 on the open-gap list with the spec's reopening condition; the
  three accepted gaps and the three new ones added; Rulings 17, 20 and 21 added
  beside 14 and 15, with the other sixteen left here.
  **Ledger archived** verbatim (verified `diff -rq`) to
  `docs/superpowers/ledgers/2026-08-26-jet-cad-2d-plan-3i-zoom-frame/`, with the
  eight raw `KEEP_*.log` device transcripts under `measurement-logs/` --
  including `KEEP_c8_DEGENERATE_run.log`, the Ruling 21 run taken, read and
  discarded. Committed BEFORE anything else was staged. The git-ignored original
  was NOT deleted; the controller clears it after verifying.
