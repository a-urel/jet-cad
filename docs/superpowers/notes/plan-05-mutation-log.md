# Plan 05 mutation log — M-05a..z

27 fired: 26 killed, 1 survived, 0 equivalent.

Procedure, per mutant: `cp` the target file to
`.superpowers/sdd/2026-09-23-drawing-tools/mutation-backups/<basename>.<id>`,
apply the one edit by hand, run only the named test file(s) with `CI=true`,
paste the failing test names and the summary line, restore with `cp` from the
backup, then `diff <backup> <file>` and confirm it prints nothing. Every
restore below was verified empty; none is repeated per mutant to keep this
log readable, but every single one was run and was empty at the time.

---

### M-05a — a point resolved from the screen, not the world

- **file:** `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart`,
  `onPointerDown`
- **edit:** `_resolve(ctx, e.world, e.shift)` → `_resolve(ctx,
  Vector2(e.screen.dx, e.screen.dy), e.shift)`
- **test:** `packages/jet_cad_2d_flutter/test/draw/placement_tool_test.dart`
- **result:** KILLED -- `flipY true B1`, `flipY false B1` (target), plus
  collateral `flipY true/false B2`, `B6`; summary `+7 -5`. B1 expected
  `[7010.5, 3020.25, 7090.75, 3070.5]`, got screen pixels
  `[253.1…, 94.4…, 317.1…, 176.6…]` instead of world coordinates.

### M-05b — a rectangle's closing pair dropped

- **file:** `packages/jet_cad_2d/lib/src/document/drafting.dart`,
  `rectanglePayload`
- **edit:** dropped the last pair `c1.x, c1.y` from the coordinate list
- **test:** `packages/jet_cad_2d/test/document/drafting_test.dart`
- **result:** KILLED -- `E5` (target: expected 10 coordinates, got 8, "shorter
  than expected"), plus collateral `E9` (a null-check on the now-short
  triangulation input). Summary `+8 -2`.

### M-05c — text height not cap height

- **file:** `packages/jet_cad_2d/lib/src/document/drafting.dart`,
  `textPayload` (imported `text_metrics.dart` for `kCapHeightRatio`)
- **edit:** `[heightMm, 0, 1, 0]` → `[heightMm * kCapHeightRatio, 0, 1, 0]`
- **test:** `packages/jet_cad_2d/test/document/drafting_test.dart`
- **result:** KILLED -- `E7` (target); expected `[50.0, 0.0, 1.0, 0.0]`, got
  `[35.0, 0.0, 1.0, 0.0]` (50 × 0.7). Summary `+9 -1`.

### M-05d — a handle derived from live count instead of the seed

- **file:** `packages/jet_cad_2d/lib/src/document/drafting.dart`,
  `addDrafted`
- **edit:** `doc.handleSeed.next()` →
  `Handle(doc.entities.liveCount + ReservedHandles.firstFree.value)`.
  **Deviation from the brief's literal text:** `ReservedHandles.firstFree`
  is a `Handle` (an extension type over `int`, not implicitly convertible to
  `int`), so `liveCount + ReservedHandles.firstFree` does not type-check.
  Used `ReservedHandles.firstFree.value` to keep the mutant's intent
  (handles derived from population, not from the monotonic seed) while
  compiling.
- **test:** `packages/jet_cad_2d/test/document/drafting_test.dart`
- **result:** KILLED -- `E3` (target: expected a handle greater than the
  first, "handles are never reissued", got the same value 16 both times),
  plus collateral `E2` (expected 18, got 16) and `E4`
  (`DuplicateHandleError(11)` on redo). Summary `+7 -3`.

### M-05e — an arc's start and sweep swapped/negated

- **file:** `packages/jet_cad_2d_flutter/lib/src/draw/arc_tool.dart`,
  `accept`
- **edit:** `arcPayload(points.first, _r, _tracker.start, sweep)` →
  `arcPayload(points.first, _r, _tracker.start + sweep, -sweep)`
