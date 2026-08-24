# Task 4 report: `TileCache` bakes and blits, and draws live where it cannot

**Commit:** `2f9ff5e1082a53f7e8b614bad060c57de5721cad` — "feat: the cache bakes, blits, and draws live where it cannot"

**Files:**
- Modified: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` (appended `TileCache`, per brief Step 4, verbatim except for one addition noted under Deviations)
- Created: `packages/jet_cad_2d_flutter/test/tile_cache_test.dart` (brief Step 1, plus one added test — see Deviations)
- Created: `packages/jet_cad_2d_flutter/test/support/tile_fixture.dart` (brief Step 2, verbatim)
- Not modified: `packages/jet_cad_2d_flutter/test/support/fixtures.dart` — `addLine`, `addDefinition`, `addInstance` already existed there at the exact signatures the fixture rig calls (landed at `cb49f0d`), confirmed by reading the file before writing `tile_fixture.dart`.

## Step 3: the failing run (before `TileCache` existed)

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
...
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart
test/support/tile_fixture.dart:65:14: Error: Type 'TileCache' not found.
  late final TileCache cache;
             ^^^^^^^^^
test/support/tile_fixture.dart:52:13: Error: The method 'TileCache' isn't defined for the type 'TileRig'.
 - 'TileRig' is from 'test/support/tile_fixture.dart'.
Try correcting the name to the name of an existing method, or defining a method named 'TileCache'.
    cache = TileCache(
            ^^^^^^^^^
test/support/tile_fixture.dart:65:14: Error: 'TileCache' isn't a type.
  late final TileCache cache;
             ^^^^^^^^^
00:00 +0 -1: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart [E]
  Failed to load "/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart":
  Compilation failed for testPath=/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: test/support/tile_fixture.dart:65:14: Error: Type 'TileCache' not found.
    late final TileCache cache;
               ^^^^^^^^^
  test/support/tile_fixture.dart:52:13: Error: The method 'TileCache' isn't defined for the type 'TileRig'.
   - 'TileRig' is from 'test/support/tile_fixture.dart'.
  Try correcting the name to the name of an existing method, or defining a method named 'TileCache'.
      cache = TileCache(
              ^^^^^^^^^
  test/support/tile_fixture.dart:65:14: Error: 'TileCache' isn't a type.
    late final TileCache cache;
               ^^^^^^^^^
  .
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart
```

Exactly the expected compile failure: `TileCache` had no members yet.

## Step 5: the passing run (`TileCache` implemented, brief's three tests only)

Before adding the fourth test (see Deviations), the brief's original three tests were run and passed:

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
...
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart
00:00 +0: a first frame bakes up to its budget and draws the rest live
00:00 +1: a warm frame bakes nothing and blits the whole visible set
00:00 +2: the blit Paint is one instance for the life of the cache
00:00 +3: All tests passed!
CI=true flutter test test/tile_cache_test.dart 2>&1  1.48s user 0.35s system 93% cpu 1.954 total
```

All three counting assertions matched the brief's hand-computed numbers exactly (bakeCount 3, blitCount 3, liveDrawCount 1 on the first frame; blitCount > 30 on the warm frame's first pass, 0 bakes / same blitCount / 0 live draws on the second).

## Step 6: mutant M13 — the brief's mutation does not redden the brief's test

Per Step 6, `_blitPaint` was replaced at its one use site (the `canvas.drawImageRect` call in `paintFrame`) with a fresh `Paint()..filterQuality = FilterQuality.none` literal, leaving the `_blitPaint` field and the `debugBlitPaint` getter untouched:

```dart
      canvas.drawImageRect(image, _tileSourceRect, dest,
          Paint()..filterQuality = FilterQuality.none);
```

Re-running the brief's three-test file against this mutation:

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
...
00:00 +0: a first frame bakes up to its budget and draws the rest live
00:00 +1: a warm frame bakes nothing and blits the whole visible set
00:00 +2: the blit Paint is one instance for the life of the cache
00:00 +3: All tests passed!
```

