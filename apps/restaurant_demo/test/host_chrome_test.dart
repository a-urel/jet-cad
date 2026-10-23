// Ported from the old apps/restaurant_demo/test/host_chrome_test.dart (the
// restaurant-kit test audit, section 5, docs/superpowers/specs/
// 2026-10-16-restaurant-kit-test-audit.md): the editor's three profiles
// (Full, Tables, Read only) with the demo's table inspector under Tables;
// the planner's service bar carrying the area's name, and the demo's own
// service bar, built from the controller's commands and state, in place of
// it; the demo's own export dialog at every Export; a failed print logged;
// the plan's keys and focus given to the demo; a table search in the app
// bar. On the Salon sample, whose fitted camera is neither the identity nor
// at the origin. Screen points come from the public `unitDetails` and
// `worldToGlobal`; expected exports from the public `export`, never from
// the demo's code.
//
// New: EX-area (an export started in one area writes that area's page even
// if another is shown while the dialog is up).
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import 'package:restaurant_demo/editor_profiles.dart' show DemoEditor;

import 'support/demo_rig.dart';

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

Offset centreOf(PlanController c, String n) => unitScreen(c, n);

Future<void> clickAt(WidgetTester tester, Offset at) async {
  await tester.tapAt(at, kind: PointerDeviceKind.mouse);
  await settle(tester);
}

