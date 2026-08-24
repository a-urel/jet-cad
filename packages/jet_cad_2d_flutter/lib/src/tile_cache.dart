import 'dart:typed_data';
import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2, Colors;

import 'camera_controller.dart';
import 'canvas_draw_sink.dart';
import 'draft_painter.dart';
import 'vertices_draw_sink.dart';
import 'viewport_transform.dart';

/// A tile's side, in **device** pixels.
///
/// 256 is a starting value with a measured shape behind it and a sweep still
/// owed. Memory and bake cost pull in opposite directions: at a `dpr` of 2 on a
/// 3200x2400 device viewport, 128 px costs 32.5 MiB of visible set but bakes
/// **4.00x** its own area, because [kTileSlack] is 32 *logical* pixels and a
/// 128 px tile is only 64 logical wide; 512 px costs 48.0 MiB and bakes 1.56x.
/// Those multipliers were a prediction when this was written and are the real
/// cost since Task 9a: the padded bake is what closed defect F1. 1024 px is
/// excluded outright — its 80.0 MiB visible set leaves no room under
/// [kTileCacheBytes] for the carry-over composite.
const int kTileDevicePixels = 256;

/// The slack a tile's **arrival** rule and its **invalidation** rule share, in
/// logical pixels.
///
/// **One constant, because they are one question asked from two sides.** A
/// stroke is wider than its geometry: an entity whose centreline sits just
/// outside a tile still inks pixels inside it. [DraftPainter] already knows
/// this and inflates its *screen clip* by [kScreenClipInflate] — "half the
/// widest stroke the frame can draw" in that constant's own words — but its
/// index query carries no slack at all, and on a full frame that costs
/// nothing because the missed entity is off-screen. A tile's edge is interior
/// to the drawing, and there the two halves diverge:
///
/// * **Arrival.** [_bake] passes the tile as the viewport, so an unpadded
///   query hands the painter nothing for a stroke whose centreline is 0.2
///   device pixels the wrong side of the seam. A clip only *keeps*; it cannot
///   return what the query never yielded, so the half of the stroke reaching
///   back into the tile was drawn by nobody. That was defect F1: six of
///   forty-one swept zoom factors lost a whole stroke column.
/// * **Invalidation.** Direction two condemned the tiles whose *exact* world
///   rect met a touched entity's *geometric* box, so the same stroke arriving
///   from just outside left a tile inked and unconditioned. That was accepted
///   gap G6.
///
/// Padding one alone makes them disagree: a tile's `_baked` record would list
/// entities whose geometry never entered it while the geometry that condemns
/// it stayed exact, and the arrival oracle would over-report against an
/// invalidation rule that under-condemns. So both use this, and the number is
/// [kScreenClipInflate] because that is the painter's *published* culling
/// slack — the amount of extra ink the frame is entitled to draw.
///
/// **What it costs.** Invalidation now over-drops by a ring: at the production
/// 256 device-pixel tile and a `dpr` of 2 the ring is a quarter of a tile
/// wide, and at the 64-pixel tile the tests use it is a whole tile. That is a
/// hit-rate cost, never a correctness one — a tile dropped that need not have
/// been is rebaked, a tile kept that should have been dropped is a visible
/// defect.
const double kTileSlack = kScreenClipInflate;

/// Tiles baked per frame while a generation fills in.
///
/// The settle after a zoom leaves the whole visible set stale, and baking it in
/// one frame is the ~60 ms stall this plan exists to remove, moved rather than
/// removed. At 256 px this covers a 154-tile visible set in twenty frames.
const int kTilesBakedPerFrame = 8;

/// The cache's byte ceiling, counting the carry-over composite and every
/// generation's tiles together.
///
/// 96 MiB, not 64, for two reasons. A retired generation lives on as one
/// viewport-sized composite (29.3 MiB on the reference viewport) beside the
/// incoming generation's tiles (38.5 MiB at 256 px). And 96 MiB is the figure
/// this cache may *replace*: the vertex buffer's high-water mark at 500,000
/// entities, which falls to a single tile's geometry once bakes flush per tile.
const int kTileCacheBytes = 96 * 1024 * 1024;

/// One tile's position in its generation's grid. Not world coordinates: the
/// grid is anchored to the generation's own device-pixel lattice.
@immutable
class TileKey {
  const TileKey(this.x, this.y);

  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is TileKey && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'TileKey($x, $y)';
}

/// Snaps a camera's screen translation to whole device pixels.
///
/// **This is the whole of Plan 3g's exactness claim, and it applies to the live
/// path too.** A world-anchored tile lands at a fractional device offset after
/// an arbitrary pan, and settling never returns the camera to the one the grid
/// was anchored at — the tile key excludes translation by design, and a pan is
/// required to invalidate nothing. Quantising both paths puts every tile
/// destination on whole device pixels at every camera, which is what lets the
/// tiled frame be required to equal the live frame with zero differing pixels.
///
/// The cost is up to half a device pixel of global position error, identical in
/// both paths and uniform across the frame. Nothing on screen provides a
/// reference against which it could read as jitter.
ViewportTransform quantiseCamera(
    ViewportTransform camera, double devicePixelRatio) {
  final m = camera.worldToScreenMatrix;
  final e = (m.e * devicePixelRatio).roundToDouble() / devicePixelRatio;
  final f = (m.f * devicePixelRatio).roundToDouble() / devicePixelRatio;
  // Returning the same instance matters: `ViewportTransform`'s constructor
  // inverts the matrix, and this runs once per frame on the frame path.
  if (e == m.e && f == m.f) return camera;
  return ViewportTransform(
      worldToScreenMatrix: Transform2(m.a, m.b, m.c, m.d, e, f));
}

/// One scale generation's lattice.
///
/// Tile `(x, y)` occupies device pixels `[x*T, (x+1)*T) x [y*T, (y+1)*T)` in
/// the **anchor's** screen space. A later camera at the same scale differs from
/// the anchor by a whole number of device pixels, so a tile's destination is
/// that rect plus an integral offset — never a resample.
@immutable
class TileGrid {
  const TileGrid({
    required this.anchor,
    required this.devicePixelRatio,
    required this.tileDevicePixels,
  });

  /// The quantised camera this generation was baked against.
  final ViewportTransform anchor;
  final double devicePixelRatio;
  final int tileDevicePixels;

  /// A tile's side in logical pixels.
  double get _tileLogical => tileDevicePixels / devicePixelRatio;

  /// **Exact, not tolerant.** Stored-value comparisons in this repository are
  /// exact `==`, and a tolerant test would replay a generation baked at a
  /// different stroke width and a different dash phase.
  bool matchesScale(ViewportTransform camera) {
    final a = anchor.worldToScreenMatrix;
    final b = camera.worldToScreenMatrix;
    return a.a == b.a && a.b == b.b && a.c == b.c && a.d == b.d;
  }

  /// How far [camera] sits from the anchor, in device pixels.
  ///
  /// Integral whenever both cameras came through [quantiseCamera], which is
  /// the invariant the whole grid rests on. `round` rather than a bare cast so
  /// a `0.9999999` from the division does not truncate to a one-pixel shift.
  (int, int) deviceDeltaFrom(ViewportTransform camera) {
    final a = anchor.worldToScreenMatrix;
    final b = camera.worldToScreenMatrix;
    return (
      ((b.e - a.e) * devicePixelRatio).round(),
      ((b.f - a.f) * devicePixelRatio).round(),
    );
  }

