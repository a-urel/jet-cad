# Task 4 review: the planner wiring (D1, D4, D5 PlannerView, R-7, R-20)

**Reviewed:** `37a1797` against base `eba82d0`, in the detached worktree `.worktrees/dark-review`. Mutants ran in a scratch copy of that worktree (`scratchpad/review4/mut`), so they never touched a file the gates were reading.

**Verdict: Approved.** There are no blocking, major or minor findings, only three notes. I accept rulings R-C4-1 to R-C4-4.

## 1. Implementation against the spec and the plan

### PlannerView
- `chrome` and `paper` are required (`planner_view.dart:29-30`).
- All three `.light` placeholders are gone.
- `widget.chrome` reaches `RulerFrame` (`:177`) and `PageChromePainter` (`:237`).
- `widget.paper` reaches `PageChromePainter` (`:238`) and `SelectionOverlayPainter` (`:261`).
- PlannerView is constructed in only two places: `planner_shell.dart:897` and `service_view.dart:199`.

### PlannerShell and ServiceView (D4 mechanics, checked in both)
- **`_surfaceArgb`** is set in `didChangeDependencies` from `Theme.of(context).colorScheme.surface.toARGB32()` (`planner_shell.dart:214`, `service_view.dart:122`). Nothing else reads the theme for the paper.
- **`_paperArgb()`** is `_page.value?.background ?? _surfaceArgb` (`planner_shell.dart:193`, `service_view.dart:108`). It feeds both `foregroundFor`, in `_onPage` and `didChangeDependencies`, and `PaperPalette.forPaper` in `build` (`:910`, `:212`).
- **The resolver** is `late` plus `_hasResolver` (R-C4-3). The first `didChangeDependencies` assigns it. After that it is replaced only when `foregroundFor(_paperArgb())` differs from `_resolver.foreground`, both in `didChangeDependencies` and in `_onPage`.
  - `didChangeDependencies` does not call `setState`, which is correct: a `build` always follows.
  - `_onPage` calls `setState` on a flip, and that rebuild is what delivers the new paper palette.
  - The palette and the foreground cannot drift apart: `forPaper` keys on the same `foregroundFor`.
- **Nothing reads the resolver before the first `didChangeDependencies`.**
  - In the shell, `_resolver` is read only at `:206` (`_onPage`), `:218` (`didChangeDependencies`), `:900` and `:941` (`build`).
  - In ServiceView, it is read only at `:114`, `:125` and `:202`. Its `late final` fields (`_statusPainter`, `_tools`, `_parametric`, `_tableLabels`) never touch it.
  - `_page.addListener(_onPage)` runs in `initState`, and nothing can notify synchronously between it and `didChangeDependencies`. In ServiceView the `_page` notifier is created lazily at that `addListener`, after `_parametric` and `_tableLabels` are installed.
- **Palettes stay current after a page change.** `_onPage` re-derives the resolver from the page, and `build` recomputes `forPaper(_paperArgb())`. White to Ivory changes neither the foreground nor the palette, so no rebuild is needed. The test checks this.
- **Chrome** is `ChromePalette.of(theme.brightness)` in `build`, in both.

