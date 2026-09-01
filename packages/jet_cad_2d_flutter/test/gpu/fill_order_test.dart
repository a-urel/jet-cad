import 'dart:typed_data';
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
    // instead finds one at index 153, from 905's own boundary outline.
    //
    // **What this assertion does and does not prove.** `lastStroke >
    // lastFill` only says a stroke instance exists somewhere after the
    // last fill instance in walk order -- true of any document whose final
    // region contributes a boundary outline after its own fill, regardless
    // of whether that stroke or any other actually overlaps a fill on
    // screen. It would stay true even if every fill covered only the
    // strokes drawn BEFORE it, which would make criterion 4 unobservable
    // here despite this line passing. It is kept as an anti-vacuity floor
    // -- a corpus with no stroke anywhere after its last fill could not
    // show a permutation-order effect at all, and this does redden under
    // the sorted-buffer mutation (`task-7-report.md`) -- but the actual
    // overlap property criterion 4 depends on (903's higher-handle stroke
    // genuinely sharing screen pixels with fill 901) is proved separately,
    // by `fixtures_test.dart`'s `strokeInkInsideFill`-based guard test,
    // which measures 337 logical pixels of shared ink between them.
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

  // The three tests above measure PIXELS, and a wrong-stride reorder could
  // move `differing` past 200 and `withinTwoFraction` under 0.995 for
  // entirely the wrong reason -- garbled records still paint a different,
  // wrong picture, which reads as "the gate works" without the gate ever
  // having tested a real permutation. `reorderedInstances` was only
  // verified once, by a throwaway test written and deleted for
  // `task-7-report.md`; the two tests below pin the same property
  // permanently, at the RECORD level, so the pixel gate's premise rests on
  // the suite rather than on that review-time run.
  test('the identity permutation renders the same picture as no permutation',
      () {
    // Kills a stride or off-by-one bug in the reorder loop directly: for
    // `order[i] == i` (every index, in place) any correct implementation
    // must reproduce the input exactly. A mutant that shifted the copy
    // range by one float, or read `order[i +/- 1]`, would move a record
    // even under the identity permutation and this would redden -- where
    // the pixel tests above could not tell an off-by-one from a genuine
    // reorder, since both move pixels.
    final inOrder = renderFillFixture();
    final identity = renderFillFixture(permute: (order) => order);
    expect(countDifferingPixels(inOrder, identity), 0,
        reason: 'permute: (order) => order must be a true no-op');
  });

  test(
      'sortByKind is a multiset-equal reordering of the walk-order buffer, '
      'not a scramble', () {
    // Kills a NON-BIJECTIVE `sortByKind` -- one that silently duplicates one
    // instance index into two output slots and drops another -- which the
    // tests above cannot see: the pixel gates would still likely read
    // "different enough" (a duplicated record still paints something, just
    // the wrong thing), and the identity-permutation test above never calls
    // `sortByKind` at all, so a bug confined to its own sort/dedupe logic is
    // invisible to it. (A pure index-stride bug in the reorder COPY itself,
    // composed with any genuine permutation, stays bijective and would NOT
    // fail this multiset check -- verified by firing exactly that mutation
    // in `reorderedInstances` during review: it passed this test and failed
    // only the identity-permutation one above, which is why both tests are
    // needed rather than either alone. See `task-7-report.md`.) Comparing
    // whole records as a multiset -- every one present in the sorted buffer
    // exactly as many times as in the walk-order buffer -- catches a
    // duplicate-and-drop directly, independent of what picture it paints.
    final c = collectFillFixture();
    final data = c.data;
    final n = c.instanceCount;
    final order = sortByKind(List<int>.generate(n, (i) => i));
    expect(order.length, n,
        reason: 'sortByKind must return one index per instance, or '
            'reorderedInstances would truncate or duplicate records');

    final reordered = reorderedInstances(data, n, order);

    // Every whole 16-float record, as its own key -- not `kind` alone, so
    // a mutant that grouped by kind correctly but corrupted a position or
    // a colour along the way still fails this.
    Map<String, int> recordCounts(Float32List buf) {
      final counts = <String, int>{};
      for (var i = 0; i < n; i++) {
        final record =
            buf.sublist(i * kFloatsPerInstance, (i + 1) * kFloatsPerInstance);
        final key = record.join(',');
        counts[key] = (counts[key] ?? 0) + 1;
      }
      return counts;
    }

    expect(recordCounts(reordered), equals(recordCounts(data)),
        reason: 'sortByKind must be a bijection on instance indices: every '
            'record in the walk-order buffer must appear in the sorted one '
            'exactly as many times, whole and unmodified -- not garbled, '
            'dropped or duplicated by a wrong-stride copy');
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
