import 'dart:ui' show Size;

import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../flutter_text_measurer.dart';
import 'resident_collection.dart';
import 'resident_rebuilder.dart';

/// The seam between this package and a GPU that can serve
/// `RenderBackend.residentGpu`.
///
/// **Why a registry, and not a dependency.** The resident backend's GPU code
/// (`ResidentGeometry`, `GpuDrawBackend`, the `flutter_scene` shim they reach
/// the GPU through) lives in package `jet_cad_2d_gpu`, so that
/// `flutter_scene` and its build hook never enter the build of an app that
/// depends on this package and never asks for the GPU -- which is every
/// host. This package keeps everything GPU-free (the collection, the
/// rebuilder, the compositor, `DraftCanvas`) and asks the registry, at the
/// moment a canvas is attached, whether a GPU was installed:
///
/// - `resolveBackend(RenderBackend.residentGpu)` gives `residentGpu` only
///   when one is registered and [available]; otherwise `vertices`, and
///   `DraftCanvas` reports the fallback once per process;
/// - `DraftCanvas`'s default uploader is the registered one's [upload].
///
/// An app installs the real one with `installResidentGpu()` from
/// `package:jet_cad_2d_gpu/jet_cad_2d_gpu.dart`, first thing in `main`.
/// Tests register a fake and clear it in `tearDown`.
abstract interface class ResidentGpu {
  /// Whether this platform can serve the resident backend now. Read once per
  /// `DraftCanvas` attachment, never per frame.
  bool get available;

  /// Uploads [collection] and returns the painter the frame draws through,
  /// or `null` when it cannot (the upload failed, or there is no GPU after
  /// all). [viewport] is the canvas's logical size, the ceiling for the
  /// patch targets.
  Future<ResidentFramePainter?> upload(
    ResidentCollection collection,
    Size viewport, {
    required FlutterTextMeasurer measurer,
    required TextStyleRecord Function(Handle) textStyleOf,
  });
}

ResidentGpu? _registered;

/// Registers [gpu] as the process's resident GPU; `null` clears the
/// registration. The last registration wins.
///
/// **Process-wide state,** like the probe cache it replaces in this package:
/// a test that registers one clears it in `tearDown`.
void registerResidentGpu(ResidentGpu? gpu) {
  _registered = gpu;
}

/// The registered resident GPU, or `null` when none is installed.
ResidentGpu? get registeredResidentGpu => _registered;
