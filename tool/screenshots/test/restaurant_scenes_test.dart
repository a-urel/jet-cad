// The restaurant kit's scenes (package READMEs spec D5, umbrella A11): the
// demo's Salon sample in the plan library's editor, and the plan library's
// gallery over the kit's own symbols, its section shown. Written to
// jet_cad_2d_kit_restaurant/doc/screenshots/ under UPDATE_SCREENSHOTS=1.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SymbolGallery;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_kit_restaurant/jet_cad_2d_kit_restaurant.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:restaurant_demo/samples/salon.dart';

import 'support/shots.dart';

const _package = 'jet_cad_2d_kit_restaurant';

/// The restaurant kit's own kit id, the gallery's `<kit>/<category>` prefix.
const String _kit = 'restaurant';

/// The plan library's app, as a host builds it: the plan's locales and
/// delegates around [home].
Widget _app(Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto'),
      supportedLocales: planSupportedLocales,
      localizationsDelegates: planLocalizationsDelegates,
      home: home,
    );

Future<void> _loaded(WidgetTester tester, PlanController controller) async {
  await settle(tester,
      until: () => controller.symbolsState.value == SymbolsState.ready);
}

void main() {
  setUpAll(() async {
    await loadManifestFonts();
    await ensurePlanFonts();
  });

  testWidgets('RS1 restaurant_salon.png: the demo\'s Salon in the editor',
      (tester) async {
    // The demo's Salon (apps/restaurant_demo/lib/samples/salon.dart): the
    // architecture kit's walls and door with the restaurant kit's tables,
    // booths, bar and host stand, in the plan library's editor. Both kits
    // load in the demo's order (the architecture kit first).
    final controller = PlanController(
        kits: [architectureKit, restaurantKit], build: buildSalon);
    addTearDown(controller.dispose);
    await pumpScene(
        tester, _app(Scaffold(body: PlanEditor(controller: controller))));
    await _loaded(tester, controller);
    await shoot(tester, package: _package, file: 'restaurant_salon.png');
  });

  testWidgets('RS2 restaurant_gallery.png: the gallery over the kit\'s section',
      (tester) async {
    // The plan library's gallery (spec P2 Task 13), filtered to the
    // restaurant kit so its own section shows, one category open.
    final controller = PlanController(kits: [architectureKit, restaurantKit]);
    addTearDown(controller.dispose);
    await _loaded(tester, controller);
    await pumpScene(
        tester,
        _app(Material(
            child: PlanSymbolGallery(
                controller: controller, filter: (s) => s.kitId == _kit))),
        size: kPanel);
    await settle(tester);
    const open = '$_kit/Outdoor and Decor';
    final gallery = tester.widget<SymbolGallery>(find.byType(SymbolGallery));
    final ids = [for (final c in gallery.categories) c.id];
    expect(ids, contains(open));
    expect(ids, everyElement(startsWith('$_kit/')));
    // Collapse every category, in the gallery's order: collapsing the first
    // shortens the panel, so each next header is built in turn (only the
    // visible ones are). Then open the one to show.
    for (final id in ids) {
      final header = find.byKey(Key('symbol-group-$id'));
      await tester.ensureVisible(header);
      await tester.tap(header);
      await tester.pump();
    }
    // Let the scroll position clamp back once every grid is gone, so the
    // headers are all built again.
    await tester.pumpAndSettle();
    final openHeader = find.byKey(Key('symbol-group-$open'));
    await tester.ensureVisible(openHeader);
    await tester.tap(openHeader);
    await tester.pumpAndSettle();
    // The thumbnails paint asynchronously, over settle's rounds.
    await settle(tester);
    await shoot(tester,
        package: _package, file: 'restaurant_gallery.png', size: kPanel);
  });
}
