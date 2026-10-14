// Ported from jet_cad_floor_plan/test/planner_draw_test.dart; assertions unchanged.
//
// The drawing on the canvas alone: the TEXT entry's place (A7), the ink of
// a drafted line through the canvas's own resolver and its survival across
// rebuilds (A17), and the ink following the paper (A20-A22). A key that
// armed a tool is the controller's selectTool here (the keyboard is Task
// 16's); a swatch is the page edit it made (the page panel is Task 18's).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/canvas/plan_canvas_view.dart';

import '../support/canvas_fixture.dart';

void main() {
  testWidgets(
      'A7 the field sits at the camera\'s point and survives a pan '
      'with its state (M-05n, M-05u)', (tester) async {
    final c = drawController().c;
    await pumpDraw(tester, c);
    c.selectTool('plan.text');
    await tester.pump();
    await tester.tapAt(globalOf(tester, c, 7100.5, 3050.25));
    await tester.pump();
    final field = find.byKey(const Key('text-entry'));
    final placed = c.textTool;
    final at = placed.pending.value!.point;
    Offset corner() =>
        tester.getBottomLeft(find.byKey(const Key('text-entry-box')));
    final want = globalOf(tester, c, at.x, at.y);
    expect((corner() - want).distance, lessThan(0.5));
    await tester.enterText(field, 'abc');
    final state = tester.state<EditableTextState>(entryEditable);
    c.camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2.translation(40, -25)
            .multiply(c.camera.value.worldToScreenMatrix));
    await tester.pump();
    expect(
        (corner() - globalOf(tester, c, at.x, at.y)).distance, lessThan(0.5));
    expect(identical(tester.state<EditableTextState>(entryEditable), state),
        isTrue,
        reason: 'Ruling 05-10: never rebuilt by the camera');
    expect(state.widget.focusNode.hasFocus, isTrue);
    expect(placed.controller.text, 'abc');
  });

  testWidgets(
      'A17 a line drafted with L is ByLayer on layer 0 and resolves black '
      "through the canvas's own resolver, which survives a rebuild "
      '(fix/post-07)', (tester) async {
    final seeded = drawController();
    final c = seeded.c;
    await pumpDraw(tester, c);
    c.selectTool('plan.line');
    await tester.pump();
    await tester.tapAt(globalOf(tester, c, 7010, 3020));
    await tester.pump();
    await tester.tapAt(globalOf(tester, c, 7060, 3090));
    await tester.pump();
    c.selectTool('plan.select');
    await tester.pump();
    final doc = c.document;
    final drafted =
        ofKind(doc, EntityKind.line).where((h) => h != seeded.line).single;
    final slot = doc.entities.slotOf(drafted)!;
    // The fixture is the defect's own: nothing concrete to fall back on.
    expect(doc.entities.colorAt(slot), kByLayer);
    expect(doc.entities.layerAt(slot), ReservedHandles.layerZero);
    expect(doc.tables.layers[ReservedHandles.layerZero]!.color,
        const IndexedColor(7));

    DraftCanvasState canvas() =>
        tester.state<DraftCanvasState>(find.byType(DraftCanvas));
    final painter = canvas().painter;
    expect(painter.resolver.styleFor(slot, StyleContext.documentRoot).argb,
        0xFF000000,
        reason: 'ACI 7 is the foreground, black on the paper');

    // A rebuild of the shell and the view must hand the canvas the same
    // resolver: a different one makes `didUpdateWidget` rebuild the painter.
    tester.element(find.byType(PlanCanvas)).markNeedsBuild();
    tester.element(find.byType(PlanCanvasView)).markNeedsBuild();
    await tester.pump();
    expect(identical(canvas().painter, painter), isTrue,
        reason: 'one resolver per paper foreground, not one per build');
  });

  /// Drafts one line with plan.line on [c] and returns its slot: ByLayer on
  /// layer 0, which is ACI 7.
  Future<int> draftLine(WidgetTester tester, PlanController c) async {
    final doc = c.document;
    final before = ofKind(doc, EntityKind.line).toSet();
    c.selectTool('plan.line');
    await tester.pump();
    await tester.tapAt(globalOf(tester, c, 7010, 3020));
    await tester.pump();
    await tester.tapAt(globalOf(tester, c, 7060, 3090));
    await tester.pump();
    c.selectTool('plan.select');
    await tester.pump();
    final drafted =
        ofKind(doc, EntityKind.line).where((h) => !before.contains(h)).single;
    final slot = doc.entities.slotOf(drafted)!;
    expect(doc.entities.colorAt(slot), kByLayer);
    expect(doc.entities.layerAt(slot), ReservedHandles.layerZero);
    return slot;
  }

  /// The slot's colour through the canvas's own painter's resolver.
  int argbOnCanvas(WidgetTester tester, int slot) => tester
      .state<DraftCanvasState>(find.byType(DraftCanvas))
      .painter
      .resolver
      .styleFor(slot, StyleContext.documentRoot)
      .argb;

  testWidgets(
      'A20 the foreground follows the paper: black on White, white on '
      'Blueprint picked in the Page panel, back by undo and redo; White to '
      'Ivory keeps the resolver (fix/post-07 F1b)', (tester) async {
    final c = drawController().c;
    await pumpDraw(tester, c);
    final doc = c.document;
    PageComponent page() => doc.components.get<PageComponent>(doc.rootHandle)!;
    DraftCanvasState canvas() =>
        tester.state<DraftCanvasState>(find.byType(DraftCanvas));
    expect(page().background, 0xFFFFFFFF, reason: 'starts on White');
    final slot = await draftLine(tester, c);
    expect(argbOnCanvas(tester, slot), 0xFF000000, reason: 'White');

    // Each page edit below is heard after the frame it is pumped in (the
    // document's change stream is asynchronous, and the canvas alone has
    // nothing that schedules that frame, as the shell's swatch tap and bar
    // did): a second pump draws it.
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle, page().copyWith(background: 0xFF1F3A5F)));
    await tester.pump();
    await tester.pump();
    expect(page().background, 0xFF1F3A5F);
    expect(argbOnCanvas(tester, slot), 0xFFFFFFFF, reason: 'Blueprint');

    doc.commands.undo();
    await tester.pump();
    await tester.pump();
    expect(page().background, 0xFFFFFFFF);
    expect(argbOnCanvas(tester, slot), 0xFF000000, reason: 'undo to White');

    doc.commands.redo();
    await tester.pump();
    await tester.pump();
    expect(page().background, 0xFF1F3A5F);
    expect(argbOnCanvas(tester, slot), 0xFFFFFFFF, reason: 'redo Blueprint');

    doc.commands.undo();
    await tester.pump();
    await tester.pump();
    expect(argbOnCanvas(tester, slot), 0xFF000000, reason: 'undo again');

    // White to Ivory: the page changes, the foreground does not, so the
    // canvas keeps its painter (a new resolver would rebuild it).
    final painter = canvas().painter;
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle, page().copyWith(background: 0xFFFAF6EC)));
    await tester.pump();
    await tester.pump();
    expect(page().background, 0xFFFAF6EC);
    expect(identical(canvas().painter, painter), isTrue,
        reason: 'same foreground, same resolver');
    expect(argbOnCanvas(tester, slot), 0xFF000000, reason: 'Ivory');
  });

  testWidgets(
      'A21 a document that opens on Blueprint drafts white from the start, '
      'and a load onto White turns it black (fix/post-07 F1b)', (tester) async {
    final c = drawController(background: 0xFF1F3A5F).c;
    final doc = c.document;
    await pumpDraw(tester, c);
    final slot = await draftLine(tester, c);
    expect(argbOnCanvas(tester, slot), 0xFFFFFFFF, reason: 'at startup');

    // Out of band, as a decode writes the registry before `notifyLoaded`.
    doc.components.attach<PageComponent>(
        doc.rootHandle,
        doc.components
            .get<PageComponent>(doc.rootHandle)!
            .copyWith(background: 0xFFFFFFFF));
    doc.commands.notifyLoaded();
    await tester.pump();
    await tester.pump(); // heard after the frame, as in A20
    expect(argbOnCanvas(tester, slot), 0xFF000000, reason: 'after the load');
  });

  testWidgets(
      'A22 a document without a page drafts black: no sheet is painted, so '
      "the drafting lies on the shell's light surface (fix/post-07 F1b)",
      (tester) async {
    final c = pagelessController();
    final doc = c.document;
    expect(doc.components.get<PageComponent>(doc.rootHandle), isNull);
    await pumpDraw(tester, c);
    final slot = await draftLine(tester, c);
    expect(argbOnCanvas(tester, slot), 0xFF000000);
  });
}
