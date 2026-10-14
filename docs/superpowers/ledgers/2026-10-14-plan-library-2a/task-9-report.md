# Task 9 report: words, fonts, theme (spec P5)

Status: DONE. One commit, `5229bd1b feat(plan): words, fonts and theme of the plan library (2a P5)` (BASE 551985c8).

## Implemented

- **Contract (`jet_cad_2d_kit`).** `lib/src/kit/swatch.dart`: `enum PlanSwatch` (eight hues, `rgb`) and `planSwatchNamed`. Ported from `plan_color.dart`. It is exported from `jet_cad_2d_kit.dart` only, so `authoring.dart` and the purity test are untouched. One CHANGELOG bullet was added under 0.1.0.
- **Words.**
  - `PlanStrings` (abstract) and `PlanStringsEn`/`De`/`Tr`. A script ported them from the four `FloorPlanStrings*` files and dropped the 48 "stay behind" members by name. The script asserted that exactly 48 were removed from each file. The result has 80 members (77 kept and 3 new: `lockedHint`, `sectionFailed`, `planDamaged`), and each language has 80 `@override`s. `colorName` takes `PlanSwatch`.
  - `localizations.dart` defines `planSupportedLocales`, `planLocalizationsDelegates` and `PlanLocalizations.delegate`.
  - These files were ported with renames only: `panel_number.dart`, `number_text.dart`, `search_fold.dart`, `numbered_names.dart` and `document_separator.dart`.
- **`PlanLocaleScope.push`** (`lib/src/l10n/locale_scope.dart`). It reports the locale and `PlanStrings.of(context)` in a post-frame callback (with `ensureVisualUpdate`), and only while the context is still mounted. With no `Localizations` above, it reports English.
- **Controller (NS7 ruling).**
  - `reportLocale(Locale, {PlanStrings? strings})` keeps `_reportedStrings`.
  - `_separatorOf(locale)` is `documentSeparatorFor(_reportedStrings ?? PlanStrings.forLocale(locale))`. Both `reportLocale` and `newPlan` use it.
  - In `new_plan.dart`, `decimalSeparatorFor` is now `documentSeparatorFor(PlanStrings.forLocale(locale))`.
- **Theme.** `lib/src/theme/plan_theme.dart`: `PlanTheme` (four fields), `PlanTheme.of`, and the `@internal` `PlanThemeScope`, `InheritedPlanTheme`, `validatePlanTheme` and `planPaperPaletteFor`. This is the brief's file, verbatim.
- **Fonts.**
  - `lib/src/fonts/plan_fonts.dart`: `kPlanFontFamily`, `kPlanFontAsset`, `kPlanFontLicenceAsset`, `ensurePlanFonts`, `resetPlanFontsForTest` and `registerFontLicences`.
  - `lib/fonts/Roboto-Regular.ttf` (SHA-256 `79e851…6d95`, identical to the golden copy) and `assets/fonts/Roboto_LICENSE.txt` were copied unmodified. `assets/fonts/README.md` is new.
  - `pubspec.yaml` gains `flutter_localizations` and the two assets.
- **Barrel.** It now exports `PlanStrings*`, the localizations, `PlanTheme` (show) and the fonts (show `ensurePlanFonts`, `kPlanFontFamily`, `registerFontLicences`).

## TDD evidence

- **RED (kit),** `flutter test test/kit/swatch_test.dart`:
  - `test/kit/swatch_test.dart:12:26: Error: Undefined name 'PlanSwatch'.`
  - `test/kit/swatch_test.dart:27:14: Error: Method not found: 'planSwatchNamed'.`
- **GREEN (kit),** `flutter test test/kit/swatch_test.dart test/invariants`: `00:00 +14: All tests passed!`
- **RED (plan),** `flutter test test/l10n test/theme test/fonts`, all 8 files failing to load (`00:00 +0 -8: Some tests failed.`), for example:
  - `test/fonts/fonts_register_test.dart:12:8: Error: Error when reading 'lib/src/fonts/plan_fonts.dart': No such file or directory`
  - `test/l10n/locale_scope_test.dart:14:8: Error: Error when reading 'lib/src/l10n/locale_scope.dart': No such file or directory`
  - `test/theme/plan_theme_test.dart:17:8: Error: Error when reading 'lib/src/theme/plan_theme.dart': No such file or directory`
  - `test/l10n/l10n_test.dart:101:18: Error: Undefined name 'planLocalizationsDelegates'.`
- **GREEN (plan),** the same command: `00:01 +46: All tests passed!`

## Mutations

Every mutation was run on the committed files. Each was reverted with `git checkout -- <file>`, and `git diff --quiet -- <file>` then exited 0 (printed `revert 0` each time). The red lines are quoted from the runs.

