### Task 9: Words, fonts, theme (spec P5)

**Files:**
- Create (all under `packages/jet_cad_2d_plan/` unless they start with `packages/`):
  - `lib/src/l10n/strings.dart`, `lib/src/l10n/strings_en.dart`, `lib/src/l10n/strings_de.dart`, `lib/src/l10n/strings_tr.dart` (ported)
  - `lib/src/l10n/localizations.dart`, `lib/src/l10n/panel_number.dart`, `lib/src/l10n/number_text.dart`, `lib/src/l10n/search_fold.dart`, `lib/src/l10n/numbered_names.dart`, `lib/src/l10n/document_separator.dart` (ported)
  - `lib/src/l10n/locale_scope.dart` (new)
  - `lib/src/theme/plan_theme.dart` (ported)
  - `lib/src/fonts/plan_fonts.dart` (ported)
  - `lib/fonts/Roboto-Regular.ttf`, `assets/fonts/Roboto_LICENSE.txt` (binary/text copies), `assets/fonts/README.md` (new)
  - `packages/jet_cad_2d_kit/lib/src/kit/swatch.dart` (ported: the palette)
- Modify:
  - `packages/jet_cad_2d_kit/lib/jet_cad_2d_kit.dart` (one export), `packages/jet_cad_2d_kit/CHANGELOG.md` (one bullet)
  - `pubspec.yaml` (`flutter_localizations`, the two font assets)
  - `lib/jet_cad_2d_plan.dart` (exports)
  - `lib/src/controller/new_plan.dart` (Task 8's `decimalSeparatorFor`: one expression)
  - `lib/src/controller/plan_controller.dart` (`reportLocale(locale, {PlanStrings? strings})`, the last reported strings; controller ruling on NS7)
- Test:
  - `packages/jet_cad_2d_kit/test/kit/swatch_test.dart`
  - `test/l10n/l10n_test.dart`, `test/l10n/value_words_test.dart`, `test/l10n/numbered_names_test.dart` (ported + new)
  - `test/l10n/locale_scope_test.dart` (new)
  - `test/l10n/document_separator_test.dart` (ported: NS7a, NS7)
  - `test/theme/plan_theme_test.dart` (ported over the generic fields)
  - `test/fonts/fonts_register_test.dart` (ported, alone in its file), `test/fonts/plan_assets_test.dart` (ported + new)

(Paths below are under `packages/jet_cad_2d_plan/` unless they start with `packages/` or name the repository root.)

**Interfaces:**
- Consumes:
  - `PlanController` (Task 8): `ValueListenable<Locale> locale` and `@internal void reportLocale(Locale)` (the widgets' report: it sets `locale` and settles an untouched new plan's separator; this task adds `{PlanStrings? strings}`, Step 10, since `PlanStrings` is this task's type), `void newPlan({String? decimalSeparator})`, `DraftDocument get document`, `selectTool(String id)`, `dispose()`.
  - `PlanKit`, `PlanTool`, `PlanServices.words`, `KitWords` (`word`, `maybe`, `locale`), `KitNames` (Tasks 4, 6; the kit's words read live from `controller.locale`, Task 4's `KitNamesWords` wired by Task 8).
  - Engine: `LayerNameProblem` and its five subclasses, `DecimalSeparator`, `PageComponent`. Flutter layer: `PaperPalette`.
- Produces:
  - In `jet_cad_2d_kit` (exported from `package:jet_cad_2d_kit/jet_cad_2d_kit.dart` only): `enum PlanSwatch { red, orange, yellow, green, teal, blue, purple, grey }` with `final int rgb`; `PlanSwatch? planSwatchNamed(String? name)`.
  - Exported from the barrel `package:jet_cad_2d_plan/jet_cad_2d_plan.dart`:
    - `abstract class PlanStrings` — `static PlanStrings of(BuildContext)`, `static PlanStrings forLocale(Locale?)`, the 80 members listed in Step 3; `class PlanStringsEn`, `PlanStringsDe`, `PlanStringsTr`.
    - `const List<Locale> planSupportedLocales`; `const List<LocalizationsDelegate<Object>> planLocalizationsDelegates`; `abstract final class PlanLocalizations { static const LocalizationsDelegate<PlanStrings> delegate; }`.
    - `final class PlanTheme extends ThemeExtension<PlanTheme>` — `const PlanTheme({Color? selectionOnLight, Color? selectionOnDark, double? selectionWidth, Color? canvasBackground})`; `static PlanTheme? of(BuildContext)` (null: no theme anywhere, today's look); `copyWith`, `merge(PlanTheme?)`, `lerp`, `==`, `hashCode`, `toString`.
    - `const String kPlanFontFamily = 'Roboto'`; `Future<void> ensurePlanFonts([AssetBundle?])`; `void registerFontLicences([AssetBundle?])`.
  - Package-internal (not exported; later tasks import them by path):
    - `String formatPanelNumber(double, PlanStrings)`, `double? parsePanelNumber(String, PlanStrings)`, `String panelNumberText(double)` (Tasks 17, 18, 15's status line);
    - `String searchFold(String)` (Task 13's gallery search);
    - `int? numberedNameIndex(String, String Function(PlanStrings, int), PlanStrings, {String Function(String) fold})` (Task 18's `nextLayerName`);
    - `DecimalSeparator documentSeparatorFor(PlanStrings)`;
    - `abstract final class PlanLocaleScope { static void push(BuildContext, PlanController) }` (`lib/src/l10n/locale_scope.dart`) — every widget of Tasks 13 and 15-20 calls it from `didChangeDependencies` and when handed another controller; it never notifies during a build (the write lands after the frame);
    - `@internal class PlanThemeScope extends StatelessWidget` (`PlanThemeScope({PlanTheme? view, required Widget child})`, `static PlanTheme? of(BuildContext)`), `@internal class InheritedPlanTheme`, `@internal void validatePlanTheme(PlanTheme)`, `@internal PaperPalette planPaperPaletteFor(int paperArgb, PlanTheme? theme)` (Tasks 15, 20);
    - `const String kPlanFontAsset`, `const String kPlanFontLicenceAsset`, `@visibleForTesting void resetPlanFontsForTest()` (Task 19 ports `loadExportFont` and `ExportFontCache` over `kPlanFontAsset`).
    - Three new words the later tasks show: `lockedHint` (Task 15's lock hint), `sectionFailed` (Task 11's `KitSectionBoundary`), `planDamaged` (Task 20's bar warning).

Plan decision (which words move): `PlanStrings` keeps the 77 members of `FloorPlanStrings` (`jet_cad_floor_plan/lib/src/l10n/strings.dart:1-421`) that the generic shell, the generic symbol section, the Page panel and the layer panel, row and picker read (each read checked by grep: `planner_shell.dart:998,1006,1186,1246`, `document_toolbar.dart:90`, `selection_panel.dart:1141-1169` (the symbol section), `page_panel.dart`, `layers/*.dart`, `colors/color_picker.dart`) and adds three. **The 48 that stay behind:**
- **2b (tables, the service bar):** `tableNumberProblem`, `tableNumberUsed`, `numberingWarning`, `merge`, `split`, `tableTitle`, `number`, `seats`, `rotateLeft`, `rotateRight` (the table section, `selection_panel.dart:1201-1242`).
- **Sub-project 3 (the architecture kit; its words become `KitNames` words under `type:`/`tool:`/`property:` ids):** `roomOccupied`, `toolBox`, `toolWall`, `toolDoor`, `toolWindow`, `toolGap`, `toolRoom`, `toolSeparator`, `toolDimension`, `width`, `height`, `thickness`, `justifyLeft`, `justifyCentre`, `justifyRight`, `position`, `flipHinge`, `flipSwing`, `area`, `value`, `aligned`, `horizontal`, `vertical`, `end1`, `end2`, `endFixed`, `leftFace`, `centreline`, `rightFace`, `axesTurned`, `endOnWall`, `roomName`, `sampleHall`, `sampleKitchen`, `sampleBath`, `sampleLiving`, `sampleDining`, `sampleBedroom`.

Plan decision (the palette lives in the contract): `colorName` needs the plan's eight swatches. Today's `FloorPlanColor` (`jet_cad_floor_plan/lib/src/colors/plan_color.dart:1-38`) is pure Dart on purpose ("No Flutter import: the room (pure Dart over `package:jet_cad_2d`) reads it", `:6`), and a swatch is "a name from the plan's palette" (spec P3, Colour) that a kit's `ColourTarget.write` stores. A kit depends on `jet_cad_2d_kit`, never on `jet_cad_2d_plan` (A1), so the palette goes to the contract as `PlanSwatch` in a new pure-Dart file `packages/jet_cad_2d_kit/lib/src/kit/swatch.dart`, exported from `jet_cad_2d_kit.dart` only (not from `authoring.dart`; the purity test is untouched).

Plan decision (`PlanTheme`'s fields): the generic part of `FloorPlanTheme` (`jet_cad_floor_plan/lib/src/host/floor_plan_theme.dart:28-361`) is its four fields that are not a status, a group, the focus veil, the table colour or the service bar: `selectionOnLight`, `selectionOnDark`, `selectionWidth`, `canvasBackground`. The spec's "grips, the attachment marker" (P5) have no `FloorPlanTheme` field today: grips take `PaperPalette.grip*` and the marker `PaperPalette.snap` (`jet_cad_floor_plan/lib/src/symbols/symbol_place_tool.dart:509`), both from the paper palette that `planPaperPaletteFor` hands out with the theme's selection colour. No new field is invented here; 2b adds the rest.

Plan decision (`PlanTheme.of`): the public face of today's `FloorPlanThemeScope.of` (`floor_plan_theme.dart:465-472`), with its answer: the resolved theme, or null when no theme is set anywhere. "With defaults" (the task scope) is each field's null, which is today's value (`const PlanTheme()` draws what no theme draws); keeping null for "no theme" keeps ported P-6 unchanged and is what Tasks 15 and 18 read (`PlanTheme?`).

Plan decision (the locale): `PlanLocaleScope.push` reports `Localizations.maybeLocaleOf(context)` through Task 8's `controller.reportLocale`, English when there is no `Localizations` above (as `PlanStrings.of` answers English there). It is called from `didChangeDependencies`, inside a build, where a notifier's listener that marks another widget dirty would assert ("setState() or markNeedsBuild() called during build"); so the locale is reported in a post-frame callback (with `ensureVisualUpdate`), and only while the calling element is still mounted; an unchanged locale notifies nothing (`ValueNotifier` semantics inside `reportLocale`). A widget that shows a kit's words listens to `controller.locale` for that one-frame-later rebuild (Tasks 16, 17). A new plan's default separator is `documentSeparatorFor(lastStrings ?? PlanStrings.forLocale(locale))` of the last report: the reported language class (a host's own, through its `LocalizationsDelegate<PlanStrings>`), else the built-in language of the pushed locale. Today's controller takes the separator of the view's `FloorPlanStrings.of(context)`, so a host's own language subclass gives its own separator (`floor_plan_view.dart:552-555`, `floor_plan_controller.dart:1029-1030`); the plan library keeps that (controller ruling on NS7, A14 parity): `push` reports the locale **and** `PlanStrings.of(context)`, and `reportLocale(locale, strings:)` keeps the last reported strings, so a new plan's default separator is `documentSeparatorFor(lastStrings ?? PlanStrings.forLocale(locale))`. NS7 pins it (ported below).

Plan decision (the widget-level l10n and theme tests): the tests that pump `FloorPlanView` cannot be ported before the widgets exist. Each goes with the task that ports its widget, assertions unchanged where the semantics carry:
- `test/l10n/shell_words_test.dart` SW1, SW2 (design parts) → Tasks 16 and 20; their service-bar lines → 2b.
- `test/l10n/panel_words_test.dart` PW1, PW2 (Page panel and layers) → Task 18; the Wall section → sub-project 3.
- `test/l10n/overflow_test.dart` (design parts) and `test/l10n/leak_test.dart` LK1 (with a `RecordingPlanStrings` generated from `PlanStrings`) → Task 20; LK2 and `determinism_test.dart` DT1 (rooms, tables, dimensions) → sub-project 3.
- `test/l10n/stale_error_test.dart` (the layer name) and `numbered_names_test.dart` NN1 (`nextLayerName`) → Task 18; NN3 → sub-project 3.
- `test/l10n/symbol_words_test.dart` → Task 13. `value_words_test.dart` VW2-VW4 → 2b.
- `test/host/floor_plan_theme_test.dart`'s view-level groups (validation through the view, resolution in both modes, `FloorPlanView(theme:)`) → Task 20; S-12 (the export dialog) → Task 19; G-5 (overlays) → 2b. `test/host/theme_canvas_test.dart` (pixels) and `test/dark_canvas_test.dart` → Task 15. `test/invariants/theme_colours_test.dart` (no literal colour in a widget) → Task 20, over this package's `lib`.

- [ ] **Step 1: The palette in the contract: failing test.** Create `packages/jet_cad_2d_kit/test/kit/swatch_test.dart`:

```dart
// Spec P3 (colour targets) and P5: the plan's palette is contract data a
// kit's ColourTarget stores by name. Ported from jet_cad_floor_plan's
// plan_color.dart (plan colours spec PC-1): the names and hues are what a
// file and a print show, so both are pinned.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

void main() {
  test('W-SW1 the eight swatches, their names and hues, in palette order', () {
    // M-W-SW1: a hue changed, or two swatches swapped, goes red.
    expect(
        [for (final s in PlanSwatch.values) (s.name, s.rgb)],
        const [
          ('red', 0xE53935),
          ('orange', 0xFB8C00),
          ('yellow', 0xFDD835),
          ('green', 0x43A047),
          ('teal', 0x00897B),
          ('blue', 0x1E88E5),
          ('purple', 0x8E24AA),
          ('grey', 0x757575),
        ]);
  });

  test('W-SW2 a swatch is found by its name, never by its index', () {
    for (final s in PlanSwatch.values) {
      expect(planSwatchNamed(s.name), s, reason: s.name);
    }
    // M-W-SW2: `planSwatchNamed` comparing case-insensitively finds 'Teal'.
    for (final name in [null, '', 'Teal', 'magenta', '4', 'teal ']) {
      expect(planSwatchNamed(name), isNull, reason: '$name');
    }
  });
}
```

- [ ] **Step 2: Run it to see it fail.** Run: `cd packages/jet_cad_2d_kit && flutter test test/kit/swatch_test.dart`. Expected: compilation errors (`Undefined name 'PlanSwatch'`, `The method 'planSwatchNamed' isn't defined`).

- [ ] **Step 3: The palette.** Create `packages/jet_cad_2d_kit/lib/src/kit/swatch.dart` (ported from `jet_cad_floor_plan/lib/src/colors/plan_color.dart:1-38`; adaptations: `FloorPlanColor` → `PlanSwatch`, `floorPlanColorNamed` → `planSwatchNamed`, the header names the contract):

```dart
// The plan's palette (spec P3 "Colour", P5): eight fixed hues a kit's
// ColourTarget stores by name, never by index, so reordering or extending
// the palette breaks no file; a name this release does not know is kept as
// read and drawn as no colour. Ported from jet_cad_floor_plan's
// plan_color.dart (plan colours spec PC-1).
//
// Pure Dart: no Flutter import. A kit's parametric type (pure Dart over
// `package:jet_cad_2d`) reads it to colour what it generates.

/// A plan colour: one of eight fixed hues.
///
/// [rgb] is the document's colour, `0xRRGGBB`: what white paper, the export
/// and the print show. A dark canvas shows it re-toned, as it shows every
/// colour. A later release may add hues: an exhaustive `switch` over this
/// enum then needs a new case.
enum PlanSwatch {
  red(0xE53935),
  orange(0xFB8C00),
  yellow(0xFDD835),
  green(0x43A047),
  teal(0x00897B),
  blue(0x1E88E5),
  purple(0x8E24AA),
  grey(0x757575);

  const PlanSwatch(this.rgb);

  /// The hue, `0xRRGGBB`.
  final int rgb;
}

/// The palette entry named [name] (its `name`), or null for null and for a
/// name this release does not know.
PlanSwatch? planSwatchNamed(String? name) {
  if (name == null) return null;
  for (final s in PlanSwatch.values) {
    if (s.name == name) return s;
  }
  return null;
}
```

In `packages/jet_cad_2d_kit/lib/jet_cad_2d_kit.dart`, add beside the other `src/kit/` exports (keep the file's alphabetical order of export lines):

```dart
export 'src/kit/swatch.dart';
```

Append to the `## 0.1.0` list of `packages/jet_cad_2d_kit/CHANGELOG.md` (after Task 5's bullet):

```markdown
- `PlanSwatch`, the plan's eight-colour palette, and `planSwatchNamed`:
  kits name a swatch without depending on the plan library.
```

Run: `cd packages/jet_cad_2d_kit && flutter test test/kit/swatch_test.dart test/invariants`. Expected: `All tests passed!` (the purity test still finds `authoring.dart` pure: `swatch.dart` is not exported from it).

- [ ] **Step 4: The pubspec and the font files.** In `packages/jet_cad_2d_plan/pubspec.yaml`:
  - under `dependencies:`, add these lines (Task 6's pubspec leaves `flutter_localizations` to this task; spec 14d L2 needs Flutter's own `de` and `tr` words, as `jet_cad_floor_plan/pubspec.yaml` lists them):

    ```yaml
      flutter_localizations:
        sdk: flutter
    ```
  - add (or merge into an existing top-level `flutter:` section):

    ```yaml
    flutter:
      assets:
        - lib/fonts/Roboto-Regular.ttf
        - assets/fonts/Roboto_LICENSE.txt
    ```

  Copy the two files unmodified, from the repository root:

  ```bash
  mkdir -p packages/jet_cad_2d_plan/lib/fonts packages/jet_cad_2d_plan/assets/fonts
  cp packages/jet_cad_floor_plan/lib/fonts/Roboto-Regular.ttf packages/jet_cad_2d_plan/lib/fonts/Roboto-Regular.ttf
  cp packages/jet_cad_floor_plan/assets/fonts/Roboto_LICENSE.txt packages/jet_cad_2d_plan/assets/fonts/Roboto_LICENSE.txt
  ```

  Create `assets/fonts/README.md`:

  ```markdown
  # The plan library's font

  `Roboto-Regular.ttf` (in `lib/fonts/`, so a host can also declare the bare
  family from it: `packages/jet_cad_2d_plan/fonts/Roboto-Regular.ttf`) is the
  family `Roboto` that `DraftDocument`'s Standard text style asks for;
  `ensurePlanFonts` registers it (spec P5, ported from `jet_cad_floor_plan`).
  The screen draws text in it, and the PDF export embeds the same bytes.

  - Source: `packages/jet_cad_floor_plan/lib/fonts/Roboto-Regular.ttf`, itself
    a copy of `packages/jet_cad_2d_flutter/test/golden/fonts/Roboto-Regular.ttf`
    (Flutter 3.27.3's `bin/cache/artifacts/material_fonts/Roboto-Regular.ttf`)
  - SHA-256: `79e851404657dac2106b3d22ad256d47824a9a5765458edb72c9102a45816d95`
  - Licence: Apache 2.0, `Roboto_LICENSE.txt` beside this file (registered with
    `LicenseRegistry` under `Roboto` by `registerFontLicences`)
  - Copied unmodified, 2026-10-14, sub-project 2a Task 9

  `test/fonts/plan_assets_test.dart` asserts that the font equals the Flutter
  layer's golden copy byte for byte.
  ```

  Run: `cd packages/jet_cad_2d_plan && flutter pub get`, then from the root `git status --short`. Expected: the new and modified files of this step, and possibly ` M packages/*/analysis_options.yaml` rewritten by `pub get` — **never stage those**.

- [ ] **Step 5: Write the failing tests.**

  **Ported, assertions unchanged:**
  - `test/l10n/l10n_test.dart` ← `packages/jet_cad_floor_plan/test/l10n/l10n_test.dart:1-184`, every test: LB1, LB2, LB3, LB4, LB5, the group "NT the panels' numbers" (its three tests) and SF. Adaptations: the imports become `package:jet_cad_2d_plan/jet_cad_2d_plan.dart` (for `PlanStrings`, `PlanStringsEn`/`De`/`Tr`, `PlanLocalizations`, `planSupportedLocales`, `planLocalizationsDelegates`) and `package:jet_cad_2d_plan/src/l10n/number_text.dart`, `.../search_fold.dart`; renames `FloorPlanStrings` → `PlanStrings`, `FloorPlanStringsDe`/`En`/`Tr` → `PlanStringsDe`/`En`/`Tr`, `FloorPlanLocalizations` → `PlanLocalizations`, `floorPlanSupportedLocales` → `planSupportedLocales`, `floorPlanLocalizationsDelegates` → `planLocalizationsDelegates`; the header comment adds "Ported from jet_cad_floor_plan (2a Task 9)".
  - `test/l10n/document_separator_test.dart` ← `packages/jet_cad_floor_plan/test/host/new_plan_separator_test.dart`'s NS7a (`:96-102`) with its `_Fr` (`:76-82`, `extends PlanStringsEn`), which Task 8 sent here: `documentSeparatorFor` reads the class's separator, not its language code; and NS7 (`:104-127`, controller ruling: today's behaviour kept), assertions unchanged. The host's own class is `_Fr extends PlanStringsEn` (`languageCode` `'fr'`, `decimalSeparator` `','`), provided the way `PlanStrings.of` finds it (Task 9's `strings.dart`: `Localizations.of<PlanStrings>(context, PlanStrings)` first): a `_FrDelegate extends LocalizationsDelegate<PlanStrings>` (`:84-94`, `FloorPlanStrings` → `PlanStrings`) listed in the `MaterialApp`'s `localizationsDelegates` in place of `PlanLocalizations.delegate` (`...planLocalizationsDelegates.where((d) => d != PlanLocalizations.delegate)`). `FloorPlanView(controller: c)` → `_Shows(controller: c)`, a `StatefulWidget` calling `PlanLocaleScope.push(context, widget.controller)` from `didChangeDependencies` (as W-L1's `_Pusher`); `FloorPlanController()` → `PlanController(kits: const [])`; `FloorPlanStrings.forLocale` → `PlanStrings.forLocale`; `separatorOf(c.activeDocument)` → `c.document.components.get<PageComponent>(c.document.rootHandle)!.decimalSeparator`; `c.activeDocument` → `c.document`. Imports: `package:flutter/foundation.dart` (`SynchronousFuture`), `package:flutter/material.dart`, `package:flutter_test/flutter_test.dart`, `package:jet_cad_2d/jet_cad_2d.dart`, `package:jet_cad_2d_plan/jet_cad_2d_plan.dart`, `package:jet_cad_2d_plan/src/l10n/document_separator.dart`, `package:jet_cad_2d_plan/src/l10n/locale_scope.dart`.
  - `test/l10n/value_words_test.dart` ← the same file's `languages`, `expectWorded` (`:20-39`) and VW1 (`:42-62`), unchanged but for the same renames and imports (`package:jet_cad_2d/jet_cad_2d.dart` for the `LayerName*` classes). Not ported: VW2-VW4 (2b).
  - `test/l10n/numbered_names_test.dart` ← NN2's first loop only (`:46-53`, the `layerName` pattern), renamed "NN2 a layer name of another shape takes no N". Its last assertion (`:54-57`) reads `roomName`, which stays with the room (sub-project 3); W-NN4 below asserts the same rule (a name in another built-in language counts) over `layerName`. NN1 → Task 18, NN3 → sub-project 3.
  - `test/fonts/fonts_register_test.dart` ← `packages/jet_cad_floor_plan/test/fonts_register_test.dart:1-61`, FR1, alone in its file (a registered face cannot be taken back). Adaptations: import `package:jet_cad_2d_plan/src/fonts/plan_fonts.dart`; `kFloorPlanFontFamily` → `kPlanFontFamily`; `ensureFloorPlanFonts` → `ensurePlanFonts`; the `_MapBundle` key `'packages/jet_cad_floor_plan/lib/fonts/Roboto-Regular.ttf'` → `'packages/jet_cad_2d_plan/lib/fonts/Roboto-Regular.ttf'` (written out, not read from the constant: a key that drifted must turn it red).
  - `test/fonts/plan_assets_test.dart` ← `packages/jet_cad_floor_plan/test/package_assets_test.dart`: PA1 (its font and licence lines) and PA5 (its two font assets); full code below with the new tests.

  **New and adapted, full code.** Append to `test/l10n/value_words_test.dart`, inside `main()` after VW1:

```dart
  test('W-VW5 the plan library\'s three new words in each language', () {
    // M-W-VW5: a language that returns the English text for a new word
    // (copy-paste) makes the three not distinct.
    expectWorded((s) => s.lockedHint, english: 'This object is locked');
    expectWorded((s) => s.sectionFailed,
        english: 'This section could not be shown');
    expectWorded((s) => s.planDamaged,
        english: 'An edit failed and the plan may be damaged');
  });

  test('W-VW6 every swatch is worded, differently, in each language', () {
    // M-W-VW6: `colorName` returning one word for teal and blue in a
    // language goes red on the per-language set size.
    for (final s in languages) {
      final names = {for (final c in PlanSwatch.values) s.colorName(c)};
      expect(names, hasLength(PlanSwatch.values.length),
          reason: s.languageCode);
    }
    expectWorded((s) => s.colorName(PlanSwatch.teal), english: 'Teal');
  });
```

  and add `import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanSwatch;` to its imports.

  Append to `test/l10n/numbered_names_test.dart`, inside `main()`:

```dart
  test('W-NN4 a layer name in another built-in language counts', () {
    // M-W-NN4: `numberedNameIndex` comparing with `current` only (the
    // built-in languages left out of its list) answers null here.
    expect(
        numberedNameIndex(
            'Katman 7', (s, n) => s.layerName(n), const PlanStringsDe()),
        7);
    expect(
        numberedNameIndex(
            'Ebene 12', (s, n) => s.layerName(n), const PlanStringsEn()),
        12);
    // Folded: the fold given meets a case difference.
    expect(
        numberedNameIndex('KATMAN 3', (s, n) => s.layerName(n),
            const PlanStringsEn(),
            fold: (s) => s.toLowerCase()),
        3);
  });
```

  Create `test/l10n/locale_scope_test.dart`:

```dart
// Spec P5 "Words": the widgets push the app's locale into
// controller.locale, and a kit's KitWords read it live, so a kit's words
// follow a change of language while mounted; English stands in for a
// language the kit lacks. A new plan takes the pushed language's decimal
// separator (today's rule, spec Q0 N1).
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show KeyEvent;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/l10n/locale_scope.dart';

/// The services the probe tool's factory was given, per test.
PlanServices? captured;

/// A tool that does nothing: only its factory matters here.
class _IdleTool extends Tool {
  @override
  String get name => 'probe';
  @override
  ToolPhase get phase => ToolPhase.idle;
  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerExit(ToolContext ctx) {}
  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) =>
      KeyEventResult.ignored;
  @override
  void cancel(ToolContext ctx) {}
  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport,
      PaperPalette paper) {}
}

/// A kit with one tool, English and Turkish words, no German.
PlanKit probeKit() => PlanKit(
      id: 'wkit',
      version: '1.0.0',
      tools: [
        PlanTool(
            id: 'wkit.probe',
            icon: Icons.circle_outlined,
            create: (services) {
              captured = services;
              return _IdleTool();
            }),
      ],
      names: const KitNames({
        'en': {'tool:wkit.probe': 'Probe'},
        'tr': {'tool:wkit.probe': 'Sonda'},
      }),
    );

/// A widget of the plan library's shape: it pushes the locale from
/// didChangeDependencies, as every widget of Tasks 13 and 15-20 does.
class _Pusher extends StatefulWidget {
  const _Pusher({required this.controller});
  final PlanController controller;
  @override
  State<_Pusher> createState() => _PusherState();
}

class _PusherState extends State<_Pusher> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    PlanLocaleScope.push(context, widget.controller);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

Widget appIn(Locale locale, PlanController c) => MaterialApp(
    locale: locale,
    supportedLocales: planSupportedLocales,
    localizationsDelegates: planLocalizationsDelegates,
    home: _Pusher(controller: c));

void main() {
  setUp(() => captured = null);

  testWidgets(
      'W-L1 the app\'s locale reaches controller.locale and a kit\'s words '
      'follow it while mounted; a language the kit lacks reads English',
      (tester) async {
    final c = PlanController(kits: [probeKit()]);
    addTearDown(c.dispose);
    c.selectTool('wkit.probe');
    expect(captured, isNotNull, reason: 'premise: the tool\'s factory ran');
    final words = captured!.words;

    await tester.pumpWidget(appIn(const Locale('tr'), c));
    // M-W-L1a: `push` writing nothing (its body removed) leaves 'en'.
    expect(c.locale.value, const Locale('tr'));
    // M-W-L1b: Task 8's services built with the locale read once
    // (`final l = locale.value; KitNamesWords(names, () => l)`) keep the
    // construction's English here.
    expect(words.word('tool:wkit.probe'), 'Sonda');
    expect(words.locale, const Locale('tr'));

    await tester.pumpWidget(appIn(const Locale('de'), c));
    expect(c.locale.value, const Locale('de'));
    expect(words.word('tool:wkit.probe'), 'Probe',
        reason: 'no German word: the English one');

    await tester.pumpWidget(appIn(const Locale('tr'), c));
    expect(words.word('tool:wkit.probe'), 'Sonda',
        reason: 'back again, live');
  });

  testWidgets(
      'W-L4 a change of language while mounted reaches the listeners after '
      'the build, never inside it', (tester) async {
    final c = PlanController(kits: [probeKit()]);
    addTearDown(c.dispose);
    await tester.pumpWidget(appIn(const Locale('en'), c));
    final phases = <SchedulerPhase>[];
    c.locale.addListener(
        () => phases.add(SchedulerBinding.instance.schedulerPhase));
    await tester.pumpWidget(appIn(const Locale('tr'), c));
    // M-W-L4: `push` calling `controller.reportLocale(…)` at once
    // notifies inside the frame's build (persistentCallbacks).
    expect(phases, [SchedulerPhase.postFrameCallbacks]);
    expect(c.locale.value, const Locale('tr'));
    await tester.pumpWidget(appIn(const Locale('tr'), c));
    expect(phases, hasLength(1), reason: 'an unchanged locale writes nothing');
  });

  testWidgets('W-L2 with no Localizations above, the pushed locale is English',
      (tester) async {
    final c = PlanController(kits: [probeKit()]);
    addTearDown(c.dispose);
    c.reportLocale(const Locale('tr'));
    await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr, child: _Pusher(controller: c)));
    // M-W-L2: `push` returning early when `maybeLocaleOf` is null keeps
    // 'tr'.
    expect(c.locale.value, const Locale('en'));
  });

  test(
      'W-L3 a new plan takes the separator of the locale\'s built-in '
      'language: a comma for German and Turkish, a point otherwise', () {
    final c = PlanController(kits: const []);
    addTearDown(c.dispose);
    DecimalSeparator separatorAfterNewPlanIn(Locale locale) {
      c.reportLocale(locale);
      c.newPlan();
      final d = c.document;
      return d.components.get<PageComponent>(d.rootHandle)!.decimalSeparator;
    }

    // M-W-L3: `documentSeparatorFor` answering `point` always turns the
    // first two red.
    expect(separatorAfterNewPlanIn(const Locale('de')), DecimalSeparator.comma);
    expect(separatorAfterNewPlanIn(const Locale('tr')), DecimalSeparator.comma);
    expect(separatorAfterNewPlanIn(const Locale('fr')), DecimalSeparator.point);
    expect(separatorAfterNewPlanIn(const Locale('en')), DecimalSeparator.point);
    // An explicit separator wins over the locale.
    c.reportLocale(const Locale('de'));
    c.newPlan(decimalSeparator: '.');
    final d = c.document;
    expect(d.components.get<PageComponent>(d.rootHandle)!.decimalSeparator,
        DecimalSeparator.point);
  });
}
```

  Create `test/theme/plan_theme_test.dart` (ported from `packages/jet_cad_floor_plan/test/host/floor_plan_theme_test.dart` over the four generic fields, and `test/host/theme_canvas_test.dart:193-215`; what changed is listed after the code):

```dart
// Spec P5 "Theme": PlanTheme, the generic part of jet_cad_floor_plan's
// FloorPlanTheme, its value semantics, copyWith, merge and lerp, and its
// resolution below a PlanThemeScope: the ambient extension with the view's
// set fields over it, validated, provided by an inherited widget compared
// by ==. Ported from floor_plan_theme_test.dart (host embedding API spec
// Slice 3, T-1, T-2, S-3 to S-5, S-11, T-3) over the four fields that move;
// the statuses, groups, focus veil, table colour and service bar are 2b's.
//
// The themes are not the default shape: colours that are no palette's and
// no other theme's, widths that are not today's.
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show PaperPalette;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/theme/plan_theme.dart';

const Color seed = Color(0xFF2266CC);
final ThemeData lightTheme = ThemeData(colorSchemeSeed: seed);
final ThemeData darkTheme =
    ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark);
const int white = 0xFFFFFFFF;
const int blueprint = 0xFF1F3A5F;

/// A full theme, every field off today's value.
const PlanTheme fullA = PlanTheme(
  selectionOnLight: Color(0xFFD81B60),
  selectionOnDark: Color(0xFFFFD54F),
  selectionWidth: 4,
  canvasBackground: Color(0xFF263238),
);

/// A second full theme, every field different from [fullA]'s and today's.
const PlanTheme fullB = PlanTheme(
  selectionOnLight: Color(0xFF5E35B1),
  selectionOnDark: Color(0xFFC0CA33),
  selectionWidth: 2.5,
  canvasBackground: Color(0xFFEFEBE9),
);

typedef Field = ({
  String name,
  Object? Function(PlanTheme t) get,
  PlanTheme Function(PlanTheme t, Object v) set,
  Object? Function(Object a, Object b, double t) lerp,
});

Object? _color(Object a, Object b, double t) =>
    Color.lerp(a as Color, b as Color, t);
Object? _double(Object a, Object b, double t) =>
    lerpDouble(a as double, b as double, t);

/// The four fields, in declaration order.
final List<Field> fields = [
  (
    name: 'selectionOnLight',
    get: (t) => t.selectionOnLight,
    set: (t, v) => t.copyWith(selectionOnLight: v as Color),
    lerp: _color,
  ),
  (
    name: 'selectionOnDark',
    get: (t) => t.selectionOnDark,
    set: (t, v) => t.copyWith(selectionOnDark: v as Color),
    lerp: _color,
  ),
  (
    name: 'selectionWidth',
    get: (t) => t.selectionWidth,
    set: (t, v) => t.copyWith(selectionWidth: v as double),
    lerp: _double,
  ),
  (
    name: 'canvasBackground',
    get: (t) => t.canvasBackground,
    set: (t, v) => t.copyWith(canvasBackground: v as Color),
    lerp: _color,
  ),
];

PlanTheme only(Field field, PlanTheme source) =>
    field.set(const PlanTheme(), field.get(source)!);

void expectField(Object? a, Object? b, String reason) {
  if (a is double && b is double) {
    expect(a, closeTo(b, 1e-12), reason: reason);
  } else {
    expect(a, b, reason: reason);
  }
}

ThemeData lightWith(PlanTheme t) => lightTheme.copyWith(extensions: [t]);
ThemeData darkWith(PlanTheme t) => darkTheme.copyWith(extensions: [t]);

/// A valid theme whose width sits near the edge of its range.
const PlanTheme edgeA = PlanTheme(selectionWidth: 3);

/// [edgeA]'s partner: the width different.
const PlanTheme edgeB = PlanTheme(selectionWidth: 0.5);

/// The resolved theme a widget under a PlanThemeScope over [view] reads,
/// under [theme] (or the light theme), [dark] and [mode], zero animation.
PlanTheme? seen;

Widget scopeApp(
        {PlanTheme? view,
        ThemeData? theme,
        ThemeData? dark,
        ThemeMode mode = ThemeMode.light,
        bool scope = true,
        Key? key}) =>
    MaterialApp(
        key: key,
        theme: theme ?? lightTheme,
        darkTheme: dark ?? darkTheme,
        themeMode: mode,
        themeAnimationDuration: Duration.zero,
        home: scope
            ? PlanThemeScope(view: view, child: const _Probe())
            : const _Probe());

class _Probe extends StatelessWidget {
  const _Probe();
  @override
  Widget build(BuildContext context) {
    seen = PlanTheme.of(context);
    return const SizedBox();
  }
}

/// A dependent of the resolved theme: logs each dependency change.
class ThemeReader extends StatefulWidget {
  const ThemeReader({super.key, required this.log});
  final List<PlanTheme?> log;
  @override
  State<ThemeReader> createState() => _ThemeReaderState();
}

class _ThemeReaderState extends State<ThemeReader> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.log.add(PlanThemeScope.of(context));
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 10, height: 10);
}

void main() {
  setUp(() => seen = null);

  test('TH0 the field table names the four fields of a full theme', () {
    expect(fields, hasLength(4));
    for (final f in fields) {
      expect(f.get(fullA), isNotNull, reason: f.name);
      expect(f.get(fullB), isNotNull, reason: f.name);
      expect(f.get(fullA) == f.get(fullB), isFalse, reason: f.name);
      expect(f.get(const PlanTheme()), isNull, reason: f.name);
      expect(fullA.toString(), contains('${f.name}: '), reason: f.name);
    }
  });

  group('merge (T-2)', () {
    test(
        'TH1 a view setting one field over an ambient setting all four: '
        'that field the view\'s, the three others the ambient\'s', () {
      // M-TH1: `merge` taking `this.canvasBackground ?? other...` (the
      // ambient over the view) goes red for canvasBackground.
      for (final f in fields) {
        final merged = fullB.merge(only(f, fullA));
        for (final g in fields) {
          final want = identical(g, f) ? g.get(fullA) : g.get(fullB);
          expect(g.get(merged), want, reason: '${f.name} set: ${g.name}');
        }
      }
    });

    test('TH2 a null view is the ambient itself; an empty view keeps it', () {
      expect(identical(fullA.merge(null), fullA), isTrue);
      expect(fullA.merge(const PlanTheme()), fullA);
      expect(const PlanTheme().merge(fullA), fullA);
    });
  });

  group('lerp (S-4)', () {
    test('TH3 two full themes at 0, 0.25, 0.5 and 1: each field its type\'s '
        'lerp', () {
      // M-TH3: `selectionWidth` lerped with `t` and `1 - t` swapped.
      for (final t in [0.0, 0.25, 0.5, 1.0]) {
        final l = fullA.lerp(fullB, t);
        for (final f in fields) {
          expectField(f.get(l), f.lerp(f.get(fullA)!, f.get(fullB)!, t),
              '${f.name} at $t');
        }
      }
      for (final f in fields) {
        expect(f.get(fullA.lerp(fullB, 0)), f.get(fullA), reason: f.name);
        expect(f.get(fullA.lerp(fullB, 1)), f.get(fullB), reason: f.name);
      }
      expect(fullA.lerp(fullB, 0.25) == fullA, isFalse);
    });

    test(
        'TH4 R-1: two valid themes at t -0.2 and 1.2, both ways: the width '
        'within its ends, the theme valid', () {
      // M-TH4: `_lerpBetween` returning `lerpDouble(a, b, t)!` unclamped.
      for (final t in [-0.2, 1.2]) {
        for (final (a, b) in [(edgeA, edgeB), (edgeB, edgeA)]) {
          final l = a.lerp(b, t);
          final reason = '${a == edgeA ? 'A to B' : 'B to A'} at $t';
          expect(l.selectionWidth, inInclusiveRange(0.5, 3.0), reason: reason);
          expect(() => validatePlanTheme(l), returnsNormally, reason: reason);
        }
      }
      expect(edgeA.lerp(edgeB, 1.2).selectionWidth, 0.5);
      expect(edgeB.lerp(edgeA, 1.2).selectionWidth, 3.0);
    });

    test(
        'TH5 R-2: a theme lerped with an equal one is that theme at every t '
        '(itself when equal); a field equal on both sides stays exactly '
        'equal', () {
      for (var i = 1; i < 100; i++) {
        final t = i / 100;
        expect(fullA.lerp(fullA, t), fullA, reason: 'at $t');
        expect(identical(fullA.lerp(fullA.copyWith(), t), fullA), isTrue,
            reason: 'at $t');
        final l = fullA.lerp(fullA.copyWith(selectionWidth: 5), t);
        expect(l.selectionWidth, closeTo(4 + t, 1e-12), reason: 'at $t');
        for (final f in fields.where((f) => f.name != 'selectionWidth')) {
          expect(f.get(l) == f.get(fullA), isTrue, reason: '${f.name} at $t');
        }
      }
    });

    test(
        'TH6 T1-b: a field null on one side switches at 0.5 and never fades '
        '(no selectionOnLight to 0xFF00897B: null at 0.25, opaque at 0.75)',
        () {
      // M-TH6: `_lerp` lerping toward a null side as transparent
      // (`Color.lerp(a, null, t)`) makes 0.75 translucent.
      const to = PlanTheme(selectionOnLight: Color(0xFF00897B));
      expect(const PlanTheme().lerp(to, 0.25).selectionOnLight, isNull);
      final at75 = const PlanTheme().lerp(to, 0.75).selectionOnLight!;
      expect(at75, const Color(0xFF00897B));
      expect(at75.a, 1.0);
      for (final t in [0.0, 0.25, 0.49]) {
        expect(const PlanTheme().lerp(fullB, t), const PlanTheme(),
            reason: 'at $t');
        expect(fullA.lerp(const PlanTheme(), t), fullA, reason: 'at $t');
      }
      for (final t in [0.5, 0.75, 1.0]) {
        expect(const PlanTheme().lerp(fullB, t), fullB, reason: 'at $t');
        expect(fullA.lerp(const PlanTheme(), t), const PlanTheme(),
            reason: 'at $t');
      }
    });

    test('TH7 lerp(null, t) is the theme itself', () {
      for (final t in [0.0, 0.3, 1.0]) {
        expect(identical(fullA.lerp(null, t), fullA), isTrue);
      }
    });

    test(
        'TH8 through ThemeData.lerp: a light ThemeData with the extension and '
        'a dark one without carry the first\'s unchanged; both with it, '
        'lerped', () {
      for (final t in [0.25, 0.75]) {
        expect(
            identical(
                ThemeData.lerp(lightWith(fullA), darkTheme, t)
                    .extension<PlanTheme>(),
                fullA),
            isTrue,
            reason: 'at $t');
        expect(
            ThemeData.lerp(lightWith(fullA), darkWith(fullB), t)
                .extension<PlanTheme>(),
            fullA.lerp(fullB, t),
            reason: 'at $t');
      }
    });
  });

  group('copyWith, ==, hashCode, toString', () {
    test('TH9 each field changed alone makes != and a different hash', () {
      // M-TH9: `==` without `other.canvasBackground == canvasBackground`.
      expect(fullA, fullA.copyWith());
      expect(identical(fullA, fullA.copyWith()), isFalse);
      expect(fullA.copyWith().hashCode, fullA.hashCode);
      for (final f in fields) {
        final changed = f.set(fullA, f.get(fullB)!);
        expect(f.get(changed), f.get(fullB), reason: f.name);
        for (final g in fields) {
          if (!identical(g, f)) {
            expect(g.get(changed), g.get(fullA),
                reason: '${f.name}: ${g.name}');
          }
        }
        expect(changed == fullA, isFalse, reason: f.name);
        expect(changed.hashCode == fullA.hashCode, isFalse, reason: f.name);
        expect(only(f, fullA) == const PlanTheme(), isFalse, reason: f.name);
        expect(only(f, fullA).hashCode == const PlanTheme().hashCode, isFalse,
            reason: f.name);
      }
    });

    test('TH10 toString names the set fields only, in declaration order', () {
      expect(const PlanTheme().toString(), 'PlanTheme()');
      expect(const PlanTheme(selectionWidth: 4).toString(),
          'PlanTheme(selectionWidth: 4.0)');
      const canvas = Color(0xFF263238);
      expect(
          const PlanTheme(canvasBackground: canvas, selectionWidth: 4)
              .toString(),
          'PlanTheme(selectionWidth: 4.0, canvasBackground: $canvas)');
      expect(fullA.type, PlanTheme);
    });
  });

  group('validation (S-5), through the scope', () {
    testWidgets(
        'TH11 the width: accepted and refused, naming the field; an ambient '
        'theme out of range is refused the same way', (tester) async {
      // M-TH11: `validatePlanTheme` without its `positive(selectionWidth)`
      // call accepts every refused theme.
      Future<Object?> pumpWith({PlanTheme? view, PlanTheme? ambient}) async {
        await tester.pumpWidget(scopeApp(
            key: UniqueKey(),
            view: view,
            theme: ambient == null ? lightTheme : lightWith(ambient)));
        return tester.takeException();
      }

      final accepted = <(String, PlanTheme)>[
        ('selectionWidth', const PlanTheme(selectionWidth: 0.5)),
        ('all', fullA),
      ];
      final refused = <(String, PlanTheme)>[
        for (final v in [0.0, -1.0, double.infinity, double.nan])
          ('selectionWidth', PlanTheme(selectionWidth: v)),
      ];
      for (final (name, theme) in accepted) {
        expect(await pumpWith(view: theme), isNull, reason: '$name: $theme');
        expect(seen, theme, reason: '$name: $theme');
        expect(await pumpWith(ambient: theme), isNull,
            reason: 'ambient $name: $theme');
      }
      for (final (name, theme) in refused) {
        for (final ambient in [false, true]) {
          final e = ambient
              ? await pumpWith(ambient: theme)
              : await pumpWith(view: theme);
          expect(e, isA<ArgumentError>().having((e) => e.name, 'name', name),
              reason: '${ambient ? 'ambient ' : ''}$name: $theme');
        }
      }
      expect(refused, hasLength(4));
    });
  });

  group('resolution (T-2, S-11)', () {
    testWidgets(
        'TH12 P-6: no theme anywhere resolves to null; ambient '
        'only is the ambient itself; view only the view itself',
        (tester) async {
      // M-TH12: `PlanThemeScope.build` merging `view.merge(ambient)` (the
      // ambient over the view) breaks the identity of the view-only case
      // only when an ambient exists, so TH13 catches it; here, a scope that
      // drops the view (`InheritedPlanTheme(theme: ambient, ...)`) goes red.
      await tester.pumpWidget(scopeApp());
      expect(seen, isNull);

      await tester.pumpWidget(scopeApp(theme: lightWith(fullA)));
      expect(identical(seen, fullA), isTrue);

      await tester.pumpWidget(scopeApp(view: fullB));
      expect(identical(seen, fullB), isTrue);
    });

    testWidgets(
        'TH13 M-H30: one field in the ambient theme and another in the '
        'view\'s resolve to both; one field in both takes the view\'s',
        (tester) async {
      await tester.pumpWidget(scopeApp(
          view: const PlanTheme(selectionOnLight: Color(0xFFD81B60)),
          theme:
              lightWith(const PlanTheme(canvasBackground: Color(0xFF00897B)))));
      expect(
          seen,
          const PlanTheme(
              canvasBackground: Color(0xFF00897B),
              selectionOnLight: Color(0xFFD81B60)));

      await tester.pumpWidget(scopeApp(
          view: const PlanTheme(selectionWidth: 5),
          theme: lightWith(const PlanTheme(
              selectionWidth: 3, canvasBackground: Color(0xFF00897B)))));
      expect(seen,
          const PlanTheme(selectionWidth: 5, canvasBackground: Color(0xFF00897B)));
    });

    testWidgets(
        'TH14 an ambient switch (light with A to dark with B, zero '
        'animation) reaches the scope after one pump', (tester) async {
      await tester.pumpWidget(
          scopeApp(theme: lightWith(fullA), dark: darkWith(fullB)));
      expect(seen, fullA);
      await tester.pumpWidget(scopeApp(
          theme: lightWith(fullA), dark: darkWith(fullB), mode: ThemeMode.dark));
      await tester.pump();
      expect(seen, fullB);
    });

    testWidgets(
        'TH15 with no scope above, the ambient extension, validated: in '
        'range read, out of range refused naming the field (R-4)',
        (tester) async {
      // M-TH15: `PlanThemeScope.of` returning the ambient without
      // `validatePlanTheme` lets the bad width through.
      await tester.pumpWidget(scopeApp(scope: false, theme: lightWith(fullA)));
      expect(identical(seen, fullA), isTrue);
      await tester.pumpWidget(scopeApp(scope: false, key: UniqueKey()));
      expect(seen, isNull);

      await tester.pumpWidget(scopeApp(
          scope: false,
          key: UniqueKey(),
          theme: lightWith(fullA.merge(const PlanTheme(selectionWidth: -3)))));
      expect(tester.takeException(),
          isA<ArgumentError>().having((e) => e.name, 'name', 'selectionWidth'));
    });
  });

  group('T1-c: the scope notifies by value', () {
    test('TH16 updateShouldNotify: false for equal themes, true for different',
        () {
      // M-TH16: `updateShouldNotify` returning `!identical(theme, old.theme)`.
      final a1 = fullA.copyWith();
      final a2 = fullA.copyWith();
      expect(identical(a1, a2), isFalse);
      InheritedPlanTheme scope(PlanTheme? t) =>
          InheritedPlanTheme(theme: t, child: const SizedBox());
      expect(scope(a1).updateShouldNotify(scope(a2)), isFalse);
      expect(scope(null).updateShouldNotify(scope(null)), isFalse);
      expect(scope(fullA).updateShouldNotify(scope(fullB)), isTrue);
      expect(scope(fullA).updateShouldNotify(scope(null)), isTrue);
      expect(scope(null).updateShouldNotify(scope(fullA)), isTrue);
    });

    testWidgets(
        'TH17 a host rebuild with an equal, non-identical view theme notifies '
        'no dependent; a different one does', (tester) async {
      final log = <PlanTheme?>[];
      final reader = ThemeReader(log: log);
      Widget app(PlanTheme view) => MaterialApp(
          theme: lightTheme,
          themeAnimationDuration: Duration.zero,
          home: PlanThemeScope(view: view, child: reader));
      await tester.pumpWidget(app(fullA.copyWith()));
      expect(log, [fullA]);
      await tester.pumpWidget(app(fullA.copyWith()));
      expect(log, [fullA], reason: 'an equal theme notifies nobody');
      await tester.pumpWidget(app(fullB.copyWith()));
      expect(log, [fullA, fullB]);
    });
  });

  test(
      'TH18 planPaperPaletteFor: today\'s const sets with no colour for the '
      'set', () {
    const onLight = Color(0xFFD81B60);
    const onDark = Color(0xFFFFD54F);
    expect(identical(planPaperPaletteFor(white, null), PaperPalette.light),
        isTrue);
    expect(identical(planPaperPaletteFor(blueprint, null), PaperPalette.dark),
        isTrue);
    const lightOnly = PlanTheme(selectionOnLight: onLight);
    const darkOnly = PlanTheme(selectionOnDark: onDark);
    expect(
        identical(planPaperPaletteFor(blueprint, lightOnly), PaperPalette.dark),
        isTrue);
    expect(identical(planPaperPaletteFor(white, darkOnly), PaperPalette.light),
        isTrue);
    // M-TH18: the two colours swapped (`selectionOnLight` for the dark set).
    expect(planPaperPaletteFor(white, lightOnly),
        PaperPalette.light.withSelection(onLight));
    expect(planPaperPaletteFor(blueprint, darkOnly),
        PaperPalette.dark.withSelection(onDark));
    expect(
        identical(planPaperPaletteFor(white, const PlanTheme(selectionWidth: 4)),
            PaperPalette.light),
        isTrue);
  });
}
```

  What changed against the source tests (all else is copied with `FloorPlanTheme` → `PlanTheme`, `FloorPlanThemeScope` → `PlanThemeScope`, `InheritedFloorPlanTheme` → `InheritedPlanTheme`, `validateFloorPlanTheme` → `validatePlanTheme`, `paperPaletteFor` → `planPaperPaletteFor`, and `palette_fixture.dart`'s `seed`, `lightTheme`, `darkTheme`, `white`, `blueprint` copied in):
  - **Fixture:** `fullA`/`fullB` keep the source's values of the four fields; `edgeA`/`edgeB` keep only `selectionWidth` (3 and 0.5, the source's). The views are replaced by a `PlanThemeScope` with a probe child (the widgets come in Tasks 15-20).
  - **TH0** asserts `hasLength(4)` where the source asserts 17: the field table is the fixture. Reported here as the one count that changes with the field set.
  - **TH1** drops the source's `TextStyle` branch (no style field moves). **TH4** keeps the within-ends and validity loop; the source's four overshoot assertions name 2b fields (`statusFillOpacity`, `tableColorOpacity`, `groupChipPadding`, `statusCaptionStyle`) and are replaced by the same check on `selectionWidth`. **TH6** is T1-b over `selectionOnLight` instead of `groupFrameColor`. **TH10**'s two-field example uses `selectionWidth` and `canvasBackground` (the source's used two 2b fields), the colour's text interpolated from `Color.toString`. **TH11** keeps the source's accepted/refused shape for `selectionWidth`; the refused count is 4. **TH12** is P-6 with its assertions unchanged (`isNull`, then the two identities).
  - **Not ported (2b):** T1-a (text styles), R-3 (styles), the G-5 overlay tests. View-level groups → Task 20.

  Create `test/fonts/plan_assets_test.dart`:

```dart
// Spec P5 "Fonts": the plan's font and its licence are the package's
// assets, read under its `packages/` keys (ported from jet_cad_floor_plan's
// package_assets_test PA1, PA5), the font is the vendored face byte for
// byte, and registerFontLicences registers the licence under `Roboto`.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/fonts/plan_fonts.dart';

class _MapBundle extends CachingAssetBundle {
  _MapBundle(this.assets);

  final Map<String, Uint8List> assets;

  @override
  Future<ByteData> load(String key) async {
    final bytes = assets[key];
    if (bytes == null) throw FlutterError('no asset $key');
    return ByteData.sublistView(bytes);
  }
}

void main() {
  // Written out, not read from the constants: a key that drifted back to
  // another package's must turn these red.
  const fontKey = 'packages/jet_cad_2d_plan/lib/fonts/Roboto-Regular.ttf';
  const licenceKey = 'packages/jet_cad_2d_plan/assets/fonts/Roboto_LICENSE.txt';

  test('PA1 the constants name the package keys', () {
    expect(kPlanFontAsset, fontKey);
    expect(kPlanFontLicenceAsset, licenceKey);
    expect(kPlanFontFamily, 'Roboto');
  });

  test('PA5 the pubspec declares the two font assets', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final asset in const [
      'lib/fonts/Roboto-Regular.ttf',
      'assets/fonts/Roboto_LICENSE.txt',
    ]) {
      expect(
          RegExp('^\\s*-\\s+${RegExp.escape(asset)}\\s*\$', multiLine: true)
              .hasMatch(pubspec),
          isTrue,
          reason: asset);
      expect(File(asset).existsSync(), isTrue, reason: asset);
    }
  });

  test('W-F1 the font is the vendored face, byte for byte', () {
    // M-W-F1: any other file at lib/fonts/Roboto-Regular.ttf.
    final ours = File('lib/fonts/Roboto-Regular.ttf').readAsBytesSync();
    final vendored =
        File('../jet_cad_2d_flutter/test/golden/fonts/Roboto-Regular.ttf')
            .readAsBytesSync();
    expect(ours, orderedEquals(vendored));
    expect(
        File('assets/fonts/Roboto_LICENSE.txt').readAsStringSync(),
        File('../jet_cad_2d_flutter/test/golden/fonts/Roboto_LICENSE.txt')
            .readAsStringSync());
  });

  test(
      'W-F2 registerFontLicences adds one entry for Roboto, its text read '
      'from the given bundle under the package key', () async {
    LicenseRegistry.reset();
    addTearDown(LicenseRegistry.reset);
    registerFontLicences(
        _MapBundle({licenceKey: utf8.encode('Licence text 7')}));
    final entries = await LicenseRegistry.licenses.toList();
    // M-W-F2a: the package named 'roboto' finds nothing here.
    final roboto = [
      for (final e in entries)
        if (e.packages.contains('Roboto')) e
    ];
    expect(roboto, hasLength(1));
    // M-W-F2b: `rootBundle` in place of the given bundle reads the real
    // licence (or nothing) instead.
    expect([for (final p in roboto.single.paragraphs) p.text].join('\n'),
        'Licence text 7');
  });
}
```

- [ ] **Step 6: Run them to see them fail.** Run: `cd packages/jet_cad_2d_plan && flutter test test/l10n test/theme test/fonts`. Expected: compilation errors naming the missing libraries (`Error when reading 'lib/src/l10n/locale_scope.dart'`, `'lib/src/theme/plan_theme.dart'`, `'lib/src/fonts/plan_fonts.dart'`) and undefined names (`PlanStrings`, `PlanTheme`, `planSupportedLocales`).

- [ ] **Step 7: The words (ported).**

  **`lib/src/l10n/strings.dart`** ← `packages/jet_cad_floor_plan/lib/src/l10n/strings.dart:1-421`. Adaptations:
  1. Replace lines 1-44 (header, imports, class head, `of`, `forLocale`, `languageCode`, `decimalSeparator`) with:

```dart
// The plan library's own words (spec P5 "Words"): one abstract class, a
// member per string -- a getter for a fixed one, a method for one with
// values or a count -- and one implementation per built-in language, so the
// compiler refuses a language that misses a word. A host may subclass a
// language and provide it through its own delegate. Ported from
// jet_cad_floor_plan's FloorPlanStrings (spec 14d L1, L2): its generic
// words; a kit's words come from KitNames (KitWords).
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show LayerNameProblem;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanSwatch;

import 'strings_de.dart';
import 'strings_en.dart';
import 'strings_tr.dart';

/// The plan library's words in one language.
abstract class PlanStrings {
  const PlanStrings();

  /// The words of [context]'s scope: those a [Localizations] scope provides
  /// through a `LocalizationsDelegate<PlanStrings>`, else the built-in
  /// language of the resolved locale, else English. Never throws.
  static PlanStrings of(BuildContext context) =>
      Localizations.of<PlanStrings>(context, PlanStrings) ??
      forLocale(Localizations.maybeLocaleOf(context));

  /// The built-in language for [locale]'s language code, English for any
  /// other (or none).
  static PlanStrings forLocale(Locale? locale) =>
      switch (locale?.languageCode) {
        'de' => const PlanStringsDe(),
        'tr' => const PlanStringsTr(),
        _ => const PlanStringsEn(),
      };

  /// The language's code: `en`, `de` or `tr` for the built-in ones.
  String get languageCode;

  /// The decimal separator of the panels' numbers (L12): `.` or `,`.
  String get decimalSeparator;
```

  2. Delete the declarations (with their doc comments) of the 48 members listed in this task's "stay behind" decision, and the two now-empty comment lines `// Values the engine and the planner hand out (L6, L5).` keeps only `layerNameProblem` (keep the comment); `// Names written into the document once (Task 5, L7).` keeps only `layerName` (keep the comment).
  3. Replace `String colorName(FloorPlanColor color);` (`:358`) with `String colorName(PlanSwatch swatch);`, doc unchanged.
  4. Before the class's closing brace, add:

```dart

  // The plan library's own notices (sub-project 2a).

  /// The canvas's short hint when an edit would change a locked object
  /// (spec P4 "Locks").
  String get lockedHint;

  /// What stands in a property section whose kit code failed (spec P4
  /// "The failure boundary").
  String get sectionFailed;

  /// The warning a damaged plan shows (spec P4: a rollback that threw).
  String get planDamaged;
```

  **`lib/src/l10n/strings_en.dart`** ← `strings_en.dart:1-438`; **`strings_de.dart`** ← `strings_de.dart:1-442`; **`strings_tr.dart`** ← `strings_tr.dart:1-436`. The same adaptations in each:
  1. The header line becomes `// The plan library's words in English (spec P5; ported from jet_cad_floor_plan's strings_en.dart, spec 14d L1).` (German, Turkish likewise); the imports become:

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart'
    show
        LayerNameBadCharacter,
        LayerNameDuplicate,
        LayerNameEdgeSpace,
        LayerNameEmpty,
        LayerNameProblem,
        LayerNameTooLong;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanSwatch;

import 'strings.dart';
```

  2. `class FloorPlanStringsEn extends FloorPlanStrings` → `class PlanStringsEn extends PlanStrings` (its constructor `const PlanStringsEn();`), `De`, `Tr` likewise; the class doc `/// The planner's words in English.` → `/// The plan library's words in English.`
  3. Delete the `@override` of each of the 48 staying members.
  4. In `colorName`, the parameter becomes `(PlanSwatch swatch) => switch (swatch)` and each case `FloorPlanColor.x` → `PlanSwatch.x`; the words are unchanged.
  5. Before the closing brace, add the three new words:

  English:

```dart

  @override
  String get lockedHint => 'This object is locked';

  @override
  String get sectionFailed => 'This section could not be shown';

  @override
  String get planDamaged => 'An edit failed and the plan may be damaged';
```

  German:

```dart

  @override
  String get lockedHint => 'Dieses Objekt ist gesperrt';

  @override
  String get sectionFailed => 'Dieser Abschnitt kann nicht angezeigt werden';

  @override
  String get planDamaged =>
      'Eine Bearbeitung ist fehlgeschlagen; der Plan ist möglicherweise '
      'beschädigt';
```

  Turkish:

```dart

  @override
  String get lockedHint => 'Bu nesne kilitli';

  @override
  String get sectionFailed => 'Bu bölüm gösterilemiyor';

  @override
  String get planDamaged =>
      'Bir düzenleme başarısız oldu; plan bozulmuş olabilir';
```

  **`lib/src/l10n/localizations.dart`** (ported from `jet_cad_floor_plan/lib/src/l10n/localizations.dart:1-48`; adaptations: the names):

```dart
// The plan library's localizations (spec P5 "Words"; ported from
// jet_cad_floor_plan's localizations.dart, spec 14d L2): its delegate, the
// locales it speaks, and the delegates a host's MaterialApp lists for them.
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'strings.dart';

/// The locales the plan library speaks: English, German, Turkish.
const List<Locale> planSupportedLocales = [
  Locale('en'),
  Locale('de'),
  Locale('tr'),
];

/// The plan library's delegate and Flutter's three, for a host's
/// `MaterialApp.localizationsDelegates` (a host that lists `de` or `tr` in
/// `supportedLocales` needs Flutter's, or Material widgets throw).
const List<LocalizationsDelegate<Object>> planLocalizationsDelegates = [
  PlanLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// The plan library's [LocalizationsDelegate]: the built-in language of the
/// resolved locale, English for any other. Optional: without it,
/// [PlanStrings.of] picks the same language from the locale.
abstract final class PlanLocalizations {
  static const LocalizationsDelegate<PlanStrings> delegate =
      _PlanStringsDelegate();
}

final class _PlanStringsDelegate extends LocalizationsDelegate<PlanStrings> {
  const _PlanStringsDelegate();

  /// Every locale: an unknown one is answered in English.
  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<PlanStrings> load(Locale locale) =>
      SynchronousFuture(PlanStrings.forLocale(locale));

  @override
  bool shouldReload(_PlanStringsDelegate old) => false;
}
```

  **Copied with renames only** (each file's code unchanged but for the names; header comment gains "Ported from jet_cad_floor_plan (2a Task 9)."):
  - `lib/src/l10n/panel_number.dart` ← `jet_cad_floor_plan/lib/src/panel_number.dart:1-18` (no rename).
  - `lib/src/l10n/number_text.dart` ← `jet_cad_floor_plan/lib/src/l10n/number_text.dart:1-35`: `import '../panel_number.dart';` → `import 'panel_number.dart';` (the `strings.dart` import keeps its name), `FloorPlanStrings` → `PlanStrings`.
  - `lib/src/l10n/search_fold.dart` ← `jet_cad_floor_plan/lib/src/l10n/search_fold.dart:1-31` (no rename).
  - `lib/src/l10n/numbered_names.dart` ← `jet_cad_floor_plan/lib/src/l10n/numbered_names.dart:1-35`: the imports to `strings*.dart`; `FloorPlanStrings` → `PlanStrings`, `FloorPlanStringsEn`/`De`/`Tr` → `PlanStringsEn`/`De`/`Tr`; the header's "a new room's `Room n` and" is dropped (the room is sub-project 3's).
  - `lib/src/l10n/document_separator.dart` ← `jet_cad_floor_plan/lib/src/l10n/document_separator.dart:1-17`: `FloorPlanStrings` → `PlanStrings` (the `strings.dart` import keeps its name).

  **`lib/src/l10n/locale_scope.dart`** (new):

```dart
// Spec P5 "Words": the widgets push the app's Localizations locale into
// controller.locale; a kit's KitWords read it live. Every widget of the
// plan library calls [PlanLocaleScope.push] from didChangeDependencies
// (which a change of the app's locale triggers, through the dependency
// `maybeLocaleOf` registers) and when it is handed another controller.
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../controller/plan_controller.dart';

/// Pushes the locale of a widget's [Localizations] into its controller.
abstract final class PlanLocaleScope {
  static const Locale _english = Locale('en');

  /// Reports [context]'s locale and its [PlanStrings] to [controller]
  /// (`reportLocale`, Task 8, with this task's `strings:`),
  /// English when no [Localizations] is above (as `PlanStrings.of` answers
  /// English there), and registers [context] as a dependent of the locale.
  ///
  /// Never notifies during a build: the report lands after the current
  /// frame (one is scheduled when none is pending), and only while
  /// [context] is still mounted; an unchanged locale notifies nothing.
  static void push(BuildContext context, PlanController controller) {
    final next = Localizations.maybeLocaleOf(context) ?? _english;
    // The language class too (a host's own gives its own separator: NS7).
    final strings = PlanStrings.of(context);
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (context.mounted) controller.reportLocale(next, strings: strings);
      })
      ..ensureVisualUpdate();
  }
}
```

- [ ] **Step 8: The theme (ported).** Create `lib/src/theme/plan_theme.dart` — ported from `packages/jet_cad_floor_plan/lib/src/host/floor_plan_theme.dart:1-498`. Adaptations: the 13 non-generic fields (`statusCaptionStyle`, `statusFillOpacity`, `tableColorOpacity`, `groupFrameColor`, `groupFrameWidth`, `groupFrameMargin`, `groupChipColor`, `groupChipTextStyle`, `groupChipRadius`, `groupChipPadding`, `focusVeilColor`, `focusVeilOpacity`, `serviceBarHeight`) and `kTableColorOpacity` removed, with their branches in `copyWith`, `merge`, `lerp`, `==`, `hashCode`, `_fields` and the validator, and the now-unused `_mergeStyle`, `_lerpInsets`, `_lerpStyle`; names `FloorPlanTheme` → `PlanTheme`, `validateFloorPlanTheme` → `validatePlanTheme`, `paperPaletteFor` → `planPaperPaletteFor`, `FloorPlanThemeScope` → `PlanThemeScope`, `InheritedFloorPlanTheme` → `InheritedPlanTheme`; the new `PlanTheme.of`. The whole file:

```dart
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
```

- [ ] **Step 9: The fonts (ported).** Create `lib/src/fonts/plan_fonts.dart` — ported from `packages/jet_cad_floor_plan/lib/src/fonts.dart:1-41` and the asset constants and `registerFontLicences` of `lib/src/export/export_font.dart:8-37`. Adaptations: `kFloorPlanFontFamily` → `kPlanFontFamily`, `ensureFloorPlanFonts` → `ensurePlanFonts`, `resetFloorPlanFontsForTest` → `resetPlanFontsForTest`, `kExportFontAsset` → `kPlanFontAsset`, `kExportFontLicenceAsset` → `kPlanFontLicenceAsset`, the keys name `jet_cad_2d_plan`; `loadExportFont` and `ExportFontCache` stay for Task 19 (which imports `kPlanFontAsset` from here):

```dart
// The plan's font (spec P5 "Fonts", today's host guide §2, moved
// unchanged): documents name the family `Roboto`, and the measurer uses
// that name verbatim, but a font a package declares registers as
// `packages/jet_cad_2d_plan/Roboto`. So the package registers the bare
// family itself, from its own bytes, before the first document is
// measured: the screen then lays text out in the same face the PDF embeds,
// on every platform, whatever the host's default font. Its Apache 2.0
// licence is registered at start-up by [registerFontLicences]. Ported from
// jet_cad_floor_plan's fonts.dart and export_font.dart.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, FontLoader, rootBundle;

/// The family documents name and the plan library registers.
const String kPlanFontFamily = 'Roboto';

/// The bundled font's asset key: the package's `lib/fonts/` file, declared
/// under `assets:` in its `pubspec.yaml`, so every host has it. It lives
/// under `lib/` so a host can also declare the bare family `Roboto` from it
/// (`packages/jet_cad_2d_plan/fonts/Roboto-Regular.ttf`); either way
/// [ensurePlanFonts] registers `Roboto` from these bytes.
const String kPlanFontAsset =
    'packages/jet_cad_2d_plan/lib/fonts/Roboto-Regular.ttf';

/// The font's licence text (declared under `assets:` in the package's
/// `pubspec.yaml`).
const String kPlanFontLicenceAsset =
    'packages/jet_cad_2d_plan/assets/fonts/Roboto_LICENSE.txt';

Future<void>? _registered;

/// Forgets the registration, so the next [ensurePlanFonts] registers again:
/// a test seam (the registration is process-wide, and a test must not
/// inherit another's pending future). The engine keeps any face already
/// loaded.
@visibleForTesting
void resetPlanFontsForTest() => _registered = null;

/// Registers family [kPlanFontFamily] from the package's bundled Roboto
/// (read from [bundle], [rootBundle] when null). Once per process: every
/// call after the first returns the first call's future, unless that one
/// failed, in which case the next call tries again. A host awaits it before
/// `runApp` (after `WidgetsFlutterBinding.ensureInitialized()`).
Future<void> ensurePlanFonts([AssetBundle? bundle]) {
  final pending = _registered;
  if (pending != null) return pending;
  final loader = FontLoader(kPlanFontFamily)
    ..addFont((bundle ?? rootBundle).load(kPlanFontAsset));
  final next = loader.load();
  _registered = next;
  next.then<void>((_) {}, onError: (Object _) {
    if (identical(_registered, next)) _registered = null;
  });
  return next;
}

/// Registers the font's licence with [LicenseRegistry] under the package
/// name `Roboto`, its text read from [bundle] ([rootBundle] when null) when
/// the licences are collected.
void registerFontLicences([AssetBundle? bundle]) {
  LicenseRegistry.addLicense(() async* {
    final text = await (bundle ?? rootBundle).loadString(kPlanFontLicenceAsset);
    yield LicenseEntryWithLineBreaks(const <String>['Roboto'], text);
  });
}
```

- [ ] **Step 10: The barrel and the controller's default separator.** In `lib/jet_cad_2d_plan.dart`, add (keeping the file's export lines sorted):

```dart
export 'src/fonts/plan_fonts.dart'
    show ensurePlanFonts, kPlanFontFamily, registerFontLicences;
export 'src/l10n/localizations.dart';
export 'src/l10n/strings.dart';
export 'src/l10n/strings_de.dart';
export 'src/l10n/strings_en.dart';
export 'src/l10n/strings_tr.dart';
export 'src/theme/plan_theme.dart' show PlanTheme;
```

  In `lib/src/controller/new_plan.dart` (Task 8), make `decimalSeparatorFor(Locale locale)` return `documentSeparatorFor(PlanStrings.forLocale(locale))` (import `../l10n/document_separator.dart` and `../l10n/strings.dart`), replacing Task 8's `switch` on the language code, so the plan library has one mapping for a locale (W-L3 pins it).

  In `lib/src/controller/plan_controller.dart` (Task 8; controller ruling on NS7), import `../l10n/document_separator.dart` and `../l10n/strings.dart`, then:
  1. Add the field and the helper:

```dart
  /// The language class the last report carried (a host's own, NS7), or
  /// null when it carried none.
  PlanStrings? _reportedStrings;

  /// A new plan's separator under [locale]: the reported class's, else the
  /// built-in language's.
  DecimalSeparator _separatorOf(Locale locale) =>
      documentSeparatorFor(_reportedStrings ?? PlanStrings.forLocale(locale));
```

  2. `reportLocale` becomes `void reportLocale(Locale locale, {PlanStrings? strings})`; its first lines become `_locale.value = locale; _reported = locale; _reportedStrings = strings;`, and its `final separator = decimalSeparatorFor(locale);` becomes `final separator = _separatorOf(locale);`.
  3. In `newPlan`, `: decimalSeparatorFor(reported));` becomes `: _separatorOf(reported));`.

  Every positional call `reportLocale(locale)` (Task 8's NS, CM and C tests, W-L2, W-L3, Task 17's test) compiles unchanged and reports no class.

- [ ] **Step 11: Run the tests.** Run: `cd packages/jet_cad_2d_plan && flutter test test/l10n test/theme test/fonts`. Expected: `All tests passed!`.

- [ ] **Step 12: Format and the gates.** Run, one command at a time:
  - `cd packages/jet_cad_2d_kit && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0.
  - `cd packages/jet_cad_2d_plan && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — the same. If `flutter analyze` reports an import of this task's new files as unnecessary or unused (Flutter's libraries re-export parts of one another), delete that import line; change nothing else to quiet it.
  - From the root, `git status --short`: only this task's files (plus any ` M .../analysis_options.yaml` from `pub get`, not staged).

- [ ] **Step 13: Commit.**

```bash
git add packages/jet_cad_2d_kit/lib/src/kit/swatch.dart packages/jet_cad_2d_kit/lib/jet_cad_2d_kit.dart packages/jet_cad_2d_kit/CHANGELOG.md packages/jet_cad_2d_kit/test/kit/swatch_test.dart packages/jet_cad_2d_plan/pubspec.yaml packages/jet_cad_2d_plan/lib/fonts/Roboto-Regular.ttf packages/jet_cad_2d_plan/assets/fonts/Roboto_LICENSE.txt packages/jet_cad_2d_plan/assets/fonts/README.md packages/jet_cad_2d_plan/lib/src/l10n/strings.dart packages/jet_cad_2d_plan/lib/src/l10n/strings_en.dart packages/jet_cad_2d_plan/lib/src/l10n/strings_de.dart packages/jet_cad_2d_plan/lib/src/l10n/strings_tr.dart packages/jet_cad_2d_plan/lib/src/l10n/localizations.dart packages/jet_cad_2d_plan/lib/src/l10n/panel_number.dart packages/jet_cad_2d_plan/lib/src/l10n/number_text.dart packages/jet_cad_2d_plan/lib/src/l10n/search_fold.dart packages/jet_cad_2d_plan/lib/src/l10n/numbered_names.dart packages/jet_cad_2d_plan/lib/src/l10n/document_separator.dart packages/jet_cad_2d_plan/lib/src/l10n/locale_scope.dart packages/jet_cad_2d_plan/lib/src/theme/plan_theme.dart packages/jet_cad_2d_plan/lib/src/fonts/plan_fonts.dart packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart packages/jet_cad_2d_plan/lib/src/controller/new_plan.dart packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart packages/jet_cad_2d_plan/test/l10n/l10n_test.dart packages/jet_cad_2d_plan/test/l10n/value_words_test.dart packages/jet_cad_2d_plan/test/l10n/numbered_names_test.dart packages/jet_cad_2d_plan/test/l10n/locale_scope_test.dart packages/jet_cad_2d_plan/test/theme/plan_theme_test.dart packages/jet_cad_2d_plan/test/fonts/fonts_register_test.dart packages/jet_cad_2d_plan/test/fonts/plan_assets_test.dart packages/jet_cad_2d_plan/test/l10n/document_separator_test.dart
git commit -m "$(cat <<'EOF'
feat(plan): words, fonts and theme of the plan library (2a P5)

PlanStrings in English, German and Turkish carries the generic words of
the planner's strings plus three notices; the widgets push the app's
locale into the controller, and a kit's words follow it live. The font
and its licence move with ensurePlanFonts and registerFontLicences.
PlanTheme is the generic part of FloorPlanTheme, and the palette's eight
swatches go to the contract, where a kit's colour target reads them.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 14: Mutation check** (committed files only; after each: run the named test, see it red, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0):
  - M-W-SW1: in `packages/jet_cad_2d_kit/lib/src/kit/swatch.dart`, `teal(0x00897B)` → `teal(0x00897C)` → W-SW1 red (`cd packages/jet_cad_2d_kit && flutter test test/kit/swatch_test.dart`).
  - M-W-SW2: in `swatch.dart`, `if (s.name == name)` → `if (s.name == name.trim().toLowerCase())` → W-SW2 red.
  - M-W-VW5: in `strings_tr.dart`, `lockedHint => 'Bu nesne kilitli'` → `lockedHint => 'This object is locked'` → W-VW5 red (`flutter test test/l10n/value_words_test.dart`).
  - M-W-VW6: in `strings_de.dart`, `PlanSwatch.teal => 'Petrol'` → `PlanSwatch.teal => 'Blau'` → W-VW6 red.
  - M-W-NN4: in `numbered_names.dart`, the list `[current, const PlanStringsEn(), const PlanStringsDe(), const PlanStringsTr()]` → `[current]` → W-NN4 red (`flutter test test/l10n/numbered_names_test.dart`).
  - M-W-L1a: in `locale_scope.dart`, delete the statement `SchedulerBinding.instance ..addPostFrameCallback(...)..ensureVisualUpdate();` → W-L1 red (`flutter test test/l10n/locale_scope_test.dart`).
  - M-W-L4: in `push`, replace that statement by `controller.reportLocale(next, strings: strings);` (at once, no post-frame callback) → W-L4 red.
  - M-NS7: in `push`, `controller.reportLocale(next, strings: strings)` → `controller.reportLocale(next)` (the strings dropped) → NS7 red (`point`, not `comma`; `flutter test test/l10n/document_separator_test.dart`).
  - M-W-L1b: in `lib/src/controller/plan_controller.dart`'s private constructor (where Task 8 builds `KitNamesWords(kit.names, () => _locale.value)`), read the locale once before the map (`final fixed = _locale.value;`) and pass `() => fixed` → W-L1 red at `'Sonda'`.
  - M-W-L2: in `push`, `final next = Localizations.maybeLocaleOf(context) ?? _english;` → `final next = Localizations.maybeLocaleOf(context) ?? controller.locale.value;` → W-L2 red.
  - M-W-L3: in `document_separator.dart`, the body → `DecimalSeparator.point` → W-L3 red.
  - M-TH1: in `plan_theme.dart` `merge`, `other.canvasBackground ?? canvasBackground` → `canvasBackground ?? other.canvasBackground` → TH1 red (`flutter test test/theme/plan_theme_test.dart`).
  - M-TH3: in `lerp`, `_lerp(selectionWidth, other.selectionWidth, t, _lerpBetween)` → `_lerp(selectionWidth, other.selectionWidth, 1 - t, _lerpBetween)` → TH3 red.
  - M-TH4: `_lerpBetween` body → `lerpDouble(a, b, t)!` → TH4 red.
  - M-TH6: `_lerp`'s `a == null || b == null ? (t < 0.5 ? a : b)` → `a == null || b == null ? (t < 0.5 ? a : b) ?? a` and, for colours, the call `_lerp(selectionOnLight, ...)` → `Color.lerp(selectionOnLight, other.selectionOnLight, t)` → TH6 red.
  - M-TH9: in `==`, delete `other.canvasBackground == canvasBackground &&` (keep the expression valid) → TH9 red.
  - M-TH11: in `validatePlanTheme`, delete the `if` → TH11 red.
  - M-TH12: in `PlanThemeScope.build`, `InheritedPlanTheme(theme: resolved, ...)` → `InheritedPlanTheme(theme: ambient, ...)` → TH12 red (view only).
  - M-TH15: in `PlanThemeScope.of`, delete `if (ambient != null) validatePlanTheme(ambient);` → TH15 red.
  - M-TH16: `updateShouldNotify` body → `!identical(theme, oldWidget.theme)` → TH16 and TH17 red.
  - M-TH18: in `planPaperPaletteFor`, swap `theme?.selectionOnDark` and `theme?.selectionOnLight` → TH18 red.
  - M-W-F1: none needed beyond the byte comparison (a replaced asset is the mutant): `printf x >> packages/jet_cad_2d_plan/lib/fonts/Roboto-Regular.ttf` → W-F1 red (`flutter test test/fonts/plan_assets_test.dart`); revert with `git checkout --`.
  - M-W-F2a: in `plan_fonts.dart`, `const <String>['Roboto']` → `const <String>['roboto']` → W-F2 red.
  - M-W-F2b: `(bundle ?? rootBundle).loadString` → `rootBundle.loadString` → W-F2 red.
  - FR1 (ported) keeps its source mutation M-14b1-2: in `ensurePlanFonts`, `FontLoader(kPlanFontFamily)` → `FontLoader('packages/jet_cad_2d_plan/Roboto')` → FR1 red (`flutter test test/fonts/fonts_register_test.dart`).

  Quote each red line.

#### Assumed from earlier tasks

- Task 8: `PlanController({required List<PlanKit> kits, ...})`; `ValueListenable<Locale> locale` (default `Locale('en')`) and `@internal void reportLocale(Locale)`, its writer; `void newPlan({String? decimalSeparator})` where the argument is the separator character (`'.'` or `','`), as today's `newPlan`; `DraftDocument get document` with a `PageComponent` on the root after `newPlan`; `selectTool(String id)` runs (or has run) the tool's factory; the kit's `PlanServices.words` is Task 4's `KitNamesWords(names, () => _locale.value)` (W-L1 and mutation M-W-L1b rely on the getter being live).
- Task 4: `PlanTool({required String id, required IconData icon, String? letter, Set<Capability> needs, PlanToolSettings<Object>? settings, required Tool Function(PlanServices) create})`; `KitWords.word`, `KitWords.locale`; `PlanKit(tools: ...)` validates `tool:` words with English present.
- Task 6: the package `jet_cad_2d_plan` with its barrel, `pubspec.yaml` and `analysis_options.yaml`.
- Tasks 15 and 18 (written in parallel) read this task's files as `lib/src/l10n/strings.dart`, `strings_en.dart`, `locale_scope.dart` and `PlanTheme.of` as `PlanTheme?`, and a `push` that never notifies during a build: the names and behaviour above match them.

#### Interface problem

Resolved by controller ruling (NS7): today's behaviour kept (A14 parity); `push` reports the locale and `PlanStrings.of(context)`, `reportLocale(locale, {strings})` keeps the last strings, and NS7 is ported with its assertions unchanged (`document_separator_test.dart`, M-NS7).

---

