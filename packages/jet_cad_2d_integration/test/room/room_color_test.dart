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
// Ported from jet_cad_floor_plan/test/room_color_test.dart (RC8; the
// fixture case and RC1-RC7 run in the kit) (spec 3a C6, C7); assertions
// unchanged. The plan is built by a PlanBuild over the architecture kit and
// exported by the plan library's PNG exporter, today's exportBytes
// (fixture changes).
import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/room_plans.dart';

DraftCommand recolor(DraftDocument doc, Handle room, String? color) =>
    SetComponentCommand<RoomParams>(
        room, doc.components.get<RoomParams>(room)!.copyWith(color: color));

/// Today's fixture() (room_color_test.dart:75-88): the two-room plan at
/// [corpusGroups], the app's opening page, A ('Kitchen') turned 0.61 rad in
/// a group of its own, B ('Room 2') at the identity, both uncoloured; built
/// and clean.
({RoomPlan p, DraftDocument doc, Handle a, Handle b}) fixture() {
  const place = corpusGroups;
  final at = place.at(1400, 1900);
  final g =
      Transform2.translation(at.x, at.y).multiply(Transform2.rotation(0.61));
  final p = roomPlan(twoRoomWalls, place: place, page: PageComponent(), rooms: [
    (x: 1500.25, y: 2000.5, name: 'Kitchen', label: null, at: g),
    (x: 4700.75, y: 1900.25, name: 'Room 2', label: null, at: null),
  ]);
  return (p: p, doc: p.doc, a: p.rooms[0], b: p.rooms[1]);
}

void main() {
  testWidgets(
      'RC8 the export draws a coloured room\'s tint in its hue at 20 %, and '
      'an uncoloured one\'s as before: PNG pixels inside two rooms',
      (tester) async {
    final f = fixture();
    final doc = f.doc;
    // A page that holds the plan at the corpus far origin, turned 23 deg:
    // its lower-left corner 3 m west and 2 m south of the plan's origin; no
    // grid line to fall on a sampled pixel.
    final base = f.p.at(0, 0);
    final page = PageComponent(
        originX: base.x - 3000, originY: base.y - 2000, gridVisible: false);
    doc.commands
        .execute(SetComponentCommand<PageComponent>(doc.rootHandle, page));

    const dpi = 96;
    const png96 = PlanExportChoice(dpi: PlanExportDpi.d96);
    Future<({int w, int h, Uint8List rgba})> export() async =>
        (await tester.runAsync(() async {
          final out = await f.p.c.export('plan.png', png96);
          final codec = await ui.instantiateImageCodec(out!.bytes);
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
      final world = f.p.at(px, py);
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
