// F-7 (Slice 4's results, found not fixed): a symbol tagged `against-wall`
// turned to the wall it was placed or moved against under `rotate: false`,
// since the wall's attachment set its turn. Through `FloorPlanView` on the
// editor fixture under `editorCamera()`: a base unit 600 (tagged, its base
// point its front centre) placed against the east wall's inner face (x
// 25,750, which takes a quarter turn) and the north wall's (y 16,750, which
// takes none), and one placed free in the room, then dragged so its back
// meets the east face. Under `full` each east attachment turns (the
// control); under `rotate: false` none does, while the north face, which
// keeps the unit's turn, still attaches.
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectTool;
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'editor_tools_review_test.dart'
    show activeTool, drag, gridSnapOff, place;
import 'editor_tools_test.dart' as t;

typedef Caps = FloorPlanEditorCapabilities;

/// [m]'s linear part.
List<double> linearOf(Transform2 m) => [m.a, m.b, m.c, m.d];

const List<double> unturned = [1.0, 0.0, 0.0, 1.0];

void main() {
  for (final rotate in [true, false]) {
    testWidgets(
        'F-7 rotate: $rotate: a base unit placed against the east face '
        '${rotate ? 'turns' : 'does not turn'}; against the north face it '
        'attaches unturned; one dragged to the east face '
        '${rotate ? 'turns' : 'keeps its turn'}', (tester) async {
      final h =
          await t.mountEditor(tester, caps: Caps.full.copyWith(rotate: rotate));
      final c = h.c;
      final d = c.activeDocument;
      gridSnapOff(d);
      await t.openSymbols(tester, c);
      await tester.enterText(t.byKey('symbol-search'), 'base unit 600');
      await tester.pump();
      await t.arm(tester, 'kitchen.base.600');

      // 20 mm west of the east wall's inner face, north of its window
      // (y 13,300..15,100).
      final east = await place(tester, c, Vector2(25730, 16200));
      if (rotate) {
        expect(east.transform.a, closeTo(0, 1e-9),
            reason: 'premise: the east face turns the unit a quarter turn');
      } else {
        expect(linearOf(east.transform), unturned,
            reason: 'the east face may not turn it');
      }

      // 20 mm below the north wall's inner face: this face keeps the turn.
      final north = await place(tester, c, Vector2(24200, 16730));
      expect(linearOf(north.transform), unturned);
      expect(north.transform.f, 16750 - 600,
          reason: 'attached: its back on the face, its front 600 below');

      // Mirrored (M), against the same face east of it: the face still
      // takes it, mirrored and unturned; M again for the rest.
      await t.press(tester, LogicalKeyboardKey.keyM);
      final mirrored = await place(tester, c, Vector2(24900, 16730));
      expect(linearOf(mirrored.transform), [-1.0, 0.0, 0.0, 1.0]);
      expect(mirrored.transform.f, 16750 - 600, reason: 'attached');
      await t.press(tester, LogicalKeyboardKey.keyM);

      // Free in the room: x 24,700..25,300, y 13,700..14,300.
      final free = await place(tester, c, Vector2(25000, 13700));
      expect(linearOf(free.transform), unturned, reason: 'premise');
      // Its base point, the front centre (300, 0), at the click.
      final base = free.transform.transformPoint(Vector2(300, 0));
      expect((base.x, base.y), (25000.0, 13700.0),
          reason: 'premise: free, at the click');
      await t.press(tester, LogicalKeyboardKey.escape);
      await t.press(tester, LogicalKeyboardKey.escape);
      expect(activeTool(tester), isA<SelectTool>(), reason: 'premise');

      // Its east edge dragged so its back-centre (25,000, 14,300) comes to
      // 30 mm west of the east face, north of the window.
      final from = Vector2(25300, 14000);
      await drag(tester, c, from, from + Vector2(720, 1500));
      final moved = d.tree[free.handle]! as InstanceNode;
      expect(moved.transform == free.transform, isFalse,
          reason: 'premise: the drag moved it');
      if (rotate) {
        expect(moved.transform.a, closeTo(0, 1e-9),
            reason: 'premise: the move attaches it, a quarter turn');
      } else {
        expect(linearOf(moved.transform), unturned,
            reason: 'the move may not turn it');
      }
    });
  }
}
