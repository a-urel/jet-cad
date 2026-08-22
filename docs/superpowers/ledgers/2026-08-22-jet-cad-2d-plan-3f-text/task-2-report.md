# Task 2 report: FlutterTextMeasurer splits into two caches

## Step 2: failing-test output (before the rewrite)

```
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (105.0.0 available)
  analyzer 13.3.0 (14.1.0 available)
  code_assets 1.2.1 (2.0.0 available)
  hooks 2.1.0 (2.2.0 available)
  lucide_icons_flutter 3.1.15 (3.1.17 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  objective_c 9.5.0 (9.6.0 available)
  package_config 2.2.0 (3.0.0 available)
  record_use 1.1.0 (1.1.1 available)
  shadcn_ui 0.55.1 (0.56.1 available)
  source_maps 0.10.13 (0.10.14 available)
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/flutter_text_measurer_test.dart
test/flutter_text_measurer_test.dart:33:35: Error: No named parameter with the name 'paragraphLimit'.
    final m = FlutterTextMeasurer(paragraphLimit: 2);
                                  ^^^^^^^^^^^^^^
lib/src/flutter_text_measurer.dart:41:3: Context: Found this candidate, but the arguments don't match.
  FlutterTextMeasurer({this.limit = kParagraphCacheLimit});
  ^^^^^^^^^^^^^^^^^^^
test/flutter_text_measurer_test.dart:163:35: Error: No named parameter with the name 'paragraphLimit'.
    final m = FlutterTextMeasurer(paragraphLimit: 4, metricsLimit: 1024);
                                  ^^^^^^^^^^^^^^
lib/src/flutter_text_measurer.dart:41:3: Context: Found this candidate, but the arguments don't match.
  FlutterTextMeasurer({this.limit = kParagraphCacheLimit});
  ^^^^^^^^^^^^^^^^^^^
test/flutter_text_measurer_test.dart:185:35: Error: No named parameter with the name 'paragraphLimit'.
    final m = FlutterTextMeasurer(paragraphLimit: 512, metricsLimit: 2);
                                  ^^^^^^^^^^^^^^
lib/src/flutter_text_measurer.dart:41:3: Context: Found this candidate, but the arguments don't match.
  FlutterTextMeasurer({this.limit = kParagraphCacheLimit});
  ^^^^^^^^^^^^^^^^^^^
test/flutter_text_measurer_test.dart:91:21: Error: The getter 'paragraphEvictionCount' isn't defined for the type 'FlutterTextMeasurer'.
 - 'FlutterTextMeasurer' is from 'package:jet_cad_2d_flutter/src/flutter_text_measurer.dart' ('lib/src/flutter_text_measurer.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'paragraphEvictionCount'.
    expect(measurer.paragraphEvictionCount, 0);
                    ^^^^^^^^^^^^^^^^^^^^^^
test/flutter_text_measurer_test.dart:156:14: Error: The getter 'liveMetricsCount' isn't defined for the type 'FlutterTextMeasurer'.
 - 'FlutterTextMeasurer' is from 'package:jet_cad_2d_flutter/src/flutter_text_measurer.dart' ('lib/src/flutter_text_measurer.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'liveMetricsCount'.
    expect(m.liveMetricsCount, 1);
             ^^^^^^^^^^^^^^^^
test/flutter_text_measurer_test.dart:199:14: Error: The getter 'liveMetricsCount' isn't defined for the type 'FlutterTextMeasurer'.
 - 'FlutterTextMeasurer' is from 'package:jet_cad_2d_flutter/src/flutter_text_measurer.dart' ('lib/src/flutter_text_measurer.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'liveMetricsCount'.
    expect(m.liveMetricsCount, 1);
             ^^^^^^^^^^^^^^^^
test/flutter_text_measurer_test.dart:202:14: Error: The getter 'liveMetricsCount' isn't defined for the type 'FlutterTextMeasurer'.
 - 'FlutterTextMeasurer' is from 'package:jet_cad_2d_flutter/src/flutter_text_measurer.dart' ('lib/src/flutter_text_measurer.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'liveMetricsCount'.
    expect(m.liveMetricsCount, 0);
             ^^^^^^^^^^^^^^^^
00:00 +0 -1: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/flutter_text_measurer_test.dart [E]
  Failed to load "/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/flutter_text_measurer_test.dart":
  Compilation failed for testPath=/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/flutter_text_measurer_test.dart: test/flutter_text_measurer_test.dart:33:35: Error: No named parameter with the name 'paragraphLimit'.
      final m = FlutterTextMeasurer(paragraphLimit: 2);
                                    ^^^^^^^^^^^^^^
  lib/src/flutter_text_measurer.dart:41:3: Context: Found this candidate, but the arguments don't match.
    FlutterTextMeasurer({this.limit = kParagraphCacheLimit});
    ^^^^^^^^^^^^^^^^^^^
  test/flutter_text_measurer_test.dart:163:35: Error: No named parameter with the name 'paragraphLimit'.
      final m = FlutterTextMeasurer(paragraphLimit: 4, metricsLimit: 1024);
                                    ^^^^^^^^^^^^^^
  lib/src/flutter_text_measurer.dart:41:3: Context: Found this candidate, but the arguments don't match.
    FlutterTextMeasurer({this.limit = kParagraphCacheLimit});
    ^^^^^^^^^^^^^^^^^^^
  test/flutter_text_measurer_test.dart:185:35: Error: No named parameter with the name 'paragraphLimit'.
      final m = FlutterTextMeasurer(paragraphLimit: 512, metricsLimit: 2);
                                    ^^^^^^^^^^^^^^
  lib/src/flutter_text_measurer.dart:41:3: Context: Found this candidate, but the arguments don't match.
    FlutterTextMeasurer({this.limit = kParagraphCacheLimit});
    ^^^^^^^^^^^^^^^^^^^
  test/flutter_text_measurer_test.dart:91:21: Error: The getter 'paragraphEvictionCount' isn't defined for the type 'FlutterTextMeasurer'.
   - 'FlutterTextMeasurer' is from 'package:jet_cad_2d_flutter/src/flutter_text_measurer.dart' ('lib/src/flutter_text_measurer.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'paragraphEvictionCount'.
      expect(measurer.paragraphEvictionCount, 0);
                      ^^^^^^^^^^^^^^^^^^^^^^
  test/flutter_text_measurer_test.dart:156:14: Error: The getter 'liveMetricsCount' isn't defined for the type 'FlutterTextMeasurer'.
   - 'FlutterTextMeasurer' is from 'package:jet_cad_2d_flutter/src/flutter_text_measurer.dart' ('lib/src/flutter_text_measurer.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'liveMetricsCount'.
      expect(m.liveMetricsCount, 1);
               ^^^^^^^^^^^^^^^^
  test/flutter_text_measurer_test.dart:199:14: Error: The getter 'liveMetricsCount' isn't defined for the type 'FlutterTextMeasurer'.
   - 'FlutterTextMeasurer' is from 'package:jet_cad_2d_flutter/src/flutter_text_measurer.dart' ('lib/src/flutter_text_measurer.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'liveMetricsCount'.
      expect(m.liveMetricsCount, 1);
               ^^^^^^^^^^^^^^^^
  test/flutter_text_measurer_test.dart:202:14: Error: The getter 'liveMetricsCount' isn't defined for the type 'FlutterTextMeasurer'.
   - 'FlutterTextMeasurer' is from 'package:jet_cad_2d_flutter/src/flutter_text_measurer.dart' ('lib/src/flutter_text_measurer.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'liveMetricsCount'.
      expect(m.liveMetricsCount, 0);
               ^^^^^^^^^^^^^^^^
  .
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/flutter_text_measurer_test.dart: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/flutter_text_measurer_test.dart
```

