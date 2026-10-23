// Plan colours spec PC-8, PC-9 and PC-10: the Selection panel's Colour row.
// Nine swatches, None and the palette's eight hues, set the colour of every
// selected room and table in one undo step labelled Colour; read-only while
// the host refuses `recolor` or the permissions refuse the edit; its words
// in Turkish; its swatches as the canvas shows the hues.
//
// The plan is the two-room rectangle at the corpus far origin, turned 23°,
// every wall and the separator in its own rotated, translated group; room A
// sits in a group of its own turned 0.61 rad, room B at the identity. The
// hues under test are `teal` and `purple`, never the first of the palette,
// and `magenta`, a name no release knows.
//
// CP7 to CP11 (Slice 2, tables) run through `FloorPlanView` on the editor
// fixture: the startup flat's rooms beside its tables, `1` turned 30 degrees,
// `2` mirrored at 90, `7` and ` 7 ` sharing a number, `L` on a locked layer.
// Ported for jet_cad_2d_integration (3a Task 27, Appendix A D-21, D-39): the
// rooms, the wall and the separator are the architecture kit's; assertions
// unchanged but ruling IP-R7. The fixture case, CP1-CP5 and CP6b; CP6 and
// CP7-CP12 stay 2a's and 2b's.
import 'dart:convert' show jsonEncode;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show
        InteractionLayer,
        SelectionKey,
        ViewportTransform,
        darkCanvasTone,
        kDarkCanvasPaper;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanSwatch;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart'
    show ArchitectureTools, RoomParams, SeparatorParams, WallParams;
import 'package:jet_cad_2d_plan/src/chrome/icon_button.dart' show PlanTooltip;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/canvas_rig.dart';
import '../support/plans.dart';
import '../support/rooms_plan.dart';

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

/// The kit's grey tint transparency (kit-internal, R-P1).
const int kRoomTintTransparency =
    229; // jet_cad_floor_plan/lib/src/parametric/room.dart:125 (kit-internal)

/// The editor over [Rooms.c], its pixels readable.
final class Rig {
  Rig._(this.tester, this.c, this.capture, this.topLeft);

  final WidgetTester tester;
  final PlanController c;
  final GlobalKey capture;
  final Offset topLeft;

  /// Pumps the editor over [r], the camera at 0.07 px/mm (y up) centred on
  /// the plan's middle, with [r]'s permissions and, when given, [locale]
  /// (with the plan library's delegates) and [theme].
  static Future<Rig> pump(WidgetTester tester, Rooms r,
      {Locale? locale, ThemeData? theme}) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final capture = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: capture,
        child: MaterialApp(
            locale: locale,
            theme: theme,
            supportedLocales: planSupportedLocales,
            localizationsDelegates: planLocalizationsDelegates,
            home: Scaffold(body: PlanEditor(controller: r.c)))));
    await tester.pump();
    final layer = find.byType(InteractionLayer);
    final size = tester.getSize(layer);
    final mid = r.plan.at(4800, 2000);
    const px = 0.07;
    r.c.camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2(px, 0, 0, -px,
            size.width / 2 - px * mid.x + 0.37, size.height / 2 + px * mid.y));
    await tester.pump();
    return Rig._(tester, r.c, capture, tester.getTopLeft(layer));
  }

  Future<void> select(List<Handle> hs) async {
    c.activeSelection.replace([for (final h in hs) k(h)]);
    await tester.pump();
  }

  /// The RGB of the pixel that holds world point [p], as drawn now.
  Future<List<int>> rgb(Vector2 p) async {
    final boundary =
        capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final (bytes, width) = (await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final w = image.width;
      image.dispose();
      return (data!, w);
    }))!;
    final s = c.camera.value.worldToScreen(p);
    final o = topLeft + Offset(s.x, s.y);
    final i = (o.dy.floor() * width + o.dx.floor()) * 4;
    return [bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2)];
  }
}

/// [paper] under a tint of [ink] at [alpha] (of 255).
List<double> over(List<int> paper, int ink, int alpha) => [
      paper[0] + (((ink >> 16) & 0xFF) - paper[0]) * alpha / 255,
      paper[1] + (((ink >> 8) & 0xFF) - paper[1]) * alpha / 255,
      paper[2] + ((ink & 0xFF) - paper[2]) * alpha / 255,
    ];

