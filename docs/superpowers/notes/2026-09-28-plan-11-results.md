# Plan 11 — dimensions: results

**Plan:** [2026-09-28-dimensions.md](../plans/2026-09-28-dimensions.md)
(amended at execution; see "Plan amendments" below).
**Spec:** [2026-09-28-dimensions-design.md](../specs/2026-09-28-dimensions-design.md)
(revision 4, amended at execution; see "Spec amendments" below).
**Mutation log:** [plan-11-mutation-log.md](plan-11-mutation-log.md).
**Spike:** [2026-09-28-dimensions-spike-findings.md](2026-09-28-dimensions-spike-findings.md)
(branch `spike/11-dimensions` at `675f997`, never merged).

**Branch:** `plan-11/dimensions`, cut from `spec-11/dimensions` at
`59aa198` (`main` `9774a55` + spike note `ccd5345` + spec revisions
`a2ba486`, `4fcf228`, `17e7eda`, `1fca97a` + plan `59aa198`), in the
worktree `.claude/worktrees/plan-dims`. **The base for every diff is
`9774a55`** (`main` = `origin/main` when the branch was cut).

**Commits:**
- Tasks 1–16 and their fix rounds: `99ab3ac..75f04d7`.
- Task 17: `6ed9688` (a comment-only lib change: the hidden-host
  residual's second case in `attachCandidates`' doc comment, the Task 16
  review's Minor 2), then the commit that adds this note.
- Next: the final whole-branch review, then the ledger archive
  (`docs/superpowers/ledgers/2026-09-28-dimensions/`) as the branch's last
  commit.
- The human authorised pushes when Task 6 was done (`ed28d61`), when Task
  11 was done (`7d248b2`) and when Task 16 was done (`75f04d7`). This task
  pushed nothing.

**Ledger:** `.superpowers/sdd/2026-09-28-dimensions/progress.md`
(git-ignored while in flight), with the human's decisions in
`brainstorm-decisions.md` beside it. It is the source for every verdict,
ruling, deferral and measurement below that this task did not run itself,
and each such figure says so.

**Environment:** a Linux x86_64 cloud container, Flutter 3.47.2 (Dart
3.13.2) at `/root/flutter`. `flutter build macos --release`, the macOS run
of the gate lines and the look are the human's (the plan's Ruling 11-17).

---

## What was measured

### The four gate lines, pasted with exit codes

Run by this task, in full, with `CI=true`, on the final code tree
`6ed9688` (this note's commit changes documents only). Each gate line ran
as the plan writes it, with its output saved to its own log in the session
scratchpad (`plan11/t17-final-{engine,render,harness,app}.log`, exit codes
in `plan11/t17-final-exits.log`). `git status --short` was empty before and
after: no `analysis_options.yaml` was touched.

**`packages/jet_cad_2d`**, `CI=true dart test`:

```
00:19 +1041 -2: Some tests failed.

Failing tests:
  test/testing/generate_document_test.dart: both text fractions default to zero and change nothing
  test/testing/generate_document_test.dart: the default document is the one Plan 2 measured, byte for byte
```

- 1,041 pass; the two failures are exactly the standing Linux-only hash
  tests. The test command's own exit code is 1 (a separate run of it
  alone, `t17-final-engine-testonly.log`: `00:20 +1041 -2: Some tests
  failed.`, `exit 1`).
