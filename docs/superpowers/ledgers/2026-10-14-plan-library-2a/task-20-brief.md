### Task 20: `PlanEditor`, `PlanEditorBar`, the example, README and CHANGELOG (spec P2 widgets, P7)

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/editor/plan_editor_bar.dart` (port of `bars.dart`'s editor half)
- Create: `packages/jet_cad_2d_plan/lib/src/editor/plan_editor.dart` (port of `PlannerShell`'s layout and top bar, `FloorPlanView`'s design branch, `DocumentToolbar`, `ShellCommand`, `DerivedFlag`)
- Modify: `packages/jet_cad_2d_plan/lib/src/l10n/strings.dart`, `strings_en.dart`, `strings_de.dart`, `strings_tr.dart` (four file-command words)
- Modify: `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` (every export through a `show` list)
- Create: `packages/jet_cad_2d_plan/example/main.dart`
- Modify: `packages/jet_cad_2d_plan/README.md`, `packages/jet_cad_2d_plan/CHANGELOG.md`
- Create (test support): `packages/jet_cad_2d_plan/test/support/editor_host.dart`
- Create (test support): `packages/jet_cad_2d_plan/test/support/recording_plan_strings.dart` (`RecordingPlanStrings implements PlanStrings`, for LK1; Task 9 sends LK1 here without the recorder)
- Test (new): `test/editor/plan_editor_test.dart` (ED-1 … ED-7), `test/example_test.dart` (ED-8, ED-README), `test/barrel_test.dart` (ED-9, ED-9b)
- Test (ported): `test/editor/editor_separator_test.dart` (NS2 and the `panelShows` assertions, from Task 8)
- Test (ported): `test/editor/editor_bar_test.dart`, `test/editor/editor_view_test.dart`, `test/editor/editor_options_test.dart`, `test/editor/editor_words_test.dart`, `test/editor/editor_theme_test.dart`, `test/invariants/theme_colours_test.dart`
- Modify (test): `packages/jet_cad_2d_plan/test/l10n/value_words_test.dart` (Task 9's; ED-W after Task 18's LP-W, Step 5)

**Interfaces:**
- Consumes:
  - Shared interfaces: `PlanController` (Task 8), `PlanPermissions` (`export`, `print`, `undo`, `allowsTool`; Task 12).
  - Task 15: `PlanCanvas({required controller, rulers, grid, snapping, autofocus})`; `PlanShortcutGuard`, `PlanTextKeys`, the chords (`kNewChords`, `kOpenChords`, `kSaveChords`, `kSaveAsChords`, `kExportChords`, `kPrintChords`, `kUndoChords`, `kRedoChords`) in `lib/src/shortcuts/plan_shortcut_guard.dart` (re-exporting `chords.dart`).
  - Task 13: `PlanSymbolGallery({required controller, bool Function(PlanSymbol)? filter, TextEditingController? query})`, `PlanSymbol`.
  - Task 18: `PlanLayerPanel`, `PlanPagePanel`; `test/support/mark_kit.dart`. Task 19: `EditorPageFlows`, `PlanExportDialog`, `PagePrinter`, `PrintingPagePrinter`, `PlanExport`; `test/support/fake_page_printer.dart`, `test/support/recording_exporters.dart`.
  - Task 9: `PlanStrings` (`toolSymbol`, `tabTools`, `tabSymbols`, `objectSnapOn`, `objectSnapOff`, `undo`, `redo`, `exportEllipsis`, `printEllipsis`, `controlKey`, `shiftKey`, `selectedCount`, `planDamaged`), `PlanThemeScope`, `PlanTheme`, `formatPanelNumber`, `PlanLocaleScope`, `ensurePlanFonts`, `registerFontLicences`, `planSupportedLocales`, `planLocalizationsDelegates`.
  - The engine: `zoomOf` (`jet_cad_2d/lib/src/document/page_geometry.dart:15`); the Flutter layer: `kLogicalPixelsPerMm` (`draft_canvas.dart:23`).
  - The names in "Assumed from earlier tasks" (Tasks 8, 11, 12, 16, 17).
- Produces (exported from the barrel):
  - `enum PlanEditorAction { export, print, undo, redo, snap, zoom }` (today's `FloorPlanEditorAction`, `bars.dart:17`).
  - `final class PlanEditorBar` — `const PlanEditorBar({bool visible = true, List<PlanEditorAction> actions = PlanEditorAction.values, List<Widget> leading = const [], List<Widget> trailing = const []})`; `==`, `hashCode`, `toString` (today's `FloorPlanEditorBar`, `bars.dart:93-127`).
  - `typedef PlanFileCallback = Future<void> Function();`
  - `class PlanEditor extends StatefulWidget` — `const PlanEditor({Key? key, required PlanController controller, bool toolPalette = true, bool gallery = true, bool Function(PlanSymbol symbol)? symbolFilter, bool propertyPanel = true, bool layerPanel = true, bool pagePanel = true, bool rulers = true, bool grid = true, bool snapping = true, PlanEditorBar bar = const PlanEditorBar(), PlanFileCallback? onNew, PlanFileCallback? onOpen, PlanFileCallback? onSave, PlanFileCallback? onSaveAs, void Function(PlanExport export)? onExport, PlanExportDialog? onExportDialog, void Function(Object error)? onPageFlowError, PagePrinter? printer, String exportName = 'plan', bool shortcuts = true, bool autofocus = true, PlanTheme? theme})`.
  - Package-internal: `void validatePlanEditorBar(PlanEditorBar bar)`; `PlanStrings.newDocument`, `.open`, `.save`, `.saveAs`.

Plan decision: **the options are spec P2's table and P7's rows, one to one.** Today's `FloorPlanEditorCapabilities` flags that are widgets' choices become `PlanEditor` options (`selectionPanel` → `propertyPanel`, `layerPanel`, `pagePanel`, `symbolPalette` → `gallery`, `symbolFilter`, `rulers`, `grid`, `snapping`); the editing flags live in `controller.permissions` (Task 12) and the editor reads them at each build: `export`, `print` and `undo` decide which bar buttons exist (today's `planner_shell.dart:1427-1440`). `toolPalette` is new: P2's "which panels show" names the palette too.

Plan decision: **the host's file callbacks.** `onNew`, `onOpen`, `onSave` and `onSaveAs` are today's bare shell's file commands (`planner_shell.dart` with `fileCommands:`; `bars_test.dart:85-96` lists them), offered as toolbar buttons `toolbar-new`, `toolbar-open`, `toolbar-save`, `toolbar-save-as` before Export and Print, and as their chords through `PlanShortcuts`, only when given. Each settles pending input before it calls the host (spec P2: pending input is settled before a flow reads the plan; today's app flows settled through `DocumentHost` before New, Open and Save, spec 12a D2) and is enabled while no tool is part-way through a shape (`planner_shell.dart:769-778`, `_idle`). `Open sample` (the app's) is not a library command. The words are the app's (`apps/floor_planner/lib/app_strings.dart:77-89`, `:135-147`, `:198-210`), moved into `PlanStrings`.

Plan decision: **Export and Print are the view's flows** (`EditorPageFlows`, Task 19) under the controller's guard: enabled while the flows are ready, no tool is part-way through a shape and the plan has a page (today's `_fileEnabled` for `kPageCommandIds`, `planner_shell.dart:769-778`); Export exists only with `onExport` and `permissions.export`, Print only with `permissions.print`.

Plan decision: **what is not ported.** The document name and its dirty mark (`planner_shell.dart:1174-1191`, the app's), the table inspector (`:1555-1566`, 2b), the table colour layer (`:1518-1524`, 2b), the room and dimension notices in the status line (`:1007-1011`, sub-project 3), the canvas measuring for mode switches (`floor_plan_view.dart`'s `_measureAfterFrame`, `_keepPlanInPlace`, `_chromeOrigin`: 2b's service mode). The canvas's paper and resolver are `PlanCanvas`'s own (Task 15).

Plan decision: **the damaged warning sits in the bar** (Task 9 added `planDamaged` for it): while `controller.damaged` is true a warning icon (`plan-damaged`, the scheme's error colour, the word as its tooltip) stands before the status line (spec P4: "It marks the plan `damaged`, shows a warning").

Plan decision: **the barrel shows exactly the public API.** Every export carries a `show` list, as `jet_cad_floor_plan`'s barrel does (`test/host/barrel_test.dart:10-26`); the expected set in ED-9 is the union of the **Produces (exported)** blocks of Tasks 6-20 as this plan states them. Where an earlier task's block and this list differ, that task's block wins and the difference is reported in this task's report.

- [ ] **Step 1: The fixture.** Create `packages/jet_cad_2d_plan/test/support/editor_host.dart`:

```dart
// The editor's fixture: the embedding fixture's page (originX 37000,
// originY -36200, as `jet_cad_floor_plan/test/host/embedding_fixture.dart:
// 131-132`), two turned marks and a line around the sheet's centre, saved;
// the camera the bar tests measured under (`embeddingCamera`, `:160-161`);
// and the editor pumped at 1440 x 900.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ViewportTransform;
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/editor/plan_editor.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'mark_kit.dart';

/// The marks of [editorPlanJson], in order.
const int kEditorMarks = 2;

