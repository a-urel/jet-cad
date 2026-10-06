import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show foregroundFor;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

// The palettes of the dark theme spec, D2, D3 and D6c.

/// Every field of a [ChromePalette], by name, so a failure names the field.
Map<String, Color> chromeFields(ChromePalette p) => {
      'rulerBackground': p.rulerBackground,
      'rulerInk': p.rulerInk,
      'rulerPointer': p.rulerPointer,
      'sheetEdge': p.sheetEdge,
    };

ChromePalette chromeFrom(Map<String, Color> m) => ChromePalette(
      rulerBackground: m['rulerBackground']!,
      rulerInk: m['rulerInk']!,
      rulerPointer: m['rulerPointer']!,
      sheetEdge: m['sheetEdge']!,
    );

/// Every field of a [PaperPalette], by name.
Map<String, Color> paperFields(PaperPalette p) => {
      'minorGrid': p.minorGrid,
      'majorGrid': p.majorGrid,
      'pageBreak': p.pageBreak,
      'selection': p.selection,
      'hover': p.hover,
      'windowBand': p.windowBand,
      'crossingBand': p.crossingBand,
      'grip': p.grip,
      'gripMove': p.gripMove,
      'gripHot': p.gripHot,
      'preview': p.preview,
      'snap': p.snap,
    };

PaperPalette paperFrom(Map<String, Color> m) => PaperPalette(
      minorGrid: m['minorGrid']!,
      majorGrid: m['majorGrid']!,
      pageBreak: m['pageBreak']!,
      selection: m['selection']!,
      hover: m['hover']!,
      windowBand: m['windowBand']!,
      crossingBand: m['crossingBand']!,
      grip: m['grip']!,
      gripMove: m['gripMove']!,
      gripHot: m['gripHot']!,
      preview: m['preview']!,
      snap: m['snap']!,
    );

/// WCAG 2 relative luminance of an `0xRRGGBB` colour (alpha ignored), written
/// out here so the contrast oracle shares nothing with production code.
double relativeLuminance(int rgb) {
  double channel(int shift) {
    final c = ((rgb >> shift) & 0xFF) / 255.0;
    return c <= 0.04045
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0);
}

