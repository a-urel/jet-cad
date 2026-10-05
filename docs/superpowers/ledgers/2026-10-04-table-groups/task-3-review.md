# Task 3 review — the look (G3)

Reviewer, 2026-10-04. I reviewed `e85ded9..b464204` in a detached worktree at `b464204`
(`/home/user/jet-cad/.worktrees/tg-review`, left in place). Logs, the mutant driver and the backups are in the scratch
dir `tg-review3/`.

## Verdict: Approved, with 1 minor finding and 3 notes

The implementation matches G3, F-3, F-10, F-11 and the 14c S7/R-3 frame recipe. I re-ran every gate and got the
implementer's counts exactly. All 8 named mutants I re-fired went red in the same tests the report names. 5 of my 6 own
mutants went red. The one that survived (O2, below) is a test-fixture gap, not a code defect.

## 1. Gates (run by me, real summary lines)

| Package | Test | Analyze | Format |
|---|---|---|---|
| `jet_cad_floor_plan` | `03:47 +1271: All tests passed!` | No issues found! | 207 files, 0 changed, exit 0 |
| `jet_cad_restaurant_symbols` | `00:02 +94: All tests passed!` | No issues found! | 0 changed, exit 0 |
| `apps/floor_planner` | `01:29 +201: All tests passed!` | No issues found! | 0 changed, exit 0 |
| `apps/restaurant_demo` | `00:10 +18: All tests passed!` | No issues found! | 0 changed, exit 0 |
| `apps/dev_harness_2d` | `00:34 +82: All tests passed!` | No issues found! | 0 changed, exit 0 |
| render `jet_cad_2d_flutter` (not edited) | `01:18 +1304 ~1 -7: Some tests failed.` | No issues found! | 218 files, 0 changed, exit 0 |

- **Render failures.** The 7 failures are exactly the standing set: `text_ladder_golden_test` rungs 1–5 and
  `text_lod_ladder_golden_test` rungs 1–2.
- **Planner count.** +1271 = 1254 + 17 new tests, as reported.
- **Untouched.** `git diff e85ded9..b464204 --stat -- packages/jet_cad_2d packages/jet_cad_2d_flutter` is empty, so the
  engine, the render package and both allocation invariant tests are untouched.
- **No `analysis_options.yaml` in the commit.** The only change in the worktree is the one `pub get` writes to
  `packages/jet_cad/analysis_options.yaml`, and it is not committed.
- **Existing tests.** The only edit to an existing test is `table_status_painter_test.dart` +2 lines. It is mechanical:
  `painterFor` gains two empty `ValueNotifier(const {})`, and no expectation changed. No planner or selection-mode test was
  edited, and all of them are green.

## 2. Line-by-line check

**Frame path (`TableGroupPainter.paint`, P:370-425).**
- **Reads.** Before the rebuild check it reads only scalars and identities.
- **Frames.** One reused `Float64List` is filled in place, and `_paint.strokeWidth` is set in place. Then
  `save/transform/drawPath×n/restore`, through an indexed loop over a prebuilt list.
- **Chips.** It computes `sx`/`sy` as doubles, then `translate`, `drawRRect(prebuilt)`, `drawParagraph(prebuilt, Offset.zero)`.
- **No allocation.** No closure, no iterator, no `Offset`/`RRect`/`Path`/`Paint`/`Paragraph`/`List`. `Offset.zero` is const.
  `camera.value.worldToScreenMatrix` is a field read. `GroupSpy` asserts the `Offset.zero`.
- **Status painter.** Its frame path is unchanged. The new key fields are identity checks only.

**Geometry.**
- **`convexHull` (monotone chain).** It is counter-clockwise for y up. Collinear and duplicate points are dropped because
  `!left` pops within the tolerance. I probed it with standalone copies: collinear input gives the segment ends; a box with
  every corner doubled gives the 4 corners; two clusters give 2 points.
- **`offsetHull`.** The outward normal is `atan2(-dx, dy)`, the right-hand normal of a counter-clockwise loop. That is
  correct, and since the path is in world space the camera's y flip does not matter.
- **Sweep normalisation.**
  - A convex corner gives a sweep in (0, π) after the `while (sweep < 0) += 2π` step.
  - Stadium: vertex 0 gets −π → π, centred on −x; vertex 1 gets +π, centred on +x. Both are correct semicircles. A
    π ± ε rounding error stays within (0, 1.5π].
  - Single point: `addOval`.
  - My own O5 (the `while` normalisation dropped) is red in TG-L10, TG-L4 and TG-V4. The branch-cut corner is therefore
    covered.
- **Mirrored instances.** The corners are transformed and then hulled, so a negative determinant has no effect.
- **Chip anchor.** It is the hull bounds' centre x, at max y + margin. That is the exact top of a round offset's bounds, and
  matches the spec's "frame bounds' centre x at its maximum world y". TG-L7 recomputes it independently at two scales.

