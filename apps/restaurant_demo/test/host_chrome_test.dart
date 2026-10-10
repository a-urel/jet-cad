// Host embedding API spec C-1 to C-8 in the demo (Slice 4): the editor's
// three profiles (Full, Tables, Read only) with the demo's table inspector
// under Tables; the demo's own service bar, built from the controller's
// commands and state, in place of the planner's (whose bar otherwise
// carries the area's name); the demo's own export dialog at every Export;
// a failed export or print logged; a table search in the app bar; and the
// plan's keys and focus given to the demo. On the Salon sample, whose
// fitted camera is neither the identity nor at the origin. Screen points
// come from the public `tableDetails` and `worldToGlobal`; expected exports
// from the public `exportPlan`, never from the demo's code.
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart';
import 'package:restaurant_demo/main.dart';

Finder byKey(String k) => find.byKey(Key(k));

/// A printer that fails, as a jammed one would. Its page format is typed
/// `Object`, a supertype of the interface's, so the test needs no `pdf`.
final class JammedPrinter implements PagePrinter {
  int calls = 0;

  @override
  Future<void> print(Uint8List pdf, String name, Object format) async {
    calls++;
    throw StateError('jam');
  }
}

/// The demo on its sample plans, at 1600 x 1000, in the Salon's design.
Future<DemoHomeState> pumpSamples(WidgetTester tester,
    {Locale? locale, PagePrinter? printer}) async {
  final plans = (await tester.runAsync(() => loadSamplePlans(rootBundle)))!;
  await tester.binding.setSurfaceSize(const Size(1600, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
      RestaurantDemo(plans: plans, locale: locale, printer: printer));
  await tester.pump();
  await tester.pump();
  return tester.state<DemoHomeState>(find.byType(DemoHome));
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Future<void> press(WidgetTester tester, String key) async {
  await tester.tap(byKey(key));
  await settle(tester);
}

/// Scrolls the side panel until [key] is in view, then taps it.
Future<void> pressInPanel(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(byKey(key), 100,
      scrollable: find
          .descendant(
              of: byKey('side-panel'), matching: find.byType(Scrollable))
          .first);
  await tester.pump();
  await press(tester, key);
}

/// The detail of the one table numbered [n] in [c]'s current mode.
FloorPlanTableDetail detailOf(FloorPlanController c, String n) =>
    c.tableDetails.singleWhere((d) => d.table.number == n);

/// Table [n]'s centre on the screen, through the public API.
Offset centreOf(FloorPlanController c, String n) =>
    c.worldToGlobal(detailOf(c, n).center!)!;

Future<void> click(WidgetTester tester, Offset at) async {
  await tester.tapAt(at, kind: PointerDeviceKind.mouse);
  await settle(tester);
}

/// A mouse drag from [from] by [by], in four moves.
Future<void> drag(WidgetTester tester, Offset from, Offset by) async {
  final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await g.down(from);
  for (var i = 1; i <= 4; i++) {
    await g.moveTo(from + by * (i / 4));
    await tester.pump();
  }
  await g.up();
  await g.removePointer();
  await settle(tester);
}

Future<void> chord(WidgetTester tester, LogicalKeyboardKey key,
    {bool control = false, bool shift = false}) async {
  if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await settle(tester);
}

/// Pumps, letting the real clock run, until [done] or about 8 s.
Future<void> waitFor(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 400 && !done(); i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

/// A PNG's width and height, from its header.
(int, int) pngSize(Uint8List png) {
  final b = ByteData.sublistView(png);
  return (b.getUint32(16), b.getUint32(20));
}

/// Whether the primary focus is inside the plan's view.
bool planFocused() =>
    FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<FloorPlanView>() !=
    null;

/// Whether the app bar's search field has the primary focus.
bool searchFocused(WidgetTester tester) => tester
    .widget<EditableText>(find.descendant(
        of: byKey('find-table'), matching: find.byType(EditableText)))
    .focusNode
    .hasPrimaryFocus;

void main() {
  testWidgets(
      'DH1 Tables: no wall tool, no Layer or Page panel, the Symbols tab; '
      'the inspector shows for one table and writes its POS id, its other '
      'data kept; Full shows no inspector', (tester) async {
    final demo = await pumpSamples(tester);
    final c = demo.area.controller;
    expect(c.setTableData('2', {'seats_note': 'window'}), isTrue);
    // Full (the default): today's editor, no inspector.
    expect(byKey('tool-wall'), findsOneWidget);
    expect(byKey('layers-panel'), findsOneWidget);
    await click(tester, centreOf(c, '2'));
    expect(c.selectedTables.value, {'2'}, reason: 'premise: selected');
    expect(byKey('pos-id'), findsNothing);

    await pressInPanel(tester, 'editor-tables');
    expect(demo.editor, DemoEditor.tables);
    expect(byKey('tool-wall'), findsNothing);
    expect(byKey('tool-select'), findsOneWidget);
    expect(byKey('tab-symbols'), findsOneWidget);
    expect(byKey('layers-panel'), findsNothing);
    expect(byKey('page-preset'), findsNothing);
    await click(tester, centreOf(c, '2'));
    expect(c.selectedTables.value, {'2'});
    expect(byKey('pos-id'), findsOneWidget);
    await tester.enterText(byKey('pos-id'), ' salon-2 ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(detailOf(c, '2').data, {'seats_note': 'window', 'id': 'salon-2'});
    expect(demo.log.first, 'Salon: table 2 is salon-2');
    // Another table: its own field, empty; emptied, a table is unlinked.
    await click(tester, centreOf(c, '3'));
    expect(tester.widget<TextField>(byKey('pos-id')).controller!.text, '');
    await click(tester, centreOf(c, '2'));
    expect(
        tester.widget<TextField>(byKey('pos-id')).controller!.text, 'salon-2');
    await tester.enterText(byKey('pos-id'), '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(detailOf(c, '2').data, {'seats_note': 'window'});
    expect(demo.log.first, 'Salon: table 2 unlinked');
  });

  testWidgets(
      'DH2 Read only moves and deletes nothing; its bar shows Print, Export '
      'and the zoom; under Full the same drag moves the table', (tester) async {
    final demo = await pumpSamples(tester);
    final c = demo.area.controller;
    final before = detailOf(c, '4').center!;
    // Full: the drag moves table 4; undone by the host.
    await click(tester, centreOf(c, '4'));
    await drag(tester, centreOf(c, '4'), const Offset(80, 40));
    expect(detailOf(c, '4').center, isNot(before), reason: 'control');
    c.undo();
    await settle(tester);
    expect(detailOf(c, '4').center, before);

    await pressInPanel(tester, 'editor-read-only');
    expect(byKey('toolbar-undo'), findsNothing);
    expect(byKey('osnap-text'), findsNothing);
    expect(byKey('zoom-text'), findsOneWidget);
    expect(tester.getTopLeft(byKey('toolbar-print')).dx,
        lessThan(tester.getTopLeft(byKey('toolbar-export')).dx));
    await click(tester, centreOf(c, '4'));
    expect(c.selectedTables.value, {'4'}, reason: 'a selection is no edit');
    final json = c.designJson();
    await drag(tester, centreOf(c, '4'), const Offset(80, 40));
    await chord(tester, LogicalKeyboardKey.delete);
    await chord(tester, LogicalKeyboardKey.keyW);
    expect(c.designJson(), json);
    expect(detailOf(c, '4').center, before);
    expect(c.canUndo.value, isFalse);
    expect(c.deleteSelection(), isFalse);
    expect(c.activeTool.value, FloorPlanTool.select);
  });

  testWidgets(
      "DH3 the service bar carries the area's name; Own bar hides it, and "
      "the demo's Merge, Split, Undo and Redo send what the planner's would",
      (tester) async {
    final demo = await pumpSamples(tester);
    final c = demo.area.controller;
    await press(tester, 'mode-service');
    expect(byKey('service-bar'), findsOneWidget);
    expect(
        find.descendant(of: byKey('service-bar'), matching: byKey('bar-area')),
        findsOneWidget);
    expect(tester.widget<Text>(byKey('bar-area')).data, 'Salon');
    // The planner's Merge, as a reference.
    c.select({'1', '2'});
    await settle(tester);
    await press(tester, 'service-merge');
    final merged = c.tableGroups.value;
    final mergedLog = demo.log.first;
    expect(merged.keys, ['G1'], reason: 'premise');
    c.setTableGroups(const {});
    await settle(tester);

    await pressInPanel(tester, 'own-bar');
    expect(byKey('service-bar'), findsNothing);
    expect(byKey('own-bar-row'), findsOneWidget);
    expect(tester.getRect(byKey('own-bar-row')).bottom, c.canvasRect.value!.top,
        reason: 'the canvas starts under the own bar');
    TextButton button(String key) => tester.widget<TextButton>(byKey(key));
    c.select({'1'});
    await settle(tester);
    expect(button('own-merge').onPressed, isNull, reason: 'one table');
    c.select({'1', '2'});
    await settle(tester);
    await press(tester, 'own-merge');
    expect(c.tableGroups.value, merged);
    expect(demo.log.first, mergedLog);
    // Split: the group, selected through a member.
    c.select({'3'});
    await settle(tester);
    expect(button('own-split').onPressed, isNull, reason: 'no group');
    c.select({'1'});
    await settle(tester);
    expect(c.selectedGroup.value, 'G1');
    await press(tester, 'own-split');
    expect(c.tableGroups.value, isEmpty);
    expect(demo.log.first, 'Salon: Split G1');
    // Undo and Redo of a service move.
    expect(button('own-undo').onPressed, isNull);
    final before = detailOf(c, '3').center!;
    await drag(tester, centreOf(c, '3'), const Offset(60, 30));
    final after = detailOf(c, '3').center!;
    expect(after, isNot(before), reason: 'premise: moved');
    await press(tester, 'own-undo');
    expect(detailOf(c, '3').center, before);
    await press(tester, 'own-redo');
    expect(detailOf(c, '3').center, after);

    // Off again: the planner's bar, its Merge the same.
    await pressInPanel(tester, 'own-bar');
    expect(byKey('own-bar-row'), findsNothing);
    expect(byKey('service-merge'), findsOneWidget);
  });

  testWidgets(
      "DH4 the own export dialog replaces the planner's at its Export and "
      'its chord, in both modes: a PNG at 300 dpi is what exportPlan makes, '
      'remembered as the next initial; Cancel exports nothing; the own '
      "bar's Export asks it too", (tester) async {
    final demo = await pumpSamples(tester);
    final c = demo.area.controller;
    await pressInPanel(tester, 'own-export-dialog');
    await press(tester, 'toolbar-export');
    expect(byKey('export-dialog'), findsNothing);
    expect(byKey('demo-export-dialog'), findsOneWidget);
    Finder checkIn(String key) =>
        find.descendant(of: byKey(key), matching: find.byIcon(Icons.check));
    expect(checkIn('demo-export-pdf'), findsOneWidget, reason: 'PDF, 150');
    await press(tester, 'demo-export-png-300');
    await waitFor(tester, () => demo.lastExport != null);
    final export = demo.lastExport!;
    expect(export.fileName, 'salon.png');
    expect(export.mimeType, 'image/png');
    expect(
        demo.log.first,
        'Salon: exported salon.png, '
        '${export.bytes.length} bytes');
    final expected = (await tester.runAsync(() => c.exportPlan(
        const FloorPlanExportChoice(
            format: FloorPlanExportFormat.png, dpi: FloorPlanExportDpi.d300),
        name: 'salon')))!;
    expect(export.bytes, expected.bytes);
    final at96 = (await tester.runAsync(() => c.exportPlan(
        const FloorPlanExportChoice(
            format: FloorPlanExportFormat.png, dpi: FloorPlanExportDpi.d96))))!;
    final (w300, h300) = pngSize(export.bytes);
    final (w96, h96) = pngSize(at96.bytes);
    expect(w300, closeTo(w96 * 300 / 96, 2));
    expect(h300, closeTo(h96 * 300 / 96, 2));

    // The selection mode's chord: the demo's dialog, PNG 300 remembered.
    await press(tester, 'mode-service');
    await click(tester, c.worldToGlobal(const Offset(-3210, 810))!);
    await chord(tester, LogicalKeyboardKey.keyE, control: true);
    expect(byKey('export-dialog'), findsNothing);
    expect(byKey('demo-export-dialog'), findsOneWidget);
    expect(checkIn('demo-export-png-300'), findsOneWidget);
    await press(tester, 'demo-export-cancel');
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await settle(tester);
    expect(identical(demo.lastExport, export), isTrue);

    // The own bar's Export: the same dialog, then exportPlan.
    await pressInPanel(tester, 'own-bar');
    await press(tester, 'own-export');
    expect(byKey('demo-export-dialog'), findsOneWidget);
    await press(tester, 'demo-export-png-96');
    await waitFor(tester, () => !identical(demo.lastExport, export));
    expect(demo.lastExport!.fileName, 'salon.png');
    expect(pngSize(demo.lastExport!.bytes), (w96, h96));

    // Off: the planner's own dialog again.
    await pressInPanel(tester, 'own-export-dialog');
    await chord(tester, LogicalKeyboardKey.keyE, control: true);
    expect(byKey('export-dialog'), findsOneWidget);
    expect(byKey('demo-export-dialog'), findsNothing);
  });

  testWidgets(
      "DH5 a print that fails is logged, from the planner's Print and from "
      "the own bar's", (tester) async {
    final printer = JammedPrinter();
    final demo = await pumpSamples(tester, printer: printer);
    await press(tester, 'toolbar-print');
    await waitFor(
        tester, () => demo.log.isNotEmpty && demo.log.first.contains('failed'));
    expect(printer.calls, 1);
    expect(demo.log.first, 'Salon: export or print failed (Bad state: jam)');
    expect(tester.takeException(), isNull);

    await press(tester, 'mode-service');
    await pressInPanel(tester, 'own-bar');
    final lines = demo.log.length;
    await press(tester, 'own-print');
    await waitFor(tester, () => printer.calls == 2 && demo.log.length > lines);
    expect(demo.log.first, 'Salon: export or print failed (Bad state: jam)');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      "DH6 the plan's keys off: Delete, Ctrl+Z, Ctrl+Y and Escape are the "
      "demo's, calling the controller's commands; the plan's letters do "
      'nothing; a key typed in the inspector stays the field\'s',
      (tester) async {
    final demo = await pumpSamples(tester);
    final c = demo.area.controller;
    // On (the default): the plan's Delete, and no line of the demo's.
    await click(tester, centreOf(c, '5'));
    await chord(tester, LogicalKeyboardKey.delete);
    expect(c.tables.map((t) => t.number), isNot(contains('5')),
        reason: 'control: the plan deletes');
    expect(demo.log.where((l) => l.contains("the demo's key")), isEmpty);
    c.undo();
    await settle(tester);

    await pressInPanel(tester, 'plan-keys');
    expect(demo.planKeys, isFalse);
    await click(tester, centreOf(c, '5'));
    expect(c.selectedTables.value, {'5'});
    // The demo's line, then the design's change (delivered later) and
    // the dirty flag's.
    await chord(tester, LogicalKeyboardKey.delete);
    expect(c.tables.map((t) => t.number), isNot(contains('5')));
    expect(demo.log.take(3), contains("Salon: Delete, the demo's key"));
    await chord(tester, LogicalKeyboardKey.keyZ, control: true);
    expect(c.tables.map((t) => t.number), contains('5'));
    expect(demo.log.take(3), contains("Salon: Ctrl+Z, the demo's key"));
    await chord(tester, LogicalKeyboardKey.keyY, control: true);
    expect(c.tables.map((t) => t.number), isNot(contains('5')));
    expect(demo.log.take(3), contains("Salon: Ctrl+Y, the demo's key"));
    c.undo();
    await settle(tester);
    // The plan's letter W is the plan's no more; Escape, the demo's, goes
    // back to Select, then clears the selection.
    await click(tester, centreOf(c, '5'));
    await chord(tester, LogicalKeyboardKey.keyW);
    expect(c.activeTool.value, FloorPlanTool.select);
    expect(c.selectTool(FloorPlanTool.wall), isTrue);
    await settle(tester);
    await chord(tester, LogicalKeyboardKey.escape);
    expect(c.activeTool.value, FloorPlanTool.select);
    expect(demo.log.first, "Salon: Escape, the demo's key");
    c.select({'5'});
    await settle(tester);
    await chord(tester, LogicalKeyboardKey.escape);
    expect(c.selectedTables.value, isEmpty);

    // A field inside the view keeps its keys: Backspace edits the
    // inspector's text and deletes no table.
    await pressInPanel(tester, 'editor-tables');
    await click(tester, centreOf(c, '5'));
    await tester.enterText(byKey('pos-id'), 'salon-55');
    await chord(tester, LogicalKeyboardKey.backspace);
    expect(c.tables.map((t) => t.number), contains('5'));
    expect(
        tester.widget<TextField>(byKey('pos-id')).controller!.text, 'salon-5');
  });

  testWidgets(
      "DH7 the search field keeps the focus across a mode switch; with the "
      "plan's keys off the view no longer takes the focus when it is shown "
      'again; Enter selects and centres the table, the field keeps the '
      'focus', (tester) async {
    final demo = await pumpSamples(tester);
    final c = demo.area.controller;
    expect(planFocused(), isTrue, reason: 'at start, the view takes it');
    // The view shown again by a mode switch takes the focus only with the
    // plan's keys.
    final floor = c.worldToGlobal(const Offset(-3210, 810))!;
    await press(tester, 'mode-service');
    expect(planFocused(), isTrue, reason: 'control');
    await press(tester, 'mode-design');
    expect(planFocused(), isTrue, reason: 'control');
    await pressInPanel(tester, 'plan-keys');
    await click(tester, floor);
    expect(planFocused(), isTrue, reason: 'a press takes it');
    await press(tester, 'mode-service');
    expect(planFocused(), isFalse);
    await click(tester, floor);
    expect(planFocused(), isTrue, reason: 'a press takes it');
    await press(tester, 'mode-design');
    expect(planFocused(), isFalse);
    // The field focused, the mode switched by a mouse press on the toggle
    // (a mouse press outside a field unfocuses it by default): the field
    // keeps the focus, whoever owns the keys.
    for (final keys in [false, true]) {
      if (keys) await pressInPanel(tester, 'plan-keys');
      expect(demo.planKeys, keys, reason: 'premise');
      await tester.tap(byKey('find-table'));
      await settle(tester);
      expect(searchFocused(tester), isTrue, reason: 'premise');
      await tester.tap(byKey('mode-service'), kind: PointerDeviceKind.mouse);
      await settle(tester);
      expect(c.mode.value, FloorPlanMode.selection);
      expect(searchFocused(tester), isTrue, reason: 'keys $keys');
      await tester.tap(byKey('mode-design'), kind: PointerDeviceKind.mouse);
      await settle(tester);
      expect(searchFocused(tester), isTrue, reason: 'keys $keys');
    }

    await tester.tap(byKey('find-table'));
    await tester.enterText(byKey('find-table'), '7');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(c.selectedTables.value, {'7'});
    expect(demo.log.first, 'Salon: table 7 found');
    final middle = c.canvasRect.value!.center;
    final seven = centreOf(c, '7');
    expect((seven - middle).distance, lessThan(1));
    expect(searchFocused(tester), isTrue);
    await tester.enterText(byKey('find-table'), '99');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(demo.log.first, 'Salon: no table 99');
    expect(c.selectedTables.value, {'7'});
  });

  testWidgets("DH8 the host choices' words in German and Turkish",
      (tester) async {
    for (final (locale, words) in [
      (
        const Locale('de'),
        [
          'Editor',
          'Voll',
          'Tische',
          'Nur lesen',
          'Eigener Exportdialog',
          'Tasten des Plans',
          'Tisch suchen',
        ]
      ),
      (
        const Locale('tr'),
        [
          'Düzenleyici',
          'Tam',
          'Masalar',
          'Salt okunur',
          'Kendi dışa aktarma penceresi',
          'Planın tuşları',
          'Masa bul',
        ]
      ),
    ]) {
      await pumpSamples(tester, locale: locale);
      await tester.scrollUntilVisible(byKey('plan-keys'), 100,
          scrollable: find
              .descendant(
                  of: byKey('side-panel'), matching: find.byType(Scrollable))
              .first);
      for (final w in words) {
        expect(find.text(w), findsWidgets, reason: '$locale: $w');
      }
      await tester.pumpWidget(const SizedBox());
    }
  });
}
