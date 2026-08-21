// Do the two production backends draw the same drawing?
//
// Ink-region membership in both directions, not per-pixel colour. The
// rasterizer has no anti-aliasing and a CAD stroke is about one pixel wide, so
// on the canvas side essentially every ink pixel is an edge pixel: a per-pixel
// tolerance loose enough to admit that would admit a wrong corner too, and the
// number would be a bound on nothing.
//
// ## Both sinks are driven directly, and there is no widget here
//
// `stroke_width_golden_test.dart` already makes the argument: stroke width is
// computed in the sink and the joins are built in the sink, so a `DrawSink`
// test that goes through `DraftCanvas` is testing the widget's plumbing on the
// way to the thing it means to measure. This file drives `CanvasDrawSink` and
// `VerticesDrawSink` over the *same* [Drawing] closure — one op sequence, two
// sinks — and captures each one directly: `Picture.toImage` for the canvas,
// `TriangleRasterizer.pixels` for the vertices.
//
// That also removes the reason a widget-routed version of this comparison did
// not finish. `RenderRepaintBoundary.toImage` and `decodeImageFromPixels` are
// both engine round-trips, and `tester.runAsync` cannot nest; capturing two
// backends inside one test meant chaining them, and the chain hung. Here the
// vertices side needs no async at all (the rasterizer's `Uint32List` *is* the
// image) and the canvas side needs exactly one `runAsync`, never nested.
//
// ## Device resolution, and why it is not optional
//
// Both captures are at `viewport * devicePixelRatio`, with the vertices
// positions scaled by the ratio. `VerticesDrawSink`'s width floor and colour
// fade are device-pixel quantities while its buffer is in logical pixels, and
// Task 10 landed after a rasterizer at logical resolution silently lost a
// one-device-pixel stroke and produced two goldens that passed against a
// renderer emitting no geometry at all. The ratio is read from
// `tester.view.devicePixelRatio` — 3.0 on this binding — and never written
// down as a literal.
//
// ## What this comparison excludes, and what that costs
//
// `flutter_test` renders the canvas side through **software Skia**, not
// Impeller. Two of the rules `VerticesDrawSink` mirrors are Impeller's and
// have no counterpart on the canvas side: the one-device-pixel stroke floor
// (`impeller/entity/geometry/geometry.h:19`, `_halfWidthFor`) and the
// sub-pixel alpha fade (`geometry.cc:148`, `_coveredArgb`). They are row 4 of
// the design document's permitted-divergence table, "sub-pixel strokes:
// vertices, but untestable by comparison".
//
// The fixtures here stay above the floor, so that row is excluded rather than
// measured — and `subPixelDivergenceFixture` exists to show what excluding it
// buys, by reaching below the floor deliberately and letting the divergence
// appear. Outside that one fixture the two rules are pinned by the unit tests
// in `vertices_draw_sink_test.dart` and by nothing else.
//
// Text is excluded from the pixel comparison by a mask and asserted by
// `AgreementReport.verticesFlushCount` instead: a paragraph never enters the
// triangle buffer, so the vertices-side image has no glyphs while the
// canvas-side one does. The fixture still *carries* text, because text is what
// forces the mid-frame flush, and the ordering that depends on it is half of
// what is being tested.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2, Colors;

import 'triangle_rasterizer.dart';

const Size kComparisonSize = Size(400, 300);

/// The paper-to-pixel scale the comparison runs at.
///
/// `DraftCanvas`'s own default, so the lineweights below are the widths a real
/// frame draws rather than a scale invented for a test.
const double kComparisonPixelsPerPaperMm = kLogicalPixelsPerMm;

/// Pixels of the canvas image at or above this alpha count as its ink.
///
/// Below it is anti-aliasing spill, which the rasterizer has no way to
/// produce and which is row 3 of the permitted-divergence table.
const int kInkAlphaFloor = 0xC0;

