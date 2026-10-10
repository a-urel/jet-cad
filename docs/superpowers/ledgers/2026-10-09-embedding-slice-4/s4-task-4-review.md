# Slice 4, Task 4: capabilities I — the type, the tools, the Symbols tab (independent review)

- **Commit reviewed:** `5c72a5e` (parent `e8a21a0`), branch `claude/exciting-pasteur-9m22jv`.
- **Where I worked:** two clones of my own:
  - `/home/user/review-s4t4`, at `5c72a5e`: the gates and the fix experiments;
  - `/home/user/review-s4t4b`, first at `e8a21a0` for the base side of the differential, then at `5c72a5e` for the mutants.

  I deleted both when the review was done. I edited, committed and pushed nothing in `/home/user/jet-cad`; this file is the only one I wrote there.
- **Scratch:** `/tmp/claude-0/-home-user/428cafca-0083-5012-a7ac-5456349e70a8/scratchpad/rv-s4t4/`. It holds:
  - the differential: `zz_review_diff_test.dart`, `diff-{base,new}.txt` and `.norm`;
  - the probes: `zz_rv_probes_test.dart` (RV1–RV11), `zz_rv_probes2_test.dart` (RV12–RV14), `zz_rv_probes3_test.dart` (RV12b, RV15) and `zz_rv_probes4_test.dart` (RV12c, RV12d), with their logs `rv12.log`, `rv12b-fix.log` and `probes3-task.log`;
  - the mutation runner `mutate.py`, its results `mutants.out` and its logs `mlogs/`;
  - the gate runs: `gates.sh`, and in `gates/` the JSON runs, logs and `summary.txt`.
- **Environment:** Flutter 3.47.6 at `/root/sdk/flutter/bin`, `CI=true`.

## Verdict

**Approve once R-1 and R-2 are fixed. R-3's killers should land in the same fix commit.**

- **What holds:**
  - The type is right field by field (S-12).
  - With the default capabilities, the editor matches `e8a21a0` pixel for pixel, element for element and key for key (a scripted differential, below).
  - Every gate passes with the real counts.
  - Every named and task-local mutant is red, each for a real expectation, not a compile error.
- **What does not hold:**
  - **R-1 (Important):** a mirror or turn set while it was allowed survives a change to a profile that forbids it. `full` → `tablesOnly` then places a **mirrored table**.
  - **R-2 (Important):** a runtime `rulers` change while any drawing tool is active throws `setState() or markNeedsBuild() called during build` in debug.
  - **R-3 (Minor):** fourteen of my own 24 mutants survive the task's suite. My probes kill six of them; the rest are equivalent, defensive, or untested paths I list.

## What I verified, and how

### 1. Scope, P-1 and P-6

**The changed files** (`git diff --name-status e8a21a0 5c72a5e`):
- In `lib`: the barrel, `editor_capabilities.dart` (new), the controller, the view, the shell, `symbol_panel.dart`, `symbol_place_tool.dart` and `tool_palette.dart`.
- In `test`: `barrel_test.dart` (B1 gains the three names, and nothing else changes), plus three new files.
- Nothing in `apps/`, `tool/`, `jet_cad_2d` or `jet_cad_2d_flutter`.
- No golden, counter or allocation test was touched, and no `analysis_options.yaml`.

**The barrel** gains exactly `FloorPlanEditorCapabilities`, `FloorPlanSymbol` and `FloorPlanTool`. `validateEditorCapabilities`, `leftColumnShown` and the `@internal` controller members stay out of it.

**Every new parameter is named and optional, with today's value as its default:**
- `PlannerShell.capabilities`, `onTools` and `onToolChanged`;
- `ToolPalette.showFill`;
- `SymbolPanel.filter` and `placeable`;
- `SymbolPlaceTool.canRotate` and `canMirror`;
- `FloorPlanView.editorCapabilities`.

**The differential** (`zz_review_diff_test.dart`, run on `e8a21a0` and on `5c72a5e` with `--dart-define=OUT=…`):