## Step 4: passing-test output (after the rewrite)

```
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (105.0.0 available)
  analyzer 13.3.0 (14.1.0 available)
  code_assets 1.2.1 (2.0.0 available)
  hooks 2.1.0 (2.2.0 available)
  lucide_icons_flutter 3.1.15 (3.1.17 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  objective_c 9.5.0 (9.6.0 available)
  package_config 2.2.0 (3.0.0 available)
  record_use 1.1.0 (1.1.1 available)
  shadcn_ui 0.55.1 (0.56.1 available)
  source_maps 0.10.13 (0.10.14 available)
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/flutter_text_measurer_test.dart
00:00 +0: the same string in two colours is two entries, not one
00:00 +1: a repeat request lays out nothing and allocates no metrics
00:00 +2: eviction disposes the paragraph
00:00 +3: metrics are cap-height based and taken at the nominal size
00:00 +4: an empty string measures zero, not the negative float floor
00:00 +5: resetCounters zeroes the counters and keeps the cache warm
00:00 +6: TextKeySink keys the same triple this cache does
00:00 +7: measure disposes its probe and leaves no paragraph entry
00:00 +8: a metrics sweep does not evict drawn paragraphs
00:00 +9: the metrics map evicts on its own bound, and it is not the paragraph one
00:00 +10: clear empties both maps
00:00 +11: All tests passed!
```

