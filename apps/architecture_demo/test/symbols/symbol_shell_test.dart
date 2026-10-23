// Ported from apps/floor_planner/test/symbols/symbol_shell_test.dart (audit
// docs/superpowers/specs/2026-10-16-architecture-demo-test-audit.md, section
// "symbols/symbol_shell_test.dart"): SS2, SS6, SS12 PORT; SS7, SS8, SS13,
// SS14 SPLIT (the -open half is what the app does now; the intent half is
// the library's, cited, or pinned here as SS7 by spec decision 7); SS1, SS3,
// SS4, SS5, SS9, SS10, SS11 COVERED; SS15 DROPPED (`PlannerShell(symbols:)`
// is gone). SS16 and SS17 went to 3a.
//
// COVERED, checked (each opened and read), in packages/jet_cad_2d_plan/test
// unless a package is named:
//   SS1  editor/plan_editor_test.dart:111 (ED-2: Tools and Symbols tabs,
//        Tools first), :72 (ED-1); the app's own half is SS1-app below
//   SS3  panels/plan_symbol_gallery_test.dart:426 ("the highlight follows the
//        active tool and the armed entry"); controller/plan_controller_test
//        .dart:196 (C9: a kit tool clears the selection);
//        controller/symbols_controller_test.dart:224 (S-14)
//   SS4  tools/plan_symbol_tool_test.dart:844 ("keys compose (R, R, M) and
//        work mid-press"), :945 ("armed, not pressed: every key but R and M
//        bubbles"); jet_cad_2d_integration/test/attach/
//        wall_attach_tool_test.dart:492 (R and Shift+R while attached)
//   SS5  panels/plan_symbol_gallery_test.dart:426 (another tool chosen
//        clears the highlight); shortcuts/plan_shortcuts_test.dart:255
//        (KB-4: idle Escape arms plan.select)
//   SS9, SS10, SS11  controller/symbols_controller_test.dart:109 (S-11: a
//        shared loader and cache are not disposed, its own are)
// Intent halves of the SPLIT rows: controller/lifetimes_test.dart:23
// (C-life1, `activeTool == plan.select` after a swap), tools/
// plan_symbol_tool_test.dart:406 (`isMidShape` between press and release),
// panels/plan_symbol_gallery_test.dart:289 ("the gallery gone, the
// controller stays usable").
//
// Decided: premise impossible (SS7: the old test expected the armed symbol
// cleared by a swap; spec decision 7: the library keeps `armedSymbol` on the
// controller across `newPlan` and `load`): SS7-open pins that it survives;
// SS7 pins the intent that remains (the active tool is Select, the gallery
// shows no armed cell).
// Decided: premise impossible (SS13, SS14: the old shell and its panel were
// rebuilt at each swap; the editor and its search controller are the app's
// one, kept): the -open halves pin that the text survives and that the
// controller goes with the editor.
//
// F-2 arms a furniture cell through the app; the palette's own count and
// categories are pinned in symbol_library_loader_test.dart (SL9b-open).
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/src/chrome/icon_button.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, SelectionKey;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/chrome/text_field.dart' show PlanTextField;
import 'package:jet_cad_2d_plan/src/panels/gallery_grid.dart'
    show PlanGalleryGrid;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/app_rig.dart';
import '../support/symbol_rig.dart';

void _noop() {}

