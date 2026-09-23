# Grips and transform spec — review round 1

**Spec:** [2026-09-23-grips-and-transform-design.md](../specs/2026-09-23-grips-and-transform-design.md),
revision 1 at `b6bb508`. **Reviewers, 2026-09-23, independent, read-only, one prompt:**
- Codex CLI (`gpt-5.5`): 14 findings, 2 BLOCKER, 8 MAJOR and 4 MINOR.
- An Opus subagent: 28 findings, 1 BLOCKER, 7 MAJOR and 20 MINOR.

Every finding was re-checked against the tree before it was ruled on. The
two reviewers overlap on seven. All are applied in revision 2, and none was
rejected. The raw reports follow the table verbatim.

| # | finding (source) | verified | ruling in revision 2 |
|---|---|---|---|
| 1 | **The root's transform is not in the world mapping.** The canvas, the index and the oracle descend from `identity`, so conjugating by it is wrong, and M-03r was the correct behaviour (Opus B1; Codex M3 is a symptom) | yes: `container_index.dart` 176, `spatial_index.dart` 1484, `reference_walk.dart` 42-43 | world is root space; conjugation and the old M-03r dropped; the fixture keeps the root at the identity; the `OutlineCache`/`TileCache` disagreement recorded as debt |
| 2 | **An undo can land mid-drag**, and release then overwrites the undone state or throws (Codex B2, Opus M3) | yes: `main.dart` 62-70, `select_tool.dart` 218-236 | D5: every key-down is consumed during a drag; D4: release revalidation against press-time captures; M-03t and M-03aa |
| 3 | **The selection box came from `Path.getBounds`**: an arc gives its control-point bounds, a point gives `Rect.zero`, and the origin can be stale (Codex B1, Opus M6) | yes: `outline_cache.dart` 151-157, 258-266 | `OutlineCache.worldBoundsOf` in doubles, arcs by `arcBounds` |
| 4 | The preview used `matrix ∘ T`; it must be `worldToScreen ∘ T ∘ translate(origin)` (Codex M4, Opus M5) | yes: `selection_overlay.dart` 53-87 | D7; M-03u |
| 5 | Pointer exit cannot cancel: the layer never forwards it while captured (Codex M6, Opus M2) | yes: `interaction_layer.dart` 157-160; 02's amended rule | dropped; cancel paths listed; a drag past the edge continues |
| 6 | The cursor needs a rebuild, not a repaint (Codex M7, Opus m15) | yes: `interaction_layer.dart` 185-201 | a `ListenableBuilder` around the `MouseRegion` |
| 7 | A camera change mid-drag does not re-resolve until the next pointer event (Codex M5, Opus m14) | yes: camera-owned moves are dropped (`interaction_layer.dart` 97, 108-109) | the tool listens to the camera during a drag and re-resolves from the last screen point |
| 8 | The exact-stretch claim was conditional on the root identity, against a fixture that required non-identity (Codex M8) | yes | moot after #1 |
| 9 | M-03r's fixture was degenerate for a pure-translation root (Codex M9) | yes | moot after #1; M-03r reassigned (closed polyline) |
| 10 | M-03e "stays green" contradicted gate 13's "killed" (Codex M10) | yes | M-03e is the designed survivor with a 1-ulp companion check; gate 13 says so |
| 11 | Labels: unwrapped commands cannot say `Rotate` or `Stretch` (Codex m11, Opus m17) | yes: `commands.dart` 288, 452 | always one `CompoundCommand` |
| 12 | F3 repeats on key repeat (Codex m12) | yes: `SingleActivator.includeRepeats` defaults to true | `includeRepeats: false` |
| 13 | Evidence: owner space cited at the wrong file (Codex m13) | yes | cites `entity_store.dart` 34-36 and `node.dart` 12-13 |
| 14 | Evidence: Delete's preflight is per key and skips, it is not all or nothing (Codex m14) | yes | reworded |
| 15 | M-03p could not go red with a click fixture (Opus M4) | yes: a click never starts a drag | past the slop and back; snap back onto the base |
| 16 | A closed polyline's corner stretch tears the loop (Opus M7) | yes: `triangulate.dart` 5-8, 28 | closed rule in D3; new M-03r |
| 17 | The body-drag base skipped the grid, so moves left the grid (Opus M8) | yes: `page_component.dart` 107 default `true` | base resolved by the same chain without ortho; M-03s |
| 18 | "Selected body before unselected" cannot be done with a single pick (Opus m9) | yes | the single pick decides, stated |
| 19 | Shift is both toggle and ortho (Opus m10) | yes | stated and tested |
| 20 | Clicks at a grip change 02 behaviour (Opus m11) | yes | listed in D12 |
| 21 | Coincident grips of two objects split a joint (Opus m12) | yes | stated as v1's rule; joints belong to 07 |
| 22 | Permissions only at release gave silent snap-backs under `runtime` (Opus m13) | yes: `command.dart` 57 | checked at press as well |
| 23 | `Transform2` has no `==` (Opus m16) | yes: `transform2.dart` 123-126 | nodes compared with `Node ==`, payloads with `GeometryPayload ==` |
| 24 | The arc's derived end angle is not bit-equal (Opus m18) | yes | within `Tolerance`, stated |
| 25 | The differential's absolute `1e-9` fails at 2e6 (Opus m19) | yes: `tolerance.dart` 23 | a magnitude-scaled tolerance, stated |
| 26 | Per-grip `Rect`/`Offset` allocation, and nothing gates the overlay (Opus m20) | yes | `drawRawPoints` from a reused buffer; invariant 6; M-03v |
| 27 | Gates without a named mutant (Opus m21) | yes | M-03w, x, y, z added |
| 28 | Ortho is world-axis, which looks diagonal under a rotated camera (Opus m22) | yes | stated as deliberate |
| 29 | The widget tests need a shell seam and must set the camera after the first pump (Opus m23) | yes: `planner_view.dart` 67-87 | the test seam in Architecture |
| 30 | `DragPoint.point` is final, so assigning it does not compile (Opus m24) | yes | `setFrom` throughout |
| 31 | A fixed `gridStepMm` makes the snap skip drawn minors (Opus m25) | yes: `grid_scale.dart` 89-93 | 04's rule kept; an item for the look |
| 32 | The preview missed points, and the reshape preview's space was unstated (Opus m26) | yes: `selection_overlay.dart` 129-154 | `T(worldPointOf)`; the reshape is drawn in rebased world under the overlay matrix |
| 33 | Rotation-grip details were unaligned (Opus m27) | yes | hit radius, fills-only selections and `grips == null` all stated |
| 34 | Evidence line numbers were off by one or two (Opus m28) | yes, claims true | corrected |