/// A mouse drag from [from] by [by], in four moves, unstamped.
Future<void> dragBy(WidgetTester tester, Offset from, Offset by) async {
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

/// A PNG's width and height, from its header.
(int, int) pngSize(Uint8List png) {
  final b = ByteData.sublistView(png);
  return (b.getUint32(16), b.getUint32(20));
}

/// Whether the primary focus is inside the plan's editor.
bool planFocused() =>
    FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<PlanEditor>() !=
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
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    expect(c.setUnitData('2', {'seats_note': 'window'}), isTrue);
    await settle(tester);
    bool wallEnabled() =>
        tester.widget<ListTile>(byKey('tool-architecture.wall')).enabled;
    // Full (the default): the whole editor, the inspector included. The
    // right column follows the selection: a selected table has its own
    // properties and the combo, no Layers or Page.
    expect(wallEnabled(), isTrue);
    expect(byKey('layers-panel'), findsOneWidget);
    await clickAt(tester, centreOf(c, '2'));
    expect(c.selectedUnits.value, {'2'}, reason: 'premise: selected');
    expect(byKey('pos-id'), findsOneWidget);
    expect(byKey('layers-panel'), findsNothing);
    expect(byKey('page-preset'), findsNothing);

    await pressInPanel(tester, 'editor-tables');
    expect(demo.editor, DemoEditor.tables);
    // The wall tool is shown disabled under Tables, not hidden.
    expect(wallEnabled(), isFalse);
    expect(byKey('tool-plan.select'), findsOneWidget);
    expect(byKey('tab-symbols'), findsOneWidget);
    expect(byKey('layers-panel'), findsNothing);
    expect(byKey('page-preset'), findsNothing);
    await clickAt(tester, centreOf(c, '2'));
    expect(c.selectedUnits.value, {'2'});
    expect(byKey('pos-id'), findsOneWidget);
    // Decided: the inspector is a combo over the demo's records now (D14),
    // not a text field: a record is picked, and the empty entry unlinks.
    await pickRecord(tester, 'T-02');
    await settle(tester);
    expect(dataByLabel(c)['2'], {'seats_note': 'window', 'id': 'T-02'});
    expect(demo.log.first, 'Salon: table 2 is T-02');
    // Another table: its own combo, empty; emptied, a table is unlinked.
    await clickAt(tester, centreOf(c, '3'));
    expect(pickedId(tester), '');
    await clickAt(tester, centreOf(c, '2'));
    expect(pickedId(tester), 'T-02');
    await pickRecord(tester, '');
    await settle(tester);
    expect(dataByLabel(c)['2'], {'seats_note': 'window'});
    expect(demo.log.first, 'Salon: table 2 unlinked');
  });

  testWidgets(
      'DH2 Read only moves and deletes nothing; its bar shows Print, Export '
      'and the zoom; under Full the same drag moves the table', (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    Offset? centre(String n) =>
        c.unitDetails.singleWhere((d) => d.unit.label == n).center;
    final before = centre('4')!;
    // Full: the drag moves table 4; undone by the host.
    await clickAt(tester, centreOf(c, '4'));
    await dragBy(tester, centreOf(c, '4'), const Offset(80, 40));
    expect(centre('4'), isNot(before), reason: 'control');
    c.undo();
    await settle(tester);
    expect(centre('4'), before);

    await pressInPanel(tester, 'editor-read-only');
    expect(byKey('toolbar-undo'), findsNothing);
    expect(byKey('osnap-text'), findsNothing);
    expect(byKey('zoom-text'), findsOneWidget);
    expect(tester.getTopLeft(byKey('toolbar-print')).dx,
        lessThan(tester.getTopLeft(byKey('toolbar-export')).dx));
    await clickAt(tester, centreOf(c, '4'));
    expect(c.selectedUnits.value, {'4'}, reason: 'a selection is no edit');
    final saved = c.save();
    await dragBy(tester, centreOf(c, '4'), const Offset(80, 40));
    await chord(tester, LogicalKeyboardKey.delete);
    await chord(tester, LogicalKeyboardKey.keyW);
    expect(c.save(), saved);
    expect(centre('4'), before);
    expect(c.canUndo.value, isFalse);
    expect(c.deleteSelection(), isFalse);
    expect(c.activeTool.value, PlanToolIds.select);
  });

  testWidgets(
      "DH3 the service bar carries the area's name; Own bar hides it, and "
      "the demo's Merge, Split, Undo and Redo send what the planner's would",
      (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    await press(tester, 'mode-service');
    expect(byKey('service-bar'), findsOneWidget);
    expect(
        find.descendant(of: byKey('service-bar'), matching: byKey('bar-area')),
        findsOneWidget);
    expect(textOf(tester, 'bar-area'), 'Salon');
    expect(tester.getTopLeft(byKey('bar-area')).dx,
        lessThan(tester.getTopLeft(byKey('service-undo')).dx),
        reason: 'the name leads the buttons');
    // The planner's Merge, as a reference.
    c.select({'1', '2'});
    await settle(tester);
    await press(tester, 'service-merge');
    final merged = c.unitGroups.value;
    final mergedLog = demo.log.first;
    expect(merged.keys, ['G1'], reason: 'premise');
    c.setUnitGroups(const {});
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
    expect(c.unitGroups.value.keys, merged.keys);
    expect(c.unitGroups.value['G1']!.members, merged['G1']!.members);
    expect(demo.log.first, mergedLog);
    // Split: the group, selected through a member.
    c.select({'3'});
    await settle(tester);
    expect(button('own-split').onPressed, isNull, reason: 'no group');
    c.select({'1'});
    await settle(tester);
    expect(c.selectedGroup.value, 'G1');
    await press(tester, 'own-split');
    expect(c.unitGroups.value, isEmpty);
    expect(demo.log.first, 'Salon: Split G1');
    // Undo and Redo of a service move.
    expect(button('own-undo').onPressed, isNull);
    final before = placeOf3(c, '3');
    await dragBy(tester, centreOf(c, '3'), const Offset(60, 30));
    final after = placeOf3(c, '3');
    expect(after, isNot(before), reason: 'premise: moved');
    await press(tester, 'own-undo');
    expect(placeOf3(c, '3'), before);
    await press(tester, 'own-redo');
    expect(placeOf3(c, '3'), after);

    // Off again: the planner's bar, its Merge the same.
    await pressInPanel(tester, 'own-bar');
    expect(byKey('own-bar-row'), findsNothing);
    expect(byKey('service-merge'), findsOneWidget);
  });

  testWidgets(
      "DH4 the own export dialog replaces the planner's at its Export and "
      'its chord, in both modes: a PNG at 300 dpi is what export makes, '
      'remembered as the next initial; Cancel exports nothing; the own '
      "bar's Export asks it too, from its own remembered answer",
      (tester) async {
    final demo = await pumpDemo(tester);
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
    expect(export.name, 'salon.png');
    expect(export.mimeType, 'image/png');
    expect(demo.log.first,
        'Salon: exported salon.png, ${export.bytes.length} bytes');
    final expected = (await tester.runAsync(() => c.export(
        'plan.png', const PlanExportChoice(dpi: PlanExportDpi.d300),
        name: 'salon')))!;
    expect(export.bytes, expected.bytes);
    final at96 = (await tester.runAsync(() =>
        c.export('plan.png', const PlanExportChoice(dpi: PlanExportDpi.d96))))!;
    final (w300, h300) = pngSize(export.bytes);
    final (w96, h96) = pngSize(at96.bytes);
    expect(w300, closeTo(w96 * 300 / 96, 2));
    expect(h300, closeTo(h96 * 300 / 96, 2));

    // The service's chord: the demo's dialog, PNG 300 remembered.
    await press(tester, 'mode-service');
    await clickAt(tester, c.worldToGlobal(kFloor)!);
    await chord(tester, LogicalKeyboardKey.keyE, control: true);
    expect(byKey('export-dialog'), findsNothing);
    expect(byKey('demo-export-dialog'), findsOneWidget);
    expect(checkIn('demo-export-png-300'), findsOneWidget);
    await press(tester, 'demo-export-cancel');
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await settle(tester);
    expect(identical(demo.lastExport, export), isTrue);

    // The own bar's Export: the same dialog, from the bar's own answer
    // (PDF, 150: the planner's remembered one is internal), then export.
    await pressInPanel(tester, 'own-bar');
    await press(tester, 'own-export');
    expect(byKey('demo-export-dialog'), findsOneWidget);
    expect(checkIn('demo-export-pdf'), findsOneWidget,
        reason: 'the own bar remembers its own answer');
    await press(tester, 'demo-export-png-96');
    await waitFor(tester, () => !identical(demo.lastExport, export));
    expect(demo.lastExport!.name, 'salon.png');
    expect(pngSize(demo.lastExport!.bytes), (w96, h96));
    await press(tester, 'own-export');
    expect(checkIn('demo-export-png-96'), findsOneWidget,
        reason: 'and starts from it the next time');
    await press(tester, 'demo-export-cancel');

    // Off: the planner's own dialog again.
    await pressInPanel(tester, 'own-export-dialog');
    await clickAt(tester, c.worldToGlobal(kFloor)!);
    await chord(tester, LogicalKeyboardKey.keyE, control: true);
    expect(byKey('export-dialog'), findsOneWidget);
    expect(byKey('demo-export-dialog'), findsNothing);
  });

  testWidgets(
      "OWN-busy the own bar's Export and Print are off while a page flow "
      'runs (pageFlowBusy), the planner\'s dialog included, and on again '
      'after it', (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    await press(tester, 'mode-service');
    await pressInPanel(tester, 'own-bar');
    bool enabled(String key) =>
        tester.widget<TextButton>(byKey(key)).onPressed != null;
    expect(enabled('own-export') && enabled('own-print'), isTrue,
        reason: 'premise: idle');
    expect(c.pageFlowBusy.value, isFalse);

    await clickAt(tester, c.worldToGlobal(kFloor)!);
    await chord(tester, LogicalKeyboardKey.keyE, control: true);
    expect(byKey('export-dialog'), findsOneWidget, reason: 'premise: a flow');
    expect(c.pageFlowBusy.value, isTrue);
    expect(enabled('own-export'), isFalse);
    expect(enabled('own-print'), isFalse);
    await press(tester, 'export-cancel');
    expect(c.pageFlowBusy.value, isFalse);
    expect(enabled('own-export') && enabled('own-print'), isTrue);
  });

  testWidgets(
      "DH5 a print that fails is logged, from the planner's Print and from "
      "the own bar's", (tester) async {
    final printer = JammedPrinter();
    final demo = await pumpDemo(tester, printer: printer);
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
      "nothing; a key typed in the inspector stays the field's",
      (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    List<String?> labels() => [for (final u in c.units) u.label];
    // On (the default): the plan's Delete, and no line of the demo's.
    await clickAt(tester, centreOf(c, '5'));
    await chord(tester, LogicalKeyboardKey.delete);
    expect(labels(), isNot(contains('5')), reason: 'control: the plan deletes');
    expect(demo.log.where((l) => l.contains("the demo's key")), isEmpty);
    c.undo();
    await settle(tester);

    await pressInPanel(tester, 'plan-keys');
    expect(demo.planKeys, isFalse);
    await clickAt(tester, centreOf(c, '5'));
    expect(c.selectedUnits.value, {'5'});
    // The demo's line, then the design's change (delivered later) and the
    // dirty flag's.
    await chord(tester, LogicalKeyboardKey.delete);
    expect(labels(), isNot(contains('5')));
    expect(demo.log.take(3), contains("Salon: Delete, the demo's key"));
    await chord(tester, LogicalKeyboardKey.keyZ, control: true);
    expect(labels(), contains('5'));
    expect(demo.log.take(3), contains("Salon: Ctrl+Z, the demo's key"));
    await chord(tester, LogicalKeyboardKey.keyY, control: true);
    expect(labels(), isNot(contains('5')));
    expect(demo.log.take(3), contains("Salon: Ctrl+Y, the demo's key"));
    c.undo();
    await settle(tester);
    // The plan's letter W is the plan's no more; Escape, the demo's, goes
    // back to Select, then clears the selection.
    await clickAt(tester, centreOf(c, '5'));
    await chord(tester, LogicalKeyboardKey.keyW);
    expect(c.activeTool.value, PlanToolIds.select);
    expect(c.selectTool('architecture.wall'), isTrue);
    await settle(tester);
    await chord(tester, LogicalKeyboardKey.escape);
    expect(c.activeTool.value, PlanToolIds.select);
    expect(demo.log.first, "Salon: Escape, the demo's key");
    c.select({'5'});
    await settle(tester);
    await chord(tester, LogicalKeyboardKey.escape);
    expect(c.selectedUnits.value, isEmpty);

    // A field inside the view keeps its keys: Backspace edits the symbol
    // search's text and deletes no table. Decided: the inspector is a combo
    // now (D14), with no text; the Tables profile's symbol search is the
    // text field of the view.
    await pressInPanel(tester, 'editor-tables');
    await clickAt(tester, centreOf(c, '5'));
    await tester.tap(byKey('tab-symbols'));
    await tester.pump();
    await tester.enterText(byKey('symbol-search'), 'table5');
    await chord(tester, LogicalKeyboardKey.backspace);
    expect(labels(), contains('5'));
    expect(tester.widget<TextField>(byKey('symbol-search')).controller!.text,
        'table');
  });

  testWidgets(
      "DH7 the search field keeps the focus across a mode switch; with the "
      "plan's keys off the view no longer takes the focus when it is shown "
      'again; Enter selects and centres the table, the field keeps the '
      'focus', (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    expect(planFocused(), isTrue, reason: 'at start, the view takes it');
    // The view shown again by a mode switch takes the focus only with the
    // plan's keys.
    final floor = c.worldToGlobal(kFloor)!;
    await press(tester, 'mode-service');
    expect(planFocused(), isTrue, reason: 'control');
    await press(tester, 'mode-design');
    expect(planFocused(), isTrue, reason: 'control');
    await pressInPanel(tester, 'plan-keys');
    await clickAt(tester, floor);
    expect(planFocused(), isTrue, reason: 'a press takes it');
    await press(tester, 'mode-service');
    expect(planFocused(), isFalse);
    await clickAt(tester, floor);
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
      expect(c.mode.value, PlanMode.service);
      expect(searchFocused(tester), isTrue, reason: 'keys $keys');
      await tester.tap(byKey('mode-design'), kind: PointerDeviceKind.mouse);
      await settle(tester);
      expect(searchFocused(tester), isTrue, reason: 'keys $keys');
    }

    await tester.tap(byKey('find-table'));
    await tester.enterText(byKey('find-table'), '7');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(c.selectedUnits.value, {'7'});
    expect(demo.log.first, 'Salon: table 7 found');
    final middle = c.canvasRect.value!.center;
    final seven = centreOf(c, '7');
    expect((seven - middle).distance, lessThan(1));
    expect(searchFocused(tester), isTrue);
    await tester.enterText(byKey('find-table'), '99');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(demo.log.first, 'Salon: no table 99');
    expect(c.selectedUnits.value, {'7'});
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
      await pumpDemo(tester, locale: locale);
      await reveal(tester, 'plan-keys');
      for (final w in words) {
        expect(find.text(w), findsWidgets, reason: '$locale: $w');
      }
      await tester.pumpWidget(const SizedBox());
    }
  });
}

/// Unit [label]'s placement in [c]'s active plan, as six numbers.
List<double> placeOf3(PlanController c, String label) {
  final t = placementOf(c, label);
  return [t.a, t.b, t.c, t.d, t.e, t.f];
}
