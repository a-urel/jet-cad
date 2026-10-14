// The plan library's look (spec P5 "Theme"): a ThemeExtension a host puts
// in its ThemeData, overridden field by field by a view's own theme,
// resolved once below the view and read where painters rebuild, never per
// frame. Ported from jet_cad_floor_plan's FloorPlanTheme (host embedding
// API spec T-1, T-2): its generic part, the selection and the canvas. 2b
// adds the statuses, groups, focus veil, table colours and service bar.
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show PaperPalette;

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
    this.selectionOnLight,
    this.selectionOnDark,
    this.selectionWidth,
    this.canvasBackground,
  });

  /// The resolved theme for [context]: the nearest [PlanThemeScope]'s, else
  /// the ambient extension (validated); null when no theme is set anywhere,
  /// which draws today's look (as does every null field). Registers
  /// [context] as a dependent. Read in `didChangeDependencies`, never per
  /// frame.
  static PlanTheme? of(BuildContext context) => PlanThemeScope.of(context);

  /// The selection colour on a light paper, as the paper's palette chooses
  /// today; the hover is derived from it. Null: the light palette's.
  final Color? selectionOnLight;

  /// The selection colour on a dark paper (and on the dark canvas). Null:
  /// the dark palette's.
  final Color? selectionOnDark;

  /// The selection outline's stroke, in screen logical pixels, finite and
  /// above 0. Null: 2. The hover stays 1.5.
  final double? selectionWidth;

  /// The canvas around the page and a page-less plan's paper: the
  /// drafting's ink follows it as it follows a page. A translucent colour is
  /// used as given (the ink keys on its RGB). Null: the ambient
  /// `ColorScheme.surface`.
  final Color? canvasBackground;

  /// A copy with the given fields replaced; a null argument keeps the
  /// field (Flutter's convention: [merge] a theme to set fields, there is
  /// no way back to null here).
  @override
  PlanTheme copyWith({
    Color? selectionOnLight,
    Color? selectionOnDark,
    double? selectionWidth,
    Color? canvasBackground,
  }) =>
      PlanTheme(
        selectionOnLight: selectionOnLight ?? this.selectionOnLight,
        selectionOnDark: selectionOnDark ?? this.selectionOnDark,
        selectionWidth: selectionWidth ?? this.selectionWidth,
        canvasBackground: canvasBackground ?? this.canvasBackground,
      );

  /// This theme with [other]'s set fields over it, field by field: a field
  /// [other] leaves null keeps this theme's. A null [other] returns this
  /// theme itself.
  PlanTheme merge(PlanTheme? other) {
    if (other == null) return this;
    return PlanTheme(
      selectionOnLight: other.selectionOnLight ?? selectionOnLight,
      selectionOnDark: other.selectionOnDark ?? selectionOnDark,
      selectionWidth: other.selectionWidth ?? selectionWidth,
      canvasBackground: other.canvasBackground ?? canvasBackground,
    );
  }

  /// The theme [t] of the way to [other], for an animated theme switch.
  ///
  /// A field set on both sides is interpolated ([Color.lerp], [lerpDouble]),
  /// the width clamped between its two ends: a host's overshooting curve
  /// drives `t` out of `[0, 1]`, and two valid themes must never animate
  /// into one the scope refuses. A field null on one side means a value that
  /// depends on the paper, which cannot be interpolated, so it takes the
  /// side `t` is nearer (this one below 0.5), whole, never fading from
  /// transparent.
  ///
  /// A field equal on both sides is that side's value, and an [other] equal
  /// to this theme returns this theme itself, so a theme that is the same in
  /// a host's light and dark `ThemeData` stays `==` on every frame of the
  /// switch and notifies nobody. A null [other] returns this theme itself.
  @override
  PlanTheme lerp(covariant ThemeExtension<PlanTheme>? other, double t) {
    if (other is! PlanTheme || this == other) return this;
    return PlanTheme(
      selectionOnLight:
          _lerp(selectionOnLight, other.selectionOnLight, t, Color.lerp),
      selectionOnDark:
          _lerp(selectionOnDark, other.selectionOnDark, t, Color.lerp),
      selectionWidth:
          _lerp(selectionWidth, other.selectionWidth, t, _lerpBetween),
      canvasBackground:
          _lerp(canvasBackground, other.canvasBackground, t, Color.lerp),
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

  @override
  bool operator ==(Object other) =>
      other is PlanTheme &&
      other.selectionOnLight == selectionOnLight &&
      other.selectionOnDark == selectionOnDark &&
      other.selectionWidth == selectionWidth &&
      other.canvasBackground == canvasBackground;

  @override
  int get hashCode => Object.hash(
      selectionOnLight, selectionOnDark, selectionWidth, canvasBackground);

  /// Every field by name, in declaration order (for [toString]).
  Map<String, Object?> get _fields => {
        'selectionOnLight': selectionOnLight,
        'selectionOnDark': selectionOnDark,
        'selectionWidth': selectionWidth,
        'canvasBackground': canvasBackground,
      };

  /// The set fields only, by name: `PlanTheme(selectionWidth: 4.0)`, and
  /// `PlanTheme()` for none.
  @override
  String toString() => 'PlanTheme(${[
        for (final MapEntry(:key, :value) in _fields.entries)
          if (value != null) '$key: $value',
      ].join(', ')})';
}

/// Throws an [ArgumentError] naming the field for a resolved [theme] the
/// canvas cannot draw: a selection width not finite or not above 0.
@internal
void validatePlanTheme(PlanTheme theme) {
  final width = theme.selectionWidth;
  if (width != null && !(width.isFinite && width > 0)) {
    throw ArgumentError.value(
        width, 'selectionWidth', 'must be finite and above 0');
  }
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