  /// Every key covering [viewport] at [camera], as a full rectangle.
  Iterable<TileKey> visibleKeys(ViewportTransform camera, Size viewport) sync* {
    final (dx, dy) = deviceDeltaFrom(camera);
    final left = -dx;
    final top = -dy;
    final right = left + (viewport.width * devicePixelRatio).ceil();
    final bottom = top + (viewport.height * devicePixelRatio).ceil();
    final x0 = _floorDiv(left, tileDevicePixels);
    final x1 = _floorDiv(right - 1, tileDevicePixels);
    final y0 = _floorDiv(top, tileDevicePixels);
    final y1 = _floorDiv(bottom - 1, tileDevicePixels);
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        yield TileKey(x, y);
      }
    }
  }

  /// The camera a bake uses, so the tile's top-left is the logical origin.
  ///
  /// Scale and skew come from the anchor untouched: the scale *is* the
  /// generation.
  ViewportTransform bakeCameraFor(TileKey key) {
    final m = anchor.worldToScreenMatrix;
    return ViewportTransform(
        worldToScreenMatrix: Transform2(m.a, m.b, m.c, m.d,
            m.e - key.x * _tileLogical, m.f - key.y * _tileLogical));
  }

  /// Where a tile blits, in logical pixels. Always a whole device pixel.
  Rect destRectFor(TileKey key, ViewportTransform camera) {
    final (dx, dy) = deviceDeltaFrom(camera);
    return Rect.fromLTWH(
      (key.x * tileDevicePixels + dx) / devicePixelRatio,
      (key.y * tileDevicePixels + dy) / devicePixelRatio,
      _tileLogical,
      _tileLogical,
    );
  }

  /// Floor division that stays correct for negative numerators.
  ///
  /// Dart's `~/` truncates toward zero, so `-1 ~/ 64` is `0` and the tile to
  /// the left of the origin would share a key with the tile at it. A pan in
  /// either direction reaches negative keys within one tile of the anchor.
  static int _floorDiv(int a, int b) => (a / b).floor();
}

/// A cache of rasterised viewport tiles.
///
/// **What it is for, in numbers.** Plan 3d's clean rows put a 500,000-entity
/// frame at 17.79 ms of build and 22.40 ms of raster — 40.27 ms of `totalSpan`
/// against a 16.67 ms budget. The 2026-08-23 spike's Probe D measured the same
/// frame drawn from a rasterised blit at **1.61 ms**, and the blit is
/// corpus-independent: 0.97 ms of raster at 50,000 entities and at 500,000
/// alike. The margin therefore widens with the drawing.
///
/// **What it is not for.** Rebaking every frame — the zoom regime — was
/// measured at 32.06 ms against the same 40.27, an 11-26% saving across the
/// two corpus sizes. This is a pan-and-settle optimisation and nothing else.
class TileCache {
  TileCache({
    this.tileDevicePixels = kTileDevicePixels,
    this.tilesBakedPerFrame = kTilesBakedPerFrame,
    this.cacheBytes = kTileCacheBytes,
  });

  final int tileDevicePixels;

  /// Tiles rasterised per frame while a generation fills in.
  ///
  /// **Not final, and the reason is a gate rather than a feature.** A cache
  /// constructed with a budget of zero never bakes a first generation, so it
  /// has nothing to retire, mints no composite, and reads zero on every
  /// counter — green for the one reason that makes the measurement worthless.
  /// The zoom-path tests warm a generation at a real budget and then take the
  /// budget away, so a frame that still puts the outgoing pixels on screen can
  /// only have blitted [_carryOver].
  int tilesBakedPerFrame;

  /// The byte ceiling, counting [liveBytes] whole.
  ///
  /// **Not final, and for [tilesBakedPerFrame]'s reason exactly.** A composite
  /// is minted only from a generation that *covered* the viewport, so any cap
  /// that permits one to exist is already larger than one composite -- 130
  /// tiles of coverage against a composite's 117 at the test tile size. The
  /// state "a composite stands and the ceiling is smaller than it" is
  /// therefore unreachable through the constructor, and it is the one state
  /// where `_makeRoomForOneTile`'s "bakes nothing rather than overrun" arm is
  /// the only thing running. Warming at a real ceiling and then taking it away
  /// is how a test reaches it, the same manoeuvre the zoom-path tests use on
  /// the bake budget.
  int cacheBytes;

  TileGrid? _grid;
  final Map<TileKey, Image> _tiles = <TileKey, Image>{};

  /// What each tile baked, ascending, for a binary search on change: every
  /// handle the painter visited, **and every container node above it**.
  ///
  /// **The node half is not a refinement.** `TransformNodeCommand` reports only
  /// the moved node's handle (`commands.dart:304`); the leaves it moved keep
  /// their own and appear nowhere in `touched`. A tile recording leaves alone
  /// cannot find the pixels a drag left behind.
  ///
  /// **And the painter alone does not supply the node half.**
  /// `DraftPainter.debugOnVisit` fires for leaves and for `InstanceNode`s, and
  /// both node call sites return early on `node is! InstanceNode`
  /// (`draft_painter.dart:401`, `:485`), so **a group handle never reaches it**
  /// — groups are flattened into their container's leaf list with a composed
  /// transform, and the group itself is never "descended into" as far as the
  /// callback is concerned. `TransformNodeCommand` takes a `GroupNode` as
  /// readily as an `InstanceNode` (`commands.dart:297-300`), so a record built
  /// from the callback alone loses every dragged group: direction one finds
  /// nothing, direction two drops the arrival tiles, and the departure tiles
  /// keep their pixels. That is why [_bake] walks each visited handle's owner
  /// chain and records it here rather than trusting the callback to be
  /// complete.
  ///
  /// Duplicates are left in. A handle drawn twice — the tree/overlay pair, or
  /// one definition placed twice inside one tile — costs one extra slot, and
  /// the binary search does not care. Deduplicating would be a sweep over a
  /// list that is already the right answer. The owner chain is the one
  /// exception, and only because the walk needs a visited set anyway to stay
  /// linear: an ancestor already recorded stops the climb.
  ///
  /// Keyed identically to [_tiles] at every point where either is observable:
  /// [_bake] writes here and its caller writes there, and nothing removes from
  /// one without removing from the other.
  final Map<TileKey, Uint32List> _baked = <TileKey, Uint32List>{};

  /// The frame ordinal each live tile was last blitted on. The LRU order.
  ///
  /// Keyed identically to [_tiles], like [_baked]: [paintFrame] writes here
  /// where it writes there, [_evict] and [_invalidateTouched] remove from both,
  /// and [_disposeTiles] clears both. A tile missing from here would be
  /// invisible to [_makeRoomForOneTile] and could never be reclaimed.
  ///
  /// **A parallel map rather than a reordered [_tiles].** The obvious LRU is
  /// to `remove` and re-insert on use, since Dart's `Map` iterates in
  /// insertion order — but that allocates a fresh entry per blit, every frame,
  /// on the frame path. Assigning to a key that is already present does not,
  /// and small integers are not boxed, so a warm frame's whole LRU bookkeeping
  /// allocates nothing at all.
  final Map<TileKey, int> _lastUsedFrame = <TileKey, int>{};

  /// [paintFrame] calls since construction, used only to order [_lastUsedFrame].
  ///
  /// Starts at zero and is incremented *before* anything reads it, so no tile
  /// can carry the current frame's ordinal before this frame put it there —
  /// which is what makes "not blitted this frame" a decidable question in
  /// [_makeRoomForOneTile].
  int _frameSerial = 0;

