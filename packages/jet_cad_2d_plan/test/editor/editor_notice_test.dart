// Spec 3a C1.2, Review Focus 2 (the plan half): PlanEditor's status line
// keeps today's composition (planner_shell.dart:989-1011): the tool's
// label, then " — n selected" with a selection, then " — <notice>", the
// notice worded when the line is read, so a language switch re-words it at
// once, with no stale English.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/editor_host.dart' show editorPlanJson;
import '../support/mark_kit.dart';
import '../support/notice_kit.dart';

Widget app(PlanController c, Locale locale) => MaterialApp(
    locale: locale,
    supportedLocales: planSupportedLocales,
    localizationsDelegates: planLocalizationsDelegates,
    home: Scaffold(body: PlanEditor(controller: c)));

String status(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('status-text'))).data!;

Future<PlanController> pump(WidgetTester tester) async {
  final c = PlanController(kits: [markKit(), noteKit], json: editorPlanJson());
  addTearDown(c.dispose);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(app(c, const Locale('en')));
  await tester.pump();
  return c;
}

void main() {
  testWidgets(
      'TN-status the label, the selection, then the notice; no notice, no '
      'dash (M-TN-order)', (tester) async {
    final c = await pump(tester);
    expect(c.selectTool(noteToolId), isTrue);
    await tester.pump();
    expect(status(tester), 'Mark');
    final note = c.toolFor(noteToolId)! as NoteTool;
    note.said.value = busy('Mark 1');
    await tester.pump();
    expect(status(tester), 'Mark — Already marked: Mark 1');
    final marks = c.catalog.objectsOf<MarkCross>(c.document);
    expect(marks, hasLength(2), reason: 'premise: the fixture\'s marks');
    c.selection.replace([for (final h in marks) SelectionKey.root(h)]);
    await tester.pump();
    // M-TN-order: the notice before the selection.
    expect(status(tester), 'Mark — 2 selected — Already marked: Mark 1');
    note.said.value = null;
    await tester.pump();
    expect(status(tester), 'Mark — 2 selected');
  });

  testWidgets(
      'TN-relocale (Review Focus 2) a language switch re-words a shown '
      'notice at once, in the new language, with its name; and back '
      '(M-TN-relocale)', (tester) async {
    final c = await pump(tester);
    expect(c.selectTool(noteToolId), isTrue);
    (c.toolFor(noteToolId)! as NoteTool).said.value = busy('Mark 1');
    await tester.pump();
    expect(status(tester), 'Mark — Already marked: Mark 1');
    await tester.pumpWidget(app(c, const Locale('tr')));
    await tester.pump();
    // M-TN-relocale: the editor words the notice once and keeps the text.
    expect(status(tester), 'İşaret — Zaten işaretli: Mark 1');
    await tester.pumpWidget(app(c, const Locale('en')));
    await tester.pump();
    expect(status(tester), 'Mark — Already marked: Mark 1');
  });
}
