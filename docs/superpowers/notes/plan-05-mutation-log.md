# Plan 05 mutation log — M-05a..z, plus the final fix wave (M-05aa, M-05ab)

30 fired: 30 killed, 0 survived, 0 equivalent. (27 from the original sweep,
plus M-05aa, M-05ab and the F-3 kill from the final whole-branch review's
fix wave -- see "Final fix wave" below.)

**Fix round 1 (Ruling T9-a).** M-05w′ first fired as a survivor against
PL8; Task 9 fix round 1 changed PL8's fixture geometry (test-only) so both
forms of M-05w are killed, then re-fired both mutants to confirm. See the
M-05w and M-05w′ entries below for the before/after detail.

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
- **Re-fire (fix round 1, Ruling T9-a), after PL8's fixture changed** (see
  M-05w′ below for why the change was needed): re-applied the identical
  edit against the new PL8 geometry (first vertex at `anchor + Offset(13,
  0)`, close click at `anchor + Offset(5, 0)`). Still KILLED -- `PL8`, same
  failure shape, "Bad state: No element" at
  `test/draw/polyline_tool_test.dart 172:71` (line number only changed
  because the fixture's comments grew by two lines). Summary `+9 -1`.
  Restored and diffed empty against the fresh backup
  `placement_tool.dart.M-05w-refire`.

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

**First fire (Task 9, original PL8 fixture): SURVIVED.**
`flutter test test/draw/polyline_tool_test.dart` printed `00:00 +11: All
tests passed!` — PL8 did not kill this form. **Why, concretely:** in the
original PL8 the click landed 2 px from the anchor's entity endpoint and
4 px from the polyline's own first vertex, both inside the aperture.
`resolveDragPoint` ran first and snapped `_hover.point` to the *nearer*
target, the anchor's entity endpoint (2 px). This mutant then calls
`selfSnap(_hover.point, aperture)` — i.e. it asks whether the **anchor's
endpoint** (not the raw click) is itself within the aperture of the
polyline's own first vertex. Because the original fixture placed the first
vertex only 6 px (screen) from the anchor's endpoint, and the aperture is
10 px, that check *also* succeeded, so `selfSnap` still returned the
polyline's own first vertex and the assertion `p.coords[6] is not
kAnchorX` still held by coincidence of that fixture's exact distances.
Recorded as a finding, not fixed in Task 9 itself (a test change was out
of scope there).

**Fix round 1 (Ruling T9-a): fixture changed, re-fired, KILLED.** PL8's
geometry in `packages/jet_cad_2d_flutter/test/draw/polyline_tool_test.dart`
was changed (test-only) so the first vertex sits at `anchor + Offset(13,
0)` — 13 px from the anchor, **outside** the 10 px aperture — and the close
click sits at `anchor + Offset(5, 0)`, 8 px from the first vertex and 5 px
from the anchor, both inside the aperture. Confirmed green on clean code
first (`00:00 +11: All tests passed!`). Re-fired this mutant:
`resolveDragPoint` still resolves the click to the anchor's endpoint
(nearer, object-snapped); this mutant then calls `selfSnap(_hover.point,
aperture)`, i.e. checks whether the anchor's endpoint is within the
aperture of the polyline's own first vertex — and now it is not (13 px >
10 px), so `selfSnap` returns null and the polyline never closes. KILLED --
`PL8`; "Bad state: No element" at `test/draw/polyline_tool_test.dart
172:71`, the same failure shape as M-05w's re-fire above. Summary `+9 -1`.
Restored and diffed empty against the fresh backup
`placement_tool.dart.M-05w-prime-refire`.

### M-05x — dropping the `_segments > 0` guard self-snaps before any segment commits

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

- `git status --short` after every restore in this run printed nothing
  for the `.dart` files under `packages/` and `apps/`.
- After the last restore, `git diff --stat` showed no `.dart` change.

## Fix round 1 (Ruling T9-a)

`packages/jet_cad_2d_flutter/test/draw/polyline_tool_test.dart`'s PL8 was
changed (test-only) to place the first vertex at `anchor + Offset(13, 0)`
(outside the 10 px aperture from the anchor) and the closing click at
`anchor + Offset(5, 0)` (8 px from the first vertex, 5 px from the anchor,
both inside the aperture). Confirmed green on clean code, then both M-05w
and M-05w′ were re-fired with fresh `cp` backups and both now go red
against this fixture (see their entries above for the exact RED output);
both were restored and diffed empty. `git status --short` now shows only
the test file changed, no `.dart` under `lib/`.

## Invariants and greps (Task 10)

`main` here is the local branch `main` at `7dac3b5` (the branch point); every
`git diff main -- ...` below compares against it.

```
$ git diff main -- packages/jet_cad_2d_flutter/lib/src/tool.dart packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart | wc -l
       0
```
Invariant 4 holds: 02's API (`tool.dart`, `interaction_layer.dart`) is
byte-identical to `main`.

```
$ git diff main -- packages/jet_cad_2d/test/invariants packages/jet_cad_2d_flutter/test/invariants | wc -l
       0
```
The allocation invariant tests are unedited.

```
$ grep -rn "package:flutter\|dart:ui" packages/jet_cad_2d/lib | wc -l
3
```
3 hits, all doc comments that *name* the pure-Dart constraint rather than
violate it -- no `import` of either:
- `packages/jet_cad_2d/lib/src/document/tables.dart:38` -- "`package:jet_cad_2d`
  is pure Dart on purpose -- no `dart:ui`, no Flutter --"
- `packages/jet_cad_2d/lib/src/document/text_metrics.dart:16` -- "the em size.
  `dart:ui` exposes no cap height -- `computeLineMetrics` gives"
- `packages/jet_cad_2d/lib/src/geometry/dasher.dart:47` -- "Pure geometry: no
  `dart:ui`, no document access, no allocation per call. The"

The engine stays pure Dart; the raw grep count of 3 is prose, not code.

```
$ grep -rn "Path()" packages/jet_cad_2d_flutter/lib/src/draw
packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart:47:  final Path band = Path();
```
Exactly one hit, the expected one: `placement_tool.dart`'s reused `band`
field (D12). No `Path()` is constructed on the paint path.

```
$ grep -rn "handleSeed" packages/jet_cad_2d_flutter/lib/src/draw apps/floor_planner/lib
apps/floor_planner/lib/startup_plan.dart:178:        handle: doc.handleSeed.next(),
```
One hit, and it is the pre-existing sample-plan construction the dispatch
flagged in advance, not a tool: `startup_plan.dart:178` is inside `_Pen._add`,
the sample plan's own line builder (predates this plan). There are no hits
under `packages/jet_cad_2d_flutter/lib/src/draw` or in the app's tool/overlay
code -- every handle a drawing tool allocates goes through the drafting
builders (Ruling 05-3), never `handleSeed` directly.

```
$ grep -rn "Transform2.*==" packages/jet_cad_2d_flutter/test/draw apps/floor_planner/test/planner_draw_test.dart
```
No hits. `Transform2` is never compared with `==` in the new tests.

### Gate lines

`main` is at `7dac3b5`; branch-point counts from the plan: engine 894,
render layer 854 + 1 skip + 5 goldens, harness 82, app 26.

**`packages/jet_cad_2d`:**
```
$ CI=true dart test
...
00:03 +911: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +911: All tests passed!
```
Exit code 0. 911 passed (matches the expected engine count).
```
$ dart analyze
Analyzing jet_cad_2d...
No issues found!
```
Exit code 0.
```
$ dart format --output=none --set-exit-if-changed .
Formatted 133 files (0 changed) in 0.23 seconds.
```
Exit code 0.

**`packages/jet_cad_2d_flutter`:**
```
$ CI=true flutter test
...
00:12 +911 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```
Exit code 1 -- the standing exception, exactly the five
`text_ladder_golden_test.dart` rung failures (rungs 1-5, `RenderBackend.canvas`)
and nothing else. Summary `+911 ~1 -5` matches the expected 911 pass + 1 skip
+ 5 goldens.
```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.7s)
```
Exit code 0.
```
$ dart format --output=none --set-exit-if-changed .
Formatted 175 files (0 changed) in 0.32 seconds.
```
Exit code 0.

**`apps/dev_harness_2d`:**
```
$ CI=true flutter test --concurrency=1
...
00:19 +82: All tests passed!
```
Exit code 0. 82 passed (matches the expected harness count).
```
$ flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 1.0s)
```
Exit code 0.
```
$ dart format --output=none --set-exit-if-changed .
Formatted 22 files (0 changed) in 0.05 seconds.
```
Exit code 0.

**`apps/floor_planner`:**
```
$ CI=true flutter test
...
00:03 +43: All tests passed!
```
Exit code 0. 43 passed (matches the expected app count; up from the
branch-point 26 per Task 7-9's new drawing-tool tests).
```
$ flutter analyze
Analyzing floor_planner...
No issues found! (ran in 1.2s)
```
Exit code 0.
```
$ dart format --output=none --set-exit-if-changed .
Formatted 12 files (0 changed) in 0.04 seconds.
```
Exit code 0.
```
$ flutter build macos --release
Building macOS application...
✓ Built build/macos/Build/Products/Release/floor_planner.app (51.3MB)
```
Exit code 0.
```
$ flutter build web --release
Compiling lib/main.dart for the Web...                             25.6s
✓ Built build/web
```
Exit code 0.

`git status --short` printed nothing after each of the four gate lines
(three `flutter analyze`/`flutter pub get` runs touched no
`analysis_options.yaml`).

### Branch commit trailers (Ruling P-6)

```
$ git rev-list --count 7dac3b5..HEAD
13
$ git log --format=%B 7dac3b5..HEAD | grep -c "Co-Authored-By: Claude"
13
```
13 commits on the branch, 13 `Co-Authored-By: Claude` trailers -- one per
commit.

## Final fix wave (Rulings F-1, F-2, F-3)

Three mutants fired against the final whole-branch review's fixes. Same
procedure as above: `cp` the target to the mutation-backups directory,
apply the one edit by hand, run only the named test file(s) with
`CI=true`, paste the failing names and the summary line, restore with
`cp`, then `diff` and confirm empty.

### M-05aa — the L counter moved back to its old, colliding coordinates

- **file:** `apps/floor_planner/lib/startup_plan.dart`, the kitchen
  counter's `polygonRegion` call
- **edit:** restored the pre-fix vertex list (the south/west-wall L,
  hugging the bottom-left corner)
- **test:** `apps/floor_planner/test/startup_plan_test.dart` (SP3)
- **result:** KILLED -- `SP3` (target): "Expected: false / Actual: <true>
  / door point [17900.0,9050.0] lies under a furniture fill" -- the
  hall/kitchen door's swing again lands on the counter's old footprint.
  Summary `+7 -1`. Restored and diffed empty.

### M-05ab — the F3/F mid-shape exception dropped

- **file:** `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart`,
  `onKey`
- **edit:** removed the `if ((key == LogicalKeyboardKey.f3 || key ==
  LogicalKeyboardKey.keyF) && !_hasModifier()) return
  KeyEventResult.ignored;` block, so every key-down mid-shape falls
  through to `KeyEventResult.handled` again
- **test:** `packages/jet_cad_2d_flutter/test/draw/placement_tool_test.dart`
  (B10) and `apps/floor_planner/test/planner_draw_test.dart` (A16)
- **result:** KILLED in both.
  - `placement_tool_test.dart` B10: expected `KeyEventResult.ignored`, got
    `KeyEventResult.handled` for F3 mid-shape. Summary `+12 -1`.
  - `planner_draw_test.dart` A16: expected the `osnap-text` to read
    `osnap off` after F3 mid-polyline, still read `OSNAP` (the tool
    swallowed the key before the shell's `CallbackShortcuts` ever saw
    it). Summary `+15 -1`.
  - Both restored and diffed empty.

### The F-3 kill — the stale hover marker's `_hoverVisible = false` dropped

- **file:** `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart`,
  `cancel`
- **edit:** removed the `_hoverVisible = false;` line, so a tool
  reactivated after a switch away repaints its last hover marker before
  the next pointer move
- **test:** `packages/jet_cad_2d_flutter/test/draw/placement_tool_test.dart`
  (B11)
- **result:** KILLED -- `B11` (target): "Expected: empty / Actual:
  [Instance of 'RecordedCall']" -- `paintOverlay` drew the stale marker
  immediately after the tool returned, before any new hover. Summary
  `+13 -1`. Restored and diffed empty.
