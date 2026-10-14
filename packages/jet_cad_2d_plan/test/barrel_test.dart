// 2a spec P2, P7: the barrel exports exactly the plan library's public API,
// every export through a `show` list, and the editor's names are usable
// through the barrel alone (this file imports nothing else of the package).
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
    });
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
}
