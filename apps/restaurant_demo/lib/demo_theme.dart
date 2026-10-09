// The demo's POS look (host embedding API spec T-1, T-2 and F-4): what a
// point-of-sale application whose own UI is not Material (shadcn_ui, say)
// does to make the planner match it.
//
// - A `FloorPlanTheme` in each of the app's `ThemeData`s, a light and a
//   dark one ([posFloorPlanTheme]), so the system's mode picks it.
// - A local `Theme` around the view with a hand-built `ColorScheme` of the
//   POS's tokens ([posViewTheme]): the planner's chrome (bars, panels,
//   buttons, the export dialog) reads its colours from the ambient Material
//   theme, and a seeded scheme cannot reproduce another design system's
//   tokens exactly.
// - The view's own `theme:` ([kPosViewOverride]), one field over the
//   ambient extension: the merge, field by field.
//
// The tokens are a **proposal**, shadcn's zinc palette as published, not a
// POS's real ones: a host takes its own design system's values. Literal
// colours by nature, so the colour scan (theme_colours_test) allows this
// file whole.
import 'package:flutter/material.dart';
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart';

/// The two looks the demo's app bar switches between.
enum DemoLook {
  /// Today's: the seeded Material theme, no `FloorPlanTheme` anywhere.
  standard,

  /// The POS's: [posFloorPlanTheme], [posViewTheme], [kPosViewOverride].
  pos,
}

// shadcn's zinc scale and the accent the selection takes (a proposal).
const Color _zinc50 = Color(0xFFFAFAFA);
const Color _zinc100 = Color(0xFFF4F4F5);
const Color _zinc200 = Color(0xFFE4E4E7);
const Color _zinc300 = Color(0xFFD4D4D8);
const Color _zinc400 = Color(0xFFA1A1AA);
const Color _zinc500 = Color(0xFF71717A);
const Color _zinc800 = Color(0xFF27272A);
const Color _zinc900 = Color(0xFF18181B);
const Color _zinc950 = Color(0xFF09090B);
const Color _white = Color(0xFFFFFFFF);
const Color _black = Color(0xFF000000);
const Color _red500 = Color(0xFFEF4444);
const Color _red900 = Color(0xFF7F1D1D);
const Color _orange600 = Color(0xFFEA580C);
const Color _orange400 = Color(0xFFFB923C);

/// The POS's tokens as a Material `ColorScheme`, built by hand so each
/// token lands exactly (F-4): background → `surface`, foreground →
/// `onSurface`, muted → the surface containers, muted foreground →
/// `onSurfaceVariant`, border → `outline`, primary → `primary`.
ColorScheme posColorScheme(Brightness brightness) =>
    brightness == Brightness.light
        ? const ColorScheme(
            brightness: Brightness.light,
            primary: _zinc900,
            onPrimary: _zinc50,
            primaryContainer: _zinc100,
            onPrimaryContainer: _zinc900,
            secondary: _zinc100,
            onSecondary: _zinc900,
            secondaryContainer: _zinc100,
            onSecondaryContainer: _zinc900,
            tertiary: _zinc800,
            onTertiary: _zinc50,
            error: _red500,
            onError: _zinc50,
            surface: _white,
            onSurface: _zinc950,
            onSurfaceVariant: _zinc500,
            surfaceContainerLowest: _white,
            surfaceContainerLow: _zinc50,
            surfaceContainer: _zinc100,
            surfaceContainerHigh: _zinc100,
            surfaceContainerHighest: _zinc200,
            outline: _zinc200,
            outlineVariant: _zinc200,
            shadow: _black,
            scrim: _black,
            inverseSurface: _zinc900,
            onInverseSurface: _zinc50,
            inversePrimary: _zinc300,
            surfaceTint: Colors.transparent,
          )
        : const ColorScheme(
            brightness: Brightness.dark,
            primary: _zinc50,
            onPrimary: _zinc900,
            primaryContainer: _zinc800,
            onPrimaryContainer: _zinc50,
            secondary: _zinc800,
            onSecondary: _zinc50,
            secondaryContainer: _zinc800,
            onSecondaryContainer: _zinc50,
            tertiary: _zinc200,
            onTertiary: _zinc900,
            error: _red900,
            onError: _zinc50,
            surface: _zinc950,
            onSurface: _zinc50,
            onSurfaceVariant: _zinc400,
            surfaceContainerLowest: _zinc950,
            surfaceContainerLow: _zinc900,
            surfaceContainer: _zinc900,
            surfaceContainerHigh: _zinc800,
            surfaceContainerHighest: _zinc800,
            outline: _zinc800,
            outlineVariant: _zinc800,
            shadow: _black,
            scrim: _black,
            inverseSurface: _zinc50,
            onInverseSurface: _zinc900,
            inversePrimary: _zinc800,
            surfaceTint: Colors.transparent,
          );

/// The planner's POS look on a light app theme: bold 12 px captions in the
/// planner's bundled `Roboto` (the same on every terminal, the guide's
/// advice), status fills at 0.8 of their colour, group frames in the
/// primary (the chips follow the frame), rounder chips, the muted token
/// around the page, a taller service bar, an orange selection, and a
/// heavier veil of the muted token over the tables out of focus.
const FloorPlanTheme kPosFloorPlanLight = FloorPlanTheme(
  statusCaptionStyle: TextStyle(
      fontFamily: 'Roboto', fontSize: 12, fontWeight: FontWeight.bold),
  statusFillOpacity: 0.8,
  groupFrameColor: _zinc900,
  groupChipTextStyle:
      TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w600),
  groupChipRadius: 6,
  selectionOnLight: _orange600,
  selectionOnDark: _orange400,
  focusVeilColor: _zinc100,
  focusVeilOpacity: 0.75,
  canvasBackground: _zinc100,
  serviceBarHeight: 52,
);

/// [kPosFloorPlanLight]'s dark counterpart: the dark primary and muted
/// tokens. The selection colours are per paper, not per theme, so they are
/// the light theme's: a light page under the dark theme is still shown on
/// the dark canvas (the planner's rule), and takes `selectionOnDark`.
const FloorPlanTheme kPosFloorPlanDark = FloorPlanTheme(
  statusCaptionStyle: TextStyle(
      fontFamily: 'Roboto', fontSize: 12, fontWeight: FontWeight.bold),
  statusFillOpacity: 0.8,
  groupFrameColor: _zinc50,
  groupChipTextStyle:
      TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w600),
  groupChipRadius: 6,
  selectionOnLight: _orange600,
  selectionOnDark: _orange400,
  focusVeilColor: _zinc950,
  focusVeilOpacity: 0.75,
  canvasBackground: _zinc800,
  serviceBarHeight: 52,
);

/// The POS look for [brightness]'s app theme.
FloorPlanTheme posFloorPlanTheme(Brightness brightness) =>
    brightness == Brightness.light ? kPosFloorPlanLight : kPosFloorPlanDark;

/// The view's own override under the POS look: a 3 px selection, merged
/// over the app theme's extension field by field (the extension sets no
/// width, so the resolved theme is the extension plus this).
const FloorPlanTheme kPosViewOverride = FloorPlanTheme(selectionWidth: 3);

/// The local `Theme` around the view under the POS look: [ambient]'s
/// brightness, the hand-built [posColorScheme], and [ambient]'s extensions
/// carried over, because a local `Theme` replaces the whole `ThemeData`,
/// and without them the view would see no `FloorPlanTheme`.
ThemeData posViewTheme(ThemeData ambient) => ThemeData(
      colorScheme: posColorScheme(ambient.brightness),
      extensions: ambient.extensions.values,
    );
