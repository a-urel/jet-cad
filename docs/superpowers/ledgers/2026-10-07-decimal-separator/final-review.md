# Q0 final review: the whole range `0ca8b64..f4afa58`

Reviewer: independent, wrote none of it. Clones at `f4afa58`: `/tmp/q0-final-review/repo` for the gates, `/tmp/q0-final-review/mut` for the mutants, `flutter pub get` at the root of each. I ran nothing in `/home/user/jet-cad`. This file is the only thing I wrote there. Both clones are clean afterwards (`git status --porcelain` empty).

## Verdict: **Approved with fixes**

The code is correct against E1, E2, T1 to T4, P1, N1, N2, I-1 to I-5 and D1 to D3. I found no defect in the code itself. The fixes are tests and doc wording:
- **F-1 (important):** the spec review's V-5 fix (the view reports `FloorPlanStrings.of(context)`, so a host's own delegate decides) is pinned by no test. Two plausible mutants survive every suite.
- **F-2 to F-4 (minor):** test gaps.
- **F-5 and F-6 (minor):** doc wording.
- **F-7 to F-11:** nits.

## Gates (run in the clone at `f4afa58`; actual summary lines)

| Package | test | analyze | format | `expect_failures.dart` |
|---|---|---|---|---|
| `jet_cad_2d` (`dart test`) | `00:29 +1253 -2: Some tests failed.` | `No issues found!` | `Formatted 169 files (0 changed)` | `packages/jet_cad_2d: 1255 tests; the standing failures and skips, exactly` (exit 0) |
| `jet_cad_2d_flutter` | `01:40 +1334 ~1 -7: Some tests failed.` | `No issues found! (ran in 8.7s)` | `Formatted 220 files (0 changed)` | `packages/jet_cad_2d_flutter: 1342 tests; the standing failures and skips, exactly` (exit 0) |
| `jet_cad_floor_plan` | `06:43 +1375: All tests passed!` | `No issues found! (ran in 11.4s)` | `Formatted 237 files (0 changed)` | `… 1375 tests; … exactly` (exit 0) |
| `jet_cad_restaurant_symbols` | `00:04 +97: All tests passed!` | `No issues found! (ran in 5.1s)` | `Formatted 15 files (0 changed)` | `… 97 tests; … exactly` (exit 0) |
| `apps/floor_planner` | `02:38 +212: All tests passed!` | `No issues found! (ran in 6.7s)` | `Formatted 47 files (0 changed)` | `… 212 tests; … exactly` (exit 0) |
| `apps/restaurant_demo` | `00:31 +37: All tests passed!` | `No issues found! (ran in 6.3s)` | `Formatted 4 files (0 changed)` | `… 37 tests; … exactly` (exit 0) |
| `tool/ci` (`dart test`) | `00:04 +32: All tests passed!` | | | |

- `git diff --stat 0ca8b64 f4afa58 | grep -c analysis_options` gives `0`.
- I did not run the web builds or the Chromium smoke test (plan Task 5).

## Verified across tasks (no finding)

- **Schema 8 and every decode path.**
  - `git grep '"schemaVersion"'` on committed data: both `.jetlib` assets and both demo samples are at 8; the two `pre_09c` fixtures stay at 7 and are read green.
  - No other committed encoding exists. The floor planner's open path, the controller's `load`, the service copy (`_copyOf`) and the symbol libraries all go through `DraftDocumentCodec`, which refuses only `> kSchemaVersion`.
  - The floor planner's `document_open_test` and the controller's future-version test use `kSchemaVersion + 1` or 9999, so they move with the bump.
  - 0.1.0 (`v0.1.0` = `22206f5`, the same `load` at `0ca8b64`:110) wraps the refusal as `FormatException('Not a floor plan: SchemaVersionError: unsupported schemaVersion 8 …')`. The CHANGELOG and guide claim "refuses and says why" is true.
