import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/fixtures.dart';
import '../support/gpu_comparison.dart';
import '../support/recording_frame_painter.dart';
import '../support/tile_fixture.dart';

/// Live-over-collection ratios, the band's two provisional edges among them.
const List<double> kRatios = [0.25, 0.35, 0.5, 0.7, 1.0, 1.4, 2.0, 2.8, 4.0];
const Size _size = Size(800, 600);
const Offset _centre = Offset(400, 300);
const double _dpr = 1.0;

/// Criterion 1, literally: per-channel <= 2 on >= 99.5% of the union, <= 8
/// on the rest, and differing pixels below 1% of live ink.
bool criterionOne(CompositedAgreement m) =>
    m.union > 0 &&
    m.withinTwo / m.union >= 0.995 &&
    m.overEight == 0 &&
    (m.union - m.withinTwo) < 0.01 * m.referenceInk;

Future<Map<double, CompositedAgreement>> sweep(
  DraftDocument doc,
  FlutterTextMeasurer measurer, {
  required String name,
  required ViewportTransform collection,
  required double minTextCapPixels,
}) async {
  final frame = collectionFrameFor(collection, doc.extents);
  final rows = <double, CompositedAgreement>{};
  for (final r in kRatios) {
    final m = await measureCompositedAgreement(doc,
        collectionCamera: frame.camera,
        collectionViewport: frame.viewport,
        liveCamera: zoomedAbout(collection, _centre, r),
        size: _size,
        devicePixelRatio: _dpr,
        pixelsPerPaperMm: kLogicalPixelsPerMm,
        measurer: measurer,
        minTextCapPixels: minTextCapPixels);
    rows[r] = m;
    // ignore: avoid_print
    print('BAND $name ratio=$r ${criterionOne(m) ? "PASS" : "FAIL"} $m');
  }
  return rows;
}

/// The widest contiguous run of passing ratios containing 1.0.
///
/// **1.0 itself must pass.** The first draft of this helper seeded
/// `lo = hi = 1.0` and walked outward without ever testing `rows[1.0]`, so on
/// a corpus whose centre fails it reported a run with a failing ratio inside
/// it -- `curves@8x` read `[0.7, 2.0]` while 1.0 itself was red. A run that
/// does not hold at the reference scale is not a band at all, so it collapses
/// to a point and says so.
/// [passes] defaults to criterion 1 itself. The straight corpus overrides it
/// at ratio 1.0 alone, for the tie-jitter reason test 1 documents; every
/// other corpus and every other ratio is criterion 1, literally.
(double, double) passingRun(String name, Map<double, CompositedAgreement> rows,
    {bool Function(double ratio, CompositedAgreement m)? passes}) {
  final ok = passes ?? ((_, CompositedAgreement m) => criterionOne(m));
  if (!ok(1.0, rows[1.0]!)) {
    // ignore: avoid_print
    print('BAND $name run=[1.0, 1.0] = 1.00x '
        '(ratio 1.0 itself fails criterion 1, so there is no run)');
    return (1.0, 1.0);
  }
  var lo = 1.0, hi = 1.0;
  final i1 = kRatios.indexOf(1.0);
  for (var i = i1 - 1; i >= 0 && ok(kRatios[i], rows[kRatios[i]]!); i--) {
    lo = kRatios[i];
  }
  for (var i = i1 + 1;
      i < kRatios.length && ok(kRatios[i], rows[kRatios[i]]!);
      i++) {
    hi = kRatios[i];
  }
  // ignore: avoid_print
  print('BAND $name run=[$lo, $hi] = ${(hi / lo).toStringAsFixed(2)}x');
  return (lo, hi);
}

/// Criterion 1 everywhere except the identity, where [straightTieJitter]
/// stands in. See test 1 for why the reference scale is the one ratio of the
/// sweep where two exact rasterisations disagree at all.
bool straightPasses(double ratio, CompositedAgreement m) =>
    ratio == 1.0 ? straightTieJitter(m) : criterionOne(m);

bool straightTieJitter(CompositedAgreement m) =>
    m.agreement >= 0.999 && m.uncovered * 1000 < m.referenceInk;