  /// One `Paint` for the life of the cache.
  ///
  /// `FilterQuality.none`: every blit is a 1:1 texel-to-pixel copy by
  /// construction, so a filter has nothing to interpolate and would only cost
  /// a sampler. The carry-over path in Task 9 is the one exception and states
  /// its own.
  final Paint _blitPaint = Paint()..filterQuality = FilterQuality.none;

  /// The retired generation, flattened to one viewport-sized image.
  ///
  /// **One image, not the old tiles.** [quantiseCamera] makes tile
  /// destinations exact only when they differ by whole multiples of the tile
  /// size, which holds at the generation's own scale and fails under an
  /// arbitrary zoom factor: snapped independently, adjacent scaled tiles leave
  /// a background gap or double-composite translucent ink along every shared
  /// edge. A composite has no internal edges. It also keeps the budget
  /// honest — two live generations do not fit under [kTileCacheBytes], and LRU
  /// would never reclaim the outgoing one because the frame path reads it
  /// every frame.
  ///
  /// **Never a resample of a resample.** A composite is minted only from a
  /// generation that covered the viewport ([_viewportCovered]), so a gesture
  /// frame — which anchors a fresh generation and bakes nothing into it —
  /// carries the *same* composite forward rather than re-flattening the
  /// already-scaled one. Eight gesture frames therefore filter the original
  /// pixels once, not eight times.
  Image? _carryOver;

  /// The screen space [_carryOver] was recorded in: the quantised camera of
  /// the last frame the retired generation covered.
  ///
  /// Not the grid's anchor. A generation outlives many pans, and the anchor
  /// describes the camera the *first* of them ran at — its viewport rectangle
  /// need not hold anything the user can currently see.
  ViewportTransform? _carryOverAnchor;

  /// [_carryOver]'s extent in [_carryOverAnchor]'s logical screen space.
  ///
  /// Kept rather than recomputed from `viewport` at blit time: the image's
  /// device size is a `ceil`, so the logical rectangle it stands for is a hair
  /// wider than the viewport, and the blit has to name the rectangle that was
  /// actually recorded or it rescales by that hair.
  Rect _carryOverRect = Rect.zero;

  /// **The one blit that is not a 1:1 texel-to-pixel copy, and the one that
  /// wants a filter.**
  ///
  /// Every tile blit lands on whole device pixels at its own scale, so
  /// [_blitPaint]'s `FilterQuality.none` has nothing to interpolate and a
  /// sampler would be pure cost. The carry-over is the opposite case by
  /// construction: it is replayed at a scale it was never rasterised at, at an
  /// arbitrary zoom factor and therefore at an arbitrary subpixel offset.
  /// Nearest-neighbour there is not "exact", it is aliasing — stroke rows
  /// dropped or doubled, and the drawing crawling as the factor sweeps.
  /// `FilterQuality.low` is bilinear, which is the right cost for pixels that
  /// are known to be stale and are about to be replaced by the settle.
  final Paint _carryOverPaint = Paint()..filterQuality = FilterQuality.low;

  /// Whether the previous frame's tiles covered the whole viewport.
  ///
  /// The precondition for minting a composite. A half-filled generation would
  /// flatten to an image that is transparent wherever it never baked, and
  /// blitting that in front of the live fallback would show a blank strip
  /// instead of a stale one.
  bool _viewportCovered = false;

  /// The quantised camera of the last [paintFrame].
  ViewportTransform? _lastCamera;

  int _bakes = 0;
  int _carryOverBlits = 0;
  int _blits = 0;
  int _liveDraws = 0;
  int _generation = 0;
  int _invalidations = 0;
  int _evictions = 0;
  int _blitDestinations = 0;
  int _imagesAlive = 0;

  /// `DocumentTables.mutationRevision` as of the last [paintFrame].
  ///
  /// **Negative before the first frame, and deliberately so.** A revision
  /// starts at zero and only ever increases, so no document can present this
  /// value and the first frame always takes the drop branch — over an empty
  /// cache, where it costs nothing and asserts nothing. A sentinel of `0`
  /// would instead make the first frame's behaviour depend on whether the
  /// document had been given its standard tables yet.
  int _tablesRevision = -1;

  /// Tiles rasterised since [resetCounters].
  int get bakeCount => _bakes;

  /// `drawImageRect` calls issued since [resetCounters].
  int get blitCount => _blits;

  /// Frames that fell back to a live walk for an uncovered region.
  ///
  /// **Not zero in normal operation**, and a design that expected it to be
  /// would ship an intermittent blank strip: the fallback fires on the first
  /// frame, on a pan past the retained ring, and after eviction reclaims tiles
  /// the camera returns to.
  int get liveDrawCount => _liveDraws;

  int get liveTileCount => _tiles.length;

  /// Every byte of native image memory this cache is holding open, against
  /// which [cacheBytes] is the ceiling.
  ///
  /// **The composite counts, and a cap that ignored it would not be a cap.**
  /// The carry-over is one *viewport-sized* image — 1.9 MB on the test
  /// viewport, 29.3 MiB on the reference one, whatever the tile size — so it
  /// is worth more than a hundred tiles on its own. [kTileCacheBytes] is 96
  /// MiB rather than 64 precisely because it has to hold a generation *and* a
  /// composite, and a `liveBytes` that summed only [_tiles] would report the
  /// cache using a third of what it really holds. Measured from the image's
  /// own `width` and `height` rather than from `viewport`, because the
  /// composite's device size is a `ceil` of the viewport and it outlives the
  /// camera it was recorded against.
  ///
  /// A tile is `tileDevicePixels` square, RGBA, one byte a channel: exactly
  /// what `Picture.toImageSync` allocates in [_bake].
  int get liveBytes {
    final carryOver = _carryOver;
    return _tiles.length * _tileBytes +
        (carryOver == null ? 0 : carryOver.width * carryOver.height * 4);
  }

  /// Tiles the ceiling reclaimed over this cache's whole life.
  ///
  /// Not reset by [resetCounters], for [invalidationCount]'s reason: this
  /// counts a cache-lifetime event, not a per-frame one. **Distinct from
  /// [invalidationCount] deliberately** — an invalidated tile held wrong
  /// pixels, an evicted one held perfectly good pixels there was no room for,
  /// and a test that could not tell them apart would read a thrashing cap as a
  /// busy editor.
  int get evictionCount => _evictions;

  /// Destination `Rect`s this frame computed for an image blit, since
  /// [resetCounters]. Criterion 13's per-frame allocation quantity.
  ///
  /// Counted at the point of allocation rather than at `drawImageRect`, which
  /// is the difference that makes it an allocation measurement: a visible tile
  /// the budget could not bake still costs its destination rect, and it is
  /// still bounded by the viewport over the tile size. The composite's
  /// destination counts too.
  ///
  /// **A field read, not a heap measurement.** `STATUS.md` records trap 5:
  /// there is no working Flutter-side allocation meter, and
  /// `paint_allocation_test.dart` reads one field —
  /// `VerticesDrawSink.debugCapacityVertices` — which can see neither a
  /// `Paint` nor a `Rect`. This is the `Rect` half, the same shape
  /// `VerticesDrawSink.debugPaint` uses for the other.
  int get blitDestinationCount => _blitDestinations;

  /// `ui.Image`s this cache has created and not yet disposed. Test-only.
  ///
  /// **The one instrument that can see a leaked image.** A `ui.Image` holds
  /// native memory past its Dart object, so a path that drops a tile from
  /// [_tiles] without disposing it frees nothing and no counter above would
  /// notice: [liveTileCount] falls, [liveBytes] falls, [evictionCount] rises,
  /// and the process grows. Eviction is where that mistake compounds, because
  /// it is the only path that runs *per frame* forever. Held equal to
  /// `liveTileCount + (hasCarryOver ? 1 : 0)` by construction, which is what a
  /// test asserts.
  int get debugImagesAlive => _imagesAlive;

