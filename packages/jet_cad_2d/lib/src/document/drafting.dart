import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../core/handle.dart';
import '../core/tolerance.dart';
import '../store/entity_store.dart';
import '../store/geometry_store.dart';
import 'commands.dart';
import 'draft_document.dart';
import 'page_component.dart';
import 'style.dart';

/// Spec 05 D13: the one fill colour a drawing tool gives a region, an
/// opaque light warm grey. Choosing another belongs to 12.
const DraftColor kDraftFillColor = TrueColor(0xE6E1D8);

/// Spec 05 D9: a placed text is 2.5 mm tall on paper.
const double kDraftTextPaperMm = 2.5;

/// Spec 05 D2: a root-level entity on layer 0, ByLayer everything. A text
/// takes the Standard style, left and baseline, with **no** override bits,
/// so its width factor and oblique angle come from the style. [color]
/// defaults to ByLayer; a parametric client may give its children a
/// concrete one (spec 07 D3).
EntityRecord draftRecord(Handle handle, Handle owner, EntityKind kind,
        {String text = '', DraftColor color = const ByLayerColor()}) =>
    EntityRecord(
      handle: handle,
      owner: owner,
      kind: kind,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: color,
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
      text: text,
      textStyle: ReservedHandles.standardTextStyle,
      textAttrs: 0,
    );

/// One finished shape's command (spec 05 D2, D11). The handle is taken
/// from [DraftDocument.handleSeed] **now**, when the shape finishes; redo
/// re-executes this same object, so the handle is stable. Not executed.
AddEntityCommand addDrafted(
        DraftDocument doc, EntityKind kind, GeometryPayload payload,
        {String text = ''}) =>
    AddEntityCommand(
      record:
          draftRecord(doc.handleSeed.next(), doc.rootHandle, kind, text: text),
      payload: payload,
    );

/// A filled shape's one command (spec 05 D11, D13), or null when the
/// boundary cannot be filled, and then nothing is allocated.
///
/// `triangulationFor` returns null for anything that is not a circle or a
/// closed polyline, and an **empty** list for a closed polyline that
/// self-intersects or is degenerate. `AddRegionCommand` would accept that
/// empty list and build a region with no triangles, so a polyline's empty
/// triangulation is refused here. A circle's is its normal case.
AddRegionCommand? addDraftedRegion(
  DraftDocument doc,
  EntityKind boundaryKind,
  GeometryPayload boundaryPayload, {
  DraftColor fillColor = kDraftFillColor,
  DraftColor boundaryColor = const ByLayerColor(),
  int boundaryLineweight = kLineweightDefault,
}) {
  final triangles = triangulationFor(boundaryKind, boundaryPayload);
  if (triangles == null) return null;
  if (boundaryKind == EntityKind.polyline && triangles.isEmpty) return null;
  return AddRegionCommand.allocate(
    seed: doc.handleSeed,
    owner: doc.rootHandle,
    boundaryKind: boundaryKind,
    boundaryPayload: boundaryPayload,
    layer: ReservedHandles.layerZero,
    fillColor: fillColor,
    boundaryColor: boundaryColor,
    boundaryLineweight: boundaryLineweight,
  );
}

GeometryPayload _payload(List<double> coords, List<double> scalars) =>
    GeometryPayload(
      coords: Float64List.fromList(coords),
      scalars: Float64List.fromList(scalars),
    );

GeometryPayload linePayload(Vector2 a, Vector2 b) =>
    _payload([a.x, a.y, b.x, b.y], const []);

/// [points] copied in order; [closed] appends the first point again —
/// closedness is that repeated pair under `==` (`isClosedPolyline`).
GeometryPayload polylinePayload(List<Vector2> points, {bool closed = false}) {
  final n = points.length + (closed ? 1 : 0);
  final coords = Float64List(n * 2);
  for (var i = 0; i < points.length; i++) {
    coords[i * 2] = points[i].x;
    coords[i * 2 + 1] = points[i].y;
  }
  if (closed) {
    coords[(n - 1) * 2] = points.first.x;
    coords[(n - 1) * 2 + 1] = points.first.y;
  }
  return GeometryPayload(coords: coords, scalars: Float64List(0));
}

/// Spec 05 D7: axis-aligned in world space, every coordinate copied from
/// [c1] or [c2], closing pair `==` the first.
GeometryPayload rectanglePayload(Vector2 c1, Vector2 c2) => _payload(
    [c1.x, c1.y, c2.x, c1.y, c2.x, c2.y, c1.x, c2.y, c1.x, c1.y], const []);

GeometryPayload circlePayload(Vector2 c, double r) => _payload([c.x, c.y], [r]);

GeometryPayload arcPayload(Vector2 c, double r, double start, double sweep) =>
    _payload([c.x, c.y], [r, start, sweep]);

/// Spec 05 D9: `[height, rotation, widthFactor, oblique]`. The height is
/// the **cap height** (DXF). The last two are padding: with no override
/// bits the style's values apply.
GeometryPayload textPayload(Vector2 p, double heightMm) =>
    _payload([p.x, p.y], [heightMm, 0, 1, 0]);

/// Spec 05 D9: 2.5 paper mm at the page's scale, as model mm; 2.5 with no
/// page.
double textHeightMm(PageComponent? page) => page == null
    ? kDraftTextPaperMm
    : kDraftTextPaperMm * page.scaleDenominator;

bool isDegenerateSegment(Vector2 a, Vector2 b) =>
    a.distanceTo(b) <= Tolerance.standard.linear;

bool isDegenerateRectangle(Vector2 c1, Vector2 c2) =>
    (c2.x - c1.x).abs() <= Tolerance.standard.linear ||
    (c2.y - c1.y).abs() <= Tolerance.standard.linear;

bool isDegenerateRadius(double r) => r <= Tolerance.standard.linear;

const double _tau = 2 * math.pi;

/// [a] mapped into (−π, π].
double wrapAngle(double a) {
  final w = a % _tau; // Dart's % is non-negative for a positive divisor
  return w > math.pi ? w - _tau : w;
}

/// Spec 05 D8: the angle the pointer has travelled around an arc's centre
/// since its start, and the signed sweep that direction implies.
///
/// `τ` accumulates **unbounded**: a clamp would lose the winding and flip
/// the sign on an out-and-back beyond a full turn (Ruling 05-1). Only its
/// sign is read; the magnitude of a sweep comes from the end angle alone.
final class SweepTracker {
  double _start = 0;
  double _previous = 0;
  double _travel = 0;

  double get start => _start;
  double get travel => _travel;

  void begin(double start) {
    _start = start;
    _previous = start;
    _travel = 0;
  }

  /// One pointer sample's angle. Each step is wrapped into (−π, π], so no
  /// single step jumps the seam.
  void track(double angle) {
    _travel += wrapAngle(angle - _previous);
    _previous = angle;
  }

  /// The signed sweep from the start to [end], or 0 to refuse (the end is on
  /// the start: a full circle is not an arc). Counter-clockwise when the
  /// travel is **>= 0**; that tie-break is deliberate (spec D8).
  double sweepTo(double end) {
    final delta = (end - _start) % _tau;
    final eps = Tolerance.standard.angular;
    if (delta <= eps || _tau - delta <= eps) return 0;
    return _travel >= 0 ? delta : delta - _tau;
  }
}