- `dart analyze`: `No issues found!`, exit 0.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 155
  files (0 changed) in 0.84 seconds.`, exit 0.
- The gate line's exit (its last command's, after the `;`): **0**.

**`packages/jet_cad_2d_flutter`**, `CI=true flutter test`:

```
01:00 +940 ~1 -7: Some tests failed.
```

The runner's list is truncated ("... and 3 more"); the `[E]` lines in the
same transcript name all seven:

```
test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas) [E]
test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas) [E]
test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas) [E]
test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas) [E]
test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas) [E]
test/golden/text_lod_ladder_golden_test.dart: text lod ladder rung 1 (RenderBackend.canvas) [E]
test/golden/text_lod_ladder_golden_test.dart: text lod ladder rung 2 (RenderBackend.canvas) [E]
```

- 940 pass and 1 standing skip (`Skip: run explicitly: flutter test
  --tags rig --run-skipped`); the seven failures are exactly the standing
  ones. The test command alone exits 1 (`t17-final-render-testonly.log`:
  `00:56 +940 ~1 -7: Some tests failed.`, `exit 1`).
- `flutter analyze`: `No issues found! (ran in 1.8s)`, exit 0.
- `dart format`: `Formatted 177 files (0 changed) in 0.66 seconds.`,
  exit 0.
- The gate line's exit: **0**.

**`apps/dev_harness_2d`**, `CI=true flutter test --concurrency=1`:

```
00:42 +82: All tests passed!
```

- `flutter analyze`: `No issues found! (ran in 1.1s)`; `dart format`:
  `Formatted 22 files (0 changed) in 0.11 seconds.`
- The gate line's exit: **0**.

**`apps/floor_planner`**, `CI=true flutter test`:

```
02:34 +486: All tests passed!
```

- `flutter analyze`: `No issues found! (ran in 1.5s)`; `dart format`:
  `Formatted 101 files (0 changed) in 0.67 seconds.`
- `flutter build web --release`:

  ```
  Compiling lib/main.dart for the Web...                             48.7s
  ✓ Built build/web
  ```

- The gate line's exit: **0**.

**`flutter build macos --release` is OWED:** the container cannot build
macOS (Ruling 11-17).

### Branch-point and final counts, and why they moved

The branch-point counts are the ledger's (measured on `59aa198` by the
controller); the harness's is 10's merge figure (no task touched it).

| suite | branch point | final (this run) | moved |
|---|---|---|---|
| `jet_cad_2d` | +1037 -2 | **+1041 -2** | +4 |
| `jet_cad_2d_flutter` | +940 ~1 -7 | **+940 ~1 -7** | 0 |
| `dev_harness_2d` | +82 | **+82** | 0 |
| `apps/floor_planner` | +348 | **+486** | +138 |

- **Engine +4:** `QF1`–`QF4` (Task 1, `99ab3ac`); the fix round `015d95d`
  added cases, not tests. The engine is unchanged since `015d95d`.
- **Render layer 0:** its diff against `9774a55` is empty.
- **App +138**, each step the ledger's count after the task:

  | task | count after | added |
  |---|---|---|
  | 2 | 361 | +13 |
  | 3 | 363 | +2 |
  | 4, and its fix round | 377, 378 | +14, +1 |
  | 5 | 380 | +2 |
  | 6 | 393 | +13 |
  | 7, and its fix round | 409, 412 | +16, +3 |
  | 8 | 426 | +14 |
  | 9 | 436 | +10 |
  | 10, and its fix round | 440, 442 | +4, +2 |
  | 11, and its fix round | 452, 453 | +10, +1 |
  | 12 | 464 | +11 |
  | 13 | 477 | +13 |
  | 14 | 479 | +2 |
  | 15 | 484 | +5 |
  | 16's fix round | 486 | +2 |

- **The test IDs on the tree:**
  - engine: `QF1`–`QF4`;
  - app: `AP1`–`AP3`, `AM1`–`AM6`, `AM6b`, `DF1`–`DF3`, `DP1`,
    `DL1`–`DL5`, `DL2b`, `DO1`–`DO5`, `DD1`–`DD5`, `DN1`–`DN4`, `DZ1`,
    `TL1`–`TL9`, `GE1`–`GE5`, `GE5b`, `PN1`–`PN5`, `DR1`–`DR5`, `SP1`,
    `SP5`, `SP8`, `SP9`, `SL1`, `RR1`–`RR3`.
  - **Added by the plan and its rulings, beyond the spec's 66:** `DL2b`
    (Task 7), `DD3` (Task 7's fix round), `DD4`, `DD5` (Task 8), `GE5b`
    (Task 11's fix round), `AM6b` (Task 16's fix round). Each is a
    plan-own clause, not a spec identifier.
  - 07's, 08's and 10's app test files are unedited but two. **Only
    `planner_shell_test.dart` differs from `9774a55` by exactly Ruling
    11-14's edits** (two counts less `3 × 6`, the three dimensions
    asserted gone and back on undo, a `dimensionsOn` helper).
    `startup_plan_test.dart` carries Ruling 11-14's two ruled edits
    **and** Task 14's planned `SP1`, `SP5`, `SP8` and `SP9` edits.

### AP1 and AP3 — the attach points at six placements

Printed in this task's app gate:

```
AP1 worst error at origin over 152 points: 4.973799150320701e-14 mm
AP1 worst error at corpus far origin, 23 deg over 152 points: 1.041250292910165e-9 mm
AP1 worst error at corpus far origin, 23 deg, own groups over 152 points: 1.877140660839749e-9 mm
AP1 worst error at +1e9 mm (1e6 m), 23 deg over 152 points: 1.6858739404357614e-7 mm
AP1 worst error at +1e9 mm (1e6 m), 0 deg over 152 points: 0.0 mm
AP1 worst error at +1e9 mm (1e6 m), 23 deg, own groups over 152 points: 3.769728732309794e-7 mm
AP2 C11: worst 0.0 mm; the joined A/1/left [4505142.8564206045,1196487.0508669205] is 5730.741669592764 mm from the drawn one
AP2 C11 scaled 1.5, turned 143: worst 0.0 mm; the joined A/1/left [4505811.273796221,1197229.4035694522] is 5730.7416695642005 mm from the drawn one
AP2 fellBack agreement over 364 walls, 3 local-only fallbacks (1 in the WR13 sweep), 1 reverse-edge walls (1 in the sweep)
AP3 worst distance to a stored vertex at origin over 164 face points: 0.0 mm (bound 1e-9)
AP3 worst distance to a stored vertex at corpus far origin, 23 deg over 164 face points: 0.0 mm (bound 1e-9)
AP3 worst distance to a stored vertex at corpus far origin, 23 deg, own groups over 164 face points: 1.041250292910165e-9 mm (bound 1e-8)
AP3 worst distance to a stored vertex at +1e9 mm (1e6 m), 23 deg over 164 face points: 0.0 mm (bound 0.00001)
AP3 worst distance to a stored vertex at +1e9 mm (1e6 m), 0 deg over 164 face points: 0.0 mm (bound 0.00001)
AP3 worst distance to a stored vertex at +1e9 mm (1e6 m), 23 deg, own groups over 164 face points: 2.6656007498500226e-7 mm (bound 0.00001)
```

`AP1`'s bound is 1e-6 mm; the worst, 3.77e-7 mm, is the spike's `Q1`
figure to the digit. `AP3`'s bounds are Ruling 11-10's as amended at Task 2
(1e-8 in own groups at the corpus far origin; one ulp of 4.5e6 is 9.3e-10
mm). The one reverse-edge wall is the one that kills `X2-step1only`.

### AM1 and AM5 — identification through the index

```
AM1 origin: 60 points; snap kinds {SnapKind.endpoint: 60}; worst |snapped − computed| 0.0 mm
AM1 corpus far origin, 23 deg, own groups: 60 points; snap kinds {SnapKind.endpoint: 60}; worst |snapped − computed| 1.877140660839749e-9 mm
AM1 +1e9 mm (1e6 m), 23 deg, own groups: 60 points; snap kinds {SnapKind.endpoint: 60}; worst |snapped − computed| 4.2981520598697533e-7 mm
AM5 attach search per click, 612 walls: median 1762.0 us of [1697.0, 1703.0, 1762.0, 2848.0, 2966.0] (JIT); candidates [EA/0/left, 5B2/0/right], 3 walls past the line test; thickestWall 286 us
```

`AM1`'s worst gap at +1e9 mm is 4.3e-7 mm against `dimAttach.linear` =
1e-5 mm (a 23× margin, the spike's `Q3a`). `AM5`'s click is above 1 ms at
a corner of 612 walls: each wall past the line test costs one O(n)
`wallsInDocument` (the Task 4 review's heads-up; a click only, printed, not
asserted).

### DF3 — the half through the object, and the far-origin margin

```
DF3 free wall at origin: measured 3450.5, 0.0 from the half, text 3451
DF3 two corners at origin: measured 3450.5, 0.0 from the half, text 3451
DF3 free wall at corpus far origin, 23 deg: measured 3450.5000000001096, 1.0959411156363785e-10 from the half, text 3451
DF3 two corners at corpus far origin, 23 deg: measured 3450.5000000001096, 1.0959411156363785e-10 from the half, text 3451
DF3 free wall at corpus far origin, 23 deg, own groups: measured 3450.5000000000186, 1.864464138634503e-11 from the half, text 3451
DF3 two corners at corpus far origin, 23 deg, own groups: measured 3450.5000000001096, 1.0959411156363785e-10 from the half, text 3451
DF3 free wall at +1e9 mm (1e6 m), 23 deg: measured 3450.499999984674, -1.5325895219575614e-8 from the half, text 3451
DF3 two corners at +1e9 mm (1e6 m), 23 deg: measured 3450.499999984674, -1.5325895219575614e-8 from the half, text 3451
DF3 free wall at +1e9 mm (1e6 m), 0 deg: measured 3450.5, 0.0 from the half, text 3451
DF3 two corners at +1e9 mm (1e6 m), 0 deg: measured 3450.5, 0.0 from the half, text 3451
DF3 free wall at +1e9 mm (1e6 m), 23 deg, own groups: measured 3450.499999984674, -1.5325895219575614e-8 from the half, text 3451
DF3 two corners at +1e9 mm (1e6 m), 23 deg, own groups: measured 3450.499999984674, -1.5325895219575614e-8 from the half, text 3451
```

**D18 reconciled with the measurement** (the Task 7 review's Minor 3): the
worst distance from the half is −1.53e-8 mm, about 65 times inside
`dimFormat.linear` (1e-6 mm), not the "about 1.3×" D9 and D18 estimated
from twice the spike's worst attach error. The spec's D18 is amended to
say so.

### DN4 and DZ1 — the closure and the fuzz

```
DN4 at origin, N = 1: a door slid along the wall: 1 dimension generates; the partition thickened: 1
DN4 at origin, N = 10: a door slid along the wall: 10 dimension generates; the partition thickened: 10
DN4 at origin, N = 50: a door slid along the wall: 50 dimension generates; the partition thickened: 50
DN4 at corpus far origin, 23 deg, own groups, N = 1: a door slid along the wall: 1 dimension generates; the partition thickened: 1
DN4 at corpus far origin, 23 deg, own groups, N = 10: a door slid along the wall: 10 dimension generates; the partition thickened: 10
DN4 at corpus far origin, 23 deg, own groups, N = 50: a door slid along the wall: 50 dimension generates; the partition thickened: 50
DZ1: (edits: 300, failures: 0, generates: 3045, neighbourOnly: 10 edits (11 dimensions), live dimensions: 9 at the end, 1 at the fewest, 6.8 on average, mix: {end: 47, kind: 13, wall group: 23, wall added: 22, dimension moved: 10, end re-attached: 17, page: 15, thickness: 36, wall deleted: 24, dimension added: 35, justification: 17, undo: 21, offset: 10, dimension turned: 7, none: 3}, 910 ms)
```

`DZ1`'s `(edits, failures, generates, neighbourOnly)` is `(300, 0, 3045,
10 edits / 11 dimensions)`; its reload after the run was byte-identical
with `drift()` empty (the test asserts it). The Task 8 review ran seeds
1–20 with no failure (neighbour-only 8–31 per seed; ledger).

### TL8 — the Dimension tool's hover (D12's budget, Ruling 11-21)

```
TL8 612 walls, 0.3 px/mm: median per move over the band path 34.0 us idle, 66.0 us with two points placed (the preview rebuilt each move); on the face line 1098 us, on the centreline 138 us; a Shift slide along a face line 14.0 us per move (worst 51 us); budget 1000 us per move (D12; printed, not asserted)
GE5b 612 walls: end-grip preview along a face line: first 1943 us, median 30 us, worst 1943 us, over 1 ms 1/61 (printed, not asserted)
```

- **Time per move on the band path: 34 µs idle, 66 µs with two points
  placed**, against the 1 ms budget.
- **The first touch of a wall per generation is over budget** (1,098 µs
  here on the face line): it lays out every live wall once (08's
  `wallsInDocument`). The Task 10 re-review measured it at about 0.6–1 ms
  typically and up to about 3.6 ms on 612 walls; a doc change with two
  points placed 4.4–6.8 ms (7.9–23.7 ms before the fix round); on a
  raster over the shell, 13–31 of 4,662 moves over 1 ms, the worst
  3.4–8.9 ms (ledger). **A known limit** (spec D18, amended); the
  follow-ups are below.
- **Every later touch is memoised:** a Shift slide along a face line 14 µs
  per move (it was 920–996 µs per move, worst 7.7 ms, before the Task 10
  fix round; ledger). The grips' preview likewise (`GE5b`: median 30 µs;
  the first preview of a drag pays the layout).

### RR1 and RR2 — the text and the lineweight in pixels

```
RR1 1:50 at 0.15 px/mm: text ink 51.7..238.3 mm above the line (want 50.0..228.6, tol 20.0); slash ink, off it paper; extension line ink 71.7..605.0 mm below the corner (want 75.0..600.0), gap paper
RR1 1:50 at 0.3 px/mm: text ink 48.3..231.7 mm above the line (want 50.0..228.6, tol 10.0); slash ink, off it paper; extension line ink 75.0..601.7 mm below the corner (want 75.0..600.0), gap paper
RR1 1:100 at 0.15 px/mm: text ink 96.7..463.3 mm above the line (want 100.0..457.1, tol 20.0); slash ink, off it paper; extension line ink 145.0..705.0 mm below the corner (want 150.0..700.0), gap paper
RR1 1:100 at 0.3 px/mm: text ink 103.3..463.3 mm above the line (want 100.0..457.1, tol 10.0); slash ink, off it paper; extension line ink 148.3..701.7 mm below the corner (want 150.0..700.0), gap paper
lineweight 25 at 0.052 px/mm (dpr 1.0, captured at 1.0): frames per probe {depth: 32, width: 32, hall: 32}, frames with the line lost {}
lineweight 25 at 0.15 px/mm (dpr 1.0, captured at 1.0): frames per probe {width: 32, hall: 32}, frames with the line lost {}
lineweight 25 at 0.3 px/mm (dpr 1.0, captured at 1.0): frames per probe {hall: 32}, frames with the line lost {}
lineweight 25 at 0.052 px/mm (dpr 3.0, captured at 3.0): frames per probe {depth: 32, width: 32, hall: 32}, frames with the line lost {}
lineweight 25 at 0.15 px/mm (dpr 3.0, captured at 3.0): frames per probe {width: 32, hall: 32}, frames with the line lost {}
lineweight 25 at 0.3 px/mm (dpr 3.0, captured at 3.0): frames per probe {hall: 32}, frames with the line lost {}
set-up 1, D7's caveat, not asserted: lineweight 25 at 0.052 px/mm (dpr 3.0, captured at 1.0): frames per probe {depth: 32, width: 32, hall: 32}, frames with the line lost {depth: 1, hall: 1, width: 2}
set-up 1, D7's caveat, not asserted: lineweight 25 at 0.15 px/mm (dpr 3.0, captured at 1.0): frames per probe {width: 32, hall: 32}, frames with the line lost {width: 2, hall: 2}
set-up 1, D7's caveat, not asserted: lineweight 25 at 0.3 px/mm (dpr 3.0, captured at 1.0): frames per probe {hall: 32}, frames with the line lost {hall: 2}
```

**`RR2`, the measurement of record for decision 20:** with the capture
matched to the view's device pixel ratio (set-ups 2 and 3), 0.25 mm loses
no frame at 0.052, 0.15 and 0.3 px/mm. The drop-outs appear only under
set-up 1 (ratio 3, captured at 1): the capture's own artefact, D7's
finding. So 10's R-17 premise (an axis-aligned hairline painting no pixel)
was measured with a capture below the view's ratio, and the render
follow-up re-measures it with a matched capture before the render layer
changes: STATUS's debt list carries it.

### The sample plan's figures (Task 14's probe, from the ledger)

Task 14's printing probe (Ruling 11-13, never committed) matched **every**
figure of spec D17. The ledger's copy of the probe was pasted by the
controller from `plan11/t14-probe.log` and stops after its 22nd `PROBE`
line; the rest below is from that same scratch log (81 `PROBE` lines), with
the per-line and per-child rows left out:

```
PROBE liveCount 611
PROBE extents Aabb2(11946.966991411009, 7400.0 .. 26400.0, 17053.03300858899)
PROBE page 1:50.0 DisplayUnit.meters sheet Aabb2(11575.0, 7250.0 .. 26425.0, 17750.0)
PROBE dims 5 handles (632, 639, 646, 653, 660)
PROBE dim 632: a 12/0/right b 12/1/right kind DimKind.horizontal offset -500.0 (neg true)
PROBE   text "14.00" height 125.0 at [19000.0,7550.0] rot 0.0
PROBE   references [18]
PROBE   children [633, 634, 635, 636, 637, 638]
PROBE dim 639: a 16/0/right b 16/1/right kind DimKind.vertical offset -300.0 (neg true)
PROBE   text "9.00" height 125.0 at [26250.0,12500.0] rot 1.5707963267948966
PROBE   references [22]
PROBE   children [640, 641, 642, 643, 644, 645]
PROBE dim 646: a 12/0/left b 22/0/left kind DimKind.horizontal offset 900.0 (neg false)
PROBE   text "4.69" height 125.0 at [14595.0,9200.0] rot 0.0
PROBE   references [18, 34]
PROBE   children [647, 648, 649, 650, 651, 652]
PROBE dim 653: a 22/0/right b 32/0/left kind DimKind.horizontal offset 900.0 (neg false)
PROBE   text "4.38" height 125.0 at [19250.0,9200.0] rot 0.0
PROBE   references [34, 50]
PROBE   children [654, 655, 656, 657, 658, 659]
PROBE dim 660: a 12/1/left b (22300.0, 9200.0) kind DimKind.aligned offset 0.0 (neg false)
PROBE   text "3.58" height 125.0 at [24038.274061279444,8773.20580148851] rot -0.2687030246351711
PROBE   references [18]
PROBE   children [661, 662, 663, 664, 665, 666]
PROBE drift []
PROBE diagnostics []
```

- **Entities:** 611; the five dimensions from handle 632, above every room
  child. Children: flags `[0, 2, 2, 0, 0, 0]` (the two extension lines
  not pickable), lineweight 25, ByLayer (the ledger's copy).
- **At 1:100 ft-in** (`SP9`): `45'-11 1/4"`, `29'-6 1/4"`, `15'-4 3/4"`,
  `14'-4 1/2"`, `11'-9"`; one undo step back.
