// Spec 3a C3.5, C1.1, C1.7: the room as a kit type. Its fields are its
// name (a TextProperty, trimmed, an empty name refused, gated by reshape)
// and its area as drawn (a TextDisplay over the object: the area label's
// string, '—' without one, read once per document state); its colour is its
// palette name; its grips are today's label grip at the snap aperture of
// the camera's scale, and a room is not moved or turned.
//
// The plan: the two-room box with a separator face to face at x 6,250.5,
// at the corpus far origin turned 23°, every wall and the separator in its
// own rotated, translated group; room A ('Kitchen') in a group of its own
// turned 0.61 rad, room B ('Room 2') at the identity. Area strings are
// today's hand arithmetic (room_panel_test.dart RN1, RN6).
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit/testing.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_kit_architecture/src/room/room_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/room_fixture.dart';

typedef Rooms = ({Plan plan, Handle a, Handle b});

/// A: x 100..2,950, 2,850 × 3,800 = 10,830,000 mm² ("10.83 m²"); B: x
/// 3,050..6,250.5, 3,200.5 × 3,800 = 12,161,900 mm² ("12.16 m²").
Rooms rooms() {
  final plan = buildPlan(twoRoomWalls,
      seps: const [(6250.5, 100, 6250.5, 3900)], place: corpusGroups);
  attachPage(plan.doc, PageComponent());
  final at = plan.at(1400, 1900);
  final g =
      Transform2.translation(at.x, at.y).multiply(Transform2.rotation(0.61));
  final a = addRoom(plan.doc, plan.at(1500.25, 2000.5), 'Kitchen', at: g);
  final b = addRoom(plan.doc, plan.at(4700.75, 1900.25), 'Room 2');
  plan.doc.commands.clearHistory();
  return (plan: plan, a: a, b: b);
}

/// The kit's own words in English (R-P4: fields are bound with words; the
/// room's read none).
final KitWords words =
    KitNamesWords(architectureKit.names, () => const Locale('en'));

PropertyField fieldOf(DraftDocument doc, Handle room, String id) =>
    roomPlanType.fieldsOf(doc, room, words).firstWhere((f) => f.spec.id == id);

