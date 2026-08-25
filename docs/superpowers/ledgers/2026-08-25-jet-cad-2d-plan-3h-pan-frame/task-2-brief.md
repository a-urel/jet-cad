### Task 2: `fillingGrid`, the first fixture that fills the viewport

**Files:**
- Modify: `packages/jet_cad_2d_flutter/test/support/tile_fixture.dart`
- Modify: `packages/jet_cad_2d_flutter/test/tile_cache_test.dart` (one test)

**Interfaces:**
- Consumes: `tileCamera()`, `kTileViewport`, `kTileDpr`, `addLine` from `test/support/fixtures.dart`.
- Produces: `DraftDocument fillingGrid(FlutterTextMeasurer measurer)`.

**Why.** Three attempts to catch a crippled query failed, and all three failed for one reason: **a loss is only visible where the uncovered union's boundary is interior to the drawing.** `crossingGrid` spans world x 10..200, which at `tileCamera`'s scale of 1.4 is screen **-23..243** inside a 400 px viewport (`sx = 1.4x - 37`). The drawing does not fill the frame, so a strip entering from any edge lands outside it.

The visible world box at `tileCamera` is x ∈ [26.4, 312.1], y ∈ [16.4, 230.7]. A grid spanning world **20..320 by 10..240** strictly contains it on all four edges.

- [ ] **Step 1: Write the failing test**

In `packages/jet_cad_2d_flutter/test/tile_cache_test.dart`, add inside `main()`:

```dart
  test('fillingGrid covers every edge of the viewport', () async {
    // The property three earlier fixtures lacked, asserted rather than
    // assumed: ink within one tile of all four viewport edges. Without it a
    // strip entering from an edge lands outside the drawing and no crippled
    // query can lose anything -- which is exactly what `crossingGrid`,
    // a pan, and a zoom-then-pan each demonstrated.
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final rig = TileRig(
        tileDevicePixels: 64,
        tilesBakedPerFrame: 1000,
        document: fillingGrid(measurer));
    addTearDown(rig.dispose);

    final pixels = await captureLiveFrame(rig);
    final width = (kTileViewport.width * kTileDpr).round();
    final height = (kTileViewport.height * kTileDpr).round();
    // 64 device pixels: one tile at this rig's size.
    const band = 64;

    bool inkIn(int x0, int y0, int x1, int y1) {
      for (var y = y0; y < y1; y++) {
        for (var x = x0; x < x1; x++) {
          if (pixels[(y * width + x) * 4 + 3] != 0) return true;
        }
      }
      return false;
    }

    expect(inkIn(0, 0, band, height), isTrue, reason: 'left edge');
    expect(inkIn(width - band, 0, width, height), isTrue, reason: 'right edge');
    expect(inkIn(0, 0, width, band), isTrue, reason: 'top edge');
    expect(inkIn(0, height - band, width, height), isTrue, reason: 'bottom');
  });
```

- [ ] **Step 2: Run it and watch it fail**

```sh
cd /Users/ahmeturel/Projects/oss/jet_cad_2d_flutter 2>/dev/null || cd /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter
CI=true flutter test test/tile_cache_test.dart --plain-name "fillingGrid covers"
```

Expected: a **compile error**, `The function 'fillingGrid' isn't defined`. That is the correct first failure.

- [ ] **Step 3: Write the fixture**

Append to `packages/jet_cad_2d_flutter/test/support/tile_fixture.dart`:

```dart
/// A grid that fills [kTileViewport] at [tileCamera], which no other fixture
/// here does.
///
/// **This is the property that makes a crippled query detectable, and its
/// absence is why three earlier arrangements could not detect one.** A loss in
/// the live fallback is only visible where the uncovered union's boundary is
/// *interior to the drawing*: a strip entering across empty canvas has no ink
/// to lose. [crossingGrid] spans world x 10..200, which at this camera's 1.4
/// is screen -23..243 inside a 400 px viewport -- off the left edge and short
/// of the right -- so a pan in any direction brings in empty space.
///
/// The visible world box here is x in [26.4, 312.1] and y in [16.4, 230.7];
/// 20..320 by 10..240 strictly contains it on all four edges.
///
/// Lines rather than a fill, and axis-aligned rather than diagonal: this
/// fixture carries the arm that must agree **exactly**, so it must not import
/// the near-axis slope disagreement [nearAxisDiagonals] measures.
DraftDocument fillingGrid(FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  var handle = 1000;
  // 16 units apart: half a tile's 32 logical pixels at this camera's 1.4 is
  // 22.9 world units, so no tile-sized strip anywhere in the frame can be
  // empty of ink.
  for (var t = 10.0; t <= 240.0; t += 16.0) {
    addLine(doc, doc.rootHandle, Handle(handle++), 20, t, 320, t);
  }
  for (var t = 20.0; t <= 320.0; t += 16.0) {
    addLine(doc, doc.rootHandle, Handle(handle++), t, 10, t, 240);
  }
  return doc;
}
```

- [ ] **Step 4: Run it and watch it pass**

```sh
CI=true flutter test test/tile_cache_test.dart --plain-name "fillingGrid covers"
```

Expected: `+1: All tests passed!`

- [ ] **Step 5: Prove the test is not vacuous**

Copy the fixture file aside, change `fillingGrid`'s horizontal loop bound from `240.0` to `120.0`, re-run, confirm the **bottom edge** assertion fails, then restore from the copy:

```sh
cp test/support/tile_fixture.dart /tmp/tile_fixture.orig
# edit: 240.0 -> 120.0 in fillingGrid's first loop
CI=true flutter test test/tile_cache_test.dart --plain-name "fillingGrid covers"
cp /tmp/tile_fixture.orig test/support/tile_fixture.dart
```

Expected while mutated: `bottom` fails. **`git checkout` is forbidden for this; restore from the copy.**

- [ ] **Step 6: Full suite, analyze, format, commit**

```sh
CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add test/support/tile_fixture.dart test/tile_cache_test.dart
git commit -m "test: fillingGrid, the first fixture that fills the viewport

Three arrangements failed to detect a deliberately crippled fallback query and
all three failed for one reason: a loss is only visible where the uncovered
union's boundary is interior to the drawing. crossingGrid is screen -23..243
in a 400 px viewport, so a strip entering from any edge lands outside it.

The edge assertions are proved non-vacuous by shortening the fixture and
watching the bottom edge fail."
```

---

