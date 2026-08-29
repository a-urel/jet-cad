## Task 7: The slice — band-local, integral, unfiltered

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- Test: `packages/jet_cad_2d_flutter/test/tile_band_test.dart`

**Interfaces:**
- Consumes: `_bakeBand` from Task 6, `TileBand` from Task 5.
- Produces: on `TileCache`,
  `Image _sliceTile(Image band, TileBand from, TileKey key, TileGrid grid)`.

**The rule that matters.** A key's device rectangle is in **grid** space, whose
origin is the generation's anchor, and it goes negative the moment a same-scale
pan moves the visible key range. The copy therefore reads
`keyDeviceRect - band.deviceRect.topLeft`. Reading the grid-space rectangle
directly is **M10**, and a pure zoom script never produces the case — which is
why Task 9 carries an arm that pans between the last scale change and the rest
bake.

- [ ] **Step 1: Write the failing test**

```dart
  test('a slice rectangle is band-local and integral', () {
    final camera = quantiseCamera(tileCamera(), kTileDpr);
    final grid = gridAt(camera);
    final band = grid.bandsFor(camera, kTileViewport).first;
    for (final key in band.keys) {
      final src = grid.sliceSourceRect(band, key);
      expect(src.left, greaterThanOrEqualTo(0.0),
          reason: 'band-local, so never negative however the keys are '
              'numbered -- a same-scale pan takes key.x negative');
      expect(src.top, 0.0);
      expect(src.width, 64.0);
      expect(src.height, 64.0);
      expect(src.left, src.left.roundToDouble(),
          reason: 'integral by construction: `deviceDeltaFrom` rounds, and a '
              'tile side is `tileDevicePixels / dpr` exactly');
    }
    expect(grid.sliceSourceRect(band, band.keys.first).left, 0.0);
  });
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_band_test.dart`
Expected: FAIL to compile — `sliceSourceRect` is not defined.

- [ ] **Step 3: Implement**

On `TileGrid`:

```dart
  /// Where [key]'s pixels sit **inside** [band]'s image.
  ///
  /// Band-local, not grid-space. A key's device rectangle is measured from the
  /// generation's anchor and goes negative as soon as a same-scale pan moves
  /// the visible range; the band image starts at (0, 0) whatever the keys are
  /// numbered. Integral by construction — [deviceDeltaFrom] rounds, and a tile
  /// side is `tileDevicePixels` exactly.
  Rect sliceSourceRect(TileBand band, TileKey key) => Rect.fromLTWH(
        key.x * tileDevicePixels.toDouble() - band.deviceRect.left,
        0,
        tileDevicePixels.toDouble(),
        tileDevicePixels.toDouble(),
      );
```

On `TileCache`:

```dart
  /// Copies one tile's pixels out of a band image.
  ///
  /// A texture copy, not a geometry raster — which is the whole difference
  /// from the rejected Approach B. `FilterQuality.none`: the source rectangle
  /// is integral and the destination is the same size, so there is nothing to
  /// interpolate and a sampler would be pure cost.
  Image _sliceTile(Image band, TileBand from, TileKey key, TileGrid grid) {
    final recorder = PictureRecorder();
    final into = Canvas(recorder);
    into.drawImageRect(
      band,
      grid.sliceSourceRect(from, key),
      Rect.fromLTWH(
          0, 0, tileDevicePixels.toDouble(), tileDevicePixels.toDouble()),
      _blitPaint,
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(tileDevicePixels, tileDevicePixels);
    _imagesAlive++;
    picture.dispose();
    return image;
  }
```

- [ ] **Step 4: Run it and watch it pass**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_band_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .
git add -A packages/jet_cad_2d_flutter
git commit -m "feat(tiles): slice a band into tiles with band-local integral rects"
```

---