**Status painter.**
- **Effective status.** It is `groupMap[groupOf[n]] ?? map[n]`, over `survey.tables` (ascending handle).
- **Captions.**
  - A table status draws its caption on every table carrying that number, as before.
  - A group status draws only on `inLeadOrder(visible members with a top).first`. Duplicates tie to the lower handle.
  - Lead candidates are added after the hidden check and the no-top check (M-TG-11e).
- **Rebuild key, `shouldRepaint`, repaint merge.** All three gain `tableGroups` and `groupStatuses`.
- **`debugRebuilds`.** It is a `@visibleForTesting int` incremented in `_rebuild`, so it is a test seam only.
- **Lookup keys.** The status painter now looks up `map[t.number]` (trimmed by the survey) where it used to call
  `withNumber(key)`, which trimmed the key. The controller already trims the keys (`setTableStatus`), so nothing changes
  through the API.

**ServiceView and PlannerView.**
- **Repaint merges.** The status merge is `camera, tableStatuses, tableGroups, groupStatuses, _changed, _paper`. The group
  painters' merge is `camera, tableGroups, _changed, _paper`.
- **Slot order.** In PlannerView the overlay is `Positioned.fill` after `DraftCanvas` and before the
  `SelectionOverlayPainter`.
- **Null overlay.** It adds no child (collection-`if`). The design mode passes none, so its tree is identical to before.
- **Hit testing.** Unchanged in effect. The overlay `CustomPaint` sits under the existing selection-overlay `CustomPaint`,
  and the gesture handlers are ancestors.
- **Drags.** `TableSelectTool`'s drag preview is `selectionPreviewTransform` only, and it executes no command until release.
  Frames, fills and chips therefore stay put by construction.

**Rulings.**
- **R-C3-1: accept.** It is the literal reading of G2 ("a duplicate number makes all of them members") combined with G3
  ("two or more visible members"). It is also consistent with R-C2-4, where the tool takes its members from the picker.
- **R-C3-2: accept.** It follows the D6c precedent exactly: `TableStatusPainter` already takes `_paper` as a
  `ValueListenable<int>`.
  - D5's "palette by value, `shouldRepaint` on `paper`" rule is for the painters `PlannerView` builds on every `build`.
    These painters are `late final`, so a palette passed by value would go stale.
  - `PaperPalette.forPaper(_paper.value)` is the same function on the same value that `PlannerView` receives
    (`service_view.dart:261`).
  - Assigning the colour at rebuild time, keyed on `paper.value`, is equivalent to assigning it per frame and allocates
    nothing.
  - TG-L5, TG-V4 and the M-TG-21b mutant pin it.
- **R-C3-3: accept.**
  - The early return on an empty table-status map is gone, and M-TG-10d kills a mutant that keeps it.
  - The survey is skipped only when both maps are empty, which with nothing to fill is a pure optimisation.
  - An orphan group status still triggers a survey. That is harmless.
- **R-C3-4: accept.** The hull is computed twice per rebuild, at rebuild rate only.
- **R-C3-5: accept.** These are exact conics. The bounds argument is correct: `getBounds` would include the control points.
- **R-C3-6: accept.** The spec fixes only the text size and the colours.
- **R-C3-7: accept.** A neighbour's chair under the label is the realistic case, and the premise pixel shows that the line
  is really there.

**The two "not pinned" items.**
- **`shouldRepaint` (status, frames, chips).**
  - All three painters are `late final` fields of `_ServiceViewState`.
  - The same instance is handed to the same `CustomPaint` on every build, and `RenderCustomPaint.painter=` with an
    identical instance does nothing.
  - A mode switch creates a new State and new painters, so `shouldRepaint` is never consulted with a different delegate in
    this app.
  - A mutant there is equivalent in the product. Leave it unpinned (note 4).
- **Drag test.** See note 3.

## 3. Mutants re-fired

- **Method.** For each mutant: back up with `cp`, make one exact-string replacement (count checked = 1), run the 3 test files
  (29 tests), restore with `cp`, and `filecmp` the restored file.
- **Results.** Every mutant printed "restored ok", and `git status` is clean apart from the `pub get` yaml. There were no
  compile errors.
- **Driver and output.** The driver is `tg-review3/mutants.py`, the log `mutants.log`, and the full runs `<name>.out`.

