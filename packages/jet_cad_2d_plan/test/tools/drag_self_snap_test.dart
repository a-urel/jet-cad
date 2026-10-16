// 4a spec R2 O1 (plan Task 4): plan.select's body drag must not object-snap
// to the dragged object's own pre-drag geometry (the 3a results note, "For
// the human" 3: a press released 30 mm from the unit's own old right-edge
// midpoint snapped there). Fixtures: a sloped line off the origin, a
// turned camera (support/tool_events.dart), page grid snap off so the
// result is the pointer's offset exactly, the release 30 mm from the
// object's own old midpoint and off the old line.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/tool_events.dart';

List<double> coordsOf(DraftDocument d, Handle line) {
  final e = d.entities;
  return d.geometry.read(e.geomIndexAt(e.slotOf(line)!)).coords.toList();
}

void main() {
  test(
      'O1 a line dragged by its body releases 30 mm from its own old '
      'midpoint: it moves by the pointer\'s offset, not onto the midpoint',
      () async {
    final c = PlanController(kits: const []);
    addTearDown(c.dispose);
    useTestCamera(c);
    final doc = c.document;
    final line =
        drawLine(c, Vector2(4100.5, -1250.25), Vector2(4700.75, -980.5));
    // No grid in the way: the result is the pointer's offset exactly.
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle,
        doc.components
            .get<PageComponent>(doc.rootHandle)!
            .copyWith(snapToGrid: false)));
    // PageNotifier follows the document's change stream, a microtask late.
    await pumpEventQueue();
    expect(c.page.value!.snapToGrid, isFalse, reason: 'premise: no grid');
    final before = coordsOf(doc, line);
    final mid =
        Vector2((before[0] + before[2]) / 2, (before[1] + before[3]) / 2);
    // The press: a point on the line, a fifth of the way along (far from
    // every snap of the line itself).
    final press = Vector2(before[0] + 0.2 * (before[2] - before[0]),
        before[1] + 0.2 * (before[3] - before[1]));
    // The release: 30 mm from the old midpoint along the old line, so the
    // old midpoint is the only snap in reach that is not the pointer.
    final along = Vector2(before[2] - before[0], before[3] - before[1])
      ..normalize();
    final release = mid + along * 30;
    expect((release - mid).length, closeTo(30, 1e-9), reason: 'premise');
    c.selectTool('plan.select');
    tapAt(c, press);
    expect(c.selection.keys, hasLength(1), reason: 'premise: picked');
    dragFrom(c, press, release);
    final after = coordsOf(doc, line);
    final shift = release - press;
    for (var i = 0; i < 4; i++) {
      expect(
          after[i], closeTo(before[i] + (i.isEven ? shift.x : shift.y), 1e-6),
          reason: 'coord $i');
    }
  });
}
