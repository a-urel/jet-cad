/// Flutter rendering layer for the `jet_cad_2d` engine.
library;

export 'src/camera_controller.dart';
export 'src/canvas_draw_sink.dart';
export 'src/vertices_draw_sink.dart';
export 'src/draft_canvas.dart';
export 'src/draft_painter.dart';
export 'src/draw_sink.dart';
export 'src/flutter_text_measurer.dart';
// The resident-GPU backend's own public surface. `gpu_facade.dart` stays
// unexported -- it is the one file allowed to import a GPU package, and it
// carries more than the two small functions (`gpuAvailable`,
// `debugSetGpuFactory`) an app assembling a frame might want: its
// `export 'package:flutter_scene/src/gpu/gpu.dart';` republishes that
// package's *entire* internal GPU shim -- an off-contract, pre-1.0 `lib/src/`
// API this package depends on but does not control. Exporting
// `gpu_facade.dart` from this barrel would republish all of that through
// `jet_cad_2d_flutter`'s own public API, which is the thing this barrel
// exists to not do; the two small functions are not enough reason to accept
// that. `ResidentGeometry`'s own handful of members that still resolve
// through that shim (`kStrokeVertexLayout` and its five `gpu.*`-typed
// getters) are marked `@internal` for the same reason, one file down.
// `instance_record.dart` stays unexported too, for an unrelated reason: it is
// `GeometryCollector`'s own wire format, not something a caller writes.
export 'src/gpu/geometry_collector.dart';
export 'src/gpu/gpu_draw_backend.dart';
export 'src/gpu/resident_geometry.dart';
export 'src/reference_walk.dart';
export 'src/render_backend.dart';
export 'src/tile_cache.dart';
export 'src/viewport_transform.dart';
