// The plan library's look (spec P5 "Theme"): a ThemeExtension a host puts
// in its ThemeData, overridden field by field by a view's own theme,
// resolved once below the view and read where painters rebuild, never per
// frame. Ported from jet_cad_floor_plan's FloorPlanTheme (host embedding
// API spec T-1, T-2): its generic part, the selection and the canvas. 2b
// adds the statuses, groups, focus veil, unit colours and service bar.
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show PaperPalette;

/// The unit colour fill's default alpha (spec 2b S4 "Painting"): both
/// modes, and every exporter's `PlanExportRequest.unitColourOpacity`.
const double kUnitColourOpacity = 0.35;

/// The plan library's look: the colours and widths a host may set. Every
/// field is optional, and null is today's value, so `const PlanTheme()`
/// draws exactly what no theme draws.
///
/// A host puts one in each of its `ThemeData`s, a light and a dark
/// (`ThemeData(extensions: [PlanTheme(...)])`), and may override it for one
/// editor with `PlanEditor(theme: ...)`, field by field ([merge]). The
/// constructor never throws; the scope refuses a resolved theme out of
/// range when it builds (an [ArgumentError] naming the field). The theme is
/// never saved, exported or printed.
@immutable
final class PlanTheme extends ThemeExtension<PlanTheme> {
  const PlanTheme({
    this.statusCaptionStyle,
    this.statusFillOpacity,
    this.unitColourOpacity,
    this.groupFrameColor,
    this.groupFrameWidth,
    this.groupFrameMargin,
    this.groupChipColor,
    this.groupChipTextStyle,
    this.groupChipRadius,
    this.groupChipPadding,
    this.selectionOnLight,
    this.selectionOnDark,
    this.selectionWidth,
    this.focusVeilColor,
    this.focusVeilOpacity,
    this.canvasBackground,
    this.serviceBarHeight,
  });

  /// The resolved theme for [context]: the nearest [PlanThemeScope]'s, else
  /// the ambient extension (validated); null when no theme is set anywhere,
  /// which draws today's look (as does every null field). Registers
  /// [context] as a dependent. Read in `didChangeDependencies`, never per
  /// frame.
  static PlanTheme? of(BuildContext context) => PlanThemeScope.of(context);

  /// The service's status captions. A null property is today's: a
  /// null `color` the automatic black or white ink over the drawn fill, a
  /// null `fontSize` 11 logical pixels, a null `fontFamily` the platform's
  /// default font. A family is drawn only when the host has loaded it.
  /// `fontSize`, when set, is finite and above 0. Null: today's caption.
  final TextStyle? statusCaptionStyle;

  /// The service's status fills: multiplies the host colour's alpha,
  /// once, in the range 0 to 1. Null: the colour as the host gave it.
  final double? statusFillOpacity;

  /// Both modes' unit colour fills: the hue's alpha, in the range 0 to 1.
  /// Null: 0.35.
  final double? unitColourOpacity;

  /// The service's group frames. Null: the paper's grip colour.
  final Color? groupFrameColor;

  /// The group frames' stroke, in screen logical pixels, finite and above 0.
  /// Null: 2.
  final double? groupFrameWidth;

  /// How far a group frame stands off its members, in world millimetres,
  /// finite and not negative. Null: 150.
  final double? groupFrameMargin;

  /// The group label chips' fill. Null: the frame's colour as resolved
  /// ([groupFrameColor], else the paper's grip colour).
  final Color? groupChipColor;

  /// The group label chips' text; null properties as in
  /// [statusCaptionStyle], the automatic ink taken on the chip's colour.
  final TextStyle? groupChipTextStyle;

  /// The chips' corner radius, in logical pixels, finite and not negative.
  /// Null: 4.
  final double? groupChipRadius;

  /// The chips' padding around their text, in logical pixels, each side
  /// finite and not negative. Null: 5 left and right, 2 top and bottom.
  final EdgeInsets? groupChipPadding;

  /// The selection colour on a light paper, in both modes, as the paper's
  /// palette chooses today; the hover is derived from it. Null: the light
  /// palette's.
  final Color? selectionOnLight;

  /// The selection colour on a dark paper (and on the dark canvas), in both
  /// modes. Null: the dark palette's.
  final Color? selectionOnDark;

  /// The selection outline's stroke in both modes, in screen logical
  /// pixels, finite and above 0. Null: 2. The hover stays 1.5.
  final double? selectionWidth;