void main() {
  test(
      'RM-fields a room\'s fields are its name and its area as drawn, under '
      'its property words; its section is titled by its type word', () {
    final f = rooms();
    final doc = f.plan.doc;
    expect(roomPlanType.id, ArchitectureTypes.room);
    expect(architectureKit.types, contains(roomPlanType));
    final fields = roomPlanType.fieldsOf(doc, f.a, words);
    expect([
      for (final x in fields) x.wordId
    ], [
      'property:architecture.room.name',
      'property:architecture.room.area',
    ]);
    expect([for (final x in fields) x.value], ['Kitchen', '10.83 m²']);
    expect(fields[0].spec.gate, PlanGate.reshape);
    expect(fields[0].commit, isNotNull);
    expect(fields[1].commit, isNull, reason: 'a display');
    expect(fields[1].visible, isTrue);
    expect(roomPlanType.fieldsOf(doc, f.b, words)[1].value, '12.16 m²');
    expect(roomPlanType.titleWordOf(doc, f.a), 'type:architecture.room');
    expect(roomPlanType.exported, isTrue);
  });

  test(
      'RM-name the name is trimmed, inner spaces kept; an empty name is '
      'refused (M-RM-1, M-RM-2)', () {
    final f = rooms();
    final doc = f.plan.doc;
    doc.commands.execute(roomPlanType.commitField(
        doc, f.a, fieldOf(doc, f.a, 'name'), '  Snug  room \t', words));
    expect(doc.components.get<RoomParams>(f.a)!.name, 'Snug  room');
    expect(labelStrings(doc, f.a), ['Snug  room', '10.83 m²']);
    for (final empty in ['', '   ', '\t ']) {
      expect(
          () => roomPlanType.commitField(
              doc, f.a, fieldOf(doc, f.a, 'name'), empty, words),
          throwsArgumentError,
          reason: '"$empty"');
    }
    expect(doc.commands.undoDepth, 1);
  });

  test(
      'RM-area the Area line is the area label as drawn, read once per '
      'document state, "—" for a room with no labels (M-RM-3, M-RM-4, '
      'M-RM-5, M-RM-6)', () {
    final f = rooms();
    final doc = f.plan.doc;
    final reads = debugRoomAreaReads;
    expect(fieldOf(doc, f.b, 'area').value, '12.16 m²');
    expect(fieldOf(doc, f.b, 'area').value, '12.16 m²');
    expect(debugRoomAreaReads - reads, 1, reason: 'one read at one state');

    // The page turns to ft-in at 1:100, one command: the line follows.
    // 12,161,900 / 92,903.04 ≈ 130.9096; 10,830,000 / 92,903.04 ≈ 116.5731.
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle,
        pageOf(doc).copyWith(
            displayUnit: DisplayUnit.feetInches, scaleDenominator: 100)));
    expect(fieldOf(doc, f.b, 'area').value, '130.91 ft²');
    expect(fieldOf(doc, f.b, 'area').value, textOf(doc, labelsOf(doc, f.b)[1]));
    expect(fieldOf(doc, f.a, 'area').value, '116.57 ft²');
    doc.commands.undo();
    expect(fieldOf(doc, f.a, 'area').value, '10.83 m²');

    // The separator is the page's, as drawn, whatever the UI language's
    // (KitWords.decimalSeparator is not read): German words with ',' read
    // the point the page draws, and the comma once the page draws one.
    final german = KitNamesWords(
        architectureKit.names, () => const Locale('de'),
        decimalSeparator: () => ',');
    String areaIn(KitWords w) =>
        roomPlanType.fieldsOf(doc, f.b, w)[1].value! as String;
    expect(areaIn(german), '12.16 m²');
    doc.commands.execute(SetComponentCommand<PageComponent>(doc.rootHandle,
        pageOf(doc).copyWith(decimalSeparator: DecimalSeparator.comma)));
    expect(areaIn(german), '12,16 m²');
    expect(areaIn(words), '12,16 m²');
    expect(fieldOf(doc, f.a, 'area').value, '10,83 m²');
    doc.commands.undo();

    // A file's room that never regenerated has no label: the line reads
    // '—' and is shown.
    late Handle store;
    final loaded = reloadWithPage(staleFile(doc, (bare) {
      store = addRoom(bare, f.plan.at(7000.25, 2000.5), 'Store');
    }));
    expect(kids(loaded, store), isEmpty, reason: 'premise: no children');
    final line = roomPlanType.fieldsOf(loaded, store, words)[1];
    expect(line.value, '—');
    expect(line.visible, isTrue);
  });

  test(
      'RM-colour the colour target is the room\'s palette name; recolouring '
      'is one SetComponentCommand that keeps the rest (M-RM-7)', () {
    final f = rooms();
    final doc = f.plan.doc;
    expect(roomPlanType.hasColour, isTrue);
    expect(roomPlanType.colourOf(doc, f.a), isNull);
    doc.commands.execute(roomPlanType.recolour(doc, f.a, 'teal')!);
    expect(doc.components.get<RoomParams>(f.a)!.color, 'teal');
    expect(roomPlanType.colourOf(doc, f.a), 'teal');
    expect(roomPlanType.recolour(doc, f.a, 'teal'), isNull,
        reason: 'already teal');
    doc.commands.execute(roomPlanType.recolour(doc, f.a, null)!);
    final p = doc.components.get<RoomParams>(f.a)!;
    expect((p.color, p.name), (null, 'Kitchen'));
    expect(doc.commands.undoDepth, 2);
  });

  test(
      'RM-grips the label grip returns to auto within the snap aperture at '
      'the camera\'s scale; a room is not movable (M-RM-8, M-RM-9)', () {
    final f = rooms();
    final doc = f.plan.doc;
    // 0.25 px per mm: the aperture is kSnapAperturePixels / 0.25 = 40 mm.
    final services =
        FakePlanServices(document: doc, catalog: testCatalog(), scale: 0.25);
    addTearDown(services.dispose);
    final grips = roomPlanType.gripsFor(services)!;
    expect(grips.movable(doc, f.b), isFalse);
    // B's label is auto: its grip is its pole.
    final g = grips.gripsOf(doc, f.b).single;
    final pole = Vector2(g.x, g.y);
    expect(grips.drag(doc, f.b, g, pole + Vector2(0.6 * 36, -0.8 * 36)), isNull,
        reason: '36 mm from the pole: auto stays auto');
    expect(grips.drag(doc, f.b, g, pole + Vector2(0.6 * 44, -0.8 * 44)),
        isA<SetComponentCommand<RoomParams>>(),
        reason: '44 mm from the pole: an offset');
  });
}
