// Slice 4's results, found not fixed: a `FloorPlanView` replaced by another
// of the same controller (a new key, a new parent) threw "the dispatcher
// already has an expander": Flutter mounts the new shell before it disposes
// the old one, and each shell installed the document's parametric and
// table systems of its own. Now both hold one pair ([DocumentSystems]).
// Each mode, on the editor fixture: a single child's key changed, and a
// keyed child swapped inside a `Stack` (the old one deactivated only after
// the new one is built); then two views side by side, which the host guide
// rules out, still a `StateError`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/src/document_systems.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart' show tablesOf;

import 'editor_fixture.dart';

Widget app(Widget body) => MaterialApp(home: Scaffold(body: body));

FloorPlanView viewOf(FloorPlanController c, int key) =>
    FloorPlanView(key: ValueKey(key), controller: c);

FloorPlanController controllerIn(FloorPlanMode mode) {
  final c = FloorPlanController(json: editorPlanJson());
  addTearDown(c.dispose);
  c.setMode(mode);
  return c;
}

/// The table system still acts on [doc] (review R-1): turning table `1`
/// about a point off the origin re-stamps its label, which only the table
/// system does (spec 14a T12); a slot holding the parametric system alone
/// leaves the label as it was. Undone after.
void expectRestamps(DraftDocument doc) {
  final t = tablesOf(doc).firstWhere((t) => t.number == '1');
  final node = doc.tree[t.instance]! as InstanceNode;
  List<double> label() => doc.geometry
      .read(doc.entities.geomIndexAt(doc.entities.slotOf(t.label!)!))
      .scalars
      .toList();
  final before = label();
  doc.commands.execute(CompoundCommand([
    TransformNodeCommand(
        node.handle,
        Transform2.translation(21900, 16100)
            .multiply(Transform2.rotation(0.6457718232379019))
            .multiply(Transform2.translation(-21900, -16100))
            .multiply(node.transform)),
  ], label: 'Rotate'));
  expect(label(), isNot(equals(before)), reason: 'the label was re-stamped');
  doc.commands.undo();
  expect(label(), before, reason: 'undone');
}

void main() {
  for (final mode in FloorPlanMode.values) {
    final shapes = <String, Widget Function(Widget)>{
      'a single child': (v) => v,
      'a keyed child of a Stack': (v) => Stack(children: [v]),
    };
    for (final MapEntry(key: shape, value: wrap) in shapes.entries) {
      testWidgets(
          'VR1 ${mode.name}, $shape: a view replaced by another of the same '
          'controller throws nothing; the new one keeps the same systems; '
          'unmounted, the slot is empty; mounted again, installed afresh',
          (tester) async {
        final c = controllerIn(mode);
        final doc = c.activeDocument;
        await tester.pumpWidget(app(wrap(viewOf(c, 1))));
        await tester.pump();
        final installed = doc.commands.expander;
        expect(installed, isNotNull, reason: 'premise');
        expect(DocumentSystems.holdersOf(doc), 1, reason: 'premise');

        await tester.pumpWidget(app(wrap(viewOf(c, 2))));
        expect(tester.takeException(), isNull);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'the frame after');
        expect(find.byType(FloorPlanView), findsOneWidget);
        expect(DocumentSystems.holdersOf(doc), 1);
        expect(doc.commands.expander, installed,
            reason: 'the same systems, still installed');
        expectRestamps(doc);

        await tester.pumpWidget(app(const SizedBox()));
        expect(DocumentSystems.holdersOf(doc), 0);
        expect(doc.commands.expander, isNull, reason: 'released');

        await tester.pumpWidget(app(wrap(viewOf(c, 3))));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(DocumentSystems.holdersOf(doc), 1);
        expect(doc.commands.expander, isNotNull, reason: 'installed again');
      });
    }

    testWidgets(
        'VR2 ${mode.name}: two views of one controller side by side throw '
        'a StateError at the end of the frame (the host guide\'s one view '
        'at a time); one removed, the other keeps the systems', (tester) async {
      final c = controllerIn(mode);
      final doc = c.activeDocument;
      // One over the other: both mounted, each the window's size.
      await tester
          .pumpWidget(app(Stack(children: [viewOf(c, 1), viewOf(c, 2)])));
      final error = tester.takeException();
      expect(error, isA<StateError>());
      expect('$error', contains('one FloorPlanView at a time'));
      expect(DocumentSystems.holdersOf(doc), 2);

      await tester.pumpWidget(app(Stack(children: [viewOf(c, 1)])));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(DocumentSystems.holdersOf(doc), 1);
      expect(doc.commands.expander, isNotNull);
    });
  }

  testWidgets(
      'VR3 a holder\'s release called twice releases once: the other '
      'holder keeps the systems (review R-5)', (tester) async {
    final c = controllerIn(FloorPlanMode.design);
    final doc = c.activeDocument;
    expect(DocumentSystems.holdersOf(doc), 0, reason: 'premise: no view');
    final a = DocumentSystems.acquire(doc);
    final b = DocumentSystems.acquire(doc);
    a();
    a();
    expect(DocumentSystems.holdersOf(doc), 1);
    expect(doc.commands.expander, isNotNull);
    b();
    expect(DocumentSystems.holdersOf(doc), 0);
    expect(doc.commands.expander, isNull);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
