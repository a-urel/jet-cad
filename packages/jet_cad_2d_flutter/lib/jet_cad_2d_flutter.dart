/// Flutter rendering layer for the `jet_cad_2d` engine.
library;

export 'src/camera_controller.dart';
export 'src/camera_gesture_detector.dart';
export 'src/canvas_draw_sink.dart';
export 'src/chrome_style.dart';
export 'src/vertices_draw_sink.dart';
export 'src/draft_canvas.dart';
export 'src/draft_painter.dart';
export 'src/draw_sink.dart';
export 'src/draw/arc_tool.dart';
export 'src/draw/circle_tool.dart';
export 'src/draw/placement_tool.dart';
export 'src/draw/line_tool.dart';
export 'src/draw/polyline_tool.dart';
export 'src/draw/rectangle_tool.dart';
export 'src/draw/text_tool.dart';
export 'src/flutter_text_measurer.dart';
export 'src/gesture_policy.dart';
// The resident-GPU backend's own public surface. `gpu_facade.dart` stays
// unexported -- it is the one file allowed to import a GPU package, and it
// carries more than the two small functions (`gpuAvailable`,
// `debugSetGpuFactory`) and the public typedef `GpuContextFactory` an app
// assembling a frame might want: its
// `export 'package:flutter_scene/src/gpu/gpu.dart';` republishes that
// package's *entire* internal GPU shim -- an off-contract, pre-1.0 `lib/src/`
// API this package depends on but does not control. Exporting
// `gpu_facade.dart` from this barrel would republish all of that through
// `jet_cad_2d_flutter`'s own public API, which is the thing this barrel
// exists to not do; these members are not enough reason to accept
// that. `ResidentGeometry`'s own handful of members that still resolve
// through that shim (`kInstanceVertexLayout` and its five `gpu.*`-typed
// getters) are marked `@internal` for the same reason, one file down.
// `instance_record.dart` stays unexported too, for an unrelated reason: it is
// `GeometryCollector`'s own wire format, not something a caller writes.
//
// One symbol from that file is the exception: `debugSetGpuAvailable` (Ruling
// F14) is the seam a `DraftCanvas` widget test needs to take the
// `residentGpu` path without a GPU, and callers reach it through this
// barrel like everything else. `show` filters the export down to that one
// name -- it does not re-admit the wildcard `flutter_scene` re-export the
// paragraph above is about.
export 'src/gpu/gpu_facade.dart' show debugSetGpuAvailable;
export 'src/gpu/collection_frame.dart';
export 'src/gpu/geometry_collector.dart';
export 'src/gpu/gpu_draw_backend.dart';
export 'src/gpu/resident_collection.dart';
export 'src/gpu/resident_geometry.dart';
export 'src/gpu/resident_rebuilder.dart';
export 'src/gpu/resident_text.dart';
export 'src/gpu/text_compositor.dart';
export 'src/gpu/text_patches.dart';
export 'src/grip_cache.dart';
export 'src/grip_drag.dart';
export 'src/interaction_layer.dart';
export 'src/outline_cache.dart';
export 'src/page_chrome_painter.dart';
export 'src/page_fit.dart';
export 'src/page_notifier.dart';
export 'src/reference_walk.dart';
export 'src/render_backend.dart';
export 'src/ruler_frame.dart';
export 'src/ruler_painter.dart';
export 'src/select_tool.dart';
export 'src/selection.dart';
export 'src/selection_overlay.dart';
export 'src/selection_style.dart';
export 'src/snap_marker.dart';
export 'src/snap_settings.dart';
export 'src/tile_cache.dart';
export 'src/tool.dart';
export 'src/viewport_transform.dart';