void expectRgb(List<int> got, List<double> want, String why) {
  for (var i = 0; i < 3; i++) {
    expect(got[i], closeTo(want[i], 3), reason: '$why: channel $i of $got');
  }
}

/// [room]'s tint records: its fill and the boundary the fill names, or its
/// closed POLYLINE.
List<EntityRecord> tintRecords(DraftDocument doc, Handle room) {
  final all = kids(doc, room);
  final fills = [
    for (final c in all)
      if (kindOf(doc, c) == EntityKind.fill) c
  ];
  if (fills.isNotEmpty) {
    final boundary = Handle(payloadOf(doc, fills.single).scalars[0].toInt());
    return [recordOf(doc, fills.single), recordOf(doc, boundary)];
  }
  return [
    for (final c in all)
      if (kindOf(doc, c) == EntityKind.polyline) recordOf(doc, c),
  ];
}

/// Entity [h] whole: its record as saved and its payload's numbers.
String snapOf(DraftDocument doc, Handle h) {
  final p = payloadOf(doc, h);
  return jsonEncode([
    recordOf(doc, h).toJson(),
    p.coords.toList(),
    p.scalars.toList(),
  ]);
}

/// Object [h] whole: its group's children, by handle.
Map<Handle, String> childSnaps(DraftDocument doc, Handle h) =>
    {for (final c in kids(doc, h)) c: snapOf(doc, c)};

RoomParams roomOf(DraftDocument doc, Handle h) =>
    doc.components.get<RoomParams>(h)!;

/// Sets [room]'s colour to [name] by a plain component command (the shell's
/// system must be installed: the tint follows).
void paint(DraftDocument doc, Handle room, String? name) =>
    doc.commands.execute(SetComponentCommand<RoomParams>(
        room, roomOf(doc, room).copyWith(color: name)));

/// A bare-floor point and one inside each room, off its label and every
/// stroke, in plan millimetres.
Vector2 bareAt(Rooms r) => r.plan.at(9800, 2000);
Vector2 insideA(Rooms r) => r.plan.at(800, 3300);
Vector2 insideB(Rooms r) => r.plan.at(3900, 3300);

/// A coloured room's tint alpha: transparency 204 is 51 of 255.
const int kColourAlpha = 255 - 204;