---

## Codex CLI — raw report

1. BLOCKER: D6 — selection box construction is not implementable as stated and gives wrong arc boxes — evidence: `OutlineCache.pathFor` is origin-rebased (`packages/jet_cad_2d_flutter/lib/src/outline_cache.dart:98`, `:103`) while the painter’s origin is per-frame (`selection_overlay.dart:79`-`:87`), and `OutlineCache` itself says `Path.getBounds()` is not a valid arc oracle (`outline_cache.dart:149`-`:155`) — suggested fix: expose/cache exact world bounds from `_Outline` data, using `arcBounds`, not `ui.Path.getBounds()`.

2. BLOCKER: D5/D10 — undo or an external document change can land mid-drag and leave `GripDrag` holding stale handles/payloads — evidence: `SelectTool.onKey` ignores non-Escape keys during drag (`select_tool.dart:218`-`:235`), the shell undo shortcut then bubbles and runs (`apps/floor_planner/lib/main.dart:102`-`:106`; Flutter focus propagation at `focus_manager.dart:2275`-`:2301`), and document/selection listeners are async (`undo.dart:51`-`:63`, `selection.dart:146`-`:162`) — suggested fix: cancel/block active drags on undo/redo/external `DocChange`, or add a document generation check and refuse release if anything changed.

