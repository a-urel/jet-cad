// Criteria 12 and 13, always on.
//
// **Criterion 13 is a field read and not a heap measurement, and `STATUS.md`
// says why.** There is no working Flutter-side allocation meter -- trap 5 --
// and `paint_allocation_test.dart` reads one field,
// `VerticesDrawSink.debugCapacityVertices`, which can see neither a `Paint`
// nor a `Rect`. So this pins the `Paint`'s identity and the per-frame
// destination count instead, the same shape `VerticesDrawSink.debugPaint`
// already uses.
//
// **The identity half is pinned by `SpyCanvas` in `tile_cache_test.dart`, not
// here, and that is deliberate.** `debugBlitPaint` returns the cache's own
// field, so `identical(cache.debugBlitPaint, paint)` reports true whatever the
// blit hands `drawImageRect` -- a mutation that builds a call-site-local
// `Paint` survives it, which was measured (task-4-report.md) and is why Task 4
// added a spy test and Task 9 extended it to the composite's separate `Paint`.
// The getter assertion below is kept because the brief specifies it and it is
// a cheap regression guard on the field, but the spy test is the instrument.
//
// **Why the two cap tests never zoom, when nothing outside
// `tile_cache_test.dart` ever does.** A carry-over composite is one
// viewport-sized image: 800 x 600 device pixels here, 1,920,000 bytes, which
// is more than fourteen times the 131,072-byte cap those two tests use. With
// one standing, `liveBytes <= cacheBytes` is unsatisfiable by construction --
// eviction must never reclaim the composite, because the frame path reads it
// every frame and reclaiming it replaces stale pixels with blank ones -- so a
// zoom there would assert a contradiction rather than a cap. The state is not
// skipped, though: the third test below stands a real composite at the
// production ceiling and pins that `liveBytes` counts it, which is the claim
// the cap actually rests on.

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/tile_comparison.dart';
import '../support/tile_fixture.dart';

/// One tile at the size every test here uses: 64 device pixels square, RGBA.
const int _tileBytes = 64 * 64 * 4;

/// Eight tiles. Small on purpose -- see the first test.
const int _smallCap = 8 * _tileBytes;

/// The carry-over composite's size: `ceil(400 * 2) x ceil(300 * 2)` device
/// pixels of RGBA, from [kTileViewport] at [kTileDpr].
const int _compositeBytes = 800 * 600 * 4;

