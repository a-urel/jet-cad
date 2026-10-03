// Spec 14b-2 H1-H4, H11-H14: the host controller -- the designed plan and
// the service copy, the modes, the save point, undo and redo of the active
// plan, tables and the selection by number. Tables are placed off the
// origin, turned and mirrored; one plan carries a number twice (a
// hand-edited file).
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tables/table_fixture.dart';

/// A plan: tables 1 (turned, mirrored), 2 and 3, a planter, and a line;
/// [duplicate] renames table 3 to "2".
String planJson({bool duplicate = false, Vector2? secondAt}) {
  final doc = plan();
  doc.commands.execute(placeSymbol(doc, entryOf(tableSymbol()),
      at: Vector2(-2600, 1400), quarterTurns: 1, mirrored: true));
  doc.commands.execute(placeSymbol(doc, entryOf(tableSymbol()),
      at: secondAt ?? Vector2(2300, 1400)));
  doc.commands.execute(placeSymbol(doc, entryOf(stoolSymbol),
      at: Vector2(300, -2100), quarterTurns: 2));
  doc.commands.execute(
      placeSymbol(doc, entryOf(planterSymbol), at: Vector2(4100, -900)));
  if (duplicate) {
    doc.commands.execute(
        SetEntityTextCommand(tablesOf(doc).last.label!, '2', kTableLabelTag));
  }
  return DraftDocumentCodec.encodeToString(doc);
}

/// The instance of the table numbered [n] in [doc].
InstanceNode tableNode(DraftDocument doc, String n) =>
    doc.tree[TableSurvey.of(doc).withNumber(n).single.instance]!
        as InstanceNode;

List<double> parts(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];

/// A service move: table [n] translated.
void move(FloorPlanController c, String n, double dx, double dy) {
  final node = tableNode(c.activeDocument, n);
  c.activeDocument.commands.execute(CompoundCommand([
    TransformNodeCommand(
        node.handle, Transform2.translation(dx, dy).multiply(node.transform))
  ], label: 'Move'));
}

/// A design edit: a line on layer 0.
void drawLine(FloorPlanController c) {
  final doc = c.activeDocument;
  doc.commands.execute(AddEntityCommand(
      record: tableLabelRecord(
              handle: doc.handleSeed.next(),
              instance: doc.rootHandle,
              number: '')
          .copyWith(kind: EntityKind.line, tag: ''),
      payload: GeometryPayload(
          coords: Float64List.fromList([-500, 700, 1800, 2400]),
          scalars: Float64List(0))));
}

FloorPlanController controller(WidgetTester tester, String json) {
  final c = FloorPlanController(json: json);
  addTearDown(c.dispose);
  return c;
}

