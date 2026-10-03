// Spec 14a T13: placing a servable symbol numbers it, inside the placement's
// one undo step; an unservable one is not numbered; the palette's
// thumbnails are not numbered. Placements are off the origin, turned and
// mirrored.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/src/symbols/build_library.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_library.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_panel.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'table_fixture.dart';

/// Places [entry]; returns the new instance's handle.
Handle place(DraftDocument doc, SymbolEntry entry, Vector2 at,
    {int quarterTurns = 0, bool mirrored = false}) {
  final before = {for (final n in doc.tree.nodes) n.handle};
  doc.commands.execute(placeSymbol(doc, entry,
      at: at, quarterTurns: quarterTurns, mirrored: mirrored));
  return doc.tree.nodes
      .whereType<InstanceNode>()
      .singleWhere((n) => !before.contains(n.handle))
      .handle;
}

/// Every ATTRIB in [doc]: (handle, owner, text, tag).
List<(Handle, Handle, String, String)> attribs(DraftDocument doc) {
  final e = doc.entities;
  return [
    for (final s in e.liveSlots)
      if (e.kindAt(s) == EntityKind.attrib)
        (e.handleAt(s), e.ownerAt(s), e.textAt(s), e.tagAt(s))
  ]..sort((a, b) => a.$1.value.compareTo(b.$1.value));
}

List<String?> numbers(DraftDocument doc) =>
    [for (final t in tablesOf(doc)) t.number];

void main() {
  test(
      'TP1 a turned, mirrored placement adds its label in the same step; '
      'undo and redo take and give both', () {
    final doc = plan();
    final depth = doc.commands.undoDepth;
    final i = place(doc, entryOf(tableSymbol()), Vector2(-3700, 2900),
        quarterTurns: 3, mirrored: true);
    expect(doc.commands.undoDepth, depth + 1);

    final [(label, owner, text, tag)] = attribs(doc);
    expect((owner, text, tag), (i, '1', 'TABLE'));
    final slot = doc.entities.slotOf(label)!;
    expect(doc.entities.layerAt(slot), ReservedHandles.layerZero);
    final payload = doc.geometry.read(doc.entities.geomIndexAt(slot));
    expect(payload.coords, [900, 700], reason: 'the top centre, local');
    final node = doc.tree[i]! as InstanceNode;
    final s = tableLabelStamp(node.transform);
    expect(payload.scalars, [200, s.rotation, s.widthFactor]);
    expect(s.widthFactor, -1.0);

    doc.commands.undo();
    expect(doc.tree[i], isNull);
    expect(attribs(doc), isEmpty);
    doc.commands.redo();
    expect(attribs(doc), [(label, i, '1', 'TABLE')],
        reason: 'redo replays the same handle and number');
    expect(doc.validate(), isEmpty);
  });

  test(
      'TP2 an unservable symbol gets no label and takes no number '
      '(M-14a-13)', () {
    final doc = plan();
    place(doc, entryOf(tableSymbol()), Vector2(-2000, 0), quarterTurns: 1);
    place(doc, entryOf(stoolSymbol), Vector2(0, 1500));
    final planter = place(doc, entryOf(planterSymbol), Vector2(1200, -900));
    place(doc, entryOf(tableSymbol()), Vector2(3000, 600), mirrored: true);
    expect(numbers(doc), ['1', '2', '3']);
    expect(attribs(doc).any((a) => a.$2 == planter), isFalse);
  });

  test(
      'TP3 two placements of one symbol share a definition and keep their '
      'own numbers (M-14a-16)', () {
    final doc = plan();
    final entry = entryOf(tableSymbol());
    final a = place(doc, entry, Vector2(-2000, 800), quarterTurns: 1);
    final b = place(doc, entry, Vector2(2600, -800), mirrored: true);
    expect((doc.tree[a]! as InstanceNode).definition,
        (doc.tree[b]! as InstanceNode).definition);
    final labels = attribs(doc);
    expect([for (final l in labels) l.$2], [a, b],
        reason: 'each label is owned by its instance, not the definition');
    doc.commands.execute(SetEntityTextCommand(labels.first.$1, '15', 'TABLE'));
    expect(numbers(doc), ['15', '2']);
  });

  test(
      'TP4 a deleted table\'s number is free again; the next follows the '
      'live maximum (M-14a-2)', () {
    final doc = plan();
    final entry = entryOf(tableSymbol());
    final placed = [
      for (var k = 0; k < 5; k++)
        place(doc, entry, Vector2(1500.0 * k - 3000, 700), quarterTurns: k)
    ];
    expect(numbers(doc), ['1', '2', '3', '4', '5']);
    final fifth = attribs(doc).last;
    doc.commands.execute(CompoundCommand(
        [RemoveEntityCommand(fifth.$1), RemoveNodeCommand(placed.last)],
        label: 'Delete'));
    place(doc, entry, Vector2(0, -2500));
    expect(numbers(doc), ['1', '2', '3', '4', '5']);
  });

  test(
      'TP5 the Q-2 ruling: the only table renamed 101, the next placement '
      'is 102', () {
    final doc = plan();
    final entry = entryOf(stoolSymbol);
    place(doc, entry, Vector2(-900, 400));
    doc.commands
        .execute(SetEntityTextCommand(attribs(doc).single.$1, '101', 'TABLE'));
    place(doc, entry, Vector2(900, 400), quarterTurns: 2);
    expect(numbers(doc), ['101', '102']);
  });

  test('TP6 a palette thumbnail carries no number (M-14a-17)', () {
    final thumb =
        symbolThumbnailDocument(entryOf(tableSymbol()), MetricModelMeasurer());
    expect(thumb.tree.nodes.whereType<InstanceNode>(), hasLength(1));
    expect(attribs(thumb), isEmpty);
  });

  test(
      'TP7 the furniture library\'s round dining table places numbered, '
      'its label inside the top', () {
    final lib = SymbolLibrary.decode(Uint8List.fromList(utf8
        .encode(DraftDocumentCodec.encodeToString(buildFurnitureLibrary()))));
    final round = lib.entries.firstWhere((e) => e.key == 'dining.table.round');
    final doc = plan();
    place(doc, round, Vector2(-1234, 5678), quarterTurns: 1);
    final [(label, _, text, _)] = attribs(doc);
    expect(text, '1');
    final payload = doc.geometry
        .read(doc.entities.geomIndexAt(doc.entities.slotOf(label)!));
    expect(payload.coords,
        [round.definition.basePoint.x, round.definition.basePoint.y]);
    expect(payload.scalars[0], 200);
    expect(payload.scalars[1], -math.pi / 2);
  });
}