  int get generation => _generation;

  /// Whether a retired generation is still standing in for the incoming one.
  bool get hasCarryOver => _carryOver != null;

  /// Composite blits issued since [resetCounters]. One per gesture frame.
  int get carryOverBlitCount => _carryOverBlits;

  /// Tiles thrown away by [applyChange], or by a table revision that moved,
  /// over this cache's whole life.
  ///
  /// Not reset by [resetCounters], which zeroes the three per-frame counters:
  /// this one counts edits, not frames, and a caller reading it across a
  /// frame boundary is asking a different question.
  ///
  /// The table arm is counted here rather than kept separate because it is the
  /// same event seen through a different door: a table mutation reaches no
  /// command and therefore no [DocChange], so [paintFrame] observes it as a
  /// revision instead of being told. What was invalidated is identical.
  int get invalidationCount => _invalidations;

  /// Whether [key] is currently blittable. Test-only.
  bool holds(TileKey key) => _tiles.containsKey(key);

  /// Every live tile whose bake touched [handle]. Test-only.
  List<TileKey> tilesHolding(Handle handle) => <TileKey>[
        for (final entry in _baked.entries)
          if (_contains(entry.value, handle.value)) entry.key
      ];

  /// The blit `Paint`'s identity, for criterion 13.
  ///
  /// Exposed the way `VerticesDrawSink.debugPaint` is, and for the same
  /// reason: `paint_allocation_test.dart` reads
  /// `VerticesDrawSink.debugCapacityVertices` and that field can see neither a
  /// `Paint` nor a `Rect`. `STATUS.md` records why there is no heap-level
  /// instrument on this side — trap 5 — so the allocation criterion is a field
  /// read or it is prose.
  Paint get debugBlitPaint => _blitPaint;

  /// The composite `Paint`'s identity, for the same criterion and the same
  /// reason as [debugBlitPaint].
  ///
  /// Exposed in this fix round because criterion 13's `SpyCanvas` test could
  /// not otherwise tell "the frame handed `drawImageRect` two long-lived
  /// fields" from "the frame allocated a `Paint` at the call site": with a
  /// composite standing there are legitimately two distinct `Paint` objects in
  /// one frame, and the old assertion — every call gets the *same* object —
  /// is false in that state rather than merely untested.
  Paint get debugCarryOverPaint => _carryOverPaint;

  void resetCounters() {
    _bakes = 0;
    _blits = 0;
    _liveDraws = 0;
    _carryOverBlits = 0;
    _blitDestinations = 0;
  }

  void paintFrame({
    required Canvas canvas,
    required Size viewport,
    required double devicePixelRatio,
    required ViewportTransform camera,
    required DraftPainter painter,
    required CanvasDrawSink sink,
    required VerticesDrawSink? vertices,
    required int tablesRevision,
  }) {
    // **A table edit arrives as a number, not as a change.** `TableSection`
    // mutates outside the command system, so `applyChange` never hears about a
    // layer colour, a lineweight or a linetype pattern — every one of which
    // every tile may have baked. It is pulled here, once per frame, so a
    // document mutated between two frames still invalidates.
    //
    // **The tiles go and the lattice stays**, for exactly the reason
    // `_dropGeneration` gives on a definition edit: a table edit is not a
    // scale change, the anchor still describes the camera on screen, and
    // clearing the grid would renumber every key and start a generation for
    // nothing. Dropping the whole generation rather than a subset is the same
    // trade too — a lineweight change moves a stroke's extent, so a tile that
    // never baked the entity can still owe pixels for it.
    if (tablesRevision != _tablesRevision) {
      _tablesRevision = tablesRevision;
      _dropGeneration();
    }

    // Before anything reads it, so no tile can be carrying this frame's
    // ordinal before this frame blits it. `_makeRoomForOneTile` rests on that.
    _frameSerial++;

    final quantised = quantiseCamera(camera, devicePixelRatio);
    // The viewport reaches `_gridFor` because retiring a generation is now a
    // composite and not just a `dispose`: the outgoing tiles have to be
    // flattened into one viewport-sized image *before* they go.
    final grid = _gridFor(quantised, devicePixelRatio, viewport);
    _lastCamera = quantised;

    // Derived once and handed to every bake. Rebasing is frame-global by
    // construction; a per-tile origin would give each tile its own
    // quantisation step and `float32` residuals the live frame does not have.
    final origin = rebaseOriginFor(quantised.visibleWorld(viewport));

    var budget = tilesBakedPerFrame;
    var baked = 0;
    Rect? uncovered;

    // **First, and underneath everything.** The composite is the outgoing
    // generation, so an incoming tile blitted on top of it must win, and a
    // live walk over an uncovered region must win too.
    var carryOverCovers = false;
    final carryOver = _carryOver;
    if (carryOver != null) {
      final dest = _carryOverDestRect(quantised);
      _blitDestinations++;
      canvas.drawImageRect(
          carryOver,
          Rect.fromLTWH(
              0, 0, carryOver.width.toDouble(), carryOver.height.toDouble()),
          dest,
          _carryOverPaint);
      _carryOverBlits++;
      // A zoom *in* magnifies the composite past the viewport's edges and
      // there is nothing left to fill; a zoom *out* shrinks it and leaves a
      // genuine ring the live fallback owes. Asserting the containment rather
      // than assuming the gesture's direction is the difference between a
      // cheap gesture and a blank border.
      carryOverCovers = dest.left <= 0 &&
          dest.top <= 0 &&
          dest.right >= viewport.width &&
          dest.bottom >= viewport.height;
    }

    for (final key in grid.visibleKeys(quantised, viewport)) {
      var image = _tiles[key];
      // **The ceiling is consulted before the bake, not after the frame.** A
      // small cap against a viewport of many tiles means the visible set alone
      // overruns it, so a sweep at the end of `paintFrame` would have nothing
      // left to reclaim -- every tile it could take was blitted this frame --
      // and `liveBytes` would settle wherever the visible set happened to put
      // it. Asking first makes the ceiling hold at every point inside the
      // frame as well as at its edges.
      if (image == null && budget > 0 && _makeRoomForOneTile()) {
        image = _bake(key, grid, painter, sink, vertices, origin);
        _tiles[key] = image;
        _lastUsedFrame[key] = _frameSerial;
        budget--;
        baked++;
      }
      final dest = grid.destRectFor(key, quantised);
      _blitDestinations++;
      if (image == null) {
        uncovered = uncovered == null ? dest : uncovered.expandToInclude(dest);
        continue;
      }
      // The recency the ceiling orders by, and the guard that stops a tile
      // this frame is using from being reclaimed later in the same loop.
      _lastUsedFrame[key] = _frameSerial;
      canvas.drawImageRect(image, _tileSourceRect, dest, _blitPaint);
      _blits++;
    }

    _viewportCovered = uncovered == null;
    if (uncovered == null) {
      // The incoming generation now covers every pixel the composite served,
      // so the composite is dead weight *and* a hazard: a tile's antialiased
      // edge is translucent, and `srcOver` over stale ink is not the same
      // pixel as `srcOver` over nothing. The next frame is a clean generation.
      //
      // **And not on the frame that finished the fill.** A generous budget
      // fills a whole generation in the frame that anchors it, so dropping on
      // coverage alone would mint a composite and destroy it inside one
      // `paintFrame` — unobservable from outside, and leaving the *next* scale
      // change of the same gesture with nothing to blit while its own
      // generation is still empty. Surviving the frame that filled it costs
      // one frame of stale ink under antialiased edges and buys a gesture that
      // never blanks.
      if (baked == 0) _dropCarryOver();
      return;
    }
    // Stale scaled pixels rather than a live walk, deliberately: replaying the
    // whole painter is the ~60 ms stall this cache exists to remove, and a
    // gesture frame is precisely where it must not happen.
    if (carryOverCovers) return;
    // One walk for the union, not one per tile: at 256 px a full visible set is
    // 154 tiles, and 154 painter invocations in one frame would be slower than
    // the live path this cache exists to replace. Clipped, so the covered tiles
    // keep the pixels they just blitted.
    canvas.save();
    canvas.clipRect(uncovered, doAntiAlias: false);
    _drawInto(
        canvas, viewport, quantised, painter, sink, vertices, origin, null);
    canvas.restore();
    _liveDraws++;
  }

