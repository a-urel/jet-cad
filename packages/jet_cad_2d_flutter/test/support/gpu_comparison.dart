/// Does the resident-GPU backend draw the same drawing `VerticesDrawSink`
/// does?
///
/// `sink_comparison.dart` compares `CanvasDrawSink` against `VerticesDrawSink`
/// pixel by pixel; this file is its sibling for the pair Plan B built --
/// `VerticesDrawSink`'s own triangles (the reference) against the collector's
/// buffer expanded through the Dart transcription of the vertex shader (the
/// resident arm). **Both arms go through the same rasterizer.** The question
/// this answers is whether the collector plus the vertex shader produce the
/// same triangles as `VerticesDrawSink`, not whether two rasterizers agree --
/// so `TriangleRasterizer` is held fixed and only the triangle source
/// changes. A GPU comparison is Task 11's device run; this is what
/// `flutter test` can gate before that.
///
/// **This instrument is coverage-only, and that is a real limit, not a
/// caveat.** `TriangleRasterizer.inked` is a boolean -- see its own doc,
/// "there is no partial coverage to threshold" -- so [differing] and
/// [overEight] below are always the same number and neither one measures
/// *colour* agreement. The per-channel half of the design document's
/// criterion 1 is not something this file can gate; it is gated separately,
/// by the record-level `argb` assertions in `geometry_collector_test.dart`
/// and `collector_differential_test.dart`, which compare colour channels a
/// coverage rasterizer cannot see at all. Do not read a passing
/// [ResidentAgreement] as a full criterion-1 measurement.
///
/// **Draw order is also unmeasured, and that is a repo non-negotiable, not
/// a minor gap.** `TriangleRasterizer._fill` is last-write-wins over
/// coverage with no depth test, so any permutation of emission order that
/// preserves the union of triangle footprints paints the same pixels --
/// draw order can only be pinned by a record-order assertion
/// (`collector_differential_test.dart`'s walk-order check), never by this
/// instrument.
///
/// **Geometry added INSIDE the existing footprint is invisible, and this is
/// proved rather than suspected.** [measureResidentAgreement] counts the
/// symmetric difference of two coverage unions, so a defect that only adds
/// triangles where ink already sits moves no pixel at all. The proof is
/// M-B7 against M-B15 (`task-9-report.md`): flipping every join wedge to the
/// wrong side of its corner and deleting every join outright produce the
/// *identical* reading, 26 differing pixels, and in both cases
/// `differing == referenceInk - residentInk` -- the resident set is a pure
/// subset of the reference's. A wrong-side wedge is wholly invented geometry
/// at every corner in the corpus and it contributes zero new pixels, because
/// it lands entirely within the union of the two adjacent segment quads.
///
/// **Task 9 makes this limit sharper, not smaller.** A dash GAP is visible
/// to this instrument -- it removes ink from inside a footprint that used to
/// be solid, which is exactly the kind of change [differing] does count. But
/// a fragment that is wrongly KEPT where it sits inside another primitive's
/// footprint is the same invisible case as before: the union of covered
/// pixels does not move, only which triangle (or, now, which fragment
/// decision) put the ink there. A dashed join wrongly drawn solid where a
/// solid segment already covers it is exactly this case.
///
/// So this instrument cannot see: a join emitted on both sides, a duplicated
/// instance, a segment quad overshooting into its neighbour's, or a miter
/// tip over-reaching inward. `sink_comparison.dart` carries a
/// `strayVerticesPixels` notion for exactly this class and this file has no
/// analogue. Later plans lean on this instrument; they must not read
/// agreement here as "the arms draw the same triangles", only as "the arms
/// cover the same pixels".
library;

import 'dart:typed_data';
import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'instance_expander.dart';
import 'triangle_rasterizer.dart';

/// What a resident-versus-reference comparison counted.
class ResidentAgreement {
  ResidentAgreement({
    required this.referenceInk,
    required this.residentInk,
    required this.differing,
    required this.overEight,
  });

  /// Pixels the reference inked.
  final int referenceInk;

  /// Pixels the resident arm inked.
  final int residentInk;

  /// Pixels where the two arms' coverage disagreed -- one inked, the other
  /// not. **Not a per-channel colour comparison**: see this file's doc.
  final int differing;

  /// Identical to [differing] here. `sink_comparison.dart`'s
  /// `AgreementReport` has no field of this name at all -- both the
  /// "differing by more than 2" and "differing by more than 8" thresholds
  /// its doc comment describes are per-channel colour distances, and
  /// `TriangleRasterizer.inked` carries no channel to take a distance on.
  /// Kept as a separate field anyway, equal to [differing] by construction,
  /// so a caller reading this file expecting `sink_comparison.dart`'s shape
  /// finds an honest number here rather than a name that used to mean
  /// something this file cannot measure.
  final int overEight;

