# Task 6 review: the widgets (D9a-D9d; M-DT-14..18, the panel sweep)

Reviewer: independent. Worktree `.worktrees/dark-review`, detached at `4f324f9`. Diff `1fab9a9..4f324f9`: 5 files, +768 -3.

## Verdict: Needs fixes (1 minor finding, test-only; everything else holds)

The production change is correct and small. Every named mutant I re-fired is red, and 9 of my own 11 mutants are red. The two survivors are limits of the spec's own regex and allow-list design, not implementation defects (see the notes). The one finding is a gap in the panel sweep's coverage.

## Findings

1. **minor: the panel sweep does not cover `apps/restaurant_demo`'s own UI under the dark theme.**
   - **Where:** `packages/jet_cad_floor_plan/test/widget_theme_test.dart:371-469`. `apps/restaurant_demo/test/demo_test.dart` has no dark-theme pump either: grep finds no `ThemeMode`, `platformBrightness` or `darkTheme` there.
   - **Spec:** D9's "In scope" lists "`apps/restaurant_demo`'s own UI". The sweep reads "Every panel in D9's list is pumped under the dark theme and paints without an exception."
   - **Current coverage:**
     - The scan (D9a) covers the demo's source.
     - Nothing pumps `RestaurantDemo`, or its discard dialog, at `Brightness.dark`.
     - The demo uses `themeMode: ThemeMode.system`, so a test needs `tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark`.
   - **Fix (test-only, about 15 lines):** add one smoke test in `apps/restaurant_demo/test/demo_test.dart`:
     1. Set the platform brightness to dark and pump the demo.
     2. Toggle into the service, set statuses, and return to design through the discard dialog.
     3. After each step, assert `tester.takeException()` is null and that `Theme.of(..).brightness == Brightness.dark` under `DemoHome`, so the test really runs dark.
   - Task 7's Chromium smoke is no substitute: it is not a gate.

## Notes (no fix required)

- **N1: a duplicate of an allowed literal in its own file is allowed silently** (my mutant `OWN_dup_white_vertices` survives).
  - **The mutant:** a second `final Paint _other = Paint()..color = const Color(0xFFFFFFFF);` in `vertices_draw_sink.dart`. The scan stays green (`+3: All tests passed!`).
  - **Why this meets the spec:** a (file, exact literal) pair cannot tell two equal literals apart, by construction. The spec's "a second literal in the same file still goes red" reads naturally as a *different* literal, and that does go red (the self-test, and my `OWN_tealAccent_demo`). `layer_row.dart` legitimately has two occurrences (`:200`, `:258`), so any count rule would need per-entry counts.
  - **Risk: low.** The duplicate would have to be white, in the vertex sink or page export, or a second seed in an app's `main.dart`.
  - **Optional hardening:** an expected occurrence count per pair (`layer_row` 2, the others 1), with a mismatch reported like a stale entry.
- **N2: a literal split across lines evades the spec's regex** (`OWN_multiline_literal`, `color: const Color(\n 0x00123456),` in `tool_palette.dart`, survives).
  - The cause is `\bColor\(0[xX]`, verbatim from the spec.
  - In practice `dart format` (a gate) joins such a split whenever the line fits, so only a literal at the end of a long line could stay split.
  - `Color.from(alpha:..)` and `CupertinoColors.x` are also outside the three patterns.
  - These are spec-level; if wanted, record them as debt in the Task 7 results note.
- **N3: the scan's self-test is coupled to the real tree being clean.** Under every real-file mutant (M-DT-14, `Colors.red` in an app, and others) the self-test goes red as well as the M-DT-14 test (`+1 -2`), because its premise scans the real tree. This makes failures redundant, not wrong. Acceptable.
- **N4: `widget_theme_test.dart:36` imports another test file** (`host/status_caption_test.dart show pumpService, statusController`). It works, and `show` keeps it narrow. Moving the two helpers to `test/support/` would be tidier. This is cosmetic.

## Spec and plan check, line by line

**D9b**
- `SymbolGallery` gains `required int selectedForeground`, threaded to `_Cell`.
- `_Cell` hands `_Thumbnail` `selected ? selectedForeground : foreground` (`symbol_gallery.dart:271-273`).
- `SymbolPanel` passes `foregroundFor(scheme.primaryContainer.toARGB32() & 0xFFFFFF)`, computed in `_ready` (a builder inside `build`), so no caching is possible.
- **Light pixels are unchanged.** The premise test asserts `foregroundFor` of both the light seed's `surfaceContainerLowest` and its `primaryContainer` is `0x000000`. The selected cell's request is therefore byte-identical to before in the light theme.
- **Thumbnail churn is bounded.** `_Thumbnail.didUpdateWidget` re-requests on a foreground change, so a selection move re-asks for exactly two cells; the new gallery test pins `[('chair@2', ink), ('table@1', selectedInk)]`. The cache key holds the foreground (`symbol_thumbnails.dart:76`), so moving back is a cache hit. This happens on a selection change, not per frame.