  /// Every tile is the same square, so this is built once rather than per
  /// blit. It was a getter until Task 10, which allocated a fresh `Rect` on
  /// each of a frame's ~130 blits — bounded by the viewport, so never a rule
  /// break, but the wrong side of the criterion this task lands.
  late final Rect _tileSourceRect = Rect.fromLTWH(
      0, 0, tileDevicePixels.toDouble(), tileDevicePixels.toDouble());

  /// Bytes one tile's image occupies: RGBA, one byte a channel, exactly what
  /// `Picture.toImageSync` allocates in [_bake].
  int get _tileBytes => tileDevicePixels * tileDevicePixels * 4;

  /// Reclaims least-recently-blitted tiles until one more will fit under
  /// [cacheBytes], and reports whether it succeeded.
  ///
  /// **Never a tile this frame already blitted, and that guard is the whole
  /// difference between a cap and a thrash.** A viewport holds far more tiles
  /// than a small cap does, so without it the bake loop would evict the tile
  /// it blitted two iterations ago to make room for the next one, walk the
  /// entire visible set doing that, and arrive at the next frame with every
  /// tile it needs already gone — evict, rebake, evict, forever, with the
  /// frame path doing the evicting. With it, the loop simply runs out of room
  /// and leaves the remainder to the live fallback, which is a bounded cost.
  ///
  /// **"Blitted", not "visible": the guard is weaker than a first reading
  /// suggests, and deliberately.** A tile that is visible this frame but sits
  /// later in [TileGrid.visibleKeys] than the miss being served still carries
  /// the *previous* frame's serial, so it is a legal victim.
  ///
  /// **The bound, stated as the loop below actually behaves.** One call
  /// reclaims **every** held tile whose serial is older than this frame's,
  /// until either the ceiling admits one more tile or no such tile is left —
  /// not one, and not one per bake. The only quantity it is bounded by is the
  /// number of tiles this frame has not yet blitted, which is the whole cache
  /// at the first miss of a frame. Measured rather than reasoned: the
  /// sub-composite fixture in `tile_budget_test.dart` reads **119 evictions in
  /// a single frame**, because there the ceiling cannot admit a tile at all
  /// and the first miss empties everything the guard does not protect.
  ///
  /// What *is* exact is the guard itself: a tile already blitted this frame is
  /// never reclaimed, whatever the ceiling demands, which is what stops the
  /// evict-rebake-evict cycle above. And the case where on-screen tiles are
  /// taken needs a ceiling **below the visible set** to arise at all — at a
  /// `cacheBytes` that holds the working set, `bytes > ceiling` is false on
  /// entry and the loop never runs, so there is no eviction of any kind to
  /// choose a victim for.
  ///
  /// The cost is a hit rate, never a pixel. A victim taken before it is
  /// reached becomes an ordinary miss: rebaked if the budget allows, otherwise
  /// added to the frame's uncovered rectangle and drawn by the live fallback.
  /// That is the path `tile_budget_test.dart`'s pixel comparison at the cap
  /// exercises, and it reads zero differing pixels. Tightening the guard to
  /// *visible* would mean sweeping `visibleKeys` once more before the bake
  /// loop to mark the whole visible set, on every warm frame, to buy back
  /// bakes only on frames that were already overrunning. Not worth a second
  /// pass over the frame path.
  ///
  /// **The composite is never a candidate.** It is not in [_tiles] at all, and
  /// deliberately: [paintFrame] reads it every frame it stands, so a
  /// recency-ordered policy would never choose it anyway, and reclaiming it
  /// would replace stale pixels with blank ones. It still *counts* against the
  /// ceiling through [liveBytes] — so a cap smaller than one composite simply
  /// bakes nothing, which is the honest answer rather than a silent overrun.
  ///
  /// Returning `false` rather than baking anyway is what keeps [liveBytes] a
  /// ceiling and not a suggestion.
  bool _makeRoomForOneTile() {
    // Computed from `liveBytes` so the composite is counted, then tracked
    // locally: the loop's only effect on it is one tile's worth per eviction.
    var bytes = liveBytes;
    final ceiling = cacheBytes - _tileBytes;
    while (bytes > ceiling) {
      TileKey? victim;
      var oldest = 0;
      // A linear scan, not a heap. This runs only when the cache is full, the
      // map it walks is bounded by the ceiling itself, and a priority queue
      // would need per-blit maintenance on the frame path to save a scan that
      // a warm frame never performs.
      for (final entry in _lastUsedFrame.entries) {
        if (entry.value == _frameSerial) continue;
        if (victim == null || entry.value < oldest) {
          victim = entry.key;
          oldest = entry.value;
        }
      }
      if (victim == null) return false;
      _evict(victim);
      bytes -= _tileBytes;
    }
    return true;
  }

  /// Reclaims one tile: its image, its bake record and its recency, together.
  void _evict(TileKey key) {
    _disposeImage(_tiles.remove(key));
    _baked.remove(key);
    _lastUsedFrame.remove(key);
    _evictions++;
  }

  /// The single door every `ui.Image` this cache owns leaves by, so
  /// [debugImagesAlive] can see one that never does.
  void _disposeImage(Image? image) {
    if (image == null) return;
    image.dispose();
    _imagesAlive--;
  }

  /// Where [_carryOver] lands under [camera].
  ///
  /// **Through the world, not through a scale ratio.** The composite's
  /// rectangle is mapped out of [_carryOverAnchor]'s screen space into world
  /// space and back in through the new camera, so a camera that also panned,
  /// flipped or skewed between the two frames is carried correctly instead of
  /// being assumed away. Two opposite corners suffice: the transform between
  /// two cameras that differ in scale is axis-preserving, and a rotation
  /// between them would need a `transform` rather than a `Rect` on either
  /// reading. `Rect.fromPoints` normalises, which a y-flipped camera needs.
  ///
  /// **This one is not snapped.** Every other destination in this file is
  /// rounded onto the device-pixel lattice because the copy is 1:1 and must be
  /// exact. Here the source is stale by construction and the destination is a
  /// fractional multiple of it; snapping would buy nothing and would make the
  /// drawing jump by a pixel as the zoom factor swept.
  Rect _carryOverDestRect(ViewportTransform camera) {
    final anchor = _carryOverAnchor!;
    final r = _carryOverRect;
    final topLeft =
        camera.worldToScreen(anchor.screenToWorld(Vector2(r.left, r.top)));
    final bottomRight =
        camera.worldToScreen(anchor.screenToWorld(Vector2(r.right, r.bottom)));
    return Rect.fromPoints(
        Offset(topLeft.x, topLeft.y), Offset(bottomRight.x, bottomRight.y));
  }

