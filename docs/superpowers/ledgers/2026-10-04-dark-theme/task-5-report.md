# Task 5 report — the canvas UI fixes (D6a, D6b, D6c; R-5, R-6; M-DT-12, M-DT-13)

Start: branch head `37a1797` (Tasks 1-4 done). Status: **done**. Commit: `6e3fa02` feat(dark-theme): Task 5 — the canvas UI fixes: swatch border, filled text entry, status caption ink (not pushed).

## What was built (lib)

**D6a, `page_panel.dart`.** The swatch border is `scheme.primary` when selected and `scheme.outline` when not, replacing `Colors.blue` / `Colors.black26`. The scheme is read at build from `Theme.of(context)` inside the page builder. The widths (2 / 1) are unchanged.

**D6b, `text_entry_overlay.dart`.** The decoration is now:

```dart
InputDecoration(
  isDense: true,
  border: const OutlineInputBorder(),
  filled: true,
  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
)
```

**D6c, `service/table_status_painter.dart`.**
- **`over`.** A new top-level `int over(Color colour, int paper)` returns `0xRRGGBB`. It composites with straight alpha, per channel `round(a*s + (1-a)*p)`, with `a = A/255`. It ignores the paper's own alpha.
- **`statusCaptionInk`.** A new top-level `Color statusCaptionInk(Color colour, int paper)` maps `foregroundFor(over(colour, paper))` to one of the two constants: `0xFFFFFF` gives `kStatusCaptionOnDark`, anything else gives `kStatusCaptionOnLight`. This mapping is the only conversion; nothing calls `Color(foregroundFor(..))`.
- Both functions sit in a library that no barrel exports (`lib/*.dart` never exports `service/table_status_painter.dart`), so the name `over` leaks nowhere.
- **The painter.** `TableStatusPainter` takes a new required `paper: ValueListenable<int>`.
  - The rebuild condition gains `_paperBuilt != paper.value`.
  - The caption cache is now `Map<(String, int, Color), ui.Paragraph>`, keyed `(caption, colour, ink)`.
  - `_paragraph(text, ink)` styles the text with the ink.
  - `shouldRepaint` also answers `!identical(oldDelegate.paper, paper)`.
  - The `const Color(0xFF202020)` literal is gone from the file (one of the two D9a offenders the spec names).

**D6c, `host/service_view.dart`.**
- `final ValueNotifier<int> _paper = ValueNotifier<int>(0xFFFFFFFF)` is a plain field, not `late`. It exists from construction, so `_statusPainter`, a `late final` first read in `build`, always finds it.
- **Where it is set.**
  - `_paper.value = _paperArgb()` runs in `didChangeDependencies`, right after `_surfaceArgb` is assigned. The first call runs before the first `build`, so the initial White is never painted.
  - It also runs at the top of `_onPage`, on every page change, before the foreground-flip early return. The status colour composited over the paper can flip where the paper alone does not.
- `_paper` is both the painter's `paper:` and a member of its repaint merge: `[_c.camera, _c.tableStatuses, _changed, _paper]`.
- It is disposed in `dispose()`, beside `_changed`.

## Tests added

**`packages/jet_cad_floor_plan/test/service/table_status_painter_test.dart`.** The existing `painterFor` changed mechanically. It gains an optional `paper:`, defaulting to a `ValueNotifier<int>(0xFFFFFFFF)` that is also put in its repaint merge. No existing expectation changed. New tests:
- `SP10 over composites a translucent status colour onto the paper's RGB: straight alpha, rounded per channel, the paper's alpha unread (D6c)`
  - `0x99E53935` over White is `0xEF8886`. Blue is 133.8, which rounds to 0x86; truncating would give 0x85.
  - Over Blueprint it is `0x963946`. Amber over Blueprint is `0xA58326`, and green over White is `0x8EC691`.
  - An opaque colour returns the colour, a transparent one returns the paper, and a paper with alpha 0 gives the same result as an opaque one.
- `SP11 the caption colour: the demo's statuses on White keep today's 0xFF202020; on Blueprint the paper decides, where the status colour alone would not (D6c, R-5)`
  - It checks `kStatusCaptionOnLight == Color(0xFF202020)`, and all three demo statuses on White map to `OnLight`.
  - On Blueprint, Bill and Eating map to `OnDark` and Ordered to `OnLight` (amber over navy is still light).
  - It checks `foregroundFor(0xE53935) == 0`: Bill's RGB alone takes black ink, so its white caption on Blueprint comes from the paper.
  - An opaque dark status on White maps to `OnDark`.
