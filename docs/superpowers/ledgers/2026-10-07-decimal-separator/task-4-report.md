# Task 4 report: new plans (N1, N2, M-Q0-e, M-Q0-f)

Work is on branch `claude/exciting-pasteur-9m22jv`, working tree on HEAD `7e3632f`. HEAD moved from `0c7bfca` to `7e3632f` during the task through the orchestrator's Task 2/3 review commits. Those commits touch only the spec's P1 text, `page_panel_test.dart` and `decimal_separator_test.dart`, none of which this task edits.

Nothing is committed, staged or pushed. No `analysis_options.yaml` changed. `git status` lists only the files below.

## Changes

### Library (`packages/jet_cad_floor_plan`)

- **New file `lib/src/l10n/document_separator.dart`:** `documentSeparatorFor(FloorPlanStrings)` returns `comma` iff `strings.decimalSeparator == ','`.
  - It is exported from `lib/editor.dart`.
  - It is **not** exported from the host barrel, so B1 is unchanged and green.
- **`lib/src/new_document.dart`:**
  - `defaultPage({DecimalSeparator decimalSeparator = point})`
  - `newDocument(measurer, {DecimalSeparator decimalSeparator = point})`
- **`lib/src/startup_plan.dart`:**
  - `startupPlan` takes no new parameter. Its page is `startupPage(doc.extents, decimalSeparator: documentSeparatorFor(strings))`.
  - The page is set at the same place as before: after the walls, openings and separator, and before the rooms and dimensions. The rooms' and dimensions' text is therefore generated with it.
  - `startupPage` gained `{decimalSeparator = point}`.
  - The default `strings` is English, so `startupPlan(measurer)` is still `point`. No existing literal changed.
- **`lib/src/host/floor_plan_view.dart`:**
  - New `didChangeDependencies` (`:149-153`) calls `widget.controller.reportLanguage(FloorPlanStrings.of(context))`.
  - `didUpdateWidget` makes the same call on a controller swap (`:161`).
- **`lib/src/host/floor_plan_controller.dart`** (the settling):
  - `_reported` (`:393`) holds the separator of the last reported language. `_unsettledAt` (`:397`) holds the design's state id when it was made with no language known, and is null otherwise.
  - `_untouched` (`:405`) is `stateId == _unsettledAt && !canRedo`. It is read synchronously, so an edit whose change event has not arrived yet still counts as a touch. An edit that was then undone also counts, because it leaves a Redo.
  - `@internal reportLanguage(strings)` (`:422`) works in this order:
    1. It stores the separator.
    2. If the design is unsettled and untouched, it marks it settled.
    3. If the page's separator differs, it executes one `SetComponentCommand<PageComponent>` (`page.copyWith(decimalSeparator:)`), then `clearHistory()`, then `_savedState = stateId`.
  - The constructor without `json` and `newPlan()` with nothing reported create an unsettled plan:
    - `unsettled: json == null` (`:127`, `:146`);
    - `_replaceDesign(..., unsettled:)` (`:602`).
  - `newPlan()` creates with `reported ?? point`, settled at once when a language is known.
  - `designJson()` clears `_unsettledAt` (`:548`).
  - `load` passes through `_replaceDesign` with `unsettled: false`, so a loaded plan is never settled (N2).
  - Doc comments were added to the class, the constructor, `newPlan` and `designJson`. There is no new public API.

### Floor planner (`apps/floor_planner`)

- **`lib/document_host.dart`:**
  - New top-level `launchDecimalSeparator()` (`:50`):

    ```dart
    documentSeparatorFor(FloorPlanStrings.forLocale(basicLocaleListResolution(
        WidgetsBinding.instance.platformDispatcher.locales,
        floorPlanSupportedLocales)))
    ```

  - `DocumentSession.untitled({required DecimalSeparator decimalSeparator})`. Its only caller is `main.dart`.
  - `newFlow` reads `documentSeparatorFor(FloorPlanStrings.of(context))` before `_mayDiscard()`'s await (V-17, `:448`).
  - Open sample is unchanged: it already passes `strings`.
- **`lib/main.dart:109`:** `DocumentSession.untitled(decimalSeparator: launchDecimalSeparator())`.
- **Checked:** the app's `MaterialApp` has no `locale:`, no `localeResolutionCallback` and no `localeListResolutionCallback`. Flutter's `LocalizationsResolver._resolveLocales` (`widgets/localizations.dart:890-909`) then falls back to `basicLocaleListResolution` over `platformDispatcher.locales`, which is the resolution reproduced here.

### Demo

No code change.

### Leak test