- **test:** `packages/jet_cad_2d_flutter/test/draw/arc_tool_test.dart`
- **result:** KILLED -- `AR1` flipY true/false (target: expected start
  `0.3`, got `2.2`), plus collateral `AR2`, `AR3`, `AR4`. Summary `+2 -5`.

### M-05f — an unwrapped angle step

- **file:** `packages/jet_cad_2d/lib/src/document/drafting.dart`,
  `SweepTracker.track`
- **edit:** `_travel += wrapAngle(angle - _previous);` → `_travel += angle -
  _previous;`
- **test:** `packages/jet_cad_2d/test/document/sweep_tracker_test.dart`
- **result:** KILLED -- `S4` (target: expected travel `> 0`, got
  `-5.6999999999999993`, the raw −6.2ish jump across the seam never
  wrapped), plus the differential test (`expected 1.0, got -1.0` at trial
  0). Summary `+5 -2`.

### M-05g — the CW/CCW tie-break dropped

- **file:** `packages/jet_cad_2d/lib/src/document/drafting.dart`, `sweepTo`
- **edit:** `return _travel >= 0 ? delta : delta - _tau;` → `return delta;`
- **test:** `packages/jet_cad_2d/test/document/sweep_tracker_test.dart`
- **result:** KILLED -- `S3` (target: expected ≈ −1.2, got `5.0831…`, the
  un-negated `delta`), plus the differential test. Summary `+5 -2`.

### M-05h — shift's ortho base is the first vertex, not the last

- **file:** `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart`,
  `orthoBase`
- **edit:** `points.isEmpty ? null : points.last` → `points.isEmpty ? null :
  points.first`
- **test:** `packages/jet_cad_2d_flutter/test/draw/polyline_tool_test.dart`
- **result:** KILLED -- `PL6` (target); expected `y` pinned to the second
  vertex (`3090.75`), got `3020.25` (the first). Summary `+7 -1`.

### M-05i — closing on a raw copy of the click, not the stored vertex

- **file:** `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart`,
  `onPointerDown`
- **edit:** `accept(self ?? Vector2.copy(_hover.point), ctx);` →
  `accept(self != null ? Vector2.copy(e.world) : Vector2.copy(_hover.point),
  ctx);`
- **test:** `packages/jet_cad_2d_flutter/test/draw/polyline_tool_test.dart`
- **result:** KILLED -- `PL3` flipY true/false (target: expected point count
  4, got 3 — the polyline never registers as closed because the appended
  point is a fresh copy of the raw click, not `identical` to
  `points.first`), plus collateral `PL4`, `PL5`, `PL7`, `PL8`. Summary
  `+2 -6`.

### M-05j — text height ignores the page scale

- **file:** `packages/jet_cad_2d/lib/src/document/drafting.dart`,
  `textHeightMm`
- **edit:** `page.scaleDenominator` → `50`
- **test:** `packages/jet_cad_2d/test/document/drafting_test.dart`
- **result:** KILLED -- `E8` (target); expected `50.0`, got `125.0` (2.5 ×
  50). Summary `+8 -1`.

### M-05k — the chain's next start re-derived through a screen round trip

- **file:** `packages/jet_cad_2d_flutter/lib/src/draw/line_tool.dart`,
  `accept`
- **edit:** `..add(point)` (after a commit) → `..add(ctx.camera.value
  .screenToWorld(ctx.camera.value.worldToScreen(point)))`
- **test:** `packages/jet_cad_2d_flutter/test/draw/line_tool_test.dart` (L1)
- **result:** KILLED -- `L1` flipY true and flipY false (target). Per Ruling
  05-5, the actual round-trip bits, the first line's end next to the second
  line's start (the assertion is `second.coords[0] == first.coords[2]`,
  line 45):
  - flipY **true**: `first.coords[2]` (exact, unaffected by the mutant) =
    `7137.3`; `second.coords[0]` (round-tripped) = `7137.299999999998`.
  - flipY **false**: `first.coords[2]` = `7137.3`; `second.coords[0]` =
    `7137.299999999999`.

  Both round trips move the low bit away from the exact anchor value, so
  the kill is a genuine bit-level divergence, not luck. Summary `+0 -2`.

