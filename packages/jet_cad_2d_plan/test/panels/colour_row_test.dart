// Ported from jet_cad_floor_plan/test/colors/color_picker_test.dart; assertions unchanged.
//
// Plan colours spec PC-8, PC-9 and PC-10, over the property panel's colour
// row (spec 2a P3, "Colour"): nine swatches, None and the palette's eight
// hues, set the colour of every selected object whose type has a colour
// target in one undo step labelled Colour; read-only while the permissions
// refuse `recolor` or the document's permissions refuse the edit; its words
// in Turkish; its swatches as the canvas shows the hues.
//
// Today's rooms A and B become two boxes of the box kit: A at
// (7010.25, 3020.5) in a group turned 0.61 rad, B at (7400.75, 3120.25)
// unturned; today's wall becomes a plain line. The hues under test are
// `teal` and `purple`, never the first of the palette, and `magenta`, a
// name no release knows. CP2 (tint pixels) is the room's (sub-project 3);
// CP7 to CP12 are tables (2b Task 10): placed units, three of the fixture's
// `tableSymbol(seats: 4)` labelled 1, 2 and 7.
import 'dart:convert' show jsonEncode;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show SelectionKey, darkCanvasTone, kDarkCanvasPaper;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanSwatch;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/chrome/icon_button.dart' show PlanTooltip;
import 'package:jet_cad_2d_plan/src/panels/colour_row.dart';
import 'package:jet_cad_2d_plan/src/units/unit_components.dart' show UnitColour;
import 'package:jet_cad_2d_plan/src/units/unit_index.dart' show UnitIndex;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/panel_kits.dart';
import '../support/service_fixture.dart' show serviceFixture;
import '../support/test_kit.dart' show unitKit;
import '../support/unit_fixtures.dart'
    show addUnitLabel, fxKit, placeAt, tableSymbol;

Finder swatch(String name) => find.byKey(Key('color-swatch-$name'));
Finder get picker => find.byKey(const Key('color-picker'));

/// The Semantics of swatch [name] (the outermost below its key that carries
/// the label).
Semantics semanticsOf(WidgetTester tester, String name) =>
    tester.widget<Semantics>(find
        .descendant(
            of: swatch(name),
            matching: find.byWidgetPredicate(
                (w) => w is Semantics && w.properties.label != null))
        .first);

/// The tooltip text of swatch [name].
String tooltipOf(WidgetTester tester, String name) => tester
    .widget<PlanTooltip>(
        find.descendant(of: swatch(name), matching: find.byType(PlanTooltip)))
    .message;

/// The marked swatch's name, or null for none.
String? marked(WidgetTester tester) {
  final hits = <String>[
    for (final n in ['none', for (final c in PlanSwatch.values) c.name])
      if (semanticsOf(tester, n).properties.selected ?? false) n,
  ];
  expect(hits.length, lessThanOrEqualTo(1), reason: 'at most one mark: $hits');
  return hits.isEmpty ? null : hits.single;
}

SelectionKey k(Handle h) => SelectionKey.root(h);

/// Entities sorted by handle: slot order is history, not state (06 D11).
/// floor_plan/test/support/wall_fixture.dart's `canon`.
String canon(DraftDocument d) {
  final j = DraftDocumentCodec.encode(d);
  j['entities'] = List<Map<String, Object?>>.from(j['entities']! as List)
    ..sort((a, b) => ((a['record']! as Map)['handle']! as int)
        .compareTo((b['record']! as Map)['handle']! as int));
  return jsonEncode(j);
}

/// The panel's plan.
typedef Boxes = ({
  PlanController c,
  DraftDocument doc,
  Handle a,
  Handle b,
  Handle line,
  Handle one,
  Handle two,
  Handle seven
});