  /// The service's focus veil over the units outside the focus;
  /// its alpha is multiplied by [focusVeilOpacity]. Null: the paper's
  /// colour.
  final Color? focusVeilColor;

  /// The focus veil's opacity, in the range 0 to 1. Null: 0.6.
  final double? focusVeilOpacity;

  /// The canvas around the page and a page-less plan's paper, in both
  /// modes: the drafting's ink follows it as it follows a page. A
  /// translucent colour is used as given (the ink keys on its RGB). Null:
  /// the ambient `ColorScheme.surface`.
  final Color? canvasBackground;

  /// The service's bar, in logical pixels, finite and above 0. Null:
  /// 44.
  final double? serviceBarHeight;

  /// A copy with the given fields replaced; a null argument keeps the
  /// field (Flutter's convention: [merge] a theme to set fields, there is
  /// no way back to null here).
  @override
  PlanTheme copyWith({
    TextStyle? statusCaptionStyle,
    double? statusFillOpacity,
    double? unitColourOpacity,
    Color? groupFrameColor,
    double? groupFrameWidth,
    double? groupFrameMargin,
    Color? groupChipColor,
    TextStyle? groupChipTextStyle,
    double? groupChipRadius,
    EdgeInsets? groupChipPadding,
    Color? selectionOnLight,
    Color? selectionOnDark,
    double? selectionWidth,
    Color? focusVeilColor,
    double? focusVeilOpacity,
    Color? canvasBackground,
    double? serviceBarHeight,
  }) =>
      PlanTheme(
        statusCaptionStyle: statusCaptionStyle ?? this.statusCaptionStyle,
        statusFillOpacity: statusFillOpacity ?? this.statusFillOpacity,
        unitColourOpacity: unitColourOpacity ?? this.unitColourOpacity,
        groupFrameColor: groupFrameColor ?? this.groupFrameColor,
        groupFrameWidth: groupFrameWidth ?? this.groupFrameWidth,
        groupFrameMargin: groupFrameMargin ?? this.groupFrameMargin,
        groupChipColor: groupChipColor ?? this.groupChipColor,
        groupChipTextStyle: groupChipTextStyle ?? this.groupChipTextStyle,
        groupChipRadius: groupChipRadius ?? this.groupChipRadius,
        groupChipPadding: groupChipPadding ?? this.groupChipPadding,
        selectionOnLight: selectionOnLight ?? this.selectionOnLight,
        selectionOnDark: selectionOnDark ?? this.selectionOnDark,
        selectionWidth: selectionWidth ?? this.selectionWidth,
        focusVeilColor: focusVeilColor ?? this.focusVeilColor,
        focusVeilOpacity: focusVeilOpacity ?? this.focusVeilOpacity,
        canvasBackground: canvasBackground ?? this.canvasBackground,
        serviceBarHeight: serviceBarHeight ?? this.serviceBarHeight,
      );

  /// This theme with [other]'s set fields over it, field by field (spec
  /// T-2): a field [other] leaves null keeps this theme's. The two text
  /// styles merge property by property ([TextStyle.merge]), so an
  /// [other] that sets only a weight keeps this theme's size. A null
  /// [other] returns this theme itself.
  PlanTheme merge(PlanTheme? other) {
    if (other == null) return this;
    return PlanTheme(
      statusCaptionStyle:
          _mergeStyle(statusCaptionStyle, other.statusCaptionStyle),
      statusFillOpacity: other.statusFillOpacity ?? statusFillOpacity,
      unitColourOpacity: other.unitColourOpacity ?? unitColourOpacity,
      groupFrameColor: other.groupFrameColor ?? groupFrameColor,
      groupFrameWidth: other.groupFrameWidth ?? groupFrameWidth,
      groupFrameMargin: other.groupFrameMargin ?? groupFrameMargin,
      groupChipColor: other.groupChipColor ?? groupChipColor,
      groupChipTextStyle:
          _mergeStyle(groupChipTextStyle, other.groupChipTextStyle),
      groupChipRadius: other.groupChipRadius ?? groupChipRadius,
      groupChipPadding: other.groupChipPadding ?? groupChipPadding,
      selectionOnLight: other.selectionOnLight ?? selectionOnLight,
      selectionOnDark: other.selectionOnDark ?? selectionOnDark,
      selectionWidth: other.selectionWidth ?? selectionWidth,
      focusVeilColor: other.focusVeilColor ?? focusVeilColor,
      focusVeilOpacity: other.focusVeilOpacity ?? focusVeilOpacity,
      canvasBackground: other.canvasBackground ?? canvasBackground,
      serviceBarHeight: other.serviceBarHeight ?? serviceBarHeight,
    );
  }

