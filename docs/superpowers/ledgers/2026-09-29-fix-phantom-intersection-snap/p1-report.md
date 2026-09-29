# P1 report: intersection snaps map grouped segments to world (post-11 (a))

Branch `fix/phantom-intersection-snap`, worktree `.claude/worktrees/fix-phantom-snap`.
**Commit: `c7e4ac3`** (one commit: the fix, its tests, and the AM2 premise update; not pushed).

## The fix and why it takes this shape

`packages/jet_cad_2d/lib/src/index/spatial_index.dart`:

- `_collectNearSegments(root, world, radius, from, to)` now maps every point of each candidate through that leaf's own transform. It calls `_composeLeafTransform(Transform2.identity(), root.transformOfLeaf(slot))`: the root container's placement is the identity, a const instance rather than an allocation, and null becomes the identity. The six coefficients `_lta.._ltf` are read into locals. Each point is mapped once and carried forward as the next segment's start. The segment is then measured with `distanceToSegment`, so the transform comes first and the measurement second.
- Each near segment's **world endpoints** go into a grow-once `Float64List _nearSegmentWorld` (4 doubles per near segment, starting at 256). This replaces `Int32List _nearSegment`, the segment indices. `_nearSegmentStart` is unchanged and still counts segments.
- The pair loop reads `_nearSegmentWorld` and no longer touches the payloads.

Why: the pair loop has to intersect exactly the segments the near test measured, in the space it measured them in. Storing them already mapped means the two cannot disagree. It also means each segment is transformed once, not once per pair. Reusing `_composeLeafTransform` keeps a single composition code path for leaf transforms. Nothing is allocated per candidate or per segment. The existing `_isectA1/_isectA2` scratch serves the near test, and the buffer grows by doubling, the same as the old `_nearSegment`.

Doc comments changed:
- `_considerIntersections`: "Root-level only" is now "The root container's leaves only". Instance contents are still never candidates. A flattened group's leaf is a candidate and is mapped through its group transform.
- `_nearSegmentStart`/`_nearSegmentWorld`: rewritten for the new layout.
- `_collectNearSegments`: now states that the transform comes first and the measurement second.
- `_lta` doc: it said "read back by `_descend`'s two visitors" and now also names `_collectNearSegments`. I also added `_leafPasses`, which already read them before this change.
- `snapInto`: "root-level entities only" is now "the root container's leaves only (a flattened group's included, mapped through its transform)".
- `kIntersectionCandidateCap`'s doc stays true and is unchanged.

## Tests added

- **`packages/jet_cad_2d/test/index/snap_intersection_group_test.dart`** (new, 11 tests). Every expected point is computed by hand in the test's comments. The brief's list:
  1. A turned-and-moved group: its world crossing is (103.2, 52.4), within 1e-9, `kind == intersection`, and the later-drawn leaf names it.
  2. No snap at the phantom (stored crossing (4, 0)), with an intersection-only mask. Both leaves' world boxes hold (4, 0), so only the segment coordinates decide.
  3. A grouped line crossing an ungrouped root line.
  4. Two groups with different transforms, one of them a non-uniform scale.
  5. A polyline whose world-near segment (s1) is not its stored-near segment (s0). This is the one that separates the near filter from the pair loop.
  6. A mirrored group (det −2, not symmetric).
  7. A group nested in a group.
  8. The group moved by `TransformNodeCommand`, then undone, on a live index.
  9. A grouped leaf edited by `SetEntityGeometryCommand`, then undone, **through the dirty overlay**. Premises: `rebuildCount` unchanged, `dirtyCount` grew.

  Also added: a premise test that the mask is intersection alone, and a test that the near-segment buffer keeps its rows when it grows past 64 (it kills my M-P10).
- **Corpus** (`test/invariants/corpus.dart`): the new `groupedCrossings` document holds:
  - ungrouped root lines and a polyline;
  - group A: rotation + translation;
  - group B: rotation, non-uniform scale (1.8, 0.55), translation;
  - group C: mirrored, det < 0, not symmetric;
  - group D, holding a line and group E, which is nested in D and holds more.

  The builder's own `expect`s pin these points independently of the index (from the transforms it chose):
  - the transform properties;
  - world crossings exist in every pair category (within one group, between two groups, grouped against ungrouped) and involve every group;
  - no crossing sits within 1e-6 of a segment end, and no two crossings coincide;
  - at least one phantom lies more than the 2.0 radius from every world crossing;
  - there are at least 10 world crossings.
