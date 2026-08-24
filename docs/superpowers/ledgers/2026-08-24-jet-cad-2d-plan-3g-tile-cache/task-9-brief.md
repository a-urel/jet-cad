## Task 9: The generation, the carry-over composite, and the zoom path

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- Test: `packages/jet_cad_2d_flutter/test/tile_cache_test.dart`

**Interfaces:** produces `TileCache.hasCarryOver`, `TileCache.carryOverBlitCount`.

- [ ] **Step 1: Write criterion 8 as failing tests**

```dart
  test('criterion 8: a pan drops nothing and a scale change drops everything',
      () async {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);
    rig.paintOnce();
    final generation = rig.cache.generation;
    final tiles = rig.cache.liveTileCount;

    // Twelve pans, none of them a whole tile.
    for (var i = 0; i < 12; i++) {
      rig.panBy(-5.5, -2.5);
      rig.paintOnce();
    }
    expect(rig.cache.generation, generation,
        reason: 'a pan is not a new generation');
    expect(rig.cache.liveTileCount, greaterThanOrEqualTo(tiles),
        reason: 'a pan adds tiles at the leading edge and drops none');

    rig.zoomBy(1.03);
    rig.paintOnce();
    expect(rig.cache.generation, generation + 1);
    expect(rig.cache.hasCarryOver, isTrue,
        reason: 'the retired generation lives on as one composite: two live '
            'generations do not fit under the cap, and independently snapped '
            'scaled tiles gap or overlap along every shared edge');
  });

  test('a zoom gesture blits the carry-over and bakes nothing', () async {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 0);
    addTearDown(rig.dispose);
    // Budget 0 after the first frame: prove the gesture is a blit, not a bake.
    rig.paintOnce();
    rig.cache.resetCounters();
    for (var i = 0; i < 8; i++) {
      rig.zoomBy(1.03);
      rig.paintOnce();
    }
    expect(rig.cache.bakeCount, 0);
    expect(rig.cache.carryOverBlitCount, 8,
        reason: 'one composite blit per gesture frame');
    expect(rig.cache.liveDrawCount, 0,
        reason: 'the carry-over covers the viewport, so nothing is uncovered');
  });

  test('the settle spreads its bakes across frames', () async {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 4);
    addTearDown(rig.dispose);
    rig.paintOnce();
    rig.zoomBy(1.03);
    rig.cache.resetCounters();
    // Settled: the scale stops moving, so the new generation fills in.
    for (var i = 0; i < 3; i++) {
      rig.paintOnce();
    }
    expect(rig.cache.bakeCount, 12, reason: 'four per frame, three frames');
  });
```

- [ ] **Step 2: Implement**

`_retireGeneration` composites before it disposes:

```dart
  /// The retired generation, flattened to one viewport-sized image.
  ///
  /// **One image, not the old tiles.** `quantiseCamera` makes tile
  /// destinations exact only when they differ by whole multiples of the tile
  /// size, which holds at the generation's own scale and fails under an
  /// arbitrary zoom factor: snapped independently, adjacent scaled tiles leave
  /// a background gap or double-composite translucent ink along every shared
  /// edge. A composite has no internal edges. It also keeps the budget
  /// honest -- two live generations do not fit under [kTileCacheBytes], and
  /// LRU would never reclaim the outgoing one because the frame path reads it
  /// every frame.
  Image? _carryOver;
  ViewportTransform? _carryOverAnchor;
```

`_retireGeneration(Size viewport)` records the visible tiles into one picture at viewport size, `toImageSync`es it, disposes the tiles, and stores the anchor. `paintFrame`, when the grid is fresh, blits `_carryOver` first under `Rect` derived from the *old* anchor mapped through the *new* camera — this is the one blit that is **not** snapped and **does** want a filter, so it uses a second `Paint` with `FilterQuality.low` and the class comment says why.

The carry-over is dropped when the new generation covers the viewport (`uncovered == null` and no tile was baked this frame) or by `_dropEverything`.

- [ ] **Step 3: Run, then fire M4 and M9**

**M4** — make `TileGrid.matchesScale` return `true` always. Criterion 8 must go red, and criterion 1 after a zoom must go red too: the replayed generation carries the old scale's stroke widths and dash phase.

**M9** — ignore `tilesBakedPerFrame` and bake the whole visible set. The spread-bake test must go red. Note in the report that this mutant is *invisible* to every correctness criterion, which is why criterion 11 exists.

- [ ] **Step 4: Green and commit**

```sh
git add packages/jet_cad_2d_flutter/lib/src/tile_cache.dart packages/jet_cad_2d_flutter/test/tile_cache_test.dart
git commit -m "feat: generations, the carry-over composite, and the zoom path

A scale change retires the generation into one viewport-sized image and drops
its tiles. One image and not the old tiles, for two reasons that both bite:
snapping is exact only when destinations differ by whole multiples of the tile
size, which fails under an arbitrary zoom factor and leaves gaps or
double-composited overlaps along every shared edge; and two live generations do
not fit under the cap, with LRU unable to reclaim the outgoing one because the
frame path reads it every frame.

The settle spreads its bakes. Baking a whole visible set in one frame is the
~60 ms stall this cache exists to remove, moved rather than removed -- and it
is invisible to every correctness criterion, which is what criterion 11 is for."
```

---