## Step 5: whole widget suite — `flutter test`

```
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (105.0.0 available)
  analyzer 13.3.0 (14.1.0 available)
  code_assets 1.2.1 (2.0.0 available)
  hooks 2.1.0 (2.2.0 available)
  lucide_icons_flutter 3.1.15 (3.1.17 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  objective_c 9.5.0 (9.6.0 available)
  package_config 2.2.0 (3.0.0 available)
  record_use 1.1.0 (1.1.1 available)
  shadcn_ui 0.55.1 (0.56.1 available)
  source_maps 0.10.13 (0.10.14 available)
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/large_coordinate_test.dart
00:00 +0: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/large_coordinate_test.dart: every residual reaching Canvas is small at 4.5e6
00:00 +1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/large_coordinate_test.dart: every coordinate reaching Canvas is small at 4.5e6
00:00 +2: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/large_coordinate_test.dart: recorded points reproduce world coordinates through the residual
00:00 +3: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/large_coordinate_test.dart: with rebasing disabled, float32 rounding is observable
00:00 +4: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/large_coordinate_test.dart: at the origin the rebase changes nothing measurable
00:00 +5: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/camera_controller_test.dart: rebaseOriginFor is stable while the camera moves within one grid step
00:00 +6: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/camera_controller_test.dart: rebaseOriginFor lands on the grid, at or below the view centre
00:00 +7: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/camera_controller_test.dart: rebaseOriginFor leaves a residual float32 can carry, where the raw coordinate is already lossy
00:00 +8: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/camera_controller_test.dart: rebaseOriginFor derives its step from the view span, so it works zoomed out
00:00 +9: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/camera_controller_test.dart: rebaseOriginFor snaps downward on negative coordinates, not toward zero
00:00 +10: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/camera_controller_test.dart: rebaseOriginFor a degenerate view has its origin at the world origin
00:00 +11: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/camera_controller_test.dart: CameraController panBy moves the screen position of a world point by the delta
00:00 +12: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/camera_controller_test.dart: CameraController panBy notifies, so a repaint boundary knows the frame is stale
00:00 +13: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/camera_controller_test.dart: CameraController zoomAt keeps the world point under the cursor fixed
00:00 +14: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/camera_controller_test.dart: CameraController zoomAt multiplies the scale by the factor
00:00 +15: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/camera_controller_test.dart: CameraController zoomAt ignores a factor that would make the camera singular
00:00 +16: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a segment becomes two triangles a half-width either side of it
00:00 +17: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: the residual is baked into the positions, not pushed on the canvas
00:00 +18: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: stroke width is device pixels under a non-uniform residual
00:00 +19: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a polyline of n points emits n-1 segments plus a join at each corner
00:00 +20: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a closed polyline draws its closing segment and seam join
00:00 +21: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: colour rides on the vertices, so one buffer carries every colour
00:00 +22: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: draw order survives batching: segments stay in emission order
00:00 +23: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: draw order survives the flush itself, not just the pre-flush buffer
00:00 +24: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: one flush, one draw call, whatever the colours
00:00 +25: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a zero-length segment emits nothing rather than a NaN normal
00:00 +26: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: the batched buffers survive a residual ending
00:00 +27: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: the segment count is what a rig reads to compare sinks
00:00 +28: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: the batch reaches the Canvas before the text it was batched before
00:00 +29: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: an arc is flattened, and its ends sit on the arc
00:00 +30: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: the flattened arc stays within a quarter pixel of the true one
00:00 +31: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: the segment count follows the arc as the residual scales it
00:00 +32: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a non-uniform residual turns a circle into an ellipse
00:00 +33: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a point is a square of the stroke width, at the residual
00:00 +34: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a circle closes on itself
00:00 +35: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: an unbatchable op flushes first, so draw order holds across it
00:00 +36: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a stroke above the floor keeps its exact width, not a rounded one
00:00 +37: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a sub-pixel stroke gets one device pixel and loses alpha for it
00:00 +38: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: the floor is device pixels, so it moves with the ratio
00:00 +39: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a lineweight of zero is a hairline at full alpha
00:00 +40: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: every emitter fades, not just the straight one
00:00 +41: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: the fade multiplies the style alpha rather than replacing it
00:00 +42: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a polygon fill emits exactly the triangles it was handed
00:00 +43: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a fill on a hairline layer keeps full alpha
00:00 +44: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a polygon fill is baked into the positions, not pushed on the canvas
00:00 +45: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: an empty triangle list draws nothing, defensively
00:00 +46: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: a text leaf draws one text op under its own composed residual
00:00 +47: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: a text leaf draws one text op under its own composed residual
00:00 +48: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: a text leaf draws one text op under its own composed residual
00:00 +49: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: a text leaf draws one text op under its own composed residual
00:00 +50: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: a text leaf draws one text op under its own composed residual
00:00 +51: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: a text leaf draws one text op under its own composed residual
00:00 +52: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: a text leaf draws one text op under its own composed residual
00:00 +53: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: a text leaf draws one text op under its own composed residual
00:00 +54: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: a text leaf draws one text op under its own composed residual
00:00 +55: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: a text leaf draws one text op under its own composed residual
00:00 +56: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: a text leaf draws one text op under its own composed residual
00:00 +57: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: the composed residual lands the glyph box where the bounds say
00:00 +58: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: an empty text entity draws nothing and is still counted
00:00 +59: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: text inside a mirrored instance is drawn mirrored, not corrected
00:00 +60: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: the reference walk and the painter agree with text on
00:00 +61: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/stroke_width_golden_test.dart: paper-space stroke width at three zoom levels
00:00 +62: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/stroke_width_golden_test.dart: paper-space stroke width at three zoom levels
00:00 +63: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/stroke_width_golden_test.dart: paper-space stroke width at three zoom levels
00:00 +64: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/stroke_width_golden_test.dart: paper-space stroke width at three zoom levels
00:00 +65: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/stroke_width_golden_test.dart: paper-space stroke width at three zoom levels
00:00 +66: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart: dash ladder rung 1 (RenderBackend.canvas)
00:00 +67: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart: dash ladder rung 1 (RenderBackend.canvas)
00:00 +68: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart: dash ladder rung 1 (RenderBackend.canvas)
00:01 +69: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart: fill ladder rung 1 (RenderBackend.canvas)
00:01 +70: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart: fill ladder rung 1 (RenderBackend.canvas)
00:01 +71: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
00:01 +72: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
00:01 +73: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
00:01 +74: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
00:01 +75: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends draw the same drawing
00:01 +76: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends draw the same drawing
00:01 +77: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart: dash ladder rung 3 (RenderBackend.canvas)
00:01 +78: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/differential_test.dart: the painter draws a superset of the reference walk, in order
00:01 +79: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.vertices)
00:01 +80: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.vertices)
00:01 +81: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.vertices)
00:01 +82: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.vertices)
00:01 +83: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.vertices)
00:01 +84: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.vertices)
00:01 +85: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.vertices)
00:01 +86: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.vertices)
00:01 +87: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.vertices)
00:01 +88: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.vertices)
00:01 +89: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart: dash ladder rung 3 (RenderBackend.vertices)
00:01 +90: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart: dash ladder rung 3 (RenderBackend.vertices)
00:01 +91: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart: dash ladder rung 3 (RenderBackend.vertices)
00:01 +92: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends agree on the ops the painter cannot emit
00:01 +93: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart: fill ladder rung 3 (RenderBackend.canvas)
00:01 +94: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart: fill ladder rung 3 (RenderBackend.canvas)
00:01 +95: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart: fill ladder rung 3 (RenderBackend.canvas)
00:01 +96: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart: fill ladder rung 3 (RenderBackend.canvas)
00:01 +97: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart: fill ladder rung 3 (RenderBackend.canvas)
00:01 +98: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart: fill ladder rung 3 (RenderBackend.canvas)
00:01 +99: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart: fill ladder rung 3 (RenderBackend.canvas)
00:01 +100: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart: fill ladder rung 3 (RenderBackend.canvas)
00:01 +101: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart: fill ladder rung 3 (RenderBackend.canvas)
00:01 +102: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart: fill ladder rung 3 (RenderBackend.canvas)
00:01 +103: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart: fill ladder rung 3 (RenderBackend.canvas)
00:01 +104: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart: dash ladder rung 4 (RenderBackend.canvas)
00:01 +105: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart: dash ladder rung 4 (RenderBackend.canvas)
00:01 +106: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.vertices)
00:01 +107: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.vertices)
00:01 +108: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.vertices)
00:01 +109: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.vertices)
00:01 +110: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: a full-sweep ARC leaves an unjoined seam. This is a defect
00:01 +111: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart: dash ladder rung 5 (RenderBackend.canvas)
00:01 +112: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
00:01 +113: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart: dash ladder rung 5 (RenderBackend.vertices)
00:01 +114: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.vertices)
00:01 +115: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
00:01 +116: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.vertices)
00:01 +117: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
00:01 +118: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.vertices)
00:01 +119: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: (tearDownAll)
00:01 +119: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:01 +120: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:01 +121: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:01 +122: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:01 +123: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:01 +124: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:01 +125: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:01 +126: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:01 +127: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:01 +128: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:01 +129: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +130: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +131: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +132: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +133: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +134: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +135: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +135: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/rig/paint_microbench_test.dart: (suite)
  Skip: run explicitly: flutter test --tags rig --run-skipped
00:02 +135 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +136 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +137 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +138 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +139 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +140 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +141 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +142 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +143 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +144 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +145 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +146 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +147 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +148 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +149 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +150 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +151 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +152 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +153 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +154 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +155 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +156 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: flush hands drawVertices the same Paint object every time, not a call-site-local one
00:02 +157 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +158 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +159 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +160 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +161 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +162 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +163 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +164 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +165 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +166 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +167 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +168 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +169 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
LOAD fills=5000 elapsed=73ms
00:02 +170 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: the platform default is vertices, unconditionally
00:02 +171 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:02 +172 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:02 +173 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:02 +174 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:02 +175 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:02 +176 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:02 +177 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:02 +178 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_order_test.dart: painting never issues a SpatialIndex-level query from inside a visit
00:02 +179 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_root_test.dart: a group-owned leaf is drawn through its folded transform
00:02 +180 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: an explicit backend is honoured, not clamped
00:02 +181 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: an explicit backend is honoured, not clamped
00:02 +182 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: an explicit backend is honoured, not clamped
00:02 +183 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: an explicit backend is honoured, not clamped
00:02 +184 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: an explicit backend is honoured, not clamped
00:02 +185 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: an explicit backend is honoured, not clamped
00:02 +186 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: an explicit backend is honoured, not clamped
00:02 +187 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: an explicit backend is honoured, not clamped
00:02 +188 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: an explicit backend is honoured, not clamped
00:02 +189 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:02 +190 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:02 +191 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:02 +192 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:02 +193 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:02 +194 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:02 +195 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:02 +196 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:02 +197 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:02 +198 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:02 +199 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:02 +200 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:02 +201 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:02 +202 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:02 +203 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:03 +204 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:03 +205 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/fill_seam_test.dart: the translucent seam, measured
SEAM interior=656204 over8=0 fraction=0.000% worst=0
00:03 +206 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/fill_seam_test.dart: the translucent seam, measured
00:03 +207 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/fill_seam_test.dart: the translucent seam, measured
00:03 +208 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:03 +209 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:03 +210 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:03 +211 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:03 +212 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:03 +213 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:03 +214 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:03 +215 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:03 +216 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:03 +217 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:03 +218 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:03 +219 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:03 +220 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:03 +221 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:03 +222 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:03 +223 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:03 +224 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: the corpus draws the same picture twice in a row
00:03 +225 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: the corpus draws the same picture twice in a row
00:03 +226 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: the corpus draws the same picture twice in a row
00:03 +227 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: the corpus draws the same picture twice in a row
00:03 +228 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: RecordingDrawSink ops compare by value, which is what the oracle rests on
00:03 +229 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: the miter limit and its cosine are Impellers own
00:03 +230 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: the miter limit and its cosine are Impellers own
00:03 +231 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: the miter limit and its cosine are Impellers own
00:03 +232 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: the miter limit and its cosine are Impellers own
00:03 +233 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: the miter limit and its cosine are Impellers own
00:03 +234 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: the miter limit and its cosine are Impellers own
00:03 +235 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: the miter limit and its cosine are Impellers own
00:03 +236 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: the miter limit and its cosine are Impellers own
00:03 +237 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: the miter limit and its cosine are Impellers own
00:03 +238 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:03 +239 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:03 +240 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:03 +241 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:03 +242 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:03 +243 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:03 +244 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:03 +245 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:03 +246 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:03 +247 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:03 +248 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:03 +249 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:03 +250 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:03 +251 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:03 +252 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:03 +253 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:03 +254 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:03 +255 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:03 +256 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:03 +257 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:03 +258 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:03 +259 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:03 +260 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:03 +261 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:03 +262 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the sink inks every primitive the reference walk draws
00:03 +263 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the sink inks every primitive the reference walk draws
00:03 +264 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the sink inks every primitive the reference walk draws
00:03 +265 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the sink inks every primitive the reference walk draws
00:03 +266 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the sink inks every primitive the reference walk draws
00:03 +267 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the sink inks every primitive the reference walk draws
00:03 +268 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the sink inks every primitive the reference walk draws
00:03 +269 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the sink inks every primitive the reference walk draws
00:03 +270 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the sink inks every primitive the reference walk draws
00:03 +271 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the sink inks every primitive the reference walk draws
00:03 +272 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink the canvas sink fills the path and does not stroke it
00:03 +273 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink the canvas sink fills the path and does not stroke it
00:03 +274 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink the canvas sink fills the path and does not stroke it
00:03 +275 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink the canvas sink fills the path and does not stroke it
00:04 +276 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink the canvas sink leaves its paint on stroke afterwards
00:04 +277 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink fillPolygon closes the path
00:04 +278 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink fillPolygon with fewer than 3 points draws nothing
00:04 +279 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink fillCircle draws a filled circle
00:04 +280 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink fillCircle leaves the paint on stroke afterwards
00:04 +281 ~1: All tests passed!
```

