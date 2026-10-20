// 2a spec P2, P7: the barrel exports exactly the plan library's public API,
// every export through a `show` list, and the editor's names are usable
// through the barrel alone (this file imports nothing else of the package).
//
// 2b Task 16 ports from jet_cad_floor_plan/test/host/barrel_test.dart,
// assertions unchanged, through this barrel alone: B3 (`PlanUnit.visible`),
// B5 (the unit overlays through PlanServiceView), B6's unit half
// (`unitChanges` and an exhaustive switch over PlanUnitChange's four
// types) and B-R10's label half (an exhaustive switch over
// UnitLabelProblem). Renames follow spec S5 (FloorPlanTable -> PlanUnit,
// whose `toString` gains the kind token: ruling R-13; table overlays ->
// unit overlays; designChanges -> unitChanges).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

/// The names the barrel's `show` lists name, read as text.
Set<String> barrelNames() {
  final text = File('lib/jet_cad_2d_plan.dart').readAsStringSync();
  final exports = RegExp(r'^export\s[^;]*;', multiLine: true)
      .allMatches(text)
      .map((m) => m.group(0)!.replaceAll(RegExp(r'\s+'), ' '))
      .toList();
  final names = <String>{};
  for (final e in exports) {
    // M-ED-9: an export without `show`.
    expect(e.contains(' show '), isTrue, reason: 'every export shows: $e');
    final list = e.substring(e.indexOf(' show ') + 6, e.length - 1);
    names.addAll(list.split(',').map((n) => n.trim()));
  }
  return names;
}

