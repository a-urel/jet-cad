import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'fixtures.dart';

void main() {
  test(
      'shadedDashFixture is not degenerate in any of the four ways that '
      'would make a dash test pass vacuously', () {
    final doc = shadedDashFixture();

    // 1. globalLinetypeScale is a real multiplicand.
    expect(doc.header.globalLinetypeScale, isNot(1.0));

    // 2. Every placement is non-uniform and rotated.
    for (final handle in const [Handle(991)]) {
      final node = doc.tree[handle];
      expect(node, isNotNull, reason: 'fixture node $handle went missing');
      final t = node!.transform;
      expect(t.a * t.d - t.b * t.c, isNot(0.0),
          reason: 'degenerate (singular) transform');
      expect((t.a.abs() - t.d.abs()).abs(), greaterThan(0.05),
          reason: 'a uniform scale cannot distinguish Ruling C4 divergence '
              'from agreement');
      expect(t.b, isNot(0.0), reason: 'unrotated');
    }

    // 3. The pattern repeats. Painted at the test camera, entity 910 -- the
    //    dashed polyline -- must be at least four periods of DASHED long,
    //    measured exactly as the painter itself computes it (through a
    //    shading sink), not derived independently.
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final camera = ViewportTransform.fit(doc.extents, kViewport);
    final sink = RecordingDrawSink(shadesDashes: true);
    DraftPainter(
            document: doc, index: index, resolver: DocumentStyleResolver(doc))
        .paint(sink, camera, kViewport);

    final residualStart = sink.ops.indexWhere(
        (op) => op is BeginResidualOp && op.debugHandle == const Handle(910));
    expect(residualStart, greaterThanOrEqualTo(0),
        reason: 'entity 910 never reached the sink');
    final residualEnd =
        sink.ops.indexWhere((op) => op is EndResidualOp, residualStart);
    expect(residualEnd, greaterThan(residualStart));
    final bracket = sink.ops.sublist(residualStart, residualEnd + 1);

    final begin = bracket.whereType<BeginDashOp>().single;
    final line = bracket.whereType<PolylineOp>().single;

    // Path length along the polyline, in the screen-space units the points
    // are already in (the painter carries points into screen space before
    // this bracket for a line-like leaf) -- not the straight-line distance
    // from first to last point, which would skip the corners entirely.
    var screenLength = 0.0;
    for (var i = 0; i + 3 < line.points.length; i += 2) {
      final dx = line.points[i + 2] - line.points[i];
      final dy = line.points[i + 3] - line.points[i + 1];
      screenLength += math.sqrt(dx * dx + dy * dy);
    }
    final cycle =
        begin.pattern.dashes.fold<double>(0, (sum, d) => sum + d.abs());
    final repeats = screenLength / (cycle * begin.patternToLocal);
    expect(repeats, greaterThan(4.0),
        reason: 'a fixture where the pattern fits once never exercises the '
            "fragment stage's fract past its first cycle");

    // 4. The three patterns have three different drawn-element counts --
    //    the count of positive (drawn) entries in each registered pattern.
    int drawnElements(Handle linetype) =>
        doc.tables.linetypes[linetype]!.pattern.dashes
            .where((d) => d > 0)
            .length;
    expect(<int>{
      drawnElements(const Handle(900)),
      drawnElements(const Handle(901)),
      drawnElements(const Handle(902)),
    }, <int>{
      1,
      2,
      0
    });

    // 5. entity 913's own linetypeScale is a real multiplicand, not left at
    //    the identity -- the same shape of check as (1), for the per-entity
    //    factor `_dashScale` folds in beside `globalLinetypeScale`. The
    //    default-constructed fixture above cannot exercise this by itself
    //    ([linetypeScale] defaults to 1.0), so a second fixture pins it.
    final scaled = shadedDashFixture(linetypeScale: 2.5);
    final slot = scaled.entities.slotOf(const Handle(913));
    expect(slot, isNotNull, reason: 'entity 913 went missing');
    expect(scaled.entities.read(slot!).linetypeScale, isNot(1.0));
  });
}
