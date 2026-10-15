// 2b Task 8, spec S2 "In design, a generated unit stands for its object"
// and decision 9; S4 selectUnitsOnly, relabel, the profiles. plan.select is
// driven without a canvas (tool_events.dart) under the rotated, flipped,
// off-origin test camera, over Task 5's service fixture: a turned, mirrored
// table off the origin and two seats-only rows off the origin, one turned,
// one curved.
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/kits/locks.dart' show LockSet;
import 'package:jet_cad_2d_plan/src/service/unit_picker.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart'
    show definitionForEntry;
import 'package:jet_cad_2d_plan/src/units/unit_index.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/test_kit.dart';
import '../support/service_fixture.dart' show serviceFixture;
import '../support/tool_events.dart';
import '../support/unit_editor_fixture.dart' show editorChair;
import '../support/unit_fixtures.dart'
    show
        addLayer,
        entryOf,
        fxKit,
        pickerOf,
        placeTurned,
        tableSymbol,
        unitPlan,
        worldOf;

/// Task 5's fixture's plan text.
String fixtureText() => serviceFixture().json;

PlanController design({List<PlanKit>? kits}) {
  final c = controllerFor(kits: kits ?? [unitKit()], json: fixtureText());
  useTestCamera(c);
  return c;
}

/// The root-level objects of the test kit's row type, ascending.
List<Handle> rowsOf(PlanController c) {
  final d = c.document;
  final root = d.tree[d.rootHandle]! as GroupNode;
  return [
    for (final h in d.tree.childNodesOf(root.children))
      if (d.components.unknownOf(h).isNotEmpty ||
          c.catalog.typeIdOf(d, h) != null)
        if (d.tree[h] is GroupNode) h,
  ]..sort((a, b) => a.value.compareTo(b.value));
}

/// The seats of [row], ascending.
List<Handle> seatsOf(PlanController c, Handle row) {
  final d = c.document;
  final g = d.tree[row]! as GroupNode;
  return [
    for (final h in d.tree.childNodesOf(g.children))
      if (d.tree[h] is InstanceNode) h,
  ]..sort((a, b) => a.value.compareTo(b.value));
}

/// The placed table: the root-level instance of a unit definition.
Handle tableIn(PlanController c) {
  final d = c.document;
  final root = d.tree[d.rootHandle]! as GroupNode;
  return d.tree.childNodesOf(root.children).singleWhere((h) =>
      d.tree[h] is InstanceNode &&
      d.components
              .get<UnitComponent>((d.tree[h]! as InstanceNode).definition) !=
          null);
}

/// [seat]'s outline's first vertex (its definition's lowest-handle leaf)
/// in the world.
Vector2 seatCorner(PlanController c, Handle seat) {
  final d = c.document;
  final def = (d.tree[seat]! as InstanceNode).definition;
  final leaf = d.entities.liveSlots
      .where((s) => d.entities.ownerAt(s) == def)
      .reduce((a, b) =>
          d.entities.handleAt(a).value < d.entities.handleAt(b).value ? a : b);
  final p = d.geometry.read(d.entities.geomIndexAt(leaf)).coords;
  return d.tree.accumulatedTransform(seat).transformPoint(Vector2(p[0], p[1]));
}

/// [seat]'s UNIT label's anchor in the world.
Vector2 seatLabel(PlanController c, Handle seat) {
  final d = c.document;
  final slot = d.entities.liveSlots.firstWhere((s) =>
      d.entities.ownerAt(s) == seat &&
      d.entities.kindAt(s) == EntityKind.attrib);
  final p = d.geometry.read(d.entities.geomIndexAt(slot)).coords;
  return d.tree.accumulatedTransform(seat).transformPoint(Vector2(p[0], p[1]));
}

/// The world box of [row]'s seats (their definitions' boxes through their
/// world transforms).
Aabb2 rowBox(PlanController c, Handle row) {
  final d = c.document;
  var box = Aabb2.empty();
  for (final s in seatsOf(c, row)) {
    final def = (d.tree[s]! as InstanceNode).definition;
    box = box.union(d
        .definitionBounds(def, d.leavesByOwner())
        .transformedBy(d.tree.accumulatedTransform(s)));
  }
  return box;
}

