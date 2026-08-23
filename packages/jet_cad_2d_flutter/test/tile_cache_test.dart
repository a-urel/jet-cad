// What the cache does, counted. Criteria 1-4 arrive in Tasks 5 and 6 and
// compare pixels; these three ask whether the machine ran at all, which is
// what makes a later zero-difference result mean something rather than
// meaning nothing was drawn -- the trap the 3g spike walked into with Probe C.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'support/spy_canvas.dart';
import 'support/tile_fixture.dart';

void main() {
  test('a first frame bakes up to its budget and draws the rest live',
      () async {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 3);
    addTearDown(rig.dispose);

    rig.paintOnce();

    expect(rig.cache.bakeCount, 3, reason: 'the budget, not the visible set');
    expect(rig.cache.blitCount, 3, reason: 'what was baked is what blitted');
    expect(rig.cache.liveDrawCount, 1,
        reason: 'one walk for the union of the uncovered rects, not one per '
            'tile: 154 painter invocations in a frame would be slower than '
            'the live path this cache replaces');
  });

  test('a warm frame bakes nothing and blits the whole visible set', () async {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);

    rig.paintOnce();
    final visible = rig.cache.blitCount;
    expect(visible, greaterThan(30),
        reason: 'anti-degenerate clause 3: a single-tile viewport would make '
            'every grid and seam claim vacuous');

    rig.cache.resetCounters();
    rig.paintOnce();

    expect(rig.cache.bakeCount, 0);
    expect(rig.cache.blitCount, visible);
    expect(rig.cache.liveDrawCount, 0, reason: 'nothing left uncovered');
  });

  test('the blit Paint is one instance for the life of the cache', () {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);
    rig.paintOnce();
    final first = rig.cache.debugBlitPaint;
    rig.paintOnce();
    expect(identical(rig.cache.debugBlitPaint, first), isTrue,
        reason: 'criterion 13, and the shape VerticesDrawSink.debugPaint '
            'already uses: debugCapacityVertices cannot see a Paint');
  });

  test(
      'the blit hands drawImageRect the same Paint object every time, not a '
      'call-site-local one', () {
    // The test above pins that the `_blitPaint` *field* is not reassigned,
    // which a mutation that builds a fresh, call-site-local `Paint` and
    // passes it straight to `drawImageRect` -- never touching the field --
    // survives: `debugBlitPaint` still reads the untouched field, so
    // `identical` still reports true. Confirmed empirically against this
    // exact mutation (see task-4-report.md). `SpyCanvas` reads what
    // `dart:ui` actually received, which is the only way to see the
    // difference: identity of the object handed to the call, not of the
    // field. The same gap and the same fix are recorded in
    // `paint_allocation_test.dart` for `VerticesDrawSink.debugPaint`.
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);
    final spy = SpyCanvas();

    rig.cache.paintFrame(
      canvas: spy,
      viewport: kTileViewport,
      devicePixelRatio: kTileDpr,
      camera: rig.camera,
      painter: rig.painter,
      sink: rig.sink,
      vertices: rig.vertices,
    );

    final calls = spy.named('drawImageRect').toList();
    expect(calls.length, greaterThan(30),
        reason: 'anti-degenerate clause 3: a single-tile viewport would make '
            'the identity comparison below vacuous over one call');
    final paints = calls.map((c) => c.args.whereType<Paint>().single).toList();
    final first = paints.first;
    for (final paint in paints) {
      expect(identical(paint, first), isTrue,
          reason: 'paintFrame must hand drawImageRect the one Paint built '
              "for the cache's life, not a fresh one per blit");
    }
  });
}
