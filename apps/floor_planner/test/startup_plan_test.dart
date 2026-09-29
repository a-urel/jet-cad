import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:floor_planner/parametric/box.dart';
import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/parametric/dimension.dart';
import 'package:floor_planner/parametric/opening.dart';
import 'package:floor_planner/parametric/room.dart';
import 'package:floor_planner/parametric/room_trace.dart';
import 'package:floor_planner/parametric/separator.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/startup_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/dimension_fixture.dart' show dimLines, dimText, dimTextGeometry;
import 'support/room_fixture.dart'
    show
        anchorOf,
        kids,
        kindOf,
        labelsOf,
        labelStrings,
        payloadOf,
        probeView,
        worldPoints;

/// Even-odd ray casting: a geometric decision (Tolerance is not needed --
/// the boundary case never arises for the sampled points below).
bool _pointInPolygon(Vector2 p, List<Vector2> poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final pi = poly[i], pj = poly[j];
    final crosses = (pi.y > p.y) != (pj.y > p.y);
    if (crosses && p.x < (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y) + pi.x) {
      inside = !inside;
    }
  }
  return inside;
}

/// The furniture: the root-owned regions' boundaries, ascending (spec 08
/// D18). Wall pieces are regions too, but each belongs to its wall's group.
List<Handle> furnitureOf(DraftDocument doc) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.ownerAt(slot) == doc.rootHandle &&
            doc.fills.fillsOf(doc.entities.handleAt(slot)).isNotEmpty)
          doc.entities.handleAt(slot),
    ]..sort((a, b) => a.value.compareTo(b.value));

/// The walls' extents: the union of every wall group's bounds (each at the
/// identity, SP5), so the dimensions' lines outside the plan are not in it.
Aabb2 wallExtents(DraftDocument doc) {
  var box = Aabb2.empty();
  for (final w in doc.components.withComponent<WallParams>()) {
    box = box.union(doc.definitionBounds(w));
  }
  return box;
}

