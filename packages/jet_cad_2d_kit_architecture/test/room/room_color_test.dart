// Plan colours spec PC-1 and PC-3: a room's colour. `RoomParams.color` is a
// fourth JSON key (a palette name, or null); a coloured room's tint is its
// hue at 20 %; recolouring an existing room recolours its existing tint in
// the same undo step (the engine's stamp, Task 1); a name this release does
// not know is kept and drawn as today's tint; a plan saved by 0.5.1 (schema
// 9, no `color` key) opens with its tints byte for byte.
//
// The plan is the two-room rectangle at the corpus far origin, turned 23°,
// every wall in its own rotated, translated group; room A sits in a group
// of its own turned 0.61 rad (as a file may hold one), room B at the
// identity (as the Room tool makes one). Fractional seeds. The hues under
// test are `teal` and `purple`, never the first of the palette, and
// `magenta`, a name no release knows.
// Ported from jet_cad_floor_plan/test/room_color_test.dart (the fixture
// case, RC1-RC7; RC8 runs in jet_cad_2d_integration); assertions unchanged
// but the palette's names (PlanSwatch, planSwatchNamed, the contract's) and
// RC6's component id (spec 3a C7 class 1: ids).
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show PlanSwatch, planSwatchNamed;
import 'package:jet_cad_2d_kit_architecture/src/room/room.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show FlutterTextMeasurer;

import '../support/room_fixture.dart';

/// [room]'s tint records: its fill and the boundary the fill names (D9
/// steps 1 and 2), or its closed POLYLINE (step 3).
List<EntityRecord> tintRecords(DraftDocument doc, Handle room) {
  final all = kids(doc, room);
  final fills = [
    for (final k in all)
      if (kindOf(doc, k) == EntityKind.fill) k
  ];
  if (fills.isNotEmpty) {
    final boundary = Handle(payloadOf(doc, fills.single).scalars[0].toInt());
    return [recordOf(doc, fills.single), recordOf(doc, boundary)];
  }
  return [
    for (final k in all)
      if (kindOf(doc, k) == EntityKind.polyline) recordOf(doc, k),
  ];
}

DraftCommand recolor(DraftDocument doc, Handle room, String? color) =>
    SetComponentCommand<RoomParams>(
        room, doc.components.get<RoomParams>(room)!.copyWith(color: color));

/// Entity [h] whole: its record as saved and its payload's numbers.
String snapOf(DraftDocument doc, Handle h) {
  final p = payloadOf(doc, h);
  return jsonEncode([
    recordOf(doc, h).toJson(),
    p.coords.toList(),
    p.scalars.toList(),
  ]);
}

/// Every child of [room] whole, by handle.
Map<Handle, String> childSnaps(DraftDocument doc, Handle room) =>
    {for (final k in kids(doc, room)) k: snapOf(doc, k)};

/// Every tint record of [room] whole.
List<String> tintSnaps(DraftDocument doc, Handle room) => [
      for (final r in tintRecords(doc, room)) snapOf(doc, r.handle),
    ];

typedef Fixture = ({Plan plan, DraftDocument doc, Handle a, Handle b});

/// The two-room plan at [corpusGroups]: A turned 0.61 rad in a group of its
/// own, B at the identity, both uncoloured; the parametric system stays
/// installed and the history is cleared.
Fixture fixture() {
  final plan = buildPlan(twoRoomWalls,
      place: corpusGroups, measurer: FlutterTextMeasurer());
  final doc = plan.doc;
  attachPage(doc, PageComponent());
  final at = plan.at(1400, 1900);
  final g =
      Transform2.translation(at.x, at.y).multiply(Transform2.rotation(0.61));
  final a = addRoom(doc, plan.at(1500.25, 2000.5), 'Kitchen', at: g);
  final b = addRoom(doc, plan.at(4700.75, 1900.25), 'Room 2');
  doc.commands.clearHistory();
  return (plan: plan, doc: doc, a: a, b: b);
}

/// The palette hues under test, as a tint stores them.
const tealTint = TrueColor(0x00897B);
const purpleTint = TrueColor(0x8E24AA);

