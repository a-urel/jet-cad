import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/fixtures.dart';

// Every pixel read here runs under `tester.runAsync`: `Picture.toImage` and
// `toByteData` complete through engine callbacks the fake-async zone of a
// pumped test never delivers (spec F-15).

/// A one-instance document, the shape `placeSymbol` makes: a definition whose
/// base point is off the origin, placed by a rotated and mirrored instance far
/// from the origin, with the instance's colour BYBLOCK.
///
/// Its leaves are symmetric about [centre] (the definition's local point), so
/// the document's extents are centred on that point's world image whatever
/// the padding: the thumbnail's centre pixel lies on the thick BYBLOCK line.
DraftDocument lineSymbol() {
  final doc = DraftDocument.empty();
  const def = Handle(600);
  final centre = Vector2(300, 150);
  doc.tree.addDefinition(Definition(
      handle: def, name: 'line', basePoint: centre, children: const []));
  // The thick BYBLOCK line through the centre: 2 mm, about 15 device pixels
  // at DPR 2, so the centre pixel is well inside its ink.
  addEntity(doc, def, const Handle(601), EntityKind.line,
      [centre.x - 40, centre.y - 20, centre.x + 40, centre.y + 20], const [],
      color: const ByBlockColor(), lineweight: 200);
  // An explicitly coloured ring around it, so the document is not one leaf.
  addEntity(doc, def, const Handle(602), EntityKind.circle,
      [centre.x, centre.y], const [60],
      color: const IndexedColor(1));
  addInstance(
      doc,
      doc.rootHandle,
      const Handle(610),
      def,
      Transform2.translation(52000, -31000)
          .multiply(Transform2.rotation(0.7))
          .multiply(Transform2.scale(-1, 1)));
  return doc;
}

/// A second symbol, different everywhere: an open polyline and an arc.
DraftDocument hookSymbol() {
  final doc = DraftDocument.empty();
  const def = Handle(700);
  doc.tree.addDefinition(Definition(
      handle: def,
      name: 'hook',
      basePoint: Vector2(-120, 410),
      children: const []));
  addEntity(doc, def, const Handle(701), EntityKind.polyline,
      [-160, 380, -80, 380, -80, 460], const [],
      color: const ByBlockColor(), lineweight: 100);
  addEntity(doc, def, const Handle(702), EntityKind.arc, [-140, 440],
      const [25, 0.3, 2.4],
      color: const ByBlockColor(), lineweight: 100);
  addInstance(
      doc,
      doc.rootHandle,
      const Handle(710),
      def,
      Transform2.translation(-18000, 74000)
          .multiply(Transform2.rotation(-1.2))
          .multiply(Transform2.scale(1, -1)));
  return doc;
}

/// A symbol drawn only in a sub-pixel stroke: 0.05 mm, about 0.19 logical
/// pixels. Below one device pixel the sink keeps the pixel and fades the
/// alpha by the stroke's *device* width (`vertices_draw_sink.dart`
/// `_coveredArgb`), so its ink's alpha depends on the DPR the sink is given.
DraftDocument hairlineSymbol() {
  final doc = DraftDocument.empty();
  const def = Handle(800);
  doc.tree.addDefinition(Definition(
      handle: def,
      name: 'hair',
      basePoint: Vector2(640, -275),
      children: const []));
  // One line, not a polyline: a join overlaps two faded strokes and would
  // read darker than either.
  addEntity(doc, def, const Handle(801), EntityKind.line,
      [600, -300, 680, -250], const [],
      color: const ByBlockColor(), lineweight: 5);
  addInstance(
      doc,
      doc.rootHandle,
      const Handle(810),
      def,
      Transform2.translation(-37000, -91000)
          .multiply(Transform2.rotation(0.4))
          .multiply(Transform2.scale(-1, 1)));
  return doc;
}

const ui.Size kCell = ui.Size(48, 40);

Future<Uint8List> rgba(ui.Image image) async =>
    (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
        .buffer
        .asUint8List();

/// The pixel at ([x], [y]) composited over an opaque [background]
/// (`0xRRGGBB`), as the cell would show it. `rawRgba` is premultiplied.
List<int> over(Uint8List bytes, int width, int x, int y, int background) {
  final i = (y * width + x) * 4;
  final a = bytes[i + 3];
  int channel(int c, int shift) =>
      c + (((background >> shift) & 0xFF) * (255 - a) / 255).round();
  return [
    channel(bytes[i], 16),
    channel(bytes[i + 1], 8),
    channel(bytes[i + 2], 0),
  ];
}

/// The device-pixel box `(left, top, right, bottom)` of every pixel with
/// non-zero alpha, inclusive.
(int, int, int, int) inkBox(Uint8List bytes, int width, int height) {
  var l = width, t = height, r = -1, b = -1;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (bytes[(y * width + x) * 4 + 3] == 0) continue;
      if (x < l) l = x;
      if (x > r) r = x;
      if (y < t) t = y;
      if (y > b) b = y;
    }
  }
  return (l, t, r, b);
}

