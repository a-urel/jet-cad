// The editor's fixture: the embedding fixture's page (originX 37000,
// originY -36200, as `jet_cad_floor_plan/test/host/embedding_fixture.dart:
// 131-132`), two turned marks and a line around the sheet's centre, saved;
// the camera the bar tests measured under (`embeddingCamera`, `:160-161`);
// and the editor pumped at 1440 x 900.
import 'dart:async' show Completer;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ViewportTransform;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show PlanKit, SymbolLibrarySource;
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/editor/plan_editor.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'mark_kit.dart';

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

/// The marks of [editorPlanJson], in order.
const int kEditorMarks = 2;

/// The name of [editorPlanJson]'s locked layer (`lockedLayer: true`).
const String kEditorLocked = 'B';

/// The fixture's plan; with [lockedLayer], a layer `B` (ACI 5, locked,
/// visible, not current) beside layer 0, as `layerPlan`'s, and nothing on
/// it (the embedding fixture's `kEmbeddingLocked`).
String editorPlanJson({bool lockedLayer = false}) {
  final scratch = PlanController(kits: [markKit()]);
  final doc = scratch.document;
  final root = doc.rootHandle;
  if (lockedLayer) {
    final zero = doc.tables.layers[ReservedHandles.layerZero]!;
    doc.commands.execute(AddLayerCommand(LayerRecord(
      handle: doc.handleSeed.next(),
      name: kEditorLocked,
      color: const IndexedColor(5),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency,
      visible: true,
      locked: true,
    )));
  }
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
  await tester
      .pumpWidget(MaterialApp(theme: theme, home: Scaffold(body: editor)));
  await tester.pump();
  await tester.pump();
  editor.controller.camera.value = embeddingCamera();
  await tester.pump();
}

Finder byKey(String k) => find.byKey(Key(k));

double left(WidgetTester tester, String k) => tester.getTopLeft(byKey(k)).dx;
double right(WidgetTester tester, String k) => tester.getTopRight(byKey(k)).dx;
