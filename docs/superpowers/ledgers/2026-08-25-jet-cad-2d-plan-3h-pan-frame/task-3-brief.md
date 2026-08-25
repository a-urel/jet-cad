### Task 3: The fallback sweep, gating today's code

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` (one read-only getter)
- Modify: `packages/jet_cad_2d_flutter/test/support/tile_comparison.dart`
- Create: `packages/jet_cad_2d_flutter/test/tile_fallback_test.dart`

**Interfaces:**
- Consumes: `fillingGrid`, `TileRig`, `InkReport`, `nearAxisDiagonals`.
- Produces:
  - `Rect? TileCache.debugLastStrip` — the rectangle the **shipped** `paintFrame` handed the fallback on its most recent frame, or `null` if no fallback ran.
  - `Future<InkReport> measureFallbackAgreement(TileRig rig)` — one sample.
  - `Future<List<InkReport>> sweepFallbackAgreement({required DraftDocument Function(FlutterTextMeasurer) of, required List<Offset> offsets})`.

**Why the getter is read from the shipped path.** Plan 3g's rig computed its own bake geometry in `_probeBake` instead of calling `_bake`, so its overdraw column described a reimplementation rather than the shipped code. A test that recomputed the strip from the grid would repeat that exactly. **This getter is read-only, so it is not the third mutable field the global constraints refuse.**

**Why each sample gets its own cache.** A sweep that pans one rig across offsets inherits tiles from the previous offset and quietly becomes a warm-tile comparison — which is one of the three failures Task 2's fixture exists to fix.

**Why `bakeCount == 1` is not enough.** `uncovered` is a **bounding rectangle** (`tile_cache.dart:742-744` accumulates with `expandToInclude`), so a diagonal pan's L-shaped uncovered set can bound to the whole viewport. After clamping there is no interior boundary at all, and a crippled query stays pixel-correct while both counters read exactly what a naive rule demands. Every sample must therefore prove `strip != viewport`.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d_flutter/test/tile_fallback_test.dart`:

```dart
// Criteria 1, 1b, 2, 2b and 2c: the live fallback, which no pixel gate in this
// repository has ever executed.
//
// **Every pixel comparison in `tile_cache_test.dart` runs at
// `tilesBakedPerFrame: 1000`**, where the first frame bakes the whole visible
// set, `uncovered` is null, and `paintFrame`'s fallback never runs at all. The
// two restricted-budget tests that do reach it assert counters. So the one
// composition this cache produces that nothing checked the pixels of is the
// frame that is part blit and part live walk -- which is also the frame where
// the two paths meet along a seam.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'support/tile_comparison.dart';
import 'support/tile_fixture.dart';

// **No `jet_cad_2d_flutter` import here**, and it is not an oversight: this
// file names no symbol from it, and `unused_import` is an **error** in this
// package rather than a warning. Add one only when a symbol needs it.

/// Offsets that are not multiples of the tile's **logical** size.
///
/// A tile is `tileDevicePixels / devicePixelRatio` logical pixels -- 32 at this
/// rig's 64 device pixels and [kTileDpr] of 2, not 64. An offset on that
/// lattice would put the strip boundary exactly on a tile edge at every
/// sample and the sweep would measure one arrangement N times.
///
/// Each is a single-axis pan. A diagonal pan brings in a row *and* a column,
/// and `uncovered` is a bounding rectangle, so the union bounds to the whole
/// viewport and the sample has no interior edge to lose anything across.
const List<Offset> kFallbackOffsets = <Offset>[
  Offset(37, 0),
  Offset(53, 0),
  Offset(71, 0),
  Offset(0, 37),
  Offset(0, 53),
  Offset(0, 71),
  Offset(-41, 0),
  Offset(0, -41),
];

void main() {
  test('criterion 2 and 2c: a partly baked frame equals the live frame',
      () async {
    final reports = await sweepFallbackAgreement(
        of: fillingGrid, offsets: kFallbackOffsets);

    expect(reports, hasLength(kFallbackOffsets.length));
    for (var i = 0; i < reports.length; i++) {
      final report = reports[i];
      expect(report.strayPixels, 0, reason: '${kFallbackOffsets[i]}: $report');
      expect(report.uncoveredPixels, 0,
          reason: '${kFallbackOffsets[i]}: $report');
      expect(report.differingPixels, 0,
          reason: '${kFallbackOffsets[i]}: $report');
    }
  });

  test('criterion 2b: the near-axis arm stays inside the tiled path\'s bound',
      () async {
    // The reference is not invented here: `tile_cache_test.dart` gates the
    // tiled path on this same fixture at `differingPixels <= 60` against a
    // measured 36 of 10342 ink, 0.348%. The fallback arm is held to the same
    // number, so an increase is a tripwire rather than a silent record.
    final reports = await sweepFallbackAgreement(
        of: nearAxisDiagonals, offsets: kFallbackOffsets, minimumInk: 200);

    for (var i = 0; i < reports.length; i++) {
      final report = reports[i];
      expect(report.differingPixels, lessThanOrEqualTo(60),
          reason: '${kFallbackOffsets[i]}: $report');
      expect(report.differingPixels / report.liveInk, lessThan(0.01),
          reason: '${kFallbackOffsets[i]}: $report');
    }
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```sh
CI=true flutter test test/tile_fallback_test.dart
```

Expected: a compile error, `The function 'sweepFallbackAgreement' isn't defined`.

