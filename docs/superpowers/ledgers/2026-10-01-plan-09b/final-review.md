# Plan 09b final whole-branch review

Verdict: READY WITH FIXES (0 blocking, 0 important, 1 minor doc fix, 3 nits) — the code is ready; the one fix is a docs status line.

Reviewer: fresh final reviewer. Worktree: plan-09b-review @ 47ccd78, base origin/main 75dc2e0.

## Batch 1 — gates (engine) and static checks

- engine `CI=true dart test`: `00:18 +1121 -2: Some tests failed.` The two [E] are
  `test/testing/generate_document_test.dart` ("the default document is the one Plan 2
  measured, byte for byte"; "both text fractions default to zero and change nothing") — standing.
  `dart analyze`: `No issues found!`; format: `Formatted 160 files (0 changed)`.
- `git diff --stat origin/main..HEAD -- packages/jet_cad_2d packages/jet_cad_2d_flutter/test/invariants`: empty
  (engine lib and both allocation invariant test dirs untouched). No `analysis_options.yaml` in `--name-only`.
- Purity: `symbol_search.dart`, `symbol_library_state.dart` import only `symbol_library.dart` (whose transitive
  imports are `jet_cad_2d`, `parametric/*`, `symbol_component.dart`: no Flutter). `rootBundle` appears only in
  `symbol_library_loader.dart`. No non-English strings added (the "Araçlar | Semboller" quote is spec prose only;
  the UI says Tools / Symbols).
- Frame path: `draft_painter.dart`, `vertices_draw_sink.dart` unchanged. The ghost is `paintWorldOverlay`:
  no Path / Transform2 / Float64List / Paint per paint (`_ghostPaint` reused, strokeWidth set; GhostMatrix
  reused). Per paint: 4 `Offset`s for the cross (symbol_place_tool.dart:468-471) + 1 for the snap marker
  (:442). Offsets are value structs the VM often scalar-replaces; even when not, O(1) per paint, never per
  entity: within the non-negotiable, as Task 6's review said. Judged acceptable (nit to hoist).

## Batch 2 — gates (render, app, web), real output at 47ccd78

- render `CI=true flutter test`: `00:48 +1001 ~1 -7: Some tests failed.` The 7 [E]: text_ladder_golden_test
  rungs 1, 2, 3, 4, 5 (RenderBackend.canvas) and text_lod_ladder_golden_test rungs 1, 2 (RenderBackend.canvas) —
  exactly the standing goldens. analyze `No issues found! (ran in 1.2s)`; format `Formatted 182 files (0 changed)`.
- app `CI=true flutter test`: `03:09 +885: All tests passed!`; analyze `No issues found! (ran in 1.5s)`; format
  `Formatted 153 files (0 changed)`.
- `CI=true flutter build web --release` (apps/floor_planner): `Compiling lib/main.dart for the Web... 43.9s`,
  `✓ Built build/web`, exit 0.
- `git status --short` after the gates: empty.
- Results-note count arithmetic re-checked (790 + 95 = 885; 974 + 27 = 1001) and matches the runs.

## Batch 3 — the sample of mutants re-fired on the tip (47ccd78)

One line each, cp backup in scratchpad/final09b, named test FILE in the foreground, cp back; every restore
`diff` exit 0. Logs: scratchpad/final09b/M*.log.

| # | Task | Mutant (file:line) | Test file | Result (real output) |
|---|---|---|---|---|
| 1 | 1 | M-09s `terms.every` -> `terms.any` (symbol_search.dart:36) | symbol_search_test | RED `+10 -6` incl. "several terms two terms are both required" |
| 2 | 2 | M-09b10 retry a no-op (`return;`, symbol_library_loader.dart:52) | symbol_library_loader_test | RED `+12 -1` "SL6 retry() after a failure reads again and reaches ready ..." |
| 3 | 3 | M-09x key ignores the DPR (`1.0` in the record, symbol_thumbnails.dart:76) | symbol_thumbnails_test | RED `+12 -3` "each part of the key paints anew a DPR", "the image is round(w * dpr) x round(h * dpr)", "the sink draws at the DPR ..." |
| 4 | 4 | M-09b12 `ExcludeFocus(excluding: false,` (symbol_gallery.dart:106) | symbol_gallery_test | RED `+11 -1` "a cell and a header never take focus" |
| 5 | 4 | M-09b23 `clone = image;` (symbol_gallery.dart:354) | symbol_gallery_test | RED `+1 -11` incl. "a cell shows its own clone; disposing it leaves the cache image" |
| 6 | 5 | M-09b14 `m[12] = p.e;` (symbol_ghost.dart:96) | symbol_ghost_test | RED `+5 -5` incl. "the matrix maps the base point to at − origin ..." |
| 7 | 6 | M-09b16 `_place(ctx, entry, e.world)` (symbol_place_tool.dart:178) | symbol_place_tool_test | RED `+12 -18` incl. "pointer a release places at the snapped release point, not the press", "snap with object snap off (F3) ..." |
| 8 | 6 | M-09b17 aperture not / scale (symbol_place_tool.dart:138) | symbol_place_tool_test | RED `+28 -2` "snap a release within 10 px (not 10 mm) ...", "the snap marker ..." |
| 9 | 6 | M-09b1 one-line (up without `_resolve`, :176) | symbol_place_tool_test | RED `+17 -13` incl. "pointer a release places at the snapped release point, not the press" |
| 10 | 7 | M-09b3 R the wrong way (`? 1 : -1`, :215) | symbol_place_tool_test | RED `+22 -8` incl. "keys R turns ... counter-clockwise", "Shift+R turns it clockwise" |
| 11 | 7 | M-09b2 allocate before the check (`placeSymbol(...) is Object && !needs...`, :261) | symbol_place_tool_test | RED `+27 -3`, the three "permissions a denied structure/geometry/components allocates nothing ..." (`Expected: <18> Actual: <23>`) |
| 12 | 7 | M-09b5 Esc mid-press does not cancel (`;`, :227) | symbol_place_tool_test | RED `+29 -1` "keys Esc mid-press cancels ..." |
| 13 | 8 | M-09b7 field without the guard (`KeyedSubtree(`, symbol_panel.dart:217) | symbol_panel_test | RED `+13 -1` "typing r, w and m in the field fires no shortcut (M-09b7)" |
| 14 | 8 | M-09b9 highlight ignores the active tool (symbol_panel.dart:159) | symbol_panel_test | RED `+13 -1` "the highlight follows the active tool and the armed entry (M-09b9)" |
| 15 | 9 | M-09b6 cell tap bypasses `_activate` (`_tools.activate`, main.dart:628) | symbol_shell_test | RED `+10 -1` "SS3 a cell tap arms the tool, clears the selection ..." |
| 16 | 10a | R not reaching the tool (`if (true) {`, symbol_place_tool.dart:206) | e2e | RED `+0 -1`: `Expected: same instance as <SymbolPlaceTool> Actual: <RectangleTool>` "R reached the tool, not the Rectangle binding" |
| 17 | 10a | M-09b17 aperture (:138) | e2e | RED `+0 -1`: `translation [40575.0, 27550.0] vs [40505.0, 27550.0]` |
| 18 | 10a | M-09b1 one-line (:176) | e2e | GREEN `+1: All tests passed!` — confirms the recorded equivalence R-B10-1 (red at tool level, row 9) |

Verdict on the sample: 17/17 non-equivalent mutants red; the one recorded equivalent reproduces as recorded.
Matches the results note's table rows (the `Expected seed 18 Actual 23` string reproduced verbatim).

## Batch 4 — spec audit (D1-D11, R-1..R-6) and the docs' claims

Every decision read against the code at the tip:
- D1 files as listed; `tool_palette.dart` untouched; render files know no SymbolEntry/DocumentHost. D2 loader
  (`read` seam, once-only `load`, `retry` from failed only, any throw -> failed), owned by FloorPlannerApp, passed
  through the host; bare shell has no strip (main.dart `_leftPanel`). D3 exact (every term, substring of name / any
  tag / category, lower-cased, library order, empty groups dropped, "No symbols match" + Clear). D4 gallery API,
  ExcludeFocus, keys, clone per cell, disabled greys and ignores taps. D5 cache record key, Future cached, LRU 64,
  dispose-after-completion, DraftPainter + VerticesDrawSink(no fallback) + canvas scaled by DPR + `Picture.toImage`,
  index disposed, placer's identity output as the thumbnail document, explicit foreground. D6 tool (release
  places at the snapped point, inert idle, keys with modifier rule, mid-press swallow except F/F3, permission check
  before `placeSymbol`, isMidShape, listens to `armed` and removes it in dispose; ghost: cached local path, reused
  Float64List, P recomputed on change only, cross at local base point, marker in paintOverlay). D7 field pattern
  (guard › CallbackShortcuts(Esc) › TextField, PanelFieldFocusNode, Enter/tap-outside/Esc hand back), states,
  highlight, enabled. D8 SegmentedButton under ExcludeFocus, `_armSymbol` through `_activate`, own disposal.
  D9 no new shell letter. D11 09 spec note present. R-1..R-6 all as built.
