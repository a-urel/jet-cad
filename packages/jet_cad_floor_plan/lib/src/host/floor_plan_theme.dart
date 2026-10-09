// The planner's look for a host (host embedding API spec, Slice 3, T-1,
// T-2): a `ThemeExtension` a host puts in its `ThemeData`, overridden field
// by field by `FloorPlanView.theme`, resolved once below the view and read
// by both modes when their painters rebuild (T-3), never per frame.
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The planner's look (host embedding API spec T-1): the colours, widths
/// and styles a host may set. Every field is optional, and null is
/// today's value, so `const FloorPlanTheme()` draws exactly what a view
/// with no theme draws.
///
/// A host puts one in each of its `ThemeData`s, a light and a dark
/// (`ThemeData(extensions: [FloorPlanTheme(...)])`), and may override it
/// for one view with `FloorPlanView(theme: ...)`, field by field ([merge]).
/// The constructor never throws; the view refuses a resolved theme out of
/// range when it builds (an [ArgumentError] naming the field). The theme is
/// never saved, exported or printed.
@immutable
final class FloorPlanTheme extends ThemeExtension<FloorPlanTheme> {
  const FloorPlanTheme({
    this.statusCaptionStyle,
    this.statusFillOpacity,
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

  /// The selection mode's status captions. A null property is today's: a
  /// null `color` the automatic black or white ink over the drawn fill, a
  /// null `fontSize` 11 logical pixels, a null `fontFamily` the platform's
  /// default font. A family is drawn only when the host has loaded it.
  /// `fontSize`, when set, is finite and above 0. Null: today's caption.
  final TextStyle? statusCaptionStyle;

  /// The selection mode's status fills: multiplies the host colour's alpha,
  /// once, in [0, 1]. Null: the colour as the host gave it.
  final double? statusFillOpacity;

  /// The selection mode's group frames. Null: the paper's grip colour.
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

  /// The selection mode's focus veil over the tables outside the focus;
  /// its alpha is multiplied by [focusVeilOpacity]. Null: the paper's
  /// colour.
  final Color? focusVeilColor;

  /// The focus veil's opacity, in [0, 1]. Null: 0.6.
  final double? focusVeilOpacity;

  /// The canvas around the page and a page-less plan's paper, in both
  /// modes: the drafting's ink follows it as it follows a page. A
  /// translucent colour is used as given (the ink keys on its RGB). Null:
  /// the ambient `ColorScheme.surface`.
  final Color? canvasBackground;

  /// The selection mode's bar, in logical pixels, finite and above 0. Null:
  /// 44.
  final double? serviceBarHeight;

  /// A copy with the given fields replaced; a null argument keeps the
  /// field (Flutter's convention: [merge] a theme to set fields, there is
  /// no way back to null here).
  @override
  FloorPlanTheme copyWith({
    TextStyle? statusCaptionStyle,
    double? statusFillOpacity,
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
      FloorPlanTheme(
        statusCaptionStyle: statusCaptionStyle ?? this.statusCaptionStyle,
        statusFillOpacity: statusFillOpacity ?? this.statusFillOpacity,
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
  FloorPlanTheme merge(FloorPlanTheme? other) {
    if (other == null) return this;
    return FloorPlanTheme(
      statusCaptionStyle:
          _mergeStyle(statusCaptionStyle, other.statusCaptionStyle),
      statusFillOpacity: other.statusFillOpacity ?? statusFillOpacity,
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
  /// A field set on both sides is interpolated ([Color.lerp], [lerpDouble],
  /// [TextStyle.lerp], [EdgeInsets.lerp]); a field null on one side means
  /// a value that depends on the paper, which cannot be interpolated, so it
  /// takes the side `t` is nearer (this one below 0.5). A null [other]
  /// returns this theme itself.
  @override
  FloorPlanTheme lerp(
      covariant ThemeExtension<FloorPlanTheme>? other, double t) {
    if (other is! FloorPlanTheme) return this;
    return FloorPlanTheme(
      statusCaptionStyle: _lerp(
          statusCaptionStyle, other.statusCaptionStyle, t, TextStyle.lerp),
      statusFillOpacity:
          _lerp(statusFillOpacity, other.statusFillOpacity, t, lerpDouble),
      groupFrameColor:
          _lerp(groupFrameColor, other.groupFrameColor, t, Color.lerp),
      groupFrameWidth:
          _lerp(groupFrameWidth, other.groupFrameWidth, t, lerpDouble),
      groupFrameMargin:
          _lerp(groupFrameMargin, other.groupFrameMargin, t, lerpDouble),
      groupChipColor:
          _lerp(groupChipColor, other.groupChipColor, t, Color.lerp),
      groupChipTextStyle: _lerp(
          groupChipTextStyle, other.groupChipTextStyle, t, TextStyle.lerp),
      groupChipRadius:
          _lerp(groupChipRadius, other.groupChipRadius, t, lerpDouble),
      groupChipPadding:
          _lerp(groupChipPadding, other.groupChipPadding, t, EdgeInsets.lerp),
      selectionOnLight:
          _lerp(selectionOnLight, other.selectionOnLight, t, Color.lerp),
      selectionOnDark:
          _lerp(selectionOnDark, other.selectionOnDark, t, Color.lerp),
      selectionWidth:
          _lerp(selectionWidth, other.selectionWidth, t, lerpDouble),
      focusVeilColor:
          _lerp(focusVeilColor, other.focusVeilColor, t, Color.lerp),
      focusVeilOpacity:
          _lerp(focusVeilOpacity, other.focusVeilOpacity, t, lerpDouble),
      canvasBackground:
          _lerp(canvasBackground, other.canvasBackground, t, Color.lerp),
      serviceBarHeight:
          _lerp(serviceBarHeight, other.serviceBarHeight, t, lerpDouble),
    );
  }

  /// [a] to [b] at [t] by [lerp] when both are set, else the nearer side.
  static T? _lerp<T extends Object>(
          T? a, T? b, double t, T? Function(T a, T b, double t) lerp) =>
      a == null || b == null ? (t < 0.5 ? a : b) : lerp(a, b, t);

  @override
  bool operator ==(Object other) =>
      other is FloorPlanTheme &&
      other.statusCaptionStyle == statusCaptionStyle &&
      other.statusFillOpacity == statusFillOpacity &&
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
  int get hashCode => Object.hashAll(_fields.values);

  /// Every field by name, in declaration order.
  Map<String, Object?> get _fields => {
        'statusCaptionStyle': statusCaptionStyle,
        'statusFillOpacity': statusFillOpacity,
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

  /// The set fields only, by name: `FloorPlanTheme(selectionWidth: 4.0)`,
  /// and `FloorPlanTheme()` for none.
  @override
  String toString() => 'FloorPlanTheme(${[
        for (final MapEntry(:key, :value) in _fields.entries)
          if (value != null) '$key: $value',
      ].join(', ')})';
}

/// Throws an [ArgumentError] naming the field for a resolved [theme] the
/// view cannot draw (Slice 3 plan S-5): an opacity outside [0, 1]; a
/// selection or frame width or a bar height not finite or not above 0; a
/// margin, a chip radius or a padding side not finite or negative; a text
/// style's `fontSize` not finite or not above 0.
@internal
void validateFloorPlanTheme(FloorPlanTheme theme) {
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

/// Resolves the planner's look just below `FloorPlanView` (spec T-2,
/// Slice 3 plan S-11): the ambient extension of `Theme.of(context)` with
/// [view]'s set fields over it, validated, provided to both modes by an
/// [InheritedFloorPlanTheme] compared by `==` (T-3).
///
/// Only this widget depends on the ambient `Theme`: a theme switch rebuilds
/// it and hands the inherited widget the same [child], so nothing between
/// it and the dependents (the view's listener, the host's overlays) is
/// rebuilt by it.
@internal
class FloorPlanThemeScope extends StatelessWidget {
  const FloorPlanThemeScope(
      {super.key, required this.view, required this.child});

  /// `FloorPlanView.theme`: overrides the ambient extension field by field.
  final FloorPlanTheme? view;

  final Widget child;

  /// The resolved theme of the nearest scope above [context] (null: no
  /// theme anywhere, today's look), registering [context] as its
  /// dependent; with no scope above (a bare `PlannerShell`), the ambient
  /// extension.
  static FloorPlanTheme? of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<InheritedFloorPlanTheme>();
    if (scope != null) return scope.theme;
    return Theme.of(context).extension<FloorPlanTheme>();
  }

  @override
  Widget build(BuildContext context) {
    final ambient = Theme.of(context).extension<FloorPlanTheme>();
    final resolved = ambient == null ? view : ambient.merge(view);
    if (resolved != null) validateFloorPlanTheme(resolved);
    return InheritedFloorPlanTheme(theme: resolved, child: child);
  }
}

/// The resolved theme under a [FloorPlanThemeScope]. A plain
/// [InheritedWidget], not an `InheritedTheme`: a route pushed from below it
/// (the export dialog) does not carry the view's override (S-12).
@internal
class InheritedFloorPlanTheme extends InheritedWidget {
  const InheritedFloorPlanTheme(
      {super.key, required this.theme, required super.child});

  /// The resolved theme; null for today's look.
  final FloorPlanTheme? theme;

  /// By value (T-3): an equal theme rebuilt by the host notifies nobody.
  @override
  bool updateShouldNotify(InheritedFloorPlanTheme oldWidget) =>
      theme != oldWidget.theme;
}
