import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/differential.dart';
import 'support/fixtures.dart';

void main() {
  test('the painter draws a superset of the reference walk, in order', () {
    // The reference traverses the tree directly with no index and no culling,
    // accumulating transforms by a different route than the painter. One
    // comparison therefore covers wrong culling, wrong merge order and wrong
    // transform composition at once.
    final doc = differentialFixture();
    assertNoIdentityTransforms(doc);
    final camera = ViewportTransform.fit(doc.extents, kViewport);

    expectPainterSupersetOfReference(paintToRecording(doc, camera),
        referenceToRecording(doc, camera), kViewport);
  });

  test('the same holds at 4.5e6 with the view over one nested instance', () {
    final doc = differentialFixture(originX: 4.5e6);
    assertNoIdentityTransforms(doc);
    final camera = cameraOverNestedInstance(doc);

    expectPainterSupersetOfReference(paintToRecording(doc, camera),
        referenceToRecording(doc, camera), kViewport);
  });

  test('the reference draws something, so the comparison is not vacuous', () {
    // A superset assertion passes trivially against an empty reference. This
    // is the guard that the fixture and the walk both actually work.
    final doc = differentialFixture();
    final ops = referenceToRecording(doc);
    expect(ops.whereType<PolylineOp>().length, greaterThanOrEqualTo(6));
    expect(ops.whereType<CircleOp>(), isNotEmpty);
    expect(ops.whereType<ArcOp>(), isNotEmpty);
    expect(ops.whereType<PointOp>(), isNotEmpty);
  });

  test('the differential fixture is entirely continuous', () {
    // The reference walk does not dash. If a fixture entity ever carries a
    // pattern, the painter emits spans where the reference emits one polyline
    // and the superset assertion fails for a reason that has nothing to do
    // with the walk. Dashing is covered by the dasher's own tests and by the
    // goldens, not here.
    final doc = differentialFixture();
    final resolver = DocumentStyleResolver(doc);
    for (final slot in doc.entities.liveSlots) {
      final style = resolver.styleFor(slot, StyleContext.documentRoot);
      final pattern = doc.tables.linetypes[style.linetype]?.pattern;
      expect(pattern?.dashes ?? const <double>[], isEmpty);
    }
  });

  test('the reference uses no spatial index at all', () {
    // Independence is the whole value of the oracle: two implementations that
    // share a mistake agree. The walk must run on a document that has no index
    // built over it.
    final doc = differentialFixture();
    final sink = RecordingDrawSink();
    referenceWalk(doc, sink, ViewportTransform.fit(doc.extents, kViewport),
        kViewport, DocumentStyleResolver(doc));
    expect(sink.ops, isNotEmpty);
  });

  test('the painter and the reference agree on the nested instance colour', () {
    // The definition body authored ByBlock resolves against the instance that
    // places it, through two levels. If the two walks threaded context
    // differently the styles would differ and every op would fail to match —
    // this names the failure instead of leaving it to the superset assertion.
    final doc = differentialFixture();
    final camera = ViewportTransform.fit(doc.extents, kViewport);
    final painted = flatten(paintToRecording(doc, camera));
    final reference = flatten(referenceToRecording(doc, camera));

    expect(
        painted.map((d) => d.style.argb).toSet()..removeWhere((argb) => false),
        containsAll(reference.map((d) => d.style.argb).toSet()));
  });

  group('the oracle catches a broken painter', () {
    // A differential test is only worth its runtime if it fails when the thing
    // under test is wrong. These feed the comparison a deliberately damaged op
    // list rather than damaging the painter, which is the same check without
    // an edit-and-revert cycle.
    late List<DrawOp> painted;
    late List<DrawOp> reference;

    setUp(() {
      final doc = differentialFixture();
      final camera = ViewportTransform.fit(doc.extents, kViewport);
      painted = paintToRecording(doc, camera);
      reference = referenceToRecording(doc, camera);
    });

    test('a dropped op fails', () {
      final damaged = List<DrawOp>.from(painted)
        ..removeAt(painted.indexWhere((op) => op is PolylineOp));
      expect(
          () => expectPainterSupersetOfReference(damaged, reference, kViewport),
          throwsA(isA<TestFailure>()));
    });

    test('a reordered pair fails', () {
      final geometry = <int>[
        for (var i = 0; i < painted.length; i++)
          if (painted[i] is! BeginResidualOp && painted[i] is! EndResidualOp) i
      ];
      final damaged = List<DrawOp>.from(painted);
      final a = geometry.first, b = geometry.last;
      final tmp = damaged[a];
      damaged[a] = damaged[b];
      damaged[b] = tmp;
      expect(
          () => expectPainterSupersetOfReference(damaged, reference, kViewport),
          throwsA(isA<TestFailure>()));
    });

    test('a shifted residual fails', () {
      // Half a pixel: far below anything a screenshot would show, far above
      // the 1e-6 the comparison allows for arithmetic noise.
      final damaged = [
        for (final op in painted)
          if (op is BeginResidualOp)
            BeginResidualOp(Transform2(
                op.residual.a,
                op.residual.b,
                op.residual.c,
                op.residual.d,
                op.residual.e + 0.5,
                op.residual.f))
          else
            op
      ];
      expect(
          () => expectPainterSupersetOfReference(damaged, reference, kViewport),
          throwsA(isA<TestFailure>()));
    });

    test('noise below the tolerance does not fail', () {
      final jittered = [
        for (final op in painted)
          if (op is BeginResidualOp)
            BeginResidualOp(Transform2(
                op.residual.a,
                op.residual.b,
                op.residual.c,
                op.residual.d,
                op.residual.e + 1e-9,
                op.residual.f))
          else
            op
      ];
      expectPainterSupersetOfReference(jittered, reference, kViewport);
    });
  });
}