/// Two boxes and a plain line over the box and disc kits: A (120 x 70) in a
/// group of its own turned 0.61 rad, B (90 x 60) at the identity, the line
/// on layer 0; three units of `tableSymbol(seats: 4)` labelled 1 (turned),
/// 2 (mirrored) and 7 (turned three quarters), off the origin. The history
/// cleared.
Boxes boxesPlan() {
  final c = boxController(kits: [boxKit, discKit, fxKit()]);
  final a = addBox(c, Vector2(7010.25, 3020.5),
      const BoxParams(120, 70, label: 'A', count: 2),
      turn: 0.61);
  final b = addBox(c, Vector2(7400.75, 3120.25),
      const BoxParams(90, 60, label: 'B', finish: BoxFinish.gloss));
  final add = addDrafted(c.document, EntityKind.line,
      linePayload(Vector2(7210.5, 3300.25), Vector2(7390.75, 3360.5)),
      layer: ReservedHandles.layerZero);
  c.document.commands.execute(add);
  Handle unit(String label, Vector2 at,
      {int quarterTurns = 0, bool mirrored = false}) {
    final h = placeAt(c.document, tableSymbol(seats: 4), at,
        quarterTurns: quarterTurns, mirrored: mirrored);
    addUnitLabel(c.document, h, label);
    return h;
  }

  final one = unit('1', Vector2(7210.25, 3150.5), quarterTurns: 1);
  final two = unit('2', Vector2(7050.75, 3400.25), mirrored: true);
  final seven = unit('7', Vector2(7600.5, 3300.75), quarterTurns: 3);
  c.document.commands.clearHistory();
  return (
    c: c,
    doc: c.document,
    a: a,
    b: b,
    line: add.record.handle,
    one: one,
    two: two,
    seven: seven
  );
}

BoxParams boxOf(DraftDocument doc, Handle h) =>
    doc.components.get<BoxParams>(h)!;

/// Today's `paint(doc, room, name)`: the box's colour set to [name], one
/// step.
void paint(DraftDocument doc, Handle box, String? name) => doc.commands.execute(
    SetComponentCommand<BoxParams>(box, boxOf(doc, box).withColour(name)));

/// The unit labelled [label]'s detail.
PlanUnitDetail detailOf(PlanController c, String label) =>
    c.unitDetails.singleWhere((d) => d.unit.label == label);

/// The unit labelled [label]'s colour as the host reads it.
PlanSwatch? colourOf(PlanController c, String label) =>
    detailOf(c, label).colour;

/// The stored `jetcad.unit_colour` of [unit].
UnitColour? storedOf(DraftDocument doc, Handle unit) =>
    doc.components.get<UnitColour>(unit);

/// The labels of the steps applied from now on.
List<String> appliedLabels(DraftDocument doc) {
  final labels = <String>[];
  final sub = doc.changes.listen((ch) {
    if (ch is CommandApplied) labels.add(ch.label);
  });
  addTearDown(sub.cancel);
  return labels;
}

/// The composition over [r]: the canvas and, on the right, the property
/// panel.
final class Rig {
  Rig._(this.tester, this.c);

  final WidgetTester tester;
  final PlanController c;

  /// Pumps the canvas and the panel over [r], with [permissions] and, when
  /// given, [locale] (with the plan library's delegates) and [theme].
  static Future<Rig> pump(WidgetTester tester, Boxes r,
      {PlanPermissions permissions = PlanPermissions.full,
      Locale? locale,
      ThemeData? theme}) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final c = r.c;
    c.permissions = permissions;
    // A fresh tree per pump, as today's capture key made it: a second rig
    // starts at its own theme, not animating from the first one's.
    await tester.pumpWidget(KeyedSubtree(
        key: GlobalKey(),
        child: MaterialApp(
            locale: locale,
            theme: theme,
            supportedLocales: planSupportedLocales,
            localizationsDelegates: planLocalizationsDelegates,
            home: Scaffold(
                body: Row(children: [
              Expanded(child: PlanCanvas(controller: c)),
              SizedBox(
                  width: 280,
                  child: SingleChildScrollView(
                      child: PlanPropertyPanel(controller: c))),
            ])))));
    await tester.pump();
    return Rig._(tester, c);
  }

  Future<void> select(List<Handle> hs) async {
    c.selection.replace([for (final h in hs) k(h)]);
    await tester.pump();
  }
}