**All three tests stayed green.** The brief's assertion that "the identity test must go red" is wrong for this specific test. The reason: `debugBlitPaint` returns the `_blitPaint` field directly, and the mutation never touches that field — it only changes what is passed to `drawImageRect`. `identical(rig.cache.debugBlitPaint, first)` compares the field to itself across two frames, which stays true regardless of what actually reaches `dart:ui`.

**This is exactly the gap `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart` already documents for the identical shape** on `VerticesDrawSink.debugPaint` (see its lines 197–216, and the follow-up test at 221–262: "The test above pins that the `_paint` *field* is not reassigned, which a mutation that builds a fresh, call-site-local `Paint`... survives... See the test below, which reads what `dart:ui` actually received... and is the one that closes A1."). That file's own second test uses `SpyCanvas` (`test/support/spy_canvas.dart`, already in the repo) to read the actual `Paint` object handed to `drawVertices` across two calls.

### Deviation: fixed the test, not the code

Following the same pattern, I added a fourth test to `tile_cache_test.dart`:

```dart
test(
    'the blit hands drawImageRect the same Paint object every time, not a '
    'call-site-local one', () {
  final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
  addTearDown(rig.dispose);
  final spy = SpyCanvas();

  rig.cache.paintFrame(
    canvas: spy,
    viewport: kTileViewport,
    devicePixelRatio: kTileDpr,
    camera: rig.camera,
    painter: rig.painter,
    sink: rig.sink,
    vertices: rig.vertices,
  );

  final calls = spy.named('drawImageRect').toList();
  expect(calls.length, greaterThan(30), reason: '...');
  final paints = calls.map((c) => c.args.whereType<Paint>().single).toList();
  final first = paints.first;
  for (final paint in paints) {
    expect(identical(paint, first), isTrue, reason: '...');
  }
});
```

This substitutes a `SpyCanvas` for the outer canvas passed to `paintFrame` (the bake path's inner canvas is untouched — it still needs a real recorder canvas to produce a real `ui.Image` via `toImageSync`) and reads every `Paint` object actually handed to `drawImageRect` across the whole visible set (>30 tiles, satisfying anti-degenerate clause 3 on its own).

Re-running the full four-test file against the still-active M13 mutation:

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
...
00:00 +0: a first frame bakes up to its budget and draws the rest live
00:00 +1: a warm frame bakes nothing and blits the whole visible set
00:00 +2: the blit Paint is one instance for the life of the cache
00:00 +3: the blit hands drawImageRect the same Paint object every time, not a call-site-local one
00:00 +3 -1: the blit hands drawImageRect the same Paint object every time, not a call-site-local one [E]
  Expected: true
    Actual: <false>
  paintFrame must hand drawImageRect the one Paint built for the cache's life, not a fresh one per blit

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 95:7                      main.<fn>

00:00 +3 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: the blit hands drawImageRect the same Paint object every time, not a call-site-local one
CI=true flutter test test/tile_cache_test.dart 2>&1  1.65s user 0.35s system 104% cpu 1.921 total
```

**The new test goes red under M13; the brief's original identity test stays green, confirming the two are not redundant** — exactly the relationship `paint_allocation_test.dart` documents between its own two tests.

The mutation was restored from `/tmp/tile_cache.dart.bak` (never `git checkout`, per the non-negotiable), and the diff against the backup was confirmed empty before proceeding.

**Nothing about the production code was wrong.** `_blitPaint` is declared once as a `final` field and referenced only at its one use site and in `debugBlitPaint`'s getter — this is genuinely "one `Paint` for the life of the cache." The deviation is entirely in test coverage: the brief specified a test that is *necessary but not sufficient* for criterion 13, and I added the sufficient half rather than leaving the gap. I did not change `debugBlitPaint`'s implementation (`Paint get debugBlitPaint => _blitPaint;`), since that is exactly the interface the brief specifies as a deliverable.

## Step 7: the restored green run (all four tests, full suites)

`tile_cache_test.dart` alone, on the restored (non-mutated) code:

```
$ cd packages/jet_cad_2d_flutter && time CI=true flutter test test/tile_cache_test.dart
...
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart
00:00 +0: a first frame bakes up to its budget and draws the rest live
00:00 +1: a warm frame bakes nothing and blits the whole visible set
00:00 +2: the blit Paint is one instance for the life of the cache
00:00 +3: the blit hands drawImageRect the same Paint object every time, not a call-site-local one
00:00 +4: All tests passed!
CI=true flutter test test/tile_cache_test.dart 2>&1  1.49s user 0.32s system 99% cpu 1.822 total
```

**Wall-clock cost of the new tests: ~1.8 s total** for the whole file (four tests, including `flutter test`'s own harness startup). This is the `toImageSync`/software-Skia budget line the controller asked for: at `crossingGrid`'s 24-line, 64-device-pixel-tile fixture, baking runs comfortably inside 2 s for the whole suite; later tasks growing the fixture or the tile count should watch this number, not the 256 px production tile size.

Full package suites, both green:

```
$ cd packages/jet_cad_2d && CI=true dart test
...
00:03 +797: (tearDownAll)
00:03 +797: All tests passed!

$ cd packages/jet_cad_2d && CI=true dart analyze
Analyzing jet_cad_2d...
No issues found!

$ cd packages/jet_cad_2d && CI=true dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.20 seconds.

$ cd packages/jet_cad_2d_flutter && time CI=true flutter test
...
00:04 +318: All tests passed!
CI=true flutter test 2>&1  23.73s user 5.26s system 433% cpu 6.695 total

$ cd packages/jet_cad_2d_flutter && CI=true flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.1s)

