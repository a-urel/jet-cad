// Host embedding API spec C-6 (Slice 4 plan, Task 6; S-17, S-18): the
// table inspector slot and `editorSelectedTables`. Through `FloorPlanView`
// on the editor fixture under `editorCamera()`; the inspector's detail is
// checked against the fixture's own forward transform of the box's centre.
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, SelectionKey;
import 'package:jet_cad_floor_plan/editor.dart' show WallParams, liveObjectsOf;
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';

import 'editor_fixture.dart';
import 'editor_tools_test.dart' as t;

typedef Caps = FloorPlanEditorCapabilities;

Finder byKey(String k) => find.byKey(Key(k));

final class InspectorHost {
  InspectorHost(this.c, Caps caps)
      : caps = ValueNotifier(caps),
        label = ValueNotifier('host');

  final FloorPlanController c;
  final ValueNotifier<Caps> caps;

  /// The host's own state, read by its inspector: a change rebuilds the
  /// view (the host's rebuild).
  final ValueNotifier<String> label;

  /// Every detail the builder was called with, in order.
  final List<FloorPlanTableDetail> calls = [];
}

/// The view with a host inspector: a line naming the table and its data,
/// and a field whose submission stores its text as the table's `pos`.
Future<InspectorHost> mountInspector(WidgetTester tester,
    {Caps caps = Caps.full,
    FloorPlanMode mode = FloorPlanMode.design,
    bool inspector = true}) async {
  final c = FloorPlanController(json: editorPlanJson());
  addTearDown(c.dispose);
  c.setMode(mode);
  final h = InspectorHost(c, caps);
  addTearDown(h.caps.dispose);
  addTearDown(h.label.dispose);
  await tester.binding.setSurfaceSize(kEditorSurface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: ListenableBuilder(
              listenable: Listenable.merge([h.caps, h.label]),
              builder: (_, __) {
                final label = h.label.value;
                return FloorPlanView(
                    controller: c,
                    editorCapabilities: h.caps.value,
                    tableInspectorBuilder: !inspector
                        ? null
                        : (context, d) {
                            h.calls.add(d);
                            return Column(
                                key: const Key('host-inspector'),
                                children: [
                                  Text(
                                      '$label ${d.table.number} '
                                      '${d.data['pos'] ?? '-'}',
                                      key: const Key('host-inspector-text')),
                                  TextField(
                                      key: const Key('host-inspector-field'),
                                      onSubmitted: (v) => c.setTableData(
                                          d.table.number!, {'pos': v})),
                                ]);
                          });
              }))));
  await tester.pump();
  await tester.pump();
  c.cameraController.value = editorCamera();
  await tester.pump();
  return h;
}

String inspectorText(WidgetTester tester) =>
    tester.widget<Text>(byKey('host-inspector-text')).data!;

/// Table [n]'s instance in the active plan; ` 7 ` is the later of the two
/// sevens.
Handle tableOf(FloorPlanController c, String? n) {
  final survey = TableSurvey.of(c.activeDocument);
  if (n == null) {
    return survey.tables.singleWhere((t) => t.number == null).instance;
  }
  return survey.withNumber(n)[n == ' 7 ' ? 1 : 0].instance;
}

SelectionKey keyOf(FloorPlanController c, String? n) =>
    SelectionKey.root(tableOf(c, n));

