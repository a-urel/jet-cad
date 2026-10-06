# POS readiness (14d) — design

**Date:** 2026-10-06. **Status:** design, **revision 2**: revision 1
(`82942ea`) reviewed independently, "Needs revision" (findings V-1 to
V-21); [Revision 2](#revision-2) is binding where it differs. For the
human's approval, with its questions Q0–Q4. **Sub-project:** 14
(restaurant embedding), slice **14d**, after 14b-1, 14s, 14a, 14b-2,
14c, 14t (all merged at `95d6e0e`) and 09c (merged at `43dd020`).
**Umbrella:** [2026-10-03-restaurant-embedding-design.md](2026-10-03-restaurant-embedding-design.md)
(revision 3). **Inputs:** 14b-2's spec
([2026-10-03-host-api-and-modes-design.md](2026-10-03-host-api-and-modes-design.md),
rev 2) and 14c's ([2026-10-03-selection-mode-design.md](2026-10-03-selection-mode-design.md),
rev 2), whose decisions stand unless this spec amends them by name.
**Branch:** `claude/exciting-pasteur-9m22jv`; facts at `243cee5`.
**Size:** L, in three slices. **Packages touched:** `jet_cad_2d` (the
page's decimal separator, the layer-name problems as values, schema 8),
`jet_cad_2d_flutter` (the ruler's separator, the gallery's category
key), `jet_cad_floor_plan`, `jet_cad_restaurant_symbols`, both apps,
the repository root (CI, the host guide).

## Why now

The human, 2026-10-06, after a review of what a POS still needs
(*"Restoran yazılımı için gereken başka özellik ya da değişiklik kaldı
mı?"*): four gaps were named — the UI is English and hard-coded, the
service layout dies with the app, the selection mode cannot be made
read-only nor give the host a context menu, and nothing is versioned or
built by CI. The human: *"evet, 14d spec'ini yaz. 3 dil built-in olarak
desteklenmeli: en, de, tr"* — **English, German and Turkish are built
in.** Table merging and the plan's position across a mode switch (14b-2
R-13) were named too and are **not** in 14d; they wait for the human's
rulings.

## What it delivers

- **14d-1, three languages.** Every word the planner shows — the design
  editor's panels, tools, status line, dialogs and tooltips; the
  selection mode's tooltips; the symbol names and categories of both
  shipped libraries; the numbering warnings — exists in English, German
  and Turkish, chosen by the host's locale, English for any other.
  Numbers typed and shown in the panels use the language's decimal
  separator. The plan's own text (dimensions, room areas, the rulers)
  uses a separator the **document** carries, chosen per plan on the Page
  panel, so a plan prints the same on every terminal.
- **14d-2, the service layout and the service options.** The host can
  save the service copy's table positions as a small JSON and restore
  them after a restart. A view can forbid service moves (a host stand or
  kitchen screen), and reports a secondary click — or, if the host
  chooses, a long press — on a table, so the host can open its own
  context menu.
- **14d-3, a release a POS can pin.** The four packages at `0.1.0`, a
  host guide, a GitHub Actions workflow running every gate on every push,
  and an external-host probe in CI proving the git dependency resolves.

## Decisions the human made

1. **2026-10-06:** English, German and Turkish are built in (above).
2. **2026-10-03 (umbrella), standing:** a Flutter host; a long press
   toggles a table in or out of the selection (decision 9); service moves
   never change the designed plan (decision 11); Export and Print in both
   modes (decision 6).

## Facts established (at `243cee5`)

Strings (an inventory of the five lib trees, file:line, kept in the
review's ledger):

- **F-1. No localization exists.** No `flutter_localizations`, `intl`
  (only transitive, `pubspec.lock`), ARB or `l10n.yaml` anywhere; neither
  app's `MaterialApp` sets `locale`, `supportedLocales` or
  `localizationsDelegates` (`apps/floor_planner/lib/main.dart:145-172`,
  `apps/restaurant_demo/lib/main.dart:60-64`).
- **F-2. About 184 user-visible literals in the planner package**,
  about 40 interpolated: `selection_panel.dart` 52, `planner_shell.dart`
  41 (15 of them shortcut letters), `layer_row.dart` 18, `page_panel.dart`
  16, `layer_panel.dart` 9, `symbol_panel.dart` 8, `layer_picker.dart` 7,
  `export_dialog.dart` 6, the rest under 5 each. Plurals:
  `planner_shell.dart:597` (`… selected`), `selection_panel.dart:1118`
  and `table_index.dart:131` (`Number N is used by M tables`).
- **F-3. The status line shows `Tool.name`**
  (`planner_shell.dart:594-606`): seven render-layer tools
  (`line_tool.dart:18` … `select_tool.dart:62`) and the planner's own
  (`room_tool.dart:164`, `opening_tool.dart:159-161`, …,
  `table_select_tool.dart:49`) name themselves in English. Tools also set
  English notices (`room_tool.dart:284` `Already a room: …`).
- **F-4. Text that is shown but produced without a `BuildContext`:**
  `FloorPlanController.numberingWarnings` returns English `Diagnostic`
  messages (`floor_plan_controller.dart:444-450`, from
  `table_index.dart:131,140`); the engine's `layerNameError` returns
  English sentences (`jet_cad_2d/lib/src/document/layer_commands.dart:29-44`)
  that `layer_row.dart:342` shows; `SheetSize.name` returns `'Custom'`
  (`page_component.dart:49-53`), shown by `page_panel.dart:144`;
  `table_numbers.dart:19,23` return the number field's error text.
- **F-5. Text stored in the document:**
  - room names, `'Room $n'` once at creation (`room_tool.dart:352-364`;
    the lowest free `n` found by `RegExp(r'^Room ([1-9][0-9]*)$')`, :31);
    the sample plan's seven English room names
    (`startup_plan.dart:204-210`);
  - layer names, `'Layer $n'` once at creation (`layer_panel.dart:37-42`);
  - **room area text**, `formatArea` (`room_label.dart:164-172`,
    `toStringAsFixed(2)` + `' m²'`/`' ft²'`), and **dimension text**,
    `formatDimension` (`dimension_geometry.dart:459-489`, the `.` built by
    concatenation): both **regenerated** whenever their `pageKey` —
    `(displayUnit, scaleDenominator)` (`room.dart:234-237`,
    `dimension.dart:159`) — changes;
  - the symbol's `SymbolComponent(key, name, category, tags, version)`,
    copied once at first placement (`symbol_placer.dart:128-137`); the
    Symbol section shows **this copy's** name (`selection_panel.dart:1062`);
    the demo's sample plans carry English names
    (`apps/restaurant_demo/assets/plans/salon.json`).
- **F-6. Numbers.** `panelNumberText` (`panel_number.dart:14-18`) prints
  with `.`, no grouping, and is used for every panel field, the symbol
  size, the page scale and the status line; parsing is `double.tryParse`
  (`selection_panel.dart:331,1020`, `page_panel.dart:105`), which refuses
  a `,` (the field reverts). The rulers print the engine's `formatLength`
  (`grid_scale.dart:113-140`, `ruler_painter.dart:87`).
- **F-7. Symbol names and categories** come from Dart catalogs built into
  `.jetlib` assets (`furniture_catalog.dart`: 6 categories, 41 names;
  `jet_cad_restaurant_symbols/lib/src/*.dart`: 6 categories, 69 names); a
  test pins each asset to its generator's bytes. Search
  (`symbol_search.dart:23-50`) lower-cases the query and needs every term
  to be a substring of the name, a tag or the category. The gallery keys
  its collapsed set and its header test keys by the category's text
  (`symbol_gallery.dart:96-98,116`).
- **F-8. The font covers the three languages:** the bundled Roboto
  (`packages/jet_cad_floor_plan/lib/fonts/`) has ä ö ü ß ğ ş ı İ ç, on
  screen and in the PDF.

The service copy and its gestures:

- **F-9. The service copy** is the design encoded and decoded under
  `DraftPermissions.runtime` (`floor_plan_controller.dart:385-391`); it is
  rebuilt by `setMode(selection)`, `resetLayout` and `load`, each dropping
  every service move. `serviceEdited` is `undoDepth > 0` (:279). The
  dispatcher can clear its history (`CommandDispatcher.clearHistory`,
  `undo.dart:277`).
- **F-10. A service move** is one `CompoundCommand` of
  `TransformNodeCommand`s, translation only (`table_select_tool.dart:173-185`);
  `onLayoutChanged` fires once per executed move, not for undo or redo,
  which `revision` reports (14c S8).
- **F-11. The tool ignores a press without the primary button**
  (`table_select_tool.dart:67`); the render layer gives the middle button
  to the camera only (`interaction_layer.dart:343`), so a secondary press
  reaches the tool. No code touches `BrowserContextMenu`: on the web the
  browser's own menu opens on a right click.

Release:

- **F-12. A host outside the repository can depend on the packages by
  git, today.** A probe (an empty Flutter app outside the workspace)
  depended on `jet_cad_floor_plan` and `jet_cad_restaurant_symbols` by
  git, `path:` each package, and resolved, analysed clean and built for
  the web — **only with both pinned to the same commit SHA**. Pinned to
  `main` or to a tag, pub refuses: the restaurant package's path
  dependency on the planner resolves to the commit's SHA, which differs
  from the root's `ref`. Depending on the restaurant package alone (the
  planner arriving transitively) resolves at a tag.
- **F-13. Nothing is versioned or built by CI:** the packages are
  `0.0.1`, `publish_to: none`; there is no `.github/`. The engine's two
  `generate_document_test` fingerprints and the render package's seven
  text-ladder tests fail on Linux by design (macOS values; STATUS
  "standing").

## Slice 14d-1 — three languages

### The strings

- **L1. One strings class per language, hand-written.** An abstract
  `FloorPlanStrings` in `jet_cad_floor_plan` with one member per string —
  a getter for a fixed string, a method for an interpolated one or a
  plural — and three implementations, `FloorPlanStringsEn`, `…De`,
  `…Tr`. Not ARB and `gen-l10n`: the compiler then refuses a language
  that misses a string (the completeness test is the build), there is no
  generation step in a workspace, no new dependency (`intl` is not needed:
  every plural here is a count of tables or of selected objects, written
  out per language — Turkish keeps the noun singular after a numeral,
  `3 masa`), and a host can subclass a language to change a word (H-1).
- **L2. The lookup.** `FloorPlanStrings.of(context)` returns, in order:
  the instance a `Localizations` scope provides
  (`FloorPlanLocalizations.delegate`, exported); else the built-in
  language matching `Localizations.maybeLocaleOf(context)`'s language
  code (`en`, `de`, `tr`); else English. A host that adds the delegate
  gets Flutter's locale resolution and may supply its own
  `LocalizationsDelegate<FloorPlanStrings>`; a host that adds nothing gets
  the locale's language anyway; neither ever throws. The barrel exports
  `FloorPlanStrings`, the three classes, `FloorPlanLocalizations` and
  `floorPlanSupportedLocales` (`en`, `de`, `tr`).
- **L3. A language change rebuilds the words, never the document.** Every
  widget reads its strings at build time, so a new locale redraws them; no
  string is cached across builds (a painter that caches a paragraph keys
  it by the string).
- **L4. What is translated:** every literal of F-2, F-3 and F-4 except
  - shortcut letters (`V`, `L`, `W`, …): they are keys, the same in every
    language (bound to `LogicalKeyboardKey`, F-2); only the modifier's
    name in a tooltip follows the language (`Ctrl` / `Strg` / `Ctrl`; the
    macOS glyphs stay);
  - unit symbols (`mm`, `cm`, `m`, `in`, `ft`, `°`, `m²`, `ft²`) and the
    paper names `A4`, `A3`, `Letter`, `Tabloid` (international names; only
    `Custom` is translated);
  - layer `0`, `PDF`, `PNG`, `dpi`;
  - exception text a host catches (`FormatException('Not a floor plan…')`):
    developer-facing, English; a host shows its own words;
  - command labels never shown (`CompoundCommand` labels, F-3's list in
    the ledger).
- **L5. Tool names on screen come from the shell, not from `Tool.name`.**
  `Tool.name` stays an English identifier (the render layer has no
  strings). The status line shows the label of the palette entry that
  made the active tool (a map the shell owns, keyed by the entry), and
  the selection mode shows none. A tool that sets a notice reads its
  words through a `FloorPlanStrings Function()` the shell gives it at
  construction (never a captured instance: L3).
- **L6. Text produced away from a widget becomes a value.**
  - `FloorPlanController.numberingWarnings` becomes
    `List<NumberingWarning>`: `sealed` — `DuplicateNumber(number,
    count)` and `Unnumbered(seats, symbolKey)` — and
    `FloorPlanStrings.numberingWarning(w)` words one. **A breaking change
    of the host API**; its one caller is the demo.
  - The engine's `layerNameError` returns a `LayerNameProblem?` (`empty`,
    `edgeSpace`, `tooLong(max)`, `badCharacter(c)`,
    `duplicate(existing)`) instead of a sentence; the planner words it.
    The engine stays free of any language (and of Flutter).
  - `SheetSize.name` stays (it names presets in code and tests); the Page
    panel words `Custom` itself.
  - The table number's validation (`table_numbers.dart:19,23`) returns a
    problem value the same way.
