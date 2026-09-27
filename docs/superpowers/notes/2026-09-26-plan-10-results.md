# Plan 10 — rooms and area: results

**Plan:** [2026-09-26-rooms.md](../plans/2026-09-26-rooms.md) (amended at
execution; see "Plan amendments" below).
**Spec:** [2026-09-26-rooms-design.md](../specs/2026-09-26-rooms-design.md)
(revision 3, amended at execution; see "Spec amendments" below).
**Mutation log:** [plan-10-mutation-log.md](plan-10-mutation-log.md).
**Spike:** [2026-09-26-rooms-spike-findings.md](2026-09-26-rooms-spike-findings.md)
(branch `spike/10-rooms` at `d30bce5`, never merged).

**Branch:** `plan-10/rooms`, cut from `spec-10/rooms` at `d4167e2`
(`origin/main` `418d4c7` + spike note `3054616` + spec revisions `5015828`,
`6163da8`, `9fad8ab` + plan `d4167e2`), in the worktree
`.claude/worktrees/plan-rooms`. **The base for every diff is `418d4c7`**;
the local `main` ref in this workspace is stale (`22957d1`).

**Commits:**
- Tasks 1–19, their fix rounds and the two tasks added in flight (14b and
  14c, decision 29): `abc7e7b..fe22430`.
- Task 20: `962c402` (the fixture's provenance comment, so the
  `spike_rooms` grep is empty), then the commit that adds this note.
- Next: the final whole-branch review, then the ledger archive
  (`docs/superpowers/ledgers/2026-09-26-rooms/`) as the branch's last
  commit.
- The human authorised pushes when Task 6 was done (`76d3803`), when Task
  11 was done (`6fe558e`), and once more at `02130fc` (ledger). This task
  pushed nothing.

**Ledger:** `.superpowers/sdd/2026-09-26-rooms/progress.md` (git-ignored
while in flight), with the human's decisions in `brainstorm-decisions.md`
beside it. It is the source for every verdict, ruling, deferral and
measurement below that this task did not run itself, and each such figure
says so.

**Environment:** a Linux x86_64 cloud container, Flutter 3.47.2 at
`/root/flutter`. `flutter build macos --release`, the macOS run of the
gate lines and the look are the human's (Ruling 10-25).

---

## What was measured

### The four gate lines, pasted with exit codes

Run by this task, in full, with `CI=true`, on the final code tree: `fe22430`
plus the comment edit that became `962c402` (this note's commit changes
documents only). Each command ran separately, in the plan's order, with its
output saved to its own log in the session scratchpad
(`plan10/t20-g-*.log`). `git status --short` afterwards listed only this
task's two edits in progress (the fixture comment and
`roadmap/13-export-and-print.md`): no `analysis_options.yaml`.

**`packages/jet_cad_2d`**, `CI=true dart test`:

```
00:12 +1037 -2: Some tests failed.

Failing tests:
  test/testing/generate_document_test.dart: both text fractions default to zero and change nothing
  test/testing/generate_document_test.dart: the default document is the one Plan 2 measured, byte for byte
```

- Exit 1: 1,037 pass, and the two failures are exactly the two standing
  Linux-only hash tests (Ruling 10-25).