## Step 5: `flutter analyze` — known breakage in `test/rig/paint_microbench_test.dart`

This failure is expected per the brief: `paint_microbench_test.dart` still reads the old `evictionCount` getter, and it is Task 3's responsibility to fix it. It is excluded from the widget suite by the `rig` tag, so `flutter test` passes while `flutter analyze` fails.

```
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (105.0.0 available)
  analyzer 13.3.0 (14.1.0 available)
  code_assets 1.2.1 (2.0.0 available)
  hooks 2.1.0 (2.2.0 available)
  lucide_icons_flutter 3.1.15 (3.1.17 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  objective_c 9.5.0 (9.6.0 available)
  package_config 2.2.0 (3.0.0 available)
  record_use 1.1.0 (1.1.1 available)
  shadcn_ui 0.55.1 (0.56.1 available)
  source_maps 0.10.13 (0.10.14 available)
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Analyzing jet_cad_2d_flutter...                                 

  error • The getter 'evictionCount' isn't defined for the type 'FlutterTextMeasurer'. Try importing the library that defines 'evictionCount', correcting the name to the name of an existing getter, or defining a getter or field named 'evictionCount' • test/rig/paint_microbench_test.dart:286:48 • undefined_getter
  error • The getter 'evictionCount' isn't defined for the type 'FlutterTextMeasurer'. Try importing the library that defines 'evictionCount', correcting the name to the name of an existing getter, or defining a getter or field named 'evictionCount' • test/rig/paint_microbench_test.dart:299:44 • undefined_getter
  error • The getter 'evictionCount' isn't defined for the type 'FlutterTextMeasurer'. Try importing the library that defines 'evictionCount', correcting the name to the name of an existing getter, or defining a getter or field named 'evictionCount' • test/rig/paint_microbench_test.dart:301:41 • undefined_getter
  error • The getter 'evictionCount' isn't defined for the type 'FlutterTextMeasurer'. Try importing the library that defines 'evictionCount', correcting the name to the name of an existing getter, or defining a getter or field named 'evictionCount' • test/rig/paint_microbench_test.dart:304:40 • undefined_getter

4 issues found. (ran in 1.3s)
```

