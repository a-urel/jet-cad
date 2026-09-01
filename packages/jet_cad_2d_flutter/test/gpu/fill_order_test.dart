import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

import '../support/fixtures.dart' show kViewport;
import '../support/gpu_comparison.dart';

const Size _size = kViewport;
const double _dpr = kFillFixtureDevicePixelRatio;
const double _ppmm = kLogicalPixelsPerMm;

/// Spec criterion 4: emission order is the drawing, and a permutation of the
/// buffer is a different picture.
///
/// **This file exists because of fills.** A permutation of strokes preserves
/// the union of covered pixels, so the coverage instrument cannot see it --
/// `gpu_comparison.dart` says so. A fill covers a stroke, so reordering the
/// two changes the colour of every pixel they share. Without a fill in the
/// corpus this whole file passes vacuously, which is why the first test
/// below asserts the corpus's own overlap before the second asserts the
/// permutation changes it.
void main() {
  test('the fill corpus really does have a stroke drawn over a fill', () {
    final c = collectFillFixture();
    final data = c.data;
    // `lastFill` and `lastStroke` are each the LAST index of their kind in
    // the whole walk, not the first stroke found after the first fill seen.
    //
    // **A single pass that locks `strokeAfterFill` in at the first
    // qualifying instance measures the wrong thing on this corpus, and it
    // is worth recording why rather than only fixing it.** `fillFixture`
    // draws two regions (901 and 904), and `AddRegionCommand` adds a
    // region's BOUNDARY as its own ordinary, independently visible entity
    // (`commands.dart`'s `AddRegionCommand.apply`: "Allocates the pair,
    // fill first" -- both halves land in the document tree) -- so 902's
    // outline stroke is drawn immediately after fill 901, long before fill
    // 904 is reached. A loop that stops at the first stroke seen after ANY
    // fill locks onto 902's outline and never looks again, so it compares
    // that early index against `lastFill` (which keeps advancing to 904's
    // own last instance) and reads a false negative -- exactly what an
    // earlier draft of this test did, printing `lastFill=58,
    // strokeAfterFill=3`. Scanning the whole buffer for the LAST stroke
    // instead finds one at index 153, from 905's own boundary outline,
    // which is what the corpus actually guarantees: 903's higher-handle
    // stroke over fill 901 is the one `strokeInkInsideFill`'s 337-pixel
    // overlap already measured, and it is not the only stroke after a fill
    // in this walk, only the only one whose overlap is pinned by name.
    var lastFill = -1, lastStroke = -1;
    for (var i = 0; i < c.instanceCount; i++) {
      final kind = data[i * kFloatsPerInstance + InstanceFieldOffset.kind];
      if (kind == kKindFill) lastFill = i;
      if (kind == kKindStroke) lastStroke = i;
    }
    expect(lastFill, greaterThanOrEqualTo(0), reason: 'no fill was collected');
    expect(lastStroke, greaterThan(lastFill),
        reason: 'no stroke is emitted after the last fill, so no permutation '
            'of this corpus could change a pixel and criterion 4 would pass '
            'vacuously');
  });

  test('submitting the buffer out of walk order changes the rendering', () {
    // In walk order the higher-handle stroke is drawn after the fill and is
    // visible over it. Sorted by kind -- which is what a separate pipeline
    // per kind would submit -- every fill is drawn last and covers it.
    final inOrder = renderFillFixture();
    final byKind = renderFillFixture(permute: sortByKind);

    final differing = countDifferingPixels(inOrder, byKind);
    expect(differing, greaterThan(200),
        reason: 'a permutation that changed no pixel would mean this gate '
            'cannot fail, whatever it reads');
  });

  test('the resident arm matches the reference in walk order and only there',
      () {
    final ordered = measureResidentColor(paintFillFixture,
        size: _size, devicePixelRatio: _dpr, pixelsPerPaperMm: _ppmm);
    expect(ordered.withinTwoFraction, greaterThanOrEqualTo(0.995),
        reason: ordered.toString());

    final permuted = measureResidentColor(paintFillFixture,
        size: _size,
        devicePixelRatio: _dpr,
        pixelsPerPaperMm: _ppmm,
        permute: sortByKind);
    expect(permuted.withinTwoFraction, lessThan(0.995),
        reason: 'if a kind-sorted buffer still matched the reference, this '
            'backend would have no order to preserve and the single-draw-call '
            'design would be unnecessary: ${permuted.toString()}');
  });
}

/// A stable permutation of instance indices ordered by the record's `kind`
/// slot -- the order three separate pipelines (one draw call each for
/// strokes, joins and fills) would submit in, since each pipeline drains
/// every instance of its own kind before the next pipeline's call starts.
/// **Test-only: this ordering must never appear in `lib/`** -- the whole bet
/// this plan's single buffer and single draw call makes is that walk order
/// is what a real frame needs, not a kind-sorted resubmission of it.
///
/// [order] arrives as the identity list `[0, 1, ..., n-1]` from every caller
/// in this file ([measureResidentColor] and [renderFillFixture] both build
/// it that way before calling their `permute`), so re-collecting the fixture
/// here to read each index's `kind` reproduces the same walk -- collecting
/// twice does not collect *differently*: `devicePixelRatio` moves a
/// record's `halfWidth`, never its `kind` or its position in the walk.
///
/// **Stable, and not by accident of `List.sort`'s unspecified-when-equal
/// behaviour**: Dart's `sort` is not documented stable, so ties are broken
/// explicitly, on the original index, which is what actually makes this
/// "the order three pipelines would submit in" rather than an arbitrary
/// reshuffling of instances that share a kind.
List<int> sortByKind(List<int> order) {
  final data = collectFillFixture().data;
  double kindOf(int i) =>
      data[i * kFloatsPerInstance + InstanceFieldOffset.kind];
  final sorted = List<int>.of(order)
    ..sort((a, b) {
      final byKind = kindOf(a).compareTo(kindOf(b));
      return byKind != 0 ? byKind : a.compareTo(b);
    });
  return sorted;
}