`leak_test.dart`'s `_planText` comment now reads: stored, with the page's separator, which a new plan takes from the UI's language (N1); LK2's sample is built in Turkish, so it prints `,`.

- Checked by a temporary print, since reverted: LK2 now shows the areas `22,00 m², 8,45 m², 8,41 m², 13,97 m², 13,37 m², 21,90 m², 23,04 m²`.
- `_planText` (`[-\d.,\s]+ ?(m²|…)`) matches all of them, and LK2 stays green.

## Settling: mechanism and decisions

**Why execute, clear the history and re-baseline**, rather than rebuild the plan through `newDocument`:
- The document object, its `_Plan`, its selection and its subscriptions stay as they are.
- `_placeNominally()`, `_fitOnStart` and R-13's measurement are not involved. The page's geometry is unchanged, so the camera fit is still right.
- `stateId` moves to a fresh id, so `_savedState` is re-baselined to it.
- Untouched implies clean: there was no `designJson`, so `_encodedState` is null and `_savedState` is the creation id.

**No race with R-13 or the fit.** The report runs in `FloorPlanView.didChangeDependencies`. That is before the view's first build, so before `PlannerShell` or `ServiceView` is built over the document. The shell is built over the already settled page: NS1 checks this by reading the Page panel's control, which shows `{comma}`.

**No notification during the build.** `reportLanguage` calls neither `notifyListeners`, nor sets `_revision`, nor touches any `ValueNotifier`:
- `_dirty` and `_canUndo` are unchanged.
- The command's `DocChange` reaches the controller's async listener a microtask later. That listener re-runs `_refreshFlags` (still clean, no undo) and, in the design mode, does `revision++`, which is only a redraw.
- In the demo, that `revision` listener calls `setState` after the frame. That is legal, and DQ1 passes with no exception.

**What clears "untouched", and what does not.**

| Clears it | Does not clear it |
|---|---|
| any command on the design: `stateId` moves, or a Redo remains | `markSaved()`: no bytes were handed out, and the re-baseline keeps it clean |
| `designJson()`: the host may store those bytes | `serviceLayoutJson()`: it reads only table positions |
| `load()`: the plan is replaced and never unsettled | `setMode`, `resetLayout`, `restoreServiceLayout`: they read the design only to copy it into the service copy |

The `setMode` family is not clearing because spec N1 says a service copy taken before the settling is not changed, and "is a copy of an empty plan and holds no text". So:
- the design settles after a `setMode(selection)`;
- the copy keeps `point`;
- `serviceEdited` stays false, because `serviceLayoutOf` compares tables only;
- nothing goes out on `serviceLayoutChanges`.

NS5 pins this. `restoreServiceLayout` never changes the design.

**One behaviour to note, not a defect.** When `load` happens after the view has already reported, as in the demo's Revert of a stored plan, a later report could not settle the loaded plan even under mutant M9: no new `didChangeDependencies` happens. That is why M9 survives the demo tests and is killed by NS3, NS1 and DT1 instead (see below).

## Tests

All are non-degenerate per the fixture rule: the UI language differs from the page's separator wherever it could leak in.

### `packages/jet_cad_floor_plan/test/host/new_plan_separator_test.dart` (new)

- **NS1** (`:71`). A `FloorPlanController()` shown in Turkish:
  - it is settled in place, as the same document: `comma`;
  - the Page panel shows `{comma}`;
  - undoDepth is 0, there is no Redo, `canUndo` is false and `dirty` is false, both before and after the microtask;
  - `serviceLayoutChanges` fired 0 times;
  - an edit then makes it dirty, and its Undo makes it clean again (the save point moved).
  
  Then the app switches to English: the plan stays `comma` (N2). `newPlan()` gives `point`, and that plan stays `point` when the view turns Turkish again, because it was settled when made. `newPlan()` under Turkish gives `comma`, with no step, clean, and nothing fired.
- **NS2** (`:141`). The same `FloorPlanView` state, asserted identical, is handed a second, fresh controller under German. The second plan is `comma`, with no step and clean.
- **NS3** (`:166`). The fixture plan (`q0Plan`: cm, 1:20, origin (−4180.5, 2645.25), a turned room of `12.37 m²` and a dimension of `345.7`), encoded as `point`:
  - by `FloorPlanController(json:)` under Turkish: it stays `point`, the area reads `12.37 m²`, and `designJson()` equals the input bytes;
  - by `load(json)` before any view, under Turkish: the same.
- **NS4** (`:193`). Under Turkish, each of these stays `point`:
  - `designJson()` read before any view, with `markSaved()`: the bytes stay equal and it is clean;
  - a layer added before any view: undoDepth is 1, the edit's step only;
  - a layer added and then undone: its Redo is kept.