- **The page is never rebuilt field by field.** `PageComponent(` appears in lib only as the defaults, `defaultPage`, `startupPage` and `fromJson`. Every other site is `copyWith`, so nothing drops the separator (sheet, unit, scale, Page panel, settling, `_copyOf`).
- **No other plan-text formatter.** `toStringAsFixed` in lib is only the three formatters plus the panel angle (UI separator, F-5) and the dev harness.
- **Settling (Task 4) × Page panel (Task 3) × regeneration (Task 2).**
  - The settling changes only the page of an empty plan (from `newDocument`), so it has no rooms and no dimensions, and `_pageSeeds` has nothing to regenerate.
  - A plan settled to `comma` generates every later room and dimension from the page: `pageKey` and `generate` read `page.decimalSeparator`.
  - The Page panel then shows the settled value (NS1 reads `{comma}`), and a tap is one command (PS1).
  - Undo across the settling: nothing to undo (the history was cleared on an untouched plan). The save point moved (NS1: an edit and its Undo end clean).
- **The service copy.** A copy taken before the settling keeps `point` and holds no text. `resetLayout`, `setMode` and `restoreServiceLayout` re-copy from the design. `serviceEdited` compares tables only (NS5).
- **Round-trips with `comma`.** Engine Q0-C2: encode, decode, identical bytes. The app's save and reopen and the controller's `designJson` → `load` share that codec and carry no separator-specific code. There is no app-level `comma` save/reopen test, but every plausible mutant lives in the codec and is killed there (Task 1 review).
- **I-1.** The only render change is `ruler_painter.dart:102-105`, per major tick. Neither invariant measures the ruler (`grep Ruler test/invariants` finds nothing). Nothing new is in `DraftPainter` or any painter loop.
- **I-2 and I-5.** The settling and regeneration add or reorder no entity. The page's `==` and `pageKey`'s record equality are exact.

## Mutants (mine; none was tried by a per-task review)

Each mutant was applied by script in `/tmp/q0-final-review/mut`, run, and restored. The restore was checked with `git status --porcelain` empty after each. "Targeted" means these suites:
- the planner's `test/host/new_plan_separator_test.dart`, `test/l10n/`, `page_panel_test`, `decimal_separator_test`, `room_label_test` and `dimension_format_test`;
- the floor planner's `document_separator_test`;
- the demo's `demo_test`.

Survivors were re-run on the **full** planner, floor planner and demo suites.

| # | Mutant | Result |
|---|---|---|
| A | `FloorPlanView` reports only on its first `didChangeDependencies` (a later language is never reported) | **red**: NS1 `new_plan_separator_test.dart:143` (Expected `point`, Actual `comma`); DQ2 `demo_test.dart:1210` |
| B | `documentSeparatorFor` keyed on `languageCode` (`de`/`tr` → comma) instead of `decimalSeparator == ','` | **survives**: full planner `05:03 +1375: All tests passed!`, floor planner `01:58 +212`, demo `00:26 +37` (F-1) |
| C | the view reports `FloorPlanStrings.forLocale(Localizations.maybeLocaleOf(context))` (both sites): a host's delegate is ignored, which is exactly V-5 | **survives**: full planner `05:10 +1375: All tests passed!`, floor planner `02:02 +212`, demo `00:27 +37` (F-1) |
| D | `_untouched` reads `_active` instead of `_design` | **red**: NS5 `:269` (Expected `comma`, Actual `point`) |
| E | `_replaceDesign` does not clear `_unsettledAt` on `load` (`if (unsettled) _unsettledAt = …`) | **survives** (targeted, `+60`, `+5`, `+35`). Equivalent today only by accident (F-4) |
| F | the Turkish caption reads `'Decimal separator'` (English in tr) | **survives**: full planner `05:00 +1375`, floor planner `+212`, demo `+37` (F-8) |
| G | the Dimension tool lays its preview out on the page forced to `point` | **red**: Q0-E2 and Q0-E3b (Expected `'345,7'`, Actual `'345.7'`) |
| J | `RoomType.generate` passes `point` for imperial units (`isImperial ? point : page.decimalSeparator`) | **survives**: full planner `04:53 +1375`, floor planner `+212`, demo `+37` (F-3) |
| K | `newPlan()` with nothing reported is settled (`unsettled: false`) | **survives**: full planner `04:41 +1375`, floor planner `+212`, demo `+37` (F-2) |
| R | the constructor's `json:` plan is unsettled (`unsettled: true`) | **red**: NS3 (Expected `point`, Actual `comma`), DT1 (`13.97 m²` vs `13,97 m²`), SE1, SE2 |