- **Differential** (`test/invariants/differential_test.dart`): a new per-fixture test, "snap matches brute force at and around every crossing and phantom". Its targets come from `_crossingTargets`, built from the **oracle's own `allLeavesInWorld`** list:
  - the world crossings of every pair of root-level line/polyline leaves;
  - the stored-coordinate crossings (phantoms) of every pair with a non-identity transform on either side.

  Each target is queried at the point itself and at three offsets within the radius, under three masks: intersection-only, `kDragSnapMask` and `SnapMask.all`. `reference_query.dart` is untouched. Every existing fixture that iterates the corpus still passes (entitiesInRect, instancesInRect, pick, snap) for all 20 documents. Only `differential_test.dart` imports `buildCorpus`.
- **Allocation** (`test/invariants/query_allocation_test.dart`): a new fixture, `_groupedCrossingDocument(24)`: 24 root-level groups at turned, scaled and moved transforms, 48 candidates, all with a non-null `transformOfLeaf`, 72 mapped segments. The test "snapInto does not allocate in steady state, intersecting segments mapped through their groups" runs `SnapMask.all`. It has two premises: every leaf has a transform, and an intersection is found at the query point. Their stored coordinates are far from it, so a stored-coordinate pass would do no pair work. Measured with the fix: `Vector2` 0.014, `_Record` 0.001, `TextMetrics` 0.0, `Aabb2` 0.054–0.062, `Transform2` 0.102–0.110 per call, over 2 runs.
- **App** (`apps/floor_planner/test/intersection_snap_test.dart`): `samplePlan(origin)` with P1 (`plan.walls[4]`) moved −300 mm in x by `TransformNodeCommand`, the same move `moveBy` makes. The aperture is `kSnapAperturePixels / 0.05` = 200 mm. Line-like leaves are taken to world by walking each group chain by hand, and crossings come from the test's own parametric formula. The test asserts:
  - at every phantom (29; 14 of them have no world crossing within 200 mm), an intersection-only `snapInto` finds nothing, or finds a world crossing within 1e-6;
  - `resolveDragPoint`, the app's route with `kDragSnapMask`, never reports an intersection at the 14 bare phantoms;
  - all 13 interior crossings of P1's world geometry are found within 1e-6.

  A candidate-count premise (< 64) rules out the cap as an explanation for any result.

## Red before the fix (the new tests on the unfixed engine, pasted)

Unit file on the original engine (exit 1), `00:00 +1 -9: Some tests failed.`:
```
00:00 +1 -1: two lines in one turned-and-moved group snap at their world crossing, not at the stored one [E]
00:00 +1 -2: no intersection snap at the phantom point, where the stored coordinates cross [E]
00:00 +1 -3: a grouped line crossing an ungrouped root line [E]
00:00 +1 -4: two lines in two different groups (a transform per side) [E]
00:00 +1 -5: a polyline whose world-near segment is not its stored-near segment (the near filter and the pair loop must both map) [E]
00:00 +1 -6: a mirrored group (negative determinant) snaps at its world crossing [E]
00:00 +1 -7: a group nested in a group composes both transforms [E]
00:00 +1 -8: the snap follows a TransformNodeCommand on the group, and its undo, on a live index [E]
00:00 +1 -9: the snap follows an edit to a grouped leaf through the dirty overlay, and its undo [E]
```
The phantom test's failure:
```
  Expected: false
    Actual: <true>
  the stored crossing (4, 0) is 2.53 from any world crossing: nothing to snap to within 1
```
(The buffer-growth test was written later, for M-P10. It pins new code, so it is not a regression test for (a).)

Differential test on the original engine (exit 1). Note that the random-point snap test on the same document **passed**. That is the degenerate sampling the brief described:
```
00:02 +98: groupedCrossings snap matches brute force over 200 random points
00:02 +99: groupedCrossings snap matches brute force at and around every crossing and phantom
00:02 +99 -1: groupedCrossings snap matches brute force at and around every crossing and phantom [E]
  Expected: <22>
    Actual: <19>
  groupedCrossings aimed at [51.791098533573454,48.1849755595575], query [50.49109853357346,49.0849755595575] mask=128
00:02 +99 -1: Some tests failed.
```
Allocation harness on the original engine (exit 1). The premise fails:
```
00:05 +4 -1: snapInto does not allocate in steady state, intersecting segments mapped through their groups [E]
  Expected: true
    Actual: <false>
  the mapped segments must cross near the query point, or this measures an intersection pass with no pair work to do
```
App test on the original engine (exit 1):
```
P1 moved -300: 29 stored crossings, 14 with no world crossing within 200.0 mm
00:00 +0 -1: a moved wall group: no intersection snap at the stored (phantom) crossings, and every crossing of its world geometry found [E]
  Expected: a value less than <0.000001>
    Actual: <180.0>
  near phantom [16940.0,8250.0] the snap [16940.0,8250.0] is a world crossing
```

