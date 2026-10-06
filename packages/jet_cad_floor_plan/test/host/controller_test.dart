// Spec 14b-2 H1-H4, H11-H14: the host controller -- the designed plan and
// the service copy, the modes, the save point, undo and redo of the active
// plan, tables and the selection by number. Tables are placed off the
// origin, turned and mirrored; one plan carries a number twice (a
// hand-edited file).
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
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
    expect(c.numberingWarnings, const [DuplicateNumber(number: '2', count: 2)]);
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

  testWidgets(
      'C12 a load forgets the last designJson\'s state (review m31); a '
      'bad json at construction is a FormatException (review F-5)',
      (tester) async {
    final c = controller(tester, planJson());
    drawLine(c);
    drawLine(c);
    drawLine(c);
    c.designJson(); // state 3 of the old plan
    c.load(planJson());
    drawLine(c);
    c.markSaved(); // the new plan's current state
    await tester.pump();
    expect(c.dirty.value, isFalse);
    expect(() => FloorPlanController(json: '{"entities": 7}'),
        throwsFormatException);
  });

  testWidgets(
      'C13 selectedTables holds numbered tables only: an unnumbered table '
      'and a planter selected by hand are not in it (review m40); a hidden '
      'table is not selectable (review m11b)', (tester) async {
    final c = controller(tester, planJson());
    final doc = c.activeDocument;
    doc.commands.execute(placeSymbol(doc, entryOf(tableSymbol()),
        at: Vector2(-4000, -3000), numbered: false));
    final survey = TableSurvey.of(doc);
    final bare = survey.tables.firstWhere((t) => t.number == null).instance;
    final planter = doc.tree.nodes
        .whereType<InstanceNode>()
        .firstWhere((n) => !survey.tables.any((t) => t.instance == n.handle))
        .handle;
    c.activeSelection.replace([
      SelectionKey.root(bare),
      SelectionKey.root(planter),
      SelectionKey.root(survey.withNumber('3').single.instance),
    ]);
    await tester.pump();
    expect(c.selectedTables.value, {'3'});

    final zero = doc.tables.layers[ReservedHandles.layerZero]!;
    final hidden = doc.handleSeed.next();
    doc.commands.execute(AddLayerCommand(LayerRecord(
        handle: hidden,
        name: 'Hidden',
        color: const IndexedColor(2),
        linetype: zero.linetype,
        lineweight: zero.lineweight,
        transparency: zero.transparency,
        visible: false,
        locked: false)));
    doc.commands
        .execute(SetInstanceLayerCommand(tableNode(doc, '1').handle, hidden));
    c.select({'1', '2'});
    expect(c.selectedTables.value, {'2'});
    await tester.pump();
  });

  testWidgets(
      'C14 revision moves on every change of the active plan, and only of '
      'it (demo review F-1)', (tester) async {
    final c = controller(tester, planJson());
    var r = c.revision.value;
    int moved() {
      final d = c.revision.value - r;
      r = c.revision.value;
      return d;
    }

    drawLine(c);
    await tester.pump();
    expect(moved(), 1);
    c.undo();
    await tester.pump();
    expect(moved(), 1);
    c.setMode(FloorPlanMode.selection);
    expect(moved(), 1);
    move(c, '1', 300, 0);
    await tester.pump();
    expect(moved(), 1);
    c.resetLayout();
    expect(moved(), 1);
    c.load(planJson());
    expect(moved(), 1);
    c.select({'1'});
    await tester.pump();
    expect(moved(), 0, reason: 'a selection is not a change of the plan');
  });

  testWidgets(
      'C15 statuses are not plan state: no revision, dirty, history or json '
      'change; numbers trimmed; kept across a switch and a load (M-14d)',
      (tester) async {
    final c = controller(tester, planJson());
    final json = c.designJson();
    final revision = c.revision.value;
    var heard = 0;
    c.tableStatuses.addListener(() => heard++);
    c.setTableStatus({' 1 ': TableStatus(color: const Color(0xFFE53935))});
    await tester.pump();
    expect(heard, 1);
    expect(c.tableStatuses.value.keys, ['1']);
    expect(c.revision.value, revision);
    expect(c.dirty.value, isFalse);
    expect(c.canUndo.value, isFalse);
    expect(c.designJson(), json);
    c.setMode(FloorPlanMode.selection);
    c.load(planJson());
    expect(c.tableStatuses.value.keys, ['1']);
    await tester.pump();
  });

  testWidgets(
      'C16 the service layout: null in the design mode; a restore puts '
      'the moves back as the copy\'s floor, re-selects by number, and no '
      'Undo removes it (spec 14d S1-S3, M-14d-m, M-14d-t)', (tester) async {
    final c = controller(tester, planJson());
    expect(c.serviceLayoutJson(), isNull);
    c.setMode(FloorPlanMode.selection);
    expect(jsonDecode(c.serviceLayoutJson()!)['tables'], isEmpty);
    move(c, '1', 750.25, -250.5);
    move(c, '3', -125.125, 400.75);
    final want1 = parts(tableNode(c.activeDocument, '1').transform);
    final want3 = parts(tableNode(c.activeDocument, '3').transform);
    final json = c.serviceLayoutJson()!;
    await tester.pump();

    c.setMode(FloorPlanMode.design);
    c.setMode(FloorPlanMode.selection);
    expect(c.serviceEdited, isFalse, reason: 'premise: a fresh copy');
    c.select({'2'});
    final copy = c.activeDocument;
    final restored = c.restoreServiceLayout(json);
    expect(restored.applied, ['1', '3']);
    expect(restored.dropped, isEmpty);
    expect(identical(c.activeDocument, copy), isFalse, reason: 'a new copy');
    expect(parts(tableNode(c.activeDocument, '1').transform), want1);
    expect(parts(tableNode(c.activeDocument, '3').transform), want3);
    expect(c.selectedTables.value, {'2'});
    expect(c.serviceEdited, isTrue);
    expect(c.canUndo.value, isFalse, reason: 'the restore is no step');
    c.undo();
    expect(parts(tableNode(c.activeDocument, '1').transform), want1);
    expect(c.serviceLayoutJson(), json);
    await tester.pump();
  });

  testWidgets(
      'C17 serviceEdited is the layout, not the depth: a table dragged back '
      'exactly is no edit; a restore, a move and its undo still are '
      '(spec 14d S3, M-14d-m)', (tester) async {
    final c = controller(tester, planJson());
    c.setMode(FloorPlanMode.selection);
    move(c, '2', 333.5, -71.25);
    move(c, '2', -333.5, 71.25);
    expect(c.activeDocument.commands.undoDepth, 2, reason: 'premise');
    expect(c.serviceEdited, isFalse);

    move(c, '1', 90.5, 12.75);
    final json = c.serviceLayoutJson()!;
    c.resetLayout();
    expect(c.serviceEdited, isFalse);
    c.restoreServiceLayout(json);
    move(c, '3', 15.5, 15.5);
    c.undo();
    expect(c.activeDocument.commands.undoDepth, 0, reason: 'premise');
    expect(c.serviceEdited, isTrue);
    await tester.pump();
  });

  testWidgets(
      'C18 serviceLayoutChanges fires on a move, Undo, Redo, resetLayout and '
      'a restore, never on a mode switch or a load (spec 14d S4, M-14d-r)',
      (tester) async {
    final c = controller(tester, planJson());
    var heard = 0;
    c.serviceLayoutChanges.addListener(() => heard++);
    Future<int> after(void Function() act) async {
      final before = heard;
      act();
      await tester.pump();
      return heard - before;
    }

    expect(await after(() => move(c, '1', 10.5, 0)), 0,
        reason: 'a design edit is not the service layout');
    expect(await after(() => c.setMode(FloorPlanMode.selection)), 0);
    expect(await after(() => move(c, '1', 20.25, 5)), 1);
    final json = c.serviceLayoutJson()!;
    expect(await after(c.undo), 1);
    expect(await after(c.redo), 1);
    expect(await after(c.resetLayout), 1);
    expect(await after(() => c.restoreServiceLayout(json)), 1);
    expect(await after(() => c.load(planJson())), 0);
    expect(await after(() => c.setMode(FloorPlanMode.design)), 0);
  });

  testWidgets(
      'C20 an Undo followed at once by a switch to the design is heard, '
      'before the switch: a host saving on it keeps the undone layout '
      '(review 14d-2)', (tester) async {
    final c = controller(tester, planJson());
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    final saved = <String?>[];
    c.serviceLayoutChanges.addListener(() => saved.add(c.serviceLayoutJson()));
    move(c, '1', 20.25, 5);
    await tester.pump();
    expect(saved, hasLength(1), reason: 'premise: the move is heard');
    expect(saved.last, contains('"tables":[{'), reason: 'premise: a move');
    c.undo();
    c.setMode(FloorPlanMode.design);
    expect(saved, hasLength(2), reason: 'heard before the switch');
    expect(saved.last, contains('"tables":[]'));
    await tester.pump();
    expect(saved, hasLength(2), reason: 'and only once');
  });

  testWidgets(
      'C19 a restore in the design mode is a StateError; a text that is not '
      'a layout changes nothing; a stale entry is dropped (spec 14d S2)',
      (tester) async {
    final c = controller(tester, planJson());
    expect(() => c.restoreServiceLayout('{}'), throwsStateError);
    c.setMode(FloorPlanMode.selection);
    move(c, '1', 44.5, 0);
    move(c, '2', 0, -61.75);
    final json = c.serviceLayoutJson()!;
    final copy = c.activeDocument;
    final revision = c.revision.value;
    expect(
        () => c.restoreServiceLayout('{"format":"x"}'), throwsFormatException);
    expect(identical(c.activeDocument, copy), isTrue);
    expect(c.revision.value, revision);

    // The design moves table 2 after the layout was stored.
    c.setMode(FloorPlanMode.design);
    move(c, '2', 5, 5);
    final designed2 = parts(tableNode(c.activeDocument, '2').transform);
    c.setMode(FloorPlanMode.selection);
    final r = c.restoreServiceLayout(json);
    expect(r.applied, ['1']);
    expect(r.dropped, ['2']);
    expect(parts(tableNode(c.activeDocument, '2').transform), designed2,
        reason: 'a dropped entry leaves the table at its designed place');
    await tester.pump();
  });
}
