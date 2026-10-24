// POS-host Task 6 (spec D1-D5): PlanEditor's design mode on a phone, a
// tablet and a desktop.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanKit;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/editor_host.dart'
    show editorPlanJson, embeddingCamera, slowSymbolsKit;
import '../support/mark_kit.dart';
import '../support/symbol_fixtures.dart' show demoKit;

Finder k(String key) => find.byKey(Key(key));

Future<PlanController> pump(WidgetTester tester, double w, double h,
    {PlanLayoutBreakpoints? breakpoints,
    PlanEditorLayout? layout,
    bool gallery = true,
    bool symbols = true,
    PlanKit? symbolKit}) async {
  final c = PlanController(
      kits: [markKit(), if (symbols) symbolKit ?? slowSymbolsKit()],
      json: editorPlanJson());
  addTearDown(c.dispose);
  await tester.binding.setSurfaceSize(Size(w, h));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: PlanEditor(
    controller: c,
    gallery: gallery,
    breakpoints: breakpoints ?? const PlanLayoutBreakpoints(),
    layout: layout,
  ))));
  await tester.pump();
  await tester.pump();
  c.camera.value = embeddingCamera();
  await tester.pump();
  return c;
}

String cameraOf(PlanController c) =>
    c.camera.value.worldToScreenMatrix.toString();

bool shown(String key) => k(key).hitTestable().evaluate().isNotEmpty;

