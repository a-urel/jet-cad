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
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui;

import 'package:jet_cad_floor_plan/src/colors/plan_color.dart';
import 'package:jet_cad_floor_plan/src/export/export_bytes.dart'
    show exportBytes;
import 'package:jet_cad_floor_plan/src/export/export_dialog.dart'
    show ExportChoice, ExportFormat;
import 'package:jet_cad_floor_plan/src/parametric/room.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ExportDpi, FlutterTextMeasurer;

import 'support/room_fixture.dart';

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
    expect([for (final c in FloorPlanColor.values) c.name],
        ['red', 'orange', 'yellow', 'green', 'teal', 'blue', 'purple', 'grey']);
    expect([
      for (final c in FloorPlanColor.values) c.rgb
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
    for (final c in FloorPlanColor.values) {
      expect(RoomParams(1, 2, 'R', color: c.name).colorValue, c);
      expect(floorPlanColorNamed(c.name), c);
    }
    expect(const RoomParams(1, 2, 'R').colorValue, isNull);
    expect(const RoomParams(1, 2, 'R', color: 'magenta').colorValue, isNull);
    expect(const RoomParams(1, 2, 'R', color: 'Teal').colorValue, isNull,
        reason: 'names are exact');
    expect(floorPlanColorNamed(null), isNull);
  });

  test(
      'RC6 a plan saved by 0.5.1 with rooms: edits that regenerate its rooms '
      'leave the tints ACI 7 at 229, and drift() stays empty', () {
    final f = fixture();
    final saved = jsonDecode(enc(f.doc)) as Map<String, Object?>;

    // The 0.5.1 file, by bytes: schemaVersion 9, no `color` key on a room.
    expect(saved['schemaVersion'], 10);
    final rooms = (saved['components']! as Map)['floor_planner.room']! as Map;
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

  testWidgets(
      'RC8 the export draws a coloured room\'s tint in its hue at 20 %, and '
      'an uncoloured one\'s as before: PNG pixels inside two rooms',
      (tester) async {
    final f = fixture();
    final doc = f.doc;
    // A page that holds the plan at the corpus far origin, turned 23 deg:
    // its lower-left corner 3 m west and 2 m south of the plan's origin; no
    // grid line to fall on a sampled pixel.
    final base = f.plan.at(0, 0);
    final page = PageComponent(
        originX: base.x - 3000, originY: base.y - 2000, gridVisible: false);
    attachPage(doc, page);

    const dpi = 96;
    const png96 = ExportChoice(format: ExportFormat.png, dpi: ExportDpi.d96);
    Future<({int w, int h, Uint8List rgba})> export() async =>
        (await tester.runAsync(() async {
          final bytes = await exportBytes(doc, page, png96,
              fontBytes: () async => throw StateError('a PNG reads no font'));
          final codec = await ui.instantiateImageCodec(bytes);
          final image = (await codec.getNextFrame()).image;
          codec.dispose();
          try {
            final data =
                (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
            return (
              w: image.width,
              h: image.height,
              rgba: data.buffer.asUint8List(),
            );
          } finally {
            image.dispose();
          }
        }))!;

    // Plan point (x, y) -> image pixel: `((x - ox) / den * u,
    // (oy + effH * den - y) / den * u)`, u = dpi / 25.4, computed from the
    // page's numbers, not through `pageCamera`.
    List<int> pixelAt(
        ({int w, int h, Uint8List rgba}) img, double px, double py) {
      final world = f.plan.at(px, py);
      final u = dpi / 25.4, den = page.scaleDenominator;
      final x = ((world.x - page.originX) / den * u).floor();
      final y =
          ((page.originY + page.effectiveHeightMm * den - world.y) / den * u)
              .floor();
      expect(x, inInclusiveRange(0, img.w - 1));
      expect(y, inInclusiveRange(0, img.h - 1));
      final i = (y * img.w + x) * 4;
      return [img.rgba[i], img.rgba[i + 1], img.rgba[i + 2], img.rgba[i + 3]];
    }

    // Away from walls and from both labels (seeds at (1500, 2000) and
    // (4700, 1900)): 0.4 m inside A's east wall, 0.9 m inside B's.
    const inA = (2400.0, 3300.0);
    const inB = (7000.0, 3000.0);

    // `rgb` composited at `alpha` over the white sheet, per channel.
    List<int> over(int rgb, int alpha) => [
          for (final s in [(rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF])
            (alpha / 255 * s + (1 - alpha / 255) * 255).round(),
        ];
    void expectNear(List<int> got, List<int> want, String reason) {
      expect(got[3], 255, reason: reason);
      for (var c = 0; c < 3; c++) {
        expect(got[c], closeTo(want[c], 2), reason: '$reason, channel $c');
      }
    }

    // Teal 0x00897B at alpha 51 (transparency 204); ACI 7, drawn black on
    // white, at alpha 26 (transparency 229). Literals, not the constants:
    // the pixels are what is under test.
    final teal = over(0x00897B, 51);
    final grey = over(0x000000, 26);
    expect(teal, [204, 231, 229]);
    expect(grey, [229, 229, 229]);

    // The control: nothing coloured, both rooms the grey tint.
    final plain = await export();
    expectNear(pixelAt(plain, inA.$1, inA.$2), grey, 'A uncoloured');
    expectNear(pixelAt(plain, inB.$1, inB.$2), grey, 'B uncoloured');

    // Room A teal: A's pixel takes the hue, B's stays the grey tint.
    doc.commands.execute(recolor(doc, f.a, 'teal'));
    final coloured = await export();
    expectNear(pixelAt(coloured, inA.$1, inA.$2), teal, 'A teal');
    expectNear(pixelAt(coloured, inB.$1, inB.$2), grey, 'B uncoloured');
  });
}
