# Plan 09b results — the symbol palette

**Branch:** `plan-09b/symbol-palette`, cut from `spec-09b/symbol-palette` at
the plan's commit `eb50a53` (the spec branch was cut from `main` at
`75dc2e0`, the merge that records 09a). **Spec:**
[2026-10-01-symbol-palette-design.md](../specs/2026-10-01-symbol-palette-design.md),
revision 3 (`121d944`), approved by the human on 2026-10-01, amended at
execution (its closing section). **Plan:**
[2026-10-01-symbol-palette.md](../plans/2026-10-01-symbol-palette.md).
**Ledger:** [`ledgers/2026-10-01-plan-09b/`](../ledgers/2026-10-01-plan-09b/)
(`progress.md` carries every ruling with its cost-if-wrong; the directory is
created by a later commit, which archives the ledger, so the link resolves
only after that commit).

09b is the second slice of sub-project 09: the left panel gains a
**Symbols** tab (search field, collapsible categories, a two-column grid of
thumbnails painted by `DraftPainter`); a cell tap arms a placement tool whose
ghost draws the symbol's real lines; press, drag, release places at the
snapped release point; `R`, `Shift+R`, `M`, `Esc`; one undo step per
placement. The library is loaded once per app from the bundled asset. The
engine is untouched; the render layer gains `SymbolThumbnails` and
`SymbolGallery`; everything else is in `apps/floor_planner`.

Every task had a fresh implementer and an independent reviewer who re-ran
the gates and re-fired mutants. The final whole-branch review, which
precedes the ledger's archive, is not part of this note's source material.

| Task | Commits | Review |
|---|---|---|
| 1 Search (D3) | `d4e85f6`, `7bed823` (1b, test-only) | Needs fixes (substring, key and case-sensitive-tag mutants survived; test-only) -> 1b Approved |
| 2 The loader and its wiring (D2, R-4) | `674f717`, `ebfd8bf` (2b, test-only) | Approved (minor m-T2-1: the app-made loader reaching ready over `rootBundle` unasserted, closed by 2b; note: `late final` loader, like `files`) |
| 3 Render: thumbnails (D5, R-2) | `359a70a`, `3faabd4` (3b, test-only), `5566da3` (3c, test-only) | Needs fixes (the 8% padding and the sink's DPR untested) -> 3b Approved (note: the hairline fixture not in the degeneracy guard loop, closed by 3c) |
| 4 Render: the gallery (D4, R-1) | `1951d01`, `8a44a5c` (4b, test-only) | Needs fixes (`imageFor` per rebuild and clone-after-await mutants survived) -> 4b Approved; `material.dart` import accepted; the clone race accepted as a known limit |
| 5 The ghost path and matrix (D6) | `637a429`, `c975d1d` (5b, test-only) | Needs fixes (`close()` and the per-component base-point change unpinned) -> 5b Approved |
| 6 The tool: pointer, snap, ghost (D6) | `df916b7`, `76e5f8b` (6b, test-only) | Needs fixes (the F3 object-snap toggle and the zoom-adaptive grid unpinned) -> 6b Approved; R-B6-1..3 accepted; note: the cross allocates four `Offset`s per paint |
| 7 The tool's keys and permissions (D6) | `67688a1` | Approved (R-B7-1 accepted; notes: Ctrl+R swallowed mid-press, the mid-press rule wins; the mirror has no hand literal in this file, Task 5's test hand-derives it) |
| 8 The Symbols tab (D7) | `af704cf`, `7693621` (8b, test-only) | Needs fixes (three `ExcludeFocus` wrappers unguarded) -> 8b Approved (cosmetic nit: a misplaced doc comment above `canTakeFocus`, `symbol_panel_test.dart:195-196`); R-B8-1..3 accepted; note: the panel rebuilds per hover |
| 9 The shell's tabs and wiring (D8, D9, R-5) | `7d3bff7` | Approved (R-B9-1..4 accepted; R-B9-2 flagged for the human's look) |
| 10a End to end | `c8f7a21` | Covered by the final whole-branch review |

