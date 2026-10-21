// Task 8 (D7): design mode on a 375 x 812 phone, by touch alone. Draw a 4 m
// wall, place a table from the symbols, select it, turn it, and use the
// host's widget (a DropdownButton) to write the table's data.
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart' hide Tolerance;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_kit_restaurant/jet_cad_2d_kit_restaurant.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/canvas_rig.dart';

Finder k(String key) => find.byKey(Key(key));

int _pointer = 100;

/// A finger's tap at [at]: down, held past the touch hold-back, up.
Future<void> finger(WidgetTester tester, Offset at,
    {Duration after = const Duration(milliseconds: 300)}) async {
  final g = await tester.startGesture(at,
      pointer: _pointer++, kind: PointerDeviceKind.touch);
  await tester.pump(const Duration(milliseconds: 150));
  await g.up();
  await tester.pump(after);
}

const _quick = Duration(milliseconds: 80);

/// A tap on the widget [f] by a finger.
Future<void> touch(WidgetTester tester, Finder f) async {
  expect(f, findsOneWidget);
  await finger(tester, tester.getCenter(f));
}

void main() {
  testWidgets(
      'PH1 a wall, a table from the symbols, its rotation and its host data, '
      'by touch on a 375 x 812 phone', (tester) async {
    final c = PlanController(kits: [architectureKit, restaurantKit]);
    addTearDown(c.dispose);
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: planLocalizationsDelegates,
      supportedLocales: planSupportedLocales,
      home: PlanEditor(
        controller: c,
        objectInspectorBuilder: (context, d) => DropdownButton<String>(
          key: const Key('host-table'),
          value: d.data['id'],
          hint: const Text('table'),
          items: const [
            DropdownMenuItem(value: 't1', child: Text('t1')),
            DropdownMenuItem(value: 't2', child: Text('t2')),
          ],
          onChanged: (v) => c.setObjectData(d.ref, {'id': v!}),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
    expect(k('chrome-left'), findsNothing, reason: 'premise: phone layout');
    expect(await symbolsReady(tester, c), isTrue);

    // Frame the origin at 0.05 px/mm (4 m = 200 px), y up.
    await frameOn(tester, c, Vector2(2000, 1500), scale: 0.05);
    final doc = c.document;

    // The wall: left drawer, Wall, two taps 4 m apart (the pick closes the drawer).
    await touch(tester, k('chrome-left-button'));
    await touch(tester, k('tool-architecture.wall'));
    expect(c.activeTool.value, 'architecture.wall');
    expect(k('chrome-left-drawer').hitTestable(), findsNothing);
    final a = Vector2(0, 1000), b = Vector2(4000, 1000);
    await finger(tester, globalAt(tester, c, a));
    // The second point is a double tap: its first tap is the wall's end, its
    // second ends the chain (the phone has no Enter key).
    await finger(tester, globalAt(tester, c, b), after: _quick);
    await finger(tester, globalAt(tester, c, b));
    expect(activeTool(tester).isMidShape, isFalse,
        reason: 'the double tap ended the chain');
    final wall = doc.components.withComponent<WallParams>().single;
    final p = doc.components.get<WallParams>(wall)!;
    const tol = Tolerance(linear: 1e-6, angular: 1e-9);
    expect(
        tol.eq(Vector2(p.end.x - p.start.x, p.end.y - p.start.y).length, 4000),
        isTrue,
        reason: 'the wall is 4 m: ${p.start} to ${p.end}');

    // The table: left drawer, Symbols tab, the cell (the pick closes the drawer), tap the canvas.
    await touch(tester, k('chrome-left-button'));
    await touch(tester, k('tab-symbols'));
    await tester.enterText(k('symbol-search'), 'rectangular table');
    await tester.pump();
    final cell = k('symbol-cell-restaurant.table.rect.four@1');
    await touch(tester, cell);
    expect(c.activeTool.value, PlanToolIds.symbol);
    expect(k('chrome-left-drawer').hitTestable(), findsNothing);
    final at = Vector2(2000, 2500);
    await finger(tester, globalAt(tester, c, at));
    final units = doc.tree.nodes.whereType<InstanceNode>().toList();
    expect(units, hasLength(1), reason: 'one table placed');
    final table = units.single;

    // Select it: the Select tool from the drawer, a tap on the table.
    await touch(tester, k('chrome-left-button'));
    await touch(tester, k('tab-tools'));
    await touch(tester, k('tool-plan.select'));
    final centre = table.transform.transformPoint(Vector2.zero());
    await finger(tester, globalAt(tester, c, centre));
    expect(c.activeSelection.keys, hasLength(1));

    // Rotation and the host's widget, in the right drawer.
    await touch(tester, k('chrome-right-button'));
    await tester.enterText(k('symbol-rotation'), '30');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    final turned = doc.tree[table.handle]! as InstanceNode;
    final t = turned.transform;
    expect(math.atan2(t.b, t.a) * 180 / math.pi, closeTo(30, 1e-6),
        reason: 'turned to 30 degrees by the panel field');
    expect(Vector2(t.e, t.f).distanceTo(at), lessThan(1500),
        reason: 'placed where the finger tapped, not at the origin');
    expect(Vector2(t.e, t.f).distanceTo(Vector2.zero()), greaterThan(1000));
    await touch(tester, k('host-table'));
    await touch(tester, find.text('t1').last);
    final detail = c.objectDetails.single;
    expect(detail.data, {'id': 't1'});
    expect(detail.kind, PlanObjectKind.unit);
    expect(detail.symbolKey, 'restaurant.table.rect.four');
  });
}