void main() {
  test('the fixture: room A is off the identity, the rooms are uncoloured', () {
    final r = roomsPlan();
    final g = r.doc.tree.accumulatedTransform(r.a);
    expect(g.b, isNot(0));
    expect(roomOf(r.doc, r.a).color, isNull);
    expect(roomOf(r.doc, r.b).color, isNull);
    expect(driftOf(r.doc), isEmpty);
  });

  testWidgets(
      'CP1 the Colour row shows for a selection holding a room, marks the '
      'common colour, and marks nothing for a mix or an unknown name',
      (tester) async {
    final r = roomsPlan();
    final doc = r.doc;
    final rig = await Rig.pump(tester, r);

    expect(picker, findsNothing, reason: 'nothing selected');
    await rig.select([r.w]);
    expect(picker, findsNothing, reason: 'a wall alone');
    await rig.select([r.sep]);
    expect(picker, findsNothing, reason: 'a separator alone');

    // While the Wall tool's settings show, even with a room selected.
    await rig.select([r.a]);
    expect(picker, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.pump();
    expect(byKey('settings-${ArchitectureTools.wall}'), findsOneWidget,
        reason: 'the Wall tool is active');
    // Activating a tool clears the selection (planner_shell.dart), so the
    // room is selected again under the active tool: the row's absence is
    // then the panel's own rule, not an empty selection's.
    await rig.select([r.a]);
    expect({...rig.c.activeSelection.keys}, {k(r.a)},
        reason: 'the room is selected under the Wall tool');
    expect(byKey('settings-${ArchitectureTools.wall}'), findsOneWidget,
        reason: 'the Wall tool is still active');
    expect(picker, findsNothing, reason: 'the Wall tool\'s settings show');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await rig.select([r.a]);

    expect(picker, findsOneWidget, reason: 'room A');
    expect(find.byKey(const Key('layer-picker')), findsOneWidget);
    expect(swatch('none'), findsOneWidget);
    for (final c in PlanSwatch.values) {
      expect(swatch(c.name), findsOneWidget, reason: c.name);
    }
    expect(marked(tester), 'none', reason: 'an uncoloured room');
    await rig.select([r.a, r.b]);
    expect(picker, findsOneWidget, reason: 'rooms A and B');
    expect(marked(tester), 'none', reason: 'two uncoloured rooms');
    await rig.select([r.a, r.w]);
    expect(picker, findsOneWidget, reason: 'room A and a wall');
    expect(marked(tester), 'none');

    paint(doc, r.a, 'teal');
    await tester.pump();
    await rig.select([r.a]);
    expect(marked(tester), 'teal', reason: 'A is teal');
    await rig.select([r.a, r.b]);
    expect(marked(tester), isNull, reason: 'teal and none: mixed');
    paint(doc, r.b, 'teal');
    await tester.pump();
    expect(marked(tester), 'teal', reason: 'both teal');
    paint(doc, r.b, 'purple');
    await tester.idle();
    await tester.pump();
    expect(marked(tester), isNull, reason: 'teal and purple: mixed');

    // A name this release does not know: no swatch is marked (Review Focus
    // 5), and the stored name is untouched.
    paint(doc, r.a, 'magenta');
    await rig.select([r.a]);
    expect(picker, findsOneWidget);
    expect(marked(tester), isNull, reason: 'magenta equals no swatch');
    expect(roomOf(doc, r.a).color, 'magenta');
  });

  testWidgets(
      'CP2 a tap on teal with two rooms, a wall and a separator selected: '
      'one undo step labelled Colour, both rooms teal, the wall and the '
      'separator untouched; Ctrl+Z repaints the grey in the next frame '
      '(M-C12, Review Focus 3 and 4)', (tester) async {
    final r = roomsPlan();
    final doc = r.doc;
    final rig = await Rig.pump(tester, r);
    final labels = <String>[];
    final sub = doc.commands.changes.listen((c) {
      if (c is CommandApplied) labels.add(c.label);
    });
    addTearDown(sub.cancel);

    await rig.select([r.a, r.b, r.w, r.sep]);
    expect(picker, findsOneWidget);
    final wall0 = doc.components.get<WallParams>(r.w);
    final sep0 = doc.components.get<SeparatorParams>(r.sep);
    final wallKids0 = childSnaps(doc, r.w);
    final sepKids0 = childSnaps(doc, r.sep);
    final depth = doc.commands.undoDepth;
    final bare = await rig.rgb(bareAt(r));
    final greyA = await rig.rgb(insideA(r));
    final greyB = await rig.rgb(insideB(r));
    expect(greyA, isNot(bare), reason: 'the grey tint shows over the floor');
    expect(greyB, isNot(bare));
    final before = canon(doc);

    await tester.tap(swatch('teal'));
    await tester.pump();
    await tester.pump();
    expect(doc.commands.undoDepth, depth + 1, reason: 'one undo step');
    expect(labels, ['Colour']);
    expect(roomOf(doc, r.a).color, 'teal');
    expect(roomOf(doc, r.b).color, 'teal');
    expect(doc.components.get<WallParams>(r.w), wall0);
    expect(doc.components.get<SeparatorParams>(r.sep), sep0);
    expect(childSnaps(doc, r.w), wallKids0, reason: 'the wall, whole');
    expect(childSnaps(doc, r.sep), sepKids0, reason: 'the separator, whole');
    for (final room in [r.a, r.b]) {
      for (final t in tintRecords(doc, room)) {
        expect(t.color, const TrueColor(0x00897B));
      }
    }
    expect(driftOf(doc), isEmpty);
    expect(marked(tester), 'teal');
    expectRgb(await rig.rgb(insideA(r)), over(bare, 0x00897B, kColourAlpha),
        'A drawn teal');
    expectRgb(await rig.rgb(insideB(r)), over(bare, 0x00897B, kColourAlpha),
        'B drawn teal');

    // Ctrl+Z, one pump: the tints are grey again, in the document and on
    // the canvas (the change reaches the painter in the same frame).
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
    expect(doc.commands.undoDepth, depth);
    expect(canon(doc), before, reason: 'the document is as before');
    for (final room in [r.a, r.b]) {
      for (final t in tintRecords(doc, room)) {
        expect(t.color, const IndexedColor(7));
        expect(t.transparency, kRoomTintTransparency);
      }
    }
    expect(await rig.rgb(insideA(r)), greyA, reason: 'A repainted grey');
    expect(await rig.rgb(insideB(r)), greyB, reason: 'B repainted grey');
    expect(marked(tester), 'none', reason: 'the picker follows the undo');
  });

  testWidgets(
      'CP3 a colour chosen twice is no undo step; with A teal and B purple '
      'a tap on teal changes B only (M-PC9-a, Review Focus 2)', (tester) async {
    final r = roomsPlan();
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
    await tester.idle();
    await tester.pump();
    await rig.select([r.a, r.b]);
    // Not ported (ruling IP-R7): today's recolorCommand(doc, keys,
    // FloorPlanColor.teal) is the plan's internal `recolour`; its lines
    // (the command for the selection sets B alone, and null for A, already
    // teal, and for a wall) are claimed through the panel below.
    //   final keys = [k(r.a), k(r.b)];
    //   final command = recolorCommand(doc, keys, FloorPlanColor.teal)!;
    //   expect(command, isA<CompoundCommand>());
    //   final sets = (command as CompoundCommand)
    //       .children
    //       .whereType<SetComponentCommand<RoomParams>>()
    //       .toList();
    //   expect(sets, hasLength(1), reason: 'one room changes');
    //   expect(sets.single.handle, r.b);
    //   expect(sets.single.value, roomOf(doc, r.b).copyWith(color: 'teal'));
    //   expect(recolorCommand(doc, [k(r.a)], FloorPlanColor.teal), isNull);
    //   expect(recolorCommand(doc, [k(r.w)], FloorPlanColor.teal), isNull,
    //       reason: 'a wall is no room');

    final a0 = roomOf(doc, r.a);
    final depth = doc.commands.undoDepth;
    await tester.tap(swatch('teal'));
    await tester.pump();
    expect(doc.commands.undoDepth, depth + 1);
    expect(identical(roomOf(doc, r.a), a0), isTrue, reason: 'A not rewritten');
    expect(roomOf(doc, r.b).color, 'teal');

    // None clears every selected room, and only when one is coloured.
    await tester.tap(swatch('none'));
    await tester.pump();
    expect(roomOf(doc, r.a).color, isNull);
    expect(roomOf(doc, r.b).color, isNull);
    expect(doc.commands.undoDepth, depth + 2);
    await tester.tap(swatch('none'));
    await tester.pump();
    expect(doc.commands.undoDepth, depth + 2, reason: 'none, twice');
  });

  testWidgets(
      'CP4 read-only: the picker shows, marks, changes nothing, and says '
      'why (M-C13, M-PC9-b)', (tester) async {
    // The host refuses recolor.
    final r = roomsPlan();
    final doc = r.doc;
    r.c.permissions = PlanPermissions.full.copyWith(recolor: false);
    final rig = await Rig.pump(tester, r);
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

    // The permissions refuse it (the host allows it).
    final r2 = roomsPlan();
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
    expect(roomOf(r2.doc, r2.a).color, 'purple', reason: 'allowed again');

    // Components allowed, geometry refused: the room edit capability.
    r2.doc.commands.permissions = const DraftPermissions(
        transform: true, components: true, geometry: false, structure: true);
    await rig2.select([r2.b]);
    await rig2.select([r2.a]);
    await tester.tap(swatch('teal'));
    await tester.pump();
    expect(roomOf(r2.doc, r2.a).color, 'purple');
    expect(tooltipOf(tester, 'teal'), strings.readOnlyDocument);
  });

  testWidgets(
      'CP5 in Turkish the title, the swatches\' tooltips and labels and '
      'None speak Turkish', (tester) async {
    final r = roomsPlan();
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
    final r = roomsPlan();
    var rig = await Rig.pump(tester, r, theme: ThemeData.light());
    await rig.select([r.a]);
    expect(fillOf('teal').toARGB32(), 0xFF00897B);
    expect(fillOf('purple').toARGB32(), 0xFF8E24AA);

    final r2 = roomsPlan();
    rig = await Rig.pump(tester, r2, theme: ThemeData.dark());
    await rig.select([r2.a]);
    expect(fillOf('teal').toARGB32(),
        0xFF000000 | darkCanvasTone(0x00897B, kDarkCanvasPaper));
    expect(fillOf('purple').toARGB32(),
        0xFF000000 | darkCanvasTone(0x8E24AA, kDarkCanvasPaper));
    expect(fillOf('teal').toARGB32(), isNot(0xFF00897B));
  });
}