No `lib/` file changed after `7d3bff7` (Tasks 8b, 2b, 3c and 10a are
test-only); the render layer's `lib/` is unchanged since `1951d01`
(`git diff` checked when this note was written).

## What the execution found that the spec did not

Each ruling is in the ledger with its cost-if-wrong.

- **R-B3-1:** the `FloorPlannerApp` `thumbnails` parameter (the plan's Task 2
  said "Task 3 adds it"; Task 3 is render-only) moved to Task 9, which owns
  the app wiring. Cost if wrong: none.
- **R-B3-2:** an entry evicted while its future is pending disposes its image
  one microtask after completion; holders must clone in their completion
  callback (Task 4's cells do). Pinned by Task 3's T6 and Task 4b's eviction
  test.
- **Padding (Task 3 decision):** 8% of the extents' **larger** side on every
  side (`kThumbnailPadding`), so a zero-height symbol still gets a margin;
  empty extents are not padded. Pinned by 3b's T10.
- **R-B4-1:** the render package's `lib` imports
  `package:flutter/material.dart` for the first time (spec D4 names
  `Material`, `InkWell`, `Tooltip`; `Tooltip` needs an `Overlay`). The
  reviewer accepted it.
- **R-B4-2 (known limit):** a cache hit on a finished entry delivers the image
  one microtask later; an eviction in between makes `clone()` throw; the cell
  catches it and shows an empty cell, no retry. Unreachable with 64 entries
  and 27 symbols.
- **R-B4-3:** M-09b12's red test is "the cell cannot take focus when asked"
  (`canRequestFocus`); a tap never focuses an `InkWell`, so the tap assertion
  alone is not discriminating. The review showed the traversal check is an
  independent second guard.
- **R-B5-1:** `GhostMatrix.update` also recomputes P when the base point
  changes (re-arming another symbol). Pinned per component by 5b.
- **R-B5-2:** the plan's name `ghostPathFor` is kept (the spec says
  `ghostPath`).
