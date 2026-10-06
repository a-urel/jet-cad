import 'dart:math' as math;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'dart:ui' show Brightness;
import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'canvas_palette.dart';

// The dark canvas (decision note 2026-10-05-dark-canvas-design.md, K1–K3).
// In a dark theme a light document paper is *shown* dark, and the drawing's
// colours are re-toned to read on it as they read on white. Display only:
// the document, its saved file and every export keep the document's paper
// and colours (K4).

/// True when the canvas re-tones: a dark theme over a page whose paper takes
/// black ink (White, Ivory, Grey, or any light custom paper). A dark paper
/// (Blueprint) and a document with no page are shown as they are (K1).
bool darkCanvasFor({required int? page, required Brightness brightness}) =>
    brightness == Brightness.dark &&
    page != null &&
    foregroundFor(page & 0xFFFFFF) == 0x000000;

/// The paper the canvas shows, ARGB (K1, K2): [kDarkCanvasPaper] on a dark
/// canvas, else the page's background, else, with no page, the theme's
/// [surface]. Everything that keys on the paper reads this one value.
int displayPaperFor(
        {required int? page,
        required int surface,
        required Brightness brightness}) =>
    darkCanvasFor(page: page, brightness: brightness)
        ? kDarkCanvasPaper
        : (page ?? surface);

/// The canvas's resolver for [document] on the display [paper] (ARGB, from
/// [displayPaperFor]). On a dark canvas ([dark], from [darkCanvasFor]) it is
/// a [DarkCanvasStyleResolver] over the drawing as it is on white paper
/// (K3); otherwise ACI 7 takes [paper]'s foreground, as before.
StyleResolver canvasResolverFor(DraftDocument document,
        {required int paper, required bool dark}) =>
    dark
        ? DarkCanvasStyleResolver(
            DocumentStyleResolver(document, foreground: 0x000000),
            paper: paper)
        : DocumentStyleResolver(document,
            foreground: foregroundFor(paper & 0xFFFFFF));

/// The OKLab chroma up to which a colour is treated as neutral (K3): it
/// takes the exact contrast mirror, so it may darken. Pale tints (a pale
/// zone fill, chroma 0.03–0.09) sit here, so a subtle fill stays subtle.
const double kDarkCanvasNeutralChroma = 0.09;

/// The OKLab chroma from which a colour is treated as coloured (K3): it is
/// never darkened. Every saturated ACI colour (1–6, chroma ≥ 0.155) sits
/// here. Between the two the cases blend linearly.
const double kDarkCanvasColouredChroma = 0.15;

