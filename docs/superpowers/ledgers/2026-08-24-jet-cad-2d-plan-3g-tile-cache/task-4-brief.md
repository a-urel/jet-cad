## Task 4: `TileCache` bakes and blits, and draws live where it cannot

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- Test: `packages/jet_cad_2d_flutter/test/tile_cache_test.dart` (create — the criteria land in Task 5; this task's tests are structural)

**Interfaces:**
- Consumes: `TileGrid`, `quantiseCamera`, `DraftPainter.debugRebaseOrigin`.
- Produces: `TileCache.paintFrame`, `TileCache.bakeCount`, `blitCount`, `liveDrawCount`, `liveTileCount`, `debugBlitPaint`, `dispose`.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d_flutter/test/tile_cache_test.dart` with the structural half only:

```dart
// What the cache does, counted. Criteria 1-4 arrive in Tasks 5 and 6 and
// compare pixels; these three ask whether the machine ran at all, which is
// what makes a later zero-difference result mean something rather than
// meaning nothing was drawn -- the trap the 3g spike walked into with Probe C.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/tile_fixture.dart';

void main() {
  test('a first frame bakes up to its budget and draws the rest live',
      () async {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 3);
    addTearDown(rig.dispose);

    rig.paintOnce();

    expect(rig.cache.bakeCount, 3, reason: 'the budget, not the visible set');
    expect(rig.cache.blitCount, 3, reason: 'what was baked is what blitted');
    expect(rig.cache.liveDrawCount, 1,
        reason: 'one walk for the union of the uncovered rects, not one per '
            'tile: 154 painter invocations in a frame would be slower than '
            'the live path this cache replaces');
  });

  test('a warm frame bakes nothing and blits the whole visible set', () async {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);

    rig.paintOnce();
    final visible = rig.cache.blitCount;
    expect(visible, greaterThan(30),
        reason: 'anti-degenerate clause 3: a single-tile viewport would make '
            'every grid and seam claim vacuous');

    rig.cache.resetCounters();
    rig.paintOnce();

    expect(rig.cache.bakeCount, 0);
    expect(rig.cache.blitCount, visible);
    expect(rig.cache.liveDrawCount, 0, reason: 'nothing left uncovered');
  });

  test('the blit Paint is one instance for the life of the cache', () {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);
    rig.paintOnce();
    final first = rig.cache.debugBlitPaint;
    rig.paintOnce();
    expect(identical(rig.cache.debugBlitPaint, first), isTrue,
        reason: 'criterion 13, and the shape VerticesDrawSink.debugPaint '
            'already uses: debugCapacityVertices cannot see a Paint');
  });
}
```

- [ ] **Step 2: Write the fixture rig**

Create `packages/jet_cad_2d_flutter/test/support/tile_fixture.dart`:

```dart
// One document, one camera, one cache, and a `Canvas` that goes nowhere.
//
// The camera is built by hand and is **not** `ViewportTransform.fit`:
// anti-degenerate clause 2. `fit` applies a 0.95 margin
// (`viewport_transform.dart:32`) and deriving an expected on-screen quantity
// through it cost Plan 3f two tasks.
//
// The tile size is 64 device pixels, not the production 256: anti-degenerate
// clause 1. At this size a fixture cannot fit inside one tile, so every
// boundary-crossing claim is exercised by the geometry rather than by the
// author remembering to exercise it.

import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'fixtures.dart';

const Size kTileViewport = Size(400, 300);
const double kTileDpr = 2.0;

/// World == screen at scale 1.4, y flipped, offset off both axes.
///
/// Not the identity and not the origin: a fixture at the identity transform is
/// this repository's dominant failure mode, and a tile grid anchored at (0, 0)
/// would never exercise [TileGrid] negative keys.
ViewportTransform tileCamera() => ViewportTransform(
    worldToScreenMatrix:
        Transform2(1.4, 0, 0, -1.4, -37.0, kTileViewport.height + 23.0));

class TileRig {
  TileRig({
    required int tileDevicePixels,
    required int tilesBakedPerFrame,
    int cacheBytes = kTileCacheBytes,
    DraftDocument? document,
  })  : measurer = FlutterTextMeasurer(),
        _ownsDocument = document == null {
    doc = document ?? crossingGrid(measurer);
    index = SpatialIndex(doc);
    sink = CanvasDrawSink(
        pixelsPerPaperMm: kLogicalPixelsPerMm,
        measurer: measurer,
        textStyleOf: doc.textStyleOf);
    vertices = VerticesDrawSink(
        pixelsPerPaperMm: kLogicalPixelsPerMm,
        devicePixelRatio: kTileDpr,
        fallback: sink);
    painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    cache = TileCache(
        tileDevicePixels: tileDevicePixels,
        tilesBakedPerFrame: tilesBakedPerFrame,
        cacheBytes: cacheBytes);
  }

