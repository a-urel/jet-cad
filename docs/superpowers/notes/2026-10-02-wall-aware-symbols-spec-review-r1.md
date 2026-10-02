# Spec 09c (wall-aware symbols) — review of revision 1

**Spec:** `docs/superpowers/specs/2026-10-02-wall-aware-symbols-design.md`, rev 1 (`24feacb`, branch `spec-09c/wall-aware-symbols`; the tree is `main` at `4d6b78f` plus the spec).
**Reviewer:** independent, read-only, 2026-10-02.

## Verdict: **Ready with amendments**

The decomposition, the human's decisions and most of the geometry hold up against the code. Two findings are **blocking** because, as written, they cannot be implemented: D11's conditional capability and D8's "commit = T′" claim. Four more are **major**: each is a defect or a gap an implementer would hit in the first task. Every finding below has a concrete amendment. No decision the human made has to be reopened.

### Facts F-1..F-11: verified

Every cited location is correct: `furniture_catalog.dart:1-4`, `symbol_placer.dart:39` and `:65-145`, `commands.dart:285` and `:454-492`, `draft_document.dart:193-211`, `node.dart:208`, `tree.dart:196`, `layer_commands.dart:424`, `wall_bands.dart:82`, `opening_tool.dart:447`, `opening_geometry.dart:76` and `:711`, `drag_snap.dart:14`, `placement_tool.dart:258-279`, `symbol_panel.dart:105`, `main.dart:320` and `:809`, `select_tool.dart:36/:100/:219/:347`, `grip_drag.dart:225` and `:269-330`, `grip_cache.dart:29` and `:350-359`.

The content claims also hold:
- F-1: the toilet's cistern is at y 500–700, the washbasin's tap at y 410, the bed's pillows at y 1680–1920, the sofa's back at y 700–900.
- The catalog has 27 keys (`furniture_library_test.dart:56`).
- `family:bed-double` and `against-wall` pass R03c (`symbol_library.dart:143-147`).

