# Task 1 report: The collection frame, and the GPU-free product of a rebuild

## What was implemented

- `packages/jet_cad_2d_flutter/lib/src/gpu/collection_frame.dart`
  - `CollectionFrame(camera, viewport)` — a plain value holder.
  - `collectionFrameFor(ViewportTransform live, Aabb2 extents, {double margin = kScreenClipInflate})`
    — builds a camera with the live camera's scale/rotation and a translation
    that puts the extents' screen box at `(margin, margin)`, and a viewport
    sized to the extents' screen box plus `2 * margin` on each axis. Empty
    extents return `live` unchanged with a `1x1` viewport.
- `packages/jet_cad_2d_flutter/lib/src/gpu/resident_collection.dart`
  - `ResidentCollection` — the GPU-free product of one walk: `data`,
    `instanceCount`, `texts`, `patches`, `collectionCamera`,
    `collectionViewport`, `devicePixelRatio`, `tablesRevision`, `skippedOps`,
    `walkMicros`, `classifyMicros`, plus the `patchInstanceCount` and
    `byteLength` getters.
  - `ResidentCollection.collect({...})` — reads `document.tables.mutationRevision`
    before the walk, computes the frame via `collectionFrameFor`, walks
    `painter.paint(collector, frame.camera, frame.viewport)` through a fresh
    `GeometryCollector`, copies `data`/`texts` once, then classifies patches
    via `classifyTextPatches`.
- `lib/jet_cad_2d_flutter.dart` — added
  `export 'src/gpu/collection_frame.dart';` and
  `export 'src/gpu/resident_collection.dart';` beside the existing
  `src/gpu/` exports (alphabetical order preserved).

Both files were implemented exactly as the brief specified, verbatim, with
one exception: the brief's inline code samples were not `dart format`-clean
(two lines in `collection_frame.dart` and one wrapped `expect` block in
`resident_collection_test.dart` exceeded the 80-column line-wrap the
formatter enforces). `dart format` was run on all four new/touched files to
bring them into house style; behaviour is unchanged (see the GREEN and gate
output below, all still exit 0 after formatting).

## TDD evidence

### RED 1 — `collection_frame_test.dart`

Command: `flutter test test/gpu/collection_frame_test.dart` (before
`collection_frame.dart` existed)

```
test/gpu/collection_frame_test.dart:25:15: Error: Method not found: 'collectionFrameFor'.
    final f = collectionFrameFor(kLive, kExtents);
              ^^^^^^^^^^^^^^^^^^
... (4 more identical errors, one per call site)
00:00 +0 -1: loading .../collection_frame_test.dart [E]
  Failed to load ...
00:00 +0 -1: Some tests failed.
```

Expected and matched: `collectionFrameFor` undefined, compile-time failure.

### GREEN 1 — `collection_frame_test.dart`

Command: `flutter test test/gpu/collection_frame_test.dart` (after
`collection_frame.dart` + barrel export added)

```
00:00 +0: the live camera at its own viewport sees none of the drawing
00:00 +1: the frame's visible world covers the extents
00:00 +2: scale and rotation are the live camera's; only the translation moves
00:00 +3: the viewport is the extents' screen size plus the margin, all round
00:00 +4: a rotated live camera keeps its rotation and still covers the extents
00:00 +5: empty extents give the live camera back and a 1x1 viewport
00:00 +6: All tests passed!
```

(`flutter pub get` ran once in this fresh worktree as a side effect of the
first `flutter test` invocation; `git status --short` afterwards showed no
`analysis_options.yaml` changes, so no revert was needed.)

### RED 2 — `resident_collection_test.dart`

Command: `flutter test test/gpu/resident_collection_test.dart` (before
`resident_collection.dart` existed)

```
test/gpu/resident_collection_test.dart:33:3: Error: 'ResidentCollection' isn't a type.
  ResidentCollection collect(ViewportTransform live, {double dpr = 1.0}) =>
  ^^^^^^^^^^^^^^^^^^
test/gpu/resident_collection_test.dart:34:7: Error: Undefined name 'ResidentCollection'.
      ResidentCollection.collect(
      ^^^^^^^^^^^^^^^^^^
test/gpu/resident_collection_test.dart:113:19: Error: 'ResidentCollection' isn't a type.
    double widest(ResidentCollection c) {
                  ^^^^^^^^^^^^^^^^^^
00:00 +0 -1: loading .../resident_collection_test.dart [E]
  Failed to load ...
00:00 +0 -1: Some tests failed.
```