/// WCAG 2 contrast ratio between two colours, lighter over darker.
double contrast(int a, int b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

const int kWhitePaper = 0xFFFFFFFF;
const int kIvoryPaper = 0xFFFAF6EC;
const int kGreyPaper = 0xFFEDEDED;
const int kBlueprintPaper = 0xFF1F3A5F;

void main() {
  group('M-DT-19: the light palettes equal the F-2 literals', () {
    test('ChromePalette.light, field by field', () {
      expect(chromeFields(ChromePalette.light), {
        'rulerBackground': const Color(0xFFF2F2F2),
        'rulerInk': const Color(0xFF444444),
        'rulerPointer': const Color(0xFFE53935),
        'sheetEdge': const Color(0xFF9E9E9E),
      });
    });

    test('PaperPalette.light, field by field', () {
      expect(paperFields(PaperPalette.light), {
        'minorGrid': const Color(0x14000000),
        'majorGrid': const Color(0x33000000),
        'pageBreak': const Color(0xFF3366CC),
        'selection': const Color(0xFF1E6FE8),
        'hover': const Color(0x991E6FE8),
        'windowBand': const Color(0xFF1E6FE8),
        'crossingBand': const Color(0xFF2E9E5B),
        'grip': const Color(0xFF1E6FE8),
        'gripMove': const Color(0xFF7A3FD1),
        'gripHot': const Color(0xFFE8541E),
        'preview': const Color(0xFFE8A11E),
        'snap': const Color(0xFF2E9E5B),
      });
    });
  });

  group('the dark palettes equal the D2 / D3 literals', () {
    test('ChromePalette.dark, field by field', () {
      expect(chromeFields(ChromePalette.dark), {
        'rulerBackground': const Color(0xFF2B2D31),
        'rulerInk': const Color(0xFFC8C8C8),
        'rulerPointer': const Color(0xFFFF6B66),
        'sheetEdge': const Color(0xFF8A8A8A),
      });
    });

    test('PaperPalette.dark, field by field', () {
      expect(paperFields(PaperPalette.dark), {
        'minorGrid': const Color(0x14FFFFFF),
        'majorGrid': const Color(0x33FFFFFF),
        'pageBreak': const Color(0xFF8AB4F8),
        'selection': const Color(0xFF7FB2FF),
        'hover': const Color(0x997FB2FF),
        'windowBand': const Color(0xFF7FB2FF),
        'crossingBand': const Color(0xFF5FD68F),
        'grip': const Color(0xFF7FB2FF),
        'gripMove': const Color(0xFFC4A0FF),
        'gripHot': const Color(0xFFFF8A5C),
        'preview': const Color(0xFFFFC857),
        'snap': const Color(0xFF5FD68F),
      });
    });

    test('the D6c caption colours', () {
      expect(kStatusCaptionOnLight, const Color(0xFF202020));
      expect(kStatusCaptionOnDark, const Color(0xFFFFFFFF));
    });
  });

  group('ChromePalette.of', () {
    test('answers light for a light theme and dark for a dark one', () {
      expect(ChromePalette.of(Brightness.light), same(ChromePalette.light));
      expect(ChromePalette.of(Brightness.dark), same(ChromePalette.dark));
    });
  });

  group('M-DT-3: PaperPalette.forPaper keys on foregroundFor', () {
    test('the swatches and the greys either side of the WCAG switch', () {
      // An oracle written out independently of foregroundFor: the WCAG
      // switch falls between grey bytes 117 and 118, not at 128.
      const expected = {
        kWhitePaper: false,
        kIvoryPaper: false,
        kGreyPaper: false,
        kBlueprintPaper: true,
        0xFF757575: true,
        0xFF767676: false,
      };
      for (final MapEntry(key: paper, value: dark) in expected.entries) {
        expect(
          PaperPalette.forPaper(paper),
          same(dark ? PaperPalette.dark : PaperPalette.light),
          reason: 'paper 0x${paper.toRadixString(16)}',
        );
        // The same answer foregroundFor gives for the drafting's ink.
        expect(
          foregroundFor(paper & 0xFFFFFF) == 0xFFFFFF,
          dark,
          reason: 'oracle vs foregroundFor, 0x${paper.toRadixString(16)}',
        );
      }
    });

    test('dark exactly when foregroundFor is white, over a wide sweep', () {
      final papers = <int>[
        // Every grey.
        for (var g = 0; g < 256; g++) 0xFF000000 | (g << 16) | (g << 8) | g,
        // Saturated primaries and secondaries: luminance, not byte sums.
        0xFFFF0000, 0xFF00FF00, 0xFF0000FF, 0xFFFFFF00, 0xFF00FFFF, //
        0xFFFF00FF, 0xFF800000, 0xFF008000, 0xFF000080,
        // A translucent paper value: its alpha byte does not count.
        0x001F3A5F, 0x80FFFFFF,
      ];
      var darkCount = 0;
      for (final paper in papers) {
        final white = foregroundFor(paper & 0xFFFFFF) == 0xFFFFFF;
        if (white) darkCount++;
        expect(
          PaperPalette.forPaper(paper),
          same(white ? PaperPalette.dark : PaperPalette.light),
          reason: 'paper 0x${paper.toRadixString(16)}',
        );
      }
      // Not a degenerate sweep: both sets are exercised.
      expect(darkCount, greaterThan(50));
      expect(darkCount, lessThan(papers.length - 50));
    });
  });

  group('M-DT-20: the dark set keeps its contrast', () {
    // The opaque fields of PaperPalette.dark. The grid and the hover are
    // translucent by design and are not held to the bar.
    final opaque = <String, Color Function(PaperPalette)>{
      'pageBreak': (p) => p.pageBreak,
      'selection': (p) => p.selection,
      'windowBand': (p) => p.windowBand,
      'crossingBand': (p) => p.crossingBand,
      'grip': (p) => p.grip,
      'gripMove': (p) => p.gripMove,
      'gripHot': (p) => p.gripHot,
      'preview': (p) => p.preview,
      'snap': (p) => p.snap,
    };

    for (final MapEntry(key: name, value: read) in opaque.entries) {
      for (final paper in const [kBlueprintPaper, 0xFF303030]) {
        test(
            'PaperPalette.dark.$name has 3:1 on '
            '0x${paper.toRadixString(16)}', () {
          final c = read(PaperPalette.dark).toARGB32();
          expect(c >>> 24, 0xFF, reason: '$name is opaque');
          expect(contrast(c, paper), greaterThanOrEqualTo(3.0));
        });
      }
    }

    test('ChromePalette.dark ruler ink and pointer have 4.5:1 on the bar', () {
      final bar = ChromePalette.dark.rulerBackground.toARGB32();
      expect(
        contrast(ChromePalette.dark.rulerInk.toARGB32(), bar),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(ChromePalette.dark.rulerPointer.toARGB32(), bar),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('the contrast oracle reproduces the spec\'s measured values', () {
      // Spec D3 measured these on Blueprint; a broken oracle that passes
      // everything would not land on them.
      expect(contrast(0x7FB2FF, kBlueprintPaper), closeTo(5.31, 0.01));
      expect(contrast(0xFFC857, kBlueprintPaper), closeTo(7.46, 0.01));
      expect(contrast(0xC8C8C8, 0x2B2D31), closeTo(8.24, 0.01));
      expect(contrast(0x000000, 0xFFFFFF), closeTo(21.0, 1e-9));
    });
  });

  group('the pairings of today\'s constants are kept', () {
    for (final (name, p) in [
      ('light', PaperPalette.light),
      ('dark', PaperPalette.dark),
    ]) {
      test('$name: window band = selection = grip, crossing band = snap', () {
        expect(p.windowBand, p.selection);
        expect(p.grip, p.selection);
        expect(p.crossingBand, p.snap);
      });
    }
  });

  group('value equality', () {
    test('ChromePalette compares by value, every field', () {
      final copy = chromeFrom(chromeFields(ChromePalette.dark));
      expect(identical(copy, ChromePalette.dark), isFalse);
      expect(copy, ChromePalette.dark);
      expect(copy.hashCode, ChromePalette.dark.hashCode);
      expect(ChromePalette.light == ChromePalette.dark, isFalse);
      for (final name in chromeFields(ChromePalette.dark).keys) {
        final fields = chromeFields(ChromePalette.dark)
          ..[name] = const Color(0xFF010203);
        expect(chromeFrom(fields) == ChromePalette.dark, isFalse,
            reason: 'differs in $name');
      }
    });

    test('PaperPalette compares by value, every field', () {
      final copy = paperFrom(paperFields(PaperPalette.dark));
      expect(identical(copy, PaperPalette.dark), isFalse);
      expect(copy, PaperPalette.dark);
      expect(copy.hashCode, PaperPalette.dark.hashCode);
      expect(PaperPalette.light == PaperPalette.dark, isFalse);
      for (final name in paperFields(PaperPalette.dark).keys) {
        final fields = paperFields(PaperPalette.dark)
          ..[name] = const Color(0xFF010203);
        expect(paperFrom(fields) == PaperPalette.dark, isFalse,
            reason: 'differs in $name');
      }
    });
  });
}
