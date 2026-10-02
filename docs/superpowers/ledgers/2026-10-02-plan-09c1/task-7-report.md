# Task 7 report: the placement tool attaches (spec D6)

Status: done (implementer). Base `b3284f1`. Commit **`2a1f8c2`** `feat(app): place a symbol against a wall`.

## Files changed
- `apps/floor_planner/lib/symbols/symbol_place_tool.dart`
- `apps/floor_planner/lib/main.dart`
- `apps/floor_planner/test/symbols/symbol_place_tool_test.dart`
- `apps/floor_planner/test/symbols/symbol_shell_test.dart`

`analysis_options.yaml` was not staged. Engine, render layer and both allocation invariant tests are untouched: `git diff b3284f1 -- packages` shows only the unstaged pub-get rewrite of `packages/jet_cad/analysis_options.yaml`.

## What was built
- **`SymbolPlaceTool(armed, {WallFaces? faces})`** and `const kWallAttachPixels = 16.0`. Without `faces`, `_syncAttachment` always yields null, so the tool behaves as in 09b.
- **One recompute path (C-3, R-C8b-1).** `_update(ctx, raw)` now does:
  1. `_resolve`;
  2. stores the query: the raw point (`_raw`, a reused Vector2), `objectSnap`, the camera scale and `_hasRaw`;
  3. `_syncAttachment(ctx)`;
  4. `_syncPlacement()`.
  Pointer events, the camera listener and `_onArmed` all go through it unchanged.
- **`_syncAttachment` attaches only when all of these hold:**
  - `faces` is given;
  - an entry is armed;
  - there is a stored raw point;
  - the stored object snap is on;
  - `entry.tags.contains(againstWallTag)` (R-C3-3);
  - `boxOfEntry(entry)` is not null (R-C2-2).
  It then calls `faces.attach(ctx.document, box, _raw, kWallAttachPixels / scale, mirrored: _mirrored, edgeCaptureWorld: kSnapAperturePixels / scale)`.
- **`_syncPlacement`** uses `_attached.transform` when attached; otherwise it uses today's `placementTransform`. `paintWorldOverlay` is unchanged and only reads the stored field (W-15).
- **Keys.** R, Shift+R and M call `_syncAttachment(ctx)` and then `_syncPlacement()`, reusing the stored query (see R-C7-2). M therefore mirrors the attached ghost in place. R changes `_quarterTurns` only, and the attached transform ignores the turns.
- **Release.** `placeSymbol(..., transform: _attached?.transform)`, then `faces?.bands.invalidate()`. The permission check still comes first, so a refused placement neither allocates nor invalidates.
- **Marker.** While attached, `drawNearestMarker` draws an hourglass at `q` (see R-C7-1). Otherwise `drawSnapMarker` is called as before.
- **`_onArmed` with no listened context** (hidden or idle) clears `_attached` before `_syncPlacement`.
- **`@visibleForTesting ghostAttachment`.**
- **`main.dart`.** `late final WallFaces _faces = WallFaces(_bands, accept: isUsableHost)` is handed to the tool.
  - `WallFaces` holds no subscription, so it needs no dispose; `_bands` is already disposed.
  - It reads the document each query passes it (`ctx.document`), and the host keys the shell by document (12a D2), so it never reads a stale document. Its own `_refresh` also rebuilds when the document identity changes.

