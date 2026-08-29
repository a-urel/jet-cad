## Task 9: The differential arms — criteria 5, 6 and 11

**Files:**
- Modify: `packages/jet_cad_2d_flutter/test/support/tile_comparison.dart`
- Modify: `packages/jet_cad_2d_flutter/test/support/tile_fixture.dart`
- Test: `packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart` (create)

**Interfaces:**
- Produces, in `tile_comparison.dart`:
  `Future<ByteData> captureTiled(WidgetTester t, TiledHarness h)`,
  `Future<ByteData> captureLive(WidgetTester t, TiledHarness h)`,
  `int differingPixels(ByteData a, ByteData b)`, and
  `ViewportTransform rebaseBoundaryCamera()`.
- Produces, in `tile_fixture.dart`: `DraftDocument bandCrossingGrid(
  FlutterTextMeasurer measurer)` — **entities larger than one tile**
  (anti-degenerate clause 2) and thick strokes centred just outside a band
  boundary (M9's fixture).

**Three arms, and the second and third exist because the first cannot see their
defects.**

1. **Settled equals live** — criterion 5.
2. **Sub-tile pan after a settle** — criterion 11's first arm, and **M7's only
   gate**. An edge tile's transparent overhang costs exactly what an opaque
   blit costs, so Plan 3h's p95 pan gate is blind to it; only a pixel
   comparison after a pan smaller than one tile exposes it.
3. **A pan taken between the last scale change and the rest bake** — criterion
   11's second arm and **M10's gate**. It moves the visible key range so a
   key's grid-space rectangle goes negative; the pinned pure-zoom script never
   produces the case.

- [ ] **Step 1: Write the failing tests**

```dart
// packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart
void main() {
  testWidgets('a settled generation is identical to a live frame', (t) async {
    final h = await pumpTiled(t, document: bandCrossingGrid);
    await settle(t, h);
    expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0);
  });

  testWidgets('and stays identical after a pan smaller than one tile',
      (t) async {
    final h = await pumpTiled(t, document: bandCrossingGrid);
    await settle(t, h);
    h.camera.panBy(const Offset(-11, -7)); // under one 32-logical-pixel tile
    await settle(t, h);
    expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
        reason: 'an edge tile sliced from a viewport-sized source blits its '
            'transparent overhang here, and costs the same as an opaque one, '
            'so no timing gate can see it');
  });

  testWidgets('and when a pan lands between the scale change and the bake',
      (t) async {
    final h = await pumpTiled(t, document: bandCrossingGrid);
    await settle(t, h);
    h.camera.zoomAt(const Offset(120, 90), 1.3);
    await t.pump();                        // moving
    h.camera.panBy(const Offset(-90, -60)); // key range goes negative
    await t.pump();                        // moving again, gate resets
    await settle(t, h);
    expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
        reason: 'a grid-space slice rectangle is negative here and reads off '
            'the front of the band image');
  });

  // Criterion 6, with its teeth: the boundary columns and rows specifically.
  testWidgets('tile boundaries carry no difference of their own', (t) async {
    final h = await pumpTiled(t, document: bandCrossingGrid);
    await settle(t, h);
    final tiled = await captureTiled(t, h);
    final live = await captureLive(t, h);
    const w = 800, hgt = 600; // kTileViewport at kTileDpr, in device pixels
    expect(
        differingPixelsOnTileEdges(tiled, live,
            tileDevicePixels: 64, width: w, height: hgt),
        0);
    // Not vacuous: the sweep must have looked at ink, not at background.
    expect(
        inkOnTileEdges(live, tileDevicePixels: 64, width: w, height: hgt),
        greaterThan(200));
  });
}
```

- [ ] **Step 2: Run and watch them fail**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_slice_differential_test.dart`
Expected: FAIL to compile — the helpers do not exist yet.

- [ ] **Step 3: Implement the helpers and the fixture**

`captureTiled` renders the widget as it stands. `captureLive` rebuilds the same
document, index and camera with `tiles: false` and captures that. Both go
through `tester.runAsync` and `RenderRepaintBoundary.toImage`, the pattern
`tile_comparison.dart` already uses for its ink measurements.
```dart
/// Pixels whose RGBA differs, over two captures of the same size.
///
/// Exact `==` on stored bytes, never a tolerance: these are recorded values,
/// and a tolerance here is how a seam of one unit hides.
int differingPixels(ByteData a, ByteData b) {
  expect(a.lengthInBytes, b.lengthInBytes);
  var differing = 0;
  for (var i = 0; i < a.lengthInBytes; i += 4) {
    if (a.getUint32(i) != b.getUint32(i)) differing++;
  }
  return differing;
}

/// The same comparison, restricted to the columns and rows a tile boundary
/// falls on and the pixel either side of each.
int differingPixelsOnTileEdges(ByteData a, ByteData b,
    {required int tileDevicePixels, required int width, required int height}) {
  var differing = 0;
  bool onEdge(int v) {
    final m = v % tileDevicePixels;
    return m == 0 || m == 1 || m == tileDevicePixels - 1;
  }

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (!onEdge(x) && !onEdge(y)) continue;
      final i = (y * width + x) * 4;
      if (a.getUint32(i) != b.getUint32(i)) differing++;
    }
  }
  return differing;
}

