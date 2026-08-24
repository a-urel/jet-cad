## Task 5: The live-versus-tiled ink instrument, and criteria 1 and 2

**Why a new instrument:** `measureAgreement`'s vertices arm goes through the repository's **software rasterizer**, not a `Canvas` (`test/support/sink_comparison.dart`), so it never executes a `drawPicture` or a `drawImageRect` and cannot see a tile at all.

**Files:**
- Create: `packages/jet_cad_2d_flutter/test/support/tile_comparison.dart`
- Modify: `packages/jet_cad_2d_flutter/test/tile_cache_test.dart`

**Interfaces:**
- Consumes: `TileRig`.
- Produces: `expectTiledEqualsLive(TileRig rig)` — asserts zero stray and zero uncovered pixels and returns the ink count for the caller to floor.

- [ ] **Step 1: Write the instrument**

Create `packages/jet_cad_2d_flutter/test/support/tile_comparison.dart`:

```dart
// Live frame against tiled frame, byte for byte.
//
// **Why not `measureAgreement`.** That instrument's vertices arm rasterises in
// Dart (`support/sink_comparison.dart`), so it never reaches a `Canvas` and
// never executes a `drawImageRect`. A tile is invisible to it.
//
// **Why zero rather than a tolerance.** `quantiseCamera` puts every tile
// destination on whole device pixels at every camera, so a blit is a 1:1
// texel-to-pixel copy and there is nothing for a tolerance to absorb. A
// tolerance here would hide exactly the defects the criteria exist to catch.
//
// **What this cannot prove.** Software Skia does not antialias `drawVertices`
// at all — `drawvertices_antialiasing_test.dart` pins that, in its own words
// as "a fact about `flutter_test`'s software Skia, not about this codebase" —
// so this instrument cannot produce an antialiased seam and a zero result here
// is partly a property of the instrument. It proves geometric completeness:
// no pixel missing, none drawn twice, no clipping arithmetic error. Accepted
// gap G1 owns the rest, and mutant M3 is deferred to it. **M15 is the mutant
// this instrument fires**, and it moves pixels software Skia renders perfectly
// well.

import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'tile_fixture.dart';

class InkReport {
  const InkReport({
    required this.liveInk,
    required this.tiledInk,
    required this.strayPixels,
    required this.uncoveredPixels,
    required this.differingPixels,
  });

  /// Non-transparent pixels in the live capture.
  final int liveInk;
  final int tiledInk;

  /// Tiled pixels with ink where live has none.
  final int strayPixels;

  /// Live pixels with ink where tiled has none.
  final int uncoveredPixels;

  /// Pixels whose four bytes differ at all, stray and uncovered included.
  final int differingPixels;

  @override
  String toString() => 'InkReport(live: $liveInk, tiled: $tiledInk, '
      'stray: $strayPixels, uncovered: $uncoveredPixels, '
      'differing: $differingPixels)';
}

Future<Uint8List> _capture(void Function(Canvas canvas) draw) async {
  final width = (kTileViewport.width * kTileDpr).round();
  final height = (kTileViewport.height * kTileDpr).round();
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(kTileDpr);
  canvas.clipRect(Offset.zero & kTileViewport);
  draw(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  final data = await image.toByteData();
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Paints [rig] both ways and compares.
///
/// The live arm goes through the **quantised** camera, not the raw one: that is
/// the rule, not a concession to the tiled arm. `DraftCanvas` quantises the
/// camera it hands the live path for exactly this reason, so the two arms are
/// the same drawing seen twice and not two different drawings.
Future<InkReport> measureTiledAgreement(TileRig rig) async {
  final quantised = quantiseCamera(rig.camera, kTileDpr);

  final live = await _capture((canvas) {
    rig.painter.debugRebaseOrigin =
        rebaseOriginFor(quantised.visibleWorld(kTileViewport));
    rig.sink.canvas = canvas;
    rig.vertices.canvas = canvas;
    rig.painter.paint(rig.vertices, quantised, kTileViewport);
    rig.vertices.flush();
    rig.painter.debugRebaseOrigin = null;
  });

  final tiled = await _capture((canvas) {
    rig.cache.paintFrame(
      canvas: canvas,
      viewport: kTileViewport,
      devicePixelRatio: kTileDpr,
      camera: rig.camera,
      painter: rig.painter,
      sink: rig.sink,
      vertices: rig.vertices,
    );
  });

  var liveInk = 0, tiledInk = 0, stray = 0, uncovered = 0, differing = 0;
  for (var i = 0; i < live.length; i += 4) {
    final liveHasInk = live[i + 3] != 0;
    final tiledHasInk = tiled[i + 3] != 0;
    if (liveHasInk) liveInk++;
    if (tiledHasInk) tiledInk++;
    if (tiledHasInk && !liveHasInk) stray++;
    if (liveHasInk && !tiledHasInk) uncovered++;
    if (live[i] != tiled[i] ||
        live[i + 1] != tiled[i + 1] ||
        live[i + 2] != tiled[i + 2] ||
        live[i + 3] != tiled[i + 3]) {
      differing++;
    }
  }
  return InkReport(
      liveInk: liveInk,
      tiledInk: tiledInk,
      strayPixels: stray,
      uncoveredPixels: uncovered,
      differingPixels: differing);
}

/// The gate. Zero stray, zero uncovered, zero differing — and a real drawing.
Future<InkReport> expectTiledEqualsLive(TileRig rig,
    {int minimumInk = 500}) async {
  final report = await measureTiledAgreement(rig);
  // The floor first. A comparison of two blank captures agrees perfectly and
  // proves nothing, which is the failure mode this whole plan's spike named.
  expect(report.liveInk, greaterThan(minimumInk),
      reason: 'the live arm must actually draw: $report');
  expect(report.tiledInk, greaterThan(minimumInk),
      reason: 'the tiled arm must actually draw: $report');
  expect(report.strayPixels, 0, reason: '$report');
  expect(report.uncoveredPixels, 0, reason: '$report');
  expect(report.differingPixels, 0, reason: '$report');
  return report;
}
```