## Tests added
### `symbol_place_tool_test.dart`, group "the wall attachment (spec 09c D6)"
The Rig gains optional `walls:` (the parametric system installed, walls in `attachGroup`s near (1e5, −7e4)) and `faces:`.
1. the fixtures are not degenerate
2. a tagged symbol attaches on hover and on release, byte for byte. Covers 30° (left-justified, left face) and −112.5° (right-justified, right face), mirrored and not, with R pressed. It checks against `attachToWall` and against hand arithmetic (`q = a + u·t`, `placementTransform(rotation: t)`), and presses away from the wall before releasing on it.
3. the capture is kWallAttachPixels (16 px), not the snap aperture: 300 mm attaches, 330 mm does not
4. an untagged symbol (the island) does not attach (M-09c-a)
5. with object snap off (F3) nothing attaches; on, it does (M-09c-l)
6. a tool given no wall faces never attaches (09b's behaviour)
7. M while attached mirrors in place: the footprint corners are swapped in place and the determinant flips sign (M-09c-j); both walls
8. R and Shift+R while attached change the turn count only; off the face the count applies (M-09c-k)
9. the marker is the nearest glyph at q, not at the raw or the resolved point
10. a camera zoom that brings the face within capture attaches the resting ghost (M-09c-ak)
11. a re-arm between a tagged and an untagged entry while the ghost rests near a face switches the attachment on and off; a hidden re-arm drops it too (the 8b-owed mutant)
12. W-5: a unit placed right after another snaps to it before the change stream delivers; a 250 mm gap does not snap (edge capture 10 px); one undo step each (M-09c-ap)
13. an attached placement refused by the permissions allocates nothing; once lifted, it places the attached transform

### `symbol_shell_test.dart`
- **SS16:** a fresh shell where no Wall or Opening tool ran. The wall is added by commands. Two base units are placed by mouse along a 30° face, and the second's back-centre sits at u = 1600 (snapped to the first). Each placement is one undo step, checked with undoKey twice.
- **SS17:** a wall on a hidden or a locked layer hosts nothing, while the same wall on an open layer hosts (M-09c-e).

## Gates (app; engine and render untouched, not re-run)
- `CI=true flutter test`: `04:31 +1167: All tests passed!`. The base was 1,152 (C-4); this task adds 15 (13 tool tests and 2 shell tests).
- `CI=true flutter analyze`: `No issues found!`
- `CI=true dart format --output=none --set-exit-if-changed .`: `Formatted 182 files (0 changed)`, exit 0
- `CI=true flutter build web --release`: `✓ Built build/web`, exit 0
- After a final doc-comment-only edit to `ghostAt`, I re-ran analyze, format, the two test files (`+70: All tests passed!`) and the web build. All were green.

## Mutants
Method: a `cp` backup to scratch, a scripted single-occurrence replace, `flutter test <file>`, then `cp` back. `diff` exited 0 after every restore. Line numbers are those of the pre-commit tree, which matches `2a1f8c2` apart from the one-line `ghostAt` doc change above line 150, so later lines are shifted by +1.

| Id | Where | Change | Result | Red test(s) / excerpt |
|---|---|---|---|---|
| M-09c-a | place_tool:243 | tag check deleted | red (2) | island test; re-arm test. `Expected: null Actual: ({Vector2 q, ...` |
| M-09c-j (at the call) | place_tool:248 | `mirrored: false` in `faces.attach` | red (2) | attach-on-hover/release; M test. `Which: at location [0] is <-0.866...> instead of <0.866...>` |
| M-09c-j (keys) | place_tool:390 | key path's `_syncAttachment(ctx)` deleted | red (1) | M test. `at location [0] is <-0.866...> instead of <0.866...>` |
| M-09c-k | place_tool:223 | attached transform composed with the quarter turns about the base point | red (2) | attach test; R test. `<0.4999999999999974> instead of <-0.866...>` |
| M-09c-l | place_tool:240 | `!_rawObjectSnap` dropped | red (1) | F3 test. `Expected: null Actual: ({Vector2 q, ...` |
| M-09c-ap | place_tool:445 | `faces?.bands.invalidate()` deleted | red (1) | W-5 test. `within <0.000001> of <1600> Actual: <1720.000000000006>` |
| M-09c-ap (shell) | same | same, on `symbol_shell_test.dart` | **survived** (`+17: All tests passed!`) | Expected: widget-test gestures await, so the change stream delivers between the two clicks. Killed at the tool level. |
| M-09c-ak | place_tool:303 | `_onCamera`: `_resolve` + `_syncPlacement` instead of `_update` | red (1) | zoom test. `Expected: not null Actual: <null>` |
| 8b-owed re-arm | place_tool:200 | `_onArmed`: `_resolve` + `_syncPlacement` instead of `_update` | red (1) | re-arm test. `Expected: not null Actual: <null>` |
| marker at raw | place_tool:456 | `p = attached != null ? _raw : _at.point` | red (1) | marker test. `within <1e-9> of <1756.18...> Actual: <1752.18...>` |
| marker at resolved | place_tool:456 | `p = _at.point` | red (1) | marker test. `Actual: <1752.5149999999999>` |
| glyph per spec letter | place_tool:460 | `drawSnapMarker(..., SnapKind.nearest, ...)` | red (1) | marker test. `Expected: an object with length of <4> Actual: []` (shows R-C7-1) |
| release ignores attached | place_tool:444 | `transform: null` | red (6) | attach, F3, M, R, W-5 and permissions tests. `Actual: [0.0, 1.0, -1.0, 0.0, 103050.3, -68125.7]` |
| capture constant | place_tool:247 | `kSnapAperturePixels` for the capture | red (1) | capture test. `Expected: not null Actual: <null>` |
| edge capture | place_tool:248 | `kWallAttachPixels` for the edge capture | red (1) | W-5 test. `within <0.000001> of <1850> Actual: <1600.0000000000055>` |
| hidden re-arm keeps attachment | place_tool:205 | `_attached = null` deleted | survived at first; **red** after I added the hidden re-arm assertion | re-arm test. `Expected: null Actual: (...)`. Only observable through the testing getters, because the ghost is hidden. |
| `_hasRaw` never set | place_tool:278 | deleted | red (10) | all attach tests |
| permission check removed | place_tool:439 | early return deleted | red (4) | 3 old permission tests and the new attached one |
| M-09c-e | main.dart:369 | `WallFaces(_bands)` (no `accept`) | red (1) | SS17. `Expected: <false> Actual: <true>` |
| shell hands no faces | main.dart:371 | `SymbolPlaceTool(_armed)` | red (2) | SS16 `Actual: [1.0, 0.0, 0.0, 1.0, 103075.0, -67850.0]`; SS17 |
| fresh shell (W-5, bands) | wall_bands.dart:60 | `liveWalls` without `_refresh` | red (2) | SS16, SS17 |

## Proposed rulings
- **R-C7-1 (the marker glyph).**
  - **The problem:** spec D6 says the marker is drawn "with the `SnapKind.nearest` glyph". The render layer's `drawSnapMarker` draws **nothing** for `SnapKind.nearest` (`snap_marker.dart:56-60`: "Not in kDragSnapMask: a drag never produces them"), and 09c-1 must not touch the render layer. Passing `nearest` literally would leave the attached ghost with no marker at all, which the glyph mutant above shows.
  - **What I did:** I drew AutoCAD's nearest glyph, an hourglass `kSnapMarkerPixels` wide with the marker paint, as four `drawLine` calls. It is a top-level `drawNearestMarker` in `symbol_place_tool.dart`.
  - **Cost if wrong:** one function moves to the render layer's `drawSnapMarker` `nearest` case in 09c-2, or the glyph changes shape. For the human's look list.
- **R-C7-2 (keys re-ask the faces, not the snap).**
  - **What I did:** R and M call `_syncAttachment` with the **stored** query (the raw point, the object-snap flag and the scale of the last `_update`), then `_syncPlacement`. They do not call `_resolve`. A key therefore changes only the mirror and the turns, with snap, grid and camera exactly as at the last recompute. F3 still does not refresh the ghost (the 8b note), and without faces the key path is bit for bit 09b's.
  - **Why not the full `_update`:** that would re-snap on R/M, changing 09b key behaviour, and the brief allows "or the same path". `_syncAttachment` is the attachment step `_update` itself uses.
  - **Cost if wrong:** keys call `_update(ctx, _raw)` instead; that is one line, and the stored-query fields stay.
- **R-C7-3 (W-5 at the shell).** M-09c-ap is killed only in the tool test, where the run is synchronous so the change stream has not delivered. In a widget test the gestures' awaits let the stream deliver between clicks, so SS16 cannot see a missing invalidate. Instead, SS16 kills "the shell hands no faces" and "`liveWalls` without the refresh" (the fresh-shell stale cache). Cost if wrong: none; it is a test-placement note.
- **R-C7-4 (a refused placement does not invalidate).** `invalidate()` runs only after a real commit; the permissions test pins that the generation is unchanged. Cost: one assertion.

## Found, not fixed
- `ghostAt` keeps meaning "the resolved point" while attached (its doc now says so). A caller wanting where the ghost actually sits should read `ghostAttachment`/`ghostPlacement`.
- Each attached pointer event allocates the attachment result: a record, a Vector2 and a Transform2. Free placement allocates a Transform2 too. This is off the paint path, as Task 6 documented.

## Look hardest at
- R-C7-1: the glyph drawn in the app rather than through `drawSnapMarker(nearest)`.
- R-C7-2: the key path reuses the stored query instead of a full `_update`.
- The hourglass's exact endpoints are pinned by the marker test; check the shape matches the expected nearest glyph.