- **NS5** (`:228`). `setMode(selection)` before any view, then shown under Turkish:
  - the service copy stays `point`;
  - no `serviceLayoutChanges`, not dirty, not `serviceEdited`;
  - `designJson()` is `comma`;
  - back in the design mode, the design is `comma` with undoDepth 0, `canUndo` false and clean.

### `apps/floor_planner/test/document_separator_test.dart` (new)

- **FS1** (`:63`), three tests, one fresh app state each, with `localesTestValue` set before `pumpWidget` and cleared in the teardown:

  | System locales | Language under `DocumentHost` | Launch plan |
  |---|---|---|
  | `[de_DE]` | `de` | `comma` |
  | `[fr_FR, de_DE]` | `de` | `comma` |
  | `[fr_FR]` | `en` | `point` |

  Each case also asserts `== documentSeparatorFor(FloorPlanStrings.of(<DocumentHost element>))`, undoDepth 0 and clean.
- **FS2** (`:80`). Launch under en_US is `point`. The system turns de_DE, and the premise checks that the host's language is `de`:
  - the launch plan stays `point` (N2);
  - the toolbar's New gives `comma`, with undoDepth 0 and clean.
  
  The system turns en_GB: New gives `point`.
- **FS3** (`:108`). Under tr_TR (switched after launch), the toolbar's Open sample gives `comma`.
  - The seven area texts, read from the stored TEXT entities, are exactly `22,00 m², 8,45 m², 8,41 m², 13,97 m², 13,37 m², 21,90 m², 23,04 m²`.
  - The five dimension values are `14,00, 9,00, 4,69, 4,38, 3,58`.

### `apps/restaurant_demo/test/demo_test.dart`

Two tests added at the end.
- **DQ1** (`:1162`). `RestaurantDemo(locale: Locale('de'))` with no plans:
  - Salon's plan is `comma`, not dirty, with no undo and undoDepth 0;
  - no `Salon:` log line, so no dirty line;
  - Save is disabled.
  
  After switching to Teras, Teras is `comma` and clean.
- **DQ2** (`:1193`). Under English, Salon (empty) is `point`.
  - The `lang-de` toggle leaves it `point` (N2).
  - Revert gives `newPlan`, which is `comma`, clean and with no undo.
  - Teras has a stored point `salonPlan()`; Revert reloads it, and it stays `point`.

### `packages/jet_cad_floor_plan/test/l10n/determinism_test.dart` (DT1, M-Q0-f)

`editedIn` now also does two more edits, in both languages.

**A room drawn.**
1. Escape leaves the palette's place tool. The premise checks that the tool is `SelectTool`.
2. The Kitchen (`roomsOf(doc)[3]`, premise: named `Kitchen`) is selected and deleted with the Delete key. The premise checks that it is gone.
3. M, then a click at (19000.37, 10000.61), then Escape.
4. The new room's area premise is `13.97 m²`. It is then named `Ofis` through `room-name`, because the numbered name is the language's (L7).

**A dimension moved.**
1. F3 turns object snap off.
2. The Bath diagonal, premise `3.58`, is clicked a quarter of the way along. The premise checks that it is selected.
3. Its body is dragged by world (−612.5, 437.5) through a mouse gesture.
4. The value becomes exactly `4.68`, with grid snap on.

The final checks add premises that `en` contains `"Ofis"`, `13.97 m²` and `"4.68"`, and no `"3.58"`. Then `tr == en`.

Values were read from runs, not invented: the areas and the `4.68` came from temporary prints, since reverted.

## Named mutants

Each mutant was applied by a script (in the scratchpad, `mut/run.py`), run against the listed test files, and restored by a byte copy of the good file.

After the whole run, `git diff | sha256sum`, the status hash and the hashes of the untracked files equal the pre-run values (`RESTORED`).

