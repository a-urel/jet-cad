// Spec 09c D2, plan 09c-1 Task 2: the symbol's local box. Fixtures avoid the
// degenerate cases (P-2): the catalog's boxes all start at (0, 0) (its frame,
// F-1), so the box rules are also pinned by leaves far from the origin, with
// every side of a box set by a different kind of leaf, by an interior
// polyline vertex, by an arc's axis extreme and by an arc's end point; arcs
// cross each axis separately, none, from a negative start and clockwise.
import 'dart:io';
import 'dart:math' as math;

import 'package:jet_cad_floor_plan/src/parametric/catalog.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_box.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_component.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_library.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/symbol_fixtures.dart';

SymbolLibrary assetLibrary() => SymbolLibrary.decode(
    File('assets/library/furniture.jetlib').readAsBytesSync());

SymbolEntry entryIn(SymbolLibrary lib, String key) =>
    lib.entries.firstWhere((e) => e.key == key);

/// Far from the origin, as the plan's P-2 asks.
const double cx = 1e5 + 37.5, cy = -7e4 + 12.25, r = 410.0;

(EntityKind, GeometryPayload) arc(double start, double sweep) =>
    (EntityKind.arc, arcPayload(Vector2(cx, cy), r, start, sweep));

SymbolBox boxOfArc(double start, double sweep) =>
    boxOfLeaves([arc(start, sweep)])!;

/// The box of an arc from [start] through [sweep] by its end points only.
({double minX, double maxX, double minY, double maxY}) ends(
    double start, double sweep) {
  final xs = [cx + r * math.cos(start), cx + r * math.cos(start + sweep)];
  final ys = [cy + r * math.sin(start), cy + r * math.sin(start + sweep)];
  return (
    minX: math.min(xs[0], xs[1]),
    maxX: math.max(xs[0], xs[1]),
    minY: math.min(ys[0], ys[1]),
    maxY: math.max(ys[0], ys[1]),
  );
}

Matcher near(double v) => closeTo(v, 1e-9);