int peakAlpha(Uint8List bytes) {
  var peak = 0;
  for (var i = 3; i < bytes.length; i += 4) {
    if (bytes[i] > peak) peak = bytes[i];
  }
  return peak;
}

void main() {
  test('the fixtures are not degenerate', () {
    for (final (doc, instance) in [
      (lineSymbol(), const Handle(610)),
      (hookSymbol(), const Handle(710)),
    ]) {
      final def = doc.tree.definitions.single;
      expect(def.basePoint.length, greaterThan(100));
      final node = doc.tree[instance]!;
      expect(node.transform.isIdentity, isFalse);
      expect(node.transform.determinant, lessThan(0), reason: 'mirrored');
      expect(doc.extents.minX.abs(), greaterThan(1000));
    }
  });

  testWidgets('two documents give different pixels, each with ink',
      (tester) async {
    await tester.runAsync(() async {
      final thumbs = SymbolThumbnails();
      addTearDown(thumbs.dispose);
      Future<Uint8List> bytesOf(
          String key, DraftDocument Function() doc) async {
        final image = await thumbs.imageFor(
            key: key,
            document: doc,
            logicalSize: kCell,
            devicePixelRatio: 2,
            foreground: 0x000000);
        return rgba(image);
      }

      final a = await bytesOf('line@1', lineSymbol);
      final b = await bytesOf('hook@1', hookSymbol);
      int inked(Uint8List p) => [for (var i = 3; i < p.length; i += 4) p[i]]
          .where((v) => v > 0)
          .length;
      expect(inked(a), greaterThan(50));
      expect(inked(b), greaterThan(50));
      expect(a, isNot(equals(b)));
    });
  });

  testWidgets('the image is round(w * dpr) x round(h * dpr)', (tester) async {
    // MUTATION M-09b15: the image size ignores the DPR -> 41 x 31.
    await tester.runAsync(() async {
      final thumbs = SymbolThumbnails();
      addTearDown(thumbs.dispose);
      final image = await thumbs.imageFor(
          key: 'line@1',
          document: lineSymbol,
          logicalSize: const ui.Size(41.3, 30.6),
          devicePixelRatio: 2,
          foreground: 0x000000);
      expect([image.width, image.height], [83, 61]);
      final odd = await thumbs.imageFor(
          key: 'line@1',
          document: lineSymbol,
          logicalSize: const ui.Size(41.3, 30.6),
          devicePixelRatio: 1.5,
          foreground: 0x000000);
      expect([odd.width, odd.height], [62, 46]);
    });
  });

  testWidgets('the same request twice paints once and shares the future',
      (tester) async {
    await tester.runAsync(() async {
      final thumbs = SymbolThumbnails();
      addTearDown(thumbs.dispose);
      var builds = 0;
      DraftDocument counted() {
        builds++;
        return lineSymbol();
      }

      Future<ui.Image> ask() => thumbs.imageFor(
          key: 'line@1',
          document: counted,
          logicalSize: kCell,
          devicePixelRatio: 2,
          foreground: 0x000000);
      final pending = ask();
      final shared = ask();
      expect(identical(pending, shared), isTrue, reason: 'pending is shared');
      final first = await pending;
      final again = await ask();
      expect(builds, 1);
      expect(identical(first, again), isTrue);
    });
  });

  group('each part of the key paints anew', () {
    // MUTATION M-09k: the key's own part ignored -> 'line@2' hits 'line@1'.
    // MUTATION M-09x: the logical size, the DPR or the foreground ignored
    // (one case each) -> the second request hits the first.
    final base = (
      key: 'line@1',
      size: kCell,
      dpr: 2.0,
      foreground: 0x000000,
    );
    final cases = {
      'a version change': (
        key: 'line@2',
        size: base.size,
        dpr: base.dpr,
        foreground: base.foreground,
      ),
      'a logical size': (
        key: base.key,
        size: const ui.Size(56, 40),
        dpr: base.dpr,
        foreground: base.foreground,
      ),
      'a DPR': (
        key: base.key,
        size: base.size,
        dpr: 3.0,
        foreground: base.foreground,
      ),
      'a foreground': (
        key: base.key,
        size: base.size,
        dpr: base.dpr,
        foreground: 0xFFFFFF,
      ),
    };
    for (final MapEntry(key: name, value: other) in cases.entries) {
      testWidgets(name, (tester) async {
        await tester.runAsync(() async {
          final thumbs = SymbolThumbnails();
          addTearDown(thumbs.dispose);
          var builds = 0;
          DraftDocument counted() {
            builds++;
            return lineSymbol();
          }

          Future<ui.Image> ask(
                  ({String key, ui.Size size, double dpr, int foreground}) r) =>
              thumbs.imageFor(
                  key: r.key,
                  document: counted,
                  logicalSize: r.size,
                  devicePixelRatio: r.dpr,
                  foreground: r.foreground);
          final first = await ask(base);
          final second = await ask(other);
          expect(builds, 2);
          expect(identical(first, second), isFalse);
          expect(thumbs.length, 2);
          // And the first is still cached under its own key.
          expect(identical(await ask(base), first), isTrue);
          expect(builds, 2);
        });
      });
    }
  });

  testWidgets('eviction past maxEntries disposes the least recently used',
      (tester) async {
    // MUTATION M-09z: evicted images not disposed.
    await tester.runAsync(() async {
      final thumbs = SymbolThumbnails(maxEntries: 2);
      addTearDown(thumbs.dispose);
      var builds = 0;
      Future<ui.Image> ask(String key) => thumbs.imageFor(
          key: key,
          document: () {
            builds++;
            return lineSymbol();
          },
          logicalSize: kCell,
          devicePixelRatio: 2,
          foreground: 0x000000);
      final a = await ask('a@1');
      final b = await ask('b@1');
      // A hit makes 'a' the most recent; 'b' is now the oldest.
      expect(identical(await ask('a@1'), a), isTrue);
      final c = await ask('c@1');
      expect(b.debugDisposed, isTrue);
      expect(a.debugDisposed, isFalse);
      expect(c.debugDisposed, isFalse);
      expect(thumbs.length, 2);
      expect(builds, 3);
      // An evicted key paints again.
      await ask('b@1');
      expect(builds, 4);
      expect(a.debugDisposed, isTrue, reason: "'a' was the oldest then");
    });
  });

  testWidgets(
      'an entry evicted while pending lets its awaiting holder clone first',
      (tester) async {
    // MUTATION: dispose the pending-evicted image at once instead of a
    // microtask later -> the holder's clone throws (a disposed image).
    await tester.runAsync(() async {
      final thumbs = SymbolThumbnails(maxEntries: 1);
      addTearDown(thumbs.dispose);
      Future<ui.Image> ask(String key) => thumbs.imageFor(
          key: key,
          document: lineSymbol,
          logicalSize: kCell,
          devicePixelRatio: 2,
          foreground: 0x000000);
      final pending = ask('a@1');
      final other = ask('b@1'); // evicts 'a' before it completes
      final image = await pending;
      expect(image.debugDisposed, isFalse);
      final clone = image.clone();
      await Future<void>.delayed(Duration.zero);
      expect(image.debugDisposed, isTrue);
      expect(clone.debugDisposed, isFalse);
      expect(clone.width, 96);
      clone.dispose();
      expect((await other).debugDisposed, isFalse);
    });
  });

  testWidgets('dispose() disposes every image, and the cache refuses use',
      (tester) async {
    await tester.runAsync(() async {
      final thumbs = SymbolThumbnails();
      Future<ui.Image> ask(String key) => thumbs.imageFor(
          key: key,
          document: hookSymbol,
          logicalSize: kCell,
          devicePixelRatio: 2,
          foreground: 0x000000);
      final a = await ask('a@1');
      final b = await ask('b@1');
      expect([a.debugDisposed, b.debugDisposed], [false, false]);
      thumbs.dispose();
      expect([a.debugDisposed, b.debugDisposed], [true, true]);
      expect(thumbs.length, 0);
      expect(() => ask('c@1'), throwsStateError);
    });
  });

  testWidgets('the foreground makes a BYBLOCK leaf dark on a light cell',
      (tester) async {
    // MUTATION M-09y: the foreground not passed to the resolver -> the
    // default white ACI 7 vanishes into the light cell.
    const cell = 0xF4F1EA; // a light cell colour, not pure white
    expect(foregroundFor(0xFF000000 | cell), 0x000000);
    await tester.runAsync(() async {
      final thumbs = SymbolThumbnails();
      addTearDown(thumbs.dispose);
      Future<List<int>> centre(int foreground) async {
        final image = await thumbs.imageFor(
            key: 'line@1',
            document: lineSymbol,
            logicalSize: kCell,
            devicePixelRatio: 2,
            foreground: foreground);
        final bytes = await rgba(image);
        return over(
            bytes, image.width, image.width ~/ 2, image.height ~/ 2, cell);
      }

      final dark = await centre(foregroundFor(0xFF000000 | cell));
      expect(dark, everyElement(lessThan(40)), reason: 'black ink: $dark');
      // The control: the same pixel in white ink is light, so the dark
      // reading above is the ink's colour and not merely its coverage.
      final light = await centre(0xFFFFFF);
      expect(light, everyElement(greaterThan(215)), reason: 'white: $light');
    });
  });

  testWidgets(
      'a throwing builder completes with its error, never synchronously',
      (tester) async {
    await tester.runAsync(() async {
      final thumbs = SymbolThumbnails();
      addTearDown(thumbs.dispose);
      late Future<ui.Image> future;
      expect(
          () => future = thumbs.imageFor(
              key: 'broken@1',
              document: () => throw StateError('no such symbol'),
              logicalSize: kCell,
              devicePixelRatio: 2,
              foreground: 0x000000),
          returnsNormally);
      await expectLater(future, throwsA(isA<StateError>()));
      // The cache is still usable afterwards.
      final image = await thumbs.imageFor(
          key: 'line@1',
          document: lineSymbol,
          logicalSize: kCell,
          devicePixelRatio: 2,
          foreground: 0x000000);
      expect(image.width, 96);
    });
  });

  testWidgets('the padding keeps the ink off the border, and no further',
      (tester) async {
    // MUTATION (padding ignored): `pad = 0.0 * ...` -> the ink reaches the
    // outer two device pixels. MUTATION (fit on the raw extents): the same.
    // Too much padding instead fails the "reaches near an edge" half.
    await tester.runAsync(() async {
      final thumbs = SymbolThumbnails();
      addTearDown(thumbs.dispose);
      // `tight`: the document's extents hug the ink. The line symbol's do
      // not: its ring's extents are its local box turned by 0.7 rad, about
      // 1.4 times the ring, so only its border half is checked.
      for (final (name, doc, tight) in [
        ('line', lineSymbol, false),
        ('hook', hookSymbol, true),
        ('hair', hairlineSymbol, true),
      ]) {
        final image = await thumbs.imageFor(
            key: '$name@1',
            document: doc,
            logicalSize: kCell,
            devicePixelRatio: 2,
            foreground: 0x000000);
        final w = image.width, h = image.height;
        final (l, t, r, b) = inkBox(await rgba(image), w, h);
        final box = '$name: ink [$l, $t]..[$r, $b] in ${w}x$h';
        expect(r, greaterThanOrEqualTo(0), reason: '$box: no ink');
        expect([l, t], everyElement(greaterThanOrEqualTo(2)), reason: box);
        expect([w - 1 - r, h - 1 - b], everyElement(greaterThanOrEqualTo(2)),
            reason: box);
        // The fit is limited by one axis: on that axis the ink comes within
        // 15% of the image's side on both ends.
        final nearX = l <= 0.15 * w && w - 1 - r <= 0.15 * w;
        final nearY = t <= 0.15 * h && h - 1 - b <= 0.15 * h;
        if (tight) {
          expect(nearX || nearY, isTrue, reason: '$box: padded too far');
        }
      }
    });
  });

  testWidgets('the sink draws at the DPR: a sub-pixel stroke fades by it',
      (tester) async {
    // 0.05 mm is 0.189 logical px: 0.378 device px at DPR 2 (alpha about
    // 0.756 * 255 = 193), 0.189 at DPR 1 (about 96).
    // MUTATION (the sink's devicePixelRatio forced to 1.0): DPR 2 draws at
    // the DPR 1 alpha.
    await tester.runAsync(() async {
      final thumbs = SymbolThumbnails();
      addTearDown(thumbs.dispose);
      Future<int> peakAt(double dpr) async {
        final image = await thumbs.imageFor(
            key: 'hair@1',
            document: hairlineSymbol,
            logicalSize: kCell,
            devicePixelRatio: dpr,
            foreground: 0x000000);
        return peakAlpha(await rgba(image));
      }

      final one = await peakAt(1);
      final two = await peakAt(2);
      expect(one, inInclusiveRange(80, 110), reason: 'DPR 1 peak $one');
      expect(two, inInclusiveRange(175, 210), reason: 'DPR 2 peak $two');
    });
  });
}
