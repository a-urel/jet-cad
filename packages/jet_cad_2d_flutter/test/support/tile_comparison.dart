// Live frame against tiled frame, byte for byte.
//
// **Why not `measureAgreement`.** That instrument's vertices arm rasterises in
// Dart (`support/sink_comparison.dart`), so it never reaches a `Canvas` and
// never executes a `drawImageRect`. A tile is invisible to it.
//
// **Why zero rather than a tolerance.** `quantiseCamera` puts every tile
// destination on whole device pixels at every camera, so a blit is a 1:1
// texel-to-pixel copy and there is nothing for a tolerance to absorb. A
// tolerance here would hide exactly the defects the criteria exist to catch.
//
// **What this cannot prove.** Software Skia does not antialias `drawVertices`
// at all — `drawvertices_antialiasing_test.dart` pins that, in its own words
// as "a fact about `flutter_test`'s software Skia, not about this codebase" —
// so this instrument cannot produce an antialiased seam and a zero result here
// is partly a property of the instrument. It proves geometric completeness:
// no pixel missing, none drawn twice, no clipping arithmetic error. Accepted
// gap G1 owns the rest, and mutant M3 is deferred to it. **M15 is the mutant
// this instrument fires**, and it moves pixels software Skia renders perfectly
// well.

import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'tile_fixture.dart';

class InkReport {
  const InkReport({
    required this.liveInk,
    required this.tiledInk,
    required this.strayPixels,
    required this.uncoveredPixels,
    required this.differingPixels,
  });

  /// Non-transparent pixels in the live capture.
  final int liveInk;
  final int tiledInk;

  /// Tiled pixels with ink where live has none.
  final int strayPixels;

  /// Live pixels with ink where tiled has none.
  final int uncoveredPixels;

  /// Pixels whose four bytes differ at all, stray and uncovered included.
  final int differingPixels;

  @override
  String toString() => 'InkReport(live: $liveInk, tiled: $tiledInk, '
      'stray: $strayPixels, uncovered: $uncoveredPixels, '
      'differing: $differingPixels)';
}