- `dart analyze`: `No issues found!`, exit 0.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 155
  files (0 changed) in 0.47 seconds.`, exit 0.

**`packages/jet_cad_2d_flutter`**, `CI=true flutter test`:

```
00:40 +940 ~1 -7: Some tests failed.
```

Exit 1. The runner's list is truncated ("... and 3 more"); the `[E]` lines
in the same transcript name all seven failures:

```
00:05 +111 -1: /home/user/jet-cad/.claude/worktrees/plan-rooms/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas) [E]
00:06 +115 -2: /home/user/jet-cad/.claude/worktrees/plan-rooms/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas) [E]
00:06 +118 -3: /home/user/jet-cad/.claude/worktrees/plan-rooms/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas) [E]
00:06 +119 -4: /home/user/jet-cad/.claude/worktrees/plan-rooms/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas) [E]
00:06 +120 -5: /home/user/jet-cad/.claude/worktrees/plan-rooms/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas) [E]
00:08 +143 ~1 -6: /home/user/jet-cad/.claude/worktrees/plan-rooms/packages/jet_cad_2d_flutter/test/golden/text_lod_ladder_golden_test.dart: text lod ladder rung 1 (RenderBackend.canvas) [E]
00:09 +163 ~1 -7: /home/user/jet-cad/.claude/worktrees/plan-rooms/packages/jet_cad_2d_flutter/test/golden/text_lod_ladder_golden_test.dart: text lod ladder rung 2 (RenderBackend.canvas) [E]
```

- 940 pass and 1 standing skip (`Skip: run explicitly: flutter test
  --tags rig --run-skipped`). The seven failures are exactly the standing
  ones: `text_ladder` rungs 1–5 and the Linux-only `text_lod_ladder` rungs
  1–2.
- `flutter analyze`: `No issues found! (ran in 1.0s)`, exit 0.
- `dart format`: `Formatted 177 files (0 changed) in 0.47 seconds.`,
  exit 0.

**`apps/dev_harness_2d`**, `CI=true flutter test --concurrency=1`:

```
00:27 +82: All tests passed!
```

- Exit 0.
- `flutter analyze`: `No issues found! (ran in 0.8s)`, exit 0.
- `dart format`: `Formatted 22 files (0 changed) in 0.08 seconds.`,
  exit 0.

**`apps/floor_planner`**, `CI=true flutter test`:

```
01:19 +348: All tests passed!
```

- Exit 0.
- `flutter analyze`: `No issues found! (ran in 1.0s)`, exit 0.
- `dart format`: `Formatted 81 files (0 changed) in 0.38 seconds.`,
  exit 0.
- `flutter build web --release`, exit 0:

  ```
  Compiling lib/main.dart for the Web...                             33.2s
  ✓ Built build/web
  ```

**`flutter build macos --release` is OWED:** the container cannot build
macOS (Ruling 10-25).

### Branch-point and final counts, and why they moved

The branch-point counts are the ledger's (measured on `d4167e2` by the
controller); the harness's is STATUS's for `main` at 08's merge (the plan
touches no harness file).

| suite | branch point | final (this run) | moved |
|---|---|---|---|
| `jet_cad_2d` | +1014 -2 | **+1037 -2** | +23 |
| `jet_cad_2d_flutter` | +936 ~1 -7 | **+940 ~1 -7** | +4 |
| `dev_harness_2d` | +82 | **+82** | 0 |
| `apps/floor_planner` | +244 | **+348** | +104 |

Each step is the ledger's count after the task named.

- **Engine +23:** Task 1, 1,015 (`TX1`); Task 2, 1,016 (`AT1`); Task 3,
  1,018 (`PG1`, `PG2`); Task 4, 1,019 (`DV1`); Task 5, 1,028 (`SV1`–`SV3`,
  `SD1`–`SD5`, `SD8`); Task 6, 1,033 (`SD5b`, `SD6`, `SD9`–`SD11`); Task 7,
  1,037 (`SD7`, `OB1`, `RP2`, `SD11b`). The engine is unchanged since
  Task 7.
- **Render layer +4:** `OL1`, `OL2`, `OL3`, `OL5` (Task 8). The skip and the
  seven failures are the branch point's.
- **Harness 0:** no task touched `apps/dev_harness_2d`.
- **App +104:**

  | task | count after | added |
  |---|---|---|
  | 9, and its fix round | 250, 251 | +6, +1 |
  | 10 | 259 | +8 |
  | 11, and its fix round | 265, 266 | +6, +1 |
  | 12, and its fix round | 275, 276 | +9, +1 |
  | 13 | 289 | +13 |
  | 14 | 300 | +11 |
  | 14b (14c added cases only) | 303 | +3 |
  | 15, and its fix round | 314, 318 | +11, +4 |
  | 16 | 326 | +8 |
  | 17 | 340 | +14 |
  | 18 | 348 | +8 |

  Task 19's audit fix (`4b12f65`) added cases inside `RA1` and `DE1`, not
  tests.

- **The test IDs on the tree** (engine, render and app):
  - engine: `TX1`, `AT1`, `PG1`, `PG2`, `DV1`, `SV1`–`SV3`, `SD1`–`SD11`
    with `SD5b` and `SD11b`, `OB1`, `RP2`;
  - render: `OL1`–`OL3`, `OL5`;
  - app: `RI1`, `RI2`, `RT1`–`RT9`, `LZ1`–`LZ4`, `TN1`, `RL1`–`RL4`,
    `RA1`, `RA2`, `RX1`, `RP1`, `RG1`–`RG7`, `RD1`–`RD8`, `DG1`–`DG4`,
    `RS1`–`RS6`, `RK1`, `RK2`, `DF1`, `FZ1`, `DE1`–`DE3`, `SR1`–`SR5`,
    `TT1`–`TT9`, `ST1`–`ST6`, `SG1`, `RN1`–`RN6`, `GR1`–`GR6`,
    `RR1`–`RR4`, `OL4`, `SP1`–`SP7`.
  - **Added by the plan and its rulings, beyond the spec's list:** `OB1`,
    `SR5`, `DF1`, `FZ1` (Ruling 10-1); `RI2` (Task 9), `LZ4` (Task 11),
    `RG7` (Task 12), `SD5b` (Task 6), `SD11b` (Task 7), `DE1`–`DE3` (Task
    14b), `TT8`, `ST5`, `ST6`, `SG1` (Task 15), `TT9` (Task 17). `SP7` is
    the spec's (D23).
  - 07's and 08's app tests are unedited except `startup_plan_test.dart`
    (D23) and `planner_shell_test.dart` (Ruling 10-22, `2eb2da6`); the
    greps below.

### RT1 — the sample plan's areas at six placements

Printed in this task's app gate (worst error over the six rooms against
the hand areas, D23's table):

```
RT1 worst area error at origin: 0.0 mm2
RT1 worst area error at corpus far origin, 23 deg: 0.000002462416887283325 mm2
RT1 worst area error at corpus far origin, 23 deg, own groups: 0.0000061355531215667725 mm2
RT1 worst area error at +1e9 mm (1e6 m), 23 deg: 0.0007705911993980408 mm2
RT1 worst area error at +1e9 mm (1e6 m), 0 deg: 0.0 mm2
RT1 worst area error at +1e9 mm (1e6 m), 23 deg, own groups: 0.0016147177666425705 mm2
```

The worst is 0.0016 mm², at +1e9 mm turned in own groups, against the
1e-2 mm² of gate 2 (Task 10 measured the same 0.0016). The spike without
the local frame had 96 and 182 mm² there (M-10local).

### RL1 and RL2 — the pole

```
RL1 at origin: the pole at [683.3984375,683.3984375] (plan), 583.3984375 from the boundary
RL1 at corpus far origin, 23 deg: the pole at [687.8464186117053,683.2406497162301] (plan), 583.2406497162301 from the boundary
RL1 at corpus far origin, 23 deg, own groups: the pole at [687.846418610774,683.2406497164629] (plan), 583.2406497164629 from the boundary
RL1 at +1e9 mm (1e6 m), 23 deg: the pole at [687.8464186191559,683.2406497597694] (plan), 583.2406497597694 from the boundary
RL1 at +1e9 mm (1e6 m), 0 deg: the pole at [683.3984375,683.3984375] (plan), 583.3984375 from the boundary
RL1 at +1e9 mm (1e6 m), 23 deg, own groups: the pole at [687.8464188575745,683.2406498193741] (plan), 583.2406498193741 from the boundary
RL2 at origin: the pole at [1951.7578125,1988.8671875] (plan), 1848.2421875 from the column, 1851.7578125 from the walls
```

(`RL2`'s other five placements print alike: 1,848.24 mm from the column
unturned, 1,849.78 turned.)
The thin L's pole is 583.24–583.40 mm from the boundary against 585.786 by
hand, and (685.786, 685.786) by hand against (683.40, 683.40) at the
origin: inside D10's 10 mm precision, as asserted.

### LZ1, LZ3 and SD7 — the localised trace and the bulk pass

```
LZ1: 1440 comparisons, 588 seeds traced a room
SD7 n=200 overlap tests in the edit: 5408 (n²/4 = 10000)
```

- **`LZ1`:** the localised trace equals the all-inputs trace bit for bit
  in 1,440 comparisons (every fixture at six placements, with and without
  200 far walls, decision 29's tied islands included).
- **`LZ3`'s bound** (`room_cost_test.dart`, `kSampleRebuildSegments`): **50
  segments per rebuilt room**, set from Task 18's probe (Ruling 10-20). P5
  moved 10 mm rebuilds the Kitchen and the Bath, 99 segments; their
  localised traces take in 49 and 50; one trace among every contributor
  would take in 41 (on 11 contributors the growth costs more than tracing
  everything; what it buys is a cost that does not grow with the plan).
  With 40 walls added 40 m east the counts are identical. The bound has no
  headroom and is deterministic (the Task 18 review). `LZ3` prints nothing.
- **`SD7`:** 5,408 overlap tests at n = 200 against n²/4 = 10,000. At Task
  7 the count was 5,162, of which about 3,200 were the trigger's
  per-object neighbour searches and about 1,950 the sweep (the Task 7
  review's m-1, ruled into this note); the fix round then counted each
  window evaluation as a pair test (I-1), which gives 5,408. One size
  shows the pass is not quadratic at n = 200 (the plan's design,
  accepted).

### RK2 — a wall move among many rooms (D16.6)

06's NC4 method: JIT, warm-up, the median of five, printed and not
asserted. From this task's app gate, where it ran concurrently with the
other test files:

```
RK2 grid at origin: 97 walls (6 × 7), 22 rooms; move median 2.46 ms [2.46, 3.35, 2.44, 2.33, 2.47]; rooms rebuilt per move [6, 6, 6, 6, 6]
RK2 grid at origin: 312 walls (12 × 12), 73 rooms; move median 5.17 ms [3.99, 6.87, 5.17, 5.28, 4.04]; rooms rebuilt per move [4, 4, 4, 4, 4]
RK2 grid at origin: 612 walls (17 × 17), 146 rooms; move median 8.69 ms [8.69, 8.33, 9.09, 9.39, 8.18]; rooms rebuilt per move [6, 6, 6, 6, 6]
RK2 grid at corpus far origin, 23 deg: 97 walls (6 × 7), 22 rooms; move median 2.44 ms [2.90, 2.34, 2.44, 2.62, 2.33]; rooms rebuilt per move [6, 6, 6, 6, 6]
RK2 grid at corpus far origin, 23 deg: 312 walls (12 × 12), 73 rooms; move median 3.98 ms [3.98, 5.12, 3.67, 4.53, 3.89]; rooms rebuilt per move [4, 4, 4, 4, 4]
RK2 grid at corpus far origin, 23 deg: 612 walls (17 × 17), 146 rooms; move median 8.78 ms [11.13, 11.21, 8.78, 7.46, 8.20]; rooms rebuilt per move [6, 6, 6, 6, 6]
RK2 strips of long exterior walls at origin: 97 walls (8 × 10), 28 rooms; move median 1.27 ms [1.18, 1.27, 1.21, 1.27, 1.93]; rooms rebuilt per move [2, 2, 2, 2, 2]
RK2 strips of long exterior walls at origin: 301 walls (25 × 10), 86 rooms; move median 2.85 ms [2.85, 2.83, 3.24, 2.85, 2.82]; rooms rebuilt per move [2, 2, 2, 2, 2]
RK2 strips of long exterior walls at origin: 601 walls (50 × 10), 168 rooms; move median 6.46 ms [6.46, 6.76, 6.23, 6.25, 6.96]; rooms rebuilt per move [2, 2, 2, 2, 2]
RK2 strips of long exterior walls at corpus far origin, 23 deg: 97 walls (8 × 10), 28 rooms; move median 1.70 ms [1.64, 1.71, 1.66, 2.31, 1.70]; rooms rebuilt per move [2, 2, 2, 2, 2]
RK2 strips of long exterior walls at corpus far origin, 23 deg: 301 walls (25 × 10), 86 rooms; move median 4.28 ms [4.28, 4.51, 3.70, 4.29, 3.62]; rooms rebuilt per move [2, 2, 2, 2, 2]
RK2 strips of long exterior walls at corpus far origin, 23 deg: 601 walls (50 × 10), 168 rooms; move median 7.56 ms [7.56, 7.93, 7.91, 7.14, 7.50]; rooms rebuilt per move [2, 2, 2, 2, 2]
```

- **The rooms rebuilt stay constant with the plan's size:** 2 on the
  strips (the two rooms the moved partition bounds; the long exterior
  walls it tees into do not change, S-4), 4–6 on the grid. D16.6's bound
  counted back (the Task 14 review).
- **The move's time grows about linearly** with the walls: about 8.7 ms
  at 612 walls with 146 rooms, 6.5–7.6 ms at 601 walls with 168 rooms. Task
  14 measured 1.8–10.6 ms warm up to 612 walls and 168 rooms (ledger). It
  is dominated by the per-edit O(n) survey, as 08's `RC3` (below).
- **For comparison, in the same runs:** 07's `NC4` at 600 objects, a move
  2.92 ms; 08's `RC3` at 600 walls with a door each, a move 5.77 ms and a
  line draw 6.72 ms; `RC2` at 600 Posts, a move 4.29 ms. (Engine and app
  gate logs; noisy, concurrent.)

### TT6 and TT8 — the Room tool's hover (D19)

```
TT6 600 walls, a courtyard among 600 free walls: median per Unbounded hover 19.0 us; the first, which builds the contours, 6584 us
TT6 636 walls, outside a connected 636-wall plan: median per Unbounded hover 11.6 us; the first, which builds the contours, 8265 us
```

- **Before the contour cache** (Task 15's review, ledger): 9.9 ms per
  courtyard hover at 600 walls and 12.4 ms outside the connected 636-wall
  plan, re-traced on every move, about 2,000 × the Wall tool's hover.
  **After** (Task 15's fix round): 19.0 µs and 11.6 µs in this run; the
  first hover of a generation pays the contour build, 6.6 and 8.3 ms.
- **`TT8`** compares the cached and the uncached verdicts over a 36 × 36
  hover grid, four plans, six placements (24 lines printed); every
  verdict agrees (the test's assertion), and the contours answer 0–432
  hovers per plan, e.g.:

  ```
  TT8 the sample plan, origin: 1075 faces, 0 hovers answered by the contours
  TT8 the L, origin: 835 faces, 238 hovers answered by the contours
  TT8 a connected 4 × 3 grid and a garden wall, origin: 726 faces, 432 hovers answered by the contours
  TT8 the sample plan, corpus far origin, 23 deg: 1075 faces, 103 hovers answered by the contours
  ```

- For comparison, in the same run: `WT12 n=600: median per hover 4.92 us`
  (07's Wall tool), `OT4 n=600: ... over a wall, with the preview, 10.28 us`
  (08's opening tools).
- **A click** rebuilds `RoomInputs` three times, about 22 ms per click at
  636 walls (the Task 15 review; not taken). Task 17 took the contour build
  off the click path (about 25 ms at 636 walls, ledger).

### FZ1 and DF1 — the random run and the differential check

```
FZ1 seed 1010, 200 steps at corpus far origin, 23 deg, own groups: delete 16; end drag 41; room click 9; room click in an occupied face 155; room click outside a face 82; room dissolved 2; rooms alive at the end 14; separator add 13; separator move 20; separators at the end 9; tint region checked 1855; tint step 1, exact 1855; wall add 31; wall move 45; walls at the end 30
DF1: 20 edits, dissolved {Bath: 11}, 6 rooms, 60 tint points equal bit for bit; diagnostics [Hall and Bedroom 2 share a space]; labels {Hall 339.22 ft², Bedroom 1 102.96 ft², Bedroom 2 339.22 ft², Kitchen 223.62 ft², Living 91.57 ft², Dining 399.42 ft²}
```

- **`FZ1`:** no edit refused because of rooms in 200 steps; every one of
  the 1,855 tint checks is a filled region at step 1 that triangulates
  exactly; every trace equals the all-inputs trace bit for bit and every
  area label equals `formatArea` of the all-inputs area (Task 14's fix
  round). **Before decision 29** (Task 14's fix round, ledger) the same run
  counted 1,330 regions, 465 regions back from step 3 above their labels,
  and **60 step-3 outlines**: the tint lost to a separator tying an island
  to the ring, which Tasks 14b and 14c fixed.
- **`DF1`:** twenty scripted edits on the sample plan rebuilt at the
  corpus far origin in own groups (Ruling 10-21), one of them dissolving
  the Bath (edit 11), a page change to ft-in among them; the incremental
  document and one regenerated from scratch agree on 60 tint points of
  six rooms bit for bit, on the labels and on the diagnostics.

### The tint's cost (Tasks 14b and 14c, ledger)

- The sample plan's trace after decision 29's split: 89 µs (the 14b
  review; unchanged). A pathological comb of ties is about 3× slower after
  the split, and quadratic before and after (the 14b review; its m-2, not
  taken: plan sizes are unaffected).
- `tintOf` with the slit check grows about quadratically with the ring's
  points: 406 µs, 3,656 µs and 25,885 µs at 10, 40 and 120 holes (the 14c
  re-review's final figures; 498/2,855/24,310 µs at the fix round). Fine at
  plan sizes.
- **The fuzz censuses** (the 14c reviews, five seeds, ledger): no step 2
  on a simple hole; every far left-out hole is pinched; the slit end at
  most 0.99999992 mm outside the face across chained bridges; nothing
  worse than before Task 14c except bookkeeping.

### The sample plan's figures (Task 18's probe, from the ledger)

Task 18's printing probe matched **every** figure of spec D23:

- **Entities:** 581 (549 + 28 room children + 1 separator child + 3
  column children).
- **Areas (mm²):** Hall 21,996,100; Bedroom 1 8,450,100; Bedroom 2
  8,413,200; Kitchen 13,972,200; Bath 13,366,100; Living 21,897,500 (one
  hole); Dining 23,043,600; total 111,138,800. The Task 18 reviewer
  recomputed all seven and the total by hand from the coordinates.
- **Clean:** every tint at step 1; `diagnostics()` and `drift()` empty;
  the column 1,340 mm clear of the nearest door's approach; moving P5
  rebuilds 2 rooms.
- **Renders** (scratchpad only, looked at by the controller and the Task
  18 reviewer, never committed): grey tints, the labels, the dashed
  separator, the column's hole, on White and on Blueprint. On Blueprint the
  door gaps are untinted: for the human's look.

### The invariants and greps (Task 19's, re-run by this task)

Task 19 ran them at `749c277` and its audit re-ran them at `d1a81d8`
(ledger). This task re-ran the plan's commands on the final tree, with
`BASE=418d4c7`, after its fixture comment edit; saved as
`plan10/t20-greps.log`:

```
$ grep -rnE "^\s*(import|export)\s+.(package:flutter|dart:ui)" packages/jet_cad_2d/lib apps/floor_planner/lib/parametric/wall_geometry.dart apps/floor_planner/lib/parametric/opening_geometry.dart apps/floor_planner/lib/parametric/room_trace.dart apps/floor_planner/lib/parametric/room_label.dart apps/floor_planner/lib/parametric/room_inputs.dart ; echo "exit $?"
exit 1
$ git diff "$BASE" -- packages/jet_cad_2d/test/invariants packages/jet_cad_2d_flutter/test/invariants | wc -l
0
$ grep -rn "Tolerance.standard" apps/floor_planner/lib/parametric/wall*.dart apps/floor_planner/lib/parametric/opening*.dart apps/floor_planner/lib/parametric/room*.dart apps/floor_planner/lib/parametric/separator*.dart
apps/floor_planner/lib/parametric/room_inputs.dart:196:final double _engineNeighbourOverlap = Tolerance.standard.linear;
$ grep -rn "handleSeed.next" packages/jet_cad_2d/lib/src/parametric/ ; echo "exit $?"
exit 1
$ grep -rnE "debugPlaceBoxCalls\s*(=|\+\+|\+=)" packages/jet_cad_2d/lib
packages/jet_cad_2d/lib/src/parametric/parametric_system.dart:738:    debugPlaceBoxCalls++;
packages/jet_cad_2d/lib/src/parametric/regeneration.dart:35:int debugPlaceBoxCalls = 0;
$ grep -rnE "debugReadBoxCalls\s*(=|\+\+|\+=)" packages/jet_cad_2d/lib
packages/jet_cad_2d/lib/src/parametric/parametric_system.dart:752:    debugReadBoxCalls++;
packages/jet_cad_2d/lib/src/parametric/regeneration.dart:40:int debugReadBoxCalls = 0;
$ grep -rnE "\.placeBox\(" packages/jet_cad_2d/lib
packages/jet_cad_2d/lib/src/parametric/parametric_system.dart:739:    final box = type.placeBox(v, h);
$ grep -rn "TrueColor" apps/floor_planner/lib/parametric/room*.dart apps/floor_planner/lib/parametric/separator*.dart ; echo "exit $?"
exit 1
$ grep -rnE "EntityFlags\.unpickable|\bunpickable\s*=|readsPage|policyFor" packages apps ; echo "exit $?"
exit 1
$ git diff "$BASE" --stat -- packages/jet_cad_2d/lib
 packages/jet_cad_2d/lib/src/document/style.dart    |  12 +
 .../lib/src/parametric/parametric_system.dart      | 357 +++++++++++++++++++--
 .../lib/src/parametric/regeneration.dart           | 334 +++++++++++++++++--
 3 files changed, 661 insertions(+), 42 deletions(-)
