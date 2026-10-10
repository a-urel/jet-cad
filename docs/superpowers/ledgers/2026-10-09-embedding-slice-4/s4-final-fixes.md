# Slice 4: the final review's fixes (F-1 to F-8)

- **Review:** `s4-final-review.md` (range `4e3ed91..8f45473`).
- **Commits** (pushed to `claude/exciting-pasteur-9m22jv`; rebased onto
  `9a04469`, which another session had pushed meanwhile: main merged in,
  O-10 and O-11):
  - `44b6775` fix(floor_plan): F-1 to F-4, their tests, their docs;
  - `492c70c` test(floor_plan): F-6's killers, F-5's and F-7's docs;
  - `fdf3309` test(floor_plan): `finitePlanJson()` gone (see "Found on the
    rebase").
- **Scratch:** `/tmp/claude-0/-home-user/428cafca-0083-5012-a7ac-5456349e70a8/scratchpad/s4-final-fix/`:
  `mutate.py`, `mutants.out` (first batch), `mutants-f2.out` (F-2 per
  case), `mutants-f3-rerun.out` (F-3 after the theme carve-out),
  `mut/` (one log and JSON run per mutant), `gates.sh`, `gates.out`,
  `gates/` (per-package logs and JSON runs), `pre/` (the full planner
  run before the commits, which found the theme conflict below).
- **Environment:** Flutter 3.47.6 at `/root/sdk/flutter/bin`, `CI=true`.

## Per finding

### F-1: the canvas kept across a change of both side columns

- **Change:** `planner_shell.dart`, the row's canvas `Expanded` keyed
  `Key('chrome-canvas')`.
- **Tests:** `test/host/chrome_change_test.dart` group F-1, four cases
  (both columns → none, none → both, left only → right only, right only
  → left only): after a host `centerOn` and a user pan, the change keeps
  the identical `PlannerView` state, the scale, the table's global
  position, and no fit runs a frame later.
- **Unfixed form (F1, key removed):** RED, all four.

### F-2: nothing lazily made is first made in `dispose()`

- **Change:**
  - shell: the status, tools and selection relays, Undo's and Redo's
    flags and the file flags are made at first use (nullable backing
    fields with getters) and disposed only when made; the history
    listener and `didUpdateWidget`'s deliveries touch only those made;
  - service view: `_pageReady` is made in `initState` beside `_canMerge`
    and `_canSplit`.
- **Tests:** chrome_change_test group F-2: both modes × (service bar
  hidden; editor bar hidden; both hidden with no column under
  `readOnly`), a host swaps the controller and disposes the old one in
  the same step; `takeException()` null on both frames.
- **Unfixed forms**, run one case per process (a failure in dispose
  corrupts the next test's tree, so a single run showed cascades):
  - F2a, the status relay made by dispose: RED in design / editor bar
    hidden and design / no column; the four others are green (the
    shell is not mounted, or the bar made it);
  - F2b, the selection relay made by dispose: RED in design / no column;
  - F2c, the page flag made at the bar's first build: RED in selection /
    service bar hidden and selection / both hidden;
  - F2d, Undo's flag made by dispose: survives all six. Equivalent under
    `FloorPlanView`: the flag listens to the shell's own tool relay only
    (the view passes no `busy`), and the tools are disposed after it.
    Guarded anyway, for a bare shell given a host `busy`.
- The tools (`_entries`, `_symbolTool`) stay `late final`: in debug the
  `initState` assert makes them; they subscribe only to the shell's own
  notifiers.

### F-3: chrome changed in the mode shown keeps the plan in place

- **Change:**
  - `FloorPlanView._keepPlanInPlace`, at each view build (through
    `_ChromeOrigins`, so a theme change too) and each mode build: when
    the mode is the one last laid out and its chrome origin moved
    (a bar shown or hidden, the editor's left column or rulers), it calls
    the controller's `@internal chromeMoved(from, to)`; a mode changed
    since is only recorded (the switch reframes, R-13); the record is
    reset on a controller swap;
  - `FloorPlanController.cameraController` is now a private
    `_ViewCamera` (a `CameraController` subclass, the getter's type
    unchanged): `panUnheard` pans at once and holds the notification for
    after the frame (once per frame; dropped if the controller is
    disposed first). Panning with an ordinary notification during the
    view's build asserts in any host widget outside the view that
    listens to `camera` (mutant F3c). The frame being built lays out and
    paints at the new value: every layer under the canvas is laid out
    again because the canvas changed size, and the overlays' render
    object re-places when the camera value is not identical.
  - No camera command: a fit requested and not yet performed still
    overrides it.
- **The theme's bar height is not compensated.** The ruling listed it;
  the full planner run before the commits found three existing tests in
  `theme_service_test.dart` (T3-d, RV5, "60 -> 44") that pin Slice 3's
  S-10: a runtime change of `serviceBarHeight` moves the canvas **and
  the plan with it** ("the plan moves with the canvas"), as the guide's
  § 9 says. Existing tests may not be edited, so the bar's height keeps
  that rule: when the selection bar was shown at the last build, its
  origin is re-based to today's height before comparing, so only a bar
  shown or hidden pans. **The controller should rule** whether S-10
  changes (then those three tests and § 9 change with it).
- **Tests:** chrome_change_test group F-3: design, the left column
  (`full` ↔ `readOnly`, ±240 px); design, the editor bar (±44) and the
  rulers (±`kRulerThickness`); selection under a 60 px theme, the bar
  hidden and shown (±60), then the theme at 44 moves the plan with the
  canvas (camera identical) and a hide at 44 pans by 44; a mode switch
  after a change in place; a change right after a mode switch the host
  made without rebuilding the view. Each change checks at its first
  frame the camera's forward transform from the canvas origin, a host
  overlay's centre and the painted pixels of a 60 × 60 square round the
  table (largest channel difference ≤ 2: hiding the 44 px editor bar
  rounds three edge pixels one level apart, at the first and the settled
  frame alike), then after the frame `canvasRect`, `worldToGlobal` and a
  host widget beside the view rebuilt with the identical camera value.
  Also: a rebuild with default chrome leaves the camera the identical
  object (both modes); a controller swapped back with other chrome in
  one step keeps its camera; the held notification arrives once after
  the frame, and is dropped when the controller is disposed first.
- **Unfixed form and parts:**
  - F3a, no pan: RED (5 tests);
  - F3b, no record at a mode build: RED (the change right after a mode
    switch);
  - F3c, the pan heard at once: RED (7 tests, the host widget's
    "setState() called during build");
  - F3d, the held notification sent after dispose: RED;
  - F3e, the record kept across a controller swap: survived the first
    batch, so the swap-back test was added; RED with it;
  - F3f, the theme's height compensated too: RED in the three
    theme_service tests and mine.
- **Docs:** the guide's bars sentence ("from the first frame, in both
  modes"), its left column sentence and the CHANGELOG's bars sentence
  were right as written and now match. The guide's camera paragraph
  says the view pans the camera when its bars, left column or rulers
  are shown or hidden, heard after that frame; `serviceBar`'s,
  `editorCapabilities`' and `camera`'s docs say so. § 9's bar bullet and
  the CHANGELOG's theme bullet are unchanged (S-10, above).

### F-4: an Export or a Print refused while under way hands nothing over

- **Change:** `PageFlows` takes optional `exportAllowed` and
  `printAllowed` (default allowed). Export re-reads `exportAllowed` once
  the dialog (Material or the host's) has answered, and through its
  `cancelled` once the bytes are made; Print through its `cancelled` once
  the bytes are made, before the printer is called. A refusal is a
  cancel: nothing is handed over, the answer is not remembered. The view
  passes `mode != design || editorCapabilities.export` (and `.print`):
  the selection mode is never refused (S-22). A view disposed meanwhile
  keeps its earlier path (the bytes' cancel).
- **Tests** (page_flows_test): PF22, the Material dialog open, `export`
  refused, OK: nothing exported, `exportChoice` still initial; allowed
  again, the same steps export. PF23, a host dialog answering after the
  refusal; a refusal while the bytes are made; the selection mode
  exporting under the same refusal. PF24, Print refused while its bytes
  wait on the font (the asset held through the test messenger's
  `allMessagesHandler`), nothing printed; allowed, it prints.
- **Unfixed forms:** F4a (no check after the dialog) RED PF22; F4b (no
  check after the bytes) RED PF23; F4c (Print not re-checked) RED PF24;
  F4d (the check also in the selection mode) RED PF23; F4e (the view's
  print check never refuses) RED PF24.
- **Docs:** the guide's run-time paragraph and the CHANGELOG's
  capabilities bullet.

### F-5

The CHANGELOG's *A fix a 0.3.0 host may notice*: "A host's own shortcuts
above the view no longer receive Backspace, Delete, typing keys or Ctrl+A
from the planner's text fields: the field keeps them."

### F-6: the killers

| Mutant | Killer | Result |
|---|---|---|
| S05 | `bars_test` K1 (the reviewer's, at the editor surface) | RED |
| S25 | `host_text_keys_test`, both modes: K down, two repeats, up in a field; the host's K never fires | RED (both) |
| S26 | `editor_tools_test` K3: `selectTool(wall)`, `selectTool(select)` and `deleteSelection()` after a `load` | RED |

### F-7

Recorded in the guide's capability limits and the CHANGELOG's known
limits: a table symbol tagged `against-wall` still turns to its wall
when moved or placed under `rotate: false` (none bundled is;
`snapping: false` turns the attachment off, confirmed in
`SymbolMoveResolver.resolveMove`).

### F-8

Nothing (the controller's).

## Found on the rebase

`503c504` (on origin) removed `page_flows_test`'s `finitePlanJson()`, but
`keyboard_focus_test` line 497 still called `pf.finitePlanJson()`, so at
`9a04469` that file did not compile (`flutter analyze`: an
`undefined_function` error), and my PF22 to PF24 called it too. `fdf3309`
uses `embeddingPlanJson()` in both, as `503c504` did. That one line of
an existing test is the only existing-test edit; the other test diffs
only add tests (and widen two imports).

## Gates (at `fdf33090b18340d28a38ff97b2b9b20dbd1582bc`; `gates.out`)

| Package | Tests | Standing comparison | Analyze | Format |
|---|---|---|---|---|
| `jet_cad_floor_plan` (`--enable-vmservice`) | `05:40 +1912: All tests passed!` | `1912 tests; the standing failures and skips, exactly` | No issues found! | 280 files, 0 changed |
| `apps/restaurant_demo` | `00:39 +68: All tests passed!` | `68 tests; … exactly` | No issues found! | 9 files, 0 changed |
| `apps/floor_planner` | `01:22 +212: All tests passed!` | `212 tests; … exactly` | No issues found! | 47 files, 0 changed |
| `jet_cad_restaurant_symbols` | `00:02 +97: All tests passed!` | `97 tests; … exactly` | No issues found! | 15 files, 0 changed |
| `jet_cad_2d_flutter` | exit 1 (its standing failures) | `1437 tests; … exactly` | No issues found! | 228 files, 0 changed |
| `jet_cad_2d_gpu` | `00:00 +20: All tests passed!` | `20 tests; … exactly` | No issues found! | 10 files, 0 changed |
| `jet_cad_2d` (`dart test`) | exit 1 (its standing failures) | `1272 tests; … exactly` | `--fatal-infos`: No issues found! | 171 files, 0 changed |
| `tool/ci` | `dart test` `00:06 +63: All tests passed!` | — | `--fatal-infos`: No issues found! | 11 files, 0 changed |

- `check_guide`: `docs/host-guide.md: all 48 code blocks are in the host probe`, exit 0.
- Host probe, `tool/ci/host_probe.sh file:///home/user/jet-cad fdf33090b18340d28a38ff97b2b9b20dbd1582bc` after the push, exit 0: the lock "40 packages, none of flutter_scene, flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu"; analyze clean; "✓ Built build/web", "host probe: no GPU renderer, no build hook; build/web is 42M".
- `tool/ci/old_host_probe.sh v0.3.0`, exit 0: "No issues found!", "old host probe: v0.3.0's main.dart analyses against fdf33090b18340d28a38ff97b2b9b20dbd1582bc".
- `git status` clean afterwards (no `analysis_options.yaml` touched); the branch is even with origin.
- The full planner run before the commits (`pre/`, on the unrebased tree) is the one that showed the three `theme_service_test` failures of F-3's first form.
