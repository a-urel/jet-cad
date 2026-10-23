// Ported from the old apps/restaurant_demo/test/demo_test.dart (audit
// section 4, docs/superpowers/specs/2026-10-16-restaurant-kit-test-audit.md):
// the status buttons and "Random statuses" (D12, D13), the table menu (D17,
// D20), a caption worded again with the language (D21). New: ST-caption-de
// and ST-caption-tr (restaurant-kit plan, Review Focus 4). A table is a
// unit labelled with its number; a locked one is put on a locked layer by
// raw commands (a unit's handle is not in `unitDetails`).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:restaurant_demo/main.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadContextMenuItem;

import 'support/demo_rig.dart';

void main() {
  testWidgets(
      'D12 status buttons set the selected tables\' statuses; Free clears '
      'them', (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    c.select({'1', '2'});
    await tester.pump();
    await tester.tap(byKey('status-eating'));
    await tester.pump();
    expect(c.unitStatuses.value, {
      '1': DemoHomeState.kStatuses['Eating'],
      '2': DemoHomeState.kStatuses['Eating'],
    });
    expect(demo.log.first, 'Salon: Eating for {1, 2}');
    c.select({'2'});
    await tester.tap(byKey('status-bill'));
    await tester.pump();
    expect(c.unitStatuses.value['2']!.caption, 'Bill');
    expect(c.unitStatuses.value['1'], DemoHomeState.kStatuses['Eating'],
        reason: 'only the selection changes (review T4-1)');
    c.select({'1'});
    await tester.tap(byKey('status-free'));
    await tester.pump();
    expect(c.unitStatuses.value.keys, ['2']);
  });

  testWidgets(
      'D13 random statuses are seeded and replace the previous ones '
      '(14c R-13, review T4-2)', (tester) async {
    final names = DemoHomeState.kStatuses.keys.toList();
    // The first seed that draws Free for some unit of the Salon's eleven
    // and something else for another, so a merge into the previous
    // statuses would show.
    var seed = 0;
    while (() {
      final draws = math.Random(seed);
      final picked = [for (var i = 0; i < 11; i++) draws.nextInt(names.length)];
      return !picked.any((i) => names[i] == 'Free') ||
          picked.every((i) => names[i] == 'Free');
    }()) {
      seed++;
    }
    final demo = await pumpDemo(tester, random: math.Random(seed));
    final c = demo.area.controller;
    // Every table Eating, through the demo (its own record of the names).
    c.select({for (final u in c.units) u.label!});
    await tester.pump();
    await tester.tap(byKey('status-eating'));
    await tester.pump();
    expect(c.unitStatuses.value.length, c.units.length, reason: 'premise');
    await tester.tap(byKey('status-random'));
    await tester.pump();
    final expected = math.Random(seed);
    final want = <String, UnitStatus>{};
    for (final u in c.units) {
      final s = DemoHomeState.kStatuses[names[expected.nextInt(names.length)]];
      if (s != null) want[u.label!] = s;
    }
    expect(want.length, lessThan(c.units.length), reason: 'a Free drawn');
    expect(want, isNotEmpty);
    expect(c.unitStatuses.value, want);
    expect(demo.log.first, 'Salon: random statuses for ${want.length} tables');
  });

  testWidgets(
      'D17 a right click opens the table\'s menu; a status chosen there is '
      'set on the table', (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    await enterService(tester);
    await rightClick(tester, unitScreen(c, '2'));
    expect(find.text('Table 2'), findsOneWidget);
    expect(c.selectedUnits.value, {'2'});
    await tester.tap(byKey('menu-status-bill'));
    await tester.pumpAndSettle();
    expect(c.unitStatuses.value.keys, ['2']);
    expect(demo.log, contains('Salon: menu for 2'));
  });

  testWidgets(
      'D20 a locked table\'s menu acts on that table, never on the '
      'selection', (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    putOnLayer(c, '2', 'Locked', locked: true);
    await enterService(tester);
    c.select({'1'});
    await tester.pump();
    expect(c.selectedUnits.value, {'1'}, reason: 'premise');
    await rightClick(tester, unitScreen(c, '2'));
    expect(find.text('Table 2'), findsOneWidget);
    expect(c.selectedUnits.value, {'1'},
        reason: 'premise: a locked table leaves the selection alone');
    expect(tester.widget<ShadContextMenuItem>(byKey('menu-select')).enabled,
        isFalse,
        reason: 'a locked table cannot be selected');
    await tester.tap(byKey('menu-status-bill'));
    await tester.pumpAndSettle();
    expect(c.unitStatuses.value.keys, ['2']);
  });

  testWidgets(
      'D20b a dismissed table menu answers nothing: a tap outside is '
      'swallowed, Escape closes it, a choice still acts', (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    await enterService(tester);
    c.select({'1'});
    await tester.pump();
    await rightClick(tester, unitScreen(c, '2'));
    expect(byKey('menu-select'), findsOneWidget, reason: 'premise: open');
    final before = {...c.selectedUnits.value};

    // A tap on another table: the menu closes, the tap goes no further.
    await tester.tapAt(unitScreen(c, '3'));
    await tester.pumpAndSettle();
    expect(byKey('menu-select'), findsNothing);
    expect(c.selectedUnits.value, before, reason: 'the barrier took the tap');
    expect(c.unitStatuses.value, isEmpty);

    await rightClick(tester, unitScreen(c, '2'));
    expect(byKey('menu-select'), findsOneWidget, reason: 'premise: reopened');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(byKey('menu-select'), findsNothing);
    expect(c.selectedUnits.value, before);
    expect(c.unitStatuses.value, isEmpty);

    await rightClick(tester, unitScreen(c, '2'));
    await tester.tap(byKey('menu-status-bill'));
    await tester.pumpAndSettle();
    expect(byKey('menu-select'), findsNothing);
    expect(c.unitStatuses.value.keys, ['2'],
        reason: 'the control: a choice acts');
  });

  testWidgets('D21 a status caption is worded again when the language changes',
      (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    await switchLanguage(tester, 'tr');
    c.select({'2'});
    await tester.pump();
    await tester.tap(byKey('status-bill'));
    await tester.pump();
    expect(c.unitStatuses.value['2']!.caption, 'Hesap', reason: 'premise');
    await switchLanguage(tester, 'de');
    expect(c.unitStatuses.value['2']!.caption, 'Rechnung');
    expect(c.unitStatuses.value['2']!.color,
        DemoHomeState.kStatuses['Bill']!.color);
  });

  for (final (code, host) in [
    // A host's caption (what a POS may send) longer than 12 graphemes.
    ('tr', 'Sipariş verildi'),
    ('de', 'Zahlung ausstehend'),
  ]) {
    testWidgets(
        'ST-caption-$code a caption longer than 12 graphemes is cut and the '
        'service view paints it without an overflow', (tester) async {
      final demo = await pumpDemo(tester, locale: Locale(code));
      final c = demo.area.controller;
      await enterService(tester);
      // A host's caption of any length: cut by the plan, never longer.
      c.setUnitStatus({
        '1': UnitStatus(color: const Color(0x99E53935), caption: host),
        '2': UnitStatus(
            color: const Color(0x9943A047), caption: '👨‍👩‍👧‍👦' * 14),
      });
      await tester.pump();
      await tester.pump();
      expect(host.characters.length, greaterThan(12), reason: 'premise');
      final cut = c.unitStatuses.value['1']!.caption!;
      expect(cut, host.characters.take(12).toString());
      expect(cut.characters.length, 12);
      expect(c.unitStatuses.value['2']!.caption!.characters.length, 12,
          reason: 'a grapheme cluster counts once');
      expect(tester.takeException(), isNull);
    });
  }
}