| Mutation | File change | Red |
|---|---|---|
| M-W-SW1 | `teal(0x00897B)` → `teal(0x00897C)` | W-SW1: `Which: at location [4] is (String, int):<(teal, 35196)> instead of (String, int):<(teal, 35195)>` |
| M-W-SW2 | `s.name == name.trim().toLowerCase()` | W-SW2: `Expected: null  Actual: PlanSwatch:<PlanSwatch.teal>` |
| M-W-VW5 | tr `lockedHint` → English text | W-VW5: `Actual: Set:['This object is locked', 'Dieses Objekt ist gesperrt'] Which: has length of <2>` |
| M-W-VW6 | de `PlanSwatch.teal => 'Blau'` | W-VW6: `Expected: an object with length of <8> … has length of <7>` |
| M-W-NN4 | list → `<PlanStrings>[current]` | W-NN4: `Expected: <7>  Actual: <null>` |
| M-W-L1a | push's SchedulerBinding statement deleted | W-L1 `Expected: Locale:<tr> Actual: Locale:<en>` (W-L4 and W-L2 also red) |
| M-W-L4 | statement → `controller.reportLocale(next, strings: strings);` | W-L4: `Actual: [SchedulerPhase:SchedulerPhase.persistentCallbacks]` |
| M-NS7 | `reportLocale(next)` (strings dropped) | NS7: `Expected: DecimalSeparator:<DecimalSeparator.comma> Actual: …point>` |
| M-W-L1b | `final fixed = _locale.value; … () => fixed` | W-L1: `Expected: 'Sonda'  Actual: 'Probe'` |
| M-W-L2 | `?? controller.locale.value` | W-L2: `Expected: Locale:<en> Actual: Locale:<tr>` |
| M-W-L3 | `documentSeparatorFor` body → `DecimalSeparator.point` | W-L3: `Expected: …comma> Actual: …point>` |
| M-TH1 | merge: `canvasBackground ?? other.canvasBackground` | TH1, `canvasBackground set: canvasBackground` (Expected 0xFF263238's colour, Actual 0xFFEFEBE9's) |
| M-TH3 | width lerped with `1 - t` | TH3: `Expected: a numeric value within <1e-12> of <4.0> Actual: <2.5>` (TH4 also red) |
| M-TH4 | `_lerpBetween` → `lerpDouble(a, b, t)!` | TH4: `Expected: be in range from 0.5 (inclusive) to 3.0 (inclusive) Actual: <3.4999999999999996>` |
| M-TH6 | `selectionOnLight: Color.lerp(selectionOnLight, other.selectionOnLight, t)` | TH6: `Expected: null Actual: Color:<Color(alpha: 0.2500, …)>` (TH5 also red) |
| M-TH9 | `==` without `canvasBackground` | TH9: `Expected: false Actual: <true>` |
| M-TH11 | the `if` in `validatePlanTheme` deleted | TH11 and TH15: `Expected: <Instance of 'ArgumentError'> with \`name\`: 'selectionWidth' Actual: <null>` |
| M-TH12 | `InheritedPlanTheme(theme: ambient, …)` | TH12: `Expected: true Actual: <false>` (TH11 and TH13 also red) |
| M-TH15 | `PlanThemeScope.of` without validation | TH15: `Expected: <Instance of 'ArgumentError'> … Actual: <null>` |
| M-TH16 | `!identical(theme, oldWidget.theme)` | TH16 `Expected: false Actual: <true>`; TH17 red |
| M-TH18 | the two selection colours swapped | TH18: `Expected: true Actual: <false>` |
| M-W-F1 | `printf x >> lib/fonts/Roboto-Regular.ttf` | W-F1: `Which: at location [171676] is [` |
| M-W-F2a | `['roboto']` | W-F2: `Expected: an object with length of <1> Actual: []` |
| M-W-F2b | `rootBundle.loadString` | W-F2: `Expected: 'Licence text 7' Actual: 'Apache License Version 2.0, January 2004 …'` |
| M-14b1-2 (FR1) | `FontLoader('packages/jet_cad_2d_plan/Roboto')` | FR1: `Expected: not <380.0> Actual: <380.0>` |
| M-PA6 (extra) | onError reset line deleted | PA6 red: `no asset packages/jet_cad_2d_plan/lib/fonts/Roboto-Regular.ttf` (the failed future is held) |
| M-PA8 (extra) | `if (pending != null) return pending;` deleted | PA8: `Expected: same instance as <Instance of 'Future<void>'>` |
| M-NS7c (extra) | `_reportedStrings = strings;` deleted in the controller | NS7: `Expected: …comma> Actual: …point>` |

Notes on how the brief's mutation text was applied:
- **M-TH6:** I applied the second clause only (the `Color.lerp` call). The first clause (`?? a`) is a no-op on its own.
- **M-W-L1a:** I deleted the whole post-frame statement.

## Gates (run after the commit, on a clean tree)

- **`packages/jet_cad_2d_kit`:**
  - `dart format .` reformatted 1 file before the commit, then `Formatted 68 files (0 changed)`.
  - `flutter test`: `00:04 +314: All tests passed!`
  - `flutter analyze`: `No issues found!`
  - `dart format --output=none --set-exit-if-changed .`: exit 0.
- **`packages/jet_cad_2d_plan`:**
  - `flutter test`: `00:02 +110: All tests passed!`
  - `flutter analyze`: `No issues found! (ran in 2.5s)`
  - `dart format --output=none --set-exit-if-changed .`: exit 0 (`Formatted 53 files (0 changed)`).
