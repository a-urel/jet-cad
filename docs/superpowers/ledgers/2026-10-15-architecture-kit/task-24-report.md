# Task 24 report: the wall-face provider (spec C5, C2 "Shared caches", C1.5; D-01, D-06, D-07, D-08)

Status: DONE_WITH_CONCERNS (minor; see Concerns)

Commit: `8bd6f97f feat(architecture): the wall-face provider (3a C5)` (on `b10cf092`).

## Implementation summary

- `lib/src/attach/wall_attach.dart`: ported from `jet_cad_floor_plan/lib/src/symbols/wall_attach.dart:1-397`. It has the brief's header and imports (`SymbolBox` and `placementTransform` come from `package:jet_cad_2d_kit/authoring.dart`), lines 19-57 unchanged, and the brief's `faceRunsOf(doc, wall, LiveTypeOf live, {accept})`. Lines 70-397 are unchanged (`faceRunsAmong` through `_ranksBefore`), and `attachToWall` keeps its signature and body byte for byte. `isOrthonormal` is not copied (it is the contract's), and `WallFaces` moved to `wall_faces.dart`. The `diff` against the source shows only the header, the imports and `faceRunsOf`'s doc, signature and `wallsInDocument(doc, wall, live)` call, plus the removed tail (lines 397-550).
- `lib/src/attach/wall_faces.dart`: the brief's text, which is today's lines 409-550 with these changes: the reader `live`, `_state`, D-06's `stateId` invalidation in `_refresh`, `wallFacesOf`, and the doc lines. Its `diff` against `sed -n 409,550p` shows only the changes the brief lists, plus one 3-line comment I added in `_refresh` (see Deviations).
- `lib/src/attach/wall_face_provider.dart`: the brief's text (`kWallFaceKind`, `wallFaceProvider`, `_WallFaceProvider`).
- `lib/src/kit.dart`: added `symbols: [furnitureSource]` and `attachments: [wallFaceProvider]`, with their imports.
- Test support `test/support/wall_attach_fixture.dart`: ported. Line 11's import now points at the kit's `wall.dart`, the header gains the port line, and the fixture adds `export 'wall_fixture.dart' show liveOf, testCatalog;`.

### FREEZE RULE check
- `WallFaces` keeps no per-wall holder map of its own. Its runs are rebuilt from `bands.liveWalls(doc)`, and `_refresh` calls that before it compares `bands.generation`.
- `WallBands._refresh` → `_stillLive()` is Task 11's indexed, allocation-free loop. It bumps the generation when a cached wall is no longer live, so a freeze with no document change makes the very next read of `WallFaces` rebuild.
- `_boxes` is per definition, not per wall, and is cleared on every rebuild.
- Read path cost: a `stateId` getter, the bands' O(walls) liveness loop and two int compares. Nothing is allocated.
- **WF-frozen-first** pins the freeze with a first-reader step for each of the four readers (provider `attach`, `runsOf`, `neighboursOf`, `WallFaces.attach`), each on a fresh cache. **M-WF13** turns each one red when run individually.

### Layer rule check
- The plan toggles a layer through `SetLayerCommand` (`plan_layer_panel.dart:217`), which moves `commands.stateId`. D-06 therefore makes `WallFaces` rebuild at the next query, before the `changes` stream delivers.
- **WF-hidden-toggle** pins this: faces are built, the layer is hidden or locked by command, there is no pump, and the next query offers nothing (one rebuild). The undo is seen as well.
- Both M-WF7 and M-WF8 turn it red.

## TDD evidence

RED (tests written before any lib file):
- `flutter test test/attach/` (kit) failed to compile: `test/attach/wall_faces_test.dart:13:8: Error: Error when reading 'lib/src/attach/wall_attach.dart': No such file or directory`, plus `Method not found: 'wallFaceProvider'` / `'faceRunsOf'`, `'FaceRun' isn't a type`.
- `flutter test --enable-vmservice test/furniture/` (integration) gave:
  - FU-load `Expected: an object with length of <41> Actual: []`
  - WF-offered `Expected: an object with length of <30> Actual: WhereIterable<PlanSymbol>:[] ... premise: the library names wall-face`

GREEN:
- kit `flutter test test/attach/` → `00:00 +18: All tests passed!`
- integration `flutter test --enable-vmservice test/furniture/` → `00:00 +2: All tests passed!`

Note: running the kit attach tests from the repo root fails WF-state and WF-exclude, because `File('assets/library/furniture.jetlib')` is relative to the cwd. Run them from the package, as every gate does.

## Gates (final, on 8bd6f97f)
- kit: `flutter test` → `00:19 +584: All tests passed!`; `flutter analyze` → `No issues found!`; `dart format --output=none --set-exit-if-changed .` → `Formatted 122 files (0 changed)`; `dart pub publish --dry-run` → `Package has 0 warnings.`
- integration: `flutter test --enable-vmservice` → `00:15 +96: All tests passed!`; `flutter analyze` → `No issues found!`; format → `Formatted 31 files (0 changed)`.
- root: `dart run tool/ci/check_kit_deps.dart` → `kit dependencies: 2 package(s) checked, none names the plan library or another kit` (exit 0).
- `git status --short`: clean after the commit; no `analysis_options.yaml` touched.

**Integration diagnostics.** The library and provider now join every `architectureController()`. All 94 earlier integration tests still pass, and none changed. That includes the controller-diagnostics assertions in `opening_panel_test.dart:519-545`, `opening_frozen_test.dart:93` and `wall_grips_test.dart:426-463`.

## Mutation results (each reverted with `git checkout -- <file>`, `git diff --quiet` exit 0)
M-WF1 to M-WF9 ran on `8320fc46`, the commit before a comment-only amend. M-WF10 to M-WF13 ran on `8bd6f97f`.

| Mutation | Test | Red line |
|---|---|---|
| M-WF1 front/back swapped | WF-query | `Expected: [ -0.8660254037844403, -0.4999999999999974, 0.4999999999999974, -0.8660254037844403, 103281.69163867214, -67227.58993101033 ]` (Actual differs) |
| M-WF2 `marker: query.pointer` | WF-query | `Expected: Vector2:<[102978.15334794734,-68141.84618943237]> Actual: Vector2:<[102933.15334794734,-68063.90390309178]> plain left` |
| M-WF3 `keep: null` | WF-keep | `Expected: null Actual: <Instance of 'Attachment'> plain m.y 1.0: a face it would turn to` |
| M-WF4 kept capture ×10/16 | WF-hysteresis | `Expected: not null Actual: <null> kept: the same capture, not a smaller one` |
| M-WF4b (extra) kept capture ×16/10 | WF-hysteresis | `Expected: null Actual: <Instance of 'Attachment'> kept: the same capture, not a larger one` |
| M-WF5 `exclude: null` | WF-exclude | `Expected: a value less than <0.000001> Actual: <40.00000000000013> ... no snap to the excluded instance` |
| M-WF6 delete `exclude.length > 1` | WF-exclude | `Bad state: Too many elements` (`SetBase.single`, `wall_face_provider.dart 46:49`) |
| M-WF7 drop `accept: isUsableHost` | WF-hidden, WF-hidden-toggle | `Expected: <false> Actual: <true> hidden`; `Expected: null Actual: <Instance of 'Attachment'> hidden: the first query after the toggle` |
| M-WF8 delete stateId invalidation | WF-hidden-toggle, WF-state | `Expected: null Actual: <Instance of 'Attachment'> hidden: the first query after the toggle`; `Expected: a value less than <0.000001> Actual: <40.00000000000013> ... flush to the neighbour placed one command ago` |
| M-WF9 every WallParams + non-freezing reader | WF-frozen, WF-frozen-first | `Expected: null Actual: <Instance of 'Attachment'>` (WF-frozen); same, reason `provider` (WF-frozen-first) |
| M-WF10 delete accept check in `faceRunsOf` | WF7 | `Expected: empty Actual: [ FaceRun:FaceRun(18 left ...), FaceRun:FaceRun(18 right ...) ]` |
| M-WF11 delete `attachments:` | WF-offered (integration) | `Expected: empty Actual: ['wall-face']` |
| M-WF12 delete `symbols:` | FU-load (integration) | `Expected: an object with length of <41> Actual: []` |
| **M-WF13 (new, the freeze check)**: in `_refresh`, compare `bands.generation` before reading `bands.liveWalls(doc)`, so the bands' liveness re-check is skipped | WF-frozen-first | provider: `Expected: null Actual: <Instance of 'Attachment'> provider`; with the reader list cut to each one in turn (a temporary test edit, reverted): runsOf `Expected: every element(<19>) Actual: [18, 18, 19, 19]`; neighboursOf `Expected: an object with length of <2> Actual: [[], [], [], []]`; attach `Expected: null Actual: ({... run: FaceRun(18 left ...) ...})` |

## Ported-test accounting (D-01, kit part)
`jet_cad_floor_plan/test/symbols/wall_faces_test.dart` WF1-WF9 → `packages/jet_cad_2d_kit_architecture/test/attach/wall_faces_test.dart` WF1-WF9, all 9 in the kit, all assertions unchanged. The change classes are imports, plus a fixture change: the reader argument `liveOf(<doc>)` on the 19 `faceRunsOf`, 6 `hostFrameInDocument` and 1 `layoutInDocument` calls (26 in total). WF7's `faceRunsOf(doc, h, accept: allow)` became `faceRunsOf(doc, h, liveOf(doc), accept: allow)`. The support imports keep their `show` lists. `wall_attach_test.dart`, `wall_attach_property_test.dart` and `symbol_move_test.dart` belong to Task 28.

## Files changed
- `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/architecture-kit/packages/jet_cad_2d_kit_architecture/lib/src/attach/wall_attach.dart` (new)
- `.../jet_cad_2d_kit_architecture/lib/src/attach/wall_faces.dart` (new)
- `.../jet_cad_2d_kit_architecture/lib/src/attach/wall_face_provider.dart` (new)
- `.../jet_cad_2d_kit_architecture/lib/src/kit.dart`
- `.../jet_cad_2d_kit_architecture/test/support/wall_attach_fixture.dart` (new)
- `.../jet_cad_2d_kit_architecture/test/attach/wall_faces_test.dart` (new)
- `.../jet_cad_2d_kit_architecture/test/attach/wall_face_provider_test.dart` (new)
- `.../jet_cad_2d_integration/test/furniture/furniture_load_test.dart` (new)

## Deviations
1. **Two provider cases beyond the brief, from the controller's task notes:**
   - **WF-hidden-toggle**: a layer hidden or locked by command while the faces are cached is seen at the next query with no pump; the undo is seen too.
   - **WF-frozen-first**: the first-reader steps for each of the four readers on an L, where the other wall keeps its faces and there is exactly one rebuild.

   To support them, the provider test also imports `src/attach/wall_faces.dart` (`wallFacesOf`), and `servicesOf`'s doc says the frozen set is read live. The brief's seven cases are as written, apart from `dart format`.
2. **A 3-line comment in `WallFaces._refresh`** says why `liveWalls` is read before the generation compare (the freeze path). The code is unchanged. The commit was amended once to reword that comment; the amend changed nothing else.
3. **Fixture header.** The port line is placed as the last line of the header comment, just before the imports.
4. **Two extra mutations**: M-WF4b (the kept capture made larger) and M-WF13 (the freeze check).

## Concerns
- **CHANGELOG.** The kit's CHANGELOG has no entry for the provider or the furniture library. The brief's file list does not include it, and Tasks 13-23 added none either. The reconcile or finish pass should add the 3a lines.
- **Layers changed outside a command.** `WallFaces` does not compare `doc.tables.mutationRevision` as the opening tool's host scan does. A layer edited outside a command is seen only when the `changes` stream delivers. The plan's layer panel always uses `SetLayerCommand`, which D-06 covers, and WF-hidden-toggle pins it. This is not a defect against today's behaviour; it is recorded for completeness.
- **WA9 and D-06.** Each command now invalidates the shared bands at the next `WallFaces` read, and the stream delivery invalidates them again. A command followed by a query, then the delivery, then a query therefore rebuilds twice. This matches the brief's reading of WA9 ("a delivered change and a moved state each lead to one rebuild"), but Task 28's WA9 port should confirm it.

## Fix report (review round 1: pin D-06's steady state)

Commit: `e35cc9ff test(kit-architecture): pin WallFaces' steady state (3a D-06)` (on `8bd6f97f`).

- **WF-hidden-toggle.** After the `builds + 1` check, the test runs the same `provider.attach` query again. It still answers null, and `wallFacesOf(s).builds` stays `builds + 1`, with the reason "no rebuild over an unchanged state".
- **WF-frozen-first.** After the closing `runsOf` read, the test asserts `faces.builds` is still `builds + 1`, with the reason "no rebuild at the next read".
- **`WallFaces` class doc.** It now says that a read over a cached set first runs the bands' O(walls) liveness check, and that a query is then O(runs) with O(1) allocation.
- **M-WF14** (delete `_state = state;` in `_refresh`, on e35cc9ff) went red in both tests, then was reverted (`git diff --quiet` exit 0):
  - WF-hidden-toggle: `Expected: <2> Actual: <3> hidden: no rebuild over an unchanged state`
  - WF-frozen-first: `Expected: <2> Actual: <3> provider: no rebuild at the next read`
- **Gates (on e35cc9ff).**
  - kit `flutter test` → `00:19 +584: All tests passed!`
  - `flutter analyze` → `No issues found!`
  - format → `Formatted 122 files (0 changed)`
  - `dart pub publish --dry-run` → `Package has 0 warnings.`
  - `check_kit_deps` → `kit dependencies: 2 package(s) checked, none names the plan library or another kit`
  - `git status --short`: clean.
  - The integration package was not touched, so its gates were not re-run.
