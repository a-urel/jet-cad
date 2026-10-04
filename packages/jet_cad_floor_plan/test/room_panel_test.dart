// Spec 10 D21: the Selection panel's Room section. A free-text Name field,
// committed on Enter and on its own focus loss (decision 8, R-23), trimmed,
// an empty name reverting (R-24), one `SetComponentCommand<RoomParams>` per
// change; and the Area line, the area label's stored string (R-25).
//
// The plan is the two-room rectangle at the corpus far origin, turned 23°,
// every wall and the separator in its own rotated, translated group; room A
// sits in a rotated group of its own (as a file may hold one), room B at the
// identity (as the Room tool makes one). Seeds are fractional. Expected
// area strings are hand arithmetic next to the assertion, each at least
// 0.0005 m² (or ft²) from a rounding tie.
import 'dart:convert';
import 'dart:math' as math;

import 'package:jet_cad_floor_plan/src/planner_shell.dart';
import 'package:jet_cad_floor_plan/src/parametric/catalog.dart';
import 'package:jet_cad_floor_plan/src/parametric/room.dart';
import 'package:jet_cad_floor_plan/src/parametric/wall.dart';
import 'package:jet_cad_floor_plan/src/planner_view.dart';
import 'package:jet_cad_floor_plan/src/shortcut_guard.dart';
import 'package:jet_cad_floor_plan/src/tool_palette.dart';
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/room_fixture.dart';

Finder get section => find.byKey(const Key('room-section'));
Finder get name => find.byKey(const Key('room-name'));
Finder get area => find.byKey(const Key('room-area'));

String fieldText(WidgetTester tester) =>
    tester.widget<TextField>(name).controller!.text;

String areaText(WidgetTester tester) => tester.widget<Text>(area).data!;

String status(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('status-text'))).data!;

Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

/// Focuses the Name field, types [text] and presses Enter.
Future<void> enterAndSubmit(WidgetTester tester, String text) async {
  // Past the double-tap timeout: a second tap on the field soon after the
  // first would select a word and open the selection toolbar.
  await tester.pump(kDoubleTapTimeout * 2);
  await tester.tap(name);
  await tester.pump();
  await tester.enterText(name, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
  await tester.pump();
}

/// Focuses the Name field and types [text], with no Enter.
Future<void> typeName(WidgetTester tester, String text) async {
  // Past the double-tap timeout: a second tap on the field soon after the
  // first would select a word and open the selection toolbar.
  await tester.pump(kDoubleTapTimeout * 2);
  await tester.tap(name);
  await tester.pump();
  await tester.enterText(name, text);
  await tester.pump();
}

/// A tap on the Area line: outside every field, so the field's
/// `onTapOutside` hands the focus back and its focus loss commits.
Future<void> blur(WidgetTester tester) async {
  await tester.tap(area);
  await tester.pump();
  await tester.pump();
}

Future<void> select(
    WidgetTester tester, PlannerView view, List<Handle> hs) async {
  view.selection.replace([for (final h in hs) SelectionKey.root(h)]);
  await tester.pump();
}

String nameOf(DraftDocument doc, Handle room) =>
    doc.components.get<RoomParams>(room)!.name;

/// The panel's plan.
typedef Rooms = ({DraftDocument doc, Handle a, Handle b, Handle sep, Handle w});

/// The two-room rectangle ([twoRoomWalls]: 8,000 × 4,000 of 200 mm walls, a
/// 100 mm partition at x = 3,000) at [corpusGroups], with a separator face
/// to face at x = 6,250.5, the app's opening page (1:50, metres), and two
/// rooms:
///
/// - A, `Kitchen`, seeded at (1,500.25, 2,000.5) in the left face, in a
///   rotated group of its own: x 100..2,950, y 100..3,900, 2,850 × 3,800 =
///   10,830,000 mm²;
/// - B, `Room 2`, seeded at (4,700.75, 1,900.25) between the partition and
///   the separator: x 3,050..6,250.5, 3,200.5 × 3,800 = 12,161,900 mm².
///
/// Built through a system of its own, which is disposed, and the history
/// cleared: the shell installs one over the finished document.
Rooms roomsPlan() {
  final plan = buildPlan(twoRoomWalls,
      seps: const [(6250.5, 100, 6250.5, 3900)],
      place: corpusGroups,
      measurer: FlutterTextMeasurer());
  attachPage(plan.doc, PageComponent());
  final g = Transform2.translation(plan.at(1400, 1900).x, plan.at(1400, 1900).y)
      .multiply(Transform2.rotation(0.61));
  final a = addRoom(plan.doc, plan.at(1500.25, 2000.5), 'Kitchen', at: g);
  final b = addRoom(plan.doc, plan.at(4700.75, 1900.25), 'Room 2');
  plan.system.dispose();
  plan.doc.commands.clearHistory();
  return (doc: plan.doc, a: a, b: b, sep: plan.seps.single, w: plan.walls[4]);
}

/// Pumps the shell over [doc].
Future<PlannerView> pumpShell(WidgetTester tester, DraftDocument doc) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: PlannerShell(document: doc)));
  await tester.pump();
  return tester.widget<PlannerView>(find.byType(PlannerView));
}

