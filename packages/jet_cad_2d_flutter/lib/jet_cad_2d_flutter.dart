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
// unexported -- it is the one file allowed to import a GPU package, and its
// only public entry points (`gpuAvailable`, `debugSetGpuFactory`) are a test
// seam and a platform probe, neither of which an app assembling a frame
// needs to call directly. `instance_record.dart` stays unexported too: it is
// `GeometryCollector`'s own wire format, not something a caller writes.
export 'src/gpu/geometry_collector.dart';
export 'src/gpu/gpu_draw_backend.dart';
export 'src/gpu/resident_geometry.dart';
export 'src/reference_walk.dart';
export 'src/render_backend.dart';
export 'src/tile_cache.dart';
export 'src/viewport_transform.dart';
