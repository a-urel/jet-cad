// Spec 12b D2's creation and D7: each parametric tool commits its object
// with `ObjectLayer(drawingLayer(document))` in the creation compound, so
// the object and every child the parametric system generates for it are on
// the effective current layer, in one undo step; the symbol placer writes
// that layer on the instance, and the definition's leaves stay on layer 0.
//
// P-6's fixture: the walls on `A`, the current layer `B` (locked: D3 keeps
// a locked layer usable), so the expected layer is neither layer 0 nor the
// walls' own; every click is off the origin, at the corpus far origin turned
// 23°, every wall in its own rotated group.
import 'package:floor_planner/parametric/box_tool.dart';
import 'package:floor_planner/parametric/dimension.dart';
import 'package:floor_planner/parametric/dimension_tool.dart';
import 'package:floor_planner/parametric/opening.dart';
import 'package:floor_planner/parametric/opening_tool.dart';
import 'package:floor_planner/parametric/room.dart';
import 'package:floor_planner/parametric/room_inputs.dart';
import 'package:floor_planner/parametric/room_tool.dart';
import 'package:floor_planner/parametric/separator.dart';
import 'package:floor_planner/parametric/separator_tool.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/parametric/wall_tool.dart';
import 'package:floor_planner/parametric/box.dart';
import 'package:floor_planner/symbols/symbol_library.dart';
import 'package:floor_planner/symbols/symbol_placer.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../support/layer_fixture.dart';
import '../support/symbol_fixtures.dart' show buildValidLibrary, bytesOf;
import '../support/wall_fixture.dart' show worldWallOf;

/// Every group node of [doc], by handle.
Set<Handle> groupsOf(DraftDocument doc) =>
    {for (final n in doc.tree.nodes.whereType<GroupNode>()) n.handle};

/// Runs [create], which must add exactly one object of type [T] in one undo
/// step; checks that the object's `ObjectLayer` is [layer] and that every
/// child generated for it is on [layer]; then undoes it and checks that the
/// object, its children and its `ObjectLayer` are gone. Returns the object
/// (dead after the undo) and its children's count.
(Handle, int) expectCreatedOn<T extends Component>(
    DraftDocument doc, Handle layer, void Function() create) {
  final before = groupsOf(doc);
  final depth = doc.commands.undoDepth;
  create();
  final added = groupsOf(doc).difference(before);
  expect(added, hasLength(1), reason: 'premise: one object was created');
  final h = added.single;
  expect(doc.components.get<T>(h), isNotNull, reason: 'premise: a $T');
  expect(doc.commands.undoDepth, depth + 1, reason: 'one undo step');
  expect(objectLayerOf(doc, h), layer, reason: 'the object takes the layer');
  final children = kids(doc, h);
  expect(children, isNotEmpty, reason: 'premise: generated children');
  for (final k in children) {
    expect(layerOf(doc, k), layer,
        reason: 'generated child ${k.toHex()} (${kindOf(doc, k)})');
  }
  doc.commands.undo();
  expect(doc.tree[h], isNull, reason: 'one undo takes the object away');
  expect(kids(doc, h), isEmpty);
  expect(objectLayerOf(doc, h), isNull,
      reason: 'and its ObjectLayer, with the same step');
  return (h, children.length);
}

/// P-6's fixture with `B` current (by the user form).
LayerDoc onB({bool room = true, bool dimension = true}) {
  final l = layerFixture(room: room, dimension: dimension);
  l.doc.commands.execute(SetCurrentLayerCommand(l.b));
  expect(drawingLayer(l.doc), l.b, reason: 'premise: B is current');
  return l;
}