- **View setup:** `FloorPlanView` with no new parameter over the startup flat, at 1800 × 1100, with a fixed panned camera.
- **Recorded:**
  - the keyed chrome present;
  - a pixel hash of the whole view;
  - the render tree and the element tree, as `toStringDeep` with identity hashes stripped;
  - for each letter, V L P R B W D N G M S I C A T in turn: the status line, the selected palette row, three clicks and the document hash after each, then Enter, Escape and Escape;
  - F (the Fill checkbox), F3 twice (the OSNAP text), Ctrl+Z three times, Ctrl+Shift+Z, Ctrl+Y and Ctrl+E (the dialog), each with the document hash;
  - the Symbols tab: pixels and both trees, then arming `dining.table.round`, R, M and a click;
  - the selection mode's pixels, and the pixels back in the design mode.
- **The bare shell** (`PlannerShell(document: startupPlan)`): its keys, pixels and trees, then W, F, F3 and pixels again.
- **The comparison:** the two 53,479-line traces differ only in Dart library-private ids (`@1657220820` vs `@1658220820`) and in `OrdinalSortKey` hash names. After normalising those two (`diff-*.norm`), `diff` exits 0. Every `SHOT` hash, every `DOC` hash, every key's `handled` result and every status line is identical.

### 2. Correctness

**The type** (by reading the code and by EC1–EC7):
- **The three profiles are exactly as S-12 lists them.** `full`'s `selectTablesOnly` is false, its only restriction flag. `tablesOnly`'s filter is a private static function, so the profile stays `const`.
- **`copyWith`:** a null argument keeps the field, the filter included.
- **`==` and `hashCode`:** the tools are compared as a set (`hashAllUnordered`) and the filter by `==`.
- **`toString`** lists only what differs from `full`.
- **Validation:** the view throws an `ArgumentError` named `tools` at build when `select` is missing, in both modes (T4-i).

**The shell**, by reading the code and by probes:
- **One choke point.** `_activate` refuses a tool outside `tools`. The palette lists the allowed rows only, and only the allowed letters are bound, so a refused letter reaches the host (M-H41).
- **Fill.** The Fill row and F exist only while Polyline, Rectangle or Circle is allowed. RV7: `{select, circle}` shows the row and F is the shell's; `{select, line}` shows no row and F reaches the host.
- **The symbol tool** needs `symbol` in `tools` and `symbolPalette`, and its filter is applied before the search. With `symbol` refused, the Symbols tab is shown but its gallery is disabled.
- **R and M** are gated by `rotate` and `mirror` at each key. **This is where R-1 sits.**
- **The bar's commands are filtered from the commands the shell was created with,** so a runtime change brings them back. RV9: `print: false, undo: false` → no Print, no Redo, and Ctrl+Z reaches the host and undoes nothing.
- **Snapping.** `snapping: false` unbinds F3 and hides OSNAP. `_CapabilitySnap` turns object snap off for the tools and for the select tool's grip drags. RV11: a free line's end grip-dragged to 12/8 mm off the column corner lands on the corner (23,500, 13,800) under `full`, and on the grid point (23,475, 13,800) with `snapping: false`. The user's setting is kept (the task's own test).
- **Rulers and grid** reach `PlannerView`.
- **The left column** is built only by `leftColumnShown`. RV8: `{select, symbol}` with `symbolPalette: false` gives no column.
- **The canvas is re-measured** on a rulers or left-column change. RV15: removing the column while the selection mode is shown, then switching back, puts table `1` exactly where it was, in the first frame and after it.

**Runtime changes:**
- **M-H47 (runtime):** a tool the new capabilities refuse falls back to select.
- **T4-c:** an armed chair refused falls back.
- **RV4:** an armed table falls back when only `symbolPalette` goes false.
- **RV5:** an armed chair falls back when only the filter changes.
- **RV10:** a pending line under `readOnly` → select, and nothing more is added.
- **Restoring the capabilities** brings everything back (T4-e, T4-g, T4-j).

