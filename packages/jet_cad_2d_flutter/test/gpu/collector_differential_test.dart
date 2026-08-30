import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_flutter/src/gpu/geometry_collector.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

import '../support/fixtures.dart';

const double _devicePixelRatio = 2.0;

/// Tighter than any of the mutations below by orders of magnitude, but far
/// looser than the two arms' honest disagreement: the collector stores
/// `float32` (about 1.2e-7 relative precision) while the reference sink
/// works in `double`, and the largest coordinate this fixture produces is a
/// few hundred device pixels, so float32 rounding alone is on the order of
/// 1e-4 at most. A transposed residual, a dropped `x dpr` factor or a
/// reordered buffer each move a value by whole units or more, so 1e-3 catches
/// every one of them while never tripping on rounding.
const double _tolerance = 1e-3;

void main() {
  test(
      'emits every polyline segment the painter walks, in the same order, '
      'with the residual applied and half-width scaled by dpr', () {
    // `differentialFixture` is this suite's standing corpus, not a fixture
    // built for this test alone: two placements of the same "outer"
    // definition (instance 820, non-uniformly scaled `scale(1.6, 1.1)`, and
    // instance 830, mirrored but conformal `scale(-1.3, 1.3)` -- see
    // `fixtures.dart:126-128`'s own "still conformal: anisotropyRatio 1").
    // Both placements carry a nested instance of "inner" two levels deep
    // (node 520 lives inside definition "outer", so it is placed once per
    // placement of "outer" -- `fixtures.dart:86-96`), plus a root line and a
    // grouped line. No transform anywhere in it is the identity --
    // `assertNoIdentityTransforms`
    // pins that below, which is the guard this project's post-mortem asked
    // for after four fixtures hid a composition-order defect behind
    // transforms that happened to commute.
    //
    // A single-entity fixture cannot show an ordering defect at all: with
    // only one leaf there is only one possible position for its segment in
    // the buffer. This one has two placements of "outer" (each contributing
    // a polyline leaf) interleaved with a nested instance and group leaves,
    // so walk order is a real constraint here -- sorting the buffer by
    // coordinate, or emitting handles in ascending order instead of walk
    // order, produces a different sequence than the one asserted below.
    final doc = differentialFixture();
    assertNoIdentityTransforms(doc);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final resolver = DocumentStyleResolver(doc);
    final camera = ViewportTransform.fit(doc.extents, kViewport);
    final painter =
        DraftPainter(document: doc, index: index, resolver: resolver);

    // The reference: what the painter emits, recorded.
    final recording = RecordingDrawSink();
    painter.paint(recording, camera, kViewport);

    // The arm: what the collector writes, from the same painter replaying
    // the same camera over the same document.
    final collector = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm,
        devicePixelRatio: _devicePixelRatio);
    painter.paint(collector, camera, kViewport);

    // Rebuild the expected segment list from the recording, applying the
    // residual exactly as the collector must, and keeping each segment's
    // style alongside it so the half-width and colour checks below are
    // per-segment.
    // **What this residual actually is, in the real walk.** Every
    // `beginResidual` a `PolylineOp` sees here carries a *pure translation*:
    // `DraftPainter._emitScreenSpace` folds the full affine chain into the
    // points themselves and leaves only the screen-origin rebase as the
    // residual (`draft_painter.dart`, and its own comment that the general
    // `_emit` polyline path is dead). So this loop's generic
    // `a/b/c/d/e/f` application is honest, but a mutation that swaps the
    // residual's off-diagonal terms (b <-> c) cannot be observed through
    // *this* walk -- b and c are always 0 here, by construction, on every
    // fixture. That mutation is covered instead by
    // `geometry_collector_test.dart`'s "applies the residual, and a
    // transposed one is not the same residual", which drives
    // `GeometryCollector.polyline` directly with a genuine off-diagonal
    // residual. See Task 8's report for the transcript proving that.
    final expectedPoints = <List<double>>[];
    final expectedStyles = <ResolvedStyle>[];
    Transform2 residual = Transform2.identity();
    for (final op in recording.ops) {
      if (op is BeginResidualOp) residual = op.residual;
      if (op is PolylineOp) {
        final t = residual;
        // `PolylineOp.points` is already trimmed to the drawn point count
        // (`draw_sink.dart`'s own doc comment) -- there is no separate
        // `count` field on the op, unlike the brief's sample code assumed.
        final pts = op.points;
        final count = pts.length ~/ 2;
        var px = t.a * pts[0] + t.c * pts[1] + t.e;
        var py = t.b * pts[0] + t.d * pts[1] + t.f;
        for (var i = 1; i < count; i++) {
          final qx = t.a * pts[i * 2] + t.c * pts[i * 2 + 1] + t.e;
          final qy = t.b * pts[i * 2] + t.d * pts[i * 2 + 1] + t.f;
          if (px != qx || py != qy) {
            expectedPoints.add([px, py, qx, qy]);
            expectedStyles.add(op.style);
          }
          px = qx;
          py = qy;
        }
        // `differentialFixture` never sets `closed: true` --
        // `draft_painter.dart`'s own `_emitScreenSpace` comment says the
        // model carries no closed-polyline flag yet, so every `PolylineOp`
        // in this walk has `closed == false` and this branch never runs on
        // this fixture. It mirrors `GeometryCollector.polyline`'s own
        // closing-segment emission anyway, so this builder does not start
        // silently under-counting the day a closed flag exists.
        if (op.closed && count > 1) {
          final fx = t.a * pts[0] + t.c * pts[1] + t.e;
          final fy = t.b * pts[0] + t.d * pts[1] + t.f;
          if (px != fx || py != fy) {
            expectedPoints.add([px, py, fx, fy]);
            expectedStyles.add(op.style);
          }
        }
      }
    }

    expect(expectedPoints, isNotEmpty,
        reason: 'a fixture with no polylines would make this test vacuous');
    expect(collector.instanceCount, expectedPoints.length,
        reason: 'the collector must emit exactly one instance per segment '
            'the walk produced -- neither dropping nor duplicating one');

    // Captured once: `collector.data` copies `_buffer` on every access, so
    // the comparison loop below reads a single snapshot rather than a fresh
    // sublist per index.
    final data = collector.data;

    for (var i = 0; i < expectedPoints.length; i++) {
      final o = i * kFloatsPerInstance;
      final style = expectedStyles[i];

      // -- kind: every record this task's collector writes is a stroke.
      expect(data[o], kKindStroke,
          reason: 'instance $i must tag itself a stroke');

      // -- walk order & the residual -----------------------------------
      expect(data[o + 1], closeTo(expectedPoints[i][0], _tolerance),
          reason: 'instance $i x0 must be the walk\'s $i-th segment start');
      expect(data[o + 2], closeTo(expectedPoints[i][1], _tolerance),
          reason: 'instance $i y0 must be the walk\'s $i-th segment start');
      expect(data[o + 3], closeTo(expectedPoints[i][2], _tolerance),
          reason: 'instance $i x1 must be the walk\'s $i-th segment end');
      expect(data[o + 4], closeTo(expectedPoints[i][3], _tolerance),
          reason: 'instance $i y1 must be the walk\'s $i-th segment end');

      // -- half-width: the collector stores DEVICE pixels, the reference
      // sink's own formula (`VerticesDrawSink._halfWidthFor`) stores LOGICAL
      // pixels. They must differ by exactly `devicePixelRatio` -- this is
      // not a bug being tolerated, it is the fact this test pins (see the
      // module doc on `GeometryCollector._halfWidthFor`).
      final sinkHalf = _referenceLogicalHalfWidth(style.lineweightHundredths);
      expect(data[o + 5], closeTo(sinkHalf * _devicePixelRatio, _tolerance),
          reason: 'instance $i half-width must be the reference sink\'s '
              'logical half-width scaled by devicePixelRatio, not the raw '
              'logical value copied straight across');

      // -- colour: every entity in `differentialFixture` carries the
      // default lineweight (25 hundredths-of-a-mm), which at
      // `kLogicalPixelsPerMm` and dpr 2 computes to a device width above
      // `VerticesDrawSink.kMinStrokeDevicePixels` -- so `_coveredArgb` is a
      // no-op on every one of these segments and the reference colour is
      // `style.argb` unmodified. That is why this fixture's colour
      // comparison is meaningful without the collector implementing
      // `_coveredArgb` itself: hairline fading is Plan B's job
      // (`geometry_collector.dart`'s module doc), and folding it in here
      // would smuggle that work into the wrong layer just to pass a test.
      final argb = style.argb;
      expect(data[o + 6], closeTo(((argb >> 16) & 0xFF) / 255.0, _tolerance),
          reason: 'instance $i red channel');
      expect(data[o + 7], closeTo(((argb >> 8) & 0xFF) / 255.0, _tolerance),
          reason: 'instance $i green channel');
      expect(data[o + 8], closeTo((argb & 0xFF) / 255.0, _tolerance),
          reason: 'instance $i blue channel');
      expect(data[o + 9], closeTo(((argb >> 24) & 0xFF) / 255.0, _tolerance),
          reason: 'instance $i alpha channel');
    }
  });
}

/// `VerticesDrawSink._halfWidthFor`, reproduced here because that method is
/// private to its own file. Computes the half-width **in logical pixels** --
/// the reference sink's own space, per its `floorLogical` naming
/// (`vertices_draw_sink.dart:544-552`) -- so the test above can assert the
/// `x devicePixelRatio` relationship explicitly instead of checking the
/// collector against a copy of its own formula.
double _referenceLogicalHalfWidth(int lineweightHundredths) {
  const pixelsPerPaperMm = kLogicalPixelsPerMm;
  // The reference sink's own floor, not a third copy of it: the collector's
  // module doc (`geometry_collector.dart:31-35`) claims raising either
  // constant out of step with the other turns this test red, and that claim
  // is only true if this side reads the sink's live constant rather than
  // hardcoding its current value.
  final logical = lineweightHundredths / 100.0 * pixelsPerPaperMm;
  final floorLogical =
      VerticesDrawSink.kMinStrokeDevicePixels / _devicePixelRatio;
  final w = logical.isFinite && logical > floorLogical ? logical : floorLogical;
  return w / 2;
}
