# Plan 12b results — the layer panel

**Branch:** `plan-12b/layer-panel`, cut from `spec-12b/layer-panel` at
`3b35ef2` (the spec branch was cut from `main` at `7330c7b`). **Spec:**
[2026-10-01-layer-panel-design.md](../specs/2026-10-01-layer-panel-design.md),
revision 3 (`c8b55da`), approved by the human on 2026-10-01 ("onaylıyorum,
devam et", recorded at `3b35ef2`), amended at execution (its closing
section). **Plan:**
[2026-10-01-layer-panel.md](../plans/2026-10-01-layer-panel.md) (`9ee2e60`).
**Ledger:** [`ledgers/2026-10-01-plan-12b/`](../ledgers/2026-10-01-plan-12b/)
(`progress.md` carries every ruling R-12b-1 .. R-12b-9 with its
cost-if-wrong; the directory is created by a later commit, which archives
the ledger, so the link resolves only after that commit).

12b gives the floor planner layers. A collapsible **Layers** section in the
right panel lists every layer (layer 0 first, then by name): each row has a
current-layer mark, an eye, a lock, a colour swatch (ACI 1–9) and the name,
renamed inline by a double-click; + adds `Layer N`, delete removes an empty
layer. Every tool — drafting, symbols, walls, openings, separators, rooms,
dimensions — draws on the current layer. The Selection section gains a
**Layer** menu that moves the whole selection (lines, regions, symbols and
parametric objects alike) to a layer in one undo step. Hidden layers do not
draw, pick, snap, outline or plot; locked layers draw and do not select.
Every change is one command, one undo step, and marks the document dirty.
The file keeps the layers, the current layer and every object's layer
(schema 7).

The engine gains the header's `currentLayer`, schema 7, the six layer
commands in two forms (user, `.restore`), `ObjectLayer` and the
regeneration's stamp and detach, the index's revision check, reconcile skip
and effective layer (layer-0 substitution) on a preallocated depth array,
two validation warnings and `drafting`'s required `layer`. The render
package gains the selection prune, the outline's and the oracle's effective
layer, and the drawing tools' current layer. The app gains `LayerPanel`,
`LayerRow`, `LayerPicker`, the tools' and the placer's current layer, the
dimension attach gate and the opening tool's host rule.

Every task had a fresh implementer. Tasks 1–10 each had an independent
reviewer who re-ran the gates and re-fired mutants; **10b (`c3ab7ca`) and
11a (`1f2788a`, `35af9b9`) had no per-task review: their only review is the
final whole-branch review** (plan Task 11, at `35af9b9`), whose verdict was
**Ready with fixes** — see "The final whole-branch review" below; 11b
(`064965c` and this commit) carries its fixes.