**Kill check for F-1's fix.** I ran the probe in F-1's fix (scratch, removed afterwards):

| Run | Result |
|---|---|
| unmutated | `00:02 +2: All tests passed!` |
| B | `+0 -2` |
| C | `+1 -1` (Actual `DecimalSeparator.point`) |

## Findings

**F-1 (important, test gap). A host's own language class is never exercised, so the spec review's V-5 fix is unpinned.**
- **What the spec requires:** N1 and V-5 say every site applies `documentSeparatorFor` to `FloorPlanStrings.of(context)`, "so a host's own language class (its delegate) gets the separator its panels use".
- **Evidence:** mutants B and C survive the full planner, floor planner and demo suites (table above).
  - C reverts V-5 exactly: the view reads `forLocale`.
  - B keys the separator on the language code.
  - Every M-Q0-e fixture uses a built-in language, so `of(context)` and `forLocale(locale)` agree, and so do `decimalSeparator` and `languageCode`. The fixture is degenerate for this property.
  - `floor_plan_view.dart:152` and `:161` and `document_separator.dart:14-17` are therefore unguarded.
- **Fix:** add to `new_plan_separator_test.dart`:
  1. A host class `_Fr extends FloorPlanStringsEn` with `languageCode 'fr'` and `decimalSeparator ','`, given by a `LocalizationsDelegate<FloorPlanStrings>` under `locale: Locale('fr')`, `supportedLocales: [Locale('fr')]` and Flutter's global delegates. A `FloorPlanController()` shown in a `FloorPlanView` is settled to `comma`.
  2. A unit check: `documentSeparatorFor(const _Fr()) == comma`.
  - My probe of exactly this passes on `f4afa58` and kills B and C (above).

**F-2 (minor, test gap). The "newPlan() with no language yet is unsettled" path is untested.**
- **What the spec requires:** N1 says a `newPlan()` with nothing reported is `point` *and unsettled*.
- **Evidence:** mutant K (`floor_plan_controller.dart:597`, `unsettled: reported == null` → `false`) survives every suite.
  - Under K, a host that calls `newPlan()` before its first view (for example a "start over" in `initState`, or a demo-style Revert of an unmounted area) keeps `point` forever under German or Turkish. That contradicts N1 and the guide.
- **Fix:** a test: `FloorPlanController()`, `newPlan()` before any view, then shown under `tr`. Expect `comma`, undoDepth 0, `dirty` false.

**F-3 (minor, test gap). The room's caller passes the separator in cm only.**
- **Evidence:** mutant J (`room.dart:315-316` drops the separator for imperial units) survives every suite.
  - `formatArea`'s ft² cells are pinned only at the formatter (Q0-RA1).
  - Q0-S1 and the echoes regenerate rooms at cm only, so the caller's argument is checked in one unit family.
- **Fix:** in Q0-S1 (or a sibling), set the fixture page to `feetInches` with `comma`, and assert the room's stored area text, `133,15 ft²` (12.37005 m²).