void main() {
  late FlutterTextMeasurer measurer;
  setUp(() {
    measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
  });

  // The positive statement, and the control for every negative one below:
  // where the collection freezes NO scale-dependent decision, the resident
  // arm reproduces the reference exactly over the whole 16x sweep. A corpus
  // of straight strokes has no chord count to freeze and no label to cull,
  // so the frame transform, `expandInstances` and the compositor are the
  // only things under test -- and they are exact. Every failure in the tests
  // that follow is therefore attributable to a frozen decision, not to the
  // arrangement.
  test('straight geometry meets criterion 1 at every ratio of the sweep',
      () async {
    final doc = crossingGrid(measurer);
    final fit = ViewportTransform.fit(doc.extents, _size);
    final rows = await sweep(doc, measurer,
        name: 'straight@fit', collection: fit, minTextCapPixels: 0);
    for (final r in kRatios) {
      expect(rows[r]!.referenceInk, greaterThan(1000),
          reason: 'anti-vacuity at ratio $r: ${rows[r]}');
      if (r == 1.0) continue;
      expect(criterionOne(rows[r]!), isTrue, reason: 'ratio $r: ${rows[r]}');
    }

    // Ruling F13-b. The reference scale is the ONE ratio of this sweep where
    // the two arms disagree at all -- 8 pixels of 9,792 -- and the reason is
    // a tie, not a frozen decision.
    //
    // `crossingGrid` is axis-aligned. At ratio exactly 1.0 its stroke edges
    // land on device-pixel boundaries, and there a 1-ulp difference between
    // the resident arm's float32 collection vertices (plus the offscreen
    // image round-trip the compositor adds, which the reference does not
    // have) and the reference's float64 direct draw flips the pixel to the
    // other side. Off the identity the same edges land mid-pixel, both arms
    // compute the same antialiased coverage, and the disagreement is gone:
    // 0.999 and 1.001 both measure exact, in both directions.
    //
    // Three candidate causes were eliminated by measurement, not by
    // argument: the count is identical with the collection frame's
    // fractional shift, with NO shift at all (collection camera == live
    // camera, `collectionToLogical` the identity), and with the shift
    // rounded to whole device pixels. So it is not `collectionFrameFor`'s
    // translation, and rounding that translation would not fix it.
    //
    // `criterionOne` admits no jitter (`overEight == 0`) and stays that way
    // -- it is the spec's literal criterion 1. This ratio is bounded
    // instead, tightly and in the same unit as the zoom-out defect.
    expect(straightTieJitter(rows[1.0]!), isTrue,
        reason: 'tie jitter at the identity: ${rows[1.0]}');

    expect(
        passingRun('straight@fit', rows, passes: straightPasses), (0.25, 4.0));
  });

  // The decomposition, and the whole of criterion 2's text half: text and
  // geometry are pixel-exact across the band, and what fails past it is one
  // named frozen row -- the level-of-detail cull.
  //
  // `textOverlapFixture`'s TINY label sits under `kMinTextCapPixels` at the
  // reference scale and above it at a 1.4x live scale, so the live reference
  // draws it while the frozen collection -- which culled it -- does not.
  // That is `uncovered` ink, and it stands until the band exit rebuilds. Run
  // the same ratio with the cull switched off and criterion 1 holds, which
  // is what makes this a statement about the frozen row rather than about
  // text rendering: Plan E's `text_order_test.dart` already proved 1.25 and
  // 2.0 exact at level of detail off.
  test(
      'text with level of detail on: exact inside [0.5, 1.0], and the 1.4 '
      'failure is the frozen cull by construction', () async {
    final doc = textOverlapFixture(measurer);
    final fit = ViewportTransform.fit(doc.extents, _size);
    final rows = await sweep(doc, measurer,
        name: 'text-lod@fit',
        collection: fit,
        minTextCapPixels: kMinTextCapPixels);
    for (final r in [0.5, 0.7, 1.0]) {
      expect(criterionOne(rows[r]!), isTrue, reason: 'ratio $r: ${rows[r]}');
    }
    expect(rows[1.0]!.patchCount, greaterThanOrEqualTo(1));
    expect(rows[1.4]!.uncovered, greaterThan(0),
        reason: 'the frozen cull leaves the reference label blank: '
            '${rows[1.4]}');

    final frame = collectionFrameFor(fit, doc.extents);
    final lodOff = await measureCompositedAgreement(doc,
        collectionCamera: frame.camera,
        collectionViewport: frame.viewport,
        liveCamera: zoomedAbout(fit, _centre, 1.4),
        size: _size,
        devicePixelRatio: _dpr,
        pixelsPerPaperMm: kLogicalPixelsPerMm,
        measurer: measurer,
        minTextCapPixels: 0);
    // ignore: avoid_print
    print('BAND text-nolod@fit ratio=1.4 '
        '${criterionOne(lodOff) ? "PASS" : "FAIL"} $lodOff');
    expect(criterionOne(lodOff), isTrue,
        reason: 'with the cull off, 1.4 is exact -- so the 1.4 failure above '
            'is the frozen cull and nothing else: $lodOff');
  });

  // The geometry half of the same decomposition. A curve's chord count is
  // chosen at the collection scale and frozen; at any other scale the two
  // arms are two independent, individually-correct polygonal approximations
  // of one curve, differing by a fraction of a pixel along the outline. On a
  // corpus that is almost entirely curve outline that moves ~7-10% of the ink
  // past criterion 1's per-channel tolerance, in BOTH directions and at any
  // step across a refinement threshold -- measured at 1% of zoom, not merely
  // at the band's edges. The step is asserted here in both directions; its
  // sharpness is recorded in the results note.
  //
  // The floor is 1,000, not the plan's 5,000: this fixture inks 1,873 at
  // ratio 1.0 in an 800x600 viewport at dpr 1. The 5,000 figure belongs to
  // Plan E's `resident_pixel_differential_test.dart`, which measures a
  // different corpus at dpr 2.0, and was carried into this plan by mistake.
  test('solid curves at fit: exact at 1.0, and the chord-count step is real',
      () async {
    final doc = differentialFixture(measurer: measurer);
    final fit = ViewportTransform.fit(doc.extents, _size);
    final rows = await sweep(doc, measurer,
        name: 'curves@fit', collection: fit, minTextCapPixels: 0);
    expect(criterionOne(rows[1.0]!), isTrue, reason: 'ratio 1.0: ${rows[1.0]}');
    expect(rows[1.0]!.referenceInk, greaterThan(1000),
        reason: 'anti-vacuity: ${rows[1.0]}');
    expect(rows[1.4]!.agreement, lessThan(rows[1.0]!.agreement),
        reason: 'the step on zoom in: ${rows[1.4]}');
    expect(rows[0.7]!.agreement, lessThan(rows[1.0]!.agreement),
        reason: 'and on zoom out: ${rows[0.7]}');
    passingRun('curves@fit', rows);
  });

  // Ruling F2's cost, measured. The buffer holds absolute frame coordinates,
  // so a collection at 8x the fit scale stores coordinates 8x larger and
  // spends float32 mantissa on them. At ratio 1.0 that shows as 6 differing
  // pixels out of a 479-pixel union -- the measured price of the shifted
  // float32 frame at a working scale, and the reason this asserts 0.98 rather
  // than criterion 1's 0.995.
  //
  // Ratios 2.8 and 4.0 ink nothing at all (`union=0`): zooming the fit camera
  // 8x about the viewport centre puts the drawing off screen, and zooming
  // further in keeps it there. Those rows are printed, not asserted.
  test('solid curves at a working zoom (8x): Ruling F2\'s precision, measured',
      () async {
    final doc = differentialFixture(measurer: measurer);
    final working =
        zoomedAbout(ViewportTransform.fit(doc.extents, _size), _centre, 8.0);
    final rows = await sweep(doc, measurer,
        name: 'curves@8x', collection: working, minTextCapPixels: 0);
    expect(rows[1.0]!.agreement, greaterThanOrEqualTo(0.98),
        reason: 'float32 at 8x: ${rows[1.0]}');
    expect(rows[1.0]!.referenceInk, greaterThan(400),
        reason: 'anti-vacuity: ${rows[1.0]}');
  });

  // Criterion 2's reported number. The intersection is what the spec asks
  // for; that it is 1.00x is the design failure the spec names, recorded in
  // the results note with the rows above rather than asserted here as a
  // threshold. What IS asserted is the shape of the result: the unfrozen
  // corpus spans the whole sweep, and the intersection contains the
  // reference scale.
  test('the reported band is the intersection of the passing runs', () async {
    final straightDoc = crossingGrid(measurer);
    final straightFit = ViewportTransform.fit(straightDoc.extents, _size);
    final straight = passingRun(
        'straight@fit',
        await sweep(straightDoc, measurer,
            name: 'straight@fit', collection: straightFit, minTextCapPixels: 0),
        passes: straightPasses);

    final textDoc = textOverlapFixture(measurer);
    final textFit = ViewportTransform.fit(textDoc.extents, _size);
    final text = passingRun(
        'text-lod@fit',
        await sweep(textDoc, measurer,
            name: 'text-lod@fit',
            collection: textFit,
            minTextCapPixels: kMinTextCapPixels));

    final curveDoc = differentialFixture(measurer: measurer);
    final curveFit = ViewportTransform.fit(curveDoc.extents, _size);
    final curves = passingRun(
        'curves@fit',
        await sweep(curveDoc, measurer,
            name: 'curves@fit', collection: curveFit, minTextCapPixels: 0));

    final lo =
        [straight.$1, text.$1, curves.$1].reduce((a, b) => a > b ? a : b);
    final hi =
        [straight.$2, text.$2, curves.$2].reduce((a, b) => a < b ? a : b);
    // ignore: avoid_print
    print('BAND reported: [$lo, $hi] = ${(hi / lo).toStringAsFixed(2)}x  '
        '(curves and text-lod limit it; straight: '
        '[${straight.$1}, ${straight.$2}])');

    expect(straight, (0.25, 4.0),
        reason: 'the unfrozen corpus spans the whole sweep');
    expect(lo, lessThanOrEqualTo(1.0));
    expect(hi, greaterThanOrEqualTo(1.0));
  });
}