- [ ] **Step 3: Add the read-only getter to `TileCache`**

In `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`, beside `tilesHolding`, add the field and getter:

```dart
  /// The rectangle the fallback walked on the most recent frame, or `null` if
  /// no fallback ran. Test-only, and **read-only**.
  ///
  /// Read from the shipped `paintFrame` rather than recomputed by a test, and
  /// that is the whole point of it. Plan 3g's rig reimplemented the bake
  /// geometry in `_probeBake` instead of calling `_bake`, so its overdraw
  /// column described the reimplementation and not the code that ships. A
  /// sweep that derived this rectangle from [TileGrid] would repeat that.
  ///
  /// **A getter, not a mutable field.** `TileCache` already carries two
  /// mutable test-only fields and the standing bar is that a third triggers
  /// revisiting the design; `tilesHolding` is the precedent for reading state
  /// out without adding a way to write it.
  Rect? get debugLastStrip => _lastStrip;

  Rect? _lastStrip;
```

Then in `paintFrame`, set it. Two sites, and **both are required**:

- immediately after `_frameSerial++`, add `_lastStrip = null;` — so a frame that runs no fallback reports `null` rather than the previous frame's rectangle;
- in the fallback branch, immediately before `_drawInto(...)`, add `_lastStrip = <the rectangle passed>;`. In today's code that rectangle is the whole viewport, so write `_lastStrip = Offset.zero & viewport;`.

- [ ] **Step 4: Write the sweep instrument**

Append to `packages/jet_cad_2d_flutter/test/support/tile_comparison.dart`:

```dart
/// One fallback sample: a frame that is part blit and part live walk, compared
/// against the live frame at the same camera.
///
/// **Each sample owns its cache.** A sweep that panned one rig across offsets
/// would inherit tiles from the previous offset and become a warm-tile
/// comparison -- one of the three arrangements that failed to detect a
/// crippled query before this instrument existed.
Future<InkReport> measureFallbackAgreement(
  DraftDocument Function(FlutterTextMeasurer) of,
  FlutterTextMeasurer measurer,
  Offset pan, {
  int minimumInk = 500,
}) async {
  final rig = TileRig(
      tileDevicePixels: 64,
      tilesBakedPerFrame: 1000,
      document: of(measurer));
  try {
    // Cover the viewport, so the strip that enters next has blitted tiles on
    // its interior side.
    rig.paintOnce();
    rig.cache.resetCounters();
    // One tile a frame, so the entering band stays uncovered and the fallback
    // owes it.
    rig.cache.bakeBudgetDevicePixels = 64 * 64;
    rig.panBy(pan.dx, pan.dy);

    final report = await measureTiledAgreement(rig);

    // Anti-vacuity, and every clause of it was earned by an arrangement that
    // passed while proving nothing.
    expect(rig.cache.liveDrawCount, greaterThan(0),
        reason: 'pan $pan ran no fallback: $report');
    expect(rig.cache.blitCount, greaterThan(0),
        reason: 'pan $pan blitted nothing, so nothing was partly baked');
    final strip = rig.cache.debugLastStrip;
    expect(strip, isNotNull, reason: 'pan $pan recorded no strip');
    // The clause `bakeCount`/`liveDrawCount` cannot supply: `uncovered` is a
    // bounding rectangle, so an L-shaped uncovered set bounds to the whole
    // viewport and leaves no interior edge for a crippled query to lose ink
    // across.
    expect(strip != Offset.zero & kTileViewport, isTrue,
        reason: 'pan $pan left no interior strip edge: strip=$strip');
    expect(report.liveInk, greaterThan(minimumInk), reason: '$report');
    expect(report.tiledInk, greaterThan(minimumInk), reason: '$report');
    return report;
  } finally {
    rig.dispose();
  }
}

/// [measureFallbackAgreement] over a set of pan offsets, each independent.
Future<List<InkReport>> sweepFallbackAgreement({
  required DraftDocument Function(FlutterTextMeasurer) of,
  required List<Offset> offsets,
  int minimumInk = 500,
}) async {
  final reports = <InkReport>[];
  for (final offset in offsets) {
    final measurer = FlutterTextMeasurer();
    try {
      reports.add(await measureFallbackAgreement(of, measurer, offset,
          minimumInk: minimumInk));
    } finally {
      measurer.clear();
    }
  }
  return reports;
}
```

