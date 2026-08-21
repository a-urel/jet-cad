// The test that earns the two-backend decision. See `support/sink_comparison.dart`
// for what "agree" means here and for why neither sink is driven through a
// widget.
//
// Numbers below are measurements of record, taken 2026-08-21 on this binding
// (`devicePixelRatio` 3.0, so a 1200x900 device-pixel surface). They are here
// so a later change that halves the ink is visible as a number and not only as
// a pass.

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'support/sink_comparison.dart';

void main() {
  testWidgets('the two backends draw the same drawing', (tester) async {
    // Every primitive the painter emits, under a rotated and non-uniformly
    // scaled residual, at an oblique corner, at a corner past the miter limit,
    // and around a text op that forces a mid-frame flush. The fixture that
    // would be degenerate is the one at the identity, and this repository
    // names that as its dominant failure mode.
    //
    // 2026-08-21: canvas 22398 ink pixels, vertices 23241, disagreement 0/0.
    final doc = comparisonFixture();
    assertNoIdentityTransforms(doc);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final report = await expectSinksAgree(tester, doc, paintDrawing(doc, index),
        textMask: comparisonTextMask(doc));
    expect(report.canvasInkPixels, greaterThan(15000));
    expect(report.verticesInkPixels, greaterThan(15000));
    // The half the pixels cannot check. The fixture's one text entity sits
    // between two groups of stroke geometry, so the sink batches, flushes in
    // front of the paragraph, batches again and flushes at the end: two
    // `drawVertices` calls, not one. One would mean the strokes after the
    // text had drawn before it.
    expect(report.verticesFlushCount, 2,
        reason: 'text must force a mid-frame flush with real batched work on '
            'both sides of it');
  });

  testWidgets('the two backends agree on the ops the painter cannot emit',
      (tester) async {
    // A closed run and a point under a rotated residual. `DraftPainter` can
    // produce neither (see `comparisonDirectOps`), and between them they are
    // the only thing in this file that catches three of the four mutants Task
    // 11 ran -- the seam join, the bevel triangle and Task 6's point shape.
    //
    // 2026-08-21: canvas 18291 ink pixels, vertices 18906, disagreement 0/0.
    final doc = DraftDocument.empty();
    final report = await expectSinksAgree(tester, doc, comparisonDirectOps);
    expect(report.canvasInkPixels, greaterThan(12000));
    expect(report.verticesInkPixels, greaterThan(12000));
    // No text here, so nothing is unbatchable and the whole drawing goes out
    // in the one flush at the end.
    expect(report.verticesFlushCount, 1);
  });

  testWidgets('anisotropic stroke width diverges, and vertices is right',
      (tester) async {
    // **Row 1 of the design document's permitted-divergence table**, admitted
    // by name rather than swallowed by a tolerance.
    //
    // `CanvasDrawSink._widthFor` divides the device width by
    // `residual.scaleMagnitude` -- `sqrt(|det|)`, one scalar standing in for
    // two axis scales -- and then lets the residual scale the result, so its
    // apparent width runs from `W / sqrt(3)` to `W * sqrt(3)` around this
    // ellipse. `VerticesDrawSink` takes the perpendicular after transforming
    // the endpoints, so it draws `W` everywhere. The vertices sink is the one
    // that is right.
    //
    // 2026-08-21 at `scaleY` 3.0: canvas 19194 ink pixels, vertices 24580,
    // 3513 stray and 897 uncovered. Looked at: the canvas stroke is visibly
    // fatter at the two ends of the ellipse's major axis and visibly thinner
    // along its flanks, while the vertices stroke is even all the way round.
    final doc = anisotropyDivergenceFixture(scaleY: 3.0);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final report =
        await measureAgreement(tester, doc, paintDrawing(doc, index));
    // `measureAgreement` has no ink floors of its own -- `expectSinksAgree`
    // owns those, and this test does not go through it. Without them a sink
    // that drew nothing would satisfy every "greaterThan" below by having
    // nothing to disagree with. 2026-08-21: 19194 and 24580.
    expect(report.canvasInkPixels, greaterThan(10000));
    expect(report.verticesInkPixels, greaterThan(10000));
    expect(report.strayVerticesPixels, greaterThan(1000),
        reason: 'the vertices sink should be wider than the canvas one along '
            'the flanks, where the canvas divides by sqrt(3)');
    expect(report.uncoveredCanvasPixels, greaterThan(200),
        reason: 'and narrower at the ends of the major axis, where the '
            'canvas multiplies by sqrt(3)');
    // Both directions, which is what says this is a *width* divergence and
    // not the ellipse being in the wrong place.
    expect(report.verticesInkPixels, greaterThan(report.canvasInkPixels));
  });

  testWidgets('a sub-pixel stroke is where the two backends stop agreeing',
      (tester) async {
    // **Row 4**, "sub-pixel strokes: vertices, but untestable by comparison".
    // Nothing else in this repository reaches below the floor -- the ladders
    // sit at 0.34 logical pixels against a 0.33 floor, dash at 1.13,
    // stroke_width at 4.0 -- so this is the only place the row is exercised
    // at all, and it is exercised by measuring the divergence rather than by
    // asserting agreement.
    //
    // `VerticesDrawSink._halfWidthFor` clamps to one device pixel and
    // `_coveredArgb` fades the alpha in proportion; `CanvasDrawSink` has
    // neither rule and no `devicePixelRatio` field to write one against, so
    // software Skia just draws a fainter, thinner line. At lineweight 1 the
    // stroke is 0.11 device pixels and every canvas pixel it produces is
    // below `kInkAlphaFloor`.
    //
    // 2026-08-21: canvas 0 ink pixels, vertices 1140, all 1140 stray. Looked
    // at: the vertices sink draws a clean one-device-pixel line and the
    // canvas image is blank at the ink floor.
    final doc = subPixelDivergenceFixture(lineweight: 1);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final report =
        await measureAgreement(tester, doc, paintDrawing(doc, index));
    expect(report.canvasInkPixels, 0,
        reason: 'the canvas backend has no stroke floor, so a 0.11 '
            'device-pixel line never reaches the ink alpha floor');
    expect(report.verticesInkPixels, greaterThan(500),
        reason: 'the vertices backend clamps the width to one device pixel');
    expect(report.strayVerticesPixels, report.verticesInkPixels,
        reason: 'every vertices pixel is stray, because the canvas side of '
            'this fixture is empty');
  });

  testWidgets('a full-sweep ARC leaves an unjoined seam. This is a defect',
      (tester) async {
    // **Not on the permitted-divergence list**, and therefore a defect in
    // Task 5 rather than in this comparison. `closed` is decided
    // structurally -- `VerticesDrawSink.circle` passes `true` and `arc`
    // passes `false`, with no tolerance anywhere -- so an arc payload whose
    // third scalar is `2 * pi` draws a full circle with no seam join, where
    // `Canvas.drawArc` closes the loop.
    //
    // **Can the corpus produce one?** No. `generate_document.dart` draws arc
    // sweeps from `(0.25 + rand * 1.5) * pi` at the root and
    // `(0.5 + rand) * pi` inside definitions, both strictly below `2 * pi`,
    // and there is no DXF reader in this repository at all
    // (`packages/jet_cad_2d/lib/src/codec/` holds `json_codec.dart` and
    // `schema_version.dart`). What would have to change for it to: a DXF
    // reader that maps an `ARC` with equal start and end angles onto a
    // `2 * pi` sweep, or any corpus change that widens that range. Nothing
    // between `AddEntityCommand` and `sink.arc` validates or normalises the
    // scalar, so the value reaches the sink untouched once it exists.
    //
    // It is pinned here rather than left as prose because it is invisible at
    // any ordinary lineweight: the seam notch is `half * sqrt(2 / R)` device
    // pixels wide at the flattening tolerance, which is under the one-pixel
    // dilation unless the stroke is a large fraction of the radius. A 2*pi
    // arc through the painter at a realistic size measured 0 stray and 0
    // uncovered on 2026-08-21 -- the divergence was there and the comparison
    // could not see it. This fixture is a 36-device-pixel radius stroked 25
    // device pixels wide, where it can.
    //
    // 2026-08-21: canvas 5688 ink pixels, vertices 5710, 0 stray and 6
    // uncovered. Looked at: one radial red notch at the 3 o'clock seam, the
    // start angle, and nothing anywhere else on the ring.
    //
    // **When Task 5's `closed` decision learns about a full sweep, this test
    // goes red and the right fix is to change these two expectations to
    // zero**, not to delete the fixture.
    final doc = DraftDocument.empty();
    final report = await measureAgreement(tester, doc, fullSweepArcDrawing);
    // Floors first, and they are not decoration. This test does not go
    // through `expectSinksAgree`, so it inherits none of its ink floors, and
    // a `greaterThan(0)` on missing ink is exactly the assertion an empty
    // vertices side satisfies best. Task 11's review made `arc` return early
    // for `sweep > 6.0` -- the vertices backend then drew *nothing* for this
    // fixture -- and every test in this file still passed. 2026-08-21 the ring
    // measures 5688 and 5710 ink pixels, so 4000 is clear of an empty side by
    // a wide margin and clear of the real number by a wider one.
    expect(report.canvasInkPixels, greaterThan(4000),
        reason: 'the canvas backend must have drawn the whole ring');
    expect(report.verticesInkPixels, greaterThan(4000),
        reason: 'the vertices backend must have drawn the whole ring, not '
            'skipped the op and left a notch-shaped hole the size of it');
    // And an upper bound, so "unjoined seam" cannot quietly become "half the
    // ring missing" and still read as this known defect. The notch measured 6
    // pixels.
    expect(report.uncoveredCanvasPixels, lessThan(50),
        reason: 'one seam notch, not a missing arc');
    expect(report.uncoveredCanvasPixels, greaterThan(0),
        reason: 'the seam of a 2*pi ARC is unjoined on the vertices backend');
    expect(report.strayVerticesPixels, 0,
        reason: 'the notch is missing ink, never invented ink');
  });
}
