// The sample plans (audit section 9 `sample_plans_test` SPLIT, and demo_test
// D15's intent): the plans are exactly the hand-written placements below,
// built by `PlanController(build: ...)`; the units are numbered 1-3, 4-5,
// 6-7, 8-11 (Salon) and 1-6 (Teras) in build order; each plan opens clean
// with nothing to undo, and saves, loads and saves again byte for byte.
// The expected table is the old plans' (assets/plans/*.json at v0.7.2): the
// definition and the instance's translation, copied from the JSON, not
// derived from the code under test.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_kit_restaurant/jet_cad_2d_kit_restaurant.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;
import 'package:restaurant_demo/samples/place_tables.dart' show kSheetMin;
import 'package:restaurant_demo/samples/salon.dart';
import 'package:restaurant_demo/samples/teras.dart';

import 'support/demo_rig.dart';

/// (definition, translation x, translation y, label or null for a
/// non-unit), in build order.
typedef Placement = (String, double, double, String?);

const List<Placement> salon = [
  ('restaurant.table.rect.four@1', -5525, 1625, '1'),
  // Decided: tables 2 and 3 stand in the Garden, outside the south wall
  // (spec D14), at y -1250 mm from the sheet's lower-left corner.
  ('restaurant.table.rect.four@1', -4025, -7225, '2'),
  ('restaurant.table.rect.four@1', 2475, -7225, '3'),
  ('restaurant.table.round.six@1', -5900, -2125, '4'),
  ('restaurant.table.round.six@1', -2900, -2125, '5'),
  ('restaurant.booth.four@1', 2975, 2200, '6'),
  ('restaurant.booth.four@1', 2975, -500, '7'),
  ('restaurant.bar.stool@1', 85, -2790, '8'),
  ('restaurant.bar.stool@1', 885, -2790, '9'),
  ('restaurant.bar.stool@1', 1685, -2790, '10'),
  ('restaurant.bar.stool@1', 2485, -2790, '11'),
  ('restaurant.bar.counter@1', -25, -3750, null),
  ('restaurant.host.stand@1', 5875, -4175, null),
];

const List<Placement> teras = [
  ('restaurant.table.round.four@1', -5450, 725, '1'),
  ('restaurant.table.round.four@1', -2450, 725, '2'),
  ('restaurant.table.round.four@1', -5450, -2475, '3'),
  ('restaurant.table.round.four@1', -2450, -2475, '4'),
  ('restaurant.bar.table.high.two@1', 1435, 1110, '5'),
  ('restaurant.bar.table.high.two@1', 1435, -2090, '6'),
  ('restaurant.planter.round@1', -6725, 3950, null),
  ('restaurant.planter.round@1', 5775, 3950, null),
  ('restaurant.planter.long@1', -725, -4450, null),
];

/// The seats of each seated definition in the plans above.
const Map<String, int> capacities = {
  'restaurant.table.rect.four@1': 4,
  'restaurant.table.round.six@1': 6,
  'restaurant.booth.four@1': 4,
  'restaurant.bar.stool@1': 1,
  'restaurant.bar.table.high.two@1': 2,
  'restaurant.table.round.four@1': 4,
};

PlanController open(PlanBuild build) {
  final c =
      PlanController(kits: [architectureKit, restaurantKit], build: build);
  addTearDown(c.dispose);
  return c;
}