**Existing test change** (`symbol_gallery_test.dart`)
- The diff is additions only.
- `Harness.build`/`pump` gain an optional `int? selectedForeground`, passed as `selectedForeground ?? foreground`.
- The recorder gains an `asked` list.
- No existing expectation changed, so the change is mechanical.

**D9a scan.** Can it pass silently?
- **Roots.** These are relative to the package; `flutter test` runs with the package as cwd. A missing root throws `StateError`, which a test pins. Each root must contribute more than 0 files, and the total must exceed 100.
- **152 files is correct.** I counted with `find`: 82 + 59 + 10 + 1.
- **Dropping a root also goes red through the stale check**, because every root holds at least one allow-list entry:
  - `lib`: `layer_row`;
  - `jet_cad_2d_flutter`: `canvas_palette` and the sink;
  - `floor_planner`: the seed;
  - `restaurant_demo`: four entries.
- **The three regexes are verbatim** from spec D9a.
- **Matching.** A match is allowed when `startsWith(literal, m.start)` and, for a literal that ends in a word character, the next character is not a word character. My `Colors.tealAccent` mutant is red, and the stale `Colors.teal` entry is reported too.
- **`ui.Color(` is matched:** `\b` sits between `.` and `C`. My `OWN_uiColor_widget` is red.
- **`TrueColor(0x` is not matched:** there is no boundary inside the identifier, and the self-test pins it.
- **Stale entries fail.** That covers a pair or a whole file whose matches are empty. The real-file stale mutant in the report is consistent with my reading of the code.
- **The matches the scan sees on the real tree are exactly the spec's eight pairs**, plus `Colors.transparent` (excluded by the pattern) and `canvas_palette.dart`. I checked with `grep -P`.

**D9c.** `layer_row.dart:364`'s `Border.all(color: scheme.outline)` is unchanged and pinned by M-DT-18 in both themes:
- left and right border pixels exactly `outline`;
- the centre pixel `0x000000`;
- a premise that the outline is not near black.

**D9d audit.** I re-ran a grep for `late final` and for `Color`/`ColorScheme`/`ThemeData` fields, plus theme reads within `initState`, across the floor-plan lib, `symbol_gallery.dart` and both apps' lib. Only widget constructor fields turn up (`layer_row.dart:356`, `floor_plan_types.dart:76`, the gallery's `cellColor`). I agree that there is nothing to fix.

**Fixtures**
- **M-DT-15** is the one non-seed theme: `fromSeed(0xFF2266CC, dark).copyWith(primaryContainer: 0xFFD8E2FF)`.
  - The selection comes from a real tap through the shell, with a premise on the cell's `Material.color`.
  - The pixel oracle is a WCAG formula written in the test and shares no code with production.
- **M-DT-16/17/18** use `palette_fixture.dart`'s real-seed `lightTheme`/`darkTheme`.
- **Paper.** White is the default paper, which is degenerate only where the rule is about the paper. D9b/D9c are about the theme, and M-DT-18 asserts the paper's black ink on a dark panel, which is the point.
- **M-DT-17 is a real live switch with state kept**:
  - `pumpWidget` of an identically shaped `MaterialApp` with a new `themeMode` at `themeAnimationDuration: Duration.zero`.
  - The Symbols tab stays open across the switch without being re-tapped, so the `cell(id)` finder only works if state was kept.
  - The `late final` mutants (page panel, re-fired by me) go red. A fresh State would have re-read the theme and hidden them.
- **The panel sweep** runs under `ThemeMode.dark` and asserts `chrome-left == dark.surfaceContainerLow`. It steps through:
  1. the shell;
  2. the layer colour menu;
  3. the selection panel and its layer picker;
  4. a text entry;
  5. the export dialog;
  6. the symbol panel, with search matching and not matching.

  It also pumps `ServiceView` with a status through `pumpService(.., ThemeMode.dark)` (real seed). Print has no in-app dialog (`page_flows.dart`), which is accepted. The demo's own UI is the gap (finding 1).

## Rulings

- **R-C6-1, accepted.** "Centre leaf" is the extremes of the thumbnail rect's middle half.
  - The region is larger than the spec's 3×3 block, so it is more lenient. But the thumbnail is transparent, so every pixel there is the cell background or ink, and the thresholds are the spec's.
  - All the pixel mutants are red under it. One of mine, `selectedForeground` from `scheme.primary`, goes red in both the dark test and the light control.
- **R-C6-2, accepted.** M-DT-17 is a new test. The M-DT-9 shell has no symbol loader, and extending it would not be mechanical. The live switch it performs is the same mechanism.
- **R-C6-3, accepted.** The capture boundary sits in `MaterialApp.builder`, so menus and dialogs are in the shot. `palette_fixture.dart` is unedited.

## Gates (my runs, `CI=true`, Flutter in `/home/user/flutter/bin`)

