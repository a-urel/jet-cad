// Spec Q0 N1, N2, R-4 (M-Q0-e): a controller's empty plan is settled by
// the language of the first view that shows it -- as if made so: no undo
// step, clean, nothing on `serviceLayoutChanges` -- unless something read
// or edited it first; `newPlan()` takes the language a view last reported;
// a loaded plan is never settled. The UI language differs from the page's
// separator wherever it could leak in (the fixture rule).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:jet_cad_floor_plan/src/l10n/localizations.dart';
import 'package:jet_cad_floor_plan/src/parametric/catalog.dart';
import 'package:jet_cad_floor_plan/src/parametric/room.dart';

import '../decimal_separator_test.dart' show q0Plan;
import '../support/room_fixture.dart' show labelsOf, textOf;

/// [c] shown in a [FloorPlanView] under [locale]; the same tree shape for
/// every call, so a second call with another controller is a swap.
Future<void> show(
    WidgetTester tester, FloorPlanController c, Locale locale) async {
  await tester.pumpWidget(MaterialApp(
      locale: locale,
      supportedLocales: floorPlanSupportedLocales,
      localizationsDelegates: floorPlanLocalizationsDelegates,
      home: Scaffold(body: FloorPlanView(controller: c))));
  await tester.pump();
}

/// [doc]'s page separator.
DecimalSeparator separatorOf(DraftDocument doc) =>
    doc.components.get<PageComponent>(doc.rootHandle)!.decimalSeparator;

/// The separator [json]'s page prints.
DecimalSeparator separatorIn(String json) =>
    separatorOf(DraftDocumentCodec.decodeString(json,
        measurer: const InsertionPointMeasurer(),
        registerComponents: registerAppComponents,
        diagnostics: <Diagnostic>[]));

/// What the Page panel's control shows selected.
Set<DecimalSeparator> panelShows(WidgetTester tester) => tester
    .widget<SegmentedButton<DecimalSeparator>>(
        find.byKey(const Key('page-decimal-separator')))
    .selected;

/// The fixture's plan, encoded: cm at 1:20, its origin off zero, a turned
/// box off the origin with the room `Kitchen` (12.37 m²) and a turned
/// dimension (345.7), all `point`.
String q0Json() => DraftDocumentCodec.encodeToString(q0Plan().plan.doc);

