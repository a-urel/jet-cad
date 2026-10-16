// Ported from apps/floor_planner/test/symbols/symbol_library_loader_test.dart
// (audit docs/superpowers/specs/2026-10-16-architecture-demo-test-audit.md,
// section "symbols/symbol_library_loader_test.dart"): SL9b SPLIT. The other
// rows are COVERED (SL1-SL8, SL9, SL10, SL11) or DROPPED (SL9c, SL12) and
// need no app test.
//
// COVERED, checked (each opened and read), in packages:
//   SL premise (41 symbols, six categories)  jet_cad_2d_kit_architecture/test/
//        furniture/furniture_library_test.dart:68 ("ships 41 symbols in six
//        categories")
//   SL1  jet_cad_2d_plan/test/controller/symbols_controller_test.dart:44
//        (S-9: loading, then ready, started with the controller);
//        symbols/plan_symbol_loader_test.dart:161 (S-7, read once)
//   SL2-SL5  symbols/plan_symbol_loader_test.dart:110 (S-5: a throwing read,
//        bytes that do not decode, a Error as well as an Exception)
//   SL6, SL7  symbols_controller_test.dart:148 (S-12: retry reaches ready;
//        from ready it reads nothing again); panels/
//        plan_symbol_gallery_test.dart:174 ("a failed load shows its message
//        and Retry; Retry reaches ready")
//   SL8  symbols/plan_symbol_loader_test.dart:192 (S-8: a disposed loader
//        refuses), symbols_controller_test.dart:204 (S-13: a late load
//        neither notifies nor throws)
//   SL9  jet_cad_2d_integration/test/furniture/furniture_load_test.dart:26
//        (FU-load, through the bundle); jet_cad_2d_kit_architecture/test/
//        furniture/package_assets_test.dart:43 (PA2)
//   SL10, SL11  symbols_controller_test.dart:109 (S-11: a shared loader is
//        not disposed, the controller's own is); plan_symbol_loader_test.dart
//        :161 (S-7)
//
// SL9b-open: the app reads the architecture kit's furniture and nothing else
// (41 symbols, six categories, every id the kit's), through the app's
// controller and the real bundle. Pinned through the app so a controller
// without the kit's symbol source shows an empty gallery. The intent (the
// thumbnail cache holds at least the symbol count, `kPlanThumbnailCapacity`
// = 128) was unpinned; SL9b pins it.
//
// Not pinned, and why: the app hands the controller a `PlanSymbolLoader` it
// owns (`symbols: _symbols`). A controller given no loader makes and
// disposes its own over the same sources, so removing the argument changes
// nothing the app can show; the loader's ownership is the library's
// (symbols_controller_test.dart S-11).
import 'package:flutter/material.dart' show Key;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/symbol_rig.dart';

void main() {
  testWidgets(
      'SL9b-open the app\'s Symbols tab lists the architecture kit\'s 41 '
      'furniture symbols in six categories, in the kit\'s order, and no '
      'other kit\'s', (tester) async {
    final rig = await pumpSymbolsApp(tester);
    final c = rig.controller;
    await tapFinder(tester, tabSymbols);
    final ids = galleryIdsOf(tester);
    expect(ids, hasLength(41));
    expect(ids.toSet(), hasLength(41), reason: 'each id once');
    expect(
        categoryNamesOf(tester),
        [
          'Dining Room',
          'Kitchen',
          'Bed Room',
          'Living Room',
          'Bathroom',
          'Office',
        ],
        reason: 'the kit\'s six categories, in the library\'s order');
    expect([for (final s in c.symbols) s.id], ids,
        reason: 'the gallery shows the controller\'s symbols in load order');
    expect({for (final s in c.symbols) s.kitId}, {'architecture'});
    expect(ids.every((id) => id.startsWith('architecture.')), isTrue);
    expect(ids.first, 'architecture.dining.table.square.two@1');
    expect(ids.last, 'architecture.office.bookshelf@1');
    expect(ids, contains('architecture.bed.double@1'));
    expect(c.diagnostics.value, isEmpty, reason: 'no library problem');
    // The first cells are built and keyed by their ids (the gallery builds
    // lazily).
    expect(find.byKey(Key('symbol-cell-${ids.first}')), findsOneWidget);
  });

  testWidgets(
      'SL9b the thumbnail cache holds at least every symbol: the capacity '
      'is not below the 41 the app lists', (tester) async {
    final rig = await pumpSymbolsApp(tester);
    final c = rig.controller;
    expect(c.symbols, hasLength(41));
    expect(c.thumbnails.maxEntries, kPlanThumbnailCapacity);
    expect(c.thumbnails.maxEntries, greaterThanOrEqualTo(c.symbols.length),
        reason: 'one entry per symbol: scrolling the gallery does not '
            'evict what the next cell draws');
  });
}
