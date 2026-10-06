# Plan 14d-1 results — three languages (en, de, tr)

**Branch:** `claude/exciting-pasteur-9m22jv`, after 14d-2 (`6e9c4b9`).
**Spec:** [2026-10-06-pos-readiness-design.md](../specs/2026-10-06-pos-readiness-design.md),
revision 2 (L1–L12, L15–L18 as amended; Q0: the plan's own text keeps
`.`, so L13, L14, M-14d-d and M-14d-e are out). **Plan:**
[2026-10-06-three-languages.md](../plans/2026-10-06-three-languages.md).
**Approval:** the human's *"evet, 14d-1'e başla"* (2026-10-06). **Not
merged.**

The planner, both symbol libraries and both apps speak English, German
and Turkish. A host lists `floorPlanSupportedLocales` and
`floorPlanLocalizationsDelegates` in its `MaterialApp`; the planner
follows the resolved locale, English for any other. Every word comes
from `FloorPlanStrings` (one hand-written class per language, so the
compiler refuses a missing word); the engine and the planner hand out
values (`LayerNameProblem`, `TableNumberProblem`, `NumberingWarning`,
`RoomOccupied`) that the strings word. Panel numbers show and read with
the language's separator, never grouped, and accept the other separator
once when it cannot be a grouping (an English iPad keypad in a German
UI). New rooms and layers are named in the language of the moment,
their number counted over every language. Symbols show by key in the
language (110 entries, 12 categories, German and Turkish), search meets
either language through a fold (`kose` finds `Köşe loca`), and the
document keeps the library's English. The demo has an EN / DE / TR
switch; the floor planner follows the system.

## Commits

