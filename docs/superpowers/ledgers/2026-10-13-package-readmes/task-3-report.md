# Task 3 report: the planner's scenes P1–P6

**Status: DONE_WITH_CONCERNS.** Commit `08dfe6ee` ("feat(tool): the planner's six scenes and their screenshots").

The concern: in P1 and P2 the **ruler labels draw as test-font boxes**. No public API can fix this from a scene. Details are under Concerns.

## What I built

`tool/screenshots/test/planner_scenes_test.dart` has six `testWidgets`, one per scene. Each runs over `apps/restaurant_demo/assets/plans/salon.json` with `SymbolLibraryLoader(sources: [furnitureSymbolSource, restaurantSymbolSource])`. The scenes use the barrels only. `shots.dart` is unchanged.

Where I departed from the brief's shared code, and why:

- **`_controller()` returns a record `(c, symbols)`.** Per ruling R1, the loader stays in a local. It is passed to `FloorPlanController(symbols:)` and to `_ready`. The scene does not own the loader, so it calls `addTearDown(symbols.dispose)` itself.
- **`_ready` calls `unawaited(symbols.load())` before `settle`.**
  - Why: `FloorPlanController.startSymbols()` runs only when the *design* view mounts. In selection mode the loader never starts. P3–P6 failed with "the scene settled" until I made this change.
  - Is it public API: `load()` is public and once-only, so the design scenes' second call does nothing. A host that shares its loader does the same.