void main() {
  late FlutterTextMeasurer measurer;
  setUp(() {
    measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
  });

  test('is at the target scale: between 500 and 1,000 entities', () {
    final doc = startupPlan(measurer);
    expect(doc.entities.liveCount, inInclusiveRange(500, 1000));
  });

  // The degenerate fixture this repository names: a drawing centred on the
  // origin. The extents must not contain (0, 0) and must not be symmetric
  // about either axis.
  test('is off-origin and not axis-symmetric', () {
    final doc = startupPlan(measurer);
    final e = doc.extents;
    expect(e.minX > 0 || e.maxX < 0, isTrue, reason: 'x span excludes 0');
    expect(e.minY > 0 || e.maxY < 0, isTrue, reason: 'y span excludes 0');
    expect(e.minX, isNot(-e.maxX));
    expect(e.minY, isNot(-e.maxY));
    expect(e.maxX - e.minX, isNot(e.maxY - e.minY),
        reason: 'not square either');
  });

  test(
      'the outer walls close: the walls\' extents are the outer rectangle; '
      'the document\'s reach past it to the overall dimensions', () {
    final doc = startupPlan(measurer);
    final e = wallExtents(doc);
    expect(e.minX, kPlanOriginX);
    expect(e.minY, kPlanOriginY);
    expect(e.maxX, kPlanOriginX + kPlanWidth);
    expect(e.maxY, kPlanOriginY + kPlanHeight);

    // Spec 11 D17: the overall width and depth lie outside the walls, so
    // the document's extents reach past them (Ruling 11-14, the
    // controller's ruling). At 1:50, the slash is 3 mm on paper, 150 mm
    // long, at 45°: half of it reaches 75 · cos 45° = 53.033 each way; the
    // extension lines overshoot the dimension line by 2 mm on paper, 100.
    // - west: the width's slash at x 12,000 − 53.033 = 11,946.967;
    // - south: the width's line at 8,000 − 500 = 7,500, its extension lines
    //   100 past it, to 7,400 (its slashes reach only 7,446.967);
    // - east: the depth's line at 26,000 + 300 = 26,300, its extension
    //   lines to 26,400 (its slashes only 26,353.033);
    // - north: the depth's slash at y 17,000 + 53.033 = 17,053.033.
    final half = 75 * math.cos(math.pi / 4);
    expect(half, closeTo(53.033, 1e-3));
    final d = doc.extents;
    expect(d.minX, closeTo(kPlanOriginX - half, 1e-6));
    expect(d.minY, closeTo(kPlanOriginY - 500 - 100, 1e-6));
    expect(d.maxX, closeTo(kPlanOriginX + kPlanWidth + 300 + 100, 1e-6));
    expect(d.maxY, closeTo(kPlanOriginY + kPlanHeight + half, 1e-6));
  });

  // Spec D4's owed check: the constants against the document's own units.
  // At 1440 x 900 the fit scale is 0.95 * min(1440 / 14000, 900 / 9000) --
  // 0.095 px/mm -- so kMinScale allows ~95x further out and kMaxScale
  // ~1000x further in. Both decades are needed by a CAD user; neither is
  // absurd. The numbers are printed so the results note can quote them.
  test('the clamp constants bracket the fitted scale by decades', () {
    final doc = startupPlan(measurer);
    final fit = ViewportTransform.fit(doc.extents, const Size(1440, 900));
    // ignore: avoid_print
    print('STARTUP fit scale ${fit.scale} px/mm; '
        'min $kMinScale (${fit.scale / kMinScale}x out), '
        'max $kMaxScale (${kMaxScale / fit.scale}x in)');
    expect(fit.scale / kMinScale, greaterThan(10));
    expect(kMaxScale / fit.scale, greaterThan(100));
  });

  test(
      'the startup plan carries an A4 landscape page at 1:50 centred on the '
      'plan, in millimetres, with no history', () {
    final doc = startupPlan(measurer);
    final page = doc.components.get<PageComponent>(doc.rootHandle)!;
    expect(page.preset, SheetSize.a4);
    expect(page.orientation, PageOrientation.landscape);
    expect(page.scaleDenominator, 50);
    expect(page.displayUnit, DisplayUnit.meters);
    final rect = sheetWorldRect(page);
    // Centred on the plan, the walls' outer rectangle (19,000, 12,500):
    // the page is set before the rooms and dimensions, and spec 11 D17's
    // overall dimensions, outside the walls, do not move it (Ruling 11-14,
    // the controller's ruling).
    final extents = wallExtents(doc);
    expect(extents.center.x, 19000);
    expect(extents.center.y, 12500);
    expect(rect.center.x, closeTo(extents.center.x, 1e-9));
    expect(rect.center.y, closeTo(extents.center.y, 1e-9));
    expect(rect.minX, lessThan(kPlanOriginX));
    expect(rect.maxX, greaterThan(kPlanOriginX + kPlanWidth));
    expect(doc.header.units, DrawingUnits.millimeters);
    expect(doc.commands.canUndo, isFalse, reason: 'Ruling 04-1');
  });

  test(
      'SP1 the furniture is eight root-owned filled regions with the '
      'furniture outline; the plan holds 611 entities', () {
    final doc = startupPlan(measurer);
    final boundaries = furnitureOf(doc);
    expect(boundaries, hasLength(8));
    for (final b in boundaries) {
      final r = doc.entities.read(doc.entities.slotOf(b)!);
      expect(r.color, const TrueColor(0x8A6D3B));
      expect(r.lineweight, 25);
      final fill = doc.fills.fillsOf(b).single;
      final f = doc.entities.read(doc.entities.slotOf(fill)!);
      expect(f.color, kDraftFillColor);
      expect(f.owner, doc.rootHandle);
    }
    // Spec 08 D18: 509 (Ruling 05-12: 523 − 14) − 70 hand-drawn entities
    // (8 exterior and 10 partition lines, 7 doors × 4, 8 windows × 3) + 110
    // parametric children: 72 for the walls (3 per piece: 2 + 3 + 5 + 3
    // pieces for E1–E4, 3 + 2 + 3 + 2 + 1 for P1–P5, one more than each
    // wall's openings), 14 for the doors (2 each) and 24 for the windows
    // (3 each). Measured (Task 13, Ruling 08-18), not assumed.
    //
    // Spec 10 D23: 549 + 28 room children (seven rooms, each a tint fill,
    // its boundary, a name TEXT and an area TEXT) + 1 separator child (its
    // dashed POLYLINE) + 3 column children (one wall piece, 3 as above) =
    // 581. Measured (Task 18's probe, Ruling 10-20), as D23 expected.
    //
    // Spec 11 D17: 581 + 5 × 6 dimension children (each a dimension line,
    // two extension lines, two slashes and a value TEXT) = 611. Measured
    // (Task 14's probe, Ruling 11-13), as D17 expected.
    expect(doc.entities.liveCount, 581 + 5 * 6);
    expect(doc.entities.liveCount, 611);
  });

  test(
      'SP2 every furniture fill draws over every floor-finish line (M-05r); '
      'the nine walls\' pieces are built first, below both (08 D18); the '
      'column, the separator and the rooms come after the furniture, in '
      'that order (10 D23)', () {
    final doc = startupPlan(measurer);
    var maxFinish = 0, minFinish = 1 << 62, minFill = 1 << 62;
    var maxFill = 0;
    var maxWallChild = 0;
    // Spec 10 D23: the column is the tenth wall, the last one built.
    final column = (doc.components.withComponent<WallParams>().toList()
          ..sort((a, b) => a.value.compareTo(b.value)))
        .last;
    for (final slot in doc.entities.liveSlots) {
      final r = doc.entities.read(slot);
      if (r.kind == EntityKind.fill && r.owner == doc.rootHandle) {
        if (r.handle.value < minFill) minFill = r.handle.value;
        if (r.handle.value > maxFill) maxFill = r.handle.value;
      }
      if (r.kind == EntityKind.line &&
          r.color == const TrueColor(0xBBBBBB) &&
          r.handle.value > maxFinish) {
        maxFinish = r.handle.value;
      }
      if (r.kind == EntityKind.line &&
          r.color == const TrueColor(0xBBBBBB) &&
          r.handle.value < minFinish) {
        minFinish = r.handle.value;
      }
      if (doc.components.get<WallParams>(r.owner) != null &&
          r.owner != column &&
          r.handle.value > maxWallChild) {
        maxWallChild = r.handle.value;
      }
    }
    expect(maxFinish, greaterThan(0));
    expect(minFill, greaterThan(maxFinish));
    expect(maxWallChild, greaterThan(0));
    // Every wall child lies below the LOWEST finish line, not merely below
    // the highest: a grid built before the walls would interleave them.
    expect(maxWallChild, lessThan(minFinish),
        reason: 'every wall child lies below every finish line');

    // Spec 10 D23: after the furniture, the column (so its band draws over
    // the parquet it stands on), then the separator, then the rooms, each
    // object's handle and its children's above everything before it.
    final separator = doc.components.withComponent<SeparatorParams>().single;
    final rooms = doc.components.withComponent<RoomParams>().toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final order = [column, separator, ...rooms];
    var floor = maxFill;
    for (final g in order) {
      final children = [for (final k in kids(doc, g)) k.value]..sort();
      expect(children, isNotEmpty, reason: 'object $g draws');
      expect(g.value, greaterThan(floor), reason: 'object $g after the last');
      expect(children.first, greaterThan(g.value));
      floor = children.last;
    }
  });

  test(
      'SP3 no door leaf or swing lies under a furniture fill (Ruling F-1, '
      'M-05aa)', () {
    final doc = startupPlan(measurer);

    // Every furniture boundary (SP1's eight), as a polygon or a circle.
    final polygons = <List<Vector2>>[];
    final circles = <(Vector2, double)>[];
    for (final h in furnitureOf(doc)) {
      final slot = doc.entities.slotOf(h)!;
      final kind = doc.entities.kindAt(slot);
      final payload = doc.geometry.read(doc.entities.geomIndexAt(slot));
      if (kind == EntityKind.circle) {
        circles.add((payload.pointAt(0), payload.scalars[0]));
      } else {
        polygons.add([
          for (var i = 0; i < payload.pointCount; i++) payload.pointAt(i),
        ]);
      }
    }
    bool insideFurniture(Vector2 p) {
      for (final (c, r) in circles) {
        if ((p - c).length <= r) return true;
      }
      for (final poly in polygons) {
        if (_pointInPolygon(p, poly)) return true;
      }
      return false;
    }

    // Every arc is a door swing (nothing else in the plan emits one); every
    // door leaf is a line entity with one endpoint exactly on the arc's
    // centre and its far endpoint the arc's radius away (Tolerance: which
    // line is the leaf is a geometric decision; the endpoints themselves
    // are the stored values, compared exactly).
    const tol = Tolerance.standard;
    final arcs = <GeometryPayload>[];
    final lines = <GeometryPayload>[];
    for (final slot in doc.entities.liveSlots) {
      final kind = doc.entities.kindAt(slot);
      if (kind != EntityKind.arc && kind != EntityKind.line) continue;
      final payload = doc.geometry.read(doc.entities.geomIndexAt(slot));
      (kind == EntityKind.arc ? arcs : lines).add(payload);
    }
    expect(arcs, hasLength(7), reason: 'one swing per door');

    final samples = <Vector2>[];
    for (final arc in arcs) {
      final c = arc.pointAt(0);
      final radius = arc.scalars[0];
      final start = arc.scalars[1];
      final sweep = arc.scalars[2];
      for (final t in const [0.0, 0.25, 0.5, 0.75, 1.0]) {
        final a = start + sweep * t;
        samples.add(
            Vector2(c.x + radius * math.cos(a), c.y + radius * math.sin(a)));
      }
      final leaf = lines.firstWhere((l) {
        final a = l.pointAt(0), b = l.pointAt(1);
        final Vector2 far;
        if (a.x == c.x && a.y == c.y) {
          far = b;
        } else if (b.x == c.x && b.y == c.y) {
          far = a;
        } else {
          return false;
        }
        return tol.eq((far - c).length, radius);
      }, orElse: () => throw StateError('no leaf found for arc at $c'));
      final a = leaf.pointAt(0), b = leaf.pointAt(1);
      for (final t in const [0.0, 0.25, 0.5, 0.75, 1.0]) {
        samples.add(Vector2(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t));
      }
    }
    expect(samples, hasLength(70));

    for (final p in samples) {
      expect(insideFurniture(p), isFalse,
          reason: 'door point $p lies under a furniture fill');
    }
  });

  test(
      'SP4 every doorway is clear of furniture and of the column for 900 mm '
      'on both sides (Ruling F-8, 10 D23)', () {
    final doc = startupPlan(measurer);

    final polygons = <List<Vector2>>[];
    final circles = <(Vector2, double)>[];
    for (final h in furnitureOf(doc)) {
      final slot = doc.entities.slotOf(h)!;
      final payload = doc.geometry.read(doc.entities.geomIndexAt(slot));
      if (doc.entities.kindAt(slot) == EntityKind.circle) {
        circles.add((payload.pointAt(0), payload.scalars[0]));
      } else {
        polygons.add([
          for (var i = 0; i < payload.pointCount; i++) payload.pointAt(i),
        ]);
      }
    }
    // Spec 10 D23: the column (the tenth wall, one piece) is an obstacle
    // too, its outline as drawn.
    final column = (doc.components.withComponent<WallParams>().toList()
          ..sort((a, b) => a.value.compareTo(b.value)))
        .last;
    // Its piece's region: the fill, drawn from the boundary it names.
    final columnFill = [
      for (final k in kids(doc, column))
        if (kindOf(doc, k) == EntityKind.fill) k,
    ].single;
    final columnOutline = worldPoints(
        doc, Handle(payloadOf(doc, columnFill).scalars[0].toInt()),
        closed: true);
    expect(columnOutline, hasLength(4), reason: 'premise: a square');
    polygons.add(columnOutline);
    bool insideFurniture(Vector2 p) =>
        circles.any((c) => (p - c.$1).length <= c.$2) ||
        polygons.any((poly) => _pointInPolygon(p, poly));

    // Each door's swing is a quarter arc about the hinge. One end of it is
    // the leaf's far end (perpendicular to the wall); the other is the far
    // jamb, so hinge → far jamb spans the opening along the wall. The
    // approach zone is that span swept 900 mm to either side of the hinge's
    // face -- the wall's swing face, where 08 D10 puts the hinge, not its
    // centreline: where a person stands to walk through.
    const tol = Tolerance.standard;
    const depth = 900.0;
    final lines = <GeometryPayload>[];
    final arcs = <GeometryPayload>[];
    for (final slot in doc.entities.liveSlots) {
      final kind = doc.entities.kindAt(slot);
      if (kind != EntityKind.arc && kind != EntityKind.line) continue;
      final payload = doc.geometry.read(doc.entities.geomIndexAt(slot));
      (kind == EntityKind.arc ? arcs : lines).add(payload);
    }
    expect(arcs, hasLength(7), reason: 'one swing per door');
    var sampled = 0;
    for (final arc in arcs) {
      final c = arc.pointAt(0);
      final r = arc.scalars[0];
      Vector2 end(double a) =>
          Vector2(c.x + r * math.cos(a), c.y + r * math.sin(a));
      final e0 = end(arc.scalars[1]);
      final e1 = end(arc.scalars[1] + arc.scalars[2]);
      // The leaf starts exactly at the hinge; its far end is on the arc.
      bool isLeafEnd(Vector2 e) => lines.any((l) {
            final a = l.pointAt(0), b = l.pointAt(1);
            final far = a.x == c.x && a.y == c.y
                ? b
                : (b.x == c.x && b.y == c.y ? a : null);
            return far != null && tol.eq((far - e).length, 0);
          });
      final leafEnd = isLeafEnd(e0) ? e0 : e1;
      final jamb = identical(leafEnd, e0) ? e1 : e0;
      expect(isLeafEnd(jamb), isFalse, reason: 'door at $c: one leaf');
      final along = (jamb - c) / r;
      final across = (leafEnd - c) / r;
      for (var i = 0; i <= 20; i++) {
        for (var j = -18; j <= 18; j++) {
          final p = c + along * (r * i / 20) + across * (depth * j / 18);
          sampled++;
          expect(insideFurniture(p), isFalse,
              reason: 'the doorway at $c is blocked at $p');
        }
      }
    }
    expect(sampled, 7 * 21 * 37);
  });

  test(
      'SP5 the sample plan is nine walls, seven doors and eight windows, '
      'exactly as spec 08 D18\'s tables say, then a column, a separator and '
      'seven rooms as spec 10 D23 says, then spec 11 D17\'s five dimensions '
      'above every room child; no gap, no box; drift() and diagnostics() are '
      'empty', () {
    final doc = startupPlan(measurer);
    const x0 = kPlanOriginX, y0 = kPlanOriginY;
    const x1 = kPlanOriginX + kPlanWidth, y1 = kPlanOriginY + kPlanHeight;
    const c = Justification.centre;
    // E1–E4, P1–P5, in the table's order, which is the build order.
    const walls = [
      WallParams(x0 + 125, y0 + 125, x1 - 125, y0 + 125, 250, c),
      WallParams(x1 - 125, y0 + 125, x1 - 125, y1 - 125, 250, c),
      WallParams(x1 - 125, y1 - 125, x0 + 125, y1 - 125, 250, c),
      WallParams(x0 + 125, y1 - 125, x0 + 125, y0 + 125, 250, c),
      WallParams(x0 + 5000, y0 + 125, x0 + 5000, y1 - 125, 120, c),
      WallParams(x0 + 125, y0 + 5000, x0 + 5000, y0 + 5000, 120, c),
      WallParams(x0 + 5000, y0 + 3500, x1 - 125, y0 + 3500, 120, c),
      WallParams(x0 + 2600, y0 + 5000, x0 + 2600, y1 - 125, 120, c),
      WallParams(x0 + 9500, y0 + 125, x0 + 9500, y0 + 3500, 120, c),
      // Spec 10 D23: the column, 400 x 400, the tenth wall.
      WallParams(x0 + 11500, y0 + 6000, x0 + 11900, y0 + 6000, 400, c),
    ];
    final ws = doc.components.withComponent<WallParams>().toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    expect([for (final w in ws) doc.components.get<WallParams>(w)], walls);
    for (final w in ws) {
      expect(doc.tree[w], isA<GroupNode>());
      expect(doc.tree[w]!.parent, doc.rootHandle);
      expect((doc.tree[w]! as GroupNode).transform, Transform2.identity());
    }
    final [e1, e2, e3, e4, p1, p2, p3, p4, p5, column] = ws;
    const start = HingeEnd.start;
    const left = SwingSide.left, right = SwingSide.right;
    const door = OpeningKind.door, window = OpeningKind.window;
    final openings = [
      OpeningParams(p1, 5875, 900, door, hinge: start, swing: left),
      OpeningParams(p1, 1375, 900, door, hinge: start, swing: right),
      OpeningParams(p4, 2800, 800, door, hinge: start, swing: right),
      OpeningParams(p2, 1075, 800, door, hinge: start, swing: right),
      OpeningParams(p3, 2000, 800, door, hinge: start, swing: left),
      OpeningParams(p3, 6500, 700, door, hinge: start, swing: left),
      OpeningParams(e1, 6375, 1000, door, hinge: start, swing: left),
      OpeningParams(e3, 12575, 1200, window),
      OpeningParams(e3, 9975, 1200, window),
      OpeningParams(e3, 6675, 1200, window),
      OpeningParams(e3, 3075, 1200, window),
      OpeningParams(e2, 1675, 1200, window),
      OpeningParams(e2, 6075, 1800, window),
      OpeningParams(e4, 6675, 1000, window),
      OpeningParams(e4, 2275, 1400, window),
    ];
    final os = doc.components.withComponent<OpeningParams>().toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    expect(
        [for (final o in os) doc.components.get<OpeningParams>(o)], openings);
    for (final o in os) {
      expect(doc.tree[o]!.parent, doc.rootHandle);
      expect((doc.tree[o]! as GroupNode).transform, Transform2.identity());
    }
    expect(os.first.value, greaterThan(p5.value),
        reason: 'the nine walls, then the openings');
    expect(column.value, greaterThan(os.last.value),
        reason: 'then the column (10 D23)');
    expect(doc.components.withComponent<BoxParams>(), isEmpty);

    // Spec 10 D23: the separator, x = 21,500 from P3's north face to E3's
    // inner face, then the seven rooms in the table's order, each a
    // root-level group at the identity with an auto label.
    final [separator] =
        doc.components.withComponent<SeparatorParams>().toList();
    expect(doc.components.get<SeparatorParams>(separator),
        const SeparatorParams(x0 + 9500, y0 + 3560, x0 + 9500, y0 + 8750));
    expect(separator.value, greaterThan(column.value));
    final rooms = doc.components.withComponent<RoomParams>().toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    expect([
      for (final r in rooms) doc.components.get<RoomParams>(r)
    ], const [
      RoomParams(14500, 10500, 'Hall'),
      RoomParams(13300, 15000, 'Bedroom 1'),
      RoomParams(15800, 15000, 'Bedroom 2'),
      RoomParams(19000, 10000, 'Kitchen'),
      RoomParams(23500, 10000, 'Bath'),
      RoomParams(24500, 16000, 'Living'),
      RoomParams(19000, 16000, 'Dining'),
    ]);
    expect(rooms.first.value, greaterThan(separator.value));
    for (final g in [separator, ...rooms]) {
      expect(doc.tree[g]!.parent, doc.rootHandle);
      expect((doc.tree[g]! as GroupNode).transform, Transform2.identity());
    }
    // Each room's labels: its name and D23's area label, the page's metres.
    expect([
      for (final r in rooms) labelStrings(doc, r)
    ], const [
      ['Hall', '22.00 m²'],
      ['Bedroom 1', '8.45 m²'],
      ['Bedroom 2', '8.41 m²'],
      ['Kitchen', '13.97 m²'],
      ['Bath', '13.37 m²'],
      ['Living', '21.90 m²'],
      ['Dining', '23.04 m²'],
    ]);

    // Spec 11 D17 (R-30): the five dimensions, in the table's order, each a
    // root-level group at the identity, their ends what the tool would store
    // (decision 19): the width on E1's outer corners, the depth on E2's, the
    // Hall from E1's inner corner to P1's west T-butt corner, the Kitchen
    // from P1's east one to P5's west one, and the diagonal from E1's inner
    // east corner (not E2/0/left, the spike's) to the basin's centre, a
    // fixed end. The offsets: −500 and −300 keep the overall lines on the
    // sheet (not the spike's 1,200); +900 inside; `+0.0` on the diagonal.
    // `==` compares the ends and kinds exactly and the offsets with
    // `compareTo` (D2).
    final dims = doc.components.withComponent<DimensionParams>().toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    const r = WallSide.right, l = WallSide.left;
    final want = [
      DimensionParams(AttachedEnd(e1, 0, r), AttachedEnd(e1, 1, r),
          DimKind.horizontal, -500),
      DimensionParams(
          AttachedEnd(e2, 0, r), AttachedEnd(e2, 1, r), DimKind.vertical, -300),
      DimensionParams(AttachedEnd(e1, 0, l), AttachedEnd(p1, 0, l),
          DimKind.horizontal, 900),
      DimensionParams(AttachedEnd(p1, 0, r), AttachedEnd(p5, 0, l),
          DimKind.horizontal, 900),
      DimensionParams(AttachedEnd(e1, 1, l),
          const FixedEnd(x0 + 10300, y0 + 1200), DimKind.aligned, 0.0),
    ];
    expect(
        [for (final d in dims) doc.components.get<DimensionParams>(d)], want);
    for (final (i, d) in dims.indexed) {
      final p = doc.components.get<DimensionParams>(d)!;
      expect(p.offset.compareTo(want[i].offset), 0, reason: 'dimension $i');
      expect(doc.tree[d]!.parent, doc.rootHandle);
      expect((doc.tree[d]! as GroupNode).transform, Transform2.identity());
    }
    // Draw order: every dimension and every dimension child lies above
    // every room child, so the dimensions draw over the rooms' tints.
    var maxRoomChild = 0;
    for (final g in rooms) {
      for (final k in kids(doc, g)) {
        if (k.value > maxRoomChild) maxRoomChild = k.value;
      }
    }
    expect(maxRoomChild, greaterThan(0));
    for (final d in dims) {
      final children = [for (final k in kids(doc, d)) k.value]..sort();
      expect(children, hasLength(6), reason: 'dimension $d');
      expect(d.value, greaterThan(maxRoomChild), reason: 'dimension $d');
      expect(children.first, greaterThan(maxRoomChild),
          reason: 'dimension $d\'s children above every room child');
    }

    final system = ParametricSystem(doc, parametricCatalog);
    expect(system.drift(), isEmpty);
    expect(system.diagnostics(), isEmpty,
        reason: 'no clamp, no overlap, no no-fit, no dangling reference; no '
            'room.shared, no room.tint, no separator.degenerate; no '
            'dimension.degenerate, no dimension.broken');
  });

  /// The five dimensions of spec 11 D17, ascending: the build order.
  List<Handle> dimensionsOf(DraftDocument doc) =>
      doc.components.withComponent<DimensionParams>().toList()
        ..sort((a, b) => a.value.compareTo(b.value));

  test(
      'SP8 the five dimensions read D17\'s values at 1:50 m with text 125 '
      'high, reference the walls listed, and a click on each line selects '
      'it', () {
    final doc = startupPlan(measurer);
    final dims = dimensionsOf(doc);
    expect(dims, hasLength(5));
    final ws = doc.components.withComponent<WallParams>().toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final [e1, e2, _, _, p1, _, _, _, p5, _] = ws;

    // Spec 11 D17's table, by hand from the faces (exterior 250 about the
    // rectangle (12,125, 8,125)–(25,875, 16,875), partitions ±60):
    // - the width, E1's outer corners: 26,000 − 12,000 = 14,000 → 14.00;
    // - the depth, E2's outer corners: 17,000 − 8,000 = 9,000 → 9.00;
    // - the Hall, E1's inner corner to P1's west butt corner (17,000 − 60):
    //   16,940 − 12,250 = 4,690 → 4.69;
    // - the Kitchen, P1's east butt corner (17,000 + 60) to P5's west one
    //   (21,500 − 60): 21,440 − 17,060 = 4,380 → 4.38;
    // - the diagonal, (25,750, 8,250) to the basin's centre (22,300,
    //   9,200): √(3,450² + 950²) = √12,805,000 = 3,578.4 → 3.58 (not 3.45,
    //   its x projection).
    expect(3450.0 * 3450 + 950 * 950, 12805000);
    expect(math.sqrt(12805000), closeTo(3578.407, 1e-3));
    expect([for (final d in dims) dimText(doc, d)],
        ['14.00', '9.00', '4.69', '4.38', '3.58']);
    // 2.5 mm on paper at 1:50: 125 mm.
    for (final d in dims) {
      final (_, height, _) = dimTextGeometry(doc, d);
      expect(height, 125.0, reason: 'dimension $d');
    }
    // The dimension lines, by hand: the width's at 8,000 − 500 = 7,500; the
    // depth's at 26,000 + 300 = 26,300; the Hall's and the Kitchen's at
    // 8,250 + 900 = 9,150; the diagonal's through its two points.
    final lines = [for (final d in dims) dimLines(doc, d)[0]];
    final wantLines = [
      (Vector2(12000, 7500), Vector2(26000, 7500)),
      (Vector2(26300, 8000), Vector2(26300, 17000)),
      (Vector2(12250, 9150), Vector2(16940, 9150)),
      (Vector2(17060, 9150), Vector2(21440, 9150)),
      (Vector2(25750, 8250), Vector2(22300, 9200)),
    ];
    for (final (i, (a, b)) in lines.indexed) {
      expect((a - wantLines[i].$1).length, lessThan(1e-9), reason: '$i q0');
      expect((b - wantLines[i].$2).length, lessThan(1e-9), reason: '$i q1');
    }
    // D17's references: E1; E2; E1 and P1; P1 and P5; E1.
    const type = DimensionType();
    expect([
      for (final d in dims)
        type.references(doc.components.get<DimensionParams>(d)!).toList()
    ], [
      [e1],
      [e2],
      [e1, p1],
      [p1, p5],
      [e1],
    ]);

    // The click (the plan's Ruling 11-24): the select tool's pick —
    // `pickInto` with `picking()` and a radius of kPickRadiusPixels over the
    // camera's px/mm — at a quarter of the way along each dimension line,
    // on the camera the shell fits to this plan at 1440 x 900.
    final fit = ViewportTransform.fit(doc.extents, const Size(1440, 900));
    final radius = kPickRadiusPixels / fit.scale;
    expect(radius, inInclusiveRange(50, 100), reason: 'premise: about 68 mm');
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final hit = HitPath();
    for (final (i, (a, b)) in lines.indexed) {
      final q = a + (b - a) * 0.25;
      expect(
          index.pickInto(q, radius, const QueryFilter.picking(), hit), isTrue,
          reason: 'dimension $i at $q');
      expect(resolveHit(hit, doc), SelectionKey.root(dims[i]),
          reason: 'dimension $i at $q');
    }
  });

  test(
      'SP9 the page switched to 1:100 ft-in in one command reads D17\'s '
      'ft-in column at height 250; one undo step; undo restores the metres',
      () {
    final doc = startupPlan(measurer);
    final system = installParametric(doc);
    addTearDown(system.dispose);
    final dims = dimensionsOf(doc);
    expect(dims, hasLength(5));
    const metres = ['14.00', '9.00', '4.69', '4.38', '3.58'];
    expect([for (final d in dims) dimText(doc, d)], metres);
    final depth = doc.commands.undoDepth;
    final page = doc.components.get<PageComponent>(doc.rootHandle)!;
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle,
        page.copyWith(
            scaleDenominator: 100, displayUnit: DisplayUnit.feetInches)));
    expect(doc.commands.undoDepth, depth + 1, reason: 'one undo step');
    // D17's ft-in column, in quarters of an inch (D9), by hand:
    // - 14,000 / 25.4 = 551.18" → 2,204.72 quarters → 2,205 = 551.25" =
    //   45 × 12 + 11.25: 45'-11 1/4";
    // - 9,000 → 354.33" → 1,417.32 → 1,417 = 354.25" = 29 × 12 + 6.25:
    //   29'-6 1/4";
    // - 4,690 → 184.65" → 738.58 → 739 = 184.75" = 15 × 12 + 4.75:
    //   15'-4 3/4";
    // - 4,380 → 172.44" → 689.76 → 690 = 172.5" = 14 × 12 + 4.5:
    //   14'-4 1/2";
    // - 3,578.407 → 140.88" → 563.53 → 564 = 141" = 11 × 12 + 9: 11'-9".
    expect([
      for (final d in dims) dimText(doc, d)
    ], [
      '45\'-11 1/4"',
      '29\'-6 1/4"',
      '15\'-4 3/4"',
      '14\'-4 1/2"',
      '11\'-9"',
    ]);
    // 2.5 mm on paper at 1:100: 250 mm.
    for (final d in dims) {
      final (_, height, _) = dimTextGeometry(doc, d);
      expect(height, 250.0, reason: 'dimension $d');
    }
    expect(system.drift(), isEmpty);

    doc.commands.undo();
    expect([for (final d in dims) dimText(doc, d)], metres);
    for (final d in dims) {
      final (_, height, _) = dimTextGeometry(doc, d);
      expect(height, 125.0, reason: 'dimension $d undone');
    }
    expect(system.drift(), isEmpty);
  });

  test(
      'SP6 the sample plan saves, loads and saves again byte for byte; the '
      'loaded plan has no drift and no diagnostic (spec 08 D19)', () {
    final doc = startupPlan(measurer);
    final saved = DraftDocumentCodec.encodeToString(doc);
    final loaded = DraftDocumentCodec.decodeString(saved, measurer: measurer,
        registerComponents: (r) {
      PageComponent.register(r);
      parametricCatalog.registerComponents(r);
    });
    final system = installParametric(loaded);
    expect(system.drift(), isEmpty);
    expect(system.diagnostics(), isEmpty);
    expect(loaded.entities.liveCount, doc.entities.liveCount);
    for (final o in doc.components.withComponent<OpeningParams>()) {
      expect(loaded.components.get<OpeningParams>(o),
          doc.components.get<OpeningParams>(o));
    }
    for (final w in doc.components.withComponent<WallParams>()) {
      expect(loaded.components.get<WallParams>(w),
          doc.components.get<WallParams>(w));
    }
    expect(DraftDocumentCodec.encodeToString(loaded), saved);
  });

  test(
      'SP7 each sample-plan room\'s net area matches the table to 1e-2 '
      'mm², its labels are 125 and 100 high, and its label point lies in its '
      'face', () {
    final doc = startupPlan(measurer);
    // Spec 10 D23's table, by hand from the inner faces: exterior faces at
    // x 12,250 and 25,750, y 8,250 and 16,750; partitions ±60 about their
    // centrelines (P1 x 17,000, P2 y 13,000, P3 y 11,500, P4 x 14,600, P5
    // x 21,500); the separator at x 21,500; the column 400 x 400.
    final table = {
      'Hall': (16940.0 - 12250) * (12940 - 8250), // 21,996,100
      'Bedroom 1': (14540.0 - 12250) * (16750 - 13060), // 8,450,100
      'Bedroom 2': (16940.0 - 14660) * (16750 - 13060), // 8,413,200
      'Kitchen': (21440.0 - 17060) * (11440 - 8250), // 13,972,200
      'Bath': (25750.0 - 21560) * (11440 - 8250), // 13,366,100
      // 22,057,500 − 160,000 = 21,897,500
      'Living': (25750.0 - 21500) * (16750 - 11560) - 400 * 400,
      'Dining': (21500.0 - 17060) * (16750 - 11560), // 23,043,600
    };
    // The labels (SP5) sit at least 0.0005 m² from a rounding tie: 22.0
    // (21.9961), 8.4501, 8.4132, 13.9722, 13.3661, 21.8975, 23.0436.
    expect(table.values.fold<double>(0, (a, b) => a + b), 111138800,
        reason: 'D23\'s total');
    final rooms = doc.components.withComponent<RoomParams>().toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    expect([for (final r in rooms) doc.components.get<RoomParams>(r)!.name],
        table.keys.toList());
    final seeds = [
      for (final r in rooms)
        doc.tree
            .accumulatedTransform(r)
            .transformPoint(doc.components.get<RoomParams>(r)!.seed),
    ];
    // The rooms' own path: each face traced through a view of the plan, as
    // `RoomType.generate` traces it.
    final traces = probeView(doc, seeds: seeds).traces;
    for (final (i, r) in rooms.indexed) {
      final name = doc.components.get<RoomParams>(r)!.name;
      final face = traces[i] as Traced;
      expect(face.area, closeTo(table[name]!, 1e-2), reason: name);
      expect(face.holes, hasLength(name == 'Living' ? 1 : 0),
          reason: '$name: the column is Living\'s one hole');
      // The heights at 1:50 (spec 10 D11): 2.5 and 2.0 mm on paper.
      final [nameText, areaText] = labelsOf(doc, r);
      expect(payloadOf(doc, nameText).scalars[0], 125.0, reason: name);
      expect(payloadOf(doc, areaText).scalars[0], 100.0, reason: name);
      // The label point, the anchor the name and the area sit about: inside
      // the outer ring and inside no hole.
      final a = anchorOf(doc, r) - seeds[i];
      List<Vector2> relative(List<Vector2> ring) =>
          [for (final q in ring) q - seeds[i]];
      expect(pointInRing(a, relative(face.ring)), isTrue, reason: name);
      for (final h in face.holes) {
        expect(pointInRing(a, relative(h)), isFalse, reason: name);
      }
    }
  });
}