- **L7. Names the planner stores** are written once, in the language of
  the moment, and are the user's afterwards:
  - a new room is `Room n` / `Raum n` / `Oda n`; the lowest free `n` is
    counted over the names in **all three** patterns, so a plan edited in
    two languages never gets `Room 3` and `Oda 3`;
  - a new layer is `Layer n` / `Ebene n` / `Katman n`, counted the same
    way;
  - the sample plan (`startup_plan.dart`) names its rooms in the language
    it is generated in.
  Nothing renames what exists: a stored name is a stored value.

### Symbols

- **L8. A library source carries its names.** `SymbolLibrarySource` gains
  `names: SymbolNames?`: per language code, a map from the entry's `key`
  to its name and from the category's English name to the category's.
  The two shipped sources fill `de` and `tr` for every key and category
  (`en` is the asset's own text). The `.jetlib` format and the assets do
  **not** change: their bytes stay pinned (F-7).
- **L9. Display goes by key, never by the stored name.** The palette, the
  search, the Symbol section and the placement ghost's notice show
  `names[lang][key] ?? entry.name`; the Symbol section of a placed symbol
  looks its key up the same way and falls back to the document copy's
  `SymbolComponent.name` (F-5) when no loaded library knows the key. The
  document copy is not rewritten: a plan saved in Turkish opens in
  German with German names, and a demo sample with English names shows
  Turkish ones.
- **L10. Categories are keyed by their English name.** The gallery's
  collapsed set and its test keys use the key; the header shows the
  translation.
- **L11. Search matches either language.** A term matches if it is a
  substring of the shown name, the shown category, the English name, the
  English category or a tag, after a **fold** applied to both sides:
  lower case, `İ I ı → i`, `ä→a ö→o ü→u ß→ss ğ→g ş→s ç→c`, the combining
  dot U+0307 dropped. So `kose` finds `Köşe kabin`, `ISIK` finds `ışık`,
  and `booth` still finds it in Turkish. The fold is for search only:
  never applied to a stored value.

### Numbers

- **L12. Panels follow the language; the plan follows the document.**
  - **Panels** (every field of the Selection and Page panels, the symbol
    size, the Rotation field, the axes line, the status line's scale):
    the UI language's separator — `.` for `en`, `,` for `de` and `tr` —
    and **no grouping in any language** (a grouped `1.600` reads as 1600
    to a German and as 1.6 to an English reader; a plan's numbers are
    never grouped today, F-6).
  - **The plan** (dimension text, room area text, the rulers, and so the
    PDF and PNG): the document's separator (L13). A German terminal
    opening an English plan shows `,` in its fields and `.` on the
    canvas; the Area and Value rows, which echo stored text, show the
    document's.
- **L13. The page carries a decimal separator.** `PageComponent` gains
  `decimalSeparator`, an enum `point` / `comma`, default `point`; it
  joins the `pageKey` of rooms and dimensions, so a change regenerates
  their text in the same step (F-5). `formatLength` (engine),
  `formatDimension` and `formatArea` take it. The Page panel gains a
  **Decimal separator** menu (`1.5` / `1,5`), one undo step. A new plan
  takes the UI language's separator when a widget creates it (the shell's
  New, the sample plan); `FloorPlanController` gains `Locale? locale`
  for the plans it creates without a widget (its constructor without
  `json`, `newPlan()`): `de` or `tr` give `comma`, anything else
  `point`.
- **L14. Schema 8.** `PageComponent.toJson` writes `decimalSeparator`;
  `fromJson` defaults it to `point` when absent — the whole of the v7→v8
  migration. The bump exists for the reader, as 6's and 7's did: a v7
  build would load a v8 plan, drop the separator and regenerate its
  dimensions with `.` on the next edit. Every committed encoding is
  regenerated (the two `.jetlib` assets, the demo's sample plans, the
  engine's fixtures); the engine's macOS fingerprints
  (`generate_document_test`) move and are **owed a macOS re-baseline**,
  as 12b's were.
- **L15. Parsing is strict per language.** A field accepts the
  language's separator only; the other one is refused as today (the
  field reverts). `1,600` in English and `1.600` in German or Turkish
  mean thousands to some readers and decimals to others: refusing both
  costs a retype, accepting either can cost a factor of a thousand.
  After the separator check, the text is parsed as today
  (`double.tryParse` with `.`). Mobile keyboards stay
  `numberWithOptions(decimal: true, signed: …)`; their decimal key
  follows the device's locale, which the host's locale normally matches.

### The apps

- **L16. `apps/floor_planner`** adds `flutter_localizations` and sets
  `supportedLocales: floorPlanSupportedLocales` and the three delegates
  (`GlobalMaterialLocalizations`, `GlobalWidgetsLocalizations`,
  `GlobalCupertinoLocalizations`) plus `FloorPlanLocalizations.delegate`;
  it follows the system's language. Its own 32 strings (F-2's
  `document_host.dart`, `document_files.dart`, `exit_guard_web.dart`)
  move into an app-level strings class built the same way (L1).
