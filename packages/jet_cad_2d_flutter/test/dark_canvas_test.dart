// Dark canvas decision note (2026-10-05) K1–K3: which canvases re-tone,
// the paper they show, the re-toning rule, and the resolver that applies it.
//
// The contrast oracle below is written out from WCAG 2.x here and shares
// nothing with `dark_canvas.dart` but the formula's published constants.
// The rule is checked on two dark papers, `kDarkCanvasPaper` and a
// saturated navy, so a rule that only holds for the one shipped paper goes
// red.
//
// Named mutants: M-DC-2 (`darkCanvasFor` on dark papers too), M-DC-5
// (neutral colours take `max(L, target)`), M-DC-6 (coloured colours take
// the target exactly), M-DC-7 (the contrast target a constant), M-DC-8 (the
// resolver's cache skipped).
import 'dart:math' as math;
import 'dart:ui' show Brightness;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/fixtures.dart';

double _lin(int c) {
  final s = c / 255;
  return s <= 0.04045 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4) * 1.0;
}

double _y(int rgb) =>
    0.2126 * _lin((rgb >> 16) & 0xFF) +
    0.7152 * _lin((rgb >> 8) & 0xFF) +
    0.0722 * _lin(rgb & 0xFF);

/// WCAG contrast of two `0xRRGGBB` colours.
double contrast(int a, int b) {
  final ya = _y(a), yb = _y(b);
  return (math.max(ya, yb) + 0.05) / (math.min(ya, yb) + 0.05);
}

String hex(int rgb) => '0x${rgb.toRadixString(16).padLeft(6, '0')}';

const int white = 0xFFFFFFFF, ivory = 0xFFFAF6EC, grey = 0xFFE6E6E6;
const int blueprint = 0xFF1F3A5F;
const int darkSurface = 0xFF111318, lightSurface = 0xFFF9F9FF;