- **`cd packages/jet_cad_2d_plan && dart pub publish --dry-run`:** `Package has 0 warnings.` This was after the commit. Before it, the one warning was "4 checked-in files are modified".
- **`dart run tool/ci/check_kit_deps.dart`:** `kit dependencies: 1 package(s) checked, none names the plan library or another kit`, exit 0.
- **`git status --short`:** clean. `pub get` rewrote no `analysis_options.yaml` this time.

## Files

- **Kit:**
  - `packages/jet_cad_2d_kit/lib/src/kit/swatch.dart`
  - `packages/jet_cad_2d_kit/lib/jet_cad_2d_kit.dart`
  - `packages/jet_cad_2d_kit/CHANGELOG.md`
  - `packages/jet_cad_2d_kit/test/kit/swatch_test.dart`
- **Plan library, under `packages/jet_cad_2d_plan/`:**
  - `pubspec.yaml`
  - `lib/fonts/Roboto-Regular.ttf`, `assets/fonts/Roboto_LICENSE.txt`, `assets/fonts/README.md`
  - `lib/jet_cad_2d_plan.dart`
  - `lib/src/l10n/{strings,strings_en,strings_de,strings_tr,localizations,panel_number,number_text,search_fold,numbered_names,document_separator,locale_scope}.dart`
  - `lib/src/theme/plan_theme.dart`, `lib/src/fonts/plan_fonts.dart`
  - `lib/src/controller/{new_plan,plan_controller}.dart`
  - `test/l10n/{l10n,value_words,numbered_names,locale_scope,document_separator}_test.dart`
  - `test/theme/plan_theme_test.dart`
  - `test/fonts/{fonts_register,plan_assets}_test.dart`

## Deviations from the brief

1. **`locale_scope.dart` adds `import 'strings.dart';`.** The brief's code calls `PlanStrings.of(context)` without importing it, so it does not compile without the import.
2. **Unnecessary imports were removed** from three tests, which Step 12 allows. `flutter analyze` flagged them:
   - `package:jet_cad_2d_plan/jet_cad_2d_plan.dart` in `test/fonts/plan_assets_test.dart` (everything it used comes from `src/fonts/plan_fonts.dart`);
   - the same import in `test/theme/plan_theme_test.dart` (from `src/theme/plan_theme.dart`);
   - `package:flutter/services.dart show KeyEvent` in `test/l10n/locale_scope_test.dart` (`material.dart` provides it).
3. **`strings.dart` doc:** `/// [color]'s name, …` became `/// [swatch]'s name, …`. The brief says "doc unchanged", but the parameter was renamed to `swatch`, so `[color]` would point at nothing.
4. **Two header comments.**
   - `numbered_names.dart`: dropping the room phrase left the example "`Room 3` and `Oda 3`". It is now "`Layer 3` and `Katman 3`", and the lines are rewrapped.
   - `panel_number.dart` had no header comment, so a one-line header naming the port was added above its doc comment.
5. **`plan_assets_test.dart` also ports PA6 and PA8** (`ensurePlanFonts`' retry after a failure and its one registration) from `package_assets_test.dart`'s V-11 group. Their assertions are unchanged, and they run with `setUp`/`tearDown(resetPlanFontsForTest)`. The brief listed only PA1 and PA5, but these two test the function this task ports, and no other task names them. Mutations M-PA6 and M-PA8 above turn them red.
6. **The language-file headers are two comment lines**, because the brief's one-line header is longer than 80 columns. `strings_en.dart`'s original second line ("today's literals, byte for byte…") was replaced by it.
7. **`newPlan`'s and `reportLocale`'s doc comments** were reworded to mention `strings` (the brief gave only the code changes).

There is no change to a Shared interface or to another task's contract.

## Self-review

- **Ported test assertions are unchanged.**
  - `l10n_test`: LB1-LB5, the NT group and SF are renames and imports only.
  - VW1 is unchanged.
  - NN2 keeps its first loop only, as the brief says.
  - FR1 changes only in names and the bundle key.
  - NS7 and NS7a are adapted exactly as the brief lists.
  - PA1 and PA5 are the brief's code.
- **The strings ports are mechanical.** The script failed on any chunk that mixed a kept member and a staying one. `merge` and `split` share one doc chunk in the abstract class, and both stay. Every remaining word text is the source's, byte for byte.
- **The swatch file is pure Dart** with no imports, and the purity invariant tests pass.
- **`decimalSeparatorFor` is now unused in `lib/`.** The controller calls `_separatorOf` (the brief's code). It is kept as the brief instructs.

## Concerns

- **`decimalSeparatorFor` (in `new_plan.dart`) has no caller left in `lib/`.** The brief's Step 10 rewrites it and also has the controller use `_separatorOf` directly. A reviewer may want it either deleted, or used inside `_separatorOf` as the fallback (the same behaviour). I left it as the brief wrote it.
- **The `_reportedStrings` lifecycle.** A positional `reportLocale(locale)`, for example from a widget outside a `Localizations` scope, clears a host class reported earlier. That is the brief's `_reportedStrings = strings` semantics and matches "the last report".
