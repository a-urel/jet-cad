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
