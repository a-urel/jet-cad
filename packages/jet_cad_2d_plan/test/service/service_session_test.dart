// Spec 2b S3 "Mode and copy": the service copy in a ServiceSession of its
// own, with its own lock expander over the design's lock set and its own
// failure boundary (its freeze clears the copy's history only, then
// retries once); which members stay on the design and which switch on
// `mode`; execute and the design writes refused in service; the copy's
// lifetime; E3 in the copy (its rollback failing) the copy's alone; the
// design's tool back to plan.select on entering service; a component the
// design keeps raw (E4) kept raw in the copy.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

// box_kit.dart and test_kit.dart both declare `addObject` and `DiscType`;
// box_kit.dart and harness.dart both declare `addLine`: only what is used
// is shown.
import '../support/box_kit.dart'
    show
        Switches,
        SquareParams,
        DiscParams,
        boxKit,
        ringKit,
        addObject,
        atSquare,
        componentsText,
        nearSquare;
import '../support/harness.dart' show controllerFor, pointerAt;
import '../support/recording_exporters.dart';
import '../support/service_plans.dart';
import '../support/test_kit.dart' show testKit, unitKit;

List<KitDiagnostic> failuresOf(PlanController c) => [
      for (final d in c.diagnostics.value)
        if (d.code == KitDiagnosticCode.hookFailed) d
    ];

Transform2 transformOf(DraftDocument d, Handle h) => switch (d.tree[h]) {
      final InstanceNode n => n.transform,
      final GroupNode n => n.transform,
      _ => throw StateError('no node ${h.toHex()}'),
    };

List<KitDiagnostic> rollbacksOf(PlanController c) => [
      for (final d in c.diagnostics.value)
        if (d.code == KitDiagnosticCode.rollbackFailed) d
    ];

// The E3 commands of 2a's failure_flow_test.dart (F-6, F-14, F-14b).

/// Applies [inner], then hands back an inverse that throws: the engine's
/// rollback of a failed edit throws, E3's PartialMutationError.
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

/// Applies [inner]; its undo applies [inner]'s inverse and then throws
/// E3's error.
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

/// [inner] applied, then E3's error.
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
    throw PartialMutationError('forced: the step applied, then failed');
  }
}

/// Applies [inner]; its undo is [inner]'s inverse, whose own inverse (the
/// redo) applies and then throws E3's error.
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

/// A design over the box kit with a square off the origin, turned, and one
/// step in its history, in service: the controller and the square.
({PlanController c, Handle square}) boxInService(Switches sw) {
  final c = controllerFor(kits: [boxKit(sw)]);
  final square =
      addObject(c.document, atSquare, const SquareParams(side: 1200));
  c.setMode(PlanMode.service);
  return (c: c, square: square);
}