void main() {
  test('the fixture: room A is off the identity, the rooms are uncoloured', () {
    final f = fixture();
    final g = f.doc.tree.accumulatedTransform(f.a);
    expect(g.b, isNot(0));
    expect(f.doc.components.get<RoomParams>(f.a)!.color, isNull);
    expect(f.doc.components.get<RoomParams>(f.b)!.color, isNull);
    for (final r in [f.a, f.b]) {
      for (final t in tintRecords(f.doc, r)) {
        expect(t.color, const IndexedColor(7));
        expect(t.transparency, kRoomTintTransparency);
      }
    }
    expect(driftOf(f.doc), isEmpty);
  });

  test(
      'RC1 RoomParams JSON: color is the fourth key, null when none; a '
      'schema 9 room reads null; an unknown name is kept; a wrong type '
      'throws; copyWith', () {
    const teal = RoomParams(1234.5, -987.25, 'Room 1', color: 'teal');
    const none = RoomParams(1234.5, -987.25, 'Room 1');
    expect(jsonEncode(teal.toJson()),
        '{"seed":[1234.5,-987.25],"name":"Room 1","label":null,"color":"teal"}');
    expect(jsonEncode(none.toJson()),
        '{"seed":[1234.5,-987.25],"name":"Room 1","label":null,"color":null}');
    for (final p in [teal, none]) {
      final back = RoomParams.fromJson(
          jsonDecode(jsonEncode(p.toJson())) as Map<String, Object?>);
      expect(back, p);
      expect(back.hashCode, p.hashCode);
    }

    // A schema 9 room: three keys.
    final v9 = RoomParams.fromJson({
      'seed': [1234.5, -987.25],
      'name': 'Room 1',
      'label': null,
    });
    expect(v9.color, isNull);
    expect(v9, none);

    // A name this release does not know is kept, and is no palette entry.
    final magenta = RoomParams.fromJson({
      'seed': [1234.5, -987.25],
      'name': 'Room 1',
      'label': null,
      'color': 'magenta',
    });
    expect(magenta.color, 'magenta');
    expect(magenta.colorValue, isNull);
    expect(
        jsonEncode(magenta.toJson()),
        '{"seed":[1234.5,-987.25],"name":"Room 1","label":null,'
        '"color":"magenta"}');

    // A wrong type throws, as it does for `name`.
    expect(
        () => RoomParams.fromJson({
              'seed': [1234.5, -987.25],
              'name': 'Room 1',
              'label': null,
              'color': 7,
            }),
        throwsA(isA<TypeError>()));
    expect(
        () => RoomParams.fromJson({
              'seed': [1234.5, -987.25],
              'name': 7,
              'label': null,
              'color': null,
            }),
        throwsA(isA<TypeError>()));

    // copyWith: null clears, left out keeps, another field keeps it (M-C22).
    expect(teal.copyWith(color: null), none);
    expect(teal.copyWith(), teal);
    expect(teal.copyWith(name: 'X').color, 'teal');
    expect(teal.copyWith(name: 'X'),
        const RoomParams(1234.5, -987.25, 'X', color: 'teal'));
    expect(teal.copyWith(seedX: 5).color, 'teal');
    expect(none.copyWith(color: 'teal'), teal);
    expect(none == teal, isFalse);
  });

  test(
      'RC2 recolouring an existing room recolours its existing tint in one '
      'undo step: the same children, the labels untouched; undo and redo', () {
    final f = fixture();
    final doc = f.doc;
    final before = canon(doc);
    final kids0 = kids(doc, f.a);
    final labels0 = {for (final l in labelsOf(doc, f.a)) l: snapOf(doc, l)};
    final b0 = childSnaps(doc, f.b);
    final depth = doc.commands.undoDepth;

    doc.commands.execute(recolor(doc, f.a, 'teal'));
    expect(doc.commands.undoDepth, depth + 1, reason: 'one undo step');
    expect(kids(doc, f.a), kids0, reason: 'the same handles (D18)');
    expect(tintRecords(doc, f.a), hasLength(2));
    for (final t in tintRecords(doc, f.a)) {
      expect(t.color, tealTint);
      expect(t.transparency, kRoomColorTransparency);
      expect(t.transparency, 204);
    }
    expect({for (final l in labelsOf(doc, f.a)) l: snapOf(doc, l)}, labels0);
    expect(childSnaps(doc, f.b), b0, reason: 'room B untouched');
    expect(driftOf(doc), isEmpty);
    final after = canon(doc);

    doc.commands.undo();
    for (final t in tintRecords(doc, f.a)) {
      expect(t.color, const IndexedColor(7));
      expect(t.transparency, kRoomTintTransparency);
    }
    expect(canon(doc), before, reason: 'undo restores the bytes');

    doc.commands.redo();
    for (final t in tintRecords(doc, f.a)) {
      expect(t.color, tealTint);
      expect(t.transparency, 204);
    }
    expect(canon(doc), after, reason: 'redo is the recolour again');

    // The last leg: a rename after the recolour keeps the colour (M-C22).
    doc.commands.execute(renameRoom(doc, f.a, 'Pantry'));
    expect(doc.components.get<RoomParams>(f.a)!.color, 'teal');
    for (final t in tintRecords(doc, f.a)) {
      expect(t.color, tealTint);
      expect(t.transparency, 204);
    }
    expect(labelStrings(doc, f.a).first, 'Pantry');
  });

  test(
      'RC3 purple, then none: the tint is back to ACI 7 at 229 exactly; '
      'room B is untouched throughout', () {
    final f = fixture();
    final doc = f.doc;
    final a0 = childSnaps(doc, f.a);
    final b0 = childSnaps(doc, f.b);

    doc.commands.execute(recolor(doc, f.a, 'purple'));
    for (final t in tintRecords(doc, f.a)) {
      expect(t.color, purpleTint);
      expect(t.transparency, 204);
    }
    expect(childSnaps(doc, f.b), b0);

    doc.commands.execute(recolor(doc, f.a, null));
    for (final t in tintRecords(doc, f.a)) {
      expect(t.color, const IndexedColor(7));
      expect(t.transparency, 229);
    }
    expect(childSnaps(doc, f.a), a0,
        reason: 'purple, then none: every child as it was');
    expect(childSnaps(doc, f.b), b0);
    expect(driftOf(doc), isEmpty);
  });

  test(
      'RC4 an unknown colour name is kept, saved back and drawn as today\'s '
      'tint', () {
    final f = fixture();
    final doc = f.doc;
    final a0 = childSnaps(doc, f.a);
    doc.commands.execute(SetComponentCommand<RoomParams>(
        f.a, doc.components.get<RoomParams>(f.a)!.copyWith(color: 'magenta')));
    expect(doc.components.get<RoomParams>(f.a)!.color, 'magenta');
    expect(doc.components.get<RoomParams>(f.a)!.colorValue, isNull);
    for (final t in tintRecords(doc, f.a)) {
      expect(t.color, const IndexedColor(7));
      expect(t.transparency, 229);
    }
    expect(childSnaps(doc, f.a), a0, reason: 'today\'s tint, bit for bit');
    expect(enc(doc), contains('"color":"magenta"'));
    expect(driftOf(doc), isEmpty);

    final loaded = reloadWithPage(enc(doc));
    expect(loaded.components.get<RoomParams>(f.a)!.color, 'magenta');
    expect(enc(loaded), enc(doc), reason: 'saved back as read');
    expect(driftOf(loaded), isEmpty);
  });

  test('RC5 colorValue is the palette entry; the eight hues are the spec\'s',
      () {
    expect([for (final c in PlanSwatch.values) c.name],
        ['red', 'orange', 'yellow', 'green', 'teal', 'blue', 'purple', 'grey']);
    expect([
      for (final c in PlanSwatch.values) c.rgb
    ], [
      0xE53935,
      0xFB8C00,
      0xFDD835,
      0x43A047,
      0x00897B,
      0x1E88E5,
      0x8E24AA,
      0x757575,
    ]);
    for (final c in PlanSwatch.values) {
      expect(RoomParams(1, 2, 'R', color: c.name).colorValue, c);
      expect(planSwatchNamed(c.name), c);
    }
    expect(const RoomParams(1, 2, 'R').colorValue, isNull);
    expect(const RoomParams(1, 2, 'R', color: 'magenta').colorValue, isNull);
    expect(const RoomParams(1, 2, 'R', color: 'Teal').colorValue, isNull,
        reason: 'names are exact');
    expect(planSwatchNamed(null), isNull);
  });

  test(
      'RC6 a plan saved by 0.5.1 with rooms: edits that regenerate its rooms '
      'leave the tints ACI 7 at 229, and drift() stays empty', () {
    final f = fixture();
    final saved = jsonDecode(enc(f.doc)) as Map<String, Object?>;

    // The 0.5.1 file, by bytes: schemaVersion 9, no `color` key on a room.
    expect(saved['schemaVersion'], 10);
    final rooms = (saved['components']! as Map)['architecture.room']! as Map;
    expect(rooms, hasLength(2));
    for (final r in rooms.values) {
      expect((r as Map).remove('color'), isNull);
      expect(r.keys, ['seed', 'name', 'label']);
    }
    saved['schemaVersion'] = 9;
    final v9 = jsonEncode(saved);
    expect(v9, isNot(contains('"color":null')));

    final doc = reloadWithPage(v9);
    for (final r in [f.a, f.b]) {
      expect(doc.components.get<RoomParams>(r)!.color, isNull);
      expect(tintSnaps(doc, r), tintSnaps(f.doc, r), reason: 'opened as saved');
    }
    expect(driftOf(doc), isEmpty, reason: 'nothing to plan on open');
    final a0 = tintSnaps(doc, f.a), b0 = tintSnaps(doc, f.b);
    // The records as saved (the geometry is the payload's, not the record's):
    // a regeneration that moves the tint must leave every record field alone.
    final records0 = {
      for (final r in [f.a, f.b])
        r: [for (final t in tintRecords(doc, r)) jsonEncode(t.toJson())],
    };

    // A rename regenerates room A.
    final gens = debugRoomGenerates;
    doc.commands.execute(renameRoom(doc, f.a, 'Pantry'));
    expect(debugRoomGenerates, greaterThan(gens), reason: 'A regenerated');
    expect(tintSnaps(doc, f.a), a0, reason: 'A\'s tint, bit for bit');
    expect(tintSnaps(doc, f.b), b0);
    expect(driftOf(doc), isEmpty);

    // A wall moved by 0.5 mm regenerates both rooms.
    final gens2 = debugRoomGenerates;
    doc.commands.execute(
        moveWall(f.plan, 0, const W(0, 0.5, 8000, 0.5, 200), doc: doc));
    expect(debugRoomGenerates, gens2 + 2, reason: 'both rooms regenerated');
    for (final r in [f.a, f.b]) {
      expect(tintRecords(doc, r), hasLength(2));
      for (final t in tintRecords(doc, r)) {
        expect(t.color, const IndexedColor(7));
        expect(t.transparency, 229);
      }
      expect([for (final t in tintRecords(doc, r)) jsonEncode(t.toJson())],
          records0[r],
          reason: 'room $r: every tint record whole, as before the edit');
    }
    expect(tintSnaps(doc, f.a), isNot(a0), reason: 'A\'s tint did move');
    expect(tintSnaps(doc, f.b), isNot(b0), reason: 'B\'s tint did move');
    expect(driftOf(doc), isEmpty);

    // Saved again, a room carries `"color":null` (schema 10).
    final again = jsonDecode(enc(doc)) as Map<String, Object?>;
    expect(again['schemaVersion'], 10);
    expect('"color":null'.allMatches(enc(doc)).length, greaterThanOrEqualTo(2));
  });

  test(
      'RC7 step 3: the outline of a room whose tint does not triangulate '
      'takes the hue, stays invisible and keeps its transparency', () {
    addTearDown(() => debugTintFailedSteps = null);
    final plan = buildPlan(boxWalls,
        place: corpusGroups, measurer: FlutterTextMeasurer());
    final doc = plan.doc;
    attachPage(doc, PageComponent());
    final at = plan.at(1000, 1900);
    final g =
        Transform2.translation(at.x, at.y).multiply(Transform2.rotation(0.61));
    debugTintFailedSteps = {1, 2};
    final room = addRoom(doc, plan.at(1000.25, 3000.5), 'Room 1', at: g);
    final kids0 = kids(doc, room);
    expect(kindsOf(doc, room).toSet(), {EntityKind.text, EntityKind.polyline},
        reason: 'step 3: an outline, no fill');
    final outline = tintRecords(doc, room).single;
    expect(outline.color, const IndexedColor(7));
    expect(outline.flags & EntityFlags.invisible, isNot(0));
    final transparency0 = outline.transparency;

    doc.commands.execute(recolor(doc, room, 'teal'));
    expect(kids(doc, room), kids0, reason: 'the same children');
    final after = tintRecords(doc, room).single;
    expect(after.handle, outline.handle);
    expect(after.color, tealTint);
    expect(after.flags, outline.flags);
    expect(after.flags & EntityFlags.invisible, isNot(0));
    expect(after.transparency, transparency0);
    expect(driftOf(doc), isEmpty);
  });
}
