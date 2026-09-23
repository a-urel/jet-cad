# Task 4 report: `OutlineCache.worldBoundsOf`, style constants, `GripCache`

## What was implemented

- `packages/jet_cad_2d_flutter/lib/src/outline_cache.dart`: added
  `Aabb2? worldBoundsOf(SelectionKey key)` right after `worldPointOf`,
  computed purely from the cached world records (`_Segments` by point,
  `_Arc` via `arcBounds`, `_Point` by position), never from a `ui.Path`.
  Returns null when the key is not cached or its accumulated box is empty.
- `packages/jet_cad_2d_flutter/lib/src/selection_style.dart`: appended the
  grip/preview/snap-marker style constants (`kGripPixels`, `kGripColor`,
  `kGripMoveColor`, `kGripHotColor`, `kRotationGripPixels`,
  `kRotationGripOffset`, `kPreviewColor`, `kPreviewStrokePixels`,
  `kSnapMarkerColor`, `kSnapMarkerPixels`, `kSnapMarkerStrokePixels`,
  `kGridMarkerPixels`).
- `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart` (new): `kMaxGrips`,
  `kGripHitPixels`, `GripRef`, `rotationGripOf`, and `GripCache extends
  ChangeNotifier` — wires to `SelectionController` and `OutlineCache`,
  builds `grips` (ascending handle, then ordinal), `moveCount`,
  `stretchCount`, `box`, `rotatable`, `hot`, `leafGripsLive`, `hitTest`,
  `hitsRotationGrip`, applies the `kMaxGrips` cap, and rebuilds on both a
  selection change and an outline-cache change (never on `document.changes`
  directly).
- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart`: added
  `export 'src/grip_cache.dart';` after the last `src/gpu/...` export and
  before `src/interaction_layer.dart`.
- `packages/jet_cad_2d_flutter/test/support/grip_fixture.dart` (new): first
  version exactly as the brief specifies — `GripScene`, `gripScene()`,
  `gripCamera()`, `screenOf()`, `payloadOf()`, `snapshot()`.
- `packages/jet_cad_2d_flutter/test/outline_cache_test.dart`: appended O1,
  `worldBoundsOf: an arc by arcBounds, a point by its position (M-03ah)`.
- `packages/jet_cad_2d_flutter/test/grip_cache_test.dart` (new): C1–C7, the
  full suite from the brief.

## TDD evidence

### RED

To get a genuine RED, the three implementation files were rolled back to
their exact HEAD content (`git diff` against HEAD showed zero lines) while
the two new/updated test files (with the fixture) stayed in place, then run:

```
CI=true flutter test test/outline_cache_test.dart test/grip_cache_test.dart
```

Output (relevant excerpt):

```
test/grip_cache_test.dart:7:8: Error: Error when reading 'lib/src/grip_cache.dart': No such file or directory
import 'package:jet_cad_2d_flutter/src/grip_cache.dart';
       ^
test/grip_cache_test.dart:18:37: Error: Type 'GripCache' not found.
test/grip_cache_test.dart:21:17: Error: Method not found: 'GripCache'.
test/grip_cache_test.dart:120:68: Error: Undefined name 'kMaxGrips'.
test/grip_cache_test.dart:202:15: Error: Method not found: 'rotationGripOf'.
test/grip_cache_test.dart:206:40: Error: Undefined name 'kRotationGripOffset'.
test/grip_cache_test.dart:79:26: Error: The method 'worldBoundsOf' isn't defined for the type 'OutlineCache'.
00:00 +0 -2: Some tests failed.
```

Exactly the compile failures the brief predicted (`worldBoundsOf`,
`GripCache`, `rotationGripOf`, `kRotationGripOffset` undefined). Both test
files failed to load (2 failures).

The implementation files were then restored from the exact content written
for this task (byte-identical — verified with `git diff` showing the
expected new diff again).

### GREEN

```
CI=true flutter test test/outline_cache_test.dart test/grip_cache_test.dart
```

```
00:00 +19: All tests passed!
```

(12 tests in `outline_cache_test.dart` — 11 pre-existing + O1 — and 7 in
`grip_cache_test.dart`, interleaved by the test runner: 19 total.)

## Gate line output

```
cd packages/jet_cad_2d_flutter && CI=true flutter test
```
```
00:11 +805 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

