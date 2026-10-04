// Dark theme spec D6a, D6b, D7, R-5 (plan Task 5): the two deliberate
// light-theme changes on the canvas's UI. The page swatch border is the
// scheme's primary (selected) or outline (not selected), in both themes;
// the text entry is filled with the scheme's `surfaceContainerHighest`, so
// the paper does not show through it (M-DT-12).
//
// Under the floor planner's seed, light and dark (support/
// palette_fixture.dart). The selected swatch is not the first one, and the
// selection moves, so a border read from the wrong swatch is seen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/page_panel.dart';
import 'package:jet_cad_floor_plan/src/planner_shell.dart';
import 'package:jet_cad_floor_plan/src/text_entry_overlay.dart'
    show kTextEntrySize;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/palette_fixture.dart';

/// The page panel's Ivory swatch (index 1).
const int ivory = 0xFFFAF6EC;

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
      final doc = DraftDocument.empty();
      PageComponent.register(doc.components);
      doc.commands.execute(SetComponentCommand<PageComponent>(doc.rootHandle,
          PageComponent(originX: 7350, originY: -1230, background: ivory)));
      doc.commands.clearHistory();
      final page = PageNotifier(doc);
      addTearDown(page.dispose);
      await pumpThemed(
          tester,
          Scaffold(
              body: SizedBox(
                  width: 280, child: PagePanel(document: doc, page: page))),
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

  // M-DT-12: dark theme on White, and the crossing, light theme on
  // Blueprint. The sample is a pixel inside the field, right of the
  // (empty) text and the caret, on the box's middle row: the paper before
  // the field opens, the theme's surfaceContainerHighest after.
  for (final (mode, theme, paper, name) in [
    (ThemeMode.dark, darkTheme, white, 'dark theme, White paper'),
    (ThemeMode.light, lightTheme, blueprint, 'light theme, Blueprint paper'),
  ]) {
    testWidgets(
        'M-DT-12, $name: a pixel inside the text entry, away from the glyphs, '
        'is surfaceContainerHighest, not the paper', (tester) async {
      final m = FlutterTextMeasurer();
      final f = paletteDoc(m, paper: paper);
      addTearDown(() {
        f.doc.dispose();
        m.clear();
      });
      windowAt(tester, const Size(1440, 900));
      await pumpThemed(tester, PlannerShell(document: f.doc), mode);
      await tester.pump();
      final camera = tester
          .widget<CameraGestureDetector>(find.byType(CameraGestureDetector))
          .camera;
      camera.value = paletteCamera;
      await tester.pump();

      // The insertion point, inside the sheet and clear of the lines.
      final at = paletteCamera.worldToScreen(Vector2(10500, 6400));
      final area = tester.getTopLeft(find.byType(InteractionLayer));
      final click = area + Offset(at.x, at.y);
      // Where the field will be: its box's bottom-left at the click.
      final sample = (
        (click.dx + 200).floor(),
        (click.dy - kTextEntrySize.height / 2).floor()
      );
      final before = await shoot(tester);
      expect(hex(before.rgbAt(sample.$1, sample.$2)), hex(paper & 0xFFFFFF),
          reason: 'premise: the paper shows there before the field opens');

      await tester.tap(find.byKey(const Key('tool-text')));
      await tester.pump();
      await tester.tapAt(click);
      await tester.pump();
      expect(find.byKey(const Key('text-entry')), findsOneWidget);
      final box = tester.getRect(find.byKey(const Key('text-entry-box')));
      expect(box.contains(Offset(sample.$1 + 0.5, sample.$2 + 0.5)), isTrue,
          reason: 'the sample lies inside the field');

      final after = await shoot(tester);
      expect(hex(after.rgbAt(sample.$1, sample.$2)),
          hex(rgbOf(theme.colorScheme.surfaceContainerHighest)),
          reason: '$name: the field is filled from the theme');
    });
  }
}
