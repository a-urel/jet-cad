import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';

import 'support/shots.dart';

void main() {
  setUpAll(loadManifestFonts);

  test('FT1 Roboto is a real face, not Ahem', () {
    // Ahem advances every glyph one em: "Mi" at 20 px is 40 px wide.
    final painter = TextPainter(
        text: const TextSpan(
            text: 'Mi', style: TextStyle(fontFamily: 'Roboto', fontSize: 20)),
        textDirection: TextDirection.ltr)
      ..layout();
    expect(painter.width, isNot(40.0));
    expect(painter.width, inInclusiveRange(15.0, 35.0));
  });

  testWidgets('FT2 a Material icon inks a glyph, not a box', (tester) async {
    const black = Color(0xFF000000);
    await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const RepaintBoundary(
              key: ValueKey('icon'),
              child: Icon(Icons.add, size: 100, color: black)),
          // The same glyph in a family nobody loaded: Ahem's tofu.
          RepaintBoundary(
              key: const ValueKey('tofu'),
              child: Text(String.fromCharCode(Icons.add.codePoint),
                  style: const TextStyle(
                      fontFamily: 'NoSuchFamily',
                      fontSize: 100,
                      color: black))),
        ])));
    Future<double> ink(String key) async {
      final boundary =
          tester.renderObject<RenderRepaintBoundary>(find.byKey(ValueKey(key)));
      return (await tester.runAsync(() async {
        final image = await boundary.toImage();
        final raw =
            (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        var n = 0;
        for (var i = 3; i < raw.lengthInBytes; i += 4) {
          if (raw.getUint8(i) > 128) n++;
        }
        final all = image.width * image.height;
        image.dispose();
        return n / all;
      }))!;
    }

    final icon = await ink('icon');
    final tofu = await ink('tofu');
    expect(icon, greaterThan(0.02), reason: 'the icon drew something');
    // A plus covers a fraction of its box; the tofu covers far more.
    expect(icon, lessThan(0.5 * tofu), reason: 'icon $icon, tofu $tofu');
  });

  testWidgets('SH3 without UPDATE_SCREENSHOTS nothing is written',
      (tester) async {
    if (updating) return; // the generator's own run writes, by design
    final dir = Directory('../../packages/jet_cad_2d_flutter/doc/screenshots');
    final before = dir.existsSync()
        ? {for (final f in dir.listSync()) f.path: f.statSync().modified}
        : const <String, DateTime>{};
    await pumpScene(tester, const ColoredBox(color: Color(0xFFFFFFFF)));
    await shoot(tester, package: 'jet_cad_2d_flutter', file: 'probe.png');
    expect(File('${dir.path}/probe.png').existsSync(), isFalse);
    final after = dir.existsSync()
        ? {for (final f in dir.listSync()) f.path: f.statSync().modified}
        : const <String, DateTime>{};
    expect(after, before);
  });
}
