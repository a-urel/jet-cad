// The library gaps (spec decision 10, audit "Library facts" 7 and the
// decision list's item 5): `PlanEditor` behaviours that no test in
// packages/jet_cad_2d_plan pinned when the audit grepped it, pinned here
// through the app. Each case names the library mutation that turns it red
// (task-7-report.md lists them, with every other test the mutation reds).
//
//   LG1  the file buttons and chords are gated while a tool is part-way
//        (`_idleFlag` in the editor's file commands)
//   LG2  the Meta forms of the file and print chords (`_chord` in
//        chords.dart)
//   LG3  the redo chords: Cmd+Shift+Z, Ctrl+Shift+Z, Ctrl+Y (kRedoChords)
//   LG4  focus in the Symbols gallery (the strip and the cells never take
//        it; Tab walks past them) and tab switches arm no tool
//   LG5  the gallery's search text survives a tab switch and a New
//        (`_symbolQuery` in the editor)
//   LG6  Export and Print follow the page: detached, undone, redone
//        (the editor's `_exportFlag` and `_printFlag`)
//
// Several of these are also pinned by Task 4's and Task 6's ports (DC2, DC4,
// DC5, PR6, EX9b, SS12, SS13-open): the library mutations in the report show
// which tests each one reds. The per-platform tooltip glyphs are DC1b's.
//
// Decided: premise impossible (LG6: "the page panel's off switch"): the page
// panel has no switch that detaches the page, only the document's command
// (`SetComponentCommand<PageComponent>(root, null)`) does, as EX9b has it.
//
// Decided: premise differs (LG4: "Tab moves from the search field to the
// first cell"): the gallery is wrapped in `ExcludeFocus` (Ruling 05-6), so a
// cell is never in the focus order; Tab from the search field lands on the
// canvas, and the case pins exactly that.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/src/chrome/icon_button.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart'
    show PageComponent, SetComponentCommand;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, SymbolGallery;

import 'support/app_fakes.dart';
import 'support/app_rig.dart';
import 'support/export_rig.dart';
import 'support/symbol_rig.dart';

/// Presses [key] with every key of [modifiers] held; whether the key-down
/// was handled.
Future<bool> pressWith(WidgetTester tester, List<LogicalKeyboardKey> modifiers,
    LogicalKeyboardKey key) async {
  for (final m in modifiers) {
    await tester.sendKeyDownEvent(m);
  }
  final handled = await tester.sendKeyEvent(key);
  for (final m in modifiers.reversed) {
    await tester.sendKeyUpEvent(m);
  }
  await tester.pump();
  return handled;
}

final Map<String, LogicalKeyboardKey> _modifiers = {
  'Cmd': LogicalKeyboardKey.meta,
  'Ctrl': LogicalKeyboardKey.control,
};

