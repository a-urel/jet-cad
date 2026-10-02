# Spec 09c (wall-aware symbols): review of revision 2

**Spec:** `docs/superpowers/specs/2026-10-02-wall-aware-symbols-design.md`, rev 2 (`dad5ac0`). **Reviewer:** independent, read-only, 2026-10-02. Code read on the same tree.

## Verdict: **Ready with amendments**

These amendments landed correctly and completely: W-1, W-3, W-5, W-7, W-9, W-11 to W-15 and W-17. The D11 static capabilities match the dispatcher, which checks `capabilities` before `apply` (`undo.dart:191`, `:287-291`). The placer's undo inverse runs `SetComponentCommand(null)` before `RemoveDefinitionCommand`, so its snapshot is empty when the removal runs.

Four amendments are flawed:
- **W-2** is applied but leaves gaps (S-5).
- **W-4** conflicts with the mirrored-group fixture that W-10 requires (S-3).
- **W-6** chose an anchor that breaks decision 10 (S-1, blocking).
- **W-10** rests on a wrong premise about scaled groups (S-2).

The geometry otherwise holds:
- `R·(0,1) = (c,d) = (−sin, cos) = −m`.
- `atan2(−c, d)` fits `Transform2(cos, sin, −sin, cos)` (`transform2.dart:42-44`).
- The cap ends are correct (`wall_geometry.dart:486-490`).
- `GripDrag.singleNode` can be derived from the private `_captures` (`grip_drag.dart:144-162`).
- The preview, `carry` and `_revalidate` all work with `T'·M⁻¹`.

---

**S-1 (blocking). D8: anchoring on the plain-moved insertion point means an attached symbol never stays attached.**
- **Location:** D8, "The app's resolver"; M-09c-an.
- **Evidence:**
  - Base points are on the front or at the centre (`furniture_catalog.dart:2-4`). Examples: `kitchen.base.600` base `(300, 0)` with depth 600 (`:256-266`); `bed.double` `(800, 1000)` (`:336-341`); toilet `(200, 0)` with its box reaching y = 700 (`:449-461`).
  - Once attached, the insertion point therefore sits D or D/2 from the face, which is 600–2000 mm.
  - D4 step 1 requires `s ≤ captureWorld = 16 px / scale`, which is 80 mm at 0.2 px/mm.
- **Consequences:**
  - The first move event of a symbol that is already flush returns null, so "dragging one such symbol along a wall keeps it on the face" fails.
  - Attaching to another wall needs the back pushed about D into it.
  - W-6's premise is wrong. In placement the attached pointer is within capture of the **face**, near the ghost's back, not at its base point.
- **Amendment:**
  - Set `p = delta · node.transform · c`, where `c = ((left+right)/2, back)` is D4's back-centre.
  - While attached, this point is `q` (s ≈ 0), so the symbol stays attached.
  - Its `u` equals the insertion point's for every catalog symbol (the D9 base-on-centre-x test), so there is no jump along the face.
  - Redefine M-09c-an as "anchors on the insertion point (or the raw pointer)".
  - Add a fixture: a unit placed by D6 at 0.2 px/mm, dragged 500 mm along the face, must stay attached and flush.

