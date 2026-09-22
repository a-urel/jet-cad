import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:floor_planner/page_panel.dart';

void main() {
  (DraftDocument, PageNotifier) docWithPage() {
    final doc = DraftDocument.empty();
    PageComponent.register(doc.components);
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle, PageComponent(originX: 7350, originY: -1230)));
    doc.commands.clearHistory();
    return (doc, PageNotifier(doc));
  }

  Future<void> pump(
          WidgetTester tester, DraftDocument doc, PageNotifier page) =>
      tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SizedBox(
                  width: 280, child: PagePanel(document: doc, page: page)))));

  PageComponent pageOf(DraftDocument doc) =>
      doc.components.get<PageComponent>(doc.rootHandle)!;

  testWidgets(
      'each toggle is exactly one command, and undo reverts the control',
      (tester) async {
    // M-04o.
    final (doc, page) = docWithPage();
    addTearDown(page.dispose);
    await pump(tester, doc, page);
    for (final (key, read) in [
      ('page-grid', (PageComponent p) => p.gridVisible),
      ('page-snap', (PageComponent p) => p.snapToGrid),
      ('page-breaks', (PageComponent p) => p.pageBreaks),
    ]) {
      final before = read(pageOf(doc));
      final depth = doc.commands.undoDepth;
      await tester.tap(find.byKey(Key(key)));
      await tester.pump();
      expect(read(pageOf(doc)), !before, reason: key);
      expect(doc.commands.undoDepth, depth + 1, reason: key);
      doc.commands.undo();
      await tester.pump();
      expect(read(pageOf(doc)), before);
      expect(
          tester.widget<CheckboxListTile>(find.byKey(Key(key))).value, before);
    }
  });

  testWidgets('preset, orientation, unit and swatch each issue one command',
      (tester) async {
    final (doc, page) = docWithPage();
    addTearDown(page.dispose);
    await pump(tester, doc, page);

    await tester.tap(find.byKey(const Key('page-preset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Letter').last);
    await tester.pumpAndSettle();
    expect(pageOf(doc).preset, SheetSize.letter);
    expect(doc.commands.undoDepth, 1);

    await tester.tap(find.byKey(const Key('page-orientation-portrait')));
    await tester.pump();
    expect(pageOf(doc).orientation, PageOrientation.portrait);
    expect(doc.commands.undoDepth, 2);

    await tester.tap(find.byKey(const Key('page-unit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ft-in').last);
    await tester.pumpAndSettle();
    expect(pageOf(doc).displayUnit, DisplayUnit.feetInches);
    expect(doc.commands.undoDepth, 3);

    await tester.tap(find.byKey(const Key('page-swatch-3')));
    await tester.pump();
    expect(pageOf(doc).background, 0xFF1F3A5F);
    expect(doc.commands.undoDepth, 4);
  });

  testWidgets('the scale field commits on submit, refuses junk',
      (tester) async {
    final (doc, page) = docWithPage();
    addTearDown(page.dispose);
    await pump(tester, doc, page);
    await tester.enterText(find.byKey(const Key('page-scale')), '100');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(pageOf(doc).scaleDenominator, 100);
    expect(doc.commands.undoDepth, 1);
    await tester.enterText(find.byKey(const Key('page-scale')), '-3');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(pageOf(doc).scaleDenominator, 100);
    expect(doc.commands.undoDepth, 1);
  });

  testWidgets('a custom size shows Custom', (tester) async {
    final (doc, page) = docWithPage();
    addTearDown(page.dispose);
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle, PageComponent(widthMm: 200, heightMm: 300)));
    await tester.pump();
    await pump(tester, doc, page);
    expect(find.text('Custom'), findsOneWidget);
  });
}
