# Task 28 report: the wall attachment end to end, R-16's room lines, the paint invariant

Status: DONE_WITH_CONCERNS (the concerns are listed at the end; no assertion was changed, and no failing test is outstanding)

Commit: `9ad8f0e5 test(integration): the wall attachment end to end, R-16, the paint invariant (3a Task 28)` (on top of 524cc375)

## Implementation summary

- **Kit (R-P1, R-P3):** `test/attach/wall_attach_test.dart` (WA1-WA18, WK0-WK4, 23 cases), `test/attach/wall_attach_property_test.dart` (WP1, WP2), `test/furniture/symbol_box_asset_test.dart` (3), `test/furniture/symbol_end_to_end_test.dart` (2), and `test/support/select_rig.dart` (copied unchanged). `test/support/place_entry.dart` gained `InstanceStyle` and a `style:` parameter. See Deviation 2.
- **Integration support:**
  - New: `attach_plans.dart`, `shot.dart`, `fill_plan.dart`, `zone_plan.dart`.
  - `units.dart`: `entryOf` now keeps `attachTo` and `family`.
  - `editor_fixture.dart`: `mountEditor` gained `bool snapping = true`.
  - `canvas_rig.dart` gained `worldAt` (the canvas's read of a pointer). See Deviation 3.
- **Integration tests:**
  - `attach/`: `symbol_move_test` (6), `wall_attach_tool_test` (12), `against_wall_rotate_test` (3), `wall_attach_end_to_end_test` (WE1), `symbol_shell_test` (SS16, SS17), `editor_tools_review_test` (3).
  - `symbols/symbol_search_test` (12).
  - `service/room_fill_test` (TF1-room, TF3-count, TF7-tint).
  - `export/room_export_test`: the premise test, then EX2-room, EX3-room, EX5-room.
  - `controller/zone_room_test` (CZ1).
  - `invariants/paint_allocation_test` (IA-alloc).

## TDD evidence

These are ports against code that already exists, so no RED existed before the test. RED was shown instead by the Step 14 mutations below, each run on committed code. While porting, the first real failures were:
- `SymbolEntry` has no `key`, so `e.key` became `e.symbol.key`.
- `c.snap` is `@internal` (analyzer). The premise became `pressKey(F3)` returning handled.
- Two mice on device 0 in R-3 tripped a `mouse_tracker` assertion. The fix reads through the resting mouse.
- WE1's `spans[0].lo` came out as `3.27e-9`, not within `1e-9`. See Deviation 5.

## Gates (run after the final edits)

- **Kit** `packages/jet_cad_2d_kit_architecture`:
  - `dart format .` → `Formatted 136 files (0 changed)`
  - `flutter test` → `00:19 +650: All tests passed!`
  - `flutter analyze` → `No issues found! (ran in 3.8s)`
  - format check → exit 0
  - `dart pub publish --dry-run` → `Package has 0 warnings.` (after the commit; before it, the only warning was "1 checked-in file is modified in git")
- **Integration** `packages/jet_cad_2d_integration`:
  - `dart format .` → `Formatted 79 files (0 changed)`
  - `flutter test --enable-vmservice` → `00:54 +226: All tests passed!`
  - `flutter analyze` → `No issues found! (ran in 3.8s)`
  - format check → exit 0
- **Repo root:** `dart run tool/ci/check_kit_deps.dart` → `kit dependencies: 2 package(s) checked, none names the plan library or another kit`
- `grep -rn "package:jet_cad_2d_plan/src\|package:jet_cad_2d_kit_architecture/src" packages/jet_cad_2d_integration` → nothing.
- `grep -rln invalid_use_of_internal_member packages/jet_cad_2d_integration/test` → this task adds only `controller/zone_room_test.dart` (`room_export_test` uses `c.export`, not `pageFlows`). The brief expected this grep to list only Task 26's `room_paint_test.dart`; that is stale. Earlier tasks already carry the ignore in 19 other files (l10n, wall, room, opening, panels, dimension, `opening_support.dart`).
- **Non-ASCII.** A script checked every quoted literal containing non-ASCII in `test/attach/*.dart` and `test/symbols/*.dart` against the source files: every fragment is present verbatim. There are 26 lines with `−`, `°` or `²`.
- `git status --short` was empty after the commit and after every mutation revert. No `analysis_options.yaml` was touched.

## Mutations (committed code; every revert by `git checkout --` was followed by `git diff --quiet` → exit 0)

| Mutation | Test | Result (quoted red line) |
|---|---|---|
| M-IA-alloc `plan_canvas.dart:381` `resolver: _resolver` → `canvasResolverFor(_c.document, paper: _paperArgb(), dark: _darkCanvas)` (a fresh resolver every build) | IA-alloc | RED: `Expected: true Actual: <false> a rebuild handed DraftCanvas a new resolver` |
| M-IA-1 `wall_face_provider.dart` `kWallFaceKind = 'wall-face-x'` | wall_attach_tool "a tagged symbol attaches on hover and on release"; WE1 | Both RED: `Expected: [-0.8660254037844403, -0.4999999999999974, ...` (the provider's transform; the commit was free). Also red under it: MV1, MV4, SS16, SS17. |
| M-IA-2 `wall_face_provider.dart` `keep: query.mayRotate ? null : query.current` → `keep: null` | against_wall_rotate `rotate: false` | RED: `Expected: [1.0, 0.0, 0.0, 1.0] Actual: [0.0, -1.0, 1.0, 0.0] ... the east face may not turn it`. R-1 (`not turned to the north face`) and R-3 (`ghostAttachment isNull`) are red too. |
| M-IA-3 `wall_faces.dart` stateId comparison removed | SS16 | **Stayed GREEN** (`00:02 +2: All tests passed!`). wall_attach_tool W-5 is green too. Why: in a widget test the pumps between the two clicks deliver the document's async change stream to the bands, which invalidate on their own, so the stateId check never decides. SS16 is unchanged, as the brief asks. Coverage evidence: under the same mutation Task 24's kit `test/attach/wall_face_provider_test.dart:326` goes RED: `Actual: <40.00000000000013> ... flush to the neighbour placed one command ago`. |
| M-IA-4 `wall_faces.dart:186` `accept: isUsableHost` → `(_, __) => true` | SS17 | RED: `Expected: <false> Actual: <true> Hidden` |
| M-IA-5 `room.dart:133` `kRoomColorTransparency` 204 → 230 | TF1-room | RED: `Actual: <26> ... the room's tint alone: 0xe6f3f2, want 0xcce7e5`. EX2-room, EX3-room (`0: the room's tint stays`) and TF7-tint (`tint 0x1e2a2c, want 0x1d3636`) are red too. |

## Ported-test accounting

Change classes: C1 = ids/keys, C2 = tags to fields, C3 = widget form. IA-R1 to IA-R6 are the brief's rulings.

### Kit cases

| Old case | New case | Change |
|---|---|---|
| wall_attach_test WA1-WA18, WK0-WK4 (23) | kit `test/attach/wall_attach_test.dart`, same names | C1 (`architecture.bath.toilet`); `placeEntry`; R-P3 `liveOf` parameters; the neighbours group's shared bands read the scene's document (Deviation 1); `e.symbol.key` |
| wall_attach_property_test WP1, WP2 | kit `wall_attach_property_test.dart` | same adaptations |
| symbol_box_test :321-339 (2 cases), :391-410 (1 case) | kit `symbol_box_asset_test.dart` (3) | C1 (`architecture.` prefix, `armchair` → `architecture.armchair.single`, `e.symbol.key`); `registerKitComponents`; `placeEntry` |
| symbol_end_to_end_test (2) | kit `symbol_end_to_end_test.dart` | C1 `architecture.bed.double`; `prepareDocument` less DASHED and the old catalog; `placeEntry` with `style:` (Deviation 2); codec registrations are the page and the contract's |

### symbol_move_test (integration, IA-R2 and IA-R3)

| Old case | New case | Change |
|---|---|---|
| MV1-MV6 | `attach/symbol_move_test.dart` | `fx.test.*`, `attachTo` (C1, C2); dragged through plan.select; `attachedAt` comes from the provider (IA-R1) |

- MV1's marker line is not ported (IA-R3, human).
- MV3's "no library" clause is not ported (IA-R3, premise impossible).
- MV3's three clauses run in one case, mounting an editor per clause.

### The wall attachment group (integration, IA-R4)

`symbol_place_tool_test.dart:1372-1716` → `attach/wall_attach_tool_test.dart`, 12 cases, names unchanged. A ghost read is the click's commit, read and then undone, so the `undoDepth` and `.single` lines stay verbatim (Deviation 4).

Not ported:
- "a tool given no wall faces never attaches": premise impossible (C7).
- `rig.notifications` (2 places), the marker case's `paintOverlay` and `drawLine`/`drawRect` lines, and `rig.tool.faces isNull`: IA-R4, human.
- Concern 2: `bands.generation` lines in W-5 and the permissions case.

### The apps' tests and the review cases (integration, IA-R5)

| Old case | New case | Notes |
|---|---|---|
| against_wall_rotate ×3 | `attach/against_wall_rotate_test.dart` | R-3's ghost reads are clicks through the resting mouse, then undone (IA-R4) |
| apps WE1 | `attach/wall_attach_end_to_end_test.dart` | |
| apps SS16, SS17 | `attach/symbol_shell_test.dart` | SS17's `isUsableHost` premise becomes the layer's `visible && !locked` |
| editor_tools_review: north wall, O13a, O13b | `attach/editor_tools_review_test.dart` | `Caps.snapping` → `PlanEditor.snapping`; `view.grips` → `gripsOf` |

WE1 details:
- The hovered-ghost lines are human (IA-R5); they are not ported.
- The save round trip is `c.save()` and a second controller.
- WE2 is not ported (umbrella decision 9).

### symbol_search_test (integration)

`symbols/symbol_search_test.dart:76-164` and `:189-267`, 12 cases. C1 ids (`architecture.<key>@1`, `@2` → `@1`, `armchair` → `armchair.single`). The result is read from the gallery's cell and header keys in tree order. Every term still hits its single field: no key-only finding.

### R-16 room lines (integration, IA-R6)

| Old lines | New case |
|---|---|
| TF1 :542-545 | `service/room_fill_test.dart` TF1-room |
| TF3 :587 (`hasLength(6)`) and its 3 `isNull` premises | TF3-count |
| TF7 :690-711, :718-719 | TF7-tint |
| EX2 :237-241 | `export/room_export_test.dart` EX2-room |
| EX3 :277-278 | EX3-room |
| EX5's R row | EX5-room |
| premises key list :140-143 | `room_export_test` "the fixture premises..." |
| CZ1 :559-586 | `controller/zone_room_test.dart` CZ1 (whole) |

### New

IA-alloc → `invariants/paint_allocation_test.dart`: green; it also passes its `frameTriangleCount > 1000` premise.

## Deviations (each with its reason)

1. **wall_attach_test's neighbours group.** Today's `setUp(() => bands = WallBands())` has no document. The brief's `WallBands(liveOf(doc))` cannot be written in `setUp`. The group's shared bands and faces read through `String? live(Handle h) => liveOf(scene)(h)`, and each case sets `scene` before its first read: WA7, WA8 and WA9 to their document, WA9 also to its "other" document, and WA10 to its scene. No assertion was touched. WA9's build counts pass unchanged (1 through 6).
2. **`place_entry.dart` gained `InstanceStyle` and `style:`.** It is the plan placer's class, copied. symbol_end_to_end needs today's coloured instance (`placeSymbol(..., style:)`). R-P14 says extend the support, so the existing placer was extended rather than copied. The file is not in the brief's commit list; it was added to the commit.
3. **`worldAt` added to `canvas_rig.dart`**, copied from dimension_shell_test's test-local helper. The brief names it as the canvas's read and gives it no support home. canvas_rig.dart is not in the brief's commit list; it was added to the commit.
4. **IA-R4 ghost reads.** The brief says each ghost read is "the instance one click commits … `undoDepth` expectations shifted". Each read here clicks, reads the newest instance and undoes. So the source's `undoDepth` values and `instances.single` stay verbatim, and the document a later read sees is the source's.
   - `quarterTurns` is read as the commit off the face, where the turns apply.
   - "pressed away" uses `away(run)`, 2 m into the room. The source's pA is 20 m away, off the canvas.
   - A mid-press `ghostAttachment isNull` read becomes a ghost read at that point.
   - "Hidden re-arm": the pointer leaves the canvas, then a click reads.
5. **WE1 inside corner.** The run's `a` is hand arithmetic: the meet of A's and B's inside face lines. Cramer's rule over absolute coordinates near 1e5 put it `3.27e-9` from the kit's corner along `t`, which broke `spans[0].lo closeTo(0, 1e-9)`. The meet is now solved along A's face from its own point, in relative coordinates, and the assertion passes unchanged. Only the oracle's arithmetic changed; the tolerance did not.
6. **The move tests' plan page has `snapToGrid: false`.** Today's scene had no page, so no grid moved the drag. The press point is the left edge's middle for the bed (MV4's `(0,1000)`). For the unit it is `(0,120)`: a mid-edge press would release 30 mm from the unit's own old right-edge midpoint, and plan.select's drag object-snaps there. Today's MV6 called the resolver directly, so it never met this.
7. **TF1-room camera.** It runs under 2b's `viewCamera` (0.06 px/mm, today's `pumpPlan`), not `painterCamera`. Under `painterCamera` the 1440 x 900 editor's canvas cannot hold R. TF3-count uses `painterCamera`, which `FillSpy.fillOf` needs.
8. **WE1 handles.** The groups are turned as today's handles 7 and 8 turned them (`rotations:`). Today's launch document holds DASHED at 6, so its first walls take 7 and 8. This is inferred, not run against the app.
9. **CZ1's `boundOf`** reads the units through `units.dart`'s labels and the definition's `SymbolComponent` key. 2b's version reads the plan's internal unit index. `frameUnits` and its constants are copied, with the source lines cited.