void main() {
  group(
      'the furniture palette through the app (the loader test pins its count)',
      () {
    testWidgets(
        'F-2 a cell tap arms the symbol it shows: plan.symbol is the active '
        'tool, the cell is the highlighted one, the selection is cleared',
        (tester) async {
      final rig = await pumpSymbolsApp(tester);
      final c = rig.controller;
      await rig.editOnce();
      final wall = wallsOf(c).single;
      c.activeSelection.replace([SelectionKey.root(wall)]);
      await tester.pump();
      expect(c.activeSelection.keys, hasLength(1), reason: 'premise');
      final bed = symbolOf(c, 'bed.double');
      expect(bed.entry.definition.basePoint.x, isNot(0),
          reason: 'premise: the base point is off the origin');
      await armBySymbolsTab(tester, c, bed);
      expect(c.activeSelection.keys, isEmpty);
      expect(galleryOf(tester).selectedId, bed.id);
      expect(tester.widget<Text>(find.byKey(const Key('status-text'))).data,
          isNotEmpty);
    });
  });

  testWidgets('SS1-app the app\'s editor has the tab strip, Tools first',
      (tester) async {
    final rig = await pumpSymbolsApp(tester);
    expect(strip, findsOneWidget);
    expect(tabTools, findsOneWidget);
    expect(tabSymbols, findsOneWidget);
    expect(find.byType(PlanToolPalette), findsOneWidget,
        reason: 'Tools is the default tab');
    expect(find.byType(PlanSymbolGallery), findsNothing);
    expect(rig.controller.symbols, hasLength(41));
  });

  testWidgets('SS2 the tabs switch the panel\'s content and change no tool',
      (tester) async {
    final rig = await pumpSymbolsApp(tester);
    await press(tester, LogicalKeyboardKey.keyW);
    final wall = activeTool(tester);
    expect(rig.controller.activeTool.value, 'architecture.wall',
        reason: 'premise');

    await tapFinder(tester, tabSymbols);
    expect(find.byType(PlanSymbolGallery), findsOneWidget);
    expect(find.byType(PlanToolPalette), findsNothing);
    expect(activeTool(tester), same(wall));
    expect(rig.controller.activeTool.value, 'architecture.wall');

    await tapFinder(tester, tabTools);
    expect(find.byType(PlanToolPalette), findsOneWidget);
    expect(find.byType(PlanSymbolGallery), findsNothing);
    expect(activeTool(tester), same(wall));
    expect(rig.controller.activeTool.value, 'architecture.wall');
  });

  testWidgets(
      'SS6 the tab strip and the cells take no focus: the canvas keeps it, '
      'on a tap and when asked', (tester) async {
    final rig = await pumpSymbolsApp(tester);
    await tapFinder(tester, tabSymbols);
    final canvas = canvasFocus(tester);

    await armBySymbolsTab(
        tester, rig.controller, symbolOf(rig.controller, 'bed.double'));
    expect(FocusManager.instance.primaryFocus, same(canvas));

    final stripNodes = focusNodesUnder(tester, strip);
    expect(stripNodes, isNotEmpty, reason: 'premise: the segments\' nodes');
    for (final n in stripNodes) {
      n.requestFocus();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(canvas),
          reason: 'a segment cannot take the focus');
    }
    final cellNodes = focusNodesUnder(tester, find.byType(PlanGalleryGrid));
    expect(cellNodes, isNotEmpty, reason: 'premise: the cells\' nodes');
    for (final n in cellNodes) {
      n.requestFocus();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(canvas),
          reason: 'a cell cannot take the focus');
    }
    await tapFinder(tester, tabTools);
    expect(FocusManager.instance.primaryFocus, same(canvas));
  });

  group('a document swap and the armed symbol (spec decision 7)', () {
    testWidgets(
        'SS7-open after New the armed furniture symbol is still the '
        'controller\'s armed symbol, the active tool is Select',
        (tester) async {
      final rig = await pumpSymbolsApp(tester);
      final c = rig.controller;
      final bed = symbolOf(c, 'bed.double');
      await armBySymbolsTab(tester, c, bed);
      expect(rig.controller.dirty.value, isFalse, reason: 'premise: clean');
      final document = c.document;

      await rig.host.newFlow();
      await tester.pump();
      expect(c.document, isNot(same(document)), reason: 'premise: swapped');
      expect(c.armedSymbol.value, same(bed),
          reason: 'today\'s library: armedSymbol survives newPlan');
      expect(c.activeTool.value, 'plan.select');
    });

    testWidgets(
        'SS7 a document swap (New, clean) leaves no armed tool: the active '
        'tool is Select, Tools is the tab, and the gallery shows no armed '
        'cell', (tester) async {
      final rig = await pumpSymbolsApp(tester);
      final c = rig.controller;
      final bed = symbolOf(c, 'bed.double');
      await armBySymbolsTab(tester, c, bed);
      expect(galleryOf(tester).selectedId, bed.id, reason: 'premise: armed');
      final armedTool = activeTool(tester);
      // A hover over the canvas shows the placement ghost (T7-M3): the
      // armed tool's overlays paint.
      await aimCamera(tester, c, kFar);
      final size = tester.getSize(find.byType(InteractionLayer));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
          location: globalOf(tester, c, kFar) + const Offset(9, 7));
      await tester.pump();
      await mouse.moveTo(globalOf(tester, c, kFar));
      await tester.pump();
      expect(overlayCalls(armedTool, c, size), greaterThan(0),
          reason: 'premise: the ghost is shown while hovering');
      expect(rig.controller.dirty.value, isFalse, reason: 'premise: clean');
      final document = c.document;

      await rig.host.newFlow();
      await tester.pump();
      expect(c.document, isNot(same(document)), reason: 'premise: swapped');

      expect(activeTool(tester), isNot(same(armedTool)),
          reason: 'the armed placement tool is not the active one');
      expect(c.activeTool.value, 'plan.select');
      // No ghost is left on the canvas: neither the armed tool nor the
      // active one paints an overlay (the old `ghostVisible` isFalse).
      await mouse.moveTo(globalOf(tester, c, kFar) + const Offset(20, 10));
      await tester.pump();
      expect(overlayCalls(armedTool, c, size), 0,
          reason: 'the armed tool\'s ghost is gone after the swap');
      expect(overlayCalls(activeTool(tester), c, size), 0,
          reason: 'the active tool paints no ghost');
      await mouse.removePointer();
      // The tab stays where the user left it (the editor is the same one):
      // the Symbols gallery is still shown, and highlights no cell.
      expect(find.byType(PlanGalleryGrid), findsOneWidget);
      expect(galleryOf(tester).selectedId, isNull);
      await tapFinder(tester, tabTools);
      expect(find.byType(PlanToolPalette), findsOneWidget);
      await tapFinder(tester, tabSymbols);
      expect(galleryOf(tester).selectedId, isNull);
    });
  });

  testWidgets(
      'SS8-open the mid-shape rule: during a symbol placement press the '
      'toolbar\'s Save is disabled; after the release it is enabled again',
      (tester) async {
    final rig = await pumpSymbolsApp(tester);
    final c = rig.controller;
    await aimCamera(tester, c, kFar);
    await armBySymbolsTab(tester, c, symbolOf(c, 'bed.double'));
    VoidCallback? save() => tester
        .widget<PlanIconButton>(find.byKey(const Key('toolbar-save')))
        .onPressed;
    expect(save(), isNotNull, reason: 'premise: Save enabled');

    final a = kFar + Vector2(310.5, -220.25);
    final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    await mouse.down(globalOf(tester, c, a));
    await tester.pump();
    expect(activeTool(tester).isMidShape, isTrue, reason: 'premise');
    expect(save(), isNull);

    await mouse.moveTo(globalOf(tester, c, a) + const Offset(30, 20));
    await tester.pump();
    expect(save(), isNull);
    await mouse.up();
    await mouse.removePointer();
    await tester.pump();
    expect(instancesOf(c.document), hasLength(1), reason: 'premise: placed');
    expect(save(), isNotNull);
  });

  group('the search text', () {
    testWidgets(
        'SS12 "bed" typed, Tools and back: the field reads "bed" and the '
        'gallery is filtered', (tester) async {
      final rig = await pumpSymbolsApp(tester);
      final c = rig.controller;
      await tapFinder(tester, tabSymbols);
      final all = galleryIdsOf(tester);
      await tester.enterText(searchField, 'bed');
      await tester.pump();
      final beds = galleryIdsOf(tester);
      expect(beds, idsMatching(c, 'bed'), reason: 'premise: filtered');
      expect(beds.length, lessThan(all.length), reason: 'premise');
      expect(beds, contains('architecture.bed.double@1'));

      await tapFinder(tester, tabTools);
      expect(find.byType(PlanSymbolGallery), findsNothing,
          reason: 'the gallery is removed on the Tools tab');
      // A second build of the editor while the gallery is away.
      await press(tester, LogicalKeyboardKey.keyW);
      await tapFinder(tester, tabSymbols);
      expect(tester.widget<PlanTextField>(searchField).controller.text, 'bed');
      expect(galleryIdsOf(tester), beds);
      expect(categoryNamesOf(tester), ['Bed Room']);
      expect(find.byKey(const Key('symbol-search-clear')), findsOneWidget);
    });

    testWidgets(
        'SS13-open a document replacement keeps it: New, then Open sample, '
        'and the Symbols tab still reads "bed" (the editor is the same one)',
        (tester) async {
      final rig = await pumpSymbolsApp(tester);
      final c = rig.controller;
      await tapFinder(tester, tabSymbols);
      await tester.enterText(searchField, 'bed');
      await tester.pump();
      final given = tester.widget<PlanTextField>(searchField).controller;
      final editor = tester.state(find.byType(PlanEditor));

      for (final replace in [
        () => rig.host.newFlow(),
        () => rig.host.openSampleFlow(),
      ]) {
        final before = c.document;
        await replace();
        await tester.pump();
        expect(c.document, isNot(same(before)), reason: 'premise: replaced');
        expect(before.commands.isDisposed, isTrue,
            reason: 'the replaced document is disposed');
        expect(tester.state(find.byType(PlanEditor)), same(editor),
            reason: 'the same editor');

        await tapFinder(tester, tabTools);
        await tapFinder(tester, tabSymbols);
        expect(
            tester.widget<PlanTextField>(searchField).controller, same(given));
        expect(given.text, 'bed');
        expect(galleryIdsOf(tester), idsMatching(c, 'bed'));
      }
    });

    testWidgets(
        'SS14-open the search controller is the editor\'s: the gallery gone '
        'it stays usable, it goes with the editor, and a new app starts '
        'empty', (tester) async {
      await pumpSymbolsApp(tester);
      await tapFinder(tester, tabSymbols);
      await tester.enterText(searchField, 'bed');
      await tester.pump();
      final given = tester.widget<PlanTextField>(searchField).controller;

      await tapFinder(tester, tabTools);
      expect(find.byType(PlanSymbolGallery), findsNothing, reason: 'premise');
      // Not disposed with the gallery: it still takes text and listeners.
      given.text = 'sofa';
      given.addListener(_noop);
      given.removeListener(_noop);
      await tapFinder(tester, tabSymbols);
      expect(tester.widget<PlanTextField>(searchField).controller.text, 'sofa');
      expect(
          galleryIdsOf(tester),
          allOf(isNotEmpty,
              everyElement(matches(RegExp(r'^architecture\.sofa')))));

      await tester.pumpWidget(const SizedBox());
      expect(() => given.addListener(_noop), throwsFlutterError,
          reason: 'disposed with the editor');
      await pumpSymbolsApp(tester);
      await tapFinder(tester, tabSymbols);
      expect(tester.widget<PlanTextField>(searchField).controller,
          isNot(same(given)));
      expect(
          tester.widget<PlanTextField>(searchField).controller.text, isEmpty);
    });
  });
}