| Mutant | Change | Result | Red tests | Matches report |
|---|---|---|---|---|
| M-TG-10b | `_c.groupStatuses` out of the status repaint merge | `+28 -1` | TG-V3 | yes |
| M-TG-10c | `_groupStatusesBuilt` identity out of the key | `+27 -2` | TG-L1, TG-V3 | yes |
| M-TG-11a | caption lead condition → `true` | `+25 -4` | TG-L1, L2, L3, L9 | yes |
| M-TG-12d | hull → the corners' AABB | `+28 -1` | TG-L4 | yes |
| M-TG-12g | `arcTo` → chord (`moveTo`/`lineTo`) | `+26 -3` | TG-L10, L4, V4 | yes |
| M-TG-15b | status painter `if (true \|\| …)` | `+28 -1` | TG-L9 | yes |
| M-TG-21a | `forPaper(paper.value)` → `PaperPalette.light` | `+26 -3` | TG-L5, L8, V4 | yes |
| M-TG-22 | chips moved into the underlay `Stack` above the status layer, no overlay | `+27 -2` | TG-V1, TG-V2 | yes |
| **O1** (mine) | frames sorted in descending handle order | `+28 -1` | TG-L5 | — |
| **O2** (mine) | frame order by the group's **highest** member handle (`members.last`) | **`+29` all passed: survives** | — | — |
| **O3** (mine) | chip drawn for a group with one visible member (chips layer only) | `+27 -2` | TG-L9, TG-V5 | — |
| **O4** (mine) | a group status applied to non-members too (`id == null ? groupMap.values.first`) | `+24 -5` | TG-L1, L2, L3, V3, V5 | — |
| **O5** (mine) | `offsetHull`'s `while (sweep < 0) += 2π` dropped | `+26 -3` | TG-L10, L4, V4 | — |
| **O6** (mine) | chip ink from `foregroundFor(paper)` instead of `foregroundFor(gripMove)` | `+28 -1` | TG-L8 | — |

## 4. Fixtures

They are not degenerate in the dimensions the rules depend on:
- the camera is off the origin at 0.05–0.13 px/mm, plus 0.004 for hiding;
- members are turned and mirrored about 40 m off the origin;
- `G7 = {12, 3, 7}`, with the lead's number duplicated;
- one member is hidden and one has no top;
- one definition is asymmetric, with its box off the base point and one member mirrored;
- a non-member sits inside the members' AABB but outside the hull plus the margin;
- both themes and both papers are covered.

The one gap is finding 1.

## Findings

1. **minor: the draw-order rule's fixture is degenerate, and O2 survives.**
   - **Where.** `test/service/table_group_painter_test.dart`, TG-L5, ~line 509. The second groups map is
     `GB = {7, 20}`, `GA = {12, 3}`.
   - **Evidence.**
     - The two groups occupy disjoint handle ranges: GA is handles 0–1, GB is 2–3. Ordering by any member's handle gives
       the same order.
     - O2 sorts by the highest member handle instead of the lowest (G3's "ascending order of each group's lowest member
       handle", the draw-order non-negotiable), and it passes all 29 tests.
     - Frames share one paint, so the order is invisible in pixels. Chips share the same sorted list, though, and
       overlapping chips do show it.
   - **Fix (test only).** Interleave the handles: `GB = {7, 3}`, `GA = {12, 20}`. The lowest handles are GA = 12 (#0) and
     GB = 3 (#1); the highest are GA = 20 (#3) and GB = 7 (#2), so the two orders differ.
   - **Verified by a scratch probe, restored afterwards.**
     - With only that map changed and the existing assertions kept (`paths[0]` contains 12's base point, `paths[1]` 7's),
       TG-L5 passes unmutated: `00:00 +1: All tests passed!`.
     - Under O2 it goes red: `Expected: true / Actual: <false>`, `00:00 +0 -1`.
2. **note: `convexHull` returns two coincident points for three or more coincident inputs.**
   - **Where.** `lib/src/service/table_group_painter.dart:66-111`.
   - **Evidence.** A standalone copy prints `[1.0, 1.0, 1.0, 1.0]` for `[1,1,1,1,1,1]`. The `n < 3` branch collapses two
     coincident points to one, but the general path does not.
   - **Effect.** `offsetHull` then gets two zero-length edges, every sweep is 0, and no circle is drawn.
   - **Reachability.** It needs every member's box to be the same single point. `Aabb2.isEmpty` admits zero-area boxes,
     but a seating definition whose bounds are one point is not realistic.
   - **Optional fix.** After `hull.removeLast()`, collapse a 2-index hull whose points are within the tolerance to one
     point, as the `n == 2` branch does.
3. **note: no test pins "frames, fills and chips stay put during a drag".**
   - **Why it holds.** The drag preview is `selectionPreviewTransform` only, and nothing executes until release, so it holds
     by construction. No named mutant requires a test.
   - **Recommendation.** If the controller wants a guard against a future "frames follow the preview" change, a cheap
     widget test would do:
     - mid-drag, assert `debugRebuilds` is unchanged and the frame path is the same object for all three painters;
     - after release, assert one rebuild.
   - Not required for approval.
4. **note: the `shouldRepaint` additions are untested.**
   - **Why.** The implementer's reason is true for all three painters. Each is `late final` in `_ServiceViewState` and
     reused across builds; an identical painter is a no-op in `RenderCustomPaint`; a mode switch builds a new State.
   - **Effect.** Any mutant of these lines is equivalent in the product.
   - **Recommendation.** Leave them unpinned.