void main() {
  test('criterion 12: the cap holds and eviction is real, not theoretical',
      () async {
    // A cap of eight tiles at 64 device pixels: 8 * 64 * 64 * 4 = 131,072 B.
    // Small on purpose -- the point is that the policy runs, and a production
    // cap would need a corpus this suite cannot afford.
    final rig = TileRig(
        tileDevicePixels: 64, tilesBakedPerFrame: 1000, cacheBytes: 131072);
    addTearDown(rig.dispose);

    for (var i = 0; i < 6; i++) {
      rig.panBy(-64, -32);
      rig.paintOnce();
      expect(rig.cache.liveBytes, lessThanOrEqualTo(131072), reason: 'pan $i');
    }
    expect(rig.cache.evictionCount, greaterThan(0),
        reason: 'anti-degenerate clause 7: a cap nothing reaches is not a cap');
  });

  test('criterion 12: a pan back to reclaimed tiles draws live, not blank',
      () async {
    // Anti-degenerate clause 7. This is the failure that would ship as an
    // intermittent blank strip: no settled-frame criterion can see it.
    final rig = TileRig(
        tileDevicePixels: 64, tilesBakedPerFrame: 2, cacheBytes: 131072);
    addTearDown(rig.dispose);
    rig.paintOnce();
    for (var i = 0; i < 6; i++) {
      rig.panBy(-64, 0);
      rig.paintOnce();
    }
    rig.cache.resetCounters();
    for (var i = 0; i < 6; i++) {
      rig.panBy(64, 0);
      rig.paintOnce();
    }
    expect(rig.cache.liveDrawCount, greaterThan(0),
        reason: 'the camera returned to tiles the cap reclaimed');
  });

  test('criterion 13: allocation is viewport-bounded and the Paint is one',
      () async {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);
    rig.paintOnce();
    final paint = rig.cache.debugBlitPaint;
    rig.cache.resetCounters();
    rig.paintOnce();
    final first = rig.cache.blitDestinationCount;
    rig.cache.resetCounters();
    rig.paintOnce();

    expect(identical(rig.cache.debugBlitPaint, paint), isTrue);
    expect(rig.cache.blitDestinationCount, first,
        reason: 'two identical frames allocate the same number of rects: '
            'bounded by the viewport over the tile size, not by entity count');
    expect(first, lessThan(200),
        reason: 'a viewport quantity. If this grows with the document, the '
            'per-entity half of the rule is broken.');
  });

  // ---------------------------------------------------------------------
  // The three above are the brief's, verbatim. What follows is what asking
  // "what would have to break for this to fail, and is that the thing it
  // names?" of each of them turned up.
  // ---------------------------------------------------------------------

  test('criterion 13: and the destination count is a live reading, not a zero',
      () async {
    // **The instrument has to be able to produce the artefact.** Every
    // assertion criterion 13 makes above is satisfied by a counter that never
    // increments: `0 == 0` and `0 < 200`. A mutation deleting the increment on
    // the frame path leaves that test green, which was fired and confirmed.
    // This pins the count against a quantity the frame independently reports.
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);
    rig.paintOnce();
    rig.cache.resetCounters();
    rig.paintOnce();

    expect(rig.cache.blitDestinationCount, greaterThan(30),
        reason: 'anti-degenerate clause 3: a single-tile viewport would make '
            'every count in this file vacuous');
    expect(rig.cache.blitDestinationCount, rig.cache.blitCount,
        reason: 'a covered frame with no composite standing allocates exactly '
            'one destination per tile it blits');
  });

  test('criterion 12: liveBytes counts the composite, not only the tiles',
      () async {
    // **A cap that ignores the composite is not a cap**, and nothing above can
    // see whether this one does: the two cap tests only pan, so no generation
    // is ever retired and `_carryOver` stays null through every assertion they
    // make. Dropping the composite term from `liveBytes` leaves all three
    // green. That is trap 6 -- a shape absent from every fixture -- and this
    // is the fixture that contains it.
    //
    // The numbers are why it matters: one composite is worth 117 tiles at this
    // tile size, and on the reference viewport it is 29.3 MiB against a
    // generation's 38.5. `kTileCacheBytes` is 96 MiB rather than 64 for
    // exactly this reason.
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);

    rig.paintOnce();
    expect(rig.cache.hasCarryOver, isFalse,
        reason: 'setup: a pan-only history mints no composite, so the reading '
            'below is tiles alone');
    final tiles = rig.cache.liveTileCount;
    expect(tiles, greaterThan(30),
        reason: 'anti-degenerate clause 3: a single-tile viewport would make '
            'the arithmetic below vacuous');
    expect(rig.cache.liveBytes, tiles * _tileBytes);

    // The scale change retires the covered generation into a composite. The
    // budget is generous, so the incoming generation covers too and the
    // composite survives the frame that filled it -- `paintFrame` drops it
    // only when a covering frame baked nothing.
    rig.zoomBy(1.19);
    rig.paintOnce();
    expect(rig.cache.hasCarryOver, isTrue,
        reason: 'setup: the assertion below is about a standing composite, so '
            'the state has to exist. Without this the test would pass over a '
            'null one and prove nothing.');
    expect(rig.cache.liveBytes,
        rig.cache.liveTileCount * _tileBytes + _compositeBytes,
        reason: 'the composite is one viewport-sized image and it counts');
    expect(
        rig.cache.liveBytes, greaterThan(rig.cache.liveTileCount * _tileBytes),
        reason: 'and the term is not zero: an implementation that measured the '
            'composite as nothing would satisfy the equality above by '
            'accident if _compositeBytes were ever wrong');
  });

  test('criterion 12: eviction never reclaims a tile this frame blitted',
      () async {
    // **The thrash clause.** The visible set here is 130 tiles against a cap
    // of eight, so a policy without that guard evicts the tile it blitted two
    // iterations ago to bake the next one, walks the whole visible set doing
    // it, and arrives at the next frame with everything it needs already gone:
    // evict, rebake, evict, forever, with the frame path doing the evicting.
    // Nothing else in this file can see it -- `liveBytes` stays under the cap
    // either way, which is precisely what makes a cap test the wrong
    // instrument for it.
    final rig = TileRig(
        tileDevicePixels: 64, tilesBakedPerFrame: 1000, cacheBytes: _smallCap);
    addTearDown(rig.dispose);

    rig.paintOnce();
    expect(rig.cache.liveTileCount, 8,
        reason: 'setup: the cap is full, which is the state the guard is '
            'about. A frame that stopped short of it would never ask.');
    expect(rig.cache.blitDestinationCount, greaterThan(100),
        reason: 'setup: and the visible set is far larger than the cap, so '
            'the loop really does run out of room mid-frame');
    final evictionsAfterFill = rig.cache.evictionCount;

    // The same camera again. Every tile the cache holds is visible, so every
    // one of them is blitted before the loop reaches a key it cannot serve.
    rig.cache.resetCounters();
    rig.paintOnce();

    expect(rig.cache.bakeCount, 0,
        reason: 'a settled frame at the cap bakes nothing: the only tiles it '
            'could evict are the eight it just blitted');
    expect(rig.cache.evictionCount, evictionsAfterFill,
        reason: 'and reclaims nothing');
    expect(rig.cache.blitCount, 8, reason: 'it blits what it holds');
    expect(rig.cache.liveDrawCount, 1,
        reason: 'and pays one live walk for the rest, which is the bounded '
            'cost the guard trades the thrash for');
  });

  test('criterion 12: a frame at the cap still equals the live frame',
      () async {
    // **The blank strip, asserted rather than described.** The brief's
    // pan-back test above reads `liveDrawCount > 0`, and at a budget of two
    // tiles against a 130-tile viewport that is true on the very first frame,
    // before a single eviction: it cannot distinguish "the camera came back
    // over reclaimed tiles and the walk covered them" from "the budget never
    // covered anything". This is the same journey with the pixels compared.
    //
    // A blank strip where a reclaimed tile used to be shows up as
    // `uncoveredPixels`, which `expectTiledEqualsLive` requires to be zero
    // over a capture that is required to have real ink in it.
    final rig = TileRig(
        tileDevicePixels: 64, tilesBakedPerFrame: 2, cacheBytes: _smallCap);
    addTearDown(rig.dispose);

    rig.paintOnce();
    // Twelve tiles of travel against an eight-tile ring: the long-pan fixture
    // has to leave the retained set behind, or "reclaimed" names nothing.
    for (var i = 0; i < 6; i++) {
      rig.panBy(-64, 0);
      rig.paintOnce();
    }
    expect(rig.cache.evictionCount, greaterThan(0),
        reason: 'setup: the pan really did overrun the cap');
    expect(rig.cache.holds(const TileKey(0, 0)), isFalse,
        reason: 'setup: and the tile the first frame baked is gone');

    // Every key here is inside the end camera's visible rectangle -- the
    // anchor never moved, so that rectangle is x in 0..12, y in 0..9 -- and
    // each was held at the far end of the pan.
    final atFarEnd = <TileKey>[
      for (var x = 6; x <= 12; x++)
        if (rig.cache.holds(TileKey(x, 0))) TileKey(x, 0)
    ];
    expect(atFarEnd.length, greaterThan(2),
        reason: 'setup: there have to be tiles to come back to');

    for (var i = 0; i < 6; i++) {
      rig.panBy(64, 0);
      rig.paintOnce();
    }
    final reclaimed = atFarEnd.where((k) => !rig.cache.holds(k)).toList();
    expect(reclaimed, isNotEmpty,
        reason: 'setup: the camera is back over tiles the cap reclaimed on '
            'the way, which is the state the pixel comparison is about');
    expect(rig.cache.liveBytes, lessThanOrEqualTo(_smallCap));

    await expectTiledEqualsLive(rig);
  });

  test('criterion 12: eviction disposes what it reclaims', () async {
    // **No other instrument in this plan can see a leaked `ui.Image`.** An
    // image holds native memory past its Dart object, so a path that removes a
    // tile from the map without disposing it frees nothing while every counter
    // reports success: `liveTileCount` falls, `liveBytes` falls,
    // `evictionCount` rises. Eviction is where that compounds, because it is
    // the only reclaim path that runs every frame forever.
    final rig = TileRig(
        tileDevicePixels: 64, tilesBakedPerFrame: 1000, cacheBytes: _smallCap);
    addTearDown(rig.dispose);

    for (var i = 0; i < 6; i++) {
      rig.panBy(-64, -32);
      rig.paintOnce();
      expect(rig.cache.debugImagesAlive, rig.cache.liveTileCount,
          reason: 'pan $i: every image this cache created and did not dispose '
              'is a tile it can still blit');
    }
    expect(rig.cache.evictionCount, greaterThan(0),
        reason: 'setup: images were actually reclaimed, so the equality above '
            'is a statement about a disposal that happened');

    // And the composite is tracked too, so the same equality keeps meaning
    // "nothing leaked" once one stands.
    final zoomed = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(zoomed.dispose);
    zoomed.paintOnce();
    zoomed.zoomBy(1.19);
    zoomed.paintOnce();
    expect(zoomed.cache.hasCarryOver, isTrue, reason: 'setup');
    expect(zoomed.cache.debugImagesAlive, zoomed.cache.liveTileCount + 1);

    zoomed.cache.dispose();
    expect(zoomed.cache.debugImagesAlive, 0,
        reason: 'dispose releases every one of them');
  });
}
