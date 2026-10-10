# Slice 4, Task 4: capabilities I — the type, the tools, the Symbols tab (implementer's report)

- **Branch:** `claude/exciting-pasteur-9m22jv`, from `e8a21a0` (Task 3).
- **Commit:** `5c72a5e`. Pushed as `e8a21a0..5c72a5e`.
- **Environment:** Flutter 3.47.6 at `/root/sdk/flutter/bin`, `CI=true`. Scratch files, the mutant runner and its logs: `/tmp/claude-0/-home-user/428cafca-0083-5012-a7ac-5456349e70a8/scratchpad/s4t4-impl/` (`mutate.py`; `mutants.log` and `logs/` for the final round on the committed tree, `mutants-round1.log` and `logs1/` for the first; `gates.sh`, `gates.out` and the per-package `*.json`, `*.test.log`, `*.cmp.log`, `*.analyze.log`, `*.format.log`; `base_query.log` and `q_test.dart`, the base run of the bundled library's search).
- **`analysis_options.yaml`:** none touched or committed; `git status` before the commit showed only the task's twelve files.
- **Scope:** Task 4's Builds and Tests only. The select tool's gates, the grip cache's wiring, `selectTablesOnly`, the panels and their fields are Task 5's and are not touched (`move`, `rotate` beyond the symbol tool's R, `reshape`, `delete`, `renumber`, `changeLayer`, `selectionPanel`, `layerPanel`, `pagePanel`, `editLayers`, `editPage`, `selectTablesOnly` exist on the type and are read by nothing yet). The engine and `jet_cad_2d_flutter` are not edited. No golden, counter or allocation test is edited. The only edited existing test is B1 in `barrel_test.dart` (+3 names), which the plan names.

## Files

| File | What |
|---|---|
| `lib/src/host/editor_capabilities.dart` (new) | `enum FloorPlanTool` (the palette's fifteen in its order, then `symbol`; S-6). `final class FloorPlanSymbol` (`key`, `name` — the library's stored name, S-23 — `category`, `tags`, `seats`; `const` constructor; `==`, `hashCode`, `toString`) with an `@internal factory FloorPlanSymbol.of(SymbolEntry)` (tags `List.unmodifiable`). `final class FloorPlanEditorCapabilities`: C-5's twenty-two fields; a `const` constructor whose defaults are `full`; `static const full, tablesOnly, readOnly` as S-12 lists them (`tablesOnly`'s filter is a private static function, so the profile is `const`); `copyWith` (null keeps, the filter included); `==` / `hashCode` over every field (tools as a set, `symbolFilter` by `==`); `toString` naming only what differs from `full` (`symbolFilter: given`). Internal `validateEditorCapabilities` (an `ArgumentError` named `tools` without `select`) and `leftColumnShown(caps, symbols:)` (S-13), the one rule the shell and the view share. |
| `lib/src/planner_shell.dart` | An optional `capabilities` (`full`), `onTools` (`ShellToolRegistrar`, new typedef) and `onToolChanged`. `_activate` returns whether the tool is now active and refuses a tool the capabilities do not allow (`_allows`: select always; a palette tool by `tools`; the placement tool when `symbol` is in `tools`, `symbolPalette` holds and the filter offers the armed entry). The palette lists the allowed rows only (`_entries` itself when every row is allowed); only allowed letters are bound; the Fill row and F only while Polyline, Rectangle or Circle is allowed (S-9 f). `SymbolPlaceTool` is given `canRotate` / `canMirror` reading the capabilities live. The Symbols tab only with `symbolPalette` (the chosen tab is kept for when it returns); `SymbolPanel` gets `filter` (the host's filter over `FloorPlanSymbol.of`, made once per entry in an `Expando`) and `placeable` (`symbol` in `tools`). The bar: the file commands filtered by `export` / `print`, Undo and Redo by `undo`, from the commands the shell was created with, so a runtime change brings them back; one filtered list feeds the bar **and** the bindings; with the default `actions` and nothing left, no toolbar. `snapping`: F3 unbound, the OSNAP read-out gone, and the tools and the grip cache read a `_CapabilitySnap` (a `SnapSettings` whose `objectSnap` is the user's setting AND the flag; toggles and listeners are the user's, so the setting is kept; S-14). `rulers`, `grid` to `PlannerView`. The left column only when `leftColumnShown`. `didUpdateWidget`: a capabilities change that refuses the active tool activates select (which cancels a pending shape). The tool controller gets a listener (`_onTools`, attached where the controller is made, so nothing is built earlier than today) that tells `onToolChanged` each change; `initState` registers `_selectByHost` through `onTools` and announces select; `dispose` withdraws. |
| `lib/src/tool_palette.dart` | An optional `showFill` (true): false omits the divider and the Fill row. |
| `lib/src/symbols/symbol_panel.dart` | Optional `filter` (applied before `searchSymbols`, and to a tapped cell's entry) and `placeable` (true; ANDed into the gallery's `enabled`). |
| `lib/src/symbols/symbol_place_tool.dart` | Optional `canRotate`, `canMirror` (`bool Function()?`), read at each key: a refused R or M is any other key (bubbles while armed, swallowed mid-press). |
| `lib/src/host/floor_plan_controller.dart` | `ValueListenable<FloorPlanTool> activeTool` and `bool selectTool(FloorPlanTool)` (false in the selection mode, with no editor registered, for a refused tool; `symbol` re-activates the armed entry, false with none). `@internal registerTools` (the withdrawal announces select) and `@internal toolChanged`: applied now, or, while a frame builds (`SchedulerPhase.persistentCallbacks`: a `didUpdateWidget`, a mount, a dispose), after that frame (Finding 2). `setMode` announces select. Disposed with the controller. |
| `lib/src/host/floor_plan_view.dart` | `editorCapabilities` (documented), validated at build, passed to the shell with `registerTools` / `toolChanged`. Task 2's chrome tuple gains `caps.rulers` and `leftColumnShown(caps, symbols: true)` (a view always gives a loader), so a runtime change of either re-measures the shown canvas (R-13). |
| `lib/jet_cad_floor_plan.dart`, `test/host/barrel_test.dart` | `FloorPlanEditorCapabilities`, `FloorPlanSymbol`, `FloorPlanTool`; B1 gains them. |
| `test/host/editor_fixture.dart` (new) | The editor fixture (below). |
| `test/host/editor_capabilities_test.dart` (new, 8 tests) | The type, through the barrel. |
| `test/host/editor_tools_test.dart` (new, 19 tests) | Through `FloorPlanView` on the editor fixture. |

## The editor fixture (`test/host/editor_fixture.dart`, for Tasks 4 to 6)

- `editorPlanJson()`: `startupPlan` (walls, openings, the separator, seven rooms with labels, five dimensions, the page), then, in placement order: the embedding fixture's hand-made table (box off its base point) as `1` (30°), `2` (mirrored at exactly 90°, `Transform2(0, 1, 1, 0, …)`), `7` (60°), ` 7 ` (mirrored at −150°), an unnumbered one (15°), `5` (45°, hidden layer), `L` (mirrored at 120°, locked layer); a root-level group (turned 20° at (21,600, 13,450)) of two crossing lines; a free line; a TEXT `Bar`; a chair (`test.chair`, no seats, base off its seat, turned 10°). History cleared. The world boxes are written in `editorTables`' comment; `1` and `2` stand 54 and 50 mm below the north wall's inner face.
- `editorCamera()`: 0.37 px/mm, y up, panned so world (21,400, 17,070) is the canvas's top left; never the identity. **`kEditorSurface` is 2400 × 1500**: see Finding 1.
- Constants for later tasks: `editorChairPlacement`, `editorGroupPlacement`, `editorFreeLine`, `editorTextAt`, `editorColumnCorner` (the column's south-west corner, a wall's end with nothing else within 70 mm).

## Tests

`test/host/editor_capabilities_test.dart` (through the barrel, prefixed import):
- **EC1** `FloorPlanTool`'s sixteen values in order.
- **EC2** the three profiles field by field against S-12's table written out in the test (`full` has every flag allowing, i.e. `selectTablesOnly` false; `const FloorPlanEditorCapabilities() == full`; `tablesOnly`'s filter true for `seats: 2` and `seats: 0`, false for null).
- **EC3** `copyWith` of each of the twenty flags on each profile changes that field only; `tools` and `symbolFilter`; `copyWith(symbolFilter: null)` keeps the filter.
- **EC4** `==` / `hashCode`: tools in another order equal; each flag alone unequal both ways; a static function equal to itself, two closures unequal, two tear-offs of one method on one receiver equal.
- **EC5** `toString`: `FloorPlanEditorCapabilities()`, `(reshape: false)`, `(undo: false, export: false)`, both profiles in full.
- **T4-i** (type level) `validateEditorCapabilities` with `{wall}` and `{}`: `ArgumentError` named `tools` with the set as its value; the profiles and `{select}` pass.
- **EC6** `FloorPlanSymbol` `==` (each field alone, tags order), `hashCode`, `toString` with and without seats.
- **EC7** `FloorPlanSymbol.of` of the bundled `dining.table.round` (seats 4) and `dining.chair` (seats null), every field against the catalogue's literal values; tags unmodifiable; `tablesOnly`'s filter true / false on them.

`test/host/editor_tools_test.dart` (mounted in `kEditorSurface`; a host `CallbackShortcuts` above the view counts V L P R B W D N G M S I C A T, F, F3, Ctrl+E, Ctrl+Z; a host `ValueListenableBuilder` on `activeTool` beside the view; `onExportDialog` counting and answering null):
- **full is today's editor through the view:** the canvas focused; all fifteen rows, `tool-fill`, `chrome-left`; each letter (in reverse order) activates its tool; Escape; F flips Fill; F3 flips OSNAP; no key reached the host; the four buttons and `zoom-text`; one `RulerFrame`; the `PageChromePainter`'s `grid` true; the gallery holds every library entry, in order.
- **tablesOnly / readOnly (T4-a):** `chrome-left`, both tabs, `tool-select` alone, no other row, no `tool-fill`; a table armed from the Symbols tab and a click place a table, and it is numbered; `readOnly` at runtime: no `chrome-left`, no Symbols tab, no row, select.
- **S-22:** the selection mode under `readOnly`: a service drag moves `1` by (60, 20) px in world mm exactly, `service-undo` undoes it, Ctrl+Z is the service's (the host never sees it), `selectTool` false.
- **M-H41**, **T4-b**, **T4-h**, **M-H47(runtime tool)**, **T4-c**, **T4-e**, **T4-j** (twice: at runtime and from the start), **T4-i** (through the view, both modes), **M-H47(symbolFilter)**, **T4-d**, **T4-f**, **T4-g**: as the plan writes them; details in the mutant table.
- **The Symbols tab without the symbol tool** (`tools: {select, wall}`): the gallery shown and disabled, a tap arms nothing, `selectTool(symbol)` false; `full` at runtime: enabled, and nothing was armed before.
- **Snapping keeps the user's setting:** F3 off under `full`, `snapping: false` and back, still off.

**M-H47(symbolFilter)'s queries, read on the base** (`e8a21a0`, before any `lib` change; `base_query.log`): `table` answers the five tables (`dining.table.square.two`, `.square.four`, `.rect.four`, `.rect.six`, `dining.table.round`) and five non-tables (`bed.nightstand`, `table.coffee`, `office.desk.1200`, `office.desk`, `office.desk.1600`); `sofa` answers `sofa.two` and `sofa.three` only, neither seats.

## Mutants

Each applied by `mutate.py`, its killer run by `--plain-name` and seen red, the file restored from a copy and checked byte-equal (`filecmp`, shallow=False). Every row below was seen red on the committed tree (`mutants.log`, `logs/`); every row but P-rotate also in a first round before the last two `lib` edits (`mutants-round1.log`, `logs1/`), P-rotate in `mutants2.log`. Each log was read for the failing expectation, so no row is a compile error.

| Mutant | Applied as | Killer | Seen red at |
|---|---|---|---|
| **M-H41** (bound, `_activate` refusing) | the letter bindings without `if (_allows(e.tool))` | `M-H41 tablesOnly, the canvas focused: …` | the host's count for L: expected 1, got 0 |
| **M-H41** (bound and allowed) | the same, and `_activate` without its `_allows` check | same | the host's count: expected 1, got 0 |
| **M-H47(runtime tool)** | `didUpdateWidget`'s fallback condition `false` | `M-H47(runtime tool) full, W, one click …` | `activeTool`: expected select, got wall |
| **M-H47(symbolFilter)** | `searchSymbols(library.entries, …)` (no filter) | `M-H47(symbolFilter) tablesOnly: …` | the gallery's keys under `table`: the ten, expected the five |
| **T4-a** (rows) | `ToolPalette(entries: _entries)` | `tablesOnly: the Tools tab shows Select alone … (T4-a)` | `tool-line` found |
| T4-a (Fill) | `showFill` not passed | same | `tool-fill` found |
| **T4-b** (shell) | `_selectByHost` activates the palette tool directly and answers true | `T4-b selectTool: …` | `selectTool(wall)` under `tablesOnly`: true |
| T4-b (mode) | the controller's mode check removed | same | `selectTool(wall)` right after `setMode(selection)`: true |
| **T4-c** | `_allows` true for the placement tool whenever an entry is armed | `T4-c full, a chair armed, then tablesOnly: …` | `activeTool`: expected select, got symbol |
| **T4-d** (M) | `canMirror` not passed | `T4-d tablesOnly, a table armed: …` | det: −1.0, expected > 0 |
| P-rotate (task-local, T4-d's R) | `canRotate` not passed | same (its last part, `tablesOnly.copyWith(rotate: false)`) | the host's R: expected 1, got 0 (the tool took it) |
| **T4-e** | the view omits Export without `editorCapabilities.export` and the shell does not filter it | `T4-e full.copyWith(export: false, undo: false): …` | after `full` at runtime: no `toolbar-export` |
| **T4-f** | `_CapabilitySnap.objectSnap` reads the user's setting alone | `T4-f snapping false: …` | the line's start x: 23,500 (the corner), expected 23,475 (the grid point) |
| P-snap-f3 (task-local) | F3 bound whatever `snapping` says | `T4-f …` | the host's F3: expected 1, got 0 |
| P-snap-readout (task-local) | the read-out's `snapping` clause removed | `T4-f …` | `osnap-text` found |
| **T4-g** (rulers) | `rulers:` not passed to `PlannerView` | `T4-g rulers and grid false: …` | a `RulerFrame` found |
| T4-g (grid) | `grid:` not passed | same | the sheet strip: 2 colours, expected 1 |
| T4-g (re-measure) | the chrome tuple's `caps.rulers` → `true` | same | table `1` off by 24 px after the switch |
| **T4-h** (listener) | the tool controller's `_onTools` listener not attached | `T4-h activeTool follows every change: …` | after W: select, expected wall |
| T4-h (mode) | `setMode`'s announcement removed | same | right after `setMode(selection)`: dimension, expected select |
| **T4-i** | `validateEditorCapabilities` not called in the view's build | `T4-i (design mode) tools without select: …` (and the selection mode's) | no exception thrown |
| **T4-j** (column) | the left column always built | `T4-j readOnly: no left column …` | `chrome-left` found |
| T4-j (re-measure) | the chrome tuple's left column → `true` | same | table `1` off by 240 px after the switch |
| P-defer (task-local) | `toolChanged` applied at once even during a build | `M-H47(runtime tool) …` | an assertion thrown while dispatching `ValueNotifier<FloorPlanTool>`'s notifications (the host's builder marked dirty mid-build) |
| P-fill-key (task-local) | F bound whatever the tools | `M-H41 …` | the host's F: expected 1, got 0 |
| P-placeable (task-local) | `placeable` not passed | `the Symbols tab without the symbol tool: …` | the gallery's `enabled`: true |