/// A design edit before any view: a layer added, one command.
void addLayer(FloorPlanController c) {
  final doc = c.activeDocument;
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
      'NS1 the constructor\'s empty plan, shown in Turkish, prints comma as '
      'if made so: no undo step, clean, nothing on serviceLayoutChanges; a '
      'switch to English keeps it; newPlan() in English is point and stays '
      'point when the view turns Turkish; newPlan() in Turkish is comma',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final c = FloorPlanController();
    addTearDown(c.dispose);
    var layoutFired = 0;
    c.serviceLayoutChanges.addListener(() => layoutFired++);
    final made = c.activeDocument;
    expect(separatorOf(made), DecimalSeparator.point,
        reason: 'premise: unsettled, the engine\'s default');

    await show(tester, c, const Locale('tr'));
    expect(identical(c.activeDocument, made), isTrue,
        reason: 'the plan is settled in place, not replaced');
    expect(separatorOf(made), DecimalSeparator.comma);
    expect(panelShows(tester), {DecimalSeparator.comma},
        reason: 'the shell is built over the settled page');
    expect(made.commands.undoDepth, 0);
    expect(made.commands.canRedo, isFalse);
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
    expect(layoutFired, 0);
    // The change is heard a microtask later: still no step and clean.
    await tester.pump();
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
    expect(layoutFired, 0);
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
    expect(separatorOf(c.activeDocument), DecimalSeparator.comma);

    // newPlan() takes the last language reported: English, point, settled
    // at once.
    c.newPlan();
    await tester.pump();
    final english = c.activeDocument;
    expect(identical(english, made), isFalse, reason: 'premise: a new plan');
    expect(separatorOf(english), DecimalSeparator.point);
    await show(tester, c, const Locale('tr'));
    expect(identical(c.activeDocument, english), isTrue);
    expect(separatorOf(english), DecimalSeparator.point,
        reason: 'settled when made: a later language does not change it');
    expect(panelShows(tester), {DecimalSeparator.point});

    // And in Turkish, comma, with no undo step and clean.
    c.newPlan();
    await tester.pump();
    await tester.pump();
    expect(separatorOf(c.activeDocument), DecimalSeparator.comma);
    expect(panelShows(tester), {DecimalSeparator.comma});
    expect(c.activeDocument.commands.undoDepth, 0);
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
    expect(layoutFired, 0);
  });

  testWidgets(
      'NS2 a view handed another controller reports its language to it: the '
      'second empty plan, shown by the same view in German, is comma',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final a = FloorPlanController();
    final b = FloorPlanController();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await show(tester, a, const Locale('de'));
    expect(separatorOf(a.activeDocument), DecimalSeparator.comma);
    final view = tester.state(find.byType(FloorPlanView));
    expect(separatorOf(b.activeDocument), DecimalSeparator.point,
        reason: 'premise: b is unsettled');

    await show(tester, b, const Locale('de'));
    expect(identical(tester.state(find.byType(FloorPlanView)), view), isTrue,
        reason: 'premise: the same view, its controller swapped');
    expect(separatorOf(b.activeDocument), DecimalSeparator.comma);
    expect(b.activeDocument.commands.undoDepth, 0);
    expect(b.dirty.value, isFalse);
    expect(panelShows(tester), {DecimalSeparator.comma});
  });

  testWidgets(
      'NS3 a loaded plan is never settled (N2): by the constructor or by '
      'load(), a point plan shown in Turkish stays point, its texts with .',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final json = q0Json();
    expect(separatorIn(json), DecimalSeparator.point, reason: 'premise');

    final byJson = FloorPlanController(json: json);
    addTearDown(byJson.dispose);
    await show(tester, byJson, const Locale('tr'));
    final doc = byJson.activeDocument;
    expect(separatorOf(doc), DecimalSeparator.point);
    final room = doc.components.withComponent<RoomParams>().single;
    expect(textOf(doc, labelsOf(doc, room)[1]), '12.37 m²');
    expect(byJson.designJson(), json, reason: 'the bytes are the file\'s');

    final byLoad = FloorPlanController();
    addTearDown(byLoad.dispose);
    byLoad.load(json);
    await show(tester, byLoad, const Locale('tr'));
    expect(separatorOf(byLoad.activeDocument), DecimalSeparator.point);
    expect(byLoad.dirty.value, isFalse);
    expect(byLoad.designJson(), json);
  });

  testWidgets(
      'NS4 an empty plan touched before any view stays point in Turkish '
      '(N2): read by designJson(); edited; edited and undone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final read = FloorPlanController();
    addTearDown(read.dispose);
    final stored = read.designJson();
    read.markSaved();
    await show(tester, read, const Locale('tr'));
    expect(separatorOf(read.activeDocument), DecimalSeparator.point);
    expect(read.designJson(), stored, reason: 'the stored bytes still hold');
    expect(read.dirty.value, isFalse);

    final edited = FloorPlanController();
    addTearDown(edited.dispose);
    addLayer(edited);
    await show(tester, edited, const Locale('tr'));
    expect(separatorOf(edited.activeDocument), DecimalSeparator.point);
    expect(edited.activeDocument.commands.undoDepth, 1,
        reason: 'the edit\'s step only');

    final undone = FloorPlanController();
    addTearDown(undone.dispose);
    addLayer(undone);
    undone.undo();
    expect(undone.activeDocument.commands.canRedo, isTrue,
        reason: 'premise: an undone edit');
    await show(tester, undone, const Locale('tr'));
    expect(separatorOf(undone.activeDocument), DecimalSeparator.point);
    expect(undone.activeDocument.commands.canRedo, isTrue,
        reason: 'its Redo is kept');
  });

  testWidgets(
      'NS5 shown first in the selection mode: the design settles to comma, '
      'the service copy taken before keeps its page, nothing fires',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final c = FloorPlanController();
    addTearDown(c.dispose);
    var layoutFired = 0;
    c.serviceLayoutChanges.addListener(() => layoutFired++);
    c.setMode(FloorPlanMode.selection);
    final copy = c.activeDocument;
    await show(tester, c, const Locale('tr'));
    await tester.pump();
    expect(identical(c.activeDocument, copy), isTrue);
    expect(separatorOf(copy), DecimalSeparator.point,
        reason: 'a copy taken before is not changed');
    expect(layoutFired, 0);
    expect(c.dirty.value, isFalse);
    expect(c.serviceEdited, isFalse);
    expect(separatorIn(c.designJson()), DecimalSeparator.comma);
    c.setMode(FloorPlanMode.design);
    await tester.pump();
    expect(separatorOf(c.activeDocument), DecimalSeparator.comma);
    expect(c.activeDocument.commands.undoDepth, 0);
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
  });
}
