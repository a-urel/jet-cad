## Task 8: Wire the rest bake into `paintFrame`

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` — `paintFrame`
- Test: `packages/jet_cad_2d_flutter/test/tile_settle_test.dart`
- Test: `packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart`

**Interfaces:**
- Consumes: `bandsFor`, `_bakeBand`, `_sliceTile`, `_band`, `_restGateSteps`.
- Produces: the resting branch. `_baked` gains one shared `Uint32List` per
  band. Task 10 reads `invalidationCount` against it.

**The order inside the frame is load-bearing.** Drop the composite *first*: the
frame is about to draw real content and does not need it, and at the reference
viewport composite + tiles + band is what keeps the peak at ~56 MiB instead of
running past `kTileCacheBytes`.

- [ ] **Step 1: Write the failing test**

Add to `tile_settle_test.dart`:

```dart
  testWidgets('the settle completes in one frame', (t) async {
    final h = await pumpTiled(t);
    await settle(t, h);
    expect(h.cache.viewportCovered, isTrue);

    h.camera.zoomAt(const Offset(120, 90), 1.3);
    await t.pump();                       // moving
    await t.pump();                       // in between
    final tilesBefore = h.cache.liveTileCount;
    await t.pump();                       // the rest frame
    expect(h.cache.viewportCovered, isTrue,
        reason: 'one rest frame covers the viewport; the tiled fill it '
            'replaces took one frame per tile');
    expect(h.cache.liveTileCount, greaterThan(tilesBefore));
    expect(t.binding.hasScheduledFrame, isFalse,
        reason: 'and nothing is owed afterwards');
  });
```

Add to `tile_bytes_test.dart`:

```dart
  testWidgets('the ceiling holds at every point inside the rest frame',
      (t) async {
    final h = await pumpTiled(t);
    await settle(t, h);
    h.cache.debugOnSliceForTest = () {
      expect(h.cache.liveBytes, lessThanOrEqualTo(kTileCacheBytes),
          reason: 'the band image is resident here and the meter counts it');
    };
    addTearDown(() => h.cache.debugOnSliceForTest = null);

    h.camera.zoomAt(const Offset(120, 90), 1.3);
    await t.pump();
    await t.pump();
    await t.pump();

    expect(h.cache.debugImagesAlive, h.cache.liveTileCount,
        reason: 'no band image outlives its band, and the composite was '
            'dropped before the bake');
  });
```

- [ ] **Step 2: Run both and watch them fail**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_settle_test.dart test/invariants/tile_bytes_test.dart`
Expected: FAIL — the settle still takes one frame per tile, and
`debugOnSliceForTest` is not defined.

- [ ] **Step 3: Implement the resting branch**

Replace the visible-key loop's body for the resting case. After the
`if (!resting) { return; }` guard from Task 2:

```dart
    // **The composite goes first.** The frame is about to draw real content
    // and does not need it, and at the reference viewport keeping it would put
    // composite + tiles + band past `kTileCacheBytes`.
    _dropCarryOver();

    final bands = grid.bandsFor(quantised, viewport);
    for (final band in bands) {
      final visited = <int>[];
      final image =
          _bakeBand(band, grid, quantised, painter, sink, vertices, origin, visited);
      _band = image;
      visited.sort();
      // **One record per band, shared by reference.** `_invalidateTouched`
      // condemns tiles by iterating `_baked`, and a sliced tile with no record
      // is invisible to it: edit an entity after a settle and the stale tile
      // keeps blitting over the corrected drawing. Sharing makes invalidation
      // band-coarse, which is right because a band is exactly the unit a
      // rebake walks.
      final record = Uint32List.fromList(visited);
      for (final key in band.keys) {
        debugOnSliceForTest?.call();
        // The ceiling is consulted before the write, not after the frame --
        // the rule the tile loop already follows. The slice bypasses
        // `budgetedTilesPerFrame`, which rations bakes; a slice is not a bake.
        if (!_makeRoomForOneTile()) break;
        final tile = _sliceTile(image, band, key, grid);
        _tiles[key] = tile;
        _baked[key] = record;
        _lastUsedFrame[key] = _frameSerial;
      }
      _band = null;
      image.dispose();
      _imagesAlive--;
      _bakes++;
    }

    // Now blit what was just produced. The visible-key loop below is unchanged
    // and finds every tile present.
```

Add the test seam beside the other debug members:

```dart
  /// Called once per sliced tile, while the band image is resident.
  ///
  /// The only point at which the byte ceiling can be observed at its peak;
  /// a check after the frame would always read the steady state.
  @visibleForTesting
  void Function()? debugOnSliceForTest;
```

- [ ] **Step 4: Run and watch them pass**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test`
Expected: PASS, the whole package.

- [ ] **Step 5: Fire M2 and M6**

**M2** — `for (final key in band.keys)` becomes `band.keys.take(1)`. Expected:
the one-frame settle test goes red.
**M6** — delete `image.dispose(); _imagesAlive--;`. Expected: the
`debugImagesAlive` assertion goes red.
Restore from the copy each time. Record both verbatim in the mutation log.

- [ ] **Step 6: Commit**

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .
git add -A packages/jet_cad_2d_flutter docs/superpowers/notes/plan-3i-mutation-log.md
git commit -m "feat(tiles): a resting frame bakes in bands and slices them into tiles"
```

---

