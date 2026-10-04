// Dark theme spec D1, D4, D5 (plan Task 4): the shell hands `PlannerView`
// the chrome from the theme and the paper set from the paper, and both
// follow a live switch without a camera move.
//
// The real shell under the floor planner's seed, light and dark, at zero
// theme animation; read back in pixels (support/palette_fixture.dart). The
// selection, the ink, the ruler bar, the corner box and the sheet's edge
// are each asserted on their own, so a palette taken from the wrong source
// shows up in the crossing that separates the two sources: a dark theme on
// White paper, and a light theme on Blueprint.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/planner_shell.dart';
import 'package:jet_cad_floor_plan/src/planner_view.dart';

import 'support/palette_fixture.dart';

/// The shell over [doc] in [mode], at 1440 x 900, with [selected] selected
/// and the fixture's camera set after the view's own first fit.
Future<PlannerView> pumpShell(WidgetTester tester, DraftDocument doc,
    Handle selected, ThemeMode mode) async {
  windowAt(tester, const Size(1440, 900));
  await pumpThemed(tester, PlannerShell(document: doc), mode);
  await tester.pump();
  final view = tester.widget<PlannerView>(find.byType(PlannerView));
  view.camera.value = paletteCamera;
  view.selection.replace([SelectionKey.root(selected)]);
  await tester.pump();
  return view;
}

/// Pumps the same shell under [mode] (the tree keeps its shape, so every
/// state survives) and lets the zero-length theme change land.
Future<void> switchTheme(
    WidgetTester tester, DraftDocument doc, ThemeMode mode) async {
  await pumpThemed(tester, PlannerShell(document: doc), mode);
  await tester.pump();
}

DraftCanvasState canvas(WidgetTester tester) =>
    tester.state<DraftCanvasState>(find.byType(DraftCanvas));

/// The colour ACI 7 resolves to on the canvas's own resolver.
int inkArgb(WidgetTester tester, DraftDocument doc, Handle line) =>
    canvas(tester)
        .painter
        .resolver
        .styleFor(doc.entities.slotOf(line)!, StyleContext.documentRoot)
        .argb;

