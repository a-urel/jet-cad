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
// CP7 to CP12 are tables (2b).
import 'dart:convert' show jsonEncode;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show SelectionKey, darkCanvasTone, kDarkCanvasPaper;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanSwatch;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/panels/colour_row.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/panel_kits.dart';

Finder swatch(String name) => find.byKey(Key('color-swatch-$name'));
Finder get picker => find.byKey(const Key('color-picker'));

/// The Semantics node of swatch [name] (the nearest above its InkWell that
/// carries the label).
Semantics semanticsOf(WidgetTester tester, String name) =>
    tester.widget<Semantics>(find
        .ancestor(
            of: swatch(name),
            matching: find.byWidgetPredicate(
                (w) => w is Semantics && w.properties.label != null))
        .first);

/// The tooltip text of swatch [name].
String tooltipOf(WidgetTester tester, String name) => tester
    .widget<Tooltip>(
        find.ancestor(of: swatch(name), matching: find.byType(Tooltip)).first)
    .message!;

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
  Handle line
});

/// Two boxes and a plain line over the box and disc kits: A (120 x 70) in a
/// group of its own turned 0.61 rad, B (90 x 60) at the identity, the line
/// on layer 0. The history cleared.
Boxes boxesPlan() {
  final c = boxController(kits: [boxKit, discKit]);
  final a = addBox(c, Vector2(7010.25, 3020.5),
      const BoxParams(120, 70, label: 'A', count: 2),
      turn: 0.61);
  final b = addBox(c, Vector2(7400.75, 3120.25),
      const BoxParams(90, 60, label: 'B', finish: BoxFinish.gloss));
  final add = addDrafted(c.document, EntityKind.line,
      linePayload(Vector2(7210.5, 3300.25), Vector2(7390.75, 3360.5)),
      layer: ReservedHandles.layerZero);
  c.document.commands.execute(add);
  c.document.commands.clearHistory();
  return (c: c, doc: c.document, a: a, b: b, line: add.record.handle);
}

BoxParams boxOf(DraftDocument doc, Handle h) =>
    doc.components.get<BoxParams>(h)!;

/// Today's `paint(doc, room, name)`: the box's colour set to [name], one
/// step.
void paint(DraftDocument doc, Handle box, String? name) => doc.commands.execute(
    SetComponentCommand<BoxParams>(box, boxOf(doc, box).withColour(name)));

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
}