## Mutants

Procedure for each: `cp` the file to `/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/p1-backup-spatial_index.dart`, apply one exact replacement, run the tests, `cp` back, then `diff` against the backup. Every restore `diff` exited 0. Line numbers below are the committed files': `differential_test.dart` 307 is the `expect(out.entity, ...)` of the aimed test (recorded at 301 before I added the header paragraph); unit-file lines are unchanged.

| Mutant | Mutation (in my shape) | Result |
|---|---|---|
| M-P1 | Near filter maps, but the stored coordinates are written into `_nearSegmentWorld`, so the pair loop reads stored | **Killed**: all 9 unit tests (lines 93, 117, 135, 153, 178, 203, 223, 241, 278) and the differential aimed test (307) |
| M-P2 | Near filter measures stored coordinates; mapped endpoints are written | **Killed**: the same 9 unit tests and the differential test |
| M-P3 | Every candidate uses the first candidate's transform (`if (k == 0) _composeLeafTransform(...)`) | **Killed**: grouped × ungrouped (135), two groups (153), polyline world-near (178), differential (`Expected <22> Actual <19>`) |
| M-P4 | Any candidate with a null transform turns mapping off for all. This is a per-query analogue: my shape has no per-pair transform to skip | **Killed**: grouped × ungrouped (135), polyline world-near (178), differential |
| M-P5 | Translation dropped (`+ e`, `+ f` removed) | **Killed**: 8 unit tests (93, 135, 153, 178, 203, 223, 241, 278) and the differential test. The phantom test (117) stays green here: its group is a pure rotation |
| M-P6 | Linear part transposed (`b = _ltc, c = _ltb`) | **Killed**: 8 unit tests (93, 117, 135, 153, 203, 223, 241, 278) and the differential test. The polyline test stays green: its group is a pure translation |
| M-P7 | Inverse transform applied (`transformOfLeaf(slot)?.invert()`) | **Killed**: all 9 unit tests and the differential test |
| M-P8 | The whole original file restored. **Differential test alone** | **Killed** (exit 1): `groupedCrossings snap matches brute force at and around every crossing and phantom [E]  Expected: <22> Actual: <19> ... query [50.49109853357346,49.0849755595575] mask=128` |
| M-P9 | One `Vector2` per segment (`_isectA1.setFrom(Vector2(x1, y1))`) | **Killed** by the allocation harness at line 782: `Vector2: 3.902 per call over 1000 calls` (budget 0.5) |
| M-P9d (own) | Each point mapped with `Transform2(a,b,c,d,e,f).transformPoint(Vector2(lx, ly))` | **Killed** at line 782: `Vector2: 1.166 per call` |
| M-P9b | One `Transform2` per segment, read back into doubles, never escaping | **Survived**. `Transform2` read 0.116 per call, the same as the unmutated baseline (0.102–0.110) |
| M-P9c (own) | One `Transform2` per candidate via `Transform2.identity().multiply(group)`, read back into doubles | **Survived**. `Transform2` read 0.133 per call, again the baseline |
| M-P10 (own) | Growth of `_nearSegmentWorld` drops the rows already written (no `setRange`) | Survived the first suite; I then added the buffer-growth test. **Killed**: the near-segment buffer test (line 330) |
| M-P11 (own) | The carried start point is never advanced, so every segment starts at point 0 | **Killed**: polyline world-near (178) and the differential test |

**Why M-P9b and M-P9c survive.** Neither object escapes, so the JIT evidently scalar-replaces it: the profiler reads exactly the baseline. A heap allocation that never happens cannot be counted. This is the same limit the harness header already records for depth-bound `Transform2`. Whether AOT would allocate these objects is not measured. The allocation test's doc comment now states what it catches and what it does not. The measured Vector2 kill (3.9 per call) is well below the 72 segments per call, which fits the profiler's known undercounting, but it is still well over budget.

## Gates (Linux container, worktree root)

- **Engine** (`packages/jet_cad_2d`): `00:22 +1077 -2: Some tests failed.`, `dart test` exit 1.
  - The 2 failures are the standing Linux-only hashes (`test/testing/generate_document_test.dart`: "both text fractions default to zero and change nothing" and "the default document is the one Plan 2 measured, byte for byte").
  - 1,077 = 1,041 + 11 new unit tests + 20 aimed differential tests (one per corpus document) + 4 existing differential tests for the new document + 1 allocation test.
  - `dart analyze`: "No issues found!" (exit 0). `dart format`: 0 changed (exit 0).
