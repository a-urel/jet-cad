import 'dart:ui' show Brightness, Color;

import 'package:flutter/foundation.dart' show immutable;
import 'package:jet_cad_2d/jet_cad_2d.dart' show foregroundFor;

/// The canvas chrome's colours: what surrounds and frames the paper (dark
/// theme spec D2). They follow the host's theme, not the paper.
///
/// [light] is today's chrome; [dark] is its counterpart for a dark theme.
/// A view picks one with [of] from its theme's brightness. The two `const`
/// instances are immutable and shared; nothing holds a mutable palette.
@immutable
class ChromePalette {
  const ChromePalette({
    required this.rulerBackground,
    required this.rulerInk,
    required this.rulerPointer,
    required this.sheetEdge,
  });

  /// The ruler bars' and the corner box's fill.
  final Color rulerBackground;

  /// The ruler's ticks and labels.
  final Color rulerInk;

  /// The ruler's pointer-position marker.
  final Color rulerPointer;

  /// The sheet's edge stroke.
  final Color sheetEdge;

  /// The chrome in a light theme: today's colours.
  static const ChromePalette light = ChromePalette(
    rulerBackground: Color(0xFFF2F2F2),
    rulerInk: Color(0xFF444444),
    rulerPointer: Color(0xFFE53935),
    sheetEdge: Color(0xFF9E9E9E),
  );

  /// The chrome in a dark theme.
  static const ChromePalette dark = ChromePalette(
    rulerBackground: Color(0xFF2B2D31),
    rulerInk: Color(0xFFC8C8C8),
    rulerPointer: Color(0xFFFF6B66),
    sheetEdge: Color(0xFF8A8A8A),
  );

  /// [light] for [Brightness.light], [dark] for [Brightness.dark].
  static ChromePalette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  @override
  bool operator ==(Object other) =>
      other is ChromePalette &&
      other.rulerBackground == rulerBackground &&
      other.rulerInk == rulerInk &&
      other.rulerPointer == rulerPointer &&
      other.sheetEdge == sheetEdge;

  @override
  int get hashCode =>
      Object.hash(rulerBackground, rulerInk, rulerPointer, sheetEdge);
}

/// The sheet a dark theme shows in place of a light document paper, ARGB
/// (dark canvas decision note K1): a neutral dark, as in AutoCAD.
const int kDarkCanvasPaper = 0xFF1E1F22;

/// The colours of everything drawn **on** the paper: the grid, the page
/// breaks and the interaction overlays (dark theme spec D3). They follow the
/// paper, not the theme, so they stay legible on any paper in either theme.
///
/// [light] is today's set, for paper that takes black ink; [dark] is for
/// paper that takes white ink. [forPaper] picks one.
@immutable
class PaperPalette {
  const PaperPalette({
    required this.minorGrid,
    required this.majorGrid,
    required this.pageBreak,
    required this.selection,
    required this.hover,
    required this.windowBand,
    required this.crossingBand,
    required this.grip,
    required this.gripMove,
    required this.gripHot,
    required this.preview,
    required this.snap,
    this.guide,
  });

  /// The minor grid lines.
  final Color minorGrid;

  /// The major grid lines.
  final Color majorGrid;

  /// The page-break tiling.
  final Color pageBreak;

  /// The selected outline.
  final Color selection;

  /// The hover outline: the selection's hue at 60% alpha, so a hovered
  /// object reads as a weaker statement than a selected one. [withSelection]
  /// derives it from another selection colour the same way.
  final Color hover;

  /// The window (left-to-right) band.
  final Color windowBand;

  /// The crossing (right-to-left) band.
  final Color crossingBand;

  /// Stretch and radius grips.
  final Color grip;

  /// Move (centre) grips.
  final Color gripMove;

  /// The hovered grip, and the grabbed one during a drag.
  final Color gripHot;

  /// The move's base-to-target line, rubber bands and ghosts.
  final Color preview;

  /// Snap markers.
  final Color snap;

  /// Alignment guides and their gap marks. Null on a palette built without
  /// one; [guideColor] then picks [lightGuide] or [darkGuide] by the paper.
  final Color? guide;

  /// The alignment guides' magenta on paper that takes black ink.
  static const Color lightGuide = Color(0xFFE0218A);

  /// The alignment guides' pink on paper that takes white ink.
  static const Color darkGuide = Color(0xFFFF5CB0);

  /// [guide] when set; else [darkGuide] when the paper is dark (the minor
  /// grid is light ink, luminance above one half), else [lightGuide].
  Color get guideColor =>
      guide ?? (minorGrid.computeLuminance() > 0.5 ? darkGuide : lightGuide);

