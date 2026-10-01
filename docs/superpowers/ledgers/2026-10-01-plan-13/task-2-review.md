# Task 2 review: omitOwners (spec D6, T-2), with the unplanned painter fix

**Scope**
- Reviewer: independent.
- Commits: `749e8b1`, `32d488f`, `257876e`, `64bb01c` (range `c96bb9b..64bb01c`).
- Reviewed in the detached worktree `.claude/worktrees/plan-13-review`, at `64bb01c`.
- Scratch: `.../scratchpad/r2/`. The mutant runner is `mut.sh`. It cp-backs-up the file, makes one exact-string replacement, runs the named test file in the foreground, then cps the file back under a trap and diffs it. Every run printed `RESTORED diff=0`.
- Nothing was committed. `git status --short` printed nothing at the end.

## 1. Render gate, re-run by me (`packages/jet_cad_2d_flutter`, `CI=true`)

```
00:49 +1039 ~1 -7: Some tests failed.
```
All 7 failures are the standing Linux golden failures, and there are no others (`grep '\[E\]'`, deduplicated):
```
test/golden/text_ladder_golden_test.dart: text ladder rung 1..5 (RenderBackend.canvas) [E]   (5)
test/golden/text_lod_ladder_golden_test.dart: text lod ladder rung 1, 2 (RenderBackend.canvas) [E] (2)
```
- `flutter analyze`: `No issues found! (ran in 1.6s)`.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 188 files (0 changed)`, exit 0.

The counts match the expectation: 1039 pass, 1 skip, 7 standing failures.

**Allocation invariants**, run unedited:
- `flutter test test/invariants/paint_allocation_test.dart`: `00:01 +3: All tests passed!`.
- `dart test test/invariants/query_allocation_test.dart` (engine): `00:06 +6: All tests passed!`.
- `git diff --stat c96bb9b` on both files printed nothing.

**Scope**
- `git diff --stat c96bb9b -- packages/jet_cad_2d_flutter/test/golden/ packages/jet_cad_2d_flutter/test/invariants/ packages/jet_cad_2d/ apps/` printed nothing. No golden PNG changed, and the engine and the app are untouched.
- The changed files are exactly these six:
  - `draft_painter.dart`
  - `reference_walk.dart`
  - `omit_owners_test.dart`
  - `grouped_root_instance_test.dart`
  - `export_fixture.dart`
  - `export_fixture_test.dart`
- Commit trailers: correct on all four commits.

## 2. The unplanned fix, `32d488f` (screen frame path)

### (a) The bug is real at `c96bb9b`

At `c96bb9b`, `_drawInstance` passed `accumulated: node.transform`.

**FIX-rev mutant.** I reverted exactly that expression. At `draft_painter.dart:434-436`, `node.parent == document.rootHandle ? node.transform : index.rootIndex.transformOfInstance(instance)` became `node.transform`. Then I ran `test/grouped_root_instance_test.dart`:
```
00:00 +0 -1: the outer group's instance's leaf lands where the tree puts it [E]
  Expected: a value less than <0.000001>
    Actual: <488.06321745861294>
