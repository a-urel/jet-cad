# Slice 3: the final review's fixes (F-1 to F-4)

- **Range:** `6fb7a6d..9eb8434` on `claude/exciting-pasteur-9m22jv`, pushed.
- **Environment:** Flutter `/root/sdk/flutter/bin` (3.47.6), `CI=true`, in `/home/user/jet-cad` (no clone).
- **Scratch:** `scratchpad/s3-final-fix/`: `mut.py`, `mut.log`, `p1mut.py`, `run-*.json`, `gates.sh`, `gates/`.
- **No existing test edited.** The removed lines in `git diff 6fb7a6d 9eb8434 -- '**/test/**'` are 2 of Slice 3's own test files only:
  - their header comments, which now name the new tests;
  - `theme_service_test.dart`'s import of `theme_canvas_test.dart` gains `withExtension` in its `show`.
- **No `lib/` change.** No `analysis_options.yaml` committed. STATUS, the results note and the roadmap are untouched (F-5 is the controller's).

| SHA | Commit |
|---|---|
| `237a28e` | F-2, F-3: the four probes and P1 as committed tests |
| `9eb8434` | F-1, F-4: the CHANGELOG bullet and the guide's sentence |

## F-1: the CHANGELOG (docs)

One bullet after the `jet_cad_2d_flutter` Slice 3 bullet in Unreleased:

> `jet_cad_floor_plan`'s `editor.dart`: `PlannerView.selectionStrokePixels`
> (default `kSelectionStrokePixels`); and a `PlannerShell` with no
> `FloorPlanView` above it follows the ambient `FloorPlanTheme`'s
> `selectionOnLight`, `selectionOnDark`, `selectionWidth` and
> `canvasBackground`, and throws an `ArgumentError` naming the field for
> an ambient look out of range.

**Checked against the code:**
- `FloorPlanThemeScope.of` with no scope validates the whole ambient extension (`floor_plan_theme.dart:451-453`), hence "an ambient look out of range".
- `planner_shell.dart` reads `canvasBackground` (`:278`), `selectionWidth` (`:1017`) and the selection colours through `paperPaletteFor`.

## F-2: four behaviours pinned (tests)

| Probe | Landed as | File |
|---|---|---|
| Q1 (P6) | "a full view theme removed at runtime restores today's pixels exactly, at {1.0, 0.32} x the look camera's scale …" (2 tests) | `test/host/theme_service_test.dart` |
| P5 | "the bar (T-1, S-10) a runtime change that shrinks the bar, 60 -> 44, then design: a table keeps its global position (S-10 both ways)" | `test/host/theme_service_test.dart` |
| Q2 and P7 | "the guide ({design, selection}): a translucent canvasBackground (0x40000000) on a page-less plan under the light theme: the ink is chosen on its RGB …" (2 tests) | `test/host/theme_canvas_test.dart` |

**Q1, removing the theme:**
- **The scene:** the look fixture with three captioned statuses (Bill, a dark one, a light one), the labelled group G7 and a focus on 20.
- **The setup:** it runs through the file's `pumpHost`, at the probe's cameras (the look camera scaled about the origin, shifted 300 px).
- **The comparison:** it compares the whole 1440×900 window after the host sets `theme` from `fullTheme` to null against a fresh view that never had a theme.
- **The premise the probe lacked:** under the theme, more than 1000 pixels differ from the fresh capture.

**P5, the shrinking bar.** It adds two premises: the canvas starts at (0, 44), and the plan moved up 16 px with it.

**Q2 and P7, the translucent canvas.** They are one test per mode, on the palette fixture's page-less plan rather than the zone fixture. Each checks:
- **Premises:** the colour's RGB inks white; composited over the light surface it would ink black.
- **The palettes:** `PlannerView.paper` and the selection overlay's `paper` are `identical` to `PaperPalette.dark`.
- **In pixels:** the ink witness is light and the selection is the dark set's.

**Mutants.** The reviewer's definitions (`rv-s3-final/mutants.py`) were applied in `/home/user/jet-cad` by `s3-final-fix/mut.py`, for each mutant in turn:
1. copy the file aside;
2. write the mutant, asserting exactly one match;
3. run both edited test files (38 tests, `--enable-vmservice`);
4. restore the file from the copy;
5. `filecmp.cmp(shallow=False)`.

Every restore read "cmp identical: True", and `git status` afterwards showed only the two test files.

| Mutant | Result | Killers |
|---|---|---|
| F03 `_captionSize` sticky | **red** 1/38 | the theme removed, at 0.32× |
| F05 `_chipBottom` sticky | **red** 2/38 | the theme removed, at 1.0× and 0.32× |
| F06 the bar re-measured only when it grows | **red** 1/38 | the shrinking bar, 60 -> 44 |
| F15 a translucent canvas composited over `surface` | **red** 1/38 | the guide (selection): the translucent canvas |

F15 lives in `ServiceView`, so only the selection-mode instance kills it. The design-mode instance (P7) pins the guide's claim on the editor's path.

## F-3: an animated switch through Task 3's painters (test)

P1 is landed in `theme_service_test.dart` as "an animated switch (easeOutBack) from the light theme with a full theme to the dark one with another, and back: …".

**The setup:**
- `MaterialApp` with `themeAnimationCurve: Curves.easeOutBack`, the light theme carrying `fullTheme` and the dark one `otherFullTheme`. `otherFullTheme` is a new constant in the file with every field different from `fullTheme`.
- The look fixture in the selection mode, with captioned statuses, G7 labelled and a focus.
- A counting `tableOverlayBuilder`; the home widget is one instance across pumps.

**The checks:**
- **Each switch** (light to dark, then dark to light) runs 30 frames of 10 ms. On each frame there is no exception, and each of the four layers' `debugRebuilds` and the veil's `debugRecolours` rise by at most 1.
- **The premise:** more than 5 rebuild frames per switch.
- **Afterwards:** ten pans leave every counter unchanged, and the overlay builder is never called again.

**A named mutation (not unique, as the review found):** in `table_status_painter.dart`, `_themeBuilt = look;` becomes `_themeBuilt = null;`, so the painter rebuilds on every paint under a theme. This test goes red on "pans rebuild nothing" (`s3-final-fix/p1mut.py`). The file was restored and `cmp` read identical.

## F-4: the guide's sentence (docs)

§ 9, "An animated switch", now reads:

> An extension only the new theme has applies one frame later, from the switch's second frame (its first frame is t = 0, still the old theme); one only the old theme has stays until the switch ends.

The paragraph is rewrapped; no code block moved.

## Gates (my runs on the final tree, before the commits; logs in `s3-final-fix/gates/`)

| Package | Tests | Standing comparison | Analyze | Format |
|---|---|---|---|---|
| `packages/jet_cad_floor_plan` | `flutter test --enable-vmservice`: "05:11 +1692: All tests passed!" | "packages/jet_cad_floor_plan: 1692 tests; the standing failures and skips, exactly" | No issues found! | 264 files (0 changed) |
| `apps/restaurant_demo` | "+60: All tests passed!" | "60 tests; … exactly" | No issues found! | 8 files (0 changed) |
| `apps/floor_planner` | "+212: All tests passed!" | "212 tests; … exactly" | No issues found! | 47 files (0 changed) |
| `packages/jet_cad_2d` | "00:21 +1256 -2: Some tests failed." | "packages/jet_cad_2d: 1258 tests; … exactly" | `--fatal-infos`: No issues found! | 170 files (0 changed) |
| `packages/jet_cad_2d_flutter` | "01:13 +1382 ~1 -7: Some tests failed." | "packages/jet_cad_2d_flutter: 1390 tests; … exactly" | No issues found! | 225 files (0 changed) |
| `packages/jet_cad_2d_gpu` | "+20: All tests passed!" | "20 tests; … exactly" | No issues found! | 10 files (0 changed) |
| `packages/jet_cad_restaurant_symbols` | "+97: All tests passed!" | "97 tests; … exactly" | No issues found! | 15 files (0 changed) |
| `tool/ci` | `dart test` "+63: All tests passed!"; `check_guide`: "docs/host-guide.md: all 37 code blocks are in the host probe" | — | `--fatal-infos` over CI's list: No issues found! | CI's list with `host_probe/lib`: 11 files (0 changed) |

- **The planner's count:** 1692 is the review's 1686 plus the 6 new tests.
- **The engine and render runs:** their failures are the standing ones, and the comparison is exact.
- **The tree:** after the gates, `git status` listed only the four files these commits touch.
- **`build/` directories:** all predate this session, so none was removed.
