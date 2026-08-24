## Task 3: `TileKey`, `TileGrid` and `quantiseCamera` — arithmetic only, nothing drawn

**Why separate:** every correctness claim in this plan rests on tile destinations being integral device pixels at *every* camera. That is pure arithmetic and it is worth a reviewer's gate of its own, before a single pixel is baked.

**Files:**
- Create: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- Create: `packages/jet_cad_2d_flutter/test/tile_grid_test.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart`

**Interfaces:**
- Consumes: `ViewportTransform`, `Transform2`.
- Produces: `kTileDevicePixels`, `TileKey`, `TileGrid`, `quantiseCamera`. Task 4 bakes and blits with them.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d_flutter/test/tile_grid_test.dart`:

```dart
// The grid is the whole of Plan 3g's exactness claim. A tile blits 1:1 only
// if its destination lands on whole device pixels, and criterion 1 requires
// that at *every* camera, not at a privileged one -- the key excludes
// translation by design, and a pan drops nothing, so there is no moment when
// the camera returns to where the grid was anchored.
//
// Nothing here draws. The arithmetic is worth failing on its own.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// Deliberately not `ViewportTransform.fit`, and deliberately not the
/// identity: `fit` applies a 0.95 margin and cost Plan 3f two tasks, and a
/// scale of 1.0 with a zero translation hides every mistake this file exists
/// to catch. Scale 2.5, y flipped, and an offset that is not a whole device
/// pixel.
ViewportTransform awkwardCamera() => ViewportTransform(
    worldToScreenMatrix: Transform2(2.5, 0, 0, -2.5, 17.31, 409.77));

const double kDpr = 2.0;
const Size kViewport = Size(400, 300);
const int kTestTile = 64;

