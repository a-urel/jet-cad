// The colour picker's plan (jet_cad_floor_plan/test/colors/
// color_picker_test.dart:76-113) as a plan file (3a Task 27): the two-room
// rectangle at the corpus far origin turned 23 degrees, every wall and the
// separator in its own rotated group, a separator at x = 6,250.5, room A
// `Kitchen` in a group turned 0.61 rad and room B `Room 2` at the identity,
// the page's grid hidden (today's replaced the document's whole page with
// `PageComponent(gridVisible: false)`; the plan file's page is replaced the
// same way).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import 'plans.dart';

/// The plan, opened: its controller (disposed at tear-down) and handles.
typedef Rooms = ({
  PlanController c,
  Plan plan,
  DraftDocument doc,
  Handle a,
  Handle b,
  Handle sep,
  Handle w
});

/// The two-room rectangle at [corpusGroups], with a separator at x = 6,250.5
/// and two rooms, `Kitchen` (A, in a group of its own turned 0.61 rad) and
/// `Room 2` (B, at the identity). The page's grid is hidden, so a pixel of
/// bare floor is the surround. Saved and opened: no history.
Rooms roomsPlan() {
  late Plan plan;
  late Handle a, b;
  final json = planWith((d) {
    plan = buildPlan(d, twoRoomWalls,
        seps: const [(6250.5, 100, 6250.5, 3900)], place: corpusGroups);
    attachPage(d, PageComponent(gridVisible: false));
    final g =
        Transform2.translation(plan.at(1400, 1900).x, plan.at(1400, 1900).y)
            .multiply(Transform2.rotation(0.61));
    a = addRoom(d, plan.at(1500.25, 2000.5), 'Kitchen', at: g);
    b = addRoom(d, plan.at(4700.75, 1900.25), 'Room 2');
  });
  final c = architectureController(json: json);
  addTearDown(c.dispose);
  return (
    c: c,
    plan: plan,
    doc: c.document,
    a: a,
    b: b,
    sep: plan.seps.single,
    w: plan.walls[4]
  );
}
