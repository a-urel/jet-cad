import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../document/page_component.dart';
import '../geometry/grid_scale.dart';
import 'snap.dart';
import 'spatial_index.dart';

/// The kinds live during a drag (spec D8): the cheap five plus
/// intersection.
const SnapMask kDragSnapMask = SnapMask(0x9F); // cheap | intersection

/// The object-snap aperture in screen pixels; a caller divides by the
/// camera's scale.
const double kSnapAperturePixels = 10.0;

/// A drag's resolved point. Caller-owned and reused, never held (spec D8).
final class DragPoint {
  final Vector2 point = Vector2.zero();

  /// Non-null: an object snap won.
  SnapKind? objectKind;

  /// The grid won.
  bool grid = false;

  void reset() {
    point.setZero();
    objectKind = null;
    grid = false;
  }
}

/// Spec D8's chain: ortho in world axes, then an object snap that overrides
/// it, then the grid with the ortho axis re-pinned, else the constrained
/// point.
///
/// Object snap always beats the grid, whatever the two distances (04 D6).
/// Between object-snap kinds, the engine's kind-first order decides.
void resolveDragPoint({
  required Vector2 raw,
  required Vector2? orthoBase,
  required SpatialIndex index,
  required double apertureWorld,
  required bool objectSnap,
  required PageComponent? page,
  required double? gridStepMm,
  required SnapResult scratch,
  required DragPoint out,
}) {
  out.objectKind = null;
  out.grid = false;

  // 1. Ortho, in world axes: the minor axis is pinned to the base. Under a
  //    rotated camera this looks diagonal on screen, deliberately.
  var cx = raw.x, cy = raw.y;
  var pinX = false, pinY = false;
  final base = orthoBase;
  if (base != null) {
    if ((raw.x - base.x).abs() >= (raw.y - base.y).abs()) {
      cy = base.y;
      pinY = true;
    } else {
      cx = base.x;
      pinX = true;
    }
  }

  // 2. Object snap, queried at the pointer: the marker the user aims at is
  //    under it. It wins outright and overrides ortho. Copied at once,
  //    because the next query rewrites `scratch.point` (invariant 7).
  if (objectSnap) {
    index.snapInto(raw, apertureWorld, kDragSnapMask, scratch);
    if (scratch.found) {
      out.point.setFrom(scratch.point);
      out.objectKind = scratch.kind;
      return;
    }
  }

  // 3. The grid, then the ortho axis written back from the base, so a
  //    shift-drag from an off-grid base stays exactly on its line (M-03q).
  if (page != null && page.snapToGrid && gridStepMm != null) {
    out.point.setValues(cx, cy);
    out.point.setFrom(snapToGrid(out.point, gridStepMm, page));
    if (pinY) out.point.y = base!.y;
    if (pinX) out.point.x = base!.x;
    out.grid = true;
    return;
  }

  // 4. Otherwise, the constrained point.
  out.point.setValues(cx, cy);
}

/// The drag's grid step (04 D6, Ruling 03-11): the page's fixed step
/// exactly, else the zoom-adaptive minor, else the major; null with no page
/// or no rung.
double? dragGridStepMm(PageComponent? page, double pxPerWorldMm) {
  if (page == null) return null;
  final fixed = page.gridStepMm;
  if (fixed != null) return fixed;
  final scale = GridScale.pick(page.displayUnit, pxPerWorldMm);
  if (scale == null) return null;
  return scale.minorMm ?? scale.majorMm;
}
