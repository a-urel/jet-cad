// Spec 2b S3 "Mode and copy": the service copy in a ServiceSession of its
// own, with its own lock expander over the design's lock set and its own
// failure boundary (its freeze clears the copy's history only, then
// retries once); which members stay on the design and which switch on
// `mode`; execute and the design writes refused in service; the copy's
// lifetime.
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
        nearSquare;
import '../support/harness.dart' show controllerFor;
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
    await tester.pump();
  });
}