  /// The overlays on paper that takes black ink: today's colours.
  static const PaperPalette light = PaperPalette(
    minorGrid: Color(0x14000000),
    majorGrid: Color(0x33000000),
    pageBreak: Color(0xFF3366CC),
    selection: Color(0xFF1E6FE8),
    hover: Color(0x991E6FE8),
    windowBand: Color(0xFF1E6FE8),
    crossingBand: Color(0xFF2E9E5B),
    grip: Color(0xFF1E6FE8),
    gripMove: Color(0xFF7A3FD1),
    gripHot: Color(0xFFE8541E),
    preview: Color(0xFFE8A11E),
    snap: Color(0xFF2E9E5B),
    guide: lightGuide,
  );

  /// The overlays on paper that takes white ink.
  static const PaperPalette dark = PaperPalette(
    minorGrid: Color(0x14FFFFFF),
    majorGrid: Color(0x33FFFFFF),
    pageBreak: Color(0xFF8AB4F8),
    selection: Color(0xFF7FB2FF),
    hover: Color(0x997FB2FF),
    windowBand: Color(0xFF7FB2FF),
    crossingBand: Color(0xFF5FD68F),
    grip: Color(0xFF7FB2FF),
    gripMove: Color(0xFFC4A0FF),
    gripHot: Color(0xFFFF8A5C),
    preview: Color(0xFFFFC857),
    snap: Color(0xFF5FD68F),
    guide: darkGuide,
  );

  /// The set for a paper of colour [argb] (`0xAARRGGBB`; the alpha byte is
  /// ignored): [dark] exactly when ACI 7's ink on that paper is white.
  ///
  /// It applies to any paper value, not only the swatches, since a loaded
  /// file may carry any background. Keying on [foregroundFor] puts the
  /// overlays' switch at exactly the paper where the drafting's ink flips.
  static PaperPalette forPaper(int argb) =>
      foregroundFor(argb & 0xFFFFFF) == 0xFFFFFF ? dark : light;

  /// This set with [selection] as its selection colour and [hover] derived
  /// from it: [selection]'s colour at its alpha times `0x99 / 0xFF` (60%),
  /// the ratio both sets' own hover has to their selection, so
  /// `light.withSelection(light.selection) == light`. The other colours
  /// are this set's, [guide] included (host embedding API spec T-1, S-8).
  PaperPalette withSelection(Color selection) => PaperPalette(
        minorGrid: minorGrid,
        majorGrid: majorGrid,
        pageBreak: pageBreak,
        selection: selection,
        hover: selection.withValues(alpha: selection.a * 0x99 / 0xFF),
        windowBand: windowBand,
        crossingBand: crossingBand,
        grip: grip,
        gripMove: gripMove,
        gripHot: gripHot,
        preview: preview,
        snap: snap,
        guide: guide,
      );

  /// This set with [guide] as its alignment-guide colour; the rest are this
  /// set's.
  PaperPalette withGuide(Color guide) => PaperPalette(
        minorGrid: minorGrid,
        majorGrid: majorGrid,
        pageBreak: pageBreak,
        selection: selection,
        hover: hover,
        windowBand: windowBand,
        crossingBand: crossingBand,
        grip: grip,
        gripMove: gripMove,
        gripHot: gripHot,
        preview: preview,
        snap: snap,
        guide: guide,
      );

  @override
  bool operator ==(Object other) =>
      other is PaperPalette &&
      other.minorGrid == minorGrid &&
      other.majorGrid == majorGrid &&
      other.pageBreak == pageBreak &&
      other.selection == selection &&
      other.hover == hover &&
      other.windowBand == windowBand &&
      other.crossingBand == crossingBand &&
      other.grip == grip &&
      other.gripMove == gripMove &&
      other.gripHot == gripHot &&
      other.preview == preview &&
      other.snap == snap &&
      other.guide == guide;

  @override
  int get hashCode => Object.hash(
        minorGrid,
        majorGrid,
        pageBreak,
        selection,
        hover,
        windowBand,
        crossingBand,
        grip,
        gripMove,
        gripHot,
        preview,
        snap,
        guide,
      );
}

/// A table status caption's colour where the paper it lies on takes black
/// ink (dark theme spec D6c, as amended by P7): today's caption. A group
/// chip's text, which lies on the chip, takes the same two colours from
/// the chip's own ink.
const Color kStatusCaptionOnLight = Color(0xFF202020);

/// A table status caption's colour where the paper it lies on takes white
/// ink (dark theme spec D6c, as amended by P7).
const Color kStatusCaptionOnDark = Color(0xFFFFFFFF);