  TileGrid _gridFor(
      ViewportTransform quantised, double devicePixelRatio, Size viewport) {
    final grid = _grid;
    if (grid != null &&
        grid.devicePixelRatio == devicePixelRatio &&
        grid.tileDevicePixels == tileDevicePixels &&
        grid.matchesScale(quantised)) {
      return grid;
    }
    _retireGeneration(viewport);
    final fresh = TileGrid(
        anchor: quantised,
        devicePixelRatio: devicePixelRatio,
        tileDevicePixels: tileDevicePixels);
    _grid = fresh;
    _generation++;
    return fresh;
  }

  /// Flattens the outgoing generation into [_carryOver], then drops its tiles.
  ///
  /// **Only reached from [_gridFor]**, which is the only place a *scale*
  /// changes. `_dropGeneration` throws tiles away for a definition or a table
  /// edit, and those tiles hold wrong pixels rather than stale ones:
  /// compositing them would put the pre-edit colour back on screen for the
  /// whole of the refill, with `liveTileCount` reading zero the entire time.
  ///
  /// **Three guards, and each of them is a different way to mint nonsense.**
  /// No grid or no camera is the first frame, where there is nothing to
  /// flatten. No tiles is a gesture frame, whose fresh generation baked
  /// nothing — and there the *existing* composite is kept, which is what stops
  /// a sweep of the zoom factor filtering the same pixels once per frame.
  /// [_viewportCovered] is the half-filled generation: flattened, it is
  /// transparent wherever it never baked, and a transparent composite in front
  /// of the live fallback is a blank strip rather than a stale one.
  void _retireGeneration(Size viewport) {
    final grid = _grid;
    final camera = _lastCamera;
    if (grid != null &&
        camera != null &&
        _viewportCovered &&
        _tiles.isNotEmpty) {
      final dpr = grid.devicePixelRatio;
      final width = (viewport.width * dpr).ceil();
      final height = (viewport.height * dpr).ceil();
      final rect = Rect.fromLTWH(0, 0, width / dpr, height / dpr);
      final recorder = PictureRecorder();
      final into = Canvas(recorder);
      into.scale(dpr);
      // Hard, for `_bake`'s reason: an antialiased clip edge would leave the
      // composite's own border at partial coverage.
      into.clipRect(rect, doAntiAlias: false);
      // Recorded against the *last* camera, so the composite is a picture of
      // what the user was actually looking at rather than of the anchor's
      // viewport, which many pans ago may have left the screen entirely.
      for (final key in grid.visibleKeys(camera, viewport)) {
        final image = _tiles[key];
        if (image == null) continue;
        into.drawImageRect(
            image, _tileSourceRect, grid.destRectFor(key, camera), _blitPaint);
      }
      final picture = recorder.endRecording();
      // The old composite goes first: it was fully hidden by the generation
      // being retired -- that is what `_viewportCovered` means -- and it holds
      // native memory past its Dart object.
      _dropCarryOver();
      _carryOver = picture.toImageSync(width, height);
      _imagesAlive++;
      _carryOverAnchor = camera;
      _carryOverRect = rect;
      picture.dispose();
    }
    _disposeTiles();
  }

  /// Disposes every tile image and forgets what they baked.
  ///
  /// Clears [_viewportCovered] with them: coverage is a statement about tiles
  /// that exist, and leaving it standing would let the *next* scale change
  /// composite an empty generation.
  void _disposeTiles() {
    for (final image in _tiles.values) {
      _disposeImage(image);
    }
    _tiles.clear();
    _baked.clear();
    _lastUsedFrame.clear();
    _viewportCovered = false;
  }

  /// Releases the composite's native memory. Idempotent.
  void _dropCarryOver() {
    _disposeImage(_carryOver);
    _carryOver = null;
    _carryOverAnchor = null;
    _carryOverRect = Rect.zero;
  }

  /// Throws away whatever [change] made stale.
  ///
  /// **All five subclasses, exhaustively.** `DocChange` has five and five
  /// emitters — `CommandApplied` (`undo.dart:112`), `CommandUndone` (`:140`),
  /// `CommandRedone` (`:161`), `DocumentLoaded` (`:169`) and `DocumentPurged`
  /// (`:178`). A cache that handles apply and undo and forgets redo shows
  /// stale pixels after every redo while passing an undo-only gate. The switch
  /// is written without a default so that a sixth subclass is a compile error
  /// here rather than a silent omission, which is what
  /// `SpatialIndex._onChange` does with the same stream.
  void applyChange(DocChange change, DraftDocument document) {
    // **Every arm, before the switch even runs.** `_dropGeneration` covers the
    // definition arm and the table revision `paintFrame` reads for itself, but
    // `_invalidateTouched`'s ordinary per-tile path removes tiles one at a
    // time and never reaches it — so a leaf edit would leave the composite
    // standing, and a composite covering the viewport suppresses the live
    // fallback that would have repainted. Hoisted above the switch rather than
    // repeated in each case for the reason the switch itself is exhaustive: a
    // sixth `DocChange` subclass must not be able to arrive without this.
    _dropCarryOver();
    switch (change) {
      // A purge rewrites the entity store's slots wholesale and a load
      // replaces the document; neither leaves anything worth keeping, and
      // neither leaves the anchor camera meaning what it meant.
      case DocumentLoaded():
      case DocumentPurged():
        _dropEverything();
      case CommandApplied(:final touched):
      case CommandUndone(:final touched):
      case CommandRedone(:final touched):
        if (touched.isEmpty) {
          // `DocChange.touched` is documented as empty when the whole document
          // changed (`doc_change.dart:11-12`).
          _dropEverything();
          return;
        }
        _invalidateTouched(touched, document);
    }
  }

  void _invalidateTouched(Set<Handle> touched, DraftDocument document) {
    // **A definition edit drops the generation.** If a tile baked a definition
    // and that definition changed, every instance of it in that tile changed,
    // so invalidation by definition is exact at tile granularity. The one case
    // it does not cover — a definition whose content bounds grew, spilling an
    // instance into a tile that never baked it — is why this is a generation
    // drop rather than a per-tile pass. A definition edit is a block edit, not
    // ordinary drawing.
    for (final handle in touched) {
      if (_isDefinitionOwned(document, handle)) {
        _dropGeneration();
        return;
      }
    }

    final grid = _grid;
    if (grid == null) return;
    final doomed = <TileKey>{};

    // Direction one: the old position. `DocChange` carries no previous
    // geometry, and this is why each tile records what it baked.
    for (final entry in _baked.entries) {
      for (final handle in touched) {
        if (_contains(entry.value, handle.value)) {
          doomed.add(entry.key);
          break;
        }
      }
    }

    // Direction two: the new position. Both are needed, for the reason
    // `_letBoundRecede` exists in the index — a handle that moved *out* of a
    // tile is only findable from the tile's record, and a handle that moved
    // *into* one appears in no record at all.
    //
    // The boxes are derived once, ahead of the tile sweep, rather than once
    // per (handle, tile) pair: `_worldBoxOf` reads the entity store and may
    // walk a definition, and `touched` is small while the tile set is not.
    final boxes = <Aabb2>[];
    // Derived at most once per change, and only when a node handle is actually
    // in `touched`. `DraftDocument.definitionBounds` recomputes this map on
    // every call it is not given one, and that is a full entity-store scan —
    // `draft_document.dart:160-175` says so in as many words, and records the
    // benchmark where not threading it cost seconds. Without this, invalidation
    // would be O(live entities) *per touched node handle*.
    Map<Handle, List<int>>? leavesByOwner;
    for (final handle in touched) {
      if (leavesByOwner == null && document.tree[handle] != null) {
        leavesByOwner = document.leavesByOwner();
      }
      final box = _worldBoxOf(document, handle, leavesByOwner);
      if (box != null && !box.isEmpty) boxes.add(box);
    }
    if (boxes.isNotEmpty) {
      for (final key in _baked.keys) {
        if (doomed.contains(key)) continue;
        final rect = _worldRectOf(key, grid);
        for (final box in boxes) {
          if (rect.intersects(box)) {
            doomed.add(key);
            break;
          }
        }
      }
    }

    for (final key in doomed) {
      _disposeImage(_tiles.remove(key));
      _baked.remove(key);
      // Keyed identically to `_tiles`: a recency left behind here would name a
      // tile that no longer exists, and `_makeRoomForOneTile` would pick it as
      // its victim and free nothing.
      _lastUsedFrame.remove(key);
      _invalidations++;
    }
  }

