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
/// **4.00x** its own area, because `kScreenClipInflate` is 32 *logical* pixels
/// and a 128 px tile is only 64 logical wide; 512 px costs 48.0 MiB and bakes
/// 1.56x. 1024 px is excluded outright — its 80.0 MiB visible set leaves no
/// room under [kTileCacheBytes] for the carry-over composite.
const int kTileDevicePixels = 256;

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
  final int tilesBakedPerFrame;
  final int cacheBytes;

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

  /// One `Paint` for the life of the cache.
  ///
  /// `FilterQuality.none`: every blit is a 1:1 texel-to-pixel copy by
  /// construction, so a filter has nothing to interpolate and would only cost
  /// a sampler. The carry-over path in Task 9 is the one exception and states
  /// its own.
  final Paint _blitPaint = Paint()..filterQuality = FilterQuality.none;

  int _bakes = 0;
  int _blits = 0;
  int _liveDraws = 0;
  int _generation = 0;
  int _invalidations = 0;

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

  int get generation => _generation;

  /// Tiles thrown away by [applyChange] over this cache's whole life.
  ///
  /// Not reset by [resetCounters], which zeroes the three per-frame counters:
  /// this one counts edits, not frames, and a caller reading it across a
  /// frame boundary is asking a different question.
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

  void resetCounters() {
    _bakes = 0;
    _blits = 0;
    _liveDraws = 0;
  }

  void paintFrame({
    required Canvas canvas,
    required Size viewport,
    required double devicePixelRatio,
    required ViewportTransform camera,
    required DraftPainter painter,
    required CanvasDrawSink sink,
    required VerticesDrawSink? vertices,
  }) {
    final quantised = quantiseCamera(camera, devicePixelRatio);
    final grid = _gridFor(quantised, devicePixelRatio);

    // Derived once and handed to every bake. Rebasing is frame-global by
    // construction; a per-tile origin would give each tile its own
    // quantisation step and `float32` residuals the live frame does not have.
    final origin = rebaseOriginFor(quantised.visibleWorld(viewport));

    var budget = tilesBakedPerFrame;
    Rect? uncovered;

    for (final key in grid.visibleKeys(quantised, viewport)) {
      var image = _tiles[key];
      if (image == null && budget > 0) {
        image = _bake(key, grid, painter, sink, vertices, origin);
        _tiles[key] = image;
        budget--;
      }
      final dest = grid.destRectFor(key, quantised);
      if (image == null) {
        uncovered = uncovered == null ? dest : uncovered.expandToInclude(dest);
        continue;
      }
      canvas.drawImageRect(image, _tileSourceRect, dest, _blitPaint);
      _blits++;
    }

    if (uncovered == null) return;
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

  Rect get _tileSourceRect => Rect.fromLTWH(
      0, 0, tileDevicePixels.toDouble(), tileDevicePixels.toDouble());

  TileGrid _gridFor(ViewportTransform quantised, double devicePixelRatio) {
    final grid = _grid;
    if (grid != null &&
        grid.devicePixelRatio == devicePixelRatio &&
        grid.tileDevicePixels == tileDevicePixels &&
        grid.matchesScale(quantised)) {
      return grid;
    }
    _retireGeneration();
    final fresh = TileGrid(
        anchor: quantised,
        devicePixelRatio: devicePixelRatio,
        tileDevicePixels: tileDevicePixels);
    _grid = fresh;
    _generation++;
    return fresh;
  }

  /// Drops the current generation's tiles. Task 9 gives this a carry-over.
  void _retireGeneration() {
    for (final image in _tiles.values) {
      image.dispose();
    }
    _tiles.clear();
    _baked.clear();
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
      _tiles.remove(key)?.dispose();
      _baked.remove(key);
      _invalidations++;
    }
  }

  /// Drops every tile and the lattice they were baked on.
  ///
  /// Task 9's carry-over composite is cleared here too: it is anchored to the
  /// grid that is about to go.
  void _dropEverything() {
    _dropGeneration();
    _grid = null;
  }

  /// Drops the tiles and **keeps the grid**, so the next frame rebakes into
  /// the same lattice rather than anchoring a new generation.
  ///
  /// A definition edit is not a scale change. Clearing `_grid` here would
  /// renumber every key for no reason, bump [generation], and throw away the
  /// one thing — the anchor — that lets the refilled tiles blit at whole
  /// device pixels against the cameras already on screen.
  void _dropGeneration() {
    _invalidations += _tiles.length;
    _retireGeneration();
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
  /// **The bound is geometric, not rasterised.** A bake's own index query is
  /// widened by the index's narrow-phase slack — half a stroke width and the
  /// like — so a tile whose bake drew a hairline spilling in from just outside
  /// its world rect is not found here. Direction one catches that case
  /// wherever the handle was already in the tile; what is left is a handle
  /// arriving at a position that misses a tile geometrically while its stroke
  /// clips into it, bounded by half the stroke width in world units. Recorded
  /// rather than papered over with an arbitrary inflation.
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

  /// The world-space box of tile [key] under [grid]'s anchor camera.
  ///
  /// **All four corners, not two.** `ViewportTransform.visibleWorld` documents
  /// the reason and this is the same inversion: under a rotated or skewed
  /// camera the axis-aligned box of two opposite corners omits world that is
  /// genuinely inside the tile, and the tiles it omits are the ones this
  /// method exists to condemn.
  Aabb2 _worldRectOf(TileKey key, TileGrid grid) {
    final side = grid._tileLogical;
    final left = key.x * side;
    final top = key.y * side;
    var box = Aabb2.empty();
    for (final p in <Vector2>[
      Vector2(left, top),
      Vector2(left + side, top),
      Vector2(left, top + side),
      Vector2(left + side, top + side),
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

    _drawInto(into, Size(side, side), grid.bakeCameraFor(key), painter, sink,
        vertices, origin, (handle) {
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
    visited.sort();
    _baked[key] = Uint32List.fromList(visited);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(tileDevicePixels, tileDevicePixels);
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
    _retireGeneration();
    _grid = null;
  }
}
