import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:floor_planner/parametric/box.dart';
import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/parametric/opening.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/startup_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

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

  test('the outer walls close: the extents are the outer rectangle', () {
    final doc = startupPlan(measurer);
    final e = doc.extents;
    expect(e.minX, kPlanOriginX);
    expect(e.minY, kPlanOriginY);
    expect(e.maxX, kPlanOriginX + kPlanWidth);
    expect(e.maxY, kPlanOriginY + kPlanHeight);
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
    final extents = doc.extents;
    expect(rect.center.x, closeTo(extents.center.x, 1e-9));
    expect(rect.center.y, closeTo(extents.center.y, 1e-9));
    expect(rect.minX, lessThan(kPlanOriginX));
    expect(rect.maxX, greaterThan(kPlanOriginX + kPlanWidth));
    expect(doc.header.units, DrawingUnits.millimeters);
    expect(doc.commands.canUndo, isFalse, reason: 'Ruling 04-1');
  });

  test(
      'SP1 the furniture is eight root-owned filled regions with the '
      'furniture outline; the plan holds 549 entities', () {
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
    expect(doc.entities.liveCount, 549);
  });

  test(
      'SP2 every furniture fill draws over every floor-finish line (M-05r); '
      'the walls\' pieces are built first, below both (08 D18)', () {
    final doc = startupPlan(measurer);
    var maxFinish = 0, minFill = 1 << 62, maxWallChild = 0;
    for (final slot in doc.entities.liveSlots) {
      final r = doc.entities.read(slot);
      if (r.kind == EntityKind.fill &&
          r.owner == doc.rootHandle &&
          r.handle.value < minFill) {
        minFill = r.handle.value;
      }
      if (r.kind == EntityKind.line &&
          r.color == const TrueColor(0xBBBBBB) &&
          r.handle.value > maxFinish) {
        maxFinish = r.handle.value;
      }
      if (doc.components.get<WallParams>(r.owner) != null &&
          r.handle.value > maxWallChild) {
        maxWallChild = r.handle.value;
      }
    }
    expect(maxFinish, greaterThan(0));
    expect(minFill, greaterThan(maxFinish));
    expect(maxWallChild, greaterThan(0));
    expect(maxWallChild, lessThan(maxFinish),
        reason: 'the walls\' first children lie below the finishes');
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
      'SP4 every doorway is clear of furniture for 900 mm on both sides '
      '(Ruling F-8)', () {
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
    bool insideFurniture(Vector2 p) =>
        circles.any((c) => (p - c.$1).length <= c.$2) ||
        polygons.any((poly) => _pointInPolygon(p, poly));

    // Each door's swing is a quarter arc about the hinge. One end of it is
    // the leaf's far end (perpendicular to the wall); the other is the far
    // jamb, so hinge → far jamb spans the opening along the wall. The
    // approach zone is that span swept 900 mm to either side of the wall's
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
      'exactly as spec 08 D18\'s tables say; no gap, no box; drift() and '
      'diagnostics() are empty', () {
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
    ];
    final ws = doc.components.withComponent<WallParams>().toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    expect([for (final w in ws) doc.components.get<WallParams>(w)], walls);
    for (final w in ws) {
      expect(doc.tree[w], isA<GroupNode>());
      expect(doc.tree[w]!.parent, doc.rootHandle);
      expect((doc.tree[w]! as GroupNode).transform, Transform2.identity());
    }
    final [e1, e2, e3, e4, p1, p2, p3, p4, _] = ws;
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
    expect(os.first.value, greaterThan(ws.last.value),
        reason: 'the walls, then the openings');
    expect(doc.components.withComponent<BoxParams>(), isEmpty);
    final system = ParametricSystem(doc, parametricCatalog);
    expect(system.drift(), isEmpty);
    expect(system.diagnostics(), isEmpty,
        reason: 'no clamp, no overlap, no no-fit, no dangling reference');
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
}