void main() {
  test(
      'the fixture: the room group is off the identity, the labels as '
      'drawn', () {
    final r = roomsPlan();
    final g = r.doc.tree.accumulatedTransform(r.a);
    expect(math.atan2(g.b, g.a), isNot(0));
    expect(labelStrings(r.doc, r.a), ['Kitchen', '10.83 m²']);
    expect(labelStrings(r.doc, r.b), ['Room 2', '12.16 m²']);
    expect(driftOf(r.doc), isEmpty);
  });

  testWidgets(
      'RN1 the Room section shows for exactly one room: hidden for none, two '
      'rooms, a room and a wall, a wall, a separator', (tester) async {
    final r = roomsPlan();
    final view = await pumpShell(tester, r.doc);
    expect(section, findsNothing, reason: 'none');
    await select(tester, view, [r.a]);
    expect(section, findsOneWidget);
    expect(tester.widget<Text>(section).data, 'Room');
    expect(fieldText(tester), 'Kitchen');
    expect(areaText(tester), '10.83 m²');
    // A free-text field (Task 16's review M3): a text keyboard and no unit.
    final field = tester.widget<TextField>(name);
    expect(field.keyboardType, TextInputType.text);
    expect(field.decoration!.suffixText, isNull);
    await select(tester, view, [r.b]);
    expect(fieldText(tester), 'Room 2');
    expect(areaText(tester), '12.16 m²');
    await select(tester, view, [r.a, r.b]);
    expect(section, findsNothing, reason: 'two rooms');
    await select(tester, view, [r.a, r.w]);
    expect(section, findsNothing, reason: 'a room and a wall');
    await select(tester, view, [r.w]);
    expect(section, findsNothing, reason: 'a wall');
    expect(find.byKey(const Key('wall-section')), findsOneWidget);
    await select(tester, view, [r.sep]);
    expect(section, findsNothing, reason: 'a separator');
    // Spec 12b D12: a separator has no type section; the panel shows only
    // the layer picker.
    expect(find.byKey(const Key('wall-section')), findsNothing,
        reason: 'a separator has no section');
    expect(find.byKey(const Key('layer-picker')), findsOneWidget);
    await select(tester, view, []);
    expect(section, findsNothing);
  });

  testWidgets(
      'RN2 Enter commits the name in one undo step and hands focus back; '
      'Esc works after', (tester) async {
    final r = roomsPlan();
    final doc = r.doc;
    final view = await pumpShell(tester, doc);
    final [nameLabel, areaLabel] = labelsOf(doc, r.a);
    final kids0 = kids(doc, r.a);
    final p0 = doc.components.get<RoomParams>(r.a)!;
    await select(tester, view, [r.a]);
    await enterAndSubmit(tester, 'Pantry');
    expect(doc.commands.undoDepth, 1, reason: 'one step, Enter and blur');
    expect(doc.components.get<RoomParams>(r.a), p0.copyWith(name: 'Pantry'));
    expect(kids(doc, r.a), kids0, reason: 'the same children');
    expect(textOf(doc, nameLabel), 'Pantry', reason: 'rewritten in place');
    expect(textOf(doc, areaLabel), '10.83 m²');
    expect(fieldText(tester), 'Pantry');
    expect(nameOf(doc, r.b), 'Room 2');
    expect(driftOf(doc), isEmpty);
    // The focus is back on the canvas: not on the field.
    expect(tester.widget<TextField>(name).focusNode!.hasFocus, isFalse);

    // An unchanged name issues no command: as it is, and once trimmed.
    for (final same in ['Pantry', '  Pantry ']) {
      await enterAndSubmit(tester, same);
      expect(doc.commands.undoDepth, 1, reason: '"$same"');
      expect(fieldText(tester), 'Pantry');
    }

    // An undo with the room still selected reloads the field (Task 16's
    // review M2): the same target, a new value; a redo reloads it back.
    doc.commands.undo();
    await tester.pump();
    await tester.pump();
    expect(view.selection.keys, [SelectionKey.root(r.a)]);
    expect(fieldText(tester), 'Kitchen', reason: 'reloaded after undo');
    doc.commands.redo();
    await tester.pump();
    await tester.pump();
    expect(fieldText(tester), 'Pantry', reason: 'reloaded after redo');
    expect(doc.commands.undoDepth, 1);

    // Escape reaches the canvas: it clears the selection.
    await press(tester, LogicalKeyboardKey.escape);
    expect(view.selection.keys, isEmpty);
    expect(section, findsNothing);

    // One undo restores the name, the label again in place.
    doc.commands.undo();
    await tester.pump();
    expect(doc.components.get<RoomParams>(r.a), p0);
    expect(kids(doc, r.a), kids0);
    expect(textOf(doc, nameLabel), 'Kitchen');
    await select(tester, view, [r.a]);
    expect(fieldText(tester), 'Kitchen');
  });

  testWidgets(
      'RN3 every shell letter types into the Name field (X15-guardMS: M '
      'and S included)', (tester) async {
    final r = roomsPlan();
    final doc = r.doc;
    final view = await pumpShell(tester, doc);
    final palette = tester.widget<ToolPalette>(find.byType(ToolPalette));
    // Every letter the shell binds, read from the shell itself -- each
    // palette entry's key and F, the Fill toggle -- and every entry of the
    // guard's list: a letter left out of the guard still gets typed here.
    final letters = <LogicalKeyboardKey>{
      ...kShellLetterKeys,
      for (final e in palette.entries) e.logicalKey,
      LogicalKeyboardKey.keyF,
    };
    expect(letters,
        containsAll([LogicalKeyboardKey.keyM, LogicalKeyboardKey.keyS]));
    expect(letters, hasLength(kShellLetterKeys.length),
        reason: 'the guard covers every shell letter');
    await select(tester, view, [r.a]);
    final status0 = status(tester);
    expect(status0, startsWith('Select'));
    await tester.tap(name);
    await tester.pump();
    tester.testTextInput.enterText('');
    await tester.pump();
    var typed = '';
    for (final key in letters) {
      // Unhandled by every shortcut: the platform turns it into text, as
      // the test's text input does next.
      expect(await tester.sendKeyEvent(key), isFalse,
          reason: '$key reaches the platform as text');
      typed += key.keyLabel.toLowerCase();
      tester.testTextInput.enterText(typed);
      await tester.pump();
      expect(status(tester), status0, reason: '$key switched no tool');
      expect(fieldText(tester), typed, reason: '$key typed');
    }
    expect(typed, hasLength(letters.length));
    expect(palette.fill.value, isFalse, reason: 'F toggled no fill');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();
    expect(nameOf(doc, r.a), typed);
    expect(labelStrings(doc, r.a), [typed, '10.83 m²']);
    expect(doc.commands.undoDepth, 1);
  });

  testWidgets(
      'RN4 the Name field\'s target is pinned at focus gain (M-10pin, '
      'X16-noBlur)', (tester) async {
    final r = roomsPlan();
    final doc = r.doc;
    final view = await pumpShell(tester, doc);
    final b0 = doc.components.get<RoomParams>(r.b)!;

    // Select A, type, select B without taking the focus, blur.
    await select(tester, view, [r.a]);
    await typeName(tester, 'Larder');
    await select(tester, view, [r.b]);
    expect(fieldText(tester), 'Larder', reason: 'focused: not reloaded');
    await blur(tester);
    expect(nameOf(doc, r.a), 'Larder');
    expect(labelStrings(doc, r.a), ['Larder', '10.83 m²']);
    expect(doc.components.get<RoomParams>(r.b), b0);
    expect(labelStrings(doc, r.b), ['Room 2', '12.16 m²']);
    expect(fieldText(tester), 'Room 2', reason: 'now B\'s');
    expect(doc.commands.undoDepth, 1);

    // Enter after the selection change: A still, once.
    await select(tester, view, [r.a]);
    await typeName(tester, 'Scullery');
    await select(tester, view, [r.b]);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();
    expect(nameOf(doc, r.a), 'Scullery');
    expect(doc.components.get<RoomParams>(r.b), b0);
    expect(doc.commands.undoDepth, 2);
    expect(driftOf(doc), isEmpty);
  });

  testWidgets(
      'RN5 an empty name reverts; runtime is read-only; a refused edit '
      'reverts (X16-untrimmed)', (tester) async {
    final r = roomsPlan();
    final doc = r.doc;
    final view = await pumpShell(tester, doc);
    await select(tester, view, [r.a]);

    // Empty after trimming: reverts, by Enter and by the focus loss.
    for (final empty in ['   ', '', '\t ']) {
      await enterAndSubmit(tester, empty);
      expect(fieldText(tester), 'Kitchen', reason: 'Enter "$empty"');
      await typeName(tester, empty);
      await blur(tester);
      expect(fieldText(tester), 'Kitchen', reason: 'blur "$empty"');
    }
    expect(nameOf(doc, r.a), 'Kitchen');
    expect(doc.commands.undoDepth, 0);

    // Leading and trailing spaces trimmed; inner ones kept.
    await enterAndSubmit(tester, '  Snug  room \t');
    expect(nameOf(doc, r.a), 'Snug  room');
    expect(labelStrings(doc, r.a), ['Snug  room', '10.83 m²']);
    expect(fieldText(tester), 'Snug  room');
    expect(doc.commands.undoDepth, 1);

    // Read-only unless both components and geometry are allowed.
    for (final (why, perms) in [
      ('runtime', DraftPermissions.runtime),
      (
        'components denied',
        const DraftPermissions(
            transform: true, components: false, geometry: true, structure: true)
      ),
      (
        'geometry denied',
        const DraftPermissions(
            transform: true, components: true, geometry: false, structure: true)
      ),
    ]) {
      doc.commands.permissions = perms;
      await select(tester, view, [r.b]);
      await select(tester, view, [r.a]);
      expect(tester.widget<TextField>(name).readOnly, isTrue, reason: why);
    }
    doc.commands.permissions = DraftPermissions.all;
    await select(tester, view, [r.b]);
    await select(tester, view, [r.a]);
    expect(tester.widget<TextField>(name).readOnly, isFalse);
    // Typed while allowed, committed after the permissions changed: the
    // commit checks them too.
    await typeName(tester, 'Den');
    doc.commands.permissions = DraftPermissions.runtime;
    await blur(tester);
    expect(nameOf(doc, r.a), 'Snug  room');
    expect(fieldText(tester), 'Snug  room');
    expect(doc.commands.undoDepth, 1);
    doc.commands.permissions = DraftPermissions.all;

    // The pinned room's group removed under the field while B is shown:
    // the text is discarded; nothing escapes.
    await select(tester, view, [r.a]);
    await typeName(tester, 'Gone');
    await select(tester, view, [r.b]);
    doc.commands.execute(deleteObject(doc, r.a));
    await tester.pump();
    expect(doc.tree[r.a], isNull);
    await blur(tester);
    expect(tester.takeException(), isNull);
    expect(nameOf(doc, r.b), 'Room 2');
    expect(fieldText(tester), 'Room 2');
    expect(doc.commands.undoDepth, 2, reason: 'the delete alone');
    // And while it is the room shown: the section goes with it.
    await typeName(tester, 'Gone too');
    doc.commands.execute(deleteObject(doc, r.b));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(section, findsNothing);
    expect(doc.commands.undoDepth, 3, reason: 'the delete alone');
    doc.commands.undo();
    doc.commands.undo();
    await tester.pump();
    expect(nameOf(doc, r.a), 'Snug  room');
    expect(nameOf(doc, r.b), 'Room 2');
  });

  testWidgets(
      'RN5 a refused edit (a loaded room whose tint fill names another '
      'room\'s boundary) reverts and re-pins; no exception escapes Enter or '
      'the focus loss', (tester) async {
    final src = roomsPlan();
    final j = DraftDocumentCodec.encode(src.doc);
    final aFill = kids(src.doc, src.a)
        .firstWhere((k) => kindOf(src.doc, k) == EntityKind.fill);
    final bFill = kids(src.doc, src.b)
        .firstWhere((k) => kindOf(src.doc, k) == EntityKind.fill);
    final bBoundary = payloadOf(src.doc, bFill).scalars[0];
    for (final e in j['entities']! as List) {
      final entity = e as Map<String, Object?>;
      if ((entity['record']! as Map)['handle'] == aFill.value) {
        (entity['geometry']! as Map)['scalars'] = [bBoundary];
      }
    }
    final doc = DraftDocumentCodec.decode(
        jsonDecode(jsonEncode(j)) as Map<String, Object?>,
        measurer: FlutterTextMeasurer(), registerComponents: (r) {
      PageComponent.register(r);
      parametricCatalog.registerComponents(r);
    });
    final view = await pumpShell(tester, doc);
    final a0 = doc.components.get<RoomParams>(src.a)!;
    final before = enc(doc);
    // The premise: the document itself refuses A's rename.
    expect(
        () => doc.commands.execute(
            SetComponentCommand<RoomParams>(src.a, a0.copyWith(name: 'Study'))),
        throwsStateError);
    expect(enc(doc), before);

    await select(tester, view, [src.a]);
    await enterAndSubmit(tester, 'Study');
    expect(tester.takeException(), isNull);
    expect(fieldText(tester), 'Kitchen', reason: 'reverted');
    expect(enc(doc), before);
    // Re-pinned: the focus loss alone is refused alike.
    await typeName(tester, 'Office');
    await blur(tester);
    expect(tester.takeException(), isNull);
    expect(fieldText(tester), 'Kitchen');
    expect(enc(doc), before);
    expect(doc.commands.undoDepth, 0);

    // B is sound: its rename lands.
    await select(tester, view, [src.b]);
    await enterAndSubmit(tester, 'Hall');
    expect(nameOf(doc, src.b), 'Hall');
    expect(labelStrings(doc, src.b), ['Hall', '12.16 m²']);
    expect(doc.commands.undoDepth, 1);
  });

  testWidgets(
      'RN6 the Area line shows the area label\'s string: after a page change '
      'to ft-in it reads the label\'s ft² string', (tester) async {
    final r = roomsPlan();
    final doc = r.doc;
    final view = await pumpShell(tester, doc);
    await select(tester, view, [r.b]);
    // B: 12,161,900 mm² = 12.1619 m² (the tie 12.165 is 0.0031 away).
    expect(areaText(tester), '12.16 m²');
    expect(areaText(tester), textOf(doc, labelsOf(doc, r.b)[1]));

    // With B shown, the page turns to ft-in at 1:100: one step.
    final page = doc.components.get<PageComponent>(doc.rootHandle)!;
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle,
        page.copyWith(
            displayUnit: DisplayUnit.feetInches, scaleDenominator: 100)));
    await tester.pump();
    // 12,161,900 / (304.8 × 304.8) = 12,161,900 / 92,903.04 ≈ 130.9096
    // (the tie 130.905 is 0.0046 away).
    expect(areaText(tester), '130.91 ft²');
    expect(areaText(tester), textOf(doc, labelsOf(doc, r.b)[1]));
    // A: 10,830,000 / 92,903.04 ≈ 116.5731 (the tie 116.575 is 0.0019
    // away).
    await select(tester, view, [r.a]);
    expect(areaText(tester), '116.57 ft²');
    expect(areaText(tester), textOf(doc, labelsOf(doc, r.a)[1]));

    // Undo: metres again. A: 10,830,000 mm² = 10.83 m², exact.
    doc.commands.undo();
    // The change arrives in a microtask, flushed after this pump's frame;
    // its rebuild lands in the next.
    await tester.pump();
    await tester.pump();
    expect(areaText(tester), '10.83 m²');
    expect(areaText(tester), textOf(doc, labelsOf(doc, r.a)[1]));
    // A wall moved: A's area follows, and the line with it. The partition
    // (x 3,000, 100 thick) moved to x 3,300.5: A x 100..3,250.5, 3,150.5 ×
    // 3,800 = 11,971,900 mm², 11.9719 m² (the tie 11.975 is 0.0031 away).
    final place = corpusGroups;
    final w = doc.components.get<WallParams>(r.w)!;
    final inv = doc.tree.accumulatedTransform(r.w).invert();
    final s = inv.transformPoint(place.at(3300.5, 0));
    final e = inv.transformPoint(place.at(3300.5, 4000));
    doc.commands.execute(SetComponentCommand<WallParams>(
        r.w, WallParams(s.x, s.y, e.x, e.y, w.thickness, w.justification)));
    await tester.pump();
    expect(areaText(tester), '11.97 m²');
    expect(areaText(tester), textOf(doc, labelsOf(doc, r.a)[1]));
    expect(driftOf(doc), isEmpty);

    // A room whose area TEXT lands in a lower slot than its name (Task 16's
    // review M1): four lines deleted in one step leave four free slots,
    // reused last-in first-out. The Area line is the second label in
    // handle order, never in slot order.
    final lines = <Handle>[];
    for (var i = 0; i < 4; i++) {
      final h = doc.handleSeed.next();
      doc.commands.execute(AddEntityCommand(
          record: draftRecord(h, doc.rootHandle, EntityKind.line,
              layer: ReservedHandles.layerZero),
          payload: linePayload(place.at(-2000.25 + 300 * i, -3000.5),
              place.at(-1500.75, -2700.25))));
      lines.add(h);
    }
    doc.commands.execute(CompoundCommand(
        [for (final h in lines) RemoveEntityCommand(h)],
        label: 'Delete'));
    // C, between the separator and the east wall: x 6,250.5..7,900, 1,649.5
    // × 3,800 = 6,268,100 mm², 6.2681 m² (the tie 6.265 is 0.0031 away).
    final c = addRoom(doc, place.at(7000.25, 2000.5), 'Store');
    await tester.pump();
    final [cName, cArea] = labelsOf(doc, c);
    expect(doc.entities.slotOf(cArea)!, lessThan(doc.entities.slotOf(cName)!),
        reason: 'premise: the area TEXT sits in the lower slot');
    await select(tester, view, [c]);
    expect(fieldText(tester), 'Store');
    expect(areaText(tester), '6.27 m²');
    expect(areaText(tester), textOf(doc, cArea));
  });
}
