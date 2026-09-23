# Plan 03 (grips-and-transform) — mutation log

**Tally: 62 mutants exercised — fired 60, killed 60, survived 1 (M-03e,
designed), equivalent 1 (M-03ai's ordinal tie-break clause, by
construction).**

- The spec's 27 (M-03a … M-03aa): 26 killed, 1 designed survivor (M-03e).
- Plus M-03ah′ (Ruling from the addendum, a second worldBoundsOf case): 1
  killed.
- Plus M-03ai's ordinal-clause variant: 1 equivalent, by construction —
  does not count against the "only M-03e survives" rule.
- The plan's 23 (M-03ab … M-03ax, Ruling 03-17): 23 killed.
- The controller's 10 (review findings, M-03ay … M-03bg, including
  M-03bf′): 10 killed. Seven new tests landed for them, each in its own
  commit (M-03bf and M-03bf′ share one). M-03bc and M-03bd were already
  guarded, by the extended T14 and by the M-03at test, and needed none.

26 + 1 + 23 + 10 = 60 mutants killed. Add M-03e, the designed survivor, and
M-03ai's equivalent ordinal-clause variant, and 62 were exercised. M-03ai
counts once among the plan's 23 for its main edit (killed) and once more for
the equivalent variant. M-03bf/M-03bf′ share one heading for two edits. With
those two readings, 60 killed + 1 survived + 1 equivalent = 62 reconciles
against every heading in this file.

`git status --short` at the end of this task lists only this log and the
seven new test files (Tasks 1, 3, 4 ×2, 7, 8 ×2) touched for the
controller-added mutants; no production `.dart` file differs from HEAD
32fa2cd.

Method: for each mutant, the source file is copied aside to
`.superpowers/sdd/2026-09-23-grips-and-transform/mutation-backups/<basename>.<id>`,
the one edit is applied by hand, the named test file is run with `CI=true`,
the result is recorded, then the file is restored from the backup and `diff`
confirms a clean restore.

## The spec's named mutants (M-03a … M-03aa)

### M-03a — the drag delta from a scaled screen delta, no inverse camera
file: packages/jet_cad_2d_flutter/lib/src/select_tool.dart, in `_follow`
edit: `_retarget(ctx, e.world, e.shift);` -> `_retarget(ctx, Vector2(_pressWorld.x + (e.screen.dx - _start.dx) / ctx.camera.value.scale, _pressWorld.y + (e.screen.dy - _start.dy) / ctx.camera.value.scale), e.shift);`
test: CI=true flutter test test/select_tool_drag_test.dart
result: FIRED -- `a body drag moves the selection under a rotated camera (M-03a)` [E], plus 6 other tests that happen to share the same drag path (`a centre grip moves the whole selection from the grip itself`, `a move dragged past the layer's edge continues and lands`, `a rotation turns about the selection box centre, far from the origin`, `shift steps the rotation by 15 degrees`, `permissions at press...`, `a camera change mid-drag re-resolves the target...`); 13 passed, 7 failed
restored: diff clean

### M-03b — snap tie-break decides by distance first, not kind
file: packages/jet_cad_2d/lib/src/index/spatial_index.dart, in `_considerSnapCandidate`
edit: `final better = _bestSnapKind == null || kindIndex < _bestSnapKind!.index || (kindIndex == _bestSnapKind!.index && (dist < _bestSnapDist || (dist == _bestSnapDist && (effectiveRoot > _bestSnapRoot || (effectiveRoot == _bestSnapRoot && handle.value > _bestSnapEntity)))));` -> `final better = _bestSnapKind == null || dist < _bestSnapDist || (dist == _bestSnapDist && kindIndex < _bestSnapKind!.index);`
test: CI=true dart test test/index/drag_snap_test.dart test/index/snap_test.dart
result: FIRED -- `kind decides between object snaps through a drag (M-03b)` [E] in drag_snap_test.dart, and `kind priority dominates even when the higher-priority candidate is FARTHER, not merely equidistant` [E] in snap_test.dart; 29 passed, 2 failed
restored: diff clean