3. MAJOR: D3/D4 — root-transform conjugation conflicts with `rigidTransformLeaf` for valid non-rigid root transforms — evidence: `Transform2` and node transforms are full affine (`transform2.dart:15`-`:22`, `node.dart:26`), the root is a normal `GroupNode` (`tree.dart:61`-`:62`), but `rigidTransformLeaf` rejects non-rigid `T_root`; `R^-1 * rotate * R` is non-rigid when `R` has non-uniform scale/shear — suggested fix: specify unsupported/cancel behavior for rotating root leaves under non-rigid ancestors, or restrict the editable root transform fixture to a rigid rotation/translation.

4. MAJOR: D7 — `matrix ∘ T` is the wrong preview order for rebased selection paths — evidence: paths are stored as `world - origin` (`outline_cache.dart:98`-`:107`) and current overlay matrix is effectively `camera * translate(origin)` (`selection_overlay.dart:79`-`:87`); with `Transform2.multiply` applying the argument first (`transform2.dart:58`-`:62`), `matrix.multiply(T)` rotates about the rebased origin, not the world pivot — suggested fix: draw preview with `camera * T * translate(origin)`, or conjugate `T` into rebase space before multiplying by the existing matrix.

5. MAJOR: D5 — “camera change mid-drag keeps the object under the pointer” is only true after a later pointer event — evidence: camera pan/zoom mutates the camera in `CameraGestureDetector` (`camera_gesture_detector.dart:56`-`:68`), while `ToolPointerEvent.world` is recomputed only when `InteractionLayer` receives pointer events (`interaction_layer.dart:80`-`:95`) — suggested fix: during a drag, store the last screen point and recompute the drag target on camera notifications, or weaken the claim/test.

6. MAJOR: D5 / exit gate 9 — pointer-exit cancel contradicts the current interaction layer — evidence: `InteractionLayer._onExit` deliberately returns while a pointer is active (`interaction_layer.dart:150`-`:160`), so `SelectTool.onPointerExit` cancel logic (`select_tool.dart:205`-`:208`) is unreachable for an ordinary drag exit — suggested fix: either change `InteractionLayer` and update 02 expectations, or remove pointer-exit cancel from the spec and rely on pointer cancel/deactivate.

7. MAJOR: D5 — cursor updates will not follow tool notifications if implemented literally — evidence: `InteractionLayer.build` creates a `MouseRegion` but does not listen to `ToolController` (`interaction_layer.dart:185`-`:200`); Flutter applies cursor changes via `MouseRegion.updateRenderObject` (`basic.dart:7467`-`:7474`) and `RenderMouseRegion.cursor` (`proxy_box.dart:3401`-`:3408`) — suggested fix: wrap the `MouseRegion` in a `ListenableBuilder`/state listener on `ToolController`.

8. MAJOR: D8 / Testing / exit gate 10 — exact snapped stretch is qualified on root identity but the fixture rule requires non-identity root transforms for root leaves — evidence: D8 says exact `==` only with “root transform identity” (`docs/superpowers/specs/2026-09-23-grips-and-transform-design.md:382`-`:384`), while the fixture rule requires non-identity root transforms (`:492`-`:497`) and the exit gate repeats exact landing without the qualification (`:560`-`:562`) — suggested fix: run exact snap-stretch tests under identity owner-to-world transform, and use tolerance or a separate conjugation test under non-identity root.

9. MAJOR: M-03r — “non-identity root transform” is a degenerate mutant fixture — evidence: D4 says any non-identity `R` makes skipped conjugation red (`docs/...grips-and-transform-design.md:229`-`:230`), but a pure root translation is non-identity and commutes with move translations, so `T_root == T` — suggested fix: require a non-commuting rigid root transform, e.g. a rotation not equal to 0 or 180 degrees, plus a nonzero drag delta.

10. MAJOR: M-03e / exit gate 13 — the named mutant table says M-03e must stay green, but the exit gate requires every named mutant to be killed or declared equivalent — evidence: M-03e row says “stays green” (`docs/...grips-and-transform-design.md:507`), while exit gate 13 requires M-03a…r killed/equivalent (`:565`-`:566`) — suggested fix: split M-03e into an expected-survivor audit plus a killed 1-ulp perturbation mutant, or exempt it explicitly.

