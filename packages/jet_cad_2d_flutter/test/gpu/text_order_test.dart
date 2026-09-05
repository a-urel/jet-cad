import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/fixtures.dart';
import '../support/gpu_comparison.dart';

const Size _size = Size(800, 600);
const double _dpr = 1.0;
const double _ppmm = 3.78;

/// The camera the buffer is collected at, and the four live cameras the
/// gate runs at: the band's floor, two interior points, and the ceiling.
/// The floor is where the reach expansion is load-bearing.
ViewportTransform _fit(DraftDocument doc) =>
    ViewportTransform.fit(doc.extents, _size);

ViewportTransform _scaled(ViewportTransform base, double s) {
  final centre = Offset(_size.width / 2, _size.height / 2);
  final m = Transform2.translation(centre.dx, centre.dy)
      .multiply(Transform2.scale(s, s))
      .multiply(Transform2.translation(-centre.dx, -centre.dy))
      .multiply(base.worldToScreenMatrix);
  return ViewportTransform(worldToScreenMatrix: m);
}

void main() {
  late FlutterTextMeasurer measurer;
  late DraftDocument doc;
  setUp(() {
    measurer = FlutterTextMeasurer();
    doc = textOverlapFixture(measurer);
  });

  for (final s in const [0.5, 0.8, 1.25, 2.0]) {
    test('the composited picture matches the reference at scale $s', () async {
      // `minTextCapPixels: 0` -- level of detail OFF on both arms. Text
      // culling is a watermark decision frozen at the reference scale (the
      // spec's table), so with it on the two arms legitimately disagree
      // about TINY away from scale 1; that disagreement is Plan F's band
      // statement, not this gate's. The LOD-on case is the next test.
      // Ruling R5-1: the anti-vacuity floor is per row, not one constant
      // across the band -- the scale-1 calibration of 5000 lives on the
      // LOD-on row below, and each scale here gets its own floor instead.
      final base = _fit(doc);
      final m = await measureCompositedAgreement(doc,
          collectionCamera: base,
          liveCamera: _scaled(base, s),
          size: _size,
          devicePixelRatio: _dpr,
          pixelsPerPaperMm: _ppmm,
          measurer: measurer,
          minTextCapPixels: 0.0);
      expect(m.referenceInk, greaterThan(1000),
          reason: 'anti-vacuity -- the scale-1 floor of 5000 lives on the '
              'LOD-on row; this corpus at 0.5 is a quarter of that '
              'picture');
      expect(m.patchCount, greaterThanOrEqualTo(1),
          reason: 'COVERED must be a patch or this test sees no ordering');
      expect(m.agreement, greaterThanOrEqualTo(0.995),
          reason: 'spec criterion 1, per channel <= 2 on >= 99.5% of the '
              'union; scale $s: withinTwo=${m.withinTwo} union=${m.union} '
              'overEight=${m.overEight}');
    });
  }

  test('with level of detail on, both arms cull TINY the same way at scale 1',
      () async {
    final base = _fit(doc);
    final m = await measureCompositedAgreement(doc,
        collectionCamera: base,
        liveCamera: base,
        size: _size,
        devicePixelRatio: _dpr,
        pixelsPerPaperMm: _ppmm,
        measurer: measurer);
    expect(m.referenceInk, greaterThan(5000),
        reason: 'anti-vacuity at the scale the floor was calibrated on');
    expect(m.agreement, greaterThanOrEqualTo(0.995));
  });

  test('drawing all text in one pass -- no patches -- changes the picture',
      () async {
    // The spec's headline text mutation, as a seam rather than a source
    // edit: with the classifier's output discarded, the later stroke 903
    // draws UNDER label COVERED, and the fill 904 under it too.
    final base = _fit(doc);
    final m = await measureCompositedAgreement(doc,
        collectionCamera: base,
        liveCamera: base,
        size: _size,
        devicePixelRatio: _dpr,
        pixelsPerPaperMm: _ppmm,
        measurer: measurer,
        mutatePatches: (_) => const []);
    expect(m.patchCount, 0);
    expect(m.overEight, greaterThan(200),
        reason: 'the ink of 903 and 904 inside COVERED\'s glyphs is where '
            'the two arms now disagree; fewer than 200 pixels means the '
            'overlap is not real and Task 3\'s guard is wrong');
    expect(m.agreement, lessThan(0.995));
  });

  test('the label nothing later reaches is not a patch, and still matches',
      () async {
    final base = _fit(doc);
    final m = await measureCompositedAgreement(doc,
        collectionCamera: base,
        liveCamera: base,
        size: _size,
        devicePixelRatio: _dpr,
        pixelsPerPaperMm: _ppmm,
        measurer: measurer);
    // Exactly the labels the table says are covered: COVERED and GRAZED.
    // UNDER is not (its only stroke is of lower handle); TINY is not.
    expect(m.patchCount, 2,
        reason: 'a classifier that patches every label reads 4 here');
  });
}