### M-05l — Escape also finishes the shape before cancelling it

- **file:** `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart`,
  `onKey`
- **edit:** Escape's `cancel(ctx);` → `finish(ctx); cancel(ctx);`
- **test:** `packages/jet_cad_2d_flutter/test/draw/polyline_tool_test.dart`
  (PL9)
- **result:** KILLED -- `PL9` (target); the byte-identical snapshot check
  fails: the "before" snapshot has one entity (the anchor line, handle 18),
  the "after" gains a second entity (handle 19, an open polyline from the
  three vertices `finish` committed before `cancel` cleared them). Summary
  `+10 -1`.

### M-05m — Escape handled even when idle

- **file:** `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart`,
  `onKey`
- **edit:** inserted `if (key == LogicalKeyboardKey.escape) return
  KeyEventResult.handled;` before the existing `if (event is KeyUpEvent ||
  !isPending) return KeyEventResult.ignored;`
- **test:** `packages/jet_cad_2d_flutter/test/draw/placement_tool_test.dart`
  (B4) and `apps/floor_planner/test/planner_draw_test.dart` (A4)
- **result:** KILLED in both named files.
  - `placement_tool_test.dart` B4 (target): expected `false` (idle Escape
    ignored), got `true`. Summary `+11 -1`.
  - `planner_draw_test.dart` A4 (target): expected `'Select'`, got
    `'Line'` — an idle Escape no longer bubbles to the shell, so the tool
    never switches back to Select. Summary `+14 -1`.

### M-05n — the field positioned from the placement point, not the camera

- **file:** `apps/floor_planner/lib/text_entry_overlay.dart`, the camera
  builder
