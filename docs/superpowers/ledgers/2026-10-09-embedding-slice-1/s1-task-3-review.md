# Slice 1, Task 3: the overlay layer, non-interactive (G-5, G-6, G-7, H-8), independent review

**Commit reviewed:** `b420493` (parent `6c742b4`), branch `claude/exciting-pasteur-9m22jv`.
**Where:** my own clones at `b420493`: `/tmp/s1t3-review/repo` for the named and own mutants, `/tmp/s1t3-review/gates` for the gates, and `/tmp/s1t3-review/probe` for probes (`packages/jet_cad_floor_plan/test/host/zz_review_probe_test.dart`, uncommitted, P1 to P9) and the probe-side mutants. In `/home/user/jet-cad` I edited nothing except this file.
**Read:** CLAUDE.md; the plan's Global constraints, Task 3 and the mutant table; the spec's F-9, P-4, P-6, G-5, G-6, G-7, H-8, invariant 7 and the Slice 1 mutants; the implementer's report; `git diff 6c742b4 b420493` in full.

## Verdict

**Approve with fixes.** None of the fixes needs a code change in `lib/`.

The render object matches Flutter's model:
- `paint`, `hitTestChildren`, `applyPaintTransform` and semantics all read the same `dx`/`dy`.
- RepaintBoundary children are re-composited at their new offset without repainting.
- Culled children are not composited and not in semantics.
- Children are keyed by instance and painted in ascending handle order.
- The listeners are paired with attach/detach and with init/dispose.

The probes confirm this directly:
- **P1:** after pan and zoom, each shown child's `OffsetLayer.offset` equals its parent data and its `localToGlobal`. Culled children's layers are detached.
- **P2 and P9:** culled and hidden-by-scale overlays have no semantics node. The semantics rect follows a pan.
- **P5:** a natural widget whose size changes is re-centred, and a canvas resize re-culls.
- **P7:** overlays in both modes with mode switches and pans throw nothing.

The screen boxes are right for the 30°, mirrored 90° and (1.5, 0.8)-scaled tables with the off-base box under the y-flipped, panned camera. The anchor is `Align`'s rule. All 8 named mutants are killed. Gates are green and the standing sets match exactly.

What needs attention:
- **R-1 (decision):** a mismatch between spec G-5 and the plan/implementation about when a host rebuild calls the builder.
- **R-2 (decision):** F-1. I recommend accepting it and amending the spec text.
- **R-3 to R-6:** test gaps where the code is right but the suite does not pin it. Paint is the main one: the suite checks positions only through `applyPaintTransform`, so two paint mutants survive.

## The render object against Flutter's model (item 1)

| Check | Result |
|---|---|
| parentData offset vs `paint` / `hitTestChildren` / `applyPaintTransform` / semantics | All four read `dx`/`dy`. `paint` passes a cached `BoxParentData.offset` that is refreshed when it differs. P1 shows the composited `OffsetLayer.offset` equals `Offset(dx, dy)`, and `localToGlobal` agrees within 1e-9, for every shown child over 3 pan+zoom frames. |
| RepaintBoundary children, layer offsets | `paintChild` on a clean boundary goes through `_compositeChild`, which sets the child's `OffsetLayer.offset` with no repaint. The `paint` `offset` is `Offset.zero` because the stack sits directly under its own `RepaintBoundary`, so the `offset + data.offset` branch never allocates in practice. |
| `markNeedsPaint` vs `markNeedsLayout` per size mode | natural: paint plus semantics (layout only on the first un-hide). box: layout. The box branch is effectively decided by `!_naturalLaidOut`, which is always false in box mode. That is why my O16 was an equivalent mutant; O16b, the real flip, is killed. |
| Culling | `shown` is false when hidden by scale, when the slot is out of range, when a natural child is unlaid, or when the rect misses `Offset.zero & size`. Not painted (P1, and O7 is killed through the counter), not hit (`shown && hasSize`), not in semantics (P2, P9). |
| `hideBelowScale` | `<` is strict, so the bound itself shows (TO11). Children are not laid out below it. If a child goes dirty while hidden, the parent's `performLayout` runs and resets `_naturalLaidOut`, so an un-hide relays it. |
| Child order and keys | `ValueKey(instance.value)` on the `ParentDataWidget`, so two `7`s keep two elements. Order is `tableDetails`, which is `TableSurvey.tables`, "ascending by handle (T1)". This is the draw order. |
| Adoption and drop | Children are rebuilt from `_values` each build. Insert, move and remove go through `MultiChildRenderObjectElement`. `_OverlaySlot` re-slots and marks layout. The `corners` setter sets `_stale`, so layout re-measures. The `_built` cache drops dead instances. |
| Camera listener | Added in `attach`, removed in `detach`; the `camera` setter swaps while attached. The state removes its own in `dispose`. Neither removal is pinned by the suite (R-4). |
| Inside `ClipRect` | `Positioned.fill(ClipRect(IgnorePointer(RepaintBoundary(stack))))` is the last child of the canvas `Stack`, inside `InteractionLayer` and `CameraGestureDetector`. Badges never paint over rulers or bars. The clip also drops partly visible semantics correctly. |
| `IgnorePointer` | TO8 holds: a tap on a badge is the table's. `hitTestChildren` (which uses `addWithPaintOffset` with the same offset) is unreachable until Task 4, as the report's F-5 says. |

