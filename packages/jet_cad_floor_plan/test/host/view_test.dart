// Spec 14b-2 H5-H7, H11, R-2, R-9: the host's view -- the design mode's
// editor with Export and Print and no file commands, the selection mode's
// canvas over the service copy, the settle before a switch, the drop rule,
// and Export of what is on screen in both modes. Tables are placed on the
// page, off its centre, turned and mirrored.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:jet_cad_floor_plan/src/host/page_flows.dart';
import 'package:jet_cad_floor_plan/src/host/table_fit.dart';
import 'package:jet_cad_floor_plan/src/export/page_printer.dart';
import 'package:jet_cad_floor_plan/src/new_document.dart';
import 'package:jet_cad_floor_plan/src/parametric/catalog.dart'
    show registerAppComponents;
import 'package:jet_cad_floor_plan/src/service/table_picker.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_library_loader.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_library_state.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:jet_cad_floor_plan/src/planner_shell.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label.dart'
    show kTableLabelTag;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/palette_fixture.dart'
    show Shot, pumpThemed, shoot, white, windowAt;
import '../tables/table_fixture.dart';
import 'zone_fixture.dart';

/// A plan on the default page: tables 1 (turned, mirrored) and 2.
String pagePlan() {
  final measurer = FlutterTextMeasurer();
  final doc = newDocument(measurer);
  final sheet =
      sheetWorldRect(doc.components.get<PageComponent>(doc.rootHandle)!);
  final cx = (sheet.minX + sheet.maxX) / 2, cy = (sheet.minY + sheet.maxY) / 2;
  doc.commands.execute(placeSymbol(doc, entryOf(tableSymbol()),
      at: Vector2(cx - 2600, cy + 900), quarterTurns: 1, mirrored: true));
  doc.commands.execute(placeSymbol(doc, entryOf(tableSymbol()),
      at: Vector2(cx + 2100, cy - 700)));
  final json = DraftDocumentCodec.encodeToString(doc);
  doc.dispose();
  measurer.clear();
  return json;
}

Finder byKey(String k) => find.byKey(Key(k));

/// A printer that records its calls and finishes each when told.
class FakePrinter implements PagePrinter {
  final List<String> names = [];
  final List<Completer<void>> pending = [];

  @override
  Future<void> print(Uint8List pdf, String name, PdfPageFormat format) {
    names.add(name);
    final done = Completer<void>();
    pending.add(done);
    return done.future;
  }
}

Future<FloorPlanController> pumpView(WidgetTester tester,
    {void Function(FloorPlanExport)? onExport,
    PagePrinter? printer,
    String exportName = 'plan',
    String? json,
    SymbolLibraryLoader? symbols}) async {
  final c = FloorPlanController(json: json ?? pagePlan(), symbols: symbols);
  addTearDown(c.dispose);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: FloorPlanView(
              controller: c,
              onExport: onExport,
              printer: printer,
              exportName: exportName))));
  await tester.pump();
  await tester.pump();
  return c;
}

