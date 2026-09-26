// The document the app opens before sub-project 12 gives it a file.
//
// A hand-written flat, in millimetres: two bedrooms, a living room, a
// kitchen, a bathroom and a hall, with walls, doors, windows, a few pieces
// of furniture and the floor finishes drawn in -- the finishes are what
// carry the count into the target scale (500-5,000 entities) while every
// line stays something a person can check by eye: do the walls close, does
// the door swing into the room, is the tile grid square.
//
// **Walls and openings are parametric objects** (spec 08 D18): nine 07
// walls and fifteen 08 openings, at the places the hand-drawn double lines
// and symbols stood before. The plan builds them through its own parametric
// system, disposes it, and hands the shell a finished document, which the
// shell's system trusts as it would a loaded file (06 D10).
//
// **Off-origin and not axis-symmetric, by construction.** A drawing centred
// on (0, 0) is the degenerate fixture this repository keeps rediscovering,
// and this is the fixture a human looks at every session.
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'parametric/catalog.dart';
import 'parametric/opening.dart';
import 'parametric/wall.dart';

/// Zoom bounds for the product camera, in logical pixels per world unit
/// (millimetre). Spec D4; checked against this document in
/// `startup_plan_test.dart`.
const double kMinScale = 0.001;
const double kMaxScale = 100.0;

/// The flat's outer wall corner, and its outer size.
const double kPlanOriginX = 12000.0;
const double kPlanOriginY = 8000.0;
const double kPlanWidth = 14000.0;
const double kPlanHeight = 9000.0;

const double _wall = 250.0; // exterior wall thickness
const double _partition = 120.0; // interior wall thickness

const DraftColor _furnitureColor = TrueColor(0x8A6D3B);
const DraftColor _finishColor = TrueColor(0xBBBBBB);