**A mutant that survived, and what I did:** the shell's own check in `_armSymbol` (arm nothing the capabilities refuse) survived its killer in the first round: the panel already refuses every such tap (a filtered entry has no cell, and without `symbol` the gallery is disabled), and `_activate` refuses the placement tool for a refused entry. The check was dead code, so I removed it; `_armSymbol` is today's again, and the panel and `_allows` are the two gates, each with a killer above (P-placeable, M-H47(symbolFilter), T4-c).

## Gates (real results, on the committed tree)

| Package | Test | Comparison | Analyze | Format |
|---|---|---|---|---|
| `packages/jet_cad_floor_plan` (`flutter test --enable-vmservice`) | `05:22 +1769: All tests passed!` (1742 + 27) | `1769 tests; the standing failures and skips, exactly` | No issues | 271 files, 0 changed |
| `apps/restaurant_demo` | `+60: All tests passed!` | exactly | No issues | 0 changed |
| `apps/floor_planner` | `+212: All tests passed!` | exactly | No issues | 0 changed |
| `packages/jet_cad_2d_flutter` | exit 1: its 7 standing failures, 1 skip | `1405 tests; … exactly` | No issues | 0 changed |
| `packages/jet_cad_2d` (`dart test`) | exit 1: its 2 standing failures | `1258 tests; … exactly` | No issues (`--fatal-infos`) | 0 changed |

