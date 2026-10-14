// Spec Q0 N1, N2, R-4 through a view (2a spec P2: newPlan's "default: the
// locale's, as today"): what Task 8 could not port without one (controller
// ruling R-m). Ported from jet_cad_floor_plan/test/host/
// new_plan_separator_test.dart: NS2 whole (a view handed another controller
// reports its language to it), and NS1 and NS6 re-run as the source runs
// them, through a PlanEditor, with the Page panel's `panelShows` assertions
// Task 8 left out. NS3, NS4, NS8 and NS9 assert nothing of the panel (NS3's
// room label is sub-project 3's); the service layout's lines are 2b's.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/editor/plan_editor.dart';
import 'package:jet_cad_2d_plan/src/l10n/localizations.dart';

/// [c] shown in a [PlanEditor] under [locale]; the same tree shape for
/// every call, so a second call with another controller is a swap.
Future<void> show(WidgetTester tester, PlanController c, Locale locale) async {
  await tester.pumpWidget(MaterialApp(
      locale: locale,
      supportedLocales: planSupportedLocales,
      localizationsDelegates: planLocalizationsDelegates,
      home: Scaffold(body: PlanEditor(controller: c))));
  await tester.pump();
}

/// [doc]'s page separator.
DecimalSeparator separatorOf(DraftDocument doc) =>
    doc.components.get<PageComponent>(doc.rootHandle)!.decimalSeparator;

/// What the Page panel's control shows selected.
Set<DecimalSeparator> panelShows(WidgetTester tester) => tester
    .widget<SegmentedButton<DecimalSeparator>>(
        find.byKey(const Key('page-decimal-separator')))
    .selected;

/// A design edit before any view: a layer added, one command.
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
      'NS6 the constructor\'s empty plan shown first in English is settled '
      'at point: a later Turkish view leaves it point, with no undo step '
      'and clean (Task 4 review)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final c = PlanController(kits: const []);
    addTearDown(c.dispose);
    final made = c.document;
    await show(tester, c, const Locale('en'));
    expect(separatorOf(made), DecimalSeparator.point);
    await show(tester, c, const Locale('tr'));
    await tester.pump();
    expect(identical(c.document, made), isTrue);
    expect(separatorOf(made), DecimalSeparator.point,
        reason: 'settled by the first language, already point (N2)');
    expect(panelShows(tester), {DecimalSeparator.point});
    expect(made.commands.undoDepth, 0);
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
  });

  testWidgets(
      'NS1 the constructor\'s empty plan, shown in Turkish, prints comma as '
      'if made so: no undo step, clean; a switch to English keeps it; '
      'newPlan() in English is point and stays point when the view turns '
      'Turkish; newPlan() in Turkish is comma', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final c = PlanController(kits: const []);
    addTearDown(c.dispose);
    final made = c.document;
    expect(separatorOf(made), DecimalSeparator.point,
        reason: 'premise: unsettled, the engine\'s default');

    await show(tester, c, const Locale('tr'));
    expect(identical(c.document, made), isTrue,
        reason: 'the plan is settled in place, not replaced');
    expect(separatorOf(made), DecimalSeparator.comma);
    expect(panelShows(tester), {DecimalSeparator.comma},
        reason: 'the shell is built over the settled page');
    expect(made.commands.undoDepth, 0);
    expect(made.commands.canRedo, isFalse);
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
    // The change is heard a microtask later: still no step and clean.
    await tester.pump();
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
    // The settled state is the save point: an edit is dirty, its Undo is
    // clean again.
    addLayer(c);
    await tester.pump();
    expect(c.dirty.value, isTrue, reason: 'premise: an edit');
    c.undo();
    await tester.pump();
    expect(c.dirty.value, isFalse, reason: 'the save point moved with it');

    // English now: the settled plan is not converted (N2).
    await show(tester, c, const Locale('en'));
    expect(separatorOf(c.document), DecimalSeparator.comma);

    // newPlan() takes the last language reported: English, point, settled
    // at once.
    c.newPlan();
    await tester.pump();
    final english = c.document;
    expect(identical(english, made), isFalse, reason: 'premise: a new plan');
    expect(separatorOf(english), DecimalSeparator.point);
    await show(tester, c, const Locale('tr'));
    expect(identical(c.document, english), isTrue);
    expect(separatorOf(english), DecimalSeparator.point,
        reason: 'settled when made: a later language does not change it');
    expect(panelShows(tester), {DecimalSeparator.point});

    // And in Turkish, comma, with no undo step and clean.
    c.newPlan();
    await tester.pump();
    await tester.pump();
    expect(separatorOf(c.document), DecimalSeparator.comma);
    expect(panelShows(tester), {DecimalSeparator.comma});
    expect(c.document.commands.undoDepth, 0);
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
  });

  testWidgets(
      'NS2 a view handed another controller reports its language to it: the '
      'second empty plan, shown by the same view in German, is comma',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final a = PlanController(kits: const []);
    final b = PlanController(kits: const []);
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await show(tester, a, const Locale('de'));
    expect(separatorOf(a.document), DecimalSeparator.comma);
    final view = tester.state(find.byType(PlanEditor));
    expect(separatorOf(b.document), DecimalSeparator.point,
        reason: 'premise: b is unsettled');

    await show(tester, b, const Locale('de'));
    expect(identical(tester.state(find.byType(PlanEditor)), view), isTrue,
        reason: 'premise: the same view, its controller swapped');
    expect(separatorOf(b.document), DecimalSeparator.comma);
    expect(b.document.commands.undoDepth, 0);
    expect(b.dirty.value, isFalse);
    expect(panelShows(tester), {DecimalSeparator.comma});
  });
}