void main() {
  testWidgets(
      'CP1 the Colour row shows for a selection holding a room, marks the '
      'common colour, and marks nothing for a mix or an unknown name',
      (tester) async {
    final r = boxesPlan();
    final doc = r.doc;
    final rig = await Rig.pump(tester, r);

    expect(picker, findsNothing, reason: 'nothing selected');
    await rig.select([r.line]);
    expect(picker, findsNothing, reason: 'a line alone');

    // While the Disc tool's settings show, even with a box selected.
    await rig.select([r.a]);
    expect(picker, findsOneWidget);
    r.c.selectTool('disc.draw');
    await tester.pump();
    expect(find.byKey(const Key('settings-disc.draw')), findsOneWidget,
        reason: 'the Disc tool is active');
    // Activating a tool clears the selection (PlanController.selectTool), so
    // the box is selected again under the active tool: the row's absence is
    // then the panel's own rule, not an empty selection's.
    await rig.select([r.a]);
    expect({...r.c.selection.keys}, {k(r.a)},
        reason: 'the box is selected under the Disc tool');
    expect(find.byKey(const Key('settings-disc.draw')), findsOneWidget,
        reason: 'the Disc tool is still active');
    expect(picker, findsNothing, reason: 'the Disc tool\'s settings show');
    r.c.selectTool('plan.select');
    await tester.pump();
    await rig.select([r.a]);

    expect(picker, findsOneWidget, reason: 'box A');
    expect(find.byKey(const Key('layer-picker')), findsOneWidget);
    expect(swatch('none'), findsOneWidget);
    for (final c in PlanSwatch.values) {
      expect(swatch(c.name), findsOneWidget, reason: c.name);
    }
    expect(marked(tester), 'none', reason: 'an uncoloured box');
    await rig.select([r.a, r.b]);
    expect(picker, findsOneWidget, reason: 'boxes A and B');
    expect(marked(tester), 'none', reason: 'two uncoloured boxes');
    await rig.select([r.a, r.line]);
    expect(picker, findsOneWidget, reason: 'box A and a line');
    expect(marked(tester), 'none');

    paint(doc, r.a, 'teal');
    await tester.pump();
    await rig.select([r.a]);
    expect(marked(tester), 'teal', reason: 'A is teal');
    await rig.select([r.a, r.b]);
    expect(marked(tester), isNull, reason: 'teal and none: mixed');
    // Two pumps: a box's colour draws nothing (a room's tint did), so no
    // frame is due when the change reaches the panel, a microtask later.
    paint(doc, r.b, 'teal');
    await tester.pump();
    await tester.pump();
    expect(marked(tester), 'teal', reason: 'both teal');
    paint(doc, r.b, 'purple');
    await tester.pump();
    await tester.pump();
    expect(marked(tester), isNull, reason: 'teal and purple: mixed');

    // A name this release does not know: no swatch is marked (Review Focus
    // 5), and the stored name is untouched.
    paint(doc, r.a, 'magenta');
    await rig.select([r.a]);
    expect(picker, findsOneWidget);
    expect(marked(tester), isNull, reason: 'magenta equals no swatch');
    expect(boxOf(doc, r.a).colour, 'magenta');
  });

  testWidgets(
      'CP3 a colour chosen twice is no undo step; with A teal and B purple '
      'a tap on teal changes B only (M-PC9-a, Review Focus 2)', (tester) async {
    final r = boxesPlan();
    final doc = r.doc;
    final rig = await Rig.pump(tester, r);

    await rig.select([r.a, r.b]);
    await tester.tap(swatch('teal'));
    await tester.pump();
    expect(doc.commands.undoDepth, 1);
    final after = canon(doc);
    final stateId = doc.commands.stateId;
    // The same swatch again, and a selection already all teal.
    await tester.tap(swatch('teal'));
    await tester.pump();
    await rig.select([r.a]);
    await tester.tap(swatch('teal'));
    await tester.pump();
    expect(doc.commands.undoDepth, 1, reason: 'no new step');
    expect(doc.commands.stateId, stateId);
    expect(canon(doc), after);
    // Undo takes it all the way back: it was one step.
    doc.commands.undo();
    await tester.pump();
    expect(doc.commands.canUndo, isFalse);

    // A teal, B purple: a tap on teal changes B only.
    paint(doc, r.a, 'teal');
    paint(doc, r.b, 'purple');
    await tester.pump();
    await rig.select([r.a, r.b]);
    final keys = [k(r.a), k(r.b)];
    final command = recolourCommand(r.c, keys, PlanSwatch.teal)!;
    expect(command, isA<CompoundCommand>());
    final sets = (command as CompoundCommand)
        .children
        .whereType<SetComponentCommand<BoxParams>>()
        .toList();
    expect(sets, hasLength(1), reason: 'one box changes');
    expect(sets.single.handle, r.b);
    expect(sets.single.value, boxOf(doc, r.b).withColour('teal'));
    expect(recolourCommand(r.c, [k(r.a)], PlanSwatch.teal), isNull);
    expect(recolourCommand(r.c, [k(r.line)], PlanSwatch.teal), isNull,
        reason: 'a line is no box');

    final a0 = boxOf(doc, r.a);
    final depth = doc.commands.undoDepth;
    await tester.tap(swatch('teal'));
    await tester.pump();
    expect(doc.commands.undoDepth, depth + 1);
    expect(identical(boxOf(doc, r.a), a0), isTrue, reason: 'A not rewritten');
    expect(boxOf(doc, r.b).colour, 'teal');

    // None clears every selected box, and only when one is coloured.
    await tester.tap(swatch('none'));
    await tester.pump();
    expect(boxOf(doc, r.a).colour, isNull);
    expect(boxOf(doc, r.b).colour, isNull);
    expect(doc.commands.undoDepth, depth + 2);
    await tester.tap(swatch('none'));
    await tester.pump();
    expect(doc.commands.undoDepth, depth + 2, reason: 'none, twice');
  });

  testWidgets(
      'CP4 read-only: the picker shows, marks, changes nothing, and says '
      'why (M-C13, M-PC9-b)', (tester) async {
    // The permissions refuse recolor.
    final r = boxesPlan();
    final doc = r.doc;
    final rig = await Rig.pump(tester, r,
        permissions: PlanPermissions.full.copyWith(recolor: false));
    const strings = PlanStringsEn();
    paint(doc, r.a, 'teal');
    await rig.select([r.a]);
    expect(picker, findsOneWidget);
    expect(marked(tester), 'teal');
    final before = canon(doc);
    final depth = doc.commands.undoDepth;
    await tester.tap(swatch('purple'));
    await tester.pump();
    await tester.tap(swatch('none'));
    await tester.pump();
    expect(canon(doc), before, reason: 'a tap changes nothing');
    expect(doc.commands.undoDepth, depth);
    expect(tooltipOf(tester, 'teal'), strings.colorRefused);
    expect(tooltipOf(tester, 'none'), strings.colorRefused);
    expect(semanticsOf(tester, 'teal').properties.enabled, isFalse);

    // The document's permissions refuse it (the editor's allow it).
    final r2 = boxesPlan();
    final rig2 = await Rig.pump(tester, r2);
    paint(r2.doc, r2.a, 'teal');
    r2.doc.commands.permissions = DraftPermissions.runtime;
    await rig2.select([r2.b]);
    await rig2.select([r2.a]);
    expect(picker, findsOneWidget);
    expect(marked(tester), 'teal');
    final before2 = canon(r2.doc);
    final depth2 = r2.doc.commands.undoDepth;
    await tester.tap(swatch('purple'));
    await tester.pump();
    expect(canon(r2.doc), before2);
    expect(r2.doc.commands.undoDepth, depth2);
    expect(tooltipOf(tester, 'purple'), strings.readOnlyDocument);
    expect(semanticsOf(tester, 'purple').properties.enabled, isFalse);
    r2.doc.commands.permissions = DraftPermissions.all;
    await rig2.select([r2.b]);
    await rig2.select([r2.a]);
    await tester.tap(swatch('purple'));
    await tester.pump();
    expect(boxOf(r2.doc, r2.a).colour, 'purple', reason: 'allowed again');

    // Components allowed, geometry refused: the box's edit capability.
    r2.doc.commands.permissions = const DraftPermissions(
        transform: true, components: true, geometry: false, structure: true);
    await rig2.select([r2.b]);
    await rig2.select([r2.a]);
    await tester.tap(swatch('teal'));
    await tester.pump();
    expect(boxOf(r2.doc, r2.a).colour, 'purple');
    expect(tooltipOf(tester, 'teal'), strings.readOnlyDocument);
  });

  testWidgets(
      'CP5 in Turkish the title, the swatches\' tooltips and labels and '
      'None speak Turkish', (tester) async {
    final r = boxesPlan();
    final rig = await Rig.pump(tester, r, locale: const Locale('tr'));
    await rig.select([r.a]);
    expect(find.descendant(of: picker, matching: find.text('Renk')),
        findsOneWidget);
    expect(tooltipOf(tester, 'teal'), 'Turkuaz');
    expect(semanticsOf(tester, 'teal').properties.label, 'Turkuaz');
    expect(tooltipOf(tester, 'none'), 'Yok');
    expect(semanticsOf(tester, 'none').properties.label, 'Yok');
    expect(tooltipOf(tester, 'purple'), 'Mor');
  });

  testWidgets(
      'CP6b the swatches are the canvas\'s hues: as the document has them on '
      'a light canvas, re-toned on a dark one (M-PC9-c)', (tester) async {
    Color fillOf(String name) => ((tester
            .widget<Container>(find
                .descendant(of: swatch(name), matching: find.byType(Container))
                .first)
            .decoration) as BoxDecoration)
        .color!;
    final r = boxesPlan();
    var rig = await Rig.pump(tester, r, theme: ThemeData.light());
    await rig.select([r.a]);
    expect(fillOf('teal').toARGB32(), 0xFF00897B);
    expect(fillOf('purple').toARGB32(), 0xFF8E24AA);

    final r2 = boxesPlan();
    rig = await Rig.pump(tester, r2, theme: ThemeData.dark());
    await rig.select([r2.a]);
    expect(fillOf('teal').toARGB32(),
        0xFF000000 | darkCanvasTone(0x00897B, kDarkCanvasPaper));
    expect(fillOf('purple').toARGB32(),
        0xFF000000 | darkCanvasTone(0x8E24AA, kDarkCanvasPaper));
    expect(fillOf('teal').toARGB32(), isNot(0xFF00897B));
  });

  test('CP6 the swatch is the canvas\'s hue, re-toned on a dark canvas', () {
    expect(swatchColor(0x00897B, null).toARGB32(), 0xFF00897B);
    expect(swatchColor(0x8E24AA, null).toARGB32(), 0xFF8E24AA);
    expect(swatchColor(0x00897B, kDarkCanvasPaper).toARGB32(),
        0xFF000000 | darkCanvasTone(0x00897B, kDarkCanvasPaper));
    expect(
        swatchColor(0x00897B, kDarkCanvasPaper).toARGB32(), isNot(0xFF00897B));
  });

  testWidgets(
      'CP7 a tap on teal with two units and a room selected: one undo step '
      'labelled Colour, the units\' details read teal, the room is teal, '
      'the others untouched; one Ctrl+Z takes all three back (M-C12 tables)',
      (tester) async {
    final r = boxesPlan();
    final c = r.c;
    final doc = r.doc;
    final rig = await Rig.pump(tester, r);
    final labels = appliedLabels(doc);
    for (final n in ['1', '2', '7']) {
      expect(colourOf(c, n), isNull, reason: 'premise: table $n');
    }
    await rig.select([r.one, r.two, r.a]);
    expect(picker, findsOneWidget);
    expect(marked(tester), 'none', reason: 'two bare tables and a bare room');
    final depth = doc.commands.undoDepth;

    await tester.tap(swatch('teal'));
    await tester.pump();
    expect(doc.commands.undoDepth, depth + 1, reason: 'one undo step');
    expect(labels, ['Colour']);
    expect(colourOf(c, '1'), PlanSwatch.teal);
    expect(colourOf(c, '2'), PlanSwatch.teal);
    expect(storedOf(doc, r.one), UnitColour(PlanSwatch.teal));
    expect(boxOf(doc, r.a).colour, 'teal');
    expect(colourOf(c, '7'), isNull, reason: 'an unselected table');
    expect(storedOf(doc, r.seven), isNull);
    expect(marked(tester), 'teal');

    await tester.tap(swatch('purple'));
    await tester.pump();
    expect(labels, ['Colour', 'Colour']);
    expect(colourOf(c, '1'), PlanSwatch.purple);
    expect(colourOf(c, '2'), PlanSwatch.purple);
    expect(boxOf(doc, r.a).colour, 'purple');
    expect(doc.commands.undoDepth, depth + 2);

    c.undo();
    await tester.pump();
    expect(colourOf(c, '1'), PlanSwatch.teal);
    expect(boxOf(doc, r.a).colour, 'teal');
    c.undo();
    await tester.pump();
    expect(doc.commands.undoDepth, depth);
    expect(colourOf(c, '1'), isNull);
    expect(colourOf(c, '2'), isNull);
    expect(storedOf(doc, r.one), isNull, reason: 'the component is gone');
    expect(boxOf(doc, r.a).colour, isNull);

    // None clears the tables, and a table already bare is no edit.
    await tester.tap(swatch('teal'));
    await tester.pump();
    final after = doc.commands.undoDepth;
    await rig.select([r.one, r.seven]);
    await tester.tap(swatch('none'));
    await tester.pump();
    expect(colourOf(c, '1'), isNull);
    expect(doc.commands.undoDepth, after + 1);
    await tester.tap(swatch('none'));
    await tester.pump();
    expect(doc.commands.undoDepth, after + 1, reason: 'none, twice');
    expect(recolourCommand(c, [k(r.seven)], null), isNull,
        reason: 'a bare table, none');
    expect(recolourCommand(c, [k(r.seven)], PlanSwatch.teal),
        isA<CompoundCommand>());
  });

  testWidgets(
      'CP8 marking: two teal tables mark teal; a teal table and a purple '
      'room mark nothing; a table with a kept payload marks nothing, alone '
      'or beside a bare table (M-PC9-t)', (tester) async {
    final r = boxesPlan();
    final c = r.c;
    final doc = r.doc;
    final rig = await Rig.pump(tester, r);
    expect(
        c.setUnitsColour({'1': PlanSwatch.teal, '2': PlanSwatch.teal}), isTrue);
    await rig.select([r.one, r.two]);
    expect(marked(tester), 'teal', reason: 'two teal tables');
    await rig.select([r.one]);
    expect(marked(tester), 'teal');

    paint(doc, r.a, 'purple');
    await rig.select([r.one, r.a]);
    expect(marked(tester), isNull, reason: 'a teal table and a purple room');
    await rig.select([r.one, r.seven]);
    expect(marked(tester), isNull, reason: 'a teal table and a bare one');

    // A payload of another shape is kept verbatim: it reads as no colour,
    // and as no colour that a bare table has either.
    doc.commands.execute(SetComponentCommand<UnitColour>(
        r.seven, UnitColour.fromJson(const {'color': 7})));
    expect(storedOf(doc, r.seven)!.isKept, isTrue, reason: 'premise');
    expect(colourOf(c, '7'), isNull);
    await rig.select([r.seven]);
    expect(picker, findsOneWidget);
    expect(marked(tester), isNull, reason: 'a kept payload marks no swatch');
    await rig.select([r.seven, r.two]);
    expect(marked(tester), isNull, reason: 'a kept payload and a teal table');
    // An unknown name marks nothing either.
    doc.commands.execute(SetComponentCommand<UnitColour>(
        r.two, UnitColour.fromJson(const {'color': 'magenta'})));
    await rig.select([r.two]);
    expect(marked(tester), isNull, reason: 'magenta equals no swatch');
    expect(storedOf(doc, r.two)!.name, 'magenta');

    // A tap replaces the kept payload; None removes it.
    await rig.select([r.seven, r.two]);
    await tester.tap(swatch('teal'));
    await tester.pump();
    expect(storedOf(doc, r.seven), UnitColour(PlanSwatch.teal));
    expect(storedOf(doc, r.two), UnitColour(PlanSwatch.teal));
    expect(marked(tester), 'teal');
    doc.commands.execute(SetComponentCommand<UnitColour>(
        r.seven, UnitColour.fromJson(const {'hue': 'teal'})));
    await rig.select([r.seven]);
    await tester.tap(swatch('none'));
    await tester.pump();
    expect(storedOf(doc, r.seven), isNull, reason: 'none drops a kept payload');
  });

  testWidgets(
      'CP9 unitsOnly: the row shows for a selected table and acts; with '
      'recolor false it shows read-only and says why', (tester) async {
    final r = boxesPlan();
    final c = r.c;
    final doc = r.doc;
    final rig =
        await Rig.pump(tester, r, permissions: PlanPermissions.unitsOnly);
    await rig.select([r.one, r.two]);
    expect(picker, findsOneWidget);
    expect(find.byKey(const Key('layer-picker')), findsNothing,
        reason: 'premise: unitsOnly has no layer picker');
    final labels = appliedLabels(doc);
    await tester.tap(swatch('purple'));
    await tester.pump();
    expect(labels, ['Colour']);
    expect(colourOf(c, '1'), PlanSwatch.purple);
    expect(colourOf(c, '2'), PlanSwatch.purple);
    expect(marked(tester), 'purple');

    c.permissions = PlanPermissions.unitsOnly.copyWith(recolor: false);
    await tester.pump();
    expect(picker, findsOneWidget, reason: 'read-only, still shown');
    expect(marked(tester), 'purple');
    final before = canon(doc);
    final depth = doc.commands.undoDepth;
    await tester.tap(swatch('teal'));
    await tester.pump();
    await tester.tap(swatch('none'));
    await tester.pump();
    expect(canon(doc), before);
    expect(doc.commands.undoDepth, depth);
    expect(colourOf(c, '1'), PlanSwatch.purple);
    expect(tooltipOf(tester, 'teal'), const PlanStringsEn().colorRefused);
    expect(semanticsOf(tester, 'teal').properties.enabled, isFalse);

    c.permissions = PlanPermissions.unitsOnly;
    await tester.pump();
    await tester.tap(swatch('teal'));
    await tester.pump();
    expect(colourOf(c, '1'), PlanSwatch.teal, reason: 'allowed again');
  });

  testWidgets(
      'CP10 permissions: without components the row is read-only for a '
      'table selection, with the readOnlyDocument tooltip; restored, it acts',
      (tester) async {
    final r = boxesPlan();
    final c = r.c;
    final doc = r.doc;
    final rig = await Rig.pump(tester, r);
    expect(c.setUnitColour('1', PlanSwatch.teal), isTrue);
    await rig.select([r.one]);
    expect(picker, findsOneWidget);
    doc.commands.permissions = const DraftPermissions(
        transform: true, components: false, geometry: true, structure: true);
    await rig.select([r.two]);
    await rig.select([r.one]);
    expect(picker, findsOneWidget, reason: 'read-only, still shown');
    expect(marked(tester), 'teal');
    final before = canon(doc);
    final depth = doc.commands.undoDepth;
    await tester.tap(swatch('purple'));
    await tester.pump();
    await tester.tap(swatch('none'));
    await tester.pump();
    expect(canon(doc), before);
    expect(doc.commands.undoDepth, depth);
    expect(tooltipOf(tester, 'purple'), const PlanStringsEn().readOnlyDocument);
    expect(semanticsOf(tester, 'purple').properties.enabled, isFalse);

    doc.commands.permissions = DraftPermissions.all;
    await rig.select([r.two]);
    await rig.select([r.one]);
    await tester.tap(swatch('purple'));
    await tester.pump();
    expect(colourOf(c, '1'), PlanSwatch.purple, reason: 'allowed again');
  });

  testWidgets(
      'CP11 a table selected under the active Disc tool: the tool is still '
      'the disc, the selection holds the table, and the Colour row is '
      'absent (M-PC9-tool)', (tester) async {
    final r = boxesPlan();
    final c = r.c;
    final rig = await Rig.pump(tester, r);
    await rig.select([r.one]);
    expect(picker, findsOneWidget, reason: 'the select tool: the row shows');

    expect(c.selectTool('disc.draw'), isTrue);
    await tester.pump();
    expect(c.activeTool.value, 'disc.draw');
    expect(find.byKey(const Key('settings-disc.draw')), findsOneWidget,
        reason: 'the Disc tool\'s settings show');
    // Activating a tool clears the selection; select the table afterwards.
    c.select({'1'});
    await tester.pump();
    expect({...c.selection.keys}, {k(r.one)},
        reason: 'premise: the table is selected');
    expect(c.activeTool.value, 'disc.draw',
        reason: 'premise: selecting did not leave the Disc tool');
    expect(picker, findsNothing, reason: 'no Colour row under a tool');

    expect(c.selectTool('plan.select'), isTrue);
    await tester.pump();
    c.select({'1'});
    await tester.pump();
    expect(picker, findsOneWidget, reason: 'back on the select tool');
  });

  testWidgets(
      'CP12 hover notifications over a selection of two tables and a room '
      'rebuild the panel and the Colour row without surveying the document '
      '(14a review R-7; the panel keeps its survey per document change)',
      (tester) async {
    final r = boxesPlan();
    final c = r.c;
    final rig = await Rig.pump(tester, r);
    await rig.select([r.one, r.two, r.a]);
    expect(picker, findsOneWidget);
    final keys = [k(r.one), k(r.seven), k(r.a)];
    // Warm: one hover so any first-use work is behind us.
    c.selection.setHover(keys.first);
    await tester.pump();
    final before = UnitIndex.debugBuilds;
    for (final key in [...keys, null, ...keys.reversed, null]) {
      c.selection.setHover(key);
      await tester.pump();
      expect(picker, findsOneWidget);
    }
    expect(UnitIndex.debugBuilds, before,
        reason: 'a hover rebuild rescanned the document');
    // The picker's own reads are survey-free, empty selection included.
    pickedColours(c, const []);
    pickedColours(c, keys);
    recolourCommand(c, keys, PlanSwatch.teal);
    expect(UnitIndex.debugBuilds, before);
    // And they agree with the index: the placed-unit check is its rule.
    expect(pickedColours(c, keys), hasLength(3));
    bool isTable(Handle h) => c.unitIndex[h]?.generated == false;
    for (final h in [r.one, r.two, r.seven]) {
      expect(isTable(h), isTrue, reason: h.toHex());
    }
    expect(isTable(r.a), isFalse);
    expect(isTable(r.doc.rootHandle), isFalse);
    expect(isTable(const Handle(0x7FFFFFF)), isFalse, reason: 'no node');
  });

  testWidgets(
      'CP13 a locked unit (its kit missing) is no colour target: selected, '
      'no picker shows and recolourCommand is null; with its kit loaded the '
      'same unit is one (M-UW14)', (tester) async {
    final f = serviceFixture();
    final locked = PlanController(kits: const [], json: f.json);
    addTearDown(locked.dispose);
    final open = PlanController(kits: [unitKit()], json: f.json);
    addTearDown(open.dispose);
    expect(open.isLocked(f.table), isFalse, reason: 'premise');
    expect(unitColourTargets(open, [k(f.table)]), [f.table],
        reason: 'premise: the control');
    expect(locked.isLocked(f.table), isTrue, reason: 'premise');
    expect(locked.unitIndex[f.table]?.generated, isFalse, reason: 'premise');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: PlanPropertyPanel(controller: locked)))));
    locked.selection.replace([k(f.table)]);
    await tester.pump();
    // M-UW14: `!c.isLocked(h)` deleted from unitColourTargets.
    expect(unitColourTargets(locked, [k(f.table)]), isEmpty);
    expect(picker, findsNothing);
    expect(recolourCommand(locked, [k(f.table)], PlanSwatch.teal), isNull);
  });

  test(
      'CP14 a generated seat is no colour target through unitColourTargets, '
      'its placed table beside it is (M-UW15)', () {
    final f = serviceFixture();
    final c = PlanController(kits: [unitKit()], json: f.json);
    addTearDown(c.dispose);
    final seat = f.seatsA.first;
    expect(c.unitIndex[seat]?.generated, isTrue, reason: 'premise');
    expect(c.isLocked(seat), isFalse, reason: 'premise: not the lock');
    // M-UW15: `index[h]?.generated == false` reduced to `index[h] != null`.
    expect(unitColourTargets(c, [k(seat)]), isEmpty);
    expect(unitColourTargets(c, [k(seat), k(f.table)]), [f.table]);
    expect(recolourCommand(c, [k(seat)], PlanSwatch.teal), isNull);
  });
}
