### Task 10: Mutation testing — every named mutant, and M-03e as the designed survivor

**Files:**
- Create: `docs/superpowers/notes/plan-03-mutation-log.md`

**Interfaces:**
- Consumes: every test landed in Tasks 1–9. No code changes survive this
  task.

For each mutant in the table below, in order:
1. `cp` the file to `.superpowers/sdd/2026-09-23-grips-and-transform/mutation-backups/<basename>.<id>`.
2. Apply the one edit by hand.
3. Run **only the named test file(s)**.
4. Paste the failing test names and the summary line.
5. Restore with `cp` back from the backup.
6. Run `diff <backup> <file>` and paste the empty output.

**Never `git checkout --` a `.dart` file.** Log format per mutant:

```
### M-03a — the drag delta from a scaled screen delta, no inverse camera
file: packages/jet_cad_2d_flutter/lib/src/select_tool.dart, in `_follow`
edit: `_retarget(ctx, e.world, e.shift);` → `_retarget(ctx, Vector2(_pressWorld.x + (e.screen.dx - _start.dx) / ctx.camera.value.scale, _pressWorld.y + (e.screen.dy - _start.dy) / ctx.camera.value.scale), e.shift);`
test: CI=true flutter test test/select_tool_drag_test.dart
result: FIRED — `a body drag moves the selection under a rotated camera (M-03a)` [E]; N failed
restored: diff clean
```

- `result:` is `FIRED` (at least one named test red) or `SURVIVED`.
- Only **M-03e** is expected to survive. Any other survivor is a defect in
  a test: stop, fix the test in its own commit on this branch, re-fire the
  mutant, and log both runs.
- A mutant that does not compile does not count as fired: re-express the
  same idea so it compiles, and log both attempts (Ruling 04-18's
  precedent).

**The spec's named mutants.** Paths are under `packages/jet_cad_2d/` for
engine files and `packages/jet_cad_2d_flutter/` for render files; the test
paths are relative to the same package.