Two facts are imprecise; see W-9 (F-7) and W-4 (F-7's "Obstacles … (a T)").

---

## Blocking

**W-1 (blocking). D11: "Capability: `structure` plus `components` when the snapshot is not empty" cannot be implemented.**
- **Where:** D11, bullet 2.
- **What is wrong:** `CommandDispatcher.execute` calls `_require(effective)` **before** `apply` (`undo.dart:191`), and `_require` reads `command.capabilities` (`undo.dart:287-291`). `RemoveDefinitionCommand(handle)` has no target before `apply`, so it cannot know whether the snapshot will be empty. This is the stateful-capability problem the parametric-layer review ruled out (B4, `2026-09-24-parametric-layer-spec-review-r1.md`).
- **Evidence:** `command.dart:123-129`; `undo.dart:187-193`.
- **Amendment:**
  - The forward command declares a **static** `capabilities => {structure, components}`. Its `capability` (the summary that `SpatialIndex` reads, `spatial_index.dart:2709-2716`) stays `structure`.
  - The inverse ("re-add the definition and restore the snapshot") declares `{structure}` plus `components` when the snapshot it carries is non-empty. It can know this, because it is built after the snapshot is taken.
  - The placer is unaffected under every permission set. Its forward compound already needs `components` (`SetComponentCommand`), so P17 still refuses before anything applies. Its inverse compound already contains the `SetComponentCommand(null)` inverse.
  - The amendment must also say that **SC12** (`symbol_component_test.dart:257-274`) asserts today's behaviour (the component survives `RemoveDefinitionCommand`), so it must be rewritten, and that engine tests asserting `capability == structure` (`definition_commands_test.dart:165-184`) stay valid.

**W-2 (blocking). D8: "the commit stays `TransformNodeCommand(h, delta · node.transform) = T′`" is false in floating point, and the no-op test would discard real attached moves.**
- **Where:** D8, the seam's first bullet.
- **What is wrong:**
  - `(T′·M⁻¹)·M` is not bitwise `T′`. The exact cos and sin and the `-0.0` normalisation (D4 step 3, F-2) would be lost in the stored bytes, and so would "back exactly on the face", which the neighbour test (D4, `wallJoin.linear` = 1e-6, `wall.dart:19`) relies on.
  - Separately, `command()` returns null when `target − base == 0` (`grip_drag.dart:296-300`). An attached drag that ends with the pointer back on the press point still rotates the symbol, but nothing is committed, even though the preview showed the move.
- **Amendment:**
  - `moveToTransform` receives `T′` as well as the delta. It stores `T′` for the single capture and sets `_transform = delta` for the preview and for `carry`.
  - `command()` emits `TransformNodeCommand(h, T′)` verbatim, and it is a no-op only when `T′ == node.transform` (exact).
  - `target` is still set to the snapped point, so the guide keeps working.
  - Add the mutant "commit uses `delta·node.transform`", killed by a bytes test at 30° far from the origin.

## Major

**W-3 (major). D4 step 1: the tie rule snaps to the wrong piece at a T and at a straight joint.**
- **Where:** D4 step 1.
- **What is wrong:** The two pieces of a T-split face lie on the **same line**, so they have the same `s`; so do two collinear walls meeting end to end. Their `u` windows overlap by up to `2·capture − gap`. A pointer just to the right of a 100 mm stem, inside the right piece, is also within `L + capture` of the left piece. `|s|` ties, the handle and the face tie, and "the lower `a`" picks the left piece. The clamp then pulls the ghost away from the pointer, to the other side of the stem.
- **Amendment:** Rank the candidates by `|s|`, then by the distance from `u` to `[0, L]` (0 inside), then by the existing ties. Add a mutant without the second key, killed by a T fixture with the pointer 1 px to the right of the stem.

**W-4 (major). D3 "A T splits a run … an obstacle on the other side leaves this face whole": an `Obstacle` does not carry the side, and X obstacles are not addressed.**
- **Where:** D3, bullet 3.
- **What is wrong:**
  - `typedef Obstacle = ({double a, double b, Handle wall})` (`opening_geometry.dart:98`) has no side. `obstaclesOf` computes the near face internally (`:144`, `end.a.dot(hn) > 0 ? hl : hr`) and throws it away.
  - `obstaclesOf` also returns **X crossings** (`:152-167`), which cut both faces.
  - F-7 suggests `stretchesOf`, but that clips to the straight span `[uS, uE]` (`:190-196`), not to the drawn face. On an outside face it would cut the run back to roughly the inside face's extent, which partly hides M-09c-f.
- **Amendment:**
  - Specify the side test (for a T end `k` of wall B: the left face when `End(B, k).a · n > 0`, else the right face). Either `obstaclesOf` gains a side field, which touches only 08's private call sites (`:621-630`), or 09c recomputes it.
  - State that an X cuts both faces.
  - State that runs are cut by the obstacles directly and never through `stretchesOf`.
  - Split M-09c-g into "T ignored", "T applied to both faces" and "X applied to one face".

**W-5 (major). D3/D6: the face cache cannot key on `WallBands.generation` as written.**
- **Where:** D3 "Candidates", "Cost"; D6 last bullet.
- **What is wrong:**
  - `WallBands` exposes no wall enumeration (`_cache` and `_handles` are private; the only public scans are `hostAt` and `joinInto`).
  - Its document subscription is created only inside `_refresh` (`wall_bands.dart:120-127`). If the Symbol tool only reads `generation` and the session never ran a Wall or Opening scan, the generation never moves and the face cache stays stale forever.
  - The stream also delivers after the task (`:21-22`), so a run of kitchen units placed one after another depends on the tool invalidating at commit, as the opening tool does (`opening_tool.dart:179`).
- **Amendment:**
  - `WallBands` gains a public refresh or enumeration (for example `liveWalls(doc)`, which runs `_refresh`) that the tool calls on each move.
  - The tool calls `_bands.invalidate()` after its own commit (Ruling 08-13's "and at every click").
  - Add a test: a fresh shell with no wall tool used, place two units, and the second snaps to the first.

**W-6 (major). D8, the app's resolver: which point attaches, and the inputs the resolver lacks.**
- **Where:** D8, "The app's resolver"; the `MoveResolver` signature.
- **What is wrong:**
  1. With the raw pointer as D4's `p`, the box centre jumps under the cursor at attach: a 2000 mm sofa grabbed at its end leaps about 1 m. In placement the pointer **is** the base point, so decision 10's "as in placement" maps to the instance's insertion point following the plain move, `delta·node.transform·basePoint`, not to the raw pointer.
  2. Neighbours are "found through the spatial index", but `resolveMove(DraftDocument, Handle, Vector2, Transform2, double)` receives no `SpatialIndex` (it is `ToolContext.index`, `tool.dart:55`) and no object-snap state (`ctx.snap?.objectSnap`).
  3. The spec never says how the tool learns the drag is a single root-level **body** drag. `_captures` is private, and a move-grip drag is also `DragKind.move` (`select_tool.dart:257`). "Multi-key" is also ambiguous between keys and captures: a fill key is skipped (`grip_drag.dart:159`).
  4. The guide line and the snap marker (`select_tool.dart:758-768`) are unspecified while attached; D6 puts placement's marker at `q`.
  5. Shift (ortho) is unspecified while attached.
- **Amendment:**
  - `p` is the plain-moved insertion point.
  - The resolver receives the index and `objectSnap`, or the app scans the root instances once per generation.
  - `GripDrag` exposes `Handle? singleNode`, non-null only for one `_NodeCapture`, and the tool consults the resolver only for `PressClass.selectedBody` and `unselectedBody` without shift.
  - While attached, the marker is drawn at `q` and the guide runs from `base` to `q`.
  - While attached, ortho is ignored.

**W-7 (major). D4 steps 3 and 5: the mirror composes wrongly when read literally.**
- **Where:** D4 steps 3 and 5.
- **What is wrong:** Step 3 defines `M` as `scale(−1, 1)` **about the box's centre `x`**. Step 5 applies `M` **after** `translate(−c)`, where the box is already centred on `x = 0`. A pivot at the local `cx` there gives `x′ = 2cx − x`, which moves a 1600 mm bed by `2cx` = 1600 mm.
- **Amendment:** In step 5, `M = scale(−1, 1)`. It pivots about `cx` because of `translate(−c)`. Note that this pivot differs from `placementTransform`'s (the base point, `symbol_placer.dart:48-51`), and that D5's generalised form is `placementTransform(at: q, basePoint: c, rot, mirrored)` exactly.

**W-8 (major). D14 contradicts D8 on scaled instances.**
- **Where:** D14 bullet 4; D8.
- **What is wrong:** D14 says a scaled instance "is not attached by a move", but D8's resolver uses only the sign of `ad − bc`, so it would attach the instance and silently drop its scale, because `T′` has no scale. D7's Rotate and Mirror are equally silent on the scale.
- **Amendment:**
  - The resolver returns null unless the linear part is orthonormal within `Tolerance`.
  - Rotate and Mirror compose with the existing linear part, so they keep the scale.
  - Add the mutant "a scaled instance attaches".

## Minor

**W-9 (minor). F-7 and D3, "the start cap's point on that face": the order is right, but name the points.**
- **Where:** F-7; D3 bullet 2.
- **What is wrong:** I checked the caps' order. `End(w, 1)` has `nOut = −n` and `left = −r` (`wall_geometry.dart:66-72`), so the end cap starts on the right face. The start cap starts on the left face. A node owner's cap walks the whole lobe, from its left corner to its right corner (`:325-330`), so it has **interior points** that lie on neither face.
- **Amendment:** Say "left face: `startCap.first` → `endCap.last`; right face: `startCap.last` → `endCap.first`". The outline ring `[...endCap, ...startCap]` confirms these are the drawn face edges. Add a mutant "the face point taken from the wrong cap end", distinct from M-09c-f, killed by the 100/240 L.

**W-10 (minor). D3: "For a left face `t = −d`" holds only without a mirror, and `w` is not defined.**
- **Where:** D3, first paragraph.
- **What is wrong:** Under a mirrored group (det < 0) the mapped normal gives `t = +M·d` for the left face. D3's own definition (`a` is the end with the smaller `·t`) is robust to this, but the parenthetical is not. `w` must be the **world** thickness: under a scaled group it is `t·s` (spec 11 S-5), while `WorldWall.t` is unscaled (`wall_geometry.dart:24`).
- **Amendment:** Delete the parenthetical or qualify it, and define `w` as the distance between the mapped faces. Add a **mirrored** group and a **scaled** group to the attachment fixtures. A rotated, translated group alone is a degenerate fixture for this.

**W-11 (minor). D10: the leaf-equality field list is incomplete.**
- **Where:** D10.
- **What is wrong:** `EntityRecord` also has `text`, `tag`, `textStyle` and `textAttrs` (`entity_store.dart:59-70`). The placer copies via `copyWith(handle, owner)`, and `AddEntityCommand` rewrites `geomIndex` (`commands.dart:57-58`).
- **Amendment:** Say "every `EntityRecord` field except `handle`, `owner` and `geomIndex`", and add "the definition has no child nodes". Note that `==` equates `-0.0` and `0.0`, which is acceptable but should be said.

**W-12 (minor). D7: the permissions.**
- **Where:** D7.
- **What is wrong:** Runtime allows `transform` (`command.dart:56-57`), so D7's own rule makes Rotation and Mirror **editable** under runtime. F-11 says every section is read-only there. The Size menu's needs also vary: a copy needs `{structure, components, geometry, transform}`, a reuse needs `{structure, transform}`.
- **Amendment:** State both outcomes explicitly, and gate the Size menu on the worst case, as the placement tool does (`symbol_place_tool.dart:79-83`).

**W-13 (minor). D7: no command has ever changed an instance's definition (F-5).**
- **Where:** D7.
- **What is wrong:** `SpatialIndex` rebuilds on any touched node (`spatial_index.dart:2786-2789`), so it is safe. `OutlineCache` and `TileCache` have never seen this edge change.
- **Amendment:** Require a render test. After a size change, an undo and a redo, the outline bounds, the pick and the painted tile must match the new definition, and a later edit to the new definition must propagate.

**W-14 (minor). D4: neighbours.**
- **Where:** D4, "Neighbours".
- **What is wrong:** The pieces of a T share a line, so "both ends on the run's line" admits symbols that stand in the other piece.
- **Amendment:** Require `[uLeft, uRight]` to overlap `[0, L]`. Say whether hidden or locked instances count (the picking filter, presumably). Add a fixture where the neighbour is rotated 180°, so that its local left is its world right, and one with a back-to-back symbol on the opposite face.

**W-15 (minor). D5: where the transform is computed.**
- **Where:** D5.
- **What is wrong:** `paintWorldOverlay` calls `_matrix.update` today (`symbol_place_tool.dart:290-294`). Building a `Transform2` there would allocate on every paint.
- **Amendment:** Say that the placement transform is computed on pointer, key and camera events and stored in a field. The paint passes the stored value.

**W-16 (minor). Named mutants: gaps and fixture notes.**
- **Missing mutants:**
  - vertex-only arc bounds (the toilet's front at 200);
  - `s ≥ −w` or `s ≥ 0` in place of `−w/2`;
  - the W-1 capability;
  - the W-2 exact commit;
  - the W-3 tie key;
  - D12 not re-resolving the *attachment* on zoom, only the snap;
  - the Rotation row losing the mirror;
  - a family member of a different depth (add a catalog test that a family shares `D` and `back`, which D9 asserts but nothing checks).
- **M-09c-n** can go red only on an **axis-aligned** wall (cos = −m.y = −0.0). Every fixture D-Testing names avoids that, so the spec must name the exception explicitly.
- The others look killable. M-09c-s's "not removed" needs the dispose path driven with a live camera.

## Nits

**W-17 (nit). Wording.**
- The "No schema change" invariant sentence contradicts itself ("open in 12b's build except for … which 12b also reads").
- D4 step 2's "`Tolerance.linear`" should name `wallJoin.linear`.
- In "ties to the lower value" (edge snaps), say the value of what.
- D12: also remove the listener when the symbol is disarmed.

---

## Answers to the checklist

1. **Facts:** all correct. F-7 is imprecise (W-9, W-4).
2. **Geometry:**
   - The cap order is right (W-9).
   - The orientation is a proper rotation: `R(0,1) = (−sin, cos) = −m` and `R(1,0) = t`. It is consistent with "left side to run start", and `t` is the right hand of a viewer facing the wall.
   - The `−w/2` rule splits at the band **midline** for every justification, consistent with 08-23 (`opening_tool.dart:357-364`). The midline tie goes to the left face, as the door swing does.
   - The defects are the T tie (W-3), the obstacle side (W-4) and the mirror order (W-7).
3. **D8:** implementable with W-2 and W-6. The preview, `carry` (`grip_cache.dart:242`), `_revalidate` and the camera re-target (`select_tool.dart:374-381`) all work with a delta. Shift re-targets through `_onCamera` (`:569-575`).
4. **D7 and D11:** `SetInstanceDefinitionCommand` is implementable. `replaceNode` guards cycles for nested instances (`tree.dart:493-503`). D11 needs W-1. With a static set, the placer's undo (P17, P18) is unaffected under every permission set.
5. **D10:** W-11.
6. **D2:** the tags are legal. The tag-only ruling is safe:
   - reuse never compares tags;
   - stale tags in old plans are ignored, because tags are read from the library;
   - the asset is regenerated, and "the committed bytes equal the built library" stays a true gate.
   
   A new copy writes the new tag strings into `SymbolComponent` JSON. That is data, not schema.
7. **Testing:** W-10, W-14, W-16.
8. **Non-negotiables:**
   - **Draw order:** holds. A size change keeps the instance's handle, and copies keep the leaves ascending.
   - **No schema change:** confirmed. D11 changes what a save writes after a definition removal, but not the format.
   - **Frame-path allocation:** holds, given W-15.
   - **Tolerance vs exact `==`:** holds, given W-2.
9. **Split:** clean. 09c-1 is lookable and green on its own; the family tags are inert until 09c-2 but are tested by R03d.
10. **Consistency:** D14 contradicts D8 (W-8), and D7 contradicts F-11 (W-12). Otherwise no D-section contradicts a human decision.
