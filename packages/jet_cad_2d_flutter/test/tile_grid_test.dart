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
      // Twenty-three pans of a deliberately awkward step, growing the
      // anchor-relative delta *positive*. That is what pushes the visible
      // rectangle's leading edge negative and exercises floor division for a
      // negative numerator from the very first pan: subtracting from e/f (as
      // an earlier version of this test did) only makes the delta more
      // negative, which pushes `left`/`top` in visibleKeys more *positive* --
      // receding from the anchor without ever crossing zero, so `_floorDiv`
      // never sees a negative numerator no matter how many pans follow. Each
      // camera is quantised, so each destination must still land exactly.
      var camera = grid.anchor;
      for (var i = 0; i < 23; i++) {
        final m = camera.worldToScreenMatrix;
        camera = quantiseCamera(
            ViewportTransform(
                worldToScreenMatrix:
                    Transform2(m.a, m.b, m.c, m.d, m.e + 7.37, m.f + 3.19)),
            kDpr);
        final (dx, dy) = grid.deviceDeltaFrom(camera);
        // The reference floor, computed independently of TileGrid, so a
        // truncating `_floorDiv` (Dart's `~/`) is caught even though it never
        // touches destRectFor: a truncated x0/y0 silently drops the tile that
        // should cover the viewport's leading edge, which shows up here as
        // the leftmost/topmost visible key being one column short of zero.
        final expectedX0 = (-dx / kTestTile).floor();
        final expectedY0 = (-dy / kTestTile).floor();
        final keys = grid.visibleKeys(camera, kViewport).toList();
        expect(keys.map((k) => k.x).reduce((a, b) => a < b ? a : b), expectedX0,
            reason: 'pan $i leftmost column: floor division toward negative '
                'infinity, not truncation toward zero');
        expect(keys.map((k) => k.y).reduce((a, b) => a < b ? a : b), expectedY0,
            reason: 'pan $i topmost row');
        for (final key in keys) {
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
      expect(baked.a, anchor.a,
          reason: 'scale is the generation, not the tile');
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
          worldToScreenMatrix:
              Transform2(m.a + m.a * 1e-15, m.b, m.c, m.d, m.e, m.f));
      expect(grid.matchesScale(nudged), isFalse);
    });

    // **Four fields, four arms, one field moved per arm.** `awkwardCamera`
    // has `d == -a` and `b == c == 0`, so the arm above -- which moves `a`
    // alone -- is the only one of the four comparisons it can fail: deleting
    // `a.b == b.b`, `a.c == b.c` or `a.d == b.d` from `matchesScale` left the
    // file green. This is `sameQuantisedCamera`'s own degeneracy (M19) at the
    // other stored-value comparison in this file, closed the same way, and it
    // needs its own fixture because no camera the tiled tests drive reaches
    // `matchesScale` with `b`, `c` or an independent `d`.
    test('every scale term is compared, one at a time', () {
      // Anisotropic *and* skewed, so no two of the four terms are tied.
      final grid = gridAt(ViewportTransform(
          worldToScreenMatrix:
              Transform2(2.5, 0.3, -0.7, -1.9, 17.31, 409.77)));
      final m = grid.anchor.worldToScreenMatrix;
      expect(grid.matchesScale(grid.anchor), isTrue,
          reason: 'non-vacuity: the anchor matches itself, so the four arms '
              'below fail for the field they move and not for the fixture');
      expect(
          grid.matchesScale(ViewportTransform(
              worldToScreenMatrix: Transform2(2.6, m.b, m.c, m.d, m.e, m.f))),
          isFalse,
          reason: 'a: the x scale');
      expect(
          grid.matchesScale(ViewportTransform(
              worldToScreenMatrix: Transform2(m.a, 0.4, m.c, m.d, m.e, m.f))),
          isFalse,
          reason: 'b: a generation baked without this shear cannot blit with '
              'it');
      expect(
          grid.matchesScale(ViewportTransform(
              worldToScreenMatrix: Transform2(m.a, m.b, -0.8, m.d, m.e, m.f))),
          isFalse,
          reason: 'c: the other shear term');
      expect(
          grid.matchesScale(ViewportTransform(
              worldToScreenMatrix: Transform2(m.a, m.b, m.c, -2.0, m.e, m.f))),
          isFalse,
          reason: 'd: the y scale, which every tiled fixture ties to -a');
      // And the translation is *not* in this comparison: a pan keeps the
      // generation, which is the whole reason the key excludes translation.
      expect(
          grid.matchesScale(ViewportTransform(
              worldToScreenMatrix:
                  Transform2(m.a, m.b, m.c, m.d, m.e + 13, m.f - 7))),
          isTrue,
          reason: 'a pan does not retire a generation');
    });
  });
}