/// Exports a 96 dpi PNG through the view's Export and returns its bytes.
Future<Uint8List> exportPng(
    WidgetTester tester, String button, List<FloorPlanExport> got) async {
  final before = got.length;
  await tester.tap(byKey(button));
  await tester.pump();
  await tester.pump();
  expect(byKey('export-dialog'), findsOneWidget);
  await tester.tap(byKey('export-format-png'));
  await tester.pump();
  await tester.tap(byKey('export-dpi-96'));
  await tester.pump();
  await tester.tap(byKey('export-ok'));
  await tester.pump();
  for (var i = 0; i < 400 && got.length == before; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(got, hasLength(before + 1));
  final e = got.last;
  expect(e.fileName, 'plan.png');
  expect(e.mimeType, 'image/png');
  return e.bytes;
}

void move(FloorPlanController c, String n, double dx, double dy) {
  final d = c.activeDocument;
  final node =
      d.tree[TableSurvey.of(d).withNumber(n).single.instance]! as InstanceNode;
  d.commands.execute(CompoundCommand([
    TransformNodeCommand(
        node.handle, Transform2.translation(dx, dy).multiply(node.transform))
  ], label: 'Move'));
}

void main() {
  testWidgets(
      'V1 the design mode is the editor with Export and Print and no file '
      'commands; the selection mode is the canvas alone', (tester) async {
    final c = await pumpView(tester, onExport: (_) {});
    expect(find.byType(PlannerShell), findsOneWidget);
    expect(byKey('toolbar-export'), findsOneWidget);
    expect(byKey('toolbar-print'), findsOneWidget);
    for (final k in ['toolbar-new', 'toolbar-open', 'toolbar-save']) {
      expect(byKey(k), findsNothing, reason: k);
    }
    expect(byKey('document-name'), findsNothing);

    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    await tester.pump();
    expect(find.byType(PlannerShell), findsNothing);
    expect(byKey('service-bar'), findsOneWidget);
    expect(byKey('service-export'), findsOneWidget);
    expect(byKey('tool-select'), findsNothing, reason: 'no palette');
    expect(byKey('selection-panel'), findsNothing, reason: 'no panels');

    c.setMode(FloorPlanMode.design);
    await tester.pump();
    await tester.pump();
    expect(find.byType(PlannerShell), findsOneWidget);
  });

  testWidgets('V2 without onExport, Export is not offered', (tester) async {
    final c = await pumpView(tester);
    expect(byKey('toolbar-export'), findsNothing);
    expect(byKey('toolbar-print'), findsOneWidget);
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    expect(byKey('service-export'), findsNothing);
  });

  testWidgets(
      'V3 a switch, a reset and a load with the view mounted: nothing '
      'throws, the old plans are disposed after the frame (M-14b2-12 '
      'survives: recorded)', (tester) async {
    final c = await pumpView(tester);
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    final copy = c.activeDocument;
    move(c, '1', 500, 0);
    c.resetLayout();
    await tester.pump();
    await tester.pump();
    c.setMode(FloorPlanMode.design);
    await tester.pump();
    await tester.pump();
    final oldDesign = c.activeDocument;
    c.load(pagePlan());
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(c.tables, hasLength(2));
    // The copy's systems were disposed last in, first out (review m33),
    // and the dropped plans are disposed (review m36).
    expect(copy.commands.expander, isNull);
    expect(copy.commands.isDisposed, isTrue);
    expect(oldDesign.commands.isDisposed, isTrue);
  });

  testWidgets(
      'V4 a value typed in the Table section reaches the design and the '
      'copy before the switch (M-14b2-11)', (tester) async {
    final c = await pumpView(tester);
    c.select({'2'});
    await tester.pump();
    expect(byKey('table-section'), findsOneWidget);
    await tester.tap(byKey('table-number'));
    await tester.pump();
    await tester.enterText(byKey('table-number'), '42');
    await tester.pump();

    c.setMode(FloorPlanMode.selection);
    expect([for (final t in c.tables) t.number], ['1', '42'],
        reason: 'the copy has the typed number');
    await tester.pump();
    await tester.pump();
    final design = c.designJson();
    expect(design.contains('"42"'), isTrue);
    await tester.pump();
    expect(c.designJson(), design, reason: 'nothing lands later');
    expect(c.selectedTables.value, {'42'});
  });

  testWidgets(
      'V5 Export plots what is on screen: the service copy in the selection '
      'mode, the design again after resetLayout (M-14b2-7)', (tester) async {
    final got = <FloorPlanExport>[];
    final c = await pumpView(tester, onExport: got.add);
    final design = await exportPng(tester, 'toolbar-export', got);
    expect(design.sublist(1, 4), 'PNG'.codeUnits);

    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    await tester.pump();
    final same = await exportPng(tester, 'service-export', got);
    expect(same, design, reason: 'the copy, unmoved, is the design');

    move(c, '1', 900, -600);
    await tester.pump();
    final moved = await exportPng(tester, 'service-export', got);
    expect(moved, isNot(design));

    c.resetLayout();
    await tester.pump();
    await tester.pump();
    final reset = await exportPng(tester, 'service-export', got);
    expect(reset, design);
  });

  testWidgets(
      'V6 the selection mode offers nothing that needs geometry or '
      'structure: a dispatcher spy sees no refusal (M-12a)', (tester) async {
    final c = await pumpView(tester, onExport: (_) {});
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    await tester.pump();
    final refused = <Object>[];
    final doc = c.activeDocument;
    final inner = doc.commands.expander;
    doc.commands.expander = (cmd) {
      for (final cap in cmd.capabilities) {
        if (!doc.commands.permissions.allows(cap)) refused.add(cmd);
      }
      return inner?.call(cmd) ?? cmd;
    };
    // Every control of the service bar, and a drag on the canvas.
    for (final k in ['service-undo', 'service-redo']) {
      await tester.tap(byKey(k));
      await tester.pump();
    }
    await tester.dragFrom(const Offset(700, 450), const Offset(120, 80));
    await tester.pump();
    expect(refused, isEmpty);
    expect(doc.commands.undoDepth, 0, reason: 'nothing was edited');
    // Back before the view unmounts: the table system asserts that it
    // still holds the slot it took (14a T12).
    doc.commands.expander = inner;
  });

  /// Where world point [w] is on the screen: the canvas's top left (the
  /// interaction layer's, whose coordinates the camera's are) plus the
  /// camera's image of [w].
  Offset globalOf(WidgetTester tester, FloorPlanController c, Vector2 w) {
    final s = c.camera.value.worldToScreen(w);
    return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
  }

  testWidgets(
      'V7a a mode switch keeps the plan in place on the screen, from the '
      'first frame, both ways; there and back gives the camera\'s numbers '
      'again; fitToView still fits (R-13 as amended)', (tester) async {
    final c = await pumpView(tester);
    c.camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2(0.07, 0, 0, -0.07, -310.5, 2400.25));
    await tester.pump();
    final w = Vector2(3170.5, -820.25);
    final before = globalOf(tester, c, w);
    final canvas = tester.getTopLeft(find.byType(InteractionLayer));

    c.setMode(FloorPlanMode.selection);
    // Before any frame: already shifted by the chrome's difference, so the
    // first frame of the service draws the plan in place.
    expect(c.camera.value.worldToScreenMatrix.e, -310.5 + 240 + 24);
    expect(c.camera.value.worldToScreenMatrix.f, 2400.25 + 24);
    await tester.pump();
    expect(tester.getTopLeft(find.byType(InteractionLayer)), isNot(canvas),
        reason: 'premise: the canvas starts elsewhere in the service');
    final there = globalOf(tester, c, w);
    expect(there.dx, closeTo(before.dx, 1e-9));
    expect(there.dy, closeTo(before.dy, 1e-9));
    expect(c.camera.value.worldToScreenMatrix.a, 0.07, reason: 'no zoom');

    c.setMode(FloorPlanMode.design);
    await tester.pump();
    final back = globalOf(tester, c, w);
    expect(back.dx, closeTo(before.dx, 1e-9));
    expect(back.dy, closeTo(before.dy, 1e-9));
    expect(c.camera.value.worldToScreenMatrix.e, -310.5);
    expect(c.camera.value.worldToScreenMatrix.f, 2400.25);

    c.fitToView();
    await tester.pump();
    await tester.pump();
    expect(c.camera.value.worldToScreenMatrix.a, isNot(0.07));
  });

  testWidgets(
      'V7b a canvas origin that is not the seeded one is measured after the '
      'frame and the plan put back in place (R-13 as amended)', (tester) async {
    final seeds = Map.of(floorPlanCanvasSeeds);
    addTearDown(() => floorPlanCanvasSeeds
      ..clear()
      ..addAll(seeds));
    floorPlanCanvasSeeds[FloorPlanMode.selection] = const Offset(130, 7);
    final c = await pumpView(tester);
    c.camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2(0.05, 0, 0, -0.05, 120.75, 610.5));
    await tester.pump();
    final w = Vector2(-1450.25, 2210.5);
    final before = globalOf(tester, c, w);
    c.setMode(FloorPlanMode.selection);
    expect(c.camera.value.worldToScreenMatrix.e, 120.75 + 240 + 24 - 130,
        reason: 'premise: shifted by the wrong seed');
    await tester.pump();
    final after = globalOf(tester, c, w);
    expect(after.dx, closeTo(before.dx, 1e-9));
    expect(after.dy, closeTo(before.dy, 1e-9));
    // Back to the design: the measured origin is the one used now.
    c.setMode(FloorPlanMode.design);
    await tester.pump();
    final back = globalOf(tester, c, w);
    expect(back.dx, closeTo(before.dx, 1e-9));
    expect(back.dy, closeTo(before.dy, 1e-9));
  });

  Widget viewApp(FloorPlanController? c) => MaterialApp(
      home: Scaffold(
          body: c == null ? const SizedBox() : FloorPlanView(controller: c)));

  final cam = ViewportTransform(
      worldToScreenMatrix: Transform2(0.05, 0, 0, -0.05, 120.75, 610.5));
  final w = Vector2(-1450.25, 2210.5);

  void expectSame(Offset a, Offset b, String reason) {
    expect(a.dx, closeTo(b.dx, 1e-9), reason: reason);
    expect(a.dy, closeTo(b.dy, 1e-9), reason: reason);
  }

  testWidgets(
      'V7c the seeds are where each mode\'s canvas starts in the view (so '
      'the first frame after a switch needs no correction)', (tester) async {
    final c = await pumpView(tester);
    Offset canvas() =>
        tester.getTopLeft(find.byType(InteractionLayer)) -
        tester.getTopLeft(find.byType(FloorPlanView));
    expect(canvas(), floorPlanCanvasSeeds[FloorPlanMode.design]);
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    expect(canvas(), floorPlanCanvasSeeds[FloorPlanMode.selection]);
  });

  testWidgets(
      'V7d a switch while no view is shown keeps the place the next view '
      'shows (review F-3)', (tester) async {
    final c = FloorPlanController(json: pagePlan());
    addTearDown(c.dispose);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(viewApp(c));
    await tester.pump();
    c.camera.value = cam;
    await tester.pump();
    final before = globalOf(tester, c, w);
    await tester.pumpWidget(viewApp(null));
    c.setMode(FloorPlanMode.selection);
    await tester.pumpWidget(viewApp(c));
    await tester.pump();
    expectSame(globalOf(tester, c, w), before, 'remounted in the service');
  });

  testWidgets(
      'V7e a switch right after the first frame keeps the place (review '
      'F-1)', (tester) async {
    final c = FloorPlanController(json: pagePlan());
    addTearDown(c.dispose);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    c.takeFitOnStart(); // a host whose plan was already shown and fitted
    c.camera.value = cam;
    var switched = false;
    tester.binding.addPostFrameCallback((_) {
      c.setMode(FloorPlanMode.selection);
      switched = true;
    });
    await tester.pumpWidget(viewApp(c));
    expect(switched, isTrue, reason: 'premise');
    final s = cam.worldToScreen(w);
    final before = tester.getTopLeft(find.byType(FloorPlanView)) +
        floorPlanCanvasSeeds[FloorPlanMode.design]! +
        Offset(s.x, s.y);
    await tester.pump();
    await tester.pump();
    expectSame(globalOf(tester, c, w), before, 'in the service');
  });

  testWidgets(
      'V7h a wrong seed for the mode switched out of, measured only after '
      'the switch: the plan is put back in place', (tester) async {
    final seeds = Map.of(floorPlanCanvasSeeds);
    addTearDown(() => floorPlanCanvasSeeds
      ..clear()
      ..addAll(seeds));
    floorPlanCanvasSeeds[FloorPlanMode.design] = const Offset(190, 31);
    final c = FloorPlanController(json: pagePlan());
    addTearDown(c.dispose);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    c.takeFitOnStart();
    c.camera.value = cam;
    tester.binding
        .addPostFrameCallback((_) => c.setMode(FloorPlanMode.selection));
    await tester.pumpWidget(viewApp(c));
    final s = cam.worldToScreen(w);
    final before = tester.getTopLeft(find.byType(FloorPlanView)) +
        seeds[FloorPlanMode.design]! +
        Offset(s.x, s.y);
    await tester.pump();
    await tester.pump();
    expectSame(globalOf(tester, c, w), before, 'in the service');
  });

  testWidgets(
      'V7f a controller swapped on the view: the new one keeps its place, '
      'the old one is not moved by the view', (tester) async {
    final a = FloorPlanController(json: pagePlan());
    final b = FloorPlanController(json: pagePlan());
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(viewApp(a));
    await tester.pump();
    await tester.pumpWidget(viewApp(b));
    await tester.pump();
    b.camera.value = cam;
    await tester.pump();
    final before = globalOf(tester, b, w);
    b.setMode(FloorPlanMode.selection);
    await tester.pump();
    await tester.pump();
    expectSame(globalOf(tester, b, w), before, 'b in the service');
    a.camera.value = cam;
    await tester.pump();
    expect(a.camera.value.worldToScreenMatrix.e, 120.75);
  });

  testWidgets(
      'V7g a load and a switch before a frame: the fit wins, nothing is '
      'shifted on top of it', (tester) async {
    final c = await pumpView(tester);
    c.camera.value = cam;
    await tester.pump();
    c.load(pagePlan());
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    await tester.pump();
    final fitted = c.camera.value.worldToScreenMatrix;
    c.fitToView();
    await tester.pump();
    await tester.pump();
    final again = c.camera.value.worldToScreenMatrix;
    expect([fitted.a, fitted.e, fitted.f], [again.a, again.e, again.f]);
  });

  testWidgets(
      'V8 the keyboard\'s Undo and Redo act on the copy in the selection '
      'mode', (tester) async {
    final c = await pumpView(tester);
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    await tester.pump();
    move(c, '2', 700, 300);
    await tester.pump();
    expect(c.canUndo.value, isTrue);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
    expect(c.canUndo.value, isFalse);
    expect(c.canRedo.value, isTrue);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyY);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
    expect(c.canUndo.value, isTrue);
  });

  /// Lets the flows' real async work (the font, the PDF) run.
  Future<void> letRun(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 400 && !done(); i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
  }

  testWidgets(
      'V9 Print in the selection mode prints the copy under the export name; '
      'a second press while it runs does nothing (review m21b, m39)',
      (tester) async {
    final printer = FakePrinter();
    final c = await pumpView(tester, printer: printer, exportName: 'teras');
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    await tester.pump();
    move(c, '1', 400, 400);
    await tester.tap(byKey('service-print'));
    await tester.pump();
    await letRun(tester, () => printer.names.isNotEmpty);
    expect(printer.names, ['teras']);
    await tester.tap(byKey('service-print'));
    await tester.pump();
    await letRun(tester, () => printer.names.length > 1);
    expect(printer.names, ['teras'], reason: 'busy: the press is ignored');
    // The chord is not a disabled button: the flows' own guard (m21b).
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
    await letRun(tester, () => printer.names.length > 1);
    expect(printer.names, ['teras'], reason: 'busy: the chord is ignored');
    printer.pending.single.complete();
    await tester.pump();
    await tester.tap(byKey('service-print'));
    await tester.pump();
    await letRun(tester, () => printer.names.length > 1);
    expect(printer.names, ['teras', 'teras']);
    printer.pending.last.complete();
    await tester.pump();
  });

  testWidgets(
      'V10 a host rebuild, or the view removed, while Print runs throws '
      'nothing (review F-1)', (tester) async {
    final printer = FakePrinter();
    final c = await pumpView(tester, printer: printer);
    await tester.tap(byKey('toolbar-print'));
    await tester.pump();
    await letRun(tester, () => printer.names.isNotEmpty);
    // A rebuild with a new closure, as a host's build makes one.
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FloorPlanView(
                controller: c, printer: printer, onExport: (_) {}))));
    printer.pending.single.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(byKey('toolbar-print'), findsOneWidget);

    await tester.tap(byKey('toolbar-print'));
    await tester.pump();
    await letRun(tester, () => printer.names.length > 1);
    await tester.pumpWidget(const SizedBox());
    printer.pending.last.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'V11 a plan swapped while a flow awaits: nothing is printed or '
      'exported (review m21, m21c)', (tester) async {
    final printer = FakePrinter();
    final got = <FloorPlanExport>[];
    final c = await pumpView(tester, printer: printer, onExport: got.add);
    // The flow runs synchronously up to its first await; the plan is
    // swapped right after, as a host could.
    final flows = PageFlows(
        controller: c,
        settings: () =>
            (onExport: got.add, printer: printer, exportName: 'plan'));
    addTearDown(flows.dispose);
    final printing = flows.print(tester.element(find.byType(FloorPlanView)));
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    await letRun(tester, () => printer.names.isNotEmpty);
    await tester.runAsync(() => printing);
    expect(printer.names, isEmpty);

    await tester.tap(byKey('service-export'));
    await tester.pump();
    await tester.pump();
    expect(byKey('export-dialog'), findsOneWidget);
    c.resetLayout();
    await tester.tap(byKey('export-format-png'));
    await tester.pump();
    await tester.tap(byKey('export-ok'));
    await tester.pump();
    await letRun(tester, () => got.isNotEmpty);
    expect(got, isEmpty);
  });

  testWidgets(
      'V12 fitToView right after a switch, and a load, fit the new view '
      '(review F-2, m28)', (tester) async {
    final c = await pumpView(tester);
    await tester.pump();
    final odd = ViewportTransform(
        worldToScreenMatrix: Transform2(0.07, 0, 0, -0.07, -310, 2400));
    c.camera.value = odd;
    c.setMode(FloorPlanMode.selection);
    c.fitToView();
    await tester.pump();
    await tester.pump();
    // The selection mode's canvas is wider than the editor's: its fit.
    final fitted = c.camera.value.worldToScreenMatrix.a;
    expect(fitted, isNot(0.07));
    c.camera.value = odd;
    c.fitToView();
    await tester.pump();
    await tester.pump();
    expect(c.camera.value.worldToScreenMatrix.a, fitted,
        reason: 'the same view fits the same');

    c.camera.value = odd;
    c.load(pagePlan());
    await tester.pump();
    await tester.pump();
    expect(c.camera.value.worldToScreenMatrix.a, fitted);
  });

  testWidgets(
      'V13 a plan without a page: Export and Print are disabled in the '
      'service bar (review F-4)', (tester) async {
    final doc = plan();
    final c = await pumpView(tester,
        onExport: (_) {}, json: DraftDocumentCodec.encodeToString(doc));
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    await tester.pump();
    for (final k in ['service-print', 'service-export']) {
      expect(tester.widget<IconButton>(byKey(k)).onPressed, isNull, reason: k);
    }
  });

  testWidgets('V14 a shared symbol loader is loaded by the view (review F-3)',
      (tester) async {
    final loader = SymbolLibraryLoader();
    addTearDown(loader.dispose);
    await pumpView(tester, symbols: loader);
    await letRun(tester, () => loader.state is SymbolLibraryReady);
    expect(loader.state, isA<SymbolLibraryReady>());
  });

  /// Table [n]'s top centre on the screen, in the test's coordinates.
  Offset tableOnScreen(WidgetTester tester, FloorPlanController c, String n) {
    final d = c.activeDocument;
    final node = d.tree[TableSurvey.of(d).withNumber(n).single.instance]!
        as InstanceNode;
    final w = node.transform.transformPoint(Vector2(900, 700));
    final s = c.camera.value.worldToScreen(w);
    return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
  }

  testWidgets(
      'V15 through the widgets: a tap reports the number and selects; a '
      'drag moves and reports once; a reset mid-drag executes nothing '
      '(14c S8, R-5)', (tester) async {
    final taps = <String>[];
    var layouts = 0;
    final c = FloorPlanController(json: pagePlan());
    addTearDown(c.dispose);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FloorPlanView(
                controller: c,
                onTableTap: taps.add,
                onLayoutChanged: () => layouts++))));
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    await tester.pump();

    await tester.tapAt(tableOnScreen(tester, c, '2'));
    await tester.pump();
    expect(taps, ['2']);
    expect(c.selectedTables.value, {'2'});

    final g = await tester.startGesture(tableOnScreen(tester, c, '2'));
    await g.moveBy(const Offset(30, 0));
    await g.moveBy(const Offset(30, 10));
    await g.up();
    await tester.pump();
    expect(layouts, 1);
    expect(c.serviceEdited, isTrue);
    expect(c.activeDocument.commands.undoDepth, 1);

    final g2 = await tester.startGesture(tableOnScreen(tester, c, '2'));
    await g2.moveBy(const Offset(40, 0));
    c.resetLayout();
    await tester.pump();
    await g2.moveBy(const Offset(40, 0));
    await g2.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(c.serviceEdited, isFalse, reason: 'the new copy saw no move');
    expect(layouts, 1);
  });

  testWidgets(
      'V18 by touch: a second finger joining a table drag cancels it and '
      'pinches; nothing moves; a tap after it selects (14t T6, M-14t-7)',
      (tester) async {
    final taps = <String>[];
    var layouts = 0;
    final c = FloorPlanController(json: pagePlan());
    addTearDown(c.dispose);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FloorPlanView(
                controller: c,
                onTableTap: taps.add,
                onLayoutChanged: () => layouts++))));
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    await tester.pump();
    final scale = c.camera.value.scale;
    final at2 = tableOnScreen(tester, c, '2');
    final a = await tester.startGesture(at2,
        pointer: 31, kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 150));
    await a.moveTo(at2 + const Offset(40, 0));
    await a.moveTo(at2 + const Offset(70, 15));
    final b = await tester.startGesture(at2 + const Offset(200, 120),
        pointer: 32, kind: PointerDeviceKind.touch);
    for (var i = 1; i <= 3; i++) {
      await a.moveTo(at2 + Offset(70.0 - 20 * i, 15.0 - 10 * i));
      await b.moveTo(at2 + Offset(200.0 + 25 * i, 120.0 + 15 * i));
    }
    await a.up();
    await b.up();
    await tester.pump(const Duration(milliseconds: 200));
    expect(c.activeDocument.commands.undoDepth, 0, reason: 'no Move');
    expect(layouts, 0);
    expect(c.serviceEdited, isFalse);
    expect(c.camera.value.scale, greaterThan(scale * 1.2), reason: 'zoomed');
    expect(c.selectedTables.value, {'2'},
        reason: 'the drag selected it at the slop; the selection stands');

    c.fitToView();
    await tester.pump();
    await tester.pump();
    final t = await tester.startGesture(tableOnScreen(tester, c, '1'),
        pointer: 33, kind: PointerDeviceKind.touch);
    await t.up();
    await tester.pump();
    expect(c.selectedTables.value, {'1'}, reason: 'the tool is not stuck');
    expect(taps, ['1']);
  });

  testWidgets(
      'V19 by touch through the view: a long press toggles 500 ms from '
      'contact (14t T5, review F-6)', (tester) async {
    final c = FloorPlanController(json: pagePlan());
    addTearDown(c.dispose);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: FloorPlanView(controller: c))));
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    await tester.pump();
    final g = await tester.startGesture(tableOnScreen(tester, c, '2'),
        pointer: 34, kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 499));
    expect(c.selectedTables.value, isEmpty);
    await tester.pump(const Duration(milliseconds: 2));
    expect(c.selectedTables.value, {'2'});
    await g.up();
    await tester.pump();
    expect(c.selectedTables.value, {'2'}, reason: 'spent: no tap after');
  });

  testWidgets('V16 the status layer is drawn in the selection mode only',
      (tester) async {
    final c = await pumpView(tester);
    c.setTableStatus({'1': TableStatus(color: const Color(0xFF43A047))});
    await tester.pump();
    expect(byKey('table-status-layer'), findsNothing);
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    await tester.pump();
    expect(byKey('table-status-layer'), findsOneWidget);
  });

  testWidgets(
      'V17 the status layer repaints on a status change, a move, an undo '
      'and the camera (R-4, review F-3)', (tester) async {
    final c = await pumpView(tester);
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    await tester.pump();
    final painter =
        tester.widget<CustomPaint>(byKey('table-status-layer')).painter!;
    var repaints = 0;
    void count() => repaints++;
    painter.addListener(count);
    addTearDown(() => painter.removeListener(count));

    c.setTableStatus({'1': TableStatus(color: const Color(0xFF43A047))});
    expect(repaints, 1, reason: 'a status change');
    move(c, '1', 700, -300);
    await tester.pump();
    await tester.pump();
    expect(repaints, 2, reason: 'a move');
    c.activeDocument.commands.undo();
    await tester.pump();
    await tester.pump();
    expect(repaints, 3, reason: 'its undo');
    final before = repaints;
    c.fitToView();
    await tester.pump();
    await tester.pump();
    expect(repaints, greaterThan(before), reason: 'the camera');
  });

  testWidgets(
      'V18 the selection mode draws no rulers and no grid; the sheet stays; '
      'the design mode keeps both', (tester) async {
    final c = await pumpView(tester);
    PageChromePainter chrome() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<PageChromePainter>()
        .single;
    expect(
        c.activeDocument.components
            .get<PageComponent>(c.activeDocument.rootHandle)!
            .gridVisible,
        isTrue,
        reason: 'premise: the page shows its grid');
    expect(find.byType(RulerFrame), findsOneWidget);
    expect(chrome().grid, isTrue);
    final designArea = tester.getRect(find.byType(InteractionLayer));

    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    await tester.pump();
    expect(find.byType(RulerFrame), findsNothing);
    expect(chrome().grid, isFalse);
    expect(chrome().page.value, isNotNull, reason: 'the sheet is drawn');
    final serviceArea = tester.getRect(find.byType(InteractionLayer));
    expect(serviceArea.width, greaterThan(designArea.width),
        reason: 'the rulers\' room goes to the plan');

    c.setMode(FloorPlanMode.design);
    await tester.pump();
    await tester.pump();
    expect(find.byType(RulerFrame), findsOneWidget);
    expect(chrome().grid, isTrue);
  });

  // Zone spec Z5-Z8: a framing performed by the view, pending with none.
  // The fixture is `zone_fixture.dart`'s; a non-identity camera is set
  // before every call.

  /// A controller over the zone fixture, its camera elsewhere, no view.
  FloorPlanController zoneController() {
    final c = FloorPlanController(json: zonePlanJson());
    addTearDown(c.dispose);
    c.camera.value = zoneCamera();
    return c;
  }

  Future<void> mountAt1440(WidgetTester tester, FloorPlanController c) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(viewApp(c));
    await tester.pump();
    await tester.pump();
  }

  /// The camera frames the tables [numbers] of the active plan in the
  /// shown canvas: Z3's camera on the test's own bound at the canvas's
  /// size, the bound's centre at the canvas's within 1e-6 px.
  void expectFramed(
      WidgetTester tester, FloorPlanController c, Set<String> numbers,
      {String? reason}) {
    final canvas = find.byType(InteractionLayer);
    final box = boundOf(c.activeDocument, numbers);
    expectCamera(c.camera.value, frameTables(box, tester.getSize(canvas)),
        reason: reason);
    final centre = globalOf(tester, c, box.center);
    final want = tester.getCenter(canvas);
    expect(centre.dx, closeTo(want.dx, 1e-6), reason: reason);
    expect(centre.dy, closeTo(want.dy, 1e-6), reason: reason);
  }

  /// The page fit of the mounted view: what [FloorPlanController.fitToView]
  /// gives from another camera. Leaves the camera there.
  Future<ViewportTransform> pageFit(
      WidgetTester tester, FloorPlanController c) async {
    c.camera.value = zoneCamera();
    c.fitToView();
    await tester.pump();
    await tester.pump();
    expect(c.camera.value.worldToScreenMatrix.a, isNot(0.37),
        reason: 'premise: refitted');
    return c.camera.value;
  }

  testWidgets(
      'VZ1 with no view mounted, a framing is pending: the next view frames '
      'on its first frame, in both modes (M-Z8)', (tester) async {
    final c = zoneController();
    c.takeFitOnStart(); // a host whose plan was already shown and fitted
    expect(c.fitToTables({'3'}), isTrue);
    await mountAt1440(tester, c);
    expectFramed(tester, c, {'3'}, reason: 'design');
    expect(c.takeFitOnStart(), isFalse, reason: 'performed');

    await tester.pumpWidget(viewApp(null));
    c.setMode(FloorPlanMode.selection);
    c.camera.value = zoneCamera();
    expect(c.fitToTables({'A1', 'A2'}), isTrue);
    await tester.pumpWidget(viewApp(c));
    await tester.pump();
    expectFramed(tester, c, {'A1', 'A2'}, reason: 'selection');
  });

  testWidgets(
      'VZ2 load and newPlan drop a framing: the next view fits the page '
      '(M-Z9, M-Z32)', (tester) async {
    final c = zoneController();
    expect(c.fitToTables({'3'}), isTrue);
    c.load(zonePlanJson());
    c.camera.value = zoneCamera();
    await mountAt1440(tester, c);
    final first = c.camera.value;
    expectCamera(first, await pageFit(tester, c), reason: 'load');

    await tester.pumpWidget(viewApp(null));
    c.camera.value = zoneCamera();
    expect(c.fitToTables({'3'}), isTrue);
    c.newPlan();
    // The new plan gets a table 3 before a view shows it: the old
    // request named the old plan's.
    placeZoneTable(c.activeDocument, trapezoidTable, 40000, -27000, '3',
        mirrored: true);
    c.camera.value = zoneCamera();
    await tester.pumpWidget(viewApp(c));
    await tester.pump();
    final second = c.camera.value;
    expectCamera(second, await pageFit(tester, c), reason: 'newPlan');
  });

  testWidgets(
      'VZ3 a framing is resolved when performed: a restore moving the '
      'table before the view mounts is followed (M-Z10)', (tester) async {
    final c = zoneController();
    c.setMode(FloorPlanMode.selection);
    move(c, '3', 4300.5, -2100.25);
    final json = c.serviceLayoutJson()!;
    c.resetLayout();
    final designed = boundOf(c.activeDocument, {'3'});
    c.takeFitOnStart();
    c.camera.value = zoneCamera();
    expect(c.fitToTables({'3'}), isTrue);
    expect(c.restoreServiceLayout(json).applied, ['3']);
    expect(boundOf(c.activeDocument, {'3'}).minX, isNot(designed.minX),
        reason: 'premise: 3 moved');
    await mountAt1440(tester, c);
    expectFramed(tester, c, {'3'});
  });

  testWidgets(
      'VZ4 the last request wins: fitToTables then fitToView fits the page; '
      'the reverse frames the tables (M-Z12)', (tester) async {
    final c = zoneController();
    await mountAt1440(tester, c);
    final page = await pageFit(tester, c);
    c.camera.value = zoneCamera();
    expect(c.fitToTables({'3'}), isTrue);
    c.fitToView();
    await tester.pump();
    await tester.pump();
    expectCamera(c.camera.value, page, reason: 'the page');

    c.camera.value = zoneCamera();
    c.fitToView();
    expect(c.fitToTables({'3'}), isTrue);
    await tester.pump();
    await tester.pump();
    expectFramed(tester, c, {'3'}, reason: 'the tables');

    // With no view mounted, the same.
    await tester.pumpWidget(viewApp(null));
    c.camera.value = zoneCamera();
    expect(c.fitToTables({'3'}), isTrue);
    c.fitToView();
    await tester.pumpWidget(viewApp(c));
    await tester.pump();
    expectCamera(c.camera.value, page, reason: 'the page, remounted');
  });

  testWidgets(
      'VZ5 the framed tables\' centre is the canvas\'s; the upper table is '
      'drawn above (M-Z6)', (tester) async {
    final c = zoneController();
    c.setMode(FloorPlanMode.selection);
    await mountAt1440(tester, c);
    final box = boundOf(c.activeDocument, {'3', '7'});
    expect(box.maxX - box.minX + 1000, lessThan(3000),
        reason: 'premise: x at the minimum span');
    c.camera.value = zoneCamera();
    expect(c.fitToTables({'3', '7'}), isTrue);
    await tester.pump();
    await tester.pump();
    expectFramed(tester, c, {'3', '7'});
    final upper = boundOf(c.activeDocument, {'7'}).center;
    final lower = boundOf(c.activeDocument, {'3'}).center;
    expect(upper.y, greaterThan(lower.y), reason: 'premise: 7 is above');
    expect(
        globalOf(tester, c, upper).dy, lessThan(globalOf(tester, c, lower).dy));
  });

  testWidgets(
      'VZ6 a pending framing lands after the measured origin\'s correction: '
      'no view, a switch, a framing, a view whose canvas is not where the '
      'seed says (M-Z14)', (tester) async {
    final seeds = Map.of(floorPlanCanvasSeeds);
    addTearDown(() => floorPlanCanvasSeeds
      ..clear()
      ..addAll(seeds));
    floorPlanCanvasSeeds[FloorPlanMode.selection] = const Offset(130, 7);
    final c = zoneController();
    c.setMode(FloorPlanMode.selection);
    expect(c.fitToTables({'3'}), isTrue);
    await mountAt1440(tester, c);
    expect(
        tester.getTopLeft(find.byType(InteractionLayer)) -
            tester.getTopLeft(find.byType(FloorPlanView)),
        isNot(const Offset(130, 7)),
        reason: 'premise: the seed is wrong');
    expectFramed(tester, c, {'3'});
  });

  testWidgets(
      'VZ7 the design mode frames too, through the editor\'s view (M-Z15)',
      (tester) async {
    final c = zoneController();
    await mountAt1440(tester, c);
    expect(find.byType(PlannerShell), findsOneWidget);
    c.camera.value = zoneCamera();
    expect(c.fitToTables({'7'}), isTrue);
    await tester.pump();
    await tester.pump();
    expectFramed(tester, c, {'7'});
  });

  testWidgets(
      'VZ8 a failed framing leaves a pending one: no view, 3, then an '
      'unknown number; the view frames 3 (M-Z30)', (tester) async {
    final c = zoneController();
    c.takeFitOnStart();
    expect(c.fitToTables({'3'}), isTrue);
    expect(c.fitToTables({'nope'}), isFalse);
    await mountAt1440(tester, c);
    expectFramed(tester, c, {'3'});
  });

  testWidgets(
      'VZ9 a framing with no table left when performed fits the page and '
      'is done: the table undone, or its layer hidden (M-Z31)', (tester) async {
    final c = zoneController();
    c.takeFitOnStart();
    final d = c.activeDocument;
    d.commands.execute(placeSymbol(d, entryOf(trapezoidTable),
        at: Vector2(44000, -24000), mirrored: true));
    final number = TableSurvey.of(d).tables.last.number!;
    expect(c.fitToTables({number}), isTrue);
    c.undo();
    expect(TableSurvey.of(d).withNumber(number), isEmpty, reason: 'premise');
    await mountAt1440(tester, c);
    final first = c.camera.value;
    expect(c.takeFitOnStart(), isFalse, reason: 'done');
    expectCamera(first, await pageFit(tester, c), reason: 'undone');

    await tester.pumpWidget(viewApp(null));
    c.camera.value = zoneCamera();
    expect(c.fitToTables({'3'}), isTrue);
    final hidden =
        d.tables.layers.records.firstWhere((l) => l.name == 'Hidden');
    d.commands.execute(SetInstanceLayerCommand(
        TableSurvey.of(d).withNumber('3').single.instance, hidden.handle));
    await tester.pumpWidget(viewApp(c));
    await tester.pump();
    final second = c.camera.value;
    expect(c.takeFitOnStart(), isFalse, reason: 'done');
    expectCamera(second, await pageFit(tester, c), reason: 'hidden');
  });

  testWidgets(
      'VZ10 a framing asked in the design and a switch in one step: the old '
      'view does nothing; the selection mode\'s frames after its '
      'correction. A view unmounted in the step that asked does nothing '
      'either: the framing stays pending (M-Z33)', (tester) async {
    final seeds = Map.of(floorPlanCanvasSeeds);
    addTearDown(() => floorPlanCanvasSeeds
      ..clear()
      ..addAll(seeds));
    floorPlanCanvasSeeds[FloorPlanMode.selection] = const Offset(130, 7);
    final c = zoneController();
    await mountAt1440(tester, c);
    c.camera.value = zoneCamera();
    expect(c.fitToTables({'3'}), isTrue);
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    await tester.pump();
    expectFramed(tester, c, {'3'});

    // The host leaves the floor in the step that asks: the unmounted
    // view's posted fit neither moves the camera nor ends the request, so
    // the next view, in the other mode, frames.
    c.setMode(FloorPlanMode.design);
    await tester.pump();
    await tester.pump();
    c.camera.value = zoneCamera();
    expect(c.fitToTables({'A1', 'A2'}), isTrue);
    await tester.pumpWidget(viewApp(null));
    c.setMode(FloorPlanMode.selection);
    await tester.pumpWidget(viewApp(c));
    await tester.pump();
    expectFramed(tester, c, {'A1', 'A2'}, reason: 'remounted');
  });

  testWidgets(
      'VZ11 the view narrowed and a framing asked in one step: framed in '
      'the new canvas (M-Z41)', (tester) async {
    final c = zoneController();
    c.setMode(FloorPlanMode.selection);
    final width = ValueNotifier<double>(1440);
    addTearDown(width.dispose);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ValueListenableBuilder<double>(
                valueListenable: width,
                builder: (context, w, _) => Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                        width: w, child: FloorPlanView(controller: c)))))));
    await tester.pump();
    await tester.pump();
    final wide = tester.getSize(find.byType(InteractionLayer));
    c.camera.value = zoneCamera();
    width.value = 1010;
    expect(c.fitToTables({'3'}), isTrue);
    await tester.pump();
    await tester.pump();
    expect(tester.getSize(find.byType(InteractionLayer)).width,
        lessThan(wide.width),
        reason: 'premise: narrowed');
    expectFramed(tester, c, {'3'});
  });

  // Zone spec Z10-Z16: the focus's veil through the real view. The fixture
  // is `zone_fixture.dart`'s with a White page; the camera is panned, off
  // the pixel grid. A shot with the focus is compared with one of the same
  // scene without it: a faded quad is the paper at 0.6 over what it covers,
  // everything else unchanged.

  /// The zone fixture with a White page, in a controller; no view.
  FloorPlanController paged() {
    final c = FloorPlanController(json: zonePlanJson());
    addTearDown(c.dispose);
    final d = c.activeDocument;
    d.commands.execute(
        SetComponentCommand<PageComponent>(d.rootHandle, PageComponent()));
    return c;
  }

  /// [c]'s view in the window at 1440 x 900, device pixel ratio 1, under
  /// the planner's seed themes in [mode].
  Future<void> mountFocus(WidgetTester tester, FloorPlanController c,
      {ThemeMode mode = ThemeMode.light,
      void Function(String)? onTableTap,
      void Function()? onLayoutChanged,
      void Function(Set<String>)? onMergeRequested}) async {
    windowAt(tester, const Size(1440, 900));
    await pumpThemed(
        tester,
        Scaffold(
            body: FloorPlanView(
                controller: c,
                onTableTap: onTableTap,
                onLayoutChanged: onLayoutChanged,
                onMergeRequested: onMergeRequested)),
        mode);
    await tester.pump();
    await tester.pump();
  }

  /// The camera on world ([x], [y]) at the canvas's centre, [scale] px/mm,
  /// off the pixel grid.
  Future<void> aim(
      WidgetTester tester, FloorPlanController c, double x, double y,
      {double scale = 0.25}) async {
    final size = tester.getSize(find.byType(InteractionLayer));
    c.camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2(
            scale,
            0,
            0,
            -scale,
            size.width / 2 - scale * x + 0.31,
            size.height / 2 + scale * y + 0.17));
    await tester.pump();
  }

  /// [got] against [under] over the canvas (`checkVeil`), the quads read
  /// from the active plan now.
  VeilCheck compare(
      WidgetTester tester, FloorPlanController c, Shot under, Shot got,
      {required Set<String> focus,
      required int paper,
      Set<String> skipped = const {},
      Map<String, bool Function(double x, double y)> regions = const {}}) {
    final area = find.byType(InteractionLayer);
    final topLeft = tester.getTopLeft(area);
    final size = tester.getSize(area);
    expect(topLeft.dx, topLeft.dx.roundToDouble(), reason: 'whole pixels');
    expect(topLeft.dy, topLeft.dy.roundToDouble(), reason: 'whole pixels');
    final d = c.activeDocument;
    final check = checkVeil(
        camera: c.camera.value,
        left: topLeft.dx.toInt(),
        top: topLeft.dy.toInt(),
        width: size.width.toInt(),
        height: size.height.toInt(),
        under: under.rgbAt,
        got: got.rgbAt,
        // The hidden 5 is no candidate: neither faded nor focused.
        faded: quadsOf(
            d,
            (t) =>
                t.number != '5' &&
                !skipped.contains(t.number) &&
                !focus.contains(t.number)),
        focused: quadsOf(d, (t) => focus.contains(t.number)),
        paper: paper & 0xFFFFFF,
        regions: regions);
    expect(check.wrong, isEmpty,
        reason: '${check.mismatched} pixels wrong: ${check.wrong.join('; ')}');
    return check;
  }

  /// Table [n]'s quad in the active plan.
  TestQuad quad(FloorPlanController c, String n) =>
      quadsNumbered(c.activeDocument, n).single;

  /// The midpoint of tables 3 and 7, world.
  const midX = 40000.0, midY = -25800.0;

  testWidgets(
      'VF1 the design mode draws no veil: no veil layer, every pixel '
      'unchanged by a focus; the selection mode has the layer (M-Z16)',
      (tester) async {
    final c = paged();
    await mountFocus(tester, c);
    await aim(tester, c, midX, midY);
    final before = await shoot(tester);
    c.setTableFocus({'7'});
    await tester.pump();
    await tester.pump();
    expect(byKey('table-focus-layer'), findsNothing);
    final three = quad(c, '3');
    final after = await shoot(tester);
    final check = compare(tester, c, before, after,
        // Nothing veiled: every pixel the same.
        focus: {for (final t in c.tables) t.number ?? ''},
        paper: 0xFFFFFF,
        regions: {'3': (x, y) => three.holds(x, y, 0)});
    expect(check.counts['3'] ?? 0, greaterThan(20000),
        reason: 'premise: table 3 is on the canvas');

    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    await tester.pump();
    expect(byKey('table-focus-layer'), findsOneWidget);
  });

  testWidgets('VF2 the veil repaints on every setTableFocus (M-Z36)',
      (tester) async {
    final c = paged();
    c.setMode(FloorPlanMode.selection);
    await mountFocus(tester, c);
    final painter =
        tester.widget<CustomPaint>(byKey('table-focus-layer')).painter!;
    var repaints = 0;
    void count() => repaints++;
    painter.addListener(count);
    addTearDown(() => painter.removeListener(count));
    c.setTableFocus({'3'});
    expect(repaints, 1);
    c.setTableFocus({'3'});
    expect(repaints, 2, reason: 'an equal set');
    c.setTableFocus(null);
    expect(repaints, 3);
  });

  for (final (mode, paper) in [
    (ThemeMode.light, 0xFFFFFFFF),
    (ThemeMode.dark, kDarkCanvasPaper),
  ]) {
    testWidgets(
        'VF3 ${mode.name}: a faded statused pixel is the status over the '
        'paper, then the paper at 0.6 over it; a focused one the status '
        'alone (M-Z23, M-Z25)', (tester) async {
      const red = 0xC62828, green = 0x2E7D32;
      final c = paged();
      c.setMode(FloorPlanMode.selection);
      c.setTableStatus({
        '7': TableStatus(color: const Color(0xFF000000 | red)),
        '3': TableStatus(color: const Color(0xFF000000 | green)),
      });
      await mountFocus(tester, c, mode: mode);
      await aim(tester, c, midX, midY);
      final under = await shoot(tester);
      c.setTableFocus({'3'});
      await tester.pump();
      final got = await shoot(tester);
      final seven = quad(c, '7'), three = quad(c, '3');
      final check = compare(tester, c, under, got,
          focus: {'3'},
          paper: paper,
          regions: {
            '7': (x, y) => seven.holds(x, y, 0),
            '3': (x, y) => three.holds(x, y, 0),
          });
      expect(check.counts['7'] ?? 0, greaterThan(10000));
      expect(check.counts['3'] ?? 0, greaterThan(10000));
      // On each top, clear of its edges and its number.
      final area = tester.getTopLeft(find.byType(InteractionLayer));
      (int, int) pixel(TestQuad q) {
        final w = q.transform.transformPoint(Vector2(1200, 420));
        final s = c.camera.value.worldToScreen(w);
        return ((area.dx + s.x).floor(), (area.dy + s.y).floor());
      }

      final (x7, y7) = pixel(seven);
      final (x3, y3) = pixel(three);
      expect(under.rgbAt(x7, y7), red, reason: 'premise: 7\'s status');
      expect(rgbDistance(got.rgbAt(x7, y7), veilOver(paper & 0xFFFFFF, red)),
          lessThanOrEqualTo(1),
          reason: 'the paper at 0.6 over the status');
      expect(got.rgbAt(x3, y3), green, reason: 'the focused status alone');
    });
  }

  testWidgets(
      'VF4 the focus is kept by number: set in the design, shown after the '
      'switch; after a load where 7 is another instance, the veil follows '
      'the number (M-Z20)', (tester) async {
    final c = paged();
    c.setMode(FloorPlanMode.selection);
    await mountFocus(tester, c);
    await aim(tester, c, midX, midY);
    final under = await shoot(tester);
    final oldSeven = TableSurvey.of(c.activeDocument).withNumber('7').single;
    final oldThree = TableSurvey.of(c.activeDocument).withNumber('3').single;
    c.setMode(FloorPlanMode.design);
    await tester.pump();
    c.setTableFocus({'7'});
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    await tester.pump();
    final seven = quad(c, '7'), three = quad(c, '3');
    compare(tester, c, under, await shoot(tester), focus: {'7'}, paper: white);

    // 3 and 7 swap their labels in the plan loaded.
    final doc = DraftDocumentCodec.decodeString(zonePlanJson(),
        registerComponents: registerAppComponents);
    final s = TableSurvey.of(doc);
    final l3 = s.withNumber('3').single.label!,
        l7 = s.withNumber('7').single.label!;
    doc.commands
      ..execute(SetEntityTextCommand(l3, '7', kTableLabelTag))
      ..execute(SetEntityTextCommand(l7, '3', kTableLabelTag))
      ..execute(
          SetComponentCommand<PageComponent>(doc.rootHandle, PageComponent()));
    final swapped = DraftDocumentCodec.encodeToString(doc);
    doc.dispose();
    c.load(swapped);
    await tester.pump();
    await tester.pump();
    final now = TableSurvey.of(c.activeDocument);
    expect(now.withNumber('7').single.instance, oldThree.instance,
        reason: 'premise: 7 is the old 3\'s instance');
    expect(now.withNumber('3').single.instance, oldSeven.instance);
    await aim(tester, c, midX, midY);
    final got = await shoot(tester);
    c.setTableFocus(null);
    await tester.pump();
    final check = compare(tester, c, await shoot(tester), got,
        focus: {'7'},
        paper: white,
        regions: {
          'the new 7, clear': (x, y) => three.holds(x, y, 0),
          'the new 3, veiled': (x, y) => seven.holds(x, y, 0),
        });
    for (final name in check.regions) {
      expect(check.counts[name] ?? 0, greaterThan(10000), reason: name);
    }
  });

  testWidgets(
      'VF5 a faded table acts as any other: a tap reports and selects it, '
      'a drag moves it, select() selects it, the selection keeps it when '
      'the focus changes, Merge offers it (M-Z22)', (tester) async {
    final heard = <String>[];
    final merged = <Set<String>>[];
    var layouts = 0;
    final c = paged();
    c.setMode(FloorPlanMode.selection);
    await mountFocus(tester, c,
        onTableTap: heard.add,
        onLayoutChanged: () => layouts++,
        onMergeRequested: merged.add);
    final three = quad(c, '3');
    final at = three.centre;
    await aim(tester, c, at.x, at.y, scale: 0.37);
    c.setTableFocus({'7'});
    await tester.pump();
    Offset onThree() {
      final s = c.camera.value
          .worldToScreen(three.transform.transformPoint(Vector2(900, 650)));
      return tester.getTopLeft(find.byType(InteractionLayer)) +
          Offset(s.x, s.y);
    }

    await tester.tapAt(onThree(), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(heard, ['3']);
    expect(c.selectedTables.value, {'3'});

    final before = (c.activeDocument.tree[TableSurvey.of(c.activeDocument)
            .withNumber('3')
            .single
            .instance]! as InstanceNode)
        .transform;
    final g =
        await tester.startGesture(onThree(), kind: PointerDeviceKind.mouse);
    await g.moveBy(const Offset(45, -20));
    await g.moveBy(const Offset(45, -20));
    await g.up();
    await tester.pump();
    final after = (c.activeDocument.tree[TableSurvey.of(c.activeDocument)
            .withNumber('3')
            .single
            .instance]! as InstanceNode)
        .transform;
    expect(after.e, closeTo(before.e + 90 / 0.37, 1e-6), reason: 'moved');
    expect(after.f, closeTo(before.f + 40 / 0.37, 1e-6), reason: 'moved');
    expect(layouts, 1);

    c.select({'3', 'A1'});
    expect(c.selectedTables.value, {'3', 'A1'});
    c.setTableFocus({});
    await tester.pump();
    expect(c.selectedTables.value, {'3', 'A1'}, reason: 'kept');
    await tester.tap(byKey('service-merge'));
    await tester.pump();
    expect(merged, [
      {'3', 'A1'}
    ]);
  });

  testWidgets(
      'VF6 a table with a NaN translation or a singular transform is '
      'skipped, in both modes, by the framing, the veil and the pick; '
      'nothing throws; a table near the double range is framed by a finite '
      'camera, and a camera not finite is no framing (M-Z43; Task 1 review '
      'R-1)', (tester) async {
    final c = paged();
    c.setMode(FloorPlanMode.selection);
    await mountFocus(tester, c);
    await aim(tester, c, midX, midY);
    final under = await shoot(tester);

    void spoil() {
      final d = c.activeDocument;
      final s = TableSurvey.of(d);
      d.commands
        ..execute(TransformNodeCommand(s.withNumber('A1').single.instance,
            Transform2(0.8, 0.6, -0.6, 0.8, double.nan, -36000)))
        ..execute(TransformNodeCommand(s.withNumber('A2').single.instance,
            const Transform2(1, 2, 2, 4, 50000, -36000)))
        // Task 1 review R-1: its four corners finite, near the double
        // range.
        ..execute(TransformNodeCommand(s.withNumber('B4').single.instance,
            Transform2(0.8, 0.6, -0.6, 0.8, 1.7e308, -31000)));
    }

    void expectSkipped(String mode) {
      final d = c.activeDocument;
      c.camera.value = zoneCamera();
      const size = Size(1200, 900);
      // R-1: a table near the double range is framed by a finite camera;
      // a camera that is not finite is no framing.
      expect(c.fitToTables({'B4'}), isTrue, reason: '$mode: far');
      final framed = c.framingFor(size);
      expect(framed, isNotNull, reason: '$mode: far, framed');
      final far = framed!.worldToScreenMatrix;
      expect(
          [far.a, far.b, far.c, far.d, far.e, far.f].every((v) => v.isFinite),
          isTrue,
          reason: '$mode: far, finite');
      expectCamera(c.framingFor(size), frameTables(boundOf(d, {'B4'}), size),
          reason: '$mode: far');
      expect(c.framingFor(const Size(double.infinity, 900)), isNull,
          reason: '$mode: an infinite camera is no framing');
      expect(c.fitToTables({'A1'}), isFalse, reason: '$mode: NaN');
      expect(c.fitToTables({'A2'}), isFalse, reason: '$mode: singular');
      expect(c.fitToTables({'A1', 'A2', '3'}), isTrue, reason: mode);
      expectCamera(c.framingFor(size), frameTables(boundOf(d, {'3'}), size),
          reason: '$mode: 3 alone');
      final skipped = {
        for (final n in ['A1', 'A2'])
          TableSurvey.of(d).withNumber(n).single.instance
      };
      expect(
          TablePicker(d)
              .candidates
              .where((p) => skipped.contains(p.table.instance)),
          isEmpty,
          reason: '$mode: the pick');
    }

    spoil();
    await tester.pump();
    expectSkipped('selection');
    // The framing of 3 is performed; then the camera goes back.
    await tester.pump();
    await tester.pump();
    expectFramed(tester, c, {'3'});
    await aim(tester, c, midX, midY);
    c.setTableFocus({});
    await tester.pump();
    await tester.pump();
    final three = quad(c, '3');
    final check = compare(tester, c, under, await shoot(tester),
        focus: {},
        paper: white,
        skipped: {'A1', 'A2', 'B4'},
        regions: {'3, veiled': (x, y) => three.holds(x, y, 0)});
    expect(check.counts['3, veiled'] ?? 0, greaterThan(10000));

    c.setMode(FloorPlanMode.design);
    await tester.pumpWidget(const SizedBox());
    spoil();
    expectSkipped('design');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'VZ12 fitToTables copies and trims the host\'s set: " 3 " and a blank, '
      'the set cleared before a view mounts, frames 3 (M-Z34; Task 1 review '
      'R-2)', (tester) async {
    final c = zoneController();
    c.takeFitOnStart(); // a host whose plan was already shown and fitted
    final mine = {' 3 ', ''};
    expect(c.fitToTables(mine), isTrue);
    mine.clear(); // the host reuses its set
    await mountAt1440(tester, c);
    expectFramed(tester, c, {'3'});
  });

  testWidgets(
      'VF7 a focus asked as " 7 " focuses 7; the host\'s set changed after '
      'the call changes no veil; {\'\'} veils every table (M-Z34, M-Z35, '
      'M-Z26)', (tester) async {
    final c = paged();
    c.setMode(FloorPlanMode.selection);
    await mountFocus(tester, c);
    await aim(tester, c, midX, midY);
    final under = await shoot(tester);
    final seven = quad(c, '7'), three = quad(c, '3');
    final regions = {
      '7': (double x, double y) => seven.holds(x, y, 0),
      '3': (double x, double y) => three.holds(x, y, 0),
    };

    c.setTableFocus({' 7 '});
    await tester.pump();
    var check = compare(tester, c, under, await shoot(tester),
        focus: {'7'}, paper: white, regions: regions);
    expect(check.counts['7'] ?? 0, greaterThan(10000), reason: '7 clear');

    final mine = {'7'};
    c.setTableFocus(mine);
    mine.add('3');
    // A change off the canvas rebuilds the veil.
    move(c, 'B4', 300, 0);
    await tester.pump();
    await tester.pump();
    check = compare(tester, c, under, await shoot(tester),
        focus: {'7'}, paper: white, regions: regions);
    expect(check.counts['3'] ?? 0, greaterThan(10000), reason: '3 veiled');

    c.setTableFocus({''});
    await tester.pump();
    check = compare(tester, c, under, await shoot(tester),
        focus: {}, paper: white, regions: regions);
    expect(check.counts['7'] ?? 0, greaterThan(10000), reason: '7 veiled');
  });
}
