// The demo's POS look (host embedding API spec T-1, T-2 and F-4): what a
// point-of-sale application whose own UI is not Material (shadcn_ui, say)
// does to make the planner match it.
//
// - A `PlanTheme` in each of the app's `ThemeData`s, a light and a
//   dark one ([posPlanTheme]), so the system's mode picks it.
// - The app's `ShadTheme` ([demoShadTheme]), shadcn's zinc palette, given
//   to the `ShadApp` root: the planner's chrome (bars, panels, buttons, the
//   export dialog) uses an ancestor `ShadTheme` as it finds it.
// - The view's own `theme:` ([kPosViewOverride]), one field over the
//   ambient extension: the merge, field by field.
//
// The tokens are a **proposal**, shadcn's zinc palette as published, not a
// POS's real ones: a host takes its own design system's values. The
// `PlanTheme`s below hold literal colours by nature, so the colour scan
// (theme_colours_test) allows this file whole.
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// The two looks the demo's app bar switches between.
enum DemoLook {
  /// Today's: the library's default `PlanTheme`.
  standard,

  /// The POS's: [posPlanTheme] and [kPosViewOverride].
  pos,
}

// shadcn's zinc scale and the accent the selection takes (a proposal).
const Color _zinc50 = Color(0xFFFAFAFA);
const Color _zinc100 = Color(0xFFF4F4F5);
const Color _zinc800 = Color(0xFF27272A);
const Color _zinc900 = Color(0xFF18181B);
const Color _orange600 = Color(0xFFEA580C);
const Color _orange400 = Color(0xFFFB923C);

/// The planner's POS look on a light app theme: bold 12 px captions in the
/// planner's bundled `Roboto` (the same on every terminal, the guide's
/// advice), status fills at 0.8 of their colour, group frames in the
/// primary (the chips follow the frame), rounder chips, the muted token
/// around the page, a taller service bar, 1.5 px alignment guides, an orange
/// selection, and a heavier veil over the tables out of focus. The veil keeps
/// the paper's colour: one of another colour would show each faded table's
/// box.
const PlanTheme kPosPlanLight = PlanTheme(
  statusCaptionStyle: TextStyle(
      fontFamily: 'Roboto', fontSize: 12, fontWeight: FontWeight.bold),
  statusFillOpacity: 0.8,
  groupFrameColor: _zinc900,
  groupChipTextStyle:
      TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w600),
  groupChipRadius: 6,
  selectionOnLight: _orange600,
  selectionOnDark: _orange400,
  focusVeilOpacity: 0.75,
  canvasBackground: _zinc100,
  serviceBarHeight: 52,
  guideWidth: 1.5,
);

/// [kPosPlanLight]'s dark counterpart: the dark primary and muted
/// tokens. The selection colours are per paper, not per theme, so they are
/// the light theme's: a light page under the dark theme is still shown on
/// the dark canvas (the planner's rule), and takes `selectionOnDark`.
const PlanTheme kPosPlanDark = PlanTheme(
  statusCaptionStyle: TextStyle(
      fontFamily: 'Roboto', fontSize: 12, fontWeight: FontWeight.bold),
  statusFillOpacity: 0.8,
  groupFrameColor: _zinc50,
  groupChipTextStyle:
      TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w600),
  groupChipRadius: 6,
  selectionOnLight: _orange600,
  selectionOnDark: _orange400,
  focusVeilOpacity: 0.75,
  canvasBackground: _zinc800,
  serviceBarHeight: 52,
  guideWidth: 1.5,
);

/// The POS look for [brightness]'s app theme.
PlanTheme posPlanTheme(Brightness brightness) =>
    brightness == Brightness.light ? kPosPlanLight : kPosPlanDark;

/// The view's own override under the POS look: a 3 px selection, merged
/// over the app theme's extension field by field (the extension sets no
/// width, so the resolved theme is the extension plus this).
const PlanTheme kPosViewOverride = PlanTheme(selectionWidth: 3);

/// The app's `ShadTheme`, under both looks: shadcn's zinc palette for
/// [brightness], in the planner's bundled `Roboto` (the same on every
/// terminal, as the `PlanTheme`s' captions).
ShadThemeData demoShadTheme(Brightness brightness) => ShadThemeData(
      brightness: brightness,
      colorScheme: brightness == Brightness.light
          ? const ShadZincColorScheme.light()
          : const ShadZincColorScheme.dark(),
      textTheme: ShadTextTheme(family: 'Roboto'),
    );