  static TextStyle? _mergeStyle(TextStyle? base, TextStyle? over) =>
      base == null ? over : base.merge(over);

  /// The theme [t] of the way to [other], for an animated theme switch.
  ///
  /// A field set on both sides is interpolated ([Color.lerp], [lerpDouble],
  /// [TextStyle.lerp], [EdgeInsets.lerp]), and each interpolated double (a
  /// double field, each padding side, a style's `fontSize`) is clamped
  /// between its two ends: a host's overshooting curve
  /// (`Curves.easeOutBack`) drives `t` out of `[0, 1]`, and two valid themes
  /// must never animate into one the scope refuses. A field null on one side
  /// means a value that depends on the paper, which cannot be interpolated,
  /// so it takes the side `t` is nearer (this one below 0.5); so does a
  /// text style whose `color` one side leaves null (that colour is the
  /// automatic ink), whole, never fading from transparent.
  ///
  /// A field equal on both sides is that side's value, and an [other]
  /// equal to this theme returns this theme itself, so a theme that is the
  /// same in a host's light and dark `ThemeData` stays `==` on every frame
  /// of the switch and notifies nobody (T-3). A null [other] returns this
  /// theme itself.
  @override
  PlanTheme lerp(covariant ThemeExtension<PlanTheme>? other, double t) {
    if (other is! PlanTheme || this == other) return this;
    return PlanTheme(
      statusCaptionStyle:
          _lerp(statusCaptionStyle, other.statusCaptionStyle, t, _lerpStyle),
      statusFillOpacity:
          _lerp(statusFillOpacity, other.statusFillOpacity, t, _lerpBetween),
      unitColourOpacity:
          _lerp(unitColourOpacity, other.unitColourOpacity, t, _lerpBetween),
      groupFrameColor:
          _lerp(groupFrameColor, other.groupFrameColor, t, Color.lerp),
      groupFrameWidth:
          _lerp(groupFrameWidth, other.groupFrameWidth, t, _lerpBetween),
      groupFrameMargin:
          _lerp(groupFrameMargin, other.groupFrameMargin, t, _lerpBetween),
      groupChipColor:
          _lerp(groupChipColor, other.groupChipColor, t, Color.lerp),
      groupChipTextStyle:
          _lerp(groupChipTextStyle, other.groupChipTextStyle, t, _lerpStyle),
      groupChipRadius:
          _lerp(groupChipRadius, other.groupChipRadius, t, _lerpBetween),
      groupChipPadding:
          _lerp(groupChipPadding, other.groupChipPadding, t, _lerpInsets),
      selectionOnLight:
          _lerp(selectionOnLight, other.selectionOnLight, t, Color.lerp),
      selectionOnDark:
          _lerp(selectionOnDark, other.selectionOnDark, t, Color.lerp),
      selectionWidth:
          _lerp(selectionWidth, other.selectionWidth, t, _lerpBetween),
      focusVeilColor:
          _lerp(focusVeilColor, other.focusVeilColor, t, Color.lerp),
      focusVeilOpacity:
          _lerp(focusVeilOpacity, other.focusVeilOpacity, t, _lerpBetween),
      canvasBackground:
          _lerp(canvasBackground, other.canvasBackground, t, Color.lerp),
      serviceBarHeight:
          _lerp(serviceBarHeight, other.serviceBarHeight, t, _lerpBetween),
    );
  }

  /// [a] to [b] at [t] by [lerp] when both are set and differ, [a] when
  /// they are equal, else the nearer side.
  static T? _lerp<T extends Object>(
          T? a, T? b, double t, T? Function(T a, T b, double t) lerp) =>
      a == null || b == null ? (t < 0.5 ? a : b) : (a == b ? a : lerp(a, b, t));

  /// [lerpDouble] clamped between [a] and [b], whatever [t].
  static double _lerpBetween(double a, double b, double t) =>
      clampDouble(lerpDouble(a, b, t)!, math.min(a, b), math.max(a, b));

  /// [EdgeInsets.lerp], each side clamped between its two ends.
  static EdgeInsets _lerpInsets(EdgeInsets a, EdgeInsets b, double t) =>
      EdgeInsets.fromLTRB(
        _lerpBetween(a.left, b.left, t),
        _lerpBetween(a.top, b.top, t),
        _lerpBetween(a.right, b.right, t),
        _lerpBetween(a.bottom, b.bottom, t),
      );

