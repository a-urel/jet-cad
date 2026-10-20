// The room's own name through the kit contract (PlanType.name).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit_architecture/src/room/room_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/room_fixture.dart';

void main() {
  test('RN1 roomPlanType.nameOf is the room\'s name', () {
    final plan = buildPlan(const [
      W(12000, 7000, 18000, 7000, 200),
      W(18000, 7000, 18000, 11000, 200),
      W(18000, 11000, 12000, 11000, 200),
      W(12000, 11000, 12000, 7000, 200),
    ]);
    addTearDown(plan.doc.dispose);
    final room = addRoom(plan.doc, Vector2(14500.5, 9000.25), 'VIP');
    expect(roomPlanType.hasName, isTrue);
    expect(roomPlanType.nameOf(plan.doc, room), 'VIP');
  });
}
