// 2a spec P2 (PlanEditor: today's layout, its options, the host's file
// callbacks, the bar's commands by the permissions, the theme), P4 (the
// damaged warning) and P7 (one view over a controller).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, SelectionKey;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show SymbolsState;
import 'package:jet_cad_2d_plan/src/chrome/menu_button.dart';
import 'package:jet_cad_2d_plan/src/canvas/plan_canvas.dart';
import 'package:jet_cad_2d_plan/src/chrome/icon_button.dart';
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
import '../support/export_plan.dart';
import '../support/fake_page_printer.dart';
import '../support/layer_plan.dart';
import '../support/mark_kit.dart';
import '../support/recording_exporters.dart';
import '../support/symbol_fixtures.dart' show demoKit;

const _en = PlanStringsEn();

/// [c]'s marks, in the order the plan made them.
List<Handle> marksOf(PlanController c) =>
    c.catalog.objectsOf<MarkCross>(c.document);

PlanIconButton _button(WidgetTester tester, String key) =>
    tester.widget<PlanIconButton>(byKey(key));

/// A host that owns its controller and disposes it in its own `dispose`,
/// with the editor below it (spec P7; the controller outlives no view).
/// [json] is made before the host builds: `save()` settles pending input,
/// which a build may not.
class _OwningHost extends StatefulWidget {
  const _OwningHost(this.json);

  final String json;

  @override
  State<_OwningHost> createState() => _OwningHostState();
}