- Departures: all are in "Amended at execution (Plan 09b)" (thumbnails param in Task 9, material.dart import,
  padding on the larger side, microtask dispose, `ghostPathFor`, base point in the change check, no cancelled flag,
  keys as built, panel API, search clears on tab switch, M-09b1/M-09b12 notes). I found no unrecorded departure.
- Claims checked true: "No lib/ file changed after 7d3bff7" (`git diff --stat 7d3bff7 HEAD -- '*/lib/*'` empty);
  "render lib unchanged since 1951d01" (empty); counts 885 / 1001 / 1121 reproduced; "Expected seed 18 Actual 23"
  reproduced; e2e `translation [...] vs [40505.0, 27550.0]` shape reproduced (M-09b17 gives 40575.0 here, a
  different mutant than the note's two-line M-09b1 row, so not a contradiction); task-8 re-review's `00:56 +1001`
  is in task-8-review.md's re-review section as the note says.

## Batch 5 — cross-task hunts (a temporary test file, run, then removed; real output)

Temp file `apps/floor_planner/test/symbols/zz_final_hunt_test.dart` (kept in scratchpad/final09b as
`zz_final_hunt_test.final.dart`; removed from the tree, `git status --short` empty afterwards).
- H1 a cell tap with **no thumbnail loaded** (a cache whose futures never complete), a click-placement far from the
  origin under the rotated 0.1 px/mm camera, Esc, then Select clicks a point on the instance's first segment:
  `H1 selection: {SelectionKey( 19)}; placed 19; grip box Aabb2(40775.0, 26600.0 .. 41575.0, 28100.0)` — selected,
  grips present. PASS.
- H2 tool armed, search field tapped, R pressed: `H2 after R in field: turns 0, active Symbol` — R goes to the
  field, not the tool; after Esc (hand back) R turns to 1. PASS.
- H3 document swap (New, clean) with thumbnails shown: `H3 clones shown before swap: 11, cache 17` then
  `H3 after swap disposed: 11/11; cache 17`; the app cache is not disposed. No clone leaks across a swap. PASS.
- By reading: placement while loading is impossible (no cells until ready); undo while armed is covered by the e2e
  (Cmd+Z bubbles armed-idle; swallowed mid-press); a doc swap mid-press is unreachable by keyboard (the tool
  swallows Cmd+O mid-press) and would dispose the tool with the shell (SS7 covers disposal). Listeners: panel
  `ListenableBuilder` (loader is app-lived, removed on unmount), `_query`, tool->`_armed` all removed.
- Web: no `kIsWeb` branch added; `Picture.toImage` (async), `Image.clone`, `canvas.transform(Float64List(16))`,
  `rootBundle.load` with the declared asset key are all portable; web release build succeeds. The `on StateError`
  around `clone()` relies on the native engine's throw; on web a clone of a disposed image may assert only in debug —
  reachable only through R-B4-2's race, already a known limit.

## Findings

1. minor — docs/superpowers/specs/2026-10-01-symbol-palette-design.md:3-7: the header still says "Status: design,
   revision 3 ... Awaiting the human's approval." while the results note (line 7) and the ledger record the approval
   ("onaylıyorum, planı yaz"). Update the status line (e.g. "approved 2026-10-01; amended at execution").
2. nit — F-15 / D5 premise is not universally true in this harness: in my first H1 run with the real cache and no
   `runAsync`, `RawImage.image` was already `Image:<[303×225]>` after a few pumps (`Expected: null Actual:
   Image:<[303×225]>`). Pixel tests under `runAsync` remain correct; but a test that assumes "images never arrive in
   a pumped test" would be wrong. No existing test asserts that, so nothing is red; worth a sentence in the note.
3. nit — symbol_place_tool.dart:468-471 (and :442): five `Offset`s per overlay paint. O(1), never per entity, so
   within the non-negotiable; already recorded in "Found, not fixed". Hoisting is optional.
4. nit — after a swap the cache keeps 17 entries for 11 visible cells (off-screen cells built in the sliver cache
   extent). Bounded by 64; harmless.

No blocking or important finding.
