# Task 3 report — the Page panel control (P1, M-Q0-g)

Branch `claude/exciting-pasteur-9m22jv`, on HEAD `44e96ef`. Nothing is committed, staged or pushed. No `analysis_options.yaml` was changed: `git status` lists only the 7 files below.

## Changes

- `packages/jet_cad_floor_plan/lib/src/l10n/strings.dart:296-298`: the new abstract getter `String get pageDecimalSeparator;`.
  - It sits between `pageBreaks` and `paper`.
  - Its doc comment is in the file's style: `"Decimal separator"`, with a note that it is the page's own separator, not `[decimalSeparator]`.
- `strings_en.dart`: `'Decimal separator'`. `strings_de.dart`: `'Dezimaltrennzeichen'`. `strings_tr.dart`: `'Ondalık ayırıcı'`. Each is placed after `pageBreaks`.
- `packages/jet_cad_floor_plan/test/l10n/recording_strings.dart:258`: `String get pageDecimalSeparator => record(inner.pageDecimalSeparator);`. It is recorded, unlike `decimalSeparator` at `:30`.
- `packages/jet_cad_floor_plan/lib/src/page_panel.dart:238-260`: the new control, right after the unit menu and before the check boxes.
  - The caption is `Text(_strings.pageDecimalSeparator)` (`:243`). It sits between `SizedBox`es of 8 and 4 px, like the Paper caption.
  - The control is `SegmentedButton<DecimalSeparator>`, with key `page-decimal-separator` (`:245`).
  - Its segments are labelled `Text('1.5')` and `Text('1,5')`. The labels carry the keys `page-decimal-separator-point` and `-comma`, the way the orientation control keys its labels.
  - `selected: {page.decimalSeparator}` (`:257`).
  - `onSelectionChanged: (s) => _set(page.copyWith(decimalSeparator: s.single))` (`:259`).
- `packages/jet_cad_floor_plan/test/page_panel_test.dart`: a new `group('the decimal separator (spec Q0 P1, M-Q0-g)')` at `:102`, holding PS1, PS2 and PS3, plus an import of `l10n/localizations.dart`.
  - The file had no ids, so the tests are named PS1 to PS3 inside a group named after the spec.

### How the panel follows the page

`build` is a `ValueListenableBuilder` over `widget.page`, a `PageNotifier` (`page_panel.dart:131-133`). `PageNotifier` refreshes on `CommandApplied`, `CommandUndone` and `CommandRedone` when the root is touched, and on load and purge (`jet_cad_2d_flutter/lib/src/page_notifier.dart:19-32`).

So the control moves with an Undo or Redo made anywhere, with no extra listener. PS2 shows it.

### Other implementers of FloorPlanStrings

- **Implementers:** `RecordingFloorPlanStrings` is the only class in the repo that `implements` it (repo-wide grep). `test/l10n/l10n_test.dart:25` `_Custom extends FloorPlanStringsTr`, so it inherits the new member.
- **No other implementers:** the apps, `tool/ci/host_probe/lib/main.dart:232` and the host guide only call `FloorPlanStrings.of(context)`. They implement nothing.
- **So `tool/ci` is not affected**, and its `dart test` was not run.

## Tests (M-Q0-g)

Every fixture is a page at cm, 1:20, with its origin at (7350, −1230). Each test sets the UI's separator against the page's (V-11).

- **PS1** (`:135`), an English UI on a `comma` page:
  - the caption `Decimal separator` shows;
  - `1.5` and `1,5` each show once;
  - the selection is `{comma}`.
  - A tap on `1.5`:
    - sets the page to `point`, with `undoDepth` 1, so exactly one command;
    - moves the selection to `{point}`;
    - keeps the unit, the scale and the origin.
  - `doc.commands.undo()`:
    - puts the page back to `comma`, with `undoDepth` 0;
    - puts the selection back to `{comma}`.
- **PS2** (`:162`), an English UI on a `comma` page. A `SetComponentCommand` to `point`, an Undo and a Redo are all made through `doc.commands`, never through the panel. The selection follows each one: `{point}`, then `{comma}`, then `{point}`.
- **PS3** (`:180`), a German UI on a `point` page:
  - the caption `Dezimaltrennzeichen` shows;
  - both labels show;
  - the selection is `{point}`;
  - `undoDepth` is 0: nothing is written when the panel opens.
  - A tap on `1,5` writes `comma` (depth 1). A tap on `1.5` writes `point` (depth 2) against the UI's comma, and the selection is `{point}`.

Run alone, `flutter test test/page_panel_test.dart` gives `00:03 +7: All tests passed!`.

## Named mutants

Each mutant was applied to the working tree, run, and reverted by a byte copy of the good file. The restore was confirmed with `cmp`.