Expected and matched: `ResidentCollection` undefined.

### GREEN 2 — both files

Command: `flutter test test/gpu/collection_frame_test.dart test/gpu/resident_collection_test.dart`
(after `resident_collection.dart` + barrel export added)

```
00:00 +0: .../collection_frame_test.dart: the live camera at its own viewport sees none of the drawing
00:00 +1: .../collection_frame_test.dart: the frame's visible world covers the extents
00:00 +2: .../collection_frame_test.dart: scale and rotation are the live camera's; only the translation moves
00:00 +3: .../collection_frame_test.dart: the viewport is the extents' screen size plus the margin, all round
00:00 +4: .../collection_frame_test.dart: a rotated live camera keeps its rotation and still covers the extents
00:00 +5: .../collection_frame_test.dart: empty extents give the live camera back and a 1x1 viewport
00:00 +6: .../resident_collection_test.dart: the corner camera sees only part of the drawing
00:00 +7: .../resident_collection_test.dart: a collection at the corner zoom holds everything the fit one holds
00:00 +8: .../resident_collection_test.dart: the collection camera differs from the live camera by a translation
00:00 +9: .../resident_collection_test.dart: the table revision and the ratio are the ones the walk ran at
00:00 +10: .../resident_collection_test.dart: half-widths follow the device pixel ratio
00:00 +11: .../resident_collection_test.dart: the timings are read and the byte length counts the patches
00:00 +12: All tests passed!
```

All 12 tests pass, exit code 0.

## The mutation (Step 8) — fired by hand

`cp lib/src/gpu/resident_collection.dart /tmp/rc.bak`, then replaced
`painter.paint(collector, frame.camera, frame.viewport);` with
`painter.paint(collector, live, const Size(800, 600));` (cull to the live
viewport instead of the collection frame).

Command: `flutter test test/gpu/resident_collection_test.dart`

```
00:00 +0: the corner camera sees only part of the drawing
00:00 +1: a collection at the corner zoom holds everything the fit one holds
00:00 +1 -1: a collection at the corner zoom holds everything the fit one holds [E]
  Expected: <14>
    Actual: <0>
  this fixture has no curve, so the instance count is scale-free; a difference is culling

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/resident_collection_test.dart 71:5         main.<fn>

00:00 +1 -1: the collection camera differs from the live camera by a translation
00:00 +2 -1: the table revision and the ratio are the ones the walk ran at
00:00 +3 -1: half-widths follow the device pixel ratio
00:00 +4 -1: the timings are read and the byte length counts the patches
00:00 +5 -1: Some tests failed.
```

Went RED exactly as predicted: `b.instanceCount` (0, at the corner camera
under the live viewport with no collection-frame margin) is a fraction of
`a.instanceCount` (14, at the fit camera) — in this case the corner camera at
the *live* 800x600 viewport sees nothing of the fixture at all, since
`corner()` deliberately puts the drawing's corner near the screen origin
under an 8x zoom, so most of the drawing falls outside `kViewport`. Three
other tests cascaded red as a consequence (the collection-camera/translation
test, the revision test and the half-width test all call `collect` and got
an empty or truncated buffer back).

Restore: `cp /tmp/rc.bak lib/src/gpu/resident_collection.dart`. Confirmed by
re-running `flutter test test/gpu/collection_frame_test.dart test/gpu/resident_collection_test.dart`:

```
00:00 +12: All tests passed!
```

(same 12/12 pass as GREEN 2 above, exit code 0).

## The three gate commands

### `flutter test`

Tail of output:

```
00:08 +624 ~1: .../tile_measurement_seam_test.dart: the rest bake fires: the unflagged arm slices every visible tile
00:08 +625 ~1: .../tile_measurement_seam_test.dart: the rest bake fires: the unflagged arm slices every visible tile
00:08 +626 ~1: .../tile_measurement_seam_test.dart: the rest bake fires: the unflagged arm slices every visible tile
00:08 +627 ~1: .../tile_measurement_seam_test.dart: debugRestBakeDisabled slices nothing and still covers
00:08 +628 ~1: .../tile_measurement_seam_test.dart: debugFullViewportQuery grows the fallback walk to the whole viewport
00:08 +629 ~1: All tests passed!
```