## git status checked before committing

Run before `git add`, confirming neither `analysis_options.yaml` nor the `.pbxproj` were staged:

```
On branch main
Your branch is ahead of 'origin/main' by 7 commits.
  (use "git push" to publish your local commits)

Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   apps/dev_harness/analysis_options.yaml
	modified:   apps/dev_harness/macos/Podfile
	modified:   apps/dev_harness/macos/Runner.xcodeproj/project.pbxproj
	modified:   packages/jet_cad_2d_flutter/lib/src/flutter_text_measurer.dart
	modified:   packages/jet_cad_2d_flutter/test/flutter_text_measurer_test.dart

no changes added to commit (use "git add" and/or "git commit -a")
```

---

# Fix round 1 of 5

Two findings, both about test coverage, not production logic:

1. **`probe.dispose()` in `measure()` was untested.** Neither assertion in
   `measure disposes its probe and leaves no paragraph entry` moves if that
   line is removed. Added `Paragraph? debugLastProbe`, set immediately after
   `probe.dispose()` in `measure()`, mirroring `debugLastEvicted`. Asserted
   `m.debugLastProbe!.debugDisposed` in the existing probe test.
2. **`clear()`'s dispose loop was untested.** Deleting the loop left the
   suite green because nothing checked the paragraph's own `debugDisposed`
   flag, only the map's emptiness. Captured the paragraph `paragraphFor`
   returns in `clear empties both maps` and asserted
   `p.debugDisposed, isTrue` after `m.clear()`.