void main() {
  test(
      'premise: the seed\'s light surface takes black ink, its dark one '
      'white; Blueprint and White take opposite sets', () {
    expect(foregroundFor(lightTheme.colorScheme.surface.toARGB32()), 0x000000);
    expect(foregroundFor(darkTheme.colorScheme.surface.toARGB32()), 0xFFFFFF);
    expect(PaperPalette.forPaper(white), PaperPalette.light);
    expect(PaperPalette.forPaper(blueprint), PaperPalette.dark);
    // The chrome sets and the paper sets differ where the tests look.
    expect(ChromePalette.light.rulerBackground,
        isNot(ChromePalette.dark.rulerBackground));
    expect(ChromePalette.light.sheetEdge, isNot(ChromePalette.dark.sheetEdge));
    expect(PaperPalette.light.selection, isNot(PaperPalette.dark.selection));
  });

  // M-DT-1, M-DT-2 and review 2's note: all four crossings. The light theme
  // on White pins what `PlannerView` hands down when nothing is dark.
  for (final (mode, paper, name) in [
    (ThemeMode.light, white, 'light theme, White paper'),
    (ThemeMode.light, blueprint, 'light theme, Blueprint paper'),
    (ThemeMode.dark, white, 'dark theme, White paper'),
    (ThemeMode.dark, blueprint, 'dark theme, Blueprint paper'),
  ]) {
    testWidgets(
        'M-DT-1, M-DT-2: $name: the selection takes the paper\'s set, the '
        'ruler bar, the corner and the sheet edge the theme\'s chrome, the '
        'ink the paper\'s foreground', (tester) async {
      final m = FlutterTextMeasurer();
      addTearDown(m.clear);
      final f = paletteDoc(m, paper: paper);
      final view = await pumpShell(tester, f.doc, f.selected, mode);
      final chrome =
          mode == ThemeMode.dark ? ChromePalette.dark : ChromePalette.light;
      final set = paper == blueprint ? PaperPalette.dark : PaperPalette.light;
      final seen = look(tester, await shoot(tester));
      expectSelection(seen, set, name);
      expectChrome(seen, chrome, name);
      if (paper == blueprint) {
        expectLightInk(seen, name);
        expect(inkArgb(tester, f.doc, f.ink), 0xFFFFFFFF);
      } else {
        expectDarkInk(seen, name);
        expect(inkArgb(tester, f.doc, f.ink), 0xFF000000);
      }
      // What the shell hands the view, and the view its painters (the page
      // chrome's paper set included, which the pixels above do not show).
      expect(view.chrome, chrome);
      expect(view.paper, set);
      expectPainters(tester, chrome, set, name);
    });
  }

  testWidgets(
      'M-DT-9: a theme switch with no camera move repaints the ruler bar, '
      'the corner and the sheet edge in the dark chrome and back; the '
      'paper\'s selection and ink stay, and the canvas keeps its resolver',
      (tester) async {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final f = paletteDoc(m, paper: white);
    final view = await pumpShell(tester, f.doc, f.selected, ThemeMode.light);
    final camera = view.camera.value;
    var seen = look(tester, await shoot(tester));
    expectChrome(seen, ChromePalette.light, 'light');
    expectSelection(seen, PaperPalette.light, 'light');
    final painter = canvas(tester).painter;

    await switchTheme(tester, f.doc, ThemeMode.dark);
    expect(identical(view.camera.value, camera), isTrue,
        reason: 'no camera move: only shouldRepaint can repaint');
    seen = look(tester, await shoot(tester));
    expectChrome(seen, ChromePalette.dark, 'after the switch to dark');
    expectSelection(seen, PaperPalette.light, 'White stays the light set');
    expectDarkInk(seen, 'White stays black ink');
    expect(identical(canvas(tester).painter, painter), isTrue,
        reason: 'a theme switch under a page keeps the foreground, so the '
            'resolver, so the painter');

    await switchTheme(tester, f.doc, ThemeMode.light);
    seen = look(tester, await shoot(tester));
    expectChrome(seen, ChromePalette.light, 'back to light');
  });

  testWidgets(
      'M-DT-9: with a line selected, White to Blueprint with no camera move '
      'repaints the selection 0x7FB2FF and the ink white; White to Ivory '
      'keeps the light set', (tester) async {
    // The shell's rebuild on a foreground flip is what hands the view the
    // new set. The overlay's repaint here also comes from the outline cache
    // (every `DocChange` with a selection), so its `shouldRepaint` is
    // witnessed by the no-page theme switch below (R-C4-2).
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final f = paletteDoc(m, paper: white);
    final view = await pumpShell(tester, f.doc, f.selected, ThemeMode.light);
    final camera = view.camera.value;
    var seen = look(tester, await shoot(tester));
    expectSelection(seen, PaperPalette.light, 'White');

    PageComponent page() =>
        f.doc.components.get<PageComponent>(f.doc.rootHandle)!;
    Future<void> paper(int argb) async {
      f.doc.commands.execute(SetComponentCommand<PageComponent>(
          f.doc.rootHandle, page().copyWith(background: argb)));
      await tester.pump();
    }

    await paper(blueprint);
    expect(identical(view.camera.value, camera), isTrue);
    seen = look(tester, await shoot(tester));
    expectSelection(seen, PaperPalette.dark, 'Blueprint');
    expect(rgbOf(PaperPalette.dark.selection), 0x7FB2FF);
    expectLightInk(seen, 'Blueprint');
    expectChrome(seen, ChromePalette.light, 'the chrome stays the theme\'s');

    await paper(0xFFFAF6EC); // Ivory
    seen = look(tester, await shoot(tester));
    expectSelection(seen, PaperPalette.light, 'Ivory');
    expectDarkInk(seen, 'Ivory');
  });

  testWidgets(
      'M-DT-10: no page in the dark theme: ACI 7 is light on the dark '
      'surface and the selection is the dark set', (tester) async {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final f = paletteDoc(m, paper: null);
    expect(f.doc.components.get<PageComponent>(f.doc.rootHandle), isNull);
    final view = await pumpShell(tester, f.doc, f.selected, ThemeMode.dark);
    expect(view.paper, PaperPalette.dark);
    final seen = look(tester, await shoot(tester));
    expectLightInk(seen, 'no page, dark');
    expectSelection(seen, PaperPalette.dark, 'no page, dark');
    expect(inkArgb(tester, f.doc, f.ink), 0xFFFFFFFF);
  });

  testWidgets(
      'M-DT-10: no page in the light theme: ACI 7 is black and the selection '
      'the light set (today\'s behaviour)', (tester) async {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final f = paletteDoc(m, paper: null);
    final view = await pumpShell(tester, f.doc, f.selected, ThemeMode.light);
    expect(view.paper, PaperPalette.light);
    final seen = look(tester, await shoot(tester));
    expectDarkInk(seen, 'no page, light');
    expectSelection(seen, PaperPalette.light, 'no page, light');
    expect(inkArgb(tester, f.doc, f.ink), 0xFF000000);
  });

  testWidgets(
      'M-DT-9, M-DT-10, D4: no page, a theme switch re-derives the ink and '
      'the paper set from the new surface: light to dark turns ACI 7 white '
      'and the selection dark with no camera move, and back', (tester) async {
    // The overlay's own repaint witness: no `DocChange` happens here, so
    // nothing in the overlay's repaint merge fires, and only its
    // `shouldRepaint` can show the new set (and only the canvas's can show
    // the new ink). The paper flip below cannot be that witness: with a line
    // selected, the page command's `DocChange` makes the `OutlineCache`, a
    // member of the merge, notify (ruling R-C4-2).
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final f = paletteDoc(m, paper: null);
    await pumpShell(tester, f.doc, f.selected, ThemeMode.light);
    var seen = look(tester, await shoot(tester));
    expectDarkInk(seen, 'light');
    expectSelection(seen, PaperPalette.light, 'light');

    await switchTheme(tester, f.doc, ThemeMode.dark);
    seen = look(tester, await shoot(tester));
    expect(inkArgb(tester, f.doc, f.ink), 0xFFFFFFFF);
    expectLightInk(seen, 'after the switch to dark');
    expectSelection(seen, PaperPalette.dark, 'after the switch to dark');

    await switchTheme(tester, f.doc, ThemeMode.light);
    seen = look(tester, await shoot(tester));
    expect(inkArgb(tester, f.doc, f.ink), 0xFF000000);
    expectDarkInk(seen, 'back to light');
    expectSelection(seen, PaperPalette.light, 'back to light');
  });
}
