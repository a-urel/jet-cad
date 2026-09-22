# Task 11 — mutation anchors (located by the controller at 9f08c10)

One production edit per mutant, applied to a `cp` backup, restored with `cp`,
`diff` to confirm. Line numbers are as of 9f08c10; re-grep before editing —
Task 10 may shift `apps/` files but never these.

| id | file | anchor (current text) | mutation |
|---|---|---|---|
| M-04a | `packages/jet_cad_2d_flutter/lib/src/ruler_painter.dart:85` | `? cam.worldToScreen(Vector2(world, 0)).x` | `? world * cam.scale` |
| M-04b | same file `:85` | same anchor | `? cam.worldToScreen(Vector2(world, 0)).x * 0 + world + cam.worldToScreenMatrix.e` (drops the scale, keeps the translation) — or simply `? world + cam.worldToScreenMatrix.e` |
| M-04c | `packages/jet_cad_2d/lib/src/geometry/grid_scale.dart:80-81` | `for (final step in ladderFor(unit, floorMm: floorMm)) {` / `if (step * pxPerWorldMm >= kMajorMinPixels) {` | replace the loop with a continuous major: `final step = kMajorMinPixels / pxPerWorldMm;` and drop the `>=` test (keep the divisor and minor logic) |
| M-04d | `packages/jet_cad_2d/lib/src/codec/json_codec.dart:118` | `registerComponents?.call(doc.components);` | move the line to just **after** `doc.components.loadJson(...)` |
| M-04e | `packages/jet_cad_2d/lib/src/document/page_component.dart:132,134` | `orientation == PageOrientation.portrait ? widthMm : heightMm;` and the mirror | swap the two arms on both lines |
| M-04f | `packages/jet_cad_2d_flutter/lib/src/page_chrome_painter.dart:149` | `cam.worldToScreen(Vector2(p.originX + i * stepMm, minY)).x` | `cam.worldToScreen(Vector2(i * stepMm, minY)).x` (and the same for the index computation `i0`/`i1` if you want the differential to fire on the anchor alone; the first-major test fires either way) |
| M-04g | `packages/jet_cad_2d/lib/src/geometry/grid_scale.dart:86` | `minorMm: minor * pxPerWorldMm >= minorMinPixels ? minor : null,` | `minorMm: minor,` |
| M-04h | `packages/jet_cad_2d/lib/src/geometry/grid_scale.dart:147-148` | `.roundToDouble()` (both) | `.truncateToDouble()` |
| M-04i | `packages/jet_cad_2d/lib/src/geometry/grid_scale.dart:109` | `DisplayUnit.meters => '${_trim(mm / 1000, 3)} m',` | `DisplayUnit.meters => '${_trim(mm, 3)} mm',` |
| M-04j | `packages/jet_cad_2d/lib/src/document/page_geometry.dart:10` | `page.originX + page.effectiveWidthMm * page.scaleDenominator,` | `page.originX + page.effectiveWidthMm,` (and `:11` for height) |
| M-04k | `apps/floor_planner/lib/planner_view.dart:85` | `? fitToPage(page, size)` | `? ViewportTransform.fit(widget.document.extents, size)` |
| M-04l | `packages/jet_cad_2d_flutter/lib/src/page_notifier.dart:23` | `CommandUndone(:final touched) \|\|` | delete that line (the or-pattern then covers Applied and Redone only; add `CommandUndone() => false,` as its own arm to keep the switch exhaustive) |
| M-04m | `packages/jet_cad_2d_flutter/lib/src/page_chrome_painter.dart:173-174` | `if (w * cam.scale < kBreaksMinSheetPixels \|\|` … `{ return; }` | `if (false) {` |
| M-04n | `packages/jet_cad_2d/lib/src/document/page_geometry.dart:17` | `pxPerWorldMm * page.scaleDenominator / pixelsPerPaperMm;` | `pxPerWorldMm / pixelsPerPaperMm;` |
| M-04o | `apps/floor_planner/lib/page_panel.dart:52` | `void _set(PageComponent next) => widget.document.commands.execute(` … | make `_set` a block body that executes the same command twice (the second execute is a no-op by value but a second history entry) |
| M-04p | `packages/jet_cad_2d_flutter/lib/src/ruler_painter.dart:97` | `for (var i = i1; i >= i0; i--) {` | `for (var i = i0; i <= i1; i++) {` (the vertical branch) |
| M-04q | `packages/jet_cad_2d/lib/src/geometry/grid_scale.dart:61` | `if (floorMm != null) {` | `if (false) {` |
| M-04r | `packages/jet_cad_2d/lib/src/index/spatial_index.dart:2606` | `if (capability == Capability.components) return;` | delete the line |
| M-04s | `packages/jet_cad_2d/lib/src/document/undo.dart:117` | `capability: command.capability);` | `capability: Capability.geometry);` |
| M-04t | `packages/jet_cad_2d_flutter/lib/src/page_chrome_painter.dart:96-97` | `math.max(visible.minX, sheet.minX)` / `math.min(visible.maxX, sheet.maxX)` | `sheet.minX` / `sheet.maxX` (and the y pair) |
| M-04u | `packages/jet_cad_2d_flutter/lib/src/page_notifier.dart:12` | `: super(document.components.get<PageComponent>(document.rootHandle)) {` | `: super(null) {` |
| M-04v | `packages/jet_cad_2d_flutter/lib/src/page_chrome_painter.dart:165` | `Float32List.sublistView(_buffer, start, n)` | `_buffer` |

Tile-cache twin of M-04r: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart:1876`, same edit, test `tile_invalidation_test.dart`.