| # | Mutant | Result | Red (failing line) |
|---|---|---|---|
| M1 | New always `point` (`newDocument(measurer)` in `newFlow`) | **red** | FS2 (`document_separator_test.dart:95`) |
| M2 | `documentSeparatorFor` always `point` | **red** | NS1 `:89`, NS2 `:151`, NS5 `:247`; FS1 `:72`, FS2 `:95`, FS3 `:116`; DQ1 `demo_test.dart:1175`, DQ2 `:1210` |
| M3a | launch reads `platformDispatcher.locales.first` | **red** | FS1 `[fr_FR, de_DE]` (`:72`) |
| M3b | launch reads `platformDispatcher.locale` | **red** | FS1 (`:72`) |
| M4 | the view not reporting (`didChangeDependencies` report removed) | **red** | NS1, NS2, NS5; DQ1, DQ2 |
| M5 | the view not reporting on a controller swap | **red** | NS2 (`new_plan_separator_test.dart:159`) |
| M6a | `newPlan()` ignores the last language: always `point`, settled | **red** | NS1 `:132`; DQ2 `:1210` |
| M6b | `newPlan()` ignores the last language: always `point`, unsettled | **red** | NS1 `:124` (settled later in Turkish); DQ2 `:1210` |
| M7a | settling a touched plan (`_untouched` → `true`) | **red** | NS4 `:211` |
| M7b | `!canRedo` dropped (an undone edit counts as untouched) | **red** | NS4 `:222` |
| M7c | `designJson()` does not clear "untouched" | **red** | NS4 `:203` |
| M8a | settling leaves history (`clearHistory` removed) | **red** | NS1 `:92`, NS2 `:160`, NS5 `:251`; DQ1 `:1177` |
| M8b | settling does not move the save point (dirty) | **red** | NS1 `:95`, NS2 `:161`, NS5 `:245`; DQ1 `:1176` |
| M9 | settling a loaded plan (constructor and `_replaceDesign` always unsettled) | **red** in the planner: DT1 `determinism_test.dart:158` (the Turkish run's area reads `13,97 m²`), NS1 `:124`, NS3 `:178`. **Survives** the demo tests (DQ1/DQ2 green): DQ2's reload happens after the view has reported, and no later report comes (see the note above) | |
| M10 (M-Q0-f) | the shell sets the page's separator from the UI on open (in `PlannerShell.didChangeDependencies`, executes `page.copyWith(decimalSeparator: <UI's>)`) | **red** | DT1 `:158` (Expected `13.97 m²`, Actual `13,97 m²`) |
| M11 (extra) | Open sample ignores the strings (`startupPage(doc.extents)`) | **red** | FS3 `:116` |

## Gates

Actual last lines. Each test suite was run after the final code and test edits and after `dart format`. The mutation run came after them and restored the tree byte for byte, as hashed above.

| Package | `flutter test` | `flutter analyze` | `dart format --output=none --set-exit-if-changed .` |
|---|---|---|---|
| `packages/jet_cad_floor_plan` | `07:12 +1374: All tests passed!` (exit 0) | `No issues found! (ran in 5.9s)` | `Formatted 237 files (0 changed)`, exit 0 |
| `apps/floor_planner` | `03:35 +212: All tests passed!` (exit 0) | `No issues found! (ran in 6.2s)` | `Formatted 47 files (0 changed)`, exit 0 |
| `apps/restaurant_demo` | `00:40 +37: All tests passed!` (exit 0) | `No issues found! (ran in 6.2s)` | `Formatted 4 files (0 changed)`, exit 0 |
| `packages/jet_cad_restaurant_symbols` | `00:04 +97: All tests passed!` (exit 0) | `No issues found! (ran in 5.0s)` | `Formatted 15 files (0 changed)`, exit 0 |
| `tool/ci` (`dart test`) | `00:04 +32: All tests passed!` | | |

- B1 (`test/host/barrel_test.dart`) is unchanged and green in the planner suite.
- `jet_cad_2d_flutter` was not run: no shared helper was touched.
- Logs are in the scratchpad: `planner.test.log`, `fp.test.log`, `demo.test.log`, `sym.test.log`, and `mut/*.log` with `mut/run.out`.

## Findings

1. **No existing test literal had to change.** The defaults stay `point` everywhere a caller passes nothing: `newDocument`, `startupPlan`'s English default, and `PlannerShell`'s fallback.
2. **The settling cannot race R-13 or the fit.** It happens in the view's `didChangeDependencies`, before any shell or canvas is built over the plan, and it changes no page geometry. No spec deviation was needed.
3. **"Untouched" is checked synchronously** (`stateId` plus `canRedo`), not by the asynchronous change stream. An edit made in the same synchronous step as the report therefore still counts. M7b shows that the `canRedo` half matters.
4. **`setMode`, `resetLayout`, `restoreServiceLayout`, `serviceLayoutJson` and `markSaved` do not clear "untouched".** This is a deliberate reading of N1's "a service copy taken before … is not changed". NS5 pins it.
5. **M9 is not killable through the demo's Revert path.** The view does not report again after a `load`, so even a mutant that marked loaded plans unsettled would leave them alone there. NS3 (planner) and DT1 kill it.
6. **For Task 5's docs:**
   - The host guide's controller text needs the sentence on the empty plan's language (D2).
   - The CHANGELOG needs N1 (D1).
   - `DocumentSession.untitled` now requires `decimalSeparator`. It is app-internal, not host API.