## Concerns

1. **M-IA-3 stays green on SS16.** The reason and the kit coverage are given in the mutation table. The brief says report it; SS16 is unchanged.
2. **Human (A14), beyond IA-R4's list.** W-5's `bands.generation` lines and the permissions case's `rig.bands!.generation` lines have no public read: the kit's bands live in the plan's services. They are left out with "Not ported" comments and need the human's word.
3. **Coverage lost through clicks.** The zoom (M-09c-ak) and R-3 "with no pointer event" cases now read through a click. The click re-resolves on its own events, so these two ports no longer pin the camera listener or the gate-change re-resolve. 2a's AT tests cover those paths (IA-R4).
4. **Stale grep expectation.** The brief's `invalid_use_of_internal_member` grep result is outdated: 19 files from earlier tasks carry the ignore. This task adds only zone_room_test.

## Files

Kit:
- `packages/jet_cad_2d_kit_architecture/test/attach/{wall_attach_test,wall_attach_property_test}.dart`
- `packages/jet_cad_2d_kit_architecture/test/furniture/{symbol_box_asset_test,symbol_end_to_end_test}.dart`
- `packages/jet_cad_2d_kit_architecture/test/support/{select_rig,place_entry}.dart`

Integration support:
- `packages/jet_cad_2d_integration/test/support/{attach_plans,shot,fill_plan,zone_plan}.dart` (new)
- `packages/jet_cad_2d_integration/test/support/{units,editor_fixture,canvas_rig}.dart` (modified)

