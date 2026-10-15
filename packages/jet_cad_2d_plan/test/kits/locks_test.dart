// Spec P4 "Locks: a missing kit, a broken object" (A9): which objects are
// locked, what they keep (they draw as saved, their components round-trip
// byte for byte, Review Focus 1) and what they lose: grips, gates, delete,
// and every change on commit, the lock check stacked on the expander after
// the parametric system (apply, check `touched` and the containers,
// roll back, throw PlanLocked). A mid-session lock clears the history.
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/kits/locks.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/box_kit.dart';

/// A plan saved with the box kit: a square [square] (side 1200) and a
/// placed lamp, and a plain line; the text and the handles.
({
  String json,
  Handle square,
  ({Handle definition, Handle instance, Handle circle}) lamp,
  Handle line
}) boxPlan() {
  final a = PlanController(kits: [boxKit(Switches())]);
  final square =
      addObject(a.document, atSquare, const SquareParams(side: 1200));
  final lamp = addLamp(a.document, nearSquare(2400, 300, 0.4));
  final line =
      addLine(a.document, Vector2(-3100.5, 4200.25), Vector2(-1700.75, 5100.5));
  final json = a.save();
  a.dispose();
  return (json: json, square: square, lamp: lamp, line: line);
}

/// A grip provider that gives every group one grip and moves it anywhere.
final class _AllGrips implements ObjectGripProvider {
  int calls = 0;
  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) {
    calls++;
    return const [Grip(GripRole.stretch, 0, 7010, 3020)];
  }

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) {
    calls++;
    return TransformNodeCommand(
        group, Transform2.translation(world.x, world.y));
  }

  @override
  List<(EntityKind, GeometryPayload)> preview(
      DraftDocument d, Handle group, Grip grip, Vector2 world) {
    calls++;
    return [(EntityKind.line, linePayload(Vector2.zero(), world))];
  }

  @override
  bool movable(DraftDocument d, Handle group) {
    calls++;
    return true;
  }
}

