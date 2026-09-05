import 'dart:ui' show Size;

import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../draft_painter.dart' show kScreenClipInflate;
import '../viewport_transform.dart';

/// The camera and viewport one rebuild walks under (Ruling F2).
///
/// [camera] has the live camera's scale and rotation and a translation that
/// puts the document's extents at the viewport's origin; [viewport] is the
/// extents' screen size plus a margin on every side. `DraftPainter.paint`
/// culls to `camera.visibleWorld(viewport)`, so under this pair nothing is
/// culled: a pan needs no rebuild, and neither does a viewport resize.
///
/// The two cameras differ by a pure translation, so
/// `composeTransforms(live, camera.invert())` is a translation and the
/// frame mapping `GpuDrawBackend.render` builds every frame is exact.
class CollectionFrame {
  const CollectionFrame(this.camera, this.viewport);
  final ViewportTransform camera;
  final Size viewport;
}

/// The frame a rebuild at [live] walks under, covering [extents].
///
/// [margin] defaults to the painter's own clip inflate so an entity on the
/// extents' edge, with its stroke width, is inside the frame; the painter
/// inflates its *clip* by the same amount but queries the index on the
/// un-inflated world rect, which is why the margin lives here.
///
/// **Float32 is the cost.** The buffer holds absolute frame coordinates,
/// bounded by the extents' size at the live scale: 1,350 px on the harness
/// floor at fit, 135,000 px at 100x (ulp 0.0078 px), 1.35 M px at 1000x
/// (ulp 0.125 px). Task 7's band sweep runs at a zoomed-in collection as
/// well as at fit, so the precision at a working scale is measured.
///
/// Empty extents -- an empty document -- give [live] back unchanged and a
/// 1x1 viewport: nothing to cover, nothing to shift, and a `Size.zero`
/// viewport would make `visibleWorld` degenerate.
CollectionFrame collectionFrameFor(ViewportTransform live, Aabb2 extents,
    {double margin = kScreenClipInflate}) {
  if (extents.isEmpty) return CollectionFrame(live, const Size(1, 1));
  final m = live.worldToScreenMatrix;
  final box = extents.transformedBy(Transform2(m.a, m.b, m.c, m.d, 0, 0));
  final camera = ViewportTransform(
      worldToScreenMatrix:
          Transform2(m.a, m.b, m.c, m.d, margin - box.minX, margin - box.minY));
  return CollectionFrame(camera,
      Size(box.maxX - box.minX + 2 * margin, box.maxY - box.minY + 2 * margin));
}