- **R-B6-1:** no "cancelled" flag: a primary move with no live press is
  ignored and an up with no live press places nothing (covers pointer cancel,
  `cancel()`, Task 7's `Esc`). The reviewer confirmed the layer keeps its
  active pointer after a tool-side cancel, so this is needed.
- **R-B6-2:** re-arming keeps the current turns and mirror (spec silent);
  Task 7 kept it.
- **R-B6-3 (known limit):** the ghost does not follow a wheel zoom until the
  next pointer event (no camera listener; the drawing tools only listen
  mid-shape).
- **R-B7-1:** key-ups always pass through (including R's and M's); `Esc`
  mid-press is `cancel(ctx)` (ends the press as R-B6-1 and hides the ghost
  until the next hover); `Shift+M` toggles the mirror (the spec excludes only
  Ctrl, Meta and Alt); `Ctrl+R` / `Ctrl+M` pass through armed-idle and are
  swallowed mid-press.
- **R-B8-1:** `SymbolPanel` takes an optional `measurer` (default
  `InsertionPointMeasurer`) for the thumbnail's `prepareDocument`; symbols
  hold no text.
- **R-B8-2:** permissions reach the panel as a `DraftPermissions` value;
  `kSymbolPlacementNeeds` = {structure, geometry, components}. The reviewer
  found no runtime assignment to `commands.permissions`, so a value is enough.
- **R-B8-3:** `onSelect` returns the `SymbolEntry` (looked up from the gallery
  id); `symbolIdOf` and `symbolThumbnailDocument` are top-level.
- **Note (Task 8):** a widget test's `sendKeyEvent` inserts no text: the
  `r`/`w`/`m` test proves no shortcut fires; filtering is proven by
  `enterText`.
- **R-B9-1:** a shell with a loader but no cache makes and disposes its own
  cache (only a bare shell hits it; the app always passes one).
- **R-B9-2:** switching to Tools removes the Symbols panel, so **the search
  text clears on every tab switch** (spec silent). User-visible: flagged for
  the human's look. Keeping the panel alive (`IndexedStack`/`Offstage`) would
  also keep it rebuilding on every hover while hidden (Task 9 review).
- **R-B9-3:** the document measurer is not passed to `SymbolPanel` (the cache
  outlives the shell; symbols hold no text).
- **R-B9-4:** with geometry denied a cell tap sets `armed` but `_activate`
  refuses; the gallery is disabled then anyway, and no highlight shows (the
  tool is not active).
- **R-B10-1:** M-09b1's one-line form (the up without `_resolve`) is
  equivalent at the end-to-end level: the tool follows every pressed move and
  the up arrives where the last move was. Task 6's tool-level test is its
  red test; the two-line form is red end to end.
- **Observation (Task 10a):** the shell has no guard of its own against tool
  letters mid-press; today the tool swallows every mid-press key except F and
  F3, so it is unreachable.
- **Task 2 decisions:** `load()` is once-only; `retry()` from loading or
  ready is a no-op; `catch (e)` catches Errors too (SL5).
- **Task 3 decisions:** the cache key is a Dart record `(key, logicalSize,
  devicePixelRatio, foreground)` compared exactly; failed futures stay cached
  (the library is immutable in a session); `imageFor` after `dispose()` throws
  `StateError`.
- **Task 6 decisions:** after a placement the ghost stays at the release point
  (on touch it lingers until the next event); the matrix's `update` is called
  once, in `paintWorldOverlay`.
- **The real `rootBundle` load** (owed by 09a) works inside `testWidgets`
  without `runAsync` (SL9), and the app-made loader reaches ready over it
  (SL11, 2b).
- **The environment.** Flutter 3.47.2 at `/root/flutter` had to be installed
  in this container (from `storage.googleapis.com`) in the 09a session; 09b
  used it. `flutter pub get` rewrites `packages/jet_cad/analysis_options.yaml`;
  it was never staged.

## Gates of record (Linux container, `CI=true`)

Branch point `75dc2e0`: engine 1,121 + 2 standing; render 974 + 1 skip + 7
standing; app 790.

- **engine** 1,121 + 2 standing (`test/testing/generate_document_test.dart`).
  No engine file changed: `git diff 75dc2e0 HEAD -- packages/jet_cad_2d` is
  empty (checked when this note was written); no task report re-ran the
  engine suite.
- **render** 1,001 + 1 skip + 7 standing (text_ladder rungs 1-5,
  text_lod_ladder rungs 1-2, `RenderBackend.canvas`); 974 + 13 (Task 3) + 10
  (Task 4) + 2 (3b) + 2 (4b) = 1,001. Last run in full by Task 8b's report
  (`00:58 +1001 ~1 -7`) and its re-review (`00:56 +1001 ~1 -7`, the 7 `[E]`
  listed); analyze and format clean (`Formatted 182 files (0 changed)`).
- **app** 885 (Task 10a's report at `c8f7a21`: `03:03 +885: All tests
  passed!`); 790 + 11 (1) + 13 (2) + 8 (5) + 14 (6) + 14 (7) + 14 (8) + 11
  (9) + 5 (1b) + 2 (5b) + 2 (6b) + 1 (10a) = 885; analyze clean, format
  `Formatted 153 files (0 changed)`.
- **web** `CI=true flutter build web --release`: `✓ Built build/web` (Task
  10a's report, at `c8f7a21`).
- **The two allocation invariant tests** are unedited: `git diff 75dc2e0 HEAD
  --stat` over `packages/jet_cad_2d` (which holds
  `test/invariants/query_allocation_test.dart`) and
  `packages/jet_cad_2d_flutter/test/invariants` is empty (checked when this
  note was written). Their green run is part of the engine and render suites
  above.
- **Purity:** `symbol_search.dart` and `symbol_library_state.dart` import only
  `symbol_library.dart`; `rootBundle` appears only in
  `symbol_library_loader.dart` (grep, checked when this note was written).
  `analysis_options.yaml` is not in `git diff 75dc2e0 HEAD --stat`.

## Mutants

The P-8 rule of 09a applies (the plan's Task 10): this table is compiled
from each task's report and independent review, both of which fired real
runs at the task commit; the final whole-branch review re-fires a sample on
the tip. **That sample is not in this note** (the review had not run when it
was written). Line numbers are at the task's commit. Every run restored the
file (`diff` exit 0).

| Id | Where | Red test | Task |
|---|---|---|---|
| M-09k thumbnail key ignores the version | `symbol_thumbnails.dart:76` | T1, T4 "a version change", T5, T6 | 3 |
| M-09x key ignores the logical size / the DPR / the foreground (each) | `symbol_thumbnails.dart:76` | T4 logical size; T2 and T4 DPR; T4 foreground and T8 | 3 |
| M-09y foreground not passed | `symbol_thumbnails.dart:112` | T8 (`Actual: [255, 255, 255]`) | 3 |
| M-09z eviction drops the entry without `release()`; (b) `release()` does not dispose | `symbol_thumbnails.dart:87`; `:170` | T5, T6; T5, T7 | 3 |
| M-09b15 image width ignores the DPR | `symbol_thumbnails.dart:139` | T2 (`Expected: [83, 61]` / `Actual: [41, 61]`), T6, T8, T9 | 3 |
| M-09l search ignores tags | `symbol_search.dart:49` | "tag alone" and four more | 1 |
| M-09s `every` -> `any`; category ignored | `symbol_search.dart:36`; `:50` | "two terms both required" and five more; "category alone", "terms on different fields" | 1 |
| M-09m `isMidShape => false` | `symbol_place_tool.dart:79`; at the shell `:94` | "isMidShape is true between press and release, and notifies"; SS8 (the 12a mid-shape rule) | 6; 9 |
| M-09w `needs` drops structure / geometry / components (each) | `symbol_place_tool.dart:81-83` | "permissions a denied structure / geometry / components ..." (each) | 7 |
| M-09b1 the tool places at the press point | `symbol_place_tool.dart:161` (one-line: no `_resolve` at the up) | "a release places at the snapped release point, not the press" | 6 |
| M-09b1, two-line form end to end (pressed moves ignored and no `_resolve` at the up) | `symbol_place_tool.dart:163` + `:176` | the end-to-end test (`translation [43175.0, 25950.0] vs [40505.0, 27550.0]`) | 10a |
| M-09b2 `placeSymbol` before the permission check | `symbol_place_tool.dart:261` | the three permission tests (`Expected seed 18 Actual 23`) | 7 |
| M-09b3 R the wrong way; Shift+R ignored; M does not mirror | `symbol_place_tool.dart:215`; `:215`; `:218` | "R turns ... counter-clockwise" (+7); "Shift+R turns it clockwise", "keys compose"; "M toggles the mirror" (+4) | 7 |
| M-09b4a linear part omitted; M-09b4b mirror dropped; M-09b4c whole P omitted | `symbol_ghost.dart:154`; `:150`; `:146` | "the matrix maps the base point to at − origin ...", the P-count test, "drawn under the matrix" | 5 |
| M-09b5 `Esc` mid-press does not cancel | `symbol_place_tool.dart:227` | "Esc mid-press cancels: the remaining moves and the up place nothing" | 7 |
| M-09b6 the cell tap bypasses `_activate` | `main.dart:628` | SS3 | 9 |
| M-09b7 the search field without `ShellShortcutGuard` | `symbol_panel.dart:217` | "typing r, w and m in the field fires no shortcut" | 8 |
| M-09b8 `Esc` binding / `onEditingComplete` / `onTapOutside` removed (each) | `symbol_panel.dart:222`; `:233`; `:234` | the matching "hands the focus back to the canvas" test (each) | 8 |
| M-09b9 the highlight ignores the active tool | `symbol_panel.dart:159` | "the highlight follows the active tool and the armed entry"; at the shell SS5 | 8; 9 |
| M-09b10 retry does nothing; retry never runs; the panel's Retry a no-op | `symbol_library_loader.dart:52`; `:54`; `symbol_panel.dart:174` | SL6; SL6; "a failed load shows its message and Retry; Retry reaches ready" | 2; 2; 8 |
| M-09b11 the tab strip without `symbols` | `main.dart:749` | SS1 | 9 |
| M-09b12 the gallery outside `ExcludeFocus` | `symbol_gallery.dart:106` | "a cell and a header never take focus" (`canRequestFocus`; the traversal check also red, by the review's probe) | 4 |
| M-09b13 the ghost path rebuilt per call; per paint in the tool | `symbol_ghost.dart:33`; `symbol_place_tool.dart:220` | "the path is cached"; "the ghost paints the cached path", "a second paint reuses ..." | 5; 6 |
| M-09b14 the rebase origin ignored | `symbol_ghost.dart:96` (and `:97`, review); `symbol_place_tool.dart:228` | the matrix tests (`Expected 3250.5 Actual 73250.5`); the tool's ghost paint tests | 5; 6 |
| M-09b16 the tool places at the raw point | `symbol_place_tool.dart:163`; end to end `:178` | the release, touch, cancel, stays-armed and snap tests; the end-to-end test | 6; 10a |
| M-09b17 the aperture not divided by the scale | `symbol_place_tool.dart:123`; end to end `:138` | "a release within 10 px (not 10 mm) ...", "the snap marker ..."; the end-to-end test | 6; 10a |
| M-09b18 the ghost stays after exit / cancel | `symbol_place_tool.dart:171`; `:188` | "the ghost hides on pointer exit and on cancel" (+ the pointer-cancel test) | 6 |
| M-09b19 the tool does not listen to `armed` | `symbol_place_tool.dart:44` | "re-arming notifies, drops the press and swaps the ghost path" | 6 |
| M-09b20 modifiers not checked for R/M | `symbol_place_tool.dart:211` | "Ctrl, Meta or Alt with R or M is ignored and changes nothing" | 7 |
| M-09b21 a key repeat steps | `symbol_place_tool.dart:213` | "a key repeat is consumed with no effect" | 7 |
| M-09b22 the gallery's `enabled` ignores `components` | `symbol_panel.dart:28` | "a tap reports the entry; a denied structure, geometry or components disables the cells" | 8 |
| M-09b23 a cell shows the cache's image, not a clone | `symbol_gallery.dart:354` | the clone test (+8 at teardown on the double dispose) | 4 |
| Search extras: query / name not lower-cased; empty groups kept; split on one space; category order by first match; reversed within a group | `symbol_search.dart:25, 48, 40, 11, 33, 41` | upper case; name alone; order/empty groups; blank query, white space runs; "a category keeps its library place ..."; four tests | 1, 1 review |
| Search 1b: name / tag / category `contains` -> `startsWith`; key instead of name; key also searched; tags case-sensitive | `symbol_search.dart:48-50` | "a term inside the name / a tag / the category ..."; "a term in the key alone finds nothing"; "a mixed-case tag is found in any case" (all survived at Task 1) | 1b |
| Loader extras: failure swallowed as loading; load() not once; load() after dispose; completion after dispose notifies; retry from any state; `on Exception`; no notify on ready; wrong asset key | `symbol_library_loader.dart:62, 44, 44, 65, 52, 61, 71, 13` | SL2-SL6; SL1; SL8; SL8; SL7; SL5; SL1, SL6, SL7; SL9 | 2, 2 review |
| Wiring extras: host / app does not pass `symbols`; app never loads; app disposes a given loader; app keeps its own alive; the app's own read throws | `document_host.dart:537`, `main.dart:132, 96, 101, 101, 88` | SL10, SL11; SL10; SL10; SL11; SL11 (2b) | 2, 2b |
| Thumbnail extras: pending disposed immediately; cache `dispose` skips entries; FIFO not LRU; off-by-one eviction; canvas not DPR-scaled; builder closure in the key; error not swallowed; use after dispose; no flush | `symbol_thumbnails.dart:154, 98, 77, 85, 119, 76, 158, 74, 129` | T6; T7; T5; T5, T6; T8; T5; T9; T7; T1, T8 | 3, 3 review |
| Thumbnail 3b: padding `0.0 *`; fit on the raw extents; padding `0.25 *`; sink DPR forced to 1.0 | `symbol_thumbnails.dart:114, 117, 114, 125` | T10 (`Actual: [5, 0]`); T10; T10; T11 (`Actual: <96>`) (the first two and the last survived at Task 3) | 3b |
| Gallery extras: highlight ignores `selectedId`; disabled tap calls `onSelect`; collapse ignored; replace / dispose keeps the clone; header count +1; three columns; tooltip shows the id; label on two lines | `symbol_gallery.dart:140, 243, 123, 369, 375, 118, 129, 230, 265` | the highlight, disabled, collapse, clone-replacement, own-clone, header and grid tests | 4, 4 review |
| Gallery 4b: `imageFor` on every widget update; clone after an await gap | `symbol_gallery.dart:330`; `:348` | "a rebuild with the same key requests no thumbnail again"; "a cell whose entry is evicted while pending still shows a clone" (both survived at Task 4) | 4b |
| Ghost extras: arc sweep sign; P recomputed always; path not local; circle radius halved; `writeGhostMatrix` linear; `m[15]` not 1 | `symbol_ghost.dart:61, 131, 44, 54, 89, 77` | the arc tests; the P-count test; the bounds test; the bounds test; the `writeGhostMatrix` test; the matrix tests | 5, 5 review |
| Ghost 5b: `close()` dropped; base point x / y left out of the change check | `symbol_ghost.dart:49`; `:134`; `:135` | "a closed polyline's contour is closed, a line's is not"; "a change of the base point's x alone, then of its y alone ..." (all survived at Task 5) | 5b |
| Tool extras: cancel keeps the press; cancelled moves followed; re-arm keeps the press; listener not removed; matrix per paint; stroke / cross not scaled; ghost ignores `at`; idle not inert; secondary presses; marker at the raw point; no notify on down; cursor basic | `symbol_place_tool.dart:186, 148, 109, 243, 228, 229, 230, 224, 134, 135, 205, 140, 83` | the pointer-cancel, re-arm, dispose, ghost-paint, idle/secondary and snap-marker tests | 6, 6 review |
| Tool 6b: `objectSnap: true`; `gridStepMm: page?.gridStepMm` | `symbol_place_tool.dart:139`; `:141` | "with object snap off (F3) ..."; "with no fixed grid step ... zoom-adaptive step" (both survived at Task 6) | 6b |
| Key extras: F/F3 swallowed; no permission check; idle swallows; inert not checked; R/M not notifying; key-up of R/M consumed; turns not normalised; Ctrl+F bubbles mid-press | `symbol_place_tool.dart:232, 261, 224, 206, 220, 206, 216, 231` | the F/F3, permissions, armed-idle, inert, R and key-up tests | 7, 7 review |
| Panel extras: thumbnail turned / offset / mirrored; foreground ignored; plain unfocus instead of `handBack` | `symbol_panel.dart:43, 199, 132` | "the thumbnail document is the placer's identity output"; "the cells are the entries ..."; the hand-back tests | 8, 8 review |
| Panel 8b: the x / Retry / the empty-result Clear without `ExcludeFocus` | `symbol_panel.dart:242, 301, 331` | the clear, Retry and empty-result tests (`canTakeFocus`; all survived at Task 8) | 8b |
| Shell extras: strip without `ExcludeFocus`; tool / `_armed` not disposed; app / host do not pass thumbnails; own cache not disposed / a given one disposed; shell's own cache not disposed; cell tap does not activate / arm; W consumed armed-idle; tabs ignore a tap; a tab switch changes the tool; host does not key the shell; dispose order swapped | `main.dart:756, 693, 694, 149, 117, 696, 628, 627, 769`, `document_host.dart:543, 534`, `symbol_place_tool.dart:224` | strip: SS6; tool / `_armed`: SS7; passing thumbnails: SS9, SS10; own cache: SS10; a given one: SS9; shell's own: SS11; activate: SS3, SS4, SS5, SS7, SS8; arm: SS3, SS4; W: SS4 (+ SS5); tabs ignore a tap: SS2 (+ SS3-SS9); tab switch: SS2; keying: SS7; dispose order: SS1, SS2 | 9, 9 review |
| End-to-end extras: the cell tap not arming; R not reaching the tool; R swallowed with no turn; the shell / the app not passing the cache; cells show no image; object snap off | `main.dart:785, 778, 149`; `symbol_place_tool.dart:211, 212, 139`; `symbol_gallery.dart:384` | the end-to-end test (each) | 10a |
| **M-09b1 one-line form at the end-to-end level** | `symbol_place_tool.dart:176` | **equivalent, recorded** (R-B10-1); Task 6's tool-level test is its red test | 10a |
| `_entries[cacheKey] = hit` -> `??= hit` | `symbol_thumbnails.dart:79` | **equivalent, discarded** (the key was just removed); replaced by the FIFO mutant | 3 |
| the loader's view offset dropped (`asUint8List()`) | `symbol_library_loader.dart:18` | **survived, accepted as equivalent** under the test binding's fresh buffers | 2 review |

Notes on the table. Mutants that did not compile and are not counted: a
`forOrigin` null check (Task 5 review), a paint guard without `entry == null`
(Task 6 review), a first structure mutant at Task 7's review (re-fired as a
valid one). M-09b17 survived the first form of the end-to-end test (`ec908e2`,
the line's end sat on the coarse grid); the fixture was fixed before any
review (`c8f7a21`). Two shell disposal mutants survived Task 9's first commit
(`641d3dd`, a vacuous probe) and were fixed before any review (`7d3bff7`).
Precondition guards ("the fixtures are not degenerate", including the
hairline fixture of 3c) have no mutant.

## Found, not fixed

- **The ghost's cross allocates four `Offset`s per paint** (Task 6 review):
  O(1), not per entity, within the non-negotiable; could be hoisted.
- **The Symbols panel rebuilds per hover** (Task 8 review): it listens to the
  `ToolController`, which forwards every tool notification, and the symbol
  tool notifies on every hover move (the tool palette does the same); 4b
  guarantees no thumbnail re-request on such rebuilds.
- **The ghost does not follow a wheel zoom until the next pointer event**
  (R-B6-3).
- **The cache-hit/eviction clone race** (R-B4-2): unreachable with 64 entries
  and 27 symbols; the cell would show blank, not break.
- **No shell-level mid-press letter guard** (Task 10a observation): unreachable
  while the tool swallows every mid-press key but F and F3.
- **R-B9-2: the search text clears on a tab switch.**
- `forOrigin` before any `update` throws `StateError`, untested (the tool
  always calls `update` first).
- A closed polyline's `close()` is pinned through `PathMetric.isClosed` (5b),
  not by pixels.
- Task 8 review note 3: the empty-result Clear's focus outcome is not asserted
  directly (covered in effect by the tap-outside test).
- The cosmetic nit at `symbol_panel_test.dart:195-196` (8b re-review).

## The human's look

Copied from the spec's Exit gate. **Nothing is marked done for the human.**
macOS and web (Chrome, Firefox), light theme only:

- the Symbols tab's look (the grid, the group headers, the thumbnails sharp
  on a Retina display);
- category collapse;
- the search box takes focus, typing fires no shortcut, `Enter`, a click
  outside and `Esc` return focus to the canvas;
- clicking a cell arms the tool and the cell highlights;
- the ghost follows the pointer, shows the symbol's lines in the right
  orientation, snaps;
- press-drag-release places (and on a touch screen or a simulated touch);
- `R`, `Shift+R`, `M`, `Esc`;
- two placements, then undo twice and redo;
- switching to the Tools tab and back;
- saving and reopening a plan with symbols;
- a plan saved with an older symbol version opens and its symbols stay.

**A point to judge (R-B9-2):** switching to the Tools tab and back clears the
search text. Keep it, or keep the panel alive across tab switches.
