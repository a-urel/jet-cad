// New tests N3 and N5 (audit docs/superpowers/specs/
// 2026-10-16-architecture-demo-test-audit.md, "New tests"): the web tab's
// title, which is the `ShadApp`'s `onGenerateTitle`, follows the plan's
// name, its dirty flag and the language.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/app_rig.dart';

final Vector2 far = Vector2(41234.5, -27654.25);

/// Switches the system language to [locale] and pumps the three frames the
/// app needs to show it in its title: the first rebuilds the host, whose
/// post-frame callback tells the app; the second carries the tick the
/// shadcn words need to arrive (`kLocaleTick`), and rebuilds the host; the
/// third rebuilds the app.
Future<void> switchTo(WidgetTester tester, Locale locale) async {
  tester.platformDispatcher.localesTestValue = [locale];
  await tester.pump();
  await tester.pump(kLocaleTick);
  await tester.pump();
}

void main() {
  testWidgets(
      'N3 the title: Untitled, dotted when edited, the file\'s name after a '
      'Save As, and clean again after an edit is undone back to the save '
      'point', (tester) async {
    final rig = await pumpApp(tester);
    final c = rig.controller;
    expect(titleOf(tester), 'Untitled — jet-cad');

    await rig.editOnce(at: far);
    expect(titleOf(tester), '• Untitled — jet-cad');

    rig.files.scriptSaveLocation(name: 'flat.jetplan', location: '/p/flat');
    expect(await rig.host.saveAsStep(), isTrue);
    await tester.pump();
    expect(c.dirty.value, isFalse, reason: 'premise: saved');
    expect(titleOf(tester), 'flat — jet-cad');

    await drawWall(
        tester, c, far + Vector2(0, 2500), far + Vector2(2600, 2500));
    expect(titleOf(tester), '• flat — jet-cad');
    await undoKey(tester);
    expect(c.dirty.value, isFalse, reason: 'premise: back at the save point');
    expect(titleOf(tester), 'flat — jet-cad',
        reason: 'clean by the save point, not by a flag set in a save');
  });

  testWidgets(
      'N5 the language: a switch from English to Turkish renames an '
      'untitled plan in the title and the bar within that pump sequence, '
      'and the editor speaks Turkish with it; a named plan keeps its '
      'file\'s name through a switch to German', (tester) async {
    tester.platformDispatcher.localesTestValue = [const Locale('en', 'US')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final rig = await pumpApp(tester);
    expect(titleOf(tester), 'Untitled — jet-cad');
    expect(shownName(tester), 'Untitled');
    expect(find.text('Wall'), findsOneWidget, reason: 'premise: English');
    expect(find.text('Duvar'), findsNothing);

    await switchTo(tester, const Locale('tr', 'TR'));
    expect(PlanStrings.of(tester.element(find.byType(PlanEditor))).cancel,
        isNot('Cancel'),
        reason: 'premise: the library switched');
    expect(shownName(tester), 'Adsız', reason: 'the bar');
    expect(titleOf(tester), 'Adsız — jet-cad', reason: 'the title');
    expect(find.text('Duvar'), findsOneWidget, reason: 'an editor word');
    expect(find.text('Wall'), findsNothing);

    // Dirty and untitled: the dot stays, the word changes again.
    await rig.editOnce(at: far);
    expect(titleOf(tester), '• Adsız — jet-cad');
    await switchTo(tester, const Locale('de', 'DE'));
    expect(titleOf(tester), '• Unbenannt — jet-cad');

    // Named: the file's name is not a word of any language.
    rig.files.scriptSaveLocation(name: 'flat.jetplan', location: '/p/flat');
    expect(await rig.host.saveAsStep(), isTrue);
    await tester.pump();
    expect(titleOf(tester), 'flat — jet-cad');
    await switchTo(tester, const Locale('tr', 'TR'));
    expect(titleOf(tester), 'flat — jet-cad');
    expect(shownName(tester), 'flat');
    await switchTo(tester, const Locale('en', 'US'));
    expect(titleOf(tester), 'flat — jet-cad');
  });
}
