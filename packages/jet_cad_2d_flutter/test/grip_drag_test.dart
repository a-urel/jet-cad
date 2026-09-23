import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/grip_drag.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/grip_fixture.dart';

SelectionKey k(Handle h) => SelectionKey.root(h);

Handle targetOf(DraftCommand c) => switch (c) {
      SetEntityGeometryCommand(:final handle) => handle,
      TransformNodeCommand(:final handle) => handle,
      _ => throw StateError('unexpected member $c'),
    };

/// The next double above a positive [x].
double nextUp(double x) {
  final b = ByteData(8)..setFloat64(0, x);
  b.setInt64(0, b.getInt64(0) + 1);
  return b.getFloat64(0);
}

/// A *decision*-style comparison — what M-03e swaps the undo assertion to.
bool payloadsClose(GeometryPayload a, GeometryPayload b) {
  if (a.coords.length != b.coords.length ||
      a.scalars.length != b.scalars.length) {
    return false;
  }
  for (var i = 0; i < a.coords.length; i++) {
    if (!Tolerance.standard.eq(a.coords[i], b.coords[i])) return false;
  }
  for (var i = 0; i < a.scalars.length; i++) {
    if (!Tolerance.standard.eq(a.scalars[i], b.scalars[i])) return false;
  }
  return true;
}

/// A rotate of a leaf, an arc, the rotated group and an instance, executed
/// and then undone. Returns what was stored before.
(Map<Handle, GeometryPayload>, Map<Handle, Node>) rotateAndUndo(GripScene s) {
  final doc = s.document;
  final payloads = {
    for (final h in [s.line, s.arcNeg]) h: payloadOf(doc, h)
  };
  final nodes = {
    for (final h in [s.group, s.instA]) h: doc.tree[h]!
  };
  final drag = GripDrag.rotate(
      doc,
      [k(s.line), k(s.arcNeg), k(s.group), k(s.instA)],
      Vector2(7200, 3150),
      Vector2(7300, 3150))!;
  drag.rotateTo(Vector2(7250, 3240), step: false);
  doc.commands.execute(drag.command(DraftPermissions.all)!);
  expect(payloadOf(doc, s.line), isNot(payloads[s.line]),
      reason: 'the fixture really moved');
  doc.commands.undo();
  return (payloads, nodes);
}