  /// Drops every tile and the lattice they were baked on.
  ///
  /// The carry-over composite is cleared here too — not uniquely, since
  /// [_dropGeneration] and [applyChange]'s hoisted call clear it as well; the
  /// call below is redundant with the one [_dropGeneration] already makes and
  /// is kept because this method's contract is "nothing survives", not
  /// "whatever the callee happens to do". It is anchored to a camera over a
  /// document that no longer exists, so replaying it would show the previous
  /// drawing scaled over the new one — and it holds native memory nothing else
  /// would release.
  void _dropEverything() {
    _dropGeneration();
    _dropCarryOver();
    _grid = null;
    _lastCamera = null;
  }

  /// Drops the tiles and **keeps the grid**, so the next frame rebakes into
  /// the same lattice rather than anchoring a new generation.
  ///
  /// A definition edit is not a scale change. Clearing `_grid` here would
  /// renumber every key for no reason, bump [generation], and throw away the
  /// one thing — the anchor — that lets the refilled tiles blit at whole
  /// device pixels against the cameras already on screen.
  /// **And mints no carry-over.** [_retireGeneration] is the scale path; this
  /// one runs for a definition or a table edit, whose tiles are wrong rather
  /// than merely stale.
  ///
  /// **It destroys one, though, and that is not symmetry — it is the whole of
  /// finding C1.** A composite is a picture of the document *before* the
  /// edit, and [paintFrame] suppresses the live fallback outright whenever the
  /// composite covers the viewport. An edit landing while one stands therefore
  /// produced a frame that was nothing but pre-edit pixels, and kept producing
  /// it: measured at `hasCarryOver=true, liveTileCount=0, liveDrawCount=0,
  /// carryOverBlitCount=1` on the frame after a layer edit, and still
  /// `liveDrawCount=0` eleven frames later — at a *real* bake budget too,
  /// where the un-refilled remainder of the viewport showed the old colour for
  /// the whole of the settle. Nothing else on this path would ever have
  /// cleared it: the composite is not a tile, so [liveTileCount] read zero the
  /// entire time and every invalidation gate in this plan stayed green.
  void _dropGeneration() {
    _invalidations += _tiles.length;
    _disposeTiles();
    _dropCarryOver();
  }

  /// Whether [handle] draws inside a block definition rather than at the
  /// document root.
  ///
  /// **Not "is it owned by the root".** A leaf owned by a group is neither
  /// root-owned nor definition-owned, and groups draw at root level, so the
  /// test has to be for a definition. The walk climbs owners because a leaf
  /// may sit under a group that is itself inside a definition, in which case
  /// its own owner names no definition at all.
  bool _isDefinitionOwned(DraftDocument document, Handle handle) {
    final slot = document.entities.slotOf(handle);
    if (slot != null) {
      return _enclosingDefinition(
              document.tree, document.entities.ownerAt(slot)) !=
          null;
    }
    if (document.tree[handle] == null) return false;
    return _enclosingDefinition(document.tree, handle) != null;
  }

  /// The definition [container] sits inside, or null if it sits at the root.
  ///
  /// `DocumentTree.ancestorsOf` walks `parent` while the parent is a *node*,
  /// and a definition handle lives in the definition map rather than the node
  /// map — so a definition never appears in the chain it returns. The
  /// definition, when there is one, is therefore the `parent` of the chain's
  /// last element, and that is the one place worth looking.
  ///
  /// **The climb past the first line is what handles a node nested inside a
  /// prototype**, where [container] names neither a definition nor anything
  /// whose own parent is one: a group inside a definition owning a leaf, and
  /// an instance inside a definition placing another. `nestedFixture` in
  /// `tile_invalidation_test.dart` builds both, and reducing this method to
  /// its first line reddens that test on each. Nothing else in the repository
  /// has that shape — `differentialFixture`'s `Handle(520)` is an
  /// `InstanceNode` parented directly to the definition `outer`
  /// (`fixtures.dart:88-97`), which the chain's own
  /// `chain.isEmpty ? container : chain.last` already resolves.
  static Handle? _enclosingDefinition(DocumentTree tree, Handle container) {
    if (tree.definition(container) != null) return container;
    if (tree[container] == null) return null;
    final chain = tree.ancestorsOf(container);
    final top = chain.isEmpty ? container : chain.last;
    final parent = tree[top]!.parent;
    return tree.definition(parent) != null ? parent : null;
  }

  /// Where [handle] draws **now**, in world coordinates, or null if it draws
  /// nothing.
  ///
  /// Only ever called for handles [_isDefinitionOwned] has already rejected,
  /// so the enclosing space is the document root and the accumulated transform
  /// of the owner is the whole of the placement.
  ///
  /// **The bound is geometric, not rasterised, and that is why the *tile* box
  /// is the padded one.** A stroke puts ink up to half its width beyond this
  /// box, so a handle arriving at a position that misses a tile geometrically
  /// can still clip into it — accepted gap G6, until Task 9a. The remedy is
  /// not here: inflating this box by a resolved lineweight would need the
  /// style resolution the caller does not have, and would be a *different*
  /// number from the one [_bake] queries with. [_worldRectOf] grows the tile
  /// instead, by [kTileSlack], which is the same slack the bake uses — so the
  /// record of what a tile holds and the geometry that condemns it are one
  /// rectangle rather than two that nearly agree.
  Aabb2? _worldBoxOf(DraftDocument document, Handle handle,
      Map<Handle, List<int>>? leavesByOwner) {
    final tree = document.tree;
    final node = tree[handle];
    if (node != null) {
      // `definitionBounds` is the public spelling of "union of everything a
      // container holds, in its own space", and it takes a group handle as
      // readily as a definition handle (`draft_document.dart:241-242`). An
      // instance handle is the one thing it does *not* resolve — it holds no
      // leaves and lists no children of its own — so the definition is named
      // explicitly here.
      final content = switch (node) {
        InstanceNode(:final definition) =>
          document.definitionBounds(definition, leavesByOwner),
        GroupNode() => document.definitionBounds(handle, leavesByOwner),
      };
      if (content.isEmpty) return null;
      return content.transformedBy(tree.accumulatedTransform(handle));
    }
    final slot = document.entities.slotOf(handle);
    if (slot == null) return null; // deleted, or never a drawable at all
    final record = document.entities.read(slot);
    final payload = document.geometry.read(record.geomIndex);
    // A fill's own payload names a boundary rather than carrying coordinates,
    // so its bound is the boundary's. Copied from `container_index.dart:99-114`
    // — the same boundary case, resolved the same way.
    EntityKind? boundaryKind;
    GeometryPayload? boundaryPayload;
    if (record.kind == EntityKind.fill) {
      final b = document.entities.slotOf(boundaryHandleOf(payload));
      if (b != null) {
        boundaryKind = document.entities.kindAt(b);
        boundaryPayload =
            document.geometry.read(document.entities.geomIndexAt(b));
      }
    }
    final box = entityBounds(
      kind: record.kind,
      payload: payload,
      measurer: document.textMeasurer,
      textStyle: document.textStyleOf(record.textStyle),
      textAttrs: record.textAttrs,
      text: record.text,
      boundaryKind: boundaryKind,
      boundaryPayload: boundaryPayload,
    );
    if (box.isEmpty) return null;
    return box.transformedBy(
        tree.accumulatedTransform(document.entities.ownerAt(slot)));
  }