void main() {
  testWidgets(
      'EL1 1440 x 900: chrome-left/right present, no buttons, no drawers',
      (tester) async {
    await pump(tester, 1440, 900);
    expect(k('chrome-left'), findsOneWidget);
    expect(k('chrome-right'), findsOneWidget);
    expect(tester.getSize(k('chrome-left')).width, 240);
    expect(tester.getSize(k('chrome-right')).width, 280);
    expect(k('chrome-left-button'), findsNothing);
    expect(k('chrome-right-button'), findsNothing);
    expect(k('chrome-left-drawer'), findsNothing);
    expect(k('chrome-right-drawer'), findsNothing);
    expect(k('chrome-tool-strip'), findsNothing);
  });

  testWidgets(
      'EL2 375 x 812: no docked columns; both buttons in chrome-top; each '
      'opens its drawer', (tester) async {
    await pump(tester, 375, 812);
    expect(k('chrome-left'), findsNothing);
    expect(k('chrome-right'), findsNothing);
    expect(k('chrome-tool-strip'), findsNothing);
    final top = tester.getRect(k('chrome-top'));
    final l = tester.getRect(k('chrome-left-button'));
    final r = tester.getRect(k('chrome-right-button'));
    expect(top.contains(l.center), isTrue);
    expect(top.contains(r.center), isTrue);
    expect(l.left, lessThan(top.left + 24), reason: 'the bar\'s first item');
    expect(r.right, greaterThan(top.right - 24), reason: 'its last item');
    expect(shown('chrome-left-drawer'), isFalse);
    expect(shown('chrome-right-drawer'), isFalse);

    await tester.tap(k('chrome-left-button'));
    await tester.pump();
    expect(shown('chrome-left-drawer'), isTrue);
    expect(shown('chrome-right-drawer'), isFalse);
    expect(
        find.descendant(
            of: k('chrome-left-drawer'), matching: k('tool-plan.line')),
        findsOneWidget);
    expect(tester.getSize(k('chrome-left-drawer')).width, 280);

    await tester.tap(k('chrome-right-button'));
    await tester.pump();
    expect(shown('chrome-left-drawer'), isFalse);
    expect(shown('chrome-right-drawer'), isTrue);
    expect(tester.getSize(k('chrome-right-drawer')).width, 300);
    expect(
        find.descendant(
            of: k('chrome-right-drawer'), matching: k('chrome-right-scroll')),
        findsOneWidget);
  });

  testWidgets('EL2b a drawer is capped at 85% of a 320 px width',
      (tester) async {
    await pump(tester, 320, 640);
    await tester.tap(k('chrome-right-button'));
    await tester.pump();
    expect(tester.getSize(k('chrome-right-drawer')).width, 320 * 0.85);
  });

  testWidgets(
      'EL3 800 x 1280: the tool strip, the symbols icon opens the gallery '
      'drawer, the right button opens the properties', (tester) async {
    await pump(tester, 800, 1280);
    expect(k('chrome-tool-strip'), findsOneWidget);
    expect(k('chrome-left'), findsNothing);
    expect(k('chrome-right'), findsNothing);
    expect(k('chrome-left-button'), findsNothing);
    expect(k('chrome-right-button'), findsOneWidget);
    expect(tester.getSize(k('chrome-tool-strip')).width, lessThan(80));
    // Icons only: no tool label text in the strip.
    expect(
        find.descendant(
            of: k('chrome-tool-strip'), matching: find.text('Line')),
        findsNothing);
    expect(
        find.descendant(
            of: k('chrome-tool-strip'), matching: k('tool-plan.line')),
        findsOneWidget);
    await tester.tap(k('tool-plan.line'));
    await tester.pump();

    await tester.tap(k('chrome-symbols-button'));
    await tester.pump();
    expect(shown('chrome-left-drawer'), isTrue);
    expect(
        find.descendant(
            of: k('chrome-left-drawer'),
            matching: find.byType(PlanSymbolGallery)),
        findsOneWidget);
    await tester.tap(k('chrome-right-button'));
    await tester.pump();
    expect(shown('chrome-left-drawer'), isFalse);
    expect(shown('chrome-right-drawer'), isTrue);
  });

  testWidgets('EL3b the symbols icon is absent with gallery: false',
      (tester) async {
    await pump(tester, 800, 1280, gallery: false);
    expect(k('chrome-tool-strip'), findsOneWidget);
    expect(k('chrome-symbols-button'), findsNothing);
  });

  testWidgets(
      'EL4 one drawer at a time; a canvas tap, the button again and Escape '
      'each close it; opening moves no camera', (tester) async {
    final c = await pump(tester, 375, 812);
    final before = cameraOf(c);
    expect(tester.getSize(k('chrome-canvas')), const Size(375, 768),
        reason: 'premise: the canvas fills the body');
    expect(before, isNot(equals(cameraOf(PlanController(kits: [markKit()])))),
        reason: 'premise: a camera that is not the default');

    await tester.tap(k('chrome-right-button'));
    await tester.pump();
    expect(shown('chrome-right-drawer'), isTrue);
    expect(cameraOf(c), before);
    // The same button again.
    await tester.tap(k('chrome-right-button'));
    await tester.pump();
    expect(shown('chrome-right-drawer'), isFalse);

    // A tap on the canvas (the barrier) closes it, and selects nothing.
    await tester.tap(k('chrome-left-button'));
    await tester.pump();
    expect(shown('chrome-left-drawer'), isTrue);
    expect(cameraOf(c), before);
    await tester.tapAt(const Offset(350, 400));
    await tester.pump();
    expect(shown('chrome-left-drawer'), isFalse);
    expect(c.selection.isEmpty, isTrue);

    // Escape.
    await tester.tap(k('chrome-right-button'));
    await tester.pump();
    expect(shown('chrome-right-drawer'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(shown('chrome-right-drawer'), isFalse);
    expect(cameraOf(c), before);
  });

  testWidgets(
      'EL4c Escape in a drawer\'s text field does not close the drawer; '
      'Escape with the canvas focused does', (tester) async {
    await pump(tester, 375, 600);
    await tester.tap(k('chrome-right-button'));
    await tester.pump();
    final field = find
        .descendant(
            of: k('chrome-right-drawer'), matching: find.byType(EditableText))
        .first;
    await tester.ensureVisible(field);
    await tester.pump();
    await tester.tap(field);
    await tester.pump();
    expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<EditableText>(),
        isNotNull,
        reason: 'premise: the field holds the focus');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(shown('chrome-right-drawer'), isTrue);

    // Focus back on the canvas: Escape closes.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(shown('chrome-right-drawer'), isFalse);
  });

  testWidgets('EL4b a drawer keeps its panel\'s scroll across close and open',
      (tester) async {
    await pump(tester, 375, 300);
    await tester.tap(k('chrome-right-button'));
    await tester.pump();
    final scrollable = find
        .descendant(
            of: k('chrome-right-scroll'), matching: find.byType(Scrollable))
        .first;
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.maxScrollExtent, greaterThan(60),
        reason: 'premise: the panels are taller than the drawer');
    position.jumpTo(60);
    await tester.pump();
    await tester.tap(k('chrome-right-button'));
    await tester.pump();
    expect(shown('chrome-right-drawer'), isFalse);
    await tester.tap(k('chrome-right-button'));
    await tester.pump();
    expect(tester.state<ScrollableState>(scrollable).position.pixels, 60);
  });

  testWidgets(
      'EL5 breakpoints (tablet: 700) and layout: phone are both obeyed; 1000 '
      'is desktop', (tester) async {
    await pump(tester, 650, 900,
        breakpoints: const PlanLayoutBreakpoints(tablet: 700));
    expect(k('chrome-left-button'), findsOneWidget, reason: '650 < 700');
    expect(k('chrome-tool-strip'), findsNothing);

    await pump(tester, 1440, 900, layout: PlanEditorLayout.phone);
    expect(k('chrome-left-button'), findsOneWidget);
    expect(k('chrome-left'), findsNothing);

    await pump(tester, 900, 700, layout: PlanEditorLayout.desktop);
    expect(k('chrome-left'), findsOneWidget);
    expect(k('chrome-left-button'), findsNothing);

    await pump(tester, 1000, 700);
    expect(k('chrome-left'), findsOneWidget, reason: '1000 is desktop');
    await pump(tester, 600, 700);
    expect(k('chrome-tool-strip'), findsOneWidget, reason: '600 is tablet');
    await pump(tester, 599, 700);
    expect(k('chrome-left-button'), findsOneWidget, reason: '599 is phone');
  });

  testWidgets(
      'EL6 a drawer open on the phone, resized to 1440 x 900 and back: no '
      'exception, no drawer open, the selection kept', (tester) async {
    final c = await pump(tester, 375, 812);
    final marks = c.catalog.objectsOf<MarkCross>(c.document);
    c.selection.replace([SelectionKey.root(marks.first)]);
    await tester.tap(k('chrome-right-button'));
    await tester.pump();
    expect(shown('chrome-right-drawer'), isTrue);

    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(k('chrome-right'), findsOneWidget);
    expect(k('chrome-right-drawer'), findsNothing);

    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(shown('chrome-right-drawer'), isFalse);
    expect(shown('chrome-left-drawer'), isFalse);
    expect(c.selection.length, 1);
  });

  testWidgets('EL7 the phone bar at 320 px wide does not overflow',
      (tester) async {
    await pump(tester, 320, 640);
    expect(tester.takeException(), isNull);
    expect(
        tester.getRect(k('chrome-right-button')).right, lessThanOrEqualTo(320));
    expect(k('status-text'), findsNothing, reason: 'hidden on the phone');
    expect(k('zoom-text'), findsNothing);
  });

  testWidgets(
      'EL8 phone: picking Wall in the left drawer closes it; picking a symbol '
      'in the gallery drawer closes it; a tab switch and a search do not',
      (tester) async {
    final c = await pump(tester, 375, 812, symbolKit: demoKit());
    await tester.runAsync(() async {
      for (var i = 0;
          i < 50 && c.symbolsState.value == SymbolsState.loading;
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
    await tester.tap(k('chrome-left-button'));
    await tester.pump();
    expect(shown('chrome-left-drawer'), isTrue);
    await tester.tap(k('tab-symbols'));
    await tester.pump();
    await tester.enterText(k('symbol-search'), 'sofa');
    await tester.pump();
    expect(shown('chrome-left-drawer'), isTrue,
        reason: 'a tab and a search pick nothing');
    await tester.tap(k('tab-tools'));
    await tester.pump();
    await tester.tap(k('tool-plan.line'));
    await tester.pump();
    expect(c.activeTool.value, 'plan.line');
    expect(shown('chrome-left-drawer'), isFalse);

    await tester.tap(k('chrome-left-button'));
    await tester.pump();
    await tester.tap(k('tab-symbols'));
    await tester.pump();
    await tester.tap(k('symbol-cell-demo.sofa.three@1'));
    await tester.pump();
    expect(c.activeTool.value, PlanToolIds.symbol);
    expect(shown('chrome-left-drawer'), isFalse);

    // A second symbol with the symbol tool already active: only the armed
    // symbol changes, and that alone closes the drawer.
    expect(c.armedSymbol.value!.id, 'demo.sofa.three@1');
    await tester.tap(k('chrome-left-button'));
    await tester.pump();
    expect(shown('chrome-left-drawer'), isTrue);
    await tester.tap(k('symbol-cell-demo.sofa.two@1'));
    await tester.pump();
    expect(c.armedSymbol.value!.id, 'demo.sofa.two@1');
    expect(shown('chrome-left-drawer'), isFalse);

    // The right drawer is not closed by a pick.
    await tester.tap(k('chrome-right-button'));
    await tester.pump();
    c.selectTool('plan.rectangle');
    await tester.pump();
    expect(shown('chrome-right-drawer'), isTrue);
  });

  testWidgets(
      'EL-TOP the docked columns run the canvas height; a right column '
      'shorter than it starts at the top', (tester) async {
    await pump(tester, 1440, 900);
    final canvas = tester.getRect(k('chrome-canvas'));
    final right = tester.getRect(k('chrome-right'));
    final left = tester.getRect(k('chrome-left'));
    final content = tester.getRect(find.byType(PlanLayerPanel));
    expect(right.top, canvas.top);
    expect(right.height, canvas.height);
    expect(left.top, canvas.top);
    expect(left.height, canvas.height);
    expect(content.top, right.top,
        reason: 'the first panel sits at the column top');
    // Premise: the column's content is shorter than the canvas, else the
    // check above cannot tell top from centre.
    final scroll = tester.getRect(find
        .descendant(of: k('chrome-right-scroll'), matching: find.byType(Column))
        .first);
    expect(scroll.height, lessThan(canvas.height));
  });
}
