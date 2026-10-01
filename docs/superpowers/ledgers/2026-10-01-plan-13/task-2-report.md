# Task 2 report — omitOwners (spec D6, T-2)

**Commits** (on top of `c96bb9b`, not pushed):
1. `749e8b1` test(render): the export fixture's outside line is outside at every scale (Task 1 review finding 1)
2. `32d488f` fix(render): a root-level instance inside a group is placed through the group (**pre-existing painter defect, found by T-2; see "Spec/plan wrong" 1**)
3. `257876e` feat(render): omitOwners in the painter and the reference walk
4. `64bb01c` test(render): omitOwners through the container route and debugOnVisit

## Files
- `packages/jet_cad_2d_flutter/test/support/export_fixture.dart`: `outsideLine` is now `[-6000, 2500, -3500, 3700]`, left of the sheet's origin x 3000, so it is outside at every scale.
- `packages/jet_cad_2d_flutter/test/support/export_fixture_test.dart`:
  - "everything but the outside line" now asserts `all.minX < sheet.minX`. The old assertion was `maxX > sheet.maxX`.
  - New test: "the outside line is wholly outside the sheet at 1:50 and 1:100". Its bounding box must not intersect `sheetWorldRect`, and it must be clear of every edge by 1,000 mm.
- `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`:
  - `final Set<Handle> omitOwners` (constructor, default `const {}`).
  - `_omitted(slot) => omitOwners.isNotEmpty && omitOwners.contains(document.entities.ownerAt(slot))`.
  - At the root stream it is checked after the lower-handled instances are flushed (`return`). In `_drawContainer` it is checked after the duplicate check (`continue`). Both checks come before `debugOnVisit` and before anything is resolved.
  - Fix (commit 2): `_drawInstance` now uses `node.parent == document.rootHandle ? node.transform : index.rootIndex.transformOfInstance(instance)`.
- `packages/jet_cad_2d_flutter/lib/src/reference_walk.dart`: `referenceWalk(..., Set<Handle> omitOwners = const {})`.
  - `_ownLeaves(node)` returns no leaves for a node in the set. `_collect` uses it for a node's own leaves and for an instance's ATTRIB leaves.
  - `_childNodesOf` is untouched, so the walk still recurses into an omitted node's child nodes (D6's own route).
- `packages/jet_cad_2d_flutter/test/export/omit_owners_test.dart` (new, 14 tests): T-2.
- `packages/jet_cad_2d_flutter/test/grouped_root_instance_test.dart` (new, 1 test): regression test for the fix.

## T-2 as built
- Setup:
  - Camera: `pageCamera(f.page, 72/25.4)`, with viewport = `size`.
  - Both routes get `minTextCapPixels: 0` and `omitOwners`.
  - Painter sink: `RecordingDrawSink(shadesDashes: true)`.
  - Walk sink: `RecordingDrawSink()`.
- Comparison: `expectPainterSupersetOfReference` from `test/support/differential.dart`, plus an equal count of flattened items, which makes it "equal".
- With `{separatorGroup, outerGroup}` omitted:
  - The two routes draw the same drawing.
  - Each list contains these leaves (by `BeginResidualOp.debugHandle`): instanceLine, instancePolyline, pointInInstance, labelBig, labelWc, nestedLine, outerInstanceLeaf, line, closedPolyline, dashed, arc, circle, fill, fillBoundary and aci7Line.
  - Each list contains no separatorLine, outerGroupLine or outsideLine. This is checked by handle and also by position: no drawn vertex lies within 1e-3 px of their page points, which are composed from the tree independently of both routes.
- With the default empty set:
  - The routes are equal.
  - Both draw separatorLine and outerGroupLine, by handle and by position.
  - The painted leaf set minus the omitted-run leaf set is exactly `{separatorLine, outerGroupLine}`.
