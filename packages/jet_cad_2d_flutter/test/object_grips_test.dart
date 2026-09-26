import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show SystemMouseCursors;
import 'package:flutter/widgets.dart' show Offset, Path;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/grip_cache.dart';
import 'package:jet_cad_2d_flutter/src/grip_drag.dart';
import 'package:jet_cad_2d_flutter/src/select_tool.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/grip_fixture.dart';
import 'support/selection_fixture.dart';
import 'support/spy_canvas.dart';

// Spec 07 D11: the object grip seam, driven by a fake provider over 03's
// standard grip scene -- off the origin, a rotated root group, a rotated,
// y-flipped camera.

SelectionKey k(Handle h) => SelectionKey.root(h);

Vector2 worldOf(GripRig rig, Offset screen) =>
    rig.camera.value.screenToWorld(Vector2(screen.dx, screen.dy));

/// The first LINE [group] owns directly.
Handle lineOf(DraftDocument d, Handle group) {
  final e = d.entities;
  return [
    for (final slot in e.liveSlots)
      if (e.ownerAt(slot) == group && e.kindAt(slot) == EntityKind.line)
        e.handleAt(slot),
  ].first;
}

/// A provider for any group owning a LINE: two stretch grips at that line's
/// world endpoints. [drag] rewrites the line's end in the group's local
/// space; [replacement], when set, is the command [drag] returns instead.
/// [movable] answers true except for the groups in [immovable] (spec 08
/// D16).
final class FakeObjects implements ObjectGripProvider {
  FakeObjects({this.replacement, this.immovable = const {}});

  final DraftCommand Function(DraftDocument d, Handle group)? replacement;

  /// The groups [movable] calls immovable.
  final Set<Handle> immovable;

  /// Every group [movable] was asked about, in order.
  final List<Handle> movableAsked = [];

  @override
  bool movable(DraftDocument d, Handle group) {
    movableAsked.add(group);
    return !immovable.contains(group);
  }

  /// Every group [gripsOf] was asked about, in order.
  final List<Handle> asked = [];

  /// Every [drag] call, and the command each returned.
  final List<(Handle, Grip, Vector2, DraftCommand)> drags = [];

  int previews = 0;

  (Vector2, Vector2) _world(DraftDocument d, Handle group) {
    final c = payloadOf(d, lineOf(d, group)).coords;
    final m = d.tree.accumulatedTransform(group);
    return (
      m.transformPoint(Vector2(c[0], c[1])),
      m.transformPoint(Vector2(c[2], c[3])),
    );
  }

  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) {
    asked.add(group);
    final (a, b) = _world(d, group);
    return [
      Grip(GripRole.stretch, 0, a.x, a.y),
      Grip(GripRole.stretch, 1, b.x, b.y),
    ];
  }

  /// The line with end [grip].index at world [world], in [space].
  static GeometryPayload moved(
      GeometryPayload line, Grip grip, Vector2 world, Transform2 space) {
    final c = Float64List.fromList(line.coords);
    final p = space.transformPoint(world);
    c[2 * grip.index] = p.x;
    c[2 * grip.index + 1] = p.y;
    return GeometryPayload(coords: c, scalars: Float64List(0));
  }

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) {
    final line = lineOf(d, group);
    final command = replacement?.call(d, group) ??
        CompoundCommand([
          SetEntityGeometryCommand(
              line,
              moved(payloadOf(d, line), grip, world,
                  d.tree.accumulatedTransform(group).invert())),
        ], label: 'Fake');
    drags.add((group, grip, world.clone(), command));
    return command;
  }

  @override
  List<(EntityKind, GeometryPayload)> preview(
      DraftDocument d, Handle group, Grip grip, Vector2 world) {
    previews++;
    final (a, b) = _world(d, group);
    final line = GeometryPayload(
        coords: Float64List.fromList([a.x, a.y, b.x, b.y]),
        scalars: Float64List(0));
    return [
      (EntityKind.line, moved(line, grip, world, Transform2.identity())),
    ];
  }
}