/// Ink on those same rows and columns, so the sweep above cannot pass by
/// having looked at background. `live` is the untiled capture.
int inkOnTileEdges(ByteData live,
    {required int tileDevicePixels, required int width, required int height}) {
  var ink = 0;
  bool onEdge(int v) {
    final m = v % tileDevicePixels;
    return m == 0 || m == 1 || m == tileDevicePixels - 1;
  }

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (!onEdge(x) && !onEdge(y)) continue;
      // Opaque and not the white page: a drawn pixel.
      if (live.getUint32((y * width + x) * 4) != 0xFFFFFFFF) ink++;
    }
  }
  return ink;
}
```

`captureTiled` renders the widget as it stands. `captureLive` rebuilds the same
document, index and camera with `tiles: false` and captures that. Both go
through `tester.runAsync` and `RenderRepaintBoundary.toImage`, the pattern
`tile_comparison.dart` already uses.

`bandCrossingGrid` must satisfy anti-degenerate clauses 2 and 5: entities
**longer than one tile** — a 64-device-pixel tile is 32 logical at `kTileDpr`,
so lines of 200 logical units cross six tiles — and a fixture placed at the
far-from-origin coordinates `tile_fixture.dart` already uses, never at (0, 0).

- [ ] **Step 4: Run and watch them pass**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_slice_differential_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Fire M3, M7, M9, M10, M11 and M8**

| Mutant | Edit | Expected |
|---|---|---|
| M3 | `sliceSourceRect` returns `Rect.fromLTWH(0, 0, tile, tile)` | arms 1, 2 and 4 red |
| M7 | `bandsFor` clamps its rects to the viewport | arm 2 red |
| M9 | `const pad = 0.0` in `_bakeBand` | arm 1 red on `bandCrossingGrid` |
| M10 | `sliceSourceRect` drops `- band.deviceRect.left` | arm 3 red |
| M11 | `_bakeBand` derives its own origin from the band | the Task 6 boundary test red |
| M8 | `_sliceTile` uses a `FilterQuality.low` paint | **green — a declared survivor** |

**M8 is expected to survive** and is recorded as such, not as a gate's failure.
With integral source rectangles a bilinear sample and a nearest sample read the
same texels; only a sampler is paid for. Plan 3h's M6 had this shape and was
recorded as gap H6.

- [ ] **Step 6: Commit**

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .
git add -A packages/jet_cad_2d_flutter docs/superpowers/notes/plan-3i-mutation-log.md
git commit -m "test(tiles): differential arms for the slice, the overhang and the pan"
```

---