$ git diff "$BASE" --stat -- packages/jet_cad_2d_flutter/lib
 .../jet_cad_2d_flutter/lib/src/grip_cache.dart     | 36 ++++++++++++----
 .../jet_cad_2d_flutter/lib/src/outline_cache.dart  | 48 ++++++++++++++++++++--
 .../lib/src/selection_overlay.dart                 | 11 ++++-
 3 files changed, 83 insertions(+), 12 deletions(-)
$ git diff "$BASE" --stat -- apps/floor_planner/test/wall_*_test.dart apps/floor_planner/test/opening_*_test.dart apps/floor_planner/test/support/wall_fixture.dart apps/floor_planner/test/support/opening_fixture.dart apps/floor_planner/test/selection_panel_test.dart apps/floor_planner/test/page_panel_test.dart apps/floor_planner/test/box_test.dart apps/floor_planner/test/planner_box_test.dart apps/floor_planner/test/planner_grips_test.dart | wc -l
0
$ git diff "$BASE" --stat -- apps/floor_planner/test/planner_shell_test.dart apps/floor_planner/test/planner_draw_test.dart
 apps/floor_planner/test/planner_shell_test.dart | 35 ++++++++++++++++++++++---
 1 file changed, 31 insertions(+), 4 deletions(-)
$ grep -rn "spike_rooms" apps packages ; echo "exit $?"
exit 1
$ git ls-files apps packages | xargs grep -ln "spike_rooms" ; echo "exit $?"
exit 123
$ git rev-list --count "$BASE"..HEAD
53
$ git log --format=%B "$BASE"..HEAD | grep -c "^Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>$"
53
$ git log --format=%B "$BASE"..HEAD | grep -c "^Claude-Session: https://claude.ai/code/session_013XiH3QE4FtMMNUjbASxiEv$"
53
$ git log --name-only --format= "$BASE"..HEAD | grep -c "analysis_options.yaml"
0
```

- Every grep prints what the plan's comment says. `planner_shell_test.dart`
  is exactly `2eb2da6` (Ruling 10-22, accepted). The `spike_rooms` grep is
  empty since this task's comment edit (Task 19's F2); the second form,
  over tracked files only, exits 123 because `grep` found nothing in any
  file.
- **The counts are at `fe22430`, before this task's commits** (the greps
  ran before them): every commit since `418d4c7` carries both trailers,
  and none commits an `analysis_options.yaml`.
- Both allocation invariants pass in the gates above and are unedited
  since the base. The engine's barrel exports the new API through its
  whole-file exports (Task 19, ledger).

### Mutation tally

From [plan-10-mutation-log.md](plan-10-mutation-log.md), after Task 19's
audit fix round (`fe22430`): **362 fired: 331 killed, 26 equivalent
(fired, and they survive as argued or ruled), 5 accepted (cost) (green;
they change only what the code costs, each accepted by a ruling), 0
surviving at HEAD; 16 N/A.** Plus 4 controls and 8 re-fires: 374 fires,
374 restores, every one `diff` exit 0 and `git diff --quiet` exit 0.

- **The spec's 51 named mutants: 60 fires, one per site or form, all
  killed** (Ruling 10-26) but M-10inputbox's literal form, which is
  equivalent (`Aabb2` has no `==`; its value form is killed at `SD11`).
  Multi-site: M-10dissolve at three sites (the engine's planner in two
  forms, `RoomType.dissolves`); M-10pagekey, M-10offset, M-10sep and
  M-10preview at two; M-10grow and M-10pin in two forms each.
- **The tasks' extras: 302 fired: 272 killed, 25 equivalent, 5 accepted
  (cost)** (`rv7-wide`, `rv14c-noSkipSame`, `X14-sc-seedGuard`,
  `X14-sc-runReturn`, `rv16-noMemo`). They include the plan-owned
  mutants of Tasks 14b and 14c: every `X14b-*` killed by `DE1`, every
  `X14c-*` by `TN1` (`X14c-noSlitCheck` also by `RG2`).
- **One survivor, a finding, fixed by a fixture:** M-10hover survived
  `TT6` at `749c277`. Once any hover had built Task 15's outer contours,
  a hover outside the bounding box got the same verdict from them, so the
  short-circuit's absence changed nothing `TT6` counted. `TT6` now hovers
  outside the box on a fresh generation and asserts no trace and no
  contour build (`ee610fd`); M-10hover is red there.
- **The audit** (Task 19's reviewer) re-fired 69 entries and reproduced
  every value and line; it found three recorded "equivalents" that were
  not: X11-feet (a tie label; `RA1`'s 28.125 ft², `4b12f65`),
  `rv14b-splitOnce` (a star of 1,002 tied columns in `DE1`, `4b12f65`) and
  X14-sc-boxGuard (the same edit as X6-readAlways, red at `SD6` 704).
- **Controls:** the degenerate rectangle under M-10a, M-10b and M-10c, and
  M-10b's least-absolute-area form, behave as the spec says (not counted).
- **N/A 16:** reviewer mutants whose edits were never written down and
  whose names do not determine them.
- **A nit in the log's header** (the re-audit's, ruled into this note):
  "Four kills came after a fixture fix" is three kills after a fixture fix
  (`M-10hover`, `X11-feet`, `rv14b-splitOnce`) and one re-fire at a killer
  the first run missed (`X14-sc-boxGuard`, whose killer `SD6` needed no
  fix). The log is left as committed; this note is the correction.
- **Killers that differ from the plan's tables** (each recorded in the
  log): X11-canonical is killed by `RT2`, `RT3`, `RT4`, `RT6`, `RT7`,
  `RT8`, not `LZ1`; X10-collinear by `RT8`, not `RT1`; M-10cert's
  app-level killers are `FZ1` and `LZ2`, not `DF1`; X12-noSeed by `DG2`,
  not `FZ1`; M-10before also by `RG3`; M-10e by `RG3` at 23° and by `RS4`.
  Ledger records Task 19 corrected: `rv13-exactStep` is now killed (`RG2`
  403); `rv14-noStep3` now dies at `TN1`, `RG2`, `DG3`, not `FZ1`;
  `t10-holeLen` is now equivalent (subsumed by 14b's split).

---

## Exit gate

The spec's seventeen criteria and where each is witnessed:

| # | criterion | witness | state |
|---|---|---|---|
| 1 | the four gate lines with `CI=true` on the human's macOS machine; `flutter build macos --release` and `flutter build web --release` | Linux half: the four lines above, with only the standing failures (the engine's 2 hash tests; the render layer's 5 `text_ladder` and 2 Linux-only `text_lod_ladder` goldens, and its skip), and `✓ Built build/web`. **The macOS build and the macOS run of the four lines: the human's machine** | **OWED** |
| 2 | every fixture's area equals its hand arithmetic to 1e-2 mm² at every placement, the sample plan's seven included | `RT1`–`RT9`, `LZ1`, `LZ2`, `RG1`, `RG2`, `SP7`, `DE1`, `DE2`; `RT1`'s worst error 0.0016 mm² (above) | PASS |
| 3 | a doorway, a window and a gap never break a room | `RT1` (15 openings), `RT2` (the L with a door, a window and a gap); M-10d | PASS |
| 4 | moving a wall updates every room it touches in one undo step, labels included; undo and redo exact; `drift()` empty, `FB` included | `RG3`, `RG4`, `RG7`, `RS1`–`RS6` (`RS6` is `FB`), `DF1`, `FZ1` | PASS |
| 5 | a room dissolves exactly when D8 says, in the same step; two rooms in one face both survive, reported once | `RD1`–`RD8`, `DG1` (once per pair), `RS4`, `DV1`; the shell's wall-delete undo tests (Ruling 10-22) | PASS |
| 6 | holes: a component wholly inside is subtracted and cut out of the tint; one touching the ring is walked around | `RT3`, `RT4`, `RT6`, `RG2`, `TN1`, `RD4`; a tied island is a hole (decision 29): `DE1`–`DE3` | PASS |
| 7 | the label lands inside the thin L; its offset rides with the pole; it stays horizontal under a rotated room group | `RL1` (583.24–583.40 mm from the boundary, six placements), `RL2`, `RL3`, `RL4`; a mirrored group is a known limit (below) | PASS |
| 8 | the area follows the page's unit and the heights its scale; a page change regenerates in one step; a paper change regenerates no room | `RA1` (with the ft² tie), `RA2`, `RX1`, `PG1`, `PG2` | PASS |
| 9 | save → load → save byte-identical; `drift()` empty after load | `RG5`, `RG6`, `SP6`, `TX1` | PASS |
| 10 | the tint is translucent, follows the paper at paint time, is never picked, band-selected or stroked; a selected or hovered room outlines its labels and its ring | `RR1` (picks, and a window band over floor and over a label; Ruling 10-23), `RR2` (with the bridge sample), `RR3`, `RG1`, `OL1`–`OL5` | PASS |
| 11 | the separator is dashed, splits a face and is trimmed to faces | `RR4`, `SR2`, `SR3`, `RT8`, `ST2`, `ST4`, `ST5`, `ST6`, `GR5` | PASS |
| 12 | the tools (the status notice included), the Room section, the label grip and the separator grips behave as D19–D21 say | `TT1`–`TT9`, `ST1`–`ST6`, `SG1`, `RN1`–`RN6`, `GR1`–`GR6` | PASS |
| 13 | the spatial trigger is exact and its cost pinned by counters; the timing recorded | `SV1`–`SV3`, `SD1`–`SD11` (with `SD5b`, `SD11b`), `OB1`, `RK1`, `LZ3`, `TT6`; `RK2` printed above | PASS |
| 14 | the allocation invariants pass unchanged; the render layer's `lib` changes only in the fill arm and the movable filter; its gate green with only its standing failures | the invariants' diff against `418d4c7` is 0 lines and both pass; the render `lib` diff is `outline_cache.dart`, `grip_cache.dart`, `selection_overlay.dart` | PASS |
| 15 | the sample plan is D23's; its tests pass; `drift()` and `diagnostics()` empty | `SP1`–`SP7`; Task 18's probe matched every D23 figure | PASS |
| 16 | every named mutant killed, logged in `plan-10-mutation-log.md`; `roadmap/13` carries "separators do not plot" | the log: 51 names, 60 fires, all killed but one equivalent form; `roadmap/13-export-and-print.md`'s fourth decision (this task) | PASS |
| 17 | the human's look, on macOS, in Chrome and in Firefox | see below | **OWED** |

**15 of 17 PASS; criteria 1 and 17 are OWED.** Criterion 1's Linux half is
green. Nothing was simulated to fill in either owed criterion.

### Review Focus items and their tests

1. M in a room that already has one: nothing placed; `… — Already a room:
   Kitchen`, also while hovering. `TT7`.
2. The partition dragged into the next wall, then cmd+Z: both rooms survive
   as one space, `room.shared` once, one undo restores both. `RD5`,
   `RS4`, `RG4`.
3. A column deleted: the hole closes, nothing reported, undo restores it.
   `RD4`.
4. A name of spaces, M or S typed into the Name field: spaces revert;
   every letter types, no tool switches. `RN5`, `RN3`, `SG1`.
5. ft-in at 1:100: ft² everywhere, labels double, one undo step; Blueprint
   regenerates nothing and the tints turn light. `RA2`, `PG2`, `RR3`.
6. A wall and a room selected and dragged: the wall moves, the room
   re-traces, the preview does not carry the ring. `OL5`, `GR4`.
7. The Living label dragged onto the sofa, then a click there: the room is
   selected; dropped back on its pole, it returns to auto. `GR1`, `GR2`,
   `RR1`.
8. A separator drawn centreline to centreline with F3 on: stored trimmed to
   the faces; with F3 off, as drawn; both split the room. `ST2`, `ST4`.

---

## OWED by the human

**Nothing below is ticked on the human's behalf.**

### Criterion 1's macOS half

- ☐ done ☐ not done: `cd apps/floor_planner && flutter build macos --release` → `✓ Built`.
- ☐ done ☐ not done: the four gate lines with `CI=true` on macOS (engine,
  render layer with only its standing failures, harness, app).

### Criterion 17: the look

Run it on each platform:

- **macOS:** `cd apps/floor_planner && flutter run -d macos --release`;
- **Chrome:** `cd apps/floor_planner && flutter run -d chrome --release`;
- **Firefox:** `build/web`, served statically
  (`cd apps/floor_planner/build/web && python3 -m http.server`).

Use cmd on macOS and ctrl in a browser. For each item and platform, tick
one box.

| # | item | macOS | Chrome | Firefox |
|---|---|---|---|---|
| 1 | **The Room tool (M) and its preview:** hovering inside a face outlines the would-be ring and its holes; a click places one room, named `Room N`, with a light tint and two labels (name above area) at the face's middle; the tool stays active; Esc returns to Select; a click in a wall or outside the building does nothing | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 2 | **The Room tool's status notice:** hovering or clicking a face that already has a room shows `… — Already a room: <name>` in the status line, and nothing is placed; it clears on leaving the face and on switching tools | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 3 | **The Separator tool (S) and its preview:** two clicks per separator; the rubber band is drawn trimmed; with F3 on, an end clicked inside a wall is stored on the wall's face; with F3 off, as clicked; either way it splits the room it crosses (one side keeps the room) | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 4 | **The sample plan on White:** seven rooms (Hall, Bedroom 1, Bedroom 2, Kitchen, Bath, Living, Dining) with light grey tints over floors, finishes and furniture, names and areas readable (`22.00 m²` … `23.04 m²`), the Living column cut out of the tint, the Living \| Dining separator dashed | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 5 | **The sample plan on Blueprint:** the tints lighten the paper visibly, labels and separator white; switching paper regenerates nothing. Judge also the door gaps, which are not tinted (the Task 18 review) | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 6 | **A selected room:** clicking a label selects the room; its labels **and its ring, with the column's hole**, are outlined in the selection colour (hover: the hover colour); no rotation grip; dragging the room's body moves nothing; a click on bare floor inside a room selects nothing | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 7 | **The separator's dashes,** at a few zooms, and **whether 0.35 mm reads as thin** (S-15) | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 8 | **Moving walls around rooms, and undo:** dragging a partition or an end grip re-shapes the rooms on both sides, labels and areas updating; one cmd/ctrl+Z restores; dragging a partition into the next wall merges two rooms into one space (both labels stay) | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 9 | **Deleting walls around rooms, and undo:** deleting an outer wall removes the rooms whose space opens to the outside (the sample's E4: Hall and Bedroom 1); deleting the column closes Living's hole; one undo brings everything back | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 10 | **The label grip:** a selected room shows one grip under its name; dragging it moves both labels and a line from the face's middle follows; dropped near the middle again, the labels return to auto; after a wall move, a dragged label keeps its offset | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 11 | **The Room section's Name field:** free text; Enter commits one undo step and hands focus back (then L works); an empty name reverts; M, S and every other letter type into the field and switch no tool; the Area line shows the label's string | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |
| 12 | **The page's unit and scale:** ft-in at 1:100 turns every area into ft² and doubles the labels, in one undo step | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge | ☐ seen ☐ not seen ☐ could not judge |

**Known behaviour to expect,** recorded so the look does not rediscover
it. None of it is a 10 defect.

- **The keyhole's slit** is 0.5 mm wide (0.01 mm on paper at 1:50), below
  a pixel at any zoom where a room reads; at a convex corner its end can
  tint up to 0.5 mm of the wall.
- **A label over furniture wins the click** (decision 22); move it with
  its grip.
- **A room whose face pinches at a single corner** (two walls meeting at a
  point) shows an unfilled outline instead of a tint and reports
  `room.tint`; its ring is not outlined when selected (D24). After such a
  room returns to a fill, its tint draws over its labels (translucent).
- **On Blueprint,** the startup plan's finishes and furniture stay dark
  (fix/post-07's debt).
- **A separator in a document without the DASHED record** (a file only;
  the sample plan has it) draws continuous.

---

## Known limits

Recorded, not defects, each by a ruling or a review:

- **A referrer of a dissolving room keeps a dead reference.** Only a
  loaded file whose opening names a room as its host reaches it (08 D17
  allows a live non-wall host); when the room dissolves, the opening is
  reported `parametric.dangling` and an edit of it is refused. No tool,
  grip or sample makes one (Task 4's flag and review; spec D15's
  amendment).
- **An ATTRIB key's movability.** `GripCache` leaves a fill leaf out of
  its movable set (a move never captures a fill) but not an ATTRIB leaf,
  which a move carries only with its host (a path older than D24). No
  pick or band yields an ATTRIB key (Task 8's ruling; spec D24's
  amendment).
- **A mirrored room group's labels are not kept horizontal.** D10 holds
  under similarities without a reflection; only a file makes a mirrored
  room group (the Task 12 review's observation).
- **08's `wallsInDocument` passes every live wall** as a wall's
  neighbours, not the engine's reach list; the two differ inside 07's wide
  node cluster only (the Task 9 review). A 07/08 edge; rooms do not use
  it. D16.4's no-drift proof inherits 07's own drift edge there.
- **The warm face cache's hover answer** can differ from a fresh trace
  within about 1e-6 mm of a face edge; hover only, the click re-traces
  (the Task 15 re-review's nit).
- **A click rebuilds `RoomInputs` three times,** about 22 ms at 636
  walls (the Task 15 review's nit; not taken, correctness first).
- **The Room section's Area lookup is linear** in the document per
  document change, cached per room and change; off the frame path (Task
  16).
- **The slit's end can overshoot the face by up to 0.5 mm** per chained
  bridge (about 1 mm in the fuzz): into a band, across a separator into
  the neighbouring room, or through a wall thinner than 0.5 mm; the tint's
  error has either sign; the area label is the trace's (spec D9 and D18
  amended; the Task 13 review's m-3).
- **Holes the tint may leave out,** reported by `room.tint`: a simple hole
  within the slit's width (0.5 mm) of the ring or of another hole; a
  pinched hole (step 2, or left out) anywhere. Step 3 remains for an outer
  ring pinched at a vertex (spec D9's Task 14c paragraph).
- **After step 3, the tint draws over its labels** (fresh handles above
  theirs); translucent, so the labels still read (spec D9 and D18).
- **The tint's cost grows about quadratically with the ring's points**
  (25.9 ms at 120 holes; a comb of ties about 3× slower after the split);
  fine at plan sizes (Tasks 14b and 14c's reviews).
- **A wall move costs about 6.5–8.8 ms at 600 walls with 146–168 rooms**
  (`RK2`), almost all the per-edit survey's O(n), as 08's `RC3`.
- **The first courtyard hover of a generation builds the contours,**
  about 6.6–8.3 ms at 600 walls (`TT6`).
- **The label returns to auto within the snap aperture of its pole
  whatever F3 says** (Ruling 10-17's cost).
- **X18-pageLate is equivalent on the sample plan,** whose page is the
  fallback's (1:50 m); R-27's hazard shows only at another page, where
  `SP5`'s `drift()` catches it (the Task 18 review).
- **`LZ3`'s bound has no headroom** (deterministic; a change to the
  growth or the certificate moves it).
- **`DF1`'s own bitwise comparison has no killer:** every face of its
  script closes in its first tracing box; `FZ1` and `LZ2` kill M-10cert
  (the Task 14 re-review; the log's F3).
- **An undo restores content, not the root's child order.** After a
  dissolve (or any delete) is undone, the restored groups are re-linked
  last among the root's children and the entity slots can differ; every
  handle, record and component comes back, draw order (by handle) is
  unchanged, and save→load→save is byte-identical in every state. This is
  06's and 08's undo, the same before rooms (the Task 18 review; the final
  review's probe D; spec D8's amendment).
- **The dissolve's plan order** (removals, then the detach) has no state
  consequence; `DV1`'s replay line is its only witness (the Task 4
  review).
- **`flutter_test` captures** skip a 1-px non-antialiased stroke centred on
  a whole device pixel (08's observation); 10's pixel tests frame with
  `fit` or a fractional translation (Ruling 10-28).

## Debt

One line each. None is fixed by this plan.

- **Dash patterns in paper units and the vanishing axis-aligned hairline**
  (R-17, spike findings 3 and 4): a render-layer follow-up; the DASHED
  record is in model millimetres, and 0.35 mm is the thinnest weight with
  evidence.
- **Separators do not plot** (decision 15): 13 skips them or adds a plot
  flag (`roadmap/13`'s new line).
- **12's file-open path decides** whether a loaded document without the
  DASHED record gets one (D3).
- **A persistent cache of wall outlines across edits** (a non-goal) is the
  follow-up if a plan's size ever makes `RK2`'s move too slow.
- **06's bare `RemoveNodeCommand`** leaves a deleted object's own generated
  leaves with a dead owner (08's debt, unchanged).
- **Paste, import, block explode and file merge must remap stored
  handles** (08's debt; rooms and separators store none).
- **Rotate about a chosen base point** (08's debt, unchanged).
- **The Text tool's pending entry is lost on a web alt-tab**
  (fix/post-07's debt, unchanged).
- **The opening tools' hover is a linear scan over the walls** (08's debt,
  unchanged).

---

## Reviews and rulings, per task

Every verdict and ruling below is the ledger's. Each reviewer ran the
gates and re-fired the task's mutants. "→ Task n" means copied verbatim
into Task n's brief (Ruling 10-26).

**Before Task 1.** The controller accepted the plan's eleven spec gaps as
the plan rules them (10-7, 10-3, 10-4, 10-13, 10-14, 10-16, 10-1/10-27,
10-23, 10-10, 10-17/18/24 and `RP2`'s structure, the stale local `main`),
with the spec amendments owed to this task.

**Task 1** (`abc7e7b`), generated text. **Approved.** `rv1-flags` and
`rv1-idx` survived → Task 2 (a non-zero `flags`; two TEXTs); the TEXT match
reads `textAt` → Task 2.

**Task 2** (`f0734f4`), record attributes. **Approved.** Plan gap: the
Swatch's fill flags of 0 would let X2-default survive (the inherit variant
sets them invisible). The review's minor (the add-versus-match contrast)
not taken: a re-add is caught by handle equality.

**Task 3** (`e01b9b4`), the page. **Approved.** `rv3-firstType` and
`rv3-noShort` survived → Task 4 (one step changing scale and unit; the
call-site guard and a `pageKey` counter). The filter mutants are
equivalent.

**Task 4** (`40ad500`, `ff7d9c0`), the dissolve. **Approved.** Plan wrong:
X4-order is not state-visible; the replay order pins it. `rv4-break` →
Task 5. The dangling referrer of a dissolving room: a known limit (above).
The D15 order: a convention, witnessed by the replay only.

**Task 5** (`f9ab74d`, `4529776`), place roles, the before-view, the
trigger. **Approved.** Plan wrong: `SD4`'s premise impossible in one
direction (two steps). `rv5-desc` → Task 6 (`SD5b`); `placeBox`'s one-hop
assumption → Task 6 (doc) and the spec (this task).

**Task 6** (`76d3803`), changed inputs only, the counters. **Approved.**
`rv6-rodLocal`, `rv6-rcBefore` and `SD11`'s premise → Task 7 (`SD11b`, an
`SD10` compound); `placeInput`'s contract and "`==` difference" → Task 7
(doc) and the spec (D16.6 "at most", ±0).

**Task 7** (`46bdb88`, `3b9df9a`, fix round `8421a3e`), the bulk pass,
`objectsOf`, the dashed handle. **Needs fixes → Approved.** I-1
(`rv7-cont`): overlap tests counted before the window check; I-2
(`rv7-sortMax`): `SD7`'s cells turned; m-2: the sweep's doc "O(n log n +
pairs whose x ranges overlap)", and D16.5 amended here; m-1: `SD7`'s
split, above. The engine was frozen from here.

**Task 8** (`07c92df`, `1294929`, fix round `7445232`), the ring outline
and the move preview. **Approved; minors fixed in a round.** M1
(`rv8-picking`): `OL2`'s locked-layer case; M2: a fill leaf is never
movable. The ATTRIB key: a known limit. The render layer was frozen from
here.

**Task 9** (`e48606a`, fix round `5b71e01`), trace inputs and the
separator. **Needs fixes → Approved.** I-1: X9-allWalls is not equivalent
(07's wide node cluster, now in `RI1`); I-2: `RoomInput`'s exact `==`
(`RI2`); m-3: `RoomInputs.invalidate()`. `rv9-sepLenGe`, `rv9-wallFinite`
→ Task 13 (`DG4`). The 08 `wallsInDocument` edge: a known limit.

**Task 10** (`417edbd`, fix round `bacce35`), the tracer. **Needs fixes →
Approved.** I-1: a free separator tree came back as a 2-point hole (a
hole needs three vertices); m-1–m-5: the diagonal separator, the 0.5 nm
short separators, the pinch tie-break (20 relabelled variants), the hole
and merged sources, `RT1`'s comment. `rv10-holeLen4` → Task 11 (the
separator triangle).

**Task 11** (`436fe55`, `9eb913e`, fix round `6fe558e`), the localised
trace, the tint, the pole, the format. **Needs fixes → Approved.** Plan
wrong: X11-canonical's killer is the tracer tests, not `LZ1` (Ruling
10-7's premise amended). I-1: a bridge through an obstacle's vertex is
blocked; m-1: the margin case is 0.5 nm (the commit subject's "0.5 um"
stays, history); m-2: `LZ4`; m-3: the hidden-hole branch is defensive.
The RT8 mislabel → Task 12.

**Task 12** (`54431ab`, fix round `02130fc`), the room type. **Needs fixes
→ Approved.** The local-frame guard kept (→ Task 13's seam). I-1: `RG7`
(the 2 mm margin); m-1, m-2: `RL4`, `RL3`; m-3–m-5 → Task 13 (the pole
with holes, one tint helper, X12-noSeed's killer `DG2`). Mirrored groups:
a known limit.

**Task 13** (`07a2610`, `c9a9630`, fix round `855d7b0`), dissolving,
holes, diagnostics. **Needs fixes → Approved.** Honest step-2 and step-3
fixtures exist; Ruling 10-16's seam kept for the local guard. I-1: `DG1`'s
room in a turned group (`rv13-otherLocal`); m-1: `room.shared` skips a
broken room; m-3: the slit's overshoot, a known limit and a spec
amendment. Spec wording owed here: D22 per pair, D9's slit, step 3's
handles.

**Task 14** (`f869e76`, fix round `161d23c`), rooms follow every wall.
**Needs fixes → Approved.** I-1: `FZ1` counted step 3 by position (a room
back from step 3 has its region above its labels); m-1–m-4: every `FZ1`
and `DF1` trace against the all-inputs trace, refusal as null/non-null,
an untimed warm-up in `RK2`, a dissolve in `DF1`. Findings recorded:
`FB`'s after-box premise holds unturned only; M-10before killed by `RG3`;
M-10e only at 23°. **The product finding:** a separator tying an island
to the ring lost the tint (step 3) → **decision 29**, the human's: fix it
in 10.

**Task 14b** (`733733b` spec, `45d4a9e`), doubled edges split into holes.
**Approved** (0 Important in the diff). The review found an Important
defect outside the diff (Task 11's `tintOf`: the slit's return edge could
cross the hole) → Task 14c. m-2 (cost) not taken.

**Task 14c** (`2c2dbc0`, `e1c91ae`, fix rounds `786d072`, `eed7ac4`), the
slit checked as well as the bridge. **Needs fixes twice → Approved.** I-1:
a far simple hole left out at an acute vertex (each slit end in its own
sector); I-1r: a slit end landing on an end (the end-on-end clause).
Wording → Task 15 (`room.tint`'s "no clear keyhole reaches them"; "each
chained bridge adds at most 0.5 mm").

**Task 15** (`183d97b`, `ae055d6`, fix round `8dc5434`), the two tools.
**Approved; minors fixed in a round.** Minor 1: the outer-contour cache
(spec D19 amended, T-8 adopted); Minor 2: re-trimming at a mitre (`ST5`);
Minor 3: `TT2`'s tied island; Minor 4: the first crossing (`ST6`);
X15-guardMS killed by `SG1`. Plan wrong: `TT5`'s 30 px, `TT2`'s store map,
the `DuplicateHandleError`. The warm face cache and the triple rebuild:
known limits. The re-review's Minors A and B → Task 17.

**Task 16** (`e17c65d`), the Room section. **Approved.** Minors M1–M3 →
Task 17 (test only). Plan: `RN5`'s refused edit is two cases.

**Task 17** (`2f0fed8`, `10894c6`), the grips. **Approved.** Minors M1–M3
→ Task 18 (`GR6` in world, `GR1` at 1:100 ft-in, a doc line).

**Task 18** (`f9bc949`, `2eb2da6`, `749c277`), the sample plan and its
renders. **Approved.** Ruling 10-22 applied and accepted (`2eb2da6`);
X18-pageLate equivalent on this plan; Blueprint's untinted door gaps are
for the human's look. Minors → Task 19 (text).

**Task 19** (`ee610fd`, `d255acb`, `d1a81d8`, fix round `4b12f65`,
`fe22430`), the mutation log, invariants and greps. **Audit: Needs fixes →
Approved.** I-1: three false equivalents (two new cases, one re-fire);
m-1–m-3: the log. F1 (D19's wording) and F2 (the `spike_rooms` grep) →
this task.

**Task 20** (`962c402` and this note's commit): the gates, this note, the
amendments, STATUS and the roadmap.

---

## Spec amendments

In [2026-09-26-rooms-design.md](../specs/2026-09-26-rooms-design.md).

**Already amended in flight** by Tasks 14b and 14c (decision 29), marked
in place: D5 step 9 (doubled edges split), D6 (a tied island is a hole),
D9 (the doubled-edge paragraph; the slit checked, each end in its own
sector; what remains). This task did not repeat them; its D5, D9 and D18
paragraphs add only what they do not say.

**Written by this task,** each a paragraph beginning "**Amended at
execution (Plan 10)**" at the end of the section it amends:
- **Header:** a pointer to the amendments and to this note.
- **D3:** `SR5`; the DASHED description (Ruling 10-14); a separator exactly
  `roomTrace.linear` long is degenerate (`DG4`).
- **D4:** one local ring (Ruling 10-8); the document adapter's predicate
  (10-10), `RoomInputs` (10-11) and its `invalidate()`; `RI1`'s probe
  (10-12) and wide node cluster; `RI2`; 08's `wallsInDocument` edge.
- **D5:** the canonical output (Ruling 10-7) and its premise corrected
  (far inputs never move the walk's start; X11-canonical's killers); a
  hole needs three vertices; the pair search's tolerances; sources;
  M-10d's site; X10-collinear's killer; `debugTracedSegments` unannotated.
- **D7:** `U` for the view (Ruling 10-13); step 3's shortcut; the margin
  pinned at 0.5 nm (and `9eb913e`'s subject); `LZ4`; `LZ1`'s count;
  `LZ3`'s bound (50 per rebuilt room); M-10cert's killers.
- **D8:** outer-wall deletes dissolve rooms in the shell (Ruling 10-22);
  the undo's child order.
- **D9:** the slit's real error (either sign, up to 0.5 mm per chained
  bridge, not "0.5 mm × bridge"); a bridge through a vertex blocked; the
  hidden-hole branch defensive; step 3's fresh handles above the labels;
  Ruling 10-16's seam kept for the local-frame guard; one helper for
  `generate` and `diagnose`; the labels' justification literal (Ruling
  10-14).
- **D10:** a mirrored group is not covered; `RL1`'s measured distances;
  `RL3`/`RL4`'s frame cases.
- **D11:** `RA1`'s deliberate ft² tie (`28.12`); ties follow the binary
  value.
- **D12:** the clients (Ruling 10-2); the ordinal match pinned
  (`rv1-idx`); `TX1`'s fractional values.
- **D13:** every attribute non-default in a fixture (`rv1-flags`,
  X2-default); a re-add caught by handle equality.
- **D14:** the page seeds after `_checkDangling` (Ruling 10-4); the
  call-site guard and the counter; M-10pagekey's reading; the clients.
- **D15:** the order's only witness is the replay; `DV1` plans past a
  dissolve; the known limit (a referrer of a dissolving room).
- **D16:** staged in three tasks (Rulings 10-3, 10-5, 10-6); `paramsOf`
  narrowed; point 2's "`==` difference" (±0 equal) instead of "any bit
  difference"; `placeInput`'s contract; point 4's one-hop assumption in
  `placeBox`'s doc; point 5's "O(n log n + pairs whose x ranges overlap)";
  point 6's "at most" the same number of `placeInput` calls; `SD7`'s
  split; `FB`'s premise unturned only; M-10before killed by a T-joined
  partition, M-10e at 23°; `RK1`'s three short circuits; the clients and
  `SD4`'s two steps.
- **D17:** `RP2` is an engine test (Ruling 10-1); the default linetypes
  are at handles 2, 3, 4.
- **D18:** "never covers a wall's band" amended (the slit); "the labels
  draw over the tint" while it keeps its first form; the dissolve's undo;
  `RG7`.
- **D19:** T-8's outer-contour cache adopted, the verdict order, `TT6`'s
  timings and `TT8`; **the bounding-box short-circuit now saves the
  contour build, not a trace** (Task 19's F1); a click builds no contour
  (`TT9`); `invalidate()` at every click; no snap marker; the
  `DuplicateHandleError`; the warm face cache and the triple rebuild as
  known limits; `TT5`'s and `TT2`'s geometry.
- **D20:** re-trimming at a mitre and a chamfer (`ST5`), the first
  crossing (`ST6`); one `trimSeparator` (Ruling 10-9).
- **D21:** Ruling 10-17 (the aperture, in world; `GR6`, `GR1`); a drop on
  the grip returns null; invalidate at release; the Room section as built
  (`RN1`, `RN2`, `RN5`'s two cases, `RN6`, the Area lookup); `SG1`.
- **D22:** `room.shared` once **per pair**, not "at most once per object";
  another room's seed through its group; a broken other room skipped;
  `room.tint`'s three messages; M-10objects' site (Ruling 10-27).
- **D23:** Task 18's probe matched every figure; X18-pageLate equivalent
  on this plan; the pixel tests hide the grid.
- **D24:** no boundary kind check; a fill leaf never movable; `OL2`'s
  locked layer; the ATTRIB key's known limit; `OL3` at the render layer
  (Ruling 10-24) and the frame path measured.
- **Architecture, Files:** the files as built; `room.dart`'s
  `flutter/foundation` import; the roadmap line.
- **Amendments to 06, 07 and 08:** a row for 07 D6's local ring (Ruling
  10-8).
- **Testing, tests by area:** Ruling 10-1 (`SD10` split, `OB1`, `RP2`'s
  home, `SR5`, `DF1`, `FZ1`); the plan-added tests (`RI2`, `LZ4`, `RG7`,
  `SD5b`, `SD11b`, `DE1`–`DE3`, `TT8`, `TT9`, `SG1`, `ST5`, `ST6`); cases
  added inside tests; Rulings 10-23, 10-18, 10-21, 10-28.
- **Named mutants:** 51 killed at 60 fires; the killers that differ;
  M-10hover's fixture fix.
- **Differential check:** `DF1`, `FZ1`'s all-inputs comparisons,
  `expectSameTrace` unkilled.
- **Exit gate:** criterion 10's witnesses (Ruling 10-23); 1 and 17 owed.
- **Open questions:** decision 29, the one question raised in flight.

**D1, D2 and D6 needed none** (D6's in-flight paragraph stands).

## Plan amendments

In [2026-09-26-rooms.md](../plans/2026-09-26-rooms.md), each a paragraph
beginning "**Amended at execution (Plan 10)**":
- **Header:** a pointer; Tasks 14b and 14c added in flight (decision 29).
- **Task 1:** `TX1`'s values; `rv1-flags`, `rv1-idx` → Task 2.
- **Task 2:** the Swatch's fill flags (X2-default).
- **Task 3:** X3-allTypes; M-10pagekey's reading; the carried items.
- **Task 4:** X4-order → the replay, not `DV1`'s undo; `rv4-break`; the
  known limit.
- **Task 5:** `SD4` in two steps; `SV1`, `SD1`; `paramsOf`; X5-noStored,
  X5-referrerFirst.
- **Task 6:** "at most" `placeInput` calls; the quarter turn;
  M-10inputbox's literal form; the carried items.
- **Task 7:** `RP2`'s wording (handles 2, 3, 4); `SD7`'s grid and count.
- **Task 8:** the fix round; no mutant named for `OL3`
  (`t8-rebuildAlways`); the ATTRIB key.
- **Task 9:** X9-allWalls not equivalent; `RI2`; `invalidate()`.
- **Task 10:** M-10d's site; X10-collinear's killer `RT8`; the fix round.
- **Task 11:** X11-canonical's killers; X11-feet; 0.5 nm; the fix round
  and `LZ4`.
- **Task 12:** the local guard; X12-noSeed's killer `DG2`; `RG7`.
- **Task 13:** Ruling 10-16's premise did not hold; `room.shared` per
  pair; the fix round.
- **Task 14:** M-10before, M-10e, `FB`, `RK1`, X14-noSeedBox and
  X14-margin0; the fix round; Tasks 14b and 14c added.
- **Task 15:** `TT5`, `TT2`, `DuplicateHandleError`; the fix round.
- **Task 16:** `RN5`'s two cases; `RN3`; the two pumps; the Area lookup.
- **Task 17:** a drop on the grip; invalidate at release; the carried
  items.
- **Task 18:** every D23 figure matched; Ruling 10-22; X18-pageLate.
- **Task 19:** the tally; M-10hover; the audit; the grep.
- **Mutant assignment:** the killers that differ; the X14b/X14c mutants.

---

## Files this task touched

**First commit, `962c402`:**
- `apps/floor_planner/test/support/room_fixture.dart`: the provenance
  comment names branch `spike/10-rooms`'s fixture support file, not
  `test/spike_rooms/support.dart` (Task 19's F2). Comment only.

**Second commit** (this note's):
- `docs/superpowers/notes/2026-09-26-plan-10-results.md`: this file.
- `docs/superpowers/specs/2026-09-26-rooms-design.md`: the amendments
  above.
- `docs/superpowers/plans/2026-09-26-rooms.md`: the amendments above.
- `roadmap/13-export-and-print.md`: "Room separators do not plot", its
  fourth decision already made (decision 15).
- `roadmap/10-rooms-and-area.md`: the status line.
- `roadmap/00-README.md`: the 10 row and the summary under the table.
- `STATUS.md`: the top paragraph, a Plan 10 section, the branch map and
  "Resume here".
