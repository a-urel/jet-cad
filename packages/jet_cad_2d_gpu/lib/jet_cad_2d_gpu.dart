/// The GPU-resident render backend for `jet_cad_2d_flutter`.
///
/// **Not a host package.** It depends on `flutter_scene`, whose build hook
/// compiles shaders with the engine's `impellerc`, and raises the Flutter
/// floor to 3.47. It exists apart from `jet_cad_2d_flutter` so that neither
/// reaches an app that never asks for `RenderBackend.residentGpu`. An app
/// that does -- the measurement harness -- calls [installResidentGpu] first
/// in `main`.
///
/// `gpu_facade.dart` is exported only for its test seams and its probe: its
/// own `export 'package:flutter_scene/src/gpu/gpu.dart';` republishes that
/// package's *entire* internal GPU shim -- an off-contract, pre-1.0
/// `lib/src/` API -- and `show` keeps that out of this barrel.
library;

export 'src/gpu_draw_backend.dart';
export 'src/gpu_facade.dart'
    show
        GpuContextFactory,
        debugSetGpuAvailable,
        debugSetGpuFactory,
        gpuAvailable;
export 'src/install.dart';
export 'src/resident_geometry.dart';
export 'src/resident_upload.dart';