/// One op sequence, handed to each backend's sink in turn.
typedef Drawing = void Function(DrawSink sink);

/// Counts produced by a comparison run. See [measureAgreement].
class AgreementReport {
  AgreementReport({
    required this.width,
    required this.height,
    required this.canvasInkPixels,
    required this.verticesInkPixels,
    required this.strayVerticesPixels,
    required this.uncoveredCanvasPixels,
    required this.canvasBytes,
    required this.verticesPixels,
    required this.verticesFlushCount,
  });

  /// Device pixels the two images were captured at.
  final int width;
  final int height;

  /// Canvas pixels at or above [kInkAlphaFloor], outside the text mask.
  final int canvasInkPixels;

  /// Vertices pixels the rasterizer painted, outside the text mask.
  final int verticesInkPixels;

  /// Vertices ink with no canvas ink within one pixel. Invented geometry.
  final int strayVerticesPixels;

  /// Canvas ink above the floor with no vertices ink within one pixel.
  /// Missing geometry.
  final int uncoveredCanvasPixels;

  /// RGBA8888, kept so a non-zero count can be looked at rather than argued
  /// about. See [writeDisagreementImages].
  final Uint8List canvasBytes;
  final Uint32List verticesPixels;

  /// `drawVertices` calls the vertices backend issued: one at the end of the
  /// drawing, plus one before every op it cannot batch.
  ///
  /// Text is the only such op, and it is the half of this comparison the
  /// pixels cannot check -- the vertices image has no glyphs at all, so the
  /// mask hides both the text and the ordering around it. This is what says
  /// the flush happened.
  final int verticesFlushCount;
}

/// Draws [draw] through both backends and returns the agreement counts.
///
/// [doc] supplies only the text-style lookup `CanvasDrawSink` needs; the
/// geometry is whatever [draw] emits. [textMask] is in **logical** pixels and
/// is scaled to device pixels here.
Future<AgreementReport> measureAgreement(
  WidgetTester tester,
  DraftDocument doc,
  Drawing draw, {
  Rect textMask = Rect.zero,
}) async {
  final dpr = tester.view.devicePixelRatio;
  final w = (kComparisonSize.width * dpr).round();
  final h = (kComparisonSize.height * dpr).round();

  final canvasBytes = await _captureCanvas(tester, doc, draw, dpr, w, h);
  final (rasterizer, flushes) = _captureVertices(doc, draw, dpr, w, h);

  expect(canvasBytes.length, w * h * 4);
  expect(rasterizer.pixels.length, w * h);

  final mask = Rect.fromLTRB(textMask.left * dpr, textMask.top * dpr,
      textMask.right * dpr, textMask.bottom * dpr);
  bool inMask(int x, int y) =>
      x >= mask.left && x < mask.right && y >= mask.top && y < mask.bottom;

  final canvasMask = List<bool>.filled(w * h, false);
  final verticesMask = List<bool>.filled(w * h, false);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (inMask(x, y)) continue;
      final i = y * w + x;
      if (canvasBytes[i * 4 + 3] >= kInkAlphaFloor) canvasMask[i] = true;
      // The rasterizer writes an opaque RGBA word or leaves the pixel at
      // zero; there is no partial coverage to threshold.
      if (rasterizer.pixels[i] != 0) verticesMask[i] = true;
    }
  }

  var canvasInk = 0, verticesInk = 0, stray = 0, uncovered = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      if (canvasMask[i]) canvasInk++;
      if (verticesMask[i]) verticesInk++;
      if (verticesMask[i] && !_nearInk(canvasMask, w, h, x, y)) stray++;
      if (canvasMask[i] && !_nearInk(verticesMask, w, h, x, y)) uncovered++;
    }
  }

  return AgreementReport(
    width: w,
    height: h,
    canvasInkPixels: canvasInk,
    verticesInkPixels: verticesInk,
    strayVerticesPixels: stray,
    uncoveredCanvasPixels: uncovered,
    canvasBytes: canvasBytes,
    verticesPixels: rasterizer.pixels,
    verticesFlushCount: flushes,
  );
}

