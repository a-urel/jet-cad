# Plan 02 (interaction-core) — mutation log

Method: for each mutant, the source file is copied aside, the one edit is
applied by hand, the named test file is run with `CI=true`, the result is
recorded, then the file is restored from the backup and `diff` confirms a
clean restore. Thirty named mutants (M-02a … M-02p, M-02r … M-02ac, with
M-02c′ and M-02e′); M-02c and M-02e are declared equivalent by construction.
There is no M-02q.

### M-02a — swap window/crossing predicates
file: packages/jet_cad_2d/lib/src/index/spatial_index.dart, `_leafPasses`: `if (mode == BandMode.window) {` → `if (mode == BandMode.crossing) {`
test: CI=true dart test test/index/band_query_test.dart
result: FIRED — `window keeps only the enclosed line; crossing adds the straddler` — `Expected: [18]` … `Actual: [18, 19]` — "the straddler leaves the band, so a window must not take it"; 13 failed, 2 passed
restored: diff clean

### M-02b — drop the instance transform in `_bandDescend`'s recursion
file: packages/jet_cad_2d/lib/src/index/spatial_index.dart, `_bandDescend`: `toWorld.multiply(index.transformOfInstance(node))` → `toWorld`
test: CI=true dart test test/index/band_query_test.dart
result: FIRED — `crossing and window agree with the brute-force arm on the generated corpus` — `Expected: Set:[443]` … `Actual: Set:[]` (BandMode.window trial 18); 14 passed, 1 failed. Note: this recursive `toWorld.multiply(...)` composes an instance transform only two-or-more levels deep (an instance nested inside another instance's definition); every hand-written fixture in this file places its instance directly under the root, so only the generated `groupCount`/nesting-depth-2 differential corpus exercises the mutated line — the single-level `placement` fixture (translate(300,-200)·rotate 30°·scale 1.5) that the spec's table names is composed at the *call site* in `forEachInstanceInBand`, not inside this recursion, and stays green under this mutation.
restored: diff clean

### M-02o — instance crossing tests the instance box instead of descending
file: packages/jet_cad_2d/lib/src/index/spatial_index.dart, `_bandDescend`: inserted, right after `localQuery` is computed, `if (mode == BandMode.crossing) { return localQuery.intersects(index.bounds) ? _BandVerdict.pass : _BandVerdict.fail; }` — models a broad-phase-only verdict that never descends to the real leaves
test: CI=true dart test test/index/band_query_test.dart
result: FIRED — `an L-shaped block is not crossed by a band in the empty quadrant of its box` — `Expected: empty` … `Actual: [400]` — "(7,7) is inside the block's bounding box and nowhere near either arm, which is exactly what descending past the box buys"
restored: diff clean

### M-02s — drop the dirty-overlay fallback from `_leafPasses`
file: packages/jet_cad_2d/lib/src/index/spatial_index.dart, `_leafPasses`: `index.boxOfLeaf(slot) ?? index.dirty.boxOf(slot)` → `index.boxOfLeaf(slot)`
test: CI=true dart test test/index/band_query_test.dart
result: FIRED — `the window band sees a leaf edited since the last rebuild` — `Expected: [18, 19]` … `Actual: [18]` — "the window must read the overlay, not the stale tree box"
restored: diff clean

### M-02t — drop `transformOfLeaf` from `_leafPasses`
file: packages/jet_cad_2d/lib/src/index/spatial_index.dart, `_leafPasses`: `_composeLeafTransform(toWorld, index.transformOfLeaf(slot));` → `_composeLeafTransform(toWorld, null);`
test: CI=true dart test test/index/band_query_test.dart
result: FIRED — `a grouped leaf inside a definition uses the group transform too` — `Expected: [400]` … `Actual: []` — "the group's translation must reach the narrow phase"
restored: diff clean

### M-02u — band walks report a fill slot
file: packages/jet_cad_2d/lib/src/index/spatial_index.dart, `forEachLeafInBand`: removed `if (document.entities.kindAt(slot) == EntityKind.fill) return;` from the `searchLeaves` visitor
test: CI=true dart test test/index/band_query_test.dart
result: FIRED — `a fill slot is never reported` — `Expected: [102]` … `Actual: [101, 102]` — "a fill is not pickable and is not band-selectable either; it follows its boundary"
restored: diff clean

### M-02z — drop the band walks' result sort
file: packages/jet_cad_2d/lib/src/index/spatial_index.dart, `forEachLeafInBand`: removed `_scratch.sortByHandle(document.entities);`
test: CI=true dart test test/index/band_query_test.dart
result: FIRED — `results are ascending by handle even when the tree order differs` — `Expected: [101, 102, 103, 104]` … `Actual: [104, 101, 102, 103]` — "and the straddler's stroke enters the band its box leaves"; the drop also cascades an earlier failure in `window keeps only the enclosed line; crossing adds the straddler` (`[18, 19]` vs `[19, 18]`)
restored: diff clean

### M-02c′ — `resolveHit` returns the leaf instead of `chain[0]`
file: packages/jet_cad_2d_flutter/lib/src/selection.dart, `resolveHit`: `if (hit.chainLength > 0) return SelectionKey.root(Handle(hit.chain[0]));` → `if (hit.chainLength > 0) return SelectionKey.root(hit.entity);`
test: CI=true flutter test test/selection_test.dart
result: FIRED — `two instances of one definition are two keys; two leaves of one instance are one` — `Expected: <Instance of 'InstanceNode'>` … `Actual: <null>`
restored: diff clean

### M-02k — `SelectionController` never subscribes to `changes`
file: packages/jet_cad_2d_flutter/lib/src/selection.dart, `SelectionController` constructor: `document.changes.listen(_onChange)` → `document.changes.listen((_) {})`
test: CI=true flutter test test/selection_test.dart
result: FIRED — `an external remove prunes; an unrelated add does not` — `Expected: <1>` … `Actual: <2>`
restored: diff clean

### M-02p — D2 resolves to the nearest group, not the topmost
file: packages/jet_cad_2d_flutter/lib/src/selection.dart, `topmostGroupOf`: `topmost = h;` → `topmost ??= h;`
test: CI=true flutter test test/selection_test.dart
result: FIRED — `a leaf owned by a nested group resolves to the outer group; a single-level group to itself` — `Expected: <18>` … `Actual: <19>` — "a leaf owned by a nested group selects the outermost group"
restored: diff clean

### M-02aa — `replace` notifies unconditionally
file: packages/jet_cad_2d_flutter/lib/src/selection.dart, `SelectionController.replace`: removed `if (setEquals(incoming, _keys)) return;`
test: CI=true flutter test test/selection_test.dart
result: FIRED — `replace with the same set does not notify` — `Expected: <1>` … `Actual: <2>` — "the second replace names the same set"
restored: diff clean

### M-02d — `kPickRadiusPixels` ×10
file: packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart: `const double kPickRadiusPixels = 6.0;` → `const double kPickRadiusPixels = 60.0;`
test: CI=true flutter test test/select_tool_test.dart
result: FIRED — `the pick radius is six screen pixels` — `Expected: true` … `Actual: <false>` (`select_tool_test.dart`'s `ev` helper imports and reads `kPickRadiusPixels` directly, so the ×10 is visible to the fixture itself); three further tests in the same file also went red (`a group is window-selected only when every leaf is enclosed`, `left-to-right encloses, right-to-left touches`, `shift-band toggles`) since the same radius feeds their pick geometry
restored: diff clean

### M-02l — `pickRadiusWorld` not divided by `camera.scale`
file: packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart, `_wrap`: `pickRadiusWorld: kPickRadiusPixels / cam.scale,` → `pickRadiusWorld: kPickRadiusPixels,`
test: CI=true flutter test test/interaction_layer_test.dart
result: FIRED — `the pick radius is converted by the camera scale` — `Expected: <1>` … `Actual: <0>` — "a world-space radius of 6 would miss at 20 world units out" (the scale-0.25 arm of the fixture; per the spec's note, the test's scale-4 arm is not discriminating — at scale 4 the mutated 6-world-unit radius still reaches targets a 1.5-world-unit correct radius would also reach, at the fixture's distances — and is not what kills this mutant)
restored: diff clean

### M-02y — `onPointerCancel` not wired to `cancel`
file: packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart, `build`: removed `onPointerCancel: _onCancel,` from the `Listener`
test: CI=true flutter test test/interaction_layer_test.dart
result: FIRED — `a pointer cancel ends the band` — `Expected: ToolPhase:<ToolPhase.idle>` … `Actual: ToolPhase:<ToolPhase.dragging>`
restored: diff clean

### M-02f — `kBandSlopPixels` → 0
file: packages/jet_cad_2d_flutter/lib/src/select_tool.dart: `const double kBandSlopPixels = 4.0;` → `const double kBandSlopPixels = 0.0;`
test: CI=true flutter test test/select_tool_test.dart
result: FIRED — `a 2 px move keeps the press a click` — `Expected: ToolPhase:<ToolPhase.pressed>` … `Actual: ToolPhase:<ToolPhase.dragging>`. Per the spec's note, the kill is this `phase == pressed` assertion taken *before* the release — the post-release selection this test also checks is not discriminating, because `replace(∅)` and `clear()` read the same on an empty selection.
restored: diff clean

### M-02h — shift toggle replaced by replace
file: packages/jet_cad_2d_flutter/lib/src/select_tool.dart, `onPointerUp` (pressed branch): `e.shift ? ctx.selection.toggle([key]) : ctx.selection.replace([key]);` → `ctx.selection.replace([key]);`
test: CI=true flutter test test/select_tool_test.dart
result: FIRED — `click replaces, shift-click toggles` — `Expected: <2>` … `Actual: <1>`
restored: diff clean

### M-02r — group window rule reads "any" instead of "every"
file: packages/jet_cad_2d_flutter/lib/src/select_tool.dart, `_everyLeafIn`: `if (!passing.contains(slot)) return false;` → `if (passing.contains(slot)) return true;`
test: CI=true flutter test test/select_tool_test.dart
result: FIRED — `a group is window-selected only when every leaf is enclosed` — `Expected: true` … `Actual: <false>` (i.e. `selection.isEmpty` came back false) — "the group is missing a leaf and the straddler is not fully enclosed, so window takes neither"
restored: diff clean

### M-02j — group delete skips the owned leaves
file: packages/jet_cad_2d_flutter/lib/src/select_tool.dart, `_groupCascade`: removed the `for (final slot in leaves) { ... out.add(RemoveEntityCommand(h)); }` loop that appends each non-skipped leaf's remove command
test: CI=true flutter test test/select_tool_test.dart
result: FIRED — `Delete cascades a group: leaves, child instance, nested group, then the group` — `Expected: null` … `Actual: <0>` (a leaf's slot is still present after Delete); a second test in the same file also went red (`a region inside a group is deleted once: the boundary's command takes the fill`)
restored: diff clean

### M-02n — permission preflight dropped from Delete
file: packages/jet_cad_2d_flutter/lib/src/select_tool.dart, `_deleteSelection`: removed `if (!list.every((c) => permissions.allows(c.capability))) continue;`
test: CI=true flutter test test/select_tool_test.dart
result: FIRED — `a read-only document is selectable and Delete is a no-op` — `Expected: return normally` … `Actual: <Closure: () => KeyEventResult>` which threw `PermissionDeniedError: "Remove entity" needs geometry`; a second test in the same file also went red (`a refused object stays selected, a permitted one goes`, uncaught `PermissionDeniedError: "Remove node" needs structure`)
restored: diff clean

### M-02x — the `KeyDownEvent` gate removed
file: packages/jet_cad_2d_flutter/lib/src/select_tool.dart, `onKey`: removed `if (event is! KeyDownEvent) return KeyEventResult.ignored;`
test: CI=true flutter test test/select_tool_test.dart
result: FIRED — `a KeyUpEvent and a KeyRepeatEvent do nothing` — `Expected: KeyEventResult:<KeyEventResult.ignored>` … `Actual: KeyEventResult:<KeyEventResult.handled>`
test: CI=true flutter test test/interaction_layer_test.dart
result: SURVIVED (on this file) — `one Delete press is one remove` stayed green. That fixture selects one key, sends a KeyDownEvent then a KeyUpEvent; the down event's own `_deleteSelection` already empties the selection and calls `ctx.selection.remove([key])`, so the mutated up event's second `_deleteSelection` walks an empty `ctx.selection.keys` and is a no-op — the fixture's single-selection shape does not distinguish "gate present" from "gate absent". `select_tool_test.dart`'s dedicated `KeyUpEvent`/`KeyRepeatEvent` test is what the spec's table names as the kill, and it does fire above.
restored: diff clean

### M-02g — band direction test inverted (`>=` → `<`)
file: packages/jet_cad_2d_flutter/lib/src/select_tool.dart, `onPointerMove` (both the pressed→dragging transition and the dragging branch): `_end.dx >= _start.dx ? BandMode.window : BandMode.crossing;` → `_end.dx < _start.dx ? BandMode.window : BandMode.crossing;`
test: CI=true flutter test test/interaction_layer_test.dart
result: FIRED — `drag direction selects the mode; a vertical drag is a window` — `Expected: BandMode:<BandMode.window>` … `Actual: BandMode:<BandMode.crossing>` — the purely vertical drag (`dx == 0`) is the one input the `>=`/`<` spellings disagree on
test: CI=true flutter test test/select_tool_test.dart
result: FIRED — `left-to-right encloses, right-to-left touches` — `Expected: BandMode:<BandMode.window>` … `Actual: BandMode:<BandMode.crossing>`; `a group is window-selected only when every leaf is enclosed` and `shift-band toggles` also went red in the same file
restored: diff clean

### M-02i — `onPointerExit` does not clear hover
file: packages/jet_cad_2d_flutter/lib/src/select_tool.dart, `onPointerExit`: removed `ctx.selection.setHover(null);` (the concrete hover-clearing call `InteractionLayer._onExit` reaches through `Tool.onPointerExit`)
test: CI=true flutter test test/interaction_layer_test.dart
result: FIRED — `exiting the layer clears hover` — `Expected: null` … `Actual: SelectionKey:<SelectionKey( 12)>`
restored: diff clean

### M-02v — outline path built at absolute world coordinates
file: packages/jet_cad_2d_flutter/lib/src/outline_cache.dart, `_rebuildPaths`: `final ox = _origin.x, oy = _origin.y;` → `final ox = 0.0, oy = 0.0;` (drops the `- origin` subtraction throughout the path builder without touching each call site)
test: CI=true flutter test test/outline_cache_test.dart
result: FIRED — `the path is built in rebased space` — `Expected: a numeric value within <0.000001> of <42.0>` … `Actual: <4500010.0>`; `a circle under a non-uniform instance scale is emitted with the geometric-mean radius` and `a mirrored arc flips its sweep and takes its start from the transformed start point` also went red in the same file
test: CI=true flutter test test/selection_overlay_test.dart
result: FIRED — `the outline coincides with the drawn line at 4.5e6` — `Expected: a numeric value within <0.01> of <150.0>` … `Actual: <4500118.13>`; `the outline coincides under a rotated, non-uniform camera` also went red in the same file
restored: diff clean

### M-02w — cache not rebuilt on a `DocChange`
file: packages/jet_cad_2d_flutter/lib/src/outline_cache.dart, `_onChange`: removed `_walk(_world.keys.toList());`
test: CI=true flutter test test/outline_cache_test.dart
result: FIRED — `a DocChange inside a selected instance rebuilds the outline` — `Expected: a numeric value within <1e-9> of <281.69134295108995>` … `Actual: <308.69134295108995>`
restored: diff clean

### M-02e′ — overlay built with `repaint: null`
file: packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart, `SelectionOverlayPainter` constructor: `super.repaint,` → `Object? repaint,` (accepted but never forwarded, so the implicit `super()` call always passes `repaint: null` to `CustomPainter`)
test: CI=true flutter test test/selection_overlay_test.dart
result: FIRED — `a selection change repaints the overlay and not the canvas` — `Expected: <2>` … `Actual: <1>` — "the selection is in the overlay's repaint merge"
restored: diff clean

### M-02m — overlay stroke width not divided by scale
file: packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart, `paint`: `_selected.strokeWidth = kSelectionStrokePixels / scale;` → `_selected.strokeWidth = kSelectionStrokePixels;`
test: CI=true flutter test test/selection_overlay_test.dart
result: FIRED — `stroke width is 2 px at any zoom` — `Expected: a numeric value within <1e-12> of <0.5>` … `Actual: <2.0>`
restored: diff clean

### M-02ab — a fresh `Paint` per `drawPath` in the overlay
file: packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart, `paint`: the two `canvas.drawPath(path, _selected)` / `canvas.drawPath(path, _hover)` calls in the world-space pass replaced with `canvas.drawPath(path, Paint()..color = _selected.color..style = _selected.style..strokeWidth = _selected.strokeWidth)` (and the `_hover` equivalent) — a new `Paint` object built from the field's current values on every call
test: CI=true flutter test test/selection_overlay_test.dart
result: FIRED — `the two Paints are reused across frames` — `Expected: true` … `Actual: <false>` — "the selected paint is a field, not a per-frame allocation"
restored: diff clean

### M-02ac — the hover-skip removed
file: packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart, `paint`: `hover != null && !selection.contains(hover) ? hover : null;` → `hover;`
test: CI=true flutter test test/selection_overlay_test.dart
result: FIRED — `hover on a selected key draws once` — `Expected: an object with length of <1>` … `Actual: WhereIterable<RecordedCall>:[...]` (length 2)
restored: diff clean

### M-02c — key equality compares bare handles, not chains
EQUIVALENT under D2 — every chain is empty; logged (no code edit made). Reason (spec's): `SelectionKey`'s chain is always empty under this task's D2 (task 02 never produces a non-root key with a populated chain), so a mutation that compared only the bare `target` handle instead of `(chain, target)` would answer identically to the real `==` on every reachable `SelectionKey` — there is no input this task's scope can construct that would distinguish the two implementations.

### M-02e — overlay `shouldRepaint` false unconditionally
EQUIVALENT under D9 — logged (no code edit made). Reason (spec's): `SelectionOverlayPainter.shouldRepaint` is specified to always return `false` — every reason to repaint already lives in the `repaint` listenable (`Listenable.merge([selection, tools, camera])`) that `RenderCustomPaint` re-attaches on every rebuild regardless of what `shouldRepaint` answers, so a mutant that hard-codes `false` (which is exactly the current, correct body) is not a mutant at all — there is no alternate boolean expression whose behavior could differ from the specified constant under this contract.

## Tally

- Fired: 28 (M-02a, M-02b, M-02o, M-02s, M-02t, M-02u, M-02z, M-02c′, M-02k, M-02p, M-02aa, M-02d, M-02l, M-02y, M-02f, M-02h, M-02r, M-02j, M-02n, M-02x, M-02g, M-02i, M-02v, M-02w, M-02e′, M-02m, M-02ab, M-02ac)
- Killed: 28 (all of the above went red in at least the test file the method requires)
- Survived: 0 (M-02x's `interaction_layer_test.dart` run alone did not go red — see its entry — but the mutant is killed by `select_tool_test.dart`, so it is not logged as a surviving mutant)
- Equivalent: 2 (M-02c, M-02e)

28 fired, 28 killed, 0 survived, 2 equivalent.

## Allocation gates

```
$ cd packages/jet_cad_2d && CI=true dart test test/invariants/query_allocation_test.dart
00:00 +0: loading test/invariants/query_allocation_test.dart
00:00 +0: (setUpAll)
00:00 +0: forEachInRect does not allocate in steady state
00:01 +1: forEachInstanceInRect does not allocate in steady state
00:01 +2: pickInto does not allocate in steady state, three instances deep
00:02 +3: snapInto does not allocate in steady state, three instances deep
00:02 +4: pickInto stays local: an over-wide broad phase would blow the time budget
00:02 +5: (tearDownAll)
00:02 +5: All tests passed!
```

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/invariants/paint_allocation_test.dart
00:00 +0: loading .../test/invariants/paint_allocation_test.dart
00:00 +0: a steady-state frame allocates O(1) per flush, not O(entities)
00:00 +1: flush hands drawVertices the same Paint object every time, not a call-site-local one
00:00 +2: load-time triangulation cost, recorded
LOAD fills=5000 elapsed=62ms
00:00 +3: All tests passed!
```

Both allocation gates are green.

## Diff and grep

```
$ git diff --stat main..HEAD -- apps/dev_harness_2d packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart packages/jet_cad_2d_flutter/lib/src/draft_painter.dart packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
(empty)
```

```
$ grep -rn "kIsWeb\|dart:ui_web" packages/jet_cad_2d_flutter/lib/src/selection.dart packages/jet_cad_2d_flutter/lib/src/selection_style.dart packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart packages/jet_cad_2d_flutter/lib/src/tool.dart packages/jet_cad_2d_flutter/lib/src/select_tool.dart packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart packages/jet_cad_2d_flutter/lib/src/outline_cache.dart
(no output — no matches)
```

Both checks pass: this plan's diff touches none of the naming/render-layer files listed for task 01, and none of task 02's own files reference `kIsWeb` or `dart:ui_web`.
