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
  /// [tilesBakedPerFrame] is a **tile count**, not the device-pixel budget
  /// [TileCache] actually takes.
  ///
  /// Every fixture in this file builds at one fixed [tileDevicePixels] (64),
  /// so converting here -- `tilesBakedPerFrame * tileDevicePixels^2` -- is
  /// exact and loses nothing: `1000` still means "never runs out", `0` still
  /// means "bake nothing this frame", and `4` still means exactly four
  /// tiles. Keeping the tile-count spelling at the call sites is the point:
  /// every test built against this rig read as "bake N tiles" before
  /// [TileCache.bakeBudgetDevicePixels] existed, and translating the unit
  /// here rather than at each of those call sites is what keeps every one of
  /// those intents legible instead of a `* 4096` scattered through the file.
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
        bakeBudgetDevicePixels:
            tilesBakedPerFrame * tileDevicePixels * tileDevicePixels,
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
      // Read live rather than pinned: a rig that mutates a table between two
      // frames must see the second frame invalidate, and a constant here would
      // make that untestable through the rig.
      tablesRevision: doc.tables.mutationRevision,
    );
    recorder.endRecording().dispose();
  }

  void panBy(double dx, double dy) {
    final m = camera.worldToScreenMatrix;
    camera = ViewportTransform(
        worldToScreenMatrix:
            Transform2(m.a, m.b, m.c, m.d, m.e + dx, m.f + dy));
  }

  /// Scales about the **viewport centre**, the way a zoom gesture keeps the
  /// point under the cursor still.
  ///
  /// **Not by multiplying `a` and `d` alone.** That pins whichever world point
  /// happens to sit at screen `(e, f)` — here `(-37, 323)`, outside the
  /// viewport and below it — so a zoom *in* slides the whole drawing right and
  /// down, and the retired generation's composite lands short of the left
  /// edge by `e * (1 - factor)`. No zoom gesture behaves that way, and reading
  /// the resulting uncovered strip as a fact about the carry-over rather than
  /// about the rig is exactly the "gate that cannot see what it claims to
  /// measure" this plan keeps finding. It also left `b` and `c` unscaled,
  /// which is not a scale at all under a skewed camera.
  void zoomBy(double factor) {
    final m = camera.worldToScreenMatrix;
    final cx = kTileViewport.width / 2;
    final cy = kTileViewport.height / 2;
    camera = ViewportTransform(
        worldToScreenMatrix: Transform2(
            m.a * factor,
            m.b * factor,
            m.c * factor,
            m.d * factor,
            cx + (m.e - cx) * factor,
            cy + (m.f - cy) * factor));
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
/// a `dpr` of 2, a tile is 32 logical pixels wide. Each line below is 190
/// world units, which at this camera's 1.4 scale is 266 logical pixels — about
/// eight tiles.
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

/// Labels large enough to clear `kMinTextCapPixels` and long enough to cross
/// tile boundaries.
///
/// Text is the one content type that does not reach the vertices sink: it
/// falls back to `CanvasDrawSink`, which flushes the batch first. A tile bake
/// therefore exercises a mid-picture flush, and criterion 3 is the only place
/// this plan sees it.
DraftDocument crossingLabels(FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  var handle = 1000;
  for (var row = 0; row < 6; row++) {
    // 14 world units of cap height at this camera's 1.4 scale is 19.6 logical
    // pixels, well clear of the 3.0 default, and `culledTextCount` is
    // asserted rather than assumed below.
    addText(doc, doc.rootHandle, Handle(handle++), 'SECTION-A$row', 20,
        30 + row * 40.0, 14);
  }
  return doc;
}

/// Overlapping translucent strokes: [crossingGrid]'s exact geometry, so every
/// intersection of a horizontal and a vertical line is a genuine overlap of
/// two translucent strokes, some inside one tile and some straddling a seam.
///
/// Transparency rides on the vertex colour, and a tile is baked to a
/// transparent-backed `Image` and composited with `srcOver`. Both halves have
/// to survive, and a blend-mode mistake shows up as a uniform shift rather
/// than as a missing shape -- which is why the criterion compares bytes and
/// not ink counts.
///
/// **Deliberately not a near-axis line.** An earlier version of this fixture
/// drew ten near-axis diagonals (`(20, 30 + i*6)` to `(220, 150 - i*6)`).
/// That geometry disagrees between the two paths even with `transparency: 0`,
/// on tens of pixels out of ten thousand. Task 6 read this as a
/// tile-*crossing* defect; Task 6a measured it and it is not one --
/// [crossingGrid] crosses just as many seams and agrees exactly, and ten
/// *parallel* diagonals at slope 0.6 also agree exactly. It is a property of
/// the slope, it is the accepted gap [nearAxisDiagonals] now measures on
/// every run, and it is orthogonal to what criterion 4 is chartered to prove
/// -- alpha survives `toImageSync` and the `srcOver` blit. Reusing
/// [crossingGrid]'s already-proven-exact axis-aligned geometry (criterion 2
/// runs it at `transparency: 0` and gets zero differing pixels across the
/// same camera and tile size) isolates that one channel instead of
/// conflating it with the gap. See Task 6a's report for the mechanism.
DraftDocument translucentOverlap(FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  var handle = 1000;
  for (var i = 0; i < 12; i++) {
    final t = i * 24.0;
    // 60% transparent (of 255), so an overlap is visibly darker than a single
    // stroke and a lost alpha is a byte difference on thousands of pixels.
    // Zero is this channel's identity, so the value must not be zero -- 153
    // (60% of 255) is what `addLine` receives.
    addLine(doc, doc.rootHandle, Handle(handle++), 10, 10 + t, 200, 10 + t,
        transparency: 153);
    addLine(doc, doc.rootHandle, Handle(handle++), 10 + t, 10, 10 + t, 200,
        transparency: 153);
  }
  return doc;
}

/// Ten near-axis lines, the geometry that measures Task 6a's accepted gap.
///
/// **This fixture is expected to disagree, by a bounded amount.** Each line
/// spans 200 world units — 560 device pixels, 8.75 tiles at this rig's 64
/// device-pixel tile — and rises only 12 to 24 units over that span, so its
/// stroke edges run almost parallel to the pixel rows. Every fixture here
/// crosses many tile seams; so does [crossingGrid], which agrees exactly. The
/// variable is the slope, not the crossing.
///
/// **The mechanism, measured in Task 6a and not fixable from this
/// repository.** A tile is rasterised into its own surface, so every vertex
/// reaches Skia offset by the tile's position. That offset is a whole number
/// of device pixels, but it still moves a coordinate to a different binary
/// exponent, and Skia's `Float32` pipeline cannot always hold the low bits
/// there: for this fixture's leftmost vertices the device x moves from
/// `-17.943408966064453` to an exact `-401.94340896606445` that rounds to
/// `-401.94342041015625`, an error of **1.144e-05 device pixels**. On a slope
/// whose stroke edge passes exactly through a sample point — here every 50
/// device pixels, because the device slope is exactly 3/50 — that error
/// decides the tie, and one pixel moves. Reproduced with no `jet_cad` code at
/// all: the same `Vertices` drawn twice into two 800x600 surfaces, one of them
/// translated by a whole number of device pixels, differs on the same pixels.
///
/// Folding the offset into the camera instead (what `TileGrid.bakeCameraFor`
/// does) rounds in `VerticesDrawSink`'s `Float32` vertex buffer rather than in
/// Skia's matrix, at the same magnitude, and was measured to give **pixel-for-
/// pixel identical** disagreement. There is no third place to put the offset.
DraftDocument nearAxisDiagonals(FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  var handle = 1000;
  for (var i = 0; i < 10; i++) {
    addLine(doc, doc.rootHandle, Handle(handle++), 20, 30 + i * 6.0, 220,
        150 - i * 6.0);
  }
  return doc;
}

/// A grid that fills [kTileViewport] at [tileCamera] **and goes on filling it
/// at every offset the fallback sweep pans to**, which no other fixture here
/// does.
///
/// **This is the property that makes a crippled query detectable, and its
/// absence is why three earlier arrangements could not detect one.** A loss in
/// the live fallback is only visible where the uncovered union's boundary is
/// *interior to the drawing*: a strip entering across empty canvas has no ink
/// to lose. [crossingGrid] spans world x 10..200, which at this camera's 1.4
/// is screen -23..243 inside a 400 px viewport -- off the left edge and short
/// of the right -- so a pan in any direction brings in empty space.
///
/// **The extent is derived from the sweep rather than from the resting
/// camera, and the predecessor extent that was not cost this plan its witness
/// for `canvas.translate`.** [tileCamera] maps world to screen as
/// `sx = 1.4 * wx - 37` and `sy = -1.4 * wy + 323`, so **one world unit is
/// 1.4 screen pixels** and the resting visible world box is x in
/// [26.4, 312.1], y in [16.4, 230.7]. `TileRig.panBy` adds its offset to the
/// camera's translation, so a pan of `d` screen pixels slides this drawing by
/// `d` on screen: an edge of the grid stays outside the viewport under that
/// pan only while its own screen distance past that viewport edge exceeds
/// `|d|`. At the extent below, those four distances are
///
/// | edge   | world   | screen | past the viewport edge by |
/// |--------|---------|--------|---------------------------|
/// | left   | x = -52 | -109.8 | 109.8 px                  |
/// | right  | x = 380 |  495.0 |  95.0 px                  |
/// | top    | y = 300 |  -97.0 |  97.0 px                  |
/// | bottom | y = -52 |  395.8 |  95.8 px                  |
///
/// and the largest offset the fallback sweep pans is **71 screen pixels**, so
/// every edge clears the whole sweep by at least 24 screen pixels and the
/// viewport stays strictly interior to the drawing at all eight offsets.
///
/// **What the predecessor extent (20..320 by 10..240) did.** It contained the
/// resting visible box on all four edges, but by only about 9 to 13 *screen*
/// pixels, against a sweep that pans 37 to 71. At `Offset(-41, 0)` and
/// `Offset(0, -41)` the entering `uncovered` region therefore landed on bare
/// canvas: the live fallback drew **nothing** there and the sweep's
/// zero-differing-pixel assertions were satisfied vacuously. Those two
/// offsets are also precisely the ones whose strip does not start at (0, 0)
/// -- the only ones where `TileCache.paintFrame`'s
/// `canvas.translate(strip.left, strip.top)` is not a no-op -- so deleting
/// that line left the whole widget suite green. The extent above is what
/// gives that line a witness -- **not** the ink-inside-the-strip clause
/// added alongside it (`InkReport.liveStripInk` in `tile_comparison.dart`):
/// that clause measures `TileCache.debugLastStrip`, which pads `uncovered`
/// outward, so it can find ink in already-blitted area even when the band
/// the fallback owes is itself bare. A re-review confirmed that clause could
/// not have supplied this witness on its own: restoring the predecessor
/// extent with that clause live still lets `canvas.translate`'s deletion
/// pass the whole suite. See gap H7 in STATUS.md.
///
/// Lines rather than a fill, and axis-aligned rather than diagonal: this
/// fixture carries the arm that must agree **exactly**, so it must not import
/// the near-axis slope disagreement [nearAxisDiagonals] measures.
DraftDocument fillingGrid(FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  var handle = 1000;
  // 16 units apart: half a tile's 32 logical pixels at this camera's 1.4 is
  // 22.9 world units, so no tile-sized strip anywhere in the frame can be
  // empty of ink. The bounds are a whole number of steps apart end to end
  // (-52 + 16*22 = 300, -52 + 16*27 = 380), so the outermost line lands
  // exactly on the extent the table above measures rather than short of it.
  for (var t = -52.0; t <= 300.0; t += 16.0) {
    addLine(doc, doc.rootHandle, Handle(handle++), -52, t, 380, t);
  }
  for (var t = -52.0; t <= 380.0; t += 16.0) {
    addLine(doc, doc.rootHandle, Handle(handle++), t, -52, t, 300);
  }
  return doc;
}

/// Which side of boundary [n] its thick stroke sits on: **one stroke, not a
/// pair**, alternating so both directions of the pad are exercised across the
/// fixture.
///
/// **A stroke either side of the same boundary masks the loss it was placed to
/// expose, and it did.** The two centrelines are 2 logical pixels apart
/// against a 3.780 half-width, so their ink overlaps by 5.56 logical pixels
/// and the union covers the boundary either way: the stroke centred at
/// `32k - 1` inks `32k .. 32k + 2.780` inside band `k`, and the stroke centred
/// at `32k + 1` -- which band `k`'s own query finds, padded or not -- inks
/// `32k - 2.780 .. 32k + 4.780` over the top of it. Measured: with the pair in
/// place, `const pad = 0.0` in `_bakeBand` (M9) changed **zero** pixels at
/// [tileCamera]. With one stroke a boundary it changes thousands.
double _sideFor(int n) => n.isOdd ? -1.0 : 1.0;

/// The lineweight the band-boundary strokes in [bandCrossingGrid] carry, in
/// 1/100 mm on paper.
///
/// **Chosen so the stroke is wider than its distance to the boundary, which is
/// the whole of what M9 tests.** `CanvasDrawSink` and `VerticesDrawSink` both
/// turn a lineweight into pixels as `hundredths / 100 * pixelsPerPaperMm`, and
/// [kLogicalPixelsPerMm] is `96 / 25.4 = 3.7795`. At `200` that is
/// `2.0 * 3.7795 = 7.559` logical pixels wide, so the half-width is **3.780
/// logical pixels** — 7.559 device pixels at [kTileDpr]. A centreline placed
/// one logical pixel outside a band's edge therefore inks 2.780 logical
/// pixels (5.56 device rows) *inside* that band, across the band's whole
/// width, and an unpadded band query drops every one of them.
///
/// The default `25` every other fixture here carries is 0.945 logical pixels
/// wide — a half-width of 0.47, less than the one-pixel offset — so this
/// fixture cannot be built out of it.
const int kBandStrokeLineweight = 200;

/// [fillingGrid]'s extent and spacing, plus **thick strokes centred just
/// outside a band boundary**: the fixture the slice differential runs on.
///
/// **Anti-degenerate clause 2 — entities larger than one tile.** A 64
/// device-pixel tile is 32 logical pixels at [kTileDpr]. Every horizontal line
/// here spans world x `-52 .. 380`, which at [tileCamera]'s 1.4 scale is
/// **604.8 logical pixels — 18.9 tiles**; every vertical spans world y
/// `-52 .. 300`, **492.8 logical pixels, 15.4 tiles**. Crossing multiplicity
/// is what the band design attacks (`kTileDevicePixels`' own doc comment
/// measures it as the larger term), and a fixture of tile-sized entities would
/// make the win invisible: no entity would ever be walked into two bands, and
/// a slice arithmetic error would have nothing to disagree about.
///
/// **M9's target — a stroke whose centreline is outside the band it inks.**
/// [tileCamera] maps world to screen as `sy = -1.4 * wy + 323`, and a band is
/// one tile row: band `k` owns device rows `[64k, 64k + 64)`, which is logical
/// screen y `[32k, 32k + 32)`. For each `k` in `1..9` this fixture places
/// **one** [kBandStrokeLineweight] stroke, at logical screen y `32k - 1` for
/// odd `k` and `32k + 1` for even `k` — one logical pixel outside a boundary,
/// against a half-width of 3.780, so it inks 2.780 logical pixels (5.56 device
/// rows) into the band on the far side. That entity's *bounds* do not
/// intersect that band at all, and the painter's index query is an exact rect
/// intersection on bounds — measured: a line 0.1 world units outside a query
/// rect is not returned — so with `const pad = 0.0` in `_bakeBand` the band
/// loses those rows across its full 800-device-pixel width. See [_sideFor] for
/// why it is one stroke and not two.
///
/// The same is done one logical pixel outside each **column** boundary, which
/// is not a band edge but is a tile edge: those strokes are what the per-tile
/// `_bake` path's own pad owes, and they put ink on the columns
/// `differingPixelsOnTileEdges` sweeps.
///
/// **Never (0, 0) and never the identity.** The extent, the spacing and the
/// reasoning behind all three are [fillingGrid]'s — see its doc comment for
/// why the drawing has to stay strictly wider than the viewport under every
/// pan these arms take. The thick strokes are laid out by inverting
/// [tileCamera], so their world coordinates are the far-from-origin,
/// non-round numbers that camera implies rather than a hand-picked grid.
DraftDocument bandCrossingGrid(FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  var handle = 1000;
  // [fillingGrid]'s geometry verbatim: the viewport stays interior to the
  // drawing under every pan these arms take.
  for (var t = -52.0; t <= 300.0; t += 16.0) {
    addLine(doc, doc.rootHandle, Handle(handle++), -52, t, 380, t);
  }
  for (var t = -52.0; t <= 380.0; t += 16.0) {
    addLine(doc, doc.rootHandle, Handle(handle++), t, -52, t, 300);
  }

  // [tileCamera] inverted. Written as the inverse rather than as literals so
  // the strokes track the camera if it ever moves, instead of silently
  // drifting off the boundaries they exist to straddle.
  double worldY(double screenY) => (323.0 - screenY) / 1.4;
  double worldX(double screenX) => (screenX + 37.0) / 1.4;

  // Rows 1..9. Row 0's top edge is the viewport's own edge and row 10 is
  // past the bottom of a 600 device-pixel viewport, so neither is a band
  // boundary with a band on both sides of it.
  for (var row = 1; row <= 9; row++) {
    final y = worldY(row * 32.0 + _sideFor(row));
    addLine(doc, doc.rootHandle, Handle(handle++), -52, y, 380, y,
        lineweight: kBandStrokeLineweight);
  }
  // Columns 1..12 at 32 logical pixels: the last tile column starts at device
  // x 768 and the viewport is 800 wide, so column 12's own left edge is the
  // final one inside it.
  for (var col = 1; col <= 12; col++) {
    final x = worldX(col * 32.0 + _sideFor(col));
    addLine(doc, doc.rootHandle, Handle(handle++), x, -52, x, 300,
        lineweight: kBandStrokeLineweight);
  }
  return doc;
}
