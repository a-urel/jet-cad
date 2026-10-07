# The plan's decimal separator (Q0) — design

**Date:** 2026-10-07. **Status:** design, revision 1, for review.
**Asked by the human:** *"Q0 ile devam et"* (2026-10-07). The 14d spec
deferred this question (2026-10-06, Q0: *"`.` in the plan's own text for
0.1.0"*). The human now takes up the part 14d deferred:
[2026-10-06-pos-readiness-design.md](2026-10-06-pos-readiness-design.md)
L13, L14, M-14d-d and M-14d-e. Its Q0 section gives the amendments for
the case "the human answers no". This spec restates them against
`main` at `0ca8b64`, corrects them where the code has moved, and is
binding where it differs from them.

**Branch:** `claude/exciting-pasteur-9m22jv`. **Size:** M.
**Packages touched:**
- `jet_cad_2d`: the page's field, `formatLength`, schema 8;
- `jet_cad_2d_flutter`: the ruler;
- `jet_cad_floor_plan`: the formatters, `pageKey`, the Page panel, new plans, the controller;
- `jet_cad_restaurant_symbols`: the asset's bytes;
- both apps;
- the docs.

**The human's earlier answer to Q2 is assumed.** Q2 asked: "Should a new
plan's separator follow the UI language?" The 14d spec proposed yes, and
the human, away, asked not to be consulted unless necessary. This spec
takes the proposal (**N1**). It is the one decision the human may
overturn at the look, and overturning it costs one line per creation
site.

## Why

A German or Turkish terminal shows `,` in every panel since 14d-1. The
plan itself still prints `.` on screen and on the PDF and PNG a
restaurant prints, in three places:
- the dimension text;
- the room area text;
- the rulers' labels.

So does the stored text the panels echo:
- the Area row;
- the Value row;
- the Dimension tool's notice.

A plan should print one way on every terminal, so the separator belongs
to the **document**, not to the terminal.

## Facts (at `0ca8b64`)

- **F-1. Three formatters, no others.**
  - `formatLength(double mm, DisplayUnit unit)` (`jet_cad_2d`
    `geometry/grid_scale.dart:113`). It is called only by the ruler
    (`ruler_painter.dart:102`), per major tick per paint, and is never
    stored.
  - `formatDimension(double mm, DisplayUnit unit)`
    (`dimension_geometry.dart:459`). It is called only by
    `layoutDimension` (`:417`). Its `text` is stored as the dimension's
    generated TEXT child (`dimension.dart:208-218`). The same text is the
    Dimension tool's notice (`dimension_tool.dart:463`).
  - `formatArea(double mm2, DisplayUnit unit)` (`room_label.dart:164`).
    It is called only by `RoomType.generate` (`room.dart:312`) and stored
    as the room's second TEXT child.
  - How each formats:
    - cm always prints one decimal (`250.0`) and m always two (`2.50`);
      `formatArea` always prints two.
    - `formatLength` trims trailing zeros.
    - Feet-and-inches prints fractions and has no separator.
- **F-2. The PDF and PNG carry no ruler.** `exportPagePdf` paints the
  document through `DraftPainter`. The rulers are screen chrome
  (`RulerFrame`, used once, `planner_view.dart:186`). So the paper's
  numbers are the stored dimension and area texts only. (14d's "the
  rulers, and so the PDF and PNG" was wrong.)
- **F-3. Regeneration follows `pageKey`.**
  - `RoomType.pageKey` (`room.dart:233-237`) and `DimensionType.pageKey`
    (`dimension.dart:158-162`) are both `(displayUnit, scaleDenominator)`.
  - `_pageSeeds` (`regeneration.dart:301-310`) regenerates every object
    of a type whose key differs before and after.
  - That runs only `if (before.page != after.page)`
    (`regeneration.dart:1000`), i.e. by `PageComponent.==`.
  - The page's command and the regenerated texts are one history entry
    (`ParametricReplay` of one `CompoundCommand`, `:1054-1062`).
  - `PageNotifier` also skips on `==`.
- **F-4. The page panel** (`page_panel.dart`) is, in order:
  1. the sheet menu;
  2. orientation, a `SegmentedButton`;
  3. scale, a field;
  4. unit, a menu with no label;
  5. three check boxes;
  6. the paper swatches.

  Every change is `_set(next)`: one `SetComponentCommand<PageComponent>`,
  so one undo step.
- **F-5. The panels' separator** is `FloorPlanStrings.decimalSeparator`
  (`'.'` en, `','` de and tr). It is used by `formatPanelNumber` and
  `parsePanelNumber` (`l10n/number_text.dart`). Panels are not touched
  here.
- **F-6. Where a plan is created:**

  | Site | Code | A context? |
  |---|---|---|
  | `newDocument(measurer)` | `new_document.dart:41-47`, page `defaultPage()` (`:35`) | no |
  | the floor planner's **launch** document | `DocumentSession.untitled()` (`document_host.dart:64-67`), from a field of `_FloorPlannerAppState` (`main.dart:108`) | no: above the `MaterialApp`, which resolves the system's locales against `floorPlanSupportedLocales` (`main.dart:174`, no `locale:`) |
  | the floor planner's **New** | `newFlow()` (`document_host.dart:427-433`) | yes |
  | the floor planner's **Open sample** | `startupPlan(measurer, strings:)` (`:437-444`); the page is attached before the rooms and dimensions (`startup_plan.dart:203-240`) | yes, and it already reads `FloorPlanStrings.of(context)` |
  | `FloorPlanController()` without `json`, and `newPlan()` | `floor_plan_controller.dart:94-115, 508-512` | no locale |
  | `PlannerShell`'s fallback | `planner_shell.dart:161-162` | not at that time |
  | the demo's areas | `FloorPlanController(json: plans[name])` (`restaurant_demo/lib/main.dart:142-151`); `_revert` calls `newPlan()` (`:293-298`); the locale switches at run time through `MaterialApp.locale` (`:95`) | — |
- **F-7. The codec.**
  - `kSchemaVersion = 7`. A reader refuses `version > kSchemaVersion`
    (`json_codec.dart:105-108`).
  - `PageComponent.fromJson` reads named keys and ignores unknown ones.
    So a 0.1.0 build would load a page with a new field, drop it, and
    regenerate the plan's texts with `.` on the next edit.
- **F-8. Committed encodings at schema 7:**
  - `furniture.jetlib`;
  - `restaurant.jetlib`;
  - the demo's `salon.json` and `teras.json`, which carry the 12 page keys;
  - the two `furniture_pre_09c.jetlib` fixtures, which are historical.

  Byte pins:
  - `furniture_library_test.dart:33` and `restaurant_library_test.dart:361`:
    each asset equals its generator's output;
  - `sample_plans_test.dart:69-77`: the samples equal the built text;
    `UPDATE_SAMPLES=1` rewrites them.

  Version pins:
  - `json_codec_test.dart:516, 586-587`;
  - `instance_style_codec_test.dart:81`;
  - `layer_header_test.dart:99, 104`.

  Key-list pin: `page_component_test.dart:41-53`.
- **F-9. `generate_document_test`'s two fingerprints** hash the whole
  encoding, which starts with `schemaVersion`.
  - The generated document has no page.
  - The values are macOS's, not re-baselined since 12b, and are standing
    failures on Linux (`tool/ci/standing_failures.txt`).
  - A bump moves them; the test names do not change.
- **F-10. The host barrel** exports neither `PageComponent` nor any
  `DraftDocument` type. B1 (`barrel_test.dart:28-59`) pins its 28 names.
- **F-11. Docs that state today's limit:**
  - `CHANGELOG.md:49-50`;
  - `docs/host-guide.md:119-122, 439-440`.

## Decisions

### The document

- **E1. `DecimalSeparator`** is an enum in `page_component.dart` with two
  values, `point` and `comma`. Its `char` is `.` or `,`.
  `PageComponent` gains `decimalSeparator`, default `point`. The field
  joins:
  - the constructor;
  - `copyWith`;
  - `==` and `hashCode` (F-3: without them a change is invisible to
    regeneration);
  - `toJson`, as `'decimalSeparator': name`, the key in its alphabetical
    place;
  - `fromJson`, an optional key defaulting to `point`. An unknown name is
    a `FormatException`, as `displayUnit`'s is today through `byName`'s
    `ArgumentError`. **The plan decides whether to match today's error
    type exactly.**
- **E2. Schema 8.** `kSchemaVersion = 8`, with a history entry in the
  style of 6 and 7: "8: `PageComponent.toJson` gained `decimalSeparator`;
  `fromJson` defaults it to `point` when absent, which is the whole of
  the v7→v8 migration. The bump exists for the reader (F-7)".
  - **Consequence, stated for the host guide:** a plan saved by this
    build cannot be opened by 0.1.0, which refuses it and says why. A
    0.1.0 plan opens here unchanged, as `point`.
  - **Regenerated:**
    - both `.jetlib` assets, by their generators;
    - the demo's samples, by `UPDATE_SAMPLES=1`.
  - **Not regenerated:** the `pre_09c` fixtures, which become v7-read
    fixtures.
  - **Re-pinned:** the version and key-list pins (F-8).
  - **Owed to the human:** a macOS re-baseline of F-9, as after 12b. On
    Linux nothing changes: the same two names stay standing.

### The text

- **T1. The three formatters take the separator.** Each gains
  `{DecimalSeparator separator = DecimalSeparator.point}`:
  - `formatLength(mm, unit, {separator})`;
  - `formatDimension(mm, unit, {separator})`;
  - `formatArea(mm2, unit, {separator})`.

  The decimal point a unit prints becomes `separator.char`. Feet and
  inches print fractions and are unchanged. Nothing else changes: the
  digits, rounding and units stay as they are, so a `point` page's text
  is byte for byte today's.
- **T2. The callers read the page.**
  - `layoutDimension` passes `page.decimalSeparator`.
  - `RoomType.generate` passes the page's separator.
  - The ruler (`RulerPainter`) passes `p.decimalSeparator` from the page
    it already reads per paint.
- **T3. `pageKey` adds the separator.** Both types' keys become
  `(displayUnit, scaleDenominator, decimalSeparator)`. So a separator
  change regenerates every room's and dimension's text **in the same
  undo step** as the page change (F-3), and Undo restores the bytes.
- **T4. The echoes follow for free.** The Area and Value rows and the
  Dimension tool's notice show stored or freshly laid-out text, so they
  show the document's separator. The panels' own numbers keep the UI's
  (F-5). The two can differ on one screen, by design: a German terminal
  editing an English plan types `1,5` in a field and reads `1.50` on the
  plan. 14d's L12 stated this.

### The Page panel

- **P1. A Decimal separator control** sits after the unit menu: a caption
  above a `SegmentedButton<DecimalSeparator>`, styled like orientation.
  - Its two segments read `1.5` and `1,5`. They are digits, not words, so
    they stay the same in every language.
  - Key `page-decimal-separator`.
  - A change is `_set(page.copyWith(decimalSeparator: s))`: one command,
    one undo step.
  - The control shows the page's value.
  - The caption is a new `FloorPlanStrings` member,
    `pageDecimalSeparator`:
    - en *Decimal separator*;
    - de *Dezimaltrennzeichen*;
    - tr *Ondalık ayırıcı*.

    `RecordingFloorPlanStrings` forwards it. The leak and overflow guards
    (14d-1 LK2, OV-*) must cover the panel with the control on it; the
    plan says which tests already open the Page panel and adds it where
    none does.

### New plans (N1, the assumed Q2)

- **N1. A new plan takes the UI language's separator.**
  `documentSeparatorFor(FloorPlanStrings strings)` returns `comma` when
  `strings.decimalSeparator == ','`, else `point`. It is in
  `jet_cad_floor_plan`'s l10n and exported from `editor.dart`. A host's
  own language class thus gets the separator its panels use.
  - `newDocument(measurer, {DecimalSeparator separator = point})` and
    `defaultPage({separator})` take it.
  - **New** (floor planner) and **Open sample** (`startupPlan` gains no
    parameter: it reads the separator from the `strings` it already
    takes) use the language of the moment.
  - **The floor planner's launch document** has no context (F-6). It uses
    `basicLocaleListResolution(PlatformDispatcher.locales,
    floorPlanSupportedLocales)`, the resolution its `MaterialApp`
    performs. The language is then `FloorPlanStrings.forLocale`.
    `DocumentSession.untitled` gains the separator as a parameter; the
    app computes it. This assumes the app keeps no `locale:` and no
    resolution callback; a test pins that the launch plan under a German
    system locale is `comma`.
  - **`FloorPlanController`** gains `Locale? locale`, both as a
    constructor parameter and as a **settable field**: "the language of
    the plans this controller creates from now on". The constructor
    without `json` and `newPlan()` use
    `documentSeparatorFor(FloorPlanStrings.forLocale(locale))`. Null
    gives `point`.
    - It is a plain field, notifying nothing, because it affects no
      existing plan. A host whose language changes sets it.
    - No new type enters the host barrel (`Locale` is Flutter's), so B1
      is unchanged. The host guide shows the parameter.
  - **The demo** sets each area controller's `locale` from
    `Localizations.localeOf(context)` whenever its dependencies change.
    An area without a sample, and *Revert*, then give a plan in the
    demo's language. **The samples themselves stay `point`:** they are
    data, as their names *Salon* and *Teras* are.
  - **`PlannerShell`'s fallback** and every other `newDocument` call
    without the argument stay `point`. That is the engine's default; the
    shell's fallback exists for tests.
- **N2. Nothing converts an existing plan.** Opening a plan never changes
  its separator, whatever the language. Only the Page panel does. This
  is I-3 of 14d, restated: a document's bytes never depend on the UI
  language, except the names L7 stores once and the separator a new plan
  takes.

### Docs

- **D1.** Updates for the new behaviour:
  - The CHANGELOG gains an **Unreleased** section: the separator,
    schema 8 and its consequence (E2), and `FloorPlanController.locale`.
  - The host guide's known-limit text (F-11) is replaced by the new
    behaviour and E2's consequence. Its `FloorPlanController` example
    passes `locale:`; the probe (`tool/ci/host_probe/lib/main.dart`)
    carries the same lines, so `check_guide` stays green.
  - No version is bumped and no tag is cut: a release is the human's
    word.

## Invariants

- **I-1.** The two allocation invariants are untouched and green. The
  ruler builds one label string per major tick per paint, as today; the
  separator adds no allocation.
- **I-2.** Draw order is ascending handle value. Regeneration rewrites
  existing TEXT children in place; no entity is added or reordered.
- **I-3.** N2.
- **I-4.** A `point` page's encoding differs from today's only by the
  version and the new key. Every formatter's `point` output equals
  today's, byte for byte.
- **I-5.** Stored-value comparisons are exact `==`: the page's `==` and
  `pageKey`'s record equality.

## Testing and named mutants

**Fixture rule.** Every fixture must actually show a separator and must
not sit at a default:
- a page at **cm, 1:50, its origin off zero**;
- a room off the origin whose area has a nonzero fraction, e.g. 12.37 m²;
- a dimension off the origin, turned (not axis-aligned), of a length
  whose text has a nonzero fraction;
- for `formatLength`, inches as well as metric;
- the separator **`comma`**, against today's `point`.

A fixture whose text has no decimal digit, or only `.0`/`.00`, is
**degenerate**: a separator mutant leaves it unchanged.

- **M-Q0-a, the key left out.**
  - The test: switching the fixture page to `comma` changes the room's
    area text and the dimension's text to their `,` forms in **one**
    history entry. Undo restores the encoding byte for byte; redo gives
    the `,` texts again.
  - Mutants: the separator left out of `RoomType.pageKey`; out of
    `DimensionType.pageKey`; out of `PageComponent.==`.
- **M-Q0-b, a formatter that ignores it.**
  - The test: each formatter, under `comma`, in every unit that prints a
    decimal; feet-and-inches unchanged; under `point`, equal to today's
    literals.
  - Mutants: each of the three formatters printing `.` always.
- **M-Q0-c, the codec.**
  - The tests:
    - `kSchemaVersion == 8`, and an encoding says 8;
    - `comma` round-trips;
    - a v7 page without the key decodes as `point`;
    - a v8 page with an unknown name is refused;
    - the key list includes `decimalSeparator`.
  - Mutants:
    - the key not written;
    - the key not read (always `point`);
    - `kSchemaVersion` left at 7.
- **M-Q0-d, the ruler.**
  - The test: a ruler over a `comma` page in cm and in m paints a major
    label with `,`, read from the painted text as today's ruler tests do;
    a `point` page with `.`.
  - Mutant: the ruler passing no separator.
- **M-Q0-e, new plans.**
  - The tests:
    - the floor planner's New, under de and under en: `comma` and
      `point`;
    - Open sample under tr: `comma`, its area texts with `,`;
    - the launch plan under a German system locale: `comma`;
    - `FloorPlanController(locale: Locale('tr'))` and `newPlan()` after
      `locale = Locale('en')`: `comma`, then `point`;
    - the demo's Revert after a switch to German: `comma`.
  - Mutants:
    - New always `point`;
    - the controller's field read only at construction;
    - `documentSeparatorFor` returning `point` always;
    - the launch plan ignoring the system locale.
- **M-Q0-f, the language leaking into a plan.**
  - The test: a `point` plan opened in Turkish, edited (a room drawn, a
    dimension moved) and encoded equals the same edits in English, byte
    for byte.
  - Mutant: the shell or the panel setting the page's separator from the
    UI on open.
- **M-Q0-g, the control.**
  - The tests:
    - the Page panel shows the page's separator;
    - a tap on `1,5` executes one command, which Undo reverts;
    - a page changed elsewhere (Undo) moves the control.
  - Mutant: the control bound to a constant.
- The **leak test** covers the caption in de and tr, and the
  **overflow** tests cover the panel at the minimum window in German.
  Both are existing guards, extended if needed.

## Risks

- **R-1. Old builds and stored plans.** A POS on 0.1.0 that receives a
  plan saved here refuses it. This is the bump's purpose (E2), and the
  guide says so. The library assets move too, so **a POS cannot mix
  this build's packages with 0.1.0's assets**. They ship together by one
  git SHA, so that is already the rule.
- **R-2. The macOS fingerprints** move again; owed, as after 12b.
- **R-3. N1 is assumed.** If the human prefers `point` always,
  `documentSeparatorFor` becomes a constant and M-Q0-e's tests invert;
  the rest stands.

## Not in scope

- Grouping digits.
- A separator per dimension or per room.
- Changing the panels' rules (14d L12/L15).
- Converting stored plans.
- Localising feet-and-inches.
- A release (0.2.0), which is the human's word.