- **Render** (`packages/jet_cad_2d_flutter`): `01:04 +940 ~1 -7: Some tests failed.`, exit 1.
  - The 7 failures are the standing `text_ladder` rungs 1–5 and `text_lod_ladder` rungs 1–2 goldens. Identical to the branch point.
  - `flutter analyze`: "No issues found!" (exit 0). Format: 0 changed (exit 0).
- **Harness** (`apps/dev_harness_2d`): `00:43 +82: All tests passed!` (exit 0). Analyze: no issues (exit 0). Format: 0 changed (exit 0).
- **App** (`apps/floor_planner`): `02:33 +491: All tests passed!` (exit 0; 490 + 1 new). Analyze: no issues (exit 0). Format: 0 changed (exit 0). `flutter build web --release`: "✓ Built build/web" (exit 0).
- `git status` before the commit showed no `analysis_options.yaml` change, and none is committed.

## AM2: yes, the fix changes which branch holds

I added a temporary print to the C6 block (backed up and restored, restore `diff` exit 0):
- **Unfixed engine.** At `origin`: an intersection exactly at q (distance 0.0). At `corpus far origin, 23 deg, own groups`: `null` (no snap), because the engine intersected the local coordinates.
- **Fixed engine.** At `origin`: unchanged, exactly q. At the turned own-groups placement: `SnapKind.intersection [4501709.8861087095,1200834.4396294742]` against q `[4501709.88610871,1200834.439629475]`, **1.16e-9 mm off q**. That is rounding at a magnitude of 4.5e6, where the ulp is about 9.3e-10. So neither of the old branches held ("none" or "exactly at q"), and **AM2 went red** (`Expected: true Actual: <false>`).

**Deviation.** I updated the C6 premise in `apps/floor_planner/test/dimension_attach_test.dart` to "an intersection within 1e-5 of the crossing, at every placement". 1e-5 is the file's own premise tolerance for snaps. I also rewrote the block's comment, which described the defect as expected behaviour. The attach checks are unchanged (`bruteCandidates(q)` and `through(q)` both empty). I added the same two checks at the resolved point, which is now what a user would attach at. AM2 passes at both placements (`+19: All tests passed!` for the file).

## Other deviations from the brief

- **There is no dirty-overlay route for a group move.** `SpatialIndex._reconcile` treats a node transform change as structural and answers it with `rebuildAll()` on the same index. The live-index move-and-undo test therefore asserts `rebuildCount` grew, and says so. The overlay route is covered by a separate test: an edit to a grouped leaf (`SetEntityGeometryCommand`) and its undo, with `rebuildCount` unchanged and `dirtyCount` grown.
- **M-P3 and M-P4 are per-query analogues.** My shape maps per candidate in one pass, with no per-pair transform to swap or skip. M-P3 uses the first candidate's transform for all candidates. M-P4 turns mapping off for all candidates when any candidate's transform is null.
- **The app test uses `samplePlan(origin)`** from `test/support/room_fixture.dart` (walls, column, separator and openings, with the parametric system installed), not `startupPlan`. The ledger's probe (`plan11/t4-isect_probe_test.dart`) is not in the repo. The note says "the sample plan with P1 moved −300", and `samplePlan` has no floor-finish lines, so the candidate cap never comes into play. It finds 29 stored crossings, 14 of them with nothing real within 200 mm. The note counted 7 distinct phantom points by a different method (distinct points at 0.05 px/mm), so the numbers are not comparable one for one.
- The `_lta` doc comment now also names `_leafPasses`, which already read those fields before this change. It is a one-word correction to a comment I had to touch anyway.

## Found outside scope (reported, not fixed)

- The allocation harness cannot see a non-escaping `Transform2` (M-P9b and M-P9c above). This is a limit of JIT profiling, already recorded for depth-bound costs. Nothing in this change relies on it, because the fix builds no `Transform2` at all.
- Not verified, noted for the reviewer: the oracle's intersection candidate box is `entityBounds(local).transformedBy(composed)`. If the index's container-space box for a grouped leaf is tighter than that (for example, built from the transformed geometry), the two could pick different entities under `kIntersectionCandidateCap` once more than 64 line-like entities touch one query square. No corpus document comes near 64 in a square, so there is no live disagreement. I did not read how the index builds that box.