## Green run after the fix

```
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (105.0.0 available)
  analyzer 13.3.0 (14.1.0 available)
  code_assets 1.2.1 (2.0.0 available)
  hooks 2.1.0 (2.2.0 available)
  lucide_icons_flutter 3.1.15 (3.1.17 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  objective_c 9.5.0 (9.6.0 available)
  package_config 2.2.0 (3.0.0 available)
  record_use 1.1.0 (1.1.1 available)
  shadcn_ui 0.55.1 (0.56.1 available)
  source_maps 0.10.13 (0.10.14 available)
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/flutter_text_measurer_test.dart
00:00 +0: the same string in two colours is two entries, not one
00:00 +1: a repeat request lays out nothing and allocates no metrics
00:00 +2: eviction disposes the paragraph
00:00 +3: metrics are cap-height based and taken at the nominal size
00:00 +4: an empty string measures zero, not the negative float floor
00:00 +5: resetCounters zeroes the counters and keeps the cache warm
00:00 +6: TextKeySink keys the same triple this cache does
00:00 +7: measure disposes its probe and leaves no paragraph entry
00:00 +8: a metrics sweep does not evict drawn paragraphs
00:00 +9: the metrics map evicts on its own bound, and it is not the paragraph one
00:00 +10: clear empties both maps
00:00 +11: All tests passed!
```

