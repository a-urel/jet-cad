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
| Exit (this note, STATUS, roadmap) | in progress |

**Process, stated plainly:** implemented by the controller, without a
fresh implementer or a per-task reviewer, as 14d-2; every mutant below
was fired by the controller. The code has had no independent review.
**The German and Turkish text is the controller's** (R-3): Turkish is
owed the human's read, German a native speaker's.

## Gates (Linux container, Flutter 3.47.6 / Dart 3.13.5)

**Pending:** the exit's gates are running; this section is filled in
by the next commit, with the web builds and the Chromium smoke.

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
- **The leak test covers the planner**, not the two apps; theirs are
  covered by targeted tests (AW1–AW2, D19).

## For the human

- **Look owed (macOS and web):** in the demo, switch EN / DE / TR in the
  app bar and walk the Design editor (palette, Symbols tab and search,
  Selection and Page panels, Layers, Export dialog) and the Service mode
  (menu, statuses); in the floor planner, set the system to Turkish or
  German. **Read the Turkish text**; the German is owed a native speaker.
