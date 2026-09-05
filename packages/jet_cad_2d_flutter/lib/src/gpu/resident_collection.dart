import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../draft_painter.dart';
import '../viewport_transform.dart';
import 'collection_frame.dart';
import 'geometry_collector.dart';
import 'resident_geometry.dart';
import 'resident_text.dart';
import 'text_patches.dart';

/// One rebuild's GPU-free product: what `ResidentGeometry.create` uploads,
/// plus what the three frame-read triggers compare against.
///
/// **Allocated at rebuild, read on the frame.** [data] and [texts] are the
/// collector's own copies (`GeometryCollector.data` and `.texts` each copy
/// on access -- read once here, never per frame); [tablesRevision],
/// [devicePixelRatio] and [collectionCamera] are what `ResidentRebuilder.noteFrame`
/// reads to decide whether the picture on screen was collected under the
/// tables, the display and the scale the frame is drawn at.
class ResidentCollection {
  const ResidentCollection({
    required this.data,
    required this.instanceCount,
    required this.texts,
    required this.patches,
    required this.collectionCamera,
    required this.collectionViewport,
    required this.devicePixelRatio,
    required this.tablesRevision,
    required this.skippedOps,
    required this.walkMicros,
    required this.classifyMicros,
  });

  final Float32List data;
  final int instanceCount;
  final List<ResidentTextRecord> texts;
  final List<TextPatch> patches;

  /// The frame's camera (Ruling F2): the live camera's scale and rotation,
  /// translated so the extents sit at the origin. `GpuDrawBackend` maps out
  /// of this space every frame.
  final ViewportTransform collectionCamera;
  final Size collectionViewport;
  final double devicePixelRatio;

  /// `document.tables.mutationRevision`, read before the walk.
  final int tablesRevision;
  final int skippedOps;
  final int walkMicros;
  final int classifyMicros;

  int get patchInstanceCount =>
      patches.fold(0, (sum, p) => sum + p.instanceCount);

  /// The budget row's number, before upload: main buffer plus every patch
  /// sub-buffer, as `ResidentGeometry.byteLength` will report it.
  int get byteLength => ResidentGeometry.byteLengthFor(instanceCount,
      patchInstances: patchInstanceCount);

  /// Walks [document] through [painter] under the frame [collectionFrameFor]
  /// gives for [live], then classifies. Synchronous; the caller (the
  /// rebuilder's post-frame callback) is what keeps it off the frame path.
  ///
  /// [painter] is the widget's own `DraftPainter` -- its `drawText` and
  /// `minTextCapPixels` are the walk's, so a `DRAW_TEXT=false` canvas
  /// collects no text and a canvas with level of detail on culls at the
  /// collection scale, exactly as the reference sink would at that scale.
  static ResidentCollection collect({
    required DraftDocument document,
    required DraftPainter painter,
    required ViewportTransform live,
    required double devicePixelRatio,
    required double pixelsPerPaperMm,
    required double lineweightScale,
    required TextMeasurer? measurer,
    required TextStyleRecord Function(Handle)? textStyleOf,
    double bandLowerScale = kBandLowerScale,
  }) {
    // Read before the walk: the revision the picture is *of*. A table edit
    // cannot land during the walk (one isolate), so before and after are
    // the same number; "before" is the one whose meaning does not depend on
    // that argument.
    final tablesRevision = document.tables.mutationRevision;
    final frame = collectionFrameFor(live, document.extents);
    final walk = Stopwatch()..start();
    final collector = GeometryCollector(
        pixelsPerPaperMm: pixelsPerPaperMm,
        devicePixelRatio: devicePixelRatio,
        lineweightScale: lineweightScale,
        measurer: measurer,
        textStyleOf: textStyleOf);
    painter.paint(collector, frame.camera, frame.viewport);
    // One copy each, at rebuild -- see the two getters' own doc comments.
    final data = collector.data;
    final texts = collector.texts;
    walk.stop();
    final classify = Stopwatch()..start();
    final patches = classifyTextPatches(data, collector.instanceCount, texts,
        devicePixelRatio: devicePixelRatio, bandLowerScale: bandLowerScale);
    classify.stop();
    return ResidentCollection(
      data: data,
      instanceCount: collector.instanceCount,
      texts: texts,
      patches: patches,
      collectionCamera: frame.camera,
      collectionViewport: frame.viewport,
      devicePixelRatio: devicePixelRatio,
      tablesRevision: tablesRevision,
      skippedOps: collector.skippedOps,
      walkMicros: walk.elapsedMicroseconds,
      classifyMicros: classify.elapsedMicroseconds,
    );
  }
}
