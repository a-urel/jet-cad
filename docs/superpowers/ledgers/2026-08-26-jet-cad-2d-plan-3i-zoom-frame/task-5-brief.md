## Task 5: Band geometry

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- Test: `packages/jet_cad_2d_flutter/test/tile_band_test.dart` (create)

**Interfaces:**
- Produces: on `TileGrid`,
  `List<TileBand> bandsFor(ViewportTransform camera, Size viewport)`, and the
  value type

  ```dart
  class TileBand {
    const TileBand({required this.row, required this.keys, required this.deviceRect});
    final int row;
    final List<TileKey> keys;
    /// In the grid's device space, the same space `deviceDeltaFrom` returns.
    final Rect deviceRect;
  }
  ```

  Task 6 walks each band; Task 7 slices it.

**The rule.** One band per tile row of `visibleKeys`, full union width. Bands
are what keep the peak at ~56 MiB instead of the 96 MiB a single union image
would cost — see spec D5, and note that `visibleKeys` yields a *full
rectangle*, so the union has the tile set's own area, not the viewport's.

- [ ] **Step 1: Write the failing test**

```dart
// packages/jet_cad_2d_flutter/test/tile_band_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/tile_fixture.dart';

void main() {
  TileGrid gridAt(ViewportTransform camera) => TileGrid(
      anchor: camera, devicePixelRatio: kTileDpr, tileDevicePixels: 64);

  test('the bands partition the visible keys, in row order, without gaps', () {
    final camera = quantiseCamera(tileCamera(), kTileDpr);
    final grid = gridAt(camera);
    final bands = grid.bandsFor(camera, kTileViewport);
    final fromBands = bands.expand((b) => b.keys).toList();
    final visible = grid.visibleKeys(camera, kTileViewport).toList();

    expect(fromBands.toSet(), visible.toSet(),
        reason: 'every visible key belongs to exactly one band');
    expect(fromBands.length, visible.length, reason: 'and to only one');
    for (var i = 1; i < bands.length; i++) {
      expect(bands[i].row, bands[i - 1].row + 1,
          reason: 'rows are contiguous and ascending');
      expect(bands[i].deviceRect.top, bands[i - 1].deviceRect.bottom,
          reason: 'and the bands touch without gap or overlap');
    }
  });

  test('a band is one tile tall and the full union width', () {
    final camera = quantiseCamera(tileCamera(), kTileDpr);
    final bands = gridAt(camera).bandsFor(camera, kTileViewport);
    for (final band in bands) {
      expect(band.deviceRect.height, 64.0);
      expect(band.deviceRect.width, band.keys.length * 64.0);
    }
  });

  // The overhang is the point. `visibleKeys` yields every key the viewport
  // touches, including keys that extend past it, and a source sized to the
  // viewport has no pixels for those. This is M7's territory.
  test('the union overhangs the viewport, and the bands carry the overhang',
      () {
    final camera = quantiseCamera(tileCamera(), kTileDpr);
    final bands = gridAt(camera).bandsFor(camera, kTileViewport);
    final union = bands
        .map((b) => b.deviceRect)
        .reduce((a, b) => a.expandToInclude(b));
    final device = Rect.fromLTWH(0, 0, kTileViewport.width * kTileDpr,
        kTileViewport.height * kTileDpr);
    expect(union.contains(device.topLeft), isTrue);
    expect(union.right, greaterThanOrEqualTo(device.right));
    expect(union.bottom, greaterThanOrEqualTo(device.bottom));
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_band_test.dart`
Expected: FAIL to compile — `bandsFor` and `TileBand` are not defined.

- [ ] **Step 3: Implement**

On `TileGrid`, beside `visibleKeys`:

```dart
/// One tile row of the visible region: every key in it, and the device
/// rectangle they span.
class TileBand {
  const TileBand(
      {required this.row, required this.keys, required this.deviceRect});

  final int row;
  final List<TileKey> keys;

  /// In the grid's device space — the space [TileGrid.deviceDeltaFrom]
  /// returns, whose origin is the grid's anchor and not the viewport.
  final Rect deviceRect;
}
```

```dart
  /// [visibleKeys] grouped into one band per tile row.
  ///
  /// **A band and not the whole union**, because the union has the tile set's
  /// own area — `visibleKeys` yields a full rectangle — so one image for it
  /// plus the tiles it is sliced into peaks at exactly `kTileCacheBytes` with
  /// no headroom. One row at a time is 8 MiB at the reference viewport against
  /// the union's 48.
  List<TileBand> bandsFor(ViewportTransform camera, Size viewport) {
    final byRow = <int, List<TileKey>>{};
    for (final key in visibleKeys(camera, viewport)) {
      (byRow[key.y] ??= <TileKey>[]).add(key);
    }
    final rows = byRow.keys.toList()..sort();
    return [
      for (final row in rows)
        TileBand(
          row: row,
          keys: byRow[row]!..sort((a, b) => a.x.compareTo(b.x)),
          deviceRect: Rect.fromLTWH(
            byRow[row]!.first.x * tileDevicePixels.toDouble(),
            row * tileDevicePixels.toDouble(),
            byRow[row]!.length * tileDevicePixels.toDouble(),
            tileDevicePixels.toDouble(),
          ),
        ),
    ];
  }
```

- [ ] **Step 4: Run it and watch it pass**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_band_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .
git add -A packages/jet_cad_2d_flutter
git commit -m "feat(tiles): group the visible keys into tile-row bands"
```

---