class _OwningHostState extends State<_OwningHost> {
  late final PlanController controller =
      PlanController(kits: [markKit()], json: widget.json);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      PlanEditor(controller: controller, onExport: (_) {});
}

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
      'then calls the host once; without them none is offered', (tester) async {
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
    // The alignment guides' toggle stays whatever the permissions say.
    expect(byKey('toolbar-guides'), findsOneWidget);
    expect(left(tester, 'toolbar-guides'), 12);
    expect(left(tester, 'status-text'), right(tester, 'toolbar-guides') + 16,
        reason: 'the toggle is the only button left');
    c.permissions = PlanPermissions.full;
    await tester.pump();
    expect(byKey('toolbar-undo'), findsOneWidget);
    expect(byKey('toolbar-export'), findsOneWidget);
  });

  testWidgets(
      'ED-5 a damaged plan: a warning before the status line, with the '
      'word as its tooltip; none while the plan is sound', (tester) async {
    final semantics = tester.ensureSemantics();
    final c = editorController();
    await pumpEditor(tester, PlanEditor(controller: c));
    expect(byKey('plan-damaged'), findsNothing);
    final statusBefore = left(tester, 'status-text');
    // The controller's flag, set as Task 11's rollback path sets it.
    (c.damaged as ValueNotifier<bool>).value = true;
    await tester.pump();
    // M-ED-5: the bar does not listen to `damaged`.
    expect(byKey('plan-damaged'), findsOneWidget);
    expect(find.bySemanticsLabel(_en.planDamaged), findsOneWidget);
    semantics.dispose();
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

  testWidgets(
      'ED-L the property panel\'s layer picker inside the editor: shown for '
      'a selection while changeLayer is on, gone while it is off; '
      'rebuilt after a lock (refused, the lock word) and after a swap (the '
      'new plan\'s layer)', (tester) async {
    final fx = layerPlan(objects: true);
    final c = fx.controller;
    await pumpEditor(tester, PlanEditor(controller: c));
    expect(byKey('layer-picker'), findsNothing, reason: 'nothing selected');
    c.selection.replace([SelectionKey.root(fx.marks.first)]);
    await tester.pump();
    PlanMenuButton<Handle> picker() =>
        tester.widget<PlanMenuButton<Handle>>(byKey('layer-picker'));
    expect(picker().enabled, isTrue);
    expect(tester.widget<Text>(byKey('layer-picker-value')).data, 'A');

    // M-ED-L1: the property panel drops `c.permissions.changeLayer` from
    // its layer field's condition.
    c.permissions = PlanPermissions.full.copyWith(changeLayer: false);
    await tester.pump();
    expect(byKey('layer-picker'), findsNothing);
    c.permissions = PlanPermissions.full;
    await tester.pump();
    expect(picker().enabled, isTrue);

    // M-ED-L2: the picker reads no lock (`isLocked: _never` in its build).
    c.lockBroken({fx.marks.first});
    await tester.pump();
    expect(picker().enabled, isFalse);
    expect(picker().label, _en.lockedNoLayer);

    // A swap to another plan: its selection is empty; then its mark on its
    // own layer D (no layer D in the first plan) shows D, enabled as
    // nothing in the new plan is broken.
    // M-ED-L3: the property panel never rebinds to the new document (the
    // rebinds in `_onController` and in `build` removed).
    final other = layerPlan(
        objects: true,
        more: (doc, a, b, c) {
          final zero = doc.tables.layers[ReservedHandles.layerZero]!;
          final d = doc.handleSeed.next();
          doc.commands.execute(AddLayerCommand(LayerRecord(
              handle: d,
              name: 'D',
              color: const IndexedColor(4),
              linetype: zero.linetype,
              lineweight: zero.lineweight,
              transparency: zero.transparency,
              visible: true,
              locked: false)));
          return [addMark(doc, d, at: placed(-2650.25, -1830.5, 0.85))];
        });
    c.load(other.controller.save());
    await tester.pump();
    await tester.pump();
    expect(byKey('layer-picker'), findsNothing,
        reason: 'the new plan\'s selection is empty');
    c.selection.replace([SelectionKey.root(other.marks.last)]);
    await tester.pump();
    expect(tester.widget<Text>(byKey('layer-picker-value')).data, 'D');
    expect(picker().enabled, isTrue,
        reason: 'the old plan\'s lock is not the new plan\'s');
  });

  testWidgets(
      'ED-X1 a plan with no page and only the page exporters: Export is '
      'offered and disabled, and its chord opens no dialog (today\'s rule, '
      'spec 13 D8)', (tester) async {
    final c = editorController(json: exportPlanJson(page: false));
    final got = <PlanExport>[];
    await pumpEditor(tester, PlanEditor(controller: c, onExport: got.add));
    expect(c.page.value, isNull, reason: 'premise: no page');
    expect(_button(tester, 'toolbar-export').onPressed, isNull);
    expect(_button(tester, 'toolbar-print').onPressed, isNull);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.pump();
    expect(byKey('export-dialog'), findsNothing);
    expect(got, isEmpty);
  });

  testWidgets(
      'ED-X2 a plan with no page and a host exporter that needs none: '
      'Export is enabled, and the dialog offers only the exporters that '
      'can run; with a page it offers every one', (tester) async {
    final json = RecordingExporter('host.json', 'json', 'application/json');
    final c = PlanController(
        kits: [markKit()],
        json: exportPlanJson(page: false),
        exporters: [json]);
    addTearDown(c.dispose);
    final got = <PlanExport>[];
    await pumpEditor(tester, PlanEditor(controller: c, onExport: got.add));
    expect(_button(tester, 'toolbar-export').onPressed, isNotNull);
    expect(_button(tester, 'toolbar-print').onPressed, isNull,
        reason: 'print plots the page');
    await tester.tap(byKey('toolbar-export'));
    await tester.pump();
    await tester.pump();
    expect(byKey('export-dialog'), findsOneWidget);
    // M-ED-X: the dialog is handed every exporter, page or not.
    expect(byKey('export-format-plan.pdf'), findsNothing);
    expect(byKey('export-format-plan.png'), findsNothing);
    expect(byKey('export-format-host.json'), findsOneWidget);
    await tester.tap(byKey('export-ok'));
    await tester.pump();
    for (var i = 0; i < 200 && got.isEmpty; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(got.single.name, 'plan.json');
    for (var i = 0; i < 200 && !c.pageFlows.ready.value; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }

    // Ctrl+E as the button: PlanShortcuts lets the chord through.
    // M-ED-X3: PlanShortcuts' Export chord asks for a page.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.pump();
    expect(byKey('export-dialog'), findsOneWidget);
    expect(byKey('export-format-plan.pdf'), findsNothing);
    await tester.tap(byKey('export-cancel'));
    await tester.pump();
    await tester.pump();

    // With a page, the page exporters are back.
    final paged = PlanController(
        kits: [markKit()], json: exportPlanJson(), exporters: [json]);
    addTearDown(paged.dispose);
    await pumpEditor(tester, PlanEditor(controller: paged, onExport: got.add));
    await tester.tap(byKey('toolbar-export'));
    await tester.pump();
    await tester.pump();
    for (final id in ['plan.pdf', 'plan.png', 'host.json']) {
      expect(byKey('export-format-$id'), findsOneWidget, reason: id);
    }
    await tester.tap(byKey('export-cancel'));
    await tester.pump();
    await tester.pump();
  });

  testWidgets(
      'ED-U Undo and Redo follow the history: an edit through the '
      'controller enables Undo by the next frame; Undo undoes it and '
      'enables Redo (the flags read the history, as today\'s DerivedFlag)',
      (tester) async {
    final c = editorController();
    await pumpEditor(tester, PlanEditor(controller: c));
    expect(_button(tester, 'toolbar-undo').onPressed, isNull,
        reason: 'premise: a loaded plan has no history');
    final mark = marksOf(c).first;
    expect(
        c.execute(
            SetComponentCommand<MarkCross>(mark, const MarkCross(910.75))),
        isTrue);
    // The history's change stream is asynchronous (the engine's, which
    // today's shell listened to as well): the first pump delivers it, the
    // second builds the button.
    await tester.pump();
    await tester.pump();
    // M-ED-U: the command sources leave out `c.canUndo` and `c.canRedo`.
    expect(_button(tester, 'toolbar-undo').onPressed, isNotNull);
    await tester.tap(byKey('toolbar-undo'));
    await tester.pump();
    expect(c.document.components.get<MarkCross>(mark), const MarkCross(700.5));
    expect(_button(tester, 'toolbar-undo').onPressed, isNull);
    expect(_button(tester, 'toolbar-redo').onPressed, isNotNull);
  });

  testWidgets(
      'ED-D a host that disposes its controller in its own dispose, the '
      'editor still below it: the editor goes first, nothing touches the '
      'disposed controller (a positive control)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final json = editorPlanJson();
    await tester
        .pumpWidget(MaterialApp(home: Scaffold(body: _OwningHost(json))));
    await tester.pump();
    final state = tester.state<_OwningHostState>(find.byType(_OwningHost));
    final c = state.controller;
    c.selection.replace([SelectionKey.root(marksOf(c).first)]);
    (c.damaged as ValueNotifier<bool>).value = true;
    await tester.pump();
    expect(byKey('plan-damaged'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    await tester.pump();
    expect(c.isDisposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  group('the options a host passes through (review Important 1)', () {
    testWidgets('ED-P1 toolPalette false and no symbols: no left column at all',
        (tester) async {
      final c = editorController();
      await pumpEditor(tester, PlanEditor(controller: c, toolPalette: false));
      // M-ED-P1: `_leftShown` drops `if (!widget.toolPalette) return false;`.
      expect(byKey('chrome-left'), findsNothing);
      expect(find.byType(PlanToolPalette), findsNothing);
      expect(find.byType(PlanCanvas), findsOneWidget);
    });

    testWidgets(
        'ED-P2 toolPalette false with a kit\'s symbols: the gallery alone, '
        'no tabs and no palette', (tester) async {
      final c = PlanController(kits: [slowSymbolsKit()]);
      addTearDown(c.dispose);
      await pumpEditor(tester, PlanEditor(controller: c, toolPalette: false));
      expect(byKey('chrome-left'), findsOneWidget);
      // M-ED-P2: `_leftPanel` drops `if (!widget.toolPalette) return
      // _galleryOf(c);` (the tabs over the palette come back).
      expect(byKey('left-tabs'), findsNothing);
      expect(find.byType(PlanToolPalette), findsNothing);
      expect(
          find.descendant(
              of: byKey('chrome-left'),
              matching: find.byType(PlanSymbolGallery)),
          findsOneWidget);
    });

    testWidgets(
        'ED-F symbolFilter reaches the gallery: a symbol it refuses has no '
        'cell, the others keep theirs', (tester) async {
      final c =
          PlanController(kits: [markKit(), demoKit()], json: editorPlanJson());
      addTearDown(c.dispose);
      await pumpEditor(
          tester,
          PlanEditor(
              controller: c, symbolFilter: (s) => s.id != 'demo.bed.double@1'));
      await tester.runAsync(() async {
        while (c.symbolsState.value != SymbolsState.ready) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.tap(byKey('tab-symbols'));
      await tester.pump();
      await tester.pump();
      expect(byKey('symbol-cell-demo.bed.single@1'), findsOneWidget,
          reason: 'premise: the gallery shows the library');
      // M-ED-F: the editor hands the gallery `filter: null`.
      expect(byKey('symbol-cell-demo.bed.double@1'), findsNothing);
    });

    testWidgets(
        'ED-S shortcuts false: a tool letter reaches the host\'s binding and '
        'arms nothing', (tester) async {
      final c = editorController();
      var reached = 0;
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: CallbackShortcuts(bindings: {
        const SingleActivator(LogicalKeyboardKey.keyL): () => reached++,
      }, child: PlanEditor(controller: c, shortcuts: false)))));
      await tester.pump();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pump();
      // M-ED-S: the editor hands PlanShortcuts `shortcuts: true`.
      expect(reached, 1);
      expect(c.activeTool.value, 'plan.select');
    });

    bool canvasFocused() {
      final context = FocusManager.instance.primaryFocus?.context;
      return context != null &&
          context.findAncestorWidgetOfExactType<InteractionLayer>() != null;
    }

    testWidgets(
        'ED-A1 by default the canvas takes the focus (a positive '
        'control)', (tester) async {
      final c = editorController();
      await pumpEditor(tester, PlanEditor(controller: c));
      expect(canvasFocused(), isTrue);
    });

    testWidgets('ED-A2 autofocus false: the canvas does not take the focus',
        (tester) async {
      final c = editorController();
      await pumpEditor(tester, PlanEditor(controller: c, autofocus: false));
      // M-ED-A: the editor hands the canvas `autofocus: true`.
      expect(canvasFocused(), isFalse);
    });

    testWidgets(
        'ED-E onPageFlowError receives a page flow\'s error: a printer that '
        'fails, once; the flows are ready again', (tester) async {
      final c = editorController();
      final printer = FakePagePrinter()..failNext = StateError('no printer');
      final errors = <Object>[];
      await pumpEditor(
          tester,
          PlanEditor(
              controller: c, printer: printer, onPageFlowError: errors.add));
      await tester.tap(byKey('toolbar-print'));
      await tester.pump();
      for (var i = 0; i < 200 && errors.isEmpty; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
      }
      // M-ED-E: the editor's hooks hand the flows `onError: null`.
      expect(errors, hasLength(1));
      expect(errors.single, isA<StateError>());
      expect(printer.calls, hasLength(1));
      expect(c.pageFlows.ready.value, isTrue);
    });
  });

  testWidgets(
      'ED-6b (RV6) an editor handed another controller withdraws the old '
      'one\'s tool: its polyline part-way is cancelled and plan.select '
      'armed', (tester) async {
    final one = editorController();
    final two = editorController();
    await pumpEditor(tester, PlanEditor(controller: one));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.pump();
    final origin = tester.getTopLeft(find.byType(InteractionLayer));
    await tester.tapAt(origin + const Offset(210.5, 160.25));
    await tester.tapAt(origin + const Offset(330.75, 215.5));
    await tester.pump();
    expect(one.toolController.active.isMidShape, isTrue,
        reason: 'premise: a polyline part-way');
    await pumpEditor(tester, PlanEditor(controller: two));
    await tester.pump();
    // M-ED-6b: PlanCanvas.didUpdateWidget withdraws no tool of the old
    // controller.
    expect(one.toolController.active.isMidShape, isFalse);
    expect(one.activeTool.value, 'plan.select');
  });
}