String editorPlanJson() {
  final scratch = PlanController(kits: [markKit()]);
  final doc = scratch.document;
  final root = doc.rootHandle;
  doc.commands.execute(SetComponentCommand<PageComponent>(
      root, PageComponent(originX: 37000, originY: -36200)));
  final sheet = sheetWorldRect(doc.components.get<PageComponent>(root)!);
  final cx = (sheet.minX + sheet.maxX) / 2, cy = (sheet.minY + sheet.maxY) / 2;
  addMark(doc, ReservedHandles.layerZero,
      at: Transform2.translation(cx - 2600.5, cy + 900.25)
          .multiply(Transform2.rotation(0.4)),
      size: 700.5);
  addMark(doc, ReservedHandles.layerZero,
      at: Transform2.translation(cx + 2100.25, cy - 700.5)
          .multiply(Transform2.rotation(-1.1)),
      size: 520.25);
  doc.commands.execute(addDrafted(
      doc,
      EntityKind.line,
      linePayload(Vector2(cx - 3900.5, cy - 2100.25),
          Vector2(cx + 3300.75, cy + 1800.5)),
      layer: ReservedHandles.layerZero));
  final json = scratch.save();
  scratch.dispose();
  return json;
}

ViewportTransform embeddingCamera() => ViewportTransform(
    worldToScreenMatrix: Transform2(0.37, 0, 0, -0.37, -14612.25, -9431.5));

/// A controller over [editorPlanJson] (or [json]), disposed at tear-down.
PlanController editorController({String? json}) {
  final c = PlanController(kits: [markKit()], json: json ?? editorPlanJson());
  addTearDown(c.dispose);
  return c;
}

/// [editor] in a 1440 x 900 window, two frames, then [editor]'s controller
/// under [embeddingCamera]. Pump again with another editor to change its
/// options at runtime (the same element is updated).
Future<void> pumpEditor(WidgetTester tester, PlanEditor editor,
    {ThemeData? theme}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
      MaterialApp(theme: theme, home: Scaffold(body: editor)));
  await tester.pump();
  await tester.pump();
  editor.controller.camera.value = embeddingCamera();
  await tester.pump();
}

Finder byKey(String k) => find.byKey(Key(k));

double left(WidgetTester tester, String k) => tester.getTopLeft(byKey(k)).dx;
double right(WidgetTester tester, String k) => tester.getTopRight(byKey(k)).dx;
```

- [ ] **Step 2: The new tests (they fail first).** Create `packages/jet_cad_2d_plan/test/editor/plan_editor_test.dart`:

```dart
// 2a spec P2 (PlanEditor: today's layout, its options, the host's file
// callbacks, the bar's commands by the permissions, the theme), P4 (the
// damaged warning) and P7 (one view over a controller).
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/src/canvas/plan_canvas.dart';
import 'package:jet_cad_2d_plan/src/controller/permissions.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/editor/plan_editor.dart';
import 'package:jet_cad_2d_plan/src/editor/plan_tool_palette.dart';
import 'package:jet_cad_2d_plan/src/export/registries.dart';
import 'package:jet_cad_2d_plan/src/l10n/strings_en.dart';
import 'package:jet_cad_2d_plan/src/panels/plan_layer_panel.dart';
import 'package:jet_cad_2d_plan/src/panels/plan_page_panel.dart';
import 'package:jet_cad_2d_plan/src/panels/plan_property_panel.dart';
import 'package:jet_cad_2d_plan/src/panels/plan_symbol_gallery.dart';
import 'package:jet_cad_2d_plan/src/theme/plan_theme.dart';

import '../support/editor_host.dart';
import '../support/fake_page_printer.dart';

const _en = PlanStringsEn();

/// A kit whose one library never finishes reading: the gallery has a
/// source, so the Symbols tab is offered, and stays loading.
PlanKit slowSymbolsKit() => PlanKit(
      id: 'gal',
      version: '1.0.0',
      symbols: [
        SymbolLibrarySource(
            label: 'never', read: () => Completer<Uint8List>().future),
      ],
    );