/// The scene's group, and its line, 40 long in local space.
({GripScene s, Handle group, Handle line}) scene() {
  final s = gripScene();
  return (s: s, group: s.group, line: s.groupLeaf);
}

/// The index in [rig]'s grips of [group]'s object grip [ordinal].
int objectGrip(GripRig rig, Handle group, int ordinal) => rig.grips.grips
    .indexWhere((r) => r.object && r.key == k(group) && r.ordinal == ordinal);

/// A world point off every other object: 30 up and 20 across from the
/// group's far end, in world.
Vector2 targetFrom(Grip g) => Vector2(g.x + 20, g.y + 30);

/// The handle a move's or rotate's member rewrites.
Handle memberOf(DraftCommand c) => switch (c) {
      SetEntityGeometryCommand(:final handle) => handle,
      TransformNodeCommand(:final handle) => handle,
      _ => throw StateError('unexpected member $c'),
    };

/// [t]'s six numbers, for exact comparison.
List<double> numbers(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];

/// A second root-level group beside the scene's: rotated, off the origin,
/// owning one LINE of its own.
Handle addOtherGroup(DraftDocument doc) {
  final g = addGroup(doc, doc.rootHandle,
      Transform2.translation(7320, 3110).multiply(Transform2.rotation(-0.4)));
  addEntity(doc, g, EntityKind.line, [0, 0, 25, 10], []);
  doc.commands.clearHistory();
  return g;
}

/// The screen point of the scene group's line at 20 of its 40, local: its
/// body, 20 away from both of the fake's grips.
Offset groupBody(GripRig rig, Handle group) {
  final p = rig.document.tree
      .accumulatedTransform(group)
      .transformPoint(Vector2(20, 0));
  return screenOf(rig.camera, p.x, p.y);
}

/// Hovers [at] with no button down.
void hover(GripRig rig, Offset at) =>
    rig.tool.onPointerMove(pointerAt(rig.camera, at, buttons: 0), rig.context);

