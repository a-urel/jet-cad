// The service fixture (2b Task 5; spec "Tests": not degenerate): a plan over
// unitKit() holding one placed table of four, a quarter turn and mirrored,
// at (-2400.5, 3100.25), labelled 12; and two rows of the test seat, sharing
// one definition: A (six seats, 600 apart, straight) turned 0.35 rad at
// (5200.5, -3100.25), and B (five seats, 650 apart, curved 0.18 rad a seat)
// at (-4800.75, -2600.5). Later tasks load `json` into a controller over
// [unitKit()] (or another kit set, for a missing kit) and address the parts
// by the handles below, which the plan text keeps.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart'
    show definitionForEntry, placeSymbol;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'harness.dart';
import 'test_kit.dart';

typedef ServiceFixture = ({
  String json,
  Handle table,
  Handle tableLabel,
  Handle tableDefinition,
  Handle seatDefinition,
  Handle rowA,
  List<Handle> seatsA,
  Handle rowB,
  List<Handle> seatsB,
});

final SymbolLibrary _library = SymbolLibrary.decode(testUnitLibraryBytes());

/// The unit library's entry [id] (`key@version`).
SymbolEntry testEntry(String id) =>
    _library.entries.firstWhere((e) => e.id == id);

/// [placeRowCommand], executed; the row's handle.
Handle addRow(DraftDocument d, RowComponent row,
    {required Vector2 at, double angle = 0}) {
  final h = d.handleSeed.next();
  d.commands.execute(placeRowCommand(d, row, at: at, angle: angle, handle: h));
  return h;
}

/// The live rows of [d], ascending.
List<Handle> rowsOf(DraftDocument d) => [
      for (final h in d.components.withComponent<RowComponent>())
        if (d.tree[h] is GroupNode) h,
    ]..sort((a, b) => a.value.compareTo(b.value));

/// [row]'s instance children, ascending: its seats.
List<Handle> seatsOf(DraftDocument d, Handle row) => [
      for (final h in (d.tree[row]! as GroupNode).children)
        if (d.tree[h] is InstanceNode) h,
    ]..sort((a, b) => a.value.compareTo(b.value));

/// [instance]'s UNIT ATTRIBs, (handle, text), ascending by handle.
List<(Handle, String)> unitLabelsOf(DraftDocument d, Handle instance) {
  final e = d.entities;
  return [
    for (final s in e.liveSlots)
      if (e.ownerAt(s) == instance &&
          e.kindAt(s) == EntityKind.attrib &&
          e.tagAt(s) == kUnitLabelTag)
        (e.handleAt(s), e.textAt(s)),
  ]..sort((a, b) => a.$1.value.compareTo(b.$1.value));
}

/// Adds [text] as the UNIT label of the placed [instance] of [entry], as
/// today's placement shapes it (layer 0, BYBLOCK, centred, the stamp for
/// the instance's transform, the height of the entry's top): executed; the
/// label's handle.
Handle labelPlacedUnit(
    DraftDocument d, Handle instance, SymbolEntry entry, String text) {
  final node = d.tree[instance]! as InstanceNode;
  final h = d.handleSeed.next();
  d.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: h,
      owner: instance,
      kind: EntityKind.attrib,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byBlockLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByBlockColor(),
      lineweight: kByBlock,
      transparency: kByBlock,
      flags: 0,
      text: text,
      tag: kUnitLabelTag,
      textStyle: ReservedHandles.standardTextStyle,
      textAttrs: kUnitLabelTextAttrs,
    ),
    payload: unitLabelPayload(
        anchor: entry.definition.basePoint,
        height: unitLabelHeight(entryTop(entry)),
        instanceToWorld: node.transform),
  ));
  return h;
}

/// The label [label]'s world linear map under [instanceToWorld] is the
/// identity: it reads upright and unmirrored, whatever the instance's turn.
void expectUprightLabel(
    DraftDocument d, Handle label, Transform2 instanceToWorld) {
  final p = d.geometry.read(d.entities.geomIndexAt(d.entities.slotOf(label)!));
  final t = instanceToWorld;
  final w = Transform2(t.a, t.b, t.c, t.d, 0, 0)
      .multiply(Transform2.rotation(p.scalars[1]))
      .multiply(Transform2.scale(p.scalars[2], 1));
  expect([
    w.a,
    w.b,
    w.c,
    w.d
  ], [
    closeTo(1, 1e-12),
    closeTo(0, 1e-12),
    closeTo(0, 1e-12),
    closeTo(1, 1e-12),
  ]);
}

ServiceFixture serviceFixture() {
  late Handle table, tableLabel, tableDefinition, seatDefinition, rowA, rowB;
  late List<Handle> seatsA, seatsB;
  final json = planText([unitKit()], (d) {
    final tableEntry = testEntry(tableSymbolId);
    final before = {for (final n in d.tree.nodes) n.handle};
    d.commands.execute(placeSymbol(d, tableEntry,
        at: Vector2(-2400.5, 3100.25), quarterTurns: 1, mirrored: true));
    final placed = d.tree.nodes
        .whereType<InstanceNode>()
        .singleWhere((n) => !before.contains(n.handle));
    table = placed.handle;
    tableDefinition = placed.definition;
    tableLabel = labelPlacedUnit(d, table, tableEntry, '12');

    final seatEntry = testEntry(rowSeatKey);
    final made = definitionForEntry(d, seatEntry);
    d.commands.execute(CompoundCommand(made.commands, label: 'Seat'));
    seatDefinition = made.definition;
    RowComponent row(String prefix, int count, double spacing, double curve) =>
        RowComponent(
            prefix: prefix,
            count: count,
            spacing: spacing,
            curve: curve,
            seat: seatDefinition,
            base: seatEntry.definition.basePoint,
            top: entryTop(seatEntry));
    rowA = addRow(d, row('A', 6, 600, 0),
        at: Vector2(5200.5, -3100.25), angle: 0.35);
    rowB = addRow(d, row('B', 5, 650, 0.18), at: Vector2(-4800.75, -2600.5));
    seatsA = seatsOf(d, rowA);
    seatsB = seatsOf(d, rowB);
  });
  return (
    json: json,
    table: table,
    tableLabel: tableLabel,
    tableDefinition: tableDefinition,
    seatDefinition: seatDefinition,
    rowA: rowA,
    seatsA: seatsA,
    rowB: rowB,
    seatsB: seatsB,
  );
}
