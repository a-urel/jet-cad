# Task 7 review: the placement tool attaches (spec D6)

Reviewer: independent, detached worktree `.worktrees/plan-09c1-review-t7` at `2a1f8c2`. Diff reviewed: `b3284f1..2a1f8c2` (4 files: `main.dart`, `symbol_place_tool.dart`, `symbol_place_tool_test.dart`, `symbol_shell_test.dart`).

**Verdict: Approved.** There are no blocking, major or minor findings. Five notes follow; none needs a code change before Task 8 or 11.

## Gates (re-run by me, `CI=true`, Flutter 3.47.2)
- App `flutter test`: `05:02 +1167: All tests passed!`. This matches the implementer's count (1,152 + 15).
- App `flutter analyze`: `No issues found! (ran in 6.3s)`.
- App `dart format --output=none --set-exit-if-changed .`: `Formatted 182 files (0 changed)`, exit 0.
- App `flutter build web --release`: `✓ Built build/web`, exit 0.
- `apps/dev_harness_2d` `flutter analyze`: `No issues found!`.
- Engine and render layer: `git diff b3284f1..2a1f8c2 -- packages` is empty, so I did not re-run them.
  - Both allocation invariant tests are unedited (an empty diff on both `test/invariants` directories).
  - `git status` shows only pub get's unstaged rewrite of `packages/jet_cad/analysis_options.yaml`. No `analysis_options.yaml` is in the commit.
- Purity: `wall_attach.dart` and `symbol_box.dart` import no Flutter and no `dart:ui` (I read their imports). This task did not touch either file.

## Spec D6 and the plan, line by line
- **After `_resolve`, from the raw pointer, in the one path.** `_update` does `_resolve`, stores `raw` / objectSnap / scale, then `_syncAttachment`, then `_syncPlacement` (l.274-282).
  - Pointer down, move and up, `_onCamera` (l.305) and `_onArmed` with a listened context (l.202) all go through `_update`. That satisfies C-3 and R-C8b-1.
  - The attachment is fed the raw point, not `_at.point`. My mutant O1 (the resolved point) is red in 7 tests.
- **The conditions:** faces given, an entry armed, a stored query, object snap on, `entry.tags.contains(againstWallTag)` (the constant, as R-C3-3 requires), and `boxOfEntry` non-null (R-C2-2: no `!`).
  - Capture is `kWallAttachPixels / scale` with `kWallAttachPixels = 16.0`. Edge capture is `kSnapAperturePixels / scale`. Both match spec D4.
- **No `Transform2` is built in a paint.**
  - `paintWorldOverlay` is unchanged: it passes the stored `_placement` to `GhostMatrix.update`.
  - `_syncPlacement` returns `attached.transform` verbatim; it composes nothing on top of it.
- **The release.** The permission check comes first (l.440). Then `placeSymbol(..., transform: _attached?.transform)`, then `faces?.bands.invalidate()`, and only after the execute.
  - The committed bytes equal `attachToWall`'s. The test compares all six doubles, against `attachToWall` over the rig's runs and against hand arithmetic (`q = a + u·t`, `placementTransform(rotation: t)`).
  - `at: _at.point` is ignored when `transform` is given (R-C5-1).
- **Keys.** `M` and `R` call `_syncAttachment(ctx)` then `_syncPlacement()` over the stored query.
  - While attached, the turns are ignored. M re-asks D4 with the new mirror, so the footprint stays in place (the test checks the swapped corners and the sign of the determinant).
- **The marker** is drawn at `attached.q`, the face point after the edge snap and the clamp, otherwise as before.
- **`main.dart`.** `late final WallFaces _faces = WallFaces(_bands, accept: isUsableHost)` is handed to the tool.
  - `_bands` is the instance shared with the Wall and Opening tools, and it is disposed at l.762.
  - `WallFaces` holds no subscription, so it needs no dispose.
  - Lifetime: the host keys the shell by document, so a new document builds a new shell, a new `WallFaces` and a new tool. `WallFaces._refresh` also rebuilds on a change of document identity, and every query passes `ctx.document`. No stale-document path.