void main() {
  test(
      'OG1 without a provider a selected group has no grips: the cache is '
      "exactly today's", () {
    final f = scene();
    final doc = f.s.document;
    final rig = gripRig(doc);
    expect(rig.grips.objects, isNull);
    rig.selection.replace([k(f.group)]);
    expect(rig.grips.grips, isEmpty);
    rig.selection.replace([k(f.s.line), k(f.group), k(f.s.instA)]);
    expect([
      for (final r in rig.grips.grips) (r.key, r.grip, r.ordinal)
    ], [
      for (final (i, g)
          in leafGrips(EntityKind.line, payloadOf(doc, f.s.line)).indexed)
        (k(f.s.line), g, i),
    ]);
    expect(rig.grips.grips.any((r) => r.object), isFalse);
  });

  test(
      'OG2 a provider\'s grips appear for a selected root-level group only, '
      'in world, after the lower handles\' grips', () {
    final f = scene();
    final doc = f.s.document;
    // A group nested in the root group, owning a line of its own.
    final nested = addGroup(doc, f.group, Transform2.translation(15, -8));
    addEntity(doc, nested, EntityKind.line, [0, 0, 10, 5], []);
    doc.commands.clearHistory();
    final fake = FakeObjects();
    final rig = gripRig(doc, objects: fake);
    rig.selection.replace([k(f.s.line)]);
    expect(fake.asked, isEmpty, reason: 'no group is selected');
    expect(rig.grips.grips.any((r) => r.object), isFalse);

    rig.selection.replace([k(nested), k(f.s.instA), k(f.group), k(f.s.line)]);
    expect(fake.asked, [f.group],
        reason: 'neither an instance nor a nested group is asked');
    final m = doc.tree.accumulatedTransform(f.group);
    final a = m.transformPoint(Vector2(0, 0));
    final b = m.transformPoint(Vector2(40, 0));
    expect([
      for (final r in rig.grips.grips) (r.key, r.grip, r.object)
    ], [
      for (final g in leafGrips(EntityKind.line, payloadOf(doc, f.s.line)))
        (k(f.s.line), g, false),
      (k(f.group), Grip(GripRole.stretch, 0, a.x, a.y), true),
      (k(f.group), Grip(GripRole.stretch, 1, b.x, b.y), true),
    ]);
    expect(b.x, isNot(closeTo(7440, 1)), reason: 'the group is rotated');
    expect(rig.grips.stretchCount, 4);

    // The pointer finds it like a leaf grip.
    final i = objectGrip(rig, f.group, 1);
    expect(
        rig.grips.hitTest(screenOf(rig.camera, b.x, b.y) + const Offset(3, -2),
            rig.camera.value.worldToScreenMatrix),
        i);
  });

  test(
      'OG3 a drag of an object grip dispatches the provider\'s command, '
      'wrapped in one Stretch, one undo step; its preview is painted',
      () async {
    final f = scene();
    final doc = f.s.document;
    final fake = FakeObjects();
    final rig = gripRig(doc, objects: fake);
    rig.selection.replace([k(f.group)]);
    final before = snapshot(doc);
    final labels = <String>[];
    final sub = doc.changes.listen((c) {
      if (c is CommandApplied) labels.add(c.label);
    });
    addTearDown(sub.cancel);
    final grip = rig.grips.grips[objectGrip(rig, f.group, 1)].grip;
    final from = screenOf(rig.camera, grip.x, grip.y);
    final aim = targetFrom(grip);
    final to = screenOf(rig.camera, aim.x, aim.y);
    pressAndMove(rig, from, to);
    expect(rig.tool.pressClass, PressClass.grip);
    expect(rig.tool.dragKind, DragKind.reshape);
    expect(fake.previews, greaterThan(0));
    expect(fake.drags, isEmpty, reason: 'nothing is built before release');

    // The preview: one path, the provider's moved line, rebased.
    final origin = Vector2(7000, 3000);
    final spy = SpyCanvas();
    rig.tool.paintWorldOverlay(spy, origin, rig.camera.value.scale);
    final path = spy.named('drawPath').single.args[0]! as Path;
    final world = worldOf(rig, to);
    final m = doc.tree.accumulatedTransform(f.group);
    final a = m.transformPoint(Vector2(0, 0)) - origin;
    final w = world - origin;
    final bounds = path.getBounds();
    expect([
      bounds.left,
      bounds.top,
      bounds.right,
      bounds.bottom
    ], [
      closeTo(a.x < w.x ? a.x : w.x, 1e-3),
      closeTo(a.y < w.y ? a.y : w.y, 1e-3),
      closeTo(a.x > w.x ? a.x : w.x, 1e-3),
      closeTo(a.y > w.y ? a.y : w.y, 1e-3),
    ]);

    release(rig, to);
    await Future<void>.delayed(Duration.zero); // the change stream delivers
    final (group, got, at, _) = fake.drags.single;
    expect(group, f.group);
    expect(got, grip);
    expect([at.x, at.y], [world.x, world.y],
        reason: 'the resolved target, exactly');
    expect(labels, ['Stretch']);
    expect(doc.commands.undoDepth, 1);
    final local = m.invert().transformPoint(world);
    expect(payloadOf(doc, f.line).coords, [0, 0, local.x, local.y]);

    // The same command, straight from a GripDrag: a Stretch whose one
    // member is the provider's own.
    doc.commands.undo();
    expect(snapshot(doc), before);
    final drag = GripDrag.reshapeObject(doc, k(f.group), grip, fake)!;
    drag.moveTo(world);
    final built = drag.command(DraftPermissions.all)! as CompoundCommand;
    expect(built.label, 'Stretch');
    expect(built.children.single, same(fake.drags.last.$4));
  });

  group('OG4 a document change mid-drag cancels the object reshape', () {
    for (final (name, change)
        in <(String, void Function(DraftDocument, Handle, Handle))>[
      (
        'the group node',
        (d, g, _) => d.commands.execute(TransformNodeCommand(
            g,
            Transform2.translation(3, 1)
                .multiply(d.tree.accumulatedTransform(g))))
      ),
      (
        "a child's payload",
        (d, _, line) => d.commands.execute(SetEntityGeometryCommand(
            line,
            GeometryPayload(
                coords: Float64List.fromList([0, 0, 41, 0]),
                scalars: Float64List(0))))
      ),
      (
        'a child added',
        (d, g, _) => addEntity(d, g, EntityKind.line, [5, 5, 9, 9], [])
      ),
    ]) {
      test(name, () {
        final f = scene();
        final doc = f.s.document;
        final fake = FakeObjects();
        final rig = gripRig(doc, objects: fake);
        rig.selection.replace([k(f.group)]);
        final grip = rig.grips.grips[objectGrip(rig, f.group, 1)].grip;
        final aim = targetFrom(grip);
        final to = screenOf(rig.camera, aim.x, aim.y);
        pressAndMove(rig, screenOf(rig.camera, grip.x, grip.y), to);
        expect(rig.tool.dragKind, DragKind.reshape);
        change(doc, f.group, f.line);
        expect(doc.commands.undoDepth, 1);
        final after = snapshot(doc);
        release(rig, to);
        expect(fake.drags, isEmpty, reason: 'revalidation refused first');
        expect(doc.commands.undoDepth, 1);
        expect(snapshot(doc), after);
      });
    }
  });

  test(
      'OG5 an object grip needs components and geometry: runtime denies it, '
      'and so does components alone', () {
    final f = scene();
    final doc = f.s.document;
    final fake = FakeObjects();
    final rig = gripRig(doc, objects: fake);
    rig.selection.replace([k(f.group)]);
    final grip = rig.grips.grips[objectGrip(rig, f.group, 1)].grip;
    final from = screenOf(rig.camera, grip.x, grip.y);
    final aim = targetFrom(grip);
    final to = screenOf(rig.camera, aim.x, aim.y);

    // Geometry allowed, components denied: the grip is hit, the drag never
    // starts, and the press stays a click.
    doc.commands.permissions = const DraftPermissions(
        transform: true, components: false, geometry: true, structure: true);
    final before = snapshot(doc);
    pressAndMove(rig, from, to);
    expect(rig.tool.pressClass, PressClass.grip);
    expect(rig.tool.dragKind, isNull);
    release(rig, to);
    expect(fake.drags, isEmpty);
    expect(snapshot(doc), before);

    // Runtime: no grip is hit at all.
    doc.commands.permissions = DraftPermissions.runtime;
    expect(rig.grips.hitTest(from, rig.camera.value.worldToScreenMatrix), -1);

    // A drag built directly: its needs are the grip's, whatever the
    // provider's command names. Here that command needs only components,
    // which runtime allows; the drag is still refused.
    PageComponent.register(doc.components);
    final componentsOnly = FakeObjects(
        replacement: (d, g) =>
            SetComponentCommand<PageComponent>(g, PageComponent()));
    final drag = GripDrag.reshapeObject(doc, k(f.group), grip, componentsOnly)!;
    expect(drag.capabilities, {Capability.components, Capability.geometry});
    expect(drag.permittedBy(DraftPermissions.runtime), isFalse);
    drag.moveTo(aim);
    expect(drag.command(DraftPermissions.runtime), isNull);
    expect(componentsOnly.drags, isEmpty);
    expect(drag.command(DraftPermissions.all), isNotNull,
        reason: 'the control: allowed, it builds');
  });

  // ---- Spec 08 D16, Ruling 08-16: `movable` -----------------------------

  test(
      'MV1 (M-08i) GripDrag.move and rotate skip a root-level group the '
      'provider calls immovable: alone nothing is captured; in a mixed '
      'selection the rest moves and rotates and the group stays', () {
    final f = scene();
    final doc = f.s.document;
    final other = addOtherGroup(doc);
    final fake = FakeObjects(immovable: {f.group});
    final pivot = Vector2(7310, 3170), press = Vector2(7390, 3120);

    // Alone: nothing to capture, so no drag.
    expect(GripDrag.move(doc, [k(f.group)], objects: fake), isNull);
    expect(GripDrag.rotate(doc, [k(f.group)], pivot, press, objects: fake),
        isNull);
    // The controls: without a provider it is captured.
    expect(GripDrag.move(doc, [k(f.group)]), isNotNull);
    expect(GripDrag.rotate(doc, [k(f.group)], pivot, press), isNotNull);

    final keys = [k(f.s.instA), k(f.group), k(other), k(f.s.line)];
    final rest = [f.s.line, f.s.instA, other]
      ..sort((a, b) => a.value.compareTo(b.value));
    final g0 = doc.tree[f.group]!;
    final o0 = doc.tree[other]!.transform;
    final before = snapshot(doc);

    // The move: only root-level groups are asked.
    fake.movableAsked.clear();
    final move = GripDrag.move(doc, keys, objects: fake)!
      ..base.setValues(7100, 3100)
      ..moveTo(Vector2(7163.5, 3071.25));
    expect(fake.movableAsked.toSet(), {f.group, other});
    final moved = move.command(DraftPermissions.all)! as CompoundCommand;
    expect([for (final c in moved.children) memberOf(c)], rest);
    doc.commands.execute(moved);
    expect(doc.tree[f.group], g0, reason: 'the immovable group stays');
    expect(numbers(doc.tree[other]!.transform),
        numbers(move.transform!.multiply(o0)),
        reason: 'the movable group moves');
    doc.commands.undo();
    expect(snapshot(doc), before);

    // The rotate.
    final rotate = GripDrag.rotate(doc, keys, pivot, press, objects: fake)!
      ..rotateTo(pivot + Vector2(math.cos(1.1), math.sin(1.1)) * 80,
          step: false);
    final rotated = rotate.command(DraftPermissions.all)! as CompoundCommand;
    expect([for (final c in rotated.children) memberOf(c)], rest);
    doc.commands.execute(rotated);
    expect(doc.tree[f.group], g0, reason: 'the immovable group stays');
    expect(numbers(doc.tree[other]!.transform),
        numbers(rotate.transform!.multiply(o0)),
        reason: 'the movable group turns');
  });

  test(
      'MV2 (X11-rotgrip, M-08i) the rotation grip needs a movable key: an '
      'immovable group alone has a box but is not rotatable, and its grip '
      'is neither hit nor pressed; beside a movable key it is', () {
    final f = scene();
    final doc = f.s.document;
    final rig = gripRig(doc, objects: FakeObjects(immovable: {f.group}));
    final m = rig.camera.value.worldToScreenMatrix;
    rig.selection.replace([k(f.group)]);
    expect(rig.grips.box, isNotNull, reason: 'the group has an outline');
    expect(rig.grips.rotatable, isFalse);
    final disc = rotationGripOf(rig.grips.box!, m, rig.grips.frame).centre;
    expect(rig.grips.hitsRotationGrip(disc, m), isFalse);
    rig.tool.onPointerDown(pointerAt(rig.camera, disc), rig.context);
    expect(rig.tool.pressClass, isNot(PressClass.rotationGrip));
    release(rig, disc);

    // With a movable leaf beside it: rotatable, and hit.
    rig.selection.replace([k(f.group), k(f.s.line)]);
    expect(rig.grips.rotatable, isTrue);
    final both = rotationGripOf(rig.grips.box!, m, rig.grips.frame).centre;
    expect(rig.grips.hitsRotationGrip(both, m), isTrue);

    // The control: a provider that calls it movable.
    final movable = gripRig(doc, objects: FakeObjects());
    movable.selection.replace([k(f.group)]);
    expect(movable.grips.rotatable, isTrue);
    expect(movable.grips.hitsRotationGrip(disc, m), isTrue);
  });

  test(
      'MV3 (X11-cursor, M-08i) through the select tool, at all four of its '
      'call sites: a body drag on a selected or unselected immovable group '
      'stays a click with no command and hovering it shows no move cursor; '
      'a centre grip and the rotation grip move and turn the rest only', () {
    final f = scene();
    final doc = f.s.document;
    final rig = gripRig(doc, objects: FakeObjects(immovable: {f.group}));
    final body = groupBody(rig, f.group);
    final away = body + const Offset(60, -35);
    final g0 = doc.tree[f.group]!;
    final before = snapshot(doc);

    // Selected: no move cursor; a drag stays a click.
    rig.selection.replace([k(f.group)]);
    hover(rig, body);
    expect(rig.selection.hover, k(f.group), reason: 'it is under the pointer');
    expect(rig.tool.cursor, isNot(SystemMouseCursors.move));
    pressAndMove(rig, body, away);
    expect(rig.tool.pressClass, PressClass.selectedBody);
    expect(rig.tool.dragKind, isNull);
    release(rig, away);
    expect(doc.commands.undoDepth, 0);
    expect(snapshot(doc), before);
    expect(rig.selection.keys, [k(f.group)]);

    // Unselected: the press selects it, and nothing moves.
    rig.selection.clear();
    pressAndMove(rig, body, away);
    expect(rig.tool.pressClass, PressClass.unselectedBody);
    expect(rig.tool.dragKind, isNull);
    release(rig, away);
    expect(doc.commands.undoDepth, 0);
    expect(rig.selection.keys, [k(f.group)]);

    // A circle's centre grip moves the selection: the circle, not the group.
    rig.selection.replace([k(f.group), k(f.s.circle)]);
    final centre = rig.grips.grips.indexWhere(
        (r) => r.key == k(f.s.circle) && r.grip.role == GripRole.move);
    final cg = rig.grips.grips[centre].grip;
    final c0 = payloadOf(doc, f.s.circle).coords.toList();
    final from = screenOf(rig.camera, cg.x, cg.y);
    pressAndMove(rig, from, from + const Offset(-40, 25));
    expect(rig.tool.dragKind, DragKind.move);
    release(rig, from + const Offset(-40, 25));
    expect(doc.commands.undoDepth, 1);
    expect(doc.tree[f.group], g0, reason: 'the group stays');
    expect(payloadOf(doc, f.s.circle).coords.toList(), isNot(c0));
    doc.commands.undo();

    // The rotation grip turns the line, not the group.
    rig.selection.replace([k(f.group), k(f.s.line)]);
    final m = rig.camera.value.worldToScreenMatrix;
    final disc = rotationGripOf(rig.grips.box!, m, rig.grips.frame).centre;
    final l0 = payloadOf(doc, f.s.line).coords.toList();
    pressAndMove(rig, disc, disc + const Offset(70, 40));
    expect(rig.tool.dragKind, DragKind.rotate);
    release(rig, disc + const Offset(70, 40));
    expect(doc.commands.undoDepth, 1);
    expect(doc.tree[f.group], g0, reason: 'the group stays');
    expect(payloadOf(doc, f.s.line).coords.toList(), isNot(l0));
  });

  test(
      'MV4 without a provider, and with one that calls every group movable, '
      'the rotation grip, the cursor and a body drag are today\'s', () {
    for (final movable in [false, true]) {
      final f = scene();
      final doc = f.s.document;
      final objects = movable ? FakeObjects() : null;
      final rig = gripRig(doc, objects: objects);
      final why = movable ? 'a provider' : 'no provider';
      rig.selection.replace([k(f.group)]);
      expect(rig.grips.rotatable, isTrue, reason: why);
      final body = groupBody(rig, f.group);
      hover(rig, body);
      expect(rig.tool.cursor, SystemMouseCursors.move, reason: why);
      final g0 = doc.tree[f.group]!.transform;
      pressAndMove(rig, body, body + const Offset(60, -35));
      expect(rig.tool.dragKind, DragKind.move, reason: why);
      final t = rig.tool.selectionPreviewTransform!;
      release(rig, body + const Offset(60, -35));
      expect(doc.commands.undoDepth, 1, reason: why);
      expect(numbers(doc.tree[f.group]!.transform), numbers(t.multiply(g0)),
          reason: why);
      // The same members with the provider as without.
      final keys = [k(f.s.instA), k(f.group), k(f.s.line)];
      List<Handle> members(ObjectGripProvider? p) {
        final drag = GripDrag.move(doc, keys, objects: p)!
          ..moveTo(Vector2(7003, 2990));
        final c = drag.command(DraftPermissions.all)! as CompoundCommand;
        return [for (final m in c.children) memberOf(m)];
      }

      expect(members(objects), members(null), reason: why);
      expect(members(objects), hasLength(3), reason: why);
    }
  });
}
