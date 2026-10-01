import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/export_fixture.dart';

/// Spec 13 T-7, T-8 (PNG) and T-9 (PNG), every one through `exportPagePng`
/// (spec "Route per test"), the pixels read back by decoding the returned
/// bytes. `toImage`, `toByteData` and the decode run under
/// `tester.runAsync` (plan 13 P-4).
///
/// The fixture's document measures with a `FlutterTextMeasurer` (Ahem under
/// flutter_test, P-5). Expected pixel positions are computed here from the
/// page's numbers and the fixture's world coordinates, **not** through
/// `pageCamera`: a world point `(x, y)` on a page whose lower-left corner is
/// `(ox, oy)` and whose sheet is `effH` mm high at 1:`den` lands at
/// `((x - ox) / den · u, (oy + effH · den - y) / den · u)` px, `u = dpi / 25.4`.
///
/// Named mutants: M-13a (the coverage check), M-13p (PNG), M-13s, M-13t,
/// M-13u; the hook restore on the PNG path.
void main() {
  /// [world] in image pixels on [page] at [dpi].
  ({double x, double y}) toPixel(PageComponent page, int dpi, Vector2 world) {
    final u = dpi / 25.4, den = page.scaleDenominator;
    return (
      x: (world.x - page.originX) / den * u,
      y: (page.originY + page.effectiveHeightMm * den - world.y) / den * u,
    );
  }

  Future<Uint8List> export(
    WidgetTester tester,
    DraftDocument document,
    PageComponent page, {
    ExportDpi dpi = ExportDpi.d150,
    Set<Handle> omitOwners = const {},
  }) async =>
      (await tester.runAsync(() => exportPagePng(
            document: document,
            page: page,
            dpi: dpi,
            omitOwners: omitOwners,
          )))!;

  Future<_Pixels> decode(WidgetTester tester, Uint8List png) async =>
      (await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(png);
        final frame = await codec.getNextFrame();
        codec.dispose();
        final image = frame.image;
        try {
          final data =
              (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          return _Pixels(image.width, image.height, data);
        } finally {
          image.dispose();
        }
      }))!;

  group('T-7: the pixel size is the effective sheet at the dpi, rounded', () {
    final f = exportFixture(measurer: FlutterTextMeasurer());
    // Written out from the paper, mm / 25.4 · dpi rounded to the nearest
    // pixel (A4 landscape at 150 dpi is 1753.94… × 1240.16…).
    const expected = {
      ('A4', 96): (794, 1123),
      ('A4', 150): (1240, 1754),
      ('A4', 300): (2480, 3508),
      ('A3', 96): (1123, 1587),
      ('A3', 150): (1754, 2480),
      ('A3', 300): (3508, 4961),
    };
    for (final (name, w, h) in [('A4', 210.0, 297.0), ('A3', 297.0, 420.0)]) {
      for (final orientation in PageOrientation.values) {
        for (final dpi in ExportDpi.values) {
          final page = f.page
              .copyWith(widthMm: w, heightMm: h, orientation: orientation);
          final (portraitW, portraitH) = expected[(name, dpi.value)]!;
          final (expectedW, expectedH) =
              orientation == PageOrientation.landscape
                  ? (portraitH, portraitW)
                  : (portraitW, portraitH);
          testWidgets(
              '$name ${orientation.name} at ${dpi.value} dpi is '
              '$expectedW × $expectedH', (tester) async {
            final png = await export(tester, f.document, page, dpi: dpi);
            final chunks = _chunks(png);
            final ihdr = ByteData.sublistView(chunks.first.data);
            expect(chunks.first.type, 'IHDR');
            expect(
                [ihdr.getUint32(0), ihdr.getUint32(4)], [expectedW, expectedH]);
          });
        }
      }
    }

    test('ExportDpi values are 96, 150 and 300', () {
      expect(ExportDpi.values.map((d) => d.value), [96, 150, 300]);
    });
  });

  group('T-7: pHYs', () {
    // round(dpi / 0.0254), written out: 3779.53…, 5905.51…, 11811.02….
    const ppm = {96: 3780, 150: 5906, 300: 11811};
    final f = exportFixture(measurer: FlutterTextMeasurer());
    for (final dpi in ExportDpi.values) {
      testWidgets(
          'at ${dpi.value} dpi: exactly one pHYs, right after IHDR and before '
          'the first IDAT, ${ppm[dpi.value]} px/m on both axes, unit 1, its '
          'CRC right', (tester) async {
        final png = await export(tester, f.document, f.page, dpi: dpi);
        final chunks = _chunks(png);
        final types = [for (final c in chunks) c.type];
        expect(types.where((t) => t == 'pHYs'), hasLength(1));
        expect(types.indexOf('pHYs'), 1, reason: '$types');
        expect(types.first, 'IHDR');
        expect(types.indexOf('pHYs'), lessThan(types.indexOf('IDAT')));
        final phys = chunks[1];
        final v = ByteData.sublistView(phys.data);
        expect(phys.data, hasLength(9));
        expect([v.getUint32(0), v.getUint32(4), v.getUint8(8)],
            [ppm[dpi.value], ppm[dpi.value], 1]);
        expect(phys.crc, _bitwiseCrc32([...'pHYs'.codeUnits, ...phys.data]));
        // Every other chunk's CRC still holds: nothing was spliced into one.
        for (final c in chunks) {
          expect(c.crc, _bitwiseCrc32([...c.type.codeUnits, ...c.data]),
              reason: c.type);
        }
      });
    }
  });

  group('T-7: the pixels', () {
    testWidgets(
        '"WC" (0.5 mm on paper, below the default LOD cull at 96 and 150 dpi) '
        'has dark pixels in its box at 150 and at 300 dpi', (tester) async {
      final f = exportFixture(measurer: FlutterTextMeasurer());
      for (final dpi in [ExportDpi.d150, ExportDpi.d300]) {
        final px = await decode(
            tester, await export(tester, f.document, f.page, dpi: dpi));
        // Cap height in px: 25 mm at 1:50 is 0.5 mm on paper.
        final cap = 25 / 50 * dpi.value / 25.4;
        final origin = toPixel(f.page, dpi.value, Vector2(10500, 4500));
        var dark = 0;
        for (var y = (origin.y - 2 * cap).floor(); y <= origin.y.ceil(); y++) {
          for (var x = origin.x.floor();
              x <= (origin.x + 4 * cap).ceil();
              x++) {
            if (px.at(x, y).take(3).every((c) => c < 0x80)) dark++;
          }
        }
        expect(dark, greaterThan(0),
            reason: 'no dark pixel in "WC"\'s box at ${dpi.value} dpi');
      }
    });

    testWidgets(
        'A3 portrait at 1:100, 300 dpi: a horizontal 0.50 mm line is its own '
        'colour on its row and white at ± (width / 2 + 2) px', (tester) async {
      final f = exportFixture(measurer: FlutterTextMeasurer());
      final a3 = f.page.copyWith(
        widthMm: 297,
        heightMm: 420,
        orientation: PageOrientation.portrait,
        scaleDenominator: 100,
      );
      f.document.commands.execute(
        SetComponentCommand<PageComponent>(f.document.rootHandle, a3),
      );
      _addLine(f.document, [20000, 20000, 30000, 20000],
          rgb: 0x5D4037, lineweight: 50);
      final px = await decode(
          tester, await export(tester, f.document, a3, dpi: ExportDpi.d300));
      expect([px.width, px.height], [3508, 4961]);

      const u = 300 / 25.4;
      final row = (-1500 + 420 * 100 - 20000) / 100 * u; // 2421.26…
      final halfWidth = 0.50 * u / 2; // 2.95… px
      final above = (row - halfWidth - 2).floor();
      final below = (row + halfWidth + 2).floor();
      for (final worldX in [21000.0, 25000.0, 29000.0]) {
        final x = ((worldX - 3000) / 100 * u).floor();
        expect(px.at(x, row.floor()), [0x5D, 0x40, 0x37, 0xFF],
            reason: 'on the line\'s row ${row.floor()} at x $x');
        expect(px.at(x, above), [255, 255, 255, 255], reason: 'row $above');
        expect(px.at(x, below), [255, 255, 255, 255], reason: 'row $below');
      }
    });

    testWidgets(
        'an oblique line, away from any text, has pixels of intermediate '
        'coverage (anti-aliased paths)', (tester) async {
      final f = exportFixture(measurer: FlutterTextMeasurer());
      final px = await decode(tester,
          await export(tester, f.document, f.page, dpi: ExportDpi.d300));
      // The fixture's root line (4000, 500)–(9000, 2500), 0x1565C0, 0.35 mm,
      // crossed by pixel columns at three points along it.
      const ink = [0x15, 0x65, 0xC0, 0xFF], white = [255, 255, 255, 255];
      var full = 0, partial = 0;
      for (final worldX in [5500.0, 6500.0, 7500.0]) {
        final worldY = 500 + (worldX - 4000) * 2000 / 5000;
        final p = toPixel(f.page, 300, Vector2(worldX, worldY));
        for (var y = p.y.floor() - 6; y <= p.y.floor() + 6; y++) {
          final c = px.at(p.x.floor(), y);
          if (_listEquals(c, ink)) {
            full++;
          } else if (!_listEquals(c, white)) {
            partial++;
            expect(c[3], 255, reason: 'opaque over the white ground');
          }
        }
      }
      expect(full, greaterThan(0), reason: 'the columns cross the line');
      expect(partial, greaterThan(0),
          reason: 'every pixel is either the ink or white: no anti-aliasing');
    });

    testWidgets('the corners outside the drawing are white and opaque',
        (tester) async {
      final f = exportFixture(measurer: FlutterTextMeasurer());
      final px = await decode(tester, await export(tester, f.document, f.page));
      expect([px.width, px.height], [1754, 1240]);
      for (final (x, y) in [
        (0, 0),
        (px.width - 1, 0),
        (0, px.height - 1),
        (px.width - 1, px.height - 1),
      ]) {
        expect(px.at(x, y), [255, 255, 255, 255], reason: '($x, $y)');
      }
    });
  });

  group('T-8 (PNG): the separator', () {
    // Every pixel whose centre is within the stroke's half width plus 1.5 px
    // of the separator's segment, at 150 dpi on the fixture's page.
    List<List<int>> band(ExportFixture f, _Pixels px) {
      final group =
          Transform2.translation(9200, 5200).multiply(Transform2.rotation(0.1));
      final a = toPixel(f.page, 150, group.transformPoint(Vector2(100, 150)));
      final b = toPixel(f.page, 150, group.transformPoint(Vector2(2600, 150)));
      final reach = 0.35 * 150 / 25.4 / 2 + 1.5;
      final dx = b.x - a.x, dy = b.y - a.y;
      final length = math.sqrt(dx * dx + dy * dy);
      final out = <List<int>>[];
      for (var y = (math.min(a.y, b.y) - reach).floor();
          y <= (math.max(a.y, b.y) + reach).ceil();
          y++) {
        for (var x = (math.min(a.x, b.x) - reach).floor();
            x <= (math.max(a.x, b.x) + reach).ceil();
            x++) {
          final cx = x + 0.5 - a.x, cy = y + 0.5 - a.y;
          final along = (cx * dx + cy * dy) / length;
          final across = (cx * dy - cy * dx).abs() / length;
          if (along >= 0 && along <= length && across <= reach) {
            out.add(px.at(x, y));
          }
        }
      }
      return out;
    }

    testWidgets(
        'with its group omitted every pixel of its band is white; without the '
        'set some are dark', (tester) async {
      final f = exportFixture(measurer: FlutterTextMeasurer());
      final omitted = band(
          f,
          await decode(
              tester,
              await export(tester, f.document, f.page,
                  omitOwners: {f.separatorGroup})));
      expect(omitted.length, greaterThan(500));
      expect(omitted, everyElement([255, 255, 255, 255]));

      final drawn = band(
          f, await decode(tester, await export(tester, f.document, f.page)));
      expect(drawn.where((c) => c.take(3).every((v) => v < 0x80)), isNotEmpty);
    });
  });

  group('T-9 (PNG): the document is untouched', () {
    testWidgets('the codec\'s bytes and the stateId are unchanged',
        (tester) async {
      final f = exportFixture(measurer: FlutterTextMeasurer());
      final codecBefore = DraftDocumentCodec.encodeToString(f.document);
      final stateBefore = f.document.commands.stateId;
      await export(tester, f.document, f.page, dpi: ExportDpi.d96);
      expect(stateBefore, isNot(0), reason: 'the fixture ran commands');
      expect(f.document.commands.stateId, stateBefore);
      expect(DraftDocumentCodec.encodeToString(f.document), codecBefore);
    });

    // A region nothing in the fixture reaches, for the "screen" index's
    // query after an edit.
    final probe = Aabb2(Vector2(19900, 19900), Vector2(20200, 20200));
    int count(SpatialIndex index) {
      var n = 0;
      index.forEachInRect(probe, const QueryFilter.all(), (_) => n++);
      return n;
    }

    testWidgets(
        'with a screen index on the document: the same hooks after a normal '
        'and a throwing export, and the screen index hears the next edit',
        (tester) async {
      final measurer = _ArmedMeasurer();
      final f = exportFixture(measurer: measurer);
      final screen = SpatialIndex(f.document);
      addTearDown(screen.dispose);
      final commands = f.document.commands;
      final after = commands.onAfterMutate, before = commands.onBeforeMutate;
      expect([after, before], everyElement(isNotNull));

      await export(tester, f.document, f.page, dpi: ExportDpi.d96);
      expect(commands.onAfterMutate, after, reason: 'normal export');
      expect(commands.onBeforeMutate, before, reason: 'normal export');

      measurer.armed = true;
      final error = await tester.runAsync(() async {
        try {
          await exportPagePng(
              document: f.document, page: f.page, dpi: ExportDpi.d96);
          return null;
        } on _Boom catch (e) {
          return e;
        }
      });
      measurer.armed = false;
      expect(error, isA<_Boom>(), reason: 'the paint threw');
      expect(commands.onAfterMutate, after, reason: 'throwing export');
      expect(commands.onBeforeMutate, before, reason: 'throwing export');

      expect(count(screen), 0);
      _addLine(f.document, [19950, 19950, 20100, 20100],
          rgb: 0x5D4037, lineweight: 35);
      expect(count(screen), 1, reason: 'the screen index saw the edit');
    });

    testWidgets('with no index on the document: no hook is left behind',
        (tester) async {
      final measurer = _ArmedMeasurer();
      final f = exportFixture(measurer: measurer);
      final commands = f.document.commands;
      expect([commands.onAfterMutate, commands.onBeforeMutate],
          everyElement(isNull));
      await export(tester, f.document, f.page, dpi: ExportDpi.d96);
      expect([commands.onAfterMutate, commands.onBeforeMutate],
          everyElement(isNull));
      measurer.armed = true;
      final error = await tester.runAsync(() async {
        try {
          await exportPagePng(
              document: f.document, page: f.page, dpi: ExportDpi.d96);
          return null;
        } on _Boom catch (e) {
          return e;
        }
      });
      measurer.armed = false;
      expect(error, isA<_Boom>());
      expect([commands.onAfterMutate, commands.onBeforeMutate],
          everyElement(isNull));
    });
  });
}