  /// [TextStyle.lerp] with its `fontSize` clamped between the two ends; a
  /// `color` null on exactly one side (the automatic ink) switches the
  /// whole style at 0.5 instead.
  static TextStyle _lerpStyle(TextStyle a, TextStyle b, double t) {
    if ((a.color == null) != (b.color == null)) return t < 0.5 ? a : b;
    final lerped = TextStyle.lerp(a, b, t)!;
    final size = lerped.fontSize;
    final from = a.fontSize ?? b.fontSize;
    final to = b.fontSize ?? a.fontSize;
    if (size == null || from == null || to == null) return lerped;
    final clamped = clampDouble(size, math.min(from, to), math.max(from, to));
    return clamped == size ? lerped : lerped.copyWith(fontSize: clamped);
  }

  @override
  bool operator ==(Object other) =>
      other is PlanTheme &&
      other.statusCaptionStyle == statusCaptionStyle &&
      other.statusFillOpacity == statusFillOpacity &&
      other.unitColourOpacity == unitColourOpacity &&
      other.groupFrameColor == groupFrameColor &&
      other.groupFrameWidth == groupFrameWidth &&
      other.groupFrameMargin == groupFrameMargin &&
      other.groupChipColor == groupChipColor &&
      other.groupChipTextStyle == groupChipTextStyle &&
      other.groupChipRadius == groupChipRadius &&
      other.groupChipPadding == groupChipPadding &&
      other.selectionOnLight == selectionOnLight &&
      other.selectionOnDark == selectionOnDark &&
      other.selectionWidth == selectionWidth &&
      other.focusVeilColor == focusVeilColor &&
      other.focusVeilOpacity == focusVeilOpacity &&
      other.canvasBackground == canvasBackground &&
      other.serviceBarHeight == serviceBarHeight;

  @override
  int get hashCode => Object.hash(
        statusCaptionStyle,
        statusFillOpacity,
        unitColourOpacity,
        groupFrameColor,
        groupFrameWidth,
        groupFrameMargin,
        groupChipColor,
        groupChipTextStyle,
        groupChipRadius,
        groupChipPadding,
        selectionOnLight,
        selectionOnDark,
        selectionWidth,
        focusVeilColor,
        focusVeilOpacity,
        canvasBackground,
        serviceBarHeight,
      );

  /// Every field by name, in declaration order (for [toString]).
  Map<String, Object?> get _fields => {
        'statusCaptionStyle': statusCaptionStyle,
        'statusFillOpacity': statusFillOpacity,
        'unitColourOpacity': unitColourOpacity,
        'groupFrameColor': groupFrameColor,
        'groupFrameWidth': groupFrameWidth,
        'groupFrameMargin': groupFrameMargin,
        'groupChipColor': groupChipColor,
        'groupChipTextStyle': groupChipTextStyle,
        'groupChipRadius': groupChipRadius,
        'groupChipPadding': groupChipPadding,
        'selectionOnLight': selectionOnLight,
        'selectionOnDark': selectionOnDark,
        'selectionWidth': selectionWidth,
        'focusVeilColor': focusVeilColor,
        'focusVeilOpacity': focusVeilOpacity,
        'canvasBackground': canvasBackground,
        'serviceBarHeight': serviceBarHeight,
      };

  /// The set fields only, by name: `PlanTheme(selectionWidth: 4.0)`,
  /// and `PlanTheme()` for none.
  @override
  String toString() => 'PlanTheme(${[
        for (final MapEntry(:key, :value) in _fields.entries)
          if (value != null) '$key: $value',
      ].join(', ')})';
}