**`activeTool` and `selectTool` (S-6):**
- **T4-b:** `selectTool` is false in the selection mode and with no editor.
- **T4-c / T4-b:** `symbol` re-activates only an armed entry that is still offered.
- **RV6:** with the view unmounted, `activeTool` reads select and `selectTool` answers false.
- **T4-h:** the selection mode reads select.

### 3. Gates (my runs, on `5c72a5e`)

| Package | Test | Standing comparison | Analyze | Format |
|---|---|---|---|---|
| `packages/jet_cad_floor_plan` (`flutter test --enable-vmservice`) | `06:04 +1769: All tests passed!` (PA1–PA3 ran; no skip) | `1769 tests; the standing failures and skips, exactly` | No issues found | 271 files, 0 changed |
| `apps/restaurant_demo` | `00:52 +60: All tests passed!` | `60 tests; … exactly` | No issues found | 8 files, 0 changed |
| `apps/floor_planner` | `02:45 +212: All tests passed!` | `212 tests; … exactly` | No issues found | 47 files, 0 changed |
| `packages/jet_cad_2d_flutter` | `01:48 +1397 ~1 -7: Some tests failed.` | `1405 tests; … exactly` | No issues found | 227 files, 0 changed |
| `packages/jet_cad_2d` (`dart test`) | `00:38 +1256 -2: Some tests failed.` | `1258 tests; … exactly` | No issues found (`--fatal-infos`) | 170 files, 0 changed |

These match the report's counts.

### 4. Mutants

I applied all 52 with `mutate.py`. Each edit is an exact, unique string replacement. The runner restores the file from a copy and checks it with `git diff --quiet`. For each mutant it runs `editor_tools_test.dart` and `editor_capabilities_test.dart`. If those stay green, it also runs my probes. Every red row below failed on an expectation, not a compile error (`compile_error=False` throughout). I read the failing expectations in `mlogs/`.

