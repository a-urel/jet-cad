import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/spy_canvas.dart';

const TextStyleRecord _roboto =
    TextStyleRecord(handle: Handle(11), name: 'Standard', fontFamily: 'Roboto');

/// A label whose collection-space box is [minX, minY]..[maxX, maxY], upright,
/// baseline at its box's bottom. Text, style and colour are the same for all
/// three; only the box moves.
ResidentTextRecord label(double minX, double minY, double maxX, double maxY) =>
    ResidentTextRecord(
        text: 'LABEL',
        style: const Handle(11),
        argb: 0xFF000000,
        a: 1,
        b: 0,
        c: 0,
        d: -1,
        e: minX,
        f: maxY,
        boxMinX: minX,
        boxMinY: minY,
        boxMaxX: maxX,
        boxMaxY: maxY,
        instanceIndex: 0);

void main() {
  test(
      'labels outside the viewport are skipped; inside and straddling are drawn',
      () {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final compositor =
        TextCompositor(measurer: measurer, textStyleOf: (_) => _roboto);
    const viewport = Size(400, 300);
    // The outer transform is a pan of (-1000, 0): a label at x 1020..1100 in
    // collection space lands at 20..100 on screen (inside), one at 400..480
    // lands at -600..-520 (outside, left), one at 970..1030 straddles x = 0,
    // one at 1000..1080 / y 900..950 is below the viewport (outside).
    final outer = Transform2.translation(-1000, 0);
    final texts = <ResidentTextRecord>[
      label(1020, 100, 1100, 130),
      label(400, 100, 480, 130),
      label(970, 200, 1030, 230),
      label(1000, 900, 1080, 950),
    ];
    final spy = SpyCanvas();
    compositor.paint(spy,
        main: null,
        viewport: viewport,
        collectionToLogical: outer,
        texts: texts,
        patches: const <PatchImage>[]);
    // MUTATION (M-F11): invert the rejection -> 2 paragraphs skipped, 2 drawn
    // -- the wrong two, and `text_order_test.dart`'s composited differential
    // goes red with it.
    expect(spy.named('drawParagraph').length, 2,
        reason: 'the inside label and the straddling one');
    expect(compositor.labelsSkipped, 2);
    // Anti-vacuity: with a pan that brings every label on screen, all four
    // draw and nothing is skipped.
    final all = SpyCanvas();
    compositor.paint(all,
        main: null,
        viewport: const Size(2000, 2000),
        collectionToLogical: Transform2.identity(),
        texts: texts,
        patches: const <PatchImage>[]);
    expect(all.named('drawParagraph').length, 4);
    expect(compositor.labelsSkipped, 0);
  });
}