/// Draws [draw] through both backends and asserts they draw the same drawing.
Future<AgreementReport> expectSinksAgree(
  WidgetTester tester,
  DraftDocument doc,
  Drawing draw, {
  Rect textMask = Rect.zero,
}) async {
  final report = await measureAgreement(tester, doc, draw, textMask: textMask);
  // A picture that never inked a pixel passes every membership assertion
  // trivially and pins nothing.
  expect(report.verticesInkPixels, greaterThan(500),
      reason: 'the vertices backend drew nothing worth comparing');
  expect(report.canvasInkPixels, greaterThan(500),
      reason: 'the canvas backend drew nothing worth comparing');
  expect(report.strayVerticesPixels, 0,
      reason: 'the vertices backend drew ink the canvas backend has no ink '
          'near: invented geometry, or a divergence not on the design '
          "document's permitted list. Do not widen the dilation -- write both "
          'images out with writeDisagreementImages and look at them.');
  expect(report.uncoveredCanvasPixels, 0,
      reason: 'the canvas backend drew ink the vertices backend has no ink '
          'near: missing geometry, or a divergence not on the design '
          "document's permitted list. Do not widen the dilation -- write both "
          'images out with writeDisagreementImages and look at them.');
  return report;
}

/// Renders [draw] through `CanvasDrawSink` into a `Picture` and returns its
/// RGBA8888 bytes at device resolution.
Future<Uint8List> _captureCanvas(WidgetTester tester, DraftDocument doc,
    Drawing draw, double dpr, int w, int h) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  // The engine composites the layer tree at the device pixel ratio; a
  // `PictureRecorder` does not, so the scale is applied here. Everything the
  // sink computes stays in logical pixels, exactly as it does in a frame.
  canvas.scale(dpr);
  // `_DraftCustomPainter.paint` clips to the viewport, and the rasterizer
  // clips to its own surface, so the canvas side has to clip too or offscreen
  // geometry would count as canvas-only ink.
  canvas.clipRect(Offset.zero & kComparisonSize);
  final measurer = FlutterTextMeasurer();
  draw(CanvasDrawSink(
      canvas: canvas,
      pixelsPerPaperMm: kComparisonPixelsPerPaperMm,
      measurer: measurer,
      textStyleOf: doc.textStyleOf));
  final picture = recorder.endRecording();
  // The one place this file needs the engine. `Picture.toImage` and
  // `Image.toByteData` are real engine callbacks that the automated binding's
  // fake-async zone will not deliver, so they run inside a single, never
  // nested, `runAsync`.
  final bytes = (await tester.runAsync(() async {
    final image = await picture.toImage(w, h);
    final data = await image.toByteData();
    image.dispose();
    return data!.buffer.asUint8List();
  }))!;
  picture.dispose();
  // Only now: a `Paragraph` holds native glyph memory the collector does not
  // see, and `clear` disposes every cached one -- which the recorded picture
  // still refers to until it has been rasterised.
  measurer.clear();
  return bytes;
}

/// Renders [draw] through `VerticesDrawSink` and the coverage rasterizer.
///
/// Synchronous: the rasterizer's `Uint32List` is already the image, so nothing
/// here goes through `decodeImageFromPixels`.
(TriangleRasterizer, int) _captureVertices(
    DraftDocument doc, Drawing draw, double dpr, int w, int h) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final rasterizer = TriangleRasterizer(w, h);
  final measurer = FlutterTextMeasurer();
  final fallback = CanvasDrawSink(
      canvas: canvas,
      pixelsPerPaperMm: kComparisonPixelsPerPaperMm,
      measurer: measurer,
      textStyleOf: doc.textStyleOf);
  final sink = VerticesDrawSink(
    pixelsPerPaperMm: kComparisonPixelsPerPaperMm,
    canvas: canvas,
    fallback: fallback,
    devicePixelRatio: dpr,
  )..observer = (positions, colors) {
      // The buffer is in logical pixels and the surface is in device pixels.
      final scaled = Float32List(positions.length);
      for (var i = 0; i < positions.length; i++) {
        scaled[i] = positions[i] * dpr;
      }
      rasterizer.observe(scaled, colors);
    };
  draw(sink);
  sink.flush();
  // This picture is never rasterised -- the rasterizer read the triangles off
  // the flush -- so the paragraphs the fallback laid out can go immediately.
  recorder.endRecording().dispose();
  measurer.clear();
  return (rasterizer, sink.totalFlushCount);
}

