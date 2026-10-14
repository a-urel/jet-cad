// Ported from jet_cad_floor_plan/test/canvas_ui_test.dart; assertions unchanged.
//
// Dark theme spec D6b, D7, R-5 (plan Task 5): the text entry is filled
// with the scheme's `surfaceContainerHighest`, so the paper does not show
// through it (M-DT-12). D6a, the page panel's swatch borders, is Task 18's.
//
// Under the floor planner's seed, light and dark (support/
// canvas_fixture.dart).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/canvas/text_entry_overlay.dart'
    show kTextEntrySize;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/canvas_fixture.dart';

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
      final f = paletteController(paper: paper);
      windowAt(tester, const Size(1440, 900));
      await pumpThemed(
          tester, Scaffold(body: PlanCanvas(controller: f.c)), mode);
      await tester.pump();
      f.c.camera.value = paletteCamera;
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
      // Dark canvas K1: a dark theme shows White as kDarkCanvasPaper.
      final shown = mode == ThemeMode.dark ? kDarkCanvasPaper : paper;
      final before = await shoot(tester);
      expect(hex(before.rgbAt(sample.$1, sample.$2)), hex(shown & 0xFFFFFF),
          reason: 'premise: the paper shows there before the field opens');

      f.c.selectTool('plan.text');
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