## The builder diffing (item 2)

- **Cache.** The cache is a `Map<Handle, _Built(value, widget)>`, keyed by instance. If a table's `FloorPlanTableOverlay` is `==` to the cached one, it gets the identical `_OverlayChild` and Flutter skips it.
- **`==` cost.** `FloorPlanTableOverlay.==` compares `detail` with `FloorPlanTableDetail.==`, which compares the four corners deeply (`listEquals`) plus scalar fields. `_recompute` also runs `listEquals` over the whole list. That is O(tables × 4) at source rate (revision, selection, focus, statuses, groups, detail crossing, host rebuild) and never per frame. It is cheap.
- **Builder identity change.** This builds every table (TO15; O18 is killed).
- **Detail crossing.** This builds every table once (TO4). O15, which only rebuilds on upward crossings, is killed by TO3.
- **Status, focus and selection changes.** Only the affected tables are rebuilt (TO5, TO6; M-H18, O19 and the focus flip are all covered).
- **Pan and zoom.** The state's camera listener computes only `overlayDetailLevel`, an indexed loop. No build happens (TO2, TO10; M-H8 is killed).
- **A host rebuild with a closure literal.** This rebuilds every overlay on every host build: P3 measured 7 calls for one host `setState`. That matches G-5's "or when the host rebuilds the view" literally. With a tear-off it rebuilds none, which does not match: see R-1.

## Findings

### R-1 (Medium, decision): G-5 says a host rebuild calls the builder again; the code calls it only when the function changes

Spec G-5, the binding text, says: "again **for that table only** when its `FloorPlanTableOverlay` changes … **or when the host rebuilds the view**". The plan narrowed this to "the view rebuilds with a new builder". The code and TO15 follow the plan, using `oldWidget.builder != widget.builder`.

