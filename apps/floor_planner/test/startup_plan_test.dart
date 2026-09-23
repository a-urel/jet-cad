import 'dart:math' as math;
import 'dart:ui' show Size;

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
      'SP1 the furniture is eight filled regions with the furniture '
      'outline', () {
    final doc = startupPlan(measurer);
    final boundaries = <Handle>[];
    for (final slot in doc.entities.liveSlots) {
      final h = doc.entities.handleAt(slot);
      if (doc.fills.fillsOf(h).isNotEmpty) boundaries.add(h);
    }
    expect(boundaries, hasLength(8));
    for (final b in boundaries) {
      final r = doc.entities.read(doc.entities.slotOf(b)!);
      expect(r.color, const TrueColor(0x8A6D3B));
      expect(r.lineweight, 25);
      final fill = doc.fills.fillsOf(b).single;
      expect(
          doc.entities.read(doc.entities.slotOf(fill)!).color, kDraftFillColor);
    }
    expect(doc.entities.liveCount, 509, reason: 'Ruling 05-12: 523 − 14');
  });

  test('SP2 every fill draws over every floor-finish line (M-05r)', () {
    final doc = startupPlan(measurer);
    var maxFinish = 0, minFill = 1 << 62;
    for (final slot in doc.entities.liveSlots) {
      final r = doc.entities.read(slot);
      if (r.kind == EntityKind.fill && r.handle.value < minFill) {
        minFill = r.handle.value;
      }
      if (r.kind == EntityKind.line &&
          r.color == const TrueColor(0xBBBBBB) &&
          r.handle.value > maxFinish) {
        maxFinish = r.handle.value;
      }
    }
    expect(maxFinish, greaterThan(0));
    expect(minFill, greaterThan(maxFinish));
  });

  test(
      'SP3 no door leaf or swing lies under a furniture fill (Ruling F-1, '
      'M-05aa)', () {
    final doc = startupPlan(measurer);

    // Every furniture boundary (SP1's eight), as a polygon or a circle.
    final polygons = <List<Vector2>>[];
    final circles = <(Vector2, double)>[];
    for (final slot in doc.entities.liveSlots) {
      final h = doc.entities.handleAt(slot);
      if (doc.fills.fillsOf(h).isEmpty) continue;
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
    for (final slot in doc.entities.liveSlots) {
      final h = doc.entities.handleAt(slot);
      if (doc.fills.fillsOf(h).isEmpty) continue;
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
}