  @override
  String toString() => 'ResidentAgreement(referenceInk: $referenceInk, '
      'residentInk: $residentInk, differing: $differing, '
      'overEight: $overEight)';
}

/// Draws [draw] through both arms at [size] and counts their disagreement.
///
/// **The two arms are driven at identity residual, in the same "collection
/// space" [draw]'s coordinates are written in, and the device scale is
/// applied separately to each -- not by handing either sink's own
/// `beginResidual` a `Transform2.scale(devicePixelRatio, devicePixelRatio)`.**
/// This is not a stylistic choice; the two classes document incompatible
/// things about the space a residual scale would land in:
///
///  - `VerticesDrawSink`'s buffer is in **logical** pixels -- its own doc,
///    "the buffer is in logical pixels, because that is the space the
///    `Canvas` this sink flushes into is in" -- and `_halfWidthFor` returns a
///    **logical**-pixel half-width, independent of the residual entirely.
///    Scaling the residual by `devicePixelRatio` would move the centreline
///    positions into device space while the half-width offset added to them
///    stayed in logical space, thinning every stroke by a factor of
///    `devicePixelRatio` relative to its length. `sink_comparison.dart`
///    avoids exactly this by keeping the sink at its own (here, identity)
///    residual and scaling the **captured triangle positions** by
///    `devicePixelRatio` in the observer, after the half-width has already
///    been added to them in logical space -- so position and width scale
///    together. This file does the same.
///  - `GeometryCollector._halfWidthFor` is the mirror image: it returns an
///    **already-device**-pixel half-width (`logical * devicePixelRatio`,
///    floored in device pixels), independent of the residual too. So the
///    collector is likewise driven at an identity residual, and it is
///    `expandInstances`' `collectionToDevice` argument -- not the residual --
///    that carries `Transform2.scale(devicePixelRatio, devicePixelRatio)`,
///    landing the transformed centreline positions in the same device-pixel
///    space the half-width was always measured in.
///
/// The brief's sample code for this function did the opposite of both: it
/// scaled the sink's residual and left the collector's `collectionToDevice`
/// at identity. The first run built against that sample produced a
/// near-total disagreement (see `task-9-report.md`), which is what motivated
/// re-deriving the scaling from each class's own space documentation instead
/// of tuning a threshold.
ResidentAgreement measureResidentAgreement(
  void Function(DrawSink sink) draw, {
  required Size size,
  required double devicePixelRatio,
  required double pixelsPerPaperMm,

  /// The `dashScale` `expandInstances` needs -- live logical pixels per
  /// collection unit. Every caller today drives both arms at the same
  /// camera the buffer was collected at, so the live-to-collection ratio is
  /// exactly `1.0`; a caller that ever animates the camera between the two
  /// arms would need to pass the real ratio here instead.
  required double dashScale,
}) {
  final w = (size.width * devicePixelRatio).round();
  final h = (size.height * devicePixelRatio).round();

  // The reference arm: `VerticesDrawSink`'s own triangles, at its own
  // (logical-pixel) residual, with the device scale applied to the captured
  // positions only -- mirroring `sink_comparison.dart`'s `_captureVertices`.
  final referenceRaster = TriangleRasterizer(w, h);
  final recorder = PictureRecorder();
  final sink = VerticesDrawSink(
    canvas: Canvas(recorder),
    pixelsPerPaperMm: pixelsPerPaperMm,
    devicePixelRatio: devicePixelRatio,
  )..observer = (positions, colors) {
      final scaled = Float32List(positions.length);
      for (var i = 0; i < positions.length; i++) {
        scaled[i] = positions[i] * devicePixelRatio;
      }
      referenceRaster.observe(scaled, colors);
    };
  sink.beginResidual(Transform2.identity());
  draw(sink);
  sink.endResidual();
  sink.flush();
  recorder.endRecording().dispose();

  // The resident arm: the collector's buffer, expanded by the Dart copy of
  // the vertex shader. The collector, like the sink, is driven at an
  // identity residual -- its half-width is already a device-pixel quantity
  // regardless of the residual -- and the device scale is supplied to
  // `expandInstances` as `collectionToDevice` instead, so the expanded
  // positions land in the same device-pixel space the half-width was
  // measured in.
  final collector = GeometryCollector(
      pixelsPerPaperMm: pixelsPerPaperMm, devicePixelRatio: devicePixelRatio);
  collector.beginResidual(Transform2.identity());
  draw(collector);
  collector.endResidual();
  final expanded = expandInstances(collector.data, collector.instanceCount,
      Transform2.scale(devicePixelRatio, devicePixelRatio),
      dashScale: dashScale);
  final residentRaster = TriangleRasterizer(w, h)
    ..observe(expanded.positions, expanded.colors, dash: expanded.dashVaryings);

  return _agreementOf(referenceRaster, residentRaster, w, h);
}