The planner's run includes PA1–PA3 (run, not skipped), `paint_allocation_test` and `query_allocation_test` (render), and every test the plan lists as unedited and green for this task.

## Findings

1. **The editor fixture's window.** At 0.37 px/mm the flat (14 × 9 m, 5,180 × 3,330 px) fits no ordinary test window, so "panned so the flat is on screen" cannot hold literally. The fixture defines `kEditorSurface` (2400 × 1500; the canvas is 1856 × 1412 under the default chrome) and frames the living room's north-east part: the north wall and its inner face, the east wall with its window opening, the column, the separator, the overall depth's dimension, and every object the fixture adds. The parquet's hairlines lie under all of it, so a pick inside a table's box away from its lines hits a parquet line (useful for S-15 in Task 5). Tasks 5 and 6 should mount in `kEditorSurface`.
2. **`activeTool` during a build is announced after the frame.** A runtime fallback runs in the shell's `didUpdateWidget`, a new plan's editor announces select in `initState`, and a withdrawn editor in `dispose`: all inside a frame's build. A host widget listening to `activeTool` (a tool strip beside the view) would then be marked dirty mid-build, outside the shell's subtree, and Flutter asserts (P-defer shows it). So `toolChanged` defers those to a post-frame callback: after the frame of the change `activeTool` reads the new tool (the plan's "after one pump" holds), and the host's widget rebuilds in the next frame. A key, a tap, `selectTool` and `setMode` announce at once.
3. **A refused R or M in the symbol tool is any other key** (S-9 b): it bubbles while armed. Under a profile that allows the Rectangle tool and refuses `rotate` (none of the three), R therefore switches to Rectangle while a symbol is armed, as W switches to Wall today. Documented on `canRotate`.
4. **`selectTool(FloorPlanTool.symbol)`** re-activates the armed entry and answers false with none armed, as S-6 recommends; a host cannot choose a symbol (recorded as a limit, for the guide in Task 7).
5. **T4-f's raw point is the grid point.** The startup page has `snapToGrid` on, and grid snap stays the page's (S-14), so under `snapping: false` a click's point is the grid point of the raw one. The test computes it itself from the page's origin and `dragGridStepMm` (the engine's step at 0.37 px/mm), and asserts the corner under `full`.
6. **Added internals beyond the plan's list** (all optional or `@internal`; nothing enters the barrel but the three names): `ToolPalette.showFill`; `SymbolPanel.placeable` (the Symbols tab can show without the symbol tool when a host keeps `symbolPalette` and drops `symbol`; the gallery is then disabled, as a denied permission disables it); `ShellToolRegistrar` (a typedef in `planner_shell.dart`, which `lib/editor.dart` exports whole, as Task 2's `ShellIdleRegistrar`); `PlannerShell.onTools` / `onToolChanged`; `FloorPlanController.registerTools` / `toolChanged`.
7. **`tablesOnly`'s filter is private.** It is a private static function (so the profile is `const`); a host that wants the same filter reads `FloorPlanEditorCapabilities.tablesOnly.symbolFilter`. A public one would be a new member the plan does not list (R-1).
8. **For Task 5:** `didUpdateWidget` is where a capability change lands; Task 3's findings 4–5 (one gates object for `SelectTool` and `GripCache`, `grips.gatesChanged()` on a change) fit there unchanged. The `_CapabilitySnap` already gates the select tool's drag snap and the grip cache's object snap.
9. **Line references moved** since the plan's verification: `planner_shell.dart`'s `_activate` is `:698-707` at `e8a21a0` (the plan says `:682-687`), the bindings `:1047-1065`, the left column `:1075-1080`, after Task 2's bar.

## Fixes

Commit `c65a3a0` (pushed as `834c832..c65a3a0`): the review's R-1 to R-4 with the controller's rulings, on top of `834c832` (Tasks 1 to 3's fixes). Scratch: `/tmp/claude-0/-home-user/428cafca-0083-5012-a7ac-5456349e70a8/scratchpad/s4t4-fix/` (`mutants.py`, its results `mutants-part1.out` and `mutants-part2.out`, the logs `mlogs/`; `gates.sh`, `gates.out` and the per-package logs and JSON runs; the probes `zz_probe_test.dart` and `zz_probe2_test.dart`, run in the package and moved out before the gates). No `analysis_options.yaml` touched; no `jet_cad_2d_flutter` edit.

### R-1: the stored turn and mirror are never used under capabilities that forbid them

- `symbol_place_tool.dart`: `_turns` (the stored turns while `canRotate` allows, else 0) and `_mirror` (the stored mirror while `canMirror` allows) are what `_syncPlacement` (the ghost), `_syncAttachment` (the wall attachment) and `_place` read. The stored values (`quarterTurns`, `mirrored`) are kept, so they return with the flag. A new `gatesChanged()` recomputes the ghost and its attachment.
- `planner_shell.dart` `didUpdateWidget`: when `rotate` or `mirror` changes and the symbol tool stays active, `gatesChanged()`, so the ghost never shows what a click would not place, with no pointer event.
- T4-d's last step (the plan's own test, the one allowed edit): under `tablesOnly.copyWith(rotate: false)` the placement is now **unturned** (`a = 1, b = 0`), and back under `tablesOnly` the stored turn returns (`a = 0, b = 1`).
- Killers (`test/host/editor_tools_review_test.dart`): RV1 (M under `full`, then `tablesOnly`: still armed, det +1; `full` again: det −1); RV2 (M, Escape, `tablesOnly`, re-armed: det +1; `full`, re-armed: det −1); RV3 (R under `full`, then `tablesOnly` without `rotate`: unturned); the ghost (mirror and turn, each refused and returned at the change, no pointer event); `bath.toilet` against the north wall (M, then `mirror: false`: the attached transform equals the unmirrored control's exactly; `full`: det −1).

### R-2: a runtime `rulers` change with a tool active throws nothing

- `planner_shell.dart`: a private `_FrameSafeRelay` (a `ChangeNotifier` over a source) forwards at once, except during `SchedulerPhase.persistentCallbacks`, when it holds one notification and delivers it after the frame (`FloorPlanController.toolChanged`'s pattern). Three relays: the tools (the palette, the Symbols tab, the Undo/Redo and file flags), the selection (the selection panel), and the status line's merge (selection, tools, the Room and Dimension notices). `PlannerView`'s own descendants keep the raw sources.
- The probes showed the selection's hover (`_release` → `setHover(null)`) asserts the same way as the tool's cancel (the selection panel and the status line), so the selection is relayed too.
- `didUpdateWidget` delivers whatever the relays hold at its end: every listener is in the shell's subtree, rebuilt in that build, so a fallback's flags are right after the one pump (M-H47 and T4-c keep their "after one pump").
- `ToolPalette.toolChanges`, `SymbolPanel.toolChanges` and `SelectionPanel.selectionChanges`: optional, internal, defaulting to today's source.
- Killers: a wall part-way (history present), rulers off then on: no exception at either pump, `activeTool` wall, status `Wall`, Undo enabled after the delivered frame, the tool restarts from no point; Line idle, the select tool hovering the free line, a symbol's ghost shown: rulers off and on throw nothing; a fallback with a wall part-way: Undo enabled after that one pump.
- Behaviour to note for the guide: the rulers' toggle re-parents the canvas, so a pending shape is cancelled (the tool stays active).

### R-3: the survivors

- **O3:** EC3b (`editor_capabilities_test.dart`) builds two bases by the constructor whose twenty flags alternate (so `rulers != grid` in each), checks `copyWith()` keeps every field and each flag replaces that field alone.
- **RV4 to RV9** landed (O9, O10, O11, O7, O8, O24).
- **O22:** `full.copyWith(symbolPalette: false)`: no `tab-symbols` or `left-tabs`, `chrome-left` with the palette; `full`: the tab returns.
- **O13a:** the overall depth's end grip dropped exactly on the column's corner, the page's grid snap off: a `FixedEnd` at the corner under `snapping: false`, an `AttachedEnd` under `full`. (A drop off the corner does not separate them: `attachCandidates` gathers within `dimAttach.linear`, 1e-5 mm, so only the select tool's own snap brings a drop there.)
- **O13b:** the east window's slide grip dropped at (25,878, 15,835), the grid snap off: the stored centre is the projection, 7,710, under `snapping: false`, and the stretch's end, 7,725, under `full` (the jamb 15 mm short, inside the 27 mm aperture). With the grid on every candidate sits on the 50 mm grid, so the grid snap hides the edge snap.
- **O23:** `full.copyWith(export: false, print: false, undo: false)`: no `DocumentToolbar`, `status-text` at the bar's 12 px padding.
- O12 (defensive) and O16, O21 (equivalent) as the review rules: no test.

### R-4

- `copyWith` wraps a given `tools` in `Set.unmodifiable`. The `const` constructor cannot copy (EC2 and T4-i use `const` instances), so `FloorPlanView` takes its own copy of each value handed in (`copyWith(tools: given.tools)`, once per value by identity) and hands the shell that copy: a host changing its set afterwards changes nothing the editor has, and a new value is compared with the copy of the last, so a refused tool falls back. Documented on `tools`.
- The capabilities' doc no longer claims every edit path is gated: the edit flags say which edits the user may make; `rotate` and `mirror` also bound the symbol tool's keys and placement; the class summary names the profiles by purpose (S-12 lists their fields). True at this commit and after Task 5.
- **A filter refusing everything:** the no-match line only with a non-empty query; with none, an empty area (`symbol_panel.dart`).
- Killers: `copyWith` copies (the host's set mutated after: unchanged; `add` throws); a host's own set through a `StatefulBuilder` host (`setState` compares nothing): mutated in place, a tab switch and a host rebuild with the same value keep the wall row and the Wall tool; a new value from the mutated set → select, no row; a filter `(_) => false`: no gallery and no no-match line without a query, `No symbols match "table"` with one.

### Implementer's finding 3

Accepted by the controller: a refused R or M bubbles to another tool's letter while a symbol is armed. Recorded for the guide (Task 7); nothing now.

### Mutants (each seen red on an expectation, `compile_error=False`; the file restored from a copy and compared byte for byte)

| Mutant | Red by | Expectation seen |
|---|---|---|
| `_place` reads the raw mirror | RV1, RV2 | det −1, expected > 0 |
| `_place` reads the raw turns | RV3, T4-d | `a` 0, expected 1 |
| `_syncAttachment` reads the raw mirror | the toilet against the wall | `[-1, 0, 0, 1, 24400, 16050]`, expected `[1, 0, 0, 1, 24000, 16050]` |
| `_syncPlacement` reads the raw mirror | the ghost | det −1 |
| `_syncPlacement` reads the raw turns | the ghost | `a` 0, expected 1 |
| the shell never calls `gatesChanged` | the ghost | det −1 |
| the flags' sources the raw tools | the wall part-way rulers test | `markNeedsBuild() called during build` |
| the palette on the raw tools | both rulers tests | same |
| the Symbols tab on the raw tools | the hover / ghost rulers test | same |
| the selection panel on the raw selection | the hover / ghost rulers test | same |
| the status line on the raw merge | both rulers tests | same |
| the relay always immediate | both rulers tests | same |
| no `deliver()` in `didUpdateWidget` | the fallback's Undo | false, expected true |
| O3 | EC3b | the flags map |
| O7, O8, O24 | RV7, RV8, RV9 (O24 also O23's test) | `tool-fill` not found; `chrome-left` found; `toolbar-print` found |
| O9 | RV4, RV5, the ghost | `activeTool` symbol |
| O10, O11 | RV4, RV6 | `activeTool` symbol; wall |
| O13a | O13a | `AttachedEnd`, expected `FixedEnd` |
| O13b | O13b | 7,725, expected 7,710 |
| O22 | O22 | `tab-symbols` found |
| O23 | O23 | a `DocumentToolbar` found |
| the view takes no copy | the host's own set | `tool-wall` gone after the in-place change |
| `copyWith` keeps the host's set | the copy test | `{select, line}`, expected `{select, wall}` |
| the no-match line without a query | the filter offering nothing | `symbol-search-empty` found |

### Gates (on the fix's tree, before the commit)

| Package | Test | Standing comparison | Analyze | Format |
|---|---|---|---|---|
| `packages/jet_cad_floor_plan` (`flutter test --enable-vmservice`) | `04:36 +1809: All tests passed!` | `1809 tests; the standing failures and skips, exactly` | No issues found | 272 files, 0 changed |
| `apps/restaurant_demo` | `00:28 +60: All tests passed!` | | No issues found | 8 files, 0 changed |
| `apps/floor_planner` | `01:20 +212: All tests passed!` | | No issues found | 47 files, 0 changed |
| `packages/jet_cad_2d_flutter` | `01:01 +1407 ~1 -7` (its standing failures) | `1415 tests; … exactly` | No issues found | 227 files, 0 changed |
| `packages/jet_cad_2d` (`dart test`) | `00:18 +1256 -2` (its standing failures) | `1258 tests; … exactly` | No issues found | 170 files, 0 changed |