| id | file | edit (old → new) | test file → test that must go red |
|---|---|---|---|
| M-03a | `lib/src/select_tool.dart` `_follow` | `_retarget(ctx, e.world, e.shift);` → `_retarget(ctx, Vector2(_pressWorld.x + (e.screen.dx - _start.dx) / ctx.camera.value.scale, _pressWorld.y + (e.screen.dy - _start.dy) / ctx.camera.value.scale), e.shift);` | `test/select_tool_drag_test.dart` → T2 "a body drag moves the selection under a rotated camera" |
| M-03b | engine `lib/src/index/spatial_index.dart` `_considerSnapCandidate` | the `final better = …;` expression → `final better = _bestSnapKind == null \|\| dist < _bestSnapDist \|\| (dist == _bestSnapDist && kindIndex < _bestSnapKind!.index);` | engine `test/index/drag_snap_test.dart` → S5 "kind decides between object snaps through a drag"; also log `snap_test.dart`'s own kind-priority tests, which go red too |
| M-03c | `lib/src/grip_drag.dart` `command`, the `_NodeCapture` case | the body → `if (node is InstanceNode) { for (final slot in document.leavesByOwner()[node.definition] ?? const <int>[]) { members.add(SetEntityGeometryCommand(document.entities.handleAt(slot), rigidTransformLeaf(document.entities.kindAt(slot), document.geometry.read(document.entities.geomIndexAt(slot)), t))); } } else { members.add(TransformNodeCommand(handle, t.multiply(node.transform))); }` | `test/grip_drag_test.dart` → D3 "an instance move rewrites the instance node, never the definition" |
| M-03d | `lib/src/select_tool.dart` `_follow` | append after `_retarget(…);`: `final c = _drag!.command(ctx.document.commands.permissions); if (c != null) ctx.execute(c);` | `test/select_tool_drag_test.dart` → T3 "no command during a drag…" |
| M-03e | `test/grip_drag_test.dart` D10 | `expect(payloadOf(doc, s.line), payloads[s.line]);` → `expect(payloadsClose(payloadOf(doc, s.line), payloads[s.line]!), isTrue);`, and the same for `s.arcNeg` | **must stay green**: log `SURVIVED — designed (spec D11)`. The companion D11 ("the undo assertion enforces ==: one ulp is caught") is green in the unmutated suite and shows `==` failing and `Tolerance` passing on a one-ulp nudge. Paste D11's result beside it. |
| M-03f | engine `lib/src/index/drag_snap.dart` step 1 | swap the two branch bodies: the `>=` branch pins `cx = base.x; pinX = true;` and the else branch pins `cy = base.y; pinY = true;` | `test/index/drag_snap_test.dart` → S2; `test/select_tool_drag_test.dart` → T6 |
| M-03g | engine `lib/src/index/drag_snap.dart` step 2 | inside `if (scratch.found) {`, before the copy, insert: `if (page != null && page.snapToGrid && gridStepMm != null) { final g = snapToGrid(raw, gridStepMm, page); if (g.distanceTo(raw) < scratch.point.distanceTo(raw)) { out.point.setFrom(g); out.grid = true; return; } }` | `test/index/drag_snap_test.dart` → S4 "an object snap beats a nearer grid point" |
| M-03h | engine `lib/src/document/grips.dart` `rigidTransformLeaf`, arc | delete `if (scalars.length >= 2) scalars[1] = scalars[1] + theta;` | `test/document/rigid_transform_test.dart` → R2 and R6 (the differential); render `test/grip_drag_test.dart` → D4 |
| M-03i | `lib/src/grip_drag.dart` `command` | `TransformNodeCommand(handle, t.multiply(node.transform))` → `TransformNodeCommand(handle, node.transform.multiply(t))` | `test/grip_drag_test.dart` → D2 "a rotated group moves by T.multiply(node.transform)" |
| M-03j | `lib/src/select_tool.dart` `_beginDrag`, rotation grip | `final pivot = Vector2((box.minX + box.maxX) / 2, (box.minY + box.maxY) / 2);` → `final pivot = Vector2.zero();` | `test/select_tool_drag_test.dart` → T11 "a rotation turns about the selection box centre…" |
| M-03k | `lib/src/grip_drag.dart` `command` | `if (members.any((m) => !m.capabilities.every(permissions.allows))) { return null; }` → `members.removeWhere((m) => !m.capabilities.every(permissions.allows)); if (members.isEmpty) return null;` | `test/grip_drag_test.dart` → D8 "a refused member cancels the whole drag" |
| M-03l | `lib/src/select_tool.dart` `onKey`, the dragging block | before `cancel(ctx);` insert `final c = _drag?.command(ctx.document.commands.permissions); if (c != null) ctx.execute(c);` | `test/select_tool_drag_test.dart` → T15 "…Escape cancels byte-identically" |
| M-03m | engine `lib/src/document/grips.dart` `rigidTransformLeaf`, text | `scalars[1] = scalarOr(payload, 1, 0) + theta;` → `scalars[1] = scalarOr(payload, 1, 0);` | `test/document/rigid_transform_test.dart` → R3 and R6 |
| M-03n | engine `lib/src/document/grips.dart` `reshapeLeaf`, arc end | `nextSweep = _wrapSweep(a - start, sweep);` → `nextSweep = _wrapSweep(a - start, 1.0);` | `test/document/grips_test.dart` → "an arc end stretch on a negative sweep stays negative" |
| M-03o | engine `lib/src/document/grips.dart` `reshapeLeaf`, line/polyline | `coords[i * 2] = localTarget.x; coords[i * 2 + 1] = localTarget.y;` → `coords[(i + 1) * 2] = localTarget.x; coords[(i + 1) * 2 + 1] = localTarget.y;` | `test/document/grips_test.dart` → "a polyline middle-vertex stretch…" |
| M-03p | `lib/src/grip_drag.dart` `command` | delete the `if (kind == DragKind.move && target.x - base.x == 0 && target.y - base.y == 0) { return null; }` statement | `test/grip_drag_test.dart` → D6; `test/select_tool_drag_test.dart` → T4 |
| M-03q | engine `lib/src/index/drag_snap.dart` step 3 | delete `if (pinY) out.point.y = base!.y;` and `if (pinX) out.point.x = base!.x;` | `test/index/drag_snap_test.dart` → S6 "a grid snap re-pins the ortho axis afterwards" |
| M-03r | engine `lib/src/document/grips.dart` `reshapeLeaf` | delete the `if (i == 0 && kind == EntityKind.polyline && isClosedPolyline(payload)) { … }` block | `test/document/grips_test.dart` → "a closed room corner moves as one…" |
| M-03s | `lib/src/select_tool.dart` `_moveBase` | `_resolve(ctx, _pressWorld, null);` → `resolveDragPoint(raw: _pressWorld, orthoBase: null, index: ctx.index, apertureWorld: kSnapAperturePixels / ctx.camera.value.scale, objectSnap: ctx.snap?.objectSnap ?? true, page: null, gridStepMm: null, scratch: _snapScratch, out: _dragPoint);` | `test/select_tool_drag_test.dart` → T5 "with grid snap on, on-grid geometry stays on the grid" |
| M-03t | `lib/src/grip_drag.dart` `command` | delete `if (!_revalidate()) return null;` | `test/grip_drag_test.dart` → D7; `test/select_tool_drag_test.dart` → T17 |
| M-03u | `lib/src/selection_overlay.dart` `_paintPreview` | `final pe = t.a * origin.x + t.c * origin.y + t.e;` → `final pe = t.e + origin.x;` and `final pf = t.b * origin.x + t.d * origin.y + t.f;` → `final pf = t.f + origin.y;` (that is `matrix ∘ T`) | `test/selection_overlay_grips_test.dart` → P1 "the move/rotate preview is drawn through worldToScreen ∘ T ∘ translate(origin)" |
| M-03v | `lib/src/selection_overlay.dart` `_paintGrips` | replace both `drawRawPoints` calls with per-grip loops: `for (var j = 0; j < s; j += 2) { canvas.drawRect(Rect.fromCenter(center: Offset(_stretchPoints[j], _stretchPoints[j + 1]), width: kGripPixels, height: kGripPixels), _gripPaint); }`, and the same over `_movePoints`/`mv` with `_gripMovePaint` (add `Rect` to the `dart:ui` show list) | `test/selection_overlay_grips_test.dart` → P2 "grips are one drawRawPoints per colour at 10 grips and at 300…" |
| M-03w | `lib/src/grip_drag.dart` | `const double kRotationStep = math.pi / 12;` → `math.pi / 6` | `test/select_tool_drag_test.dart` → T12 "shift steps the rotation by 15°" |
| M-03x | engine `lib/src/index/drag_snap.dart` step 2 | `if (objectSnap) {` → `if (true) {` | engine `test/index/drag_snap_test.dart` → S7; app `test/planner_grips_test.dart` → A2 |
| M-03y | engine `lib/src/document/grips.dart` `leafGrips`, circle | `for (var q = 0; q < 4; q++)` → `q < 3` | `test/document/grips_test.dart` → "the grip set per kind…"; render `test/grip_cache_test.dart` → C1 |
| M-03z | `lib/src/grip_cache.dart` `_rebuild` | `if (_grips.length > kMaxGrips)` → `>= kMaxGrips` | `test/grip_cache_test.dart` → C4 "the cap…" |
| M-03aa | `lib/src/select_tool.dart` `onKey` | delete the `return KeyEventResult.handled;` that ends the dragging block | `test/select_tool_drag_test.dart` → T15; app `test/planner_grips_test.dart` → A4 |