void main() {
  group('LG1 the file buttons and chords wait for a part-way shape', () {
    testWidgets(
        'with the Wall tool pressed and not released New, Open, Save and Save '
        'As are disabled, a tap does nothing, and neither Cmd+S nor Ctrl+S '
        'writes; after Escape both work', (tester) async {
      final rig = await pumpApp(tester);
      final c = rig.controller;
      final files = rig.files;
      files.scriptSaveLocation(name: 'plan.jetplan', location: '/p/plan');
      await aimCamera(tester, c, kFar);
      await press(tester, LogicalKeyboardKey.keyW);
      final mouse = await tester.createGesture(
          kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
      await mouse.down(globalOf(tester, c, kFar));
      await tester.pump();
      expect(activeTool(tester).isMidShape, isTrue, reason: 'premise');

      PlanIconButton button(String id) =>
          tester.widget<PlanIconButton>(find.byKey(Key('toolbar-$id')));
      for (final id in ['new', 'open', 'save', 'save-as']) {
        expect(button(id).onPressed, isNull, reason: id);
        await rig.tapKey('toolbar-$id');
      }
      for (final modifier in _modifiers.values) {
        await pressWith(tester, [modifier], LogicalKeyboardKey.keyS);
      }
      await tester.pump();
      expect(files.writes, isEmpty, reason: 'nothing written');
      expect(files.saveLocationCalls, isEmpty, reason: 'nothing asked');
      expect(files.openCalls, 0);
      expect(rig.session.busy.value, isFalse);

      await mouse.up();
      await mouse.removePointer();
      await tester.pump();
      expect(activeTool(tester).isMidShape, isTrue,
          reason: 'premise: a wall chain goes on after the release');
      await press(tester, LogicalKeyboardKey.escape);
      expect(activeTool(tester).isMidShape, isFalse, reason: 'premise');
      for (final id in ['new', 'open', 'save', 'save-as']) {
        expect(button(id).onPressed, isNotNull, reason: id);
      }
      await pressWith(
          tester, [LogicalKeyboardKey.meta], LogicalKeyboardKey.keyS);
      await tester.pump();
      expect(files.writes, hasLength(1), reason: 'Cmd+S saves once idle');
    });
  });

  group('LG2 the Meta forms of the chords run the flows the Ctrl forms do', () {
    for (final entry in _modifiers.entries) {
      final label = entry.key;
      final modifier = entry.value;

      testWidgets('$label+S saves (asks, writes plan.jetplan)', (tester) async {
        final rig = await pumpApp(tester);
        rig.files.scriptSaveLocation(name: 'plan.jetplan', location: '/p/plan');
        await rig.editOnce();
        await pressWith(tester, [modifier], LogicalKeyboardKey.keyS);
        await tester.pump();
        expect(rig.files.saveLocationCalls, ['Untitled.jetplan']);
        expect(rig.files.writes.map((w) => w.location), ['/p/plan']);
        expect(rig.controller.dirty.value, isFalse);
      });

      testWidgets('$label+Shift+S asks where', (tester) async {
        final rig = await pumpApp(tester);
        rig.files.scriptSaveCancel();
        await pressWith(tester, [modifier, LogicalKeyboardKey.shift],
            LogicalKeyboardKey.keyS);
        await tester.pump();
        expect(rig.files.saveLocationCalls, hasLength(1));
        expect(rig.files.writes, isEmpty);
      });

      testWidgets('$label+O opens: the file picker is asked once',
          (tester) async {
        final rig = await pumpApp(tester);
        rig.files.scriptOpenCancel();
        await pressWith(tester, [modifier], LogicalKeyboardKey.keyO);
        await tester.pump();
        expect(rig.files.openCalls, 1);
      });

      testWidgets(
          '$label+N from an edited plan asks Save / Don\'t Save, and Don\'t '
          'Save starts a new plan', (tester) async {
        final rig = await pumpApp(tester);
        await rig.editOnce();
        final before = rig.controller.document;
        await pressWith(tester, [modifier], LogicalKeyboardKey.keyN);
        await tester.pump();
        await answerReplace(tester, 'replace-discard');
        noDialog(tester);
        expect(identical(rig.controller.document, before), isFalse);
        expect(rig.controller.document.entities.liveCount, 0);
      });

      testWidgets('$label+P prints once', (tester) async {
        final printer = FakePagePrinter();
        await pumpFlat(tester, printer: printer);
        await pressWith(tester, [modifier], LogicalKeyboardKey.keyP);
        await settleUntil(tester, () => printer.calls.isNotEmpty);
        await tester.pump();
        expect(printer.calls, hasLength(1));
      });
    }
  });

  testWidgets(
      'LG3 the redo chords: Cmd+Shift+Z, Ctrl+Shift+Z and Ctrl+Y each redo '
      'one undone step, and no other key does', (tester) async {
    final rig = await pumpApp(tester);
    final c = rig.controller;
    final doc = c.document;
    await rig.editOnce();
    final done = doc.commands.stateId;
    final redoChords = <(String, List<LogicalKeyboardKey>, LogicalKeyboardKey)>[
      (
        'Cmd+Shift+Z',
        [LogicalKeyboardKey.meta, LogicalKeyboardKey.shift],
        LogicalKeyboardKey.keyZ
      ),
      (
        'Ctrl+Shift+Z',
        [LogicalKeyboardKey.control, LogicalKeyboardKey.shift],
        LogicalKeyboardKey.keyZ
      ),
      ('Ctrl+Y', [LogicalKeyboardKey.control], LogicalKeyboardKey.keyY),
    ];
    for (final (name, mods, key) in redoChords) {
      expect(
          await pressWith(
              tester, [LogicalKeyboardKey.meta], LogicalKeyboardKey.keyZ),
          isTrue,
          reason: 'premise: Cmd+Z undoes');
      expect(doc.commands.undoDepth, 0, reason: 'undone before $name');
      expect(doc.commands.canRedo, isTrue);
      expect(await pressWith(tester, mods, key), isTrue, reason: name);
      expect(doc.commands.undoDepth, 1, reason: name);
      expect(doc.commands.stateId, done, reason: '$name redoes the step');
    }
    // Shift+Z with neither Cmd nor Ctrl is no redo chord.
    doc.commands.undo();
    await tester.pump();
    await pressWith(
        tester, [LogicalKeyboardKey.shift], LogicalKeyboardKey.keyZ);
    expect(doc.commands.undoDepth, 0, reason: 'Shift+Z alone is no redo');
  });

  group('LG4 focus and tabs in the Symbols gallery', () {
    testWidgets(
        'Tab from the search field lands on the canvas, Shift+Tab on neither '
        'the strip nor a cell: the cells and the strip are not in the focus '
        'order', (tester) async {
      await pumpSymbolsApp(tester);
      await tapFinder(tester, tabSymbols);
      bool under(Finder f) => focusNodesUnder(tester, f)
          .contains(FocusManager.instance.primaryFocus);

      await tester.tap(searchField);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus,
          tester.widget<TextField>(searchField).focusNode,
          reason: 'premise: the search field has the focus');
      await press(tester, LogicalKeyboardKey.tab);
      final afterTab = FocusManager.instance.primaryFocus;
      expect(
          find
              .descendant(
                  of: find.byType(InteractionLayer),
                  matching:
                      find.byElementPredicate((e) => e == afterTab!.context),
                  matchRoot: true)
              .evaluate(),
          isNotEmpty,
          reason: 'Tab walks past the cells to the canvas');

      for (var i = 0; i < 6; i++) {
        await press(tester, LogicalKeyboardKey.tab);
        expect(under(find.byType(SymbolGallery)), isFalse, reason: 'tab $i');
        expect(under(strip), isFalse, reason: 'tab $i');
      }
      await tester.tap(searchField);
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await pressWith(
            tester, [LogicalKeyboardKey.shift], LogicalKeyboardKey.tab);
        expect(under(find.byType(SymbolGallery)), isFalse,
            reason: 'shift+tab $i');
        expect(under(strip), isFalse, reason: 'shift+tab $i');
      }
    });

    testWidgets(
        'switching tabs back and forth, with the Wall tool and with an armed '
        'symbol, changes no tool', (tester) async {
      final rig = await pumpSymbolsApp(tester);
      final c = rig.controller;
      await press(tester, LogicalKeyboardKey.keyW);
      expect(c.activeTool.value, 'architecture.wall', reason: 'premise');
      for (var i = 0; i < 2; i++) {
        await tapFinder(tester, tabSymbols);
        expect(c.activeTool.value, 'architecture.wall', reason: 'to Symbols');
        await tapFinder(tester, tabTools);
        expect(c.activeTool.value, 'architecture.wall', reason: 'to Tools');
      }
      await armBySymbolsTab(tester, c, symbolOf(c, 'bed.double'));
      await tapFinder(tester, tabTools);
      expect(c.activeTool.value, 'plan.symbol', reason: 'armed, to Tools');
      expect(c.armedSymbol.value, isNotNull);
      await tapFinder(tester, tabSymbols);
      expect(c.activeTool.value, 'plan.symbol', reason: 'armed, to Symbols');
      expect(galleryOf(tester).selectedId, symbolOf(c, 'bed.double').id);
    });
  });

  testWidgets(
      'LG5 the gallery\'s search text survives a tab switch and a New: the '
      'field reads it and the gallery is filtered', (tester) async {
    final rig = await pumpSymbolsApp(tester);
    final c = rig.controller;
    await tapFinder(tester, tabSymbols);
    await tester.enterText(searchField, 'sofa');
    await tester.pump();
    final sofas = galleryIdsOf(tester);
    expect(sofas, isNotEmpty);
    expect(sofas.length, lessThan(41), reason: 'premise: filtered');

    await tapFinder(tester, tabTools);
    await rig.host.newFlow();
    await tester.pump();
    await tapFinder(tester, tabSymbols);
    expect(tester.widget<TextField>(searchField).controller!.text, 'sofa');
    expect(galleryIdsOf(tester), sofas);
    expect(galleryIdsOf(tester), idsMatching(c, 'sofa'));
  });

  testWidgets(
      'LG6 Export and Print follow the page: detached they are disabled, '
      'the undo enables them, the redo disables them', (tester) async {
    final rig = await pumpFlat(tester);
    final c = rig.controller;
    final root = c.document.rootHandle;
    bool both() => on(tester, 'export') && on(tester, 'print');
    bool neither() => !on(tester, 'export') && !on(tester, 'print');
    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
    }

    expect(both(), isTrue, reason: 'premise: a page');
    c.document.commands.execute(SetComponentCommand<PageComponent>(root, null));
    await settle();
    expect(pageOf(c), isNull, reason: 'premise: detached');
    expect(neither(), isTrue, reason: 'detached');
    expect(
        await pressWith(
            tester, [LogicalKeyboardKey.meta], LogicalKeyboardKey.keyZ),
        isTrue);
    await settle();
    expect(pageOf(c), isNotNull, reason: 'premise: undone');
    expect(both(), isTrue, reason: 'attached again by the undo');
    expect(
        await pressWith(
            tester,
            [LogicalKeyboardKey.meta, LogicalKeyboardKey.shift],
            LogicalKeyboardKey.keyZ),
        isTrue);
    await settle();
    expect(pageOf(c), isNull, reason: 'premise: redone');
    expect(neither(), isTrue, reason: 'redone');
  });
}