11. MINOR: D4 — the specified command labels cannot be produced for unwrapped single-object commands with existing APIs — evidence: `TransformNodeCommand.label` is always `Move` (`commands.dart:287`-`:288`), `SetEntityGeometryCommand.label` is always `Edit geometry` (`commands.dart:450`-`:451`), and only `CompoundCommand` accepts a custom label (`commands.dart:735`-`:739`) — suggested fix: drop the label promise for unwrapped commands or add label overrides/new commands.

12. MINOR: D10 — F3 will toggle repeatedly on key repeat if bound with default `SingleActivator` — evidence: Flutter `SingleActivator` defaults `includeRepeats = true` (`shortcuts.dart:444`-`:462`) and accepts `KeyRepeatEvent` when enabled (`shortcuts.dart:576`-`:578`) — suggested fix: bind F3 with `includeRepeats: false` and test a repeat event.

13. MINOR: Evidence of record — `GeometryPayload` owner-space citation is off — evidence: the cited `geometry_store.dart:16` only defines the class and its `coords` comment says document units (`geometry_store.dart:16`-`:18`); owner-space is stated on `EntityRecord.owner` (`entity_store.dart:34`-`:36`) and `Node` (`node.dart:12`-`:13`) — suggested fix: cite those lines instead.

14. MINOR: Evidence of record — `_deleteSelection` is not a whole-list all-or-nothing permission preflight — evidence: refused delete keys are skipped (`select_tool.dart:284`-`:288`) and the permitted commands still execute as one compound (`select_tool.dart:294`-`:296`) — suggested fix: reword the evidence to “per-key preflight, skipped refused keys, one compound for permitted commands.”

---

## Opus subagent — raw report

# Review — docs/superpowers/specs/2026-09-23-grips-and-transform-design.md (revision 1)

Reviewer: Opus, read-only, tree at `b6bb508` (spec commit on top of `c1f9877`).
Every finding below was checked against the code; file:line references are to that tree.

Counts: BLOCKER 1, MAJOR 7, MINOR 20.

---

1. **BLOCKER: D4 (root conjugation), D6 (grips "mapped through the root's transform"), D8 Exactness, Testing fixture rule, M-03r.** The spec assumes the root `GroupNode`'s `transform` is part of the world mapping. It isn't: the canvas, the spatial index, picking, snapping and the reference oracle all ignore it. "World" as drawn and queried is root space with the root's own transform left out. The conjugation `T_root = R⁻¹·T·R` is therefore wrong. So is mapping grips through `R`. The fixture rule "non-identity root transform where the test touches root leaves" makes the correct implementation fail and the spec-correct one draw grips and previews off the geometry.
   — evidence:
   - `container_index.dart:176`: the root container is built from `(container, Transform2.identity())`, and the root node's own transform is never read.
   - `spatial_index.dart:1484`: `_descend(root, Transform2.identity(), …)` for `snapInto`, and `pickInto` is the same.
   - `draft_painter.dart:369`: the canvas draws through `index.forEachInRect` over the root container.
   - `reference_walk.dart:42-43`: the oracle also starts `container(doc.rootHandle, Transform2.identity(), …)`.
   - The codebase is already inconsistent. `outline_cache.dart:281-294` draws root groups and instances through `tree.accumulatedTransform`, which includes `R` because `ancestorsOf` (`tree.dart:240-257`) walks up to the root. Root leaves get `Transform2.identity()` (`outline_cache.dart:292-294`). `tile_cache.dart:2096,2127` also includes `R`.

   Reachability, with the spec followed literally and `R` a rotation:
   - A root leaf's grip is drawn at `R·p` while the line is drawn at `p`, so grip hit-testing (D2 class 2) misses what the user sees.
   - A move of a root leaf writes `R⁻¹TR·x`, which the canvas draws as `R⁻¹TR·x`, not `T·x`.
   - A snapped stretch writes `R⁻¹·(snap point)`, and D8's "lands exactly" fails.
   - With a non-uniform or sheared `R`, `R⁻¹·Rot·R` is not rigid, so `rigidTransformLeaf` throws `ArgumentError` on every rotate of a root leaf.
   - M-03r's "mutant" (no conjugation) is the behaviour that matches the renderer.

   — suggested fix: state that world is root space and that the root's transform is not applied by the canvas, index or oracle. Drop the conjugation, `L = T_root` and M-03r. Map grips with no `R`. Remove "non-identity root transform" from the fixture rule. Separately, pin `R == identity` (a `validate` check, or refuse `TransformNodeCommand` on the root), or fix the latent `OutlineCache` and `TileCache` disagreement as its own task. Do not build 03 on either reading.

