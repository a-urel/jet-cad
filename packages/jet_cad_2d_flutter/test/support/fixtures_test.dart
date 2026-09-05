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

  group('fillFixture', () {
    test('is not degenerate in any of the four ways that would hide a defect',
        () {
      final doc = fillFixture();

      // 1. A fill exists and is indexed, so the painter can reach it, and
      //    its boundary's triangulation was actually materialised --
      //    `AddRegionCommand.apply` writes it, not this fixture.
      final fillSlot = doc.entities.slotOf(const Handle(901))!;
      expect(doc.entities.kindAt(fillSlot), EntityKind.fill);
      expect(doc.fills.trianglesFor(const Handle(902)), isNotNull,
          reason: 'an unfillable boundary is skipped by the painter and the '
              'corpus would silently draw no fill at all');

      // 2. Strokes on BOTH sides of the fill in handle order. Without the
      //    higher one, permuting the buffer changes no pixel and the
      //    criterion-4 test in Task 7 passes vacuously.
      expect(const Handle(900).value, lessThan(const Handle(901).value));
      expect(const Handle(903).value, greaterThan(const Handle(901).value));

      // 3. The translucent fill is actually translucent -- neither opaque
      //    nor invisible.
      final translucentSlot = doc.entities.slotOf(const Handle(904))!;
      final translucent = doc.entities.transparencyAt(translucentSlot);
      expect(translucent, greaterThan(0));
      expect(translucent, lessThan(255));

      // 4. No identity transform: the fill sits under a rotated, non-uniform
      //    instance well away from the origin. An axis-aligned fill at the
      //    origin hides a transposed matrix element -- Plan 2's post-mortem.
      final node = doc.tree[const Handle(910)]! as InstanceNode;
      expect(node.transform.a, isNot(closeTo(node.transform.d, 1e-9)));
      expect(node.transform.b, isNot(0.0));
      expect(node.transform.e.abs(), greaterThan(1.0));
    });

    test('the fill and the higher-handle stroke actually overlap on screen',
        () {
      // A corpus whose "overlapping" shapes miss each other proves nothing.
      // Painted through the reference sink, the stroke's ink must land
      // inside the fill's bounding box.
      final doc = fillFixture();
      final fillBox = doc.extents;
      expect(fillBox.min.x, lessThan(fillBox.max.x));
      final overlap = strokeInkInsideFill(doc);
      expect(overlap, greaterThan(200),
          reason: 'fewer than 200 shared device pixels and the order gate '
              'cannot see a permutation');
    });
  });

  group('textOverlapFixture', () {
    late DraftDocument doc;
    setUp(() => doc = textOverlapFixture(FlutterTextMeasurer()));

    test('has the handles the table names, and the strokes are thick', () {
      for (final h in [900, 901, 903, 904, 905, 910, 911, 921, 922, 931]) {
        expect(doc.entities.slotOf(Handle(h)), isNotNull, reason: 'handle $h');
      }
      int lineweightOf(int h) =>
          doc.entities.lineweightAt(doc.entities.slotOf(Handle(h))!);
      expect(lineweightOf(903), 120);
      expect(lineweightOf(922), 400);
    });

    test('the placement is mirrored, rotated and non-uniform', () {
      // `DocumentTree.operator []` is the lookup by handle (`tree.dart:12`).
      final t = (doc.tree[const Handle(990)]! as InstanceNode).transform;
      expect(t.determinant, lessThan(0), reason: 'mirrored');
      expect(t.b, isNot(0.0), reason: 'rotated');
      expect(t.anisotropyRatio, isNot(closeTo(1.0, 1e-6)),
          reason: 'non-uniform');
    });

    test('stroke 903 actually crosses label 901 at the fitted camera',
        () async {
      // The overlap is measured, not assumed: the label alone is painted
      // through the reference and its ink read back; then the stroke alone;
      // the two must share at least 200 device pixels. `strokeInkInsideLabel`
      // is the same instrument Task 5's gate reads.
      expect(
          await strokeInkInsideLabel(doc, const Handle(903), const Handle(901)),
          greaterThan(200));
      expect(
          await strokeInkInsideLabel(doc, const Handle(900), const Handle(901)),
          greaterThan(200));
    });

    test("stroke 922's centerline misses label 921 but its width reaches it",
        () async {
      expect(
          await strokeInkInsideLabel(doc, const Handle(922), const Handle(921)),
          greaterThan(50));
      // The same corpus rebuilt with 922 at hairline width: there is no
      // modify-lineweight command in this package, so the fixture takes the
      // lineweight as a parameter and the test builds it twice.
      final hairline =
          textOverlapFixture(FlutterTextMeasurer(), grazeLineweight: 1);
      expect(
          await strokeInkInsideLabel(
              hairline, const Handle(922), const Handle(921)),
          0,
          reason: 'at hairline width the same centerline touches no glyph');
    });
  });
}
