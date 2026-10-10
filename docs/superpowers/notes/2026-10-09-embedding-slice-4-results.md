# Host embedding API, Slice 4: results

**Asked by the human:** *"tamam, Dilim 4 ile devam et"* (2026-10-09),
after Slice 3 merged; the merge on *"evet, main'e merge et"*, confirmed
(*"Yine de sen merge et"*) over another session's relayed "don't merge".

**Spec:** [2026-10-09-host-embedding-api-design.md](../specs/2026-10-09-host-embedding-api-design.md),
revision 3, as amended: the plan's points S-1 to S-24, ruled as it
recommended but **S-16** (`shortcuts: false` unbinds every idle key, and
the controller gains `deleteSelection()`); the tasks' rulings (Task 2 R-3
the first frame exact, Task 6 R-1 (a) no inspector for a shared number,
Task 7 finding 1 the planner's fields keep their keys); the final review's
F-1 to F-4 and F-7. C-3, C-5, C-6 and M-H46 are amended in place; the
Review section lists the rest.

**Plan:** [2026-10-09-embedding-slice-4.md](../plans/2026-10-09-embedding-slice-4.md).

**Branch:** `claude/exciting-pasteur-9m22jv`, from `main` at `4e3ed91`
(Slice 3 merged). **Merged** into `main` at `4331c74` on the human's
*"evet, main'e merge et"*. `main`'s O-10 and O-11 fixes, made by other sessions on
their own branches, came in through `263e2ca`, with their owed tests
(`a5b1ead`, `503c504`) and the hover-removal test (`f0c77cf`).

**Process.** Each of Tasks 1–6 had a fresh implementer, then an
independent reviewer in its own clone, then its fixes. Task 7 (the demo,
the guide, the probe, the CHANGELOG, the gates) was delegated by the
controller and gated by it. An independent review of the whole range
closes the slice.

## What a host gets

