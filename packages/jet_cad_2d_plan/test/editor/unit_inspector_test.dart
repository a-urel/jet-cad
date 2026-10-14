// Ported from jet_cad_floor_plan/test/host/inspector_test.dart (assertions
// unchanged; 2b Task 10, spec S4 "The unit inspector"): the unit inspector
// slot and `editorSelectedUnits`. Through `PlanEditor` on the editor fixture
// under `editorCamera()`; the inspector's detail is checked against the
// fixture's own forward transform of the box's centre. "None without a
// builder ...; none in the selection mode" and T6-e need the mode (Task 16
// ports them whole).
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, SelectionKey;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/unit_editor_fixture.dart' as t;
import '../support/unit_editor_fixture.dart'
    show editorCamera, editorNorthWall, editorTextAt, kEditorSurface;
import '../support/unit_fixtures.dart' show fxKit;

Finder byKey(String k) => find.byKey(Key(k));

final class InspectorHost {
  InspectorHost(this.c, bool panel)
      : panel = ValueNotifier(panel),
        label = ValueNotifier('host');

  final PlanController c;
  final ValueNotifier<bool> panel;

  /// The host's own state, read by its inspector: a change rebuilds the
  /// editor (the host's rebuild).
  final ValueNotifier<String> label;

  /// Every detail the builder was called with, in order.
  final List<PlanUnitDetail> calls = [];
}

/// The editor with a host inspector: a line naming the unit and its data,
/// and a field whose submission stores its text as the unit's `pos`.
Future<InspectorHost> mountInspector(WidgetTester tester,
    {bool panel = true, bool inspector = true}) async {
  final c = PlanController(kits: [fxKit()], json: t.unitEditorPlanJson());
  addTearDown(c.dispose);
  final h = InspectorHost(c, panel);
  addTearDown(h.panel.dispose);
  addTearDown(h.label.dispose);
  await tester.binding.setSurfaceSize(kEditorSurface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: ListenableBuilder(
              listenable: Listenable.merge([h.panel, h.label]),
              builder: (_, __) {
                final label = h.label.value;
                return PlanEditor(
                    controller: c,
                    propertyPanel: h.panel.value,
                    unitInspectorBuilder: !inspector
                        ? null
                        : (context, d) {
                            h.calls.add(d);
                            return Column(
                                key: const Key('host-inspector'),
                                children: [
                                  Text(
                                      '$label ${d.unit.label} '
                                      '${d.data['pos'] ?? '-'}',
                                      key: const Key('host-inspector-text')),
                                  TextField(
                                      key: const Key('host-inspector-field'),
                                      onSubmitted: (v) => c.setUnitData(
                                          d.unit.label!, {'pos': v})),
                                ]);
                          });
              }))));
  await tester.pump();
  await tester.pump();
  c.camera.value = editorCamera();
  await tester.pump();
  return h;
}

String inspectorText(WidgetTester tester) =>
    tester.widget<Text>(byKey('host-inspector-text')).data!;

SelectionKey keyOf(PlanController c, String? n) =>
    SelectionKey.root(t.tableOf(c, n));

Future<void> selectKeys(
    WidgetTester tester, PlanController c, List<SelectionKey> keys) async {
  c.selection.replace(keys);
  await tester.pump();
}

/// The north wall's stand-in: the root line between [editorNorthWall]'s
/// points.
Handle northWall(PlanController c) {
  final d = c.document;
  final (a, b) = editorNorthWall;
  for (final slot in d.entities.liveSlots) {
    if (d.entities.kindAt(slot) != EntityKind.line ||
        d.entities.ownerAt(slot) != d.rootHandle) {
      continue;
    }
    final coords = d.geometry.read(d.entities.geomIndexAt(slot)).coords;
    if (coords[0] == a.x &&
        coords[1] == a.y &&
        coords[2] == b.x &&
        coords[3] == b.y) {
      return d.entities.handleAt(slot);
    }
  }
  throw StateError('no north wall');
}