- **09b without faces.**
  - With `faces == null`, `_syncAttachment` always leaves `_attached` null. `_syncPlacement` and `paintOverlay` then take exactly the old branches.
  - In `_place`, `transform: null` is the old call, and `faces?.bands.invalidate()` is a no-op.
  - The test file's diff removes only two lines: the Rig constructor signature (new optional parameters with defaults) and `SymbolPlaceTool(armed)` → `SymbolPlaceTool(armed, faces: wallFaces)`, where `wallFaces` is null when there are no walls.
  - Every 09b test body is untouched, and all of them pass.

## Rulings
- **R-C7-1 (an app-side hourglass): accept.**
  - I confirmed `drawSnapMarker` returns without drawing for `nearest` (`snap_marker.dart:56-60`).
  - Geometry: four lines, top edge (x−h, y−h)→(x+h, y−h), a diagonal to (x−h, y+h), the bottom edge to (x+h, y+h), and a diagonal back to (x−h, y−h). That is the closed hourglass of AutoCAD's nearest glyph, kSnapMarkerPixels wide, the same size as the endpoint square.
  - Paint: the same `_markerPaint`.
  - Allocation: 8 `Offset`s per paint, constant and not per entity. The existing marker path already allocates per paint at this level: `at.translate` Offsets, a `Rect`, and a whole `Path` for the midpoint and quadrant glyphs. It is not on either measured invariant path.
- **R-C7-2 (keys re-ask the faces with the stored query, no re-snap): accept.**
  - Decision 5 asks that "M toggles the mirror, which D4 applies", for the same pointer. A full `_update` would re-snap on a key and change 09b's key behaviour.
  - The stored scale is never stale while the ghost is shown, because the camera listener re-runs `_update`. My mutant O2 (scale stored once) is red.
- **R-C7-3 (M-09c-ap killed at the tool, not the shell): accept.** I re-fired it on `symbol_shell_test.dart`: `+17: All tests passed!` (it survives there, as the report says). On the tool test it is red.
- **R-C7-4 (no invalidate on a refused placement): accept.** My mutant O6, which invalidates before the permission check, is red: the permissions test pins the generation.

## Mutants (fired by me: `cp` backup, a single-occurrence scripted replace, the named test file, `cp` back; `diff` exit 0 after every restore)