- [ ] **Step 2: Write criteria 1 and 2 as failing tests**

Append to `test/tile_cache_test.dart`:

```dart
  test('criterion 1: a warm tiled frame equals the live frame exactly',
      () async {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);
    // Warm first: criterion 1 is about a settled frame, and the uncovered path
    // is criterion 2's and Task 10's business.
    rig.paintOnce();
    await expectTiledEqualsLive(rig);
  });

  test('criterion 1: and it still holds after twenty-three awkward pans',
      () async {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);
    for (var i = 0; i < 23; i++) {
      // Not whole pixels, and not a whole tile: the claim is that quantisation
      // makes an arbitrary pan exact, so an arbitrary pan is what tests it.
      rig.panBy(-7.37, -3.19);
      rig.paintOnce();
      await expectTiledEqualsLive(rig);
    }
  });

  test('criterion 2: a fixture crossing tile boundaries still matches',
      () async {
    // `crossingGrid` is 90-logical-pixel lines on a 32-logical-pixel tile, so
    // every line crosses at least two boundaries and most cross three. The
    // seam is exercised by geometry, not by intent -- anti-degenerate clause 1.
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);
    rig.paintOnce();
    final report = await expectTiledEqualsLive(rig);
    expect(report.liveInk, greaterThan(5000),
        reason: 'a fixture this small would make the seam claim thin: $report');
  });
```

- [ ] **Step 3: Run them and watch them fail or pass, and read which**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
```

These may pass on the first run, because Task 4 already implemented the mechanism. **That is not a reason to skip Step 4.** A test that has never been red proves nothing; Step 4 is where it earns its place.

- [ ] **Step 4: Fire mutants M15 and M17**

```sh
cp lib/src/tile_cache.dart /tmp/tile_cache.dart.bak
```

**M15** — offset a tile's bake camera by one device pixel. In `TileGrid.bakeCameraFor`, change `m.e - key.x * _tileLogical` to `m.e - key.x * _tileLogical + 1 / devicePixelRatio`. Criterion 2 must go red with non-zero stray *and* uncovered counts. Record the numbers.

**M17** — drop the injected origin. In `_bake`, pass `Vector2.zero()` instead of `origin`. Criterion 1 must go red. **If it does not**, the fixture is too close to the world origin for the rebase quantisation to differ — move `crossingGrid` out to 4.5e6 and say so in the report, because a criterion that cannot see M17 is not gating D1.

Restore from the copy after each.

- [ ] **Step 5: Green and commit**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .
git add packages/jet_cad_2d_flutter/test
git commit -m "test: criteria 1 and 2 -- the tiled frame equals the live frame exactly

Zero stray, zero uncovered, zero differing pixels, and an ink floor on both
arms first: two blank captures agree perfectly and prove nothing, which is the
failure mode this plan's own spike walked into.

A new instrument, because measureAgreement's vertices arm rasterises in Dart
and never reaches a Canvas, so it cannot see a drawImageRect at all.

The exactness holds after twenty-three pans of 7.37 by 3.19 logical pixels --
arbitrary on purpose, since the claim is that quantisation makes an arbitrary
pan exact.

What this cannot prove is written into the instrument's header. Software Skia
antialiases no drawVertices, so it cannot produce an antialiased seam and a
zero here is partly a property of the instrument. It proves geometric
completeness; G1 owns the rest and M3 is deferred to it. M15 is the mutant this
one fires."
```

---

