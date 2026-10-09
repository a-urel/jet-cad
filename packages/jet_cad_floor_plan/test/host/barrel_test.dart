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
      // One space for any run of whitespace: the formatter wraps a long
      // `show` list onto its own lines.
      .map((m) => m.group(0)!.replaceAll(RegExp(r'\s+'), ' '))
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
      'FloorPlanTableDetail',
      'FloorPlanDesignChange',
      'FloorPlanTableAdded',
      'FloorPlanTableRemoved',
      'FloorPlanTableChanged',
      'FloorPlanPlanReplaced',
      'FloorPlanCamera',
      'FloorPlanTheme',
      'FloorPlanTableOverlay',
      'FloorPlanTableOverlayBuilder',
      'FloorPlanOverlayLayout',
      'FloorPlanOverlaySize',
      'FloorPlanExport',
      'TableStatus',
      'ServiceLayoutRestore',
      'FloorPlanLongPress',
      'NumberingWarning',
      'DuplicateNumber',
      'Unnumbered',
      'FloorPlanLocalizations',
      'floorPlanLocalizationsDelegates',
      'floorPlanSupportedLocales',
      'FloorPlanStrings',
      'FloorPlanStringsEn',
      'FloorPlanStringsDe',
      'FloorPlanStringsTr',
      'TableGroup',
      'ensureFloorPlanFonts',
      'registerFontLicences',
      'SymbolLibraryLoader',
      'SymbolLibrarySource',
      'furnitureSymbolSource',
      'SymbolNames',
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
            controller: c,
            printer: printer,
            onExport: (e) => last = e,
            longPress: FloorPlanLongPress.toggleSelection)));
    expect(c.mode.value, FloorPlanMode.design);
    expect(c.tables, const <FloorPlanTable>[]);
    expect(last, isNull);
    expect(ensureFloorPlanFonts, isA<Function>());
    expect(registerFontLicences, isA<Function>());
    expect(furnitureSymbolSource, isA<SymbolLibrarySource>());
    c.setTableStatus({'1': TableStatus(color: const Color(0xFF00AA00))});
    c.setMode(FloorPlanMode.selection);
    final ServiceLayoutRestore restored =
        c.restoreServiceLayout(c.serviceLayoutJson()!);
    expect(restored.applied, isEmpty);
  });

  test(
      'B3 FloorPlanTable.visible through the barrel: named, true by default, '
      'in ==, hashCode and toString (zone spec Z24)', () {
    const shown = FloorPlanTable(number: '5', seats: 4, symbolKey: 'k');
    const hidden =
        FloorPlanTable(number: '5', seats: 4, symbolKey: 'k', visible: false);
    expect(shown.visible, isTrue);
    expect(hidden.visible, isFalse);
    expect(
        shown,
        const FloorPlanTable(
            number: '5', seats: 4, symbolKey: 'k', visible: true));
    expect(shown == hidden, isFalse);
    expect(shown.hashCode,
        const FloorPlanTable(number: '5', seats: 4, symbolKey: 'k').hashCode);
    expect(shown.hashCode == hidden.hashCode, isFalse);
    expect(shown.toString(), 'FloorPlanTable(5, 4, k, visible: true)');
    expect(hidden.toString(), 'FloorPlanTable(5, 4, k, visible: false)');
  });

  testWidgets(
      'B4 the camera through the barrel alone (host embedding API spec G-2, '
      'G-3): the bounds, the camera, the canvas, the commands, userCamera',
      (tester) async {
    final c = FloorPlanController(minScale: 0.01, maxScale: 10);
    addTearDown(c.dispose);
    expect(() => FloorPlanController(minScale: 1, maxScale: 1),
        throwsArgumentError);
    final FloorPlanCamera before = c.camera.value;
    expect(c.canvasRect.value, isNull);
    expect(c.worldToGlobal(Offset.zero), isNull);
    expect(c.zoomBy(2), isFalse);
    c.panBy(const Offset(3, 4));
    expect(c.camera.value == before, isFalse);
    c.centerOn(const Offset(1000, 2000), scale: 0.5);
    await tester.pumpWidget(
        MaterialApp(home: FloorPlanView(controller: c, userCamera: false)));
    await tester.pump();
    final Rect canvas = c.canvasRect.value!;
    expect(c.camera.value.scale, closeTo(0.5, 1e-12));
    expect(c.worldToGlobal(const Offset(1000, 2000))!.dx,
        closeTo(canvas.center.dx, 1e-6));
    expect(c.globalToWorld(canvas.center)!.dy, closeTo(2000, 1e-9));
    expect(c.zoomBy(2), isTrue);
    expect(c.camera.value.visibleWorld(canvas.size).center.dx,
        closeTo(1000, 1e-9));
  });

  testWidgets(
      'B5 the table overlays through the barrel alone (host embedding API '
      'spec G-5, G-6, G-7)', (tester) async {
    final c = FloorPlanController();
    addTearDown(c.dispose);
    FloorPlanTableOverlay? seen;
    Widget? badge(BuildContext context, FloorPlanTableOverlay table) {
      seen = table;
      return null;
    }

    final FloorPlanTableOverlayBuilder builder = badge;
    const layout = FloorPlanOverlayLayout(
        anchor: Alignment.topCenter,
        size: FloorPlanOverlaySize.box,
        maxNaturalSize: Size(80, 40),
        hideBelowScale: 0.01,
        detailBreakpoints: [0.05, 0.2]);
    await tester.pumpWidget(MaterialApp(
        home: FloorPlanView(
            controller: c,
            tableOverlayBuilder: builder,
            tableOverlayLayout: layout,
            tableOverlayModes: const {
          FloorPlanMode.design,
          FloorPlanMode.selection
        })));
    await tester.pump();
    expect(seen, isNull, reason: 'an empty plan has no table');
    expect(layout.size, FloorPlanOverlaySize.box);
    expect(FloorPlanOverlaySize.values, hasLength(2));
  });

  testWidgets(
      'B6 the design changes through the barrel alone (host embedding API '
      'spec E-5): the stream, the five types, an exhaustive switch',
      (tester) async {
    final c = FloorPlanController();
    addTearDown(c.dispose);
    final seen = <FloorPlanDesignChange>[];
    final sub = c.designChanges.listen(seen.add);
    addTearDown(sub.cancel);
    c.newPlan();
    await tester.pump();
    expect(seen, [const FloorPlanPlanReplaced()]);

    const table = FloorPlanTableDetail(
        table: FloorPlanTable(number: '3', seats: 2, symbolKey: null),
        center: Offset(41000, -27000),
        size: Size(800, 600),
        rotation: -0.5,
        mirrored: false,
        corners: [],
        layer: '0',
        locked: false,
        data: {'id': 'a'});
    String word(FloorPlanDesignChange change) => switch (change) {
          FloorPlanTableAdded(:final table) => 'added ${table.table.number}',
          FloorPlanTableRemoved(:final table) =>
            'removed ${table.table.number}',
          FloorPlanTableChanged(:final before, :final after) =>
            'changed ${before.data} to ${after.data}',
          FloorPlanPlanReplaced() => 'replaced',
        };
    expect(
        [
          const FloorPlanTableAdded(table),
          const FloorPlanTableRemoved(table),
          const FloorPlanTableChanged(table, table),
          ...seen,
        ].map(word),
        ['added 3', 'removed 3', 'changed {id: a} to {id: a}', 'replaced']);
  });
}
