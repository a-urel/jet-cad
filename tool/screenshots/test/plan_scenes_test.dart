// The plan library's scenes (package READMEs spec D5, umbrella A11): the
// editor over the architecture kit's sample flat, and the plan library's own
// `PlanSymbolGallery` over the kit's furniture, written to
// jet_cad_2d_plan/doc/screenshots/ under UPDATE_SCREENSHOTS=1. Public API
// only: the barrels.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/panels/gallery_grid.dart'
    show PlanGalleryGrid;

import 'support/shots.dart';

const _package = 'jet_cad_2d_plan';

/// The plan library's app, as its README's example builds it: the plan's
/// locales and delegates around [home].
Widget _app(Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto'),
      supportedLocales: planSupportedLocales,
      localizationsDelegates: planLocalizationsDelegates,
      home: home,
    );

/// Runs [body] with a controller whose symbol library is loaded: the kits'
/// libraries start loading in the constructor and read through rootBundle,
/// so real time is needed (as R5 waits).
Future<void> _loaded(WidgetTester tester, PlanController controller) async {
  await settle(tester,
      until: () => controller.symbolsState.value == SymbolsState.ready);
}

void main() {
  setUpAll(() async {
    await loadManifestFonts();
    await ensurePlanFonts();
  });

  testWidgets('PL1 plan_editor.png: the editor over the sample flat',
      (tester) async {
    // One plan over the architecture kit, filled by the kit's sample flat
    // (spec 3a C3.7): walls, doors, windows, floor finishes, rooms and
    // dimensions, in the plan library's own editor. The editor puts the
    // plan's own gallery on the left when a loaded kit has symbols.
    final controller =
        PlanController(kits: [architectureKit], build: buildSampleFlat);
    addTearDown(controller.dispose);
    await pumpScene(
        tester, _app(Scaffold(body: PlanEditor(controller: controller))));
    await _loaded(tester, controller);
    await shoot(tester, package: _package, file: 'plan_editor.png');
  });

  testWidgets('PL2 plan_gallery.png: PlanSymbolGallery over the kit',
      (tester) async {
    // The plan library's own gallery widget (spec P2 Task 13) over the
    // architecture kit's furniture library, one category open: the picture
    // the renderer's README carried before R5's fix, now where A11 puts it
    // (the widget is this package's).
    final controller = PlanController(kits: [architectureKit]);
    addTearDown(controller.dispose);
    await _loaded(tester, controller);
    await pumpScene(tester,
        _app(Material(child: PlanSymbolGallery(controller: controller))),
        size: kPanel);
    await settle(tester);
    // One category open: every other header collapsed, so the panel shows
    // the library's categories and one of them whole. The header key
    // carries the group id `<kit>/<English category>`.
    const open = 'architecture/Bathroom';
    final gallery =
        tester.widget<PlanGalleryGrid>(find.byType(PlanGalleryGrid));
    expect([for (final c in gallery.groups) c.id], contains(open));
    for (final c in gallery.groups) {
      if (c.id == open) continue;
      final header = find.byKey(Key('symbol-group-${c.id}'));
      await tester.ensureVisible(header);
      await tester.tap(header);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    // The thumbnails paint asynchronously, over settle's rounds.
    await settle(tester);
    await shoot(tester,
        package: _package, file: 'plan_gallery.png', size: kPanel);
  });
}