/// Draws [document] through both arms with the real painter, at [camera].
///
/// **The two arms take different routes through `DraftPainter` and that is
/// the point.** [measureResidentAgreement] drives each sink with the same
/// hand-written closure, which is sound only because neither
/// `VerticesDrawSink` nor `GeometryCollector` branches on `shadesDashes` --
/// the closure itself never has to. A dash does: `VerticesDrawSink
/// .shadesDashes` is false, so `DraftPainter` cuts the spans before handing
/// them to it; `GeometryCollector.shadesDashes` is true, so the painter
/// hands it the whole pattern via `beginDash`/`endDash` instead
/// (`draft_painter.dart`, the `sink.shadesDashes` branches). A closure
/// written here that dashed for one arm and not the other would be a THIRD
/// implementation of that branch, alongside the painter's own and the
/// pattern the shader (and `expandInstances`) reads -- and the branch is
/// exactly what this comparison exists to check. So this entry point drives
/// the real [DraftPainter] into both sinks instead of a hand-written
/// closure, and is a second, separate function rather than a replacement
/// for [measureResidentAgreement]: existing callers pass their own closures
/// to that one and do not go through a painter at all.
///
/// [dashScale] is always `1.0` here, not a parameter: both arms are painted
/// at [camera], the same camera the buffer is collected at, so the
/// live-to-collection ratio `expandInstances` needs is exactly `1.0` by
/// construction -- there is no second, "live" camera for either arm to
/// diverge from.
ResidentAgreement measurePaintedAgreement(
  DraftDocument document, {
  required ViewportTransform camera,
  required Size size,
  required double devicePixelRatio,
  required double pixelsPerPaperMm,
}) {
  final w = (size.width * devicePixelRatio).round();
  final h = (size.height * devicePixelRatio).round();
  final index = SpatialIndex(document);
  final resolver = DocumentStyleResolver(document);
  final painter =
      DraftPainter(document: document, index: index, resolver: resolver);

  // The reference arm: the real painter drives `VerticesDrawSink`, which
  // cuts dash gaps into separate spans (`shadesDashes == false`) before this
  // sink ever sees them -- so what reaches `observe` here is already solid
  // per-span geometry, same as `measureResidentAgreement`'s reference arm.
  final referenceRaster = TriangleRasterizer(w, h);
  final recorder = PictureRecorder();
  final sink = VerticesDrawSink(
    canvas: Canvas(recorder),
    pixelsPerPaperMm: pixelsPerPaperMm,
    devicePixelRatio: devicePixelRatio,
  )..observer = (positions, colors) {
      final scaled = Float32List(positions.length);
      for (var i = 0; i < positions.length; i++) {
        scaled[i] = positions[i] * devicePixelRatio;
      }
      referenceRaster.observe(scaled, colors);
    };
  painter.paint(sink, camera, size);
  sink.flush();
  recorder.endRecording().dispose();

  // The resident arm: the same painter drives `GeometryCollector`, which
  // keeps the whole pattern (`shadesDashes == true`) and hands it to the
  // shader as `v_dash` -- reproduced here by `expandInstances`, exactly as
  // in `measureResidentAgreement`.
  final collector = GeometryCollector(
      pixelsPerPaperMm: pixelsPerPaperMm, devicePixelRatio: devicePixelRatio);
  painter.paint(collector, camera, size);
  final expanded = expandInstances(collector.data, collector.instanceCount,
      Transform2.scale(devicePixelRatio, devicePixelRatio),
      // Both arms are painted at `camera`, the same camera the buffer is
      // collected at -- see this function's own doc.
      dashScale: 1.0);
  final residentRaster = TriangleRasterizer(w, h)
    ..observe(expanded.positions, expanded.colors, dash: expanded.dashVaryings);

  return _agreementOf(referenceRaster, residentRaster, w, h);
}

/// The pixel-by-pixel coverage comparison both entry points share.
ResidentAgreement _agreementOf(
    TriangleRasterizer reference, TriangleRasterizer resident, int w, int h) {
  var referenceInk = 0, residentInk = 0, differing = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final a = reference.inked(x, y);
      final b = resident.inked(x, y);
      if (a) referenceInk++;
      if (b) residentInk++;
      if (a != b) differing++;
    }
  }
  return ResidentAgreement(
      referenceInk: referenceInk,
      residentInk: residentInk,
      differing: differing,
      // Coverage-only: see the class doc. Equal to `differing` by
      // construction, not a second, looser threshold.
      overEight: differing);
}
