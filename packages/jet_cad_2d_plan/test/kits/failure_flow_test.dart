// Spec P4 "The failure boundary", through the controller: a hook that
// fails during an edit is caught at the expander, that type's objects are
// probed (E2), the failing ones frozen and locked, the history cleared,
// and the edit run once more; a second failure refuses it with one
// diagnostic. A load probes once. A component its factory cannot read is
// kept raw, locked and frozen (E4). A rollback that throws damages the
// plan (E3), and saving a damaged plan first reads it back. An edit the
// planner refuses on no hook probes every kit object instead (final
// review, I2).
import 'package:flutter/foundation.dart';
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
      'F-7b (final review) a damaged save that does not read back marks '
      'nothing: markSaved after it keeps the last good save as the save '
      'point, so the plan stays dirty', () async {
    final sw = Switches();
    final c = PlanController(kits: [boxKit(sw)]);
    addTearDown(c.dispose);
    final d = c.document;
    final s = addObject(d, atSquare, const SquareParams(side: 1200));
    c.save();
    c.markSaved();
    expect(
        c.execute(SetComponentCommand<SquareParams>(
            s, const SquareParams(side: 1250.5))),
        isTrue);
    sw.failing.add('reach');
    // The edit writes a layer on a handle no file can hold, and a square
    // whose reach throws; undoing it throws: E3, the plan damaged with
    // both kept. It encodes, but the handle does not read back.
    expect(
        () => c.execute(_Sabotage(CompoundCommand([
              SetComponentCommand<ObjectLayer>(const Handle(-7),
                  const ObjectLayer(ReservedHandles.layerZero)),
              SetComponentCommand<SquareParams>(
                  s, const SquareParams(side: 1300.5, poisoned: true)),
            ], label: 'Both'))),
        throwsA(isA<PartialMutationError>()));
    expect(c.damaged.value, isTrue, reason: 'premise');
    expect(
        c.save,
        throwsA(isA<PlanFormatException>()
            .having((e) => e.code, 'code', PlanFormatCode.damagedUnsavable)));
    c.markSaved();
    await Future<void>.delayed(Duration.zero);
    // M-F7b: `save` marking the state encoded before its read-back: the
    // unsaved damaged plan reads as saved.
    expect(c.dirty.value, isTrue);
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

  test(
      'F-13 (fix round 1) the load\'s dry run fails on no kit hook (an open '
      'region the planner refuses): each kit object is probed, the failing '
      'one frozen and locked with a diagnostic', () {
    final sw = Switches();
    final a = PlanController(kits: [boxKit(sw)]);
    final broken = addObject(
        a.document, atSquare, const SquareParams(side: 1200, poisoned: true));
    final other = addObject(a.document, nearSquare(4000, -500, 0.25),
        const SquareParams(side: 500));
    final json = a.save();
    a.dispose();
    sw.failing.add('openRegion');

    final c = PlanController(kits: [boxKit(sw)], json: json);
    addTearDown(c.dispose);
    // M-F13a: probeLoaded's non-kit catch back to `return`.
    expect(c.locked.value, {broken});
    expect(c.frozen, {broken});
    final failures = diagnosticsOf(c, KitDiagnosticCode.hookFailed);
    expect([for (final f in failures) (f.kitId, f.subject)],
        [('box', SquareParams.id)]);
    expect(
        c.execute(SetComponentCommand<SquareParams>(
            other, const SquareParams(side: 640.5))),
        isTrue);
  });

  test(
      'F-13b (fix round 1) a dry run that throws while no object\'s probe '
      'fails: the load goes on, nothing is locked, and the error reaches '
      'FlutterError.onError', () {
    final sw = Switches();
    final a = PlanController(kits: [boxKit(sw)]);
    addObject(
        a.document, atSquare, const SquareParams(side: 1200, poisoned: true));
    final json = a.save();
    a.dispose();
    // Only the dry run sees the open region: the probe after it does not.
    sw.once.add('openRegion');
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);

    final c = PlanController(kits: [boxKit(sw)], json: json);
    addTearDown(c.dispose);
    expect(c.locked.value, isEmpty);
    // M-F13b: the FlutterError.reportError call dropped.
    expect(reported, hasLength(1));
    expect(reported.single.exception, isArgumentError);
    expect(reported.single.library, 'jet_cad_2d_plan');
  });

  test(
      'F-14 (fix round 1) a partial mutation while undoing: undo returns, '
      'the plan is damaged and rebuilt (history cleared, index rebuilt), '
      'one rollbackFailed diagnostic', () {
    final c = PlanController(kits: [boxKit(Switches())]);
    addTearDown(c.dispose);
    final d = c.document;
    final line = d.handleSeed.next();
    expect(
        c.execute(_HalfUndone(AddEntityCommand(
            record: draftRecord(line, d.rootHandle, EntityKind.line,
                layer: ReservedHandles.layerZero),
            payload: linePayload(
                Vector2(-3100.5, 4200.25), Vector2(-1700.75, 5100.5))))),
        isTrue);
    final box = Aabb2.fromPoints([Vector2(-3200, 4100), Vector2(-1600, 5200)]);
    int indexed() {
      var n = 0;
      c.index.forEachInRect(box, const QueryFilter.all(), (_) => n++);
      return n;
    }

    expect(indexed(), 1, reason: 'premise');
    // M-F14: undo without its `on PartialMutationError` clause: it escapes.
    expect(c.undo, returnsNormally);
    expect(d.entities.slotOf(line), isNull, reason: 'the undo half-applied');
    expect(c.damaged.value, isTrue);
    expect(d.commands.canUndo, isFalse);
    expect(d.commands.canRedo, isFalse);
    expect(indexed(), 0, reason: 'rebuilt from what the plan holds');
    expect(diagnosticsOf(c, KitDiagnosticCode.rollbackFailed), hasLength(1));
  });

  test(
      'F-14b (fix round 1) a partial mutation while redoing: redo returns, '
      'the plan is damaged and the history cleared', () {
    final c = PlanController(kits: [boxKit(Switches())]);
    addTearDown(c.dispose);
    final d = c.document;
    final line = d.handleSeed.next();
    expect(
        c.execute(_HalfRedone(AddEntityCommand(
            record: draftRecord(line, d.rootHandle, EntityKind.line,
                layer: ReservedHandles.layerZero),
            payload: linePayload(
                Vector2(-3100.5, 4200.25), Vector2(-1700.75, 5100.5))))),
        isTrue);
    c.undo();
    expect(d.commands.canRedo, isTrue, reason: 'premise');
    expect(c.damaged.value, isFalse, reason: 'premise');
    // M-F14b: redo without its `on PartialMutationError` clause.
    expect(c.redo, returnsNormally);
    expect(d.entities.slotOf(line), isNotNull, reason: 'the redo applied');
    expect(c.damaged.value, isTrue);
    expect(d.commands.canRedo, isFalse);
    expect(diagnosticsOf(c, KitDiagnosticCode.rollbackFailed), hasLength(1));
  });

  test(
      'F-15 (final review I2) a square whose generate the planner refuses '
      '(no hook throws): its own edit is refused once, with the square '
      'frozen, locked and one diagnostic; its neighbour then edits', () {
    final s = refusedScene();
    final c = s.c;
    final d = c.document;
    final drawn = coordsOf(d, s.broken);
    // M-F15a: the controller not setting `LockExpander.onRefusedEdit`: the
    // edit is refused by the planner, nothing is locked or reported, and
    // the neighbour's edit below is refused as well.
    expect(
        c.execute(TransformNodeCommand(s.broken, nearSquare(100.5, 50.25, 0))),
        isFalse);
    expect(c.lockHint.value, isTrue, reason: 'the retry met the lock');
    expect(c.locked.value, {s.broken});
    expect(c.frozen, {s.broken});
    final failures = diagnosticsOf(c, KitDiagnosticCode.hookFailed);
    expect([for (final f in failures) (f.kitId, f.subject)],
        [('box', SquareParams.id)]);
    final before = coordsOf(d, s.neighbour);
    expect(
        c.execute(SetComponentCommand<SquareParams>(
            s.neighbour, const SquareParams(side: 1010.5))),
        isTrue);
    expect(coordsOf(d, s.neighbour), isNot(before), reason: 'regenerated');
    expect(coordsOf(d, s.broken), drawn,
        reason: 'the broken one keeps its geometry');
    expect(diagnosticsOf(c, KitDiagnosticCode.hookFailed), hasLength(1));
  });

  test(
      'F-15b (final review I2) the neighbour edits first: the edit is not '
      'refused; the refused square is frozen and locked on the way', () {
    final s = refusedScene();
    final c = s.c;
    final d = c.document;
    final before = coordsOf(d, s.neighbour);
    // M-F15a again: the neighbour's edit is refused, nothing locked.
    expect(
        c.execute(SetComponentCommand<SquareParams>(
            s.neighbour, const SquareParams(side: 1010.5))),
        isTrue);
    expect(coordsOf(d, s.neighbour), isNot(before));
    expect(c.locked.value, {s.broken});
    expect(c.lockHint.value, isFalse);
    expect(diagnosticsOf(c, KitDiagnosticCode.hookFailed), hasLength(1));
  });

  test(
      'F-15c (final review I2) the planner refuses the edit\'s own new '
      'value, and no stored object fails its probe: refused, nothing '
      'locked, no diagnostic, the document unchanged', () {
    final s = refusedScene(poisoned: false);
    final c = s.c;
    final d = c.document;
    final before = canon(d);
    final depth = d.commands.undoDepth;
    // M-F15c: `recoverRefused` answering true when nothing froze: the
    // retry fails again and reports a diagnostic for a plain refusal.
    expect(
        c.execute(SetComponentCommand<SquareParams>(
            s.neighbour, const SquareParams(side: 950.5, poisoned: true))),
        isFalse);
    expect(canon(d), before);
    expect(d.commands.undoDepth, depth);
    expect(c.locked.value, isEmpty);
    expect(c.diagnostics.value, isEmpty);
  });

  test(
      'F-15d (final review I2) a stored square the planner refuses, and an '
      'edit whose own new value it refuses too: the stored one is frozen and '
      'locked, the retry fails, and the edit is refused with a diagnostic', () {
    final s = refusedScene();
    final c = s.c;
    final d = c.document;
    final drawn = coordsOf(d, s.neighbour);
    // M-F15d: the controller not setting `LockExpander.onRetryFailed`:
    // the second refusal reports nothing.
    expect(
        c.execute(SetComponentCommand<SquareParams>(
            s.neighbour, const SquareParams(side: 950.5, poisoned: true))),
        isFalse);
    expect(c.locked.value, {s.broken});
    expect(coordsOf(d, s.neighbour), drawn);
    expect([
      for (final f in diagnosticsOf(c, KitDiagnosticCode.hookFailed))
        (f.kitId, f.subject)
    ], [
      ('box', SquareParams.id),
      ('plan', null),
    ]);
  });
}