## Mutation 1: comment out `probe.dispose();` in `measure()` — red

Line 192 of `lib/src/flutter_text_measurer.dart` changed to:
```dart
    // MUTANT: probe.dispose();
```

```
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (105.0.0 available)
  analyzer 13.3.0 (14.1.0 available)
  code_assets 1.2.1 (2.0.0 available)
  hooks 2.1.0 (2.2.0 available)
  lucide_icons_flutter 3.1.15 (3.1.17 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  objective_c 9.5.0 (9.6.0 available)
  package_config 2.2.0 (3.0.0 available)
  record_use 1.1.0 (1.1.1 available)
  shadcn_ui 0.55.1 (0.56.1 available)
  source_maps 0.10.13 (0.10.14 available)
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/flutter_text_measurer_test.dart
00:00 +0: the same string in two colours is two entries, not one
00:00 +1: a repeat request lays out nothing and allocates no metrics
00:00 +2: eviction disposes the paragraph
00:00 +3: metrics are cap-height based and taken at the nominal size
00:00 +4: an empty string measures zero, not the negative float floor
00:00 +5: resetCounters zeroes the counters and keeps the cache warm
00:00 +6: TextKeySink keys the same triple this cache does
00:00 +7: measure disposes its probe and leaves no paragraph entry
00:00 +7 -1: measure disposes its probe and leaves no paragraph entry [E]
  Expected: true
    Actual: <false>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/flutter_text_measurer_test.dart 159:5          main.<fn>
  
00:00 +7 -1: a metrics sweep does not evict drawn paragraphs
00:00 +8 -1: the metrics map evicts on its own bound, and it is not the paragraph one
00:00 +9 -1: clear empties both maps
00:00 +10 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/flutter_text_measurer_test.dart: measure disposes its probe and leaves no paragraph entry
```

Restored the file by copying the pre-mutation backup back over it (never
`git checkout`, which would have wiped the uncommitted fix). Re-ran the
suite green before proceeding to the second mutation.

## Mutation 2: delete `clear()`'s dispose loop — red

`clear()` changed to:
```dart
  void clear() {
    // MUTANT: dispose loop removed
    _paragraphs.clear();
    _metrics.clear();
  }
```