void main() {
  group('the inspector (S-18)', () {
    testWidgets(
        'M-H45 none for 1 and 2, for 7 and " 7 " (one number), for 7 or '
        '" 7 " alone (a number two tables share), for 1 and a wall, for the '
        "unnumbered table alone; 1 alone shows the host's widget with 1's "
        'detail under the Selection panel, 2 alone with 2\'s', (tester) async {
      final h = await mountInspector(tester);
      final c = h.c;
      expect(c.setUnitData('1', const {'pos': 'a1'}), isTrue);
      await tester.pump();
      final wall = SelectionKey.root(northWall(c));
      final cases = <String, List<SelectionKey>>{
        '1 and 2': [keyOf(c, '1'), keyOf(c, '2')],
        '7 and " 7 "': [keyOf(c, '7'), keyOf(c, ' 7 ')],
        // Task 6 review R-1 (a): a number another table shares names no
        // one table; `setUnitData` refuses it too.
        '7 alone': [keyOf(c, '7')],
        '" 7 " alone': [keyOf(c, ' 7 ')],
        '1 and a wall': [keyOf(c, '1'), wall],
        'the unnumbered table': [keyOf(c, null)],
        'a wall': [wall],
      };
      for (final MapEntry(key: name, value: keys) in cases.entries) {
        await selectKeys(tester, c, keys);
        expect(c.selection.length, keys.length, reason: name);
        expect(byKey('host-inspector'), findsNothing, reason: name);
      }
      expect(c.editorSelectedUnits.value, isEmpty, reason: 'the last: a wall');
      expect(h.calls, isEmpty, reason: 'the builder was never asked');
      // `select` picks both sevens: one number, two tables.
      c.select({'7'});
      await tester.pump();
      expect(c.selection.length, 2);
      expect(c.editorSelectedUnits.value, {'7'});
      expect(byKey('host-inspector'), findsNothing);
      expect(h.calls, isEmpty);

      await selectKeys(tester, c, [keyOf(c, '1')]);
      expect(byKey('host-inspector'), findsOneWidget);
      expect(inspectorText(tester), 'host 1 a1');
      final d = h.calls.last;
      expect(d.unit.label, '1');
      expect(d.data, const {'pos': 'a1'});
      final centre = t.centreOf(c, '1');
      expect(d.center!.dx, closeTo(centre.x, 1e-6));
      expect(d.center!.dy, closeTo(centre.y, 1e-6));
      expect(d.rotation, closeTo(30 * 3.141592653589793 / 180, 1e-9));
      // Under jet-cad's fields, above the Layers.
      expect(
          tester.getTopLeft(byKey('host-inspector')).dy,
          greaterThanOrEqualTo(
              tester.getBottomLeft(byKey('property-panel')).dy));
      expect(tester.getBottomLeft(byKey('host-inspector')).dy,
          lessThanOrEqualTo(tester.getTopLeft(find.byType(PlanLayerPanel)).dy));
      // 2 alone: its own detail, not the first table's.
      await selectKeys(tester, c, [keyOf(c, '2')]);
      expect(inspectorText(tester), 'host 2 -');
      expect(h.calls.last.unit.label, '2');
      expect(h.calls.last.center, isNot(d.center));
      // ` 7 ` alone: none (Task 6 review R-1 (a)).
      await selectKeys(tester, c, [keyOf(c, ' 7 ')]);
      expect(byKey('host-inspector'), findsNothing);
      expect(c.setUnitData('7', const {'pos': 'x'}), isFalse,
          reason: 'the link the inspector would offer is refused');
    });

    testWidgets(
        'T6-d a counting builder: no call across 50 pans and zooms (the '
        "controller's and the user's wheel) nor across hovers; one per "
        'selection change', (tester) async {
      final h = await mountInspector(tester);
      final c = h.c;
      await selectKeys(tester, c, [keyOf(c, '1')]);
      expect(h.calls.length, 1);
      final canvas = tester.getCenter(find.byType(InteractionLayer));
      final mouse =
          await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
      await mouse.addPointer(location: canvas);
      for (var i = 0; i < 50; i++) {
        switch (i % 3) {
          case 0:
            c.panBy(Offset(i.isEven ? 7 : -5, 3));
          case 1:
            c.zoomBy(i.isEven ? 1.05 : 0.96);
          case 2:
            await tester.sendEventToBinding(PointerScrollEvent(
                position: canvas, scrollDelta: Offset(0, i.isEven ? 20 : -20)));
        }
        await tester.pump();
      }
      expect(h.calls.length, 1, reason: 'the camera builds nothing');
      // Hovers over 2, 1 and the TEXT: the selection's hover moves.
      final hovers = <SelectionKey?>{};
      for (final w in [t.centreOf(c, '2'), t.centreOf(c, '1'), editorTextAt]) {
        await mouse.moveTo(t.screenOf(tester, c, w));
        await tester.pump();
        hovers.add(c.selection.hover);
      }
      expect(hovers.length, 3, reason: 'three hovers: $hovers');
      expect(h.calls.length, 1, reason: 'a hover builds nothing');
      await selectKeys(tester, c, [keyOf(c, '2')]);
      expect(h.calls.length, 2);
      await selectKeys(tester, c, [keyOf(c, '2')]);
      expect(h.calls.length, 2, reason: 'the same table');
      await selectKeys(tester, c, [keyOf(c, '1')]);
      expect(h.calls.length, 3);
      await selectKeys(tester, c, [keyOf(c, '1'), keyOf(c, '2')]);
      expect(h.calls.length, 3, reason: 'none shown');
      await mouse.removePointer();
    });

    testWidgets(
        'T6-f propertyPanel: false, 1 selected: no inspector, no call; '
        'shown again with the panel', (tester) async {
      final h = await mountInspector(tester, panel: false);
      final c = h.c;
      await selectKeys(tester, c, [keyOf(c, '1')]);
      expect(byKey('unit-inspector'), findsNothing);
      expect(byKey('host-inspector'), findsNothing);
      expect(h.calls, isEmpty);
      h.panel.value = true;
      await tester.pump();
      expect(byKey('host-inspector'), findsOneWidget);
      expect(h.calls.single.unit.label, '1');
    });

    testWidgets(
        "the inspector reaches the host's state: its field calls "
        'setUnitData and the inspector shows the new data after the '
        "revision; letters typed there are the field's; undo shows the old; "
        'a host rebuild builds it again', (tester) async {
      final h = await mountInspector(tester);
      final c = h.c;
      await selectKeys(tester, c, [keyOf(c, '1')]);
      expect(inspectorText(tester), 'host 1 -');
      final revision = c.revision.value;
      await tester.tap(byKey('host-inspector-field'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pump();
      expect(c.activeTool.value, 'plan.select',
          reason: 'a letter in the field is no tool letter');
      await tester.enterText(byKey('host-inspector-field'), 'b7');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(c.revision.value, greaterThan(revision));
      expect(inspectorText(tester), 'host 1 b7');
      expect(h.calls.last.data, const {'pos': 'b7'});
      c.undo();
      await tester.pump();
      expect(inspectorText(tester), 'host 1 -');
      h.label.value = 'pos';
      await tester.pump();
      expect(inspectorText(tester), 'pos 1 -', reason: 'the host rebuilt');
    });

    testWidgets('none without a builder (no slot)', (tester) async {
      final none = await mountInspector(tester, inspector: false);
      await selectKeys(tester, none.c, [keyOf(none.c, '1')]);
      expect(byKey('unit-inspector'), findsNothing);
    });
  });
}
