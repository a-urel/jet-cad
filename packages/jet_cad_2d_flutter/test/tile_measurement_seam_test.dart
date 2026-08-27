// The two runtime switches Plan 3i's Tasks 12 and 13 measure through, and the
// only tests that can tell a switch that switches from one that is merely
// read.
//
// **Why this file exists at all.** Criterion 4 scores a ratio between a
// "rest" arm and a "tiled" arm; criterion 8 scores a ratio between a "narrow"
// arm and an "M4" arm. Both ratios are defined to run **interleaved in one
// session**, which means one binary has to be able to be both arms — hence
// `TileCache.debugRestBakeDisabled` and `TileCache.debugFullViewportQuery`.
// A flag that is read but changes nothing observable would make both ratios
// read exactly 1.00, and the degenerate number would land in a document of
// record with nothing to contradict it. So each test below asserts on what
// the frame path *did* — slices, coverage, the recorded strip, triangles
// emitted — and never on the flag's own value, which is true by assignment.
//
// **Why a file of its own, rather than `tile_regime_test.dart` or
// `tile_fallback_test.dart`.** The two switches share a subject — they are
// the measurement seams, and they exist for one reason — but they sit on
// opposite sides of `paintFrame`: one suppresses the rest bake, the other
// widens the live fallback's query. Splitting them across those two files
// would put half of one purpose in each and leave neither file able to say
// why its half is there; `tile_regime_test.dart` is about the rest *gate*
// predicate (four of its tests are pure-Dart camera comparisons) and
// `tile_fallback_test.dart` is a pixel-agreement sweep that declares in its
// own header that it names no symbol from `jet_cad_2d_flutter`. Both flag
// tests name several.
//
// Mutants M13 and M14 in `docs/superpowers/notes/plan-3i-mutation-log.md` are
// the deletions of the two switches; each reddens exactly one test here.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/tile_fixture.dart';
import 'support/tile_harness.dart';

/// Drops [h]'s generation at an unmoved camera and settles, counting slices.
///
/// **This is `settleFromBands` with its two promises removed, and the
/// removal is the point rather than a shortcut.** That helper asserts
/// `slices == liveTileCount` and `viewportCovered`, which is exactly the
/// claim `debugRestBakeDisabled` is built to falsify: the flagged arm slices
/// nothing. A shared helper cannot both promise the band settle and be the
/// vehicle for proving it did not happen, so the two arms below drive
/// themselves and state their own promises at the call site — the enabled arm
/// restates `settleFromBands`'s equality verbatim.
///
/// Everything else is deliberately *not* re-implemented: the pump bound lives
/// in [settle] and is called, not copied, so this file cannot drift out of
/// step with `kRestGateFrames` the way a second copy of that loop would.
///
/// The mechanics are `settleFromBands`'s and its doc comment carries the
/// reasoning: `paintFrame` reads `tables.mutationRevision` every frame and
/// drops the generation when it moves, keeping the lattice and the anchor, so
/// the very next frame is a rest frame over an empty generation **at a camera
/// that never moved** — which is the only state where the whole viewport is
/// in the rest bake's hands rather than the two corner tiles the initial
/// budgeted fill happens to leave. The layer added is referenced by nothing,
/// so not one pixel changes with it.
Future<int> _restFromEmptyGeneration(WidgetTester t, TiledHarness h) async {
  await settle(t, h);
  var slices = 0;
  h.cache.debugOnSliceForTest = () => slices++;
  addTearDown(() => h.cache.debugOnSliceForTest = null);
  h.document.tables.layers.add(const LayerRecord(
    handle: Handle(901),
    name: 'SEAM-DROP',
    color: IndexedColor(3),
    linetype: ReservedHandles.continuousLinetype,
    lineweight: 50,
    transparency: 0,
  ));
  await t.pump();
  await settle(t, h);
  h.cache.debugOnSliceForTest = null;
  return slices;
}

/// What one live-fallback frame did, read off the shipped frame path.
class _FallbackArm {
  const _FallbackArm(this.strip, this.triangles, this.liveDraws);

  /// `TileCache.debugLastStrip`: the rectangle the fallback actually walked.
  final Rect? strip;

  /// `VerticesDrawSink.frameTriangleCount` for that frame — the quantity
  /// criterion 8's ratio is built on, and the one `kTriangleBudgetRatio`
  /// already uses to kill this mutation as a source edit.
  final int triangles;
  final int liveDraws;

  @override
  String toString() => '_FallbackArm(strip: $strip, triangles: $triangles, '
      'liveDraws: $liveDraws)';
}

