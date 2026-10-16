// 4a spec R2 O2 (plan Task 4): the Page panel's orientation row lays each
// label out on one line, so no word breaks mid-word ("Landscap/e" was seen
// at 1440 px in the architecture demo's smoke). Golden-free: the line count
// of each label's RenderParagraph, in the panel at the editor's right
// column width and in the editor itself at 1440x900, in en, de and tr.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

/// The laid-out line count (paragraph height over one line's) of the one `Text` under [key].
int linesOf(WidgetTester tester, Key key) {
  final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.byKey(key), matching: find.byType(RichText)));
  // The same text laid out without a width limit is one line by
  // construction; a taller paragraph wrapped.
  final one = TextPainter(
      text: paragraph.text,
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler)
    ..layout();
  final lines = (paragraph.size.height / one.height).round();
  one.dispose();
  return lines;
}

void main() {
  const labels = {
    'en': ('Portrait', 'Landscape'),
    'de': ('Hochformat', 'Querformat'),
    'tr': ('Dikey', 'Yatay'),
  };

  void expectOneLine(WidgetTester tester, String lang) {
    final (portrait, landscape) = labels[lang]!;
    expect(find.text(portrait), findsOneWidget, reason: lang);
    expect(find.text(landscape), findsOneWidget, reason: lang);
    expect(linesOf(tester, const Key('page-orientation-portrait')), 1,
        reason: '$lang portrait');
    expect(linesOf(tester, const Key('page-orientation-landscape')), 1,
        reason: '$lang landscape');
  }

  // 280 is the editor's right column; 240 is narrower than any host gives
  // the panel today.
  for (final lang in labels.keys) {
    for (final width in [280.0, 240.0]) {
      testWidgets('O2 the panel at $width px, $lang: each label on one line',
          (tester) async {
        final c = PlanController(kits: const []);
        addTearDown(c.dispose);
        await tester.pumpWidget(MaterialApp(
            locale: Locale(lang),
            supportedLocales: planSupportedLocales,
            localizationsDelegates: planLocalizationsDelegates,
            home: Scaffold(
                body: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                        width: width, child: PlanPagePanel(controller: c))))));
        await tester.pump();
        expectOneLine(tester, lang);
      });
    }

    testWidgets('O2 the editor at 1440x900, $lang: each label on one line',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = PlanController(kits: const []);
      addTearDown(c.dispose);
      await tester.pumpWidget(MaterialApp(
          locale: Locale(lang),
          supportedLocales: planSupportedLocales,
          localizationsDelegates: planLocalizationsDelegates,
          home: Scaffold(body: PlanEditor(controller: c))));
      await tester.pump();
      await tester.pump();
      expect(tester.getSize(find.byKey(const Key('chrome-right'))).width, 280);
      expectOneLine(tester, lang);
    });
  }
}
