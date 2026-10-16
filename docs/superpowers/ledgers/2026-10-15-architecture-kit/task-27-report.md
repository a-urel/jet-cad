# Task 27 report: integration of the panels and the words

Status: **DONE_WITH_CONCERNS**. Commit `cdd95213` test(integration): the panels and the words over the kit (3a Task 27).

The concern is one finding the controller has to rule on: WS9's premise cannot hold (IP-R8). The case is ported unchanged and marked `skip: true`. Details are below.

## Implementation summary

- **Kit tests (2 files)**
  - `test/room/decimal_separator_test.dart`: Q0-S1 and Q0-S2, with the fixture copied (`q0Walls`, `q0Page`, `q0Plan`, `separatorTo`).
  - `test/words/value_words_test.dart`: VW3's Room-notice line over `KitNamesWords`.
- **Integration support**
  - New: `q0_plan.dart`, `rooms_plan.dart`, and `recording_plan_strings.dart` (a copy that imports through the plan's barrel).
  - `units.dart` gains `diningTableTwo`.
  - Extended: `planEditorApp`, in the integration lib, and the rig's `pumpEditor` now take an optional `layerPanel` (default `true`). See deviation D1.
- **Integration tests**
  - `panels/`: `wall_section_test.dart`, `selection_page_test.dart`, `colour_row_test.dart`, `decimal_separator_test.dart`, `titles_test.dart`.
  - `l10n/`: `determinism_test.dart`, `leak_test.dart`, `overflow_test.dart`, `panel_words_test.dart`, `numbered_names_test.dart`, `locale_separator_test.dart`.

## Finding (for the controller): WS9 (ruling IP-R8)

The malformed plan (A's fill names B's outline), loaded through `architectureController(json: jsonEncode(j))`, is frozen and locked at open. It is not refused at the commit, as the case assumes. Output of a throwaway debug test (since deleted) that printed the controller's state after the pump:

```
frozen {1300}
locked {1300}
diags [hookFailed [architecture architecture.wall]: Bad state: fill 515 of 514 names A2A, which is not a child of the same object]
keys [property-panel, layer-picker, layer-picker-value, layers-panel, ...]   (no section-*, no property-thickness)
```

A frozen object shows no section (2a, binding). So WS9's first `tester.tap(thickness)` after `select([wa])` finds nothing. First red, before the skip:

```
The finder "Found 0 widgets with widget matching predicate: []" (used in a call to "tap()") could not find any matching widgets.
#3 main.<anonymous closure> (.../wall_section_test.dart:437:18)
```

The case is ported whole, with the same assertions and the IP-R8 mapping. It is marked `skip: true` (`testWidgets` takes a `bool`), with a comment naming this report. No assertion was changed. Ruling needed: keep it skipped, split it (the Task 18 precedent: "what the plan now does" plus the old intent on a live object), or drop it.

## Deviations (each a brief defect or a fixture adaptation; no assertion changed)

- **D1 `layerPanel`.**
  - The brief calls `pumpPlanEditor(..., layerPanel: false)`, which did not exist.
  - Added an optional `bool layerPanel = true` to `planEditorApp` (lib) and the rig's `pumpEditor` (`editor_rig.dart`). `selection_page_test` uses `pumpEditor(window: 1440x1080, centre: (7150, 3110), layerPanel: false)`. That is the rig's own pumpDraw camera (turned 0.35, 2 px/mm, non-reflecting), so no camera code was copied.
  - `boxPlanJson()` is the rig's existing `pagePlanJson(PageComponent(1:20 at (7000, 3000), snap off))` (R-P14).
- **D2 WS4, one more pump after `doc.commands.undo()`.**
  - With one pump, the dropdown still showed `left`: the DocChange arrives a microtask late (the notes' timing fact).
  - Red before the fix: `Expected: Set:[Justification.centre] Actual: Set:[Justification.left]` at `wall_section_test.dart:209`. Green with the second pump. The assertion is unchanged.
- **D3 DT1 and LK2, the library cell is scrolled into view.**
  - The gallery builds its cells lazily, and the kit's 41 furniture symbols come first. The fixture table's cell was not built at first (`Found 0 widgets with key [<'symbol-cell-fx.dining.table.two@1'>]`), then built but off-screen (`Offset(62.5, 951.6) is outside the bounds ... Size(1440.0, 900.0)`).
  - Added `scrollUntilVisible` plus `ensureVisible` on the `SymbolGallery`'s `Scrollable`. This is a fixture change under IP-R4.
- **D4 DT1's Select premise.**
  - The brief's premise "plan.select is the Flutter layer's SelectTool, unguarded" is wrong: `Expected: <Instance of 'SelectTool'> Actual: <Instance of 'GuardedTool'>`.
  - Mapped to `c.toolFor(c.activeTool.value), isA<SelectTool>()`, the inner tool, under R-P9's `invalid_use_of_internal_member` ignore. The assertion (`isA<SelectTool>()`) is unchanged.
- **D5 LK2's allowlist was vacuous as the brief wrote it.**
  - The kit's Turkish `text:architecture.dimension-value` is `{value}`, so the brief's `kitTemplates` held `^(.+)$`, which matches every text. Debug output: `^(.+)$ matches "A literal never moved": true`.
  - Fix: a template that is only placeholders is left out. Its filling is a number, which `_numeric` and `_planText` already allow.
  - Added a positive control (premise): `leaksOf({'A literal never moved'}, ...)` equals `['A literal never moved']`.
  - Evidence that the fix keeps the test's strength. The extra mutation below (a literal `'Symbol'` in place of `_strings.toolSymbol`) turns LK2 red with the committed file. With the brief's template list and no control, the same mutation stays green: `00:02 +1: All tests passed!`.
  - The pattern escaping on `Eksenler {degrees}° döndürülmüş` gives `^Eksenler (.+)° döndürülmüş$` (printed).
- **D6 LK2, the fixture kit's category.**
  - `Dining Room`, the fx kit's untranslated gallery header, leaked: `Expected: empty Actual: ['Dining Room']`.
  - Added `diningTableTwo.category` to `kitWords`, beside its `name` (IP-R4). Today's allowlist held the library's categories in the language, in the same way.
- **D7 `reportLocale` is @internal.**
  - The brief's LK2, NN3 and NS3 call it, and the brief said "no line needs R-P9's ignore". `flutter analyze` reported 4 `invalid_use_of_internal_member` warnings.
  - The three files start with `// ignore_for_file: invalid_use_of_internal_member` (R-P9) and say so in their headers.
- **D8 smaller mappings.**
  - WS: `clickWorld` → `room_plans.dart`'s `clickAt`, and `select` → `room_plans.dart`'s `select` (R-P14). `pumpPanel` → the rig's `pumpEditor(centre: lCorner, scale: 0.15, turn: 0.35)`. `kWallMaxThickness` was a local const. `plans.dart` is imported `hide textOf`, because the brief keeps today's `textOf(tester, finder)`.
  - Q0-E*: `pumpShell` → `pumpPlanEditor(locale: de|en)`.
  - DT1: `pumpFloorPlanView` → the rig's `pumpEditor` (same app shape: `planEditorApp`).

## TDD evidence

These are ports, run against existing lib code, so the RED evidence is the first-run failures above (WS4, WS9, DT1 ×3, LK2) and the mutations below. GREEN, final runs:

- Integration (`flutter test --enable-vmservice`): `00:49 +176 ~1: All tests passed!` (was +138 before the task; +38 new, 1 skipped, which is WS9).
- Kit (`flutter test`): `00:19 +620: All tests passed!` (was +617; +3: Q0-S1, Q0-S2, VW3).

## Gates

- **Integration:** `flutter analyze` → `No issues found!`; `dart format --output=none --set-exit-if-changed .` → exit 0.
- **Kit:** `flutter analyze` → `No issues found!`; format → exit 0; `dart pub publish --dry-run` → `Package has 0 warnings.`
- **Repo-wide checks:**
  - `dart run tool/ci/check_kit_deps.dart` → `kit dependencies: 2 package(s) checked, none names the plan library or another kit`.
  - `grep -rn "package:jet_cad_2d_plan/src\|package:jet_cad_2d_kit_architecture/src" packages/jet_cad_2d_integration` → no output (exit 1).
  - Non-ASCII: the per-literal counts for `Kalınlık Sağ Ölçek Izgara Bemaßung Küche Yatak odası Yemek odası m² —` are identical between the sources and the ports (1/1/1/1/1/1/1/1, m² 17, — 5). `1:12,5 · `, `×·%°`, `⌘ ⇧`, `ft²`, `Mutfak` and `Hol` were matched file against file.
  - `git status --short` after the commit: clean. No `analysis_options.yaml` touched.

## Mutations

Each was run on committed code and reverted with `git checkout --`; `git diff --quiet` returned 0 each time.

| Mutation | Test | Red line |
|---|---|---|
| M-IP-1 `opening_plan.dart` `title: openingTitle,` deleted | IP-title | `Expected: 'Door' Actual: 'Opening'` |
| M-IP-2 flip-swing `apply: _flipHinge` | IP-door-actions | `Expected: not SwingSide:<SwingSide.left> Actual: SwingSide:<SwingSide.left>` (the swing flipped) |
| M-IP-3 both `visible: _isDoor,` deleted | IP-door-actions | `Expected: no matching candidates Actual: ...Found 1 widget...` |
| M-IP-4 `wall_plan.dart` `_thickness(t) => t` (isWallThickness check gone) | WS3 | `Expected: '150' Actual: '0'` (reason `0`) |
| M-IP-5 `room_plan.dart` `colour:` target deleted | CP1 | `Expected: exactly one matching candidate Actual: ... Found 0 widgets with key [<'color-picker'>]` |
| M-IP-6 `dimension_tool.dart` notice value `l.text.replaceAll(',', '.')` (point instead of the page's separator) | Q0-E2 | `Expected: '345,7' Actual: '345.7'` (`DecimalSeparator.comma`) |
| M-IP-7 `words/tr.dart` room-occupied → `'Zaten bir oda'` | VW3 | `Expected: contains 'Mutfak' Actual: 'Zaten bir oda'` (`tr: Zaten bir oda`) |
| extra: `plan_property_panel.dart` `Text('Symbol', key: symbol-section)` | LK2 | `Expected: empty Actual: ['Symbol']`; green under the brief's allowlist (D5) |

M-IP-6 was run as its intended equivalent: the notice's value is `layoutDimension`'s text, so the mutation forces a point onto it.

## Ported-test accounting

| Old case (source) | New case (file) | Change class / ruling |
|---|---|---|
| WS1 (`selection_panel_test.dart`) | WS1 `panels/wall_section_test.dart` | ids (IP-R1: field/section/menuOf) |
| WS2 | WS2 | ids |
| WS3 | WS3 | ids; IP-R2 (WallTool settings line not ported, commented) |
| WS4 | WS4 | ids; `wall-left` → `choose`; D2 (one more pump) |
| WS5 | WS5 | ids; `onSelectionChanged` → `onChanged` (class 3) |
| WS6 | WS6 | ids; IP-R2 (`PlacementTool.isPending` → `activeTool.isMidShape`) |
| WS7 (Wall) | WS7 (Wall) | ids |
| WS8 | WS8 | ids; class 3 |
| WS9 | WS9-open (fix report 2; WS9-refused removed: it repeated WS3/WS11, and the old intent now lives in WS9-open's C/B steps) | Decided: premise impossible under C1.10's freeze at open (Task 18's rule) |
| WS10 ×2 | WS10 ×2 | ids; IP-R2 (two tool lines not ported, commented) |
| WS11 | WS11 | ids; local `kWallMaxThickness` |
| SE13, SE15, SE16 (2a `selection_page_test.dart`) | same, `panels/selection_page_test.dart` | fixture (kit box, editor, D1); Wall lines restored (D-20) |
| SE11, SE12 (2a `selection_panel_test.dart`) | same, `panels/selection_page_test.dart` | fixture; Wall lines restored (D-20); 2a's stay |
| fixture case (`color_picker_test.dart`) | fixture case `panels/colour_row_test.dart` | fixture (plan file) |
| CP1 | CP1 | `wall-section` → `settings-architecture.wall` (ids) |
| CP2 | CP2 | fixture; local `kRoomTintTransparency` |
| CP3 | CP3 | IP-R7 (`recolorCommand` lines not ported, commented) |
| CP4 | CP4 | capabilities → `PlanPermissions` (ids); `PlanStringsEn` |
| CP5 | CP5 | delegates (ids) |
| CP6b | CP6b | fixture |
| Q0-S1, Q0-S2 (`decimal_separator_test.dart`) | kit `test/room/decimal_separator_test.dart` | none (kit fixture names) |
| Q0-E1, Q0-E3 | `panels/decimal_separator_test.dart` | `room-area` → `property-area`, `dimension-value` → `property-value` (IP-R1) |
| Q0-E2, Q0-E3b | same file | IP-R3 (notice via `c.textOf(c.toolNotice.value!)`; two tool premises not ported, commented) |
| DT1 (`l10n/determinism_test.dart`) | `l10n/determinism_test.dart` | IP-R4, IP-R1; D3, D4 |
| LK2 (`l10n/leak_test.dart`) | `l10n/leak_test.dart` | IP-R4, IP-R5; D3, D5, D6, D7 |
| OV-H-en/de/tr (`l10n/overflow_test.dart`) | `l10n/overflow_test.dart` | IP-R4 (fx table labelled `1`; `c.units`) |
| PW1, PW2 (`l10n/panel_words_test.dart`) | `l10n/panel_words_test.dart` | IP-R1, IP-R6 |
| NN3 (`l10n/numbered_names_test.dart`) | `l10n/numbered_names_test.dart` | strings → locale (C1.9); D7 |
| VW3's Room line (`l10n/value_words_test.dart`) | kit `test/words/value_words_test.dart` | `KitNamesWords.text` |
| NS3 (`host/new_plan_separator_test.dart`) via 2a's port | `l10n/locale_separator_test.dart` | 2a's `reportLocale` form; room line restored; D7 |
| (new) | IP-title, IP-door-actions `panels/titles_test.dart` | new (D-46) |

## Files changed

- `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/architecture-kit/packages/jet_cad_2d_integration/lib/jet_cad_2d_integration.dart` (`layerPanel`)
- `.../jet_cad_2d_integration/test/support/editor_rig.dart` (`layerPanel`), `units.dart`, `q0_plan.dart`, `rooms_plan.dart`, `recording_plan_strings.dart`
- `.../jet_cad_2d_integration/test/panels/{wall_section,selection_page,colour_row,decimal_separator,titles}_test.dart`
- `.../jet_cad_2d_integration/test/l10n/{determinism,leak,overflow,panel_words,numbered_names,locale_separator}_test.dart`
- `.../jet_cad_2d_kit_architecture/test/room/decimal_separator_test.dart`, `.../test/words/value_words_test.dart`

## Concerns

1. WS9: the IP-R8 finding, which needs a ruling (the case is skipped).
2. The brief's IP-R5 template rule was vacuous (D5). It is fixed, with evidence. The controller may want the ruling text amended.
3. `planEditorApp` gained an optional parameter. This is a Shared-interfaces name; the change is backward compatible.

## Fix report (controller rulings after review)

Commit: `a85e5f7e` test(integration): WS9 split under the freeze at open (3a Task 27 fix), on top of `cdd95213`.

The skipped WS9 is gone. In its place are two cases, each with the header "Decided: premise impossible under C1.10's freeze at open (Task 18's rule)". The brief's malformed plan is now a top-level `malformedPlanJson()` in `wall_section_test.dart`, and the file starts with R-P9's ignore because it reads `c.frozen`.

**WS9-open** checks, over the malformed plan:
- `c.frozen` contains `wa` (1300).
- `c.diagnostics` contains `(KitDiagnosticCode.hookFailed, 'architecture', 'architecture.wall')`. That is the code, kitId and subject observed.
- Selecting A shows no Wall section (`sectionFinder` and `field('thickness')` find nothing).
- A raw `SetComponentCommand<WallParams>(wa, thickness 250)` throws `PlanLocked`, with `canon` and A's params unchanged and no exception taken.

**Not kept: today's last lines on C** ("C, no neighbour of A's, is sound: its edit lands", 120, and undo depth 1). They do not hold, and this may be a further finding for the controller.

- In the malformed plan the panel commit of C's thickness is refused: lock hint `true`, depth 0, C still 150. A throwaway probe gave this output:

  ```
  locks {1300} frozen {1300}
  C: PlanLocked: the edit would change a locked object
  B: PlanLocked: the edit would change a locked object
  box: applied, depth 1
  ```

- In the well-formed plan, C's edit leaves B's children unchanged (probe: `B children changed by C edit: false`). So the refusal does not come from C regenerating B.
- My unverified reading: a wall edit regenerates the frozen wall A, through the shared wall bands, and that would rewrite A's broken fill. If C1.10 means a sound wall away from the frozen one must stay editable, this is a plan or kit defect, and it is not pinned by any test.

**WS9-refused** runs on a live wall A of the well-formed plan.
- For `0`, `-40` and `nextUp(kWallMaxThickness)`, each by Enter and then by focus loss: no exception, the field back to `200`, A's params, `enc(doc)` and undo depth 0 all unchanged.
- Then `250` lands: `pa.copyWith(thickness: 250)`, depth 1, and the field shows `250`.
- Mutation **M-WS9-r**: `wall_plan.dart`'s `_thickness` with its refusal removed (`=> t`). Red line: `Expected: '200' Actual: '0'` (reason `reverted: 0`). Reverted with `git checkout --`; `git diff --quiet` returned 0.

**Gates**
- Integration: `flutter test --enable-vmservice` gives `00:46 +178: All tests passed!`, with 0 skipped (`grep -rn "skip:" test` finds nothing). `flutter analyze` gives `No issues found!`. The format check exits 0.
- `check_kit_deps` gives `kit dependencies: 2 package(s) checked, none names the plan library or another kit`.
- `git status --short` is clean.

## Fix report 2 (review: two Important findings, folded minors)

Commit: `524cc375` test(integration): WS9's refusal on the locked walls; fx words (3a Task 27 fix 2), on top of `a85e5f7e`.

**1. WS9's old intent now runs on the document-level refusal.**
- The controller's root cause:
  - A's fill names B's outline.
  - B regenerating without the frozen A (C1.5) would rewrite that fill, which the locked A owns.
  - C's edit reaches B through the bands.
  - The lock set is {A} alone. This is intended, not a defect.
- The new WS9-open cites that cause in its header and asserts:
  - `c.frozen` contains A, the lock set is exactly {A} (`c.locked.value == {wa}`), and the hookFailed diagnostic (`architecture`, `architecture.wall`) is present.
  - A shows no section, and a raw edit of A throws `PlanLocked` with `canon` unchanged.
  - Through the panel, C's thickness is refused by Enter and by focus loss. The field reverts to `150`, C's params, `canon` and the undo depth are unchanged, and nothing escapes.
  - C's justification toggle is refused: the row still shows `{right}`, and nothing escapes.
  - B's thickness is refused by Enter: the field reverts to `115`, with B's params and `canon` unchanged.
  - Control: the box's width lands (`BoxParams(150, 70)`, depth 1).
- WS9-refused is removed. It repeated WS3/WS11 (an `ArgumentError` thrown before the commit). The accounting row is updated.
- Mutations, run on committed code and reverted (`git diff --quiet` returned 0 each time):
  - **(a)** In `jet_cad_2d_plan/lib/src/kits/locks.dart`, `_check` skips every covers hit: `if (!locks.covers(target, h) || h.value >= 0) continue;`. WS9-open went red: `Expected: '150' Actual: '250'` (C's edit landed).
  - **(b)** In `plan_property_panel.dart`, `_commit` no longer reverts the field: its `_show(f)` is deleted. This is an equivalent of "no revert when `execute` answers false" and also drops the revert on success. WS9-open went red: `Expected: '150' Actual: '250'` (reason `reverted`).

**2. IP-R4: the fixture kit now has words.**
- `fxKit` carries `fxNames`. German and Turkish words for `symbol:fx.dining.table.two` and `category:fx/Dining Room` are today's furniture words (`Quadratischer Esstisch, 2 Plätze` / `Esszimmer`; `Kare yemek masası, 2 kişilik` / `Yemek odası`). English stays the library's stored name.
- DT1 gains two checks:
  - A premise that the placed table's `symbol-name` shows the UI language's name (English, or `kTurkishTable` in the Turkish run).
  - `expect(tr, isNot(contains(kTurkishTable)))`: the stored name is the library's, never the one shown.
- LK2's `kitWords` now take `fxNames.words['tr']` instead of the English name and category.
- Both pass. Checks run:
  - **Mutant, the placement stores the Turkish name.** In `plan_symbol_tool.dart`, `_place` places a copy of the entry whose `SymbolComponent` name is `symbol.names.symbolName('tr', ...)`. DT1 went red at the shown-name premise: `Expected: 'Square dining table, 2 seats' Actual: 'Kare yemek masası, 2 kişilik'`. With that premise and the English-name premise also removed from the test, the new stored-name line went red on its own: `Expected: not contains 'Kare yemek masası, 2 kişilik'` (`the stored name is the library's, never the one shown`). Both files were reverted.
  - **LK2 with the Turkish table word removed from `fxNames`.** LK2 went red: `Expected: empty Actual: ['Square dining table, 2 seats']`. Reverted.

**3. Minors.**
- `selection_page_test.dart` and `decimal_separator_test.dart` use `room_plans.dart`'s `select`. The local copies are gone, and the Q0 calls pass a one-element list.
- `determinism_test.dart` takes a line-level `// ignore: invalid_use_of_internal_member` on the `toolFor` read; the file-wide ignore is removed.

**Gates**
- Integration: `flutter test --enable-vmservice` gives `00:46 +177: All tests passed!`, with 0 skipped (`grep -rn "skip:" test` is empty). `flutter analyze` gives `No issues found!`. The format check exits 0.
- Plan, untouched: `flutter test --enable-vmservice` gives `01:57 +1549: All tests passed!`.
- `check_kit_deps` gives `kit dependencies: 2 package(s) checked, none names the plan library or another kit`.
- `git status --short` is clean.