/// Applies [inner]; its undo works, and the redo after it applies and then
/// throws E3's error.
final class _HalfRedone extends DraftCommand {
  _HalfRedone(this.inner);
  final DraftCommand inner;
  @override
  Capability get capability => inner.capability;
  @override
  Set<Capability> get capabilities => inner.capabilities;
  @override
  String get label => 'Half redone';
  @override
  CommandResult apply(CommandTarget target) {
    final r = inner.apply(target);
    return CommandResult(inverse: _UndoThen(r.inverse), touched: r.touched);
  }
}

/// [inner] applied; its own inverse (the redo) throws after applying.
final class _UndoThen extends DraftCommand {
  _UndoThen(this.inner);
  final DraftCommand inner;
  @override
  Capability get capability => inner.capability;
  @override
  Set<Capability> get capabilities => inner.capabilities;
  @override
  String get label => 'Undo then';
  @override
  CommandResult apply(CommandTarget target) {
    final r = inner.apply(target);
    return CommandResult(inverse: _ThenThrow(r.inverse), touched: r.touched);
  }
}

/// Applies [inner]; its undo applies [inner]'s inverse and then throws
/// E3's error: an undo that leaves the target partially mutated.
final class _HalfUndone extends DraftCommand {
  _HalfUndone(this.inner);
  final DraftCommand inner;
  @override
  Capability get capability => inner.capability;
  @override
  Set<Capability> get capabilities => inner.capabilities;
  @override
  String get label => 'Half undone';
  @override
  CommandResult apply(CommandTarget target) {
    final r = inner.apply(target);
    return CommandResult(inverse: _ThenThrow(r.inverse), touched: r.touched);
  }
}

final class _ThenThrow extends DraftCommand {
  _ThenThrow(this.inner);
  final DraftCommand inner;
  @override
  Capability get capability => inner.capability;
  @override
  Set<Capability> get capabilities => inner.capabilities;
  @override
  String get label => 'Then throw';
  @override
  CommandResult apply(CommandTarget target) {
    inner.apply(target);
    throw PartialMutationError('forced: the undo applied, then failed');
  }
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

/// The final review's I2 scene: a square ([poisoned]: its `generate` adds
/// an open region the planner refuses, and no hook throws) and a healthy
/// square overlapping it, both off the origin and turned.
({PlanController c, Handle broken, Handle neighbour}) refusedScene(
    {bool poisoned = true}) {
  final sw = Switches();
  final c = PlanController(kits: [boxKit(sw)]);
  addTearDown(c.dispose);
  final d = c.document;
  final broken =
      addObject(d, atSquare, SquareParams(side: 1200, poisoned: poisoned));
  final neighbour = addObject(
      d, nearSquare(300.5, 200.25, 0.2), const SquareParams(side: 900));
  sw.failing.add('openRegion');
  return (c: c, broken: broken, neighbour: neighbour);
}