### M-03c — a node's own move rewrites its leaves instead of its transform
file: packages/jet_cad_2d_flutter/lib/src/grip_drag.dart, in `command`, the `_NodeCapture` case
edit: `members.add(TransformNodeCommand(handle, t.multiply(node.transform)));` -> `if (node is InstanceNode) { for (final slot in document.leavesByOwner()[node.definition] ?? const <int>[]) { members.add(SetEntityGeometryCommand(document.entities.handleAt(slot), rigidTransformLeaf(document.entities.kindAt(slot), document.geometry.read(document.entities.geomIndexAt(slot)), t))); } } else { members.add(TransformNodeCommand(handle, t.multiply(node.transform))); }`
test: CI=true flutter test test/grip_drag_test.dart
result: FIRED -- `an instance move rewrites the instance node, never the definition (M-03c)` [E], plus `a move is one CompoundCommand labelled Move, members in ascending handle order (M-03an)` [E] (the instance's own handle 28 is no longer emitted); 9 passed, 2 failed
restored: diff clean

### M-03d — a command dispatches on every move, not only on release
file: packages/jet_cad_2d_flutter/lib/src/select_tool.dart, in `_follow`
edit: append after `_retarget(ctx, e.world, e.shift);`: `final c = _drag!.command(ctx.document.commands.permissions); if (c != null) ctx.execute(c);`
test: CI=true flutter test test/select_tool_drag_test.dart
result: FIRED -- `no command during a drag; release adds exactly one Compound "Move" (M-03d, invariants 1 and 4)` [E] -- `Expected: <0>` `Actual: <1>` "nothing is dispatched during a drag"; 12 passed, 8 failed
restored: diff clean

### M-03e — designed survivor: the undo assertion loosened from == to Tolerance
file: packages/jet_cad_2d_flutter/test/grip_drag_test.dart, D10 ("undo restores every stored value with == (spec D11; M-03e is the designed survivor)")
edit: `expect(payloadOf(doc, s.line), payloads[s.line]);` -> `expect(payloadsClose(payloadOf(doc, s.line), payloads[s.line]!), isTrue);`, and the same for `s.arcNeg`
test: CI=true flutter test test/grip_drag_test.dart
result: SURVIVED -- designed (spec D11). 11 tests, `All tests passed!` -- both mutated assertions stayed green under `payloadsClose`
restored: diff clean

D11 companion, unmutated ("the undo assertion enforces ==: one ulp is caught (M-03e companion, Ruling 03-20)") -- green in the same run above: it nudges `payloadOf(doc, s.line).coords[0]` by one ulp (`nextUp`) and asserts `nudged == original` is false (== is caught by one ulp) while `payloadsClose(nudged, original)` is true (Tolerance is not) -- this is exactly why M-03e survives: the D10 assertion, mutated to `payloadsClose`, cannot see the one-ulp difference that `==` would.

### M-03f — ortho pins the major axis instead of the minor
file: packages/jet_cad_2d/lib/src/index/drag_snap.dart, `resolveDragPoint` step 1
edit: swap the two branch bodies -- the `>=` branch now pins `cx = base.x; pinX = true;` and the else branch pins `cy = base.y; pinY = true;`
test: CI=true dart test test/index/drag_snap_test.dart; CI=true flutter test test/select_tool_drag_test.dart
result: FIRED -- engine: `ortho pins the minor world axis to the base (M-03f)` [E] (7 passed, 2 failed -- also caught `a grid snap re-pins the ortho axis afterwards (M-03q)`); render: `a shift-press-drag on an unselected object adds it and moves ortho in world axes (M-03f)` [E] (18 passed, 1 failed)
restored: diff clean

### M-03g — the grid steals a win from a nearer object snap
file: packages/jet_cad_2d/lib/src/index/drag_snap.dart, `resolveDragPoint` step 2
edit: inside `if (scratch.found) {`, before the copy, insert a grid-vs-object distance race that can override the object snap
test: CI=true dart test test/index/drag_snap_test.dart
result: FIRED -- `an object snap beats a nearer grid point (M-03g)` [E] -- `Expected: [7093, 3004]` `Actual: [7100.0, 3000.0]`; 7 passed, 1 failed
restored: diff clean

### M-03h — an arc rotate leaves the start angle untouched
file: packages/jet_cad_2d/lib/src/document/grips.dart, `rigidTransformLeaf`, arc case
edit: delete `if (scalars.length >= 2) scalars[1] = scalars[1] + theta;`
test: CI=true dart test test/document/rigid_transform_test.dart; CI=true flutter test test/grip_drag_test.dart
result: FIRED -- engine: `an arc rotates its start angle; radius and sweep are copied (M-03h)` [E] and `differential: 200 seeded rigid transforms agree with an independent oracle (M-03h, M-03m)` [E] (4 passed, 2 failed); render: `a rotate is labelled Rotate and turns an arc's start angle (M-03h)` [E] (9 passed, 1 failed)
restored: diff clean

### M-03i — a node's transform conjugated in the wrong order
file: packages/jet_cad_2d_flutter/lib/src/grip_drag.dart, `command`
edit: `TransformNodeCommand(handle, t.multiply(node.transform))` -> `TransformNodeCommand(handle, node.transform.multiply(t))`
test: CI=true flutter test test/grip_drag_test.dart
result: FIRED -- `a rotated group moves by T.multiply(node.transform) (M-03i)` [E], plus `an instance move rewrites the instance node, never the definition (M-03c)` [E]; 9 passed, 2 failed
restored: diff clean

### M-03j — a rotation pivots at the world origin, not the box centre
file: packages/jet_cad_2d_flutter/lib/src/select_tool.dart, `_beginDrag`, rotation grip
edit: `final pivot = Vector2((box.minX + box.maxX) / 2, (box.minY + box.maxY) / 2);` -> `final pivot = Vector2.zero();`
test: CI=true flutter test test/select_tool_drag_test.dart
result: FIRED -- `a rotation turns about the selection box centre, far from the origin (M-03j)` [E], plus `shift steps the rotation by 15° (M-03w)` [E]; 18 passed, 2 failed
restored: diff clean

### M-03k — a refused member is dropped instead of cancelling the whole drag
file: packages/jet_cad_2d_flutter/lib/src/grip_drag.dart, `command`
edit: `if (members.any((m) => !m.capabilities.every(permissions.allows))) { return null; }` -> `members.removeWhere((m) => !m.capabilities.every(permissions.allows)); if (members.isEmpty) return null;`
test: CI=true flutter test test/grip_drag_test.dart
result: FIRED -- `a refused member cancels the whole drag (M-03k)` [E] -- `Expected: null` `Actual: <Instance of 'CompoundCommand'>` "all or nothing: the instance is permitted, the line is not"; 10 passed, 1 failed
restored: diff clean

### M-03l — Escape dispatches a command before cancelling
file: packages/jet_cad_2d_flutter/lib/src/select_tool.dart, `onKey`, dragging block
edit: before `cancel(ctx);` insert `final c = _drag?.command(ctx.document.commands.permissions); if (c != null) ctx.execute(c);`
test: CI=true flutter test test/select_tool_drag_test.dart
result: FIRED -- `every key-down and repeat is the drag's; Escape cancels byte-identically (M-03aa, M-03l)` [E] -- the saved document string differs (instance 29's transform and line 18's coords have moved); 19 passed, 1 failed
restored: diff clean

### M-03m — a text rotate drops the added rotation term
file: packages/jet_cad_2d/lib/src/document/grips.dart, `rigidTransformLeaf`, text case
edit: `scalars[1] = scalarOr(payload, 1, 0) + theta;` -> `scalars[1] = scalarOr(payload, 1, 0);`
test: CI=true dart test test/document/rigid_transform_test.dart
result: FIRED -- `a text rotates its rotation scalar; a height-only text gains one (M-03m)` [E] and `differential: 200 seeded rigid transforms agree with an independent oracle (M-03h, M-03m)` [E]; 4 passed, 2 failed
restored: diff clean

### M-03n — an arc end stretch always wraps positive, ignoring the sweep's sign
file: packages/jet_cad_2d/lib/src/document/grips.dart, `reshapeLeaf`, arc end
edit: `nextSweep = _wrapSweep(a - start, sweep);` -> `nextSweep = _wrapSweep(a - start, 1.0);`
test: CI=true dart test test/document/grips_test.dart
result: FIRED -- `reshapeLeaf an arc end stretch on a negative sweep stays negative (M-03n)` [E]; 10 passed, 1 failed
restored: diff clean

### M-03o — a stretch writes the wrong vertex, off by one
file: packages/jet_cad_2d/lib/src/document/grips.dart, `reshapeLeaf`, line/polyline
edit: `coords[i * 2] = localTarget.x; coords[i * 2 + 1] = localTarget.y;` -> `coords[(i + 1) * 2] = localTarget.x; coords[(i + 1) * 2 + 1] = localTarget.y;`
test: CI=true dart test test/document/grips_test.dart
result: FIRED -- `reshapeLeaf a polyline middle-vertex stretch moves that vertex and nothing else (M-03o)` [E] (vertex written one slot over), plus `reshapeLeaf a line stretch writes the grabbed pair and copies the rest` throws a `RangeError` (the last vertex's `(i+1)*2` runs off the end of `coords`), which cascades into `reshapeLeaf a closed room corner moves as one: first and last pairs stay == (M-03r)` also failing; 8 passed, 3 failed
restored: diff clean

### M-03p — a zero-delta move still builds a command
file: packages/jet_cad_2d_flutter/lib/src/grip_drag.dart, `command`
edit: delete the `if (kind == DragKind.move && target.x - base.x == 0 && target.y - base.y == 0) { return null; }` statement
test: CI=true flutter test test/grip_drag_test.dart test/select_tool_drag_test.dart
result: FIRED -- `a drag that changes nothing builds no command (M-03p)` [E] in grip_drag_test.dart (`Expected: null` `Actual: <Instance of 'CompoundCommand'>`), and `a drag back to the press pixel, or snapped back onto its base, adds nothing (M-03p)` [E] in select_tool_drag_test.dart; 29 passed, 2 failed
restored: diff clean

### M-03q — the grid snap never re-pins the ortho axis
file: packages/jet_cad_2d/lib/src/index/drag_snap.dart, `resolveDragPoint` step 3
edit: delete `if (pinY) out.point.y = base!.y;` and `if (pinX) out.point.x = base!.x;`
test: CI=true dart test test/index/drag_snap_test.dart
result: FIRED -- `a grid snap re-pins the ortho axis afterwards (M-03q)` [E] -- `Expected: [7200, 3017.3]` `Actual: [7200.0, 3000.0]`; 8 passed, 1 failed
restored: diff clean

### M-03r — a closed polyline's shared corner splits apart under a stretch
file: packages/jet_cad_2d/lib/src/document/grips.dart, `reshapeLeaf`
edit: delete the `if (i == 0 && kind == EntityKind.polyline && isClosedPolyline(payload)) { coords[(n - 1) * 2] = localTarget.x; coords[(n - 1) * 2 + 1] = localTarget.y; }` block
test: CI=true dart test test/document/grips_test.dart
result: FIRED -- `reshapeLeaf a closed room corner moves as one: first and last pairs stay == (M-03r)` [E] -- the last pair stays at the old corner while the first moves; 10 passed, 1 failed
restored: diff clean

### M-03s — a body drag's base skips grid snap
file: packages/jet_cad_2d_flutter/lib/src/select_tool.dart, `_moveBase`
edit: `_resolve(ctx, _pressWorld, null);` -> the full `resolveDragPoint(raw: _pressWorld, orthoBase: null, index: ctx.index, apertureWorld: kSnapAperturePixels / ctx.camera.value.scale, objectSnap: ctx.snap?.objectSnap ?? true, page: null, gridStepMm: null, scratch: _snapScratch, out: _dragPoint);` (page and gridStepMm hard-wired to null, so grid snap never applies to the base)
test: CI=true flutter test test/select_tool_drag_test.dart
result: FIRED -- `with grid snap on, on-grid geometry stays on the grid (M-03s)` [E] -- `Expected: true` `Actual: <false>` "coordinate 0 = 7064.000000000001 left the 10 mm lattice"; 19 passed, 1 failed
restored: diff clean

### M-03t — release skips revalidation against the press-time captures
file: packages/jet_cad_2d_flutter/lib/src/grip_drag.dart, `command`
edit: delete `if (!_revalidate()) return null;`
test: CI=true flutter test test/grip_drag_test.dart test/select_tool_drag_test.dart
result: FIRED -- `release revalidates against the press-time captures (M-03t)` [E] in grip_drag_test.dart (`Expected: null` `Actual: <Instance of 'CompoundCommand'>`), and `a document change mid-drag: release dispatches nothing (M-03t)` [E] in select_tool_drag_test.dart (`Expected: <1>` `Actual: <2>`); 29 passed, 2 failed
restored: diff clean

### M-03u — the move/rotate preview composes matrix ∘ T instead of T ∘ translate(origin)
file: packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart, `_paintPreview`
edit: `final pe = t.a * origin.x + t.c * origin.y + t.e;` -> `final pe = t.e + origin.x;`, and `final pf = t.b * origin.x + t.d * origin.y + t.f;` -> `final pf = t.f + origin.y;`
test: CI=true flutter test test/selection_overlay_grips_test.dart
result: FIRED -- `the move/rotate preview is drawn through worldToScreen ∘ T ∘ translate(origin) (M-03u)` [E]; 5 passed, 1 failed
restored: diff clean

### M-03v — grips drawn per-grip instead of one drawRawPoints per colour
file: packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart, `_paintGrips`
edit: add `Rect` to the `dart:ui` show list; replace both `drawRawPoints` calls with per-grip `drawRect` loops over `_stretchPoints`/`_movePoints`
test: CI=true flutter test test/selection_overlay_grips_test.dart
result: FIRED -- `grips are one drawRawPoints per colour at 10 grips and at 300, and the hot grip one more (invariant 6, M-03v, M-03aq)` [E] -- the draw-call trace shows a `drawRect` per grip instead of `drawLine`/`drawCircle` in O(1); "the draw calls do not depend on the grip count"; 5 passed, 1 failed
restored: diff clean

### M-03w — the shift rotation step doubles to 30°
file: packages/jet_cad_2d_flutter/lib/src/grip_drag.dart
edit: `const double kRotationStep = math.pi / 12;` -> `const double kRotationStep = math.pi / 6;`
test: CI=true flutter test test/select_tool_drag_test.dart
result: FIRED -- `shift steps the rotation by 15° (M-03w)` [E] -- `Expected: 0.2617993877991494` `Actual: 0.5235987755982988`; 19 passed, 1 failed
restored: diff clean

### M-03x — object snap off still snaps to objects
file: packages/jet_cad_2d/lib/src/index/drag_snap.dart, `resolveDragPoint` step 2
edit: `if (objectSnap) {` -> `if (true) {`
test: CI=true dart test test/index/drag_snap_test.dart; CI=true flutter test test/planner_grips_test.dart (app)
result: FIRED -- engine: `object snap off never snaps to an object: the grid wins (M-03x)` [E] (7 passed, 1 failed); app: `F3 turns object snap off: osnap-text says so and the drag lands on the grid (A2, M-03x)` [E] (3 passed, 1 failed)
restored: diff clean

### M-03y — a circle drops its fourth quadrant grip
file: packages/jet_cad_2d/lib/src/document/grips.dart, `leafGrips`, circle
edit: `for (var q = 0; q < 4; q++)` -> `for (var q = 0; q < 3; q++)`
test: CI=true dart test test/document/grips_test.dart; CI=true flutter test test/grip_cache_test.dart
result: FIRED -- engine: `leafGrips the grip set per kind, in owner space (M-03y)` [E] (length 4 instead of 5); render: `grips of the selected root leaves, in world, in ascending handle order (M-03y)` [E] (length 14 instead of 15)
restored: diff clean

### M-03z — the grip cap drops the boundary count itself
file: packages/jet_cad_2d_flutter/lib/src/grip_cache.dart, `_rebuild`
edit: `if (_grips.length > kMaxGrips)` -> `if (_grips.length >= kMaxGrips)`
test: CI=true flutter test test/grip_cache_test.dart
result: FIRED -- `the cap: kMaxGrips grips are kept, kMaxGrips + 1 keep none (M-03z)` [E] -- `Expected: length 400` `Actual: length 0`; 6 passed, 1 failed
restored: diff clean

### M-03aa — a dragging key-down falls through to the shell
file: packages/jet_cad_2d_flutter/lib/src/select_tool.dart, `onKey`
edit: delete the `return KeyEventResult.handled;` that ends the dragging block
test: CI=true flutter test test/select_tool_drag_test.dart; CI=true flutter test test/planner_grips_test.dart (app)
result: FIRED -- render: `every key-down and repeat is the drag's; Escape cancels byte-identically (M-03aa, M-03l)` [E] (`Expected: KeyEventResult.handled` `Actual: KeyEventResult.ignored`); app: `cmd+Z pressed mid-drag is the drag's, not the shell's (A4, M-03aa)` [E] (`Expected: <1>` `Actual: <0>` "the Z never reached the shell (spec D5)")
restored: diff clean

## The plan's mutants (Ruling 03-17): M-03ab … M-03ax

### M-03ab — the cursor renders straight off the tool, with no rebuild seam (re-expressed)
Brief's row was written before Task 7's fix (b7810fb-era): it assumed `interaction_layer.dart` still rendered a `ListenableBuilder` around the whole subtree. It does not any more -- since the Task 7 fix for a mid-drag-removal assert, the cursor is mirrored into a `ValueNotifier<MouseCursor>` rendered by a `ValueListenableBuilder<MouseCursor>` around only the `MouseRegion`. Re-expressed per the addendum: render `MouseRegion(cursor: _tool.cursor, ...)` directly, with no builder and no `_cursor` mirror, so a tool's cursor change never triggers a rebuild at all.
file: packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart, `build`
brief's edit (stale): replace the `ListenableBuilder(…)` with `MouseRegion(cursor: _tool.cursor, onExit: _onExit, child: Listener(…the same Listener…))`
actual edit: replaced `ValueListenableBuilder<MouseCursor>(valueListenable: _cursor, builder: (context, cursor, child) => MouseRegion(cursor: cursor, onExit: _onExit, child: child), child: Listener(...))` with `MouseRegion(cursor: _tool.cursor, onExit: _onExit, child: Listener(...))` directly
test: CI=true flutter test test/interaction_cursor_test.dart
result: FIRED -- `the MouseRegion follows the active tool's cursor (spec D5, M-03ab)` [E], and the other two cursor tests in the file also go red (`Expected: SystemMouseCursor(grabbing)` `Actual: defer`, `Expected: SystemMouseCursor(move)` `Actual: defer`) since the tree never rebuilds after the initial build; 0 passed, 3 failed
restored: diff clean

### M-03ac — a drag stops listening to the camera
file: packages/jet_cad_2d_flutter/lib/src/select_tool.dart, `_enter`
edit: delete `ctx.camera.addListener(_onCamera);`
test: CI=true flutter test test/select_tool_drag_test.dart
result: FIRED -- `a camera change mid-drag re-resolves the target from the last screen point (M-03ac)` [E]; 19 passed, 1 failed
restored: diff clean

### M-03ad — leaf grips stay live under a geometry denial
file: packages/jet_cad_2d_flutter/lib/src/grip_cache.dart
edit: `bool get leafGripsLive => document.commands.permissions.allows(Capability.geometry);` -> `bool get leafGripsLive => true;`
test: CI=true flutter test test/grip_cache_test.dart test/select_tool_drag_test.dart test/selection_overlay_grips_test.dart
result: FIRED -- `leaf grips are not live under a geometry denial (M-03ad)` [E] in grip_cache_test.dart (`Expected: false` `Actual: <true>`); `permissions at press: no leaf grips, a refused move stays a click, an instance still moves (M-03ad, M-03av)` [E] in select_tool_drag_test.dart (`Expected: PressClass.selectedBody` `Actual: PressClass.grip`); `no leaf grips are drawn under a geometry denial; the rotation grip still is (M-03ad)` [E] in selection_overlay_grips_test.dart; 30 passed, 3 failed
restored: diff clean

### M-03ae — a moved point-cross ignores the preview transform
file: packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart, `_drawPointCross`
edit: delete `px = tx;` and `py = ty;`
test: CI=true flutter test test/selection_overlay_grips_test.dart
result: FIRED -- `a selected point's preview cross sits at T(p) (M-03ae)` [E]; 5 passed, 1 failed
restored: diff clean

### M-03af — F3 held down toggles on every key-repeat
file: apps/floor_planner/lib/main.dart
edit: `const SingleActivator(LogicalKeyboardKey.f3, includeRepeats: false):` -> `const SingleActivator(LogicalKeyboardKey.f3):`
test: CI=true flutter test test/planner_grips_test.dart (app)
result: FIRED -- `F3 held down toggles once (A3, M-03af)` [E] -- `Expected: 'osnap off'` `Actual: 'OSNAP'` "includeRepeats: false -- a repeat would have toggled it back"; 3 passed, 1 failed
restored: diff clean

### M-03ag — the endpoint and midpoint snap markers swap shapes
file: packages/jet_cad_2d_flutter/lib/src/snap_marker.dart
edit: swap the bodies of `case SnapKind.endpoint:` and `case SnapKind.midpoint:`
test: CI=true flutter test test/snap_marker_test.dart
result: FIRED -- `each snap kind draws its own marker; the raw point draws nothing (spec D9, M-03ag)` [E] -- `Expected: ['drawRect']` `Actual: ['drawPath']`; 0 passed, 1 failed
restored: diff clean

### M-03ah — worldBoundsOf's arc case uses the bounding-box radius square, not arcBounds
file: packages/jet_cad_2d_flutter/lib/src/outline_cache.dart, `worldBoundsOf`
edit: `box = box.union(arcBounds(Vector2(cx, cy), r, start, sweep));` -> `box = box.union(Aabb2.raw(cx - r, cy - r, cx + r, cy + r));`
test: CI=true flutter test test/outline_cache_test.dart; CI=true flutter test test/grip_cache_test.dart
result: FIRED by O1 -- `worldBoundsOf: an arc by arcBounds, a point by its position (M-03ah)` [E] (`Expected: 7011.16...` `Actual: 7010.0`); 11 passed, 1 failed. Per the addendum: C2 (`the selection box is the union of worldBoundsOf; fills alone have none (M-03ah)`) does NOT catch this -- confirmed, `grip_cache_test.dart` stays green (7/7 passed), because `GripCache.box` is built by calling the same mutated `worldBoundsOf` and comparing against its own (also-mutated) output; O1 is the actual killer, since it compares against an independent `arcBounds` expectation.
restored: diff clean

### M-03ah' — worldBoundsOf's point case contributes nothing to the box
file: packages/jet_cad_2d_flutter/lib/src/outline_cache.dart, `worldBoundsOf`
edit: the `_Point(:final x, :final y): box = box.expandedToPoint(Vector2(x, y));` case body -> `break;`
test: CI=true flutter test test/outline_cache_test.dart; CI=true flutter test test/grip_cache_test.dart
result: FIRED -- outline_cache_test.dart: `worldBoundsOf: an arc by arcBounds, a point by its position (M-03ah)` [E] throws a null-check exception (the point key's box is now null); grip_cache_test.dart: `the selection box is the union of worldBoundsOf; fills alone have none (M-03ah)` [E] -- `Expected: <7250>` `Actual: <7170.901201280415>` "the point counts by its position". Here, unlike M-03ah proper, C2 IS a killer: 17 passed, 2 failed
restored: diff clean

### M-03ai — the coincident-grip tie-break picks the lesser handle
file: packages/jet_cad_2d_flutter/lib/src/grip_cache.dart, `hitTest`
edit: `(h > bestHandle ||` -> `(h < bestHandle ||`
test: CI=true flutter test test/grip_cache_test.dart test/select_tool_drag_test.dart
result: FIRED -- `hitTest: the nearest, then the greater handle, then the lower ordinal (M-03ai)` [E] (`Expected: <19>` `Actual: <18>`) and `coincident grips: the greater handle's end moves, the other object stays (M-03ai)` [E]; 25 passed, 2 failed
restored: diff clean

M-03ai (equivalent) — dropping the ordinal tie-break
file: packages/jet_cad_2d_flutter/lib/src/grip_cache.dart, `hitTest`
edit: `(h == bestHandle && ref.ordinal < bestOrdinal)` -> `(h == bestHandle)` (the ordinal clause dropped)
test: CI=true flutter test test/grip_cache_test.dart test/select_tool_drag_test.dart
result: SURVIVED -- EQUIVALENT, by construction. `_grips` (and therefore the candidates `hitTest` iterates) are built in ascending ordinal within each key by `_rebuild`'s `for (var i = 0; i < list.length; i++) { _grips.add(GripRef(key, list[i], i)); }`, so for any fixed `h == bestHandle`, the first candidate seen already has the lowest ordinal for that handle; a later candidate at the same handle and same distance can only have a strictly greater ordinal. The dropped clause `ref.ordinal < bestOrdinal` can therefore never be true at the point it is tested -- there is no reachable state where removing it changes `better`. 27 passed, 0 failed (`All tests passed!`) -- does not count against the "only M-03e survives" rule.
restored: diff clean

### M-03aj — the reshape preview path is built in absolute world, not rebased
file: packages/jet_cad_2d_flutter/lib/src/select_tool.dart, `_reshapePath`
edit: `final ox = origin.x, oy = origin.y;` -> `final ox = 0.0, oy = 0.0;`
test: CI=true flutter test test/selection_overlay_grips_test.dart
result: FIRED -- `the reshape preview is a rebased path under the world matrix (M-03aj)` [E] -- `Expected: -158.0` `Actual: 7010.0`; 5 passed, 1 failed
restored: diff clean

### M-03ak — the rotation grip hangs below the box instead of above
file: packages/jet_cad_2d_flutter/lib/src/grip_cache.dart, `rotationGripOf`
edit: `minY - kRotationGripOffset` -> `minY + kRotationGripOffset`
test: CI=true flutter test test/grip_cache_test.dart
result: FIRED -- `the rotation grip hangs 24 px above the screen box, screen-up (M-03ak)` [E] -- off by 48.0 (twice the offset); 6 passed, 1 failed
restored: diff clean

### M-03al — the grip cache never rebuilds when the outline cache changes
file: packages/jet_cad_2d_flutter/lib/src/grip_cache.dart, constructor
edit: delete `outlines.addListener(_rebuild);`
test: CI=true flutter test test/grip_cache_test.dart
result: FIRED -- `a DocChange rebuilds the grips after the outline cache (M-03al)` [E] -- `Expected: <7160>` `Actual: <7130.0>`; 6 passed, 1 failed
restored: diff clean

### M-03am — a fills-only selection still captures its fill
file: packages/jet_cad_2d_flutter/lib/src/grip_drag.dart, `_capture`
edit: `if (kind == EntityKind.fill || kind == EntityKind.attrib) continue;` -> `if (kind == EntityKind.attrib) continue;`
test: CI=true flutter test test/grip_drag_test.dart
result: FIRED -- `fills are skipped; a fills-only selection has no drag (M-03am)` [E] -- `Expected: null` `Actual: <Instance of 'GripDrag'>`; 10 passed, 1 failed
restored: diff clean

### M-03an — the captures keep the selection's own key order, not ascending handle
file: packages/jet_cad_2d_flutter/lib/src/grip_drag.dart, `_capture`
edit: delete `..sort((a, b) => a.target.value.compareTo(b.target.value))`
test: CI=true flutter test test/grip_drag_test.dart
result: FIRED -- `a move is one CompoundCommand labelled Move, members in ascending handle order (M-03an)` [E] -- `Expected: [18, 23, 25, 29]` `Actual: [29, 25, 23, 18]`; 10 passed, 1 failed
restored: diff clean

### M-03ao — a cancel dispatches the pending command before discarding it
file: packages/jet_cad_2d_flutter/lib/src/select_tool.dart, `cancel`
edit: before `_endDrag(ctx);` insert `final pending = _drag?.command(ctx.document.commands.permissions); if (pending != null) ctx.execute(pending);`
test: CI=true flutter test test/select_tool_drag_test.dart
result: FIRED -- four tests go red: `a pointer cancel leaves the document byte-identical (M-03ao)` [E], `every key-down and repeat is the drag's; Escape cancels byte-identically (M-03aa, M-03l)` [E], `tool activation cancels a drag byte-identically (M-03ao)` [E], `removing the layer mid-drag cancels byte-identically (M-03ao)` [E] -- each shows the document mutated (line 18's coords moved) where Escape/cancel should leave it byte-identical; 16 passed, 4 failed
restored: diff clean

### M-03ap — a pointer exit cancels a captured drag
file: packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart, `_onExit`
edit: delete `if (_activePointer != -1) return;`
test: CI=true flutter test test/select_tool_drag_test.dart test/interaction_layer_test.dart
result: FIRED -- `a move dragged past the layer's edge continues and lands (M-03ap)` [E] in select_tool_drag_test.dart (`Expected: DragKind.move` `Actual: null` "pointer exit is not a cancel path"), and 02's `a drag that leaves the box keeps its captured pointer` [E] in interaction_layer_test.dart (`Expected: ToolPhase.dragging` `Actual: ToolPhase.idle` "leaving the box is not the end of a captured drag"); 28 passed, 2 failed
restored: diff clean

### M-03aq — the hot grip is never drawn
file: packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart, `_paintGrips`
edit: delete the `if (hot >= 0 && hot < list.length) { ... }` block
test: CI=true flutter test test/selection_overlay_grips_test.dart
result: FIRED -- `grips are one drawRawPoints per colour at 10 grips and at 300, and the hot grip one more (invariant 6, M-03v, M-03aq)` [E] -- `Expected: length 3` `Actual: length 2` (the third, hot-grip `drawRawPoints` call is missing); 5 passed, 1 failed
restored: diff clean

### M-03ar — the snap marker is drawn at the last screen point, not the resolved target
file: packages/jet_cad_2d_flutter/lib/src/select_tool.dart, `_paintGuide`
edit: `drawSnapMarker(canvas, b, ...)` -> `drawSnapMarker(canvas, _lastScreen, ...)`
test: CI=true flutter test test/selection_overlay_grips_test.dart
result: FIRED -- `a stretch draws its guide and the snap marker at the resolved target (spec D7, D9, M-03ar)` [E] -- off by 3.0; 5 passed, 1 failed
restored: diff clean

### M-03as — a grip hit is recorded but the press class falls through to the body pick (re-expressed)
Brief's row assumed `_pressGrip` was still an `int`. It is now `GripRef? _pressRef`, re-found live at the slop (Task 4/7 review). Re-expressed per the addendum: in `_classify`, when a grip is hit, still record `_pressRef` but do not return `PressClass.grip` -- let control fall through to the ordinary object pick.
file: packages/jet_cad_2d_flutter/lib/src/select_tool.dart, `_classify`
brief's edit (stale): `if (i >= 0) { _pressGrip = i; return PressClass.grip; }` -> `if (i >= 0) { _pressGrip = i; }`
actual edit: `if (i >= 0) { _pressRef = grips.grips[i]; return PressClass.grip; }` -> `if (i >= 0) { _pressRef = grips.grips[i]; }`
test: CI=true flutter test test/select_tool_drag_test.dart
result: FIRED -- `a click on a grip or on the rotation grip changes nothing (D12, M-03as); the cursor says what a press would do (T1)` [E] -- `Expected: PressClass.grip` `Actual: PressClass.selectedBody`; four further tests cascade red for the same reason (`a centre grip moves the whole selection from the grip itself`, `a stretch released near an endpoint lands on it exactly`, `coincident grips: the greater handle's end moves, the other object stays`, `a grip or a box gone between the press and the slop leaves the press a click`); 15 passed, 5 failed
restored: diff clean

### M-03at — a centre grip moves only its own object, not the whole selection
file: packages/jet_cad_2d_flutter/lib/src/select_tool.dart, `_beginDrag`, grip branch
edit: `GripDrag.move(ctx.document, ctx.selection.keys)` -> `GripDrag.move(ctx.document, [ref.key])`
test: CI=true flutter test test/select_tool_drag_test.dart
result: FIRED -- `a centre grip moves the whole selection from the grip itself (M-03at, Ruling 03-9)` [E] -- off by 19.86 (the other selected object never moved); 19 passed, 1 failed
restored: diff clean

### M-03au — a reshape drag ignores object/grid snap, always uses the raw world point
file: packages/jet_cad_2d_flutter/lib/src/select_tool.dart, `_retarget`
edit: `drag.moveTo(_dragPoint.point);` -> `drag.moveTo(drag.kind == DragKind.reshape ? world : _dragPoint.point);`
test: CI=true flutter test test/select_tool_drag_test.dart; CI=true flutter test test/planner_grips_test.dart (app)
result: FIRED -- render: `a stretch released near an endpoint lands on it exactly (M-03au)` [E] (`Expected: [7130, 3100]` `Actual: [7130.77, 3103.19]`); app: `a stretch through the shell lands exactly on an endpoint, and cmd+Z restores it with == (A1, M-03au)` [E], and `F3 turns object snap off...` also cascades red since the two tests share document state; 19 passed/1 failed (render), 0 passed/2 failed (app, before cascade)
restored: diff clean

### M-03av — a drag starts without checking its capability
file: packages/jet_cad_2d_flutter/lib/src/select_tool.dart, `_permitted`
edit: `drag != null && drag.permittedBy(ctx.document.commands.permissions)` -> `drag != null`
test: CI=true flutter test test/select_tool_drag_test.dart
result: FIRED -- `permissions at press: no leaf grips, a refused move stays a click, an instance still moves (M-03ad, M-03av)` [E] -- `Expected: ToolPhase.pressed` `Actual: ToolPhase.dragging` "a move of a selection holding a leaf needs geometry; the press stays a click"; 19 passed, 1 failed
restored: diff clean

### M-03aw — a page's fixed grid step is ignored in favour of the adaptive one
file: packages/jet_cad_2d/lib/src/index/drag_snap.dart, `dragGridStepMm`
edit: delete `if (fixed != null) return fixed;`
test: CI=true dart test test/index/drag_snap_test.dart
result: FIRED -- `dragGridStepMm: the page step exactly, else the adaptive minor (M-03aw)` [E] -- `Expected: <250>` `Actual: <50.0>` "a fixed step is used exactly at every zoom"; 8 passed, 1 failed
restored: diff clean

### M-03ax — a non-rigid transform is applied instead of refused
file: packages/jet_cad_2d/lib/src/document/grips.dart, `rigidTransformLeaf`
edit: delete the `if (!isRigidTransform(t)) { throw ArgumentError.value(...); }` statement
test: CI=true dart test test/document/rigid_transform_test.dart
result: FIRED -- `non-rigid transforms, fills and attribs are refused (M-03ax)` [E] -- `Expected: throws ArgumentError` `Actual: returned GeometryPayload` for a ×2 scale transform; 5 passed, 1 failed
restored: diff clean

## Controller-added mutants (review findings)

### M-03bc — a drag's camera listener leaks past _endDrag (Task 7 review)
Already guarded by the extended T14 (fix round b7de33a) -- no new test needed.
file: packages/jet_cad_2d_flutter/lib/src/select_tool.dart, `_endDrag`
edit: delete `(_dragCtx ?? ctx).camera.removeListener(_onCamera);`
test: CI=true flutter test test/select_tool_drag_test.dart
result: FIRED -- `a camera change mid-drag re-resolves the target from the last screen point (M-03ac)` [E] -- `Expected: <1>` `Actual: <2>` "one camera listener per live drag: _endDrag removed the first drag's (Ruling 03-7)"; 18 passed, 1 failed
restored: diff clean

### M-03bd — a centre grip's base is the resolved press point, not the grip itself (Task 7 review)
Already guarded by the M-03at test (pressed 5 px off the grip's centre) -- no new test needed.
file: packages/jet_cad_2d_flutter/lib/src/select_tool.dart, `_beginDrag`, grip branch
edit: route the centre (move) grip's base through `_moveBase(ctx, drag!)` instead of `drag!.base.setValues(ref.grip.x, ref.grip.y)`
test: CI=true flutter test test/select_tool_drag_test.dart
result: FIRED -- `a centre grip moves the whole selection from the grip itself (M-03at, Ruling 03-9)` [E] -- off by 1.315 (the base landed at the resolved 5px-off press point instead of the grip's exact world point); 18 passed, 1 failed
restored: diff clean

### M-03ay — grips.dart `_degenerateSweep`'s near-2pi branch (Task 1 review; new test)
New test: `packages/jet_cad_2d/test/document/grips_test.dart`, "an arc end stretch landing within tolerance of a full turn is degenerate (M-03ay)" -- drags the end grip of `arcPos` (start 0.3, sweep 1.9) to `start - 1e-12`, so the resulting sweep wraps to `2*pi - 1e-12`: within `Tolerance.standard.angular` of a full turn, not of zero. Asserts `reshapeLeaf` returns null.
GREEN (unmutated): CI=true dart test test/document/grips_test.dart -> 12 tests, `All tests passed!`
edit (mutant): `_degenerateSweep`: drop the `|| (2 * math.pi - a) <= Tolerance.standard.angular` disjunct
RED (mutant): CI=true dart test test/document/grips_test.dart -> `an arc end stretch landing within tolerance of a full turn is degenerate (M-03ay)` [E] (`Expected: null` `Actual: GeometryPayload`); also caught, incidentally, by the pre-existing `an arc stretch to a zero or a full sweep is null` ("the start dragged onto the end" case lands at `2*pi - eps` via floating-point round-trip through `atan2`, not exactly zero) -- 10 passed, 2 failed
restored: diff clean
GREEN (restored): CI=true dart test test/document/grips_test.dart -> 12 tests, `All tests passed!`

### M-03az — DragPoint reuse across calls (Task 3 review; new test)
New test: `packages/jet_cad_2d/test/index/drag_snap_test.dart`, "a reused DragPoint clears objectKind and grid between calls (M-03az)" -- one `DragPoint`, first `resolveDragPoint` call lands an object snap (`objectKind == SnapKind.endpoint`), second call with nothing in the aperture and no grid asserts `objectKind == null && grid == false`.
GREEN (unmutated): CI=true dart test test/index/drag_snap_test.dart -> 10 tests, `All tests passed!`
edit (mutant): `resolveDragPoint`: delete `out.objectKind = null;` and `out.grid = false;` (the per-call reset)
RED (mutant): CI=true dart test test/index/drag_snap_test.dart -> `a reused DragPoint clears objectKind and grid between calls (M-03az)` [E] -- `Expected: null` `Actual: SnapKind.endpoint`; 9 passed, 1 failed
restored: diff clean
GREEN (restored): CI=true dart test test/index/drag_snap_test.dart -> 10 tests, `All tests passed!`

### M-03ba - GripCache's hover-change skip (Task 4 review; new test)
New test: packages/jet_cad_2d_flutter/test/grip_cache_test.dart, "a hover change does not rebuild or reset hot (Ruling 03-19; M-03ba)" -- selects a line, sets grips.hot = 1, changes the selection's hover with setHover, asserts grips.hot is still 1.
GREEN (unmutated): CI=true flutter test test/grip_cache_test.dart -> 8 tests, All tests passed.
edit (mutant): _onSelection: delete the early-return guard on an unchanged key set
RED (mutant): CI=true flutter test test/grip_cache_test.dart -> hover test [E] -- Expected: 1, Actual: -1, "a hover change is not a selection-key change: rebuilding for it would reset hot under the pointer"; 7 passed, 1 failed
restored: diff clean
GREEN (restored): CI=true flutter test test/grip_cache_test.dart -> 8 tests, All tests passed.

### M-03bb - hitTest nearest wins across two different objects (Task 4 review; new test)
New test: packages/jet_cad_2d_flutter/test/grip_cache_test.dart, "hitTest picks the nearer object, not the greater handle (M-03bb)" -- two lines, far added first (lower handle), near added second (higher handle); probe sits exactly on near's vertex and about 4.4 screen px from far's. Asserts the winning grip belongs to near.
GREEN (unmutated): CI=true flutter test test/grip_cache_test.dart -> 9 tests, All tests passed.
edit (mutant): hitTest: d < bestDistance -> d > bestDistance
RED (mutant): CI=true flutter test test/grip_cache_test.dart -> M-03bb test [E] -- Expected: 19 (near's handle), Actual: 18 (far's handle); 8 passed, 1 failed
restored: diff clean
GREEN (restored): CI=true flutter test test/grip_cache_test.dart -> 9 tests, All tests passed.

### M-03be - class 3b refuse-before-toggle (Task 7 review, Ruling 03-6; new test)
New test: packages/jet_cad_2d_flutter/test/select_tool_drag_test.dart, "class 3b: a refused move never runs before the click toggles once, net (Ruling 03-6; M-03be)" -- under DraftPermissions.runtime, shift-presses an UNSELECTED line (geometry refused), crosses the slop, asserts the selection is still empty (the class 3b toggle has not run), then releases and asserts the click toggled the line in exactly once, with no command.
GREEN (unmutated): CI=true flutter test test/select_tool_drag_test.dart -> 21 tests, All tests passed.
edit (mutant): _beginDrag, unselectedBody case: move the class 3b selection toggle (ctx.selection.toggle/replace) before the _permitted(drag, ctx) check
RED (mutant): CI=true flutter test test/select_tool_drag_test.dart -> M-03be test [E] -- Expected: empty, Actual: Set:[SelectionKey( 12)] "the class 3b toggle is release-time click state; it has not run yet at the moment the slop is crossed"; 20 passed, 1 failed
restored: diff clean
GREEN (restored): CI=true flutter test test/select_tool_drag_test.dart -> 21 tests, All tests passed.

### M-03bf / M-03bf' - overlay buffer exact size (Task 8 review, Ruling 03-10; new test)
New test: packages/jet_cad_2d_flutter/test/selection_overlay_grips_test.dart, "the stretch buffer is reallocated only when the count changes, and never draws a stale grip (Ruling 03-10; M-03bf, M-03bf')" -- ONE painter instance across three frames: paint at 300 grips, reselect to 10 and paint (buffer must shrink, length == 20), paint again unchanged (must be the identical Float32List instance, not reallocated).
GREEN (unmutated): CI=true flutter test test/selection_overlay_grips_test.dart -> 7 tests, All tests passed.

M-03bf edit (mutant a): _paintGrips: `if (_stretchPoints.length != 2 * grips.stretchCount) { _stretchPoints = Float32List(...); }` -> unconditional `_stretchPoints = Float32List(2 * grips.stretchCount);` (reallocates every frame)
RED (M-03bf): CI=true flutter test test/selection_overlay_grips_test.dart -> the new test [E] -- Expected: true, Actual: false, "the count did not change between these two frames: the same Float32List instance is reused, not reallocated (M-03bf)"; 6 passed, 1 failed
restored: diff clean

M-03bf' edit (mutant b): the same guard's `!=` -> `<` (capacity-grow instead of exact-size)
RED (M-03bf'): CI=true flutter test test/selection_overlay_grips_test.dart -> the new test [E] -- Expected: 20, Actual: 600, "the buffer must shrink to the new count, not keep drawing 300 grips' worth of stale points (M-03bf')"
restored: diff clean
GREEN (restored): CI=true flutter test test/selection_overlay_grips_test.dart -> 7 tests, All tests passed.

### M-03bg - reshape preview arc, origin subtraction on the centre (Task 8 review; new test)
New test: packages/jet_cad_2d_flutter/test/selection_overlay_grips_test.dart, "an arc reshape preview's radius grip is rebased by origin too (M-03bg)" -- reshape-drags arcPos's radius grip under a non-zero rebase origin, then reads the drawn preview Path's exact start point via Path.computeMetrics().single.getTangentForOffset(0) (exact, unlike Path.getBounds()'s conic control-point approximation for a partial sweep) and compares it to the analytically expected rebased start point.
GREEN (unmutated): CI=true flutter test test/selection_overlay_grips_test.dart -> 8 tests, All tests passed.
edit (mutant): select_tool.dart, _reshapePath, arc case: Offset(c[0] - ox, c[1] - oy) -> Offset(c[0], c[1]) (drops the origin subtraction on the centre)
RED (mutant): CI=true flutter test test/selection_overlay_grips_test.dart -> M-03bg test [E] -- Expected: -62.57, Actual: 7105.43, differs by 7168.0 (the origin's own magnitude); 7 passed, 1 failed
restored: diff clean
GREEN (restored): CI=true flutter test test/selection_overlay_grips_test.dart -> 8 tests, All tests passed.

## Invariants and greps

### Step 1: the two allocation gates, unchanged

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
LOAD fills=5000 elapsed=64ms
00:00 +3: All tests passed!
```

Both invariants pass unchanged. `flutter pub get` ran as part of this
`flutter test` invocation (dependency resolution banner); `git status --short`
from the worktree root afterward showed a clean tree, so no
`analysis_options.yaml` was rewritten and none needed to be checked out.

### Step 2: the greps

```
$ git diff --stat main..HEAD -- packages/jet_cad_2d/test/invariants packages/jet_cad_2d_flutter/test/invariants
(no output)
```
Empty, as required — the invariants' tests are unedited.

```
$ git diff --stat main..HEAD -- apps/dev_harness_2d packages/jet_cad_2d/lib/src/index/spatial_index.dart \
  packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart packages/jet_cad_2d_flutter/lib/src/draft_painter.dart \
  packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
(no output)
```
Empty, as required — the frame path's files and the harness are untouched.
(`interaction_layer.dart`, changed in Task 7 for the cursor mirror, is not in
this list per the Task 7 note — it is not a frame-path file for the canvas.)

```
$ grep -n "dart:ui\|package:flutter" packages/jet_cad_2d/lib/src/document/grips.dart packages/jet_cad_2d/lib/src/index/drag_snap.dart
(no matches, exit 1)
```
Nothing, as required — the engine stays pure Dart.

```
$ grep -n "rootHandle\|accumulatedTransform" packages/jet_cad_2d_flutter/lib/src/grip_drag.dart
(no matches, exit 1)
```
Nothing, as required — the drag path never reads the root's transform.

```
$ grep -n "accumulatedTransform" packages/jet_cad_2d_flutter/lib/src/select_tool.dart packages/jet_cad_2d_flutter/lib/src/grip_cache.dart
(no matches, exit 1)
```
Nothing, as required.

```
$ awk '/void _paintGrips/,/^  }$/' packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart | grep -n "drawRect\|Rect\.\|drawRawPoints"
24:        canvas.drawRawPoints(PointMode.points, _stretchPoints, _gripPaint);
27:        canvas.drawRawPoints(PointMode.points, _movePoints, _gripMovePaint);
34:        canvas.drawRawPoints(PointMode.points, _hotPoint, _gripHotPaint);
```
Three `drawRawPoints`, no `Rect`, as required.

```
$ grep -n "scratch.point" packages/jet_cad_2d/lib/src/index/drag_snap.dart
70:  //    because the next query rewrites `scratch.point` (invariant 7).
74:      out.point.setFrom(scratch.point);
```
Two lines matched, not the one the brief's annotation names — but line 70 is
the comment explaining the invariant (it names `scratch.point` in prose), and
line 74 is the sole line of code holding it, via `setFrom`. Read in context
(`packages/jet_cad_2d/lib/src/index/drag_snap.dart:68-78`), the invariant
holds: `SnapResult.point` is copied immediately into `out.point` and never
retained past the next query. No production code changed.

```
$ grep -n "transform ==\|transform, same\|\.transform)\s*;\s*$" packages/jet_cad_2d_flutter/test/grip_drag_test.dart packages/jet_cad_2d_flutter/test/select_tool_drag_test.dart
packages/jet_cad_2d_flutter/test/grip_drag_test.dart:102:    final want = Transform2.translation(37.5, -18.75).multiply(g0.transform);
```
One match, where the brief's annotation says "nothing" — but it is a false
positive of the pattern, not a `==` comparison. Line 102
(`packages/jet_cad_2d_flutter/test/grip_drag_test.dart:91-114`) builds the
expected transform via `.multiply(g0.transform)`; the actual comparison two
lines later destructures both transforms into their six components (`a`..`f`)
and asserts each with `closeTo(..., 1e-9)` — a tolerance comparison, never
`Transform2 ==`. No production code changed.

Both deviations above are grep-pattern false positives (a comment and a
`.multiply(...)` call, respectively, both coincidentally matching the text
pattern) — not violations of the invariants they were written to catch. Read
in context, both files comply with their respective rules.