Future<Uint8List> _capture(void Function(Canvas canvas) draw) async {
  final width = (kTileViewport.width * kTileDpr).round();
  final height = (kTileViewport.height * kTileDpr).round();
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(kTileDpr);
  canvas.clipRect(Offset.zero & kTileViewport);
  draw(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  final data = await image.toByteData();
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Paints [rig] both ways and compares.
///
/// The live arm goes through the **quantised** camera, not the raw one: that is
/// the rule, not a concession to the tiled arm. This instrument quantises its
/// own live arm, deliberately, at the call below -- `DraftCanvas` is not
/// involved and is not on this path at all. `DraftCanvas` itself quantises
/// only inside its tiled branch; its default (non-tiled) path draws the raw
/// camera untouched. Quantising here is what makes the two arms the same
/// drawing seen twice rather than two different drawings.
Future<InkReport> measureTiledAgreement(TileRig rig) async {
  final quantised = quantiseCamera(rig.camera, kTileDpr);

  final live = await _capture((canvas) {
    rig.painter.debugRebaseOrigin =
        rebaseOriginFor(quantised.visibleWorld(kTileViewport));
    rig.sink.canvas = canvas;
    rig.vertices.canvas = canvas;
    rig.painter.paint(rig.vertices, quantised, kTileViewport);
    rig.vertices.flush();
    rig.painter.debugRebaseOrigin = null;
  });

  final tiled = await _capture((canvas) {
    rig.cache.paintFrame(
      canvas: canvas,
      viewport: kTileViewport,
      devicePixelRatio: kTileDpr,
      camera: rig.camera,
      painter: rig.painter,
      sink: rig.sink,
      vertices: rig.vertices,
      tablesRevision: rig.doc.tables.mutationRevision,
    );
  });

  var liveInk = 0, tiledInk = 0, stray = 0, uncovered = 0, differing = 0;
  for (var i = 0; i < live.length; i += 4) {
    final liveHasInk = live[i + 3] != 0;
    final tiledHasInk = tiled[i + 3] != 0;
    if (liveHasInk) liveInk++;
    if (tiledHasInk) tiledInk++;
    if (tiledHasInk && !liveHasInk) stray++;
    if (liveHasInk && !tiledHasInk) uncovered++;
    if (live[i] != tiled[i] ||
        live[i + 1] != tiled[i + 1] ||
        live[i + 2] != tiled[i + 2] ||
        live[i + 3] != tiled[i + 3]) {
      differing++;
    }
  }
  return InkReport(
      liveInk: liveInk,
      tiledInk: tiledInk,
      strayPixels: stray,
      uncoveredPixels: uncovered,
      differingPixels: differing);
}

/// The gate. Zero stray, zero uncovered, zero differing — and a real drawing.
Future<InkReport> expectTiledEqualsLive(TileRig rig,
    {int minimumInk = 500}) async {
  final report = await measureTiledAgreement(rig);
  // The floor first. A comparison of two blank captures agrees perfectly and
  // proves nothing, which is the failure mode this whole plan's spike named.
  expect(report.liveInk, greaterThan(minimumInk),
      reason: 'the live arm must actually draw: $report');
  expect(report.tiledInk, greaterThan(minimumInk),
      reason: 'the tiled arm must actually draw: $report');
  expect(report.strayPixels, 0, reason: '$report');
  expect(report.uncoveredPixels, 0, reason: '$report');
  expect(report.differingPixels, 0, reason: '$report');
  return report;
}

/// The **live** frame's device pixels, RGBA, row-major at [kTileDpr].
///
/// The differential gate above reduces two captures to counts; a test that
/// needs to ask *where* the ink is — "does this stroke really reach into the
/// tile column its centreline is not in" — needs the pixels themselves. Same
/// quantised camera as [measureTiledAgreement]'s live arm, for the same
/// reason: the two arms must be one drawing seen twice.
Future<Uint8List> captureLiveFrame(TileRig rig) => _capture((canvas) {
      final quantised = quantiseCamera(rig.camera, kTileDpr);
      rig.painter.debugRebaseOrigin =
          rebaseOriginFor(quantised.visibleWorld(kTileViewport));
      rig.sink.canvas = canvas;
      rig.vertices.canvas = canvas;
      rig.painter.paint(rig.vertices, quantised, kTileViewport);
      rig.vertices.flush();
      rig.painter.debugRebaseOrigin = null;
    });

/// One fallback sample: a frame that is part blit and part live walk, compared
/// against the live frame at the same camera.
///
/// **Each sample owns its cache.** A sweep that panned one rig across offsets
/// would inherit tiles from the previous offset and become a warm-tile
/// comparison -- one of the three arrangements that failed to detect a
/// crippled query before this instrument existed.
Future<InkReport> measureFallbackAgreement(
  DraftDocument Function(FlutterTextMeasurer) of,
  FlutterTextMeasurer measurer,
  Offset pan, {
  int minimumInk = 500,
}) async {
  final rig = TileRig(
      tileDevicePixels: 64, tilesBakedPerFrame: 1000, document: of(measurer));
  try {
    // Cover the viewport, so the strip that enters next has blitted tiles on
    // its interior side.
    rig.paintOnce();
    rig.cache.resetCounters();
    // One tile a frame, so the entering band stays uncovered and the fallback
    // owes it.
    rig.cache.bakeBudgetDevicePixels = 64 * 64;
    rig.panBy(pan.dx, pan.dy);

    final report = await measureTiledAgreement(rig);

    // Anti-vacuity, and every clause of it was earned by an arrangement that
    // passed while proving nothing.
    expect(rig.cache.liveDrawCount, greaterThan(0),
        reason: 'pan $pan ran no fallback: $report');
    expect(rig.cache.blitCount, greaterThan(0),
        reason: 'pan $pan blitted nothing, so nothing was partly baked');
    final strip = rig.cache.debugLastStrip;
    expect(strip, isNotNull, reason: 'pan $pan recorded no strip');
    // The clause `bakeCount`/`liveDrawCount` cannot supply: `uncovered` is a
    // bounding rectangle, so an L-shaped uncovered set bounds to the whole
    // viewport and leaves no interior edge for a crippled query to lose ink
    // across.
    expect(strip != Offset.zero & kTileViewport, isTrue,
        reason: 'pan $pan left no interior strip edge: strip=$strip');
    expect(report.liveInk, greaterThan(minimumInk), reason: '$report');
    expect(report.tiledInk, greaterThan(minimumInk), reason: '$report');
    return report;
  } finally {
    rig.dispose();
  }
}

/// [measureFallbackAgreement] over a set of pan offsets, each independent.
Future<List<InkReport>> sweepFallbackAgreement({
  required DraftDocument Function(FlutterTextMeasurer) of,
  required List<Offset> offsets,
  int minimumInk = 500,
}) async {
  final reports = <InkReport>[];
  for (final offset in offsets) {
    final measurer = FlutterTextMeasurer();
    try {
      reports.add(await measureFallbackAgreement(of, measurer, offset,
          minimumInk: minimumInk));
    } finally {
      measurer.clear();
    }
  }
  return reports;
}