- **The rooms are unchanged:** `SP6`/`SP7` 111,138,800 mm² in all.
- **The Task 14 review's differential:** the real Dimension tool at D17's
  points stores exactly `SP5`'s five `DimensionParams` (decisions 19 and
  22 through the tool); the basin centre is not attachable (1,204.2 mm
  from the nearest attach point); a render at pixel ratio 3 shows the
  overall dimensions inside the A4 sheet; the Kitchen line crosses the
  kitchen door's swing (decision 21 accepts).
- **The startup camera** now frames `doc.extents` with the overall
  dimensions: 0.0573 px/mm in the shell at 1440 × 900 (pick radius 104.7
  mm; the ledger's first figure, 0.08857 px/mm, is the bare surface fit).

### The invariants and greps (Task 16's Part B, re-run by this task)

Task 16 ran Part B at `b3ef430` (N = 32) and its reviewer at `75f04d7` (N =
35). This task re-ran the plan's commands on its final tree, from the
repository root, `BASE=9774a55`, `T1=015d95d` (`plan11/t17-partb.sh`, the
plan's lines with the `spike_dims` grep amended to `--exclude-dir=build`
and two reads added). **The verbatim output is in the mutation log's
"Part B" section** (re-pasted by this task, the Task 16 review's Minor 1).
Every line prints what its comment says:

- the import grep: no match, exit 1; the two pure files import only
  `dart:math`, `package:jet_cad_2d`, `package:vector_math` and app files
  that are themselves pure, read transitively (Ruling 11-2);
- the invariants' diff: 0 lines; `packages/jet_cad_2d/lib`: `style.dart`,
  `query_filter.dart`, `spatial_index.dart`, `parametric_system.dart`;
  its tests: the six Ruling 11-1 files; `jet_cad_2d_flutter`: 0 lines;
  `packages/` since `T1`: 0 lines;
- `EntityFlags.unpickable` in the app: `dimension.dart`'s extension lines
  (and their doc line);
- `Tolerance.standard`, `TrueColor`, the spike's dropped names: no match,
  exit 1;
- **the `spike_dims` grep, amended** (Task 16's ruling): with
  `--exclude-dir=build`, one hit, the provenance comment at
  `apps/floor_planner/test/support/dimension_fixture.dart:8`, the expected
  one; without it, also the git-ignored `build/test_cache`;
- `debugDimensionGenerates`: the declaration and one increment;
- 07's, 08's and 10's test files: 0; `planner_shell_test.dart`: exactly
  Ruling 11-14's edits; `planner_draw_test.dart`: unchanged;
- **N = 37 commits `9774a55..HEAD`, 37 carrying each trailer, 0
  `analysis_options.yaml`**, on the final tree (this note's commit
  included).

Both allocation invariants pass in the gates above, unedited since the
base. `lib/jet_cad_2d.dart` exports `style.dart` (30), `query_filter.dart`
(55) and `spatial_index.dart` (58) whole, so `EntityFlags.unpickable` and
`QueryFilter.snapping()` are public (Task 16, read).

### Mutation tally

From [plan-11-mutation-log.md](plan-11-mutation-log.md):

- **The spec's 75 named mutants: all 75 killed**, re-fired at `5ddd96f`
  (Task 15's head) against each one's full killer list after the rulings:
  **81 fires** (one per site or form), **127 killer commands, 122 red**.
  The five green commands: M-11vertex at `AP3` (ruled dropped: every cap
  point is a stored vertex), M-11negzero's `==` form at `DO3` (a finding,
  fixed by the fixture in `b3ef430`, then red at `DO3` and `DP1`), and
  M-11attachedmoves' grip site at `GE2`, `GE3`, `GE5` (red at `GE1`,
  `GE4`).
  - **Multi-site and multi-form:** M-11negzero (two forms), M-11colour
    (two sites), M-11fallback (both steps), M-11offsetp0 (two sites),
    M-11fixedworld and M-11attachedmoves (the layout and
    `DimensionGrips._pointOf`); M-11closure and M-11text in the frozen
    engine, M-11b-cam and M-11runtime in the frozen render layer, each
    restored (`diff` 0, `git diff --quiet -- packages/` 0).
  - **Re-fired on Task 16's fix** (`49de0e8`): the 22 attach mutants,
    verdicts identical.
- **The fix round's two:** `R4-filterAll` (the Task 4 reviewer's, deferred
  to Task 16, where it exposed the hidden-host defect) and
  `X16-hostVisible`, both red at `AM6b`.
- **The tasks' extras**, copied from the ledger, not re-fired (the plan's
  rule). By this note's count of the log's table, **199 names: 185 killed,
  9 equivalent** (`R-noSimplify`, `rv8-noTriggered`, `rv9-otherIsSelf`,
  `rv10r-clickPassesMap`, `t11-noEqualOther`, `rv11-noOffsetGuard`,
  `rv11r-keyNoOrdinal`, `rv12-strictThreshold`, `rv12-noNormalise`), **1
  accepted** (`rv6-alignedH1`, rounding-sized), **1 accepted as nearly
  equivalent** (M-3, `rv9-shiftNotFromPointerDown`), **2 surviving as
  unreachable in the shell** (`rv11r-keyNoDoc`, `rv11r-dropNoCancel`:
  the select tool swallows keys mid-drag and captures the pointer; the
  Task 11 re-reviewer's reading, no further ruling), and **1 control**
  (`X8-noOracle`).
- **Controls:** the degenerate fixture (a horizontal dimension along a
  free, centred wall at the origin, centre to centre, at the identity) is
  green under M-11a, M-11axisworld, M-11d2, M-11swap, M-11attachedmoves
  and M-11fixedworld, red only under M-11d. `X2-step1only` is **killed**
  at `AP2`, not equivalent (the plan's Controls line was wrong; amended).
- **`SL1`'s later clauses** were fired on a scratch per-clause split,
  never committed (the Task 15 review's Minor 3).
- **A process slip, recorded:** `49de0e8`'s message claimed the two kills
  before they were fired; they were fired straight after, both red, and
  the message was not amended (ledger).

---

## Exit gate

The spec's sixteen criteria and where each is witnessed:

| # | criterion | witness | state |
|---|---|---|---|
| 1 | the four gate lines with `CI=true` on the human's macOS machine; `flutter build macos --release` and `flutter build web --release` | Linux half: the four lines above, with only the standing failures (the engine's 2 hash tests; the render layer's 5 `text_ladder` and 2 Linux-only `text_lod_ladder` goldens, and its skip), and `✓ Built build/web`. **The macOS build and the macOS run of the four lines: the human's machine** | **OWED** |
| 2 | every attach point equals its hand value to 1e-6 mm at every placement; the local-ring fallback's points are the drawn corners | `AP1` (worst 3.77e-7 mm), `AP2` (C11 and its scaled variant 0.0 mm; the reverse edge), `AP3` | PASS |
| 3 | an aligned dimension on a non-axis pair reads the true distance, a linear one its component, at every placement | `DL1` (six placements), `DR1`, `SP8` (the diagonal `3.58`) | PASS |
| 4 | editing a measured wall or its neighbour updates every dimension on it in one undo step; undo and redo exact; `drift()` empty; `DZ1` green with neighbour-only rebuilds | `DN1`, `DN2`, `DN4`, `DZ1` (300 edits, 0 failures, 10 neighbour-only edits), `DO5` | PASS |
| 5 | deleting a referenced wall deletes its dimensions in the same step; undo restores them with their handles | `DN3` (three dimensions on A and a survivor on B; 36 entities restored), `SL1`; the shell's E1 delete (Ruling 11-14) | PASS |
| 6 | values format per unit, half-up at an exact half despite binary floating point; `345.0`, reduced fractions, `'` and `"` in feet-inches only | `DF1`, `DF2`, `DF3` (above) | PASS |
| 7 | the text is 2.5 paper mm at two camera scales and two page scales, centred above its line, readable from the bottom or the right, upward at exactly vertical | `RR1` (above), `DL3`, `DL4`, `DO2` | PASS |
| 8 | a page change regenerates every dimension in one step; a paper change regenerates none | `DO2` (with scale-only and unit-only steps), `SP9` | PASS |
| 9 | save → load → save byte-identical; references intact; `drift()` empty after load | `DO3` (the `-0.0` offset), `DP1`, `QF3`, `DZ1`'s reload | PASS |
| 10 | linear axes are the group's: rotating a plan keeps every value, a linear dimension rotated alone turns its axis, and the panel says so | `DR1`–`DR4`, `PN3` | PASS |
| 11 | the tool (I), its grips and its section behave as D10–D14 say, decisions 19, 22 and 23 included | `TL1`–`TL8`, `GE1`–`GE5`, `GE5b`, `PN1`–`PN5`, `AM1`–`AM6`, `AM6b` | PASS |
| 12 | the dimension lines are 0.25 mm, and `RR2`, captured at the view's device pixel ratio, shows no drop-out at the look's zooms | `DO1` (lineweight 25), `RR2` (above: no frame lost in set-ups 2 and 3) | PASS |
| 13 | the engine and render suites green, `QF1`–`QF4` among them; `packages/` differs from `9774a55` only in D19's four engine files (and their tests); the render layer's diff empty; the allocation invariants pass unedited | the gates above; Part B (the four `lib` files, the six test files, the render layer 0 lines, the invariants 0 lines) | PASS |
| 14 | the sample plan is D17's: five dimensions with their values, 611 entities, `drift()` and `diagnostics()` empty | `SP1`, `SP5`, `SP8`, `SP9`; Task 14's probe matched every figure | PASS |
| 15 | every named mutant killed and logged in `plan-11-mutation-log.md` (M-11b-cam fired in the render layer and restored; M-11fallback as redefined); `roadmap/12` carries its two lines and `roadmap/13` its one | the log: 75 names, 81 fires, all killed; `roadmap/12`'s two open questions and `roadmap/13`'s fifth decision (this task) | PASS |
| 16 | **the human's look**, on macOS, in Chrome and in Firefox | see below | **OWED** |

**14 of 16 PASS; criteria 1 and 16 are OWED.** Criterion 1's Linux half is
green. Nothing was simulated to fill in either owed criterion.

### Review Focus items and their tests

The plan's nine, each with its test (all green in the app gate above):

1. I, a click on a wall corner, the same corner again (and 5 µm away): the
   second click is ignored. `TL4` (through the shell at a legal zoom
   since Task 9's fix round).
2. Shift at the second click (ortho), released before the third
   (aligned), pressed again with no move (linear). `TL2`, `TL5`.
3. A door flush against a T, dimensioned to the stem's corner through the
   door's jamb snap: the end attaches. `AM6`, `TL6`.
4. A wall carrying three dimensions deleted, then cmd+Z: the three go in
   one step and come back with handles and texts. `DN3` (three on A and a
   survivor on B, Task 9's carried item), `SL1`.
5. ft-in at 1:100: every dimension reads ft-in, its text doubles, one undo
   step; Blueprint regenerates nothing. `DO2`, `SP9`, `RR3`.
6. One horizontal dimension rotated alone: its value changes and the panel
   says "Axes turned 30.0°"; rotated with its walls, nothing changes.
   `PN3`, `DR3`, `DR4`, `SL1`.
7. A click on a wall face under an extension line selects the wall; the
   Line tool snaps to nothing at the extension line's end. `SL1`, `TL9`.
8. I typed into the room's Name field types and switches no tool. `TL7`.
9. Enter with two points placed does nothing; Esc drops them, Esc again
   returns to Select. `TL4`.

---

## OWED by the human

**Nothing below is ticked on the human's behalf.**

### Criterion 1's macOS half

- ☐ done ☐ not done: `cd apps/floor_planner && flutter build macos --release` → `✓ Built`.
- ☐ done ☐ not done: the four gate lines with `CI=true` on macOS (engine,
  render layer with only its standing failures, harness, app).

### Criterion 16: the look

Run it on each platform:

- **macOS:** `cd apps/floor_planner && flutter run -d macos --release`;
- **Chrome:** `cd apps/floor_planner && flutter run -d chrome --release`;
- **Firefox:** `build/web`, served statically
  (`cd apps/floor_planner/build/web && python3 -m http.server`).

Use cmd on macOS and ctrl in a browser. For each item and platform, tick
one box.

| # | item | macOS | Chrome | Firefox |
|---|---|---|---|---|
| 1 | **The Dimension tool (I), its three clicks:** click, click, then a third click that places the line; the tool stays active and waits for a new first click; Esc drops pending points, then returns to Select | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 2 | **The tool's preview and Shift:** after one click a rubber band; after two the would-be dimension follows the pointer; holding Shift makes it horizontal or vertical by the side dragged to, releasing it returns to aligned | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 3 | **The attach rings and the status value:** with F3 on, a small ring marks each placed or hovered point that will attach to a wall end point; none with F3 off; the status line reads `Dimension — <value>` exactly as the text will | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 4 | **The sample plan's five dimensions at 1:50, on White and on Blueprint:** the overall width `14.00` and depth `9.00` outside the plan, the Hall `4.69` and the Kitchen `4.38` inside it, the diagonal `3.58`; the ink is the foreground on both papers | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 5 | **The same at 1:100** (ft-in: `45'-11 1/4"` … `11'-9"`): the text and slashes double, in one undo step; switching paper regenerates nothing | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 6 | **0.25 mm beside the walls:** the dimension lines read as thin and never vanish at any zoom (decision 20) | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 7 | **The slashes, the text's size and its side:** 45° ticks leaning the same way; text 2.5 paper mm above its line; a vertical dimension's text reads from the right, upward | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 8 | **Walls moving under dimensions, a joint breaking, a delete, and undo:** a dragged wall updates every dimension on it and its neighbours at once; deleting E1 removes its three dimensions; one cmd/ctrl+Z restores all | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 9 | **Rotating the plan with its dimensions, and one linear dimension alone:** every value kept when the whole plan turns; a horizontal dimension turned alone measures along its turned axis and the section says `Axes turned N°` | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 10 | **The grips:** the offset grip at the line's middle moves the line; an end grip dropped on a corner attaches (also on a grid point there with F3 on), dropped elsewhere detaches; one undo step each | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 11 | **The Dimension section:** the value as displayed; Aligned \| Horizontal \| Vertical switches in one undo step, keeping the ends and the offset; the two end lines (`Wall <hex>, <start/end>, <face>` or `Fixed`) | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 12 | **The collisions decision 21 accepts:** Hall and Kitchen slashes meeting at P1, the Kitchen line across the kitchen door's swing, text over room labels at 1:100; the offset grip fixes each | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 13 | **Clicks under an extension line:** a click on E4's face under the Hall's extension line selects E4; a click on the Hall's dimension line selects the dimension; a window band around the line, slashes and text (not the extension lines) selects it | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |

**Known behaviour to expect,** recorded so the look does not rediscover
it. None of it is an 11 defect.

- **The startup view is wider than before:** the camera fits the
  drawing's extents, which now include the overall dimensions outside the
  plan.
- **A near-vertical dimension's text changes side** as the plan turns
  through vertical (decision 8); **interior extension lines lie on the
  perpendicular walls' faces** and are not seen there (D18).
- **An X crossing of two wall lines** can show an intersection snap; in a
  moved or turned group the engine's intersection snap is wrong (found
  item (a), below). Neither attaches a dimension.
- **A hover that first reaches a wall's line** after an edit can take a
  few milliseconds among hundreds of walls (known limits, below).
- **On Blueprint,** the startup plan's finishes and furniture stay dark
  (fix/post-07's debt).

---

## Found, not fixed

Each is pre-existing unless marked, outside 11's diff, and ruled a
follow-up; none is fixed on this branch (the engine and the render layer
are frozen after Task 1, Ruling 11-20).

- **(a) The phantom intersection snap** (Task 4; confirmed on `main` at
  `9774a55` by the Task 4 reviewer, byte-identical probe output):
  `SpatialIndex._considerIntersections` and `_collectNearSegments` read
  stored payload coordinates as world and never apply `transformOfLeaf`.
  After a group is moved or rotated, intersection snaps appear where no
  geometry crosses (the sample plan with P1 moved −300: 7 distinct phantom
  points at 0.05 px/mm, the worst 240 mm from any wall line), and real
  crossings of moved geometry are missed. It reaches the app through
  `resolveDragPoint` (the placement tools, the select tool's drags).
  Moderate, low frequency; it cannot mis-attach a dimension (attaching
  needs a wall end point within 1e-5 mm). **The human ruled: a separate
  `fix/` branch after Plan 11 merges** (2026-09-29). The fix maps the
  segments through the leaf transform, in the engine.
- **(b) A tapered piece** (Task 4, confirmed by its reviewer), file only:
  a scaled wall group with a flush door draws a tapered piece (07's world
  caps at ±100 against 08's cut in the scaled frame at ±150).
- **(c) A throw at turned placements** (the Task 7 re-review's m4): 07's
  region check throws from `execute` on a thickness the Selection panel
  accepts (1.5e154, and 1e100) at every turned placement, with or without
  dimensions; the edit rolls back. Follow-up: check whether the panel
  catches it. (A huge finite value's `toInt` also saturates on the VM,
  which 11 guards with `kDimMaxValueMm`.)
- **(d) An orphan component** (Task 12; confirmed on `main` at `9774a55`
  by its reviewer): `SetComponentCommand` on a handle with no node
  attaches the component (no throw); `parametric.misplaced` warns; it
  survives save, load and purge and is never drawn. No shipped path
  reaches it (every app `SetComponentCommand` re-checks liveness); a file
  can bring one in. **The fix is a guard in `ParametricEdit`**, after the
  inner command applies (a non-null registered parametric component on a
  handle that is not a live root-level group is refused), not a naive
  guard in `SetComponentCommand` (it would break undo of deletes, whose
  replay re-attaches before restoring the node).
- **(e) A missing liveness filter** (the Task 12 review's side finding;
  07): `wall_grips.dart`'s `_endsAt` loops over
  `withComponent<WallParams>()` without a liveness filter, so an orphan
  `WallParams` (from a file) joins a wall-end drag and draws a phantom
  preview; the comment at `wall_bands.dart:124-127` is inaccurate.
- **A loaded infinite value cannot be saved again** (Ruling 11-12): a
  file may carry `1e999`, which `jsonDecode` reads as Infinity; the
  dimension is then `dimension.broken`, but `jsonEncode` throws on the
  next save (`json_codec.dart:86`). It holds for every component, not
  dimensions alone. A file can never carry a NaN.
- **A stale comment in the render layer** (the Task 1 review):
  `select_tool.dart`'s band rule (about lines 483–489) names the leaves
  `picking()` rejects as "hidden, or on a locked layer"; since D19 a
  not-pickable leaf is skipped the same way. Recorded; the render layer is
  frozen.

---

## Known limits

Recorded, not defects, each by a ruling or a review (spec D18, amended):

- **The first touch of a wall per generation** costs about 0.6–1 ms
  typically and up to about 3.6 ms at 612 walls (1,098 µs in this task's
  `TL8`): the hover or grip preview lays out every live wall once (08's
  `wallsInDocument`); every later touch in the generation is memoised
  (tens of µs). A document change with two points placed costs 4.4–6.8 ms
  there (the Task 10 re-review). A click among 612 walls costs about 1.8
  ms (`AM5`).
- **Collisions** (decision 21): nothing avoids anything and nothing is
  reported; the sample's Hall and Kitchen slashes meet at P1, the Kitchen
  line crosses the kitchen door's swing, text lands on room labels at
  1:100. The offset grip fixes each.
- **The hidden-host residual** (file only; D10 amended): a visible wall
  group whose own children sit on another, hidden layer, or carry
  `EntityFlags.invisible`, while its opening's children are drawn, still
  attaches through the opening. A hidden group, a hidden layer 0 and a
  hidden door are covered (`AM6b`). No command makes the residual case;
  a group's children's layers and flags cannot be read in O(1) through the
  public API.
- **A loaded Infinity cannot be re-saved** (Ruling 11-12, above).
- **R-21's sub-micron edge** (the Task 9 review's M-4): a Shift commit on a
  pair between 1e-6 and about 1.41e-6 mm apart can store a zero linear
  dimension (both kinds measure zero), reported `dimension.degenerate`.
- **The half-up tolerance, both ways** (D9, R-32): the inch over-rounding
  (`(0, 0)–(2124, 1731)` → `9'-0"`) stands; the far-origin margin is about
  65×, not 1.3× (`DF3`, above).
- **The spec's other D18 items** stand as written: the near-vertical
  text's side; interior extension lines on faces; no along-face or
  crossing points; drafted geometry not followed; the between band; which
  wall a corner is stored on; the regeneration fan-out; 07's wide node
  cluster; mirrored groups (the Task 13 review's probe: values kept, text
  unreadable).
- **`rv11r-keyNoDoc` and `rv11r-dropNoCancel`** survive as unreachable in
  the shell (the grips' memo key's document clause; a cancelled drag's
  clear).

## Debt

One line each. None is fixed by this plan.

- **(g) The dash and hairline render re-measure** (D7's finding on 10's
  R-17): 10's axis-aligned drop-out was measured with a capture below the
  view's device pixel ratio; `RR2` loses no frame with a matched capture.
  Re-measure with a matched capture before the render layer changes
  (STATUS's debt list). Dash patterns in paper units stay with it.
- **(f) The hover's first touch:** compute `drawnCapsOf` once per wall in
  `wallEndPoints` (about half the first touch), and neighbours by the
  wall's reach instead of every live wall (it changes 07's wide node
  cluster's points, so it needs its own proof).
- **(a)–(e) above**, each a post-11 `fix/` or follow-up; (a) is the
  human's first.
- **12 inherits two lines:** a dimension style table, and a layer for
  dimensions (`roadmap/12`).
- **13 inherits one:** the not-pickable bit is not DXF (`roadmap/13`).
- **Earlier debt, unchanged:** rotate about a chosen base point (08); the
  Text tool's pending entry lost on a web alt-tab (fix/post-07); 06's bare
  `RemoveNodeCommand`; paste, import and merge must remap stored handles
  (08; dimensions store wall handles too); the opening tools' linear hover
  (08).

---

## Reviews and rulings, per task

Every verdict and ruling below is the ledger's. Each reviewer ran the
gates and re-fired the task's mutants. "→ Task n" means copied verbatim
into Task n's brief (Ruling 11-18).

**Before Task 1.** The controller accepted the plan's spec findings as the
plan rules them (11-6, 11-25, 11-11, 11-12 with the Infinity limit, 11-10,
11-2, gate 13 read for `lib`, `SL1`/`TL9`'s file, 11-7, `GE3` through the
panel's command), with the spec amendments owed to this task.

**Task 1** (`99ab3ac`, fix round `015d95d`), the not-pickable flag.
**Approved.** `QF4`'s vacuous count and the review's `R1b`/`R3` survivors
fixed (engine tests only); `R6-dragSnap` → Task 15 (`TL9`); the stale
`select_tool.dart` comment recorded. The packages froze here.

**Task 2** (`a21a124`, fix round `e7e9622`), the attach points. **Needs
fixes → Approved.** Six plan/spec findings, all confirmed (the plan
amendments); I-1: `R-reversePoints` (the reverse edge pinned by points);
`R-noSimplify` equivalent.

**Task 3** (`b67ef83`), decision 19's choice. **Approved.** `R-bandWide` →
Task 4; `R-noR8` → Task 6; the "turned further" wording → this task;
`FixedEnd`'s `==` → Tasks 6 and 7.

**Task 4** (`31ed3b8`, fix round `402e42f`), the candidates. **Approved;
minors fixed in a round.** Found (a) and (b); `AM2`'s crossing premise; the
612 walls; `R4-leftJust` fixed; `R4-filterAll` → Task 16. The fix round's
report was lost to a container restart; the controller re-fired
`R4-leftJust` and ran the app gate.

**Task 5** (`ac635a2`, fix round `b6f00a5`), the format. **Needs fixes →
Approved.** I-1: the half decided in mm at non-unit quanta
(`R5-quantaTol`); the non-finite note → Task 6.

**Task 6** (`ed28d61`), the object and the layout. **Approved.** Five plan
errors; `rv6-tieBetween`, `rv6-onHiStrict` → Task 7 (`DL2b`); the guard's
site → Task 7.

**Task 7** (`f32ac75`, fix round `94be5e4`), records, page key, save and
load, diagnostics. **Needs fixes → Approved.** I1: an unmeasurable
dimension is broken, not silent (spec D7, D15 amended); M1–M4; the
re-review's m1–m3 → Task 8 (the neutral reason, a NaN offset broken only,
`kDimMaxValueMm`), m4 → found (c).

**Task 8** (`5fff87c`), the closure and the fuzz. **Approved.** `DZ1`
cannot kill M-11a or M-11axisworld (killer lists amended); the constant's
comment and a three-dimension `DN3` → Task 9.

**Task 9** (`dced8e9`, fix round `c8d5dd6`), the tool's clicks. **Needs
fixes → Approved.** I-1: decision 22 through the tool; M-1, M-2 fixed; M-3
accepted as nearly equivalent; M-4 a known limit; M-5 `late final`.

**Task 10** (`a9c7f32`, `45f6bdf`, fix round `23e8bc5`), preview, rings,
notice, cost. **Needs fixes → Approved.** The controller's provisional
acceptance of the on-line hover cost was withdrawn on the review's
evidence (I-1): the per-generation wall-point memo; I-2 and M-1–M-4 fixed.
The re-review's Minors → Task 11 (undo and redo clear the memo; the page
from the document root) and this note (the first touch).

**Task 11** (`24c1a6f`, fix round `7d248b2`), the grips. **Needs fixes →
Approved.** I-1, I-2, M-1 (the reviewer's K1–K3 clauses); M-2 the per-drag
preview memo (`GE5b`). The re-review's M-1r → Task 12.

**Task 12** (`a21a55a`), the section. **Approved.** `PN5`'s premise wrong;
found (d) and (e); the axes angle's rounding and a stale-callback clause →
Task 13.

**Task 13** (`64777ea`), move and rotate. **Approved.** Radians at +1e9
mm; the grips' second sites; `DR4`'s left-face row → Task 14; a
together-move through the shell → Task 15.

**Task 14** (`2351d97`), the sample plan. **Stopped under Ruling 11-14,
ruled, Approved.** Four existing tests changed answer, all the spec's
consequences (the ruled edits); the camera figure corrected; two comments
→ Task 15.

**Task 15** (`5ddd96f`), through the shell and the renders. **Approved.**
Three plan corrections; `RR1`'s text band and two nits → Task 16; `SL1`
stays one test (its later clauses on a scratch split).

**Task 16** (`7b55f12`, `b3ef430`, `e8451d4`, fix round `49de0e8`,
`75f04d7`), mutation testing, invariants and greps. **Stopped under Ruling
11-19 on the hidden host, ruled, fixed, Approved.** Minors: Part B re-run
here (1); the residual's second case in the comment and the log (2, this
task's `6ed9688`); the RR1 sweep accepted (3); the Ruling 11-14 wording
(4, above).

**Task 17** (`6ed9688` and this note's commit): the gates, this note, the
amendments, the log's Part B, STATUS and the roadmap.

---

## Spec amendments

In [2026-09-28-dimensions-design.md](../specs/2026-09-28-dimensions-design.md),
each a paragraph beginning "**Amended at execution (Plan 11)**" at the end
of the section it amends:
- **Header:** a pointer to the amendments and to this note (the status
  line still says revision 3; the text is revision 4).
- **D1:** Ruling 11-2 (the value types in the pure file; `dimension.dart`
  re-exports it); `dimension_attach.dart`'s contents and counters; gate
  13 read for `lib`, the engine's test files.
- **D4:** S-2 wrong (`X2-step1only` killed at `AP2`, the `WR13` sweep the
  witness); M-11vertex's killers; C10, C11.
- **D7:** the two states restated (not laid out when the layout is not
  finite or the value exceeds `kDimMaxValueMm`; reachable by an edit);
  `RR2`'s measurement; `RR1`'s three-pixel band.
- **D9:** `kDimMaxValueMm` (1e9 km) and why; "decided in mm" pinned at
  non-unit quanta; the margin → D18.
- **D10:** **an opening's host attaches only when it is itself drawn**
  (`49de0e8`, `AM6b`) and the residual; the X crossing (defect (a)); the
  hover's and the grips' memos; `decideEnd`'s `!`; `AM3` both orders.
- **D12:** R-21's sub-micron edge; the rubber band in Task 9; the page
  from the document root; `TL8`; `TL4` at a legal zoom.
- **D13:** `GE5b`; the grips' second sites; `t11-noEqualOther`.
- **D14:** `SetComponentCommand` on a dead handle (found (d)), `PN5`; the
  axes angle's rounding; the stale callback.
- **D15:** the fifth broken reason; "only a file makes one" no longer
  holds; NaN broken only; Ruling 11-12 and the Infinity limit; `DD3`–`DD5`.
- **D17:** Task 14's probe; the two `startup_plan` tests and the shell
  counts (Ruling 11-14); the camera; the Kitchen line.
- **D18:** the far-origin margin (65×, not 1.3×); the first touch; the
  hidden-host residual; the Infinity limit; R-21's edge; collisions;
  mirrored groups.
- **D19:** as built; `resolveDragPoint` and `TL9`; the stale render
  comment.
- **Architecture, Files:** `dimension_shell_test.dart` (Ruling 11-1); the
  engine's test files; the app test files edited; the roadmap lines.
- **Testing, tests by area:** Rulings 11-9, 11-10 (as amended), 11-11,
  11-12, 11-7, 11-24; `AP2`'s wording; the 612 walls; `AM2`; `DZ1`,
  `TL8`, `TL5`, `GE5b`, `SL1`'s split; the plan-added IDs.
- **Named mutants:** all 75 killed; M-11snaponly `TL6` only (11-6);
  M-11runtime's render-layer site (11-25); M-11vertex; M-11a and
  M-11axisworld without `DZ1`; M-11fallback's step-1 sentence;
  M-11prefilter +`TL8`, M-11sign and M-11between +`GE2`; the sites; the
  control.
- **Differential check:** `DZ1`'s run and the oracle's independence.
- **Exit gate:** gate 13's precision; 1 and 16 owed.

**D2, D3, D5, D6, D8, D11 and D16 needed none**; D6's and D11's plan-level
items (M-11sign's site, the radians) are in the plan's amendments and the
tests-by-area paragraph.

## Plan amendments

In [2026-09-28-dimensions.md](../plans/2026-09-28-dimensions.md), each a
paragraph beginning "**Amended at execution (Plan 11)**":
- **Header:** a pointer.
- **Rulings:** 11-1 (the plan-own clauses `DL2b`, `DD3`–`DD5`, `GE5b`,
  `AM6b`; the test files; the Ruling 11-14 wording), 11-3 (M-11sign's
  and the other sites), 11-4 (the memos), 11-10 (1e-8), 11-19 (applied
  once), 11-21 (the withdrawn acceptance).
- **Global constraints:** `AM3` not turned further; `--no-pub` in Task
  16's driver.
- **Tasks 1–16**, each at its end: what the task found wrong or made
  precise (Task 2's six, Task 4's crossing and 612, Task 6's five, Task
  7's `DD2` gap, Task 8's `DZ1`, Task 9's `TL4`, Task 10's three, Task
  12's `PN5`, Task 13's radians, Task 14's Ruling 11-14 files and camera,
  Task 15's three), and after Task 16: **`X2-step1only` is killed, not
  equivalent**, and **the `spike_dims` grep amended to
  `--exclude-dir=build`** with the provenance comment at
  `dimension_fixture.dart:8` as its one expected hit.
- **Task 17:** this task's work.
- **Mutant assignment:** M-11vertex, M-11a, M-11axisworld, the second
  sites, the tally.
- **Exit gate:** filled in here.

---

## Files this task touched

**First commit, `6ed9688`:**
- `apps/floor_planner/lib/parametric/dimension_attach.dart`:
  `attachCandidates`' doc comment names the residual limit's second case,
  children carrying `EntityFlags.invisible` under a visible group (the
  Task 16 review's Minor 2). Comment only; the four gates green on it.

**Second commit** (this note's):
- `docs/superpowers/notes/2026-09-28-plan-11-results.md`: this file.
- `docs/superpowers/specs/2026-09-28-dimensions-design.md`: the
  amendments above.
- `docs/superpowers/plans/2026-09-28-dimensions.md`: the amendments above.
- `docs/superpowers/notes/plan-11-mutation-log.md`: Part B re-run on the
  final tree and re-pasted; the residual's second case in the fix round's
  section; the Ruling 11-14 wording.
- `roadmap/12-app-shell.md`: two open questions (a dimension style table,
  a layer for dimensions).
- `roadmap/13-export-and-print.md`: "The not-pickable bit is not DXF", its
  fifth decision already made.
- `roadmap/11-dimensions.md`: the status line.
- `roadmap/00-README.md`: the 11 row and the summary under the table.
- `STATUS.md`: the top paragraph, a Plan 11 section, the branch map and
  "Resume here".