void main() {
  testWidgets(
      'ED-1 the editor over one controller: the four slots, each widget '
      'once, the palette on the left, the Layers section between the '
      'property panel and the page panel', (tester) async {
    final c = editorController();
    await pumpEditor(tester, PlanEditor(controller: c));
    for (final k in [
      'chrome-top',
      'chrome-left',
      'chrome-canvas',
      'chrome-right',
    ]) {
      expect(byKey(k), findsOneWidget, reason: k);
      expect(tester.getSize(byKey(k)).width, greaterThan(0), reason: k);
    }
    for (final t in [
      PlanCanvas,
      PlanToolPalette,
      PlanPropertyPanel,
      PlanLayerPanel,
      PlanPagePanel,
    ]) {
      expect(find.byType(t), findsOneWidget, reason: '$t');
    }
    expect(
        find.descendant(
            of: byKey('chrome-left'), matching: find.byType(PlanToolPalette)),
        findsOneWidget);
    final column = byKey('chrome-right');
    double top(Type t) => tester
        .getTopLeft(find.descendant(of: column, matching: find.byType(t)))
        .dy;
    // M-ED-1: the Layers and Page sections swapped in the right column.
    expect(top(PlanPropertyPanel), lessThanOrEqualTo(top(PlanLayerPanel)));
    expect(top(PlanLayerPanel), lessThan(top(PlanPagePanel)));
    expect(find.byType(PlanSymbolGallery), findsNothing,
        reason: 'a kit without symbols offers no Symbols tab');
  });

  testWidgets(
      'ED-2 with a kit that has symbols: the Tools and Symbols tabs, Tools '
      'first; the Symbols tab shows the gallery; gallery: false shows the '
      'palette alone', (tester) async {
    final c = PlanController(kits: [slowSymbolsKit()]);
    addTearDown(c.dispose);
    await pumpEditor(tester, PlanEditor(controller: c));
    expect(byKey('left-tabs'), findsOneWidget);
    expect(find.byType(PlanToolPalette), findsOneWidget);
    expect(find.byType(PlanSymbolGallery), findsNothing);
    await tester.tap(byKey('tab-symbols'));
    await tester.pump();
    expect(find.byType(PlanSymbolGallery), findsOneWidget);
    expect(find.byType(PlanToolPalette), findsNothing);

    // M-ED-2: `_gallery` ignores `widget.gallery`.
    await pumpEditor(tester, PlanEditor(controller: c, gallery: false));
    expect(byKey('left-tabs'), findsNothing);
    expect(find.byType(PlanSymbolGallery), findsNothing);
    expect(find.byType(PlanToolPalette), findsOneWidget);
  });

  testWidgets(
      'ED-3 the host\'s file callbacks: New, Open, Save and Save As before '
      'Export and Print, in that order; each press settles pending input, '
      'then calls the host once; without them none is offered',
      (tester) async {
    final c = editorController();
    final log = <String>[];
    final release = c.registerSettle(() => log.add('settle'));
    addTearDown(release);
    PlanFileCallback record(String what) => () async => log.add(what);
    await pumpEditor(
        tester,
        PlanEditor(
            controller: c,
            onExport: (_) {},
            onNew: record('new'),
            onOpen: record('open'),
            onSave: record('save'),
            onSaveAs: record('save-as')));
    final order = [
      'toolbar-new',
      'toolbar-open',
      'toolbar-save',
      'toolbar-save-as',
      'toolbar-export',
      'toolbar-print',
      'toolbar-undo',
      'toolbar-redo',
    ];
    for (var i = 1; i < order.length; i++) {
      expect(left(tester, order[i]), greaterThan(left(tester, order[i - 1])),
          reason: '${order[i]} after ${order[i - 1]}');
    }
    for (final what in ['new', 'open', 'save', 'save-as']) {
      log.clear();
      await tester.tap(byKey('toolbar-$what'));
      await tester.pump();
      // M-ED-3: the file command's run calls the host without settling.
      expect(log, ['settle', what], reason: what);
    }

    await pumpEditor(tester, PlanEditor(controller: c, onExport: (_) {}));
    for (final what in ['new', 'open', 'save', 'save-as']) {
      expect(byKey('toolbar-$what'), findsNothing, reason: what);
    }
    expect(left(tester, 'toolbar-export'), 12, reason: 'the bar\'s padding');
  });

  testWidgets(
      'ED-4 the permissions shape the bar at runtime: export, print and undo '
      'off remove Export, Print, Undo and Redo; full brings them back',
      (tester) async {
    final c = editorController();
    await pumpEditor(tester, PlanEditor(controller: c, onExport: (_) {}));
    for (final k in [
      'toolbar-export',
      'toolbar-print',
      'toolbar-undo',
      'toolbar-redo',
    ]) {
      expect(byKey(k), findsOneWidget, reason: 'premise: $k');
    }
    c.permissions =
        PlanPermissions.full.copyWith(export: false, print: false, undo: false);
    await tester.pump();
    // M-ED-4: `_editCommands` ignores `permissions.undo`.
    for (final k in [
      'toolbar-export',
      'toolbar-print',
      'toolbar-undo',
      'toolbar-redo',
    ]) {
      expect(byKey(k), findsNothing, reason: k);
    }
    expect(left(tester, 'status-text'), 12,
        reason: 'no button left: no toolbar and no gap');
    c.permissions = PlanPermissions.full;
    await tester.pump();
    expect(byKey('toolbar-undo'), findsOneWidget);
    expect(byKey('toolbar-export'), findsOneWidget);
  });

  testWidgets(
      'ED-5 a damaged plan: a warning before the status line, with the '
      'word as its tooltip; none while the plan is sound', (tester) async {
    final c = editorController();
    await pumpEditor(tester, PlanEditor(controller: c));
    expect(byKey('plan-damaged'), findsNothing);
    final statusBefore = left(tester, 'status-text');
    // The controller's flag, set as Task 11's rollback path sets it.
    (c.damaged as ValueNotifier<bool>).value = true;
    await tester.pump();
    // M-ED-5: the bar does not listen to `damaged`.
    expect(byKey('plan-damaged'), findsOneWidget);
    expect(
        tester
            .widget<Tooltip>(find.ancestor(
                of: byKey('plan-damaged'), matching: find.byType(Tooltip)))
            .message,
        _en.planDamaged);
    expect(left(tester, 'status-text'), greaterThan(statusBefore));
  });

  testWidgets(
      'ED-6 another controller handed to the editor: its panels, its canvas '
      'and its page flows are the new controller\'s; the old one\'s guard is '
      'left free', (tester) async {
    final one = editorController();
    final two = editorController();
    final printer = FakePagePrinter()..hold = true;
    await pumpEditor(tester, PlanEditor(controller: one, printer: printer));
    await pumpEditor(tester, PlanEditor(controller: two, printer: printer));
    await tester.tap(byKey('toolbar-print'));
    await tester.pump();
    for (var i = 0; i < 200 && printer.held.isEmpty; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    // M-ED-6: `didUpdateWidget` keeps the old controller's flows.
    expect(two.pageFlows.ready.value, isFalse, reason: 'the new one prints');
    expect(one.pageFlows.ready.value, isTrue);
    expect(
        tester.widget<PlanLayerPanel>(find.byType(PlanLayerPanel)).controller,
        same(two));
    printer.held.single.complete();
    for (var i = 0; i < 200 && !two.pageFlows.ready.value; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(printer.calls, hasLength(1));
  });

  testWidgets(
      'ED-7 PlanEditor(theme:) overrides the ambient extension field by '
      'field inside the editor; the export dialog, a route above it, reads '
      'the ambient one (S-12)', (tester) async {
    const ambient = PlanTheme(canvasBackground: Color(0xFF203040));
    const view = PlanTheme(selectionWidth: 3.5);
    final c = editorController();
    await pumpEditor(
        tester, PlanEditor(controller: c, onExport: (_) {}, theme: view),
        theme: ThemeData(extensions: const [ambient]));
    final inside = tester.element(find.byType(PlanLayerPanel));
    // M-ED-7: the editor wraps nothing in `PlanThemeScope`.
    expect(PlanTheme.of(inside), ambient.merge(view));
    await tester.tap(byKey('toolbar-export'));
    await tester.pump();
    await tester.pump();
    final dialog = byKey('export-dialog');
    expect(dialog, findsOneWidget);
    expect(PlanTheme.of(tester.element(dialog)), ambient,
        reason: 'the view\'s theme is no InheritedTheme');
    await tester.tap(byKey('export-cancel'));
    await tester.pump();
    await tester.pump();
  });
}
```

Create `packages/jet_cad_2d_plan/test/example_test.dart`:

```dart
// The published example (2a spec P7, decision 5): PlanEditor over an empty
// plan with no kit; and the README's code is the example's.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

// The example is not under lib/, so a relative path is the only way to it.
// ignore: avoid_relative_lib_imports
import '../example/main.dart';

void main() {
  testWidgets(
      'ED-8 the example shows the editor over an empty plan with no kit '
      '(a positive control)', (tester) async {
    await tester.pumpWidget(const PlanExampleApp());
    await tester.pump();
    await tester.pump();
    expect(find.byType(PlanEditor), findsOneWidget);
    final state =
        tester.state<PlanExampleAppState>(find.byType(PlanExampleApp));
    expect(state.controller.document.entities.liveCount, 0);
    expect(state.controller.missingKits, isEmpty);
    expect(find.byType(PlanSymbolGallery), findsNothing,
        reason: 'no kit, no symbols');
  });

  test('ED-README the README\'s Dart block is the example, whole', () {
    final readme = File('README.md').readAsStringSync();
    final example = File('example/main.dart').readAsStringSync().trim();
    // M-ED-README: the example changed and the README not.
    expect(readme, contains('```dart\n$example\n```'));
  });
}
```

Create `packages/jet_cad_2d_plan/test/barrel_test.dart` (the idea of `jet_cad_floor_plan/test/host/barrel_test.dart:10-26`, `barrelNames` ported verbatim but for the path):

```dart
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
      'PlanObjectRemoved', 'PlanReplaced', 'PlanSymbolsState',
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
```

Run: `cd packages/jet_cad_2d_plan && flutter test test/editor/plan_editor_test.dart test/example_test.dart test/barrel_test.dart`. Expected: compilation errors (`Error when reading 'lib/src/editor/plan_editor.dart'`, `'example/main.dart'`).

- [ ] **Step 3: The ported tests.** Each file is its source copied with the adaptations listed; **every `expect` is unchanged** (A12) apart from the class names inside expected `toString` texts, which follow the spec's renaming (`FloorPlanEditorBar(…)` → `PlanEditorBar(…)`), a name and not an assertion. Common adaptations for every file below: `FloorPlanController(json: embeddingPlanJson())` / `editorPlanJson()` → `editorController()` (Step 1); `FloorPlanView(controller: c, …)` → `PlanEditor(controller: c, …)` with the same option names where they exist (`editorBar:` → `bar:`, `onExport`, `printer`, `exportName`, `onExportDialog`, `onPageFlowError`, `shortcuts`, `autofocus`, `theme`); `c.cameraController.value = embeddingCamera()` → `c.camera.value = embeddingCamera()`; `c.activeDocument` → `c.document`; `c.activeSelection` → `c.selection`; `c.setMode(FloorPlanMode.design)` and every selection-mode block → dropped (2b); `FloorPlanEditorCapabilities` profiles → `c.permissions` (`full` → `PlanPermissions.full`, `readOnly` → `PlanPermissions.readOnly`, `copyWith` of a flag → the same `copyWith`) or the editor's option for a widget flag (`layerPanel`, `pagePanel`, `selectionPanel` → `propertyPanel`, `symbolPalette` → `gallery`, `rulers`, `grid`, `snapping`), the host rebuilding its view for an option and setting `c.permissions` for a flag; a letter or tool of the floor planner (W, the Wall, Door and Box tools) → the generic `L` and `plan.line` (spec P2: the generic letters are V L P R C A T); the palette's keys are Task 16's `tool-<tool id>` (`tool-plan.line`, …); `tables`, `TableSurvey` and table numbers → the marks of `editorPlanJson()` (`c.catalog.objectsOf<MarkCross>(c.document)`).

**`test/editor/editor_bar_test.dart`** — from `packages/jet_cad_floor_plan/test/host/bars_test.dart`: BC2 (`:326-331`, both values of `export`; `kEditorKeys` and `kEditorEdges` `:44-52`, `:172-190` copied verbatim: the page, the camera and the window are the base's, so the left edges are); BT1's editor half (`:383-411`, through the barrel); BT2's "the editor bar" case (`:427-452`, the design mode only, `validatePlanEditorBar` throwing at build); M-H40's editor test (`:470-490`); the editor half of "the editor bar [print, undo] …" (`:493-510`); "the design mode: no top bar …" (`:601-619`; `canvasIn` measured from `find.byType(PlanEditor)`; the tools `tool-select`, `tool-wall`, `tool-polyline` → `tool-plan.select`, `tool-plan.line`, `tool-plan.polyline`); "the editor bar: leading before the toolbar …" (`:680-700`, with `hostWidgets` `:625-645` and `expectInBar` `:647-651`); T2-b's editor test (`:702-730`, `LogicalKeyboardKey.keyW` → `keyL`); R-5 "the editor bar [snap, zoom] …" (`:1115-1127`, `find.byType(DocumentToolbar)` → the toolbar's key-less row is found as no `toolbar-` key: `expect(find.byWidgetPredicate((w) => w.key is ValueKey<String> && '${(w.key! as ValueKey<String>).value}'.startsWith('toolbar-')), findsNothing)`); and from `page_flows_test.dart` PF5 and PF6 (`:282-340`), their design-mode halves (the chords Cmd+E and Ctrl+E and the bar's Export, through `PlanShortcuts`). Not ported: the service bar's tests (2b), `mergeCandidate` (2b), BC1, BC3 (a bare shell with the app's seven commands; ED-3 pins the host's file commands), the canvas re-measured group (`:998-1090`, mode switches, 2b), T2-c (the idle Undo: Task 8's C tests and Task 16's keys).

**`test/editor/editor_view_test.dart`** — from `test/host/view_test.dart`: V1's design half (`:132-150`: Export and Print and no `toolbar-new`, `-open`, `-save`; `find.byType(PlannerShell)` → `find.byType(PlanEditor)`; `document-name` absent) and V2's design half (`:158-162`). From `test/planner_shell_test.dart`: "a bare shell opens on the empty document and its default page" (`:93-105`: `PlanEditor(controller: PlanController(kits: const []))`; `view.document` → `c.document`; `view.page.value` → `c.page.value`), "the zoom text reads the scale and the fitted zoom" (`:171-185`: `view.camera` → `c.camera`), "the three chrome slots are laid out" (`:187-200`), "the status text shows the tool name and follows the selection" (`:222-247`: the sample flat → `editorPlanJson()`, and the picked wall → `SelectionKey.root(<the first mark>)` set on `c.selection`; the two expected texts `Select` and `Select — 1 selected` are unchanged). From `test/planner_draw_test.dart` (Task 16 sent them here): A16 (`:448-…`, F3 mid-polyline flips the OSNAP read-out and keeps the shape pending) and A27 (`:808-…`, the zoom read-out's scale for a 1:1e20 page parses back exactly), over Task 15's `drawController` in a `PlanEditor`, with the adaptations of Task 16's `palette_draw_test.dart`. The other `planner_shell_test.dart` cases are the canvas's (Task 15) and the keyboard's (Task 16).

**`test/editor/editor_separator_test.dart`** — from `packages/jet_cad_floor_plan/test/host/new_plan_separator_test.dart`, what Task 8 could not port without a view (controller ruling R-m): NS2 (`:260-283`, a view handed another controller reports its language to it) whole, and the `panelShows` assertions Task 8 left out of NS1, NS3, NS4, NS6, NS8 and NS9, each scenario re-run as the source runs it. `show(tester, c, locale)` (`:26-35`) pumps `PlanEditor(controller: c)` in place of `FloorPlanView`, with `planSupportedLocales` and `planLocalizationsDelegates`; `activeDocument` → `document`; `designJson()` → `save()`; `FloorPlanController()` → `PlanController(kits: const [])`; `panelShows` (`:48-51`) reads Task 18's Page panel control (`page-decimal-separator`); `serviceLayoutChanges` lines (2b) and NS3's room label (sub-project 3) stay out, as in Task 8. Every other `expect` unchanged.

**`test/editor/editor_options_test.dart`** — the widget-level capability cases Task 12 sent here:
- From `test/host/editor_panels_test.dart`: T5-g "layerPanel false: no Layers section …" (`:359-394`, the options `layerPanel`, `pagePanel`, `propertyPanel`; `selection-panel` and `table-section` → `find.byType(PlanPropertyPanel)`), "a hidden panel is out of the focus order" (`:396-410`), T5-g "editLayers false … editPage false …" (`:412-496`, through `c.permissions`; `kEmbeddingLocked` → the layer `B` of a `layerPlan`-style locked layer added to `editorPlanJson()`'s scratch document), R-2 (`:561-589`, the three cases: `readOnly`, `tablesOnly` → `PlanPermissions.full.copyWith(editLayers: false)`, none), R-3 "editLayers false alone …" (`:655-675`), R-4 "the Page panel alone" (`:693-703`), and the `readOnly (V-5)` test "no command reaches the document from a pointer path or a key" (`:282-329`), its generic parts: a body drag of a mark, the line's end grips, Delete and Backspace, the letters and Ctrl+Z (the column, the room and the table parts go to sub-project 3 and 2b).
- From `test/host/editor_tools_test.dart`: T4-e (`:599-627`), T4-j's readOnly half "no left column" (`:629-648`, without the mode round trip), T4-f's first part "snapping false: no OSNAP, F3 reaches the host" (`:777-817`, the line drawn near the column's corner → near the first mark's end, the snapped point taken from the mark's generated line), "snapping false keeps the user's setting" (`:819-832`), T4-g's first part "rulers and grid false: no RulerFrame, no grid pixel on the sheet" (`:834-883`, without the mode round trip), K3's design half (`:885-…`: after a `load`, `selectTool` and `deleteSelection` reach the new plan).
- From `test/host/editor_tools_review_test.dart`: RV6 (`:343-354`, Wall → `plan.line`), RV8 (`:373-379`, `tools {select, symbol}` → `PlanPermissions(tools: {'plan.select', 'plan.symbol'})` with `gallery: false`), RV9 (`:381-397`), O23 (`:477-486`), R-2 "Wall part-way: rulers off and on throw nothing …" (`:235-263`, a polyline part-way in place of the wall).

**`test/editor/editor_words_test.dart`** — the design parts Task 9 sent here: SW1 (`test/l10n/shell_words_test.dart:32-47`, the palette, the tabs, the status line and the toolbar in Turkish, through `PlanEditor` with `slowSymbolsKit()` of ED-2 so the tabs show), SW2's design half (`:49-…`, `Strg` in a tooltip and the switch to English; the service bar is 2b's); OV-<code> (`test/l10n/overflow_test.dart:26-82`, "no overflow from 704 px down to 656 px", over `editorPlanJson()` with the OSNAP read-out off; OV-H (`:84-…`) with each mark and the line selected in turn); LK1's editor half (`test/l10n/leak_test.dart:108-183`: the editor, its panels, tabs, menus and dialogs, with `RecordingPlanStrings`; its service-bar lines are 2b's). `test/support/recording_plan_strings.dart` is the port of `floor_plan/test/l10n/recording_strings.dart:1-407` over `PlanStrings` as it stands after this task: `RecordingPlanStrings(this.inner)` with `final PlanStrings inner`, `final Set<String> handedOut`, `String record(String s)`, and one `@override` per `PlanStrings` member, a `String` getter as `record(inner.x)`, a method returning `String` as `record(inner.x(…))`, every other member (`languageCode`, non-`String` results) delegated unrecorded, as the source does; the imports are `package:jet_cad_2d_plan/src/l10n/strings.dart` and the engine's `LayerNameProblem`. And PW1's zoom read-out (`test/l10n/panel_words_test.dart:96`, `find.textContaining('1:12,5 · ')`, which Task 18 left here): `PlanEditor` in Turkish over a plan whose page is at 1:12.5.

**`test/editor/editor_theme_test.dart`** — the view-level groups of `test/host/floor_plan_theme_test.dart` Task 9 sent here, over `PlanTheme`'s four generic fields: "validation (S-5), through the view" (`:573-671`, the width cases: `selectionWidth` accepted and refused naming the field; the opacity, bar, margin, radius, padding and font cases are 2b's fields), "resolution (T-2, S-11)" (`:673-782`, the design mode: P-6, M-H30, the ambient switch; "a bare PlannerShell reads the ambient extension" and R-4 → a `PlanCanvas` alone, which reads `PlanTheme.of` with no scope above, Task 9's rule), "T1-c: the scope notifies by value" (`:784-830`, through `PlanEditor(theme:)`), and "FloorPlanTheme through the barrel alone" (`:997-…`, → `PlanTheme` in `ThemeData(extensions:)` and `PlanEditor(theme:)`). S-12 is ED-7.

**`test/invariants/theme_colours_test.dart`** — from `packages/jet_cad_floor_plan/test/invariants/theme_colours_test.dart`, the three tests (`:160-…`), with `kRoots` (the scanned directories) → `['lib']` of `jet_cad_2d_plan` and the allow-list → this package's allowed literals (the page panel's swatches, `page_panel.dart:39-44`; the layer row's `0xFF000000 |` swatch alpha; the mark of `Colors.transparent` where today's list allows it), each entry still matching (the test's own rule).

Run: `cd packages/jet_cad_2d_plan && flutter test test/editor test/invariants/theme_colours_test.dart`. Expected: compilation errors (the editor does not exist yet).

- [ ] **Step 4: The bar's value types.** Create `packages/jet_cad_2d_plan/lib/src/editor/plan_editor_bar.dart`:

```dart
// 2a spec P2 (`PlanEditor(bar:)`, today's `editorBar`): the editor's top
// bar a host may keep, reorder, cut down, extend or hide. Ported from
// jet_cad_floor_plan/lib/src/host/bars.dart (the editor half, :13-17,
// :73-159; the service bar is 2b's).
import 'package:flutter/foundation.dart' show immutable, listEquals;
import 'package:flutter/widgets.dart' show Widget;

/// The editor's top bar items, in today's left-to-right order: the buttons
/// Export, Print, Undo and Redo at the left; the read-outs at the right,
/// the object snap's (`snap`, which F3 toggles) and the zoom's (`zoom`).
/// The status line keeps the flexible middle.
enum PlanEditorAction { export, print, undo, redo, snap, zoom }

/// The editor's top bar.
///
/// - [visible]: false removes the bar; the canvas takes its height and the
///   tools stay in the left panel.
/// - [actions]: the items shown, in this order. The buttons lie at the
///   left, after the host's file commands, with 12 logical pixels between
///   a file button and an edit button; the read-outs lie at the right, 16
///   pixels apart. Export shows only with `PlanEditor.onExport`. An action
///   listed twice is an [ArgumentError] when the editor builds.
/// - [leading], [trailing]: the host's widgets at the bar's two ends, laid
///   out in its row at its height (each needs a bounded width). A host
///   text field there takes the focus and its keystrokes: the tool
///   letters, Undo, Redo and Escape stay in the field; the file chords and
///   F3 still act on the plan from it.
///
/// [actions] shapes the bar only: the chords and keys stay bound whatever
/// it lists.
@immutable
final class PlanEditorBar {
  const PlanEditorBar({
    this.visible = true,
    this.actions = PlanEditorAction.values,
    this.leading = const <Widget>[],
    this.trailing = const <Widget>[],
  });

  final bool visible;
  final List<PlanEditorAction> actions;
  final List<Widget> leading;
  final List<Widget> trailing;

  @override
  bool operator ==(Object other) =>
      other is PlanEditorBar &&
      other.visible == visible &&
      listEquals(other.actions, actions) &&
      listEquals(other.leading, leading) &&
      listEquals(other.trailing, trailing);

  @override
  int get hashCode => Object.hash(visible, Object.hashAll(actions),
      Object.hashAll(leading), Object.hashAll(trailing));

  @override
  String toString() => 'PlanEditorBar(${[
        if (!visible) 'visible: false',
        if (!listEquals(actions, PlanEditorAction.values))
          'actions: [${actions.map((a) => a.name).join(', ')}]',
        if (leading.isNotEmpty)
          'leading: [${leading.map((w) => w.toStringShort()).join(', ')}]',
        if (trailing.isNotEmpty)
          'trailing: [${trailing.map((w) => w.toStringShort()).join(', ')}]',
      ].join(', ')})';
}