void main() {
  test('ED-9 the barrel shows exactly the plan library\'s API', () {
    expect(barrelNames(), {
      // Task 6
      'KitSet', 'validateKitSet', 'KitSetError', 'reservedKitIds',
      // Task 7
      'PlanFormatException', 'PlanFormatCode', 'PlanManifest',
      'ManifestCheck', 'checkManifest', 'kPlanFormat', 'manifestOf',
      'manifestToWrite', 'usedKits', 'decodePlan', 'encodePlan',
      'ensureManifest',
      // Task 8
      'kPlanMinScale', 'kPlanMaxScale', 'kPlanThumbnailCapacity',
      'PlanController', 'PlanChange', 'PlanObjectAdded', 'PlanObjectChanged',
      'PlanObjectRemoved', 'PlanReplaced', 'SymbolsState',
      // Task 9
      'PlanStrings', 'PlanStringsEn', 'PlanStringsDe', 'PlanStringsTr',
      'PlanLocalizations', 'planSupportedLocales',
      'planLocalizationsDelegates', 'PlanTheme', 'kPlanFontFamily',
      'ensurePlanFonts', 'registerFontLicences',
      // Task 10, 11, 12
      'PlanLocked', 'KitHookFailure', 'PlanPermissions',
      // Task 13
      'PlanSymbol', 'PlanSymbolLoader', 'PlanSymbolLoad',
      'PlanSymbolGallery', 'SymbolThumbnails',
      // Task 15, 16, 17, 18
      'PlanCanvas', 'kLockHintDuration', 'PlanToolPalette', 'PlanShortcuts',
      'PlanShortcutGuard',
      'PlanPropertyPanel', 'PlanLayerPanel', 'PlanPagePanel',
      // Task 19
      'PlanExport', 'PlanExportAnswer', 'PlanExportChoice', 'PlanExportDpi',
      'PlanExportFonts', 'PlanExportRequest', 'PlanExporter', 'PlanImporter',
      'PlanPageExporter', 'PlanExportDialog', 'PagePrinter',
      'PrintingPagePrinter',
      // Task 20
      'PlanEditor', 'PlanEditorBar', 'PlanEditorAction', 'PlanFileCallback',
      // 2b Task 8
      'isUnitSymbol',
      // 2b Task 9
      'BadLabel', 'DuplicateLabel', 'PlanCamera', 'PlanUnit', 'PlanUnitAdded',
      'PlanUnitChange', 'PlanUnitChanged', 'PlanUnitDetail', 'PlanUnitRemoved',
      'PlanUnitsReplaced', 'Unlabelled', 'UnitLabelProblem', 'UnitLabelWarning',
      // 2b Task 11
      'PlanMode',
      // POS-host Task 3
      'PlanObjectRef', 'PlanObjectDetail', 'PlanObjectKind',
      // 2b Task 12
      'UnitGroup', 'UnitStatus',
      // 2b Task 13
      'ServiceRestore',
      // 2b Task 16
      'kUnitColourOpacity', 'UnitProblem',
      'PlanLongPress', 'PlanFloorDrag', 'PlanServiceAction', 'PlanServiceBar',
      'PlanServiceView', 'PlanUnitOverlay', 'PlanUnitOverlayBuilder',
      'PlanOverlaySize', 'PlanOverlayLayout',
      // 3b Task 1
      'showPlanExportDialog', 'kFileChords',
      // 4a Task 3
      'PlanToolIds',
    });
  });

  test('the barrel exports the export dialog and the file chords', () {
    const PlanExportDialog dialog = showPlanExportDialog;
    expect(dialog, isNotNull);
    expect(kFileChords, isNotEmpty);
  });

  testWidgets('ED-9b the editor\'s names, through the barrel alone',
      (tester) async {
    final c = PlanController(kits: const []);
    addTearDown(c.dispose);
    PlanExport? last;
    const PagePrinter printer = PrintingPagePrinter();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PlanEditor(
                controller: c,
                printer: printer,
                onExport: (e) => last = e,
                bar: const PlanEditorBar(
                    actions: [PlanEditorAction.undo, PlanEditorAction.zoom]),
                theme: const PlanTheme(selectionWidth: 2)))));
    await tester.pump();
    expect(last, isNull);
    expect(c.permissions, PlanPermissions.full);
    expect(PlanExportChoice.initial.dpi, PlanExportDpi.d150);
    expect(find.byType(PlanEditor), findsOneWidget);
  });

  test('B-R10 the label problem through the barrel (its label half)', () {
    // An exhaustive switch over every enum value: dropping the export
    // (M-R10b) is a compile error here.
    String word(UnitLabelProblem p) => switch (p) {
          UnitLabelProblem.length => 'length',
          UnitLabelProblem.control => 'control',
        };
    expect(UnitLabelProblem.values.map(word).toList(), ['length', 'control']);
    expect(UnitLabelProblem.values.map((p) => p.name).toList(),
        ['length', 'control']);
  });

  test(
      'B3 PlanUnit.visible through the barrel: named, true by default, '
      'in ==, hashCode and toString (zone spec Z24)', () {
    const shown =
        PlanUnit(label: '5', kind: 'table', capacity: 4, symbolKey: 'k');
    const hidden = PlanUnit(
        label: '5', kind: 'table', capacity: 4, symbolKey: 'k', visible: false);
    expect(shown.visible, isTrue);
    expect(hidden.visible, isFalse);
    expect(
        shown,
        const PlanUnit(
            label: '5',
            kind: 'table',
            capacity: 4,
            symbolKey: 'k',
            visible: true));
    expect(shown == hidden, isFalse);
    expect(
        shown.hashCode,
        const PlanUnit(label: '5', kind: 'table', capacity: 4, symbolKey: 'k')
            .hashCode);
    expect(shown.hashCode == hidden.hashCode, isFalse);
    expect(shown.toString(), 'PlanUnit(5, table, 4, k, visible: true)');
    expect(hidden.toString(), 'PlanUnit(5, table, 4, k, visible: false)');
  });

  testWidgets(
      'B5 the unit overlays through the barrel alone (host embedding API '
      'spec G-5, G-6, G-7)', (tester) async {
    final c = PlanController(kits: const []);
    addTearDown(c.dispose);
    PlanUnitOverlay? seen;
    Widget? badge(BuildContext context, PlanUnitOverlay unit) {
      seen = unit;
      return null;
    }

    final PlanUnitOverlayBuilder builder = badge;
    const layout = PlanOverlayLayout(
        anchor: Alignment.topCenter,
        size: PlanOverlaySize.box,
        maxNaturalSize: Size(80, 40),
        hideBelowScale: 0.01,
        detailBreakpoints: [0.05, 0.2]);
    c.setMode(PlanMode.service);
    await tester.pumpWidget(MaterialApp(
        home: PlanServiceView(
            controller: c,
            unitOverlayBuilder: builder,
            unitOverlayLayout: layout,
            unitOverlayModes: const {PlanMode.design, PlanMode.service})));
    await tester.pump();
    expect(seen, isNull, reason: 'an empty plan has no table');
    expect(layout.size, PlanOverlaySize.box);
    expect(PlanOverlaySize.values, hasLength(2));
  });

  testWidgets(
      'B6 the unit changes through the barrel alone (host embedding API '
      'spec E-5): the stream, the four types, an exhaustive switch (its '
      'unit half)', (tester) async {
    final c = PlanController(kits: const []);
    addTearDown(c.dispose);
    final seen = <PlanUnitChange>[];
    final sub = c.unitChanges.listen(seen.add);
    addTearDown(sub.cancel);
    c.newPlan();
    await tester.pump();
    expect(seen, [const PlanUnitsReplaced()]);

    const unit = PlanUnitDetail(
        unit: PlanUnit(label: '3', kind: 'table', capacity: 2, symbolKey: null),
        center: Offset(41000, -27000),
        size: Size(800, 600),
        rotation: -0.5,
        mirrored: false,
        corners: [],
        layer: '0',
        locked: false,
        data: {'id': 'a'});
    String word(PlanUnitChange change) => switch (change) {
          PlanUnitAdded(:final unit) => 'added ${unit.unit.label}',
          PlanUnitRemoved(:final unit) => 'removed ${unit.unit.label}',
          PlanUnitChanged(:final before, :final after) =>
            'changed ${before.data} to ${after.data}',
          PlanUnitsReplaced() => 'replaced',
        };
    expect(
        [
          const PlanUnitAdded(unit),
          const PlanUnitRemoved(unit),
          const PlanUnitChanged(unit, unit),
          ...seen,
        ].map(word),
        ['added 3', 'removed 3', 'changed {id: a} to {id: a}', 'replaced']);
  });
}