  /// The world-space box tile [key] can hold ink from, under [grid]'s anchor
  /// camera: its own rectangle grown by [kTileSlack] on every side.
  ///
  /// **The slack is the same one [_bake] queries with, and that is the point.**
  /// A tile's `_baked` record lists what the padded query yielded; this is the
  /// geometry that condemns the tile. Inflate one and not the other and the
  /// two halves of invalidation disagree by a ring — direction one drops tiles
  /// whose record names a handle that direction two's box does not reach, and
  /// a stroke arriving from just outside a tile leaves it stale. [kTileSlack]
  /// carries the whole argument.
  ///
  /// **Grown in screen space, not in world units.** The pad is a fact about
  /// stroke widths, which are a screen-space quantity, so it is applied to the
  /// tile rectangle before the inversion. Adding a world-space margin
  /// afterwards would be the wrong size by the camera's scale, and by
  /// different amounts on the two axes under an anisotropic one.
  ///
  /// **All four corners, not two.** `ViewportTransform.visibleWorld` documents
  /// the reason and this is the same inversion: under a rotated or skewed
  /// camera the axis-aligned box of two opposite corners omits world that is
  /// genuinely inside the tile, and the tiles it omits are the ones this
  /// method exists to condemn.
  Aabb2 _worldRectOf(TileKey key, TileGrid grid) {
    const pad = kTileSlack;
    final side = grid._tileLogical;
    final left = key.x * side - pad;
    final top = key.y * side - pad;
    final span = side + 2 * pad;
    var box = Aabb2.empty();
    for (final p in <Vector2>[
      Vector2(left, top),
      Vector2(left + span, top),
      Vector2(left, top + span),
      Vector2(left + span, top + span),
    ]) {
      box = box.expandedToPoint(grid.anchor.screenToWorld(p));
    }
    return box;
  }

  /// Binary search over an ascending, possibly repeating, handle list.
  static bool _contains(Uint32List sorted, int value) {
    var lo = 0, hi = sorted.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final at = sorted[mid];
      if (at == value) return true;
      if (at < value) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return false;
  }

  Image _bake(
    TileKey key,
    TileGrid grid,
    DraftPainter painter,
    CanvasDrawSink sink,
    VerticesDrawSink? vertices,
    Vector2 origin,
  ) {
    final side = tileDevicePixels / grid.devicePixelRatio;
    final recorder = PictureRecorder();
    final into = Canvas(recorder);
    into.scale(grid.devicePixelRatio);
    // **A hard clip on the pixel grid, and the flag is the point.** An entity
    // crossing a tile boundary is drawn into both tiles. If the clip edge were
    // antialiased, each tile would contribute partial coverage along the shared
    // edge and their `source-over` would not reach full coverage: a seam. A
    // hard clip is exact for strokes, fills and glyphs alike, because the
    // geometry's own rasterisation is untouched and each tile keeps exactly
    // the pixels it owns.
    into.clipRect(Rect.fromLTWH(0, 0, side, side), doAntiAlias: false);
    // The one place the frame path allocates per entity — and a bake is not a
    // steady-state frame. `onVisit` is null at the only other call into
    // `_drawInto`, the live fallback in `paintFrame`, so a warm frame that
    // blits and bakes nothing never grows this list at all.
    final visited = <int>[];
    // Container nodes already recorded on this tile. Both a memo and the
    // termination guard: once a node is in, every ancestor of it is in too, so
    // the climb stops there — which is what keeps the whole pass linear in
    // visits rather than O(visits x depth), and what makes a malformed cyclic
    // parent chain terminate instead of hanging the bake.
    final containers = <int>{};
    final document = painter.document;

    void recordOwners(Handle from) {
      var current = from;
      while (true) {
        final node = document.tree[current];
        // A definition handle lives outside the node map, and a definition is
        // not a placement: an edit inside one takes the generation-drop path
        // and never consults this list.
        if (node == null) return;
        if (!containers.add(current.value)) return;
        visited.add(current.value);
        if (node.parent.isNone) return;
        current = node.parent;
      }
    }

    // **The query is padded; the clip is not.** [kTileSlack] is why: the tile
    // keeps exactly the pixels it owns (the hard clip above is untouched) but
    // the painter is asked about a rectangle [kTileSlack] logical pixels
    // larger on every side, so a stroke whose centreline is just outside still
    // reaches the sink and contributes the part of itself that falls inside.
    // The canvas is pulled back by the same amount, so the padded viewport's
    // origin lands where the tile's origin was.
    const pad = kTileSlack;
    final bake = grid.bakeCameraFor(key).worldToScreenMatrix;
    into.save();
    into.translate(-pad, -pad);
    _drawInto(
        into,
        Size(side + 2 * pad, side + 2 * pad),
        ViewportTransform(
            worldToScreenMatrix: Transform2(
                bake.a, bake.b, bake.c, bake.d, bake.e + pad, bake.f + pad)),
        painter,
        sink,
        vertices,
        origin, (handle) {
      visited.add(handle.value);
      final slot = document.entities.slotOf(handle);
      if (slot != null) {
        // A leaf names its container by owner; the root is a `GroupNode` like
        // any other and is recorded too, so a transform of the root reaches
        // every tile through direction one.
        recordOwners(document.entities.ownerAt(slot));
        return;
      }
      // An instance node the painter descended into: it is already recorded
      // above, and what is missing is the groups it hangs under.
      final node = document.tree[handle];
      if (node != null && !node.parent.isNone) recordOwners(node.parent);
    });
    into.restore();
    visited.sort();
    _baked[key] = Uint32List.fromList(visited);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(tileDevicePixels, tileDevicePixels);
    _imagesAlive++;
    picture.dispose();
    _bakes++;
    return image;
  }

  void _drawInto(
    Canvas canvas,
    Size size,
    ViewportTransform camera,
    DraftPainter painter,
    CanvasDrawSink sink,
    VerticesDrawSink? vertices,
    Vector2 origin,
    void Function(Handle handle)? onVisit,
  ) {
    painter.debugRebaseOrigin = origin;
    painter.debugOnVisit = onVisit;
    try {
      sink.canvas = canvas;
      if (vertices == null) {
        painter.paint(sink, camera, size);
        return;
      }
      vertices.canvas = canvas;
      painter.paint(vertices, camera, size);
      // The flush is here for the reason `_DraftCustomPainter` puts it there:
      // it is a fact about this sink, not about the walk.
      vertices.flush();
    } finally {
      // Restored even on a throw: a painter left with a stale origin would
      // draw the *next* frame against a tile's rebase point.
      painter.debugRebaseOrigin = null;
      painter.debugOnVisit = null;
    }
  }

  void dispose() {
    _disposeTiles();
    _dropCarryOver();
    _grid = null;
    _lastCamera = null;
  }
}