DraftDocument target() {
  final doc = DraftDocument.empty();
  registerAppComponents(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  return doc;
}

Handle definitionOf(DraftDocument doc, String key) {
  for (final h in doc.components.withComponent<SymbolComponent>()) {
    if (doc.components.get<SymbolComponent>(h)!.key == key &&
        doc.tree.definition(h) != null) {
      return h;
    }
  }
  throw StateError('no $key');
}

/// Every catalog symbol's box, derived by hand from `furniture_catalog.dart`
/// (left, right, front, back). The dining sets' boxes are set by their
/// chairs (350 mm beyond the table edge), the round table's too since 14s
/// (its Ø 1100 top centred at 900, 900: 900 − 550 − 350 = 0 and
/// 900 + 550 + 350 = 1800); the toilet's front only by its bowl's axis
/// extreme; the office chair's only by circles.
const Map<String, (double, double, double, double)> catalogBoxes = {
  'dining.table.square.two': (0, 800, 0, 1500),
  'dining.table.square.four': (0, 1600, 0, 1600),
  'dining.table.rect.four': (0, 1400, 0, 1500),
  'dining.table.rect.six': (0, 2500, 0, 1600),
  'dining.table.round': (0, 1800, 0, 1800),
  'dining.chair': (0, 450, 0, 450),
  'dining.bench': (0, 1200, 0, 350),
  'kitchen.base.300': (0, 300, 0, 600),
  'kitchen.base.400': (0, 400, 0, 600),
  'kitchen.base.600': (0, 600, 0, 600),
  'kitchen.base.800': (0, 800, 0, 600),
  'kitchen.sink': (0, 1200, 0, 600),
  'kitchen.hob': (0, 600, 0, 520),
  'kitchen.fridge': (0, 600, 0, 650),
  'kitchen.dishwasher': (0, 600, 0, 600),
  'kitchen.washer': (0, 600, 0, 600),
  'kitchen.island': (0, 1800, 0, 900),
  'bed.double.1400': (0, 1400, 0, 2000),
  'bed.double': (0, 1600, 0, 2000),
  'bed.double.1800': (0, 1800, 0, 2000),
  'bed.single.800': (0, 800, 0, 2000),
  'bed.single': (0, 900, 0, 2000),
  'bed.single.1000': (0, 1000, 0, 2000),
  'bed.nightstand': (0, 450, 0, 400),
  'bed.wardrobe.1200': (0, 1200, 0, 600),
  'bed.wardrobe': (0, 1800, 0, 600),
  'bed.wardrobe.2400': (0, 2400, 0, 600),
  'sofa.two': (0, 1500, 0, 900),
  'sofa.three': (0, 2000, 0, 900),
  'armchair': (0, 850, 0, 850),
  'table.coffee': (0, 1100, 0, 600),
  'tv.unit': (0, 1600, 0, 450),
  'bath.toilet': (0, 400, 0, 700),
  'bath.washbasin': (0, 600, 0, 450),
  'bath.tub': (0, 1700, 0, 750),
  'bath.shower': (0, 900, 0, 900),
  'office.desk.1200': (0, 1200, 0, 700),
  'office.desk': (0, 1400, 0, 700),
  'office.desk.1600': (0, 1600, 0, 700),
  'office.chair': (0, 600, 0, 600),
  'office.bookshelf': (0, 900, 0, 300),
};

SymbolBox boxOf((double, double, double, double) b) =>
    SymbolBox(left: b.$1, right: b.$2, front: b.$3, back: b.$4);

void main() {
  group('SymbolBox', () {
    test('width, depth and the back-centre of an off-origin box', () {
      const b =
          SymbolBox(left: -310.5, right: 1240.25, front: -75, back: 905.5);
      expect(b.width, 1550.75);
      expect(b.depth, 980.5);
      expect(b.backCentre, Vector2(464.875, 905.5));
    });

    test('equality is exact on all four sides', () {
      const b =
          SymbolBox(left: -310.5, right: 1240.25, front: -75, back: 905.5);
      // A box computed from a leaf: equal values, a distinct object (two
      // equal `const` boxes would be one canonical object).
      final computed = boxOfLeaves([
        (
          EntityKind.line,
          linePayload(Vector2(1240.25, 905.5), Vector2(-310.5, -75))
        )
      ])!;
      expect(identical(computed, b), isFalse);
      expect(computed, b);
      expect(computed.hashCode, b.hashCode);
      for (final other in const [
        SymbolBox(left: -310.4, right: 1240.25, front: -75, back: 905.5),
        SymbolBox(left: -310.5, right: 1240.3, front: -75, back: 905.5),
        SymbolBox(left: -310.5, right: 1240.25, front: -75.1, back: 905.5),
        SymbolBox(left: -310.5, right: 1240.25, front: -75, back: 905.6),
      ]) {
        expect(b == other, isFalse, reason: '$other');
      }
    });
  });

  group('boxOfLeaves', () {
    test('each side set by a different kind of leaf, far from the origin', () {
      // left: a circle's centre − r; right: a polyline's interior vertex;
      // front: an arc's axis extreme (3π/2); back: a line's second end.
      final box = boxOfLeaves([
        (
          EntityKind.line,
          linePayload(
              Vector2(1e5 + 100, -7e4 + 200), Vector2(1e5 + 300, -7e4 + 950))
        ),
        (
          EntityKind.polyline,
          polylinePayload([
            Vector2(1e5 + 50, -7e4 + 100),
            Vector2(1e5 + 1200, -7e4 + 400),
            Vector2(1e5 + 60, -7e4 + 700),
          ])
        ),
        (EntityKind.circle, circlePayload(Vector2(1e5 - 20, -7e4 + 300), 180)),
        (
          EntityKind.arc,
          arcPayload(Vector2(1e5 + 500, -7e4 + 100), 250, math.pi + 0.3, 2.5)
        ),
      ])!;
      expect(
          box,
          const SymbolBox(
              left: 1e5 - 200,
              right: 1e5 + 1200,
              front: -7e4 - 150,
              back: -7e4 + 950));
    });

    test('a circle is its centre ± r on every side', () {
      final box = boxOfLeaves([
        (EntityKind.circle, circlePayload(Vector2(-2400.5, 3100.25), 72.5))
      ])!;
      expect(
          box,
          const SymbolBox(
              left: -2473, right: -2328, front: 3027.75, back: 3172.75));
    });

    test('a closed polyline counts every vertex once, a line both ends', () {
      final box = boxOfLeaves([
        (
          EntityKind.polyline,
          polylinePayload([
            Vector2(-50, 20),
            Vector2(10, -40),
            Vector2(70, 15),
            Vector2(5, 90),
          ], closed: true)
        ),
        (EntityKind.line, linePayload(Vector2(-10, 30), Vector2(95, 10))),
      ])!;
      expect(box, const SymbolBox(left: -50, right: 95, front: -40, back: 90));
    });

    test('no leaf has no box; a leaf of another kind draws nothing', () {
      expect(boxOfLeaves(const []), isNull);
      expect(
          boxOfLeaves([
            (
              EntityKind.point,
              linePayload(Vector2(9e4, 9e4), Vector2(9e4, 9e4))
            )
          ]),
          isNull);
      final box = boxOfLeaves([
        (EntityKind.circle, circlePayload(Vector2(-2400.5, 3100.25), 72.5)),
        (EntityKind.point, polylinePayload([Vector2(9e4, -9e4)])),
        (EntityKind.text, textPayload(Vector2(-9e4, 9e4), 250)),
      ])!;
      expect(
          box,
          const SymbolBox(
              left: -2473, right: -2328, front: 3027.75, back: 3172.75));
    });
  });

  group('an arc by its true extents', () {
    test('a sweep that crosses 0 rad only', () {
      const s = -math.pi / 6, w = math.pi / 3;
      final b = boxOfArc(s, w), e = ends(s, w);
      expect(b.right, cx + r);
      expect(b.left, near(e.minX));
      expect(b.front, near(e.minY));
      expect(b.back, near(e.maxY));
    });

    test('a sweep that crosses π/2 only', () {
      const s = math.pi / 3, w = math.pi / 3;
      final b = boxOfArc(s, w), e = ends(s, w);
      expect(b.back, cy + r);
      expect(b.left, near(e.minX));
      expect(b.right, near(e.maxX));
      expect(b.front, near(e.minY));
    });

    test('a sweep that crosses π only', () {
      const s = 5 * math.pi / 6, w = math.pi / 3;
      final b = boxOfArc(s, w), e = ends(s, w);
      expect(b.left, cx - r);
      expect(b.right, near(e.maxX));
      expect(b.front, near(e.minY));
      expect(b.back, near(e.maxY));
    });

    test('a sweep that crosses 3π/2 only', () {
      const s = 4 * math.pi / 3, w = math.pi / 3;
      final b = boxOfArc(s, w), e = ends(s, w);
      expect(b.front, cy - r);
      expect(b.left, near(e.minX));
      expect(b.right, near(e.maxX));
      expect(b.back, near(e.maxY));
    });

    test('a sweep that crosses no axis is its end points', () {
      const s = math.pi / 12, w = math.pi / 3;
      final b = boxOfArc(s, w), e = ends(s, w);
      expect(b.left, near(e.minX));
      expect(b.right, near(e.maxX));
      expect(b.front, near(e.minY));
      expect(b.back, near(e.maxY));
      expect(b.right, lessThan(cx + r - 1));
      expect(b.back, lessThan(cy + r - 1));
    });

    test('a negative start (−120° through 90°) crosses −π/2', () {
      const s = -2 * math.pi / 3, w = math.pi / 2;
      final b = boxOfArc(s, w), e = ends(s, w);
      expect(b.front, cy - r);
      expect(b.left, near(cx - r / 2));
      expect(b.right, near(cx + r * math.cos(math.pi / 6)));
      expect(b.back, near(cy - r / 2));
      expect(b.left, near(e.minX));
    });

    test('a start past 2π crosses π', () {
      const s = 2 * math.pi + 5 * math.pi / 6, w = math.pi / 3;
      final b = boxOfArc(s, w);
      expect(b.left, cx - r);
      expect(b.back, near(cy + r / 2));
      expect(b.front, near(cy - r / 2));
    });

    test('a clockwise sweep from π/3 back through 0 to −π/6', () {
      const s = math.pi / 3, w = -math.pi / 2;
      final b = boxOfArc(s, w), e = ends(s, w);
      expect(b.right, cx + r);
      expect(b.back, near(e.maxY));
      expect(b.front, near(e.minY));
      expect(b.left, near(e.minX));
      expect(b.back, lessThan(cy + r - 1));
    });

    test('a full turn is the whole circle', () {
      final b = boxOfArc(0.7, 2 * math.pi);
      expect(b,
          SymbolBox(left: cx - r, right: cx + r, front: cy - r, back: cy + r));
    });
  });

  group('library entries', () {
    test('every catalog symbol\'s box equals its hand-derived literal', () {
      final lib = assetLibrary();
      expect({for (final e in lib.entries) e.key}, catalogBoxes.keys.toSet(),
          reason: 'a new catalog symbol needs its literal here');
      for (final e in lib.entries) {
        expect(boxOfEntry(e), boxOf(catalogBoxes[e.key]!), reason: e.key);
      }
    });

    test(
        'the toilet\'s front is its bowl\'s axis extreme, its back the '
        'cistern', () {
      final toilet = entryIn(assetLibrary(), 'bath.toilet');
      final box = boxOfEntry(toilet)!;
      expect(box, const SymbolBox(left: 0, right: 400, front: 0, back: 700));
      expect(box.width, 400);
      expect(box.depth, 700);
      expect(box.backCentre, Vector2(200, 700));
    });

    test('the off-centre fixtures: back and left from an arc', () {
      final lib = SymbolLibrary.decode(bytesOf(buildValidLibrary()));
      // Sofa: the arc (900, 900) r 250 from 0.5 through 1.75 rad crosses
      // π/2, so its back is 1150, beyond the polyline's 950.
      expect(boxOfEntry(entryIn(lib, 'sofa.three')),
          const SymbolBox(left: 120, right: 1680, front: 340, back: 1150));
      // Armchair: the arc (500, 500) r 300 from 0.25 through 2.5 rad sets
      // the left and right by its end points and the back by π/2; the
      // circle (510, 480) r 120 sets the front.
      final a = boxOfEntry(entryIn(lib, 'armchair.single'))!;
      expect(a.left, near(500 + 300 * math.cos(2.75)));
      expect(a.right, near(500 + 300 * math.cos(0.25)));
      expect(a.front, 360);
      expect(a.back, 800);
      expect(a.backCentre.x, near((a.left + a.right) / 2));
      expect(a.backCentre.y, 800);
      expect(boxOfEntry(entryIn(lib, 'nightstand.single')),
          const SymbolBox(left: 50, right: 450, front: 60, back: 410));
    });

    test('memoised per entry: the same object on every call', () {
      final lib = assetLibrary();
      final toilet = entryIn(lib, 'bath.toilet');
      final tub = entryIn(lib, 'bath.tub');
      expect(identical(boxOfEntry(toilet), boxOfEntry(toilet)), isTrue);
      expect(boxOfEntry(tub), isNot(boxOfEntry(toilet)));
    });
  });

  group('boxOfDefinition', () {
    test('a placed definition gives the same box as its entry', () {
      final lib = assetLibrary();
      final doc = target();
      final keys = ['bath.toilet', 'kitchen.hob', 'bath.tub', 'office.chair'];
      // Four definitions in one document (each box must read only its own
      // leaves), placed far from the origin, turned and mirrored or not:
      // the box is in the definition's coordinates, whatever the instance.
      for (var i = 0; i < keys.length; i++) {
        doc.commands.execute(placeSymbol(doc, entryIn(lib, keys[i]),
            at: Vector2(1e5 + 250.0 * i, -7e4 - 125.0 * i),
            quarterTurns: i + 1,
            mirrored: i.isOdd));
      }
      for (final key in keys) {
        expect(boxOfDefinition(doc, definitionOf(doc, key)),
            boxOfEntry(entryIn(lib, key)),
            reason: key);
      }
    });

    test('reads the live leaves: a removed leaf no longer counts', () {
      final lib = assetLibrary();
      final doc = target();
      doc.commands.execute(placeSymbol(doc, entryIn(lib, 'bath.toilet'),
          at: Vector2(1e5, -7e4), quarterTurns: 3, mirrored: true));
      final def = definitionOf(doc, 'bath.toilet');
      expect(boxOfDefinition(doc, def),
          const SymbolBox(left: 0, right: 400, front: 0, back: 700));
      // The cistern (the first leaf) goes; the lines reach y = 500.
      final cistern = [
        for (final slot in doc.entities.liveSlots)
          if (doc.entities.ownerAt(slot) == def) doc.entities.handleAt(slot)
      ].reduce((a, b) => a.value < b.value ? a : b);
      doc.commands.execute(RemoveEntityCommand(cistern));
      expect(boxOfDefinition(doc, def),
          const SymbolBox(left: 0, right: 400, front: 0, back: 500));
      doc.commands.undo();
      expect(boxOfDefinition(doc, def),
          const SymbolBox(left: 0, right: 400, front: 0, back: 700));
    });

    test(
        'not a definition (the root, a leaf, nothing), or a definition '
        'without leaves: no box', () {
      final doc = target();
      doc.commands.execute(AddDefinitionCommand(Definition(
          handle: const Handle(0x7A1),
          name: 'empty',
          basePoint: Vector2(-40, 75),
          children: const [])));
      // The root owns a drawn line and a circle: it is not a definition.
      doc.commands.execute(CompoundCommand([
        AddEntityCommand(
            record: leafRecord(0x7B0, doc.rootHandle, EntityKind.line),
            payload: linePayload(Vector2(1e5, -7e4), Vector2(1e5 + 900, -7e4))),
        AddEntityCommand(
            record: leafRecord(0x7B1, doc.rootHandle, EntityKind.circle),
            payload: circlePayload(Vector2(-310, 925), 60)),
      ], label: 'Model space'));
      expect(boxOfDefinition(doc, const Handle(0x7A1)), isNull);
      expect(boxOfDefinition(doc, const Handle(0x7A2)), isNull);
      expect(boxOfDefinition(doc, doc.rootHandle), isNull);
      expect(boxOfDefinition(doc, const Handle(0x7B0)), isNull);
    });
  });
}