**The plan's mutants (Ruling 03-17).** They are recorded in the spec's
Testing section at Task 12.

| id | file | edit (old → new) | test that must go red |
|---|---|---|---|
| M-03ab | `lib/src/interaction_layer.dart` `build` | replace the `ListenableBuilder(…)` with `MouseRegion(cursor: _tool.cursor, onExit: _onExit, child: Listener(…the same Listener…))` | `test/interaction_cursor_test.dart` → I1 |
| M-03ac | `lib/src/select_tool.dart` `_enter` | delete `ctx.camera.addListener(_onCamera);` | `test/select_tool_drag_test.dart` → T14 |
| M-03ad | `lib/src/grip_cache.dart` | `bool get leafGripsLive => document.commands.permissions.allows(Capability.geometry);` → `bool get leafGripsLive => true;` | `test/grip_cache_test.dart` → C5; `test/select_tool_drag_test.dart` → T13; `test/selection_overlay_grips_test.dart` → P4 |
| M-03ae | `lib/src/selection_overlay.dart` `_drawPointCross` | delete `px = tx;` and `py = ty;` | `test/selection_overlay_grips_test.dart` → P5 |
| M-03af | app `lib/main.dart` | `SingleActivator(LogicalKeyboardKey.f3, includeRepeats: false)` → `SingleActivator(LogicalKeyboardKey.f3)` | app `test/planner_grips_test.dart` → A3 |
| M-03ag | `lib/src/snap_marker.dart` | swap the bodies of `case SnapKind.endpoint:` and `case SnapKind.midpoint:` | `test/snap_marker_test.dart` → K1 |
| M-03ah | `lib/src/outline_cache.dart` `worldBoundsOf` | `box = box.union(arcBounds(Vector2(cx, cy), r, start, sweep));` → `box = box.union(Aabb2.raw(cx - r, cy - r, cx + r, cy + r));` | `test/outline_cache_test.dart` → O1; `test/grip_cache_test.dart` → C2 |
| M-03ah′ | `lib/src/outline_cache.dart` `worldBoundsOf` | the `_Point` case's body → `break;` | `test/outline_cache_test.dart` → O1; `test/grip_cache_test.dart` → C2 |
| M-03ai | `lib/src/grip_cache.dart` `hitTest` | `(h > bestHandle \|\|` → `(h < bestHandle \|\|` | `test/grip_cache_test.dart` → C6; `test/select_tool_drag_test.dart` → T10 |
| M-03aj | `lib/src/select_tool.dart` `_reshapePath` | `final ox = origin.x, oy = origin.y;` → `final ox = 0.0, oy = 0.0;` | `test/selection_overlay_grips_test.dart` → P6 |
| M-03ak | `lib/src/grip_cache.dart` `rotationGripOf` | `minY - kRotationGripOffset` → `minY + kRotationGripOffset` | `test/grip_cache_test.dart` → C7 |
| M-03al | `lib/src/grip_cache.dart` constructor | delete `outlines.addListener(_rebuild);` | `test/grip_cache_test.dart` → C3 |
| M-03am | `lib/src/grip_drag.dart` `_capture` | `if (kind == EntityKind.fill \|\| kind == EntityKind.attrib) continue;` → `if (kind == EntityKind.attrib) continue;` | `test/grip_drag_test.dart` → D9 |
| M-03an | `lib/src/grip_drag.dart` `_capture` | delete `..sort((a, b) => a.target.value.compareTo(b.target.value))` | `test/grip_drag_test.dart` → D1 |
| M-03ao | `lib/src/select_tool.dart` `cancel` | before `_endDrag(ctx);` insert `final pending = _drag?.command(ctx.document.commands.permissions); if (pending != null) ctx.execute(pending);` | `test/select_tool_drag_test.dart` → T16, W1 and W3 |
| M-03ap | `lib/src/interaction_layer.dart` `_onExit` | delete `if (_activePointer != -1) return;` | `test/select_tool_drag_test.dart` → W2; also log 02's `interaction_layer_test.dart` "a drag that leaves the box keeps its captured pointer" |
| M-03aq | `lib/src/selection_overlay.dart` `_paintGrips` | delete the `if (hot >= 0 && hot < list.length) { … }` block | `test/selection_overlay_grips_test.dart` → P2 |
| M-03ar | `lib/src/select_tool.dart` `_paintGuide` | `drawSnapMarker(canvas, b, …)` → `drawSnapMarker(canvas, _lastScreen, …)` | `test/selection_overlay_grips_test.dart` → P8 |
| M-03as | `lib/src/select_tool.dart` `_classify` | `if (i >= 0) { _pressGrip = i; return PressClass.grip; }` → `if (i >= 0) { _pressGrip = i; }` | `test/select_tool_drag_test.dart` → T1 |
| M-03at | `lib/src/select_tool.dart` `_beginDrag`, grip branch | `GripDrag.move(ctx.document, ctx.selection.keys)` → `GripDrag.move(ctx.document, [ref.key])` | `test/select_tool_drag_test.dart` → T8 |
| M-03au | `lib/src/select_tool.dart` `_retarget` | `drag.moveTo(_dragPoint.point);` → `drag.moveTo(drag.kind == DragKind.reshape ? world : _dragPoint.point);` | `test/select_tool_drag_test.dart` → T9; app `test/planner_grips_test.dart` → A1 |
| M-03av | `lib/src/select_tool.dart` `_permitted` | `drag != null && drag.permittedBy(ctx.document.commands.permissions)` → `drag != null` | `test/select_tool_drag_test.dart` → T13 |
| M-03aw | engine `lib/src/index/drag_snap.dart` `dragGridStepMm` | delete `if (fixed != null) return fixed;` | engine `test/index/drag_snap_test.dart` → S8 |
| M-03ax | engine `lib/src/document/grips.dart` `rigidTransformLeaf` | delete the `if (!isRigidTransform(t)) { throw … }` statement | engine `test/document/rigid_transform_test.dart` → R5 |

- [ ] **Step 1: Fire the spec's twenty-seven.** Work through M-03a…M-03aa
  in table order and write each one into the log. After M-03e, paste D11's
  green result.
- [ ] **Step 2: Fire the plan's twenty-three.** Work through
  M-03ab…M-03ax, including `ah′`.
- [ ] **Step 3: The tally.** At the log's head, record: fired N, killed N
  − 1, survived 1 (M-03e, designed), equivalent 0. Then check the tree is
  clean of mutations: `git status --short` must list only the new log.
- [ ] **Step 4: Commit.**

```bash
git add docs/superpowers/notes/plan-03-mutation-log.md
git commit -m "$(cat <<'EOF'
docs: Plan 03 mutation log -- 27 named and 23 plan mutants

Every spec mutant M-03a..aa fired and killed except M-03e, the designed
survivor, whose one-ulp companion shows == is what the undo test enforces;
the plan's M-03ab..ax (Ruling 03-17) each killed by the test it guards.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

