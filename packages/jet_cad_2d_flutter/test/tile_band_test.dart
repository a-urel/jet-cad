import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/tile_fixture.dart';

/// A painter that records what the band bake handed it and draws nothing.
///
/// **Nothing is drawn on purpose.** What this task decides is arithmetic --
/// which camera, which viewport size, which rebase origin -- and every one of
/// those is visible at the moment [paint] is entered. Rasterising the fixture
/// as well would only make the answer arrive through a pixel comparison that
/// the later differential task owns and that this task cannot yet run.
class _RecordingPainter extends DraftPainter {
  _RecordingPainter(DraftDocument document, SpatialIndex index)
      : super(
            document: document,
            index: index,
            resolver: DocumentStyleResolver(document));

  ViewportTransform? seenCamera;
  Size? seenViewport;
  Vector2? seenOrigin;
  int paints = 0;

  @override
  void paint(DrawSink sink, ViewportTransform camera, Size viewport) {
    paints++;
    seenCamera = camera;
    seenViewport = viewport;
    // Read here rather than after the call: `_drawInto` clears it in a
    // `finally`, so a test that looked afterwards would always see null and
    // could never tell a passed-through origin from a dropped one.
    seenOrigin = debugRebaseOrigin;
  }
}

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
    final union =
        bands.map((b) => b.deviceRect).reduce((a, b) => a.expandToInclude(b));
    final device = Rect.fromLTWH(
        0, 0, kTileViewport.width * kTileDpr, kTileViewport.height * kTileDpr);
    expect(union.contains(device.topLeft), isTrue);
    expect(union.right, greaterThanOrEqualTo(device.right));
    expect(union.bottom, greaterThanOrEqualTo(device.bottom));
  });

  // The band bake's own arithmetic, checked without rasterising anything.
  //
  // **The fixture is deliberately off both axes and off the anchor.** The grid
  // is anchored at the resting camera and the frame camera is then panned a
  // whole number of device pixels away from it, so the visible key range
  // starts at x = 1 rather than 0 and a band from a lower row has a non-zero
  // `deviceRect.top` as well as a non-zero `left`. A band at (0, 0) under an
  // anchor that equals the frame camera proves none of what follows.
  group('the band bake', () {
    // -50 logical at dpr 2 is exactly -100 device pixels, so the pan keeps
    // the grid's whole-device-pixel invariant and `deviceDeltaFrom` stays
    // integral.
    const panX = -50.0;
    const panY = -30.0;
    const pad = kTileSlack;

    late TileRig rig;
    late ViewportTransform anchor;
    late ViewportTransform frame;
    late TileGrid grid;
    late List<TileBand> bands;
    late TileBand band;

    setUp(() {
      rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
      anchor = quantiseCamera(tileCamera(), kTileDpr);
      final m = anchor.worldToScreenMatrix;
      frame = quantiseCamera(
          ViewportTransform(
              worldToScreenMatrix:
                  Transform2(m.a, m.b, m.c, m.d, m.e + panX, m.f + panY)),
          kTileDpr);
      grid = TileGrid(
          anchor: anchor, devicePixelRatio: kTileDpr, tileDevicePixels: 64);
      bands = grid.bandsFor(frame, kTileViewport);
      // A lower row, so neither offset is zero.
      band = bands[3];
    });

    tearDown(() => rig.dispose());

    test('the fixture puts the band off both axes and off the anchor', () {
      expect(band.deviceRect.left, isNot(0.0));
      expect(band.deviceRect.top, isNot(0.0));
      expect(frame.worldToScreenMatrix.e,
          isNot(closeTo(anchor.worldToScreenMatrix.e, 1e-9)),
          reason: 'the frame camera must differ from the anchor, or the '
              'anchor-versus-frame choice below is untestable');
      expect(frame.worldToScreenMatrix.f,
          isNot(closeTo(anchor.worldToScreenMatrix.f, 1e-9)));
    });

    test('the band camera puts a world point at the band-local pixel', () {
      // Not the origin and not a grid node: a point whose screen position is
      // fractional in both axes.
      final point = Vector2(123.5, 77.25);
      final painter = _RecordingPainter(rig.doc, rig.index);
      final visited = <int>[];

      final image = rig.cache.debugBakeBand(
          band, grid, frame, painter, rig.sink, null, Vector2.zero(), visited);
      addTearDown(image.dispose);

      expect(painter.paints, 1);
      final bandCamera = painter.seenCamera!;

      // The band's rectangle is in the grid's device space, so the reference
      // is where the *anchor* puts the point, not where this frame's camera
      // does. The two differ by the pan above, which is what makes this an
      // assertion rather than a tautology.
      final inAnchor = anchor.worldToScreen(point);
      final expected = Vector2(
        inAnchor.x - band.deviceRect.left / kTileDpr + pad,
        inAnchor.y - band.deviceRect.top / kTileDpr + pad,
      );
      final actual = bandCamera.worldToScreen(point);

      expect(actual.x, closeTo(expected.x, 1e-9));
      expect(actual.y, closeTo(expected.y, 1e-9));

      // The mutation this pins: reading the translation off the frame camera
      // instead of the anchor. It is a different number here by construction.
      final fromFrame = frame.worldToScreen(point);
      expect(
          actual.x,
          isNot(closeTo(
              fromFrame.x - band.deviceRect.left / kTileDpr + pad, 1e-6)),
          reason: 'the band camera must be anchored where the tile keys are');

      // Scale and skew are the generation's and are carried untouched.
      final a = anchor.worldToScreenMatrix;
      final b = bandCamera.worldToScreenMatrix;
      expect(b.a, a.a);
      expect(b.b, a.b);
      expect(b.c, a.c);
      expect(b.d, a.d);
    });

    test('the padded query reaches kTileSlack past the band on every side', () {
      final painter = _RecordingPainter(rig.doc, rig.index);
      final image = rig.cache.debugBakeBand(
          band, grid, frame, painter, rig.sink, null, Vector2.zero(), <int>[]);
      addTearDown(image.dispose);

      final width = band.deviceRect.width / kTileDpr;
      final height = band.deviceRect.height / kTileDpr;
      expect(width, greaterThan(0));
      expect(height, greaterThan(0));
      expect(painter.seenViewport, Size(width + 2 * pad, height + 2 * pad),
          reason: 'an unpadded query drops the half of a boundary stroke that '
              'belongs to the band, because its centreline is outside it');

      // The pad is only reach if the camera moves with it: a larger viewport
      // whose origin did not shift would query the same rectangle grown to
      // the right and down alone.
      final b = painter.seenCamera!.worldToScreenMatrix;
      final a = anchor.worldToScreenMatrix;
      expect(b.e, closeTo(a.e - band.deviceRect.left / kTileDpr + pad, 1e-9));
      expect(b.f, closeTo(a.f - band.deviceRect.top / kTileDpr + pad, 1e-9));

      // And the image is the band, not the padded query.
      expect(image.width, band.deviceRect.width.round());
      expect(image.height, band.deviceRect.height.round());
    });

    test('every band is rebased against the origin handed in', () {
      // Far from zero, so a band-derived origin could not coincide with it.
      final origin = Vector2(4500000.0, -3100000.0);
      final seen = <Vector2?>[];
      for (final each in [bands.first, bands[3], bands.last]) {
        final painter = _RecordingPainter(rig.doc, rig.index);
        final image = rig.cache.debugBakeBand(
            each, grid, frame, painter, rig.sink, null, origin, <int>[]);
        addTearDown(image.dispose);
        seen.add(painter.seenOrigin);
      }
      expect(seen, everyElement(same(origin)),
          reason: 'a per-band origin gives each band its own float32 residual '
              'and the rows disagree along their shared edge');
    });

    test('the walk reports the handles it touched into visitedInto', () {
      // The real painter here, not the recorder: this is the one claim that
      // needs the walk to actually happen.
      final visited = <int>[];
      final image = rig.cache.debugBakeBand(band, grid, frame, rig.painter,
          rig.sink, null, Vector2.zero(), visited);
      addTearDown(image.dispose);
      expect(visited, isNotEmpty);
      expect(
          visited.toSet().every((v) =>
              rig.doc.tree[Handle(v)] != null ||
              rig.doc.entities.slotOf(Handle(v)) != null),
          isTrue,
          reason: 'every recorded handle names something in the document');
    });
  });
}