Add `import 'package:jet_cad_2d/jet_cad_2d.dart';` to that file if `DraftDocument` is not already in scope.

- [ ] **Step 5: Run it and watch it pass on today's code**

```sh
CI=true flutter test test/tile_fallback_test.dart
```

Expected: **both tests pass.** Today's fallback walks the whole viewport, which is wasteful and correct — the instrument is being installed against known-good behaviour so that Task 5's change is what moves it.

**If criterion 2c's `strip != viewport` assertion fails for some offset**, that offset produced an uncovered union bounding to the whole frame. Replace that offset with a smaller single-axis one and record the substitution in the task report; do not weaken the assertion.

- [ ] **Step 6: Full suite, analyze, format, commit**

```sh
CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add lib/src/tile_cache.dart test/support/tile_comparison.dart test/tile_fallback_test.dart
git commit -m "test: a sweep that executes the live fallback, which no pixel gate ever has

Every pixel comparison in this suite runs at a budget that covers the viewport,
so paintFrame's fallback has never run under one. The two restricted-budget
tests that reach it assert counters.

Each sample owns its cache, so the sweep cannot decay into a warm-tile
comparison, and each asserts a strictly interior strip edge -- because
uncovered is a bounding rectangle and an L-shaped uncovered set bounds to the
whole viewport, where a crippled query loses nothing.

The strip is read from the shipped paintFrame through a read-only getter, never
recomputed from the grid: Plan 3g's rig reimplemented its bake geometry and its
overdraw column described the reimplementation."
```

---


---

## Controller amendment — binding, and it overrides Step 3 above

The plan's Step 3 records `_lastStrip = Offset.zero & viewport;`, and Step 4's
anti-vacuity clause then asserts `strip != Offset.zero & kTileViewport`. Those
two cannot both hold: every sample would fail and Step 5's "both tests pass" is
unreachable. The clause is the one the plan argues hardest for, so it stays and
the recorded rectangle changes.

**Task 4 has already landed `stripFor(Rect uncovered, Size viewport)`** as a
top-level public function in `lib/src/tile_cache.dart` (it is exported through
the package barrel). Use it.

In `paintFrame`'s fallback branch, immediately before `_drawInto(...)`, write:

```dart
    _lastStrip = stripFor(uncovered, viewport);
```

**Do not change the walk in this task.** `_drawInto` keeps receiving `viewport`
and `quantised` exactly as it does today, and there is no `canvas.translate`.
The recorded rectangle is metadata only: the pixels this task's sweep compares
come from the unchanged full-viewport walk, which is the whole point of
installing the instrument against known-good behaviour. Task 5 is what makes
the fallback actually walk that rectangle.

Everything else in Step 3 stands, including `_lastStrip = null;` immediately
after `_frameSerial++`.

**One wording change to the getter's doc comment.** Until Task 5 the fallback
does not yet walk this rectangle, so the first line must not claim it does.
Write it as:

```dart
  /// The rectangle the fallback owes on the most recent frame -- `uncovered`
  /// padded and clamped by [stripFor] -- or `null` if no fallback ran.
  /// Test-only, and **read-only**.
```

Keep the rest of that doc comment verbatim as the plan gives it.
