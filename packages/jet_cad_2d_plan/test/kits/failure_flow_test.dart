// Spec P4 "The failure boundary", through the controller: a hook that
// fails during an edit is caught at the expander, that type's objects are
// probed (E2), the failing ones frozen and locked, the history cleared,
// and the edit run once more; a second failure refuses it with one
// diagnostic. A load probes once. A component its factory cannot read is
// kept raw, locked and frozen (E4). A rollback that throws damages the
// plan (E3), and saving a damaged plan first reads it back.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/kits/guard.dart' show GuardedTool;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/box_kit.dart';

/// [owner]'s entities' scalars (a circle's radius), in handle order.
List<double> scalarsOf(DraftDocument d, Handle owner) => [
      for (final k in kids(d, owner))
        ...d.geometry
            .read(d.entities.geomIndexAt(d.entities.slotOf(k)!))
            .scalars,
    ];

List<KitDiagnostic> diagnosticsOf(PlanController c, KitDiagnosticCode code) => [
      for (final d in c.diagnostics.value)
        if (d.code == code) d
    ];

/// Applies [inner], then hands back an inverse that throws: a command
/// whose rollback fails.
final class _Sabotage extends DraftCommand {
  _Sabotage(this.inner);
  final DraftCommand inner;
  @override
  Capability get capability => inner.capability;
  @override
  Set<Capability> get capabilities => inner.capabilities;
  @override
  String get label => 'Sabotage';
  @override
  CommandResult apply(CommandTarget target) {
    final r = inner.apply(target);
    return CommandResult(inverse: _Throwing(), touched: r.touched);
  }
}