void main() {
  group('K1: which canvases re-tone, and the paper they show (M-DC-2)', () {
    for (final (page, brightness, retones, shown) in [
      (white, Brightness.dark, true, kDarkCanvasPaper),
      (ivory, Brightness.dark, true, kDarkCanvasPaper),
      (grey, Brightness.dark, true, kDarkCanvasPaper),
      (blueprint, Brightness.dark, false, blueprint),
      (white, Brightness.light, false, white),
      (blueprint, Brightness.light, false, blueprint),
    ]) {
      test('${hex(page)} under ${brightness.name}', () {
        expect(darkCanvasFor(page: page, brightness: brightness), retones);
        expect(
            displayPaperFor(
                page: page, surface: darkSurface, brightness: brightness),
            shown);
      });
    }

    test('no page: never re-tones, and the paper is the surface', () {
      for (final (surface, brightness) in [
        (darkSurface, Brightness.dark),
        (lightSurface, Brightness.light),
      ]) {
        expect(darkCanvasFor(page: null, brightness: brightness), isFalse);
        expect(
            displayPaperFor(
                page: null, surface: surface, brightness: brightness),
            surface);
      }
    });

    test(
        'canvasResolverFor: the dark canvas wraps, else ACI 7 takes the '
        'paper\'s foreground', () {
      final doc = DraftDocument.empty(measurer: const InsertionPointMeasurer());
      addTearDown(doc.dispose);
      final dark = canvasResolverFor(doc, paper: kDarkCanvasPaper, dark: true);
      expect(dark, isA<DarkCanvasStyleResolver>());
      dark as DarkCanvasStyleResolver;
      expect(dark.paper, kDarkCanvasPaper & 0xFFFFFF);
      expect((dark.inner as DocumentStyleResolver).foreground, 0x000000);
      for (final (paper, ink) in [(blueprint, 0xFFFFFF), (white, 0x000000)]) {
        final r = canvasResolverFor(doc, paper: paper, dark: false);
        expect((r as DocumentStyleResolver).foreground, ink);
      }
    });
  });

  group('K3: the re-toning rule', () {
    for (final paper in [kDarkCanvasPaper & 0xFFFFFF, 0x0B1F4A]) {
      group('on ${hex(paper)}', () {
        test('premise: the paper is dark', () {
          expect(foregroundFor(paper), 0xFFFFFF);
        });

        test(
            'M-DC-7: every colour keeps its contrast on white, to 0.1, '
            'where white can reach it', () {
          final maxOnPaper = contrast(0xFFFFFF, paper);
          for (final rgb in [
            0x8A6D3B, 0xBBBBBB, 0x808080, 0x0000FF, 0x006400, 0x5C3A1E, //
            0xC0C0C0, 0x333333,
          ]) {
            final shown = darkCanvasTone(rgb, paper);
            final want = math.min(contrast(rgb, 0xFFFFFF), maxOnPaper);
            expect(contrast(shown, paper), closeTo(want, 0.1),
                reason: '${hex(rgb)} -> ${hex(shown)}');
            expect(_y(shown), greaterThan(_y(paper)),
                reason: '${hex(rgb)}: shown on the light side of the paper');
          }
        });

        test('black goes white; white goes to the paper\'s luminance', () {
          expect(hex(darkCanvasTone(0x000000, paper)), hex(0xFFFFFF));
          expect(contrast(darkCanvasTone(0xFFFFFF, paper), paper),
              closeTo(1.0, 0.05));
        });

        test(
            'M-DC-5: a neutral may darken: light grey goes dark grey, and '
            'stays grey', () {
          for (final rgb in [0xBBBBBB, 0xC0C0C0]) {
            final shown = darkCanvasTone(rgb, paper);
            expect(_y(shown), lessThan(_y(rgb)),
                reason: '${hex(rgb)} -> ${hex(shown)}: darker');
            final r = (shown >> 16) & 0xFF,
                g = (shown >> 8) & 0xFF,
                b = shown & 0xFF;
            expect([r - g, g - b, r - b].map((d) => d.abs()).reduce(math.max),
                lessThanOrEqualTo(1),
                reason: '${hex(shown)}: neutral');
          }
        });

        test(
            'M-DC-6: a coloured colour never darkens: ACI 1, 2, 3, 4 and 6 '
            'stay exactly', () {
          for (final rgb in [
            0xFF0000, 0xFFFF00, 0x00FF00, 0x00FFFF, 0xFF00FF, //
          ]) {
            expect(hex(darkCanvasTone(rgb, paper)), hex(rgb));
          }
        });

        test(
            'a dark colour lightens and keeps its hue order: brown stays '
            'brown (R > G > B), blue stays blue (B largest)', () {
          for (final rgb in [0x8A6D3B, 0x5C3A1E]) {
            final shown = darkCanvasTone(rgb, paper);
            final r = (shown >> 16) & 0xFF,
                g = (shown >> 8) & 0xFF,
                b = shown & 0xFF;
            expect(r > g && g > b, isTrue, reason: hex(shown));
            expect(_y(shown), greaterThan(_y(rgb)), reason: hex(shown));
          }
          final blue = darkCanvasTone(0x0000FF, paper);
          expect(blue & 0xFF, greaterThan((blue >> 16) & 0xFF));
          expect(blue & 0xFF, greaterThan((blue >> 8) & 0xFF));
          expect(_y(blue), greaterThan(_y(0x0000FF)));
        });
      });
    }
  });

  group('DarkCanvasStyleResolver', () {
    DraftDocument doc() {
      final d = DraftDocument.empty(measurer: const InsertionPointMeasurer());
      addTearDown(d.dispose);
      addEntity(d, d.rootHandle, const Handle(800), EntityKind.line,
          [10, 20, 30, 40], const [],
          color: const TrueColor(0x000000), transparency: 64, lineweight: 50);
      addEntity(d, d.rootHandle, const Handle(801), EntityKind.line,
          [10, 20, 30, 40], const [],
          color: const TrueColor(0xBBBBBB));
      addEntity(d, d.rootHandle, const Handle(802), EntityKind.line,
          [10, 20, 30, 40], const []); // ByLayer: layer 0, ACI 7
      addEntity(d, d.rootHandle, const Handle(803), EntityKind.line,
          [10, 20, 30, 40], const [],
          color: const IndexedColor(2));
      return d;
    }

    test(
        're-tones the colour and passes alpha, lineweight, linetype and '
        'scale through', () {
      final d = doc();
      final inner = DocumentStyleResolver(d, foreground: 0x000000);
      final r = DarkCanvasStyleResolver(inner, paper: kDarkCanvasPaper);
      for (final h in [800, 801, 802, 803]) {
        final slot = d.entities.slotOf(Handle(h))!;
        final want = inner.styleFor(slot, StyleContext.documentRoot);
        final got = r.styleFor(slot, StyleContext.documentRoot);
        expect(got.argb >>> 24, want.argb >>> 24, reason: 'alpha of $h');
        expect(got.argb & 0xFFFFFF,
            darkCanvasTone(want.argb & 0xFFFFFF, kDarkCanvasPaper),
            reason: 'colour of $h');
        expect(got.lineweightHundredths, want.lineweightHundredths);
        expect(got.linetype, want.linetype);
        expect(got.linetypeScale, want.linetypeScale);
      }
      final black = r.styleFor(
          d.entities.slotOf(const Handle(800))!, StyleContext.documentRoot);
      expect(black.argb, 0xBFFFFFFF, reason: 'translucent black -> white');
      expect(black.lineweightHundredths, 50);
      final aci7 = r.styleFor(
          d.entities.slotOf(const Handle(802))!, StyleContext.documentRoot);
      expect(aci7.argb, 0xFFFFFFFF, reason: 'ACI 7 through black -> white');
      final yellow = r.styleFor(
          d.entities.slotOf(const Handle(803))!, StyleContext.documentRoot);
      expect(yellow.argb, 0xFFFFFF00);
    });

    test(
        'M-DC-8: each distinct style is re-toned once; a steady frame '
        're-tones nothing and returns the kept object', () {
      final d = doc();
      final r = DarkCanvasStyleResolver(
          DocumentStyleResolver(d, foreground: 0x000000),
          paper: kDarkCanvasPaper);
      final slots = [
        for (final h in [800, 801, 802, 803]) d.entities.slotOf(Handle(h))!
      ];
      final first = [
        for (final s in slots) r.styleFor(s, StyleContext.documentRoot)
      ];
      expect(r.debugToneCount, 4);
      for (var frame = 0; frame < 10; frame++) {
        for (var i = 0; i < slots.length; i++) {
          expect(
              identical(
                  r.styleFor(slots[i], StyleContext.documentRoot), first[i]),
              isTrue);
        }
      }
      expect(r.debugToneCount, 4);
    });

    test('contextFor delegates', () {
      final d = doc();
      final inner = DocumentStyleResolver(d, foreground: 0x000000);
      final r = DarkCanvasStyleResolver(inner, paper: kDarkCanvasPaper);
      expect(r.contextFor(d.rootHandle, StyleContext.documentRoot),
          inner.contextFor(d.rootHandle, StyleContext.documentRoot));
    });
  });
}