```
On the screen camera (`ViewportTransform.fit` at 800x600), the old painter drew the outer group's instance leaf 488 px away from where the tree composes it. `referenceWalk` composes the groups (`reference_walk.dart:101`), so the two routes disagreed. The defect is real and visible on screen.

### (b) The fix is correct

**Reading the code**
- `ContainerIndex.build` flattens groups. It stores each instance's transform composed through every group between the instance and the container: `instanceTransforms.add(acc.multiply(transform))` (`container_index.dart` build loop).
- Its instance *box*, which `forEachInstanceInRect` culls against, is built from that same composed transform.
- So before the fix, culling already used the group's placement and drawing did not. That is why the leaf vanished: the painter culled it in `_drawContainer` through the wrong inverse.
- After the fix, a grouped root instance takes the stored composed transform, and an ungrouped one keeps `node.transform`, which is byte-identical to before.

**Temporary differential test.** I wrote `test/zz_review_tmp_test.dart`, ran it, kept a copy in `scratchpad/r2/`, and deleted it from the tree. Its fixture has an ungrouped root instance, an instance directly in a root group `a`, and an instance in group `b` nested inside `a`. Group `b` rotates and scales, its instance mirrors, and nothing is at the origin. Root leaves and a group leaf are interleaved by handle between the instances.

The test asserts four things:
1. The painter is a superset of the reference.
2. The painter and the reference have equal item counts (7).
3. The `debugOnVisit` order of top-level items is exactly ascending by handle: `[l1, i0, l2, i1, lb, i2, l3]`.
4. Each instance's polyline lies within 1e-6 px of its placement, which the test composes from the tree independently of both routes.

Results:
- At `64bb01c`: `00:00 +1: All tests passed!`.
- With FIX-rev applied: `Expected: <7> Actual: <3>` (the superset cursor). The nested-group instance and the single-group instance were both misplaced.
- With FIX-always (`node.parent == document.rootHandle` replaced by `false`, so every instance takes the lookup): `+1: All tests passed!`. This equivalent mutant shows the branch is only an optimisation. For a root-parented instance, the stored composed transform equals `node.transform`.

**Agreement with picking, snapping, extents and outlines.** Nothing remains in disagreement. The painter was the only outlier.
- `SpatialIndex` takes `root.transformOfInstance(node)` / `index.transformOfInstance(node)` in each of these:
  - the band descent (`spatial_index.dart:463, 607`);
  - the pick/snap descent (`:944`);
  - the slack lifting (`instanceTransformAt`, `:2283, 2339, 2370`).

  All of these are composed through groups.
- `outline_cache.dart` composes groups too: the selection overlay's outlines use `tree.accumulatedTransform` (`:309-322`) and `toWorld.multiply(node.transform)` per level (`:356-358`).
- `tile_cache.dart` invalidation uses `tree.accumulatedTransform` (`:2096, 2127`).
- `forEachInstanceInRect` has exactly one caller in `lib`, the painter (`draft_painter.dart:373`).

### (c) Allocation

Read `draft_painter.dart:434-436`:
- `node.parent` is a field read.
- `Handle` is an `extension type const Handle(int value)`, so `==` and `List<Handle>.indexOf` are int compares with no boxing.
- `transformOfInstance` returns the stored `Transform2` object (`container_index.dart:581-585`).

Nothing is allocated. Both invariant tests are green and unedited (section 1).

There is a caveat. `paint_allocation_test` builds its corpus with `generateDocument`, which puts groups at the root but no instances in them. So the new branch is shown allocation-free by reading, not by measurement. See finding 3.

### (d) Goldens

`git diff --stat c96bb9b -- packages/jet_cad_2d_flutter/test/golden/` is empty, and the standing failure count is still 7.

**Verdict on 32d488f:** a correct, necessary fix. The commit message is accurate. It belongs in the spec's "Amended at execution" and in the results note, as the implementer asked.

## 3. The planned part: D6 and T-2

**Painter**
- `_omitted(slot)` is `omitOwners.isNotEmpty && omitOwners.contains(document.entities.ownerAt(slot))`, which is D6 verbatim.
- It is checked at the root stream (`:390`, after the lower-handled instances are flushed) and in `_drawContainer` (`:482`, after the tree/overlay duplicate check).
- Both checks run before `debugOnVisit` and before any style or geometry is resolved.
- The two orders are draw-order-equivalent, because instances are flushed by handle comparison against the next leaf drawn (or at the end), never relative to a skipped leaf.
- Screen cost: one `isNotEmpty` on a const empty set.

**Walk**
- `_ownLeaves(node)` returns no leaves for a node in the set.
- `_childNodesOf` is untouched, so the walk still recurses into an omitted node's children. This is D6's "own route", and it is honestly a different route from the painter's owner test.
- The ATTRIB site (`reference_walk.dart:110`) also goes through `_ownLeaves`. An ATTRIB's owner is the instance, so this matches the painter's owner test for attributes. It is consistent with D6's narrow meaning, though nothing tests it (finding 2).

**T-2 against the plan**
- Page camera `pageCamera(f.page, 72/25.4)`, viewport = page size: present.
- `{separatorGroup, outerGroup}` and `minTextCapPixels: 0` on both routes: present.
- Comparison plus equal count: present.
- Positive content checks for the instance's three leaves, both labels, `nestedLine` and `outerInstanceLeaf`, plus every other kept leaf: present.
- Negative checks: present, by handle and also by page position, with the position composed from the tree independently of both routes.
- Default empty set: both routes draw the separator and `outerGroupLine`.
- Exact-difference test: present.
- The fixture is not degenerate: the page origin is (3000, -1500), the groups are rotated and translated, and the instance is mirrored and scaled.

### Mutants (fired by me; the test file is `test/export/omit_owners_test.dart` unless noted)

| id | file:line | mutation | result (real line) | which assertions fired |
|---|---|---|---|---|
| M-13q | draft_painter.dart:404 | `omitOwners.isNotEmpty &&` → `false &&` | `00:00 +8 -6: Some tests failed.` | **comparison** (superset extras check: `Expected: true Actual: <false>`, i.e. painter drew an item inside the view the reference did not); **content** (`Expected: not contains <35>`); exact-difference (`Expected: Set:[35, 37] Actual: Set:[]`); debugOnVisit; container-route comparison and content |
| M-13r | draft_painter.dart:405 | `ownerAt(slot)` → `handleAt(slot)` | `00:00 +8 -6: Some tests failed.` | same six as M-13q: comparison and content both fire |
| M-13aa | reference_walk.dart:98 | `_childNodesOf(handle)` → `(omitOwners.contains(handle) ? const <Handle>[] : _childNodesOf(handle))` | `00:00 +12 -2: Some tests failed.` | comparison; reference content `Expected: contains <42>` (nestedLine; 39, outerInstanceLeaf, also absent) |
| R-broad (mine) | draft_painter.dart:405 | painter also skips a leaf whose owner's *parent* is in the set (the wide reading) | `00:00 +10 -4: Some tests failed.` | comparison (`Expected: <15> Actual: <14>`, the equal-count assertion), painter content `contains <42>`, exact-difference `[35, 37, 42]`, debugOnVisit |
| P-cont (mine, re-fired) | draft_painter.dart:482 | container-site skip deleted | `00:00 +12 -2: Some tests failed.` | container-route comparison and content (`not contains <30>`) |
| R-visit-cont (mine) | draft_painter.dart:482-483 | container site: `debugOnVisit` called before the skip | `00:00 +14: All tests passed!` | **survives**: see finding 1 |
| R-attrib (mine) | reference_walk.dart:110 | ATTRIB site ignores the set (`leaves[child] ?? const <int>[]`) | `00:00 +14: All tests passed!` | **survives**: see finding 2 |
| FX-out | export_fixture.dart:199 | outside line crosses the sheet edge `[-6000, 2500, 3500, 3700]` (test file `export_fixture_test.dart`) | `00:00 +7 -1: Some tests failed.` | "the outside line is wholly outside the sheet at 1:50 and 1:100" (`Expected: false Actual: <true>`) |
| FIX-rev | draft_painter.dart:434-436 | the pre-fix `node.transform` (test file `grouped_root_instance_test.dart`, and my temporary test) | `00:00 +0 -1` / `Expected: <7> Actual: <3>` | see §2(a)/(b) |

**Notes on the counts**
- The implementer reported M-13q and M-13r as `+7 -3`. I get `+8 -6`, because the container-route tests added in `64bb01c` also go red. The assertion identities agree.
- The equal-count assertion the implementer added is load-bearing. Under R-broad it is the comparison assertion that fires: the superset check alone would also have caught the missing nestedLine, but the count names it.

### The implementer's deviations

1. **`differential.dart` instead of `sink_comparison.dart`.** Accepted. `sink_comparison.dart` compares the canvas and vertices backends by pixels, while `expectPainterSupersetOfReference`/`flatten` is the repo's RecordingDrawSink painter-vs-walk oracle. The plan and spec name the wrong file; record it at Task 11.
2. **`RecordingDrawSink(shadesDashes: true)` on the painter side.** Accepted. The fixture's dashed polyline and the separator's line would otherwise be cut into spans by the painter while the walk emits them whole. Shading keeps one polyline bracketed by dash ops, which `flatten` skips.
   - The cost: T-2 does not cover the painter's own dash cutting, which is what the PDF sink (`shadesDashes == false`) will receive. The implementer states this. T-3, which replays painter ops into `PdfDrawSink`, is where it belongs.
   - The comment at `test/support/differential.dart:137` ("No sink compared through this oracle shades dashes yet") is now stale (finding 4).
3. **The extra container-route case (`{definition}`).** Accepted, and it is needed. The plan's set reaches only the root stream, because groups are flattened, so P-cont would survive without it. I confirmed P-cont red. It omits a definition, which no export does, but D6 says "at the root stream and inside containers alike", and this is the only way to reach the container site with today's node kinds.
4. **The equal-count assertion.** It turns the "superset" helper into the plan's "equal". It holds on the fixture at the page camera, and R-broad shows it earning its place.

## Findings

1. **Low: the container-site `debugOnVisit` ordering is untested.**
   - Where: `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart:482-483` and `test/export/omit_owners_test.dart:200`.
   - Plan Task 2 says `debugOnVisit` is not called for a skipped leaf, at both sites. The debugOnVisit test omits only the separator and the outer group, which are root-stream leaves. Calling `debugOnVisit` before the skip inside `_drawContainer` survives (R-visit-cont).
   - Fix: in the `{definition}` group, add a visit-recording paint and assert that `f.instanceLine`, `f.instancePolyline` and `f.pointInInstance` are not visited, while `f.instance` is.
2. **Low: omitting an instance's own leaves (ATTRIBs) is untested on both routes.**
   - Where: `packages/jet_cad_2d_flutter/lib/src/reference_walk.dart:110`.
   - The walk routes ATTRIB leaves through `_ownLeaves`, and the painter's owner test covers them generically. The fixture has no ATTRIB, so R-attrib survives. No export puts an instance in the set today, so nothing ships wrong.
   - Fix: add an ATTRIB leaf (owner = an instance, instance-local coordinates) to a T-2 case that omits that instance. Assert that both routes drop the attribute and still draw the definition's leaves. Otherwise, record it as an accepted gap.
3. **Low (perf/measurement): the new grouped-root-instance branch is O(root instances) per grouped instance per frame, and no measurement covers it.**
   - Where: `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart:436` → `container_index.dart:581` (`_instanceHandles.indexOf`).
   - Today the app places every instance at the root (`symbol_placer.dart:126`), so the cost is reached only by imported or generated documents. `SpatialIndex` already pays the same linear lookup on its pick, snap and band paths.
   - The allocation corpus (`generateDocument(groupCount: 10, …)`) has no instance under a group, so `paint_allocation_test` does not execute the new branch. It allocates nothing by reading.
   - Fix (later, not in this task):
     - Carry the instance's index position alongside its handle from the root instance query, or keep a handle→position map built at index build.
     - Add a grouped root instance to the corpus in a plan that is allowed to touch it. The invariant files are frozen here.
4. **Info: a stale comment.**
   - Where: `packages/jet_cad_2d_flutter/test/support/differential.dart:137`.
   - "No sink compared through this oracle shades dashes yet" is now false: T-2 compares a `shadesDashes: true` painter recording through it.
   - Fix: reword the comment to say that a shading sink's dash brackets are skipped and the shaded polyline compares whole.
5. **Info: record the out-of-scope fix and the spec errata.**
   - Commit `32d488f` changes the screen drawing of any instance under a root-level group. It belongs in the spec's "Amended at execution" and in the results note.
   - Record the `sink_comparison.dart` → `differential.dart` erratum (spec T-2, plan Task 2) at Task 11.

## Verdict

**Approved with notes.**
- The unplanned fix is real, correct for every case I could construct, allocation-free and golden-neutral. Picking, snapping, outlines and tile invalidation already composed group transforms, so after the fix the painter agrees with them.
- D6 is implemented exactly on both routes.
- T-2 kills M-13q, M-13r, M-13aa, P-cont and my wide-reading mutant.
- Findings 1 and 2 are small test gaps that can be closed in a follow-up commit. Neither blocks Task 3.