/// The root-level instances in draw order (ascending handle).
List<InstanceNode> instances(PlanController c) => [
      for (final n in c.document.tree.nodes)
        if (n is InstanceNode) n,
    ]..sort((a, b) => a.handle.value.compareTo(b.handle.value));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final (name, build, want) in [
    ('Salon', buildSalon, salon),
    ('Teras', buildTeras, teras),
  ]) {
    group(name, () {
      test('SP1 exactly the hand-written placements, in build order', () {
        final c = open(build);
        final got = [
          for (final i in instances(c))
            (
              definitionName(c, i.handle),
              i.transform.e,
              i.transform.f,
              i.transform.a,
              i.transform.b,
              i.transform.c,
              i.transform.d,
            ),
        ];
        expect(got, [
          for (final (d, x, y, _) in want) (d, x, y, 1.0, 0.0, 0.0, 1.0),
        ]);
      });

      test(
          'SP2 the units are numbered in build order, once each, with the '
          'right seats', () {
        final c = open(build);
        final labels = unitLabels(c);
        final wantLabels = [
          for (final (_, _, _, l) in want)
            if (l != null) l,
        ];
        expect([for (final (_, t) in labels) t], wantLabels);
        // The label of each unit sits on the placement that has that number.
        for (final (instance, text) in labels) {
          final i = want.indexWhere((p) => p.$4 == text);
          expect(instances(c).indexWhere((n) => n.handle == instance), i,
              reason: 'unit $text');
        }
        expect([for (final u in c.units) u.label], wantLabels);
        expect([
          for (final u in c.units) u.capacity
        ], [
          for (final (d, _, _, l) in want)
            if (l != null) capacities[d]!
        ]);
        expect({for (final u in c.units) u.kind}, {UnitKinds.table});
        expect(c.labelWarnings, isEmpty);
      });

      test('SP3 opens clean: nothing to undo, not dirty, no diagnostic', () {
        final c = open(build);
        expect(c.document.commands.canUndo, isFalse);
        expect(c.canUndo.value, isFalse);
        expect(c.dirty.value, isFalse);
        expect(c.diagnostics.value, isEmpty);
      });

      test('SP4 saves, loads and saves again byte for byte', () {
        final c = open(build);
        final text = c.save();
        final again =
            PlanController(kits: [architectureKit, restaurantKit], json: text);
        addTearDown(again.dispose);
        expect(again.save(), text);
        expect([for (final u in again.units) u.label],
            [for (final u in c.units) u.label]);
        expect(again.dirty.value, isFalse);
      });
    });
  }

  group('Salon room', () {
    List<WallParams> walls(PlanController c) => [
          for (final h in c.document.components.withComponent<WallParams>())
            c.document.components.get<WallParams>(h)!,
        ];
    List<OpeningParams> openings(PlanController c) => [
          for (final h in c.document.components.withComponent<OpeningParams>())
            c.document.components.get<OpeningParams>(h)!,
        ];

    test('SW1 four walls, one door, two windows; the Teras has none', () {
      final c = open(buildSalon);
      expect(walls(c), hasLength(4));
      expect(
          [for (final o in openings(c)) o.kind],
          unorderedEquals(
              [OpeningKind.door, OpeningKind.window, OpeningKind.window]));
      // The door in a long wall, the windows in the opposite one.
      final hosts = {
        for (final h in c.document.components.withComponent<OpeningParams>())
          c.document.components.get<OpeningParams>(h)!.kind: [
            for (final h2
                in c.document.components.withComponent<OpeningParams>())
              if (c.document.components.get<OpeningParams>(h2)!.kind ==
                  c.document.components.get<OpeningParams>(h)!.kind)
                c.document.components.get<OpeningParams>(h2)!.host
          ],
      };
      final door = hosts[OpeningKind.door]!.single;
      final win = hosts[OpeningKind.window]!;
      expect(win.toSet(), hasLength(1), reason: 'both windows on one wall');
      final dw = c.document.components.get<WallParams>(door)!;
      final ww = c.document.components.get<WallParams>(win.first)!;
      expect(dw.sy, dw.ey, reason: 'the door wall runs west-east');
      expect(ww.sy, ww.ey);
      expect(dw.sy, lessThan(ww.sy), reason: 'opposite walls');
      expect((dw.ex - dw.sx).abs(), greaterThan(10000), reason: 'a long wall');
      final t = open(buildTeras);
      expect(walls(t), isEmpty);
      expect(openings(t), isEmpty);
    });

    test(
        'SW2 every table lies inside the room, 1200 mm clear of its inner '
        'faces; the numbers are 1-11 and the walls come first', () {
      final c = open(buildSalon);
      final w = walls(c);
      final half = w.first.thickness / 2;
      final left = w
              .map((e) => e.sx < e.ex ? e.sx : e.ex)
              .reduce((a, b) => a < b ? a : b) +
          half;
      final right = w
              .map((e) => e.sx > e.ex ? e.sx : e.ex)
              .reduce((a, b) => a > b ? a : b) -
          half;
      final bottom = w
              .map((e) => e.sy < e.ey ? e.sy : e.ey)
              .reduce((a, b) => a < b ? a : b) +
          half;
      final top = w
              .map((e) => e.sy > e.ey ? e.sy : e.ey)
              .reduce((a, b) => a > b ? a : b) -
          half;
      // Decided: tables 2 and 3 stand in the Garden, outside the south wall
      // (spec D14): they lie between the wall's outer face and the Garden's
      // south separator, clear of both by 100 mm, and inside the side walls'
      // lines; every other table keeps the room's 1200 mm.
      final garden = {unitInstance(c, '2')!, unitInstance(c, '3')!};
      final gardenSouth = kSheetMin.y + kGardenSouth;
      final gardenNorth = bottom - 2 * half;
      var minMargin = double.infinity;
      for (final i in instances(c)) {
        final b = boxOfDefinition(c.document, i.definition)!;
        for (final (x, y) in [(b.left, b.front), (b.right, b.back)]) {
          final p = i.transform.transformPoint(Vector2(x, y));
          if (garden.contains(i.handle)) {
            for (final m in [
              p.x - left,
              right - p.x,
              p.y - gardenSouth,
              gardenNorth - p.y,
            ]) {
              expect(m, greaterThanOrEqualTo(100),
                  reason: '${definitionName(c, i.handle)} at ${p.x},${p.y}');
            }
            continue;
          }
          for (final m in [p.x - left, right - p.x, p.y - bottom, top - p.y]) {
            if (m < minMargin) minMargin = m;
            expect(m, greaterThan(0),
                reason: '${definitionName(c, i.handle)} at ${p.x},${p.y}');
          }
        }
      }
      expect(minMargin, greaterThanOrEqualTo(1200));
      expect([for (final u in c.units) u.label],
          [for (var n = 1; n <= 11; n++) '$n']);
      final firstWall = c.document.components.withComponent<WallParams>().first;
      expect(firstWall.value, lessThan(instances(c).first.handle.value));
    });

    test('SW3 the room, walls and all, lies inside the sheet', () {
      final c = open(buildSalon);
      final page =
          c.document.components.get<PageComponent>(c.document.rootHandle)!;
      final sheetW = page.effectiveWidthMm * page.scaleDenominator;
      final sheetH = page.effectiveHeightMm * page.scaleDenominator;
      final w = walls(c);
      final half = w.first.thickness / 2;
      final xs = [
        for (final e in w) ...[e.sx, e.ex]
      ];
      final ys = [
        for (final e in w) ...[e.sy, e.ey]
      ];
      final room = (
        xs.reduce(math.min) - half,
        xs.reduce(math.max) + half,
        ys.reduce(math.min) - half,
        ys.reduce(math.max) + half,
      );
      expect(room.$1, greaterThanOrEqualTo(page.originX));
      expect(room.$2, lessThanOrEqualTo(page.originX + sheetW));
      expect(room.$3, greaterThanOrEqualTo(page.originY));
      expect(room.$4, lessThanOrEqualTo(page.originY + sheetH));
      // The sheet is centred where the default one is, so the placements
      // (measured from kSheetMin) are not moved.
      expect(page.originX + sheetW / 2, 0);
      expect(page.originY + sheetH / 2, 0);
    });
  });
}
