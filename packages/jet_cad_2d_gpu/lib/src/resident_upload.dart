import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'gpu_draw_backend.dart';
import 'resident_geometry.dart';

/// The production uploader: `ResidentGeometry.create`, then a
/// `GpuDrawBackend` over it. `null` when the platform has no GPU or the
/// upload failed -- `create` has already reported the failure through
/// `FlutterError.reportError` (its own doc comment), so nothing is reported
/// twice here.
///
/// [viewport] is the widget's logical size, the ceiling for the patch
/// targets; a `Size.zero` first layout still asks for a 1x1 ceiling rather
/// than a texture the driver refuses.
///
/// **Moved here from `jet_cad_2d_flutter`'s `resident_rebuilder.dart`** with
/// the GPU split: it is the only code that names both GPU types, and
/// `DraftCanvas` now reaches it through the registered `ResidentGpu`
/// (`installResidentGpu()`), never by name.
Future<ResidentFramePainter?> uploadResidentCollection(
  ResidentCollection collection,
  Size viewport, {
  required FlutterTextMeasurer measurer,
  required TextStyleRecord Function(Handle) textStyleOf,
}) async {
  final dpr = collection.devicePixelRatio;
  final geometry = await ResidentGeometry.create(
      collection.data, collection.instanceCount,
      texts: collection.texts,
      patches: collection.patches,
      devicePixelRatio: dpr,
      maxPatchWidth: math.max(1, (viewport.width * dpr).round()),
      maxPatchHeight: math.max(1, (viewport.height * dpr).round()));
  if (geometry == null) return null;
  return GpuDrawBackend(geometry, collection.collectionCamera,
      measurer: measurer, textStyleOf: textStyleOf);
}