/// One partly-baked frame with an entering band the fallback owes.
///
/// The arrangement is `measureFallbackAgreement`'s, minus the pixel capture:
/// cover the viewport at a budget that never runs out, then drop the budget to
/// one tile a frame and pan, so the entering band cannot be baked and the live
/// walk has to own it. No settle is needed — this fixture only pans, so no
/// generation is ever retired and `_carryOver` stays null throughout.
///
/// **`Offset(0, 53)` and not any pan.** `kTriangleBudgetRatio`'s doc comment
/// records the swept measurement behind this choice: over `kFallbackOffsets`
/// on `fillingGrid`, this is the offset where the shipped narrowing's
/// tiled/live triangle ratio is *worst* (0.9375) and where the mutant's is
/// highest — the tightest sample in the sweep, so a switch that failed to
/// widen the walk has the least room to hide here. Its band is also a single
/// axis, so `uncovered` stays a genuine strip rather than bounding to the
/// whole viewport the way a diagonal pan's does.
_FallbackArm _fallbackArm({required bool fullViewportQuery}) {
  final measurer = FlutterTextMeasurer();
  try {
    final rig = TileRig(
        tileDevicePixels: 64,
        tilesBakedPerFrame: 1000,
        document: fillingGrid(measurer));
    try {
      rig.paintOnce();
      rig.cache.bakeBudgetDevicePixels = 64 * 64;
      rig.cache.debugFullViewportQuery = fullViewportQuery;
      rig.panBy(0, 53);
      // Both counters zeroed immediately before the frame under test, so
      // every number below is that one frame's own emission rather than a
      // running total that includes the covering frame above.
      rig.cache.resetCounters();
      rig.vertices.resetCounters();
      rig.paintOnce();
      return _FallbackArm(rig.cache.debugLastStrip,
          rig.vertices.frameTriangleCount, rig.cache.liveDrawCount);
    } finally {
      rig.dispose();
    }
  } finally {
    measurer.clear();
  }
}

void main() {
  testWidgets('the rest bake fires, and debugRestBakeDisabled suppresses it',
      (t) async {
    // Arm 1: the flag off, which is every shipped frame. This half is the
    // anti-degenerate clause for arm 2 — without it, "no slices" would be
    // satisfied by an arrangement that never reaches a rest frame at all, and
    // the flag would look load-bearing while doing nothing.
    final enabled = await pumpTiled(t);
    final slicedWithBake = await _restFromEmptyGeneration(t, enabled);
    expect(slicedWithBake, equals(enabled.cache.liveTileCount),
        reason: 'setup: with the flag off the rest bake must own the whole '
            'viewport, or the flagged arm below proves nothing');
    expect(slicedWithBake, greaterThan(1),
        reason: 'setup: a one- or two-tile band settle is the degenerate '
            'case `settleFromBands` exists to avoid');
    expect(enabled.cache.viewportCovered, isTrue);
  });

  testWidgets('debugRestBakeDisabled slices nothing and still covers',
      (t) async {
    final h = await pumpTiled(t);
    h.cache.debugRestBakeDisabled = true;

    final sliced = await _restFromEmptyGeneration(t, h);

    // The switch actually switched: no tile on this frame came out of a band.
    expect(sliced, 0,
        reason: 'with the rest bake disabled no tile may be cut from a band '
            '-- criterion 4\'s denominator arm is the budgeted per-tile path, '
            'and an arm that still slices is the numerator arm under a '
            'different name, which would put the ratio at 1.00');
    // And it is a measurement switch, not a correctness switch: the ordinary
    // budgeted path still filled the viewport, through `_bake`, over more
    // frames. Asserting both is what separates "the bake was suppressed" from
    // "the frame did nothing at all" -- the latter would also slice zero.
    expect(h.cache.bakeCount, greaterThan(0),
        reason: 'the budgeted per-tile path must have baked the tiles the '
            'band path was not allowed to');
    expect(h.cache.viewportCovered, isTrue,
        reason: 'pixels stay correct either way; only how many frames '
            'coverage takes changes');
    expect(h.cache.liveTileCount, greaterThan(1),
        reason: 'and the generation it refilled is the whole visible set, '
            'not a corner of it');
  });

  test('debugFullViewportQuery grows the fallback walk to the whole viewport',
      () {
    final narrow = _fallbackArm(fullViewportQuery: false);
    final m4 = _fallbackArm(fullViewportQuery: true);

    // Non-vacuity first: both arms must have actually run a live fallback on
    // the frame under test, or the strips below are the previous frame's.
    expect(narrow.liveDraws, greaterThan(0), reason: 'narrow=$narrow');
    expect(m4.liveDraws, greaterThan(0), reason: 'm4=$m4');

    // The shipped arm walks a strip, and a strip strictly inside the
    // viewport. This is the clause that fails if the fixture ever stops
    // producing an interior edge -- at which point both arms would walk the
    // whole viewport for reasons that have nothing to do with the flag.
    expect(narrow.strip, isNotNull, reason: 'narrow=$narrow');
    expect(narrow.strip!.height, lessThan(kTileViewport.height),
        reason: 'the narrowed query must walk less than the full viewport, '
            'or the two arms are the same arm: narrow=$narrow');

    // The M4 arm walks the viewport. `debugLastStrip` is written by
    // `paintFrame` itself from the value the walk was handed, so this reads
    // the shipped code's decision rather than restating the flag.
    expect(m4.strip, equals(Offset.zero & kTileViewport),
        reason: 'with the flag set the query is the full viewport -- that is '
            'what Plan 3h\'s M4 is: $m4');

    // And the quantity criterion 8 is actually a ratio of. The strip
    // assertions above see the rectangle; this sees the cost, which is the
    // only reason the rectangle matters. A wider walk that tessellated the
    // same geometry would be an M4 that is inert, and the criterion 8 ratio
    // would read 1.00 with both switches working perfectly.
    expect(m4.triangles, greaterThan(narrow.triangles),
        reason: 'the full-viewport query must tessellate more geometry than '
            'the strip-sized one: narrow=$narrow m4=$m4');
  });
}