/// Throws an [ArgumentError] naming `actions` for a bar that lists an
/// action twice; called when the editor builds (bars.dart:146-159).
void validatePlanEditorBar(PlanEditorBar bar) {
  if (bar.actions.toSet().length != bar.actions.length) {
    throw ArgumentError.value(
        bar.actions, 'actions', 'must not list an action twice');
  }
}
```

- [ ] **Step 5: The four file-command words.** In Task 9's `lib/src/l10n/strings.dart`, beside `undo` and `redo`:

```dart
  /// The host's file commands (2a spec P2, `PlanEditor(onNew:, onOpen:,
  /// onSave:, onSaveAs:)`), as the floor planner app words them.
  String get newDocument;
  String get open;
  String get save;
  String get saveAs;
```

with, from `apps/floor_planner/lib/app_strings.dart` verbatim: English `'New'`, `'Open…'`, `'Save'`, `'Save As…'` (`:77-89`); German `'Neu'`, `'Öffnen…'`, `'Speichern'`, `'Speichern unter…'` (`:135-147`); Turkish `'Yeni'`, `'Aç…'`, `'Kaydet'`, `'Farklı kaydet…'` (`:198-210`). In Task 9's `test/l10n/value_words_test.dart`, after Task 18's LP-W:

```dart
  test('ED-W the file commands\' words in each language', () {
    // M-ED-W: a language that returns the English text for one of them.
    expectWorded((s) => s.newDocument, english: 'New');
    expectWorded((s) => s.open, english: 'Open…');
    expectWorded((s) => s.save, english: 'Save');
    expectWorded((s) => s.saveAs, english: 'Save As…');
  });
