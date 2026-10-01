import 'dart:convert' show latin1;
import 'dart:io' show zlib;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/export_testing.dart';

/// The content reader's own tests (plan 13, P-2), on hand-written PDFs, so a
/// reader bug cannot make a sink test pass. Each test is named for the reader
/// bug it catches.
void main() {
  test(
      'cm premultiplies the CTM (a post-multiplying reader puts the point '
      'at x 220, not 120)', () {
    final c = read('1 0 0 1 100 0 cm 2 0 0 2 0 0 cm 10 10 m 20 10 l S');
    expect(xy(c.paths.single.subpaths.single.vertices), [
      [120, 20],
      [140, 20],
    ]);
  });

  test(
      'Q restores the CTM q saved (a reader without the stack keeps the '
      'inner cm)', () {
    final c = read('q 2 0 0 2 0 0 cm 1 1 m 2 2 l S Q 1 1 m 2 2 l S');
    expect(xy(c.paths[0].subpaths.single.vertices), [
      [2, 2],
      [4, 4],
    ]);
    expect(xy(c.paths[1].subpaths.single.vertices), [
      [1, 1],
      [2, 2],
    ]);
  });

  test(
      'Q restores colour, width and the ExtGState alpha (a reader that keeps '
      'them leaks state past Q)', () {
    final c = read(
      '1 0 0 RG 0.2 0.4 0.6 rg 3 w /a0 gs '
      'q 0 0 1 RG 1 1 1 rg 7 w /a1 gs 0 0 m 1 0 l S Q '
      '0 0 m 1 0 l S',
      resources: '/ExtGState 5 0 R',
      objects: [
        '5 0 obj\n<< /a0 << /CA .5 /ca .25 >> /a1 << /CA 1 /ca 1 >> >>'
            '\nendobj'
      ],
    );
    final inner = c.paths[0].state, outer = c.paths[1].state;
    expect(inner.strokeRgb, [0, 0, 1]);
    expect(inner.lineWidth, 7);
    expect([inner.strokeAlpha, inner.fillAlpha], [1, 1]);
    expect(outer.strokeRgb, [1, 0, 0]);
    expect(outer.fillRgb, [0.2, 0.4, 0.6]);
    expect(outer.lineWidth, 3);
    expect([outer.strokeAlpha, outer.fillAlpha], [0.5, 0.25]);
    expect(outer.extGStates, ['/a0']);
  });

  test(
      're is a closed subpath of four corners in order (a reader that leaves '
      'it open or misplaces a corner)', () {
    final c = read('10 20 30 40 re f');
    final p = c.paths.single;
    expect(p.paint, PdfPaint.fill);
    expect(p.subpaths.single.closed, isTrue);
    expect(xy(p.subpaths.single.vertices), [
      [10, 20],
      [40, 20],
      [40, 60],
      [10, 60],
    ]);
  });

  test(
      'h closes its subpath and only its subpath (a reader that ignores h or '
      'carries it to the next path)', () {
    final c = read('0 0 m 1 0 l 1 1 l h S 5 5 m 6 6 l S');
    expect(c.paths[0].subpaths.single.closed, isTrue);
    expect(c.paths[0].paint, PdfPaint.stroke);
    expect(c.paths[1].subpaths.single.closed, isFalse);
  });

  test(
      'numbers like .5, -0.25, 3, -.5 and 4. parse (a lexer that wants a '
      'leading digit or a fraction drops them)', () {
    final c = read('.5 -0.25 m 3 -.5 l 4. +2 l S');
    expect(xy(c.paths.single.subpaths.single.vertices), [
      [0.5, -0.25],
      [3, -0.5],
      [4, 2],
    ]);
  });

  test(
      'c keeps both controls, carried by the CTM (a reader that keeps only '
      'the end point or maps controls in user space)', () {
    final c = read('1 0 0 -1 0 100 cm 0 0 m 1 2 3 4 5 6 c S');
    final seg = c.paths.single.subpaths.single.segments.single;
    expect(seg.isCubic, isTrue);
    expect(xy(seg.controls), [
      [1, 98],
      [3, 96],
    ]);
    expect(xy([seg.to]), [
      [5, 94],
    ]);
  });

  test(
      'a non-symmetric cm maps (x, y) to (a·x + c·y + e, b·x + d·y + f) (a '
      'reader that applies the matrix transposed puts (10, 20) at (55, 116))',
      () {
    final c = read('1 2 3 4 5 6 cm 10 20 m 11 20 l S');
    expect(xy(c.paths.single.subpaths.single.vertices), [
      [75, 106],
      [76, 108],
    ]);
  });

  test(
      'the device width is w times the CTM scale, rotated or mirrored (a '
      'reader that reports w alone, or takes the root of a negative '
      'determinant)', () {
    final c = read(
      'q 2 0 0 2 0 0 cm 0.5 w 0 0 m 1 0 l S Q '
      // Rotated by 90 degrees and scaled by 3: det +9.
      'q 0 -3 3 0 0 0 cm 0.5 w 0 0 m 1 0 l S Q '
      // Mirrored (x and y swapped) and scaled by 3: det -9.
      'q 0 3 3 0 0 0 cm 0.5 w 0 0 m 1 0 l S Q',
    );
    expect(c.paths[0].deviceLineWidth, 1.0);
    expect(c.paths[1].deviceLineWidth, 1.5);
    expect(c.paths[2].state.ctm.determinant, -9);
    expect(c.paths[2].deviceLineWidth, 1.5);
  });

  test(
      'an odd-length hex string ends in an implied 0 digit (a reader that '
      'pads at the front reads <901FA> as 09 01 FA)', () {
    // `ri` takes one operand and moves no geometry: the reader records it.
    final c = read('<901FA> ri');
    final s = c.operators.single.operands.single as PdfRawString;
    expect(s.bytes, [0x90, 0x1F, 0xA0]);
    expect(s.hex, isTrue);
  });

  group('text', () {
    // A /Type0 font over a CIDFontType2, its /W given as `[0 8 0 R]` the way
    // the pdf package writes it, and a ToUnicode CMap with a bfchar and a
    // bfrange block.
    const cmap = '/CIDInit/ProcSet findresource begin\n'
        '1 begincodespacerange\n<0000> <FFFF>\nendcodespacerange\n'
        '2 beginbfchar\n<0001> <0057>\n<0002> <0043>\nendbfchar\n'
        '1 beginbfrange\n<0003> <0004> <00E7>\nendbfrange\nend';
    final objects = [
      '5 0 obj\n<< /Type /Font /Subtype /Type0 /BaseFont /X '
          '/Encoding /Identity-H /DescendantFonts [6 0 R] /ToUnicode 7 0 R >>'
          '\nendobj',
      '6 0 obj\n<< /Type /Font /Subtype /CIDFontType2 /W [0 8 0 R] '
          '/DW 1000 >>\nendobj',
      '7 0 obj\n<< /Length ${cmap.length} >>\nstream\n$cmap\nendstream\nendobj',
      '8 0 obj\n[250 500 600]\nendobj',
    ];

    test(
        'TJ: two-byte CIDs from hex strings, kerning numbers and /W widths '
        '(a reader that reads one byte per code, ignores kerning or the '
        '/DW default)', () {
      final c = read(
        'BT /F1 10 Tf 80 Tz 5 6 Td [<0001> -100 <0002 0003>] TJ ET',
        resources: '/Font << /F1 5 0 R >>',
        objects: objects,
      );
      final t = c.textRuns.single;
      expect(t.fontResource, '/F1');
      expect(t.size, 10);
      expect(t.horizontalScale, 80);
      expect(t.codes, [1, 2, 3]);
      // (500 + 600 + 1000 (code 3: past /W, so /DW)) / 1000 · 10 · 0.8,
      // plus the kerning: +100 / 1000 · 10 · 0.8.
      expect(t.advance, closeTo(17.6, 1e-12));
    });

    test(
        'ToUnicode: bfchar and bfrange entries (a reader that drops a block '
        'or mis-offsets a range)', () {
      final c = read(
        'BT /F1 10 Tf [<0001 0002 0003 0004>] TJ ET',
        resources: '/Font << /F1 5 0 R >>',
        objects: objects,
      );
      expect(c.textRuns.single.string, 'WCçè');
    });

    test(
        'Td composes with the line matrix and the CTM carries the text matrix '
        'to the page (a reader that replaces Td or ignores the CTM)', () {
      final c = read(
        '1 0 0 -1 0 100 cm BT /F1 10 Tf 1 2 Td 3 4 Td [<0001>] TJ ET',
        resources: '/Font << /F1 5 0 R >>',
        objects: objects,
      );
      final o = c.textRuns.single.origin;
      expect([o.x, o.y], [4, 94]);
    });

    test(
        'a run starts where the previous one ended (a reader that does not '
        'advance the text matrix)', () {
      final c = read(
        'BT /F1 10 Tf 5 6 Td [<0001>] TJ [<0002>] TJ ET',
        resources: '/Font << /F1 5 0 R >>',
        objects: objects,
      );
      final second = c.textRuns[1].origin;
      expect([second.x, second.y], [5 + 5, 6]);
    });
  });

  test(
      'a FlateDecode content stream is inflated through the callback (a '
      'reader that tokenises the raw bytes finds no operators)', () {
    var calls = 0;
    final c = PdfContent.parse(
      pdf('0 0 m 1 1 l S', flate: true),
      inflate: (data) {
        calls++;
        return zlib.decode(data);
      },
    );
    expect(calls, 1);
    expect(c.operatorNames, ['m', 'l', 'S']);
  });

  test('the MediaBox is the page\'s', () {
    expect(read('').mediaBox, [0, 0, 841.88976, 595.27559]);
  });

  test(
      'Contents given as an array is read in order (a reader that takes the '
      'first stream only)', () {
    final bytes = pdf(
      '0 0 m',
      contents: '[4 0 R 9 0 R]',
      objects: ['9 0 obj\n<< /Length 7 >>\nstream\n1 1 l S\nendstream\nendobj'],
    );
    final c = PdfContent.parse(bytes, inflate: zlib.decode);
    expect(c.operatorNames, ['m', 'l', 'S']);
  });

  test(
      'a page without /Contents reads as empty (a reader that throws on a '
      'page that painted nothing)', () {
    final bytes = latin1.encode(
      '%PDF-1.5\n1 0 obj\n<< /Type /Page /MediaBox [0 0 10 20] >>\nendobj\n',
    );
    final c = PdfContent.parse(bytes, inflate: zlib.decode);
    expect(c.operators, isEmpty);
    expect(c.mediaBox, [0, 0, 10, 20]);
  });

  test(
      'stream data is never scanned for objects (a scanner that looks inside '
      'a stream finds a second page)', () {
    const decoy = '9 0 obj << /Type /Page /MediaBox [0 0 1 1] >> endobj';
    final c = PdfContent.parse(
      pdf('', objects: [
        '10 0 obj\n<< /Length ${decoy.length} >>\nstream\n$decoy\nendstream'
            '\nendobj',
      ]),
      inflate: zlib.decode,
    );
    expect(c.mediaBox, [0, 0, 841.88976, 595.27559]);
  });

  test(
      'an integer object does not swallow the next object (a scanner that '
      'reads past endobj)', () {
    final c = read(
      '/a0 gs 0 0 m 1 0 l S',
      resources: '/ExtGState << /a0 12 0 R >>',
      objects: ['11 0 obj\n42\nendobj', '12 0 obj\n<< /CA .5 >>\nendobj'],
    );
    expect(c.paths.single.state.strokeAlpha, 0.5);
  });

  test(
      'an operator that moves geometry and is not modelled throws (a reader '
      'that skips it would misplace what follows)', () {
    for (final op in ['[3] 0 d', '1 Tc', '2 Tw', '3 Ts', '4 TL', 'T*', 'W n']) {
      expect(() => read(op), throwsUnsupportedError, reason: op);
    }
  });
}