- `SP12 M-DT-13: on one painter, Bill on White has dark glyphs; the paper flips to Blueprint: light glyphs and exactly one new paragraph; ten steady frames build nothing (D6c, R-11)`
  - It uses one painter instance and renders the paper and then the painter to an image.
  - The darkest pixel of the caption box on White is exactly `0x202020`. After `paper.value = blueprint`, the brightest is exactly `0xFFFFFF`.
  - `debugAllocations == made + 1`, and the new paragraph is not identical to the old one.
  - Ten steady frames pass the identical paragraph with allocations unchanged, and `debugCached == 2`.

**`packages/jet_cad_floor_plan/test/host/status_caption_test.dart`** (new):
- `premise: Bill over the seed's light surface takes the dark caption, over its dark surface the light one; over White dark, over Blueprint light`
- `M-DT-13, F-16: ServiceView with no page, light then dark theme with no camera move: the caption repaints light on the dark surface, and back`
  - The document is page-less (`prepareDocument` plus one table, run through the codec). The camera is asserted identical across the switch.
  - The caption's glyph run is located by a recording canvas on the live painter, and the window is captured.
- `D6c: ServiceView in the dark theme on White keeps the dark caption (the paper decides, not the theme); White to Blueprint repaints it light`

**`packages/jet_cad_floor_plan/test/canvas_ui_test.dart`** (new):
- `premise: the seed schemes' primaries differ by theme, and from their outlines and from Colors.blue`
- `D6a, {light|dark} theme: the selected swatch border is scheme.primary, 2 px; the others scheme.outline, 1 px; and it moves with the selection` (2 tests)
  - It starts on Ivory (swatch 1, not the first), then taps Blueprint, and checks the border colour and width of all four swatches each time.
- `M-DT-12, {dark theme, White paper | light theme, Blueprint paper}: a pixel inside the text entry, away from the glyphs, is surfaceContainerHighest, not the paper` (2 tests)
  - Premise: before the field opens, the same pixel is exactly the paper.
  - After the field opens, the pixel is exactly the theme's `surfaceContainerHighest` (`0x33353a` in the dark theme).
  - The pixel is 200 px right of the insertion point, on the box's middle row.

## Mutant table
**Method.** `scratchpad/task5/mut.py` does the following for each mutant:
1. `cp` the file to scratch;
2. apply exact-string edits;
3. run `CI=true flutter test <files>` in `packages/jet_cad_floor_plan`;
4. `cp` the file back and run `diff -q`. Every run printed `restored diff=0`.

`sha256sum -c` of the four lib files against a pre-run snapshot printed `OK` for all four. Logs are `scratchpad/task5/<id>.log`, and the summary is `mut-summary.txt`.

Test file abbreviations: T_UI = `test/canvas_ui_test.dart`, T_SP = `test/service/table_status_painter_test.dart`, T_CAP = `test/host/status_caption_test.dart`.