```

- [ ] **Step 6: The editor.** Create `packages/jet_cad_2d_plan/lib/src/editor/plan_editor.dart`:

```dart
// 2a spec P2 (PlanEditor) and P7: today's editor layout over one
// PlanController: the top bar; the palette or the gallery on the left; the
// canvas; the property, layer and page panels on the right. Ported from
// jet_cad_floor_plan/lib/src/planner_shell.dart (build :1421-1611, the top
// bar :1278-1412, the left panel :1222-1276, the relay :1708-1752, the
// command flags :714-735 and :801-818), host/floor_plan_view.dart (the
// design branch of `_modes`, `_flowsFor`, PlannerTextKeys and the theme
// scope), document_toolbar.dart and shell_commands.dart:61-169.
import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show ValueListenable, defaultTargetPlatform, listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;
import 'package:jet_cad_2d/jet_cad_2d.dart' show zoomOf;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show kLogicalPixelsPerMm;

import '../canvas/plan_canvas.dart';
import '../controller/plan_controller.dart';
import '../export/editor_page_flows.dart';
import '../export/export_dialog.dart';
import '../export/page_printer.dart';
import '../export/registries.dart';
import '../l10n/locale_scope.dart';
import '../l10n/number_text.dart';
import '../l10n/strings.dart';
import '../panels/plan_layer_panel.dart';
import '../panels/plan_page_panel.dart';
import '../panels/plan_property_panel.dart';
import '../panels/plan_symbol_gallery.dart';
import '../shortcuts/plan_shortcut_guard.dart';
import '../shortcuts/plan_shortcuts.dart';
import '../symbols/plan_symbol.dart';
import '../theme/plan_theme.dart';
import '../tools/generic_tools.dart';
import 'plan_editor_bar.dart';
import 'plan_tool_palette.dart';

/// A host's file command: called after the editor settles pending input.
typedef PlanFileCallback = Future<void> Function();

/// The design-mode editor over [controller] (2a spec P2): the top bar
/// ([bar]); the tool palette, or the Tools and Symbols tabs when a loaded
/// kit has symbols, on the left; the canvas; the property, layer and page
/// panels on the right. Every widget in it takes only the controller.
///
/// The bar's Export (only with [onExport]) and Print run the controller's
/// flows: the dialog ([onExportDialog] when given), the remembered answer,
/// one flow at a time, errors to [onPageFlowError] (or out of the dropped
/// `Future` without it). [onNew], [onOpen], [onSave] and [onSaveAs] are
/// the host's, offered as buttons and chords only when given. Which
/// buttons exist follows `controller.permissions` (`export`, `print`,
/// `undo`) at each build.
class PlanEditor extends StatefulWidget {
  const PlanEditor({
    super.key,
    required this.controller,
    this.toolPalette = true,
    this.gallery = true,
    this.symbolFilter,
    this.propertyPanel = true,
    this.layerPanel = true,
    this.pagePanel = true,
    this.rulers = true,
    this.grid = true,
    this.snapping = true,
    this.bar = const PlanEditorBar(),
    this.onNew,
    this.onOpen,
    this.onSave,
    this.onSaveAs,
    this.onExport,
    this.onExportDialog,
    this.onPageFlowError,
    this.printer,
    this.exportName = 'plan',
    this.shortcuts = true,
    this.autofocus = true,
    this.theme,
  });

  final PlanController controller;

  /// Whether the left column offers the tool palette.
  final bool toolPalette;

  /// Whether the left column offers the Symbols tab (today's
  /// `symbolPalette`), when a loaded kit has symbols.
  final bool gallery;

  /// The gallery's filter (today's `symbolFilter`), read at each build.
  final bool Function(PlanSymbol symbol)? symbolFilter;

  /// Which right-column panels show; a hidden one is kept offstage with its
  /// state and out of the focus order.
  final bool propertyPanel;
  final bool layerPanel;
  final bool pagePanel;

  /// The canvas's options.
  final bool rulers;
  final bool grid;
  final bool snapping;

  final PlanEditorBar bar;

  final PlanFileCallback? onNew;
  final PlanFileCallback? onOpen;
  final PlanFileCallback? onSave;
  final PlanFileCallback? onSaveAs;

  /// Receives Export's bytes; without it Export is not offered.
  final void Function(PlanExport export)? onExport;

  /// The host's export dialog, in place of the Material one.
  final PlanExportDialog? onExportDialog;

  /// Where an Export or Print flow's error goes.
  final void Function(Object error)? onPageFlowError;

  /// The platform's print dialog when null.
  final PagePrinter? printer;

  /// Exports are named `<exportName>.<extension>`.
  final String exportName;

  /// False binds no key at all: every key reaches the host.
  final bool shortcuts;

  /// Whether the canvas takes the focus when it is first built.
  final bool autofocus;

  /// A per-view theme over the ambient `PlanTheme`, field by field.
  final PlanTheme? theme;

  @override
  State<PlanEditor> createState() => _PlanEditorState();
}

enum _LeftTab { tools, symbols }

class _PlanEditorState extends State<PlanEditor> {
  late EditorPageFlows _flows = _flowsFor(widget.controller);

  /// The gallery's search text, kept across tab switches.
  final TextEditingController _symbolQuery = TextEditingController();

  _LeftTab _leftTab = _LeftTab.tools;

  /// The document the relays and flags below are built over.
  Object? _bound;
  _FrameSafeRelay? _status;
  _FrameSafeRelay? _commandSources;
  _Flag? _idleFlag;
  _Flag? _pageFlag;
  _Flag? _undoFlag;
  _Flag? _redoFlag;