  final FlutterTextMeasurer measurer;
  final bool _ownsDocument;
  late final DraftDocument doc;
  late final SpatialIndex index;
  late final CanvasDrawSink sink;
  late final VerticesDrawSink vertices;
  late final DraftPainter painter;
  late final TileCache cache;

  ViewportTransform camera = tileCamera();

  /// Paints one frame into a recorder whose picture is discarded.
  ///
  /// The picture is disposed rather than dropped: a `Picture` holds native
  /// memory past the Dart object, and leaving one alive is the "moved the
  /// leak" shape this repository's rules were written against.
  void paintOnce() {
    final recorder = PictureRecorder();
    cache.paintFrame(
      canvas: Canvas(recorder),
      viewport: kTileViewport,
      devicePixelRatio: kTileDpr,
      camera: camera,
      painter: painter,
      sink: sink,
      vertices: vertices,
    );
    recorder.endRecording().dispose();
  }

  void panBy(double dx, double dy) {
    final m = camera.worldToScreenMatrix;
    camera = ViewportTransform(
        worldToScreenMatrix:
            Transform2(m.a, m.b, m.c, m.d, m.e + dx, m.f + dy));
  }

  void zoomBy(double factor) {
    final m = camera.worldToScreenMatrix;
    camera = ViewportTransform(
        worldToScreenMatrix: Transform2(
            m.a * factor, m.b, m.c, m.d * factor, m.e, m.f));
  }

  void dispose() {
    cache.dispose();
    index.dispose();
    if (_ownsDocument) measurer.clear();
  }
}

/// A grid of lines long enough that many of them cross tile boundaries.
///
/// Anti-degenerate clause 1 is structural here: at a 64 device-pixel tile and
/// a `dpr` of 2, a tile is 32 logical pixels wide, and every line below is 90
/// logical pixels long at this camera.
DraftDocument crossingGrid(FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  var handle = 1000;
  for (var i = 0; i < 12; i++) {
    final t = i * 24.0;
    addLine(doc, doc.rootHandle, Handle(handle++), 10, 10 + t, 200, 10 + t);
    addLine(doc, doc.rootHandle, Handle(handle++), 10 + t, 10, 10 + t, 200);
  }
  return doc;
}
```

If `fixtures.dart` has no `addLine` with this signature, add one there rather than inlining a local copy — the anti-degenerate rule applies to every test this plan writes, and a private fixture helper is where degenerate values hide.

- [ ] **Step 3: Run it and watch it fail**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
```

Expected: compile failure — `TileCache` has no members yet.

- [ ] **Step 4: Implement the cache's drawing half**

Append to `tile_cache.dart`:

```dart
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
    _drawInto(canvas, viewport, quantised, painter, sink, vertices, origin,
        null);
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
    _drawInto(into, Size(side, side), grid.bakeCameraFor(key), painter, sink,
        vertices, origin, null);
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
```

Add the imports this needs at the top of the file — `package:vector_math/vector_math_64.dart hide Aabb2, Colors` for `Vector2`, and the sibling imports for `camera_controller.dart`, `canvas_draw_sink.dart`, `draft_painter.dart`, `vertices_draw_sink.dart`. **`unused_import` is an error here**, so add exactly what compiles.

- [ ] **Step 5: Run it and watch it pass**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
```

If `toImageSync` is slow enough to time the suite out, the fixture is too large — shrink `crossingGrid`, not the tile size, because the tile size is an anti-degenerate guarantee.

- [ ] **Step 6: Fire mutant M13**

```sh
cp lib/src/tile_cache.dart /tmp/tile_cache.dart.bak
```

Replace `_blitPaint` at its use site with a fresh `Paint()` per blit. The identity test must go red. Restore from the copy.

- [ ] **Step 7: Green and commit**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .
git add packages/jet_cad_2d_flutter/lib/src/tile_cache.dart packages/jet_cad_2d_flutter/test/tile_cache_test.dart packages/jet_cad_2d_flutter/test/support/tile_fixture.dart packages/jet_cad_2d_flutter/test/support/fixtures.dart
git commit -m "feat: the cache bakes, blits, and draws live where it cannot

A tile bakes through a per-tile camera with the frame-global rebase origin
injected, hard-clipped to its own rect on the device pixel grid --
doAntiAlias: false, because an antialiased clip gives two tiles partial
coverage along a shared edge and their source-over does not reach full
coverage.

The uncovered path is not a startup special case. A tile is missing whenever no
image covers its rect, which happens on the first frame, on a pan past the
retained ring, and after eviction reclaims tiles the camera comes back to. It
draws live once for the union of those rects rather than once per tile: 154
painter invocations in a frame would be slower than the live path this replaces.

Counters, not pixels, in this task. A later zero-difference result means
nothing unless something is known to have drawn -- the trap the spike walked
into with Probe C."
```

---

