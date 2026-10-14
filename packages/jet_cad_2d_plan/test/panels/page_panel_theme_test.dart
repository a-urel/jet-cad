// Ported from jet_cad_floor_plan/test/canvas_ui_test.dart (the premise test
// and D6a; Task 15 sent D6a here); assertions unchanged. The page panel
// takes a PlanController (2a spec P2).
//
// Dark theme spec D6a (plan Task 5): the page swatch border is the
// scheme's primary (selected) or outline (not selected), in both themes.
//
// Under the floor planner's seed, light and dark (support/
// canvas_fixture.dart). The selected swatch is not the first one, and the
// selection moves, so a border read from the wrong swatch is seen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/panels/plan_page_panel.dart';

import '../support/canvas_fixture.dart';

/// The page panel's Ivory swatch (index 1).
const int ivory = 0xFFFAF6EC;

/// A controller whose document carries [page], with an empty history
/// (copied from page_panel_test.dart).
PlanController planWithPage(PageComponent page) {
  final scratch = PlanController(kits: const []);
  scratch.document.commands.execute(
      SetComponentCommand<PageComponent>(scratch.document.rootHandle, page));
  final json = scratch.save();
  scratch.dispose();
  return PlanController(kits: const [], json: json);
}

/// The border of the page panel's swatch [i].
Border swatchBorder(WidgetTester tester, int i) {
  final box = tester.widget<Container>(find
      .descendant(
          of: find.byKey(Key('page-swatch-$i')),
          matching: find.byType(Container))
      .first);
  return (box.decoration! as BoxDecoration).border! as Border;
}

void main() {
  test(
      'premise: the seed schemes\' primaries differ by theme, and from '
      'their outlines and from Colors.blue', () {
    for (final s in [lightTheme.colorScheme, darkTheme.colorScheme]) {
      expect(s.primary, isNot(s.outline));
      expect(s.primary, isNot(Colors.blue));
      expect(s.outline, isNot(Colors.black26));
    }
    expect(
        lightTheme.colorScheme.primary, isNot(darkTheme.colorScheme.primary));
    expect(
        lightTheme.colorScheme.outline, isNot(darkTheme.colorScheme.outline));
  });

  for (final (mode, theme) in [
    (ThemeMode.light, lightTheme),
    (ThemeMode.dark, darkTheme),
  ]) {
    testWidgets(
        'D6a, ${mode.name} theme: the selected swatch border is '
        'scheme.primary, 2 px; the others scheme.outline, 1 px; and it moves '
        'with the selection', (tester) async {
      final c = planWithPage(
          PageComponent(originX: 7350, originY: -1230, background: ivory));
      addTearDown(c.dispose);
      final doc = c.document;
      await pumpThemed(
          tester,
          Scaffold(
              body: SizedBox(width: 280, child: PlanPagePanel(controller: c))),
          mode);
      final scheme = theme.colorScheme;

      void expectSelected(int selected, String reason) {
        for (var i = 0; i < 4; i++) {
          final side = swatchBorder(tester, i).top;
          expect(side.color, i == selected ? scheme.primary : scheme.outline,
              reason: '$reason: swatch $i');
          expect(side.width, i == selected ? 2 : 1,
              reason: '$reason: swatch $i');
        }
      }

      expectSelected(1, 'Ivory');
      await tester.tap(find.byKey(const Key('page-swatch-3')));
      await tester.pump();
      await tester.pump();
      expect(doc.components.get<PageComponent>(doc.rootHandle)!.background,
          blueprint);
      expectSelected(3, 'Blueprint');
    });
  }
}
