// The document the app opens before sub-project 12 gives it a file.
//
// A hand-written flat, in millimetres: two bedrooms, a living room, a
// kitchen, a bathroom and a hall, with doors, windows, a few pieces of
// furniture and the floor finishes drawn in -- the finishes are what carry
// the count into the target scale (500-5,000 entities) while every line
// stays something a person can check by eye: do the walls close, does the
// door swing into the room, is the tile grid square.
//
// **Off-origin and not axis-symmetric, by construction.** A drawing centred
// on (0, 0) is the degenerate fixture this repository keeps rediscovering,
// and this is the fixture a human looks at every session.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

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

const DraftColor _wallColor = TrueColor(0x202020);
const DraftColor _openingColor = TrueColor(0x2266CC);
const DraftColor _furnitureColor = TrueColor(0x8A6D3B);
const DraftColor _finishColor = TrueColor(0xBBBBBB);

/// Builds the startup flat over [measurer]. `DraftCanvas` refuses a document
/// whose measurer is not a `FlutterTextMeasurer`, so the caller supplies the
/// one the app owns.
DraftDocument startupPlan(FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  final p = _Pen(doc);

  // --- Exterior walls: two rectangles, outer and inner face. ---
  const x0 = kPlanOriginX, y0 = kPlanOriginY;
  const x1 = kPlanOriginX + kPlanWidth, y1 = kPlanOriginY + kPlanHeight;
  p.rect(x0, y0, x1, y1, lineweight: 50, color: _wallColor);
  p.rect(x0 + _wall, y0 + _wall, x1 - _wall, y1 - _wall,
      lineweight: 50, color: _wallColor);

  // --- Interior partitions (double lines), room by room. ---
  // Vertical: hall/living split at x = 5000 from the origin, full height.
  p.doubleV(x0 + 5000, y0 + _wall, y1 - _wall);
  // Horizontal: bedrooms above y = 5000 on the left; kitchen/bath on the
  // right below y = 3500.
  p.doubleH(y0 + 5000, x0 + _wall, x0 + 5000);
  p.doubleH(y0 + 3500, x0 + 5000, x1 - _wall);
  // Bedroom split at x = 2600, from y = 5000 up.
  p.doubleV(x0 + 2600, y0 + 5000, y1 - _wall);
  // Kitchen/bath split at x = 9500, from the bottom to y = 3500.
  p.doubleV(x0 + 9500, y0 + _wall, y0 + 3500);

  // --- Doors: an opening (two jamb lines), a leaf, and a quarter-arc swing.
  p.door(
      x: x0 + 5000,
      y: y0 + 6000,
      width: 900,
      vertical: true,
      swingRight: false);
  p.door(
      x: x0 + 5000, y: y0 + 1500, width: 900, vertical: true, swingRight: true);
  p.door(
      x: x0 + 2600, y: y0 + 7800, width: 800, vertical: true, swingRight: true);
  p.door(
      x: x0 + 1200,
      y: y0 + 5000,
      width: 800,
      vertical: false,
      swingRight: false);
  p.door(
      x: x0 + 7000,
      y: y0 + 3500,
      width: 800,
      vertical: false,
      swingRight: true);
  p.door(
      x: x0 + 11500,
      y: y0 + 3500,
      width: 700,
      vertical: false,
      swingRight: true);
  // The front door, in the bottom exterior wall. Openings are placed on the
  // wall's centreline so nothing they draw crosses the outer face: the
  // extents stay the outer rectangle (`startup_plan_test.dart`).
  p.door(
      x: x0 + 6500,
      y: y0 + _wall / 2,
      width: 1000,
      vertical: false,
      swingRight: true,
      thickness: _wall);

  // --- Windows: three parallel lines across the exterior wall. ---
  for (final wx in const [1300.0, 3900.0, 7200.0, 10800.0]) {
    p.window(x: x0 + wx, y: y1 - _wall / 2, width: 1200, vertical: false);
  }
  p.window(x: x1 - _wall / 2, y: y0 + 1800, width: 1200, vertical: true);
  p.window(x: x1 - _wall / 2, y: y0 + 6200, width: 1800, vertical: true);
  p.window(x: x0 + _wall / 2, y: y0 + 2200, width: 1000, vertical: true);
  p.window(x: x0 + _wall / 2, y: y0 + 6600, width: 1400, vertical: true);

  // --- Furniture: rectangles, one L. ---
  p.rect(x0 + 400, y0 + 6600, x0 + 2200, y0 + 8600,
      lineweight: 25, color: _furnitureColor); // bed
  p.rect(x0 + 2900, y0 + 6800, x0 + 4500, y0 + 8600,
      lineweight: 25, color: _furnitureColor); // bed
  p.rect(x0 + 6000, y0 + 4200, x0 + 9000, y0 + 5100,
      lineweight: 25, color: _furnitureColor); // sofa
  p.rect(x0 + 6400, y0 + 5600, x0 + 8600, y0 + 6800,
      lineweight: 25, color: _furnitureColor); // table
  p.rect(x0 + 5400, y0 + 400, x0 + 6000, y0 + 3100,
      lineweight: 25, color: _furnitureColor); // counter
  p.rect(x0 + 5400, y0 + 400, x0 + 9100, y0 + 1000,
      lineweight: 25, color: _furnitureColor); // counter L
  p.rect(x0 + 12200, y0 + 400, x0 + 13500, y0 + 2000,
      lineweight: 25, color: _furnitureColor); // bath
  p.circle(x0 + 7600, y0 + 6200, 350,
      lineweight: 25, color: _furnitureColor); // lamp
  p.circle(x0 + 10300, y0 + 1200, 220,
      lineweight: 25, color: _furnitureColor); // basin

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

  return doc;
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
          {int lineweight = 25, DraftColor color = _wallColor}) =>
      _add(EntityKind.line, [ax, ay, bx, by], const [],
          lineweight: lineweight, color: color);

  void rect(double ax, double ay, double bx, double by,
      {required int lineweight, required DraftColor color}) {
    line(ax, ay, bx, ay, lineweight: lineweight, color: color);
    line(bx, ay, bx, by, lineweight: lineweight, color: color);
    line(bx, by, ax, by, lineweight: lineweight, color: color);
    line(ax, by, ax, ay, lineweight: lineweight, color: color);
  }

  void circle(double cx, double cy, double r,
          {required int lineweight, required DraftColor color}) =>
      _add(EntityKind.circle, [cx, cy], [r],
          lineweight: lineweight, color: color);

  void arc(double cx, double cy, double r, double start, double sweep,
          {required int lineweight, required DraftColor color}) =>
      _add(EntityKind.arc, [cx, cy], [r, start, sweep],
          lineweight: lineweight, color: color);

  void doubleV(double x, double ya, double yb) {
    line(x - _partition / 2, ya, x - _partition / 2, yb, lineweight: 35);
    line(x + _partition / 2, ya, x + _partition / 2, yb, lineweight: 35);
  }

  void doubleH(double y, double xa, double xb) {
    line(xa, y - _partition / 2, xb, y - _partition / 2, lineweight: 35);
    line(xa, y + _partition / 2, xb, y + _partition / 2, lineweight: 35);
  }

  /// A door centred on a wall at ([x], [y]): two jambs across the wall, the
  /// leaf perpendicular to it, and a quarter-circle swing.
  void door({
    required double x,
    required double y,
    required double width,
    required bool vertical,
    required bool swingRight,
    double thickness = _partition,
  }) {
    final h = thickness / 2, w = width / 2;
    if (vertical) {
      line(x - h, y - w, x + h, y - w, lineweight: 18, color: _openingColor);
      line(x - h, y + w, x + h, y + w, lineweight: 18, color: _openingColor);
      // Hinge at the lower jamb; the leaf lies along +x or -x, and the
      // swing is the quarter turn from the leaf up to the wall.
      final dir = swingRight ? 1.0 : -1.0;
      line(x, y - w, x + dir * width, y - w,
          lineweight: 18, color: _openingColor);
      arc(x, y - w, width, swingRight ? 0.0 : math.pi / 2, math.pi / 2,
          lineweight: 18, color: _openingColor);
    } else {
      line(x - w, y - h, x - w, y + h, lineweight: 18, color: _openingColor);
      line(x + w, y - h, x + w, y + h, lineweight: 18, color: _openingColor);
      // Hinge at the left jamb; the leaf lies along +y or -y.
      final dir = swingRight ? 1.0 : -1.0;
      line(x - w, y, x - w, y + dir * width,
          lineweight: 18, color: _openingColor);
      arc(x - w, y, width, swingRight ? 0.0 : -math.pi / 2, math.pi / 2,
          lineweight: 18, color: _openingColor);
    }
  }

  /// A window centred on an exterior wall: three lines across the opening.
  void window({
    required double x,
    required double y,
    required double width,
    required bool vertical,
  }) {
    final w = width / 2;
    for (final t in const [-_wall / 2, 0.0, _wall / 2]) {
      if (vertical) {
        line(x + t, y - w, x + t, y + w, lineweight: 18, color: _openingColor);
      } else {
        line(x - w, y + t, x + w, y + t, lineweight: 18, color: _openingColor);
      }
    }
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