| Task | Commit |
|---|---|
| Plan | `576ccec` |
| 1 The machinery: strings, lookup, delegates, panel numbers, the fold, the recording language | `22fca6c` |
| 2 Values instead of sentences | `3319957` |
| 3 The shell | `1cf2e84` |
| 4 The panels | `7ad872a` |
| 5 Stored names | `7d92635` |
| 6 Symbol names | `e5b66ea` |
| 7 The apps | `b482b2f` |
| 8 The guards (leak, determinism) | `7560148` |
| Exit (this note, STATUS, roadmap; the demo's mode word) | this commit |

**Process, stated plainly:** implemented by the controller, without a
fresh implementer or a per-task reviewer, as 14d-2; every mutant below
was fired by the controller. The code has had no independent review.
**The German and Turkish text is the controller's** (R-3): Turkish is
owed the human's read, German a native speaker's.

## Gates (Linux container, Flutter 3.47.6 / Dart 3.13.5)

| Package | Result |
|---|---|
| engine `packages/jet_cad_2d` | **1,242 passed** (+1: the layer-name values) + 2 standing (`generate_document_test`); analyze, format clean |
| render `packages/jet_cad_2d_flutter` | **1,240 passed** + 1 skip + 7 standing (the text ladders); analyze, format clean (`GalleryCategory.id` only) |
| planner `packages/jet_cad_floor_plan` | **1,212 passed** (+29: `test/l10n/`, TT4b, the failed-load check rewritten); analyze, format clean |
| restaurant symbols | **97 passed** (+3: the names); analyze, format clean |
| app `apps/floor_planner` | **203 passed** (+2: AW1–AW2); analyze, format clean |
| demo `apps/restaurant_demo` | **21 passed** (+1: D19); analyze, format clean |
| `apps/dev_harness_2d` | analyze clean |
| web builds | `apps/restaurant_demo` and `apps/floor_planner`: `✓ Built build/web` |

The two allocation invariant tests and the goldens are untouched.

**Smoke (Chromium, the web builds of this commit's code).** The demo in a
`de-DE` browser opens in German (*Restaurant-Demo*, *Werkzeuge*,
*Ebenen*, *Querformat*, *Am Raster fangen*). TR in the app bar: the
whole screen turns Turkish, the palette, the Page panel, the demo's side
panel. The Symbols tab: categories and cells in Turkish; the search
`kose` finds *Köşe loca, 5 kişilik* and *Köşe bar tezgâhı*. Service: a
right click on table 2 opens *Masa 2*, *Yalnız bunu seç* and the four
statuses; DE, then a right click on table 3: *Tisch 3*, *Nur diesen
auswählen*, *Frei*, *Bestellt*, *Beim Essen*, *Rechnung*. The floor
planner in a `tr-TR` browser: Turkish, the document *Adsız*. No page or
console error.

**Found by the smoke and fixed in this commit:** the demo's log worded
the mode by its enum name (*Salon: mod selection*); D19 had pinned it.
The log now uses the mode's word (*Salon: mod Servis*); D1 and D19
updated; the mutant (the enum name back) fails D1 and D19.

## Mutants fired

All red unless listed under *Survive*.

- **Task 1** (`test/l10n/l10n_test.dart`): **M-14d-b** `tr` mapped to
  English, the delegate ignored, the locale ignored; **M-14d-f** both
  separators accepted, the foreign one always refused (the iPad case),
  the format ignoring the language; **M-14d-j** plain `toLowerCase`, `ı`
  unfolded, the combining dot kept (the web's `İ`, after a direct case
  was added: on the VM `'İ'.toLowerCase()` has no combining dot).
- **Task 2** (`value_words_test.dart`, the engine's `layer_header_test`):
  unnumbered tables listed first, single numbers listed as duplicates (after
  a table numbered once was added to the fixture), the Turkish warning in
  English, the German duplicate-layer text without its name, the engine
  answering edge-space for too-long.
- **Task 3** (`shell_words_test.dart`): the file commands frozen at the
  first language, the status line by `Tool.name`, the modifier not named,
  the service bar's Undo as a literal, the Export dialog's Cancel as a
  literal.
- **Task 4** (`panel_words_test.dart`): the panel parsing and showing in
  English, no re-show on a language change, the Page panel parsing in
  English and not re-syncing, the zoom line in English, the Thickness
  label and the Layers title as literals.
- **Task 5** (`numbered_names_test.dart`, `room_tool_test.dart` TT4b):
  **M-14d-k** the current language's pattern only, a room always named in
  English, a layer's names not folded, the sample plan's kitchen in
  English.
- **Task 6** (`symbol_words_test.dart`, the restaurant package's
  `symbol_names_test.dart`): **M-14d-i** one Turkish name removed;
  **M-14d-j** search by plain lower case, the shown name ignored, the
  English name ignored (after `corner`, a word in no tag, was added: the
  first query matched a tag); **M-14d-h** the Symbol section reading the
  stored name first; **M-14d-s** the collapsed set keyed by the shown name,
  the palette's cells not rebuilt on a language change, the category
  header in English.
- **Task 7** (`overflow_test.dart`, the demo's D19, the app's AW1–AW2):
  **M-14d-c** a 70-character Turkish OSNAP word in the top bar's `Row`;
  the demo's locale not passed to `MaterialApp`, the Bill caption in
  English.
- **Task 8**: **M-14d-a** (`leak_test.dart`) eight literals put back —
  Paper, the layer colour tooltip, a colour name, the dpi label, the
  no-match line, the service bar's Redo, a category header in English,
  and a Turkish literal that bypasses the strings; **M-14d-g**
  (`determinism_test.dart`) the palette arming a copy of the entry
  renamed to the shown name.

**Survive, recorded:** one, not a defect of the guard: in the
determinism test, a Rotation field that parsed Turkish input as English
(`double.tryParse`) is equivalent on the typed `30`; the separator's
parsing is pinned by Task 1's and Task 4's tests instead.

## Amended at execution

- **The English sentences stay for the engine's own use**:
  `layerNameError` is `layerNameProblem(...)?.toString()`, and
  `tableNumberError` words `tableNumberProblem` in English; the planner
  uses the values.
- **An unnumbered table's warning names no handle** (D18): English reads
  *A table with 4 seats has no number* (was *Table 2F has no number*).
- **Panels keep their words in their state**, set in
  `didChangeDependencies` (an inherited lookup is not allowed in
  `initState`); a language change shows every unfocused field again.
- **The shell's file commands keep the set they were built with and take
  their words from the current widget by id** (view test V10 showed a host
  rebuild can change the set).
- **The symbol panel no longer shows the raw load error** (V-17); the
  loader logs it with `debugPrint` (a `FlutterError` report would fail
  every test that makes a load fail on purpose). The existing failed-load
  test now checks the words instead.
- **`GalleryCategory` gains `id`** (render package), defaulting to its
  name, so the planner keys by the English category and shows the
  translation.
- **The floor planner's untitled name** is set without notifying during a
  build and announced after the frame (the app's title listens to the
  session above the host: notifying in `didChangeDependencies` threw).
- **The demo's `kStatuses` stay English** for its tests; the Bill caption
  is worded when a status is set.
- **The planner depends on `flutter_localizations`** (for
  `floorPlanLocalizationsDelegates`); the root `pubspec.lock` did not
  change.

## Found, not fixed

- **The floor planner's native save panel's file type labels** (`Jet
  plan`, `PDF document`, `PNG image`) and the web exit guard's text stay
  English: the first are native dialog labels built from constants, the
  second is ignored by today's browsers.
- **An error dialog's body is the exception's own text**, English.
- **The plan's own text keeps `.`** (Q0, by design): rulers, dimension
  and area text, the Area and Value rows, the Dimension tool's notice.
- **A layer name's uniqueness folds by `toLowerCase()`**, which is not
  Turkish-aware (`I`/`ı`); unchanged, as stored-value rules are the
  engine's.
- **The demo's log keeps each line in the language it was written in**;
  the area names (*Salon*, *Teras*) are the demo's data, not words.
- **German, for the native reader:** *Am Raster fangen* (snap to grid),
  *Zufällige Status*; the demo's number field hint is cut at the side
  panel's width (*Tischnummern (durch Komma getr…*).
- **The leak test covers the planner**, not the two apps; theirs are
  covered by targeted tests (AW1–AW2, D19).

## For the human

- **Look owed (macOS and web):** in the demo, switch EN / DE / TR in the
  app bar and walk the Design editor (palette, Symbols tab and search,
  Selection and Page panels, Layers, Export dialog) and the Service mode
  (menu, statuses); in the floor planner, set the system to Turkish or
  German. **Read the Turkish text**; the German is owed a native speaker.