**The named and task-local mutants** (the implementer's list, reapplied): **all red.**

| Mutant | Red by | Expectation seen |
|---|---|---|
| M-H41 (bound, `_activate` refusing) | M-H41, T4-d | host's L: expected 1, got 0 |
| M-H41 (bound and allowed) | M-H41, T4-c, T4-d, … | host count 0 |
| M-H47(runtime tool) | M-H47(runtime tool), T4-c | `activeTool` symbol / wall, expected select |
| M-H47(symbolFilter) | M-H47(symbolFilter) | the gallery's key set |
| T4-a rows / T4-a Fill row | T4-a (and M-H47 runtime) | `tool-line` / `tool-fill` found |
| T4-b shell / T4-b mode | T4-b | `selectTool(wall)` true |
| T4-c | T4-c, T4-a | `activeTool` symbol |
| T4-d M / P-rotate | T4-d | det −1.0; host's R 0 |
| T4-e export / T4-e undo | T4-e | the button is found, or the host count is 0 |
| T4-f object snap / P-snap-f3 / P-snap-readout | T4-f | start x 23,500, expected 23,475; host's F3 0; `osnap-text` found |
| T4-g rulers / grid / re-measure | T4-g | `RulerFrame` found; 2 colours; table off |
| T4-h listener / T4-h mode | T4-h (and others) | `activeTool` stale |
| T4-i | both T4-i | no exception |
| T4-j column / T4-j re-measure | both T4-j | `chrome-left` found; table off |
| P-defer | M-H47(runtime), T4-c, … | `markNeedsBuild() called during build` |
| P-fill-key | M-H41 | host's F 0 |
| P-placeable | the Symbols tab without the symbol tool | `enabled` true |

**My own mutants (24): 10 red in the task's suite, 14 survive it.**

| # | Mutant | Task's suite | My probes |
|---|---|---|---|
| O1 | `==` ignores `symbolFilter` | red (EC4) | |
| O2 | `hashCode` hashes `tools` ordered | red (EC4) | |
| O3 | `copyWith`: `rulers: rulers ?? this.grid` | **survived** | survived |
| O4 | `toString` omits the filter | red (EC5) | |
| O5 | `tablesOnly` with `delete: false` | red (EC2, EC5) | |
| O6 | `readOnly` with `export: false` | red (EC2, EC5) | |
| O7 | Fill ignores Circle | **survived** | red (RV7) |
| O8 | the left column counts the symbol tool | **survived** | red (RV8) |
| O9 | the fallback runs only when the tools change | **survived** | red (RV4, RV5) |
| O10 | `_offers` ignores `symbolPalette` | **survived** | red (RV4) |
| O11 | the withdrawal announces nothing | **survived** | red (RV6) |
| O12 | an immediate `toolChanged` keeps a pending one | **survived** | survived (defensive; a post-frame interleaving I could not reach) |
| O13a | the dimension grips' object snap reads the user's setting | **survived** | survived |
| O13b | the opening slide grip's edge aperture reads the user's setting | **survived** | survived |
| O14 | `ToolContext.snap` is the user's setting | red (T4-f) | |
| O15 | `selectTool(symbol)` without the armed check | red (T4-b, the Symbols tab test) | |
| O16 | `FloorPlanSymbol.of` keeps the tags as given | survived | **equivalent**: `SymbolEntry` already makes them unmodifiable (`symbol_library.dart:62`) |
| O17 | `FloorPlanSymbol.==` ignores `category` | red (EC6) | |
| O18 | validation checks `isEmpty` | red (T4-i ×3) | |
| O19 | Export gated by `print` | red (T4-e) | |
| O20 | R gated by `mirror` | red (T4-d) | |
| O21 | the panel's tap ignores the filter | survived | **equivalent**: a filtered entry has no cell, and `_activate` refuses it anyway |
| O22 | the Symbols tab ignores `symbolPalette` | **survived** | survived |
| O23 | the default bar keeps an empty `DocumentToolbar` | **survived** | survived |
| O24 | Print never filtered | **survived** | red (RV9) |

## Findings

### R-1 (Important): a mirror or turn set while allowed is used under a profile that forbids it

**Evidence.** The probes are in `zz_rv_probes_test.dart`; on `5c72a5e` they read as follows:
- **RV1:** under `full`, arm `dining.table.square.two`, press M, then the host switches to `tablesOnly`. The table is still offered, so the symbol tool stays armed. A click places it with `det = −1.0`: a **mirrored table under `tablesOnly`**, whose spec text is "no mirror".
- **RV2:** under `full`, arm the table, press M, press Escape. Switch to `tablesOnly`, arm the table again from the Symbols tab, click: `det = −1.0`.
- **RV3:** under `full`, arm the table, press R, then switch to `tablesOnly.copyWith(rotate: false)`. The click places it turned 90° (`a = 0, b = 1`).

**Cause.** `SymbolPlaceTool._quarterTurns` and `_mirrored` are never reset:
- not on arming (`_onArmed`);
- not on a capability change.

`canRotate` and `canMirror` gate only the keys (`symbol_place_tool.dart:394-396`). The placement, the ghost and the wall attachment read the raw state (`_syncPlacement`, `_syncAttachment`, `_place`).

The task's own T4-d presses M a second time under `full` before it leaves `full`, which hides this. Its last step pins RV3's behaviour as intended ("the next placement keeps its turn").

**Why it matters.** It is an R-4 hole reachable through the stock profiles. A host that switches a user between `full` and `tablesOnly` (edit plan / place tables) lets a mirrored table be placed under `tablesOnly`.

**Fix.**
- **Bound the orientation the tool uses by the gates:** `int get _turns => (canRotate?.call() ?? true) ? _quarterTurns : 0;` and `bool get _mirror => _mirrored && (canMirror?.call() ?? true);`.
- **Use them in all three places:** `_syncPlacement`, `_syncAttachment` and `_place`.
- **I tried exactly this in my clone:**
  - RV1 and RV2 turn green;
  - RV3 places the table unturned;
  - the task's suite stays green except T4-d's last step, which asserts the old "keeps its turn".
- **Mirror (required):** the mirror gate as above.
- **Rotate (recommended):** the rotate gate as above, with T4-d's last expectation changed to `a = 1, b = 0`. If the controller prefers "a turn made while allowed is kept", keep T4-d as it is and gate the mirror only.
- **Killer:** RV1 and RV2 land as tests. Mutant: drop `_mirror` from `_place` → RV1 red.

### R-2 (Important): a runtime `rulers` change while a drawing tool is active throws in debug

**Evidence.**
- **RV12c** (`zz_rv_probes4_test.dart`): press L (or W), with nothing clicked, then `h.caps.value = full.copyWith(rulers: false)` and one pump. `tester.takeException()` is non-null for line and for wall, and null for select. **RV12d:** changing `grid` throws nothing.
- **RV12 / RV12b** (`rv12.log`): with a wall part-way, four such assertions are thrown and the pending wall is lost. The text of each is `setState() or markNeedsBuild() called during build … The widget which was currently being built … was: PlannerView`.

**The chain** (the stack in `rv12.log`):
1. `PlannerView.build` wraps or unwraps its drawing area in `RulerFrame` (`planner_view.dart:329-335`).
2. The area is re-parented, so `InteractionLayer` is deactivated.
3. `_release` → `PlacementTool.cancel`. This always notifies: it is not idempotent, despite the comment at `interaction_layer.dart:455-458`.
4. `ToolController._forward` notifies the shell's listeners outside `PlannerView`: the status line's `ListenableBuilder` and the Undo/Redo `DerivedFlag`s.
5. The framework asserts.

**Why it is this task's.** Before this commit nothing changed `PlannerView.rulers` at runtime. T4-g toggles it only with select active, whose cancel returns early. A host with its own "rulers" toggle hits this as soon as the user has a drawing tool armed. The remount also re-runs the layer's `autofocus`, which is Task 6's concern.

**Fix.** Cancelling the tool first in the shell's `didUpdateWidget` is **not enough**. I tried it (`rv12b-fix.log`): two assertions remain, because `PlacementTool.cancel` notifies again on deactivate. Two workable options:

- **(a) In `jet_cad_floor_plan`, within this task's files (recommended).**
  - Route the shell's own listeners on `_tools` through a frame-safe relay. Those listeners are the `_status` merge, the palette's builder and the command flags.
  - The relay forwards a notification at once, except during `SchedulerPhase.persistentCallbacks`, when it forwards it after the frame. This is the pattern `FloorPlanController.toolChanged` already uses (the report's Finding 2).
- **(b) Keep `PlannerView`'s tree stable across `rulers`, so the layer is never re-parented.** This needs `RulerFrame` to take a "hidden" mode, a `jet_cad_2d_flutter` edit. The plan allows render edits only in Task 3, so this needs the controller's ruling.

**Killer:** RV12c as a test: with W, toggle `rulers` → no exception, `activeTool` still wall, and the status line reads `Wall` after the frame. Mutant: remove the relay → red.

### R-3 (Minor, tests): untested paths and a degenerate fixture

The survivors above, with their killers:

- **O3: EC3's fixture is degenerate.**
  - **Why it survives:** EC3 flips one flag at a time on `full`, `tablesOnly` and `readOnly`, and in all three `rulers == grid == true`. So `rulers: rulers ?? this.grid` cannot be told apart. This is CLAUDE.md's degenerate-fixture failure mode.
  - **Killer:** add a base where every flag differs from its neighbour, e.g. `full.copyWith(rulers: false, print: false, …)`, and assert that `copyWith()` with no arguments equals it field by field.
- **O7, O8, O9, O10, O11, O24: land my probes RV7, RV8, RV4, RV5, RV6 and RV9.** Each turned its mutant red above. Each is about 10 lines, through `mountEditor`.
- **O22: the Symbols tab is shown under `symbolPalette: false` while `tools` still holds `symbol`.** The spec says the tab is shown only with `symbolPalette`.
  - **Killer:** `full.copyWith(symbolPalette: false)` → no `tab-symbols`, and `chrome-left` present.
- **O13a / O13b: `snapping: false` is unproven for the dimension grips' object snap and the opening slide grip's edge snap.** RV11 covers a line's end grip only.
  - **Killer:** with `snapping: false`, drag the separator's opening slide grip to within the aperture of the column corner → it lands off the corner; under `full`, on it.
- **O23: the default bar with every command refused keeps an empty `DocumentToolbar`.** Task 2's review R-5/O20 names the same 16 px.
  - **Killer:** `full.copyWith(export: false, print: false, undo: false)` → no `DocumentToolbar`, and `status-text` at the bar's left padding.
- **O12** is a defensive line. I found no reachable interleaving; no test is required.

### R-4 (Info)

- **`tools` is not copied.**
  - **The problem:** a host that mutates its own `Set` after passing it changes the old value too. `didUpdateWidget` then sees `old == new`, so a now-refused active tool never falls back.
  - **Fix:** the `const` constructor cannot copy the set, so document "pass an unmodifiable set" on `tools`, and have `copyWith` wrap it in `Set.unmodifiable`.
- **`FloorPlanEditorCapabilities`' doc is ahead of the code at this commit.** It says `move` … `changeLayer` act "by every path (grips, keys, panel fields)", but until Task 5 a `readOnly` user can still drag, delete and edit panel fields. This is fine if Task 5 lands before any release.
- **RV14:** a filter that refuses every symbol, with an empty query, shows the no-match line for `""`. It is harmless, but the guide could mention it.
- **The view's `editorCapabilities` doc** claims the plan stays in place across a re-measure. RV15 confirms that for the left column. The one-frame limit Task 2's review R-3 found for a bar toggled in the mode not shown still stands for the bars; amend both docs in Task 2's fix.

## Rulings on the implementer's findings

1. **The fixture's window:** **accepted.** At 0.37 px/mm the flat cannot be on screen in an ordinary window. `kEditorSurface` frames every object the fixture adds. Tasks 5 and 6 mount in it.
2. **`activeTool` announced after the frame when the change happens during a build:** **accepted, and necessary.**
   - **P-defer shows the alternative asserts.**
   - **The deferral is sound:**
     - an immediate change clears a pending one (`_pendingTool = null`);
     - the callback checks `_disposed`;
     - "after one pump" holds, because the post-frame callback runs inside that pump.
   - **Use the same pattern for R-2's relay.**
3. **A refused R or M is any other key, so under a profile allowing Rectangle or Room it switches tools while a symbol is armed:** **accepted as designed.** The plan says "a refused key bubbles", and this matches W switching to Wall today. None of the three profiles reaches it. Record it in the guide's limits (Task 7). Swallowing the key while armed would stop it reaching the host, which M-H41's spirit forbids. Note that R-1's fix is separate: this ruling covers the keys, not the stored orientation.
4. **`selectTool(symbol)` only re-activates an armed entry:** **accepted** (S-6). It is a limit for the guide.
5. **T4-f's raw point is the grid point:** **accepted.** The test computes it independently from the page and the engine's `dragGridStepMm`. My RV11 lands on the same grid point (23,475, 13,800) for a grip drag.
6. **Internals beyond the plan's list:** **accepted.** All are optional or `@internal`. `ShellToolRegistrar` leaks through `lib/editor.dart`'s whole-file export, as Task 2's `ShellIdleRegistrar` does. Nothing new enters the barrel.
7. **`tablesOnly`'s filter is private:** **accepted.** A host reads `FloorPlanEditorCapabilities.tablesOnly.symbolFilter`. A public name would be a new member (R-1 of the spec).

Findings 8 and 9 are notes and are confirmed. `didUpdateWidget` is where Task 5's `gatesChanged()` belongs, and `_CapabilitySnap` already gates the select tool's drag snap (RV11). The moved line numbers match `e8a21a0`.