2. **MAJOR: D5 Escape paragraph, Invariant 2, Exit gate 9.** "**Pointer exit** during a drag cancels too (02's rule for the band)" is factually wrong. 02 amended that rule to the opposite, and the layer never forwards an exit while a pointer is captured.
   — evidence:
   - `interaction_layer.dart:157-160`: `_onExit` returns when `_activePointer != -1`.
   - `docs/superpowers/specs/2026-09-21-interaction-core-design.md:586-590`: the "exit while dragging" clause is superseded, and a band dragged past the edge continues.
   - `interaction_layer_test.dart:378-400`: "a drag that leaves the box keeps its captured pointer" pins this.

   Reachability: gate 9's pointer-exit test, driven through `InteractionLayer` as the Widget-tests section requires, can never reach `SelectTool.onPointerExit` during a drag. An implementer who "fixes" `_onExit` to make the gate pass breaks 02's pinned test and makes a move stop at the canvas edge.
   — suggested fix: drop pointer exit as a cancel path. List the real cancel paths instead: Escape, `PointerCancelEvent` (`interaction_layer.dart:138-143`), `ToolController.activate`, and layer `deactivate`/`dispose`. Gate 9 then tests Escape and pointer-cancel.

3. **MAJOR: D5 and D4 (no rule for a document change mid-drag).** Undo is reachable during a drag, and the spec says nothing about it.
   — evidence: `main.dart:68-70`: `_undo` does not look at the tool phase. `main.dart:62-67`: Z bubbles past the `InteractionLayer` focus because `SelectTool.onKey` ignores it (`select_tool.dart:218-236`). The user holds the mouse and presses cmd+Z.

   Reachability:
   - A reshape built from the payload captured at press overwrites the undone state on release. The undo is silently reverted, and a new undo entry buries it.
   - If the undo removed a dragged entity, `SetEntityGeometryCommand.apply` throws `StateError('no entity with handle …')` (`commands.dart:455-457`). Inside a `CompoundCommand` this rolls back and rethrows out of `onPointerUp`.
   - `SelectionController`'s prune (`selection.dart`, async `document.changes`) also removes keys the drag still holds.

   — suggested fix: add a rule. Either any `DocChange` observed while `phase != idle` cancels the drag (GripDrag records `undoDepth` or a change counter at press and refuses release if it moved), or the shell's undo calls `tools.active.cancel` first. Name a mutant for it.

4. **MAJOR: Named mutants, M-03p.** The prescribed fixture, "the click-without-move test: undo depth unchanged", cannot kill M-03p ("release with Δ == 0 still dispatches").
   — evidence: D2 says a press that never passes `kBandSlopPixels` is "the existing click": no drag starts, and `onPointerUp` in phase `pressed` only selects (`select_tool.dart:96-102`). The release-with-Δ path is never reached, so the mutated line is never executed.
   — suggested fix: the fixture must move past the slop and return to the press pixel. Under an unchanged camera, `screenToWorld` of the same pixel is bit-identical, so Δ is exactly 0. Also add a case where snapping makes the target equal the base. Keep the pure click as a separate 02 regression test.