- **`_fonts` theme.** `ThemeData(extensions: [FloorPlanTheme(statusCaptionStyle: TextStyle(fontFamily: 'Roboto'), groupChipTextStyle: TextStyle(fontFamily: 'Roboto'))])` is in the app's theme. The view's `theme:` (P4's `_pos`) merges over it field by field.
  - The problem it fixes: without it, P3's "Bill" caption drew as boxes. Its "Party of 8" chip was not drawn at all: the painter skips a chip that is wider than its frame, and the boxes made it wider.
  - Why this is the right fix: a painted `TextStyle` with no family resolves to the test font under `flutter test`. On a device it resolves to the platform's font. Naming Roboto is a documented host option ("A family is drawn only when the host has loaded it").
- **`_expectTables(c, numbers)`.** Each scene asserts that every number it names is a live, visible table, read from `c.tables`. The Salon has tables 1–11 (see the P5 probe below).
- **P5 band.**
  - Probe output (number, world centre, size, global centre):
    - Tables 1, 2, 3: world y=2350, global y=261.3; x = 303.1, 474.1 and 645.1. They form a row.
    - Tables 4 and 5: world y=-950, global y=487.0; x = 316.8 and 522.0.
    - Tables 6 and 7: x=884.5.
    - Tables 8–11: y=599.8.
    - Canvas: `Rect.fromLTRB(0.0, 44.0, 1280.0, 800.0)`.
  - Tables 3–5 are not in a line. A rectangle that crossed all three would also cross 1 and 2. So the band crosses **1, 2 and 3**, the front row, which meets "crosses three tables".
  - Where the gesture runs: from the floor 600 mm right of table 3, a quarter of its height below its centre, to table 1's centre plus a quarter of its height. Both points are computed with `c.worldToGlobal` from `c.tableDetails`.
  - The scene asserts that both points are inside `c.canvasRect.value` and that `c.tableAt(from - canvas.topLeft)` is null (the band starts on the floor).
  - The gesture is a mouse: `startGesture`, a move to the midpoint, a move to `to`, a pump, then `shoot`, then `up`.
- **P6.** `setTablesColor` throws a `StateError` in selection mode. The scene therefore colours the tables in design mode, `expect(..., isTrue)`, then calls `setMode(FloorPlanMode.selection)`.

## Test runs

Before generating, without the variable (`cd tool/screenshots && flutter test test/planner_scenes_test.dart`):

```
00:01 +5: P6 service_colors.png: tables in plan colours
00:01 +6: (tearDownAll)
00:01 +6: All tests passed!
```

Afterwards, `git status --short` printed only `?? tool/screenshots/test/planner_scenes_test.dart`.

**Final run without the variable**, after the PNGs existed:

```
00:00 +0: (setUpAll)
00:00 +0: P1 design_light.png: the editor, light
00:00 +1: P2 design_dark.png: the editor, dark
00:00 +2: P3 service_status.png: statuses, captions, a group
00:01 +3: P4 service_dark_focus.png: dark, a POS theme, a zone in focus
00:01 +4: P5 service_band.png: a crossing band mid-drag
00:01 +5: P6 service_colors.png: tables in plan colours
00:01 +6: (tearDownAll)
00:01 +6: All tests passed!
```

To check that nothing was written, I compared `ls -lT` of `doc/screenshots/` before and after this run. `diff` printed nothing ("unchanged").

**With the variable** (`UPDATE_SCREENSHOTS=1 flutter test test/planner_scenes_test.dart`): same lines, ending in `00:01 +6: All tests passed!`.

**Whole package** (`flutter test` in `tool/screenshots`, harness included): `00:01 +9: All tests passed!`

## Per PNG

Sizes are from `ls -l` after the final generation, at kRatio 1.5, so each image is 1920×1200.

| File | Bytes | What it shows | Verdict |
|---|---|---|---|
| `design_light.png` | 124546 | The editor in light mode: top bar (print, undo/redo, "Select", OSNAP, "1:50 · 62%"), Tools/Symbols tabs, tool palette with shortcuts, rulers, the Salon fitted on its A4 landscape sheet with grid, and the Layers/Page panel. All text and icons are real Roboto/Material. | **Ruler labels are boxes** (black squares along both rulers). Everything else reads well. The palette list runs past 800 px, so its last entry ("Text") is cut at the bottom edge. That is the app's own scrolling list at this size. |
| `design_dark.png` | 126047 | The same editor on the dark theme. | Same: **ruler labels are boxes** (white squares). Everything else reads well. |
| `service_status.png` | 34036 | Selection mode. Table 1 amber, 2 green, 4 red with a "Bill" caption, 8 green, 10 amber. A purple group frame around 6 and 7 with a "Party of 8" chip. | Good. Before the `_fonts` fix: "Bill" was boxes and the chip was missing. |
| `service_dark_focus.png` | 29815 | Dark selection mode with the POS theme (`serviceBarHeight` 52 is visible as a taller bar). Zone C (8–11) is in focus and bright; the rest sits under the 0.75 veil. Statuses: 8 green, 10 amber, and a dimmed "Bill" on 4. | Reads at a glance. The veiled area takes most of the picture, and the focused tables are small round ones. Acceptable. |
| `service_band.png` | 28655 | Selection mode with a green dashed crossing band over tables 1, 2 and 3. It starts on the floor right of 3. | Good. The crossing band's colour and dashes are clear. |
| `service_colors.png` | 28069 | Selection mode. Tables 1 and 2 blue, 3 teal, 6 and 7 purple, 9 orange, at the default 0.35 fill. | Good. The colours are distinct, and every number is in Roboto. |

## kRatio

**It stays at 1.5.**

- Largest file: 126047 bytes, against a 1 MB limit per file.
- All six together: 371168 bytes, against a 4 MB limit.

## Analyze and format

- `flutter analyze` (tool/screenshots): `No issues found! (ran in 2.6s)`
- `dart format --output=none --set-exit-if-changed .`: `Formatted 3 files (0 changed)`, `format_exit=0`

## Files changed

- `tool/screenshots/test/planner_scenes_test.dart` (new)
- Six new PNGs in `packages/jet_cad_floor_plan/doc/screenshots/`: `design_light.png`, `design_dark.png`, `service_status.png`, `service_dark_focus.png`, `service_band.png`, `service_colors.png`

No `analysis_options.yaml` change. `git status --short` was clean of it before the commit.

## Self-review

- **Public API only:** the planner's barrel and `jet_cad_restaurant_symbols`. Nothing from `src/`, and no `editor.dart` import.
- **Ruling R1** is followed: the loader is a local, passed to the controller and to `_ready`.
- **Statuses** are the demo's colours and caption, verbatim. **P4's `_pos`** is verbatim from the brief.
- **Test-file hygiene:** I removed the P5 debug prints. A temporary font-probe test (`test/zz_probe_test.dart`) was deleted before the commit and never staged.
- **No pixels compared.** The scene asserts are on preconditions only: tables exist, the band starts on the floor, the canvas is placed, and `setTablesColor` returns true.

## Concerns

1. **The ruler labels in P1 and P2 are test-font boxes.**
   - Cause: `jet_cad_2d_flutter`'s `RulerPainter` builds `TextStyle(color: chrome.rulerInk, fontSize: kRulerLabelSize)` with no `fontFamily` (`lib/src/ruler_painter.dart:53` and `:180`). Under `flutter test` (flutter_tools always passes `--use-test-fonts`), a family-less paragraph resolves to the engine's test font whatever is loaded.
   - What I tried: registering Roboto bytes through `FontLoader` under these names, before any lookup: `FlutterTest`, `Ahem`, `Arial`, `Helvetica`, `sans-serif`, `.AppleSystemUIFont`, `Helvetica Neue`, `Ubuntu`, `Cantarell`, `DejaVu Sans`, `Liberation Sans`, `System Font`, `.SF NS`, `.SF NS Text`, `San Francisco`, `SF Pro`, `SF Pro Text`, `Segoe UI`, `Noto Sans`, `monospace`, `serif` and `system-ui`. A family-less "Mi" at 20 px stayed 40.0 wide (the test font); `Roboto` by name measured 22.3.
   - Why I stopped there: `ChromePalette` and `RulerFrame` expose no text style, so a scene cannot fix this. The same will hit R1 and R2 in Task 4.
   - What would fix it (a library change, your call): the rulers' label style takes a family from the ambient `DefaultTextStyle` (Material's text theme), or from a new `ChromePalette`/`RulerFrame` field. That would also make the rulers match the host's font on a device. After such a fix, regenerating P1 and P2 is one command.
   - I committed the current P1 and P2 per the brief. They should not ship as the pub.dev thumbnail until this is resolved.
2. **P5 crosses tables 1–3, not 3–5**, because 3–5 are not in a line. If you want 3–5, the band would also cross 1 and 2.
3. **The scenes add a Roboto `FloorPlanTheme` in the app theme**, for status captions and group chips. The pictures then show what a device shows with its platform font. D5 does not list it, so P3–P6's descriptions might mention it, or not.
4. **`_ready` starts the shared loader itself** (`symbols.load()`), because selection mode never starts it.
