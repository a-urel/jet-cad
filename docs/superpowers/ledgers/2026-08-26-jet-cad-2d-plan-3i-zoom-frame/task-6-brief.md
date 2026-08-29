## Task 6: The band bake — padded query, hard clip, viewport-derived origin

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- Test: `packages/jet_cad_2d_flutter/test/tile_band_test.dart`

**Interfaces:**
- Consumes: `TileBand` from Task 5; `_drawInto(canvas, size, camera, painter,
  sink, vertices, origin, onVisit)`, already in the file; `kTileSlack`, already
  a top-level constant.
- Produces: on `TileCache`,

  ```dart
  Image _bakeBand(
    TileBand band,
    TileGrid grid,
    ViewportTransform quantised,
    DraftPainter painter,
    CanvasDrawSink sink,
    VerticesDrawSink? vertices,
    Vector2 origin,
    List<int> visitedInto,
  );
  ```

  `visitedInto` is filled with the handles the walk touched, for Task 8.

**Three things this task decides, all of them from the spec's D4:**

1. **The query is padded and the clip is not.** A stroke whose centreline lies
   just outside the band still inks inside it. `_bake` already does this — its
   comment states the rule — and dropping it here is **M9**.
2. **The rebase origin is the viewport's**, passed in, never derived from the
   band. A band-derived origin gives each band its own `float32` residual and
   can cross a power-of-two step. Dropping this is **M11**.
3. **The clip is hard.** An antialiased clip edge would make two adjacent
   bands' `source-over` fall short of full coverage along the shared row — the
   same seam `_bake` avoids the same way.

- [ ] **Step 1: Write the failing test**

```dart
  // M9's gate. A stroke whose centreline sits outside the band still inks
  // inside it, so the query has to reach past the band's edge. The fixture
  // puts a thick horizontal stroke one logical pixel above a band boundary.
  testWidgets('a stroke centred outside the band still inks inside it',
      (t) async {
    final h = await pumpTiled(t);
    await settle(t, h);
    final tiled = await captureTiled(t, h);
    final live = await captureLive(t, h);
    expect(differingPixels(tiled, live), 0,
        reason: 'an unpadded band query drops the half of a boundary stroke '
            'that belongs to the band below it');
  });

  // M11's gate. Placed where the view span crosses a power-of-two step, so a
  // band-derived origin and a viewport-derived one disagree in float32.
  testWidgets('every band shares the viewport-derived rebase origin',
      (t) async {
    final h = await pumpTiled(t, camera: rebaseBoundaryCamera());
    await settle(t, h);
    final tiled = await captureTiled(t, h);
    final live = await captureLive(t, h);
    expect(differingPixels(tiled, live), 0,
        reason: 'a per-band origin gives each band its own residual, and the '
            'rows disagree along their shared edge');
  });
```

`captureTiled`, `captureLive`, `differingPixels` and `rebaseBoundaryCamera` are
added in Task 9 and used here; **write Task 9's helpers first if this task is
executed before it.** They live in
`packages/jet_cad_2d_flutter/test/support/tile_comparison.dart` beside the
existing `measureFallbackAgreement`.

- [ ] **Step 2: Run it and watch it fail**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_band_test.dart`
Expected: FAIL — `_bakeBand` does not exist yet, so nothing bakes and the
captures differ everywhere.

- [ ] **Step 3: Implement**

```dart
  /// Walks one band into one image.
  ///
  /// Modelled on [_bake] and sharing all three of its rules, at band scale.
  Image _bakeBand(
    TileBand band,
    TileGrid grid,
    ViewportTransform quantised,
    DraftPainter painter,
    CanvasDrawSink sink,
    VerticesDrawSink? vertices,
    Vector2 origin,
    List<int> visitedInto,
  ) {
    final dpr = grid.devicePixelRatio;
    final width = band.deviceRect.width / dpr;
    final height = band.deviceRect.height / dpr;
    final recorder = PictureRecorder();
    final into = Canvas(recorder);
    into.scale(dpr);
    // **Hard, and for `_bake`'s reason.** An antialiased clip edge would make
    // two adjacent bands' `source-over` fall short of full coverage along the
    // row they share: a seam, in the one place this design exists to remove
    // one.
    into.clipRect(Rect.fromLTWH(0, 0, width, height), doAntiAlias: false);

    // **The query is padded; the clip is not.** A stroke whose centreline lies
    // just outside the band still inks inside it. `kTileSlack` is the same
    // slack `_bake` uses and the same slack the invalidation rule uses --
    // padding one alone makes them disagree.
    const pad = kTileSlack;
    into.save();
    into.translate(-pad, -pad);

    final m = quantised.worldToScreenMatrix;
    final bandCamera = ViewportTransform(
      worldToScreenMatrix: Transform2(
        m.a,
        m.b,
        m.c,
        m.d,
        m.e - band.deviceRect.left / dpr + pad,
        m.f - band.deviceRect.top / dpr + pad,
      ),
    );

    _drawInto(
      into,
      Size(width + 2 * pad, height + 2 * pad),
      bandCamera,
      painter,
      sink,
      vertices,
      // **The viewport's origin, never the band's.** Rebasing is frame-global
      // by construction: a per-band origin gives each band its own
      // quantisation step and `float32` residuals the live frame does not
      // have, and can cross a power-of-two step between one row and the next.
      origin,
      (handle) => visitedInto.add(handle.value),
    );
    into.restore();

    final picture = recorder.endRecording();
    final image = picture.toImageSync(
        band.deviceRect.width.round(), band.deviceRect.height.round());
    _imagesAlive++;
    picture.dispose();
    return image;
  }
```

**The `onVisit` callback is deliberately simpler than `_bake`'s.** `_bake`
climbs owners so a container transform reaches the tile through direction one.
A band records the same information for a wider region, and Task 8 shares one
record across the band's tiles, so the owner climb happens once there rather
than per tile.

- [ ] **Step 4: Run it and watch it pass**

Run after Task 8 wires it in; on its own this step's expectation is that
`_bakeBand` compiles and the package stays green.

- [ ] **Step 5: Commit**

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .
git add -A packages/jet_cad_2d_flutter
git commit -m "feat(tiles): walk one band into one image, padded query and hard clip"
```

---