**S-2 (major). D3: under a scaled group, `w` and the face line are wrong (W-10's premise is false).**
- **Location:** D3, the definitions of `w` and the faces; Testing, "scaled group".
- **Evidence:**
  - `HostFrame`'s `lOff` and `rOff` are `host.offsets`, which use the unscaled `t` (`opening_geometry.dart:91-93`), yet they are applied in **local** space (`:59-61`).
  - When the frame did not fall back, the caps are the world ring mapped to local, `t` thick in world. That ring is what `localOutlineOf` stores and what is drawn (`wall_geometry.dart:468-476`).
  - The wall is `t·s` thick in world only in the fallback case (`drawnCapsOf` doc, `:520-525`).
  - So "offset `lOff` along `n`, mapped to world" lies `(s−1)·t/2` off the drawn face, and `w` = `t·s` ≠ the drawn thickness. A run end at an obstacle cut built with `frame.left(u)` is off the face.
- **Amendment:**
  - Define each face line by its two drawn cap points: left `startCap.first → endCap.last`, right `startCap.last → endCap.first`, mapped through `toWorld` (equal to `drawnCapsOf`).
  - Place cut points on that line.
  - Define `w` as the distance between the two drawn face lines.
  - Delete the parenthetical "not `WorldWall.t`".
  - Test the scaled-group fixture both joined and fallen back.

**S-3 (major). D3: the obstacle side is world-handed, while the faces are local-handed; under a mirror they disagree.**
- **Location:** D3, "Other walls cut a face"; Testing, mirrored group.
- **Evidence:**
  - `:144` tests `end.a.dot(hn)`, where `hn` is the **world** left normal (`:123`).
  - D3's "left face" is `lOff` along the **local** `n`.
  - When `det(toWorld) < 0`, the local ring is clockwise, so `hostFrameOf` always falls back (`:85-89`), and local left equals world right.
  - A side field "set at `:144`" therefore cuts the wrong face in the mirrored fixture that W-10 requires.
  - For a non-centre justification, `obstaclesOf`'s world band (`WorldWall.offsets`, `wall_geometry.dart:53-57`) also lies across the centreline from the drawn local rectangle.
  - The dimensions spec already lists this flip as inherited (`2026-09-28-dimensions-design.md:1699-1701`).
- **Amendment:**
  - Define the side in host-local terms: the sign of `(toLocal.linear · End(B,k).a) · frame.n`, which equals the world test flipped when `det < 0`.
  - Make the mirrored T fixture centre-justified.
  - List the non-centre mirrored case in D14 as inherited.
  - Add the mutant "side from the world normal under a mirror".

**S-4 (major). D4 steps 2 and 4: the clamp throws for a run that fits within tolerance.**
- **Location:** D4 step 4, the clamp.
- **Evidence:**
  - Step 2 admits `W ≤ L + wallJoin.linear`, but for `L < W` the bounds of `[W/2, L − W/2]` are inverted.
  - Dart's `num.clamp` throws `ArgumentError` when `lower > upper`.
  - A 600 mm dishwasher in a niche drawn 600 wide, with `L = 599.9999999998`, crashes the pointer handler.
- **Amendment:**
  - When `W ≥ L`, set `u = L/2`.
  - Add the niche fixture and the mutant "the clamp without the `W ≥ L` case".

**S-5 (major). D8: the W-2 seam has four gaps.**
- **Location:** D8, "The commit is exact"; "`_revalidate` and the camera retarget are unchanged".
- **Gaps:**
  1. Nothing says that `moveTo` clears the stored `T'`. A drag that attaches and then leaves the face would preview the plain move but commit the stale `T'`.
  2. The resolver must be consulted inside `_retarget` (`select_tool.dart:347-356`). Then the camera path (`_onCamera`, `:374-380`, which captures in pixels) and the release `_follow` (`:411`) re-resolve. Hooking `_follow` alone drops the attachment on zoom.
  3. `Transform2` has no `operator ==` by design (`transform2.dart:124-128`). "`T' == node.transform`" must say component-wise exact, as D5 does.
  4. `moveToTransform(delta, exact)` lets a caller pass the **plain** delta. Use `moveToTransform(Vector2 marker, Transform2 exact)` instead, compute `T'·M⁻¹` inside, and set `target = marker` so the guide and marker follow (`_paintGuide`, `:758-768`).
- **Mutants to add:** "`moveTo` keeps `T'`"; "a camera change does not re-ask the resolver".

**S-6 (minor). D8: `singleNode` counts captures, not keys.**
- **Location:** D8, W-6 bullet.
- **Evidence:** `_capture` skips fills (`grip_drag.dart:159`) and immovable groups (`:152`). Openings and rooms are immovable (`object_grips.dart:30-33`).
- **Effect:** a symbol selected together with a door attaches, against decision 10 ("a single selected") and the human's look.
- **Amendment:** require that the drag captured exactly one `_NodeCapture` **and** had exactly one key.

**S-7 (minor). D3: X obstacles over-cut, and 08 is touched.**
- **Location:** D3, X bullet; "ignored by 08's existing call sites".
- **Evidence:**
  - An X interval is the union of four crossings over **both** faces (`opening_geometry.dart:161-167`). At an oblique X each face is over-cut by up to `w·cot φ`, so an edge-snapped unit stands off the crossing wall.
  - `opening_geometry_test.dart:244-245` builds `Obstacle` record literals, which must gain the new field.
- **Amendment:**
  - Give an X a per-face interval from the two crossings on that face, or list the over-cut in D14.
  - Name the test edit.

**S-8 (minor). D6 and D8: the run and neighbour cache has no owner in 09c-2.**
- **Location:** D6, last bullet; D8.
- **Evidence:** D6 places the cache "in the tool". D8's resolver needs the same runs and neighbours, plus `liveWalls` and `generation`, but it is not given `WallBands`.
- **Amendment:**
  - Add a shell-owned `WallFaces` (in `wall_attach.dart`), keyed on `bands.generation` and shared by the tool and the resolver.
  - `liveWalls` returns a view, not a copy, so that D3's "a pointer move … allocates nothing" holds.

**S-9 (minor). Named mutants.**
- **M-09c-ah (`s ≥ −w`)** is equivalent in ordinary fixtures. Past the midline the far face is also a candidate with a smaller `|s|`, and it wins anyway. Name the killing fixture: the far face has no run at `p`'s `u`, for example a T stem on the far face wider than `2·captureWorld`.
- **M-09c-af:** the stem's own face is a candidate 1 px away. The fixture must keep `p` closer to the host face than that.
- **Missing mutants:**
  - the resolver attaches with F3 off (M-09c-l covers placement only);
  - D11's inverse lacks `components` for a non-empty snapshot (killable with a custom `DraftPermissions(structure: true, components: false)`);
  - D12's listener is not removed on hide, `cancel` or disarm (M-09c-s covers dispose only);
  - W-13's render-cache test;
  - D10's child nodes or leaf count;
  - D7's Size-menu gating, and Rotation and Mirror editable under runtime.

**S-10 (nit).**
- The Architecture Files table omits `lib/parametric/{wall_bands,opening_geometry}.dart`, which D1 names, and their tests.
- "Orthonormal within `Tolerance`" (D4 neighbours, D8) does not say which tolerance.
- The marker glyph while attached is unspecified: `_paintGuide` draws `_dragPoint.objectKind` (`select_tool.dart:766`), the plain snap's glyph.
- D7's "exact table" at multiples of 90° should say that it is `R(θ')·S` for a mirrored instance, normalised as in F-2.

## Amendment status

| W | Status |
|---|---|
| 1, 3, 5, 7, 9, 11–15, 17 | applied, correct |
| 2 | applied; gaps S-5 |
| 4 | applied; S-3, S-7 |
| 6 | applied; the anchor is wrong, S-1; captures vs keys, S-6 |
| 8 | applied, correct (D14 ↔ D8 consistent) |
| 10 | applied on a false premise, S-2; the mirror fixture collides with S-3 |
| 16 | applied; S-9 |
