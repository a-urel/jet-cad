import 'dart:ui' show Size;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'gpu_facade.dart' show gpuAvailable;
import 'resident_upload.dart';

/// The real [ResidentGpu]: Flutter GPU through `flutter_scene`'s shim.
///
/// [available] asks [gpuAvailable] on every read rather than once at install,
/// so a probe answered (or a test seam flipped) after install is what
/// `resolveBackend` sees. `gpuAvailable` caches its own answer, so the read
/// still costs nothing after the first.
final class _FlutterGpuResident implements ResidentGpu {
  const _FlutterGpuResident();

  @override
  bool get available => gpuAvailable();

  @override
  Future<ResidentFramePainter?> upload(
    ResidentCollection collection,
    Size viewport, {
    required FlutterTextMeasurer measurer,
    required TextStyleRecord Function(Handle) textStyleOf,
  }) =>
      uploadResidentCollection(collection, viewport,
          measurer: measurer, textStyleOf: textStyleOf);
}

const ResidentGpu _instance = _FlutterGpuResident();

/// Registers the resident GPU with `jet_cad_2d_flutter`, so a `DraftCanvas`
/// asked for `RenderBackend.residentGpu` draws through `GpuDrawBackend` where
/// the platform has Flutter GPU.
///
/// **Call it first in `main`,** before any `runApp`: a canvas resolves its
/// backend when it is attached, and one attached before this call falls back
/// to `vertices` (and says so once).
///
/// **Idempotent.** Every call registers the same instance; calling it twice
/// leaves exactly one registered. Only the harness calls it -- a host that
/// never asks for `residentGpu` neither calls it nor depends on this package.
void installResidentGpu() {
  if (identical(registeredResidentGpu, _instance)) return;
  registerResidentGpu(_instance);
}