void main() {
  test('premise: P-6\'s fixture, each object generated on its own layer', () {
    final l = layerFixture();
    final doc = l.doc;
    expect(driftOf(doc), isEmpty);
    expect([
      for (final h in [l.a, l.b, l.c])
        (
          (doc.tables.layers[h]!.color as IndexedColor).aci,
          doc.tables.layers[h]!.visible,
          doc.tables.layers[h]!.locked,
        )
    ], [
      (1, true, false),
      (5, true, true),
      (3, false, false),
    ]);
    for (final w in l.walls) {
      expect(doc.tree.accumulatedTransform(w).isIdentity, isFalse,
          reason: 'every wall in its own rotated group');
    }
    for (final (h, layer) in [
      for (final w in l.walls) (w, l.a),
      (l.openings.single, l.b),
      (l.room!, l.a),
      (l.dimension!, l.b),
    ]) {
      expect(objectLayerOf(doc, h), layer);
      expect(kids(doc, h), isNotEmpty, reason: '${h.toHex()} generated');
      for (final k in kids(doc, h)) {
        expect(layerOf(doc, k), layer, reason: k.toHex());
      }
    }
  });

  test('the Box tool creates its box and its lines on the current layer', () {
    final l = onB();
    final ctx = toolContextOf(l.doc);
    final tool = BoxTool();
    addTearDown(tool.dispose);
    final (_, n) = expectCreatedOn<BoxParams>(l.doc, l.b, () {
      clickWith(tool, ctx, l.at(12000.5, 1000.25));
      clickWith(tool, ctx, l.at(14500.75, 2500.5));
    });
    expect(n, 4, reason: 'four lines');
  });

  test(
      'a stored current layer that is hidden is not the drawing layer: the '
      'Box tool creates on layer 0 (drawingLayer, not header.currentLayer)',
      () {
    final l = layerFixture();
    // Only a file (or the restore form) stores a hidden current layer.
    l.doc.commands.execute(SetCurrentLayerCommand.restore(l.c));
    expect(l.doc.header.currentLayer, l.c);
    final ctx = toolContextOf(l.doc);
    final tool = BoxTool();
    addTearDown(tool.dispose);
    expectCreatedOn<BoxParams>(l.doc, ReservedHandles.layerZero, () {
      clickWith(tool, ctx, l.at(12000.5, 1000.25));
      clickWith(tool, ctx, l.at(14500.75, 2500.5));
    });
  });

  test('the Wall tool creates its wall and its band on the current layer', () {
    final l = onB();
    final ctx = toolContextOf(l.doc);
    final settings = ValueNotifier<WallSettings>(const WallSettings());
    final tool = WallTool(settings);
    addTearDown(() {
      tool.dispose();
      settings.dispose();
    });
    final (_, n) = expectCreatedOn<WallParams>(l.doc, l.b, () {
      clickWith(tool, ctx, l.at(12000.5, 5000.25));
      clickWith(tool, ctx, l.at(15500.75, 6200.5));
    });
    expect(n, 3, reason: 'a fill, its boundary and the centreline');
  });

  test(
      'the Door tool creates its door on the current layer, not its host\'s; '
      'the host keeps its own', () {
    final l = onB();
    final ctx = toolContextOf(l.doc);
    final settings =
        ValueNotifier(OpeningSettings.defaultFor(OpeningKind.door));
    final tool = OpeningTool(OpeningKind.door, settings);
    addTearDown(() {
      tool.dispose();
      settings.dispose();
    });
    final host = l.walls[2];
    expect(objectLayerOf(l.doc, host), l.a, reason: 'premise: host on A');
    final (h, _) = expectCreatedOn<OpeningParams>(l.doc, l.b, () {
      clickWith(tool, ctx, l.at(5000.5, 4010.25));
    });
    // Redo it and read the host's children while the door cuts it.
    l.doc.commands.redo();
    expect(l.doc.components.get<OpeningParams>(h)!.host, host,
        reason: 'premise: the door is on the top wall');
    for (final k in kids(l.doc, host)) {
      expect(layerOf(l.doc, k), l.a, reason: 'the host stays on A');
    }
  });

  test('the Separator tool creates its separator on the current layer', () {
    final l = onB();
    final ctx = toolContextOf(l.doc);
    final inputs = RoomInputs(l.doc);
    final tool = SeparatorTool(inputs);
    addTearDown(() {
      tool.dispose();
      inputs.dispose();
    });
    expectCreatedOn<SeparatorParams>(l.doc, l.b, () {
      clickWith(tool, ctx, l.at(3000.5, 800.25));
      clickWith(tool, ctx, l.at(3000.75, 3200.5));
    });
  });

  test(
      'the Room tool creates its room, its tint and its labels on the '
      'current layer', () {
    final l = onB(room: false);
    final ctx = toolContextOf(l.doc);
    final inputs = RoomInputs(l.doc);
    final tool = RoomTool(inputs);
    addTearDown(() {
      tool.dispose();
      inputs.dispose();
    });
    final (h, n) = expectCreatedOn<RoomParams>(l.doc, l.b, () {
      clickWith(tool, ctx, l.at(5250.5, 2750.25));
    });
    expect(l.doc.components.get<RoomParams>(h), isNull, reason: 'undone');
    expect(n, greaterThanOrEqualTo(4),
        reason: 'a fill, its boundary and two labels');
  });

  test(
      'the Dimension tool creates its dimension and its lines and text on '
      'the current layer', () {
    final l = onB();
    final ctx = toolContextOf(l.doc);
    final tool = DimensionTool();
    addTearDown(tool.dispose);
    expectCreatedOn<DimensionParams>(l.doc, l.b, () {
      clickWith(tool, ctx, l.at(12000.5, 8000.25));
      clickWith(tool, ctx, l.at(15000.75, 8800.5));
      clickWith(tool, ctx, l.at(13500.25, 9800.75));
    });
  });

  test(
      'the symbol placer puts the instance on the current layer, in one undo '
      'step; the definition\'s leaves stay on layer 0', () {
    final l = onB();
    final doc = l.doc;
    final entry = SymbolLibrary.decode(bytesOf(buildValidLibrary()))
        .entries
        .firstWhere((e) => e.key == 'sofa.three');
    final depth = doc.commands.undoDepth;
    doc.commands.execute(placeSymbol(doc, entry,
        at: l.at(3000.5, 2000.25), quarterTurns: 1, mirrored: true));
    expect(doc.commands.undoDepth, depth + 1, reason: 'one undo step');
    final instance = doc.tree.nodes.whereType<InstanceNode>().single;
    expect(instance.layer, l.b, reason: 'the instance takes the layer');
    final leaves = [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.ownerAt(slot) == instance.definition) slot
    ];
    expect(leaves, hasLength(entry.leaves.length),
        reason: 'premise: the definition was copied');
    for (final slot in leaves) {
      expect(doc.entities.layerAt(slot), ReservedHandles.layerZero,
          reason: 'a definition leaf stays on layer 0 (the library\'s rule)');
    }
    doc.commands.undo();
    expect(doc.tree.nodes.whereType<InstanceNode>(), isEmpty);
  });

  test(
      'a Wall tool click in the band of a wall on a hidden layer joins its '
      'end exactly (decision 8: a hidden wall still joins; 8b)', () {
    final l = layerFixture(room: false, dimension: false);
    final doc = l.doc;
    // A wall on its own, away from the box, on the hidden C, in its own
    // rotated group.
    final [hidden] =
        addWallsOn(l, const [W(12000, 1000, 15000, 1000, 200)], l.c);
    expect(doc.tables.layers[l.c]!.visible, isFalse, reason: 'premise');
    for (final k in kids(doc, hidden)) {
      expect(layerOf(doc, k), l.c, reason: 'premise: its children on C');
    }
    final w = worldWallOf(doc, hidden);
    expect(doc.tree.accumulatedTransform(hidden).isIdentity, isFalse,
        reason: 'premise: a rotated group');
    doc.commands.clearHistory();
    final ctx = toolContextOf(doc);
    final settings = ValueNotifier<WallSettings>(const WallSettings());
    final tool = WallTool(settings);
    addTearDown(() {
      tool.dispose();
      settings.dispose();
    });
    final before = groupsOf(doc);
    // In the band, 99.5 mm short of the end along the centreline and 40.25
    // mm off it: within one thickness of the end.
    final click = l.at(14900.5, 1040.25);
    expect((click - w.e).length, greaterThan(1),
        reason: 'premise: the click is not the end itself');
    clickWith(tool, ctx, click);
    clickWith(tool, ctx, l.at(14900.75, 3500.5));
    final added = groupsOf(doc).difference(before);
    expect(added, hasLength(1), reason: 'premise: one wall was drawn');
    final p = doc.components.get<WallParams>(added.single)!;
    expect([p.start.x, p.start.y], [w.e.x, w.e.y],
        reason: 'the new wall starts bitwise at the hidden wall\'s end');
  });
}
