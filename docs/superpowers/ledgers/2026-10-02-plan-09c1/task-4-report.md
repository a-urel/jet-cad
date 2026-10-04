# Task 4 report — wall faces (spec D3)

Implementer, plan 09c-1, Task 4. Status: DONE, committed `e73621f` (not pushed).

## Progress log
- Read brief, plan (P-1..P-8, Task 4), spec D3/D4/D6/D14/Testing/mutants, ledger.
- P-4 check: transitive import closure of lib/parametric/opening_geometry.dart (15 files),
  lib/parametric/wall_bands.dart (16 files) contains no package:flutter and no dart:ui.
- WallBands.liveWalls + WB2 written (test first: compile-red, then green).
- lib/symbols/wall_attach.dart (FaceSide, FaceRun, faceRunsOf, faceRunsAmong), test/support/wall_attach_fixture.dart,
  test/symbols/wall_faces_test.dart (WF1..WF8) written; 8/8 + WB1/WB2 green.
- Note: one `dart format test/` invocation ran over the whole test dir (my mistake); git status shows no file
  outside Task 3's own modified set changed, but Task 3's in-progress test files may have been re-wrapped by it.
- Mutants running (batch 1: f, g1, g2, g3).
- Batch 1 mutants all red, files restored (diff 0): M-09c-f, -g1, -g2, -g3 (raw output: scratchpad/task4/batch1.out).
- Batch 2 running: -ag (two variants), -as, -at, -ay.

- Batch 2 all red, batch 3 all red, every file restored (diff 0). Raw output: scratchpad/task4/batch{1,2,3}.out, per-mutant logs mut_<id>.log.