| ID | file | change | ran | result, red test(s), real excerpt |
|---|---|---|---|---|
| D6a Colors.blue back (named) | page_panel.dart | `? scheme.primary` → `? Colors.blue` | T_UI | `+3 -2`; both `D6a, {light,dark} theme` tests; `Actual: MaterialColor:<MaterialColor(primary value: ...` |
| D6a swapped (named) | page_panel.dart | primary ↔ outline | T_UI | `+3 -2`; both D6a tests |
| D6a black26 back (own) | page_panel.dart | `: scheme.outline` → `: Colors.black26` | T_UI | `+3 -2`; `Actual: Color:<Color(alpha: 0.2588, red: 0.0000 ...` |
| M-DT-12 filled false (named) | text_entry_overlay.dart | `filled: true` → `false` | T_UI | `+3 -2`; both M-DT-12 tests; `Expected: '0x33353a' Actual: '0xffffff'` |
| M-DT-12 fill from paper (named) | text_entry_overlay.dart | `fillColor: Colors.white` (the White paper) | T_UI | `+3 -2`; `Expected: '0x33353a' Actual: '0xffffff'` (the Blueprint crossing is red too) |
| D6b fill = surface (own) | text_entry_overlay.dart | `.surfaceContainerHighest` → `.surface` | T_UI | `+3 -2`; `Expected: '0x33353a' Actual: '0x111318'` |
| D6b fillColor omitted (own) | text_entry_overlay.dart | the `fillColor:` argument removed, `filled: true` kept | T_UI | **SURVIVES** `+5: All tests passed!`. **Equivalent** under these themes: Material 3's default fill for a filled `InputDecorator` is `colorScheme.surfaceContainerHighest`. See R-C5-2. |
| M-DT-13 caption fixed 0xFF202020 (named) | table_status_painter.dart | `TextStyle(color: const Color(0xFF202020), ..)` | T_SP+T_CAP | `+12 -3`; SP12 and both ServiceView tests; `Expected: '0xffffff' Actual: '0x583a53'` |
| M-DT-13 ink ignores paper, White (named) | table_status_painter.dart | `over(colour, 0xFFFFFFFF)` | T_SP+T_CAP | `+10 -5`; SP11, SP12 and both ServiceView tests; `Expected: Color(.. 1.0000, 1.0000, 1.0000 ..) Actual: Color(.. 0.1255 ..)` |
| M-DT-13 ink ignores paper, status RGB alone | table_status_painter.dart | `foregroundFor(colour.toARGB32() & 0xFFFFFF)` | T_SP+T_CAP | `+10 -5`; same tests |
| M-DT-13 cache key without ink (named) | table_status_painter.dart | key `(caption, colour, kStatusCaptionOnLight)` | T_SP | `+11 -1`; SP12: `Expected: '0xffffff' Actual: '0x583a53'` |
| M-DT-13 `_paper` not in repaint merge (named) | service_view.dart | `_changed, _paper]` → `_changed]` | T_CAP | `+2 -1`; `M-DT-13, F-16: ServiceView with no page ...`: `Expected: '0xffffff' Actual: '0x202020'` |
| M-DT-13 `_paper` not set in didChangeDependencies (named) | service_view.dart | the dcd assignment deleted | T_CAP | `+2 -1`; same test, same excerpt |
| M-DT-13 raw `Color(foregroundFor(..))` (named) | table_status_painter.dart | `statusCaptionInk` returns `Color(foregroundFor(over(colour, paper)))` | T_SP+T_CAP | `+10 -5`; `Actual: Color:<Color(alpha: 0.0000, red: 0.0000 ...` |
| `_paper` not set in `_onPage` (own) | service_view.dart | the `_onPage` assignment deleted | T_CAP | `+2 -1`; `D6c: ServiceView in the dark theme on White ... White to Blueprint ...`: `Expected: '0xffffff' Actual: '0x202020'` |
| rebuild condition without paper (own) | table_status_painter.dart | `\|\| _paperBuilt != paperArgb` deleted | T_SP+T_CAP | `+13 -2`; SP12 and the page-less ServiceView switch |
| `over` floors (own) | table_status_painter.dart | `.round()` → `.floor()` | T_SP | `+11 -1`; SP10: `Expected: <15698054> Actual: <15698053>` |
| `over` ignores alpha (own) | table_status_painter.dart | `a = 1.0` | T_SP | `+9 -3`; SP10, SP11, SP12 |

Not fired: `shouldRepaint` without paper. In `ServiceView` the painter is a `late final`, so the same instance is always handed back, and the `shouldRepaint` term is unreachable there (equivalent in context). It is kept for any other host that builds a new painter with a new notifier.

## Gates (this container, Flutter 3.47.6, `CI=true`; logs `scratchpad/task5/gate-*.log`)

| Package | flutter test | analyze | format |
|---|---|---|---|
| render `jet_cad_2d_flutter` | `+1302 ~1 -7: Some tests failed.`, the same count as Task 4. The 7 are exactly the standing set: text_ladder rungs 1-5 and text_lod_ladder rungs 1-2, all `RenderBackend.canvas`. | No issues found! | 218 files (0 changed) |
| planner `jet_cad_floor_plan` | `+1198: All tests passed!` = 1187 + 11 new (SP10-12: 3; status_caption: 3; canvas_ui: 5) | No issues found! | 198 files (0 changed) |
| `jet_cad_restaurant_symbols` | `+94: All tests passed!` | No issues found! | 13 (0 changed) |
| app `floor_planner` | `+201: All tests passed!` | No issues found! | 44 (0 changed) |
| demo `restaurant_demo` | `+17: All tests passed!` | No issues found! | 3 (0 changed) |
| `apps/dev_harness_2d` | `+82: All tests passed!` | No issues found! | 22 (0 changed) |

**Untouched.** `git diff --stat 37a1797` is empty on each of these:
- `packages/jet_cad_2d` and `packages/jet_cad_2d_flutter` (this task edits neither);
- `*golden*`, `*invariants*` and `*analysis_options*`.

`analysis_options.yaml` is not modified in this container, and nothing staged it.