/// Builds the startup flat over [measurer]. `DraftCanvas` refuses a document
/// whose measurer is not a `FlutterTextMeasurer`, so the caller supplies the
/// one the app owns.
DraftDocument startupPlan(FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  final p = _Pen(doc);
  // Spec 08 D18: the walls and openings regenerate through this system as
  // they are added; it is disposed before the page is set, so the shell can
  // install its own over the finished document.
  final system = installParametric(doc);

  // --- Walls (spec 08 D18's table): each in its own root-level group at the
  // identity, centre-justified. The exterior runs anticlockwise and mitres
  // at the four corners, its faces the outer and inner rectangles; every
  // partition ends on another wall's centreline, a T. E3 and E4 run against
  // the axes, so their openings' positions are measured from their east and
  // north ends. ---
  const x0 = kPlanOriginX, y0 = kPlanOriginY;
  const x1 = kPlanOriginX + kPlanWidth, y1 = kPlanOriginY + kPlanHeight;
  const h = _wall / 2;
  final e1 = p.wall(x0 + h, y0 + h, x1 - h, y0 + h, _wall); // south
  final e2 = p.wall(x1 - h, y0 + h, x1 - h, y1 - h, _wall); // east
  final e3 = p.wall(x1 - h, y1 - h, x0 + h, y1 - h, _wall); // north
  final e4 = p.wall(x0 + h, y1 - h, x0 + h, y0 + h, _wall); // west
  // Hall/living, full height.
  final p1 = p.wall(x0 + 5000, y0 + h, x0 + 5000, y1 - h, _partition);
  // Bedrooms above y = 5000 on the left.
  final p2 = p.wall(x0 + h, y0 + 5000, x0 + 5000, y0 + 5000, _partition);
  // Kitchen/bath below y = 3500 on the right.
  final p3 = p.wall(x0 + 5000, y0 + 3500, x1 - h, y0 + 3500, _partition);
  // Bedroom split at x = 2600, from y = 5000 up.
  final p4 = p.wall(x0 + 2600, y0 + 5000, x0 + 2600, y1 - h, _partition);
  // Kitchen/bath split at x = 9500, from the bottom to y = 3500.
  p.wall(x0 + 9500, y0 + h, x0 + 9500, y0 + 3500, _partition);

  // --- Doors (spec 08 D18's table): the hinge on the lower jamb of a
  // vertical wall and the left jamb of a horizontal one, the swing on the
  // side the leaf went. ---
  p.opening(OpeningParams(p1, 5875, 900, OpeningKind.door));
  p.opening(
      OpeningParams(p1, 1375, 900, OpeningKind.door, swing: SwingSide.right));
  p.opening(
      OpeningParams(p4, 2800, 800, OpeningKind.door, swing: SwingSide.right));
  p.opening(
      OpeningParams(p2, 1075, 800, OpeningKind.door, swing: SwingSide.right));
  p.opening(OpeningParams(p3, 2000, 800, OpeningKind.door));
  p.opening(OpeningParams(p3, 6500, 700, OpeningKind.door));
  // The front door, in the south exterior wall.
  p.opening(OpeningParams(e1, 6375, 1000, OpeningKind.door));

  // --- Windows (spec 08 D18's table). ---
  for (final u in const [12575.0, 9975.0, 6675.0, 3075.0]) {
    p.opening(OpeningParams(e3, u, 1200, OpeningKind.window));
  }
  p.opening(OpeningParams(e2, 1675, 1200, OpeningKind.window));
  p.opening(OpeningParams(e2, 6075, 1800, OpeningKind.window));
  p.opening(OpeningParams(e4, 6675, 1000, OpeningKind.window));
  p.opening(OpeningParams(e4, 2275, 1400, OpeningKind.window));

  // --- Floor finishes: what carries the count. ---
  // Kitchen tiles, 200 mm, both ways: x 5000+p..9500-p, y wall..3500-p.
  p.grid(x0 + 5000 + _partition, y0 + _wall, x0 + 9500 - _partition,
      y0 + 3500 - _partition,
      pitch: 200, both: true);
  // Bathroom mosaic, 150 mm, both ways.
  p.grid(x0 + 9500 + _partition, y0 + _wall, x1 - _wall, y0 + 3500 - _partition,
      pitch: 150, both: true);
  // Living room parquet: 150 mm strips running in x, with staggered joints
  // every 900 mm.
  p.parquet(
      x0 + 5000 + _partition, y0 + 3500 + _partition, x1 - _wall, y1 - _wall,
      strip: 150, plank: 900);

  // --- Furniture: filled regions (spec 05 D14), after the finishes so
  // their fills draw over the tile and parquet lines. ---
  // Bed 1, a 1400 mm double, clear of the bedroom-1/2 doorway's approach
  // (Ruling F-8): that door's opening is y0 + 7400..8200 on the partition at
  // x0 + 2600, its hinge on the partition's swing face at x0 + 2660 (08
  // D10), and a person needs 900 mm in front of it, so the approach reaches
  // x0 + 1760 and the bed, ending at x0 + 1700, is clear by 60 mm. The old
  // 1800 mm bed left 340 mm.
  p.rectRegion(x0 + 300, y0 + 6600, x0 + 1700, y0 + 8600); // bed
  // Bed 2, clear of both of bedroom 2's door swings (Ruling F-1): the
  // bedroom-1/2 door's swing starts at y0 + 7400, and the hall/living
  // partition door's swing starts at x0 + 4040 (its hinge on the face at
  // x0 + 4940, the leaf 900 mm), so the bed (ending at x0 + 4000,
  // y0 + 7200) sits below-left of both, clear by 200 mm and 40 mm.
  p.rectRegion(x0 + 2750, y0 + 5200, x0 + 4000, y0 + 7200); // bed
  // The sofa, moved off the kitchen/bath-living partition door's swing
  // (Ruling F-1): that arc starts on the partition's face at y0 + 3560 and
  // its far edge is y0 + 4360, so the sofa starts at y0 + 4500, clear by
  // 140 mm.
  p.rectRegion(x0 + 6000, y0 + 4500, x0 + 9000, y0 + 5400); // sofa
  p.rectRegion(x0 + 6400, y0 + 5600, x0 + 8600, y0 + 6800); // table
  // The kitchen counter: one L along the kitchen's south and east walls.
  // Ruling F-1 moved it off the hall/kitchen door's swing (x0 + 5060..5960)
  // and the front door's (x0 + 6000..7000); Ruling F-8 then moved its north
  // leg out of the kitchen/living doorway (x0 + 6600..7400 at y0 + 3500),
  // which it faced from 350 mm away. The south leg starts 200 mm east of
  // the front door's swing, and the east leg stops 400 mm short of the
  // north wall, both clear of every doorway's 900 mm approach.
  p.polygonRegion([
    x0 + 7200, y0 + 400, //
    x0 + 9100, y0 + 400,
    x0 + 9100, y0 + 3100,
    x0 + 8500, y0 + 3100,
    x0 + 8500, y0 + 1000,
    x0 + 7200, y0 + 1000,
  ]);
  p.rectRegion(x0 + 12200, y0 + 400, x0 + 13500, y0 + 2000); // bath
  p.circleRegion(x0 + 7600, y0 + 6200, 350); // lamp, after the table
  p.circleRegion(x0 + 10300, y0 + 1200, 220); // basin

  // Spec 08 D18: the plan is finished; the shell installs its own system.
  system.dispose();

  // Spec 04 D12 and Ruling 04-1: the page is document data, attached
  // through the log like everything else, and then the history is cleared
  // so a fresh document has none — as a loaded one has none.
  PageComponent.register(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle, startupPage(doc.extents)));
  doc.commands.clearHistory();
  return doc;
}