| # | Mutant (at `page_panel.dart`) | Result | Red tests and failure lines |
|---|---|---|---|
| 1 | The control shows the UI's separator: `selected: {_strings.decimalSeparator == ',' ? comma : point}` | **red** | PS1 `page_panel_test.dart:144` (Expected `{comma}`, Actual `{point}`); PS2 `:174`; PS3 `:189` (Expected `{point}`, Actual `{comma}`) |
| 2 | The control is bound to a constant: `selected: const {DecimalSeparator.point}` | **red** | PS1 `:144`; PS2 `:174` (after the Undo, Expected `{comma}`, Actual `{point}`); PS3 `:198` (a tap on the already selected `1.5` fires nothing) |
| 3a | `onSelectionChanged` does nothing: `(s) => {}` | **red** | PS1 `:148` (Expected `point`, Actual `comma`); PS3 `:194` |
| 3b | It writes the wrong value: `page.copyWith(decimalSeparator: page.decimalSeparator)` | **red** | PS1 `:148`; PS3 `:194` |
| 3c | It writes the UI's separator: `_strings.decimalSeparator == ',' ? comma : point` | **red** | PS3 `:198` (Expected `point`, Actual `comma`) |
| 3d | It writes a constant `point` | **red** | PS3 `:194` (Expected `comma`, Actual `point`) |
| 4 | `RecordingFloorPlanStrings` forwards without recording: `=> inner.pageDecimalSeparator` | **red** | LK1 `leak_test.dart:178` and LK2 `leak_test.dart:253`, both with Expected `empty`, Actual `['Ondalık ayırıcı']` |
| extra | The caption as a literal, `const Text('Decimal separator')` | **red** | LK1 `:178` and LK2 `:253` (Actual `['Decimal separator']`); PS3 `page_panel_test.dart:186` (no `Dezimaltrennzeichen`) |

**Why PS3 has its taps.** Mutants 3c and 3d survived PS1 as first written: under an English UI, a tap on `1.5` writes `point` either way. That is why PS3 taps both ways under German.

**Mutant 4 matters.** The leak guard admits only the strings it has recorded, so an unrecorded caption is reported as a leak. That is the spec's V-13: if the getter only forwarded, the guards would flag a word that is correct.

## Leak and overflow coverage

**Confirmed: the Page panel is on screen in LK1 and LK2.**
- The shell's right column (`planner_shell.dart:983-1012`) is one `SingleChildScrollView` (`:990`). Its `Column` always ends with `PagePanel` (`:1009`). The column is laid out whole, so its `Text`s are in the tree that `visibleTexts` walks (`leak_test.dart:52-57`).
- LK1 (`leak_test.dart:106-181`) also taps the Page panel's `page-preset` (`:148`).
- LK2 (`:183-255`) shows the same shell.
- Mutant 4 proves it: both LK1 and LK2 saw `Ondalık ayırıcı`.
- Nothing in `leak_test.dart` was changed. Its `_planText` comment at `:47-48` is left for Task 4.

**Finding: the leak test does not run in German.** Spec P1 says LK2 covers the caption "in de and tr". In fact both LK1 and LK2 run only in Turkish (`RecordingFloorPlanStrings(const FloorPlanStringsTr())` at `leak_test.dart:110` and `:187`; `recordingApp` pins `Locale('tr')` at `:96`). No leak guard runs in German.
- I did not add a German leak run: that would widen the 14d leak test, which is beyond this task.
- In German, the caption is pinned by PS3 instead (`find.text('Dezimaltrennzeichen')`, `page_panel_test.dart:186`), and the mutant with a literal caption makes it red.
- Spec P1's wording could say "tr (LK), de (PS3)".

**Overflow.**
- OV-de and OV-tr (`overflow_test.dart:25-66`) and OV-H-en, OV-H-de and OV-H-tr (`:82-114`) all pump `FloorPlanView`, and so the shell's right column with the Page panel.
- Per P1, no overflow test was added. All of them pass in the full run.
- The segment labels `1.5` and `1,5` match the leak test's `_numeric` (`leak_test.dart:39`), so they are not leaks.

## Gates

These are the actual last lines of each run, after the final edit.

| Package | `flutter test` | `flutter analyze` | `dart format --output=none --set-exit-if-changed .` |
|---|---|---|---|
| `packages/jet_cad_floor_plan` | `06:32 +1367: All tests passed!` (exit 0) | `No issues found! (ran in 8.0s)` | `Formatted 235 files (0 changed)` (exit 0) |
| `apps/floor_planner` | `02:57 +207: All tests passed!` (exit 0) | `No issues found! (ran in 7.7s)` | `Formatted 46 files (0 changed)` (exit 0) |
| `apps/restaurant_demo` | `00:35 +35: All tests passed!` (exit 0) | `No issues found! (ran in 5.8s)` | `Formatted 4 files (0 changed)` (exit 0) |
| `packages/jet_cad_restaurant_symbols` | `00:04 +97: All tests passed!` (exit 0) | `No issues found! (ran in 5.4s)` | `Formatted 15 files (0 changed)` (exit 0) |

`tool/ci` was not run, because nothing it compiles or checks was touched (see "Other implementers" above).

The logs are in the session's scratchpad: `jet_cad_floor_plan.*.log`, `floor_planner.*.log`, `restaurant_demo.*.log` and `jet_cad_restaurant_symbols.*.log`.

## Findings

1. **Spec P1 overstates the leak coverage.** LK1 and LK2 cover the caption in Turkish only, and PS3 covers German (see above). Recorded here; nothing was changed for it.
2. **The tap test needed both directions.** A tap test under an English UI that only taps `1.5` cannot kill "write the UI's separator" or "write constant `point`". PS3's taps in both directions under German kill both. Recorded as a hardening of M-Q0-g.
3. **No existing test literal had to change.**