/// One decoded RGBA image.
final class _Pixels {
  _Pixels(this.width, this.height, this.data);

  final int width, height;
  final ByteData data;

  /// `[r, g, b, a]` at column [x], row [y].
  List<int> at(int x, int y) {
    final i = (y * width + x) * 4;
    return [
      data.getUint8(i),
      data.getUint8(i + 1),
      data.getUint8(i + 2),
      data.getUint8(i + 3),
    ];
  }
}

/// The PNG's chunks in order, each with its stored CRC.
List<({String type, Uint8List data, int crc})> _chunks(Uint8List png) {
  expect(png.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
  final view = ByteData.sublistView(png);
  final out = <({String type, Uint8List data, int crc})>[];
  var at = 8;
  while (at < png.length) {
    final length = view.getUint32(at);
    out.add((
      type: String.fromCharCodes(png, at + 4, at + 8),
      data: Uint8List.sublistView(png, at + 8, at + 8 + length),
      crc: view.getUint32(at + 8 + length),
    ));
    at += 12 + length;
  }
  expect(at, png.length);
  return out;
}

/// A Flutter measurer that, while [armed], throws [_Boom] when the painter
/// asks it for a text's metrics, so an export throws inside its paint (the
/// index's own measurements, made before the paint, still succeed).
final class _ArmedMeasurer implements TextMeasurer {
  final FlutterTextMeasurer _inner = FlutterTextMeasurer();
  bool armed = false;

  @override
  TextMetrics measure({required String text, required TextStyleRecord style}) {
    if (armed && StackTrace.current.toString().contains('DraftPainter.')) {
      throw const _Boom();
    }
    return _inner.measure(text: text, style: style);
  }
}

final class _Boom implements Exception {
  const _Boom();
}

/// CRC-32 bit by bit (reflected polynomial 0xEDB88320), independent of the
/// export's table-driven one.
int _bitwiseCrc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var k = 0; k < 8; k++) {
      crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}

bool _listEquals(List<int> a, List<int> b) =>
    a.length == b.length &&
    [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((e) => e);

/// A root line of [rgb] and [lineweight], added through a command.
void _addLine(
  DraftDocument doc,
  List<double> coords, {
  required int rgb,
  required int lineweight,
}) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(
    AddEntityCommand(
      record: EntityRecord(
        handle: handle,
        owner: doc.rootHandle,
        kind: EntityKind.line,
        layer: ReservedHandles.layerZero,
        linetype: ReservedHandles.continuousLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: TrueColor(rgb),
        lineweight: lineweight,
        transparency: 0,
        flags: 0,
      ),
      payload: GeometryPayload(
        coords: Float64List.fromList(coords),
        scalars: Float64List(0),
      ),
    ),
  );
}
