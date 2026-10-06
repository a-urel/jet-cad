# Plan 14d-1 — three languages (en, de, tr)

**Spec:** [2026-10-06-pos-readiness-design.md](../specs/2026-10-06-pos-readiness-design.md),
revision 2, approved by the human (2026-10-06, Q0 yes: the plan's own
text keeps `.`; L13, L14, M-14d-d, M-14d-e are out). Slice 14d-1: L1–L12,
L15–L18 as revision 2 amends them (L1, L2, L5, L6, L11, L15; I-3; V-4,
V-9–V-13, V-16, V-17, V-20), mutants M-14d-a, -b, -c, -f, -g, -h, -i, -j,
-k, -s, -t. **Started** on the human's *"evet, 14d-1'e başla"*
(2026-10-06). **Branch:** `claude/exciting-pasteur-9m22jv`, after 14d-2
(`6e9c4b9`, not merged).

## Global constraints

- `CLAUDE.md` non-negotiables; **no schema change**; the two allocation
  invariants and the goldens untouched; no string lookup on the frame path.
- **English stays byte-identical on screen**: every `FloorPlanStringsEn`
  value is today's literal, so every existing test that finds a widget by
  its English text keeps passing unchanged (the tests' `MaterialApp`
  resolves to `en_US`).
- **A document's bytes never depend on the UI language** (I-3 amended):
  only L7's stored names do; placement copies the library's English
  `entry.name`.
- The engine stays free of any language (L6): it returns values; the
  planner words them.
- Every task ends with the planner, restaurant symbols, app and demo
  gates green; a task that touches the engine or the render package runs
  theirs too.
- Turkish and German text is the controller's (R-3); the glossary L18 is
  binding.

## Tasks

### Task 1 — the machinery (L1, L2, L11, L12, L15)

`lib/src/l10n/`: `strings.dart` (abstract `FloorPlanStrings`, a getter
per fixed string, a method per interpolated one; `languageCode`),
`strings_en.dart`, `strings_de.dart`, `strings_tr.dart`;
`localizations.dart` (`FloorPlanLocalizations.delegate`,
`FloorPlanStrings.of(context)`: the delegate's instance, else the built-in
language of `Localizations.localeOf`, else English;
`floorPlanSupportedLocales`; `floorPlanLocalizationsDelegates` with
Flutter's three, so the planner depends on `flutter_localizations`);
`number_text.dart` (`formatPanelNumber(v, strings)` — today's
`panelNumberText` with the language's separator, no grouping —
and `parsePanelNumber(text, strings)` — its separator, or the other once
when not followed by exactly three digits, V-12); `search_fold.dart`
(L11 amended: `İ`/`I` → `i` before lower-casing, `ı`, `äöüß ğşç âîû`).
`test/l10n/recording_strings.dart` (`RecordingFloorPlanStrings
implements FloorPlanStrings`, forwarding and recording). The barrel
exports `FloorPlanStrings`, the three classes, `FloorPlanLocalizations`,
`floorPlanSupportedLocales`, `floorPlanLocalizationsDelegates`.
Tests: M-14d-b (three set-ups of V-4), M-14d-f, M-14d-j.

### Task 2 — values instead of sentences (L6, L5)

Engine: `LayerNameProblem` (`empty`, `edgeSpace`, `tooLong(max)`,
`badCharacter(c)`, `duplicate(name)`) from `layerNameError`, with an
English `toString` for its own `ArgumentError`s. Planner:
`NumberingWarning` (`DuplicateNumber(number, count)`,
`Unnumbered(seats, symbolKey)`) on `numberingWarnings` (the host API's
breaking change; the demo follows); the table number's problem as a
value; the Room tool's notice as `RoomOccupied(name)`. Each worded by
`FloorPlanStrings` (M-14d-t).

### Task 3 — the shell (F-2, F-3, L4, L5)

`planner_shell.dart` (palette labels and the status line from the palette
map; the Symbol tool's own label; the selection count's plural; the tabs;
OSNAP), `shell_commands.dart` (`Ctrl` / `Strg`), `tool_palette.dart`,
`export_dialog.dart`, `floor_plan_view.dart`, `service_view.dart`,
`symbol_panel.dart` (its raw `'$error'` becomes a worded failure, the
exception reported, V-17). Labels are read at build (L3).

### Task 4 — the panels (F-2, L12, L15)

`selection_panel.dart`, `page_panel.dart`, `layers/` (panel, row,
picker): every literal; every number field through `number_text.dart`;
the keyboard as today. The Area and Value rows keep the stored text.

### Task 5 — stored names (L7)

`Room n` / `Raum n` / `Oda n` and `Layer n` / `Ebene n` / `Katman n`,
the lowest free `n` counted over all three patterns (M-14d-k); the
sample plan's room names in the language it is generated in.

### Task 6 — symbols (L8–L10)

`SymbolLibrarySource.names` (`SymbolNames`: per language, key → name and
English category → name); the furniture catalog's de/tr names (41, 6
categories) and the restaurant package's (69, 6) in
`lib/src/names.dart`; the palette, the search (L11, either language) and
the Symbol section show by key, falling back to the stored name
(M-14d-h); the render package's `GalleryCategory` gains a `key` beside
its shown name, the collapsed set keyed by it (L10). Tests M-14d-i,
-j, -h, the collapsed set across a language switch (M-14d-s).

### Task 7 — the apps (L16, L17)

`apps/floor_planner`: `flutter_localizations`, the delegates and
`floorPlanSupportedLocales`; its own strings class (document host, files,
exit guard). `apps/restaurant_demo`: the same, an **EN / DE / TR**
switch setting `MaterialApp.locale`, its words and log lines in the three
languages. The 656 px sweep and a `Row` label in `de` and `tr`
(M-14d-c).

### Task 8 — the guards and the exit

The leak test (M-14d-a, `RecordingFloorPlanStrings` over Turkish, every
panel, dialog and menu opened), the determinism test (M-14d-g, from a
loaded plan), the live switch (M-14d-s); every gate, both web builds, a
Chromium smoke in Turkish and German; the results note; STATUS; the
roadmap.

## Exit gate

All of Task 8 green, every named mutant red; the human's look owed
(Turkish read by the human; German owed a native speaker, R-3).
