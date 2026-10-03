// Spec 14b-2 H5-H7, H11, R-2, R-9: the host's view -- the design mode's
// editor with Export and Print and no file commands, the selection mode's
// canvas over the service copy, the settle before a switch, the drop rule,
// and Export of what is on screen in both modes. Tables are placed on the
// page, off its centre, turned and mirrored.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:jet_cad_floor_plan/src/new_document.dart';
import 'package:jet_cad_floor_plan/src/planner_shell.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tables/table_fixture.dart';

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

Future<FloorPlanController> pumpView(WidgetTester tester,
    {void Function(FloorPlanExport)? onExport}) async {
  final c = FloorPlanController(json: pagePlan());
  addTearDown(c.dispose);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: FloorPlanView(controller: c, onExport: onExport))));
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
      'V3 a switch, a reset and a load with the view mounted dispose the '
      'old plans after the frame (M-14b2-12)', (tester) async {
    final c = await pumpView(tester);
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    move(c, '1', 500, 0);
    c.resetLayout();
    await tester.pump();
    await tester.pump();
    c.setMode(FloorPlanMode.design);
    await tester.pump();
    await tester.pump();
    c.load(pagePlan());
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(c.tables, hasLength(2));
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

  testWidgets('V7 the camera survives a mode switch (R-13)', (tester) async {
    final c = await pumpView(tester);
    c.camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2(0.07, 0, 0, -0.07, -310, 2400));
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    await tester.pump();
    expect(c.camera.value.worldToScreenMatrix.a, 0.07);
    expect(c.camera.value.worldToScreenMatrix.e, -310);
    c.fitToView();
    await tester.pump();
    await tester.pump();
    expect(c.camera.value.worldToScreenMatrix.a, isNot(0.07));
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
}