/// Throws an [ArgumentError] naming the field for a resolved [theme] the
/// scope cannot draw (Slice 3 plan S-5): an opacity outside [0, 1]; a
/// selection or frame width or a bar height not finite or not above 0; a
/// margin, a chip radius or a padding side not finite or negative; a text
/// style's `fontSize` not finite or not above 0.
@internal
void validatePlanTheme(PlanTheme theme) {
  void opacity(double? v, String name) {
    if (v != null && !(v >= 0 && v <= 1)) {
      throw ArgumentError.value(v, name, 'must be in [0, 1]');
    }
  }

  void positive(double? v, String name) {
    if (v != null && !(v.isFinite && v > 0)) {
      throw ArgumentError.value(v, name, 'must be finite and above 0');
    }
  }

  void notNegative(double? v, String name) {
    if (v != null && !(v.isFinite && v >= 0)) {
      throw ArgumentError.value(v, name, 'must be finite and not negative');
    }
  }

  void style(TextStyle? s, String name) {
    final size = s?.fontSize;
    if (size != null && !(size.isFinite && size > 0)) {
      throw ArgumentError.value(
          s, name, 'its fontSize must be finite and above 0; $size is not');
    }
  }

  style(theme.statusCaptionStyle, 'statusCaptionStyle');
  opacity(theme.statusFillOpacity, 'statusFillOpacity');
  opacity(theme.unitColourOpacity, 'unitColourOpacity');
  positive(theme.groupFrameWidth, 'groupFrameWidth');
  notNegative(theme.groupFrameMargin, 'groupFrameMargin');
  style(theme.groupChipTextStyle, 'groupChipTextStyle');
  notNegative(theme.groupChipRadius, 'groupChipRadius');
  final padding = theme.groupChipPadding;
  if (padding != null) {
    for (final side in [
      padding.left,
      padding.top,
      padding.right,
      padding.bottom
    ]) {
      if (!(side.isFinite && side >= 0)) {
        throw ArgumentError.value(padding, 'groupChipPadding',
            'each side must be finite and not negative; $side is not');
      }
    }
  }
  positive(theme.selectionWidth, 'selectionWidth');
  opacity(theme.focusVeilOpacity, 'focusVeilOpacity');
  positive(theme.serviceBarHeight, 'serviceBarHeight');
}

/// The overlays' colours on the display paper [paperArgb] under [theme]: the
/// set [PaperPalette.forPaper] picks, with the theme's colour for that set
/// (`selectionOnDark` for the dark set, `selectionOnLight` for the light) as
/// its selection and hover ([PaperPalette.withSelection]). With no theme,
/// or no colour for that set, it is the `const` set itself, so a canvas
/// with no theme hands its painters today's instance. Grips and the
/// attachment marker take this palette's grip and snap colours.
///
/// Called where a canvas builds, never per frame.
@internal
PaperPalette planPaperPaletteFor(int paperArgb, PlanTheme? theme) {
  final set = PaperPalette.forPaper(paperArgb);
  final colour = identical(set, PaperPalette.dark)
      ? theme?.selectionOnDark
      : theme?.selectionOnLight;
  return colour == null ? set : set.withSelection(colour);
}

/// Resolves the plan library's look just below an editor or a canvas: the
/// ambient extension of `Theme.of(context)` with [view]'s set fields over
/// it, validated, provided by an [InheritedPlanTheme] compared by `==`.
///
/// Only this widget depends on the ambient `Theme`: a theme switch rebuilds
/// it and hands the inherited widget the same [child], so nothing between
/// it and the dependents is rebuilt by it.
@internal
class PlanThemeScope extends StatelessWidget {
  const PlanThemeScope({super.key, required this.view, required this.child});

  /// A view's own theme: overrides the ambient extension field by field.
  final PlanTheme? view;

  final Widget child;

  /// The resolved theme of the nearest scope above [context] (null: no
  /// theme anywhere), registering [context] as its dependent; with no scope
  /// above, the ambient extension, validated as the scope validates it (an
  /// [ArgumentError] naming the field).
  static PlanTheme? of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<InheritedPlanTheme>();
    if (scope != null) return scope.theme;
    final ambient = Theme.of(context).extension<PlanTheme>();
    if (ambient != null) validatePlanTheme(ambient);
    return ambient;
  }

  @override
  Widget build(BuildContext context) {
    final ambient = Theme.of(context).extension<PlanTheme>();
    final resolved = ambient == null ? view : ambient.merge(view);
    if (resolved != null) validatePlanTheme(resolved);
    return InheritedPlanTheme(theme: resolved, child: child);
  }
}

/// The resolved theme under a [PlanThemeScope]. A plain [InheritedWidget],
/// not an `InheritedTheme`: a route pushed from below it (the export
/// dialog) does not carry the view's override.
@internal
class InheritedPlanTheme extends InheritedWidget {
  const InheritedPlanTheme(
      {super.key, required this.theme, required super.child});

  /// The resolved theme; null for today's look.
  final PlanTheme? theme;

  /// By value: an equal theme rebuilt by the host notifies nobody.
  @override
  bool updateShouldNotify(InheritedPlanTheme oldWidget) =>
      theme != oldWidget.theme;
}