## Commit
- `e73621f` feat(app): wall face runs (5 files, +903). Parent `a6ef0bc` (Task 3's commit landed while I worked).

## Files
- apps/floor_planner/lib/parametric/wall_bands.dart: `liveWalls(doc)` (runs `_refresh`, returns a cached `UnmodifiableListView` of `_handles`; no allocation per call).
- apps/floor_planner/lib/symbols/wall_attach.dart (new): `FaceSide {left, right}` (the frame's local sides), `FaceRun {a, t, m, length, thickness, wall, side}`, `faceRunsOf(doc, wall, {accept})` (document adapter via `wallsInDocument`; `accept` asked only for a live wall), `faceRunsAmong(host, walls)` (pure D3).
- apps/floor_planner/test/support/wall_attach_fixture.dart (new): `farAt` (1e5, -7e4), `attachAngles` [30, -112.5], `attachGroup(h, {mirrored, scale})`, `attachScene`, `freeWallScene`, `lScene` (100/240), `teeScene` (host 200, stem 120, `foot`, `inward`), `crossScene`, `shortBaseScene` (C9's short-wall world fallback). Reuses wall_fixture's `addWall`, `polar`, `wallDoc`.
- apps/floor_planner/test/symbols/wall_faces_test.dart (new): WF1..WF8.
- apps/floor_planner/test/wall_bands_test.dart: WB2 added (WB1 untouched).

## Tests added
- WB2 liveWalls: fresh bands, ascending, degenerate excluded, a wall added after the first call seen after delivery, unmodifiable, view not copy, generation moves.
- WF1 free wall, 3 justifications x 2 angles x mirrored/not (12 cases): two runs, ends/m/t/a/L/w vs hand offsets from the stored params; zero-offset face on the centreline; t = +/-d flips with the mirror.
- WF2 L 100/240, 2 angles x turns +/-75 x 9 justification pairs (36): each face's ends and length vs x = (oa cos th - ob)/sin th, y = (oa - ob cos th)/sin th; inside shorter / outside longer (centre/centre).
- WF3 T, 2 angles x 3 host justifications x stem left/right x drawn from/towards (24): only the butted face split, cut ends = Cramer crossings of the stem's face lines; other face whole.
- WF4 X at 60 deg, 2 angles x 2 justification pairs: each face cut by its own crossings (premise: the faces' cuts differ by > 100 mm).
- WF5 mirrored centre-justified T (8 cases): premise local and world side tests disagree; the split face is the one on the stem's world side (frame side by the local test).
- WF6 scaled 1.5: joined L (w = 100/240 while the frame's offsets give 150/360), world fallback short base (w = 200, frame 300), local fallback C11 scaled at 143 deg (w = 300); every run end within 1e-6 of a stored outline vertex.
- WF7 degenerate (zero thickness, 5e-7 long), a non-wall handle, accept refusing -> no runs; accept asked only for the live wall.
- WF8 sliver drop: 5e-7 piece dropped, 3e-6 kept (length 3e-6 +/- 1e-9).

## Mutants (all fired by cp backup / mutate / run test file / cp back / diff exit 0)
| Id | Site | Change | Red test(s) | Excerpt |
|---|---|---|---|---|
| M-09c-f | wall_attach.dart:141 | both faces' extent = centreline [0, len] projected onto the face line | WF2, WF6 | `Expected: within 0.000001 of 3778.33 Actual: 3999.99` |
| M-09c-g1 | :132 | T cut never added | WF3, WF5, WF8 | `Expected: an object with length of <2>` |
| M-09c-g2 | :131 | T cut added to both faces | WF3, WF5 | `Expected: an object with length of <1>` |
| M-09c-g3 | :137 | X cut on the left face only | WF4 | `Expected: an object with length of <2>` |
| M-09c-ag (extent) | :141 | left face extent starts at startCap.last's projection | WF2, WF6 | `within 0.000001 of 2960.78 Actual: 3000.0` |
| M-09c-ag (line) | :157 | left face through startCap.last | WF1-WF5 | `within 1e-9 of 150 Actual: 0.0` |
| M-09c-as | :130 | T side from the world left normal | WF5 | `Expected: an object with length of <2>` |
| M-09c-at | :157-160 | face points from frame.left/right (lOff/rOff) at the caps' u | WF6 | `within 0.000001 of 100.0 Actual: 150.00000000000148` |
| M-09c-ay | :136 | X cuts both faces by the union | WF4 | `Expected: less than 1e-7 Actual: 115.47005383792528` |
| liveWalls without refresh | wall_bands.dart:60 | `_refresh(doc)` removed | WB2 | `Expected: [18, 20] Actual: []` |
| liveWalls a copy (extra) | wall_bands.dart:62 | `List.unmodifiable(_handles)` | WB2 | `Expected: [18, 19, 20] Actual: [18, 20]` |
| m = world left (extra) | wall_attach.dart:98 | `mLeft = nd` | WF1 | `Expected: less than 1e-12 Actual: 2.0` |
| t flipped (extra) | :169 | `t = (m.y, -m.x)` | WF1, WF3 | `Expected: [-0.866.., -0.5] Actual: [0.866.., 0.5]` |
| drop at 0 (extra) | :173 | `y - x > 0` | WF8 | `Expected: an object with length of <1>` |
| accept dropped (extra) | :62 | accept check removed | WF7 | `Expected: empty` |
| accept before live (extra) | :60 | accept asked before wallsInDocument | WF7 | `Expected: [18] Actual: [18, 999999]` |

## Gates
- Engine and render: **unchanged** (no file under packages/ touched); not re-run.
- App, before commit: run 1 `+1074 -1` (DC1 in document_commands_test.dart failed once under load while Task 3 worked concurrently; passes alone `+18`); run 2 `+1075: All tests passed!`. analyze: No issues found. format: `Formatted 180 files (0 changed)`, exit 0.
- App, after commit (Task 5 now editing symbol_ghost/place_tool/placer in the same tree, uncommitted): `+1071 -1`, the one failure is `loading .../test/symbols/symbol_ghost_test.dart` (Task 5's in-progress file). My files re-run: `wall_faces_test.dart wall_bands_test.dart` `+10: All tests passed!`. analyze: No issues found; format 0 changed.
- Web build: not required for this task's gate by the brief ("only the app gate"); not run.

## P-4
- Transitive import closure (script): opening_geometry.dart 15 files, wall_bands.dart 16 files, symbol_box.dart 17 files: no package:flutter, no dart:ui. wall_attach.dart imports jet_cad_2d, vector_math, ../parametric/{opening_geometry,wall,wall_geometry}.dart only.

## Proposed rulings
- **R-C4-1 (signature):** the plan's `faceRunsOf(DraftDocument doc, Handle wall, List<WorldWall> walls)` is split into `faceRunsOf(doc, wall, {accept})` (document adapter through `wallsInDocument`, the predicate per P-4/T-4) and the pure `faceRunsAmong(WorldWall host, List<WorldWall> walls)`. The plan's third parameter was redundant with `doc`. Cost if wrong: Task 6's `WallFaces` calls one or the other; a rename.
- **R-C4-2 (run order and side enum):** `faceRunsAmong` returns the left face's runs then the right face's, each ascending along the frame's world `d`; the side is a new `FaceSide` enum (the frame's local sides), not dimension_geometry's `WallSide` (which has `centre` and lives outside P-4's import list). Cost: none for D4 (its tie-break uses side and `a·t`, not list order).
- **R-C4-3 (T/X classification):** B's role is recomputed from `strictlyInside(b.endpoint(k), host)` for each wall `obstaclesOf` names (dedup by handle), as `obstaclesOf` itself decides it; `obstaclesOf`'s intervals are not used. If an intersection of a face with B's face line is parallel (null), that crossing's cut is skipped. Cost if wrong: one branch.
- **R-C4-4 (B's neighbours):** B's frame is `hostFrameOf(B, [host, ...walls less B])` sorted ascending by handle, the same set `wallsInDocument(doc, B)` gives.

## Found, not fixed
- Under a mirrored group every wall's local ring is clockwise, so `hostFrameOf`/`localOutlineOf` fall back to the local free rectangle: mirrored walls never draw joined corners (existing 07 behaviour, consistent with D14's inherited note). WF5 therefore exercises the T side test on fallen-back frames.
- My first `dart format` call ran over the whole `test/` directory instead of my own files; git status afterwards showed no file outside Task 3's own modified set, but Task 3's then-uncommitted test files may have been re-wrapped by it.

## Look hardest at
- WF5's premise and the S-3 local test; M-09c-as is killed only there.
- M-09c-at is killed only by WF6 (joined scaled L and world-fallback short base); the local-fallback C11 case cannot kill it (there the drawn faces are the frame's offsets).
- `faceRunsAmong`'s `mLeft` sign from `(ls - rs)·nd` and `thickness` measured at the start-cap points (for a joined start whose two cap points differ in u, the projection onto m still gives the line distance).