**F-4 (minor, robustness and test). The "unsettled" guard compares state ids across documents.**
- **Evidence:**
  - `UndoStack` ids are per stack, not global (`undo.dart:25-46`, `_state = ++_next` from 0).
  - Probe output: `PROBE ctor stateId=1 loaded stateId=0`.
  - So `_unsettledAt` (a state id of the constructor's document) is meaningful only for the document it was taken on. The code is correct today because `_replaceDesign` resets it (`floor_plan_controller.dart:605`).
  - Mutant E removes that reset and survives. It is not truly equivalent: constructor, then `load(json)` (state 0), then one edit before any view (state 1 == the stale mark, no redo), then a Turkish view. That converts the loaded plan to `comma` *and* clears the user's undo history (N2 and history loss).
- **Fix:**
  - Add that scenario as a test: expect `point`, undoDepth 1.
  - Optionally make the guard document-scoped, e.g. store `(DraftDocument, int)` and compare `identical(doc, _design.document)` too.

**F-5 (minor, docs). The host guide repeats the causal claim F-2 refuted, and puts N1 where N1 did not ask.**
- **Problem 1:** `docs/host-guide.md:121-122` reads "dimensions, room areas, the rulers, and so the PDF and PNG". Spec F-2 states that the PDF and PNG carry no ruler, and that 14d's "the rulers, and so the PDF and PNG" was wrong.
  - **Fix:** "dimensions and room areas (and so the PDF and PNG) and the rulers".
- **Problem 2:** N1 says the guide states the empty plan's language "in its words on creating a controller" (§ 4). It is in § 3 and § 11 only. § 5 (`:217`) still says only "`newPlan()` starts an empty plan."
  - Neither place says that `designJson()` or an edit before the first view fixes the plan at `.`. A host that seeds its store with `designJson()` in `initState` gets `.` forever under German. That is the controller's documented behaviour (`floor_plan_controller.dart:318-322`), but the guide does not say it.
  - **Fix:** one sentence after § 4's controller snippet, and the § 5 bullet extended: "…in the language of the view that last showed this controller; a plan read by `designJson()` or edited before any view keeps `.`".

**F-6 (minor, docs). `CHANGELOG.md:25-27` names only `implements`.**
- **Problem:** a class that directly `extends FloorPlanStrings` (abstract, abstract getter) breaks too.
- **Fix:** "a class that implements or directly extends `FloorPlanStrings` must add it". Optionally also list `newDocument(…, decimalSeparator:)` and `documentSeparatorFor` (`editor.dart`) if editor exports count as API here; the 0.1.0 section does not list editor exports, so this part is a nit.

**F-7 (nit, comment).** `schema_version.dart:34-37` says a v7 build would "regenerate the plan's texts with `.` on the next edit". It would regenerate only the objects that edit touches, so the plan's texts would mix `,` and `.`, and the next save would drop the key. That is a stronger reason for the bump.
- **Fix:** "…drop the separator, so the objects the next edit regenerates print `.` beside the others' `,`".

**F-8 (nit, test).** The Turkish caption is unpinned: mutant F (English text in tr) survives, because `RecordingFloorPlanStrings` records whatever the language returns. PS3 pins only the German word.
- **Fix:** run PS3's caption check under `tr` as well (`'Ondalık ayırıcı'`).

**F-9 (nit, I-1).** `_trim` (`grid_scale.dart:135`) now runs `replaceFirst` on every ruler label, a `point` one included. It returns a new string where the old code returned `s`. This is not on a measured path and stays O(major ticks), so I-1 holds.
- **Fix (optional):** `decimalSeparator == DecimalSeparator.point ? s : s.replaceFirst('.', …)`.

**F-10 (nit, report accuracy).** The Task 4 report says LK2's areas print `,` "Checked by a temporary print". That is consistent with the leak regex and with my R run (DT1). Nothing to fix; I note it so it is not counted as a test.

**F-11 (nit, coverage note).** No app-level test saves a `comma` plan through the floor planner and reopens it, nor does `designJson()` → `load` of a `comma` plan under an English UI (NS3 covers only `point` under Turkish). Both paths are the shared codec, whose mutants die in the engine. Optional: add the reverse direction of NS3 (a `comma` plan shown in English stays `comma`) for symmetry with N2.

## Disposition (controller)

- F-1: NS7 (a host's `_Fr` class through its own delegate gives comma)
  and NS7a (`documentSeparatorFor` by the class's separator). B
  (languageCode) red in NS7a, NS7; C (forLocale) red in NS7.
- F-2: NS8. K red.
- F-3: Q0-S2 (feet-and-inches, `133,15 ft²`). J red.
- F-4: the guard now keeps the plan with its state id (`_unsettled`, a
  record), compared by identity; NS9 (load, one edit, a Turkish view:
  point, the step kept). E alone is now equivalent by construction; E with
  the identity check removed is red in NS9.
- F-5: the guide's paper sentence corrected; §5's `newPlan()` bullet and
  the constructor's empty plan (keeps `.` if read or edited first).
- F-6: CHANGELOG "implements or directly extends".
- F-7: the schema comment says mixed texts.
- F-8: LB5 pins the three captions.
- F-9: `_trim` swaps only for comma.
- F-10, F-11: recorded, not changed.