/// A one-page PDF around [content], with objects 1 to 4 fixed (catalog,
/// pages, page, content stream) and [objects] appended verbatim.
Uint8List pdf(
  String content, {
  String resources = '',
  List<String> objects = const [],
  bool flate = false,
  String contents = '4 0 R',
}) {
  final b = BytesBuilder();
  void put(String s) => b.add(latin1.encode(s));
  final data =
      flate ? zlib.encode(latin1.encode(content)) : latin1.encode(content);
  put('%PDF-1.5\n');
  put('1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');
  put('2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n');
  put('3 0 obj\n<< /Type /Page /Parent 2 0 R '
      '/MediaBox [0 0 841.88976 595.27559] /Contents $contents '
      '/Resources << $resources >> >>\nendobj\n');
  put('4 0 obj\n<< /Length ${data.length}'
      '${flate ? ' /Filter /FlateDecode' : ''} >>\nstream\n');
  b.add(data);
  put('\nendstream\nendobj\n');
  for (final o in objects) {
    put('$o\n');
  }
  put('trailer\n<< /Root 1 0 R >>\n%%EOF\n');
  return b.toBytes();
}

PdfContent read(
  String content, {
  String resources = '',
  List<String> objects = const [],
}) =>
    PdfContent.parse(
      pdf(content, resources: resources, objects: objects),
      inflate: zlib.decode,
    );

List<List<double>> xy(List<PdfXY> points) => [
      for (final p in points) [p.x, p.y],
    ];