805 passed (797 baseline + 8 new: 1 in outline_cache_test.dart, 7 in
grip_cache_test.dart), 1 skipped (baseline), 5 failed — exactly the five
standing golden failures named in the standing instructions. No other
failure.

```
flutter analyze
```
```
No issues found! (ran in 1.6s)
```

```
dart format --output=none --set-exit-if-changed .
```
```
Formatted 151 files (0 changed) in 0.28 seconds.
```
Exit code 0.

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/outline_cache.dart` (modified)
- `packages/jet_cad_2d_flutter/lib/src/selection_style.dart` (modified)
- `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart` (new)
- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` (modified)
- `packages/jet_cad_2d_flutter/test/support/grip_fixture.dart` (new)
- `packages/jet_cad_2d_flutter/test/outline_cache_test.dart` (modified, O1 appended)
- `packages/jet_cad_2d_flutter/test/grip_cache_test.dart` (new)

No `analysis_options.yaml` was touched; `git status --short` was checked
before staging and again before commit.

## Self-review findings

- Verified every API surface the brief's code calls against the actual
  sources before writing anything: `Aabb2`, `arcBounds` (`geometry/primitives.dart`),
  `Transform2` field layout (`a,b,c,d,e,f`), `Capability`/`DraftPermissions`
  (`document/command.dart`), `Grip`/`GripRole`/`leafGrips`
  (`document/grips.dart`), `SelectionKey`/`SelectionController`
  (`selection.dart`), `AddRegionCommand.allocate` and `.fill.handle`
  (`document/commands.dart`), `PageComponent.register`,
  `SetComponentCommand`, `DraftDocumentCodec.encodeToString`,
  `HandleSeed`/`entities.slotOf/ownerAt/kindAt/geomIndexAt`,
  `CameraController`/`ViewportTransform` constructors used by the fixture.
  All matched the brief's code exactly — no interface had drifted since the
  brief was written.
- Confirmed draw order / grip order: `_rebuild` sorts selected keys by
  ascending `target.value` before walking, matching "draw order is ascending
  handle value" and the D2 tie-break ("grip index" = list ordinal).
- Confirmed `GripCache` never touches `document.changes` directly — it only
  listens to `selection` and `outlines`, per Ruling 03-19 and the class doc
  comment.
- Confirmed the `kMaxGrips` cap zeroes `_grips`/`_moveCount` but leaves `_box`
  computed from the full (uncapped) key set, so body move/rotate still work
  over the cap, as C4 requires.
- Confirmed `leafGripsLive` reads `document.commands.permissions` live
  (uncached), matching Ruling 03-5 (a permission change is not itself
  notified).
- Checked named mutants would go red:
  - Swapping `arcBounds` for a naive two-endpoint box in `worldBoundsOf`
    would fail O1's `maxY` assertion (the arc's top extreme falls inside the
    sweep and a two-point box would miss it).
  - Returning `Rect.zero`/`(0,0)` for a point instead of its position would
    fail O1's point assertion.
  - Dropping the `h > bestHandle` tie-break in `hitTest` would fail
    "the greater handle moves" (M-03ai first case).
  - Dropping the `ref.ordinal < bestOrdinal` tie-break would fail "the lower
    ordinal" (M-03ai second case).
  - Forgetting to check `leafGripsLive` in `hitTest` would fail M-03ad's
    post-permission-change assertion (`hitTest(vertex, m)` would still find
    grip 1 instead of returning -1).
  - Missing the `kMaxGrips` cap or applying it to `_box` too would fail
    C4's "kMaxGrips + 1 keep none" / "box still non-null" pair.
- Ran `flutter analyze` and found one deviation needed (see below); after
  fixing it, analyze is clean and the gate line reruns green.

## Concerns

None outstanding. The implementation, tests and fixture match the brief's
prescribed code verbatim except for the one import fix below.

## Deviation from the brief's code

`test/grip_cache_test.dart`'s prescribed imports include
`import 'dart:ui' show Offset;`. `Offset` is already reachable through
`package:flutter_test/flutter_test.dart`'s re-exports in this workspace, so
`flutter analyze` reported it as `unnecessary_import` (an info-level
diagnostic) — but `flutter analyze` still exits 1 on any reported issue,
info included, which would break the "every task ends green" gate. I removed
the redundant `dart:ui` import line; no other line in the file changed, and
all 7 tests in the file still pass unmodified. This is a mechanical import
cleanup, not a change to test intent or assertions.