void main() {
  testWidgets(
      'SM-members document, selection, index, page, outlines, parametric, '
      'frozen and the kits\' services stay on the design in service; '
      'activeDocument and activeSelection are the copy\'s, runtime, with '
      'the design\'s handles; back in design both are the design\'s',
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    final design = c.document;
    final selection = c.selection;
    final index = c.index;
    final page = c.page;
    final outlines = c.outlines;
    final parametric = c.parametric;
    final frozen = c.frozen;
    expect(c.mode.value, PlanMode.design);
    expect(c.activeDocument, same(design));
    expect(c.activeSelection, same(selection));
    expect(c.serviceSession, isNull);

    c.setMode(PlanMode.service);
    expect(c.mode.value, PlanMode.service);
    final s = c.serviceSession!;
    // M-SM3: `document` reads the active document.
    expect(c.document, same(design));
    expect(c.selection, same(selection));
    expect(c.index, same(index));
    expect(c.page, same(page));
    expect(c.outlines, same(outlines));
    expect(c.parametric, same(parametric));
    expect(c.frozen, same(frozen));
    expect(c.servicesOf('test').document, same(design));
    expect(c.activeDocument, same(s.document));
    expect(c.activeDocument, isNot(same(design)));
    expect(c.activeSelection, same(s.selection));
    expect(c.activeSelection, isNot(same(selection)));
    expect(s.document.commands.permissions, DraftPermissions.runtime);
    for (final label in ['1', '2', '3']) {
      expect(unitNode(s.document, label).handle, unitNode(design, label).handle,
          reason: 'the copy keeps the design\'s handles');
    }
    expect(
        c.unitIndex.units.map((u) => u.instance),
        [
          for (final l in ['1', '2', '3']) unitNode(design, l).handle
        ],
        reason: 'the unit index is the copy\'s, ascending');

    c.setMode(PlanMode.design);
    expect(c.serviceSession, isNull);
    expect(c.activeDocument, same(design));
    expect(c.activeSelection, same(selection));
    await tester.pump();
  });

  testWidgets(
      'SM-lifetime a load and a new plan in service rebuild the copy from '
      'the new design; leaving service drops it; each dropped copy is '
      'disposed after the frame, its systems uninstalled', (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    c.setMode(PlanMode.service);
    final first = c.serviceSession!;
    c.load(servicePlanText(secondAt: Vector2(5000.5, -3700.25)));
    expect(c.mode.value, PlanMode.service);
    final second = c.serviceSession!;
    expect(second, isNot(same(first)));
    expect(parts(unitNode(c.activeDocument, '2').transform),
        parts(unitNode(c.document, '2').transform),
        reason: 'the copy of the new design');
    c.newPlan();
    final third = c.serviceSession!;
    expect(third, isNot(same(second)));
    expect(c.unitIndex.units, isEmpty);
    c.setMode(PlanMode.design);
    expect(c.serviceSession, isNull);
    await tester.pump();
    for (final s in [first, second, third]) {
      // M-SM10: a dropped copy is never disposed.
      expect(() => s.selection.addListener(() {}), throwsFlutterError);
      expect(s.document.commands.isDisposed, isTrue);
      expect(s.document.commands.expander, isNull,
          reason: 'the lock, label and parametric systems, last in first out');
    }
  });

  testWidgets(
      'SM-select the selection is kept by label across a mode switch; '
      'design selects placed units only, service a seat too; '
      'editorSelectedUnits is empty in service', (tester) async {
    final h = hall();
    final c = controllerFor(kits: [unitKit()], json: h.json);
    final seat = h.seats[0][1];
    final seatLabel = labelOf(c.document, seat)!;
    final tableLabel = labelOf(c.document, h.table)!;
    c.select({tableLabel, seatLabel});
    expect(c.activeSelection.keys, {SelectionKey.root(h.table)},
        reason: 'design: placed units only');
    expect(c.selectedUnits.value, {tableLabel});
    expect(c.editorSelectedUnits.value, {tableLabel});

    c.setMode(PlanMode.service);
    // M-SM9: setMode does not select again by label.
    expect(c.activeSelection.keys, {SelectionKey.root(h.table)});
    expect(c.selectedUnits.value, {tableLabel});
    // M-SM8: `_inDesign` does not follow the mode.
    expect(c.editorSelectedUnits.value, isEmpty, reason: 'service');
    c.select({tableLabel, seatLabel, 'nope'});
    expect(c.activeSelection.keys,
        {SelectionKey.root(h.table), SelectionKey.root(seat)});
    expect(c.selectedUnits.value, {tableLabel, seatLabel});
    expect(c.selection.keys, {SelectionKey.root(h.table)},
        reason: 'the design\'s selection is untouched in service');

    c.setMode(PlanMode.design);
    expect(c.selectedUnits.value, {tableLabel},
        reason: 'the seat is not selectable in design');
    expect(c.selection.keys, {SelectionKey.root(h.table)});
    expect(c.editorSelectedUnits.value, {tableLabel});
    await tester.pump();
  });

  testWidgets(
      'SM-undo undo, redo, canUndo and canRedo act on the copy in service '
      'and on the design in design; a service undo never reaches the '
      'design', (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    drawLine(c);
    await tester.pump();
    expect(c.canUndo.value, isTrue, reason: 'premise: a design step');
    c.setMode(PlanMode.service);
    // M-SM12: the flags read the design.
    expect(c.canUndo.value, isFalse, reason: 'the copy has no history');
    final designed = parts(unitNode(c.activeDocument, '1').transform);
    move(c, '1', 333.5, -71.25);
    await tester.pump();
    expect(c.canUndo.value, isTrue);
    // M-SM11: undo acts on the design.
    c.undo();
    expect(parts(unitNode(c.activeDocument, '1').transform), designed);
    await tester.pump();
    expect(c.canUndo.value, isFalse);
    expect(c.canRedo.value, isTrue);
    c.redo();
    expect(parts(unitNode(c.activeDocument, '1').transform), isNot(designed));
    expect(c.document.commands.undoDepth, 1, reason: 'the design untouched');
    expect(c.document.commands.canRedo, isFalse);
    c.setMode(PlanMode.design);
    expect(c.canUndo.value, isTrue);
    expect(c.canRedo.value, isFalse);
    await tester.pump();
  });

  testWidgets(
      'SM-execute-false in service execute answers false and leaves the '
      'design as it was; deleteSelection answers false; the design writes '
      'throw StateError; back in design execute applies', (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    c.select({'1'});
    expect(c.selection.keys, hasLength(1), reason: 'premise');
    c.setMode(PlanMode.service);
    // Made first: making it takes a handle from the design's seed.
    final line = addDrafted(c.document, EntityKind.line,
        linePayload(Vector2(-500.5, 700.25), Vector2(1800.75, 2400.5)),
        layer: ReservedHandles.layerZero);
    final state = c.document.commands.stateId;
    final before = c.save();
    // M-SM1: execute does not check the mode.
    expect(c.execute(line), isFalse);
    expect(c.document.commands.stateId, state);
    expect(c.dirty.value, isFalse);
    // M-SM14: deleteSelection does not check the mode.
    expect(c.deleteSelection(), isFalse);
    expect(c.save(), before, reason: 'table 1 is still in the design');
    // M-SM2: `_requireDesign` lets the write through.
    expect(
        () => c.setUnitData('1', const {'seat': 'window'}), throwsStateError);
    expect(() => c.setUnitColour('1', PlanSwatch.teal), throwsStateError);
    expect(() => c.setUnitLabel('1', '7'), throwsStateError);
    c.setMode(PlanMode.design);
    expect(
        c.execute(addDrafted(c.document, EntityKind.line,
            linePayload(Vector2(-500.5, 700.25), Vector2(1800.75, 2400.5)),
            layer: ReservedHandles.layerZero)),
        isTrue);
    await tester.pump();
  });

  testWidgets(
      'SM-export in service an export is handed the copy as it is; in '
      'design the design', (tester) async {
    final acme = RecordingExporter('acme.json', 'json', 'application/json');
    final c = PlanController(
        kits: [testKit()], json: servicePlanText(), exporters: [acme]);
    addTearDown(c.dispose);
    c.setMode(PlanMode.service);
    move(c, '1', 750.5, -250.25);
    final copy = DraftDocumentCodec.encodeToString(c.activeDocument);
    final design = DraftDocumentCodec.encodeToString(c.document);
    expect(copy, isNot(design), reason: 'premise: a service move');
    await tester
        .runAsync(() => c.export('acme.json', PlanExportChoice.initial));
    // M-SM13: the page flows read the design.
    expect(acme.seen.single, copy);
    c.setMode(PlanMode.design);
    await tester
        .runAsync(() => c.export('acme.json', PlanExportChoice.initial));
    expect(acme.seen.last, design);
  });

  testWidgets(
      'SM-copy-lock the copy refuses a forged command under a locked '
      'object (a table of a missing kit), rolled back, nothing in its '
      'history; an unlocked table moves', (tester) async {
    final c = controllerFor(kits: [testKit()], json: lockedPlanText());
    final gone = unitNode(c.document, '5').handle;
    expect(c.isLocked(gone), isTrue, reason: 'premise: the design locks it');
    c.setMode(PlanMode.service);
    final copy = c.activeDocument;
    final before = DraftDocumentCodec.encodeToString(copy);
    final at = transformOf(copy, gone);
    // M-SM4: the copy's lock expander is not installed.
    expect(
        () => copy.commands.execute(TransformNodeCommand(
            gone, Transform2.translation(410.5, -95.25).multiply(at))),
        throwsA(isA<PlanLocked>()));
    expect(DraftDocumentCodec.encodeToString(copy), before,
        reason: 'rolled back');
    expect(copy.commands.canUndo, isFalse);
    expect(() => move(c, '1', 410.5, -95.25), returnsNormally);
    await tester.pump();
  });

  testWidgets(
      'SM-copy-boundary a kit hook throwing during a service move: the '
      'object frozen and locked in both documents, one diagnostic, the '
      'copy\'s history cleared and the design\'s kept, the move applied by '
      'the retry; a second type throwing on the retry refuses the move',
      (tester) async {
    final sw = Switches();
    final c = controllerFor(kits: [boxKit(sw), ringKit(sw)]);
    final d = c.document;
    final square =
        addObject(d, atSquare, const SquareParams(side: 1200, poisoned: true));
    final table = unitDefinition(d, key: 'box.table.square.four');
    final t = placeDef(
        d, table, turned(table, -2600.25, 1400.5, kDeg37, mirrored: true),
        label: '1');
    await tester.pump();
    expect(c.canUndo.value, isTrue, reason: 'premise: the design has history');

    c.setMode(PlanMode.service);
    final copy = c.activeDocument;
    move(c, '1', 120.5, 0);
    expect(copy.commands.undoDepth, 1, reason: 'premise: a first step');
    sw.failing.add('reach');
    final at = transformOf(copy, t);
    final to = Transform2.translation(750.5, -250.25).multiply(at);
    copy.commands.execute(TransformNodeCommand(t, to));
    expect(parts(transformOf(copy, t)), parts(to), reason: 'the retry');
    // M-SM6: `_lockFromCopy` does not add to the lock set.
    expect(c.locked.value, {square});
    // M-SM7: the copy's system ignores the shared frozen set.
    expect(c.frozen, {square});
    final failures = failuresOf(c);
    expect(failures, hasLength(1));
    expect((failures.single.kitId, failures.single.subject),
        ('box', SquareParams.id));
    // M-SM5: the lock clears the design's history instead of the copy's.
    expect(copy.commands.undoDepth, 1,
        reason: 'the copy\'s history cleared, then the retried move');
    expect(c.document.commands.canUndo, isTrue,
        reason: 'the design\'s history is kept');
    final sq = transformOf(copy, square);
    expect(
        () => copy.commands.execute(TransformNodeCommand(
            square, Transform2.translation(10.5, 0).multiply(sq))),
        throwsA(isA<PlanLocked>()),
        reason: 'locked in the copy');

    c.setMode(PlanMode.design);
    expect(c.canUndo.value, isTrue);
    expect(
        c.execute(TransformNodeCommand(
            square,
            Transform2.translation(10.5, 0)
                .multiply(transformOf(c.document, square)))),
        isFalse,
        reason: 'locked in the design');
    expect(c.lockHint.value, isTrue);

    // A second type's hook throws on the retry: the move is refused.
    final sw2 = Switches();
    final c2 = controllerFor(kits: [boxKit(sw2), ringKit(sw2)]);
    final d2 = c2.document;
    final square2 =
        addObject(d2, atSquare, const SquareParams(side: 1200, poisoned: true));
    final disc = addObject(d2, nearSquare(-3000.5, 2500.25, 0.5),
        const DiscParams(radius: 400, poisoned: true));
    expect(square2.value < disc.value, isTrue,
        reason: 'premise: the square is surveyed first');
    final table2 = unitDefinition(d2, key: 'box.table.square.four');
    final t2 = placeDef(d2, table2, turned(table2, 2300.75, -1700.5, -kDeg37),
        label: '1');
    c2.setMode(PlanMode.service);
    final copy2 = c2.activeDocument;
    final designDepth = c2.document.commands.undoDepth;
    expect(designDepth, greaterThan(0), reason: 'premise: design steps');
    final before = DraftDocumentCodec.encodeToString(copy2);
    sw2.failing.add('reach');
    expect(
        () => copy2.commands.execute(TransformNodeCommand(
            t2,
            Transform2.translation(640.375, 12.5)
                .multiply(transformOf(copy2, t2)))),
        throwsA(isA<KitHookFailure>()));
    expect(DraftDocumentCodec.encodeToString(copy2), before,
        reason: 'refused: nothing applied');
    expect(c2.frozen, {square2},
        reason: 'the first type froze; the second failed on the retry');
    expect(copy2.commands.canUndo, isFalse);
    expect(c2.document.commands.undoDepth, designDepth,
        reason: 'the design\'s history is kept');
    final failures2 = failuresOf(c2);
    expect(failures2, hasLength(1),
        reason: 'the first failure is reported; the retry\'s is rethrown');
    expect((failures2.single.kitId, failures2.single.subject),
        ('box', SquareParams.id));
    await tester.pump();
  });

  testWidgets(
      'SM-copy-damage a rollback that throws in the copy (E3) is the copy\'s '
      'alone, on an edit, an undo and a redo: one rollbackFailed '
      'diagnostic, the copy\'s history cleared, the design neither damaged '
      'nor its history touched', (tester) async {
    // An edit whose rollback throws (2a's F-6 in the copy).
    final sw = Switches();
    final a = boxInService(sw);
    final copy = a.c.activeDocument;
    final depth = a.c.document.commands.undoDepth;
    expect(depth, greaterThan(0), reason: 'premise: a design step');
    final at = transformOf(copy, a.square);
    copy.commands.execute(TransformNodeCommand(
        a.square, Transform2.translation(310.5, -45.25).multiply(at)));
    expect(copy.commands.canUndo, isTrue, reason: 'premise: a service step');
    sw.failing.add('reach');
    expect(
        () => copy.commands.execute(_Sabotage(SetComponentCommand<SquareParams>(
            a.square, const SquareParams(side: 1300, poisoned: true)))),
        throwsA(isA<PartialMutationError>()));
    expect(rollbacksOf(a.c), hasLength(1));
    // M-SM19: `_damageCopy` rebuilds the design instead of the copy.
    expect(copy.commands.canUndo, isFalse, reason: 'the copy rebuilt');
    expect(a.c.canUndo.value, isFalse);
    expect(a.c.document.commands.undoDepth, depth,
        reason: 'the design\'s history is never touched');
    expect(a.c.damaged.value, isFalse, reason: 'the design is not damaged');

    // An undo that half-applies in the copy (2a's F-14 in the copy).
    final b = boxInService(Switches());
    final copyB = b.c.activeDocument;
    final depthB = b.c.document.commands.undoDepth;
    final atB = transformOf(copyB, b.square);
    copyB.commands.execute(_HalfUndone(TransformNodeCommand(
        b.square, Transform2.translation(-220.75, 130.5).multiply(atB))));
    expect(copyB.commands.canUndo, isTrue, reason: 'premise: a service step');
    // M-SM20: undo routes the copy's E3 to the design's boundary.
    expect(b.c.undo, returnsNormally);
    expect(rollbacksOf(b.c), hasLength(1));
    expect(b.c.damaged.value, isFalse);
    expect(b.c.document.commands.undoDepth, depthB);
    expect(copyB.commands.canUndo, isFalse);
    expect(copyB.commands.canRedo, isFalse);
    expect(b.c.canUndo.value, isFalse);

    // A redo that half-applies in the copy (2a's F-14b in the copy).
    final r = boxInService(Switches());
    final copyR = r.c.activeDocument;
    final depthR = r.c.document.commands.undoDepth;
    final atR = transformOf(copyR, r.square);
    copyR.commands.execute(_HalfRedone(TransformNodeCommand(
        r.square, Transform2.translation(95.25, 405.5).multiply(atR))));
    r.c.undo();
    expect(copyR.commands.canRedo, isTrue, reason: 'premise');
    // M-SM21: redo routes the copy's E3 to the design's boundary.
    expect(r.c.redo, returnsNormally);
    expect(rollbacksOf(r.c), hasLength(1));
    expect(r.c.damaged.value, isFalse);
    expect(r.c.document.commands.undoDepth, depthR);
    expect(copyR.commands.canRedo, isFalse);
    expect(r.c.canRedo.value, isFalse);
    await tester.pump();
  });

  testWidgets(
      'SM-tool-reset entering service cancels a design tool part-way through '
      'a shape and arms plan.select', (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    expect(c.selectTool('test.slab'), isTrue);
    final tool = c.toolFor('test.slab')!;
    tool.onPointerDown(pointerAt(Vector2(1250.5, -730.25)), c.toolContext);
    expect(tool.isMidShape, isTrue, reason: 'premise');
    c.setMode(PlanMode.service);
    // M-SM22: setMode does not activate plan.select.
    expect(c.activeTool.value, 'plan.select');
    expect(tool.isMidShape, isFalse, reason: 'the shape cancelled');
    c.setMode(PlanMode.design);
    expect(c.activeTool.value, 'plan.select');
    await tester.pump();
  });

  testWidgets(
      'SM-copy-unreadable a component the design keeps raw (E4) is kept raw '
      'in the copy, written back as read', (tester) async {
    final sw = Switches();
    final a = controllerFor(kits: [boxKit(sw)]);
    final broken = addObject(
        a.document, atSquare, const SquareParams(side: 1200, poisoned: true));
    addObject(a.document, nearSquare(4000.5, -500.25, 0.25),
        const SquareParams(side: 500));
    final json = a.save();
    sw.failing.add('fromJson');
    final c = controllerFor(kits: [boxKit(sw)], json: json);
    final kept = c.document.components.unknownOf(broken);
    expect(kept, isNotEmpty, reason: 'premise: E4 kept it raw');
    // M-SM23: the copy decoded without keepUnreadableComponents.
    expect(() => c.setMode(PlanMode.service), returnsNormally);
    final copy = c.activeDocument;
    expect(copy, isNot(same(c.document)));
    expect(copy.components.unknownOf(broken), kept);
    expect(
        componentsText(
            DraftDocumentCodec.encodeToString(copy), SquareParams.id),
        componentsText(
            DraftDocumentCodec.encodeToString(c.document), SquareParams.id));
    await tester.pump();
  });
}
