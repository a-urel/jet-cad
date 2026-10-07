# Task 3 review — the Page panel control (P1, M-Q0-g)

Reviewer: independent. Commit `0c7bfca`, checked out in a separate clone
(`/tmp/q0-t3-review/repo`); `/home/user/jet-cad` was not touched apart from
this file.

## Verdict: **Approved** (two minor findings, two nits; none blocks)

## What I ran (in the clone, `packages/jet_cad_floor_plan`)

| Command | Result |
|---|---|
| `flutter test test/page_panel_test.dart test/l10n/` | `00:35 +41: All tests passed!` |
| `flutter test test/l10n/overflow_test.dart` | `00:10 +5: All tests passed!` (OV-de, OV-tr, OV-H-en/de/tr) |
| `flutter analyze` | `No issues found!` |
| `dart format --output=none --set-exit-if-changed .` | `Formatted 235 files (0 changed)` |

The full suites and the apps' gates were not re-run (the report's claim stands unverified for those).

## Spec conformance (P1, F-4, F-5)

- The control sits after the unit menu and before the check boxes. It is a caption above a `SegmentedButton<DecimalSeparator>`, styled like the orientation control: default style, with keyed `Text` labels.
- The key is `page-decimal-separator`. The segments read `1.5` and `1,5` and are const, the same in every language.
- `selected: {page.decimalSeparator}` reads the notifier's page, never `_strings.decimalSeparator` (F-5).
- The change is `_set(page.copyWith(decimalSeparator: s.single))`: one command.
- Words match P1 verbatim: en *Decimal separator*, de *Dezimaltrennzeichen*, tr *Ondalık ayırıcı*.
  - The tr word reuses glossary L18's *Ayırıcı*, which tr uses for Separator, qualified by *Ondalık*. It is the term Excel TR uses, so it is consistent with the glossary.
  - The de word is the standard Windows/Excel term and does not collide with L18's *Trennlinie*.
- `RecordingFloorPlanStrings` records the getter (V-13).
- **Following Undo:** the build is a `ValueListenableBuilder` over `PageNotifier`, which refreshes on undo and redo. PS2 proves this with an undo and a redo made through `doc.commands`.
- **Fixtures** follow the fixture rule: cm, 1:20, origin (7350, −1230), and the UI differs from the page (en/comma, de/point). They are not degenerate.

## Mutants (applied in the clone, run, restored; `cmp` confirms restore)

| Mutant | Result |
|---|---|
| 1 `selected:` the UI's separator | RED: PS1, PS2, PS3 |
| 2 `selected: const {point}` | RED: PS1, PS2, PS3 |
| 3c writes the UI's separator | RED: PS3 |
| 4 recording getter forwards without `record` | RED: LK1, LK2 |
| R2 segment labels swapped (`point` labelled `1,5`) | RED: PS1, PS3 |
| R3 `_set` executed twice per change | RED: PS1, PS3 (undoDepth) |
| R4 panel writes the UI's separator on open (post-frame `_set`) | RED: PS1, PS2, PS3 |
| R5 caption shows `_strings.decimalSeparator` | RED: PS1, PS3 |
| R6 caption dropped | RED: PS1, PS3 |
| R1 caption moved above the orientation control (under the wrong control) | **SURVIVED** (see F2) |

## Findings

1. **Minor: spec P1 overstates the leak coverage. The implementer is confirmed right.**
   - **Evidence:** `recordingApp` pins `Locale('tr')` (`leak_test.dart:96`), and LK1 and LK2 build `RecordingFloorPlanStrings(const FloorPlanStringsTr())` (`:110`, `:187`). No leak run is in German.
   - **German is still adequately guarded:**
     - A bypass is a literal in code, which is language-independent. The Turkish run catches it: mutant 4 and the report's literal-caption mutant both go red there.
     - The only German-specific risk is a wrong or untranslated de value. PS3's `find.text('Dezimaltrennzeichen')` pins it.
   - **Fix:** make it a docs-only change in Task 5. Amend P1's line to: "LK1/LK2 (tr) cover the caption against bypass; PS3 pins the de word." No code change.

2. **Minor: the control's placement is unpinned.**
   - **Evidence:** R1 survived. Every assertion is a `find.text` or `find.byKey` count, so the caption or the control can sit anywhere in the panel. P1 requires "after the unit menu", with the caption above the control.
   - **Fix (optional, small):** in PS1, assert the vertical order with `tester.getRect`. The order is the bottom of `page-unit`, then the top of the caption, then `page-decimal-separator`, then `page-grid`. The caption must also be directly above the control. This kills R1.

3. **Nit: accessibility.**
   - **Evidence:** the segments' semantics read `label="1,5" selected=true button=true` (probed in de). This matches the orientation control, but the segment carries no reference to the caption. A screen reader user who lands on the segment hears only "1,5".
   - **Fix (optional):** `ButtonSegment(tooltip: _strings.pageDecimalSeparator, …)`. The getter is already recorded. Not required by the spec.

4. **Nit: the tests ignore the label keys.**
   - **Evidence:** PS1 and PS3 tap `find.text('1.5')` and `find.text('1,5')`. The keys `page-decimal-separator-point` and `-comma` are unused. The existing orientation test taps its key.
   - This is harmless, because the text taps are what kill R2.
   - **Fix:** none needed.

## Layout at 280 px (German)

- **How I checked it:** I probed `FloorPlanView` at 656×700 in en, de and tr.
- **Fit:** the right column is 280 px. The control is 256×48 in every language, the content width, and its labels are 42 px wide.
- **The caption wraps in the test font:**
  - In de, *Dezimaltrennzeichen* wraps to two lines (40 px against 20 px in en). This happens because the test font's glyphs are 14 px squares: 19 × 14 = 266 > 256.
  - With a real font it fits on one line.
  - Either way the column scrolls, and OV-de and OV-H-de pass with no exception.
- **No finding.** P1's claim that the overflow guards cannot fail for this control holds.

## Report claims checked

All the report's claims I checked match my runs:
- the mutant table (rows 1, 2, 3c and 4);
- the page panel is on screen in LK1 and LK2 (mutant 4 makes both red);
- the panel follows Undo;
- the gates for the planner tests, analyze and format.

The report says "Nothing is committed", but the work is in commit `0c7bfca`. It was presumably committed after the report was written. This is not a defect.

## Disposition (controller)

- 1: spec P1 corrected (LK1/LK2 run in Turkish; PS3 pins the German word).
- 2: fixed. PS1 asserts the order unit menu, caption, control, grid; the
  reviewer's surviving mutant (the caption above the orientation control)
  is red (`Expected: a value greater than or equal to <292.0>`).
- 3, 4: not changed (the orientation control reads the same way).