- **The bars** (C-1, C-2): `FloorPlanView(serviceBar:, editorBar:)` take
  `FloorPlanServiceBar` and `FloorPlanEditorBar`: `visible`, `actions` (an
  ordered list of `FloorPlanServiceAction` / `FloorPlanEditorAction`; the
  default is today's bar, pixel for pixel), `leading` and `trailing` host
  widgets. Actions shape the bar, never the chords (S-20).
- **A bar of the host's own** (C-3): `mergeCandidate`, `activeTool` and
  `selectTool`, `editorSelectedTables`, `exportPlan(FloorPlanExportChoice)`
  and `printPlan()` (one at a time per controller, the settle and the
  document checks of the shell's own flows), `deleteSelection()`.
  **`undo()` and `redo()` wait for an idle tool in the design mode** (S-4,
  a fix a 0.3.0 host may notice).
- **The dialog hook and errors** (C-4): `onExportDialog` replaces the
  Material dialog at every Export entry point, both modes;
  `onPageFlowError` hears a failed export or print (absent: today's).
- **Editor capabilities** (C-5): `FloorPlanEditorCapabilities` with
  `full` (today's editor), `tablesOnly` and `readOnly`, `copyWith`, a
  `symbolFilter` over `FloorPlanSymbol`; tools, the Symbols tab, the three
  panels and their editing, `selectTablesOnly`, move, rotate, mirror,
  reshape, delete, renumber, changeLayer, undo, export, print, rulers,
  grid, snapping. Enforced by the shell, the panels and `SelectTool`'s
  gates for every edit path (the table below); a gesture, menu, field or
  dialog opened before a runtime change is read against the capabilities
  when it commits. Not a security boundary (V-5).
- **The table inspector** (C-6): `tableInspectorBuilder`, under the
  Selection panel's fields for exactly one numbered table, none for a
  number another table shares.
- **Keyboard and focus** (C-7): `shortcuts: false` unbinds jet-cad's
  chords and letters in both modes; `autofocus: false` leaves the focus
  where it is. The planner's own text fields keep their keys from a host's
  `Shortcuts` above the view (Backspace, Delete, typing keys, Ctrl+A, a
  held key's repeats): a change a 0.3.0 host with bindings there may
  notice, in the CHANGELOG.
- **Chrome changes keep the plan in place** (F-1, F-3): showing or hiding
  a bar, the editor's left column or its rulers keeps the canvas and the
  plan's place on the screen from the first frame; the camera's listeners
  hear the pan after that frame. A runtime change of the theme's
  `serviceBarHeight` still moves the plan with the canvas (Slice 3's S-10).
- **`jet_cad_2d_flutter`** (additive): `SelectGates`, `SelectTool(gates:)`
  and the public `SelectTool.deleteSelection(ToolContext)`,
  `GripCache(gates:)` with `moveGripsLive`, `stretchGripsLive` and
  `gatesChanged()` (the tool and the cache share one gates object),
  `InteractionLayer.autofocus`.
- **The barrel** gains exactly the ten names R-1 allows; `editor.dart`
  only additions. **No stored format changes** (schema 9 stays).
- **The demo:** an *Editor* switch (Full / Tables / Read only, the last
  with a bar of print, export and zoom), a *POS id* inspector under
  Tables, the area's name at the service bar's start, an *Own bar* and an
  *Own export dialog* switch, *The plan's keys* switch (off: the demo's
  own keys through the controller), a *Find a table* field that keeps its
  focus across a mode switch.
- **The guide:** § 8's *The bars*, *The editor's capabilities*,
  *Keyboard and focus*; § 4's eight new parameters; § 11's two bullets;
  every block in the host probe (48).

## The tasks

| Task | Commit | Review | Fixes |
|---|---|---|---|
| 1, the page flows without their dialogs (C-3's export and print, C-4, `onPageFlowError`) | `ffe0b9c` | **Approve with minor fixes**: six of the reviewer's mutants survived (read-at-each-call, the settle, an answer after `dispose()`, the view's cancellation, the remembered choice) | `82219f4`: the killers RV1–RV7 |
| 2, the two bars, `mergeCandidate`, an idle Undo | `86115fa` | **Approve once R-1 and R-2 are fixed**: S-4's whole wiring removable with the suite green; `lastFile` read once; the first frame after a switch one bar off | `834c832`: S-4's killer; `lastFile`; **R-3 fixed, not recorded: `canvasAssumed` makes the first frame exact**; the toolbar gap; docs |
| 3, `SelectGates` and `InteractionLayer.autofocus` (render) | `e8a21a0` | **Approve once R-1 lands and R-2 is ruled**: 7 of 20 mutants survived (two guard `tablesOnly`'s band and finger pick); `deleteSelection()` had no seam | `ac485fd`: public `SelectTool.deleteSelection`, the seven killers |
| 4, capabilities I: the type, the tools, the Symbols tab | `5c72a5e` | **Approve once R-1 and R-2 are fixed**: a mirror or turn set under `full` survived a switch to `tablesOnly`; a runtime `rulers` change with a drawing tool active asserted in debug | `c65a3a0`: the symbol tool's gates, a frame-safe relay (which also ends the hover-removal crash Slice 3 recorded, pinned by `f0c77cf`), the killers |
| 5, capabilities II: the select tool and the panels | `62926cb` | **Approve with fixes**: the reviewer's own R-4 enumeration found two races, a drag started before a switch to `tablesOnly` and a layer colour menu open across one; six flag pairs never varied apart | `d966e67`: a gate closed mid-gesture cancels it; the colour menu inert; the mouse's pick tolerance; the flag-pair and R-4 killers |
| 6, keyboard, focus and the inspector | `305285f` | **Approve with fixes**: the shared number to rule; two killers missing; two doc sentences | `c2fa7f5`: no inspector for a shared number (ruled), the killers, the docs |
| 7, demo, guide, probe, CHANGELOG | `9c24a85`, `2328aa6`, `24af8f7` | gated by the controller | `8f45473`: **finding 1, a host's `Shortcuts` saw the planner's field keys, fixed in the planner** (`PlannerTextKeys`) |
| the range `4e3ed91..8f45473` | — | **Independent review: Approve with fixes**; with no new parameter the planner behaves and draws as at `4e3ed91` (70 traced steps and 62 key readings identical, every pixel hash, but S-4 and one structural nit); every edit path re-enumerated is gated | `44b6775` F-1 to F-4, `492c70c` F-5 to F-7, `fdf3309` a compile fix found on the rebase |

The final review's findings:

- **F-1 (Medium):** a capability change that swapped or removed both side
  columns re-mounted the canvas and re-fitted the camera. Fixed: the
  canvas is keyed; four crossing cases pinned.
- **F-2 (Medium, regression):** with a bar hidden, a controller swapped and
  disposed in one step asserted. Fixed: nothing lazily made is first made
  in `dispose()`; pinned per mode and bar.
- **F-3:** the docs promised the plan stays in place when the chrome
  changes in the mode shown; it moved by the column's width. **Ruled: the
  behaviour**, the camera compensating, so the docs hold. The theme's bar
  height is left out, because Slice 3's S-10 and three of its tests pin
  the opposite (a height change moves the plan with the canvas).
- **F-4 (Low):** an Export started before `export: false` still exported.
  Fixed: Export re-checks after its dialog and once the bytes are made,
  Print before the printer; a refusal hands nothing over.
- **F-5:** the CHANGELOG's sentence on the field keys. **F-6:** killers
  for S05, S25, S26. **F-7:** recorded (below). **F-8:** this note, the
  spec, STATUS and the roadmap.
- **Found on the rebase:** `503c504` removed `finitePlanJson()` while
  `keyboard_focus_test` still called it; `fdf3309` uses
  `embeddingPlanJson()` there, the only edit to an existing test.

Per-task reports, reviews and fixes are archived in
[docs/superpowers/ledgers/2026-10-09-embedding-slice-4/](../ledgers/2026-10-09-embedding-slice-4/).

## Named mutants

Every named mutant of the plan went red, each with its killer recorded in
the task's report:

- Task 1: M-H46 (Cmd/Ctrl+E reaching the Material dialog with a hook).
- Task 2: M-H40, M-H44, M-H47(serviceBar).
- Task 3: T3-a to T3-j and P-1, P-2 (23 forms).
- Task 4: M-H41, M-H47(runtime tool), M-H47(symbolFilter).
- Task 5: M-H42, M-H42b, M-H43, M-H43b, M-H43c (as amended: the end grip
  absent, so a drag reshapes nothing), with T5-a to T5-h.
- Task 6: M-H41b, M-H45, M-H45b to M-H45d.
- Task 7: the probe mutant (`check_guide` exits 1) and the demo's DM1 to
  DM16.

The final review ran 31 of its own (S01–S31): 26 red on the committed
suites; S05, S25 and S26 red with the killers `492c70c` landed; S13
(`LayerPanel._execute` unguarded) and S19 (the shell's `_inspected` for a
chair) equivalent on the reachable paths. The final fixes' own mutants
(F-1's key, F-2 per case, F-3's parts, F-4's five) are red, but one form
of F-2 (Undo's flag made in `dispose`), equivalent under `FloorPlanView`.

## R-4: every edit path, its flag, its enforcement and its killer

From Task 5's report, re-enumerated independently by Task 5's reviewer
(40 rows, from every `execute`, binding and control callback in the
planner's `lib`) and again by the final review (adding the runtime races).

| Path | Flag | Enforced by | Killer |
|---|---|---|---|
| F-15: the 15 tools and their letters | `tools` | `_allows` / `_activate`, the letter bindings | M-H41; T4-a; T4-b; M-H47(runtime tool) |
| F-15: the Symbols tab | `symbolPalette`, `symbol`, `symbolFilter` | `_leftPanel`, `SymbolPanel.filter` / `placeable`, `_offers` | M-H47(symbolFilter); T4-c; O22 |
| F-15: the body drag (with wall attach) | `move` | `_CapabilityGates.move` → `SelectTool._beginDrag`, the up's re-read | T5-a |
| F-15: the rotation grip | `rotate` | `_CapabilityGates.rotate` → tool and grip cache | T5-b |
| F-15: reshape grips (every object grip; leaf stretch grips) | `reshape` | `_CapabilityGates.reshape` → tool and grip cache | M-H43c |
| F-15: the rubber band | `selectTablesOnly` | `_CapabilityGates.bandAccepts` → `SelectTool._bandKeys` | M-H42 (two forms) |
| F-15: Delete / Backspace | `delete` | `_CapabilityGates.delete` → `SelectTool.onKey` / `deleteSelection` | T5-c; T5-d |
| F-15: the table's number | `renumber` | `SelectionPanel._capable` (read-only, commit refused) | T5-e; R-3 renumber/rotate |
| F-15: the Rotation field, ±90 | `rotate` | `_capable`, `_rotateTable` | T5-b (field, commit and ±90 forms) |
| F-15: Mirror | `mirror` | not shown; `_mirrorSymbol` re-checks | M-H43 |
| F-15: Change size | `reshape` (S-10) | not shown; `_changeSize` re-checks | T5-f |
| F-15: wall, opening, room, box fields | `reshape` | `_capable`; a tool's settings exempt | T5-f; R-4 door tool's width |
| F-15: the layer picker | `changeLayer` | not shown | M-H43b; T5-h; R-3 changeLayer/reshape |
| F-15: the Layer and Page panels | `layerPanel`, `editLayers`, `pagePanel`, `editPage` | `_keptPanel`; `LayerPanel.editable`; `PagePanel.editable` | T5-g; R-3 editLayers/editPage |
| F-15: Undo and Redo | `undo` | the shell's commands and chords | T4-e |
| F-15: Export and Print | `export`, `print` | the shell's commands and chords | T4-e; RV9; O23; S17 |
| F-15: F3 and F | `snapping`; a fill tool | the binding, `_CapabilitySnap`; `_fillOffered` | T4-f; T4-a |
| S-9 a: the centre grip | `move` | the same gate (render maps the role) | render T3-c, RV-1 |
| S-9 b: the symbol tool's R, Shift+R, M | `rotate`, `mirror` | `SymbolPlaceTool.canRotate` / `canMirror`, `_turns`, `_mirror` | T4-d; RV1–RV3; Task 4 R-1's killers |
| S-9 c: an armed symbol newly refused | `symbol`, `symbolPalette`, `symbolFilter` | `didUpdateWidget`'s fallback | T4-c; RV4–RV6 |
| S-9 d: door flips, wall justification, dimension kind | `reshape` | not shown or disabled; each setter re-checks | T5-f (flips, kind forms) |
| S-9 e: the Layer panel's controls | `editLayers` | `LayerPanel._allowed` → each `LayerRow` control | T5-g |
| S-9 e: the Page panel's controls | `editPage` | `PagePanel.editable`, each control | T5-g |
| S-9 f: the Fill row | a fill tool | `ToolPalette.showFill` | T4-a; RV7 |
| S-9 g: a selection across a change of `selectTablesOnly` | `selectTablesOnly` | `didUpdateWidget`'s prune | T5-d; M-H42 S-15 |
| S-9 h: a drag across a change | the drag's flag | a gate closed mid-gesture cancels it at once (Task 5 R-1); render's re-read at the up | S-9 h; Task 5 R-1 (wall drag, chair turn, gate reopened) |
| A layer colour menu across a change | `editLayers` | a disabled row's menu has no `onSelected` (Task 5 R-2) | Task 5 R-2 |
| A field typed before a change, committed after | its own flag | `_editable` read at commit | Task 5 PROBE-5, PROBE-12; final PR8c |
| A layer rename open across a change | `editLayers` | the rename closes | final review K2 |
| A TEXT entry open across a change | `tools` | the fallback cancels it | final review PR2 |
| An Export dialog open across `export: false` | `export` | re-checked after the dialog and the bytes (F-4) | PF22–PF24 |
| S-15: the tables-only pick | `selectTablesOnly` | `restrictsPick` / `pick`, `TablePicker.skipLocked` | M-H42 S-15; S31 |
| A runtime change reaching the grips | every gate | `didUpdateWidget` → `gatesChanged()` | "a runtime change reaches the grips at once" |
| C-8: Material menus under `tablesOnly` | the panels, `changeLayer`, `reshape` | hidden | T5-h |

The host's own calls (`setTableData`, `undo()`, `load`, `select`) stay
allowed under every profile (V-5). One path stays open: **F-7**, below.

## Gates (at `fdf3309`)

| Package | Result |
|---|---|
| engine `packages/jet_cad_2d` | 1272 tests (1258 at `4e3ed91`; O-10's tests); the standing set exactly. Analyze (`--fatal-infos`) and format clean. |
| render `packages/jet_cad_2d_flutter` | 1437 tests (1390); the standing set exactly. Both allocation invariants green. |
| gpu | 20 tests; exactly. |
| planner `packages/jet_cad_floor_plan` | **1912 passed** (1692), with `--enable-vmservice`; analyze and format clean. |
| restaurant symbols | 97 passed. |
| demo `apps/restaurant_demo` | **68 passed** (60); the 60 earlier tests unedited. |
| app `apps/floor_planner` | 212 passed. |
| `tool/ci` | 63 passed; `check_guide`: all 48 code blocks are in the host probe. |
| host probe | exit 0 at `fdf3309` by `file://`: 40 packages, no GPU package, a 42M web build; v0.3.0's probe analyses against it. |
| web builds | both 42M from a clean `build/` at `24af8f7`, no `flutter_scene` assets (`main.dart.js` 3.80 MB demo, 3.60 MB planner). |
| CI on GitHub | green at `fdf3309`. |

**The frame path** (the final review): both allocation invariants, the
pick's PA1–PA3 and the painters' counters green; pan and zoom with every
new parameter set rebuild the same widgets as without (design: the zoom
read-out only; selection: none); nothing scales with the parameters or the
tables.

**Smoke check** (Chromium, Playwright, `en-US`, the demo's web build, at
`24af8f7`): every switch at its default shows today's bars; the own bar
undoes, merges ("Merged {1, 2} as G1") and exports through the demo's
dialog; Ctrl+E opens the demo's dialog when it is on; under Tables only
Select and the tables in the Symbols tab, a table placed, turned,
renumbered and linked from the inspector; under Read only no left column,
the bar of print, export and zoom, a drag, Delete and W pixel-identical;
with the plan's keys off, W stays in Select and Delete and Ctrl+Z are the
demo's; the search field keeps the focus across mode switches for a
mouse; no console error.

## Found, not fixed

- **F-7:** a table symbol tagged `against-wall` still turns to its wall
  when moved or placed under `rotate: false` (`SymbolMoveResolver`,
  `SymbolPlaceTool._place`). None bundled is; `snapping: false` turns the
  attachment off. In the guide's limits and the CHANGELOG.
- **A second `FloorPlanView` mounted on the same controller** while the
  first is still in the tree throws "the dispatcher already has an
  expander" for that one frame (pre-existing; Task 5 finding 8).
- **Hiding all three panels at once** drops their state (the right column
  is not built); hiding one or two keeps it. In the spec and the guide.
- **The select tool's cursor** after a runtime change stays stale until
  the next pointer move; the grips repaint at once.
- **Flutter web with semantics on:** a click on a button's semantics node
  unfocuses a focused text field (the engine closes the text connection);
  mouse users without the semantics tree are unaffected.
- **Under `editLayers: false`** the Layers section's delete tooltip reads
  the permission's words ("Layers cannot be changed in this document").

Ended during the slice: Slice 3's hover-removal crash (the frame-safe
relay, `c65a3a0`, pinned by `f0c77cf`) and its NaN PDF assertion (O-11).

## Owed

- **To the human:**
  - a look at the demo's three editor profiles, its own bar and its own
    keys on a tablet and a terminal;
  - a native read of the demo's new words: de *Host / Editor / Voll /
    Tische / Nur lesen / Eigene Leiste / Eigener Exportdialog / Tasten
    des Plans / Tisch suchen / Kassen-ID*, tr *Ana uygulama / Düzenleyici
    / Tam / Masalar / Salt okunur / Kendi çubuğu / Kendi dışa aktarma
    penceresi / Planın tuşları / Masa bul / Kasa kimliği*, and the log
    lines;
  - **macOS** (reported by the local session): the render package's text
    lod ladder rungs 1 and 2 pass there, so its standing set differs from
    Linux's; and the planner's Slice 3 test T-1 in
    `test/service/table_theme_painter_test.dart` fails there, with
    `main`'s engine too. Whether T-1's macOS failure is fixed as Slice 4
    work or its own task is the human's call; the macOS re-baseline of the
    engine's two fingerprints stays owed as before.
- **To Monépro:** spec 103 can name `tablesOnly` for phase 2's "edit floor
  drawing", `shortcuts: false` beside `PosShortcutsHost`, `onExportDialog`
  for a `ShadDialog`, and the inspector with `setTableData` for linking
  `pos_tables` rows. A POS that hides the bars and owns the keys works end
  to end in the final review's probes.
- **A release** carrying Slices 1–4 is the human's call; until then it is
  CHANGELOG *Unreleased*.