5. **MAJOR: D7 (move/rotate preview transform order).** "The selection's cached outlines drawn a second time through `matrix ∘ T`" is wrong for rotation. The overlay's `matrix` is `worldToScreen ∘ translate(origin)` (`selection_overlay.dart:53-87`), and the cached paths hold `world − origin` (`outline_cache.dart:245-255`). The correct composite is `worldToScreen ∘ T ∘ translate(origin)`. `matrix ∘ T` applies `T` to rebased coordinates. For a pure translation this is harmless because it commutes with `translate(origin)`. For a rotation the preview is displaced by `(I − Rot θ)·origin`.

   Reachability: the origin is `rebaseOriginFor(visibleWorld)` (`camera_controller.dart:18-33`). It is non-zero whenever the view is away from world zero, which the fixture rule requires. No named mutant or test covers the preview, so this would first show up in the human look.
   — suggested fix: specify the preview matrix as `worldToScreen ∘ T ∘ translate(origin)`, computed in doubles and refilled per frame into a second reused `Float64List`. Add a mutant (`matrix ∘ T`) with a test that reads the recorded canvas transform under a non-zero origin and a rotation.

6. **MAJOR: D6 (selection box from `ui.Path.getBounds`), and through it the rotation pivot (D4, gate 6) and the rotation-grip placement.**
   - `getBounds` returns the bounds of the conic **control points**, not of the curve. The repo documents this itself: `outline_cache.dart:151-157` measured a 2.6 rad arc reading `maxX = 19.1` against a true 17.0. So any selection containing an arc gets a box larger than its outline and a pivot that is not the box centre.
   - A selected `point` entity has an **empty** path (`outline_cache.dart:258-266`: `case _Point(): continue;`, then the empty path is stored). An empty path's `getBounds()` is `Rect.zero`, which the spec's "shifted back by `origin`" turns into a phantom point at the frame's rebase origin. Any selection that includes a point therefore gets a box stretched to that origin, and its pivot moves there.
   - The paths are float32 relative to whatever origin they were last built at. `GripCache` builds at selection-change time, possibly before the first paint, at a stale origin.

   Reachability: select an arc and rotate, or select a point and a line and rotate. Gate 6's "rotates about the selection box's centre" either fails against a doubles oracle or passes against a wrong box.
   — suggested fix: compute the box in doubles from `OutlineCache`'s world record (`_world`). Add a `worldBoundsOf(key)` using exact arc extents (`Aabb2` of the arc, as `entityBounds` does), with points contributing their position. Never use `ui.Path.getBounds`.

7. **MAJOR: D3 (polyline stretch on a closed polyline), with the D2 tie-break.** Closedness in this model is "first point repeated as last" (`triangulate.dart:5-8`; the `paint_allocation_test.dart` rooms have a closing duplicate, first == last exactly). A closed polyline therefore has two coincident grips, 0 and n−1. D2's tie-break ("then the lower grip index") picks 0, and D3's "every other coordinate copied bit for bit" moves vertex 0 only.
   — reachability: every room boundary in a floor plan. Dragging a room's first corner tears the loop open. The stroke draws from the moved v0 to the stale closing point. The fill's triangulation ignores the last point (`triangulate.dart:28`), so the fill and the outline disagree. Dragging a vertex so the loop self-intersects drops the fill silently (`commands.dart:478-483`).
   — suggested fix: when `coords[0..1] == coords[last-1..last]` (exact, a stored-value test), show one grip for the pair and write both on stretch. Add a mutant that writes only index 0 and a closed-room fixture. Decide and state what the preview shows when the reshape makes the boundary unfillable.

8. **MAJOR: D8 (base point for a body drag excludes the grid).** "For a body drag, the press point resolved by step 2 alone (object snap, no grid, no ortho)", while the target is grid-snapped. So Δ = grid point − raw press point. That is an arbitrary non-grid vector, and every body drag knocks on-grid geometry off the grid.
   — evidence: `page_component.dart:107`: `snapToGrid` defaults to `true`, so this is the default experience. It also means the object jumps by up to half a grid cell the moment the drag passes the 4 px slop, even for a tiny move.
   — reachability: press on a wall's body away from the midpoint's 10 px aperture and drag. The wall's endpoints land off-grid.
   — suggested fix: resolve the base with the same chain as the target (object snap, else grid), as AutoCAD does with SNAP on, so Δ is a lattice vector. Or state explicitly that a grid move moves by lattice multiples. Add a mutant.

