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
        worldToScreenMatrix:
            Transform2(m.a * factor, m.b, m.c, m.d * factor, m.e, m.f));
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