| Id | Change | File run | Result |
|---|---|---|---|
| M-09c-a | tag check deleted | place_tool_test | **red** (island; re-arm) |
| M-09c-j | `mirrored: false` in `faces.attach` | place_tool_test | **red** (attach byte-for-byte; M test: `at location [0] is <-0.866…> instead of <0.866…>`) |
| M-09c-k | attached transform ∘ quarter-turn rotation about the base point | place_tool_test | **red** (attach; R test: `<0.4999…> instead of <-0.866…>`) |
| M-09c-l | `!_rawObjectSnap` dropped | place_tool_test | **red** (F3 test: `Expected: null`) |
| M-09c-ap | `faces?.bands.invalidate()` deleted | place_tool_test | **red** (W-5: `within <1e-6> of <1600> Actual: <1720.000000000006>`) |
| M-09c-ap | same | shell_test | survives (`+17`), as recorded in R-C7-3 |
| M-09c-ak | `_onCamera`: `_resolve` + `_syncPlacement` | place_tool_test | **red** (zoom: `Expected: not null Actual: <null>`) |
| re-arm skips the attachment (8b-owed) | `_onArmed`: `_resolve` + `_syncPlacement` | place_tool_test | **red** (re-arm: `Expected: not null`) |
| marker at the raw point | `p = attached != null ? _raw : _at.point` | place_tool_test | **red** (marker: `within <1e-9> of <1756.18…> Actual: <1752.18…>`) |
| release ignores the attached transform | `transform: null` | place_tool_test | **red** (6 tests: `Actual: [0.0, 1.0, -1.0, 0.0, 103050.3, -68125.7]`) |
| M-09c-e | `WallFaces(_bands)` (no `accept`) | shell_test | **red** (SS17: `Expected: <false> Actual: <true>`) |
| shell hands no faces | `SymbolPlaceTool(_armed)` | shell_test | **red** (SS16, SS17) |
| O1 (mine) | attachment from the resolved point: `_raw.setFrom(_at.point)` | place_tool_test | **red** (7 tests) |
| O2 (mine) | stored scale stale after a zoom: `if (!_hasRaw) _rawScale = …` | place_tool_test | **red** (zoom test) |
| O3 (mine) | `_attached = null` at the top of `_syncAttachment` deleted (a stale attachment survives an early return) | place_tool_test | **red** (re-arm) |
| O4 (mine) | key path: `_syncPlacement` before `_syncAttachment` | place_tool_test | **red** (M test) |
| O5 (mine) | mirror applied twice: attached ∘ `scale(−1, 1)` when mirrored | place_tool_test | **red** (attach; M test) |
| O6 (mine) | `invalidate()` before the permission check | place_tool_test | **red** (permissions test, the generation) |
| O7 (mine) | attached marker draws the hourglass **and** falls through to `drawSnapMarker` | place_tool_test | **red** (`has length of <6>`) |

19 runs: 18 red, and 1 survivor (M-09c-ap at the shell) that is accepted under R-C7-3.

## Fixtures (P-2)
- The tool tests use walls at 30° and −112.5° and both non-centre justifications on their faces (left/left and right/right). The walls sit in rotated groups near (1e5, −7e4) at 0.05 px/mm.
  - The fixture test checks that the rotation is not axis-aligned, the scene is far from the origin and the scale is not 1.
  - The toilet's base point is not its back-centre (checked).
  - The tests cover mirrored and not, and turned.
  - The shell tests run at 0.1 px/mm on a 30° wall, added by commands so no tool has run.
- The degenerate risks are covered where the tool can get them wrong: raw vs resolved point, the mirror, the turns, the scale and the q marker are each pinned by a red mutant.

## Notes (no change required)
1. **Note: tool-level groups are neither mirrored nor scaled.**
   - P-2's mirrored and scaled groups are not used in `symbol_place_tool_test.dart`. All face geometry is Task 6's `attachToWall` / `faceRunsOf`, which `wall_attach_test.dart` covers under those groups. The tool only forwards the raw point, the mirror and the scale, and every one of those forwarding mutants is red here.
   - Task 11's end-to-end test could still place against a mirrored-group wall.
2. **Note: the marker test leaves `ends[2]` and `ends[6]` unpinned** (the starts of the second and fourth lines). The centroid assertion constrains their sum, so only a compensating pair of changes would survive. That is acceptable.
3. **Note: a key reuses the stored object-snap flag (R-C7-2).** With F3 toggled off while attached and no pointer move, the ghost stays attached until the next pointer event, the same as 8b's "F3 does not refresh the ghost". A release always re-runs `_update`, so the commit is never wrong. The same applies to M/R pressed while the ghost is hidden: an invisible re-query with the last raw point, recomputed on the next pointer event.
4. **Note: `invalidate()` also runs after a free (untagged) placement.** This matches spec D6 ("after its own commit") and is harmless.
5. **Note: allocation per pointer event while attached** (a record, a Vector2, a Transform2, from Task 6's `attachToWall`). It is off the paint path and was already recorded by Task 6 and the report.

## Process
- I worked only in the detached review worktree. Nothing was committed. Every mutated file was restored by `cp`, and `diff` exited 0 each time.
- No gate or mutant ran concurrently in this worktree (C-1).
- The only file I wrote in the plan worktree is this review.
