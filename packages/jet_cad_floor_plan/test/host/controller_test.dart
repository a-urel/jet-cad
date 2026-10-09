// Spec 14b-2 H1-H4, H11-H14: the host controller -- the designed plan and
// the service copy, the modes, the save point, undo and redo of the active
// plan, tables and the selection by number. Tables are placed off the
// origin, turned and mirrored; one plan carries a number twice (a
// hand-edited file).
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Color, Size;

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/host/table_fit.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tables/table_fixture.dart';
import 'embedding_fixture.dart' as embedding;
import 'zone_fixture.dart';

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

  // Zone spec Z1-Z9: framing tables by number. The fixture is
  // `zone_fixture.dart`'s; a non-identity camera is set before every call.

  FloorPlanController zoned(WidgetTester tester) {
    final c = controller(tester, zonePlanJson());
    c.cameraController.value = zoneCamera();
    return c;
  }

  const zoneSize = Size(1200, 900);

  testWidgets(
      'CZ1 a turned, mirrored table 40 m off the origin is framed by the '
      'four corners of its box; table " 7 " by 7, not the TEXT or the room '
      'named 7 (M-Z1, M-Z3)', (tester) async {
    final c = zoned(tester);
    final d = c.activeDocument;
    final three = tableNode(d, '3').transform;
    expect(three.determinant, lessThan(0), reason: 'premise: mirrored');
    expect(three.b, isNot(0), reason: 'premise: turned');
    expect(three.e.abs(), greaterThan(30000), reason: 'premise: off origin');
    expect(c.fitToTables({'3'}), isTrue);
    expectCamera(
        c.framingFor(zoneSize), frameTables(boundOf(d, {'3'}), zoneSize));

    final label = TableSurvey.of(d).withNumber('7').single.label!;
    expect(d.entities.read(d.entities.slotOf(label)!).text, ' 7 ',
        reason: 'premise: labelled with spaces');
    final seven = boundOf(d, {'7'});
    final looks = sevenTexts(d);
    expect(looks, hasLength(2), reason: 'premise: the TEXT and the room name');
    for (final p in looks) {
      expect(seven.expandedBy(15000).containsPoint(p), isFalse,
          reason: 'premise: far from table 7');
    }
    c.cameraController.value = zoneCamera();
    expect(c.fitToTables({'7'}), isTrue);
    expectCamera(c.framingFor(zoneSize), frameTables(seven, zoneSize));
  });

  testWidgets('CZ2 a hidden table is not framed, a locked one is (M-Z2, M-Z40)',
      (tester) async {
    final c = zoned(tester);
    final d = c.activeDocument;
    expect(c.fitToTables({'5'}), isFalse, reason: 'hidden');
    expect(c.framingFor(zoneSize), isNull);
    c.cameraController.value = zoneCamera();
    expect(c.fitToTables({'5', '3'}), isTrue);
    expectCamera(
        c.framingFor(zoneSize), frameTables(boundOf(d, {'3'}), zoneSize),
        reason: '3 alone');
    c.cameraController.value = zoneCamera();
    expect(c.fitToTables({'L'}), isTrue, reason: 'locked');
    expectCamera(
        c.framingFor(zoneSize), frameTables(boundOf(d, {'L'}), zoneSize));
  });

  testWidgets(
      'CZ3 two tables 10 m apart in x, where x binds: the scale holds the '
      'bound and twice the 500 mm margin (M-Z5)', (tester) async {
    final c = zoned(tester);
    final box = boundOf(c.activeDocument, {'A1', 'A2'});
    final w = box.maxX - box.minX, h = box.maxY - box.minY;
    expect(w, greaterThan(10000), reason: 'premise');
    expect(h + 2 * 500, lessThan(3000), reason: 'premise: y at the minimum');
    expect(zoneSize.width / (w + 1000), lessThan(zoneSize.height / 3000),
        reason: 'premise: x binds');
    expect(c.fitToTables({'A1', 'A2'}), isTrue);
    final a = c.framingFor(zoneSize)!.worldToScreenMatrix.a;
    final want = 0.95 * zoneSize.width / (w + 2 * 500);
    expect(a, closeTo(want, 1e-12 * want));
  });

  testWidgets('CZ4 a number used twice frames both tables (M-Z13)',
      (tester) async {
    final c = zoned(tester);
    final both = boundOf(c.activeDocument, {'2'});
    expect(both.maxY - both.minY, greaterThan(6000), reason: 'premise: two');
    expect(c.fitToTables({'2'}), isTrue);
    expectCamera(c.framingFor(zoneSize), frameTables(both, zoneSize));
  });

  testWidgets(
      'CZ5 none found: false, and nothing changes -- no request, the '
      'camera, no pending fit (M-Z7)', (tester) async {
    final c = zoned(tester);
    c.takeFitOnStart(); // a host whose plan was already shown and fitted
    var requests = 0;
    c.fitRequests.addListener(() => requests++);
    final camera = c.cameraController.value;
    for (final none in [
      {'nope'},
      {'5'},
      {'', '  '},
      <String>{},
    ]) {
      expect(c.fitToTables(none), isFalse, reason: '$none');
    }
    expect(requests, 0);
    expect(c.cameraController.value, same(camera));
    expect(c.framingFor(zoneSize), isNull);
    expect(c.takeFitOnStart(), isFalse);
  });

  testWidgets(
      'CZ6 framing is not plan state: no json, dirty, undo depth, revision, '
      'layout change, notification or settle, in either mode (M-Z11)',
      (tester) async {
    final c = zoned(tester);
    drawLine(c);
    await tester.pump();
    var notified = 0, layouts = 0, settled = 0;
    c.addListener(() => notified++);
    c.serviceLayoutChanges.addListener(() => layouts++);
    final withdraw = c.registerSettle(() => settled++);
    addTearDown(withdraw);

    void expectUnmoved(void Function() act) {
      final json = c.designJson();
      final dirty = c.dirty.value;
      final depth = c.activeDocument.commands.undoDepth;
      final revision = c.revision.value;
      final before = (notified, layouts, settled);
      act();
      expect((notified, layouts, settled), before);
      expect(c.activeDocument.commands.undoDepth, depth);
      expect(c.revision.value, revision);
      expect(c.dirty.value, dirty);
      expect(c.designJson(), json);
    }

    expect(c.dirty.value, isTrue, reason: 'premise');
    expectUnmoved(() => expect(c.fitToTables({'3', '7'}), isTrue));
    c.setMode(FloorPlanMode.selection);
    move(c, '3', 410.5, -95.25);
    await tester.pump();
    expect(c.activeDocument.commands.undoDepth, 1, reason: 'premise');
    expectUnmoved(() => expect(c.fitToTables({'2'}), isTrue));
    await tester.pump();
    expect((notified, layouts), (1, 1), reason: 'the switch, the move');
  });

  // Zone spec Z10: the focus. The fixture is `zone_fixture.dart`'s.

  testWidgets(
      'CF1 setTableFocus trims, drops blanks and copies into an '
      'unmodifiable set; {} and {\'\'} are a focus with no table, not none; '
      'every call notifies, an equal set or a second null included (M-Z34, '
      'M-Z26)', (tester) async {
    final c = zoned(tester);
    expect(c.tableFocus.value, isNull, reason: 'no focus at first');
    var heard = 0;
    c.tableFocus.addListener(() => heard++);
    c.setTableFocus({' 7 ', '', '  ', '3'});
    expect(c.tableFocus.value, {'7', '3'});
    expect(() => c.tableFocus.value!.add('2'), throwsUnsupportedError);
    c.setTableFocus({'3', '7'});
    expect(heard, 2, reason: 'an equal set notifies');
    for (final none in [
      <String>{},
      {''},
      {' ', ''}
    ]) {
      c.setTableFocus(none);
      expect(c.tableFocus.value, isNotNull, reason: '$none is a focus');
      expect(c.tableFocus.value, isEmpty, reason: '$none');
    }
    c.setTableFocus(null);
    c.setTableFocus(null);
    expect(c.tableFocus.value, isNull);
    expect(heard, 7, reason: 'every call');
  });

  testWidgets(
      'CF2 the host\'s set is copied: changing it after the call changes '
      'nothing (M-Z35)', (tester) async {
    final c = zoned(tester);
    final mine = {'7', '3'};
    c.setTableFocus(mine);
    mine
      ..remove('7')
      ..add('A1');
    expect(c.tableFocus.value, {'7', '3'});
  });

  testWidgets(
      'CF3 the focus is kept, by number, across setMode, resetLayout, '
      'restoreServiceLayout, load and newPlan (M-Z20)', (tester) async {
    final c = zoned(tester);
    c.setTableFocus({'7'});
    final focus = c.tableFocus.value;
    void kept(String after) =>
        expect(c.tableFocus.value, same(focus), reason: after);
    c.setMode(FloorPlanMode.selection);
    kept('setMode');
    move(c, '3', 410.5, -95.25);
    final json = c.serviceLayoutJson()!;
    c.resetLayout();
    kept('resetLayout');
    expect(c.restoreServiceLayout(json).applied, ['3']);
    kept('restoreServiceLayout');
    c.load(zonePlanJson());
    kept('load');
    c.newPlan();
    kept('newPlan');
    c.setMode(FloorPlanMode.design);
    kept('setMode back');
    await tester.pump();
  });

  testWidgets(
      'CF4 the focus is not plan state: no json, dirty, undo depth, '
      'revision, layout change, notification or settle, in either mode '
      '(M-Z27)', (tester) async {
    final c = zoned(tester);
    drawLine(c);
    await tester.pump();
    var notified = 0, layouts = 0, settled = 0;
    c.addListener(() => notified++);
    c.serviceLayoutChanges.addListener(() => layouts++);
    final withdraw = c.registerSettle(() => settled++);
    addTearDown(withdraw);

    void expectUnmoved(void Function() act) {
      final json = c.designJson();
      final dirty = c.dirty.value;
      final depth = c.activeDocument.commands.undoDepth;
      final redo = c.activeDocument.commands.canRedo;
      final revision = c.revision.value;
      final before = (notified, layouts, settled);
      act();
      expect((notified, layouts, settled), before);
      expect(c.activeDocument.commands.undoDepth, depth);
      expect(c.activeDocument.commands.canRedo, redo);
      expect(c.revision.value, revision);
      expect(c.dirty.value, dirty);
      expect(c.designJson(), json);
    }

    expect(c.dirty.value, isTrue, reason: 'premise');
    expectUnmoved(() => c.setTableFocus({'3', '7'}));
    expectUnmoved(() => c.setTableFocus(null));
    c.setMode(FloorPlanMode.selection);
    move(c, '3', 410.5, -95.25);
    await tester.pump();
    expect(c.activeDocument.commands.undoDepth, 1, reason: 'premise');
    expectUnmoved(() => c.setTableFocus({}));
    expectUnmoved(() => c.setTableFocus({'2'}));
    await tester.pump();
    expect((notified, layouts), (1, 1), reason: 'the switch, the move');
  });

  testWidgets('CF5 the focus is disposed with the controller', (tester) async {
    final c = FloorPlanController(json: zonePlanJson());
    final focus = c.tableFocus as ChangeNotifier;
    c.dispose();
    expect(() => focus.addListener(() {}), throwsFlutterError);
  });

  // Zone spec Z24 (ruling on V-9): `FloorPlanTable.visible` is false for a
  // table on a hidden layer, read from the table's own layer at the call;
  // `tables` keeps listing it and the numbering warnings ignore it.

  /// The numbers of [c]'s tables with [FloorPlanTable.visible] false.
  List<String?> hiddenNumbers(FloorPlanController c) => [
        for (final t in c.tables)
          if (!t.visible) t.number
      ];

  testWidgets(
      'CV1 M-Z42: the hidden 5 is not visible, every other table is (the '
      'locked L too), in both modes; showing its layer flips it once '
      '`revision` moves, an undo flips it back', (tester) async {
    final c = controller(tester, zonePlanJson());
    final numbers = [
      for (final t in TableSurvey.of(c.activeDocument).tables) t.number
    ];
    expect(numbers, hasLength(10), reason: 'premise');
    expect([for (final t in c.tables) t.number], numbers,
        reason: 'hidden tables stay listed');
    expect(hiddenNumbers(c), ['5']);
    expect(c.tables.firstWhere((t) => t.number == 'L').visible, isTrue,
        reason: 'locked is not hidden');
    expect(
        c.tables.firstWhere((t) => t.number == '5'),
        FloorPlanTable(
            number: '5',
            seats: tableSymbol().seats!,
            symbolKey: tableSymbol().key,
            visible: false));

    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    expect(hiddenNumbers(c), ['5'], reason: 'the service copy');
    c.setMode(FloorPlanMode.design);
    await tester.pump();

    var revisions = 0;
    void count() => revisions++;
    c.revision.addListener(count);
    addTearDown(() => c.revision.removeListener(count));
    final d = c.activeDocument;
    final hidden = d.tables.layers.byName('Hidden')!;
    d.commands.execute(SetLayerCommand(hidden.copyWith(visible: true)));
    await tester.pump();
    expect(revisions, greaterThan(0), reason: 'premise: revision moved');
    expect(hiddenNumbers(c), isEmpty);
    expect(c.tables.firstWhere((t) => t.number == '5').visible, isTrue);

    final seen = revisions;
    c.undo();
    await tester.pump();
    expect(revisions, greaterThan(seen));
    expect(hiddenNumbers(c), ['5']);
  });

  testWidgets(
      'CV2 M-Z42: hiding the layer of one 2 and of the unnumbered table '
      'leaves the numbering warnings and the listed numbers unchanged; '
      'only their visible flips', (tester) async {
    final c = controller(tester, zonePlanJson());
    final d = c.activeDocument;
    final back = addZoneLayer(d, 'Back');
    final survey = TableSurvey.of(d);
    final moved = [
      survey.withNumber('2').last.instance,
      survey.tables.firstWhere((t) => t.number == null).instance,
    ];
    for (final h in moved) {
      d.commands.execute(SetInstanceLayerCommand(h, back));
    }
    await tester.pump();
    final warnings = c.numberingWarnings;
    expect(warnings, hasLength(2), reason: 'premise: the 2s, the unnumbered');
    final listed = [for (final t in c.tables) (t.number, t.seats)];
    expect(hiddenNumbers(c), ['5']);

    d.commands.execute(
        SetLayerCommand(d.tables.layers[back]!.copyWith(visible: false)));
    await tester.pump();
    expect(c.numberingWarnings, warnings);
    expect([for (final t in c.tables) (t.number, t.seats)], listed);
    expect(hiddenNumbers(c)..sort((a, b) => '$a'.compareTo('$b')),
        ['2', '5', null]..sort((a, b) => '$a'.compareTo('$b')));
    final twos = [
      for (final t in c.tables)
        if (t.number == '2') t.visible
    ];
    expect(twos, [true, false], reason: 'the first 2 stays shown');
  });

  testWidgets(
      'CV3 M-Z42: the spec\'s unplacedTables recipe (Z21), verbatim, counts '
      'the hidden 5 and an unknown code as unplaced, and not 5 once its '
      'layer is shown', (tester) async {
    final controller = FloorPlanController(json: zonePlanJson());
    addTearDown(controller.dispose);

    /// The tables the POS knows that this floor does not draw: a table on
    /// a hidden layer is not drawn, so it counts as unplaced. Codes compare
    /// trimmed, as `fitToTables` and `setTableFocus` trim them.
    Set<String> unplacedTables(Set<String> codes) {
      final drawn = {
        for (final table in controller.tables)
          if (table.visible && table.number != null) table.number!,
      };
      return {
        for (final code in codes)
          if (!drawn.contains(code.trim())) code,
      };
    }

    const codes = {' 2', '3', '5', '7 ', 'A1', 'A2', 'B4', 'L', '99'};
    expect(unplacedTables(codes), {'5', '99'},
        reason: 'the final review F-3: " 2" and "7 " are drawn tables');
    final d = controller.activeDocument;
    d.commands.execute(SetLayerCommand(
        d.tables.layers.byName('Hidden')!.copyWith(visible: true)));
    await tester.pump();
    expect(unplacedTables(codes), {'99'});
  });

  // Host embedding API spec G-1: `tableDetails` follows the plan the mode
  // shows.

  testWidgets(
      'CD1 M-H4: a service move changes tableDetails in the selection mode, '
      'and not the design\'s: back in the design mode the table is where it '
      'was designed', (tester) async {
    final c = controller(tester, embedding.embeddingPlanJson());
    final box = embedding.embeddingBox;
    final one = embedding.embeddingTables.first;
    final designed =
        one.transform.transformPoint(Vector2(box.center.x, box.center.y));
    double x() => c.tableDetails.first.center!.dx;
    double y() => c.tableDetails.first.center!.dy;
    expect(c.tableDetails.first.table.number, '1', reason: 'premise');
    expect(x(), closeTo(designed.x, 1e-12 * designed.x.abs()));

    c.setMode(FloorPlanMode.selection);
    move(c, '1', 750, -250);
    await tester.pump();
    expect(x(), closeTo(designed.x + 750, 1e-12 * designed.x.abs()));
    expect(y(), closeTo(designed.y - 250, 1e-12 * designed.y.abs()));

    c.setMode(FloorPlanMode.design);
    await tester.pump();
    expect(x(), closeTo(designed.x, 1e-12 * designed.x.abs()));
    expect(y(), closeTo(designed.y, 1e-12 * designed.y.abs()));
  });

  // Host embedding API spec E-9 (Slice 2 plan, Task 1): schema 9. The
  // older and newer plans are derived from this build's own encoding of the
  // embedding fixture (the version set, then through bytes).

  group('schema 9 (E-9)', () {
    String withVersion(String encoding, int version) {
      final json = jsonDecode(encoding) as Map<String, Object?>;
      json['schemaVersion'] = version;
      return jsonEncode(json);
    }

    int versionOf(String encoding) =>
        (jsonDecode(encoding) as Map<String, Object?>)['schemaVersion']! as int;

    testWidgets('CS1 M-H26a: designJson() of the fixture declares 9',
        (tester) async {
      final c = controller(tester, embedding.embeddingPlanJson());
      expect(versionOf(c.designJson()), 9);
      drawLine(c);
      expect(versionOf(c.designJson()), 9, reason: 'after an edit as well');
    });

    testWidgets(
        'CS2 M-H26b: an 8 plan opens unchanged through the constructor and '
        'load, and saves to the 9 bytes, tables and all', (tester) async {
      final nine = embedding.embeddingPlanJson();
      final eight = withVersion(nine, 8);
      expect(versionOf(eight), 8, reason: 'premise: the file declares 8');
      expect(eight, isNot(nine), reason: 'premise');
      final reference = controller(tester, nine);
      final details = reference.tableDetails;
      expect(details, hasLength(embedding.embeddingTables.length),
          reason: 'premise: the fixture\'s tables');

      final built = controller(tester, eight);
      expect(built.tableDetails, details);
      expect(built.designJson(), nine);

      final loaded = controller(tester, planJson());
      loaded.load(eight);
      expect(loaded.tableDetails, details);
      expect(loaded.designJson(), nine);
      expect(loaded.designJson(), reference.designJson());
    });

    testWidgets(
        'CS3 a 10 plan is refused by load and the constructor, saying why, '
        'and the plan is left as it was', (tester) async {
      final ten = withVersion(embedding.embeddingPlanJson(), 10);
      final refusal = isA<FormatException>().having(
          (e) => e.message,
          'message',
          allOf(
              startsWith('Not a floor plan: '),
              contains('unsupported schemaVersion 10'),
              contains('this build writes 9')));

      final c = controller(tester, embedding.embeddingPlanJson());
      drawLine(c);
      await tester.pump();
      expect(c.canUndo.value, isTrue, reason: 'premise: an edit');
      final document = c.activeDocument;
      final before = c.designJson();
      final details = c.tableDetails;
      expect(() => c.load(ten), throwsA(refusal));
      await tester.pump();
      expect(c.activeDocument, same(document));
      expect(c.designJson(), before);
      expect(c.tableDetails, details);
      expect(c.canUndo.value, isTrue, reason: 'the edit is still undoable');

      expect(() => FloorPlanController(json: ten), throwsA(refusal));
    });

    testWidgets(
        'CS4 the service layout\'s format is its own: still version 1, '
        'with no schemaVersion', (tester) async {
      final c = controller(tester, embedding.embeddingPlanJson());
      c.setMode(FloorPlanMode.selection);
      move(c, '1', 750, -250);
      await tester.pump();
      final layout = jsonDecode(c.serviceLayoutJson()!) as Map<String, Object?>;
      expect(layout['format'], 'jet_cad.service_layout');
      expect(layout['version'], 1);
      expect(layout.containsKey('schemaVersion'), isFalse);
      expect((layout['tables']! as List<Object?>), hasLength(1),
          reason: 'premise: the move is in it');
    });
  });
}
