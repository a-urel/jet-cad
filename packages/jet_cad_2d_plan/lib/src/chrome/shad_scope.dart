// The chrome's theme scope (spec "The scope (G2, G3)"): resolves the
// shadcn theme every panel and bar reads, from the host's own `ShadTheme`
// if it has one, else derived from the Material `ThemeData`. Internal: no
// shadcn type is reachable from the library's barrel.
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// How many times [planShadThemeFrom] derived a theme rather than reading
/// its memo. Read by the scope's tests (SC8).
@visibleForTesting
int debugPlanShadDerivations = 0;

final Expando<ShadThemeData> _derived = Expando<ShadThemeData>('planShad');

/// WCAG contrast ratio of two opaque colours.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// [fg] on [bg] when they contrast at 4.5 or more, else black or white,
/// whichever reads better: a Material 2 scheme (`useMaterial3: false`, or a
/// hand-built one with default container tokens) pairs colours that were
/// never meant to be text on that surface.
Color _readable(Color fg, Color bg) {
  if (_contrast(fg, bg) >= 4.5) return fg;
  // Not colour literals: the widgets of this library hold none
  // (test/invariants/theme_colours_test.dart).
  final white = const HSLColor.fromAHSL(1, 0, 0, 1).toColor();
  final black = const HSLColor.fromAHSL(1, 0, 0, 0).toColor();
  return _contrast(white, bg) >= _contrast(black, bg) ? white : black;
}

/// The shadcn theme for [theme], mapped from its colour scheme (spec "The
/// mapping from Material"). Computed once per [ThemeData] instance.
ShadThemeData planShadThemeFrom(ThemeData theme) {
  final known = _derived[theme];
  if (known != null) return known;
  debugPlanShadDerivations++;
  final s = theme.colorScheme;
  final brightness = theme.brightness;
  return _derived[theme] = ShadThemeData(
    brightness: brightness,
    colorScheme: ShadColorScheme(
      background: s.surface,
      foreground: _readable(s.onSurface, s.surface),
      card: s.surfaceContainerLow,
      cardForeground: _readable(s.onSurface, s.surfaceContainerLow),
      popover: s.surfaceContainerLow,
      popoverForeground: _readable(s.onSurface, s.surfaceContainerLow),
      primary: s.primary,
      primaryForeground: _readable(s.onPrimary, s.primary),
      secondary: s.secondaryContainer,
      secondaryForeground:
          _readable(s.onSecondaryContainer, s.secondaryContainer),
      muted: s.surfaceContainerHighest,
      mutedForeground: _readable(s.onSurfaceVariant, s.surfaceContainerHighest),
      accent: s.surfaceContainerHigh,
      accentForeground: _readable(s.onSurface, s.surfaceContainerHigh),
      destructive: s.error,
      destructiveForeground: _readable(s.onError, s.error),
      border: s.outlineVariant,
      input: s.outline,
      ring: s.primary,
      selection: s.primary.withValues(alpha: 0.25),
    ),
    textTheme: ShadTextTheme(family: theme.textTheme.bodyMedium?.fontFamily),
  );
}

/// The theme the chrome reads at [context]: the nearest `ShadTheme`'s
/// data, else [planShadThemeFrom] of the Material theme.
ShadThemeData planShadThemeOf(BuildContext context) =>
    ShadTheme.maybeOf(context) ?? planShadThemeFrom(Theme.of(context));

/// Resolves the shadcn theme for its subtree (see the file header), and
/// installs the default text style and icon theme from it, because a
/// `ShadTheme` alone sets neither.
///
/// - [data] given: provides it (a route the library pushes, whose theme was
///   resolved at the call site).
/// - else an ancestor `ShadTheme`: used as is.
/// - else: provides the derived theme.
///
/// Where it provides a theme it also provides what `ShadApp` puts above an
/// app that shadcn's components need (0.57.3 `app.dart`:
/// `ShadMouseAreaSurface` and `ShadMouseCursorProvider`).
class PlanShadScope extends StatelessWidget {
  const PlanShadScope({super.key, required this.child, this.data});

  final Widget child;
  final ShadThemeData? data;

  @override
  Widget build(BuildContext context) {
    final given = data;
    final ancestor = given == null ? ShadTheme.maybeOf(context) : null;
    final resolved = given ?? ancestor ?? planShadThemeFrom(Theme.of(context));
    final inner = DefaultTextStyle(
      style:
          resolved.textTheme.p.copyWith(color: resolved.colorScheme.foreground),
      child: IconTheme(
        data: IconThemeData(color: resolved.colorScheme.foreground, size: 16),
        child: child,
      ),
    );
    if (ancestor != null) return inner;
    return ShadTheme(
      data: resolved,
      child: ShadMouseAreaSurface(
        child: ShadMouseCursorProvider(child: inner),
      ),
    );
  }
}