- **edit:** `left: s.x, top: s.y - kTextEntrySize.height` → `left:
  placed.point.x, top: placed.point.y - kTextEntrySize.height` (dropped the
  now-unused `final s = widget.camera.value.worldToScreen(placed.point);`).
  **Adapted from the brief:** the brief's mutant text names a `Positioned`
  built from `s.x`/`s.y` inside a camera-driven builder; that shape still
  exists in the current code (a `ListenableBuilder` over `widget.camera`
  inside a `Stack`, even though `planner_view.dart`'s root changed from a
  `Stack` to a `Flow` around it in Task 7 — that change is one layer up and
  does not touch this widget's own structure), so the edit applies as
  written, just substituting the placement's raw world point for the
  camera-projected screen point.
- **test:** `apps/floor_planner/test/planner_draw_test.dart` (A7)
- **result:** KILLED -- `A7` (target); expected the field's bottom-left to
  track the camera's projection of the placement point within 0.5 px after
  a pan, got a distance of `7258.203835522024` (the field stayed pinned to
  the raw world coordinates while the camera moved). Summary `+6 -1`.

### M-05o — a rectangle never fillable

- **file:** `packages/jet_cad_2d_flutter/lib/src/draw/rectangle_tool.dart`,
  `accept`
- **edit:** `fillable: true` → `fillable: false`
- **test:** `packages/jet_cad_2d_flutter/test/draw/rectangle_tool_test.dart`
  (R3)
- **result:** KILLED -- `R3` (target: `List.single` throws "Bad state: No
  element" because no fill entity exists), plus collateral `R5`. Summary
  `+4 -2`.

### M-05p — a region committed as two separate commands

- **file:** `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart`,
  `commitShape` (added `import 'dart:typed_data' show Float64List;`)
- **edit:** Ruling 05-15's concrete form: instead of `return region;`, the
  boundary is executed inline and the fill is returned as the one command
  `commit` itself executes:
  ```dart
  if (region != null) {
    ctx.execute(AddEntityCommand(
        record: region.boundary, payload: region.boundaryPayload));
    return AddEntityCommand(
        record: region.fill,
        payload: GeometryPayload(
            coords: Float64List(0),
            scalars: Float64List.fromList(
                [region.boundary.handle.value.toDouble()])));
  }
  ```
- **test:** `packages/jet_cad_2d_flutter/test/draw/rectangle_tool_test.dart`
  (R3) and `packages/jet_cad_2d_flutter/test/draw/polyline_tool_test.dart`
  (PL4)
- **result:** KILLED in both.
  - `rectangle_tool_test.dart` R3: expected `undoDepth == 1`, got `2` — the
    "two commands" bug lands exactly as Ruling 05-15 predicts. Summary
    `+3 -1`.
  - `polyline_tool_test.dart` PL4: expected `undoDepth == 1`, got `2`.
    Summary `+10 -2`.

### M-05q — the empty-triangulation refusal for a polyline removed

- **file:** `packages/jet_cad_2d/lib/src/document/drafting.dart`,
  `addDraftedRegion`
- **edit:** deleted `if (boundaryKind == EntityKind.polyline &&
  triangles.isEmpty) return null;`
- **test:** `packages/jet_cad_2d/test/document/drafting_test.dart` (E9) and
  `packages/jet_cad_2d_flutter/test/draw/polyline_tool_test.dart` (PL5)
- **result:** KILLED in both.
  - `drafting_test.dart` E9: expected `null` for the bow-tie polyline, got
    an `AddRegionCommand` instance. Summary `+9 -1`.
  - `polyline_tool_test.dart` PL5: expected the fill list empty, got `[19]`
    — the bow tie now commits a (degenerate) fill. Summary `+6 -1`.

### M-05r — furniture drawn before the finishes

- **file:** `apps/floor_planner/lib/startup_plan.dart`
- **edit:** moved the entire furniture block (`p.rectRegion` ×3,
  `p.polygonRegion`, another `p.rectRegion`, `p.circleRegion` ×2) from
  after the floor-finishes block to immediately after the windows block,
  before the finishes.
- **test:** `apps/floor_planner/test/startup_plan_test.dart` (SP2)
- **result:** KILLED -- `SP2` (target); expected the lowest fill handle to
  be greater than the highest floor-finish line's handle (`> 526`), got
  `88` — the fills now draw *under* the tile and parquet lines instead of
  over them. Summary `+6 -1`.

### M-05s — the polyline preview drawn as segments, not one path

- **file:** `packages/jet_cad_2d_flutter/lib/src/draw/polyline_tool.dart`,
  `paintRubberBand` (added `Offset` to the `dart:ui` import)
- **edit:** replaced the `band.reset()`/`moveTo`/`lineTo` sequence plus one
  `canvas.drawPath(band, bandPaint)` with one `canvas.drawLine(...,
  bandPaint)` per segment and one more to the hover point.
- **test:** `packages/jet_cad_2d_flutter/test/draw/draw_overlay_test.dart`
  (OV1)
- **result:** KILLED -- `OV1` (target); expected one `drawPath` call in the
  preview colour, got zero (`WhereIterable<RecordedCall>:[]`). Summary
  `+1 -1`.

### M-05t — a text entity gets override bits it should not have

- **file:** `packages/jet_cad_2d/lib/src/document/drafting.dart`,
  `draftRecord` (imported `text_geometry.dart` for `packTextAttrs`)
- **edit:** `textAttrs: 0` → `textAttrs: packTextAttrs(overrideWidthFactor:
  true, overrideOblique: true)`
- **test:** `packages/jet_cad_2d/test/document/drafting_test.dart` (E1, E7)
- **result:** KILLED in both named tests.
  - E1: expected `textAttrs == 0` ("left, baseline, no override bits"), got
    `768`.
  - E7: expected the resolved width factor `0.8` (inherited from the
    style, since no override bit should be set), got `1.0` (the payload's
    padding value, now wrongly read as a real override). Summary `+8 -2`.

### M-05u — the field rebuilt per camera change instead of held stable

- **file:** `apps/floor_planner/lib/text_entry_overlay.dart`
- **edit:** moved the `field` construction inside the `ListenableBuilder`'s
  `builder` callback (dropping the stable `child:` parameter), and keyed
  the `SizedBox` with `ValueKey(widget.camera.value.worldToScreenMatrix.e)`
  instead of `const Key('text-entry-box')`.
- **test:** `apps/floor_planner/test/planner_draw_test.dart` (A7)
- **result:** KILLED -- `A7` (target), but via a different assertion than
  Ruling 05-10's identity check: the test's `corner()` helper calls
  `tester.getBottomLeft(find.byKey(const Key('text-entry-box')))`, and
  since the mutant replaces that literal key with a `ValueKey` derived from
  the camera matrix, the finder throws "Found 0 widgets with key
  [<'text-entry-box'>]" before the test ever reaches the
  `identical(EditableTextState...)` line further down. This is a genuine
  consequence of the exact edit named in the brief (the concrete key
  replacement it specifies removes the literal key the test looks up by),
  so it is logged as a straightforward kill rather than adapted further.
  Summary `+6 -1`.

### M-05v — the shell shortcut guard removed from the field

- **file:** `apps/floor_planner/lib/text_entry_overlay.dart`
- **edit:** removed the `ShellShortcutGuard` wrapper around the
  `CallbackShortcuts`/`TextField` subtree (and its now-unused `import
  'shortcut_guard.dart';`)
- **test:** `apps/floor_planner/test/planner_draw_test.dart` (A8)
- **result:** KILLED -- `A8` (target); expected `press(tester,
  LogicalKeyboardKey.keyL)` to return `false` ("reaches the platform as
  text", Ruling 05-9), got `true` — without the guard, the shell's
  `CallbackShortcuts` consumes the key and switches tools out of Text.
  Summary `+7 -1`.

### M-05w — self-snap consulted only after 03's resolve, and only when nothing else snapped

- **file:** `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart`,
  `_resolve`
- **edit:** run `resolveDragPoint` first (unconditionally), then consult
  `selfSnap(raw, aperture)` only when `_hover.objectKind == null &&
  !_hover.grid`, i.e. only when 03's own snap chain found nothing:
  ```dart
  Vector2? _resolve(ToolContext ctx, Vector2 raw, bool shift) {
    final cam = ctx.camera.value;
    final aperture = kSnapAperturePixels / cam.scale;
    final page = ctx.page?.value;
    resolveDragPoint(
      raw: raw, orthoBase: shift ? orthoBase : null, index: ctx.index,
      apertureWorld: aperture, objectSnap: ctx.snap?.objectSnap ?? true,
      page: page, gridStepMm: dragGridStepMm(page, cam.scale),
      scratch: _scratch, out: _hover,
    );
    if (_hover.objectKind == null && !_hover.grid) {
      final self = selfSnap(raw, aperture);
      if (self != null) {
        _hover.point.setFrom(self);
        _hover.objectKind = SnapKind.endpoint;
        _hover.grid = false;
        return self;
      }
    }
    return null;
  }
  ```
- **test:** `packages/jet_cad_2d_flutter/test/draw/polyline_tool_test.dart`
  (PL8)
- **result:** KILLED -- `PL8` (target); the click 2 px from the anchor's
  entity endpoint and 4 px from the polyline's own first vertex now snaps
  to the (nearer, object-snapped) anchor endpoint instead of the own
  vertex, since 03's `resolveDragPoint` sets `_hover.objectKind` first and
  the mutant's guard then skips `selfSnap` entirely. The polyline never
  closes (`ofKind(...).single` throws "Bad state: No element"). Summary
  `+9 -1`.

### M-05w′ — self-snap applied to the resolved point (reviewer-noted second form)

- **file:** `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart`,
  `_resolve`
- **edit:** same reordering as M-05w (run `resolveDragPoint` first), but
  *always* consult self-snap afterward, against the already-resolved
  `_hover.point` rather than the raw click and rather than gating on
  whether anything snapped:
  ```dart
  Vector2? _resolve(ToolContext ctx, Vector2 raw, bool shift) {
    final cam = ctx.camera.value;
    final aperture = kSnapAperturePixels / cam.scale;
    final page = ctx.page?.value;
    resolveDragPoint(
      raw: raw, orthoBase: shift ? orthoBase : null, index: ctx.index,
      apertureWorld: aperture, objectSnap: ctx.snap?.objectSnap ?? true,
      page: page, gridStepMm: dragGridStepMm(page, cam.scale),
      scratch: _scratch, out: _hover,
    );
    final self = selfSnap(_hover.point, aperture);
    if (self != null) {
      _hover.point.setFrom(self);
      _hover.objectKind = SnapKind.endpoint;
      _hover.grid = false;
      return self;
    }
    return null;
  }
  ```
- **test:** `packages/jet_cad_2d_flutter/test/draw/polyline_tool_test.dart`
  (all 11 tests, including PL8)
- **result:** **SURVIVED.** `flutter test test/draw/polyline_tool_test.dart`
  printed `00:00 +11: All tests passed!` — PL8 does not kill this form.
  **Why, concretely (not fixed in this task; not a designed survivor —
  flagged per the dispatch note, no test change made):** in PL8 the click
  lands 2 px from the anchor's entity endpoint and 4 px from the polyline's
  own first vertex, both inside the aperture. `resolveDragPoint` runs
  first and snaps `_hover.point` to the *nearer* target, the anchor's
  entity endpoint (2 px). This mutant then calls `selfSnap(_hover.point,
  aperture)` — i.e. it asks whether the **anchor's endpoint** (not the raw
  click) is itself within the aperture of the polyline's own first vertex.
  Because the fixture places the first vertex only 6 px (screen) from the
  anchor's endpoint, and the aperture is 10 px, that check *also*
  succeeds, so `selfSnap` still returns the polyline's own first vertex
  and the assertion `p.coords[6] is not kAnchorX` still holds by
  coincidence of this fixture's exact distances. A fixture where the
  polyline's own vertex sits *outside* the aperture of the nearer entity
  endpoint (while the raw click stays inside the aperture of both) would
  be needed to distinguish the two forms; PL8 does not currently do that.
  This is recorded as a finding for a follow-up fixture change, not
  reworked here per the task's "no code change survives this task" scope.

### M-05x — a zero-length first segment refused only by `==`, not by distance

- **file:** `packages/jet_cad_2d_flutter/lib/src/draw/line_tool.dart`,
  `selfSnap`
- **edit:** dropped the `_segments > 0 &&` clause
- **test:** `packages/jet_cad_2d_flutter/test/draw/line_tool_test.dart` (L3)
- **result:** KILLED -- `L3` (target: expected `isPending == true`, got
  `false` — the tool now treats the very first click-on-itself as a valid
  self-snap and clears the shape instead of refusing), plus collateral
  `L5`. Summary `+4 -2`.

### M-05y — a canvas click cancels instead of committing

- **file:** `packages/jet_cad_2d_flutter/lib/src/draw/text_tool.dart`,
  `accept`
- **edit:** `commitText(controller.text, ctx);` → `cancelText(ctx);`
- **test:** `packages/jet_cad_2d_flutter/test/draw/text_tool_test.dart`
  (TX4)
- **result:** KILLED -- `TX4` (target); "Null check operator used on a null
  value" — `textOf(s.document)!` finds no text entity because the click
  cancelled the pending placement instead of committing it. Summary
  `+4 -1`.

### M-05z — the no-travel tie-break flipped

- **file:** `packages/jet_cad_2d/lib/src/document/drafting.dart`, `sweepTo`
- **edit:** `_travel >= 0` → `_travel > 0`
- **test:** `packages/jet_cad_2d/test/document/sweep_tracker_test.dart`
  (S5, its no-travel half) and
  `packages/jet_cad_2d_flutter/test/draw/arc_tool_test.dart` (AR4)
- **result:** KILLED in both named tests.
  - `sweep_tracker_test.dart` S5: expected `sweepTo(1.4)` ≈ `1.1` (CCW tie
    -break at `travel == 0`), got `-5.183185307179587` (the CW branch, since
    `0 > 0` is now false). Summary `+4 -1`.
  - `arc_tool_test.dart` AR4: expected sweep `> 0` ("τ == 0 is CCW"), got
    `-1.3000000000000034`. Summary `+4 -1`.

---

## Verification

- `git status --short` after every restore in this run printed nothing.
- After the last restore, `git status --short` and `git diff --stat` were
  both empty (confirmed immediately before writing this log).
