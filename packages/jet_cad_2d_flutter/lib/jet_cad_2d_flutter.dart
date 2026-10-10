/// Flutter rendering layer for the `jet_cad_2d` engine.
library;

export 'src/camera_controller.dart';
export 'src/camera_gesture_detector.dart';
export 'src/canvas_draw_sink.dart';
export 'src/canvas_palette.dart';
export 'src/dark_canvas.dart';
export 'src/chrome_style.dart';
export 'src/vertices_draw_sink.dart';
export 'src/draft_canvas.dart';
export 'src/draft_painter.dart';
export 'src/draw_sink.dart';
export 'src/export/page_camera.dart';
export 'src/export/page_export.dart';
export 'src/export/pdf_draw_sink.dart';
export 'src/draw/arc_tool.dart';
export 'src/draw/circle_tool.dart';
export 'src/draw/placement_tool.dart';
export 'src/draw/line_tool.dart';
export 'src/draw/polyline_tool.dart';
export 'src/draw/rectangle_tool.dart';
export 'src/draw/text_tool.dart';
export 'src/flutter_text_measurer.dart';
export 'src/gesture_policy.dart';
// The resident backend's GPU-free half. The GPU half -- `ResidentGeometry`,
// `GpuDrawBackend`, the `flutter_scene` facade and `uploadResidentCollection`
// -- lives in package `jet_cad_2d_gpu`, so `flutter_scene` and its build hook
// never enter the build of an app that depends on this package. That package
// plugs in through `resident_gpu.dart`'s registry (`installResidentGpu()`);
// this one never imports it (`test/invariants/no_gpu_dependency_test.dart`).
export 'src/gpu/collection_frame.dart';
export 'src/gpu/frame_info.dart';
export 'src/gpu/geometry_collector.dart';
// `instance_record.dart` is `GeometryCollector`'s own wire format, not
// something a caller writes, so it stays unexported -- except for the record's
// size and its field offsets, which the GPU package's vertex layout derives
// its strides and attribute offsets from. `show` keeps the writers out.
export 'src/gpu/instance_record.dart'
    show kFloatsPerInstance, InstanceFieldOffset;
export 'src/gpu/resident_collection.dart';
export 'src/gpu/resident_gpu.dart';
export 'src/gpu/resident_layout.dart';
export 'src/gpu/resident_rebuilder.dart';
export 'src/gpu/resident_text.dart';
export 'src/gpu/text_compositor.dart';
export 'src/gpu/text_patches.dart';
export 'src/grip_cache.dart';
export 'src/grip_drag.dart';
export 'src/input_claim.dart';
export 'src/interaction_layer.dart';
export 'src/outline_cache.dart';
export 'src/page_chrome_painter.dart';
export 'src/page_fit.dart';
export 'src/page_notifier.dart';
export 'src/reference_walk.dart';
export 'src/render_backend.dart';
export 'src/ruler_frame.dart';
export 'src/ruler_painter.dart';
export 'src/select_gates.dart';
export 'src/select_tool.dart';
export 'src/selection.dart';
export 'src/selection_overlay.dart';
export 'src/selection_style.dart';
export 'src/snap_marker.dart';
export 'src/snap_settings.dart';
export 'src/symbol_gallery.dart';
export 'src/symbol_thumbnails.dart';
export 'src/tile_cache.dart';
export 'src/tool.dart';
export 'src/viewport_transform.dart';