9. **MINOR: D2 press classification, classes 3 and 4.** "Body of a selected object" before "body of an unselected object" cannot be implemented with "the existing pick". `pickInto` returns the single best hit (`select_tool.dart:48-54`, `HitPath`). When an unselected object with a higher handle overlaps a selected one at the press point, the pick returns the unselected one: the press replace-selects it and moves it instead of moving the selection.
   — suggested fix: either say the single pick decides (drop the ordering claim), or specify a second pass over the selected keys' geometry.

10. **MINOR: D2 class 4 with shift, and D8 ortho.** Shift means "toggle into the selection" at press and "ortho" during the drag, and it is read per event (`interaction_layer.dart:89`). A shift-press-drag on an unselected object therefore adds it and moves ortho-constrained immediately. State it, or latch ortho only on a shift pressed after the drag starts.

11. **MINOR: D12 is incomplete.** "1 and 2 do nothing on release" changes 02's click behaviour at grip locations too. A click within 7 px of a grip of a selected object used to `replace([key])` (collapsing a multi-selection) or shift-`toggle` (`select_tool.dart:96-102`), and now does nothing. List it in D12 so the 02 tests that click a selected line at its endpoint are updated knowingly.

12. **MINOR: D2 tie-break for grips shared across selected objects.** Two selected walls meeting at a corner have coincident grips. The greater handle wins and only that wall's end moves, which splits the joint. This is acceptable for v1, but it should be stated as a decision, since it matters for 05 and the walls sub-project.

13. **MINOR: D4 permissions are checked only at release.** Under `DraftPermissions.runtime` (`command.dart:57-58`, geometry false), grips are shown on root leaves and every reshape or move of a root leaf previews and then silently snaps back. Check the needed capability at press: show no grips and start no drag when it is denied.

14. **MINOR: D5 "a camera change mid-drag keeps the object under the pointer".** This holds only at the next pointer event. A trackpad zoom or a middle-button pan produces no `ToolPointerEvent` (`interaction_layer.dart:97,108-109`: camera-owned moves are dropped), so the preview's world `T` stays stale until the pointer moves. Either say "at the next move", or re-resolve on camera notification from the last screen position.

15. **MINOR: D5 cursor, "InteractionLayer's MouseRegion reads it and repaints on tool notification".** `MouseRegion.cursor` is a widget parameter, so it needs a **rebuild**. `InteractionLayer.build` (`interaction_layer.dart:185-201`) does not listen to the controller today. Specify a `ListenableBuilder` (or `ValueListenableBuilder` on a cursor notifier) scoped to the `MouseRegion`, rebuilding only when the cursor value changes, not at drag-move rate.

16. **MINOR: D11 "TransformNodeCommand's the previous transform … the test compares with `==`".** `Transform2` has no `operator ==` (`transform2.dart:123-126` says so deliberately), so `==` on a transform is object identity. The undo test would pass for the wrong reason, because the inverse restores the very same object. Specify comparing the node (`GroupNode ==` / `InstanceNode ==` uses exact component equality, `node.dart:127-135`) or the six components with `==`.

17. **MINOR: D4 labels.** "label `Move`, `Rotate` or (never compound) `Stretch`" contradicts "one key → its command, unwrapped". An unwrapped `TransformNodeCommand` is always labelled `'Move'`, including for a rotate (`commands.dart:288-289`), and an unwrapped `SetEntityGeometryCommand` is `'Edit geometry'` (`commands.dart:452`). So "Stretch" never appears, and a single-object rotate reads "Move" in its `DocChange`. Either always wrap, or give the two commands a label parameter.

18. **MINOR: Exit gate 2, "bit-equal elsewhere … both arc ends".** A start-grip stretch rewrites both `startAngle` and `sweep`. The untouched end angle is `s' + sweep'`, which equals the old `s + sweep` only to within rounding. Only `cx, cy, r` are bit-equal. Say that the other end is equal within `Tolerance`, so an implementer does not write an `==` test on the derived end angle.

19. **MINOR: Differential check tolerance.** It uses translations up to 1e6 and compares "within `Tolerance`". `Tolerance.standard.linear` is an absolute `1e-9` (`tolerance.dart:23`). The ulp at 2e6 is about 4.7e-10, and each side accumulates several roundings (the arc side adds `r·ulp(angle)`), so the worst residual over 200 trials can exceed 1e-9. That means spurious failures, or an unrecorded loosening by the implementer. State the tolerance explicitly, scaled to magnitude (for example `k·ulp(max|coord|)`).

