import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/l10n/localizations.dart';
import 'package:jet_cad_floor_plan/src/page_panel.dart';

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

  group('the decimal separator (spec Q0 P1, M-Q0-g)', () {
    // The fixture rule: cm, 1:20, the origin off zero, and the UI's
    // separator differing from the page's (V-11).
    (DraftDocument, PageNotifier) separatorPage(DecimalSeparator s) {
      final doc = DraftDocument.empty();
      PageComponent.register(doc.components);
      doc.commands.execute(SetComponentCommand<PageComponent>(
          doc.rootHandle,
          PageComponent(
              originX: 7350,
              originY: -1230,
              scaleDenominator: 20,
              displayUnit: DisplayUnit.centimeters,
              decimalSeparator: s)));
      doc.commands.clearHistory();
      return (doc, PageNotifier(doc));
    }

    Future<void> pumpIn(WidgetTester tester, Locale locale, DraftDocument doc,
            PageNotifier page) =>
        tester.pumpWidget(MaterialApp(
            locale: locale,
            supportedLocales: floorPlanSupportedLocales,
            localizationsDelegates: floorPlanLocalizationsDelegates,
            home: Scaffold(
                body: SizedBox(
                    width: 280, child: PagePanel(document: doc, page: page)))));

    Set<DecimalSeparator> shown(WidgetTester tester) => tester
        .widget<SegmentedButton<DecimalSeparator>>(
            find.byKey(const Key('page-decimal-separator')))
        .selected;

    testWidgets(
        'PS1 an English UI on a comma page shows 1,5 selected; a tap on 1.5 '
        'is one command, which Undo reverts', (tester) async {
      final (doc, page) = separatorPage(DecimalSeparator.comma);
      addTearDown(page.dispose);
      await pumpIn(tester, const Locale('en'), doc, page);
      expect(find.text('Decimal separator'), findsOneWidget);
      expect(find.text('1.5'), findsOneWidget);
      expect(find.text('1,5'), findsOneWidget);
      expect(shown(tester), {DecimalSeparator.comma});
      // P1's place: after the unit menu, the caption above the control,
      // the grid's check box below (the Task 3 review's finding 2).
      final unit = tester.getRect(find.byKey(const Key('page-unit')));
      final caption = tester.getRect(find.text('Decimal separator'));
      final control =
          tester.getRect(find.byKey(const Key('page-decimal-separator')));
      final grid = tester.getRect(find.byKey(const Key('page-grid')));
      expect(caption.top, greaterThanOrEqualTo(unit.bottom));
      expect(control.top, greaterThanOrEqualTo(caption.bottom));
      expect(grid.top, greaterThanOrEqualTo(control.bottom));

      await tester.tap(find.text('1.5'));
      await tester.pump();
      expect(pageOf(doc).decimalSeparator, DecimalSeparator.point);
      expect(doc.commands.undoDepth, 1, reason: 'one command');
      expect(shown(tester), {DecimalSeparator.point});
      expect(pageOf(doc).displayUnit, DisplayUnit.centimeters);
      expect(pageOf(doc).scaleDenominator, 20);
      expect(pageOf(doc).originX, 7350);

      doc.commands.undo();
      await tester.pump();
      expect(pageOf(doc).decimalSeparator, DecimalSeparator.comma);
      expect(doc.commands.undoDepth, 0);
      expect(shown(tester), {DecimalSeparator.comma});
    });

    testWidgets(
        'PS2 an Undo and a Redo made through the document, not the panel, '
        'move the control', (tester) async {
      final (doc, page) = separatorPage(DecimalSeparator.comma);
      addTearDown(page.dispose);
      await pumpIn(tester, const Locale('en'), doc, page);
      doc.commands.execute(SetComponentCommand<PageComponent>(doc.rootHandle,
          pageOf(doc).copyWith(decimalSeparator: DecimalSeparator.point)));
      await tester.pump();
      expect(shown(tester), {DecimalSeparator.point});
      doc.commands.undo();
      await tester.pump();
      expect(shown(tester), {DecimalSeparator.comma});
      doc.commands.redo();
      await tester.pump();
      expect(shown(tester), {DecimalSeparator.point});
    });

    testWidgets(
        'PS3 a German UI on a point page shows 1.5 selected; each tap writes '
        'the segment\'s value, not the UI\'s', (tester) async {
      final (doc, page) = separatorPage(DecimalSeparator.point);
      addTearDown(page.dispose);
      await pumpIn(tester, const Locale('de'), doc, page);
      expect(find.text('Dezimaltrennzeichen'), findsOneWidget);
      expect(find.text('1.5'), findsOneWidget);
      expect(find.text('1,5'), findsOneWidget);
      expect(shown(tester), {DecimalSeparator.point});
      expect(doc.commands.undoDepth, 0, reason: 'nothing written on open');

      await tester.tap(find.text('1,5'));
      await tester.pump();
      expect(pageOf(doc).decimalSeparator, DecimalSeparator.comma);
      expect(doc.commands.undoDepth, 1);
      await tester.tap(find.text('1.5'));
      await tester.pump();
      expect(pageOf(doc).decimalSeparator, DecimalSeparator.point,
          reason: 'the segment tapped, against the UI\'s comma');
      expect(doc.commands.undoDepth, 2);
      expect(shown(tester), {DecimalSeparator.point});
    });
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