/// A command whose apply throws [error] and mutates nothing.
final class _Throws extends DraftCommand {
  _Throws(this.error);
  final Object error;
  @override
  Capability get capability => Capability.geometry;
  @override
  String get label => 'Throws';
  @override
  CommandResult apply(CommandTarget target) => throw error;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'L-1 (Review Focus 1) a plan naming a kit the host did not load opens; '
      'the kit\'s objects keep their drawing and are locked; saving keeps '
      'the manifest entry and the components byte for byte', () {
    final plan = boxPlan();
    final sw = Switches();
    final source = PlanController(kits: [boxKit(sw)], json: plan.json);
    final drawn = coordsOf(source.document, plan.square);
    source.dispose();
    expect(drawn, hasLength(4), reason: 'premise: the square generated');

    final b = PlanController(kits: const [], json: plan.json);
    addTearDown(b.dispose);
    expect(b.missingKits, contains('box'));
    // M-L1a: `LockSet.scan` skipping unknown components leaves the square
    // out; M-L1b: skipping the symbol definitions leaves the lamp out.
    expect(b.locked.value, {plan.square, plan.lamp.instance});
    expect(coordsOf(b.document, plan.square), drawn,
        reason: 'it draws as saved');

    final saved = b.save();
    expect(componentsText(saved, SquareParams.id),
        componentsText(plan.json, SquareParams.id));
    expect(componentsText(saved, SymbolComponent.componentTypeId),
        componentsText(plan.json, SymbolComponent.componentTypeId));
    final again = PlanController(kits: [boxKit(sw)], json: saved);
    addTearDown(again.dispose);
    final root = again.document.rootHandle;
    expect(again.document.components.get<ManifestComponent>(root)!.kits['box'],
        '1.4.0',
        reason: 'the missing kit\'s entry kept as read');
    expect(again.locked.value, isEmpty,
        reason: 'with its kit loaded, nothing is locked');

    b.newPlan();
    // M-L1c: `_open` keeping the previous lock set's objects.
    expect(b.locked.value, isEmpty, reason: 'a new document, a new lock set');
  });

  test(
      'L-2 a forged command on a locked object is refused: PlanLocked, the '
      'document and the history unchanged', () {
    final plan = boxPlan();
    final b = PlanController(kits: const [], json: plan.json);
    addTearDown(b.dispose);
    final d = b.document;
    // An allowed edit first, so the history has something to keep.
    d.commands.execute(SetEntityGeometryCommand(plan.line,
        linePayload(Vector2(-3000.25, 4100.5), Vector2(-1600.5, 5000.75))));
    final depth = d.commands.undoDepth;
    final state = d.commands.stateId;
    final before = canon(d);
    for (final forged in <DraftCommand>[
      TransformNodeCommand(plan.square, nearSquare(310.5, -120.25, 0.2)),
      TransformNodeCommand(plan.lamp.instance, atSquare),
    ]) {
      // M-L2a: `_LockCheck.apply` returning `result` before its check loop
      // throws nothing.
      expect(() => d.commands.execute(forged), throwsA(isA<PlanLocked>()),
          reason: forged.label);
      // M-L2b: the check without `result.inverse.apply(target)` leaves the
      // document changed.
      expect(canon(d), before, reason: forged.label);
      expect(d.commands.undoDepth, depth, reason: forged.label);
      expect(d.commands.stateId, state, reason: forged.label);
      expect(d.commands.canRedo, isFalse, reason: forged.label);
    }
  });

  test(
      'L-3 a child edit is refused through its containers: an entity of the '
      'locked group, a new entity added into it, one removed from it, an '
      'entity of the locked symbol\'s definition; a plain edit passes', () {
    final plan = boxPlan();
    final b = PlanController(kits: const [], json: plan.json);
    addTearDown(b.dispose);
    final d = b.document;
    final child = kids(d, plan.square).first;
    final added = d.handleSeed.next();
    final before = canon(d);
    // M-L3a: `covers` testing the handle alone (no closure, no walk).
    expect(
        () => d.commands.execute(SetEntityGeometryCommand(
            child, linePayload(Vector2(1, 2), Vector2(3, 4)))),
        throwsA(isA<PlanLocked>()));
    expect(
        () => d.commands.execute(AddEntityCommand(
            record: draftRecord(added, plan.square, EntityKind.line,
                layer: ReservedHandles.layerZero),
            payload: linePayload(Vector2(5, 6), Vector2(7, 8)))),
        throwsA(isA<PlanLocked>()),
        reason: 'added into a locked group: the walk finds its owner');
    // M-L3b: `_refresh` leaving the closure empty: after the removal the
    // entity has no owner to walk to.
    expect(() => d.commands.execute(RemoveEntityCommand(child)),
        throwsA(isA<PlanLocked>()));
    expect(
        () => d.commands.execute(SetEntityGeometryCommand(
            plan.lamp.circle, circlePayload(Vector2(1, 1), 99))),
        throwsA(isA<PlanLocked>()),
        reason: 'inside the locked symbol\'s definition');
    expect(canon(d), before);

    d.commands.execute(SetEntityGeometryCommand(plan.line,
        linePayload(Vector2(-2000.5, 3000.25), Vector2(-900.75, 3900.5))));
    expect(d.commands.undoDepth, 1, reason: 'a plain line edits');
  });

  test(
      'L-4 an object of a type its loaded kit does not have is locked too; '
      'the kit is not missing', () {
    final plan = boxPlan();
    final b = PlanController(
        kits: [boxKit(Switches(), types: false)], json: plan.json);
    addTearDown(b.dispose);
    expect(b.missingKits, isNot(contains('box')));
    // M-L4: the scan skipping a component whose kit is loaded.
    expect(b.locked.value, {plan.square});
    expect(
        () => b.document.commands
            .execute(TransformNodeCommand(plan.square, atSquare)),
        throwsA(isA<PlanLocked>()));
  });

  test(
      'L-5 the grip decorator gives a covered group nothing: no grips, no '
      'drag, no preview, not movable; an unlocked group is the inner\'s', () {
    final plan = boxPlan();
    final b = PlanController(kits: const [], json: plan.json);
    addTearDown(b.dispose);
    final d = b.document;
    final locks = LockSet.scan(d, (_) => false);
    final inner = _AllGrips();
    final grips = LockedGrips(locks, inner);
    final world = Vector2(7100.5, 3100.25);
    const grip = Grip(GripRole.stretch, 0, 7010, 3020);
    // M-L5a/b/c/d: each member's `if (_locks.covers(d, group))` dropped.
    expect(grips.gripsOf(d, plan.square), isEmpty);
    expect(grips.drag(d, plan.square, grip, world), isNull);
    expect(grips.preview(d, plan.square, grip, world), isEmpty);
    expect(grips.movable(d, plan.square), isFalse);
    expect(inner.calls, 0, reason: 'the inner is never asked for a lock');
    // A plain group: with no kit loaded the square's type is unregistered.
    final free = d.handleSeed.next();
    d.commands.execute(AddNodeCommand(GroupNode(
        handle: free,
        parent: d.rootHandle,
        transform: nearSquare(-5200, 800, 0.1),
        children: const [])));
    expect(grips.gripsOf(d, free), hasLength(1));
    expect(grips.movable(d, free), isTrue);
    expect(LockedGrips(locks, null).movable(d, free), isTrue,
        reason: 'no inner: an unlocked group moves, as with no provider');
    expect(LockedGrips(locks, null).gripsOf(d, free), isEmpty);
  });

  test(
      'L-6 through the controller: a locked selection shuts every gate, has '
      'no grips and cannot be deleted; a plain selection is open', () {
    final plan = boxPlan();
    final b = PlanController(kits: const [], json: plan.json);
    addTearDown(b.dispose);
    final d = b.document;
    Map<String, bool> open() {
      final g = b.grips.gates!;
      return {
        'move': g.move,
        'rotate': g.rotate,
        'reshape': g.reshape,
        'delete': g.delete,
      };
    }

    b.selection.replace([SelectionKey.root(plan.square)]);
    // M-L6a-d: `LockGates.move` (rotate, reshape, delete) without
    // `&& !_selectionLocked`.
    expect(open().values, everyElement(isFalse));
    // M-L6e: the session handing Task 8's dispatch to the GripCache
    // instead of `LockedGrips(locks, dispatch)`.
    expect(b.grips.objects!.movable(d, plan.square), isFalse);
    expect(b.grips.objects!.gripsOf(d, plan.square), isEmpty);
    // M-L6f: the `plan.select` tool built without `gates:` deletes the
    // locked square (`deleteSelection` is the select tool's, gated by
    // `delete`, select_tool.dart:744-753).
    expect(b.deleteSelection(), isFalse);
    expect(d.tree[plan.square], isNotNull);

    b.selection.replace([SelectionKey.root(plan.line)]);
    expect(open().values, everyElement(isTrue));
    expect(b.deleteSelection(), isTrue);
    expect(d.entities.slotOf(plan.line), isNull, reason: 'the line deleted');
  });

  test(
      'L-7 isLocked: a locked object, its children, a locked symbol\'s '
      'instance, definition and contents; not a plain line, not the root', () {
    final plan = boxPlan();
    final b = PlanController(kits: const [], json: plan.json);
    addTearDown(b.dispose);
    final d = b.document;
    // M-L7: `isLocked` as `locked.value.contains(handle)` misses children
    // and the definition.
    for (final h in [
      plan.square,
      ...kids(d, plan.square),
      plan.lamp.instance,
      plan.lamp.definition,
      plan.lamp.circle,
    ]) {
      expect(b.isLocked(h), isTrue, reason: h.toHex());
    }
    expect(b.isLocked(plan.line), isFalse);
    expect(b.isLocked(d.rootHandle), isFalse);
  });

  test(
      'L-8 an object locked mid-session: the history is cleared, so undo '
      'cannot reach it; its edits and its children\'s are refused', () async {
    final b = PlanController(kits: [boxKit(Switches())]);
    addTearDown(b.dispose);
    final d = b.document;
    final square = addObject(d, atSquare, const SquareParams(side: 900));
    d.commands.execute(SetComponentCommand<SquareParams>(
        square, const SquareParams(side: 1350.5)));
    // The history flags follow the document's (asynchronous) changes.
    await Future<void>.delayed(Duration.zero);
    expect(b.canUndo.value, isTrue, reason: 'premise');
    final before = canon(d);

    b.lockBroken({square});
    // M-L8: `lockBroken` without `commands.clearHistory()`.
    expect(d.commands.canUndo, isFalse);
    expect(b.canUndo.value, isFalse, reason: 'the listenable follows');
    b.undo();
    expect(canon(d), before);
    expect(b.locked.value, {square});
    expect(
        () => d.commands.execute(SetComponentCommand<SquareParams>(
            square, const SquareParams(side: 2000))),
        throwsA(isA<PlanLocked>()));
    // Task 11 freezes a broken object as it locks it (E2: a plain group,
    // whose generated children the parametric system then lets a command
    // edit); the lock is what refuses them.
    b.frozen.add(square);
    expect(
        () => d.commands.execute(SetEntityGeometryCommand(
            kids(d, square).first, linePayload(Vector2(0, 0), Vector2(9, 9)))),
        throwsA(isA<PlanLocked>()),
        reason: 'a frozen object\'s children are covered (E2: a plain group)');
    expect(canon(d), before);
  });

  test(
      'L-9 the lock expander stacks on the parametric one: with a lock set, '
      'a parametric edit still regenerates; dispose puts the slot back', () {
    final d = DraftDocument.empty();
    final catalog = ParametricCatalog()
      ..register<SquareParams>(
          SquareParams.id, SquareParams.fromJson, SquareType(Switches()));
    final system = ParametricSystem(d, catalog)..install();
    final parametricSlot = d.commands.expander;
    final locks = LockSet.scan(d, (_) => true);
    final fence = d.handleSeed.next();
    d.commands.execute(AddNodeCommand(GroupNode(
        handle: fence,
        parent: d.rootHandle,
        transform: nearSquare(-9000, 0, 0),
        children: const [])));
    locks.addBroken(d, {fence});
    final expander = LockExpander(d, locks)..install();
    // M-L9: `_expand` using `command` in place of `_previous?.call(command)`
    // adds the square with no children.
    final square = addObject(d, atSquare, const SquareParams(side: 640));
    expect(kids(d, square), hasLength(4));
    expander.dispose();
    expect(d.commands.expander, parametricSlot);
    system.dispose();
    expect(d.commands.expander, isNull);
  });

  test('L-10 LockGates: a key whose target or chain is locked shuts the gates',
      () {
    final d = DraftDocument.empty();
    final selection = SelectionController(d);
    final locked = ValueNotifier<Set<Handle>>(const {});
    final gates = LockGates(selection: selection, locked: locked);
    addTearDown(() {
      gates.dispose();
      selection.dispose();
      locked.dispose();
    });
    final a = addLine(d, Vector2(10.5, 20.25), Vector2(400.75, 90.5));
    selection.replace([SelectionKey.root(a)]);
    expect(gates.selectionLocked, isFalse);
    // M-L10: `locked.addListener(_recompute)` dropped: the lock arriving
    // after the selection is missed.
    locked.value = {a};
    expect(gates.selectionLocked, isTrue);
    expect([gates.move, gates.rotate, gates.reshape, gates.delete],
        everyElement(isFalse));
    expect(gates.bandAccepts(d, SelectionKey.root(a)), isTrue,
        reason: 'a locked object is still selectable as a whole');
    locked.value = const {};
    expect(gates.move, isTrue);
  });

  test(
      'L-11 execute (ruling R-b) answers false for a refusal (PlanLocked, '
      'DanglingReferenceError, ArgumentError), true for an applied edit, '
      'and lets a StateError through', () {
    final plan = boxPlan();
    final b = PlanController(kits: const [], json: plan.json);
    addTearDown(b.dispose);
    final d = b.document;
    final before = canon(d);
    // M-L11a: `_refusal`'s PlanLocked case dropped: the refusal escapes. A
    // real move (not the square's own placement), so the rollback is
    // observable.
    expect(
        b.execute(
            TransformNodeCommand(plan.square, nearSquare(310.5, -120.25, 0.2))),
        isFalse);
    expect(canon(d), before);
    // M-L11b: ArgumentError dropped from `_refusal`'s refusal case.
    expect(b.execute(_Throws(ArgumentError.value(3, 'side'))), isFalse);
    // M-L11c: `_refusal` answering true for a StateError (or for anything):
    // a StateError is the caller's.
    expect(() => b.execute(_Throws(StateError('refused'))), throwsStateError);
    expect(
        b.execute(SetEntityGeometryCommand(plan.line,
            linePayload(Vector2(-2900.5, 4000.25), Vector2(-1500.75, 4800.5)))),
        isTrue);
    expect(d.commands.undoDepth, 1, reason: 'the applied edit recorded');

    final c = PlanController(kits: [boxKit(Switches())]);
    addTearDown(c.dispose);
    final e = c.document;
    final partner = addObject(e, atSquare, const SquareParams(side: 800));
    final referrer = addObject(e, nearSquare(1500, -400, 0.3),
        SquareParams(side: 450, partner: partner));
    c.frozen.add(partner);
    final state = e.commands.stateId;
    // M-L11d: DanglingReferenceError dropped from `_refusal`'s refusal case:
    // E2's refusal of a frozen object's cascade referrer escapes.
    expect(
        c.execute(SetComponentCommand<SquareParams>(
            referrer, SquareParams(side: 520.5, partner: partner))),
        isFalse);
    expect(e.commands.stateId, state, reason: 'nothing applied');
  });
}
