# Task 9 report — 8b + LayerPanel (spec D9, D10, D11)

Implementer: fresh agent. Base HEAD 27db262. Scratch: scratchpad/l9/.

## Progress log
- Read common.md, brief, spec (whole), plan Task 9, Task 8 review.

## 8b — commit 1afcfdd `test(app): Task 8 review follow-ups`
Files: apps/floor_planner/test/layers/attach_layer_test.dart (new case: dangling ObjectLayer 0x7A7A, A made current, layer 0 hidden -> no candidates at S/0 l/c/r and S/1/c); apps/floor_planner/test/layers/tools_layer_test.dart (new case: wall on hidden C at (12000,1000)->(15000,1000) in its own rotated group; Wall tool click at (14900.5, 1040.25) joins; new wall's start == worldWallOf(hidden).e bitwise).
App gates at 8b: `03:13 +953: All tests passed!`; `No issues found! (ran in 1.6s)`; `Formatted 169 files (0 changed) in 0.85 seconds.`

| id | mutation | test | real output |
|---|---|---|---|
| R2 | dimension_attach.dart:143 `objectLayer(doc, host)` -> `doc.components.get<ObjectLayer>(host)?.layer ?? ReservedHandles.layerZero` | attach_layer_test | `Expected: empty` `Actual: [AttachedEnd:19/0/left]` `00:00 +2 -1: Some tests failed.` diff=0 |
| R3 | wall_bands.dart:98 `_indexAt(doc, px, py)` -> `_indexAt(doc, px, py, (d, h) => d.tables.layers[objectLayer(d, h)]?.visible ?? true)` | tools_layer_test | `Expected: [4513416.841673297, 1206781.4717807919]` `Actual: [4513309.524512457, 1206779.6443538584]` `00:00 +9 -1: Some tests failed.` diff=0 |

## Task 9 — commit 7e83eae `feat(app): the Layers panel`
Files: apps/floor_planner/lib/layers/layer_panel.dart (new), apps/floor_planner/lib/layers/layer_row.dart (new), apps/floor_planner/lib/main.dart (placement + import), apps/floor_planner/test/layers/layer_panel_test.dart (new, 21 tests).

### Gates at 7e83eae (CI=true, PATH=/root/flutter/bin)
- engine: `00:17 +1225 -2: Some tests failed.` — the 2 standing (generate_document_test: "both text fractions default to zero and change nothing", "the default document is the one Plan 2 measured, byte for byte"); `No issues found!`; `Formatted 168 files (0 changed) in 0.62 seconds.`
- render: `00:56 +1187 ~1 -7: Some tests failed.` — the 7 standing text-ladder goldens; `No issues found! (ran in 1.3s)`; `Formatted 208 files (0 changed) in 0.64 seconds.`
- app: `03:22 +974: All tests passed!` (953 at 8b + 21); `No issues found! (ran in 1.9s)`; `Formatted 172 files (0 changed) in 0.78 seconds.`
- dev_harness_2d: `No issues found! (ran in 1.1s)`
- web: `✓ Built build/web`
- git status clean after commit (no analysis_options, no golden, allocation tests untouched).

### Mutants (scratchpad/l9/mut.sh: cp backup, one sed, the named file in the foreground, cp back, `diff=0` for each). Test file: apps/floor_planner/test/layers/layer_panel_test.dart
| id | mutation | red test | real output |
|---|---|---|---|
| M-12a | layer_panel.dart:136 `_allowed` -> `true` (panel ignores permissions, dispatcher still enforces) | read-only ... (D11, M-12a) | `Expected: false` `Actual: <true>` `00:06 +20 -1: Some tests failed.` — red at the disabled assertion, before any tap; no PermissionDeniedError caught anywhere in the test |
| M-LP-18 | layer_row.dart:335 add `onChanged` dispatching each valid trimmed text | rename ... Enter commits ... (M-LP-18); also case-only rename, focus loss | `Expected: <0>` `Actual: <5>` (5 per-keystroke commands) |
| M-LP-26 | layer_row.dart:198 `r.visible && widget.current` -> `widget.current` | S-6 ... (M-LP-26) | `Expected: true` `Actual: <false>` `00:07 +20 -1: Some tests failed.` |
| P1 | layer_panel.dart:120 no commands.changes subscription | each control...; direct write + header change | `Expected: <true>` `Actual: <false>` (2 tests red) |
| P2 | layer_panel.dart:121 no tables.changes listener | direct table write; another document | `Expected: true` `Actual: <false>`; `Expected: <1>` `Actual: <0>` |
| P3 | layer_panel.dart:22 sort by code unit | rows ... (D10) | `Expected: a value greater than <228.0>` `Actual: <100.0>` |
| P4 | layer_panel.dart:34 `Layer N` taken checked case-sensitively | + adds `Layer N` ... | `Expected: <2>` `Actual: <1>` |
| P5 | layer_row.dart:31 ACI 7 not mapped to the foreground | swatches ... | `Expected: Color:<... red: 0.0000 ...` `Actual: Color:<... red: 1.0000 ...` |
| P6 | layer_row.dart:320 field without ShellShortcutGuard | no shell shortcut fires while typing | `Expected: <0>` `Actual: <21>` |
| P7 | layer_row.dart:190 focus loss never commits | focus loss ... | `Expected: <1>` `Actual: <0>` |
| P7b | layer_row.dart:190 focus loss commits an invalid name | focus loss ... | `Expected: no matching candidates` `Actual: _KeyWidgetFinder:<Found 1 widget with key [<'layer-name-field-12'>]` |
| P8 | layer_row.dart:171 Enter does not trim | rename ... Enter commits ... | `Expected: <1>` `Actual: <0>` |
| P9 | layer_panel.dart:150 + does not copy layer 0's lineweight | + adds `Layer N` ... | `Expected: <35>` `Actual: <-1>` |
| P10 | layer_panel.dart:175 delete ignores emptiness | disabled ... | `Expected: false` `Actual: <true>` |
| P11 | layer_panel.dart:105-106 didUpdateWidget does not move subscriptions | another document ... | `Expected: <0>` `Actual: <1>` |
| P12 | layer_panel.dart:188 current = stored header value, not drawingLayer | S-6; S-5 | `Expected: true` `Actual: <false>`; `Expected: false` `Actual: <true>` |
| P13 | layer_panel.dart:127 dispose keeps the tables listener | another document ... | `Expected: <0>` `Actual: <1>` |
`git status --short` empty after the runs.

### Decisions and spec/plan gaps (for the reviewer)
1. **`LayerPanel(document, foreground:)`.** D9 names `LayerPanel(document)`, but "7 drawn in the paper's foreground, as the resolver draws it" needs the paper's foreground, which the panel cannot see. Added an optional `foreground` (default 0x000000, `foregroundFor(white)`); main passes `_resolver.foreground`, so a page swatch change re-renders it.
2. **Focus loss with a valid name commits** (one SetLayerCommand), as the panel number fields commit on blur. The spec only rules the invalid case (revert, nothing). Pinned by P7.
3. **The current mark of the layer that is both stored and effective current is disabled** (a tap would be a no-op undo step). With a dangling/hidden stored current layer, layer 0's mark stays enabled (a tap stores 0). Spec only requires "disabled on a hidden layer".
4. **Read-only (D11):** every command control is disabled; the header's collapse and the row selection (not commands) stay live; the list is shown.
5. **Row sizing:** Material 3 icon buttons are 40 px minimum; each control sits in a tight 28x28 box so a row is 32 px and the name gets ~140 px at 280 px. List cap = 6 x 32 px.
6. **Extra keys** beyond the plan's list: `layer-name-field-<hex>` (the rename TextField; `layer-name-<hex>` is the name label), `layer-colour-item-<aci>` (menu entries), `layers-header`, `layers-list`.
7. **+** allocates its handle with `document.handleSeed.next()` before executing, as every tool does; the seed is not rewound by undo (unchanged engine behaviour).
8. **Existing layout tests:** none needed an edit. Checked planner_shell_test "the three chrome slots are laid out", planner_box_test BX6 and wall_tool_test:491 (they tap the first EditableText under chrome-right; the Layers panel has none unless a rename is open). Full app suite green unchanged.
9. "The list follows Open" is tested through the real app (FakeDocumentFiles, openFlow): the opened file's layers, its current layer B and hidden C show; a lock tap makes the real session dirty. The didUpdateWidget path is tested separately with listener counts.
10. M-12a goes red at the disabled assertion; the taps that follow would also have raised (tester.takeException) — the test never catches a PermissionDeniedError itself.