void main() {
  test(
      'a move is one CompoundCommand labelled Move, members in ascending '
      'handle order (M-03an)', () {
    final s = gripScene();
    final drag = GripDrag.move(
        s.document, [k(s.instA), k(s.group), k(s.arcNeg), k(s.line)])!;
    expect(drag.kind, DragKind.move);
    drag.base.setValues(7046, 3032);
    drag.moveTo(Vector2(7083.5, 3013.25));
    expect(drag.transform!.e, 37.5);
    expect(drag.transform!.f, -18.75);
    final command = drag.command(DraftPermissions.all)! as CompoundCommand;
    expect(command.label, 'Move');
    expect([for (final c in command.children) targetOf(c)],
        [s.line, s.arcNeg, s.group, s.instA]);
    expect([
      for (final c in command.children) c.runtimeType
    ], [
      SetEntityGeometryCommand,
      SetEntityGeometryCommand,
      TransformNodeCommand,
      TransformNodeCommand,
    ]);
  });

  test('a rotated group moves by T.multiply(node.transform) (M-03i)', () {
    final s = gripScene();
    final doc = s.document;
    final g0 = doc.tree[s.group]! as GroupNode;
    expect(g0.transform.b, isNot(0.0),
        reason: "the fixture's group is rotated");
    final leaf0 = payloadOf(doc, s.groupLeaf);
    final drag = GripDrag.move(doc, [k(s.group)])!..base.setValues(7400, 3300);
    drag.moveTo(Vector2(7437.5, 3281.25));
    doc.commands.execute(drag.command(DraftPermissions.all)!);
    final g1 = doc.tree[s.group]! as GroupNode;
    final want = Transform2.translation(37.5, -18.75).multiply(g0.transform);
    final got = g1.transform;
    for (final (a, b) in [
      (got.a, want.a),
      (got.b, want.b),
      (got.c, want.c),
      (got.d, want.d),
      (got.e, want.e),
      (got.f, want.f),
    ]) {
      expect(a, closeTo(b, 1e-9));
    }
    expect(g1.children, g0.children);
    expect(payloadOf(doc, s.groupLeaf), leaf0,
        reason: "the group's leaf lives in the group's space; only the node "
            'moves');
  });

  test(
      'an instance move rewrites the instance node, never the definition '
      '(M-03c)', () {
    final s = gripScene();
    final doc = s.document;
    final a0 = doc.tree[s.instA]! as InstanceNode;
    final b0 = doc.tree[s.instB]!;
    final leaf0 = payloadOf(doc, s.defLeaf);
    final drag = GripDrag.move(doc, [k(s.instA)])!..base.setValues(7460, 3055);
    drag.moveTo(Vector2(7431.25, 3102.5));
    doc.commands.execute(drag.command(DraftPermissions.all)!);
    final a1 = doc.tree[s.instA]! as InstanceNode;
    expect(a1.transform.e, closeTo(a0.transform.e - 28.75, 1e-9));
    expect(a1.transform.f, closeTo(a0.transform.f + 47.5, 1e-9));
    expect(a1.definition, a0.definition);
    expect(doc.tree[s.instB], b0, reason: 'the other instance is untouched');
    expect(payloadOf(doc, s.defLeaf), leaf0, reason: 'so is the definition');
  });

  test("a rotate is labelled Rotate and turns an arc's start angle (M-03h)",
      () {
    final s = gripScene();
    final doc = s.document;
    final drag = GripDrag.rotate(
        doc, [k(s.arcPos)], Vector2(7100, 3100), Vector2(7200, 3100))!;
    drag.rotateTo(
        Vector2(7100 + 100 * math.cos(0.7), 3100 + 100 * math.sin(0.7)),
        step: false);
    expect(drag.theta, closeTo(0.7, 1e-12));
    final command = drag.command(DraftPermissions.all)! as CompoundCommand;
    expect(command.label, 'Rotate');
    doc.commands.execute(command);
    final arc = payloadOf(doc, s.arcPos);
    expect(arc.scalars[0], 40);
    expect(arc.scalars[1], closeTo(1.0, 1e-12));
    expect(arc.scalars[2], 1.9);
    // The centre (7050, 3200) is (−50, 100) from the pivot.
    expect(arc.coords[0],
        closeTo(7100 + math.cos(0.7) * -50 - math.sin(0.7) * 100, 1e-9));
    expect(arc.coords[1],
        closeTo(3100 + math.sin(0.7) * -50 + math.cos(0.7) * 100, 1e-9));
  });

  test('a reshape is one CompoundCommand labelled Stretch', () {
    final s = gripScene();
    final doc = s.document;
    final grip = leafGrips(EntityKind.line, payloadOf(doc, s.line))[1];
    final drag = GripDrag.reshape(doc, k(s.line), grip)!;
    expect(drag.kind, DragKind.reshape);
    expect(drag.leafKind, EntityKind.line);
    expect([drag.base.x, drag.base.y], [7130, 3060]);
    drag.moveTo(Vector2(7150.5, 3070.25));
    expect(drag.previewPayload!.coords, [7010, 3020, 7150.5, 3070.25]);
    final command = drag.command(DraftPermissions.all)! as CompoundCommand;
    expect(command.label, 'Stretch');
    expect(command.children, hasLength(1));
    doc.commands.execute(command);
    expect(payloadOf(doc, s.line).coords, [7010, 3020, 7150.5, 3070.25]);
  });

  test('a drag that changes nothing builds no command (M-03p)', () {
    final s = gripScene();
    final doc = s.document;
    final move = GripDrag.move(doc, [k(s.line)])!..base.setValues(7046, 3032);
    move.moveTo(Vector2(7046, 3032));
    expect(move.command(DraftPermissions.all), isNull,
        reason: 'Δ == (0, 0) exactly');
    final rotate = GripDrag.rotate(
        doc, [k(s.line)], Vector2(7070, 3040), Vector2(7100, 3080))!;
    rotate.rotateTo(Vector2(7100, 3080), step: false);
    expect(rotate.command(DraftPermissions.all), isNull,
        reason: 'θ == 0 exactly');
    final end = leafGrips(EntityKind.line, payloadOf(doc, s.line))[1];
    final same = GripDrag.reshape(doc, k(s.line), end)!
      ..moveTo(Vector2(7130, 3060));
    expect(same.command(DraftPermissions.all), isNull,
        reason: 'a payload == the stored one');
    final radius = leafGrips(EntityKind.circle, payloadOf(doc, s.circle))[1];
    final flat = GripDrag.reshape(doc, k(s.circle), radius)!
      ..moveTo(Vector2(7300, 3250));
    expect(flat.previewPayload, isNull);
    expect(flat.command(DraftPermissions.all), isNull,
        reason: 'a degenerate reshape');
    expect(doc.commands.undoDepth, 0);
  });

  test('release revalidates against the press-time captures (M-03t)', () {
    final s = gripScene();
    final doc = s.document;
    final drag = GripDrag.move(doc, [k(s.line), k(s.instA)])!
      ..base.setValues(7046, 3032);
    drag.moveTo(Vector2(7080, 3010));
    expect(drag.command(DraftPermissions.all), isNotNull);
    doc.commands.execute(SetEntityGeometryCommand(
        s.line,
        GeometryPayload(
            coords: Float64List.fromList([7010, 3020, 7140, 3080]),
            scalars: Float64List(0))));
    expect(drag.command(DraftPermissions.all), isNull,
        reason: 'the leaf is not == its capture');
    doc.commands.undo();
    expect(drag.command(DraftPermissions.all), isNotNull,
        reason: 'undo restored it exactly, so the capture matches again');
    doc.commands
        .execute(TransformNodeCommand(s.instA, Transform2.translation(1, 2)));
    expect(drag.command(DraftPermissions.all), isNull,
        reason: 'the node is not == its capture');
    doc.commands.undo();
    doc.commands.execute(RemoveEntityCommand(s.line));
    expect(drag.command(DraftPermissions.all), isNull,
        reason: 'a target that is gone, with no throw');
  });

  test('a refused member cancels the whole drag (M-03k)', () {
    final s = gripScene();
    final doc = s.document;
    final drag = GripDrag.move(doc, [k(s.line), k(s.instA)])!
      ..base.setValues(7046, 3032);
    drag.moveTo(Vector2(7080, 3010));
    expect(drag.capabilities, {Capability.geometry, Capability.transform});
    expect(drag.permittedBy(DraftPermissions.all), isTrue);
    expect(drag.permittedBy(DraftPermissions.runtime), isFalse);
    expect(drag.command(DraftPermissions.runtime), isNull,
        reason: 'all or nothing: the instance is permitted, the line is not');
    final table = GripDrag.move(doc, [k(s.instA)])!;
    expect(table.capabilities, {Capability.transform});
    expect(table.permittedBy(DraftPermissions.runtime), isTrue);
  });

  test('fills are skipped; a fills-only selection has no drag (M-03am)', () {
    final s = gripScene();
    final doc = s.document;
    final region = AddRegionCommand.allocate(
      seed: doc.handleSeed,
      owner: doc.rootHandle,
      boundaryKind: EntityKind.polyline,
      boundaryPayload: GeometryPayload(
          coords: Float64List.fromList(
              [7600, 3000, 7700, 3000, 7700, 3100, 7600, 3000]),
          scalars: Float64List(0)),
      layer: ReservedHandles.layerZero,
      fillColor: const TrueColor(0x8844AA),
      boundaryColor: const ByLayerColor(),
    );
    doc.commands.execute(region);
    expect(GripDrag.move(doc, [k(region.fill.handle)]), isNull);
    final drag = GripDrag.move(doc, [k(region.fill.handle), k(s.line)])!
      ..base.setValues(7046, 3032);
    drag.moveTo(Vector2(7080, 3010));
    final command = drag.command(DraftPermissions.all)! as CompoundCommand;
    expect([for (final c in command.children) targetOf(c)], [s.line]);
  });

  test(
      'undo restores every stored value with == (spec D11; M-03e is the '
      'designed survivor)', () {
    final s = gripScene();
    final doc = s.document;
    final (payloads, nodes) = rotateAndUndo(s);
    // GeometryPayload == is exact per double. Transform2 is never compared
    // with == (object identity); the nodes are compared by value.
    expect(payloadOf(doc, s.line), payloads[s.line]);
    expect(payloadOf(doc, s.arcNeg), payloads[s.arcNeg]);
    expect(doc.tree[s.group], nodes[s.group]);
    expect(doc.tree[s.instA], nodes[s.instA]);
  });

  test(
      'the undo assertion enforces ==: one ulp is caught (M-03e '
      'companion, Ruling 03-20)', () {
    final s = gripScene();
    final doc = s.document;
    final (payloads, _) = rotateAndUndo(s);
    final restored = payloadOf(doc, s.line);
    final original = payloads[s.line]!;
    final nudged = GeometryPayload(
        coords: Float64List.fromList(restored.coords)
          ..[0] = nextUp(restored.coords[0]),
        scalars: Float64List.fromList(restored.scalars));
    expect(nudged.coords[0], isNot(restored.coords[0]));
    expect(nudged == original, isFalse,
        reason: '== sees one ulp: the undo test above would go red on it');
    expect(payloadsClose(nudged, original), isTrue,
        reason: 'Tolerance does not — which is why M-03e survives');
  });
}