/// A4 landscape at 1:50 in metres, centred on [extents] (spec D4).
PageComponent startupPage(Aabb2 extents) {
  final page = PageComponent();
  final w = page.effectiveWidthMm * page.scaleDenominator;
  final h = page.effectiveHeightMm * page.scaleDenominator;
  return page.copyWith(
      originX: extents.center.x - w / 2, originY: extents.center.y - h / 2);
}

/// The one way entities enter this document: `AddEntityCommand`, in source
/// order, so draw order (ascending handle) is reading order.
class _Pen {
  _Pen(this.doc);
  final DraftDocument doc;

  void _add(EntityKind kind, List<double> coords, List<double> scalars,
      {required int lineweight, required DraftColor color}) {
    doc.commands.execute(AddEntityCommand(
      record: EntityRecord(
        handle: doc.handleSeed.next(),
        owner: doc.rootHandle,
        kind: kind,
        layer: ReservedHandles.layerZero,
        linetype: ReservedHandles.byLayerLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: color,
        lineweight: lineweight,
        transparency: kByLayer,
        flags: 0,
      ),
      payload: GeometryPayload(
        coords: Float64List.fromList(coords),
        scalars: Float64List.fromList(scalars),
      ),
    ));
  }

  void line(double ax, double ay, double bx, double by,
          {required int lineweight, required DraftColor color}) =>
      _add(EntityKind.line, [ax, ay, bx, by], const [],
          lineweight: lineweight, color: color);

  /// Spec 05 D14: a furniture piece as one region, the fill under its
  /// boundary, the boundary keeping today's colour and weight.
  void _region(EntityKind kind, GeometryPayload payload) =>
      doc.commands.execute(addDraftedRegion(doc, kind, payload,
          boundaryColor: _furnitureColor, boundaryLineweight: 25)!);

  void rectRegion(double ax, double ay, double bx, double by) => _region(
      EntityKind.polyline, rectanglePayload(Vector2(ax, ay), Vector2(bx, by)));

  void polygonRegion(List<double> xy) => _region(
      EntityKind.polyline,
      polylinePayload([
        for (var i = 0; i < xy.length; i += 2) Vector2(xy[i], xy[i + 1]),
      ], closed: true));

  void circleRegion(double cx, double cy, double r) =>
      _region(EntityKind.circle, circlePayload(Vector2(cx, cy), r));

  /// Spec 08 D18: a centre-justified wall from (`sx`, `sy`) to (`ex`, `ey`),
  /// [t] thick, in its own root-level group at the identity, as the Wall
  /// tool adds one. Returns its handle.
  Handle wall(double sx, double sy, double ex, double ey, double t) {
    final h = doc.handleSeed.next();
    doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h,
          parent: doc.rootHandle,
          transform: Transform2.identity(),
          children: const [])),
      SetComponentCommand<WallParams>(
          h, WallParams(sx, sy, ex, ey, t, Justification.centre)),
    ], label: 'Add wall'));
    return h;
  }

  /// Spec 08 D18: an opening [o] in its own root-level group at the
  /// identity, as the opening tools add one.
  void opening(OpeningParams o) {
    final h = doc.handleSeed.next();
    doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h,
          parent: doc.rootHandle,
          transform: Transform2.identity(),
          children: const [])),
      SetComponentCommand<OpeningParams>(h, o),
    ], label: 'Add ${o.kind.name}'));
  }

  /// Hairline tile joints inside a rectangle.
  void grid(double ax, double ay, double bx, double by,
      {required double pitch, required bool both}) {
    for (var x = ax + pitch; x < bx; x += pitch) {
      line(x, ay, x, by, lineweight: 0, color: _finishColor);
    }
    if (!both) return;
    for (var y = ay + pitch; y < by; y += pitch) {
      line(ax, y, bx, y, lineweight: 0, color: _finishColor);
    }
  }

  /// Parquet: strips along x, plank joints staggered by half a plank on
  /// alternate rows.
  void parquet(double ax, double ay, double bx, double by,
      {required double strip, required double plank}) {
    var row = 0;
    for (var y = ay + strip; y < by; y += strip, row++) {
      line(ax, y, bx, y, lineweight: 0, color: _finishColor);
      final offset = row.isOdd ? plank / 2 : 0.0;
      for (var x = ax + offset + plank; x < bx; x += plank) {
        line(x, y - strip, x, y, lineweight: 0, color: _finishColor);
      }
    }
  }
}