/// Whether any pixel in the 3x3 neighbourhood of `(x, y)` is set in [mask].
///
/// Dilating by exactly one pixel in each direction is the whole tolerance: it
/// covers the half-pixel each rasteriser may place an edge differently, and it
/// does not cover a corner in the wrong place.
bool _nearInk(List<bool> mask, int w, int h, int x, int y) {
  for (var dy = -1; dy <= 1; dy++) {
    for (var dx = -1; dx <= 1; dx++) {
      final nx = x + dx, ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
      if (mask[ny * w + nx]) return true;
    }
  }
  return false;
}

/// Writes both captures and their difference to `dir` as PPMs.
///
/// The instruction this task carries is "when your number is not zero, look at
/// the images"; this is what makes that possible. PPM because it needs no
/// encoder and no engine round-trip. Never called by a passing test.
void writeDisagreementImages(AgreementReport report, String dir) {
  final w = report.width, h = report.height;
  void write(String name, int Function(int) rgbOf) {
    final header = 'P6\n$w $h\n255\n';
    final out = Uint8List(header.length + w * h * 3);
    out.setRange(0, header.length, header.codeUnits);
    for (var i = 0; i < w * h; i++) {
      final rgb = rgbOf(i);
      out[header.length + i * 3] = (rgb >> 16) & 0xFF;
      out[header.length + i * 3 + 1] = (rgb >> 8) & 0xFF;
      out[header.length + i * 3 + 2] = rgb & 0xFF;
    }
    File('$dir/$name').writeAsBytesSync(out);
  }

  write('canvas.ppm', (i) {
    final a = report.canvasBytes[i * 4 + 3];
    final v = 255 - a;
    return (v << 16) | (v << 8) | v;
  });
  write('vertices.ppm', (i) {
    final v = report.verticesPixels[i] == 0 ? 255 : 0;
    return (v << 16) | (v << 8) | v;
  });
  // Red where only the canvas inked, blue where only the vertices sink did,
  // black where both agree.
  write('diff.ppm', (i) {
    final c = report.canvasBytes[i * 4 + 3] >= kInkAlphaFloor;
    final v = report.verticesPixels[i] != 0;
    if (c && v) return 0x000000;
    if (c) return 0xFF0000;
    if (v) return 0x0000FF;
    return 0xFFFFFF;
  });
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// A drawing carrying every primitive the painter emits, under conditions the
/// identity transform would hide: an oblique polyline corner comfortably
/// inside the miter limit; a corner past it, so the join takes its bevel-only
/// branch; an open arc; a point; text, which forces the mid-frame flush; and a
/// circle under a rotated, **non-uniformly scaled** residual — the one
/// combination that makes the anisotropic-stroke-width divergence (design
/// document, row 1) reachable at all, because `_emitScreenSpace` hands every
/// point, line and polyline a pure-translation residual and only curves keep
/// the real one.
///
/// Handles are assigned in creation order and draw order is ascending handle
/// value, so the text entity sits between two groups of stroke geometry: the
/// flush the vertices sink performs before every text op has real batched work
/// on both sides of it, not an empty buffer either way.
DraftDocument comparisonFixture() {
  final doc = DraftDocument.empty(measurer: FlutterTextMeasurer());
  final seed = doc.handleSeed;

  // A point marker.
  _entity(
      doc, doc.rootHandle, seed.next(), EntityKind.point, [20, 250], const [],
      lineweight: 120);

  // An oblique corner, comfortably inside the miter limit: the cosine of the
  // direction change is about 0.29, nowhere near the -0.875 bevel threshold
  // and nowhere near 0 or 1, so this is a genuine mitred bend and not a right
  // angle or a straight run.
  _entity(doc, doc.rootHandle, seed.next(), EntityKind.polyline,
      [30, 60, 75, 110, 150, 75], const [],
      lineweight: 160);

  // A corner past the miter limit: a 160-degree direction change (cosine
  // -0.939), below -0.875, so `_emitJoin` takes the bevel-only branch and
  // emits no miter tip. Not the near-reversal it used to be: at 178 degrees
  // the bevel triangle is itself degenerate, so the branch was exercised
  // while the ink it controls was nil, and a mutant that emitted the miter
  // tip anyway would have been caught by luck rather than by geometry. At
  // 160 degrees the suppressed tip would reach 5.9 half-widths past the
  // corner.
  _entity(doc, doc.rootHandle, seed.next(), EntityKind.polyline,
      [170, 40, 230, 90, 173.6, 69.7], const [],
      lineweight: 160);

  // An open arc.
  _entity(doc, doc.rootHandle, seed.next(), EntityKind.arc, [280, 70],
      const [35, 0.3, 2.0],
      lineweight: 60);

  // Text: forces `_flushBeforeUnbatchable`. Its handle sits after the four
  // entities above and before the circle below.
  _text(doc, seed.next(), 'SINK', x: 45, y: 215, height: 24);

  // A circle under a rotated (0.35 rad), non-uniformly scaled (1.0 x 1.15)
  // residual. At this lineweight the two backends' widths differ by about
  // 0.16 device pixels -- the permitted divergence is present and inside the
  // one-pixel dilation; `anisotropyDivergenceFixture` is where it is made
  // large enough to see.
  final group = seed.next();
  doc.commands.execute(AddNodeCommand(GroupNode(
    handle: group,
    parent: doc.rootHandle,
    transform: Transform2.translation(300, 180)
        .multiply(Transform2.rotation(0.35))
        .multiply(Transform2.scale(1.0, 1.15)),
    children: const [],
  )));
  _entity(doc, group, seed.next(), EntityKind.circle, [0, 0], const [26],
      lineweight: 40);

  return doc;
}

/// The two ops `DraftPainter` cannot produce, drawn straight at the sink.
///
/// - **A closed run.** `draft_painter.dart` passes `closed: false` at all four
///   of its `polyline` call sites, so the seam join is unreachable through the
///   painter; a circle reaches `_endRun(closed: true)` but its chords are a
///   quarter-pixel apart, which makes the seam notch smaller than the
///   one-pixel dilation and therefore invisible to *any* ink comparison. A
///   pentagon's 72-degree seam is not.
/// - **A point under a rotated residual.** Every point takes
///   `_emitScreenSpace`, where the residual left for the sink is a pure
///   translation — under which the screen-space square Task 6 introduced and
///   the local-space `drawRawPoints` cap it replaced are the *same square*.
///   Only a rotated residual tells them apart, and no painter path supplies
///   one.
///
/// Both are in screen space and in their own comparison rather than appended
/// to [comparisonFixture]'s, because the fitted camera fills the viewport and
/// geometry laid on top of it would have its disagreements masked by whatever
/// the document already drew next door.
void comparisonDirectOps(DrawSink sink) {
  const style = ResolvedStyle(
      argb: 0xFF000000,
      lineweightHundredths: 120,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0);

  // Conformal but not the identity: a rotation and a uniform 1.3 scale, so the
  // residual is live without also invoking row 1's anisotropic-width
  // divergence, which this comparison is not the place to measure.
  sink.beginResidual(Transform2.translation(140, 150)
      .multiply(Transform2.rotation(0.4))
      .multiply(Transform2.scale(1.3, 1.3)));
  final pentagon = Float64List(10);
  for (var i = 0; i < 5; i++) {
    final a = i * 2 * math.pi / 5;
    pentagon[i * 2] = 60 * math.cos(a);
    pentagon[i * 2 + 1] = 60 * math.sin(a);
  }
  sink.polyline(pentagon, 5, style, closed: true);
  sink.endResidual();

  sink.beginResidual(
      Transform2.translation(320, 150).multiply(Transform2.rotation(0.6)));
  sink.point(0, 0, style);
  sink.endResidual();
}

/// The one non-identity node [comparisonFixture] relies on to avoid the
/// identity transform this repository's `CLAUDE.md` names as the dominant
/// failure mode. A guard, so the rule cannot rot silently.
void assertNoIdentityTransforms(DraftDocument doc) {
  final groups = doc.tree.nodes
      .whereType<GroupNode>()
      .where((n) => n.parent == doc.rootHandle)
      .toList();
  expect(groups, isNotEmpty,
      reason: 'fixture rule: expected a non-root group node');
  for (final node in groups) {
    expect(node.transform.isIdentity, isFalse,
        reason: 'fixture rule: an identity transform hides ordering defects');
    // Rotation alone would leave `scaleMagnitude` exact and hide row 1
    // entirely; a uniform scale would too.
    expect(node.transform.anisotropyRatio, greaterThan(1.0),
        reason: 'fixture rule: a conformal residual cannot reach the '
            'anisotropic-stroke-width divergence');
  }
}

/// A single circle under a strongly anisotropic residual.
///
/// Row 1 of the permitted-divergence table, made large enough to see.
DraftDocument anisotropyDivergenceFixture({double scaleY = 3.0}) {
  final doc = DraftDocument.empty(measurer: FlutterTextMeasurer());
  final seed = doc.handleSeed;
  final group = seed.next();
  doc.commands.execute(AddNodeCommand(GroupNode(
    handle: group,
    parent: doc.rootHandle,
    transform: Transform2.translation(150, 150)
        .multiply(Transform2.rotation(0.35))
        .multiply(Transform2.scale(1.0, scaleY)),
    children: const [],
  )));
  _entity(doc, group, seed.next(), EntityKind.circle, [0, 0], const [40],
      lineweight: 120);
  return doc;
}

/// One straight line whose stroke is thinner than a device pixel.
///
/// Row 4 of the permitted-divergence table. `VerticesDrawSink` clamps the
/// width to one device pixel and fades the alpha in proportion; `CanvasDrawSink`
/// has neither rule — it has no `devicePixelRatio` field at all — so software
/// Skia simply draws a fainter, thinner line. [lineweight] of 1 is 0.01 mm,
/// which at this file's scale is 0.11 device pixels.
DraftDocument subPixelDivergenceFixture({int lineweight = 1}) {
  final doc = DraftDocument.empty(measurer: FlutterTextMeasurer());
  final seed = doc.handleSeed;
  _entity(doc, doc.rootHandle, seed.next(), EntityKind.polyline,
      [0, 0, 300, 90], const [],
      lineweight: lineweight);
  return doc;
}

/// A full-sweep `ARC`: `sweep == 2 * pi`, which draws a closed circle through
/// `Canvas.drawArc` and an **unjoined** one through `VerticesDrawSink`, whose
/// `arc` passes `closed: false` structurally.
///
/// Not on the permitted-divergence list. Drawn at the sink rather than through
/// the painter so the radius and the lineweight are both controlled directly:
/// the seam notch is about `half * sqrt(2 / radius)` device pixels wide at the
/// sink's quarter-pixel flattening tolerance, so it only clears the one-pixel
/// dilation when the stroke is a large fraction of the radius. A fitted camera
/// would put the radius wherever the extents fell and hide it.
///
/// 36 device pixels of radius, stroked 25 device pixels wide.
void fullSweepArcDrawing(DrawSink sink) {
  const style = ResolvedStyle(
      argb: 0xFF000000,
      lineweightHundredths: 225,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0);
  sink.beginResidual(Transform2.translation(200, 150));
  sink.arc(0, 0, 12, 0.0, 2 * math.pi, style);
  sink.endResidual();
}

/// Paints [doc] through the real painter, into whichever sink it is given.
Drawing paintDrawing(DraftDocument doc, SpatialIndex index) {
  final camera = ViewportTransform.fit(doc.extents, kComparisonSize);
  final painter = DraftPainter(
      document: doc, index: index, resolver: DocumentStyleResolver(doc));
  return (sink) => painter.paint(sink, camera, kComparisonSize);
}

/// Adds one drawn entity.
void _entity(DraftDocument doc, Handle owner, Handle handle, EntityKind kind,
    List<double> coords, List<double> scalars,
    {required int lineweight}) {
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: kind,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      // Concrete black, not ByLayer: layer 0 resolves to ACI 7, which would be
      // white, and a white drawing on a transparent capture inks nothing at
      // all -- a missing-geometry mutation would look like a passing test.
      color: const TrueColor(0x000000),
      lineweight: lineweight,
      transparency: 0,
      flags: 0,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList(coords),
      scalars: Float64List.fromList(scalars),
    ),
  ));
}