  EditorPageFlows _flowsFor(PlanController c) => EditorPageFlows(
        controller: c,
        settings: () => (
          onExport: widget.onExport,
          printer: widget.printer ?? const PrintingPagePrinter(),
          exportName: widget.exportName,
        ),
        hooks: () => (
          exportDialog: widget.onExportDialog,
          onError: widget.onPageFlowError,
        ),
      );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onController);
    _bind();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    PlanLocaleScope.push(context, widget.controller);
  }

  @override
  void didUpdateWidget(PlanEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
      _flows.dispose();
      _flows = _flowsFor(widget.controller);
      _bind();
      PlanLocaleScope.push(context, widget.controller);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _flows.dispose();
    _unbind();
    _symbolQuery.dispose();
    super.dispose();
  }

  /// A swapped document (its selection, tools and page are new) rebinds;
  /// new permissions rebuild the bar and the columns.
  void _onController() {
    if (!identical(_bound, widget.controller.document)) _bind();
    if (mounted) setState(() {});
  }

  void _bind() {
    _unbind();
    final c = widget.controller;
    _bound = c.document;
    _status = _FrameSafeRelay(Listenable.merge([c.selection, c.toolController]));
    final sources = _commandSources = _FrameSafeRelay(Listenable.merge(
        [c.toolController, c.canUndo, c.canRedo, c.page, c.pageFlows.ready]));
    _idleFlag = _Flag(sources, () => _idle);
    _pageFlag = _Flag(sources,
        () => _idle && c.page.value != null && c.pageFlows.ready.value);
    _undoFlag = _Flag(sources, () => _idle && c.canUndo.value);
    _redoFlag = _Flag(sources, () => _idle && c.canRedo.value);
  }

  void _unbind() {
    for (final f in [_idleFlag, _pageFlag, _undoFlag, _redoFlag]) {
      f?.dispose();
    }
    _status?.dispose();
    _commandSources?.dispose();
    _idleFlag = _pageFlag = _undoFlag = _redoFlag = null;
    _status = _commandSources = null;
  }

  /// No tool is part-way through a shape (planner_shell.dart:714-718): a
  /// toolbar click is a pointer event no tool sees, so the commands wait.
  bool get _idle => !widget.controller.toolController.active.isMidShape;

  /// The host's [pick] of the current widget, after a settle.
  Future<void> Function() _file(PlanFileCallback? Function(PlanEditor w) pick) =>
      () async {
        final callback = pick(widget);
        if (callback == null) return;
        widget.controller.settlePendingInput();
        await callback();
      };

  List<_BarCommand> _fileCommands(PlanStrings s) {
    final w = widget;
    final permissions = w.controller.permissions;
    return [
      if (w.onNew != null)
        _BarCommand(
            id: 'new',
            label: s.newDocument,
            icon: Icons.note_add_outlined,
            shortcuts: kNewChords,
            enabled: _idleFlag!,
            run: _file((w) => w.onNew)),
      if (w.onOpen != null)
        _BarCommand(
            id: 'open',
            label: s.open,
            icon: Icons.folder_open_outlined,
            shortcuts: kOpenChords,
            enabled: _idleFlag!,
            run: _file((w) => w.onOpen)),
      if (w.onSave != null)
        _BarCommand(
            id: 'save',
            label: s.save,
            icon: Icons.save_outlined,
            shortcuts: kSaveChords,
            enabled: _idleFlag!,
            run: _file((w) => w.onSave)),
      if (w.onSaveAs != null)
        _BarCommand(
            id: 'save-as',
            label: s.saveAs,
            icon: Icons.save_as_outlined,
            shortcuts: kSaveAsChords,
            enabled: _idleFlag!,
            run: _file((w) => w.onSaveAs)),
      if (_flows.canExport && permissions.export)
        _BarCommand(
            id: 'export',
            label: s.exportEllipsis,
            icon: Icons.ios_share_outlined,
            shortcuts: kExportChords,
            enabled: _pageFlag!,
            run: () => _flows.export(context)),
      if (permissions.print)
        _BarCommand(
            id: 'print',
            label: s.printEllipsis,
            icon: Icons.print_outlined,
            shortcuts: kPrintChords,
            enabled: _pageFlag!,
            run: () => _flows.print(context)),
    ];
  }

  List<_BarCommand> _editCommands(PlanStrings s) =>
      widget.controller.permissions.undo
          ? [
              _BarCommand(
                  id: 'undo',
                  label: s.undo,
                  icon: Icons.undo,
                  shortcuts: kUndoChords,
                  enabled: _undoFlag!,
                  run: () async => widget.controller.undo()),
              _BarCommand(
                  id: 'redo',
                  label: s.redo,
                  icon: Icons.redo,
                  shortcuts: kRedoChords,
                  enabled: _redoFlag!,
                  run: () async => widget.controller.redo()),
            ]
          : const [];

  static _BarCommand? _byId(List<_BarCommand> commands, String id) =>
      commands.where((c) => c.id == id).firstOrNull;

  /// [command] for `PlanShortcuts`: its chord invokes the command, which
  /// does nothing while it is disabled (the key is still consumed, S-26).
  static Future<void> Function()? _chord(_BarCommand? command) =>
      command == null ? null : () async => command.invoke();

  /// The toolbar for a host's [actions] (planner_shell.dart:1384-1412): the
  /// host's file commands first (New to Save As), then the buttons in the
  /// host's order, a run of file buttons (Export, Print) and a run of edit
  /// buttons (Undo, Redo) [_Toolbar.groupGap] apart. Null with no button.
  _Toolbar? _toolbarFor(List<PlanEditorAction> actions,
      List<_BarCommand> file, List<_BarCommand> edit) {
    const page = {'export', 'print'};
    final groups = <List<_BarCommand>>[
      [
        for (final c in file)
          if (!page.contains(c.id)) c
      ],
    ];
    bool? lastFile = groups.first.isEmpty ? null : true;
    for (final action in actions) {
      final (command, isFile) = switch (action) {
        PlanEditorAction.export => (_byId(file, 'export'), true),
        PlanEditorAction.print => (_byId(file, 'print'), true),
        PlanEditorAction.undo => (_byId(edit, 'undo'), false),
        PlanEditorAction.redo => (_byId(edit, 'redo'), false),
        _ => (null, false),
      };
      if (command == null) continue;
      if (isFile != lastFile) groups.add([]);
      lastFile = isFile;
      groups.last.add(command);
    }
    if (groups.every((g) => g.isEmpty)) return null;
    return _Toolbar(groups: groups);
  }

  String _statusLine(PlanStrings strings) {
    final c = widget.controller;
    final base = planToolLabel(context, c, c.activeTool.value);
    final n = c.selection.length;
    return n == 0 ? base : '$base — ${strings.selectedCount(n)}';
  }

  String _zoomLine(PlanStrings strings) {
    final c = widget.controller;
    final page = c.page.value;
    if (page == null) return '';
    final zoom = zoomOf(c.camera.value.scale, page, kLogicalPixelsPerMm);
    final scale = formatPanelNumber(page.scaleDenominator, strings);
    return '1:$scale · ${(zoom * 100).round()}%';
  }

  /// The top bar (planner_shell.dart:1278-1376 without the document name):
  /// the host's leading widgets; the toolbar; 16 px; the damaged warning
  /// and the status line, flexible; the read-outs; the host's trailing
  /// widgets. The host's widgets sit under the shortcut guard, never in
  /// the toolbar's `ExcludeFocus`.
  Widget _topBar(ColorScheme scheme, PlanStrings strings,
      List<_BarCommand> file, List<_BarCommand> edit) {
    final c = widget.controller;
    final bar = widget.bar;
    final toolbar = listEquals(bar.actions, PlanEditorAction.values)
        ? (file.isEmpty && edit.isEmpty
            ? null
            : _Toolbar(groups: [file, edit]))
        : _toolbarFor(bar.actions, file, edit);
    final readOuts = <Widget>[];
    for (final action in bar.actions) {
      final readOut = switch (action) {
        PlanEditorAction.snap when !widget.snapping => null,
        PlanEditorAction.snap => ListenableBuilder(
            listenable: c.snap,
            builder: (_, __) => Text(
                c.snap.objectSnap
                    ? strings.objectSnapOn
                    : strings.objectSnapOff,
                key: const Key('osnap-text')),
          ),
        PlanEditorAction.zoom => ListenableBuilder(
            listenable: Listenable.merge([c.camera, c.page]),
            builder: (_, __) =>
                Text(_zoomLine(strings), key: const Key('zoom-text')),
          ),
        _ => null,
      };
      if (readOut == null) continue;
      if (readOuts.isNotEmpty) readOuts.add(const SizedBox(width: 16));
      readOuts.add(readOut);
    }
    final row = Row(
      children: [
        ...bar.leading,
        if (toolbar != null) ...[toolbar, const SizedBox(width: 16)],
        Expanded(
          child: LayoutBuilder(builder: (_, constraints) {
            final tail = math.min(16.0, constraints.maxWidth);
            return Row(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: c.damaged,
                  builder: (_, damaged, __) => damaged
                      ? Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Tooltip(
                            message: strings.planDamaged,
                            child: Icon(Icons.warning_amber,
                                key: const Key('plan-damaged'),
                                size: 18,
                                color: scheme.error),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                Expanded(
                  child: ListenableBuilder(
                    listenable: _status!,
                    builder: (_, __) => Text(_statusLine(strings),
                        key: const Key('status-text'),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis),
                  ),
                ),
                SizedBox(width: tail),
              ],
            );
          }),
        ),
        ...readOuts,
        ...bar.trailing,
      ],
    );
    return Container(
      key: const Key('chrome-top'),
      height: 44,
      color: scheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: bar.leading.isEmpty && bar.trailing.isEmpty
            ? row
            : PlanShortcutGuard(controller: c, child: row),
      ),
    );
  }

  /// A loaded kit has a symbol source and the host offers the gallery.
  bool get _gallery =>
      widget.gallery &&
      widget.controller.kits.kits.any((k) => k.symbols.isNotEmpty);

  /// The left column holds more than the Select row (spec S-13): the
  /// Symbols tab, or a palette with another allowed tool.
  bool get _leftShown {
    final c = widget.controller;
    if (_gallery) return true;
    if (!widget.toolPalette) return false;
    final ids = [
      for (final g in genericTools) g.id,
      for (final k in c.kits.kits)
        for (final t in k.tools) t.id,
    ];
    return ids.any((id) =>
        id != PlanToolIds.select &&
        id != PlanToolIds.symbol &&
        c.permissions.allowsTool(id));
  }

  /// The palette alone, or the Tools and Symbols tabs over the chosen one
  /// (planner_shell.dart:1222-1276). The strip never takes focus; switching
  /// tabs changes no tool.
  Widget _leftPanel(PlanStrings strings) {
    final c = widget.controller;
    if (!_gallery) return PlanToolPalette(controller: c);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: ExcludeFocus(
            child: SegmentedButton<_LeftTab>(
              key: const Key('left-tabs'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: _LeftTab.tools,
                    label: Text(strings.tabTools, key: const Key('tab-tools'))),
                ButtonSegment(
                    value: _LeftTab.symbols,
                    label: Text(strings.tabSymbols,
                        key: const Key('tab-symbols'))),
              ],
              selected: {_leftTab},
              onSelectionChanged: (s) => setState(() => _leftTab = s.single),
            ),
          ),
        ),
        Expanded(
          child: switch (_leftTab) {
            _LeftTab.tools => PlanToolPalette(controller: c),
            _LeftTab.symbols => PlanSymbolGallery(
                controller: c,
                filter: widget.symbolFilter,
                query: _symbolQuery),
          },
        ),
      ],
    );
  }

  /// A right-column panel: shown while [shown]; otherwise kept offstage,
  /// its state kept, and out of the focus order.
  static Widget _kept(bool shown, Widget panel) =>
      Visibility(visible: shown, maintainState: true, child: panel);

  @override
  Widget build(BuildContext context) {
    validatePlanEditorBar(widget.bar);
    final c = widget.controller;
    final scheme = Theme.of(context).colorScheme;
    final strings = PlanStrings.of(context);
    final file = _fileCommands(strings);
    final edit = _editCommands(strings);
    return PlanTextKeys(
      child: PlanThemeScope(
        view: widget.theme,
        child: PlanShortcuts(
          controller: c,
          shortcuts: widget.shortcuts,
          onNew: _chord(_byId(file, 'new')),
          onOpen: _chord(_byId(file, 'open')),
          onSave: _chord(_byId(file, 'save')),
          onSaveAs: _chord(_byId(file, 'save-as')),
          onExport: _chord(_byId(file, 'export')),
          onPrint: _chord(_byId(file, 'print')),
          child: Scaffold(
            body: Column(
              children: [
                if (widget.bar.visible) _topBar(scheme, strings, file, edit),
                Expanded(
                  child: Row(
                    children: [
                      if (_leftShown)
                        Container(
                          key: const Key('chrome-left'),
                          width: 240,
                          color: scheme.surfaceContainerLow,
                          child: _leftPanel(strings),
                        ),
                      // Keyed: when the columns on both sides come or go at
                      // once, the row still matches the canvas, so the
                      // camera and the user's zoom stay.
                      Expanded(
                        key: const Key('chrome-canvas'),
                        child: PlanCanvas(
                          controller: c,
                          rulers: widget.rulers,
                          grid: widget.grid,
                          snapping: widget.snapping,
                          autofocus: widget.autofocus,
                        ),
                      ),
                      if (widget.propertyPanel ||
                          widget.layerPanel ||
                          widget.pagePanel)
                        Container(
                          key: const Key('chrome-right'),
                          width: 280,
                          color: scheme.surfaceContainerLow,
                          child: PlanShortcutGuard(
                            controller: c,
                            child: SingleChildScrollView(
                              key: const Key('chrome-right-scroll'),
                              child: Column(
                                children: [
                                  _kept(widget.propertyPanel,
                                      PlanPropertyPanel(controller: c)),
                                  _kept(widget.layerPanel,
                                      PlanLayerPanel(controller: c)),
                                  _kept(widget.pagePanel,
                                      PlanPagePanel(controller: c)),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One command of the bar (shell_commands.dart:61-133): invoked only
/// through [invoke], by its button and its chords alike; a disabled
/// command's chord stays bound and does nothing.
@immutable
final class _BarCommand {
  const _BarCommand({
    required this.id,
    required this.label,
    required this.icon,
    this.shortcuts = const <SingleActivator>[],
    required this.enabled,
    required this.run,
  });

  /// The button's key is `toolbar-<id>`.
  final String id;
  final String label;
  final IconData icon;
  final List<SingleActivator> shortcuts;
  final ValueListenable<bool> enabled;
  final Future<void> Function() run;

  /// The label and the first chord's glyph on [platform] (`⌘S` on macOS,
  /// `Ctrl+S` elsewhere, the modifiers in the UI's language).
  String tooltipFor(TargetPlatform platform,
      {String control = 'Ctrl', String shift = 'Shift'}) {
    if (shortcuts.isEmpty) return label;
    final chord = shortcuts.first;
    final key = chord.trigger.keyLabel;
    final glyph = platform == TargetPlatform.macOS
        ? '⌘${chord.shift ? '⇧' : ''}$key'
        : '$control+${chord.shift ? '$shift+' : ''}$key';
    return '$label ($glyph)';
  }

  void invoke() {
    if (!enabled.value) return;
    unawaited(run());
  }
}

/// The toolbar (document_toolbar.dart:23-98): one icon button per command,
/// keyed `toolbar-<id>`, a [groupGap] between two non-empty groups. It
/// never takes focus and sits inside a [TextFieldTapRegion], so a press is
/// not a tap outside an open text entry.
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.groups});

  final List<List<_BarCommand>> groups;

  static const double groupGap = 12;

  @override
  Widget build(BuildContext context) {
    final strings = PlanStrings.of(context);
    final children = <Widget>[];
    for (final group in groups) {
      if (group.isEmpty) continue;
      if (children.isNotEmpty) children.add(const SizedBox(width: groupGap));
      for (final c in group) {
        children.add(ValueListenableBuilder<bool>(
          valueListenable: c.enabled,
          builder: (context, enabled, _) => IconButton(
            key: Key('toolbar-${c.id}'),
            tooltip: c.tooltipFor(defaultTargetPlatform,
                control: strings.controlKey, shift: strings.shiftKey),
            icon: Icon(c.icon),
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            onPressed: enabled ? c.invoke : null,
          ),
        ));
      }
    }
    return TextFieldTapRegion(
      child: ExcludeFocus(
        child: Material(
          color: Colors.transparent,
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

/// A flag computed from other state (shell_commands.dart:129-169): its
/// value is [_compute]'s answer at the read; listeners hear when that
/// answer changes.
final class _Flag extends ChangeNotifier implements ValueListenable<bool> {
  _Flag(this._source, this._compute) {
    _last = _compute();
    _source.addListener(_update);
  }

  final Listenable _source;
  final bool Function() _compute;
  late bool _last;

  @override
  bool get value => _compute();

  void _update() {
    final now = _compute();
    if (now == _last) return;
    _last = now;
    notifyListeners();
  }

  @override
  void dispose() {
    _source.removeListener(_update);
    super.dispose();
  }
}

/// A [_source]'s notifications, held for after the frame when they arrive
/// during one (planner_shell.dart:1694-1752): the canvas re-parents during
/// its build when the rulers come or go, and its tools and selection then
/// notify; a widget outside it marked dirty would assert.
final class _FrameSafeRelay extends ChangeNotifier {
  _FrameSafeRelay(this._source) {
    _source.addListener(_onSource);
  }

  final Listenable _source;
  bool _held = false;
  bool _due = false;
  bool _disposed = false;

  void _onSource() {
    final binding = SchedulerBinding.instance;
    if (binding.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      _held = false;
      notifyListeners();
      return;
    }
    _held = true;
    if (_due) return;
    _due = true;
    binding.addPostFrameCallback((_) {
      _due = false;
      if (_disposed || !_held) return;
      _held = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _source.removeListener(_onSource);
    super.dispose();
  }
}
```

- [ ] **Step 7: The barrel.** Rewrite `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` so that every `export` line carries a `show` list naming exactly the names of ED-9's set that its file defines (the files are those Tasks 6-19 exported, each now with `show`), and add:

```dart
export 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show SymbolThumbnails;
export 'src/editor/plan_editor.dart' show PlanEditor, PlanFileCallback;
export 'src/editor/plan_editor_bar.dart' show PlanEditorAction, PlanEditorBar;
```

The files earlier tasks exported whole get these `show` lists (the names of their tasks' Produces blocks; ED-9 holds each):

```dart
export 'src/controller/plan_controller.dart'
    show PlanController, kPlanThumbnailCapacity;
export 'src/file/plan_file.dart' show decodePlan, encodePlan, ensureManifest;
export 'src/file/plan_format_exception.dart'
    show PlanFormatCode, PlanFormatException;
export 'src/kits/kit_set.dart'
    show KitSet, KitSetError, reservedKitIds, validateKitSet;
```

Task 7's `manifest.dart` (`ManifestCheck`, `PlanManifest`, `checkManifest`, `kPlanFormat`, `manifestOf`, `manifestToWrite`, `usedKits`), Task 8's `camera_bounds.dart` (`kPlanMaxScale`, `kPlanMinScale`) and Task 16's `plan_shortcut_guard.dart` (`PlanShortcutGuard`) already carry their `show` lists; keep them.

(`SymbolThumbnails` is `PlanController(thumbnails:)`'s type: a host sharing one cache across controllers names it, P7's "a shared loader and cache".) A name an earlier task exported that is not in ED-9's set is not dropped silently: report it, and the coordinator rules whether ED-9's set or the export changes.

- [ ] **Step 8: The example, the README and the CHANGELOG.** Create `packages/jet_cad_2d_plan/example/main.dart`:

```dart
// PlanEditor over an empty plan with no kit: the plan library's own tools,
// the layers and the page. Run from the package directory with
// `flutter run -t example/main.dart`.
import 'package:flutter/material.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensurePlanFonts();
  registerFontLicences();
  runApp(const PlanExampleApp());
}

class PlanExampleApp extends StatefulWidget {
  const PlanExampleApp({super.key});

  @override
  State<PlanExampleApp> createState() => PlanExampleAppState();
}

class PlanExampleAppState extends State<PlanExampleApp> {
  /// One plan and no kit: a kit package adds its types, tools and symbols
  /// through `PlanController(kits: [...])`.
  final PlanController controller = PlanController(kits: const []);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        supportedLocales: planSupportedLocales,
        localizationsDelegates: planLocalizationsDelegates,
        home: Scaffold(body: PlanEditor(controller: controller)),
      );
}
```

Replace `packages/jet_cad_2d_plan/README.md` (Task 6's placeholder) with the text below, whose one Dart block is `example/main.dart` whole, byte for byte (ED-README):

````markdown
# jet_cad_2d_plan

The plan library of jet_cad_2d. A `PlanController` owns one plan — its
document, the parametric system over it, the camera, the selection, the
tools, the undo history — and the design-mode widgets take only the
controller: `PlanCanvas`, `PlanToolPalette`, `PlanSymbolGallery`,
`PlanPropertyPanel`, `PlanLayerPanel`, `PlanPagePanel` and `PlanShortcuts`,
or `PlanEditor`, which lays them out as one editor.

What a plan holds beyond lines and shapes comes from **kits**
(`package:jet_cad_2d_kit`): their parametric types, tools, attachment
providers and symbol libraries. The library knows no domain. A plan that
names a kit the host did not load opens, draws and saves its objects
unchanged, and locks them; a kit whose code fails is contained to the
objects it broke.

## Use

```dart
<example/main.dart, whole>
```

- `PlanController.save()` and `load(text)` read and write a plan;
  `export('plan.pdf' or 'plan.png', choice)` and `print(choice)` make its
  page's bytes; a host adds its own exporters and importers.
- `PlanPermissions` decide what the editor lets a user change.
- The kit author's contract is `docs/kits.md` in the repository.

Version 0.8.0 is unreleased: it ships with the kits of the next wave.
````

(Replace the `<example/main.dart, whole>` line with the file's text.)

Replace `packages/jet_cad_2d_plan/CHANGELOG.md` with:

```markdown
## 0.8.0 (unreleased)

The plan library of jet_cad_2d, in design mode (sub-project 2a).

- `PlanController`: one plan and every system over it; `newPlan`, `load`,
  `save`, `dirty`, `markSaved`; undo and redo (waiting while a tool is
  part-way through a shape); tools by id; `deleteSelection`; the camera;
  a `Stream<PlanChange>`; diagnostics; `missingKits`, `locked`, `damaged`.
- Kits: the kit set validated as a whole; the plan manifest
  (`jetcad.manifest`) written and checked; a missing kit's objects opened,
  drawn, locked and saved unchanged; a kit hook that fails contained by the
  guarding adapter, its objects frozen and locked.
- `PlanPermissions` (`full`, `readOnly`, per-tool and per-action flags),
  enforced at the select gates, the palette, the panels and the bar.
- Symbol libraries loaded asynchronously by `PlanSymbolLoader`, shareable
  across controllers; the gallery.
- Attachment of symbols through the kits' providers; `plan.symbol`.
- Export and import registries: `plan.pdf` and `plan.png` built in, a
  host's own beside them; printing.
- The widgets: `PlanCanvas`, `PlanToolPalette`, `PlanSymbolGallery`,
  `PlanPropertyPanel`, `PlanLayerPanel`, `PlanPagePanel`, `PlanShortcuts`,
  and `PlanEditor` with `PlanEditorBar`.
- Words in English, German and Turkish; `PlanTheme`; the bundled Roboto.
```

- [ ] **Step 9: Run the tests.** Run: `cd packages/jet_cad_2d_plan && flutter test`. Expected: `All tests passed!`. Then `cd packages/jet_cad_2d_plan && flutter run -d flutter-tester -t example/main.dart` is **not** run (it does not exit); the example is ED-8's.

- [ ] **Step 10: The gates.** `cd packages/jet_cad_2d_plan && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, format exit 0. Then, after the commit (a dry run warns about uncommitted files), `cd packages/jet_cad_2d_plan && dart pub publish --dry-run`: exit 0 and `Package has 0 warnings.` (the README and the example are what pub.dev scores). **Never** without `--dry-run`. `git status --short` shows only this task's files before the commit.

- [ ] **Step 11: Commit.**

```bash
git add packages/jet_cad_2d_plan/lib/src/editor/plan_editor_bar.dart packages/jet_cad_2d_plan/lib/src/editor/plan_editor.dart packages/jet_cad_2d_plan/lib/src/l10n/strings.dart packages/jet_cad_2d_plan/lib/src/l10n/strings_en.dart packages/jet_cad_2d_plan/lib/src/l10n/strings_de.dart packages/jet_cad_2d_plan/lib/src/l10n/strings_tr.dart packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart packages/jet_cad_2d_plan/example/main.dart packages/jet_cad_2d_plan/README.md packages/jet_cad_2d_plan/CHANGELOG.md packages/jet_cad_2d_plan/test/support/editor_host.dart packages/jet_cad_2d_plan/test/editor/plan_editor_test.dart packages/jet_cad_2d_plan/test/editor/editor_bar_test.dart packages/jet_cad_2d_plan/test/editor/editor_view_test.dart packages/jet_cad_2d_plan/test/editor/editor_options_test.dart packages/jet_cad_2d_plan/test/editor/editor_words_test.dart packages/jet_cad_2d_plan/test/editor/editor_theme_test.dart packages/jet_cad_2d_plan/test/invariants/theme_colours_test.dart packages/jet_cad_2d_plan/test/l10n/value_words_test.dart packages/jet_cad_2d_plan/test/example_test.dart packages/jet_cad_2d_plan/test/barrel_test.dart packages/jet_cad_2d_plan/test/support/recording_plan_strings.dart packages/jet_cad_2d_plan/test/editor/editor_separator_test.dart
git commit -m "$(cat <<'EOF'
feat(plan): PlanEditor, PlanEditorBar, the example and the README

Today's editor layout over one PlanController: the bar (the host's file
commands, Export, Print, Undo, Redo by the permissions, the status line,
the damaged warning, the read-outs), the palette or the Tools and Symbols
tabs, the canvas, and the property, layer and page panels, with the
options of spec P2. The barrel shows exactly the public API; the example
is an editor over an empty plan with no kit, and the README shows it.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 12: Mutation check** (on the committed files; after each, `git checkout -- <file>` and `git diff --quiet -- <file>` exits 0):
  - M-ED-1: in `plan_editor.dart`'s right column, swap `_kept(widget.layerPanel, …)` and `_kept(widget.pagePanel, …)` → ED-1 red.
  - M-ED-2: `_gallery` drops `widget.gallery &&` → ED-2 red.
  - M-ED-3: in `_file`, delete `widget.controller.settlePendingInput();` → ED-3 red.
  - M-ED-4: `_editCommands` drops the `widget.controller.permissions.undo ?` test (always the two commands) → ED-4 red.
  - M-ED-5: the `ValueListenableBuilder<bool>` over `c.damaged` builds `const SizedBox.shrink()` always → ED-5 red.
  - M-ED-6: in `didUpdateWidget`, delete `_flows.dispose(); _flows = _flowsFor(widget.controller);` → ED-6 red.
  - M-ED-7: in `build`, `PlanThemeScope(view: widget.theme, child: …)` becomes its child alone → ED-7 red.
  - M-ED-9: in the barrel, drop the `show …` of one export → ED-9 red.
  - M-ED-README: add a comment line to `example/main.dart` → ED-README red.
  - M-ED-W: in `strings_tr.dart`, `save` returns `'Save'` → ED-W red.
  - M-ED-10: `validatePlanEditorBar` returns at once → the ported BT2 red.
  - M-ED-11: in `_toolbarFor`, `if (isFile != lastFile) groups.add([]);` becomes `if (lastFile == null) groups.add([]);` → the ported "[print, undo] … 12 px apart" red.
  - M-ED-12: `_leftShown` returns `true` → the ported T4-j "readOnly: no left column" red.
  - M-ED-13: in `_fileCommands`, the Export command's `permissions.export` test is dropped → ED-4 red (and the ported T4-e).

#### Assumed from earlier tasks

Used as written; where an earlier task named it otherwise, use that task's name and report the difference.
- Task 8 (`lib/src/controller/plan_controller.dart`): `PlanController` notifies after a document swap and on new permissions; `document`, `selection` (with `length`), `page`, `camera` (`CameraController`), `snap` (`SnapSettings`, `objectSnap`), `ValueListenable<bool> canUndo`, `canRedo`, `ValueListenable<String> activeTool`, `undo()`, `redo()`, `settlePendingInput()`, `registerSettle`, `missingKits`, `KitSet get kits` (the validated set, `kits` in load order).
- Task 11: `ValueListenable<bool> PlanController.damaged`, backed by a `ValueNotifier<bool>` (ED-5 sets it through that cast, as the rollback path would).
- Tasks 8 and 12: `@internal ToolController get toolController` (controller ruling R-a: never `tools`) (its `active.isMidShape`, a `Listenable`); `PlanPermissions.allowsTool`, `PlanPermissions(tools: …)`, `readOnly`; `genericTools` (each with `id`) and `PlanToolIds.select`, `.symbol` in `lib/src/tools/generic_tools.dart`.
- Task 16 (as its body states them): `PlanToolPalette({required PlanController controller})` and `String planToolLabel(BuildContext, PlanController, String toolId)` at `lib/src/editor/plan_tool_palette.dart`; `PlanShortcuts({Key? key, required PlanController controller, required Widget child, bool shortcuts = true, Future<void> Function()? onNew, onOpen, onSave, onSaveAs, onExport, onPrint})` at `lib/src/shortcuts/plan_shortcuts.dart` (file chords bound when given, Undo and Redo while `permissions.undo`, F3 while snapping is allowed, the letters, F and Escape); the palette's row keys `tool-<tool id>`.
- Task 17: `PlanPropertyPanel({required PlanController controller})` at `lib/src/panels/plan_property_panel.dart`.
- Task 13: `PlanSymbolGallery` at `lib/src/panels/plan_symbol_gallery.dart`, `PlanSymbol` at `lib/src/symbols/plan_symbol.dart`.
- Task 15: `PlanCanvas` at `lib/src/canvas/plan_canvas.dart`; `PlanTextKeys`, `PlanShortcutGuard` and the chords from `lib/src/shortcuts/plan_shortcut_guard.dart`.
- Task 9: `PlanThemeScope({PlanTheme? view, required Widget child})` (`@internal`, in `lib/src/theme/plan_theme.dart`), `PlanTheme.merge`; Task 9's `value_words_test.dart` with `expectWorded`. (`RecordingPlanStrings` is this task's: Task 9 does not write it.)

#### Interface problem

Resolved: none against the Shared interfaces, which now list `PlanFileCallback` and `PlanEditor`'s four file-callback options; the bar's commands remain the chords' source (`PlanShortcuts` gets each command's `invoke`).

---