void main() {
  testWidgets('C1 the design mode, clean, with the plan\'s tables',
      (tester) async {
    final c = controller(tester, planJson());
    expect(c.mode.value, FloorPlanMode.design);
    expect(c.dirty.value, isFalse);
    expect(c.tables, const [
      FloorPlanTable(number: '1', seats: 2, symbolKey: 'test.table'),
      FloorPlanTable(number: '2', seats: 2, symbolKey: 'test.table'),
      FloorPlanTable(number: '3', seats: 1, symbolKey: 'test.stool'),
    ]);
    expect(c.canUndo.value, isFalse, reason: 'a loaded plan has no history');
  });

  testWidgets(
      'C2 the barrier: service edits never reach the design, and the '
      'selection mode\'s Undo and Redo never reach a design edit (M-14f, '
      'M-14b2-1)', (tester) async {
    final c = controller(tester, planJson());
    drawLine(c);
    drawLine(c);
    c.undo(); // one design step on the redo stack
    await tester.pump();
    final design = c.designJson();
    final depth = c.activeDocument.commands.undoDepth;
    expect(c.canRedo.value, isTrue);
    expect(c.dirty.value, isTrue);
    c.markSaved();
    await tester.pump();
    expect(c.dirty.value, isFalse);

    c.setMode(FloorPlanMode.selection);
    expect(c.canUndo.value, isFalse, reason: 'the copy has no history');
    expect(c.canRedo.value, isFalse);
    move(c, '1', 750, -250);
    move(c, '2', -125, 400);
    await tester.pump();
    expect(c.designJson(), design, reason: 'the design is untouched');
    expect(c.dirty.value, isFalse);
    expect(c.serviceEdited, isTrue);

    for (var k = 0; k < 5; k++) {
      c.undo();
    }
    await tester.pump();
    expect(c.canUndo.value, isFalse);
    expect(c.designJson(), design);
    for (var k = 0; k < 5; k++) {
      c.redo();
    }
    await tester.pump();
    expect(c.canRedo.value, isFalse);
    expect(c.designJson(), design, reason: 'Redo never redoes a design edit');

    c.setMode(FloorPlanMode.design);
    await tester.pump();
    expect(c.activeDocument.commands.undoDepth, depth,
        reason: 'the design\'s history is the same');
    expect(c.canRedo.value, isTrue);
    expect(c.designJson(), design);
  });

  testWidgets(
      'C3 leaving the selection mode discards the copy; re-entering shows '
      'the design (M-14b2-2)', (tester) async {
    final c = controller(tester, planJson());
    final designed = parts(tableNode(c.activeDocument, '1').transform);
    c.setMode(FloorPlanMode.selection);
    move(c, '1', 750, -250);
    expect(parts(tableNode(c.activeDocument, '1').transform), isNot(designed));
    c.setMode(FloorPlanMode.design);
    c.setMode(FloorPlanMode.selection);
    expect(parts(tableNode(c.activeDocument, '1').transform), designed);
    await tester.pump();
  });

  testWidgets('C4 the copy refuses geometry and structure (M-14b2-6)',
      (tester) async {
    final c = controller(tester, planJson());
    c.setMode(FloorPlanMode.selection);
    expect(c.activeDocument.commands.permissions, DraftPermissions.runtime);
    expect(() => drawLine(c), throwsA(isA<PermissionDeniedError>()));
    expect(() => move(c, '3', 10, 10), returnsNormally,
        reason: 'a move is a transform');
    await tester.pump();
  });

  testWidgets(
      'C5 load clears the selection and rebuilds the copy from the new '
      'plan (M-14b2-3)', (tester) async {
    final c = controller(tester, planJson());
    c.setMode(FloorPlanMode.selection);
    c.select({'1', '2'});
    expect(c.selectedTables.value, {'1', '2'});
    move(c, '2', 900, 900);
    // The same plan, table 2 elsewhere: same handles, same numbers.
    c.load(planJson(secondAt: Vector2(5000, -3700)));
    expect(c.mode.value, FloorPlanMode.selection);
    expect(c.selectedTables.value, isEmpty);
    final placed = placementAt(5000, -3700, 0);
    expect(parts(tableNode(c.activeDocument, '2').transform), parts(placed));
    expect(c.dirty.value, isFalse);
    await tester.pump();
  });

  testWidgets('C6 a number used twice selects both tables (M-14b2-4)',
      (tester) async {
    final c = controller(tester, planJson(duplicate: true));
    c.select({'2'});
    final keys = c.activeSelection.keys;
    expect(keys, hasLength(2));
    expect(c.selectedTables.value, {'2'});
    c.select({'99'});
    expect(c.activeSelection.keys, isEmpty);
    expect(c.numberingWarnings, ['Number 2 is used by 2 tables']);
    await tester.pump();
  });

  testWidgets(
      'C7 a renumber is in tables at once and in selectedTables after the '
      'change (M-14b2-5, M-14b2-13)', (tester) async {
    final c = controller(tester, planJson());
    c.select({'1'});
    final label =
        TableSurvey.of(c.activeDocument).withNumber('1').single.label!;
    c.activeDocument.commands
        .execute(SetEntityTextCommand(label, 'B7', kTableLabelTag));
    expect(c.tables.first.number, 'B7', reason: 'synchronous');
    await tester.pump();
    expect(c.selectedTables.value, {'B7'});
  });

  testWidgets(
      'C8 a bad plan changes nothing: broken structure, unknown schema '
      '(M-14b2-8)', (tester) async {
    final c = controller(tester, planJson());
    c.setMode(FloorPlanMode.selection);
    c.select({'3'});
    move(c, '3', -300, 200);
    final moved = parts(tableNode(c.activeDocument, '3').transform);
    final document = c.activeDocument;
    final good = jsonDecode(planJson()) as Map<String, Object?>;
    final broken = jsonEncode({...good, 'entities': 7});
    final future = jsonEncode({...good, 'schemaVersion': 9999});
    for (final bad in [broken, future, '{}']) {
      expect(() => c.load(bad), throwsFormatException, reason: bad);
    }
    expect(c.activeDocument, same(document));
    expect(c.mode.value, FloorPlanMode.selection);
    expect(c.selectedTables.value, {'3'});
    expect(parts(tableNode(c.activeDocument, '3').transform), moved);
    await tester.pump();
  });

  testWidgets(
      'C9 markSaved marks the state the last designJson encoded (M-14b2-14)',
      (tester) async {
    final c = controller(tester, planJson());
    drawLine(c);
    c.designJson();
    drawLine(c); // lands while the host writes
    c.markSaved();
    await tester.pump();
    expect(c.dirty.value, isTrue);
    c.designJson();
    c.markSaved();
    await tester.pump();
    expect(c.dirty.value, isFalse);
  });

  testWidgets(
      'C10 the selection survives a mode switch and resetLayout; a hidden or '
      'locked table cannot be selected (H13)', (tester) async {
    final c = controller(tester, planJson());
    c.select({'1', '3'});
    c.setMode(FloorPlanMode.selection);
    expect(c.selectedTables.value, {'1', '3'});
    move(c, '1', 600, 0);
    c.resetLayout();
    expect(c.selectedTables.value, {'1', '3'});
    expect(c.serviceEdited, isFalse);
    c.setMode(FloorPlanMode.design);
    expect(c.selectedTables.value, {'1', '3'});

    // Table 2 on a locked layer.
    final doc = c.activeDocument;
    final zero = doc.tables.layers[ReservedHandles.layerZero]!;
    final locked = doc.handleSeed.next();
    doc.commands.execute(AddLayerCommand(LayerRecord(
        handle: locked,
        name: 'Locked',
        color: const IndexedColor(5),
        linetype: zero.linetype,
        lineweight: zero.lineweight,
        transparency: zero.transparency,
        visible: true,
        locked: true)));
    doc.commands
        .execute(SetInstanceLayerCommand(tableNode(doc, '2').handle, locked));
    c.select({'2', '3'});
    expect(c.selectedTables.value, {'3'});
    await tester.pump();
  });

  testWidgets('C11 newPlan is empty and clean; load of a plan is clean',
      (tester) async {
    final c = controller(tester, planJson());
    drawLine(c);
    await tester.pump();
    expect(c.dirty.value, isTrue);
    c.newPlan();
    await tester.pump();
    expect(c.tables, isEmpty);
    expect(c.dirty.value, isFalse);
    c.load(planJson());
    expect(c.tables, hasLength(3));
    await tester.pump();
  });
}