$ cd packages/jet_cad_2d_flutter && CI=true dart format --output=none --set-exit-if-changed .
Formatted 59 files (0 changed) in 0.10 seconds.
```

(`jet_cad_2d_flutter` shows `318` passed with one pre-existing skip elsewhere in the suite, unrelated to this task — the same `rig`-tagged skip STATUS.md already records.)

## Interface confirmation

Before writing, I confirmed against the actual source (not assumed from the brief):
- `DraftPainter.debugRebaseOrigin` (`Vector2?`, mutable) and `debugOnVisit` (`void Function(Handle)?`, mutable) exist exactly as described, at `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart:123` and `:135`.
- `rebaseOriginFor` and its `visibleWorld`-derived-span behavior at `packages/jet_cad_2d_flutter/lib/src/camera_controller.dart:18-33`, matching the brief's line reference.
- `fixtures.dart`'s `addLine(doc, owner, handle, x0, y0, x1, y1)` at line 146 matches the fixture rig's call exactly — no local copy was needed and `fixtures.dart` was not modified.
- `CanvasDrawSink`/`VerticesDrawSink` constructors and `late Canvas canvas` setters match the fixture rig's usage.
- `tile_cache.dart`'s pre-existing `TileGrid`/`TileKey`/`quantiseCamera`/constants (from `9f5bd0e`) were only appended to, never rewritten, per instruction.

## Rulings applied

- **R1**: `paintFrame` takes no `tablesRevision` parameter — not added.
- **R2**: `_retireGeneration()` takes no arguments — kept private and argument-free.

## Summary of deviations from the brief

1. **Mutant M13, as literally specified, does not redden the brief's own identity test.** Root cause: `debugBlitPaint` exposes a field that the mutation never touches. Fixed by adding one more test (mirroring the existing `paint_allocation_test.dart` pattern for `VerticesDrawSink.debugPaint`) that reads the actual `Paint` objects handed to `drawImageRect` via `SpyCanvas`. The production `TileCache` code needed no change — it already builds and reuses one `Paint` correctly. Both tests are now in `tile_cache_test.dart`, and staged/committed together with `tile_cache.dart` and `tile_fixture.dart`.
2. Removed two now-unused imports (`package:jet_cad_2d/jet_cad_2d.dart`, `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart`) from `tile_cache_test.dart` after adding the `SpyCanvas`/`tile_fixture.dart` imports made them redundant — `unused_import` is an error in this package, and `flutter analyze` caught it before commit.
3. `test/support/fixtures.dart` was not staged or modified, since `addLine` already had the exact signature the fixture rig needed (confirmed by reading the file, not assumed).

No other deviations. `analysis_options.yaml` was never touched or staged (checked via `git status` before every `git add`).