The two cases differ in practice:
- **A closure written in `build`** (the common case, and the guide's likely snippet) is a new object on every build. Every host rebuild therefore rebuilds every overlay (probe P3: 7 of 7). That is the spec's behaviour, and it costs O(tables) widget builds per host build.
- **A method tear-off** (`tableOverlayBuilder: _badge`) is `==` across builds of the same `State`. A host that changes a field its builder reads, then calls `setState`, keeps the stale overlays. Probe P4: `Text('$prefix-…')` still reads `a-1` after `prefix = 'b'; setState`. Inherited dependencies (`Theme.of`, `context.watch`) do still work, because the builder runs in the overlay's own `BuildContext`.

**Recommendation: keep the implementation and amend G-5 to the plan's wording.** It is never more expensive than the spec's rule, and it is identical for closure literals. It also gives a host a way to avoid rebuilding everything: hold the builder in a field or use a tear-off. Then do three things:
- Say the following in `tableOverlayBuilder`'s dartdoc and in the host guide (Task 5): *"called again for every table only when the view gets a different function: a closure written in `build` is a new function on each build, so each host build rebuilds every overlay; a tear-off or a stored function is the same, so a builder that reads the host's own fields must be replaced when they change, or read them through an inherited widget or a listenable."*
- Pin the closure-literal case with a test (P3 shape).
- Ask the controller or the human to confirm, because the spec is the authority here.

The alternative is to follow G-5 literally: clear `_built` on every `didUpdateWidget`. That is simpler, but it throws away the tear-off optimisation.

### R-2 (Low, decision a / F-1): the paint `Offset` is the framework's floor. Accept it and amend the spec text.

`paintChild` needs an `Offset`, and the code creates one only when a painted child has moved. P6 (box mode, 2 shown, 50 pans) shows `debugPaintOffsets` +100 and `debugAllocations` +0.

The alternatives are all worse:
- **`context.pushTransform` or `Flow`'s path:** these allocate a `Matrix4` plus a layer or handle per child.
- **A mutable `Offset` subclass:** this would break composition, because `OffsetLayer.offset`'s setter compares old and new values to decide `markNeedsAddToScene`. Mutating the value in place skips the re-add.
- **One shared group `OffsetLayer` with relative child offsets:** this only helps pure pans. Zoom changes relative positions, so it saves a 32-byte young-generation object per child at the cost of a rebase path.

This does not breach CLAUDE.md. That non-negotiable covers the engine's per-entity frame path, measured by `query_allocation_test` and `paint_allocation_test`, and both are untouched and green. P-4 itself budgets "O(overlays on screen) of paint". Each host widget's own layout and paint is the host's cost.

**Fix:**
- Reword P-4/H-8 (or the results note) to say that the camera pass allocates nothing per table, and that paint hands the framework one `Offset` per painted overlay that moved.
- Keep `debugPaintOffsets` separate from `debugAllocations`, as the implementer did. TO10's `≤ painted` bar is the right one, and O7 proves it bites.
- Document box mode's own floor in `FloorPlanOverlaySize.box`'s dartdoc: per shown overlay per frame, a `Size`, a `BoxConstraints`, and a relayout and repaint of the host's widget (P6: +100 child layouts over 50 frames with 2 shown).
- Add a box variant of TO10. P6 shows `debugAllocations` +0 there today.

### R-3 (Medium, test gap): nothing in the suite checks where children are *painted*; two paint mutants survive

Every position check uses `tester.getRect`, which reads `applyPaintTransform`. Two mutants survive the whole suite:
- **O1:** `paintChild(child, offset)`, which paints every overlay at the canvas's top left.
- **O2:** the cached paint offset is never refreshed, so overlays stay frozen at their first place.

For the user these are the visible defects. A third mutant, O7 (culled children painted), is caught only through the `debugPaintOffsets` counter.

**Fix:** land P1's shape. After a pan and zoom, for every child, check:
```dart
if (d.shown) {
  expect((child.debugLayer! as OffsetLayer).offset, Offset(d.dx, d.dy));
  expect(child.debugLayer!.parent, isNotNull);
} else {
  expect(child.debugLayer?.parent, isNull); // culled: not composited
}
```
P1 kills O1 (`Expected: Offset(348.7, 419.8)` / `Actual: Offset(0.0, 0.0)`), O2 and O7.

### R-4 (Low, test gap): the camera-listener removals are not pinned

- **O9:** removing `_camera.removeListener` from `detach` survives the suite. P7 kills it: with overlays in both modes, a mode switch followed by a pan makes the leaked listener call `markNeedsPaint` on a disposed render object (`Failed assertion … '!_debugDisposed'`).
- **O10:** removing the state's `removeListener` survives the suite and my probes. It is behaviour-neutral, because of the `mounted` guard. It is still a leak: each mode switch, reset, restore or load would leave one listener on the controller-lifetime camera, and that listener runs `overlayDetailLevel` on every frame.

**Fix:** land P7's shape. O10 can stay a known survivor, recorded as an equivalent-behaviour leak.

### R-5 (Low, test gap): semantics are correct but only pinned by accident

- **O5** (semantics visit culled children) is killed in the suite only by the framework's `'!childSemantics.renderObject._needsLayout'` assertion in TO11.
- **O6** (no `markNeedsSemanticsUpdate` on camera) is killed only by a `'!semantics.parentDataDirty'` assertion in TO13.

Neither result asserts the property itself. P2 and P9 do: the live semantics tree holds exactly the shown overlays (`Expected: <2>` / `Actual: <7>` under O6), its rect follows a pan (divided by the view's DPR), it is empty when every overlay is panned off, and it is empty below `hideBelowScale` (`Expected: <0>` / `Actual: <2>` under O5).

**Fix:** land P2 and P9, or their asserts.

### R-6 (Low, test gap): box-mode culling after a canvas resize with no camera change

**O14** (drop `size != _placedIn` from `performLayout`'s guard) survives both the suite and my probes. Natural mode re-places on every layout, so the guard only matters in box mode: widen the canvas and a box overlay that should appear stays culled until the camera moves. P5 covers the natural case and passes.

**Fix:** one box test with `setSurfaceSize` and an unchanged camera.

### R-7 (Low, spec wording, decisions d and natural culling)

I agree with natural children being laid out wherever they are. G-6's "neither laid out (`box`)" scopes that rule to box mode, and natural layout happens once.

I also agree with culling a natural widget by its own rectangle rather than by the table's box. Otherwise a badge larger than a far-zoomed table would pop out while it still overlaps the canvas. G-6, however, says "Overlays whose **box** is off the canvas are … not painted".

**Fix:** amend G-6: *"natural: culled when the widget's own rectangle misses the canvas"*.

### R-8 (Low, documentation for Task 5): overlays paint above the focus veil and the number chips

The Stack order is: underlay, drafting, `overlay` (zone veil, label chips), selection outline, `tableOverlays`. That follows G-5's "after the selection overlay". The consequences:
- With `setTableFocus` active, unfocused tables' badges are **not** faded by the veil. The host must use `FloorPlanTableOverlay.focused` itself.
- A centred badge covers the table's number chip.

**Fix:** state both in the host guide and the demo (Task 5). No code change.

### R-9 (Nit): the box cache is rebuilt at value rate, not "document or mode rate" (H-8)

`_recompute` allocates a new `corners` `Float64List` whenever any value changes, including a selection tap or a status. The setter then marks layout and every slot is re-measured. That is cheap, and it is not on the frame path. It is avoidable by reusing `_corners` when `nextInstances` and every `detail` are identical to the last ones.

## The implementer's open decisions (item 3)

| # | Decision | Recommendation |
|---|---|---|
| a | F-1: one `Offset` per painted, moved overlay per camera frame | **Accept.** It is the framework's floor and not a CLAUDE.md breach. Amend the spec wording (R-2). |
| b | `selected` by number; both `7`s read selected | **Accept.** It is the host's notion: `selectedTables` is numbers, and every callback names tables by number (invariant 5). P8 confirms that `select({'7'})` marks both. Add one sentence to `selected`'s dartdoc: "two tables sharing a number are both selected when it is". |
| c | Status computed in the design mode too | **Accept.** It is controller state the host set. Nothing is drawn or saved, and P-5 is intact. |
| d | Natural children laid out regardless of position | **Accept** (R-7): one layout, no relayout per frame. |
| e | Validation in `FloorPlanView.build` | **Accept.** A `const` constructor cannot loop. Note that in release a bad layout replaces the whole view with an `ErrorWidget`. That is a programmer error, and loud is right. The extra `hideBelowScale` and `maxNaturalSize` checks are sensible and documented. |

## Screen boxes (item 4)

- **Box.** `_measure` maps all four world corners through the camera's six coefficients and takes their min and max. That is the exact screen AABB of the rotated quad for any affine camera, including the y flip. TO7 checks it against the forward transform for 30°, mirrored 90° and (1.5, 0.8) at 0.2 px/mm and after a zoom. M-H10 (corners 0 and 2 only) is killed (`Expected … 111.96…` / `Actual: 171.96…`).
- **Off-base box.** The corners come from Task 1's `detail.corners`, the definition box (300..1100, −200..400) through the instance. TO1, TO7 and TO12 use the fixture's `embeddingBox`, not the base point.
- **Anchor.** `dx = minX + a·boxW − a·w`, with `a = (anchor.x + 1)/2`. That is `Align`'s `alignment.alongOffset(parent − child)` shifted by the box origin. TO12 uses (0.5, −1). O11 (axes swapped) is killed (`Expected … 455.39` / `Actual: 209.88`).

## Mutants

Each mutant was a single exact replacement applied by a script that copied the file aside, ran the tests, restored the file from the copy, and compared it byte for byte (`restored: True` every time; `git status` clean afterwards). No `git checkout`. Suite = `test/host/table_overlay_test.dart`; probes = `zz_review_probe_test.dart` in the probe clone.

### Named (8 of 8 killed)

| Mutant | Edit | Killer | Red line |
|---|---|---|---|
| M-H8 | `_onCamera`: also `_built.clear(); setState` on every camera change | TO1, TO2 (and 6 more) | TO1 `Expected: {'1': 1, … '7': 2}` / `Actual: {'1': 3, … '7': 6}`; TO2 `Expected: <7>` / `Actual: <21>` |
| M-H9 | `breakpoints[i] <= scale` → `<` | TO3 | `Expected: <2>` / `Actual: <1>` |
| M-H10 | `_measure` corner loop `k += 2` (corners 0, 2: unrotated box) | TO7, TO9, TO12 | `Expected: … within <0.000001> of <111.96152422706655>` / `Actual: <171.96152422706655>` |
| M-H11 | `IgnorePointer(ignoring: false, …)` | TO8 | `Expected: <0>` / `Actual: <1>` |
| M-H12 | box `performLayout`: `if (data.shown)` → `if (true)` | TO9 | `Expected: not … within <0.000001> of <355.2000000000007>` / `Actual: <355.2000000000007>` |
| M-H18 | `if (built == null \|\| built.value != value)` → `if (true)` | TO5, TO6, TO15, TO16 | `Expected: {'1': 2, '2': 1, …}` / `Actual: {'1': 2, '2': 2, …, '7': 4}` |
| M-H19 | `_onCamera` without `_measure(camera)` | TO1 (and 7 more) | `Expected: … of <373.55057958016914>` / `Actual: <648.9705908728556>` |
| M-H19b(design default) | `tableOverlayModes` default `{selection, design}` | TO13 | `Expected: no matching candidates` / `Actual: … Found 7 widgets with type "Badge"` |

### Own (21 run, O1 to O20 plus O16b)

The suite kills 14. Of its 7 survivors, the probes kill 3 (O1, O2, O9). The other 4 are: O3, which cannot be reached until Task 4; O10, a leak only; O14, a box-mode resize (R-6); and O16, which is equivalent. The probes also kill O5, O6 and O7 directly.

| Mutant | Edit | Suite | Probes | Red line / note |
|---|---|---|---|---|
| O1 | `paintChild(child, offset)` (offset ignored) | **survived** | killed P1 | `Expected: Offset(348.7, 419.8)` / `Actual: Offset(0.0, 0.0)` (R-3) |
| O2 | paint offset never refreshed (`if (data.offset == Offset.zero)`) | **survived** | killed P1 | R-3 |
| O3 | `hitTestChildren` offset `Offset.zero` | **survived** | — | unreachable behind `IgnorePointer` (F-5); Task 4's M-H17 territory |
| O4 | `applyPaintTransform` ignores `dx` | killed TO1 (+7) | — | `Expected: … of <373.55057958016914>` / `Actual: <0.0>` |
| O5 | semantics visit culled children | killed TO11 | killed P9 | suite: `'!childSemantics.renderObject._needsLayout'` assertion; P9 `Expected: <0>` / `Actual: <2>` (R-5) |
| O6 | no `markNeedsSemanticsUpdate` on camera | killed TO13 | killed P2 | suite: `'!semantics.parentDataDirty'` assertion; P2 `Expected: <2>` / `Actual: <7>` (R-5) |
| O7 | culled children painted (`if (child.hasSize)`) | killed TO10 | killed P1 | `Expected: a value less than or equal to <100>` / `Actual: <350>` |
| O8 | geometry-less tables kept (`d.center == null` dropped) | killed TO1 (+all) | — | `RangeError` building the layer; `Expected: exactly 7` / `Actual: 0` |
| O9 | render object keeps its camera listener after `detach` | **survived** | killed P7 | `'!_debugDisposed': is not true` in `markNeedsPaint` (R-4) |
| O10 | state keeps its camera listener after `dispose` | **survived** | survived | leak only; `mounted` guard (R-4) |
| O11 | anchor axes swapped | killed TO12 | — | `Expected: … of <455.38645946021734>` / `Actual: <209.87881982007275>` |
| O12 | modes ignored (`if (builder == null)`) | killed TO13 | — | `Found 7 widgets with type "Badge"` |
| O13 | `performLayout` guard drops `_stale` | killed TO16 | — | `Expected: … of <453.55057958016914>` / `Actual: <373.55057958016914>` (no move on drop) |
| O14 | `performLayout` guard drops `size != _placedIn` | **survived** | survived | box-mode resize (R-6) |
| O15 | detail rebuild only on upward crossings | killed TO3 | — | `Expected: <1>` / `Actual: <2>` |
| O16 | `_onCamera`: `!_natural \|\|` dropped | survived | — | **equivalent**: `_naturalLaidOut` is always false in box mode |
| O16b | `_onCamera`: box → paint only (`_natural && …`) | killed TO7, TO9 | — | `Expected: … of <310.5255888325755>` / `Actual: <192.8054648164525>` |
| O17 | natural relaid on every camera change | killed TO10 | — | `Expected: <28>` / `Actual: <378>` |
| O18 | builder identity change not detected | killed TO15 | — | `Expected: <7>` / `Actual: <0>` |
| O19 | table status over the group's | killed TO5 | — | `Expected: TableStatus(… blue …)` |
| O20 | right-edge culling removed (`true &&`) | killed TO9, TO10 | — | `Expected: false` / `Actual: <true>` |

## Gates (real tails, clean clone at `b420493`, `export PATH=/root/sdk/flutter/bin:$PATH CI=true`)

```
### packages/jet_cad_floor_plan :: flutter test
05:42 +1490: All tests passed!
test-exit 0
### packages/jet_cad_floor_plan :: flutter analyze
No issues found! (ran in 13.9s)
### packages/jet_cad_floor_plan :: format
Formatted 250 files (0 changed) in 1.36 seconds.
format-exit 0
### apps/restaurant_demo :: flutter test
00:28 +39: All tests passed!
test-exit 0
### apps/restaurant_demo :: flutter analyze
No issues found! (ran in 5.0s)
### apps/restaurant_demo :: format
Formatted 4 files (0 changed) in 0.06 seconds.
format-exit 0
### apps/floor_planner :: flutter test
02:10 +212: All tests passed!
test-exit 0
### apps/floor_planner :: flutter analyze
No issues found! (ran in 6.2s)
### apps/floor_planner :: format
Formatted 47 files (0 changed) in 0.21 seconds.
format-exit 0
### engine
engine test-exit 1
packages/jet_cad_2d: 1255 tests; the standing failures and skips, exactly
compare-exit 0
### render
render test-exit 1
packages/jet_cad_2d_flutter: 1363 tests; the standing failures and skips, exactly
compare-exit 0
```

The engine and render runs used `test --file-reporter json:<run.json>`, then `dart run tool/ci/expect_failures.dart --package <pkg> --root <pkg> <run.json>` from the repo root (the path form). `jet_cad_2d`, `jet_cad_2d_flutter`, both allocation invariants and the goldens are untouched by the diff. Among existing tests, only `barrel_test`'s pinned set changed, plus the appended B5, as the plan allows.

## Housekeeping note

My first gate script wrote `gates.sh`, `gates.log`, `e.json` and `r.json` at the top of the session scratchpad (`/tmp/claude-0/…/scratchpad/`), where files with those names from earlier tasks already were. Those earlier files are overwritten. Everything else of mine is under `scratchpad/rev3/`.

## Fixes (controller's)

**Commit:** `31db289` on `claude/exciting-pasteur-9m22jv` (parent `adaa2bc`), not pushed. Files: `lib/src/host/table_overlay.dart`, `lib/src/host/floor_plan_view.dart`, `test/host/table_overlay_test.dart`, the spec and the plan. No `analysis_options.yaml` touched.

**Existing tests:** only **TO15** (this task's own) was edited, because R-1 changes its premise: "a host rebuild with the same builder builds none" now reads "a host rebuild builds every overlay again, keeping its State" (calls 7 → 14, State identical, `Badge.created` still 7; later counts shift by 7). Every other test is unedited. New: TO19 to TO27.

**Mutants.** A runner (`scratchpad/fix3/mut.py`) copied the file aside, replaced exactly one occurrence, ran `flutter test --no-pub test/host/table_overlay_test.dart`, restored the file from the copy and compared it byte for byte: `restored: True` every time, and the file `cmp`-equal to a pristine copy afterwards. No `git checkout`. Red lines are copied from the logs.

### R-1 (ruled: follow the spec)

- **Change:** `_TableOverlayLayerState.didUpdateWidget` clears the build cache unconditionally, so every host rebuild of the view runs the builder for every overlay, a closure literal and a method tear-off alike. To keep internal triggers narrow, `FloorPlanView.build` now makes the two `TableOverlayLayer` widgets once per build of the view, outside the controller's `ListenableBuilder`; a controller notification hands down the identical widget, so it never reaches `didUpdateWidget` (today every such notification also swaps the keyed document, so this is defence, not a behaviour change). Pan and zoom still build nothing; statuses, selection and focus still rebuild only the affected tables (TO5, TO6, TO20).
- **Docs:** the typedef's, `FloorPlanView.tableOverlayBuilder`'s and `TableOverlayLayer`'s dartdoc; the plan's Task 3 "Builder calls" bullet; spec G-5 made explicit (tear-off named).
- **Tests:** TO19 (closure literal in a `StatefulBuilder`: one host `setState` → every table once more, State kept, a later pan and zoom build nothing); TO20 (method tear-off reading `prefix`: `a-1` → `b-1` after the host's `setState`; then `select({'2'})` rebuilds table 2 alone); TO15 updated.
- **Mutant** `_built.clear();` → `if (oldWidget.builder != widget.builder) _built.clear();` (the old rule): TO15 `Expected: <14>` / `Actual: <7>` / `a host rebuild: every table again`; TO20 `Expected: no matching candidates` / `Actual: _TextWidgetFinder:<Found 1 widget with text "a-1": [`.
- Hoisting the layer back into the listener's builder is an equivalent mutant today (no controller notification keeps the document), so no test pins it; recorded.

### R-2 (accepted)

- **Docs:** `FloorPlanOverlaySize.box` states its per-frame cost (per overlay on the canvas a `Size`, a `BoxConstraints`, a layout and paint of the host's widget; `natural`: one paint offset, no layout). `RenderFloorPlanOverlays` says why the paint `Offset` exists (`paintChild` takes one; the framework's floor) and that `debugPaintOffsets` stays apart from `debugAllocations`. Spec P-4 and H-8 reworded: "nothing per table in the painters; the overlay layer allocates nothing per table beyond one paint offset per overlay shown, measured"; G-6 carries box mode's cost.
- **Test TO21** (box variant of TO10): 50 pans and zooms, `debugAllocations` +0, `debugPaintOffsets` ≤ painted, `debugChildLayouts` delta == painted (one layout per shown overlay per frame), some culled, 7 builder calls.
- **Mutant** `if (_boxes.length < 4 * slots) {` → `if (true) {`: TO10 and TO21 `Expected: <4>` / `Actual: <54>` / `0 per table per camera change`.
- **M-H12** (box layout of every child) is now also killed by TO21: `Expected: <100>` / `Actual: <350>` / `box: one layout per shown overlay per frame, none else` (besides TO9's line).

### R-3

- **Test TO22** (P1's shape): three pan+zoom frames; each shown child's `OffsetLayer.offset == Offset(dx, dy)`, attached, `localToGlobal` agreeing within 1e-9; each culled child's layer detached; premise each frame shows some and culls some; finally table 1's composited offset equals the hand-computed `badgeWanted` within 1e-6.
- **O1** `paintChild(child, offset)`: TO22 `Expected: Offset:<Offset(348.7, 419.8)>` / `Actual: Offset:<Offset(0.0, 0.0)>` / `frame 0: painted at its place`.
- **O2** offset never refreshed: TO22 `Expected: Offset:<Offset(348.7, 419.8)>` / `Actual: Offset:<Offset(649.0, 106.8)>`.
- **O7** culled painted: TO10 and TO21 `Expected: a value less than or equal to <100>` / `Actual: <350>`; TO22 `Expected: null` / `Actual: OffsetLayer:<OffsetLayer#354d2(engine layer: OffsetEngineLayer#845c7, handles: 2, offset: Offset(0.0, 0.0))>`.

### R-4

- **Test TO23** (P7's shape): overlays in both modes; design, pan, selection, pan; `takeException()` null after each; one render object left.
- **O9** (no `removeListener` in `detach`): TO23 `Expected: null` / `Actual: _AssertionError:<'package:flutter/src/rendering/object.dart': Failed assertion: line 3339 pos 12: '!_debugDisposed': is not true.>` / `design`.
- **O10** stays a known survivor (behaviour-neutral leak behind the `mounted` guard), as the review allowed.

### R-5

- **Tests:** TO24 (P2: semantics nodes == shown children, culled ones absent; after a pan each node's rect / DPR equals its widget's rect within 1e-6; none when all are panned off); TO25 (P9: none below `hideBelowScale` after having been shown). The tree is read through `tester.binding.renderViews.single.owner!.semanticsOwner` (the `pipelineOwner` getter is deprecated).
- **O5** (semantics visit culled children): TO25 `Expected: empty` / `Actual: {'T1-0': Rect.fromLTRB(1120.7, 1292.9, 1240.7, 1352.9), 'T2-0': Rect.fromLTRB(3944.3, 1000.5, 4064.3, 1060.5)}` (and TO11's framework assertion as before).
- **O6** (no `markNeedsSemanticsUpdate` on camera): TO24 `Expected: <2>` / `Actual: <7>` / `the shown alone`; TO25 `Expected: empty` / `Actual: {'T1-0': …, 'T2-0': …}`.

### R-6

- **Test TO26:** box mode at `cameraAt(0.2)`; `setSurfaceSize(560, 900)` then back to 1440, the camera identical throughout (premise asserted); the shown flags of 1 to 4 equal "the hand-computed canvas box overlaps the layer" at each size; the narrow size culls one (premise); shown ones are at their boxes again.
- **O14** (guard without `size != _placedIn`): TO26 `Expected: {'1': true, '2': false, '3': false, '4': false}` / `Actual: {'1': true, '2': true, '3': true, '4': false}` / `narrower: culled`.

### R-7

Spec G-6's culling bullet amended: a `box` overlay off the canvas is neither laid out nor painted; a `natural` one is culled by the widget's own rectangle and laid out once wherever it is.

### R-8

`FloorPlanTableOverlay.focused`'s dartdoc: overlays paint above the focus veil and the number chips; the host fades with `focused`. The rest goes to Task 5's guide.

### R-9

- **Change:** `_recompute` reuses `_corners` when the instances are equal and every `detail` is `==` to the last (`_sameDetails`); the render object's `corners` setter then sees the identical list and marks nothing. Spec H-8's box cache rate says so.
- **Test TO27** (box mode, breakpoint 0.3): a real selection tap on table 1, a status on 2 and a detail crossing keep `layer.corners` identical and `debugChildLayouts` unchanged; a service drag of 80 px replaces it and table 1's box moves by 80.
- **Mutant** reuse removed (`if (true) {`): TO27 `Expected: true` / `Actual: <false>` / `a selection`.
- **Mutant** never replaced on geometry (`if (!sameInstances) {`): TO16 `Expected: a numeric value within <0.000001> of <453.55057958016914>` / `Actual: <373.55057958016914>` / `after the drop: left`; TO27 `Expected: false` / `Actual: <true>` / `a moved table: a new cache`.

### (b) to (e)

(b) `selected`'s dartdoc: "Two tables sharing a number are both selected when it is." (c) to (e) accepted as they are.

### From Task 2's review fixes (`adaa2bc`)

Spec G-3 amended: `ArgumentError` unless `1e-6 ≤ minScale < maxScale` (the constructor's floor, with its reason); the command rule: a `panBy`/`zoomBy` before a plan's first frame drops a pending request but does not cancel that plan's own fit, which overwrites it; `centerOn` places the camera beforehand. The spec's Review section lists these amendments.

### Gates (`/home/user/jet-cad`, the tree committed as `31db289`; `PATH=/root/sdk/flutter/bin:$PATH`, `CI=true`)

```
### packages/jet_cad_floor_plan :: flutter test
04:32 +1506: All tests passed!
test-exit 0
### packages/jet_cad_floor_plan :: flutter analyze
No issues found! (ran in 4.7s)
### apps/restaurant_demo :: flutter test
00:24 +39: All tests passed!
test-exit 0
### apps/restaurant_demo :: flutter analyze
No issues found! (ran in 3.9s)
### apps/floor_planner :: flutter test
01:34 +212: All tests passed!
test-exit 0
### apps/floor_planner :: flutter analyze
No issues found! (ran in 4.6s)
### dart format --output=none --set-exit-if-changed . (exit from PIPESTATUS)
Formatted 250 files (0 changed) in 1.31 seconds.
packages/jet_cad_floor_plan format-exit 0
Formatted 4 files (0 changed) in 0.07 seconds.
apps/restaurant_demo format-exit 0
Formatted 47 files (0 changed) in 0.21 seconds.
apps/floor_planner format-exit 0
```

The planner went from 1497 to 1506: nine new tests (TO19 to TO27). `jet_cad_2d` and `jet_cad_2d_flutter` are untouched by this commit, so the engine and render runs were not repeated.