/// A band drag around [box] inflated by [pad] screen pixels: a window
/// (screen left to right) or a crossing (right to left).
void band(PlanController c, Aabb2 box, {required bool window, double pad = 8}) {
  final cam = c.toolController.context.camera.value;
  final corners = [
    for (final (x, y) in [
      (box.minX, box.minY),
      (box.maxX, box.minY),
      (box.maxX, box.maxY),
      (box.minX, box.maxY),
    ])
      cam.worldToScreen(Vector2(x, y)),
  ];
  final xs = corners.map((p) => p.x), ys = corners.map((p) => p.y);
  final a = Vector2(xs.reduce((p, q) => p < q ? p : q) - pad,
      ys.reduce((p, q) => p < q ? p : q) - pad);
  final b = Vector2(xs.reduce((p, q) => p > q ? p : q) + pad,
      ys.reduce((p, q) => p > q ? p : q) + pad);
  final from = cam.screenToWorld(window ? a : b);
  final to = cam.screenToWorld(window ? b : a);
  dragFrom(c, from, to);
}

Set<SelectionKey> selected(PlanController c) => {...c.selection.keys};

void main() {
  test('DS-0 premise: two rows of seats, a table, the camera off identity', () {
    final c = design();
    expect(rowsOf(c), hasLength(2));
    for (final row in rowsOf(c)) {
      expect(seatsOf(c, row), isNotEmpty);
      expect(c.catalog.typeIdOf(c.document, row), 'test.row');
    }
    expect(tableIn(c), isNotNull);
    expect(
        c.toolController.context.camera.value.worldToScreenMatrix.b, isNot(0));
  });

  test(
      'DS-click-seat a click and a hover on a seat\'s outline name its row; '
      'the gates replace the pick', () {
    final c = design();
    final row = rowsOf(c).first;
    final seat = seatsOf(c, row)[1];
    expect(c.selectGates.restrictsPick, isTrue);
    final tools = c.toolController;
    tools.active.onPointerMove(eventAt(c, seatCorner(c, seat)), tools.context);
    // M-DS1: the mapping removed from `pick` (the seat's key returned).
    expect(c.selection.hover, SelectionKey.root(row), reason: 'the hover');
    tapAt(c, seatCorner(c, seat));
    expect(selected(c), {SelectionKey.root(row)});
  });

  test('DS-click-attrib a click on a seat\'s label selects its row', () {
    final c = design();
    final row = rowsOf(c).last;
    final seat = seatsOf(c, row).first;
    tapAt(c, seatLabel(c, seat));
    // A positive control: `resolveHit` already maps a seat's ATTRIB to the
    // row, so M-DS2 (the hit's own entity in `pick`) leaves this green; it
    // is killed by DS-click-seat, DS-locked-object and DS-plain-group.
    expect(selected(c), {SelectionKey.root(row)});
  });

  test(
      'DS-crossing a crossing band over a seats-only row takes the row, no '
      'seat', () {
    final c = design();
    final row = rowsOf(c).first;
    band(c, rowBox(c, row), window: false);
    // M-DS3: `bandAccepts` answering true (the seats' keys let through).
    expect(selected(c), {SelectionKey.root(row)});
  });

  test(
      'DS-window a window band over a seats-only row selects nothing, no '
      'seat included (decision 9, a known limit)', () {
    final c = design();
    final row = rowsOf(c).first;
    band(c, rowBox(c, row), window: true);
    // M-DS3: `bandAccepts` answering true lets every seat in.
    expect(selected(c), isEmpty);
  });

  test(
      'DS-locked-object a row whose kit is missing: a click on a seat names '
      'the row (a lock-set object)', () {
    final c = design(kits: const []);
    final row = rowsOf(c).first;
    expect(c.locked.value, contains(row), reason: 'premise: held');
    expect(c.catalog.typeIdOf(c.document, row), isNull, reason: 'premise');
    tapAt(c, seatCorner(c, seatsOf(c, row).first));
    // M-DS4: `|| locked.contains(current)` dropped from the mapping.
    expect(selected(c), {SelectionKey.root(row)});
  });

  test(
      'DS-plain-group a table inside a plain group: the click and the band '
      'select what the bare select tool selects (today\'s selection)', () {
    final text = planText([testKit(), fxKit()], (d) {
      final g = d.handleSeed.next();
      d.commands.execute(AddNodeCommand(GroupNode(
          handle: g,
          parent: d.rootHandle,
          transform: Transform2.translation(4100.5, -1250.25)
              .multiply(Transform2.rotation(0.4)),
          children: const [])));
      final made = definitionForEntry(d, entryOf(tableSymbol()));
      final t = d.handleSeed.next();
      d.commands.execute(CompoundCommand([
        ...made.commands,
        AddNodeCommand(InstanceNode(
            handle: t,
            parent: g,
            definition: made.definition,
            layer: ReservedHandles.layerZero,
            transform: Transform2.translation(300.25, 200.5))),
      ], label: 'Place a table'));
    });
    final c = controllerFor(kits: [testKit(), fxKit()], json: text);
    useTestCamera(c);
    final d = c.document;
    final table = d.tree.nodes.whereType<InstanceNode>().single.handle;
    final corner =
        d.tree.accumulatedTransform(table).transformPoint(Vector2(300, 300));
    // The bare tool on its own selection, the same document and camera.
    final bareSelection = SelectionController(d);
    addTearDown(bareSelection.dispose);
    final bare = SelectTool();
    final ctx = ToolContext(
        document: d,
        index: c.index,
        camera: c.toolController.context.camera,
        selection: bareSelection,
        page: c.page,
        snap: SnapSettings());
    bare.onPointerDown(eventAt(c, corner, buttons: kPrimaryButton), ctx);
    bare.onPointerUp(eventAt(c, corner), ctx);
    tapAt(c, corner);
    // M-DS5: the type and lock condition dropped (every root group maps).
    expect(selected(c), {...bareSelection.keys});
    expect(selected(c), {SelectionKey.root(table)});
  });

  test(
      'DS-units-only selectUnitsOnly: a seat is passed over, the table\'s '
      'top selects it, a crossing band over everything keeps the table '
      'alone', () {
    final c = design();
    c.permissions = PlanPermissions.unitsOnly;
    final row = rowsOf(c).first;
    tapAt(c, seatCorner(c, seatsOf(c, row).first));
    // M-DS6: the session's picker built without `placedOnly`.
    expect(selected(c), isEmpty, reason: 'a seat is no placed unit');
    final table = tableIn(c);
    final node = c.document.tree[table]! as InstanceNode;
    // The centre of the table's top (its first leaf, a closed outline):
    // inside the top, away from its lines.
    final top = c.document
        .definitionBounds(node.definition, c.document.leavesByOwner());
    tapAt(
        c,
        node.transform.transformPoint(
            Vector2((top.minX + top.maxX) / 2, (top.minY + top.maxY) / 2)));
    expect(selected(c), {SelectionKey.root(table)});
    c.selection.clear();
    var all = Aabb2.empty();
    for (final r in rowsOf(c)) {
      all = all.union(rowBox(c, r));
    }
    all = all.union(c.document
        .definitionBounds(node.definition, c.document.leavesByOwner())
        .transformedBy(node.transform));
    band(c, all, window: false, pad: 40);
    // M-DS7: the selectUnitsOnly branch of `bandAccepts` removed.
    expect(selected(c), {SelectionKey.root(table)});
  });

  test(
      'DS-prune selectUnitsOnly turned on keeps only the selection\'s placed '
      'units', () {
    final c = design();
    final row = rowsOf(c).first;
    final table = tableIn(c);
    final line =
        addLine(c.document, Vector2(-900.5, 300.25), Vector2(-200.75, 950.5));
    c.selection.replace([
      SelectionKey.root(table),
      SelectionKey.root(row),
      SelectionKey.root(line),
    ]);
    c.permissions = PlanPermissions.unitsOnly;
    // M-DS8: the prune in the permissions setter removed.
    expect(selected(c), {SelectionKey.root(table)});
  });

  test(
      'DS-picker-seat the picker finds a generated seat by its top in the '
      'world (group × instance), not at its local place', () {
    final c = design();
    final row = rowsOf(c).first;
    final seat = seatsOf(c, row)[2];
    final locked = ValueNotifier<Set<Handle>>(const {});
    addTearDown(locked.dispose);
    final units = UnitIndexCache(c.document,
        catalog: c.catalog,
        locks: LockSet.scan(c.document, (k) => c.kits.kitOf(k) != null),
        locked: locked);
    addTearDown(units.dispose);
    final picker = UnitPicker(c.document, units);
    final d = c.document;
    final def = (d.tree[seat]! as InstanceNode).definition;
    final box = d.definitionBounds(def, d.leavesByOwner());
    final centre =
        Vector2((box.minX + box.maxX) / 2, (box.minY + box.maxY) / 2);
    final world = d.tree.accumulatedTransform(seat).transformPoint(centre);
    // M-DS9: candidatesOf reads the instance's own transform, not toWorld.
    expect(picker.pick(world)?.instance, seat);
    expect(picker.pick(world)?.generated, isTrue);
    expect(UnitPicker(c.document, units, placedOnly: true).pick(world), isNull);
  });

  test(
      'DS-perm relabel is an edit and readOnly turns it off; the service '
      'flags are not edits; isUnitSymbol admits any unit, a seat included', () {
    expect(PlanPermissions.readOnly.relabel, isFalse);
    // M-DS10: `relabel ||` dropped from `edits`.
    expect(PlanPermissions.readOnly.copyWith(relabel: true).edits, isTrue);
    expect(
        PlanPermissions.readOnly
            .copyWith(
                serviceMove: true, serviceMerge: true, selectUnitsOnly: true)
            .draft,
        same(DraftPermissions.readOnly));
    PlanSymbol symbol(SymbolEntry e) =>
        PlanSymbol(kitId: 'fx', names: KitNames.empty, entry: e);
    final seat = entryOf(tableSymbol(key: 'fx.seat.single', seats: 1));
    final seatEntry = SymbolEntry(
        symbol: seat.symbol,
        unit: UnitComponent(
            kind: UnitKinds.seat,
            capacity: 1,
            labelling: UnitLabelling.assigned),
        definition: seat.definition,
        leaves: seat.leaves);
    expect(isUnitSymbol(symbol(entryOf(tableSymbol()))), isTrue);
    // M-DS11: isUnitSymbol reading `unit?.kind == UnitKinds.table`.
    expect(isUnitSymbol(symbol(seatEntry)), isTrue);
    expect(isUnitSymbol(symbol(entryOf(editorChair))), isFalse);
  });

  test(
      'DS-layer a unit\'s layer locked in the layer table, no command run: '
      'the units-only picker passes it over at the next pick (Task 6\'s '
      'cache key and lock rule, carried)', () {
    final doc = unitPlan();
    final layer = addLayer(doc, 'Tables');
    final t = placeTurned(doc, tableSymbol(), Vector2(-4100.5, 2700.25));
    doc.commands.execute(SetInstanceLayerCommand(t.handle, layer));
    final picker = pickerOf(doc, skipLocked: true, placedOnly: true);
    final inside = worldOf(t, 900, 700);
    expect(picker.pick(inside)?.instance, t.handle, reason: 'premise');
    final state = doc.commands.stateId;
    final record = doc.tables.layers[layer]!;
    doc.tables.layers
      ..remove(layer)
      ..add(record.copyWith(locked: true));
    expect(doc.commands.stateId, state, reason: 'premise: no state moved');
    // M-DS12: UnitIndexCache.current's `revision == _revision` dropped.
    // M-DS13: isLockedUnit's layer check answering false.
    expect(picker.pick(inside), isNull);
  });
}