Future<void> selectKeys(
    WidgetTester tester, FloorPlanController c, List<SelectionKey> keys) async {
  c.activeSelection.replace(keys);
  await tester.pump();
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
      expect(c.setTableData('1', const {'pos': 'a1'}), isTrue);
      await tester.pump();
      final wall =
          SelectionKey.root(liveObjectsOf<WallParams>(c.activeDocument).first);
      final cases = <String, List<SelectionKey>>{
        '1 and 2': [keyOf(c, '1'), keyOf(c, '2')],
        '7 and " 7 "': [keyOf(c, '7'), keyOf(c, ' 7 ')],
        // Task 6 review R-1 (a): a number another table shares names no
        // one table; `setTableData` refuses it too.
        '7 alone': [keyOf(c, '7')],
        '" 7 " alone': [keyOf(c, ' 7 ')],
        '1 and a wall': [keyOf(c, '1'), wall],
        'the unnumbered table': [keyOf(c, null)],
        'a wall': [wall],
      };
      for (final MapEntry(key: name, value: keys) in cases.entries) {
        await selectKeys(tester, c, keys);
        expect(c.activeSelection.length, keys.length, reason: name);
        expect(byKey('host-inspector'), findsNothing, reason: name);
      }
      expect(c.selectedTables.value, isEmpty, reason: 'the last: a wall');
      expect(h.calls, isEmpty, reason: 'the builder was never asked');
      // `select` picks both sevens: one number, two tables.
      c.select({'7'});
      await tester.pump();
      expect(c.activeSelection.length, 2);
      expect(c.selectedTables.value, {'7'});
      expect(byKey('host-inspector'), findsNothing);
      expect(h.calls, isEmpty);

      await selectKeys(tester, c, [keyOf(c, '1')]);
      expect(byKey('host-inspector'), findsOneWidget);
      expect(inspectorText(tester), 'host 1 a1');
      final d = h.calls.last;
      expect(d.table.number, '1');
      expect(d.data, const {'pos': 'a1'});
      final centre = t.centreOf(c, '1');
      expect(d.center!.dx, closeTo(centre.x, 1e-6));
      expect(d.center!.dy, closeTo(centre.y, 1e-6));
      expect(d.rotation, closeTo(30 * 3.141592653589793 / 180, 1e-9));
      // Under jet-cad's fields, above the Layers.
      expect(
          tester.getTopLeft(byKey('host-inspector')).dy,
          greaterThanOrEqualTo(
              tester.getBottomLeft(byKey('selection-panel')).dy));
      expect(tester.getBottomLeft(byKey('host-inspector')).dy,
          lessThanOrEqualTo(tester.getTopLeft(byKey('layers-panel')).dy));
      // 2 alone: its own detail, not the first table's.
      await selectKeys(tester, c, [keyOf(c, '2')]);
      expect(inspectorText(tester), 'host 2 -');
      expect(h.calls.last.table.number, '2');
      expect(h.calls.last.center, isNot(d.center));
      // ` 7 ` alone: none (Task 6 review R-1 (a)).
      await selectKeys(tester, c, [keyOf(c, ' 7 ')]);
      expect(byKey('host-inspector'), findsNothing);
      expect(c.setTableData('7', const {'pos': 'x'}), isFalse,
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
        hovers.add(c.activeSelection.hover);
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
        'T6-f selectionPanel: false, 1 selected: no inspector, no call; '
        'shown again with the panel', (tester) async {
      final h = await mountInspector(tester,
          caps: Caps.full.copyWith(selectionPanel: false));
      final c = h.c;
      await selectKeys(tester, c, [keyOf(c, '1')]);
      expect(byKey('table-inspector'), findsNothing);
      expect(byKey('host-inspector'), findsNothing);
      expect(h.calls, isEmpty);
      h.caps.value = Caps.full;
      await tester.pump();
      expect(byKey('host-inspector'), findsOneWidget);
      expect(h.calls.single.table.number, '1');
    });

    testWidgets(
        "the inspector reaches the host's state: its field calls "
        'setTableData and the inspector shows the new data after the '
        "revision; letters typed there are the field's; undo shows the old; "
        'a host rebuild builds it again', (tester) async {
      final h = await mountInspector(tester);
      final c = h.c;
      await selectKeys(tester, c, [keyOf(c, '1')]);
      expect(inspectorText(tester), 'host 1 -');
      final revision = c.revision.value;
      await tester.tap(byKey('host-inspector-field'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.pump();
      expect(c.activeTool.value, FloorPlanTool.select,
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

    testWidgets(
        'none without a builder (no slot); none in the selection mode, the '
        'builder given', (tester) async {
      final none = await mountInspector(tester, inspector: false);
      await selectKeys(tester, none.c, [keyOf(none.c, '1')]);
      expect(byKey('table-inspector'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      final h = await mountInspector(tester, mode: FloorPlanMode.selection);
      final c = h.c;
      c.select({'1'});
      await tester.pump();
      expect(c.selectedTables.value, {'1'});
      expect(byKey('table-inspector'), findsNothing);
      expect(h.calls, isEmpty);
      c.setMode(FloorPlanMode.design);
      await tester.pump();
      await tester.pump();
      expect(c.selectedTables.value, {'1'});
      expect(byKey('host-inspector'), findsOneWidget, reason: 'the design');
    });
  });

  group('editorSelectedTables (S-17)', () {
    testWidgets(
        'T6-e through the barrel: 1 selected → {1}; the selection mode → '
        'empty; back → {1}; notified once per change, never for a change '
        'that keeps the numbers or one in the selection mode', (tester) async {
      final h = await mountInspector(tester, inspector: false);
      final c = h.c;
      final ValueListenable<Set<String>> editor = c.editorSelectedTables;
      var notified = 0;
      void count() => notified++;
      editor.addListener(count);
      addTearDown(() => editor.removeListener(count));
      expect(editor.value, isEmpty);
      c.select({'1'});
      await tester.pump();
      expect(editor.value, {'1'});
      expect(notified, 1);
      final wall =
          SelectionKey.root(liveObjectsOf<WallParams>(c.activeDocument).first);
      await selectKeys(tester, c, [keyOf(c, '1'), wall]);
      expect(editor.value, {'1'});
      expect(notified, 1, reason: 'the numbers kept');
      c.setMode(FloorPlanMode.selection);
      await tester.pump();
      await tester.pump();
      expect(c.selectedTables.value, {'1'});
      expect(editor.value, isEmpty);
      expect(notified, 2);
      c.select({'1', '2'});
      await tester.pump();
      expect(c.selectedTables.value, {'1', '2'});
      expect(editor.value, isEmpty);
      expect(notified, 2, reason: 'the selection mode moves nothing');
      c.setMode(FloorPlanMode.design);
      await tester.pump();
      await tester.pump();
      expect(editor.value, {'1', '2'});
      expect(notified, 3);
      expect(() => editor.value.add('9'), throwsUnsupportedError);
    });
  });
}