| Package | test | analyze | format |
|---|---|---|---|
| engine `jet_cad_2d` (untouched) | `+1241 -2`: the 2 standing `generate_document_test` byte-hash tests | No issues found! | 169 files (0 changed) |
| render `jet_cad_2d_flutter` | `+1303 ~1 -7`: exactly text_ladder rungs 1-5 and text_lod_ladder rungs 1-2 (`RenderBackend.canvas`), the standing 7 | No issues found! | 218 (0 changed), exit 0 |
| planner `jet_cad_floor_plan` | `+1211: All tests passed!` | No issues found! | 200 (0 changed), exit 0 |
| `jet_cad_restaurant_symbols` | `+94: All tests passed!` | No issues found! | 13 (0 changed), exit 0 |
| app `floor_planner` | `+201: All tests passed!` | No issues found! | 44 (0 changed), exit 0 |
| demo `restaurant_demo` | `+17: All tests passed!` | No issues found! | 3 (0 changed), exit 0 |
| `apps/dev_harness_2d` | `+82: All tests passed!` | No issues found! | 22 (0 changed), exit 0 |

These match the implementer's counts in every row. The engine was not run by the implementer; I ran it, and its standing 2 match STATUS.md.

## Mutants (mine, fired on real files)

**Method:** `scratchpad/review6/mut.py`.
1. `cp` the file to a backup.
2. Apply exact-string edits, each required to match once.
3. Run `flutter test <file>`.
4. `cp` the backup back.

Every run printed `restored diff= 0`. At the end, `git status --short` shows only pub get's `packages/jet_cad/analysis_options.yaml` rewrite (not committed).

| ID | change | test | result |
|---|---|---|---|
| **M-DT-14** (named) | `const Color _scratch = Color(0xFF123456);` in `symbol_panel.dart` | theme_colours | **RED** `+1 -2`: `Actual: 'lib/src/symbols/symbol_panel.dart:117: const Color _scratch = Color(0xFF123456);'` |
| own: `Colors.red` in an app | `apps/floor_planner/lib/main.dart` | theme_colours | **RED**: `'../../apps/floor_planner/lib/main.dart:26: const Color _x = Colors.red;'` |
| own: `Color.fromARGB(` in a planner widget | `tool_palette.dart:52` | theme_colours | **RED**: `'lib/src/tool_palette.dart:52: color: Color.fromARGB(0, 1, 2, 3),'` |
| own: `ui.Color(0x..)` in a widget | `page_panel.dart:129` | theme_colours | **RED**: `'lib/src/page_panel.dart:129: color: const ui.Color(0x00123456),'` |
| own: `Colors.teal` changed to `Colors.tealAccent` | demo `main.dart:50` | theme_colours | **RED**: the offender, plus `stale allow-list entry: (.., Colors.teal)` |
| own: duplicate `Color(0xFFFFFFFF)` | `vertices_draw_sink.dart` | theme_colours | **survives** `+3` (note N1) |
| own: literal split across lines | `tool_palette.dart` | theme_colours | **survives** `+3` (note N2; spec regex) |
| **M-DT-15** (named) | `selectedForeground` from `cellColor` | widget_theme | **RED** `+8 -1`, M-DT-15 only: `Expected: >= <3> Actual: <1.2929180718999134>` |
| own: `selectedForeground` from `scheme.primary` | symbol_panel | widget_theme | **RED** `+7 -2`: M-DT-16 dark (`> 200`, actual `<43>`) and the light control |
| own: cell inverted (`selected ? foreground : selectedForeground`) | symbol_gallery | gallery, widget_theme | **RED** both: the gallery test (`Expected <15786192> Actual <3368601>`); M-DT-15 (`1.29`) |
| **M-DT-16** (named) | `foreground: 0x000000` | widget_theme | **RED** `+6 -3`: M-DT-15, M-DT-16 dark (`Actual: <12>`), M-DT-17 |
| **M-DT-17** (named) | `PagePanelState` gets a `late final ColorScheme _scheme`, read in the builder | widget_theme | **RED** `+8 -1`: M-DT-17's swatch border is expected dark primary (`red: 0.6784`), actual light (`red: 0.2667`) |
| own: `_Thumbnail` stops re-requesting on a foreground change | symbol_gallery `didUpdateWidget` | widget_theme | **RED** `+7 -2`: M-DT-15 and M-DT-17 |
| **M-DT-18** (named) | the swatch's `border:` line deleted (`layer_row.dart:364`) | widget_theme | **RED** `+7 -2`, both M-DT-18 tests: `Expected: '0x8e9099' Actual: '0x000000'` |

## Untouched

`git diff --stat 1fab9a9..4f324f9` comes back empty over all of these:
- `packages/jet_cad_2d`;
- `*golden*`;
- `*allocation*`;
- `*analysis_options*`;
- `*paint_identity*`.

There is one commit. No `analysis_options.yaml` is committed.