/// Adds one text entity, root-owned and unrotated: the mask only has to cover
/// an axis-aligned box, and text is excluded from the pixel comparison
/// entirely, so its placement does not need to be adversarial.
void _text(DraftDocument doc, Handle handle, String text,
    {required double x, required double y, required double height}) {
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: doc.rootHandle,
      kind: EntityKind.text,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const TrueColor(0x000000),
      lineweight: 25,
      transparency: 0,
      flags: 0,
      text: text,
      textStyle: ReservedHandles.standardTextStyle,
      textAttrs: 0,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList([x, y]),
      scalars: Float64List.fromList([height, 0, 1.0, 0]),
    ),
  ));
}

/// The logical-pixel box every text entity in [doc] occupies, padded, so the
/// pixel comparison can exclude it outright rather than trying to agree on
/// glyphs the vertices sink never draws.
///
/// Uses [DraftDocument.textMeasurer] — the same measurer the painter reads to
/// place the text — rather than a fresh [FlutterTextMeasurer], so the box
/// matches what the painter actually computed.
Rect comparisonTextMask(DraftDocument doc) {
  final camera = ViewportTransform.fit(doc.extents, kComparisonSize);
  var box = Rect.zero;
  var any = false;
  for (final slot in doc.entities.liveSlots) {
    final record = doc.entities.read(slot);
    if (record.kind != EntityKind.text && record.kind != EntityKind.attrib) {
      continue;
    }
    final local = entityBounds(
      kind: record.kind,
      payload: doc.geometry.read(record.geomIndex),
      measurer: doc.textMeasurer,
      textStyle: doc.textStyleOf(record.textStyle),
      textAttrs: record.textAttrs,
      text: record.text,
    );
    // Root-owned only: this fixture never places text inside a group or an
    // instance, so `local` is already in world space and needs no further
    // placement transform.
    for (final corner in [
      Vector2(local.minX, local.minY),
      Vector2(local.maxX, local.minY),
      Vector2(local.minX, local.maxY),
      Vector2(local.maxX, local.maxY),
    ]) {
      final screen = camera.worldToScreen(corner);
      final r = Rect.fromLTWH(screen.x, screen.y, 0, 0);
      box = any ? box.expandToInclude(r) : r;
      any = true;
    }
  }
  if (!any) return Rect.zero;
  // Real glyph rendering can overshoot the metric box slightly, and the
  // margin costs nothing: the strokes elsewhere in the fixture are placed
  // well clear of the text.
  return box.inflate(4);
}