final class _Throwing extends DraftCommand {
  @override
  Capability get capability => Capability.components;
  @override
  String get label => 'Throwing';
  @override
  CommandResult apply(CommandTarget target) =>
      throw StateError('this inverse refuses');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'F-1 (spec Tests) an object whose reach throws: one edit of it is '
      'refused, the object is frozen and locked; then a plain line is drawn '
      'and edited, and the other square still regenerates', () {
    final sw = Switches();
    final c = PlanController(kits: [boxKit(sw)]);
    addTearDown(c.dispose);
    final d = c.document;
    final broken =
        addObject(d, atSquare, const SquareParams(side: 1200, poisoned: true));
    final other = addObject(
        d, nearSquare(4000, -500, 0.25), const SquareParams(side: 500));
    final drawn = coordsOf(d, broken);
    sw.failing.add('reach');

    // M-F1a: `FailureBoundary.recover` returning false at once: the move
    // is refused by the failure, not by the lock, so nothing is locked and
    // no hint is shown. `execute` catches the retry's PlanLocked and
    // answers false (controller ruling R-b).
    expect(c.execute(TransformNodeCommand(broken, nearSquare(100.5, 50.25, 0))),
        isFalse);
    // M-F1c: `execute`'s `on PlanLocked` clause without
    // `lockHint.value = true;`.
    expect(c.lockHint.value, isTrue);
    expect(c.locked.value, {broken});
    final failures = diagnosticsOf(c, KitDiagnosticCode.hookFailed);
    expect(failures, hasLength(1));
    expect((failures.single.kitId, failures.single.subject),
        ('box', SquareParams.id));

    // M-F1b: `_freeze` without `frozen.addAll(objects)`: the object is
    // locked but still surveyed, and every edit fails on its reach.
    final line = d.handleSeed.next();
    expect(
        c.execute(AddEntityCommand(
            record: draftRecord(line, d.rootHandle, EntityKind.line,
                layer: ReservedHandles.layerZero),
            payload: linePayload(
                Vector2(-3100.5, 4200.25), Vector2(-1700.75, 5100.5)))),
        isTrue);
    expect(
        c.execute(SetEntityGeometryCommand(line,
            linePayload(Vector2(-3000.25, 4100.5), Vector2(-1600.5, 5000.75)))),
        isTrue);
    final otherBefore = coordsOf(d, other);
    expect(
        c.execute(SetComponentCommand<SquareParams>(
            other, const SquareParams(side: 650.5))),
        isTrue);
    expect(coordsOf(d, other), isNot(otherBefore), reason: 'regenerated');
    expect(kids(d, other), hasLength(4));
    expect(coordsOf(d, broken), drawn,
        reason: 'the broken one keeps its geometry');
    expect(diagnosticsOf(c, KitDiagnosticCode.hookFailed), hasLength(1));
  });

  test(
      'F-2 (Review Focus 2) a broken square beside a working disc of another '
      'kit: the disc\'s edit is not refused; afterwards both kits\' working '
      'objects regenerate and the broken one keeps its geometry', () async {
    final sw = Switches();
    final c = PlanController(kits: [boxKit(sw), ringKit(sw)]);
    addTearDown(c.dispose);
    final d = c.document;
    final broken =
        addObject(d, atSquare, const SquareParams(side: 1200, poisoned: true));
    final disc =
        addObject(d, nearSquare(300, 200, 0), const DiscParams(radius: 700));
    final square = addObject(
        d, nearSquare(5200, 900, -0.4), const SquareParams(side: 400));
    final drawn = coordsOf(d, broken);
    sw.failing.add('placeBox');

    // M-F2: the controller not setting `LockExpander.onHookFailure` (no
    // recovery): the disc's edit is refused.
    expect(
        c.execute(SetComponentCommand<DiscParams>(
            disc, const DiscParams(radius: 850.5))),
        isTrue);
    expect(scalarsOf(d, disc), [850.5]);
    expect(c.locked.value, {broken});
    expect(
        c.execute(SetComponentCommand<DiscParams>(
            disc, const DiscParams(radius: 910.25))),
        isTrue);
    expect(scalarsOf(d, disc), [910.25]);
    final before = coordsOf(d, square);
    expect(
        c.execute(SetComponentCommand<SquareParams>(
            square, const SquareParams(side: 720.5))),
        isTrue);
    expect(coordsOf(d, square), isNot(before));
    expect(coordsOf(d, broken), drawn);
    expect(diagnosticsOf(c, KitDiagnosticCode.hookFailed), hasLength(1));
    // The history flags follow the document's (asynchronous) changes.
    await Future<void>.delayed(Duration.zero);
    expect(c.canUndo.value, isTrue, reason: 'the edits after the lock undo');
  });

  test(
      'F-3 a failure no object explains (the edit\'s own new value) is '
      'refused: no throw, the document and history unchanged, one '
      'diagnostic however often it recurs', () {
    final sw = Switches();
    final c = PlanController(kits: [boxKit(sw)]);
    addTearDown(c.dispose);
    final d = c.document;
    const p = SquareParams(side: 1200);
    final s = addObject(d, atSquare, p);
    sw.failing.add('reach');
    final before = canon(d);
    final depth = d.commands.undoDepth;
    final poisonIt =
        SetComponentCommand<SquareParams>(s, p.copyWith(poisoned: true));
    // M-F3a: `execute` rethrowing a KitHookFailure instead of answering
    // false.
    expect(c.execute(poisonIt), isFalse);
    expect(c.execute(poisonIt), isFalse);
    expect(canon(d), before);
    expect(d.commands.undoDepth, depth);
    expect(c.locked.value, isEmpty, reason: 'nothing to blame, nothing frozen');
    // M-F3b: `DiagnosticsLog.add` without its `_seen` check.
    expect(diagnosticsOf(c, KitDiagnosticCode.hookFailed), hasLength(1));
  });

  test(
      'F-4 a plan whose object is already broken: the load\'s dry run finds '
      'it, so it is frozen and locked before the first edit', () {
    final sw = Switches();
    final a = PlanController(kits: [boxKit(sw)]);
    final broken = addObject(
        a.document, atSquare, const SquareParams(side: 1200, poisoned: true));
    final other = addObject(a.document, nearSquare(4000, -500, 0.25),
        const SquareParams(side: 500));
    final json = a.save();
    final drawn = coordsOf(a.document, broken);
    a.dispose();
    sw.failing.add('generate');

    final c = PlanController(kits: [boxKit(sw)], json: json);
    addTearDown(c.dispose);
    // M-F4: the per-document build without `boundary.probeLoaded()`.
    expect(c.locked.value, {broken});
    expect(diagnosticsOf(c, KitDiagnosticCode.hookFailed), hasLength(1));
    expect(
        c.execute(SetComponentCommand<SquareParams>(
            other, const SquareParams(side: 640.5))),
        isTrue);
    expect(coordsOf(c.document, broken), drawn);
  });

  test(
      'F-5 (E4) a component its factory cannot read: the plan opens, the '
      'object is locked, one diagnostic names it, and saving writes the '
      'component back as read', () {
    final sw = Switches();
    final a = PlanController(kits: [boxKit(sw)]);
    final broken = addObject(
        a.document, atSquare, const SquareParams(side: 1200, poisoned: true));
    addObject(a.document, nearSquare(4000, -500, 0.25),
        const SquareParams(side: 500));
    final json = a.save();
    a.dispose();
    sw.failing.add('fromJson');

    final c = PlanController(kits: [boxKit(sw)], json: json);
    addTearDown(c.dispose);
    // M-F5: the per-document build without `boundary.reportUnreadable(...)`.
    final unreadable = diagnosticsOf(c, KitDiagnosticCode.componentUnreadable);
    expect(unreadable, hasLength(1));
    expect((unreadable.single.kitId, unreadable.single.subject),
        ('box', SquareParams.id));
    expect(c.locked.value, {broken});
    expect(componentsText(c.save(), SquareParams.id),
        componentsText(json, SquareParams.id));
  });

  test(
      'F-6 (E3) a rollback that throws: the plan is damaged, the history '
      'cleared, a diagnostic reported; a damaged plan that reads back saves',
      () async {
    final sw = Switches();
    final c = PlanController(kits: [boxKit(sw)]);
    addTearDown(c.dispose);
    final d = c.document;
    final s = addObject(d, atSquare, const SquareParams(side: 1200));
    addLine(d, Vector2(-3100.5, 4200.25), Vector2(-1700.75, 5100.5));
    await Future<void>.delayed(Duration.zero);
    expect(c.canUndo.value, isTrue, reason: 'premise');
    sw.failing.add('reach');
    // The edit's after-survey fails on the new value, and the inverse the
    // engine then applies throws: E3's PartialMutationError.
    expect(
        () => c.execute(_Sabotage(SetComponentCommand<SquareParams>(
            s, const SquareParams(side: 1300, poisoned: true)))),
        throwsA(isA<PartialMutationError>()));
    // M-F6a: the controller not setting `LockExpander.onPartialMutation`.
    expect(c.damaged.value, isTrue);
    // M-F6b: the damage handler without `commands.notifyLoaded()`.
    expect(d.commands.canUndo, isFalse);
    expect(c.canUndo.value, isFalse);
    expect(diagnosticsOf(c, KitDiagnosticCode.rollbackFailed), hasLength(1));
    sw.failing.clear();
    expect(c.save(), contains('"jetcad.manifest"'),
        reason: 'it reads back, so it saves');
    c.newPlan();
    expect(c.damaged.value, isFalse, reason: 'a new document is not damaged');
  });

  test(
      'F-7 a damaged plan that does not read back is not saved: '
      'PlanFormatException(damagedUnsavable) and a diagnostic', () {
    final sw = Switches();
    final c = PlanController(kits: [boxKit(sw)]);
    addTearDown(c.dispose);
    final d = c.document;
    final s = addObject(d, atSquare, const SquareParams(side: 1200));
    sw.failing.add('reach');
    expect(
        () => c.execute(_Sabotage(SetComponentCommand<SquareParams>(
            s, const SquareParams(side: double.nan, poisoned: true)))),
        throwsA(isA<PartialMutationError>()));
    expect(d.components.get<SquareParams>(s)!.side.isNaN, isTrue,
        reason: 'premise: the partial mutation left a value no JSON holds');
    // M-F7: `save` without its damaged check (Task 8's body alone) throws
    // the encoder's JsonUnsupportedObjectError instead.
    expect(
        c.save,
        throwsA(isA<PlanFormatException>()
            .having((e) => e.code, 'code', PlanFormatCode.damagedUnsavable)));
    expect(diagnosticsOf(c, KitDiagnosticCode.damagedUnsavable), hasLength(1));
  });

  test(
      'F-8 a tool whose factory throws is disabled: one diagnostic, and '
      'selecting it leaves plan.select armed', () {
    final sw = Switches()..failing.add('create');
    // M-F8: the controller calling `PlanTool.create` bare: the constructor
    // throws HookBoom.
    final c = PlanController(kits: [boxKit(sw)]);
    addTearDown(c.dispose);
    expect(c.isToolDisabled('box.stamp'), isTrue);
    expect(c.isToolDisabled('plan.select'), isFalse);
    final failures = diagnosticsOf(c, KitDiagnosticCode.hookFailed);
    expect(
        (failures.single.kitId, failures.single.subject), ('box', 'box.stamp'));
    c.selectTool('box.stamp');
    expect(c.activeTool.value, 'plan.select');
    // A healthy kit's tool arms, wrapped.
    sw.failing.clear();
    c.newPlan();
    expect(c.isToolDisabled('box.stamp'), isFalse,
        reason: 'the factories run again per document');
    c.selectTool('box.stamp');
    expect(c.activeTool.value, 'box.stamp');
    expect(c.toolController.active, isA<GuardedTool>());
  });

  test(
      'F-9 execute answers false for a refused edit (controller ruling R-b): '
      'an ArgumentError and a DanglingReferenceError are caught, nothing '
      'changes, no lock hint', () {
    final sw = Switches();
    final c = PlanController(kits: [boxKit(sw)]);
    addTearDown(c.dispose);
    final d = c.document;
    final s = addObject(d, atSquare, const SquareParams(side: 1200));
    final before = canon(d);
    final depth = d.commands.undoDepth;
    // M-F9a: `execute` without its `on ArgumentError` clause.
    expect(c.execute(_Refusing(ArgumentError('out of range'))), isFalse);
    // M-F9b: `execute` without its `on DanglingReferenceError` clause.
    expect(c.execute(_Refusing(DanglingReferenceError(s, s))), isFalse);
    expect(canon(d), before);
    expect(d.commands.undoDepth, depth);
    expect(c.lockHint.value, isFalse, reason: 'no lock refused it');
  });

  test(
      'F-11 (Task 10 carry) a delete a lock refuses answers false: '
      'deleteSelection and the select tool\'s Delete key set the hint, throw '
      'nothing and change nothing', () {
    final c = PlanController(kits: [boxKit(Switches())]);
    addTearDown(c.dispose);
    final d = c.document;
    final outer = d.handleSeed.next();
    final inner = d.handleSeed.next();
    final leaf = d.handleSeed.next();
    d.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: outer,
          parent: d.rootHandle,
          transform: nearSquare(-2500, 800, 0.3),
          children: const [])),
      AddNodeCommand(GroupNode(
          handle: inner,
          parent: outer,
          transform: Transform2.translation(120.5, -40.25),
          children: const [])),
      AddEntityCommand(
          record: draftRecord(leaf, inner, EntityKind.line,
              layer: ReservedHandles.layerZero),
          payload:
              linePayload(Vector2(-310.5, 45.25), Vector2(820.75, -130.5))),
    ], label: 'Nest'));
    c.lockBroken({inner});
    c.selection.replace([SelectionKey.root(outer)]);
    final before = canon(d);
    // M-F11a: deleteSelection without its `on PlanLocked` clause: the
    // lock's refusal escapes.
    expect(c.deleteSelection(), isFalse);
    expect(c.lockHint.value, isTrue);
    expect(canon(d), before);
    c.lockHint.value = false;
    // M-F11b: the session's map and tool controller holding `select` bare
    // (unguarded): the Delete key's PlanLocked escapes.
    c.toolController.active.onKey(deleteKey, c.toolContext);
    expect(c.lockHint.value, isTrue);
    expect(canon(d), before);
    expect(d.tree[outer], isNotNull);
  });
}

const KeyDownEvent deleteKey = KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.delete,
    logicalKey: LogicalKeyboardKey.delete,
    timeStamp: Duration.zero);

/// A command that refuses: [apply] throws [error] before it touches
/// anything.
final class _Refusing extends DraftCommand {
  _Refusing(this.error);
  final Object error;
  @override
  Capability get capability => Capability.components;
  @override
  String get label => 'Refusing';
  @override
  CommandResult apply(CommandTarget target) => throw error;
}
