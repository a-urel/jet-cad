# The plan's decimal separator (Q0) — design

**Date:** 2026-10-07. **Status:** design, **revision 2**. Revision 1
(`f17bf94`) was reviewed independently and came back *Approved with
fixes* (V-1 to V-19; see [Review](#review)). This text carries the fixes.

**Asked by the human:** *"Q0 ile devam et"* (2026-10-07). The 14d spec
deferred Q0, *"`.` in the plan's own text for 0.1.0"* (2026-10-06). This
spec takes up what was deferred:
[2026-10-06-pos-readiness-design.md](2026-10-06-pos-readiness-design.md)
L13, L14, M-14d-d and M-14d-e. 14d's Q0 section lists amendments for
"if the human answers no". This spec restates them against `main` at
`0ca8b64` and corrects them where the code has moved. Where it differs
from them, this spec is binding.

**Branch:** `claude/exciting-pasteur-9m22jv`. **Size:** M.

**Packages touched:**
- `jet_cad_2d`: the page's field, `formatLength`, schema 8.
- `jet_cad_2d_flutter`: the ruler.
- `jet_cad_floor_plan`: the formatters, `pageKey`, the Page panel, new
  plans, the controller and the view.
- `jet_cad_restaurant_symbols`: the asset's bytes.
- Both apps.
- The docs.

**Q2 is assumed, not asked.** Q2 asks whether a new plan's separator
follows the UI language. The 14d spec proposed yes. The human is away
and asked to be consulted only when necessary, so this spec takes the
proposal (**N1**). It is the one decision the human may overturn at the
look (R-3).

## Why

Since 14d-1, a German or Turkish terminal shows `,` in every panel. The
plan itself still prints `.`, on screen and on the PDF and PNG a
restaurant prints. That covers:
- the dimension text;
- the room area text;
- the rulers;
- the stored text the panels echo: the Area row, the Value row, and the
  Dimension tool's notice.

A plan should print the same way on every terminal. So the separator
belongs to the **document**, not to the terminal.

## Facts (at `0ca8b64`)

- **F-1. Three formatters, no others.**
  - `formatLength(double mm, DisplayUnit unit)` is in `jet_cad_2d`,
    `geometry/grid_scale.dart:113`.
    - Its only caller is the ruler (`ruler_painter.dart:102`), once per
      major tick per paint.
    - Nothing it returns is stored.
  - `formatDimension(double mm, DisplayUnit unit)` is at
    `dimension_geometry.dart:459`.
    - Its only caller is `layoutDimension` (`:417`).
    - The resulting `text` is stored as the dimension's generated TEXT
      child (`dimension.dart:208-218`).
    - It is also the Dimension tool's notice (`dimension_tool.dart:463`).
  - `formatArea(double mm2, DisplayUnit unit)` is at `room_label.dart:164`.
    - Its only caller is `RoomType.generate` (`room.dart:312`).
    - The result is stored as the room's second TEXT child.

  Which units print a decimal separator today (V-1):

  | Formatter | mm | cm | m | in | ft-in |
  |---|---|---|---|---|---|
  | `formatLength` | yes, trimmed | yes, trimmed | yes, trimmed | yes, trimmed (`_trim(mm / 25.4, 4)`) | no (fractions) |
  | `formatDimension` | no (an integer) | yes, always one decimal (`250.0`) | yes, always two (`2.50`) | no (fractions) | no (fractions) |
  | `formatArea` | yes, two (m²) | yes, two (m²) | yes, two (m²) | yes, two (ft²) | yes, two (ft²) |

  `formatLength`'s `_trim` decides whether to trim on `s.contains('.')`
  (`grid_scale.dart:121-126`).
- **F-2. The PDF and PNG carry no ruler.**
  - `exportPagePdf` paints the document through `DraftPainter`.
  - The rulers are screen chrome: `RulerFrame` is used once, at
    `planner_view.dart:186`.
  - So the only numbers on paper are the stored dimension and area texts.
    14d's "the rulers, and so the PDF and PNG" was wrong.
- **F-3. Regeneration follows `pageKey`.**
  - `RoomType.pageKey` (`room.dart:233-237`) and `DimensionType.pageKey`
    (`dimension.dart:158-162`) are both `(displayUnit, scaleDenominator)`.
  - `_pageSeeds` (`regeneration.dart:301-310`) regenerates every object of
    a type whose key differs before and after a change.
  - It runs only `if (before.page != after.page)` (`regeneration.dart:1000`),
    which is `PageComponent.==`.
  - The page's command and the regenerated texts make one history entry:
    `ParametricReplay` of one `CompoundCommand` (`:1054-1062`).
  - `PageNotifier` also skips notifications on `==`.
  - Only these two types read the page in `generate`.
- **F-4. The Page panel** (`page_panel.dart`) shows, in order:
  1. the title (`:153`);
  2. the sheet menu;
  3. orientation, a `SegmentedButton`;
  4. scale, a field;
  5. unit, a menu with no label;
  6. three check boxes;
  7. the *Paper* caption (`:257`) and the swatches.

  Every change goes through `_set(next)`, one
  `SetComponentCommand<PageComponent>`, so one undo step. The panel sits
  in the right column: a fixed 280 px inside a `SingleChildScrollView`
  (`planner_shell.dart:983-1012`).
- **F-5. The panels' separator** is `FloorPlanStrings.decimalSeparator`
  (`'.'` in en, `','` in de and tr). `formatPanelNumber` and
  `parsePanelNumber` (`l10n/number_text.dart`) use it. This spec does not
  touch the panels.
- **F-6. Where a plan is created:**

  | Site | Code | Is there a context? |
  |---|---|---|
  | `newDocument(measurer)` | `new_document.dart:41-47`; the page is `defaultPage()` (`:35`) | no |
  | the floor planner's **launch** document | `DocumentSession.untitled()` (`document_host.dart:64-67`), from a field of `_FloorPlannerAppState` (`main.dart:108`) | no: it is above the `MaterialApp`. That app sets no `locale:` and no resolution callback, so it resolves `WidgetsBinding.instance.platformDispatcher.locales` against `floorPlanSupportedLocales` through `basicLocaleListResolution` (Flutter `widgets/localizations.dart:785-787, 890-909`) |
  | the floor planner's **New** | `newFlow()` (`document_host.dart:427-433`) | yes |
  | the floor planner's **Open sample** | `startupPlan(measurer, strings:)` (`:437-444`); the page is attached before the rooms and dimensions (`startup_plan.dart:203-240`) | yes; it reads `FloorPlanStrings.of(context)` before its first `await` |
  | `FloorPlanController()` without `json`, and `newPlan()` | `floor_plan_controller.dart:94-115, 508-512` | no. Hosts make the controller in a field initializer read in `initState` (the guide and the probe, `host_probe/lib/main.dart:85-100`; the demo, `restaurant_demo/lib/main.dart:143-171`), where no locale can be read |
  | `PlannerShell`'s fallback | `planner_shell.dart:161-162` | not at that time |

  `FloorPlanView` (`host/floor_plan_view.dart`) is the widget through
  which a host shows a controller's plans. It has a context. It already
  re-targets on a controller swap (`didUpdateWidget`, `:147`).
- **F-7. The codec.**
  - `kSchemaVersion = 7`. A reader refuses any `version > kSchemaVersion`
    (`json_codec.dart:105-108`).
  - `PageComponent.fromJson` reads named keys and ignores unknown ones.
    It reads enums with `values.byName`, which throws an `ArgumentError`
    (`page_component.dart:204-211`).
  - So a 0.1.0 build would load a page that has a new field, drop the
    field, and regenerate the plan's texts with `.` on the next edit.
  - Service layouts have their own format and version
    (`service_layout.dart:14-17`) and are untouched.
- **F-8. Committed encodings at schema 7:**
  - `furniture.jetlib` and `restaurant.jetlib`;
  - the demo's `salon.json` and `teras.json`, which carry the 12 page keys;
  - the two `furniture_pre_09c.jetlib` fixtures, which are historical.

  Byte pins:
  - `furniture_library_test.dart:33` and `restaurant_library_test.dart:361`:
    each asset must equal its generator's output.
  - `sample_plans_test.dart:69-77`: each sample must equal the built text.
    `UPDATE_SAMPLES=1` rewrites them.

  Version pins:
  - `json_codec_test.dart:516, 586-587`;
  - `instance_style_codec_test.dart:81`;
  - `layer_header_test.dart:99, 104`.

  Two test names say "7": `layer_header_test.dart:98` and
  `json_codec_test.dart:514`. Neither is standing.

  The key list is pinned at `page_component_test.dart:41-53`.
- **F-9. `generate_document_test`'s two fingerprints** hash the whole
  encoding, which starts with `schemaVersion`. The generated document has
  no page. The values are macOS's, have not been re-baselined since 12b,
  and are standing failures on Linux. A version bump moves them; the test
  names do not change.
- **F-10. The host barrel** exports `FloorPlanStrings` but no document
  type. B1 (`barrel_test.dart:28-59`) pins its 28 names.
- **F-11. Docs that state today's limit:** `CHANGELOG.md:49-50` and
  `docs/host-guide.md:119-122, 439-440`. Stale comments:
  - `leak_test.dart:47-48` ("kept with `.` in every language (Q0)");
  - `room_label.dart:160-163` and `dimension_geometry.dart:440-442`
    ("`.` as the separator");
  - the `pageKey` docs at `room.dart:229-232` and `dimension.dart:154-157`.

## Decisions

### The document

- **E1. A `DecimalSeparator` enum** in `page_component.dart` has two
  values, `point` and `comma`; `char` returns `.` or `,`. `PageComponent`
  gains `decimalSeparator`, default `point`. The field goes into:
  - the constructor;
  - `copyWith`;
  - `==` (F-3: without it a change is invisible to regeneration);
  - `hashCode` (to keep the `==` contract);
  - `toString`;
  - `toJson`, as `'decimalSeparator': name`, the key in its alphabetical
    place;
  - `fromJson`, as an optional key. When the key is absent the value is
    `point`. An unknown name is refused through `values.byName`'s
    `ArgumentError`, as the sibling enums are (V-6). The hosts' paths
    already wrap any decoding error (`floor_plan_controller.dart:107-110`,
    `symbol_library.dart:125-128`).
- **E2. Schema 8.** `kSchemaVersion` becomes 8, with a history entry in
  the style of 6 and 7: *"8: `PageComponent.toJson` gained
  `decimalSeparator`; `fromJson` defaults it to `point` when absent, which
  is the whole of the v7→v8 migration. The bump exists for the reader"*
  (F-7).
  - **Consequence, stated in the host guide:** 0.1.0 cannot open a plan
    saved by this build. It refuses it and says why. A 0.1.0 plan opens
    here unchanged, as `point`.
  - **Regenerated:**
    - both `.jetlib` assets, by their generators;
    - the demo's samples, by `UPDATE_SAMPLES=1`.
  - **Not regenerated:** the `pre_09c` fixtures. They become v7-read
    fixtures.
  - **Re-pinned:** the version pins, the two test names, and the key list
    (F-8).
  - **Owed to the human:** a macOS re-baseline of F-9, as after 12b. On
    Linux nothing changes.

### The text

- **T1. The three formatters take the separator.** Each gains
  `{DecimalSeparator decimalSeparator = DecimalSeparator.point}`. The name
  is `decimalSeparator`, not `separator`: in this codebase `separator`
  means the room separator (V-16).
  - In every cell of F-1's table marked *yes*, the decimal point becomes
    `decimalSeparator.char`.
  - Nothing else changes: the digits, the rounding, the trimming and the
    units stay the same.
  - **`formatLength` decides on its trimming before it swaps the
    character.** Swapping first would print `2,500 cm` (V-9).
  - A `point` page's text stays byte for byte what it is today.
- **T2. The callers read the page.**
  - `layoutDimension` passes `page.decimalSeparator`.
  - `RoomType.generate` passes the page's separator.
  - `RulerPainter` passes `p.decimalSeparator`. It already reads that page
    on every paint.
- **T3. `pageKey` adds the separator.** Both keys become
  `(displayUnit, scaleDenominator, decimalSeparator)`. A change of
  separator then regenerates every room's and dimension's text **in the
  same undo step** as the page change (F-3). Undo restores the bytes. The
  two `pageKey` doc comments say so.
- **T4. The echoes follow on their own.**
  - The Area and Value rows show the stored text.
  - The Dimension tool's notice shows freshly laid-out text.
  - So all three show the document's separator, and the panels' own
    numbers keep the UI's (F-5). The two can differ on one screen, by
    design: a German terminal editing an English plan types `1,5` and
    reads `1.50`.
  - The rows' memos are cleared on every document change
    (`selection_panel.dart:244-249`). A test still pins them (M-Q0-h).

### The Page panel

- **P1. A *Decimal separator* control** comes after the unit menu: a
  caption above a `SegmentedButton<DecimalSeparator>`, styled like the
  orientation control.
  - Its segments read `1.5` and `1,5`. They are digits, the same in every
    language.
  - It has the key `page-decimal-separator`.
  - A change is `_set(page.copyWith(decimalSeparator: s))`: one command,
    one undo step.
  - It shows the page's value, never the UI's.
  - The caption is a new `FloorPlanStrings` member, `pageDecimalSeparator`:
    en *Decimal separator*, de *Dezimaltrennzeichen*, tr *Ondalık ayırıcı*.
  - `RecordingFloorPlanStrings` **records** it with
    `record(inner.pageDecimalSeparator)`, unlike `decimalSeparator`;
    otherwise the leak guards would report it (V-13).
  - The leak tests (LK1, LK2) open the Page panel. They run in Turkish
    only, which guards against a caption that bypasses the strings class
    in any language; PS3 pins the German word (corrected after Task 3's
    review: revision 2 said the leak test covered de and tr).
  - The overflow guards (OV-*, OV-H-*) pump the Page panel too. Inside a
    fixed 280 px scrolling column they cannot fail for this control, so no
    overflow test is added.

### New plans (N1, the assumed Q2)

- **N1. A new plan takes the UI language's separator.**
  `documentSeparatorFor(FloorPlanStrings strings)` returns `comma` when
  `strings.decimalSeparator == ','` and `point` otherwise. It lives in
  `jet_cad_floor_plan`'s l10n and is exported from `editor.dart`. At every
  site with a context it is applied to `FloorPlanStrings.of(context)`, so
  a host's own language class (its delegate) gets the separator its
  panels use.
  - `newDocument(measurer, {decimalSeparator = point})` and
    `defaultPage({decimalSeparator})` take it.
  - **New** in the floor planner reads `FloorPlanStrings.of(context)`
    **before** its first `await`, as Open sample does (V-17).
  - **Open sample.** `startupPlan` gains no parameter: it takes the
    separator from the `strings` it already receives.
  - **The floor planner's launch document** has no context (F-6). It
    takes the language from
    `basicLocaleListResolution(WidgetsBinding.instance.platformDispatcher.locales,
    floorPlanSupportedLocales)`, read through `FloorPlanStrings.forLocale`.
    That is exactly the resolution its `MaterialApp` performs (V-2).
    `DocumentSession.untitled` gains the separator as a parameter, and the
    app computes it.
  - **A controller's new plan is settled by the first view that shows
    it** (V-3, V-4, V-5). A controller cannot know the host's language,
    and a host cannot pass one at construction (F-6). So:
    - `FloorPlanView` reports `FloorPlanStrings.of(context)` to its
      controller through an `@internal` method, in
      `didChangeDependencies`, and again when the controller is swapped.
      The controller keeps the last language reported.
    - A plan the controller creates (by the constructor without `json`,
      or by `newPlan()`) is **unsettled** until a language is known.
      `newPlan()` uses the last language reported, so its plan is settled
      at once when a view has reported one. Otherwise the plan is
      `point` and unsettled.
    - When a language arrives and the designed plan is still unsettled
      **and untouched**, its page takes that language's separator. The
      plan stays as if it had been created so: no history, clean, no
      `serviceLayoutChanges`, no `revision` a host must act on beyond a
      redraw.
      - *Untouched* means no command since creation, no `designJson()`
        since creation, no `load`.
      - A plan touched first stays as it is (N2).
      - A service copy taken before that moment is not changed. It is a
        copy of an empty plan and holds no text.
    - **The host API does not change.** There is no new parameter and no
      new type, so B1 stands. The host guide says, in its words on
      creating a controller, that an empty plan takes the language of the
      view that first shows it.
  - **The demo** follows on its own: an area with no sample, shown in
    German, gets `comma`, and so does Revert after a switch to German.
    **The samples stay `point`**: they are data, like their names *Salon*
    and *Teras*.
  - **`PlannerShell`'s fallback**, and every other `newDocument` call made
    without the argument, stays `point`, the engine's default. The
    shell's fallback exists for tests.
- **N2. Nothing converts a plan that exists or has been touched.**
  Opening, loading or editing a plan never changes its separator,
  whatever the language. Only the Page panel does. 14d's I-3 holds as
  amended: a document's bytes never depend on the UI language, except
  for the names L7 stores once and the separator a new plan takes.

### Docs

- **D1. The CHANGELOG** gains an **Unreleased** section listing:
  - the separator;
  - schema 8 and its consequence (E2);
  - the new abstract member `FloorPlanStrings.pageDecimalSeparator`,
    which breaks a host class that `implements FloorPlanStrings` (V-15);
  - the empty plan's language (N1).
- **D2. The host guide.** Its known-limit text (F-11) is replaced by the
  behaviour and E2's consequence. No code block changes, so the probe and
  `check_guide` are untouched.
- **D3. The stale comments of F-11** are updated.
- **D4. No version bump, no tag.** A release is the human's word.

## Invariants

- **I-1.** The two allocation invariants stay untouched and green. The
  ruler, which neither invariant measures, still builds its labels at
  O(major ticks) per paint, as today (V-18).
- **I-2.** Draw order is ascending handle value. Regeneration rewrites
  existing TEXT children in place and adds or reorders no entity. The
  settling of an empty plan (N1) changes only its page.
- **I-3.** N2.
- **I-4.** A `point` page's encoding differs from today's only by the
  version and the new key. Every formatter's `point` output is today's,
  byte for byte.
- **I-5.** Stored-value comparisons are exact `==`: the page's `==` and
  the record equality of `pageKey`.

## Testing and named mutants

**Fixture rule.** No fixture may sit at a default, and every fixture must
show a separator:
- a page at **cm, 1:20** (1:50 is the default, V-7), its origin off zero;
- a room off the origin whose area has a nonzero fraction (for example
  12.37 m²);
- a dimension off the origin, turned, whose length has a nonzero
  fraction;
- the separator **`comma`**, against today's `point`;
- a UI language that **differs** from the page's separator wherever the
  UI could leak in (an English UI on a `comma` page, a German UI on a
  `point` page; V-11).

A fixture whose text has no decimal digit is degenerate, and so is one
whose only decimals are `.0` or `.00` where trimming applies.

- **M-Q0-a, the key left out.**
  - The test: switching the fixture's page to `comma` changes the room's
    area text and the dimension's text to their `,` forms in **one**
    history entry. Undo restores the encoding byte for byte; Redo gives
    the `,` texts again.
  - Mutants: the separator left out of `RoomType.pageKey`; out of
    `DimensionType.pageKey`; out of `PageComponent.==`.
- **M-Q0-b, a formatter that ignores it.**
  - The tests: every cell marked *yes* in F-1's table, under `comma`,
    asserts an exact string. They include `12,37 ft²` under `feetInches`,
    `2,5 cm` from 25 mm in `formatLength` (a trailing zero trimmed), and
    an `in` length. The cells marked *no* are unchanged. Under `point`,
    every output equals today's literals.
  - Mutants:
    - each formatter printing `.` always;
    - `formatLength` swapping before trimming (V-9).
- **M-Q0-c, the codec.**
  - The tests:
    - `kSchemaVersion == 8`, and an encoding says 8;
    - `comma` round-trips;
    - a v7 page without the key decodes as `point`;
    - an unknown name throws `ArgumentError`;
    - the key list includes `decimalSeparator`.
  - Mutants: the key not written; the key not read; `kSchemaVersion`
    left at 7.
- **M-Q0-d, the ruler.**
  - The tests: at a named zoom where the majors fall on 5 mm in cm
    (`0,5 cm`) and on 500 mm in m (`0,5 m`), a `comma` page paints that
    exact label; a `point` page paints `0.5 cm` (V-8).
  - Mutant: the ruler passing no separator.
- **M-Q0-e, new plans.**
  - The tests:
    - the floor planner's New, under de and under en: `comma` and
      `point`;
    - Open sample under tr: `comma`, with its area texts showing `,`;
    - the launch plan under system locales `[de_DE]` and `[fr_FR,
      de_DE]`: `comma`; under `[fr_FR]`: `point`; and in each case the
      separator `documentSeparatorFor(FloorPlanStrings.of(context))` gives
      under the app's `DocumentHost` (V-2);
    - a `FloorPlanController()` shown in a `FloorPlanView` under tr:
      `comma`;
    - its `newPlan()` after the app switches to en: `point`;
    - a controller whose plan was loaded, shown under tr: unchanged
      (N2);
    - a constructor plan whose `designJson()` was read before any view:
      `point` (N2);
    - the demo with no samples under de: `comma`; Revert after a switch
      to de: `comma`.
  - Mutants:
    - New always `point`;
    - `documentSeparatorFor` always `point`;
    - the launch plan reading `locales.first`;
    - the view not reporting (or not on a swap);
    - `newPlan()` ignoring the last language;
    - settling a touched plan.
- **M-Q0-f, the language leaking into a plan.**
  - The test: extend DT1 (`test/l10n/determinism_test.dart`) with a room
    drawn and a dimension moved, rather than adding a test (V-10).
  - Mutant: the panel or the shell setting the page's separator from the
    UI on open.
- **M-Q0-g, the control.**
  - The tests:
    - under an English UI on a `comma` page, the control shows `1,5`
      selected;
    - a tap on `1.5` executes one command, which Undo reverts;
    - an Undo made elsewhere moves the control.
  - Mutants: the control showing the UI's separator; the control bound to
    a constant.
- **M-Q0-h, the echoes** (V-12). On the fixture, with the room and then
  the dimension selected **across** the switch to `comma`:
  - the Area row and the Value row show `,`;
  - the Dimension tool's notice, on a `comma` page, shows `,`.

  Mutant: the rows' memo not cleared on a page change.

## Risks

- **R-1. Old builds.** A POS on 0.1.0 that receives a plan saved here
  refuses it. That is what the bump is for (E2), and the guide says so.
  The library assets move too, so a POS cannot mix this build's packages
  with 0.1.0's assets. They ship together under one git SHA, so this is
  already the rule.
- **R-2. The macOS fingerprints** move again. The re-baseline is owed, as
  after 12b.
- **R-3. N1 is assumed.** If the human prefers `point` always,
  `documentSeparatorFor` becomes a constant, the settling goes, and
  M-Q0-e's tests invert. The rest stands.
- **R-4. The settling is new machinery.** An empty plan changes its page
  once, after the first view's dependencies resolve. Its guards are
  *untouched* and *unsettled*, and they are mutated in M-Q0-e.

## Not in scope

- Grouping digits.
- A separator per dimension or per room.
- The panels' rules (14d L12/L15).
- Converting stored plans.
- Decimal feet-and-inches.
- A release.

## Review

Revision 1 (`f17bf94`) was reviewed independently: *Approved with fixes*.
No finding was critical.

| # | Finding | Disposition |
|---|---|---|
| V-1 important | F-1, T1 and M-Q0-b had imperial units wrong: `formatArea` prints ft² with two decimals, `formatLength` prints decimal inches, and `formatDimension` prints mm as an integer. | F-1's table; T1 and M-Q0-b follow it. |
| V-2 important | The launch resolution named a non-static accessor, and a `[de]`-only test could not kill `locales.first`. | The binding's dispatcher is named; `[fr_FR, de_DE]` is tested and tied to `DocumentHost`'s locale. |
| V-3 important | The demo's areas are built in `initState`, before any locale is known, so an empty area could not follow the language. | N1's settling by the first view; the demo test (no samples, de). |
| V-4 important | The guide's controller is a field read in `initState`, so `locale:` from a context cannot be written. | No `locale` API at all: the view reports its language, and the controller settles the empty plan. |
| V-5 important | `forLocale` ignores a host's own delegate. | The view reports `FloorPlanStrings.of(context)`, delegate included. |
| V-6 minor | The error type contradicted itself. | `byName`'s `ArgumentError`, as the siblings use. |
| V-7 minor | 1:50 is the default scale. | 1:20. |
| V-8 minor | Ruler majors at 10 or 20 mm print no fraction. | A named zoom with `0,5 cm` and `0,5 m`. |
| V-9 minor | Swapping before trimming prints `2,500 cm`. | T1's order; a named mutant. |
| V-10 minor | M-Q0-f repeated DT1. | DT1 extended. |
| V-11 minor | The control's likely mutant (the UI's separator) survived a fixture where UI and page agree. | The UI and the page differ. |
| V-12 minor | The echoes were claimed, not tested. | M-Q0-h. |
| V-13 minor | `RecordingFloorPlanStrings` must record the caption; the overflow guard cannot fail. | P1 says both. |
| V-14 minor | Stale comments. | F-11, D3. |
| V-15 minor | The CHANGELOG omitted the `FloorPlanStrings` member. | D1. |
| V-16 nit | `separator` already names the room separator. | `decimalSeparator`. |
| V-17 nit | New must read the language before its `await`. | N1. |
| V-18 nit | I-1 overclaimed "no allocation". | Reworded. |
| V-19 nit | The reason given for `hashCode`. | E1. |

Facts F-2 to F-11 were confirmed at the cited lines. F-4 lacked the title
and the *Paper* caption, and F-8 lacked the two test names. Both are now
listed.