20. **MINOR: D6 and Invariant 5 (allocation).** "No `Paint` or `Path` is allocated per grip per frame" leaves out `Rect` and `Offset`, which are heap objects. `drawRect` or `drawCircle` per grip allocates per grip, up to `kMaxGrips = 400`. Invariant 5 cites `paint_allocation_test.dart`, but that test measures only the vertices sink (`paint_allocation_test.dart:1-18`), so nothing gates the overlay. Specify `drawRawPoints(PointMode.points)` with a square cap from a reused `Float32List` (filled grips), one reused `Path` for hollow ones, and a spy-canvas test whose allocation or draw-call count is independent of the grip count, with a named mutant.

21. **MINOR: Testing bar (named mutants).** Gates 1 (grip set), 6 (the 15° step), 12 (the cap), D9 markers, D10 F3 and the D5 cursor have no named mutant, although CLAUDE.md requires one per landed test. Candidates: the cap uses `>=`, shift rounds to π/6, the marker table is swapped, F3 does not reach `snapInto`, and the grip set omits a quadrant.

22. **MINOR: D8 ortho under a rotated camera.** Ortho pins **world** axes (the minor-axis test uses `raw.x − b.x` in world). The fixture rule puts every test under a rotated camera, where world-axis ortho looks diagonal on screen. State that ortho is world-axis by design, so the human look and the tests agree.

23. **MINOR: Widget tests versus the fixture rule.**
    - "cmd+Z through the shell's binding" and F3 need `PlannerShell` (`main.dart:102-106`), not a bare `PlannerView`.
    - The shell builds its own document (`startupPlan`) and camera with no injection seam.
    - `PlannerView` posts a one-time fit after the first frame (`planner_view.dart:67-87`), which overwrites any rotated camera a test sets before that frame.

    Name the seam (constructor parameters on the shell for document and camera), and say the test sets the camera after the first `pump`.

24. **MINOR: D8 `DragPoint`.** `final Vector2 point` together with "`out.point = scratch.point`, copied immediately" does not compile. Making the field non-final to allow it would alias the scratch vector, which breaks Invariant 6. Write `out.point.setFrom(scratch.point)` (and `setFrom(snapToGrid(...))`) in the spec.

25. **MINOR: D8 grid step when `page.gridStepMm` is set (inherited from 04 D6).** The drawn grid uses `GridScale.pick(..., floorMm: gridStepMm)` (`page_chrome_painter.dart:89-90`), whose minor is `gridStepMm/5` or `/4` (`grid_scale.dart:89-93`). The drag snaps to `gridStepMm` exactly. With a 250 mm step, minor lines are drawn at 50 mm and the snap skips four of every five. Record it for the look, or snap to the drawn minor when it is a divisor.

26. **MINOR: D7 preview coverage.**
    - A selected `point` has no path, and its cross is drawn from `worldPointOf` without `T` (`selection_overlay.dart:129-131,146-154`), so points do not move in the move/rotate preview.
    - The reshape preview's space is unspecified. Drawn in screen space, arc angles must be re-derived under the camera's y-flip (`viewport_transform.dart:39-46`, `d = −s`) and rotation. Drawn in rebased world under the overlay matrix, they go in unchanged.

    State both.

27. **MINOR: D2 and D6, rotation grip details.**
    - The hit radius for class 1 is not given (`kGripHitPixels` presumably).
    - "A selection of fills only starts no drag", yet class 1 fires "when the selection is non-empty".
    - With `grips == null` there is no rotation drag (D10), but D6 draws the grip regardless.

    Align all three.

28. **MINOR: Evidence of record.**
    - `planner_view.dart 41-43` for the listener-order rule: the comment is at 43-44 (41 is `_fitted`). The claim is true.
    - `spatial_index.dart` "doc at 1404": the "kind dominates unconditionally" text is at 1405-1406. The claim is true.
