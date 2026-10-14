// Spec 2a P2 (newPlan: "default: the locale's, as today"), today's Q0 N1,
// N2: the constructor's empty plan is settled by the first locale reported
// -- as if made so: no undo step, clean -- unless something read or edited
// it first; newPlan() takes the locale last reported; a loaded plan is
// never settled. Ported from jet_cad_floor_plan's
// new_plan_separator_test.dart (NS1, NS3, NS4, NS6, NS8, NS9) with the view
// replaced by the report it makes (`reportLocale`); the Page panel's and
// the service layout's assertions are left out (Task 18; 2b).
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/harness.dart';
import '../support/test_kit.dart';

DecimalSeparator separatorOf(DraftDocument doc) =>
    doc.components.get<PageComponent>(doc.rootHandle)!.decimalSeparator;

/// A design edit before any report: a layer added, one command.
void addLayer(PlanController c) {
  final doc = c.document;
  final zero = doc.tables.layers[ReservedHandles.layerZero]!;
  doc.commands.execute(AddLayerCommand(LayerRecord(
      handle: doc.handleSeed.next(),
      name: 'Bar',
      color: const IndexedColor(5),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency,
      visible: true,
      locked: false)));
}

void main() {
  testWidgets(
      "NS1 the constructor's empty plan, reported Turkish, prints comma as if "
      'made so: no undo step, clean; English keeps it; newPlan() in English '
      'is point and stays point when Turkish comes; newPlan() in Turkish is '
      'comma', (tester) async {
    final c = controllerFor(kits: [testKit()]);
    final made = c.document;
    expect(separatorOf(made), DecimalSeparator.point,
        reason: "premise: unsettled, the engine's default");
    c.reportLocale(const Locale('tr'));
    expect(identical(c.document, made), isTrue,
        reason: 'the plan is settled in place, not replaced');
    expect(separatorOf(made), DecimalSeparator.comma);
    // M-NS1: the settle's step not cleared.
    expect(made.commands.undoDepth, 0);
    expect(made.commands.canRedo, isFalse);
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
    await tester.pump();
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
    addLayer(c);
    await tester.pump();
    expect(c.dirty.value, isTrue, reason: 'premise: an edit');
    c.undo();
    await tester.pump();
    expect(c.dirty.value, isFalse, reason: 'the save point moved with it');

    c.reportLocale(const Locale('en'));
    expect(separatorOf(c.document), DecimalSeparator.comma);

    c.newPlan();
    await tester.pump();
    final english = c.document;
    expect(identical(english, made), isFalse, reason: 'premise: a new plan');
    expect(separatorOf(english), DecimalSeparator.point);
    c.reportLocale(const Locale('tr'));
    expect(identical(c.document, english), isTrue);
    expect(separatorOf(english), DecimalSeparator.point,
        reason: 'settled when made: a later language does not change it');

    c.newPlan();
    await tester.pump();
    await tester.pump();
    expect(separatorOf(c.document), DecimalSeparator.comma);
    expect(c.document.commands.undoDepth, 0);
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
  });

  testWidgets(
      'NS3 a loaded plan is never settled (N2): by the constructor or by '
      'load(), a point plan reported Turkish stays point', (tester) async {
    final json = slabPlanText();
    final byJson = controllerFor(kits: [testKit()], json: json);
    byJson.reportLocale(const Locale('tr'));
    // M-NS3: a loaded plan made unsettled.
    expect(separatorOf(byJson.document), DecimalSeparator.point);
    expect(byJson.save(), json, reason: "the bytes are the file's");

    final byLoad = controllerFor(kits: [testKit()]);
    byLoad.load(json);
    byLoad.reportLocale(const Locale('tr'));
    expect(separatorOf(byLoad.document), DecimalSeparator.point);
    expect(byLoad.dirty.value, isFalse);
    expect(byLoad.save(), json);
    await tester.pump();
  });

  testWidgets(
      'NS4 an empty plan touched before any report stays point in Turkish '
      '(N2): read by save(); edited; edited and undone', (tester) async {
    final read = controllerFor(kits: [testKit()]);
    final stored = read.save();
    read.markSaved();
    // M-NS4: save() leaves the plan unsettled.
    read.reportLocale(const Locale('tr'));
    expect(separatorOf(read.document), DecimalSeparator.point);
    expect(read.save(), stored, reason: 'the stored bytes still hold');
    expect(read.dirty.value, isFalse);

    final edited = controllerFor(kits: [testKit()]);
    addLayer(edited);
    edited.reportLocale(const Locale('tr'));
    expect(separatorOf(edited.document), DecimalSeparator.point);
    expect(edited.document.commands.undoDepth, 1,
        reason: "the edit's step only");

    final undone = controllerFor(kits: [testKit()]);
    addLayer(undone);
    undone.undo();
    expect(undone.document.commands.canRedo, isTrue,
        reason: 'premise: an undone edit');
    undone.reportLocale(const Locale('tr'));
    expect(separatorOf(undone.document), DecimalSeparator.point);
    expect(undone.document.commands.canRedo, isTrue,
        reason: 'its Redo is kept');
    await tester.pump();
  });

  testWidgets(
      "NS6 the constructor's empty plan reported first in English is settled "
      'at point: a later Turkish leaves it point, no undo step, clean',
      (tester) async {
    final c = controllerFor(kits: [testKit()]);
    final made = c.document;
    c.reportLocale(const Locale('en'));
    expect(separatorOf(made), DecimalSeparator.point);
    // M-NS6: the first report does not settle the plan.
    c.reportLocale(const Locale('tr'));
    await tester.pump();
    expect(identical(c.document, made), isTrue);
    expect(separatorOf(made), DecimalSeparator.point,
        reason: 'settled by the first language, already point (N2)');
    expect(made.commands.undoDepth, 0);
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
  });

  testWidgets(
      "NS8 newPlan() before any report is unsettled, as the constructor's "
      'plan is: reported Turkish it is comma, no step, clean', (tester) async {
    final c = controllerFor(kits: [testKit()]);
    final first = c.document;
    // M-NS8: newPlan always settled.
    c.newPlan();
    expect(identical(c.document, first), isFalse,
        reason: 'premise: a new plan');
    expect(separatorOf(c.document), DecimalSeparator.point);
    c.reportLocale(const Locale('tr'));
    await tester.pump();
    expect(separatorOf(c.document), DecimalSeparator.comma);
    expect(c.document.commands.undoDepth, 0);
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
  });

  testWidgets(
      'NS9 a plan loaded over the unsettled one and edited once before any '
      "report keeps point and its step (F-4: state ids are per history)",
      (tester) async {
    final c = controllerFor(kits: [testKit()]);
    c.load(slabPlanText());
    addLayer(c);
    expect(c.document.commands.undoDepth, 1, reason: 'premise');
    // M-NS9: the unsettled plan kept across a load and the document check
    // dropped from _untouched.
    c.reportLocale(const Locale('tr'));
    await tester.pump();
    expect(separatorOf(c.document), DecimalSeparator.point);
    expect(c.document.commands.undoDepth, 1, reason: "the edit's step is kept");
  });

  testWidgets(
      'NS10 newPlan(decimalSeparator:) prints it and is settled; another '
      'character is an ArgumentError and changes nothing', (tester) async {
    final c = controllerFor(kits: [testKit()]);
    // M-NS10: the argument ignored.
    c.newPlan(decimalSeparator: ',');
    final comma = c.document;
    expect(separatorOf(comma), DecimalSeparator.comma);
    c.reportLocale(const Locale('en'));
    expect(separatorOf(comma), DecimalSeparator.comma, reason: 'settled');
    expect(() => c.newPlan(decimalSeparator: ';'), throwsArgumentError);
    expect(c.document, same(comma));
    c.newPlan(decimalSeparator: '.');
    expect(separatorOf(c.document), DecimalSeparator.point);
    await tester.pump();
  });
}
