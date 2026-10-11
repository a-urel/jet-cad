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
import 'package:jet_cad_floor_plan/src/document_systems.dart';

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
}