### Light theme on light paper is unchanged
- Light theme on White paper hands down `ChromePalette.light` and `PaperPalette.light`, the same values as Task 2's placeholders. `M-DT-1, M-DT-2: light theme, White paper` pins this through pixels plus `expectPainters`; the PV-dark mutant turns it red.
- **No page in the light theme:**
  - `premise` asserts `foregroundFor(lightTheme.colorScheme.surface) == 0x000000` with the real seed scheme (F-18 gives #F9F9FF).
  - `M-DT-10: no page in the light theme` asserts black ink (`0xFF000000` on the resolver, and a dark ink pixel) and the light selection set.

### Apps
- Both apps add `darkTheme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.dark)` and `themeMode: ThemeMode.system`, with the same seed as the light theme.
- **R-C4-4: accepted.** Each file holds its seed literal exactly once, as `const Color _seed`. That fits Task 6's (file, exact literal) allow-list (spec :362-376). In the demo, `Colors.teal` and the three status literals are unchanged.

### R-C4-1: the DraftCanvas repaint fix — accepted
The change: `_DraftCustomPainter.shouldRepaint` also answers true when `old.painter != painter` (`draft_canvas.dart:646`).

**(a) The painter is replaced only on a real prop change.**
- `painter` is assigned in one place, `_attach()` (`draft_canvas.dart:350`).
- `_attach()` runs only from `initState` (`:293`) and from `didUpdateWidget` (`:438`).
- `didUpdateWidget` calls it only when one of 11 props differs by `!=`/identity (`:424-434`): document, index, camera, resolver, pixelsPerPaperMm, lineweightScale, drawText, minTextCapPixels, backend, tiles, tileDevicePixels.
- An ordinary rebuild, a layout or a theme rebuild therefore keeps the same `painter`. With `resident` and the device pixel ratio unchanged, `shouldRepaint` stays false.
- Every DraftCanvas call site passes stable objects:
  - PlannerView (`planner_view.dart:246-252`) passes its widget fields. The shell's and the view's `_resolver` is a state field, replaced only on a flip.
  - The dev_harness call sites (`main.dart:1238`, `gpu_arm.dart:520/530/565`, `widget_arm_rig.dart:206`) build no inline resolver.
- Three tests witness this:
  - The new test's control arm re-pumps the same props and expects no extra paint (`draft_canvas_test.dart:141-142`).
  - The shell's M-DT-9 theme flip, which has a page, asserts `identical(canvas.painter, painter)` after the switch (`planner_palette_test.dart`, theme-switch test). Same painter, no re-attach and the same resident mean `shouldRepaint` returns false.
  - The mutant "a new resolver on every `didChangeDependencies`" is red on that identity assertion.
- A re-attach already rebuilds the sink, the painter and the caches. One extra repaint on that frame is the correct cost. Previously the retained picture showed the old drawing.

**(b) It allocates nothing.** It is an identity comparison inside `shouldRepaint`, which runs on rebuild, not per frame. Both allocation invariants are unedited and pass inside the render gate.

**(c) Existing repaint tests are not weakened.**
- `the painter never repaints per vsync` is unedited and green.
- `frame_accounting_test.dart` is unedited and green.
- My own mutant `shouldRepaint => true` is red on both `the painter never repaints per vsync` and the new test's control arm.
- `draft_canvas_test.dart` gained only additions (+32 -0).

**The alternative, keying DraftCanvas by the resolver,** would throw away the element and render object on every flip. It would fix only PlannerView and leave the same latent staleness for every other host and for `drawText` / `minTextCapPixels` changes. The fix at the cause is better.

### R-C4-2: M-DT-9's paper-flip premise — accepted
- `OutlineCache._onChange` (`outline_cache.dart:248-259`) calls `notifyListeners()` on every `DocChange` while `_world` is non-empty, that is, while something is selected.
- The cache is in the overlay's repaint merge (`planner_view.dart:113-119`). The page swatch is a `SetComponentCommand`, which produces a `DocChange`.
- So the spec's claim that only `shouldRepaint` can repaint the overlay is false for that fixture.
- **Verified by re-firing.** With the overlay's `shouldRepaint => false`, exactly two tests go red: the shell's no-page theme switch and ServiceView's no-page switch. Both paper-flip tests stay green. The mutant is killed, by the no-page theme switches.

## 2. Gates (re-run by me; `CI=true`, Flutter in `/home/user/flutter`; logs in `scratchpad/review4/gate-*.log`)

| Package | test | analyze | format |
|---|---|---|---|
| `jet_cad_2d_flutter` | `+1302 ~1 -7: Some tests failed.` The 7 are text_ladder rungs 1-5 and text_lod_ladder rungs 1-2 (RenderBackend.canvas), the standing set | No issues found! | 218 files (0 changed) |
| `jet_cad_floor_plan` | `+1187: All tests passed!` | No issues found! | 196 (0 changed) |
| `jet_cad_restaurant_symbols` | `+94: All tests passed!` | No issues found! | 13 (0 changed) |
| `apps/floor_planner` | `+201: All tests passed!` | No issues found! | 44 (0 changed) |
| `apps/restaurant_demo` | `+17: All tests passed!` | No issues found! | 3 (0 changed) |
| `apps/dev_harness_2d` | `+82: All tests passed!` | No issues found! | 22 (0 changed) |

All counts match the implementer's report exactly. I did not rebuild for web, as instructed.

## 3. Mutants (re-fired by me)
- **Method:** `scratchpad/review4/mut.py`. For each mutant it backs the file up, applies exact-string edits, runs the tests, copies the backup back and runs `diff -q`. Every mutant printed `restored diff=0`.
- **Logs:** `scratchpad/review4/<id>.log`, summarised in `mut-summary.txt`.
- **Suites:** T_SHELL is `test/planner_palette_test.dart`; T_HOST is `test/host/view_palette_test.dart`.

| Mutant | Ran | Result |
|---|---|---|
| PV-dark: every `widget.chrome`/`widget.paper` in PlannerView → `.dark` | T_SHELL | **red** `+3 -7` (light/White crossing among them) |
| M-DT-1: `forPaper` inverted | T_SHELL | **red** `+0 -10` |
| M-DT-2 (shell): `paper:` from `theme.brightness` | T_SHELL | **red** `+6 -4` (`Actual: <97>`: channel distance) |
| M-DT-2 (service): same | T_HOST | **red** `+3 -4` |
| M-DT-10 (shell): `_paperArgb` falls back to `0xFFFFFFFF` | T_SHELL | **red** `+8 -2` |
| M-DT-10 (service): same | T_HOST | **red** `+6 -1` (`Expected: <4294967295> Actual: <4278190080>`) |
| Shell: the resolver is not re-derived in `didChangeDependencies` (`if (_hasResolver) return;`) | T_SHELL | **red** `+9 -1` |
| Service: same | T_HOST | **red** `+6 -1` |
| M-DT-11 (service): `static PaperPalette? _sharedPaper` | T_HOST | **red** `+2 -5` |
| M-DT-11 (shell): same | T_HOST | **red** `+6 -1` |
| DraftCanvas fix reverted | render `draft_canvas_test.dart` + T_SHELL + T_HOST | **red**: render `+17 -1` (`Expected: <2> Actual: <1>`); planner `+15 -2` (both no-page switches, ink brightest 17) |
| Overlay `shouldRepaint => false` (R-C4-2) | T_SHELL + T_HOST | **red** `+15 -2`, only the two no-page switches. The paper-flip tests survive it, which confirms R-C4-2 |
| Shell: a new resolver on every `didChangeDependencies` (flip guard deleted) | T_SHELL | **red** `+9 -1` (painter identity: `Expected: true Actual: <false>`) |
| **Own A:** shell chrome from `MediaQuery.platformBrightnessOf` instead of the theme | T_SHELL | **red** `+7 -3` (`'0x2b2d31'` vs `'0xf2f2f2'`) |
| **Own A2:** same in ServiceView | T_HOST | **red** `+3 -4` (`'0x8a8a8a'` vs `'0x9e9e9e'`) |
| **Own B:** `_DraftCustomPainter.shouldRepaint` answers `true` (repaint on every rebuild) | render `draft_canvas_test.dart` + T_SHELL + T_HOST | **red** in render `+16 -2` (`never repaints per vsync` and the new control arm); the planner suites pass (they count no paints), so render is the witness |
| **Own C:** ServiceView `didChangeDependencies` derives the foreground from `_surfaceArgb`, ignoring the page | T_HOST | **red** `+3 -4` |
| **Own D:** shell `_surfaceArgb` frozen at the first `didChangeDependencies` | T_SHELL | **red** `+9 -1` |
| **Own E:** shell palette falls back to white while the ink uses the surface (split source) | T_SHELL | **red** `+8 -2` |
| **Own F:** ServiceView ink falls back to white while the palette uses the surface (split source) | T_HOST | **red** `+6 -1` |

All 20 are red, and none survives. Own E and Own F show that the ink and the selection set are pinned independently, so a split of `_paperArgb()` cannot pass.

## 4. Fixture quality
- **Seed scheme and theme switch:**
  - The schemes come from the real seed (`0xFF2266CC`), light and dark, at `themeAnimationDuration: Duration.zero`.
  - The theme switch re-pumps the same `MaterialApp` shape, so state survives.
  - Camera identity is asserted across the shell's M-DT-9 switch and ServiceView's switch.
  - Painter identity is asserted under a page.
- **Paper:** both White and Blueprint are crossed with both themes in the shell. ServiceView covers light/Blueprint, dark/White and dark/Blueprint, plus the two-view M-DT-11 harness in both modes. No-page is tested in both themes.
- **Camera:** y-up, off-origin, 0.125 px/mm. I checked the arithmetic:
  - tx = 40.5 − 875 = −834.5, so the sheet's left edge (x = 7000) lands at 40.5.
  - ty = 30.5 + 900 = 930.5, so the sheet's top (Y = 7200) lands at 30.5.
  - The selected line at Y = 4600 lands at 355.5 and the ink line at Y = 3904 at 442.5. Both are pixel centres, because 2600 = 325·8 and 3296 = 412·8.
  - The edge sample at area (40, 180) misses both lines, which start at x = 115.5.
  - The drawing area's top-left is asserted to be on whole pixels.
- **Assertion order:** pixels first, then the palettes held by the painters (`expectPainters`), so the page chrome's paper set is pinned despite the grid being off.
- No fixture is degenerate.

## 5. Untouched
- `git diff eba82d0..37a1797 --stat` on `packages/jet_cad_2d`, `*golden*`, `*invariants*` and `*analysis_options*` is empty.
- The Paint-identity tests are unedited.
- No `analysis_options.yaml` is committed. The only working-tree change is `packages/jet_cad/analysis_options.yaml`, rewritten by `pub get`.
- Existing tests are unedited: the only test change is +32 -0 in `draft_canvas_test.dart`.

## Notes (none blocking)
1. **note:** Some existing comments are now stale. They say `_DraftCustomPainter.shouldRepaint` is "unconditionally false":
   - `test/golden/dash_ladder_golden_test.dart:187`;
   - `text_ladder_golden_test.dart:420`;
   - `text_lod_ladder_golden_test.dart:286`;
   - `test/support/tile_comparison.dart:555`.

   They were already stale since the resident clause, and now a re-attach also repaints. The tests' behaviour is unaffected: the ladder pumps re-attach nothing, and `captureLive`'s key still forces a fresh element. The golden files are under the unedited constraint, so leave them. `tile_comparison.dart`'s comment could be refreshed in a later cleanup.
2. **note:** The two no-page theme-switch tests (shell and ServiceView) do not assert camera identity, unlike the page-present switches. The camera did not move there: the reverted-DraftCanvas mutant turns exactly those tests red, which could not happen if a camera move repainted the canvas. Adding `identical(camera.value, before)` would make that explicit.
3. **note:** The planner suites count no canvas paints, so "repaint on every rebuild" (Own B) is caught only by the render package's tests. That is sufficient, because `shouldRepaint` lives there.