```
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (105.0.0 available)
  analyzer 13.3.0 (14.1.0 available)
  code_assets 1.2.1 (2.0.0 available)
  hooks 2.1.0 (2.2.0 available)
  lucide_icons_flutter 3.1.15 (3.1.17 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  objective_c 9.5.0 (9.6.0 available)
  package_config 2.2.0 (3.0.0 available)
  record_use 1.1.0 (1.1.1 available)
  shadcn_ui 0.55.1 (0.56.1 available)
  source_maps 0.10.13 (0.10.14 available)
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/flutter_text_measurer_test.dart
00:00 +0: the same string in two colours is two entries, not one
00:00 +1: a repeat request lays out nothing and allocates no metrics
00:00 +2: eviction disposes the paragraph
00:00 +3: metrics are cap-height based and taken at the nominal size
00:00 +4: an empty string measures zero, not the negative float floor
00:00 +5: resetCounters zeroes the counters and keeps the cache warm
00:00 +6: TextKeySink keys the same triple this cache does
00:00 +7: measure disposes its probe and leaves no paragraph entry
00:00 +8: a metrics sweep does not evict drawn paragraphs
00:00 +9: the metrics map evicts on its own bound, and it is not the paragraph one
00:00 +10: clear empties both maps
00:00 +10 -1: clear empties both maps [E]
  Expected: true
    Actual: <false>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/flutter_text_measurer_test.dart 209:5          main.<fn>
  
00:00 +10 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/flutter_text_measurer_test.dart: clear empties both maps
```

Restored the file the same way (backup copy, not `git checkout`) and
confirmed the suite green again — see "Green run after the fix" above,
which was captured post-restore.

## `flutter analyze` after the fix

Unchanged from the original task report — still exactly the four
pre-existing `evictionCount` errors in `test/rig/paint_microbench_test.dart`,
owned by Task 3 and left untouched:

```
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (105.0.0 available)
  analyzer 13.3.0 (14.1.0 available)
  code_assets 1.2.1 (2.0.0 available)
  hooks 2.1.0 (2.2.0 available)
  lucide_icons_flutter 3.1.15 (3.1.17 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  objective_c 9.5.0 (9.6.0 available)
  package_config 2.2.0 (3.0.0 available)
  record_use 1.1.0 (1.1.1 available)
  shadcn_ui 0.55.1 (0.56.1 available)
  source_maps 0.10.13 (0.10.14 available)
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Analyzing jet_cad_2d_flutter...                                 

  error • The getter 'evictionCount' isn't defined for the type 'FlutterTextMeasurer'. Try importing the library that defines 'evictionCount', correcting the name to the name of an existing getter, or defining a getter or field named 'evictionCount' • test/rig/paint_microbench_test.dart:286:48 • undefined_getter
  error • The getter 'evictionCount' isn't defined for the type 'FlutterTextMeasurer'. Try importing the library that defines 'evictionCount', correcting the name to the name of an existing getter, or defining a getter or field named 'evictionCount' • test/rig/paint_microbench_test.dart:299:44 • undefined_getter
  error • The getter 'evictionCount' isn't defined for the type 'FlutterTextMeasurer'. Try importing the library that defines 'evictionCount', correcting the name to the name of an existing getter, or defining a getter or field named 'evictionCount' • test/rig/paint_microbench_test.dart:301:41 • undefined_getter
  error • The getter 'evictionCount' isn't defined for the type 'FlutterTextMeasurer'. Try importing the library that defines 'evictionCount', correcting the name to the name of an existing getter, or defining a getter or field named 'evictionCount' • test/rig/paint_microbench_test.dart:304:40 • undefined_getter

4 issues found. (ran in 0.8s)
```

## git status before staging the fix

```
On branch main
Your branch is ahead of 'origin/main' by 8 commits.
  (use "git push" to publish your local commits)

Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   apps/dev_harness/analysis_options.yaml
	modified:   apps/dev_harness/macos/Podfile
	modified:   apps/dev_harness/macos/Runner.xcodeproj/project.pbxproj
	modified:   packages/jet_cad_2d_flutter/lib/src/flutter_text_measurer.dart
	modified:   packages/jet_cad_2d_flutter/test/flutter_text_measurer_test.dart

no changes added to commit (use "git add" and/or "git commit -a")
```

Confirmed none of `analysis_options.yaml`, `Podfile`, or `.pbxproj` were
staged; only the two intended files were added and committed.

## Commit

`6ee5ecc` — test: prove the metrics probe and clear() dispose loop actually fire