- **L17. `apps/restaurant_demo`** does the same and gains an **EN / DE /
  TR** switch in its app bar, so all three can be looked at without
  changing the system's language. Its own words follow (its log lines
  too); the area names `Salon` and `Teras` are data and stay.

### Words

- **L18. A glossary fixes the recurring terms** (the human rules on any
  row before the plan; German is owed a native speaker's read, R-3):

| en | de | tr |
|---|---|---|
| Table | Tisch | Masa |
| Number | Nummer | Numara |
| Seats | Plätze | Kişilik |
| Design / Service (modes) | Entwurf / Service | Tasarım / Servis |
| Layer | Ebene | Katman |
| Wall | Wand | Duvar |
| Door / Window / Gap | Tür / Fenster / Öffnung | Kapı / Pencere / Boşluk |
| Room | Raum | Oda |
| Area | Fläche | Alan |
| Separator | Trennlinie | Ayırıcı |
| Dimension | Bemaßung | Ölçü |
| Symbol | Symbol | Sembol |
| Rotation | Drehung | Döndürme |
| Mirror | Spiegeln | Aynala |
| Page / Grid / Paper | Seite / Raster / Papier | Sayfa / Izgara / Kâğıt |
| Snap to grid | Am Raster fangen | Izgaraya yapış |
| Undo / Redo | Rückgängig / Wiederholen | Geri al / Yinele |
| Export… / Print… | Exportieren… / Drucken… | Dışa aktar… / Yazdır… |
| Select | Auswählen | Seç |
| Thickness | Dicke | Kalınlık |
| Centreline | Mittellinie | Eksen |
| Mixed | Gemischt | Karışık |
| Custom | Benutzerdefiniert | Özel |

## Slice 14d-2 — the service layout and the service options

### The service layout

- **S1. `String? serviceLayoutJson()`** on the controller: in the
  selection mode, the tables whose service position differs from the
  design's; in the design mode, `null`. Deterministic: entries ascending
  by handle, numbers as JSON doubles (Dart's shortest round-trip form):

  ```json
  {"format": "jet_cad.service_layout", "version": 1,
   "tables": [{"handle": "2F", "number": "12",
               "from": [a, b, c, d, tx, ty],
               "to":   [a, b, c, d, tx, ty]}]}
  ```

  `from` is the table's transform in the design, `to` its transform in
  the copy; `number` is its number or `null`. A table counts as differing
  when `to != from` (exact `==`: a stored value). Nothing else of the
  copy is recorded: a service edit is a move (F-10), and statuses are the
  host's (14c D13).
- **S2. `ServiceLayoutRestore restoreServiceLayout(String json)`**: the
  selection mode only (a `StateError` in the design mode). A text that is
  not a layout of version 1 throws a `FormatException` and changes
  nothing. Otherwise the copy is rebuilt from the design (as
  `resetLayout`), each entry is applied **if and only if** its handle is a
  live root table instance of the design, on a visible, unlocked layer,
  whose number equals the entry's and whose design transform equals
  `from` — then the copy's history is cleared (F-9). Every other entry is
  dropped. It returns the applied and the dropped entries' numbers. The
  restored positions are the floor: Undo does not remove them;
  `resetLayout` still returns to the design.
  *Why the strict match:* a layout outlives a restart, and the design may
  have been edited in between. A table moved, renumbered, deleted or
  locked in the design since makes its service position stale; dropping
  it shows the design's position, which is never on top of a wall the
  designer drew around the new one.
- **S3. `serviceEdited`** becomes "the copy has a layout" (S1's list is
  not empty) instead of `undoDepth > 0` (F-9): after a restore the depth
  is 0 but the service layout is real, and the demo must still ask before
  discarding it; a move dragged back exactly to its design place is no
  edit.
- **S4. Persisting is the host's, by `revision`** (14c S8 stands:
  `onLayoutChanged` stays once per drag). A host saves
  `serviceLayoutJson()` on `revision` while in the selection mode and
  calls `restoreServiceLayout` after `setMode(FloorPlanMode.selection)`
  at start. `load` in the selection mode drops the layout as today; the
  host restores again if it wants. The demo does all of this, keeping the
  layout per area in memory.

### The service options

- **S5. `FloorPlanView.serviceMoves`** (`bool`, default `true`). When
  `false`, a drag that starts on a table pans as one on the floor does;
  tap and long press are unchanged; the tool never builds a
  `TransformNodeCommand` (asserted with a dispatcher spy, as 14b-2's
  M-12a). `serviceMoves` is read at each press, so a host may switch it
  while the view is mounted.
- **S6. `FloorPlanView.onTableContextMenu`**
  `(String number, Offset globalPosition)`, null by default. A press and
  release of the **secondary** button on a table, within the touch slop,
  reports it: if the table is not selected and not locked it is first
  selected alone (as a desktop's right click does); a selected table
  keeps the selection, so the host's menu acts on `selectedTables`; a
  locked table is reported without a selection change (14c D14). On empty
  floor: nothing. Only a table with a number reports (D18: callbacks
  carry numbers).
- **S7. `FloorPlanView.longPress`**, an enum `FloorPlanLongPress`:
  `toggleSelection` (default, the human's decision 9) or `contextMenu`,
  which makes a long press report `onTableContextMenu` at the finger
  (S6's rules) instead of toggling. Under `contextMenu` a touch screen
  has no way to select several tables; the host chooses.
- **S8. The browser's menu is the host's.** Suppressing it is app-global
  (`BrowserContextMenu.disableContextMenu()`), so the view does not touch
  it; the host guide says to call it on the web when using S6, and the
  demo does.

### The demo

- **S9.** The demo's service area gains: a **Moves** switch (S5), a
  context menu on a table (S6: *Select*, *Status ▸*, the number in its
  title) and, behind a **Long press: menu** switch, S7. It saves each
  area's layout on `revision` (S4) and restores it when Service is
  entered, so Design → Service shows the moves again until Reset layout
  or Discard.

## Slice 14d-3 — a release a POS can pin

- **R1. Versions.** `jet_cad_2d`, `jet_cad_2d_flutter`,
  `jet_cad_floor_plan`, `jet_cad_restaurant_symbols` go to `0.1.0`
  (`publish_to: none` stays); a root `CHANGELOG.md` records 0.1.0 as
  sub-projects 01–14 and 09c, and 14d.
- **R2. The host guide**, `docs/host-guide.md`: the dependency (F-12:
  both packages pinned to **one commit SHA**, the tag's; or the
  restaurant package alone at the tag, the planner transitive), fonts
  (`ensureFloorPlanFonts`, `registerFontLicences`), languages (L2, L16),
  storage (`designJson`, `markSaved`, `dirty`; S1–S4), callbacks and
  statuses, the web's context menu (S8), touch, and what a host must
  never assume (handles; the service copy's undo).
- **R3. The tag** `v0.1.0` is made on `main` after 14d merges, **on the
  human's word**; its note names the SHA (R2).
- **R4. CI**, `.github/workflows/ci.yml`, on every push and pull request
  to `main` and on `claude/**` branches: Ubuntu, Flutter pinned to the
  version the gates last ran on (3.47.6); for each package and app,
  `pub get`, `analyze`, the format check and the tests; the web builds
  of both apps; `apps/dev_harness_2d` analysed. `CI=true` throughout.
- **R5. Standing failures are compared, never skipped.** The engine and
  render tests run with `--reporter json`; a small script
  (`tool/ci/expect_failures.dart`) reads the failing tests' full names
  and compares them with `tool/ci/standing_failures.txt` **exactly**: a
  new failure is red, and so is a standing one that passes (the list is
  then stale, or a re-baseline landed). No test is skipped, tagged out or
  quarantined.
- **R6. The external-host probe** (`tool/ci/host_probe/`): a template
  Flutter app whose pubspec CI writes with both packages by git at
  `${{ github.sha }}` — F-12's working form — then `pub get`, `analyze`
  and `build web`. It proves on every push that a POS can still consume
  the packages from outside the workspace.
- **R7. Nothing in CI writes.** `pub get` rewrites three
  `analysis_options.yaml` (CLAUDE.md); CI never commits, never diffs
  them, never pushes.

## Files

- `packages/jet_cad_2d/lib/src/document/page_component.dart` (L13),
  `codec/schema_version.dart` (L14), `geometry/grid_scale.dart`
  (`formatLength`'s separator), `document/layer_commands.dart` (L6).
- `packages/jet_cad_2d_flutter/lib/src/ruler_painter.dart` (the page's
  separator), `symbol_gallery.dart` (L10: a category key beside its
  shown name).
- `packages/jet_cad_floor_plan/lib/src/l10n/` (new): `strings.dart`,
  `strings_en.dart`, `strings_de.dart`, `strings_tr.dart`,
  `localizations.dart`, `search_fold.dart`, `number_text.dart` (the
  separator-aware `panelNumberText` and its parser).
- `packages/jet_cad_floor_plan/lib/src/`: every file of F-2 and F-3; the
  furniture catalog's names (L8); `host/floor_plan_controller.dart`
  (L6, L13, S1–S3), `host/floor_plan_types.dart` (`NumberingWarning`,
  `ServiceLayoutRestore`, `FloorPlanLongPress`),
  `host/floor_plan_view.dart` and `service/table_select_tool.dart`
  (S5–S7), `parametric/room_label.dart`, `dimension_geometry.dart`,
  `room.dart`, `dimension.dart` (L13), `room_tool.dart`,
  `layers/layer_panel.dart`, `startup_plan.dart` (L7).
- `packages/jet_cad_restaurant_symbols/lib/src/names.dart` (new: L8).
- `apps/floor_planner/lib/` (L16), `apps/restaurant_demo/lib/main.dart`
  (L17, S9).
- `.github/workflows/ci.yml`, `tool/ci/expect_failures.dart`,
  `tool/ci/standing_failures.txt`, `tool/ci/host_probe/`,
  `docs/host-guide.md`, `CHANGELOG.md` (R1–R6).

## Invariants

- **I-1.** The two allocation invariant tests are untouched and green:
  no string lookup or fold runs on the frame path (the ruler's labels
  are already built per tick label, at the same rate).
- **I-2.** Draw order is ascending handle value: 14d adds no entity and
  reorders nothing; a restored layout transforms existing instances
  only.
- **I-3.** A document's bytes never depend on the UI language: the same
  edits in two languages encode the same, except the names L7 stores
  once and the separator L13 a new plan takes.
- **I-4.** Every string a user sees in the planner, both libraries and
  both apps comes from a strings class (L1) or from the document.
- **I-5.** Geometric decisions use `Tolerance`; S1's "differs" and S2's
  match are stored-value comparisons, exact `==`.

## Testing and named mutants

Every fixture is off the identity: tables turned, mirrored and away from
the origin; plans with a non-default unit and scale.

- **M-14d-a, a forgotten literal.** The **leak test**: the shell and the
  service view are pumped in German and in Turkish, every panel open and
  a wall, a door, a room, a dimension, a symbol and a table selected in
  turn; no `Text`, tooltip or hint in the tree may equal a string of
  `FloorPlanStringsEn` that differs from its translation. Mutant: one
  label put back as an English literal.
- **M-14d-b, a language falls back.** Each of `de` and `tr` returns its
  own class through both lookup paths (delegate, locale alone); an
  unknown locale gives English; no host setup throws. Mutant: `tr` mapped
  to English.
- **M-14d-c, an overflow.** The shell is pumped at its minimum window in
  each language, each panel open; no `RenderFlex` overflow is reported.
  Mutant: a German label made 40 characters.
- **M-14d-d, the separator ignored.** A room and a dimension in a plan at
  `cm`, 1:50, switched to `comma`: their texts change in one undo step;
  undo restores the bytes. Mutants: the separator left out of `pageKey`;
  `formatArea` printing `.` always.
- **M-14d-e, the schema not bumped.** A v8 plan with `comma` is refused
  by a reader at v7 (the codec's version test); a v7 plan reads as
  `point`. Mutant: `kSchemaVersion` left at 7.
- **M-14d-f, lenient parsing.** In German `1,5` is 1.5 and `1.5` is
  refused; in English the reverse; no field accepts a grouping. Mutant:
  both separators accepted.
- **M-14d-g, the language in the document.** The same edits in English
  and in Turkish encode identically but for L7's names (I-3). Mutant:
  `formatArea` reading the UI's separator.
- **M-14d-h, the stored name shown.** A plan whose symbol copy says
  `Round table, 6 seats` shows the Turkish name in Turkish (L9); a key no
  library knows shows the stored name. Mutant: the Symbol section reading
  `SymbolComponent.name` first.
- **M-14d-i, a missing translation.** Every key and category of both
  shipped libraries has a `de` and a `tr` name, none empty, none equal to
  another key's name in the same category. Mutant: one entry removed.
- **M-14d-j, the fold.** `kose` finds `Köşe kabin`; `ISIK` finds
  `ışık`; `booth` finds the Turkish booth. Mutant: plain `toLowerCase`.
- **M-14d-k, counting one language.** A plan with `Room 1` and `Oda 2`
  gets `Raum 3` in German. Mutant: the current language's pattern only.
- **M-14d-l, a stale layout applied.** S2 with an entry whose table was
  moved, renumbered, deleted or locked in the design since: dropped, and
  named in the result; the others applied. Mutants: match by handle only;
  match by number only.
- **M-14d-m, the restore undoable.** After a restore, Undo changes
  nothing and `serviceEdited` is true; after a move and its undo it is
  false. Mutants: history not cleared; `serviceEdited` by depth.
- **M-14d-n, a nondeterministic layout.** `serviceLayoutJson()` twice, and
  after an encode–decode of the design, is byte-equal; entries ascend by
  handle. Mutant: entries in selection order.
- **M-14d-o, moves when forbidden.** With `serviceMoves: false`, a drag
  on a selected table pans the camera and the dispatcher spy sees no
  command. Mutant: the flag read once at construction (switched after
  mount).
- **M-14d-p, the context menu's selection.** A secondary click on an
  unselected table selects it alone and reports it; on a selected one it
  keeps the selection of three; on a locked one it changes nothing;
  under `longPress: contextMenu` a long press reports and toggles
  nothing. Mutants: no selection change; selection replaced on a
  selected table; the long press still toggling.
- **M-14d-q, a skipped failure.** `expect_failures.dart` is tested on
  recorded JSON: a new failure → exit 1; a standing test passing → exit
  1; exactly the standing set → exit 0. Mutant: a subset comparison.

## Risks

- **R-1. Size.** 14d-1 touches about 250 call sites across five trees.
  Mitigation: the plan moves strings file by file, each task leak-tested
  (M-14d-a) for its own panels.
- **R-2. German width.** German labels run 30–50 % longer; the left panel
  is 240 px and the top bar's floor is 656 px (plan 13). Mitigation:
  M-14d-c; short forms in the glossary; tooltips for long ones.
- **R-3. Translation quality.** The controller writes the German and
  Turkish text. Turkish is read by the human at the look; **German is
  owed a native speaker's read** before a German-speaking customer.
- **R-4. Schema 8** moves every committed encoding and the macOS
  fingerprints (L14); the re-baseline is the human's, as after 12b.
- **R-5. CI minutes and secrets.** The workflow needs no secret; a macOS
  runner is not used (cost), so the macOS-only fingerprints are never
  green in CI — they are in R5's standing list.

## Open questions for the human

- **Q1.** Is the glossary right (L18)? In particular *Kişilik* for
  Seats, *Boşluk* for an opening without a leaf, *Entwurf* for the design
  mode.
- **Q2.** Should the decimal separator of a new plan follow the UI
  language (L13, proposed) or always start at `.`?
- **Q3.** CI on GitHub Actions (R4) — acceptable on this repository?
- **Q4.** Order: proposed **14d-2 → 14d-1 → 14d-3** (the small, separate
  service work first; the release last, so its tag carries the
  languages).

## Not in scope

Table merging (the umbrella's "not in scope" stands); keeping the plan in
place across a mode switch (14b-2 R-13, the human's ruling pending);
right-to-left languages and any language beyond the three (L1's shape
admits more); translating a stored name; live sync between terminals;
publishing to pub.dev; Plan G; DXF.

## Revision 2

An independent review of revision 1 (`82942ea`, a fresh reviewer,
read-only) found one false fact (F-11), a persistence flow that saves an
empty layout, and twenty more items; verdict "Needs revision". Its
findings are **V-1 to V-21** here (renamed from the report's R-n, which
collided with this spec's risks). Each is applied below; where this
section and the text above differ, **this section is binding**. To end
the same collision, the release decisions R1–R7 of 14d-3 are renamed
**P1–P7** (same order, same content unless amended here).

### Facts, corrected

- **F-11, corrected (V-1).** A press without the primary button never
  reaches a tool: `InteractionLayer._onDown` returns on
  `e.buttons & kPrimaryButton == 0` (`interaction_layer.dart:353`),
  before `_tool.onPointerDown`. Line 343 is the middle button's rule
  only. A secondary click therefore needs its own path (S6, amended).
- **F-13, corrected (V-7).** `jet_cad_2d` and `jet_cad_2d_flutter` are
  already `0.1.0` (`jet_cad_2d` has no `publish_to: none`); only
  `jet_cad_floor_plan` and `jet_cad_restaurant_symbols` are `0.0.1`.
- **F-4, corrected (V-17).** `Custom` is shown by `page_panel.dart:141,147`
  (literals); `:144` shows the presets' `SheetSize.name`.
- **F-14 (new, V-5).** `PageComponent.fromJson` reads named keys and
  ignores unknown ones: an older reader would *tolerate* a new page field
  and drop it silently. Every committed encoding is at schema 7: the two
  `.jetlib` assets and the demo's `salon.json` and `teras.json`; the
  `furniture_pre_09c.jetlib` fixtures (planner and app tests) are
  historical. Expectations embedding the version or the page's key list:
  `json_codec_test.dart:516,586-587`, `instance_style_codec_test.dart:81`,
  `layer_header_test.dart:99,104`, `page_component_test.dart:53`, and the
  macOS fingerprints of `generate_document_test`.
- **F-15 (new, V-6).** The allocation invariant tests skip themselves
  when the VM service is unreachable (`query_allocation_test.dart:540,591`
  via `vm_allocation_meter.dart:228`; also `layer_filter_test.dart:637`,
  `packed_rtree_test.dart:133`); the render package has one standing
  skip.

### Q0 — the plan's own text: recommended to defer (V-14)

The document's decimal separator (L13, L14 and their mutants M-14d-d,
M-14d-e) is the costliest and riskiest part of 14d — an engine change,
schema 8, every committed encoding moved (F-14), a macOS re-baseline —
and the human asked for three UI languages, not for it. **New question
Q0: is `.` in the plan's own text (dimensions, room areas, rulers, the
PDF and PNG) acceptable for 0.1.0?** A restaurant plan's purpose is its
tables; dimensions and areas are the designer's.

- **Recommended: yes, defer.** 14d-1 then drops L13, L14, M-14d-d and
  M-14d-e; `FloorPlanController` gains no `locale`; the engine,
  `formatLength`, the rulers and every encoding stay as they are, and
  nothing is re-baselined. L12 reads: **panels follow the UI language;
  everything on the canvas and the paper keeps `.`.** The Area and
  Value rows, which echo stored text, show `.` in a German or Turkish UI
  (recorded, not a defect: they are the plan's text). The Dimension
  tool's notice is that stored text (`dimension_tool.dart:462`), so `.`
  too (V-16).
- **If the human answers no**, L13 and L14 apply as written, amended:
  L8 reads "the `.jetlib` *format* does not change; the bytes move only
  by L14"; L14's list of encodings is F-14's (the `pre_09c` fixtures are
  **not** regenerated: they become the v7-read fixtures); M-14d-e is
  restated as "`kSchemaVersion` is 8, and a v7 encoding decodes as
  `point`" (there is no v7 reader in the build, V-18); L14's rationale
  rests on F-14 (an old reader tolerates the field, so the bump is what
  makes it refuse); and the shell's New is `apps/floor_planner`'s
  `document_host.dart`, added to Files (V-21).

### 14d-1, amended

- **L1, amended (V-10).** The strings stay hand-written classes; a
  test-only `RecordingFloorPlanStrings implements FloorPlanStrings`
  forwards every member to a language and records each string it returns
  (the compiler keeps it complete). "A host can subclass a language" is
  L2's custom delegate (the undefined "H-1" is dropped, V-21).
- **L2, amended (V-4).** The lookup is the delegate's instance, else the
  built-in language for `Localizations.localeOf(context)` — the
  **resolved** locale — else English. Stated plainly: a `MaterialApp`
  resolves to one of its `supportedLocales` (default `[en_US]`), so a
  host gets German or Turkish only if it lists `de`/`tr` there, and it
  must then add `GlobalMaterialLocalizations` and its siblings or
  Material widgets throw. The host guide (P2) gives the exact
  `MaterialApp` lines; `floorPlanLocalizationsDelegates` (exported) lists
  the planner's delegate with Flutter's three. `Localizations.override`
  around the view alone is **not supported**: dialogs on the root
  navigator (Export) would not see it. The demo's switch sets
  `MaterialApp.locale` (L17).
- **L5, amended (V-16).** The status line's label comes from the palette
  map; the Symbol placement tool, which is no palette entry, is labelled
  by `FloorPlanStrings.symbolTool`; the service view has no status line.
  Notices become values the shell words: the Room tool's
  `'Already a room: …'` (cached in `_occupied`, `room_tool.dart:284`)
  becomes `RoomOccupied(name)`. "The placement ghost's notice" (L9) does
  not exist and is struck.
- **L6, amended (V-17).** `LayerNameProblem` keeps an English
  `toString()` for the engine's own `ArgumentError`s
  (`layer_commands.dart:168,294`). `Unnumbered` carries `symbolKey` and
  `seats` and no handle (D18), so two unnumbered tables of one symbol
  word alike — accepted; the host sees the count. The symbol panel's
  `'$error'` (`symbol_panel.dart:313`) becomes a worded failure, the
  exception going to `FlutterError.reportError` only (I-4).
  `apps/floor_planner/test/layers/layer_panel_test.dart:526,534` change
  with it.
- **I-3, amended (V-9).** Placement copies the **library's** `entry.name`
  — the asset's English text (`symbol_placer.dart:132`) — never the
  shown name; the stored names of L7 are the only language-bearing bytes.
- **L11, amended (V-20).** The fold maps `İ` and `I` to `i` **before**
  lower-casing, and folds `â î û` too (`Kâğıt`). Containment only, so
  `ß→ss` changing a length is harmless.
- **L15, amended (V-12).** iOS's `decimalPad` shows the **device
  region's** separator, not the app's, so a Turkish UI on an English iPad
  could never type a comma. A field therefore accepts its language's
  separator, **and** the other one when it occurs once and is not
  followed by exactly three digits: `1.5` is 1.5 in German, `1.600` is
  refused; `1,5` is 1.5 in English, `1,600` is refused. No grouping is
  ever accepted.

### 14d-2, amended

- **S2, amended (V-8).** An entry is also dropped unless `to`'s linear
  part equals `from`'s (exact `==`: a restore only translates, F-10) and
  all twelve values are finite; numbers are read as `(v as num).toDouble()`
  (the web writes `1` where the VM writes `1.0`, V-21). Duplicate handles
  make the text a `FormatException`. The result carries **counts and
  entries**, not bare numbers (a number may be `null` or shared). The
  entries are applied and the history cleared **before** the copy is
  attached, so flags and listeners see one settled copy.
- **S1, amended (V-21).** Determinism is per platform: the VM's and the
  web's encodings of one layout may differ in number form, and each reads
  the other's.
- **S4, replaced (V-2).** `revision` also moves on `setMode` and `load`
  (`floor_plan_controller.dart:340-365`), so a host saving on it would
  overwrite its stored layout with an empty one before it could restore.
  The controller gains **`Listenable serviceLayoutChanges`**, which fires
  after every change of the service layout that the host did not ask for
  by a mode switch or `load`: a drag, Undo or Redo in the selection mode,
  `resetLayout`, and `restoreServiceLayout`. It never fires on
  `setMode` or `load`. A host saves `serviceLayoutJson()` on it and
  restores after `setMode(selection)` and after a `load` in the
  selection mode. 14c S8 stands.
- **S9, amended (V-3).** With the layout kept by the host, the demo no
  longer discards it on the way to Design: its dialog *"Discard the
  service layout?"* is removed; leaving Service keeps the stored layout,
  entering Service restores it and logs the dropped entries; **Reset
  layout** is the one way to discard it. This amends 14b-2's demo
  behaviour ("the demo asks first", D12) and nothing of the controller:
  the design is never changed by service moves, as before.
- **S6, replaced (V-1, V-15).** The service view wraps its canvas in a
  `Listener` for the **secondary** button (mouse or stylus): on its
  down, it records the press; on its up within the touch slop, it picks
  through the copy's `TablePicker` at the up's world point (containment,
  no reach: a mouse) and, on a hit, applies S6's selection rule and calls
  `onTableContextMenu(number, event.position)` (already global). The
  render package is untouched. Settled cases:
  - modifiers held with the secondary button change nothing;
  - Ctrl+primary on macOS stays 14c's toggle, never a context click;
  - `onTableTap` never fires for a context gesture;
  - an **unnumbered** table is selected by S6's rule and not reported
    (D18);
  - the secondary press is ignored while a primary gesture or a touch
    session is live.
- **S7, amended (V-15, V-13).** Under `contextMenu`, the long-press
  timer also starts on a **locked** table (amending 14c R-1 and D14 for
  this mode only), which is reported without a selection change; the
  timer keeps 14t's touch value (`kLongPressTimeout - kTouchHoldBack`
  from contact, `table_select_tool.dart:80-82`); the position given is
  the tool's screen point converted by the view's render box.
- **S5, amended (V-15).** Under `serviceMoves: false` a drag from any
  table, locked or not, pans.

### 14d-3, amended

- **P1, amended (V-7).** `jet_cad_floor_plan` and
  `jet_cad_restaurant_symbols` go from `0.0.1` to `0.1.0`;
  `jet_cad_2d` and `jet_cad_2d_flutter` stay at `0.1.0`. No
  `publish_to` changes.
- **P4, amended (V-19).** CI's scope is the gates' packages and apps:
  `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_floor_plan`,
  `jet_cad_restaurant_symbols`, `apps/floor_planner`,
  `apps/restaurant_demo` (tests, analyze, format, web builds) and
  `apps/dev_harness_2d` (analyze). `packages/jet_cad` and
  `apps/dev_harness` are left out; the plan records why after checking
  their state.
- **P5, amended (V-6).** `expect_failures.dart` compares the **skipped**
  set exactly as the failing set, against `standing_skips.txt` beside
  `standing_failures.txt`; a skip whose reason is the VM service's
  absence is always red, so a runner without loopback cannot pass the
  allocation invariants by skipping them.
- **P6, amended (V-19).** The probe's git URL is the checked-out
  repository itself (`file://$GITHUB_WORKSPACE`) at `git rev-parse HEAD`
  — the commit CI is testing, merge commits included — so no token is
  needed for a private repository.

### Tests, amended

- **M-14d-a, replaced (V-10).** The leak test installs
  `RecordingFloorPlanStrings` over Turkish, pumps the shell and the
  service view with every panel, dialog and menu opened in turn (the
  Export dialog, the layer colour menu, the size menu, the page menus)
  and the selections of revision 1; then every `Text`, tooltip, label
  and hint in the tree must be a **recorded** string, document text, or
  on a short allowlist (digits and number text, unit symbols, `A4` `A3`
  `Letter` `Tabloid`, `PDF` `PNG`, shortcut letters and modifier glyphs).
  Fixture names (rooms, layers, numbers) are chosen never to collide with
  a UI word. Mutant: one label put back as a literal — it is never
  recorded, so it is red whatever its language.
- **M-14d-b, amended (V-4).** Tested through a `MaterialApp` with
  `floorPlanSupportedLocales` and `floorPlanLocalizationsDelegates`
  (German and Turkish resolved), with the delegate absent (the resolved
  locale still chooses), and with a default `MaterialApp` on a Turkish
  platform locale (English, documented).
- **M-14d-c, amended (V-11).** The mutant lengthens a label that sits in
  a `Row` without wrapping (a palette entry or the top bar); the
  existing 656 px sweep (`apps/floor_planner/test/document_commands_test.dart:986-1001`)
  runs in `de` and `tr` too.
- **M-14d-f, extended (V-12).** `1.5` in German is 1.5, `1.600` and
  `1.234,5` are refused; the English mirror; mutants: the foreign
  separator always refused (the iPad case); always accepted.
- **M-14d-g, amended (V-9).** From a **loaded** plan, with the same
  edits in English and in Turkish — a symbol placement, a room named
  explicitly, a layer named explicitly, a renumber, a table rotation —
  the encodings are byte-equal. Mutant: placement copying the shown
  name.
- **M-14d-l, extended (V-8).** Adds a table hidden in the design since,
  an entry whose `to` turns the table, a non-finite value, and duplicate
  handles (`FormatException`).
- **M-14d-m, replaced (V-13).** Cases that tell the mutants apart: a
  restore, then Undo → nothing changes and `serviceEdited` is true
  (mutant: history not cleared); a move dragged back exactly to its
  design place → `serviceEdited` false although the depth is 1 (mutant:
  by depth); a restore, a move and its Undo → true (mutant: by depth).
- **M-14d-n, amended (V-18).** The fixture moves tables in
  **descending** handle order to off-grid positions.
- **M-14d-p, amended (V-1).** Driven through `FloorPlanView` with
  `tester.tapAt(…, buttons: kSecondaryMouseButton)`, never by feeding the
  tool.
- **M-14d-q, extended (V-6).** A recorded run with an extra skip, and one
  with a VM-service skip → exit 1. Mutant: skips ignored.
- **New, M-14d-r (V-2).** `serviceLayoutChanges` fires on a drag, Undo,
  Redo, `resetLayout` and a restore, and never on `setMode` or `load`;
  the demo's start-up, a mode round trip and a `load` keep the stored
  layout. Mutant: the controller notifying on `setMode`.
- **New, M-14d-s (V-13).** The locale switched while mounted: the status
  line, an open tool notice, the Page panel and the palette's headers
  follow; the gallery's collapsed categories stay collapsed. Mutants:
  strings captured in `initState`; the collapsed set keyed by the shown
  name.
- **New, M-14d-t (V-13).** Each `LayerNameProblem` and each
  `NumberingWarning` is worded in all three languages; S1 returns `null`
  in the design mode; under S7 a finger's long press reports at 500 ms
  from contact.

### Questions for the human, now

- **Q0** (above): `.` in the plan's text for 0.1.0 — recommended yes.
- **Q1–Q4** stand; Q2 is moot if Q0 is yes. Q4's order stands
  (14d-2 → 14d-1 → 14d-3).
