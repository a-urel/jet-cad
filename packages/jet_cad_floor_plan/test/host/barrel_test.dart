// Spec 14b-2 H9, R-10 (M-14b2-9): the host barrel exports exactly the host
// API, every export through a `show` list, and each name is usable through
// the barrel alone (this file imports nothing else of the package).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart';

/// The names the barrel's `show` lists name, read as text.
Set<String> barrelNames() {
  final text = File('lib/jet_cad_floor_plan.dart').readAsStringSync();
  final exports = RegExp(r'^export\s[^;]*;', multiLine: true)
      .allMatches(text)
      .map((m) => m.group(0)!)
      .toList();
  final names = <String>{};
  for (final e in exports) {
    expect(e.contains(' show '), isTrue, reason: 'every export shows: $e');
    final list = e.substring(e.indexOf(' show ') + 6, e.length - 1);
    names.addAll(list.split(',').map((n) => n.trim()));
  }
  return names;
}

void main() {
  test('B1 the barrel shows exactly the host API', () {
    expect(barrelNames(), {
      'FloorPlanController',
      'FloorPlanView',
      'FloorPlanMode',
      'FloorPlanTable',
      'FloorPlanExport',
      'TableStatus',
      'ensureFloorPlanFonts',
      'registerFontLicences',
      'SymbolLibraryLoader',
      'SymbolLibrarySource',
      'furnitureSymbolSource',
      'SymbolThumbnails',
      'PagePrinter',
      'PrintingPagePrinter',
    });
  });

  testWidgets('B2 every name is usable through the barrel alone',
      (tester) async {
    final loader = SymbolLibraryLoader(sources: [furnitureSymbolSource]);
    final thumbnails = SymbolThumbnails(maxEntries: 8);
    final c = FloorPlanController(symbols: loader, thumbnails: thumbnails);
    addTearDown(() {
      c.dispose();
      thumbnails.dispose();
      loader.dispose();
    });
    const PagePrinter printer = PrintingPagePrinter();
    FloorPlanExport? last;
    await tester.pumpWidget(MaterialApp(
        home: FloorPlanView(
            controller: c, printer: printer, onExport: (e) => last = e)));
    expect(c.mode.value, FloorPlanMode.design);
    expect(c.tables, const <FloorPlanTable>[]);
    expect(last, isNull);
    expect(ensureFloorPlanFonts, isA<Function>());
    expect(registerFontLicences, isA<Function>());
    expect(furnitureSymbolSource, isA<SymbolLibrarySource>());
    c.setTableStatus({'1': TableStatus(color: const Color(0xFF00AA00))});
  });
}