Integration tests:
- `packages/jet_cad_2d_integration/test/attach/*.dart` (6)
- `packages/jet_cad_2d_integration/test/symbols/symbol_search_test.dart`
- `packages/jet_cad_2d_integration/test/service/room_fill_test.dart`
- `packages/jet_cad_2d_integration/test/export/room_export_test.dart`
- `packages/jet_cad_2d_integration/test/controller/zone_room_test.dart`
- `packages/jet_cad_2d_integration/test/invariants/paint_allocation_test.dart`

---

# Fix round 1

Commit: `20d592d9 test(integration): resting-ghost reads, library order, a turned IA-alloc (3a Task 28 fix)` (on 9ad8f0e5)

## Fixes

1. **IMPORTANT 1: ghost reads with no pointer event.** A click re-resolves the ghost, so a click cannot show a re-resolve that happens without a pointer event. Such reads now come from the resting ghost's own drawing, through the public `Tool` API on the canvas's active tool (the guard forwards both calls):
   - `restingMarker` paints `activeTool(tester).paintOverlay` (the call `SelectionOverlayPainter` makes, `selection_overlay.dart:219`) into a recording canvas. It returns the centre of the hourglass (the attachment's nearest glyph), or null when the ghost is free or hidden.
   - `restingPlacement` reads `paintWorldOverlay` at rebase origin 0. The matrix it hands to `canvas.transform` is exactly `ghostPlacement` (`symbol_ghost.dart:94-97`).
   - The helpers live in `attach_plans.dart` (`RecordingCanvas`, `overlayOf`, `restingMarker`, `restingPlacement`, `screenAt`).
   - The wall_attach_tool rig now uses one resting mouse. A second mouse on the same device trips the mouse tracker.

   The cases rewired:
   - **Zoom:** the marker and the placement are read right after each `zoomAt`. The commit check at the same pointer is kept.
   - **R-3:** the marker and the placement are read after each permissions change. The click commit check is kept at the end. Its title now holds as written ("with no pointer event").
   - **Re-arm:** each re-arm is read through the painter. In the hidden block, the premise (attached, then hidden: `restingPlacement` is null) is kept. Its two "hidden re-arm" lines are now "Not ported (IA-R4: the read needs a pointer event, which re-resolves)": a hidden ghost draws nothing, and bringing the pointer back re-resolves it.
   - **M and R keys:** `p0` is read on the resting ghost (its click commit is also checked). `p1` after M, "M again", "R" and "R, R, Shift+R" are painter reads. The quarterTurns reads stay off-face clicks.
   - **Marker case:** its paint lines are ported nearly verbatim on the canvas's own call (no `drawRect`, four `drawLine`s, centre at q, the glyph corners). They were previously listed as "Not ported (IA-R4)".
   - **Permissions case:** its `ghostAttachment isNotNull` premise is now a painter read.
2. **IMPORTANT 2: blank-query order.** The blank-query case now compares against `furniture.entries.map((e) => '${e.symbol.key}@${e.symbol.version}')` (the asset's order).
3. **Minors:**
   - dimension_shell_test's local `worldAt` is removed; it imports canvas_rig's.
   - `answerAt`, `instancesOf`, `partsOf` and a new `rawWorldAt` live in `attach_plans.dart`. The copies are removed from symbol_move, wall_attach_tool, WE1 and SS. The review test keeps its own `Set<Handle>` `instancesOf`: it is today's `t.instancesOf`, a different type.
   - zone_room_test's local `kPlanMinScale`/`kPlanMaxScale` are removed; it uses the plan barrel's.
   - W-5 notes that the kit's `wall_face_provider_test` pins the before-delivery stateId path.
   - IA-alloc: camera `b` is the fit turned 0.2 rad about the canvas's centre. Six `architecture.*` instances are placed by `armSymbol` and a click before the frames: bed, three-seat sofa, toilet, round dining table, and the base unit twice, so one definition draws two instances. They join the selection. **IA-alloc stays GREEN**; no allocating site found.

## Mutations (committed code; each reverted with `git checkout --`, then `git diff --quiet` → 0)

| Mutation (`plan_symbol_tool.dart` unless named) | Test | Result |
|---|---|---|
| :323 `_onCamera`'s `_update(...)` removed (the camera listener's re-resolve) | zoom case | RED: `Expected: not null  Actual: <null>` (the marker after the zoom) |
| :205 `gatesChanged`'s `_syncAttachment(ctx)` removed | R-3 | RED: `Expected: null  Actual: Offset:<Offset(1609.5, 321.9)>  ghostAttachment isNull` |
| :222 `_onArmed`'s `_update(...)` → `_syncPlacement()` (re-arm re-resolve) | re-arm case | RED: `Expected: not null  Actual: <null>  the toilet` |
| :219 `_onArmed`'s `_attached = null` removed | re-arm case | **GREEN.** With a listening context, `_update` → `_syncAttachment` clears `_attached` itself. The line decides only on the hidden path (no context), which a read cannot reach without a pointer event: those two lines are the ones not ported. |
| :411 the key handler's `_syncAttachment(ctx)` removed | M while attached | RED: `Expected: [0.8660254037844403, 0.4999999999999974, 0.4999999999999974, ...` (p1 is still the unmirrored attachment) |
| M-IA-alloc (`plan_canvas.dart:381`, a fresh resolver per build), re-run on the strengthened IA-alloc | IA-alloc | RED: `Expected: true  Actual: <false>  a rebuild handed DraftCanvas a new resolver` |
| M-IA-2 re-run on the rewritten R-3 | against_wall_rotate | RED, 3 of 4 (incl. R-3: `Expected: null  Actual: Offset:<Offset(1609.5, 321.9)>`) |

## Gates

- Integration:
  - `flutter test --enable-vmservice` → `00:55 +226: All tests passed!`
  - `flutter analyze` → `No issues found!`
  - format check → exit 0
- Kit:
  - `flutter test` → `00:20 +650: All tests passed!`
  - `flutter analyze` → `No issues found!`
  - format check → exit 0
- `check_kit_deps` → `kit dependencies: 2 package(s) checked, none names the plan library or another kit`
- `git status` is clean after the commit and after every revert.

## Remaining concerns

1. M-IA-3 (from round 0) still stays green on SS16; the kit covers it.
2. M-c2 (`_attached = null`) stays green, for the reason given in the table.
3. The `bands.generation` lines still need the human's word (A14).
