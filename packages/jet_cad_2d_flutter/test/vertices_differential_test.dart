// `VerticesDrawSink` against the reference walk.
//
// The op-stream comparison in `differential_test.dart` cannot reach this sink:
// it emits triangles, not ops. The comparison moves down a level instead —
// the reference walk says where ink belongs, the sink says where its triangles
// are, and the two are joined by point-in-triangle. See
// `support/vertices_differential.dart` for why that is a differential test and
// not a re-implementation.

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/fixtures.dart';
import 'support/vertices_differential.dart';

void main() {
  test('the sink inks every primitive the reference walk draws', () {
    // The reference traverses the tree with no index and no culling, composing
    // transforms by a different route than the painter. Running the samples
    // off *its* op stream rather than the painter's means a wrong cull, a
    // wrong merge order or a wrong transform composition all show up as
    // missing ink.
    final doc = differentialFixture();
    assertNoIdentityTransforms(doc);
    final camera = ViewportTransform.fit(doc.extents, kViewport);

    expectInkCovers(paintToVertices(doc, camera),
        inkSamples(referenceToRecording(doc, camera)));
  });

  test('the same holds at 4.5e6 with the view over one nested instance', () {
    // Far from the origin and under a tight camera: the rebase is doing real
    // work here, and a residual applied twice lands the ink somewhere else
    // entirely.
    final doc = differentialFixture(originX: 4.5e6);
    assertNoIdentityTransforms(doc);
    final camera = cameraOverNestedInstance(doc);

    expectInkCovers(paintToVertices(doc, camera),
        inkSamples(referenceToRecording(doc, camera)));
  });

  test('the sink inks nothing the painter did not ask for', () {
    // The other direction, and against the *painter's* ops rather than the
    // reference's: the painter is a superset of the reference by design, so
    // reference ops cannot bound what the sink is allowed to draw. What the
    // painter handed the sink can.
    final doc = differentialFixture();
    final camera = ViewportTransform.fit(doc.extents, kViewport);
    final ops = paintToRecording(doc, camera);

    expectNoStrayInk(paintToVertices(doc, camera), inkSamples(ops),
        // Half a sample spacing to reach the primitive between two samples,
        // plus the widest stroke's own half-width to reach its edge from the
        // centreline, plus the chord sag of the coarsest curve.
        slackPx: kSampleSpacingPx / 2 +
            widestHalfStroke(ops) +
            VerticesDrawSink.kFlattenTolerance);
  });

  test('the comparison is not vacuous', () {
    // A coverage assertion passes trivially against an empty sample set, and a
    // stray-ink assertion passes trivially against an empty sink. Both sides
    // are pinned here so neither can go quiet without a test going red.
    final doc = differentialFixture();
    final camera = ViewportTransform.fit(doc.extents, kViewport);
    final samples = inkSamples(referenceToRecording(doc, camera));
    final sink = paintToVertices(doc, camera);

    expect(samples.length, greaterThan(500));
    expect(samples.map((s) => s.from).toSet(),
        containsAll(<String>['polyline', 'circle', 'arc', 'point']));
    expect(samples.map((s) => s.rgb).toSet().length, greaterThan(1),
        reason: 'one colour everywhere would make the colour half of the '
            'coverage check vacuous');
    expect(sink.batchedSegmentCount, greaterThan(50));
  });
}
