// Task 10c: the plan's sections as a host lists them (`sectionDetails`) and
// an object's own name in `PlanObjectDetail.label`. Zones sit tens of metres
// off the origin, turned and mirrored; the rail is a type without an area
// or a name.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart' show planText;
import '../support/object_kit.dart';
import '../support/unit_fixtures.dart';
import '../support/zone_kit.dart';

late Handle garden, salon, vip, nameless, empty, rail;

String plan() => planText([fxKit(), zoneKit, objectKit], (d) {
      // Created Garden first: draw order is the handle order, not the names'.
      garden = addZone(
          d, 5000, 5000, Transform2(1, 0, 0, -1, 52000, -30000), 'Garden');
      salon = addZone(
          d,
          12000,
          8000,
          Transform2.translation(30000, -40000)
              .multiply(Transform2.rotation(20 * math.pi / 180)),
          'Salon');
      vip =
          addZone(d, 3000, 2000, Transform2.translation(33000, -38000), 'VIP');
      nameless = addZone(d, 2000, 2000, Transform2.translation(60000, -10000));
      empty =
          addZone(d, 0, 2000, Transform2.translation(70000, -10000), 'Terrace');
      rail =
          addTurned(d, const RailComponent(3000), Vector2(47000, -40000), 0.7);
      d.commands.clearHistory();
    });

PlanController controller() {
  final c = PlanController(kits: [fxKit(), zoneKit, objectKit], json: plan());
  addTearDown(c.dispose);
  return c;
}

PlanObjectRef ref(Handle h) => PlanObjectRef.of(h);

void main() {
  testWidgets(
      'SD1 sectionDetails lists every area object in draw order, with and '
      'without data', (tester) async {
    final c = controller();
    expect(c.setObjectData(ref(vip), const {'id': 'v'}), isTrue);
    final all = c.sectionDetails;
    expect([for (final d in all) d.ref],
        [ref(garden), ref(salon), ref(vip), ref(nameless), ref(empty)]);
    // The rail has no area: not a section. VIP carries data, the rest none.
    expect(all.any((d) => d.ref == ref(rail)), isFalse);
    expect(
        [for (final d in all) d.data.isEmpty], [true, true, false, true, true]);
    expect(all[2].data, {'id': 'v'});
    // objectDetails still lists only the data-carrying one.
    expect([for (final d in c.objectDetails) d.ref], [ref(vip)]);
    // The list is unmodifiable and read at call time.
    expect(() => all.add(all.first), throwsUnsupportedError);
    expect(c.setObjectData(ref(garden), const {'id': 'g'}), isTrue);
    expect(c.sectionDetails[0].data, {'id': 'g'});
  });

  testWidgets(
      'SD2 a type object\'s detail label is its name; a type without name '
      'keeps its title word', (tester) async {
    final c = controller();
    expect(c.objectDetailOf(ref(salon))!.label, 'Salon');
    expect(c.objectDetailOf(ref(garden))!.label, 'Garden');
    // An empty name falls back to the title word.
    expect(c.objectDetailOf(ref(nameless))!.label, 'Zone');
    // A type without a name capability.
    expect(c.objectDetailOf(ref(rail))!.label, 'Rail');
    expect([for (final d in c.sectionDetails) d.label],
        ['Garden', 'Salon', 'VIP', 'Zone', 'Terrace']);
  });
}