| Task | Commits | Review |
|---|---|---|
| 1 The header, the target, schema 7 (D3, D4, F8) | `a6cd4bb` | Approved with notes (no defect; 17 mutants red; the fingerprint re-baseline is owed on macOS, R-12b-1; R-12b-3 real but narrow, a known limitation) |
| 2 The layer commands and `ObjectLayer` (D1, D2, D3, D4, D5) | `ab7a225`; `582f78b` (2b, test-only) | Approved with notes (no product defect; R-12b-4 confirmed; three surviving own mutants were test gaps -> 2b) |
| 3 The index sees layer changes (D6 engine half, P-4) | `f5998db`, `af87621`; `540f9cf` (3b) | Approved with notes (R-12b-5, R-12b-6 confirmed; the reconcile skip missed an entity sharing a layer's handle in a malformed file -> 3b guard; two test gaps -> 3b) |
| 4 The `layer` parameter (D7, P-8) | `4a735fb` | Approved with notes (mechanical: 56 inserts in 33 files, checked by script by both; M3b-4 pinnable by cost only) |
| 5 The stamp and the detach (D2) | `04a14b3`; `5b1c912` (5b) | Approved with notes (rollback injected and verified; R4 survived (fill and boundary on different layers) -> 5b OL3b, plus the cascade-loss detach test). **Engine frozen after `5b1c912`** (a comment fix was its only lib change), until 11b's one-condition fix (final review Finding 1) |
| 6 Render: selection, outline, oracle (D6, D8) | `0473696`, `3a3286b`; `a4d85f0` (6b) | Approved with notes (R-12b-7: the oracle must match the painter below the root -> 6b; R-12b-8 recorded; root instance key not gated, V3, V4 -> 6b) |
| 7 Render: the drawing tools and the frame (D6, D7) | `4c7eca3` | Approved with notes (no defect; M-12e in the engine's `TableSection` wiring accepted). **Render `lib/` unchanged after `4c7eca3`** |
| 8 App: tools and hosts (D2, D6, D7) | `27db262`; `1afcfdd` (8b, test-only) | Approved with notes (R-12b-9 confirmed; R2, R3 test gaps -> 8b; the Wall tool joins a hidden wall: an open question for the human) |
| 9 App: `LayerPanel` (D9, D10, D11) | `7e83eae`; `8eef675` (9b) | Approved with notes (a stale captured record could revert a same-frame rename -> 9b reads the live record; O1–O3 test gaps -> 9b) |
| 10 App: `LayerPicker` (D12) | `5ef5673`; `c3ab7ca` (10b) | Approved with notes (no defect; R-own-2, -3, -5 test gaps -> 10b; `_choose` catch and a neutral delete tooltip -> 10b). 10b itself: reviewed only by the final review |
| 11a End to end, the sweep, this note | `1f2788a` (test-only); `35af9b9` (docs) | Reviewed only by the final whole-branch review: Ready with fixes |
| 11b The final review's fixes | `064965c` (engine + app); this commit (docs) | The fixes of the final review's Findings 1–3 (below); no further review |

## The final whole-branch review

Independent, on the whole branch (`git diff 7330c7b 35af9b9`), at the tip
`35af9b9`: every gate re-run green (the standing failures only), the
non-negotiables and the human decisions 1–11 checked. **Verdict: Ready with
fixes.** Its findings and how each was resolved:

1. **Minor defect, file-only state: a layer whose stored name fails D4
   could not be hidden, shown, locked or recoloured.** `SetLayerCommand`'s
   user form ran `layerNameError` even when the name was unchanged, so every
   eye, lock or swatch press on a layer loaded as `Walls:Ext` or ` Walls`
   threw `ArgumentError` out of the button (the panel had no catch) and
   dispatched nothing. **Fixed in 11b (`064965c`):** the user form checks
   the name only on a rename (`record.name != old.name`); the layer-0 and
   decision-7 checks are unchanged. Engine test: such layers, reloaded
   through the codec, are hidden, locked and recoloured (one undo step
   each, undo restores the bytes), and a rename to another invalid name is
   still refused with the bytes unchanged; app test: the panel's eye hides a
   `Walls:Ext` layer. Also `LayerPanel._execute` now catches `ArgumentError`
   and `StateError` as `LayerPicker._choose` and the Selection section do;
   app test: a refused press (A made current by a direct header write the
   panel does not observe, its eye still enabled) leaves the document's
   bytes and undo depth unchanged and raises nothing. Mutants M11b-1,
   M11b-1b, M11b-2 below. Recorded in the spec's amendments.
2. **Nit (docs): the macOS fingerprint step was not executable as
   written** (each test stops at its first failing `expect`, so one run
   reports only one actual). **Fixed in 11b:** the look list's step is two
   runs.
3. **Nit (docs): this note's bookkeeping** ("every task had an independent
   reviewer"; the review's verdict and sample owed). **Fixed in 11b:** the
   sentence above, the task table, this section and the sample below.
4. **Info: decision 8 has no direct app-level regression test** (a hidden
   or locked wall still cut by its opening, still bounding its room,
   regenerated by a neighbour's edit); only the Wall tool's join (8b) and
   the engine's neighbour case (OL5) pin it. Structurally safe: no generator
   or parametric path reads `visible`, `locked` or `QueryFilter`. No fix
   needed; not done.

**Its sample: 32 mutants re-fired on the tip `35af9b9`, 32 red** (cp
backup, one edit, the named test file, cp back, `diff` 0 each time):
M-LP-1, M-LP-2, M-LP-3, M-LP-4 (boundary), M-LP-4 (fill), M-LP-6,
M-LP-7a, M-LP-9, M-LP-10 (`ObjectLayer`), M-LP-11, M-LP-12, M-LP-13,
M-LP-14 (band, pick, snap, outline — four), M-LP-15, M-LP-16 (line, wall,
symbol — three), M-LP-17, M-LP-19, M-LP-20, M-LP-21, M-LP-22, M-LP-23,
M-LP-25, M-LP-26, M-12a, M-12e, M10b-catch (10b) and the end-to-end
M-LP-1 (11a).

## What the execution found that the spec did not

Each ruling is in the ledger's `progress.md` with its cost-if-wrong; the
spec's "Amended at execution (Plan 12b)" lists every deviation.

- **R-12b-1, the fingerprints.** The engine's two standing Linux failures
  (`test/testing/generate_document_test.dart`) are exactly the two
  fingerprint tests P-7 asked to re-baseline; their constants are macOS
  values (Ruling 07-7: trig-dependent output). A Linux container cannot
  compute the macOS value, so the constants were left with a comment, and
  **the two tests now fail on macOS too until the human re-baselines them**
  (the look list below has the exact step).
- **R-12b-2.** `apps/floor_planner/assets/library/furniture.jetlib` is a
  committed codec output pinned byte for byte; it was regenerated with
  `tool/generate_furniture_library.dart` (diff: schema 6 -> 7 and the
  header's `currentLayer`, nothing else, verified by script by implementer
  and reviewer). Not in the plan.
- **R-12b-3 (known limitation).** A dangling stored `currentLayer` does not
  raise the handle seed on load, so a later new layer could be issued that
  handle and become current at once. Only a hand-edited or foreign file can
  hold one; no reference kind raises the seed today. A cross-cutting
  "references raise the seed" fix, later.
- **R-12b-4, decision 7 as a transition.** The user form refuses only a
  *hide* of the effective current layer; recolouring or locking an
  already-hidden effective current layer 0 (the S-6 file state) is allowed,
  which D9's enabled lock and swatch need.
- **R-12b-5, the allocation probe uses budgets.** `_descend` already
  allocates per level (budgeted in `query_allocation_test.dart`), and
  `_Uint32List` cannot be watched (VM-service traffic); the probe watches
  what a dropped cache re-allocates (`_Set`), proven by mutant T3b.
- **R-12b-6.** The `_ownerLayer` memo relies on `SetInstanceLayerCommand`
  touching the node, which rebuilds the index (checked).
- **R-12b-7, the oracle below the root.** P-5 had the oracle filter
  contained leaves and nested instances; spec D6 keeps the painter's
  definition walk unfiltered. The spec won: the oracle filters only at the
  root, and a test pins painter == oracle in the residual state (6b).
- **R-12b-8.** The render selection reads `objectLayer` for every group key
  (it cannot tell a parametric group from a plain one), so a plain group
  without `ObjectLayer` counts as layer 0. File-only.
- **R-12b-9, the opening tool's host where bands overlap.** A wall that may
  not host (hidden or locked object layer) is passed over and the next band
  in handle order hosts; the Wall tool's band join stays unfiltered
  (decision 8).
- **Task 3: the ATTRIB rule lives in the shared leaf path**
  (`acceptsEntityOnLayer`), so an ATTRIB of a nested instance follows its
  owner, or the context when the owner is on layer 0. **Task 3 review: the
  reconcile skip** fired for any handle naming a layer, so a malformed file
  where a layer shares an entity's handle left the index stale (demonstrated);
  3b guards it with one conjunct per kind of handle.
- **Task 7: M-12e's form.** The plan's "a copy of the table edit used by the
  test" would have been a test-side fake; the mutant was built in the
  product (the layers section constructed without `onMutated`,
  `tables.dart:562`). The `add`-only bypass is equivalent for the canvas
  test (`SetLayerCommand` is remove-then-add, and `remove` still bumps the
  revision) and is killed by the engine's `tables_revision_test.dart`.
- **Task 8.** The host rule lives in `WallBands.hostAt(…, accept:)`
  (`wall_bands.dart`, not in the plan's file list); the opening tool's scan
  memo also keys on `tables.mutationRevision`.
- **Task 9.** `LayerPanel` takes an optional `foreground` (the paper's
  foreground, for ACI 7's swatch); a blur with a valid name commits it; the
  current mark is disabled on the layer that is already stored and
  effective current. **Task 9 review: a stale captured record** in the row
  callbacks could revert a rename committed on blur by the same pointer
  sequence; 9b reads the live record at dispatch.
- **Task 10.** `isParametricObject` is a hard-coded list of the six app
  types (the engine exposes no "any registered type" query; the engine was
  frozen); the catalog and the predicate now name each other (10b). The
  picker shows a key's layer per item and moves per record, so a file-split
  region (fill on D, boundary on A) shows A and choosing A repairs it. An
  absent `ObjectLayer` moved to layer 0 is a no-op; a dangling one is
  rewritten to `ObjectLayer(0)` (stored values, exact `==`).
- **Task 11a, the end-to-end test** (`layers_end_to_end_test.dart`):
  `FloorPlannerApp` over scripted files, a rotated camera far from the
  origin. A line on layer 0; + makes `Layer 1`, renamed `Furniture`,
  recoloured ACI 3, made current; a line and a wall drawn with the real
  tools land on it (every wall child too). Layer 0 is made current again —
  the current layer cannot be hidden, so the plan's literal order is
  impossible; the disabled eye is asserted as a premise — and the layer is
  hidden: the canvas's own painter (`debugOnVisit`) repaints with layer 0's
  line and without the line or any wall child; shown, all back. The wall,
  selected by a click, moves to layer 0 through the picker in one undo
  step; the layer is made current again; Save, Open, Save: **the second
  Save is byte-identical to the first**, the current layer and every layer
  (name, colour, visible, locked) kept, the panel showing it.
- **The environment.** Flutter 3.47.2 at `/root/flutter`, `CI=true` on
  every command. `flutter pub get` rewrites
  `packages/jet_cad/analysis_options.yaml`; it was never staged. Two
  container restarts during Task 10 and the ledger's resume rules held (a
  partial 9b edit survived and was reviewed as intentional work).

## Gates of record (Linux container, `CI=true`)

Branch point `7330c7b`: engine 1,121 + 2 standing; render 1,154 + 1 skip +
7 standing; app 934. At `064965c` (11b's fix; this commit changes only
docs):

- **engine** `00:18 +1226 -2: Some tests failed.` — the 2 standing, by
  name: `test/testing/generate_document_test.dart: the default document is
  the one Plan 2 measured, byte for byte` and `…: both text fractions
  default to zero and change nothing`. 1,226 = 1,121 + 17 (Task 1) + 46 (2)
  + 3 (2b) + 17 (3) + 7 (3b) + 12 (5) + 2 (5b) + 1 (11b). `dart analyze`
  `No issues found!`; `Formatted 168 files (0 changed)`.
- **render** `01:00 +1187 ~1 -7: Some tests failed.` — the 7 standing Linux
  golden failures (text ladder rungs 1–5, text lod ladder rungs 1–2,
  `RenderBackend.canvas`); the skip is the `rig`-tagged test. 1,187 = 1,154
  + 21 (Task 6) + 4 (6b) + 8 (7). `flutter analyze` `No issues found!`;
  `Formatted 208 files (0 changed)`. `flutter test --tags golden`:
  `00:33 +28 -7: Some tests failed.`, the same 7 and no other.
- **app** `03:33 +993: All tests passed!` — 993 = 934 + 17 (Task 8) + 2
  (8b) + 21 (9) + 3 (9b) + 9 (10) + 4 (10b) + 1 (11a) + 2 (11b). `flutter analyze`
  `No issues found!`; `Formatted 175 files (0 changed)`.
- **dev_harness_2d** `flutter analyze`: `No issues found!`.
- **web** `CI=true flutter build web --release`: `Compiling lib/main.dart
  for the Web... 52.7s`, `✓ Built build/web`.
- **The two allocation invariant tests** are unedited (`git diff 7330c7b --
  packages/jet_cad_2d/test/invariants/query_allocation_test.dart
  packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart`
  is empty) and green inside the engine and render runs.
- **No golden PNG changed** (`git diff --stat 7330c7b -- '*.png'` is
  empty). The only non-Dart, non-Markdown file changed is
  `apps/floor_planner/assets/library/furniture.jetlib` (R-12b-2).
- `analysis_options.yaml` is not in `git diff --stat 7330c7b`.
- The engine's fingerprint constants (`generate_document_test.dart:66, :68,
  :251, :253`) are unchanged macOS values (R-12b-1).

## Mutants

The P-10 rule: this table is compiled from each task's report and
independent review, both of which fired real runs at the task commit (cp
backup, one edit, the named test file in the foreground, cp back, `diff`
exit 0 every time); the final whole-branch review re-fires a sample on the
tip. **Numbering:** the spec's mutants are `M-LP-n` (R-19), so they do not
collide with roadmap 12's `M-12b`; roadmap 12's own are `M-12a` and
`M-12e`. Named first, then the notable own mutants.

| Id | Mutation | Red test | Task |
|---|---|---|---|
| M-LP-1 | `_beginQuery` never invalidates on a revision change | `layer_filter_test` hidden-by-direct-write (and the command, lock, layer-0 tests); at the frame (`canvas_layer_test`, review O1); end to end (`Expected: not contains <20>`) | 3; 7 review; 11a |
| M-LP-2 | no reconcile skip for a layer handle | `layer_filter_test` "cost the index no rebuild" and the S-4 "rebuilds once" | 3 |
| M-LP-3 | stamp added children only (`_stampLayer` never) | `object_layer_test` OL2 move-then-edit (`Expected: <18> Actual: <1>`), OL3–OL5, OL11 | 5 |
| M-LP-4 | a matched region's boundary not stamped; separately its fill | OL3 with reason `boundary 7D2` / `fill 7D1` (each) | 5 |
| M-LP-5 | the picker moves only the picked record of a region | `layer_picker_test` mixed and boundary (`Expected: <43> Actual: <18>`) | 10 |
| M-LP-6 | the stamp's `!=` guard dropped | OL8a (a `SetEntityLayerCommand` in the replay), OL8b (`capability` geometry, not components) | 5 |
| M-LP-7 | an inverse built with the user form (×6, every inverse) | `layer_commands_test` restore-form (a)–(d), the instance move, the add over a dangling current | 2 |
| M-LP-8 | `SetLayerCommand` skips D4 | rename to a case-folded duplicate / an invalid name (record kept) | 2 |
| M-LP-9 | the user form allows hiding the effective current layer | "the effective current layer cannot be hidden" | 2 |
| M-LP-10 | emptiness ignores `ObjectLayer`; ignores definition leaves; counts a dead node's `ObjectLayer` | the three `RemoveLayerCommand` tests, each | 2 |
| M-LP-11 | the cleanup does not detach `ObjectLayer` | OL9 delete-last-wall; OL9b cascade loss (`Expected: null Actual: ObjectLayer(12)`) | 5; 5b |
| M-LP-12 | `_loadHeader` does not copy `currentLayer` | `layer_header_test` round trip (+3); end to end (`Expected: <19> Actual: <1>`) | 1; 11a |
| M-LP-13 | `kSchemaVersion` stays 6 | "writes schema 7, reads 7, and refuses the next one" | 1 |
| M-LP-14 | no substitution in picking; snapping; the band; the outline; one level instead of recursive | `layer_filter_test` pick, snap, band, recursion; `outline_layer_test` substitution and one level | 3; 6 |
| M-LP-15 | the selection does not prune (keys; separately the hover) | `selection_prune_test` (`+4 -6`; hover `Expected: null`) | 6 |
| M-LP-16 | a tool keeps layer 0: line, text, region, shape; box, wall, opening, separator, room, dimension; the symbol placer | `draw_tools_layer_test`; `tools_layer_test`, each its own test (`Expected: <19> Actual: <1>`); end to end, line and wall | 7; 8; 11a |
| M-LP-17 | the picker dispatches one command per key | mixed (`Expected: <1> Actual: <6>`), boundary, hidden, runtime | 10 |
| M-LP-18 | rename dispatches per keystroke | `layer_panel_test` Enter (`Expected: <0> Actual: <5>`), case-only, focus loss | 9 |
| M-LP-19 | the layer moves report `capability: components` (entity; instance) | `tile_cache_layer_test` (line to C, A to B; instance to C) | 7 |
| M-LP-20 | `dimension_attach` ignores the host's `ObjectLayer` | `attach_layer_test` (`Expected: empty Actual: [AttachedEnd:19/0/left]`) | 8 |
| M-LP-21 | `drawingLayer` returns the stored layer unchecked | dangling, hidden (S-5), removed current | 1 |
| M-LP-22 | the oracle ignores layer visibility | `reference_walk_layer_test` the absolute assertions (`Expected: not contains <25>`) | 6; 6b |
| M-LP-23 | no ATTRIB substitution in `acceptsEntity` | "the instance on A is still drawn, and so is its ATTRIB" (+ pick, hide, lock) | 3 |
| M-LP-24 | no substitution for nested instances in `acceptsNode` (descend; band) | pick/snap through every level; the band | 3 |
| M-LP-25 | the opening tool ignores its host's layer | `opening_host_layer_test` hidden, locked, re-hover, overlap (`Expected: null Actual: <29>`) | 8 |
| M-LP-26 | the eye disables showing on the effective current layer too | the S-6 hidden-layer-0 file test | 9 |
| M-12a | `LayerPanel` ignores permissions (the dispatcher still enforces) | the read-only test, red at the disabled assertion, no `PermissionDeniedError` caught | 9 |
| M-12e | the layers `TableSection` built without `onMutated` (`tables.dart:562`, the product's wiring, not a test copy) | `canvas_layer_test` (`Expected: not contains <23>`) | 7 |

Notable own mutants, all red unless marked:

| Id | Mutation | Red test | Task |
|---|---|---|---|
| M-12e add-only | drop `onMutated?.call()` in `TableSection.add` only | **equivalent for the canvas test** (`remove` still bumps); killed by the engine's `tables_revision_test` (two tests) | 7, 7 review |
| T1 a–f, O1–O10 | `layerNameError` branches; `drawingLayer`, `fromJson`, `copyWith`, key order, defaults | `layer_header_test` (17 red) | 1, 1 review |
| O11 / O11b | `AddLayerCommand` user form accepts a used node / definition handle | first **survived** (entity-only test); red after the test looped over all kinds | 2 |
| R1–R4 (Task 2 review) | layer 0 never-empty; layer 0 delete; decision 7's `old.visible`; the restore form's name-holder check | all **survived** at Task 2; red by 2b | 2b |
| T3c / T3e / T3f | a query does not write its effective-layer depth (band root; `_descend`; `_bandDescend`) | first **survived** (zero-filled array, a missing layer is visible); red by `af87621`'s stale-depth tests | 3 |
| T3b | the filter cache dropped every query | the allocation probe (`_Set` per call) | 3 |
| O6 (Task 3 review) | `rebuildAll` does not record the revision | **equivalent** apart from cost | 3 review |
| Task 3 review finding 1 | the reconcile skip for a handle shared with an entity | demonstrated stale; M3b-0..3 red by one test per conjunct | 3b |
| M3b-4 | drop the definition conjunct | **survives**: behaviour-equivalent (no query answer differs); pinnable only by `rebuildCount` | 3b, 4 review |
| O1 / O2 (Task 3 review) | nested ATTRIB on layer 0 pins to 0; nested instance's lock tested by its stored layer | both **survived**; red by 3b (O2 only in the converse case, layer 0 locked, A unlocked: the review's suggested test cannot catch it) | 3b |
| X-dissolve, X-recordOf, X-plain, R1–R3 | the dissolve's detach; added records on 0; matched plain/TEXT not stamped; a neighbour's own layer | OL10; OL1+; OL2+; OL2, OL5 | 5, 5 review |
| R4 (Task 5 review) | the boundary stamp guarded on the fill's layer | **survived**; red by 5b OL3b (`Expected: <18> Actual: <1>`) | 5b |
| O-fill, O-attrib, O-group, O-missing, V1, V2 | the selection's region, ATTRIB, group, missing-layer, lock and notify rules | `selection_prune_test` | 6, 6 review |
| O-nested-node, R-instance | the outline's nested gate; the oracle's root-instance skip | both first **survived**; red by `3a3286b` | 6 |
| V3, V4 (Task 6 review) | the outline's fill context; the oracle's missing layer counts as hidden | both **survived**; red by 6b | 6b |
| R-below | the old stricter oracle (filter below the root) | the 6b residual test (`Expected: contains <31>`) | 6b |
| O-root-gate | the outline's root instance not gated | 6b (`Expected: empty`) | 6b |
| D-stored | a tool uses `header.currentLayer`, not `drawingLayer` | the hidden-stored-current tests (line tool; box tool) | 7; 8 |
| U-undo | only the restore form's move reports `components` | the tile test's undo leg | 7 review |
| O2 (Task 7 review) | the painter's instance query with `QueryFilter.all()` | `export_layer_test` (`Expected: <3> Actual: <2>`) | 7 review |
| E-leaf, E-instance | the filter's leaf / instance layer checks | `export_layer_test` | 7 |
| H-locked, H-pass, H-rev, T-drop | the host's lock; a refused wall blocks; the memo key; the tool's `ObjectLayer` dropped | `opening_host_layer_test`; `tools_layer_test` | 8 |
| R2, R3 (Task 8 review) | attach reads the stored component; the Wall tool's join filters hidden walls | both **survived**; red by 8b | 8b |
| P1–P13, O4 | the panel's subscriptions, order, `Layer N`, swatch, guard, blur, trim, lineweight, delete, `didUpdateWidget`, current, dispose; colour no-op | `layer_panel_test` | 9, 9 review |
| O1, O2, O3 (Task 9 review) | rename also flips `locked` / sets ACI 7; delete's current check on the stored value | all **survived**; red by 9b | 9b |
| M9b-1 | the lock built from the captured record | the blur-rename-then-lock test | 9b |
| O-1..O-14, R-own-1, R-own-4 | the picker's region, ATTRIB, no-op, label, permission, plain group, placement rules | `layer_picker_test` (O-12 first **survived** a degenerate premise; tightened) | 10, 10 review |
| R-own-5, R-own-2, R-own-3 (Task 10 review) | Separator and Room dropped from `isParametricObject`; `components` -> `transform`; the no-op on `objectLayer` instead of the stored value | all **survived**; red by 10b | 10b |
| M10b-catch, M10b-tip | `_choose` no longer catches `StateError`; the delete tooltip back to "Read-only document" | the refused-move test; the read-only test | 10b |
| E2E-picker | `_choose` never executes | the end-to-end test (one undo step) | 11a |
| M11b-1 | `SetLayerCommand`'s name check unconditional again (`if (true)`, the defect of final review Finding 1) | `layer_commands_test` the loaded-invalid-name test (`Invalid argument (name): A layer name cannot contain :.: "Walls:Ext"`); `layer_panel_test` its eye test (`Expected: false Actual: <true>`) | 11b |
| M11b-1b | no name check at all (`if (false)`) | the new test's refused renames, M-LP-8's two tests (`Expected: throws <Instance of 'ArgumentError'>`) | 11b |
| M11b-2 | `LayerPanel._execute` no longer catches `ArgumentError` | the refused-press test (`Expected: null Actual: ArgumentError:<Invalid argument (record): The current layer cannot be hidden.…`) | 11b |

## Found, not fixed (known limitations)

- **R-12b-3:** a dangling stored `currentLayer` does not raise the handle
  seed on load; a later new layer can take that handle and become current.
  File-only.
- **The painter's unfiltered definition walk (D6's residual):** a
  definition leaf or nested instance on a non-zero hidden layer still draws
  (the oracle matches it, R-12b-7; the outline and picking do not include
  it). The library refuses such a symbol; only a hand-written file reaches
  it.
- **The ATTRIB's style is not substituted (S-2):** an ATTRIB on layer 0
  follows its instance for visibility and lock but keeps the root context's
  style.
- **An ATTRIB on its own non-zero layer (Task 10 review info 4):** the
  picker shows and moves its instance (S-14), while the selection's prune
  uses the ATTRIB's own layer; moving the instance to a hidden layer can
  leave the ATTRIB key selected. No app path makes such an ATTRIB.
- **`ObjectLayer` on a nested (re-parented) group (Task 5 review info 3)**
  is inert and is left behind when its dead parent takes it down, as the
  registered components are. Only the CS7 state reaches it.
- **A plain group without `ObjectLayer` counts as layer 0 in the render
  selection (R-12b-8);** the picker disables for a plain group. File-only.
- **The index ignores a definition's base point** (Task 4 review note 3,
  pre-existing; the 09a placer applies it).
- **`isParametricObject` is a hard-coded list** of the six app types; a
  seventh type must be added there (the catalog says so). Later: an engine
  `ParametricCatalog.isObject(target, h)`, which R-12b-8 could use too.
- **The picker's menu has no colour swatches** (names only; the Selection
  section has no paper foreground for ACI 7).
- **The opening tool's memo within one synchronous step** (Task 8 review
  info 4): an `ObjectLayer` move and a re-hover of the same point in the
  same task can serve a stale host until the change stream delivers; a
  click always invalidates.
- **M3b-4** (the reconcile skip's definition conjunct) is pinned by nothing
  but cost; removing a definition at a layer's handle is skipped even with
  the guard (Task 4 review note 2). Malformed files only.
- **`LayerPanel._execute`'s `on StateError` arm is pinned by nothing**
  (11b): no panel action reaches a `StateError` from a sound document; it
  is kept for parity with `LayerPicker._choose` and the Selection section.
- **Decision 8 has no direct app-level regression test** (final review
  Finding 4); structurally safe, see that section.
- `SetLayerCommand` fires `tables.changes` twice with the record briefly
  missing (remove, then add); every listener reads on the next frame or the
  DocChange (Task 2 review info 4, checked again in Task 9's review).

## Risks seen

- **The stamp in the regeneration** (the spec's first risk): one column,
  exact `==`, guarded (M-LP-6); the existing parametric suite was edited
  only to pass `layer:` (Task 4's 56 inserts); a rollback with stamps in
  the plan was injected and verified byte for byte (Task 5 review).
- **Schema 7:** files from this build are refused by older builds; the
  pinned tests moved with it (P-7), and the committed furniture library
  with them (R-12b-2).
- **The fingerprints** are red on macOS until re-baselined (R-12b-1).
- **The right panel's height:** Selection, Layers (up to 6 rows, 272 px)
  and Page share the column, which does not scroll as a whole; no overflow
  was seen at 1280 × 640 with tool settings shown (Task 9 and 10 probes),
  but a tall selection on a short window is untested.
- **The hover path's allocation:** guarded by the unedited invariant tests
  and Task 3's probe (budgets, R-12b-5).
- **Handles shared between a table and an entity or node** are possible in
  a malformed file (no check on load or in `validate`); 3b guards the
  index against it, nothing else does.

## The human's look

From the spec's "The look", amended by the rulings. **Nothing is marked
done for the human.** macOS and web (Chrome, Firefox).

- **Owed on macOS first: the two engine fingerprint tests (R-12b-1).** In
  `packages/jet_cad_2d`, run `dart test
  test/testing/generate_document_test.dart`. Each test stops at its first
  failing `expect`, so this run reports one actual, the
  `generateDocument(2000, …)` value, the same in both tests: put it at
  `test/testing/generate_document_test.dart:66` and `:251`. Re-run: both
  now report the `generateDocument(20000, …)` value: put it at `:68` and
  `:253`. Re-run (both green), and commit.
- The Layers section at 280 px: layout with long names (ellipsis), the
  header collapsing and opening, the list scrolling past six rows.
- **32 px rows, below the 48 px touch target** (Task 9): are the eye, lock,
  current mark and swatch comfortable to hit with a mouse and on a
  trackpad?
- **The right column does not scroll as a whole:** a tall selection (a
  wall's or an opening's fields) on a short window, with the Layers section
  open.
- The eye, lock, current mark and colour menu (ACI 1–9; 7 drawn in the
  paper's foreground, also with a dark paper); their tooltips, including
  the disabled eye on the current layer ("The current layer cannot be
  hidden") and the disabled current mark on a hidden layer ("A hidden layer
  cannot be current").
- Inline rename: double-click, Enter, Esc, clicking away (a valid name
  commits, an invalid one reverts), the reason under the field, no shortcut
  (W, L, Cmd+Z…) firing while typing; layer 0 cannot be renamed.
- + (names `Layer N`, opens its name field) and delete with its tooltips
  (in use, layer 0, current; under a read-only or runtime document "Layers
  cannot be changed in this document").
- Hiding a layer with walls, a symbol and a dimension on it: they vanish,
  stop picking and snapping; a door on a visible layer in a hidden wall
  still cuts it (decision 8). Locking: drawn, not selectable; the selection
  drops what becomes hidden or locked.
- The picker (the **Layer** row in the Selection section): on a line alone,
  on a wall, on a mixed selection (shows "Mixed"), on a symbol; **no colour
  swatches in its menu** (is that acceptable?); a long layer name.
- Undo and redo of each panel action and each picker move (one step each);
  the dirty mark after each.
- Export (PDF, PNG) and Print with a hidden layer: it does not plot.
- Every tool draws on the current layer: Line, Text, Rectangle (filled and
  not), Box, Wall, Door, Window, Separator, Room, Dimension, a symbol.
- **An open question for the human:** the Wall tool snaps and joins a new
  wall to a wall on a **hidden** layer (decision 8 keeps hidden walls
  joining; S-11 filtered only the opening tool's host). A click near an
  invisible wall therefore bends the new wall's end to it. **Keep, or
  filter the join too?**
