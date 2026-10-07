# Plan Q0 — the plan's decimal separator

**Spec:** [2026-10-07-decimal-separator-design.md](../specs/2026-10-07-decimal-separator-design.md),
revision 2. It was reviewed independently and the fixes are applied.
Q2 is taken as proposed (N1).

**Started** on the human's *"Q0 ile devam et"* (2026-10-07).
**Branch:** `claude/exciting-pasteur-9m22jv`, from `main` at `0ca8b64`.
**Ledger:** `.superpowers/sdd/2026-10-07-decimal-separator/`.

## Global constraints

- `CLAUDE.md`'s non-negotiables apply. The two allocation invariants and
  the goldens stay untouched.
- **Every task ends green.** It runs the gates of every package it
  touches, plus those of every package whose tests read what it moved:
  - the engine: `dart test`, `dart analyze`, format;
  - the render package, the planner, the restaurant symbols, the floor
    planner and the demo: `flutter test`, `flutter analyze`, format;
  - `tool/ci`: `dart test`, when docs or standing lists move.

  The standing sets stay exactly as they are: engine 2, render 7 plus
  1 skip.
- **A `point` page prints today's bytes** (I-4). Every existing text
  literal in a test stays green unchanged. A test that has to change is a
  finding: record it.
- **Fixtures follow the spec's fixture rule:**
  - cm, 1:20, the origin off zero;
  - fractions that show the separator;
  - turned objects off the origin;
  - the UI language differing from the page.
- Each named mutant is applied, seen red, and reverted, and the result is
  recorded in the task's report.
- **Never `git checkout` a file to revert it.** Use
  `git show HEAD:path > path`.
- **Never commit an `analysis_options.yaml`.**

## Tasks

### Task 1 — the document and schema 8 (E1, E2)

**`jet_cad_2d`:**
- `DecimalSeparator` (`point`/`comma`, `char`) in `page_component.dart`,
  exported from the barrel.
- `PageComponent.decimalSeparator` in the constructor, `copyWith`, `==`,
  `hashCode`, `toString`, `toJson` (alphabetical) and `fromJson`
  (optional, `point`, `byName`).
- `kSchemaVersion = 8` with its history entry.
- The pins of spec F-8 re-pinned, the two test names included.

**Every committed v7 encoding the spec regenerates:**
- the furniture and restaurant `.jetlib`, by their generators (`tool/`);
- the demo's samples, with `UPDATE_SAMPLES=1`.

The `pre_09c` fixtures are not regenerated. Their tests must still pass,
because they are v7 reads.

**Tests:** M-Q0-c, plus the page's `==` and `copyWith` for the field.

**Gates:** engine, planner, restaurant symbols, demo, floor planner.

### Task 2 — the text (T1–T4)

- `formatLength` (engine), `formatDimension` and `formatArea` (planner)
  take `{decimalSeparator}`, per F-1's table.
- `layoutDimension`, `RoomType.generate` and `RulerPainter` pass the
  page's separator.
- Both `pageKey`s add the separator.
- The stale comments of spec F-11 are updated, except the leak test's,
  which Task 4 updates.

**Tests:** M-Q0-a, M-Q0-b, M-Q0-d, M-Q0-h, on the spec's fixture.

**Gates:** engine, render, planner, the apps.

### Task 3 — the Page panel control (P1)

- `FloorPlanStrings.pageDecimalSeparator`, in en, de and tr.
- `RecordingFloorPlanStrings` records it.
- The `SegmentedButton<DecimalSeparator>` (`page-decimal-separator`)
  after the unit menu, with its caption.
- Confirm that LK2 opens the Page panel. If it does not, open it.

**Tests:** M-Q0-g.

**Gates:** planner, the apps.

### Task 4 — new plans (N1, N2)

**`documentSeparatorFor(FloorPlanStrings)`:**
- in `lib/src/l10n/`;
- exported from `editor.dart`.

**`newDocument` and `defaultPage`** take `{decimalSeparator}`.

**The floor planner:**
- New: the strings are read before the `await`.
- Open sample: the separator comes from `startupPlan`'s strings.
- The launch document:
  - its language comes from `basicLocaleListResolution` over the binding
    dispatcher's locales and `floorPlanSupportedLocales`;
  - `DocumentSession.untitled` takes the separator.

**The controller and the view (the settling):**
- `FloorPlanView` reports `FloorPlanStrings.of(context)` in
  `didChangeDependencies` and on a controller swap. This goes through an
  `@internal` controller method.
- The controller keeps the last language reported. `newPlan()` uses it.
- The constructor's plan, and a `newPlan()` made before any report, are
  unsettled.
- A report settles an unsettled, untouched designed plan:
  - The page takes the separator.
  - No history is left, the plan is clean, and nothing goes out on
    `serviceLayoutChanges`.
- *Untouched* is cleared by:
  - any command;
  - `designJson()`;
  - `load`;
  - `restoreServiceLayout`, if it reaches the design. Check this.
- No new host API, so B1 stands.

**The demo:** nothing in the code, unless a test shows otherwise. Its
tests do change: no samples under de, and Revert after a switch.

**The leak test's comment** is updated (`leak_test.dart:47-48`).

**Tests:** M-Q0-e, and M-Q0-f (DT1 extended).

**Gates:** planner, the apps, render (untouched; run if any shared test
helper moved).

### Task 5 — docs and the exit

- The CHANGELOG's Unreleased section (D1).
- The host guide (D2):
  - its known-limit text;
  - E2's consequence;
  - the empty plan's language.
- `tool/ci` tests: run them. `check_guide` must stay green.
- Every gate, including `tool/ci`.
- The web build of both apps.
- A Chromium smoke test of the floor planner in German: New, a room, the
  separator switched.
- The results note `docs/superpowers/notes/2026-10-07-decimal-separator-results.md`:
  - the mutants;
  - the gates;
  - what was found;
  - what is owed: the macOS re-baseline, the human's look, the Q2
    ruling.
- STATUS; the roadmap's Status table, if it names 14d's Q0.

Then an independent code review of the whole range, its fixes, and the
merge on the human's word.

## Exit gate

- Task 5 green, and every named mutant red.
- The independent review applied.
- Owed to the human:
  - the Q2 ruling (N1);
  - the macOS fingerprints (R-2);
  - a look in German and Turkish.