/// [rgb] (`0xRRGGBB`) as shown on the dark [paperRgb] (K3): the colour whose
/// WCAG contrast against [paperRgb] equals [rgb]'s contrast against white,
/// at [rgb]'s OKLab hue. A neutral colour takes it exactly, so light grey
/// goes dark grey and black goes white; a coloured one is never darkened,
/// so yellow stays yellow; between them the two blend by chroma. The result
/// is brought into sRGB by reducing chroma, never by clipping a channel.
/// White, whose contrast on white is 1, shows as [paperRgb] itself, so a
/// white mask is the paper, as it is on white paper.
int darkCanvasTone(int rgb, int paperRgb) {
  if (rgb & 0xFFFFFF == 0xFFFFFF) return paperRgb & 0xFFFFFF;
  final lab = _oklab(rgb & 0xFFFFFF);
  final l = lab[0], a = lab[1], b = lab[2];
  final chroma = math.sqrt(a * a + b * b);
  final paperY = _luminance(paperRgb & 0xFFFFFF);
  final paperL = _oklab(paperRgb & 0xFFFFFF)[0];

  // Contrast on white, and the luminance with that contrast on the paper.
  final target = 1.05 / (_luminance(rgb & 0xFFFFFF) + 0.05);
  final wantY = target * (paperY + 0.05) - 0.05;

  // Bisection on lightness, from the paper to white: the gamut-mapped
  // luminance rises with it.
  var lo = paperL, hi = 1.0;
  for (var i = 0; i < 40; i++) {
    final mid = (lo + hi) / 2;
    if (_luminance(_inGamut(mid, a, b)) < wantY) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final mirror = (lo + hi) / 2;
  final w = ((kDarkCanvasColouredChroma - chroma) /
          (kDarkCanvasColouredChroma - kDarkCanvasNeutralChroma))
      .clamp(0.0, 1.0);
  final shown = w * mirror + (1 - w) * math.max(l, mirror);
  return _inGamut(shown, a, b);
}

/// A [StyleResolver] that re-tones [inner]'s colours for the dark [paper]
/// (K3). [inner] resolves the drawing as it is on white paper (ACI 7 black),
/// so ACI 7 and a black `TrueColor` take the same road to white. Alpha,
/// lineweight, linetype and scale pass through untouched.
///
/// **Allocation.** Each distinct inner style is re-toned once and the result
/// kept: a steady frame finds every style in [_styles] and returns the kept
/// object, so it allocates nothing beyond what [inner] already does. The
/// colour itself is computed once per RGB ([_tones], K3): styles that differ
/// only in lineweight, linetype or scale share it.
final class DarkCanvasStyleResolver implements StyleResolver {
  DarkCanvasStyleResolver(this.inner, {required int paper})
      : paper = paper & 0xFFFFFF;

  final StyleResolver inner;

  /// The dark paper, `0xRRGGBB`.
  final int paper;

  final Map<ResolvedStyle, ResolvedStyle> _styles = {};
  final Map<int, int> _tones = {};

  /// Test-only: how many styles have been re-toned (style cache misses).
  @visibleForTesting
  int debugToneCount = 0;

  /// Test-only: how many colours have been computed (RGB cache misses).
  @visibleForTesting
  int debugColourCount = 0;

  @override
  StyleContext contextFor(Handle instance, StyleContext inherited) =>
      inner.contextFor(instance, inherited);

  @override
  ResolvedStyle styleFor(int slot, StyleContext ctx) {
    final style = inner.styleFor(slot, ctx);
    return _styles[style] ??= _retone(style);
  }

  int _tone(int rgb) {
    debugColourCount++;
    return darkCanvasTone(rgb, paper);
  }

  ResolvedStyle _retone(ResolvedStyle style) {
    debugToneCount++;
    return ResolvedStyle(
      argb: (style.argb & 0xFF000000) |
          (_tones[style.argb & 0xFFFFFF] ??= _tone(style.argb & 0xFFFFFF)),
      lineweightHundredths: style.lineweightHundredths,
      linetype: style.linetype,
      linetypeScale: style.linetypeScale,
    );
  }
}

// --- colour maths (sRGB, OKLab, WCAG relative luminance) -------------------

double _toLinear(int channel) {
  final c = channel / 255;
  return c <= 0.04045
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

int _toByte(double linear) {
  final x = linear.clamp(0.0, 1.0);
  final v = x <= 0.0031308
      ? 12.92 * x
      : 1.055 * math.pow(x, 1 / 2.4).toDouble() - 0.055;
  return (v * 255).round().clamp(0, 255);
}

double _luminance(int rgb) =>
    0.2126 * _toLinear((rgb >> 16) & 0xFF) +
    0.7152 * _toLinear((rgb >> 8) & 0xFF) +
    0.0722 * _toLinear(rgb & 0xFF);

double _cbrt(double x) =>
    x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();

List<double> _oklab(int rgb) {
  final r = _toLinear((rgb >> 16) & 0xFF);
  final g = _toLinear((rgb >> 8) & 0xFF);
  final b = _toLinear(rgb & 0xFF);
  final l = _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  final m = _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  final s = _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  return [
    0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
  ];
}

/// Linear sRGB of OKLab (l, a, b); may fall outside [0, 1].
List<double> _linearOf(double l, double a, double b) {
  final l3 = math.pow(l + 0.3963377774 * a + 0.2158037573 * b, 3).toDouble();
  final m3 = math.pow(l - 0.1055613458 * a - 0.0638541728 * b, 3).toDouble();
  final s3 = math.pow(l - 0.0894841775 * a - 1.2914855480 * b, 3).toDouble();
  return [
    4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3,
    -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3,
    -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3,
  ];
}

bool _fits(List<double> rgb) => rgb.every((c) => c >= -1e-9 && c <= 1 + 1e-9);

/// OKLab (l, a, b) as `0xRRGGBB`, with the chroma reduced (hue and lightness
/// kept) until the colour fits sRGB.
int _inGamut(double l, double a, double b) {
  var rgb = _linearOf(l, a, b);
  if (!_fits(rgb)) {
    var lo = 0.0, hi = 1.0;
    for (var i = 0; i < 30; i++) {
      final mid = (lo + hi) / 2;
      if (_fits(_linearOf(l, a * mid, b * mid))) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    rgb = _linearOf(l, a * lo, b * lo);
  }
  return (_toByte(rgb[0]) << 16) | (_toByte(rgb[1]) << 8) | _toByte(rgb[2]);
}