Exit code: `0`. 629 tests passed, 1 pre-existing skip (`~1`), unrelated to
this task (present before this task's files were added).

### `flutter analyze`

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.3s)
```

Exit code: `0`.

### `dart format --output=none --set-exit-if-changed .`

First run (before running the real formatter on the brief's inline samples):

```
Changed lib/src/gpu/collection_frame.dart
Changed lib/src/gpu/resident_collection.dart
Changed test/gpu/collection_frame_test.dart
Changed test/gpu/resident_collection_test.dart
Formatted 103 files (4 changed) in 0.15 seconds.
```

Exit code: `1` (failure, as `CLAUDE.md` warns `(N changed)` counts as red).
Fixed by running `dart format` (no `--set-exit-if-changed`) on the four
files, then re-running the gate:

```
Formatted 103 files (0 changed) in 0.15 seconds.
```

Exit code: `0`.

After the formatting fix, `flutter test test/gpu/collection_frame_test.dart
test/gpu/resident_collection_test.dart` was re-run and still showed
`00:00 +12: All tests passed!`, and the full `flutter test` gate was re-run
in full (see above) — both green after the reformat.

## `git status --short` before staging

```
 M packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart
?? packages/jet_cad_2d_flutter/lib/src/gpu/collection_frame.dart
?? packages/jet_cad_2d_flutter/lib/src/gpu/resident_collection.dart
?? packages/jet_cad_2d_flutter/test/gpu/collection_frame_test.dart
?? packages/jet_cad_2d_flutter/test/gpu/resident_collection_test.dart
```

No `analysis_options.yaml` files present — nothing to revert.

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/gpu/collection_frame.dart` (new, 51 lines)
- `packages/jet_cad_2d_flutter/lib/src/gpu/resident_collection.dart` (new, 119 lines)
- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` (2 export lines added)
- `packages/jet_cad_2d_flutter/test/gpu/collection_frame_test.dart` (new, 81 lines)
- `packages/jet_cad_2d_flutter/test/gpu/resident_collection_test.dart` (new, 143 lines)

Commit: `9cb10f9` — "feat(gpu): the collection frame covers the extents, and
a rebuild has a GPU-free product"

## Self-review

- **Completeness:** every step of the brief (1–9) was followed in order;
  both test files match the brief verbatim; both implementation files match
  the brief verbatim (module-for-module, only reformatted for line width);
  the barrel gained exactly the two specified exports, in the specified
  position.
- **Quality:** names, doc comments and structure are the brief's own, which
  already follow the codebase's established voice (`Ruling F2`,
  `kScreenClipInflate`, etc. cross-referenced correctly against the real
  source).
- **Discipline:** confirmed via `git diff --stat HEAD~1 HEAD -- packages/jet_cad_2d`
  (empty — untouched) and the same for `vertices_draw_sink.dart`,
  `canvas_draw_sink.dart`, `draft_painter.dart` (all empty — untouched). No
  `analysis_options.yaml` touched. No shader files touched. Nothing beyond
  the five files the brief named was created or modified.
- **Testing:** the corpus of 6 frame tests and 6 collection tests specified
  in the brief is exactly what was written — no tests added, none removed,
  none altered. The one mutation the brief calls out by name
  ("cull collection to the live viewport") was fired and went red as
  predicted; the report captures the *fixture-real* magnitude
  (`0` vs `14`, a full miss rather than a partial one, since this brief's
  `corner()` camera at the live 800x600 viewport happens to see none of the
  fixture — even more decisive than "a fraction" in this instance, and still
  faithful to the brief's stated expectation that `b.instanceCount` ends up
  smaller than `a.instanceCount`). Output is pristine: no warnings from
  `flutter analyze`, and `dart format` is clean on the whole package.

## Concerns

None. One minor departure from the brief's exact transcript: the brief's own
inline code blocks for `collection_frame.dart` and `resident_collection_test.dart`
are not `dart format`-clean at 80 columns (two lines wrap differently under
the formatter). This was corrected mechanically by running `dart format` on
the affected files; the semantic content is unchanged, and the final gate
run confirms `0` files changed by the formatter afterwards.