- debugOnVisit: it is not called for separatorLine or outerGroupLine. It is still called for drawn leaves and for outerGroupInstance.
- Container route, with `{definition}` omitted:
  - The routes are equal.
  - Neither draws the instance's three leaves. outerInstanceLeaf, separatorLine and line still draw.
  - This was added because the separator and the outer group are flattened into the root index, so they never reach the container-site check. Without it, deleting that check survived nothing named.
- Page-size guard: A4 landscape at 72/25.4.

## Gates
Render, at `64bb01c` (`CI=true flutter test`), real tail:
```
00:49 +1039 ~1 -7: Some tests failed.
```
- The count is 1,023 + 1 (fixture self-test) + 1 (grouped instance regression) + 14 (T-2) = 1,039 passing, 1 skip.
- The 7 failures are exactly the standing Linux golden failures:
  - text_ladder rung 1..5 (canvas)
  - text_lod_ladder rung 1, 2 (canvas)
- Intermediate tails:
  - After the fix commit: `00:51 +1025 ~1 -7`.
  - After the feat commit: `00:52 +1035 ~1 -7`.

Analyze and format results:
- `CI=true flutter analyze`: `No issues found! (ran in 1.7s)`.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 188 files (0 changed)`, exit 0.

Allocation invariants:
- `paint_allocation_test.dart` + `differential_test.dart`: `00:01 +13: All tests passed!`.
- Engine `query_allocation_test.dart`: `00:08 +6: All tests passed!`.
- `git diff --stat c96bb9b -- packages/jet_cad_2d apps packages/jet_cad_2d_flutter/test/invariants packages/jet_cad_2d_flutter/test/golden packages/jet_cad_2d_flutter/test/differential_test.dart` printed nothing.

Unchanged and not re-run (no pubspec touched):
- **Engine:** only the one allocation test above was run.
- **App:** not re-run.

`analysis_options.yaml` was never staged.

## Mutants
Every mutant was fired with a cp backup, a one-line mutation and the named test file run in the foreground, then a cp back; `diff` exited 0 every time. The script is `scratchpad/e2/mut.sh`.

| id | file:line | mutation | red | real output |
|---|---|---|---|---|
| FX-out | export_fixture.dart:199 | outside line crosses the sheet's left edge: `[-6000, 2500, 3500, 3700]` | export_fixture_test "the outside line is wholly outside the sheet at 1:50 and 1:100" | `00:00 +7 -1: Some tests failed.` |
| FX-old | export_fixture.dart:199 | back to the old `[20000, 10000, 22500, 11200]` | the same test (reason `1:100.0`) + "everything but the outside line lies inside the sheet" | `00:00 +6 -2: Some tests failed.` |
| M-13q | draft_painter.dart:404 | `omitOwners.isNotEmpty &&` → `false &&` (painter ignores the set) | omit_owners_test: **both** the comparison and the content check. The comparison failed on "the painter drew polyline(356.29,206.41)(497.31,192.26) inside the view and the reference did not". The content check failed on `Expected: not contains <35>`, and "omitting draws exactly the omitted leaves fewer" also failed. | `00:00 +7 -3: Some tests failed.` |
| M-13r | draft_painter.dart:405 | `ownerAt(slot)` → `handleAt(slot)` | the same three tests as M-13q: the comparison (same message) and the content check (`not contains <35>`) | `00:00 +7 -3: Some tests failed.` |
| M-13aa | reference_walk.dart:98 | `_childNodesOf(handle)` → `(omitOwners.contains(handle) ? const <Handle>[] : _childNodesOf(handle))` (walk skips the subtree) | the comparison (the painter drew nestedLine and the others inside the view and the reference did not) and the reference content check ("the reference lost the nested group's line", `contains <42>`) | `00:00 +12 -2: Some tests failed.` |
| W-ign | reference_walk.dart:122 | `omitOwners.contains(node) ?` → `false ?` | comparison ×2, reference content ×2 | `00:00 +10 -4: Some tests failed.` |
| P-root | draft_painter.dart:390 | root-site skip disabled | comparison, painter content, "exactly the omitted leaves fewer", debugOnVisit | `00:00 +10 -4: Some tests failed.` |
| P-cont | draft_painter.dart:482 | container-site skip disabled | container-route comparison, container-route painter content | `00:00 +12 -2: Some tests failed.` |
| P-visit | draft_painter.dart:390 | `debugOnVisit` called before the skip | "the painter does not report a skipped leaf to debugOnVisit" | `00:00 +13 -1: Some tests failed.` |
| FIX-1 | draft_painter.dart:434 | `node.parent == document.rootHandle` → `true` (the old `node.transform` always) | grouped_root_instance_test + 6 omit_owners tests | `00:00 +8 -7: Some tests failed.` |

## What the spec / plan got wrong or left open
1. **The painter misplaced a root-level instance inside a group. This defect predates plan 13, and T-2 cannot pass without fixing it.**
   - Cause:
     - Groups are flattened into the root `ContainerIndex`, so `outerGroupInstance` arrives on `forEachInstanceInRect` at the root.
     - `_drawInstance` then descended with `node.transform` alone, dropping the group's transform.
     - `ContainerIndex` stores the composed transform, and `_descend` inside containers uses it. Only the root path was wrong.
   - Symptom: with the empty set, the painter drew 16 items and the reference 17. outerInstanceLeaf (handle 39) was missing, because with the wrong transform it was culled.
   - Why it was never caught: the differential fixture has no instance under a root-level group.
   - Fix:
     - In a separate commit (`32d488f`), a grouped root instance now takes `rootIndex.transformOfInstance` (a linear `indexOf`, paid only by grouped root instances).
     - An ungrouped one keeps `node.transform`, so the screen path is byte-identical for it.
     - No golden moved: the count is still 7 standing failures.
     - The fix allocates nothing, because the transform comes back as the stored object. The allocation test is green.
   - Open for the human/orchestrator: this is a screen-visible bug fix outside D6's letter. It is the closest thing inside the spec's bounds, because the spec requires the outer group's instance to draw, but it should be recorded in the spec's "Amended at execution" and in the results note. In the app, a separator group never holds an instance. An instance inside a user group (if the app can make one) was drawn in the wrong place on screen until now.
2. **"compared with `test/support/sink_comparison.dart`"** (plan Task 2 and spec T-2) names the wrong helper. That file compares the canvas and vertices backends by pixels. The RecordingDrawSink painter-versus-walk comparison is `expectPainterSupersetOfReference` / `flatten` in `test/support/differential.dart`, which is what I used. Record this at Task 11.
3. **The dashed polyline breaks a plain RecordingDrawSink comparison.** The painter cuts dashes into spans, while the walk emits one polyline; `differential_test` keeps its fixture "entirely continuous" for exactly this reason. The painter side therefore records with `RecordingDrawSink(shadesDashes: true)`: one polyline bracketed by dash ops, which `flatten` ignores. Note: the PDF sink has `shadesDashes == false` (D3), so T-2 does not cover the painter's own dash cutting. The dasher's own tests do.
4. **"Equal" vs the differential helper.** `expectPainterSupersetOfReference` checks a superset plus "extras are off-screen". I added an equal-count assertion so T-2 checks equality as the plan says. It holds on the fixture at the page camera.
5. **D6's container route is not reached by the plan's T-2 set.** `{separatorGroup, outerGroup}` both flatten into the root stream, so deleting the `_drawContainer` check (P-cont) survives the plan's tests. I added the `{definition}` case, which kills it.
6. The fixture's `pointInInstance` etc. are unchanged. The outside line moved, so any later task that assumed its old coordinates must use `f.outsideLine`. Nothing in the tree referenced the coordinates.

## Decisions
- The skip at the root runs after the lower-handled instances are flushed. Inside a container it runs before the flush (the `continue` defers the flush to the next leaf). Both orders are draw-order-equivalent, since instances are flushed by handle.
- The walk's `_ownLeaves` also covers an instance's ATTRIB leaves (owner = the instance), which matches the painter's owner test for attribs.