## D7: existing expectations
No existing expectation changed. No test pinned `Colors.blue` / `Colors.black26` on the swatch, or an unfilled text entry:
- `page_panel_test.dart` taps swatch 3 and checks the command only.
- The text-entry tests (`planner_draw_test.dart`, `room_tool_test.dart` and the apps' flows) check presence, focus and commit.

The only edit to an existing test is the mechanical `painterFor` change in `table_status_painter_test.dart`: a new optional `paper:` defaulting to White. D6a and D6b are covered by the new tests in `canvas_ui_test.dart`.

## Proposed rulings
- **R-C5-1: light-theme captions are unchanged only where the status over the light paper takes black ink.** D7 says the light theme's status captions are pixel-identical to today. D6c's formula holds that for the demo's three translucent statuses on White, Ivory and Grey (SP11 asserts all three on White map to `0xFF202020`).
  - **The exception.** A host status whose colour over the paper takes white ink now gets the white caption in the light theme too. An example is an opaque dark colour, as in SP1's `0xFF000000 | i*0x030507` fixtures: `statusCaptionInk(Color(0xFF1B3A1B), white) == kStatusCaptionOnDark`. Today such a caption is `0xFF202020` on a dark fill, which is unreadable.
  - **Why I followed the formula.** It is the spec's formula ("ink follows what it sits on"). No existing test pins such a caption.
  - **Cost if wrong:** to keep strict identity, the ink would have to ignore the status colour in the light theme. That contradicts D6c and needs a spec edit.
- **R-C5-2: an equivalent mutant on D6b.** Removing `fillColor:` while keeping `filled: true` survives. Material 3's `InputDecorator` defaults a filled field's colour to `colorScheme.surfaceContainerHighest`, and neither app sets an `inputDecorationTheme`. The explicit `fillColor` stays because the spec writes it and it protects against a future input theme.
  - **Cost if wrong:** none at runtime. A reviewer who wants the mutant dead could add a fixture whose theme sets `inputDecorationTheme.fillColor`. That theme is not the apps' real one.
- **R-C5-3 (small): the M-DT-13 ServiceView fixture runs at 0.07 px/mm.** In the test font, the drafted number label's glyph box reaches about 0.68 of its height below its anchor. At 0.25 px/mm it covered the caption's top rows (seen in a debug pixel map: the caption showed only in its last 2 rows), and a page-less dark run would then read the white ACI 7 label as the caption. At 0.07 px/mm the caption sits at its 11 px floor, clear of the label (9.5 px). See "Found, not fixed".
  - **Cost if wrong:** none; the test comment says why.
- **R-C5-4 (small): `over` returns `0xRRGGBB`.** It and `statusCaptionInk` are top-level in `table_status_painter.dart`, which no barrel exports. `foregroundFor` reads only the RGB bytes, so `0xRRGGBB` fits it directly.
  - **Cost if wrong:** a rename or a move to `canvas_palette.dart`.

## Found, not fixed
- **The caption can sit under the number label (14c S7, pre-existing, not a dark-theme defect).** `TableStatusPainter` puts the caption at `max(11, half*scale + 2)` below the label anchor, taking the label as centred on its anchor. With the test font, the label's glyph box reaches about 0.68 of its height below the anchor, so at moderate zooms (0.25 px/mm, tableSymbol) the caption's top rows are covered. SP8 checks only the arithmetic, not pixels.
  - **Possible cause.** The label's vertical alignment may not be a true middle, or the "half" may be half the cap height rather than half the glyph box.
  - **Not verified with the app's real font.** Worth a look in Task 7's service-view screenshot.
- **One frame of latency in tests only.** `PageNotifier` hears the change on the document's async change stream, so a test needs a second `pump` after a page command before the caption repaints. In the app, the microtask runs before the next frame.

## For the reviewer
- **Before the first `build`.** `ServiceView._paper` is a plain final created with its state. The first `didChangeDependencies` sets it before the first `build`, which is when `_statusPainter` (a `late final`) is first read. So White is never painted unless the paper really is White.
- **`_onPage` sets `_paper` before the flip early return.** This is deliberate (see its doc comment) and pinned by the `paper-not-set-in-onPage` mutant.
- **Where the caption box comes from in the host tests:** a `SpyCanvas` paint on the live painter, taken before any switch, so it cannot mask a missing repaint.
- **SP12's paint count.** It renders the paper, then the painter, to an image. The first `SpyCanvas` paint is the warm-up that allocates. `made` is read after the first real render.
