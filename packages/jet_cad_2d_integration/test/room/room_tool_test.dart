// Spec 3a C6, C1.2: the Room tool in the plan library's editor. TT1's
// shell half, TT7 and SG1 are ported from jet_cad_floor_plan/test/
// room_tool_test.dart (spec 10 D19, decision 26, R-29, X15-guardMS),
// assertions unchanged: the status line composes the tool's label and its
// notice as today ('Room — Already a room: Room 1'). RT-notice-locale is
// Review Focus 2: a language switch re-words a notice already shown, at
// once, the room's name kept.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/room_plans.dart';

/// Today's `shellSamplePlan` (room_tool_test.dart:213-218): the sample
/// plan's walls, column, separator and openings at the origin, with
/// [rooms].
RoomPlan sampleRoomPlan({List<R> rooms = const []}) =>
    roomPlan([...sampleWalls(), sampleColumn],
        seps: const [sampleSeparator], openings: sampleOpenings, rooms: rooms);

void main() {
  testWidgets(
      'TT1 M places one room with one click, one undo step, named Room 1, '
      'seeded at the raw point; the tool stays active and Esc returns to '
      'Select (the editor)', (tester) async {
    // The editor: M and the palette entry both activate the tool, a click
    // places a room, the tool stays active, and Esc returns to Select.
    final shell = sampleRoomPlan();
    await pumpEditor(tester, shell.c,
        centre: shell.at(20000, 10500), scale: 0.12);
    final sdoc = shell.doc;
    await press(tester, LogicalKeyboardKey.keyM);
    expect(status(tester), 'Room');
    await press(tester, LogicalKeyboardKey.escape);
    expect(status(tester), 'Select');
    await tester.tap(find.byKey(const Key('tool-architecture.room')));
    await tester.pump();
    expect(status(tester), 'Room');
    final sdepth = sdoc.commands.undoDepth;
    await clickAt(tester, shell.c, shell.at(18500.5, 9750.25));
    final kitchen = rooms(sdoc).single;
    expect(sdoc.commands.undoDepth, sdepth + 1);
    // The Kitchen: x 17,060-21,440, y 8,250-11,440: 4,380 × 3,190 =
    // 13,972,200 mm², 13.97 m² (0.0022 from a tie).
    expect(labelStrings(sdoc, kitchen), ['Room 1', '13.97 m²']);
    expect(status(tester), 'Room — Already a room: Room 1',
        reason: 'the tool stays active, over the face it just filled');
    await undoKey(tester);
    expect(rooms(sdoc), isEmpty);
    expect(status(tester), 'Room', reason: 'the face is free again');
    await press(tester, LogicalKeyboardKey.escape);
    expect(status(tester), 'Select');
  });

  testWidgets(
      'TT7 a click in an occupied face places nothing and the status line '
      'says so; hovering there shows it; it clears on leaving the face and '
      'on deactivation', (tester) async {
    final plan = sampleRoomPlan(rooms: const [
      (x: 19000, y: 10000, name: 'Kitchen', label: null, at: null),
    ]);
    await pumpEditor(tester, plan.c,
        centre: plan.at(20000, 10500), scale: 0.12);
    final doc = plan.doc;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    Future<void> hover(double x, double y) async {
      await mouse.moveTo(globalAt(tester, plan.c, plan.at(x, y)));
      await tester.pump();
    }

    await press(tester, LogicalKeyboardKey.keyM);
    expect(status(tester), 'Room');
    await hover(20500.5, 9000.25);
    expect(status(tester), 'Room — Already a room: Kitchen',
        reason: 'hovering the occupied face');
    final before = rooms(doc);
    final depth = doc.commands.undoDepth;
    await clickAt(tester, plan.c, plan.at(18200.5, 10800.25));
    expect(rooms(doc), before, reason: 'nothing placed');
    expect(doc.commands.undoDepth, depth);
    expect(status(tester), 'Room — Already a room: Kitchen',
        reason: 'after a click there');
    // The Bath: a face with no room.
    await hover(23500.5, 10000.25);
    expect(status(tester), 'Room', reason: 'cleared on leaving the face');
    await hover(19000.5, 10500.25);
    expect(status(tester), 'Room — Already a room: Kitchen');
    await press(tester, LogicalKeyboardKey.escape);
    expect(status(tester), 'Select', reason: 'cleared on deactivation');
    expect(plan.c.toolNotice.value, isNull);
    await press(tester, LogicalKeyboardKey.keyM);
    expect(status(tester), 'Room');
  });

  testWidgets(
      'SG1 M and S typed into a text entry switch no tool (the shell\'s '
      'guard, X15-guardMS)', (tester) async {
    final plan = roomPlan(boxWalls);
    await pumpEditor(tester, plan.c);
    await press(tester, LogicalKeyboardKey.keyT);
    expect(status(tester), 'Text');
    await tester.tapAt(globalAt(tester, plan.c, Vector2(2000.5, 2000.25)));
    await tester.pump();
    expect(find.byKey(const Key('text-entry')), findsOneWidget);
    for (final k in [LogicalKeyboardKey.keyM, LogicalKeyboardKey.keyS]) {
      await press(tester, k);
      expect(status(tester), 'Text', reason: '$k switched no tool');
      expect(find.byKey(const Key('text-entry')), findsOneWidget);
    }
  });

  testWidgets(
      'RT-notice-locale a language switch re-words the Room tool\'s notice '
      'at once, in the new language, the room\'s name kept (Review Focus 2; '
      'M-RT-3)', (tester) async {
    final plan = roomPlan(boxWalls, place: corpusGroups, rooms: const [
      (x: 1500.25, y: 2000.5, name: 'Kitchen', label: null, at: null),
    ]);
    await pumpEditor(tester, plan.c, centre: plan.at(4000, 2000), scale: 0.15);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await press(tester, LogicalKeyboardKey.keyM);
    await mouse.moveTo(globalAt(tester, plan.c, plan.at(6000.75, 1200.5)));
    await tester.pump();
    expect(status(tester), 'Room — Already a room: Kitchen');
    expect(plan.c.toolNotice.value?.id, 'text:architecture.room-occupied');
    expect(plan.c.toolNotice.value?.args, {'name': 'Kitchen'});
    // The language turns, the pointer stays: the line re-words at once.
    for (final (locale, line) in const [
      (Locale('de'), 'Raum — Bereits ein Raum: Kitchen'),
      (Locale('tr'), 'Oda — Zaten bir oda: Kitchen'),
      (Locale('en'), 'Room — Already a room: Kitchen'),
    ]) {
      await tester.pumpWidget(planEditorApp(plan.c, locale: locale));
      await tester.pump();
      expect(status(tester), line, reason: '$locale');
    }
  });
}