void main() {
  group('quantiseCamera', () {
    test('snaps the translation to whole device pixels and nothing else', () {
      final q = quantiseCamera(awkwardCamera(), kDpr);
      final m = q.worldToScreenMatrix;
      expect(m.a, 2.5, reason: 'scale untouched');
      expect(m.d, -2.5);
      expect(m.b, 0.0);
      expect(m.c, 0.0);
      expect((m.e * kDpr) % 1.0, 0.0, reason: 'e is a whole device pixel');
      expect((m.f * kDpr) % 1.0, 0.0, reason: 'f is a whole device pixel');
      // 17.31 * 2 = 34.62 -> 35 -> 17.5;  409.77 * 2 = 819.54 -> 820 -> 410.0
      expect(m.e, 17.5);
      expect(m.f, 410.0);
    });

    test('returns the same instance when already quantised', () {
      final already = ViewportTransform(
          worldToScreenMatrix: Transform2(2.5, 0, 0, -2.5, 17.5, 410.0));
      expect(identical(quantiseCamera(already, kDpr), already), isTrue,
          reason: 'rebuilding would recompute the inverse for nothing, once '
              'per frame, on the frame path');
    });

    test('a dpr of 1 still quantises', () {
      final q = quantiseCamera(awkwardCamera(), 1.0);
      expect(q.worldToScreenMatrix.e, 17.0);
      expect(q.worldToScreenMatrix.f, 410.0);
    });
  });

  group('TileGrid', () {
    TileGrid gridAt(ViewportTransform anchor) => TileGrid(
        anchor: quantiseCamera(anchor, kDpr),
        devicePixelRatio: kDpr,
        tileDevicePixels: kTestTile);

    test('the visible key count matches ceil(extent / tile) + 1 per axis', () {
      final grid = gridAt(awkwardCamera());
      // 400 x 300 logical at dpr 2 = 800 x 600 device. 800/64 = 12.5 -> 13,
      // 600/64 = 9.375 -> 10; the +1 per axis covers an arbitrary alignment.
      final keys = grid.visibleKeys(grid.anchor, kViewport).toList();
      final xs = keys.map((k) => k.x).toSet();
      final ys = keys.map((k) => k.y).toSet();
      expect(xs.length, inInclusiveRange(13, 14));
      expect(ys.length, inInclusiveRange(10, 11));
      expect(keys.length, xs.length * ys.length,
          reason: 'the visible set is a full rectangle of keys');
    });

    test('every destination is a whole device pixel, at every panned camera',
        () {
      final grid = gridAt(awkwardCamera());
      // Twenty-three pans of a deliberately awkward step. Each is quantised,
      // so each destination must still land exactly.
      var camera = grid.anchor;
      for (var i = 0; i < 23; i++) {
        final m = camera.worldToScreenMatrix;
        camera = quantiseCamera(
            ViewportTransform(
                worldToScreenMatrix: Transform2(
                    m.a, m.b, m.c, m.d, m.e - 7.37, m.f - 3.19)),
            kDpr);
        for (final key in grid.visibleKeys(camera, kViewport)) {
          final dest = grid.destRectFor(key, camera);
          expect((dest.left * kDpr) % 1.0, 0.0,
              reason: 'pan $i, key (${key.x}, ${key.y}) left');
          expect((dest.top * kDpr) % 1.0, 0.0,
              reason: 'pan $i, key (${key.x}, ${key.y}) top');
          expect(dest.width * kDpr, kTestTile);
          expect(dest.height * kDpr, kTestTile);
        }
      }
    });

    test('adjacent tiles abut exactly, with no gap and no overlap', () {
      final grid = gridAt(awkwardCamera());
      final camera = grid.anchor;
      final a = grid.destRectFor(const TileKey(3, 5), camera);
      final right = grid.destRectFor(const TileKey(4, 5), camera);
      final below = grid.destRectFor(const TileKey(3, 6), camera);
      expect(right.left, a.right, reason: 'a gap shows background');
      expect(below.top, a.bottom,
          reason: 'an overlap double-composites translucent ink');
    });

    test('the bake camera puts a tile top-left at the logical origin', () {
      final grid = gridAt(awkwardCamera());
      const key = TileKey(3, 5);
      final bake = grid.bakeCameraFor(key);
      final anchor = grid.anchor.worldToScreenMatrix;
      final baked = bake.worldToScreenMatrix;
      expect(baked.a, anchor.a, reason: 'scale is the generation, not the tile');
      expect(baked.d, anchor.d);
      expect(baked.e, anchor.e - 3 * kTestTile / kDpr);
      expect(baked.f, anchor.f - 5 * kTestTile / kDpr);
    });

    test('matchesScale is exact, not tolerant', () {
      final grid = gridAt(awkwardCamera());
      final m = grid.anchor.worldToScreenMatrix;
      expect(grid.matchesScale(grid.anchor), isTrue);
      // One ulp of zoom retires the generation. Stored-value comparisons in
      // this repository are exact `==`; a tolerant scale test would replay a
      // generation baked at a different stroke width and dash phase.
      final nudged = ViewportTransform(
          worldToScreenMatrix: Transform2(
              m.a + m.a * 1e-15, m.b, m.c, m.d, m.e, m.f));
      expect(grid.matchesScale(nudged), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_grid_test.dart
```

Expected: compile failure — `tile_cache.dart` does not exist.

- [ ] **Step 3: Write `tile_cache.dart`'s arithmetic half**

```dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart';

import 'viewport_transform.dart';

/// A tile's side, in **device** pixels.
///
/// 256 is a starting value with a measured shape behind it and a sweep still
/// owed. Memory and bake cost pull in opposite directions: at a `dpr` of 2 on a
/// 3200x2400 device viewport, 128 px costs 32.5 MiB of visible set but bakes
/// **4.00x** its own area, because `kScreenClipInflate` is 32 *logical* pixels
/// and a 128 px tile is only 64 logical wide; 512 px costs 48.0 MiB and bakes
/// 1.56x. 1024 px is excluded outright — its 80.0 MiB visible set leaves no
/// room under [kTileCacheBytes] for the carry-over composite.
const int kTileDevicePixels = 256;

/// Tiles baked per frame while a generation fills in.
///
/// The settle after a zoom leaves the whole visible set stale, and baking it in
/// one frame is the ~60 ms stall this plan exists to remove, moved rather than
/// removed. At 256 px this covers a 154-tile visible set in twenty frames.
const int kTilesBakedPerFrame = 8;

/// The cache's byte ceiling, counting the carry-over composite and every
/// generation's tiles together.
///
/// 96 MiB, not 64, for two reasons. A retired generation lives on as one
/// viewport-sized composite (29.3 MiB on the reference viewport) beside the
/// incoming generation's tiles (38.5 MiB at 256 px). And 96 MiB is the figure
/// this cache may *replace*: the vertex buffer's high-water mark at 500,000
/// entities, which falls to a single tile's geometry once bakes flush per tile.
const int kTileCacheBytes = 96 * 1024 * 1024;

/// One tile's position in its generation's grid. Not world coordinates: the
/// grid is anchored to the generation's own device-pixel lattice.
@immutable
class TileKey {
  const TileKey(this.x, this.y);

  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is TileKey && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'TileKey($x, $y)';
}

/// Snaps a camera's screen translation to whole device pixels.
///
/// **This is the whole of Plan 3g's exactness claim, and it applies to the live
/// path too.** A world-anchored tile lands at a fractional device offset after
/// an arbitrary pan, and settling never returns the camera to the one the grid
/// was anchored at — the tile key excludes translation by design, and a pan is
/// required to invalidate nothing. Quantising both paths puts every tile
/// destination on whole device pixels at every camera, which is what lets the
/// tiled frame be required to equal the live frame with zero differing pixels.
///
/// The cost is up to half a device pixel of global position error, identical in
/// both paths and uniform across the frame. Nothing on screen provides a
/// reference against which it could read as jitter.
ViewportTransform quantiseCamera(
    ViewportTransform camera, double devicePixelRatio) {
  final m = camera.worldToScreenMatrix;
  final e = (m.e * devicePixelRatio).roundToDouble() / devicePixelRatio;
  final f = (m.f * devicePixelRatio).roundToDouble() / devicePixelRatio;
  // Returning the same instance matters: `ViewportTransform`'s constructor
  // inverts the matrix, and this runs once per frame on the frame path.
  if (e == m.e && f == m.f) return camera;
  return ViewportTransform(
      worldToScreenMatrix: Transform2(m.a, m.b, m.c, m.d, e, f));
}

/// One scale generation's lattice.
///
/// Tile `(x, y)` occupies device pixels `[x*T, (x+1)*T) x [y*T, (y+1)*T)` in
/// the **anchor's** screen space. A later camera at the same scale differs from
/// the anchor by a whole number of device pixels, so a tile's destination is
/// that rect plus an integral offset — never a resample.
@immutable
class TileGrid {
  const TileGrid({
    required this.anchor,
    required this.devicePixelRatio,
    required this.tileDevicePixels,
  });

  /// The quantised camera this generation was baked against.
  final ViewportTransform anchor;
  final double devicePixelRatio;
  final int tileDevicePixels;

  /// A tile's side in logical pixels.
  double get _tileLogical => tileDevicePixels / devicePixelRatio;

  /// **Exact, not tolerant.** Stored-value comparisons in this repository are
  /// exact `==`, and a tolerant test would replay a generation baked at a
  /// different stroke width and a different dash phase.
  bool matchesScale(ViewportTransform camera) {
    final a = anchor.worldToScreenMatrix;
    final b = camera.worldToScreenMatrix;
    return a.a == b.a && a.b == b.b && a.c == b.c && a.d == b.d;
  }

  /// How far [camera] sits from the anchor, in device pixels.
  ///
  /// Integral whenever both cameras came through [quantiseCamera], which is
  /// the invariant the whole grid rests on. `round` rather than a bare cast so
  /// a `0.9999999` from the division does not truncate to a one-pixel shift.
  (int, int) deviceDeltaFrom(ViewportTransform camera) {
    final a = anchor.worldToScreenMatrix;
    final b = camera.worldToScreenMatrix;
    return (
      ((b.e - a.e) * devicePixelRatio).round(),
      ((b.f - a.f) * devicePixelRatio).round(),
    );
  }

  /// Every key covering [viewport] at [camera], as a full rectangle.
  Iterable<TileKey> visibleKeys(ViewportTransform camera, Size viewport) sync* {
    final (dx, dy) = deviceDeltaFrom(camera);
    final left = -dx;
    final top = -dy;
    final right = left + (viewport.width * devicePixelRatio).ceil();
    final bottom = top + (viewport.height * devicePixelRatio).ceil();
    final x0 = _floorDiv(left, tileDevicePixels);
    final x1 = _floorDiv(right - 1, tileDevicePixels);
    final y0 = _floorDiv(top, tileDevicePixels);
    final y1 = _floorDiv(bottom - 1, tileDevicePixels);
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        yield TileKey(x, y);
      }
    }
  }

  /// The camera a bake uses, so the tile's top-left is the logical origin.
  ///
  /// Scale and skew come from the anchor untouched: the scale *is* the
  /// generation.
  ViewportTransform bakeCameraFor(TileKey key) {
    final m = anchor.worldToScreenMatrix;
    return ViewportTransform(
        worldToScreenMatrix: Transform2(m.a, m.b, m.c, m.d,
            m.e - key.x * _tileLogical, m.f - key.y * _tileLogical));
  }

  /// Where a tile blits, in logical pixels. Always a whole device pixel.
  Rect destRectFor(TileKey key, ViewportTransform camera) {
    final (dx, dy) = deviceDeltaFrom(camera);
    return Rect.fromLTWH(
      (key.x * tileDevicePixels + dx) / devicePixelRatio,
      (key.y * tileDevicePixels + dy) / devicePixelRatio,
      _tileLogical,
      _tileLogical,
    );
  }

  /// Floor division that stays correct for negative numerators.
  ///
  /// Dart's `~/` truncates toward zero, so `-1 ~/ 64` is `0` and the tile to
  /// the left of the origin would share a key with the tile at it. A pan in
  /// either direction reaches negative keys within one tile of the anchor.
  static int _floorDiv(int a, int b) => (a / b).floor();
}
```

`math` is unused for now; do not import it until Task 10 needs it — `unused_import` is an error in this package.

- [ ] **Step 4: Export it**

In `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart`, add in alphabetical position:

```dart
export 'src/tile_cache.dart';
```

- [ ] **Step 5: Run it and watch it pass**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_grid_test.dart
```

- [ ] **Step 6: Fire two mutants by hand**

```sh
cp lib/src/tile_cache.dart /tmp/tile_cache.dart.bak
```

**M10's arithmetic half:** delete the rounding in `quantiseCamera` (`final e = m.e;`). The whole-device-pixel assertions must go red.

**The negative-key mutant:** change `_floorDiv` to `a ~/ b`. The `abut exactly` test and the panned-destination test must go red once the pan crosses the anchor. If they do not, the pan step is too small to reach a negative key and the test is degenerate — fix the test, not the mutant.

```sh
cp /tmp/tile_cache.dart.bak lib/src/tile_cache.dart && rm /tmp/tile_cache.dart.bak
```

- [ ] **Step 7: Green and commit**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .
git add packages/jet_cad_2d_flutter/lib/src/tile_cache.dart packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart packages/jet_cad_2d_flutter/test/tile_grid_test.dart
git commit -m "feat: the tile grid, and the quantisation the exactness claim rests on

A world-anchored tile lands at a fractional device offset after an arbitrary
pan, and settling never returns the camera to the one the grid was anchored at
-- the key excludes translation by design and a pan invalidates nothing. So the
frame's screen translation is quantised to whole device pixels on both the
tiled and the live path, and every tile destination is integral at every
camera.

Nothing here draws. The arithmetic is the whole of the exactness claim and it
fails on its own: destinations across twenty-three awkward pans, adjacent tiles
abutting with no gap and no overlap, and a scale test that is exact rather than
tolerant because a tolerant one would replay a generation baked at a different
dash phase.

Floor division, not truncation: -1 ~/ 64 is 0 in Dart, which would give the
tile left of the origin the same key as the tile at it, one tile into any pan."
```

---

