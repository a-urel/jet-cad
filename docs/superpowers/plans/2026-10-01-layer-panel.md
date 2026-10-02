# Layer panel, sub-project 12 slice 12b — implementation plan

> **For agentic workers:** executed task by task, subagent-driven: a fresh
> implementer per task and an independent reviewer per task, then a final
> whole-branch review. Steps use checkbox (`- [ ]`) syntax.

**Goal:** a user can create, rename, recolour, hide and lock layers, choose
the current layer that every tool draws on, and move the selection —
drafting, symbols and parametric objects alike — to a layer; each step one
undo step, each marking the document dirty; hidden layers neither draw,
pick, snap nor plot; the file keeps it all (schema 7).

**Spec:** [docs/superpowers/specs/2026-10-01-layer-panel-design.md](../specs/2026-10-01-layer-panel-design.md),
**revision 3** (`c8b55da`, approval recorded at `3b35ef2`). Read it whole
before Task 1. It has 11 human decisions, 11 facts (F1–F11), 13 decisions
(D1–D13), 26 named mutants (M-LP-1 … M-LP-26) plus the roadmap's M-12a and
M-12e, and no open question. It was reviewed independently twice (R-1–R-19,
S-1–S-16). **The human approved it on 2026-10-01** ("onaylıyorum, devam
et"), including the two rulings made in writing (the opening tool's host,
S-11; the ATTRIB style residual, S-2).

**Architecture:**
- **Engine** (`packages/jet_cad_2d`): the header and schema 7 (Task 1), the
  layer commands and `ObjectLayer` (Task 2), the index (Task 3), the
  `layer` parameter (Task 4), the regeneration's stamp and detach (Task 5).
  Frozen after Task 5 except for fixes a later review demands.
- **Render** (`packages/jet_cad_2d_flutter`): selection, outline and oracle
  (Task 6), the drawing tools and the frame-level tests (Task 7).
- **App** (`apps/floor_planner`): the tools and the hosts (Task 8),
  `LayerPanel` (Task 9), `LayerPicker` (Task 10).

**Tech stack:** Dart, Flutter 3.47.2 at `/root/flutter`. **No new
dependency.**

## Rulings made here rather than left to an implementer

- **P-1 (branch).** `plan-12b/layer-panel`, cut from `spec-12b/layer-panel`
  at `3b35ef2`; worktree `.claude/worktrees/plan-12b`. Reviews in a
  detached worktree (`.claude/worktrees/plan-12b-review`). Reviewed commits
  are pushed to `origin/plan-12b/layer-panel` only after the review
  approves. Merge is the human's, `--no-ff`, from the main checkout. The
  proxy refuses remote branch deletion: name merged branches for the human.
- **P-2 (the restore form).** Each D1 command has a public user
  constructor and a public named constructor `.restore(...)`. The user
  constructor validates in `apply` (before any mutation) and throws
  `ArgumentError`; `.restore` checks only that the handle it needs exists
  (`StateError` otherwise) and writes the stored value exactly. Every
  `inverse` a D1 command returns is built with `.restore`; the
  regeneration's stamp uses `SetEntityLayerCommand.restore`. A private
  `final bool _restore` field carries the mode; `==` is not defined on
  commands (none is today).
- **P-3 (where the helpers live).** `layerNameError`, `drawingLayer` and
  `objectLayer` live in `lib/src/document/layer_commands.dart` next to the
  commands and are exported from `package:jet_cad_2d/jet_cad_2d.dart`. They
  take a `CommandTarget` (spec S-12). `objectLayer` reads
  `target.components.get<ObjectLayer>(group)`.
- **P-4 (the effective layer in the index, spec D6/R-11).** The index's
  definition walks already keep a preallocated per-depth `_containerPath`.
  Beside it, a preallocated `Uint32List _effectiveLayer` of the same
  capacity (grown with it, never per query) holds the effective layer at
  each depth: at depth 0 the instance's own layer, or — if that is layer 0 —
  the layer of the context it sits in (layer 0 at the root); at depth
  `d+1` a nested instance's own layer, or depth `d`'s when its own is
  layer 0. Leaf tests and nested `acceptsNode` tests at depth `d` use
  `FilterEvaluator.acceptsEntityOnLayer(slot, filter, effective)` /
  `acceptsNodeOnLayer(...)`: new methods that take the layer to test
  instead of reading it, sharing the memo maps. `acceptsEntity` itself
  gains the ATTRIB rule (S-2): when the leaf is on layer 0 and
  `ownerAt(slot)` is an `InstanceNode`, the owner's effective layer is
  used, memoised per owner in a new `_ownerLayer` map (cleared by
  `invalidate`). The owner's effective layer is its own, or layer 0's
  rule up its parent chain of instances (root instances: their own).
  **No allocation per query or per entity** — a probe in Task 3 asserts it.
- **P-5 (the oracle's rule).** `reference_walk` re-implements P-4's rule
  independently (by recursion, not by sharing the index's code); that is
  what makes it an oracle.
- **P-6 (fixtures, the testing bar).** One builder per package,
  `test/support/layer_fixture.dart`: a document with layers `A` (ACI 1),
  `B` (ACI 5, locked), `C` (ACI 3, hidden), and layer 0 visible; on each a
  line away from the origin under a non-identity group transform where the
  test needs one; a symbol instance on `A` whose definition leaves are on
  layer 0, with a nested instance on layer 0 and an ATTRIB on layer 0; a
  drafted region on `A`. The app's builder adds a wall on `A`, an opening on
  `B` hosted by it, a room and a dimension. No fixture puts the hidden layer
  at layer 0 unless the test is about layer 0; no colour is ACI 7.
- **P-7 (schema re-baseline, spec R-12/S-9).** Task 1 moves, with a
  one-line comment each: `json_codec_test.dart` (the two pins of 6, and the
  refused future version at `:519` to `kSchemaVersion + 1`),
  `instance_style_codec_test.dart` (`:80` pin; `:191` to
  `kSchemaVersion + 1`), and re-baselines `generate_document_test.dart`'s
  fingerprints (`:59-62`, `:243-246`) naming the header key and the
  version. The 2 standing failures in that file stay exactly 2 (the report
  names them before and after).
- **P-8 (the `layer` parameter, Task 4).** Mechanical: every caller outside
  `drafting.dart` passes `layer: ReservedHandles.layerZero` and nothing
  else changes in that task, so the task's diff is reviewable by grep. The
  callers that later read `drawingLayer` change in Tasks 7 and 8.
- **P-9 (container restarts).** Every agent commits as soon as its gates
  are green, writes its report early and appends to it, and runs mutants in
  the foreground in small batches; a mutant's backup is restored by `cp`
  and checked by `diff`.
- **P-10 (mutant tables).** The results note's table is compiled from task
  reports and reviews; the final review re-fires a sample across tasks on
  the tip.

## Global constraints

- CLAUDE.md's non-negotiables. The frame path gains one int compare per
  query (D6) and P-4's array reads; the two allocation invariant tests stay
  **unedited** and green.
- `CI=true` on every test command; `export PATH=/root/flutter/bin:$PATH`.
- Never `git checkout --` a `.dart` file; mutants by `cp` backup, mutate,
  run the named test file, `cp` back, `diff` exit 0.
- Never commit `analysis_options.yaml` (stage by explicit path).
- **No golden PNG regenerated**; never pass `--update-goldens`.
- Never synthesize output. Code, comments, commit messages in English.
- No widget writes a `TableSection` or the header; every layer change goes
  through `document.commands.execute`.
- Commit trailers:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01M4zdYkH7yTFAU2aCUA8bdQ
  ```
- Scratch prefix for each agent: a per-agent directory under
  `/tmp/claude-0/-home-user-jet-cad/436a473c-2fd9-5dea-b1ee-ba84afc1ba81/scratchpad/`,
  named in its brief.

## Gates (every task)

```sh
export PATH=/root/flutter/bin:$PATH
(cd packages/jet_cad_2d         && CI=true dart test ; CI=true dart analyze && CI=true dart format --output=none --set-exit-if-changed .)
(cd packages/jet_cad_2d_flutter && CI=true flutter test ; CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)
(cd apps/floor_planner          && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)
(cd apps/dev_harness_2d         && CI=true flutter analyze)
```
Plus `CI=true flutter build web --release` in the app in Tasks 9–11.
Branch point (`main` `7330c7b`): engine 1,121 + 2 standing
(`test/testing/generate_document_test.dart`); render 1,154 + 1 skip + 7
standing (the golden text ladders, Linux only); app 934. **Every task from
Task 1 on re-runs all gates**: an engine change reaches every package.

## File structure

| File | Task |
|---|---|
| `packages/jet_cad_2d/lib/src/document/{header,command,tables}.dart`, `lib/src/codec/{json_codec,schema_version}.dart`, `lib/src/document/layer_commands.dart` (new: `layerNameError`, `drawingLayer`); the two command fakes; P-7's tests; `test/document/layer_header_test.dart` (new) | 1 |
| `lib/src/document/layer_commands.dart` (the commands, `objectLayer`), `lib/src/document/object_layer.dart` (new), `component.dart` (registration), `validate.dart` (warnings); `test/document/layer_commands_test.dart`, `test/document/layer_validate_test.dart` (new) | 2 |
| `lib/src/index/{query_filter,spatial_index}.dart`; `test/index/layer_filter_test.dart` (new), `test/support/layer_fixture.dart` (new) | 3 |
| `lib/src/document/drafting.dart`; every caller (P-8) in all packages | 4 |
| `lib/src/parametric/{parametric_system,regeneration}.dart`; `test/parametric/object_layer_test.dart` (new) | 5 |
| `packages/jet_cad_2d_flutter/lib/src/{selection,outline_cache,reference_walk}.dart`; `test/layers/{selection_prune,outline_layer,reference_walk_layer}_test.dart`, `test/support/layer_fixture.dart` (new) | 6 |
| `lib/src/draw/{line_tool,text_tool,placement_tool}.dart`; `test/layers/{draw_tools_layer,canvas_layer,tile_cache_layer,export_layer}_test.dart` (new) | 7 |
| `apps/floor_planner/lib/parametric/{box,wall,opening,separator,room,dimension}_tool.dart`, `dimension_attach.dart`, `opening_tool.dart` (host), `lib/symbols/symbol_placer.dart`; `test/layers/{tools_layer,attach_layer,opening_host_layer}_test.dart`, `test/support/layer_fixture.dart` (new) | 8 |
| `apps/floor_planner/lib/layers/{layer_panel,layer_row}.dart` (new), `lib/main.dart`; `test/layers/layer_panel_test.dart` (new) | 9 |
| `apps/floor_planner/lib/layers/layer_picker.dart` (new), `lib/selection_panel.dart`; `test/layers/layer_picker_test.dart` (new) | 10 |
| `apps/floor_planner/test/layers/layers_end_to_end_test.dart` (new); `docs/superpowers/notes/2026-10-01-plan-12b-results.md` (new); the spec's "Amended at execution"; `roadmap/12-app-shell.md`, `roadmap/00-README.md`; the ledger archive | 11 |

---

### Task 1: Engine — the header, the target, schema 7 (spec D3, D4, F8)

- [ ] `DocumentHeader.currentLayer` (`Handle`, default
  `ReservedHandles.layerZero`); `toJson` writes `'currentLayer'` after
  `'globalLinetypeScale'`; `fromJson` reads it optional (absent ⇒ layer 0);
  `_loadHeader` copies it.
- [ ] `kSchemaVersion = 7` with the v6→v7 paragraph (spec D3: the header key
  and the `jet_cad.object_layer` component).
- [ ] `CommandTarget` gains `DocumentHeader get header`; both test fakes
  (`commands_test.dart:7`, `command_test.dart:7`) implement it.
- [ ] `LayerRecord.copyWith` (every field; exact).
- [ ] `layer_commands.dart` (new) with `layerNameError(target, name,
  {Handle? self})` (spec D4: empty, untrimmed, > 255 UTF-16 units, the
  forbidden characters, a `toLowerCase()` duplicate other than `self`) and
  `drawingLayer(target)` (spec D3). Exported.
- [ ] P-7's re-baselines.
- [ ] Tests (`layer_header_test.dart`): round trip with a non-zero current
  layer, byte-identical; a v6 document (no key) loads with layer 0; a
  `kSchemaVersion + 1` file is refused; a dangling and a hidden stored
  current layer round-trip exactly and `drawingLayer` gives layer 0;
  showing the hidden one (a direct table write here) makes `drawingLayer`
  return it (S-5); every `layerNameError` branch, including a case-only
  rename of `self` being valid and 255 vs 256 units.
- [ ] Mutants: **M-LP-12**, **M-LP-13**, **M-LP-21**; plus one per
  `layerNameError` branch (named M-LP-T1a… in the report).
- [ ] Commit `feat(engine): the current layer in the header, schema 7`.

### Task 2: Engine — the layer commands and `ObjectLayer` (spec D1, D2's component, D3's warnings, D4, D5)

- [ ] `ObjectLayer` (`object_layer.dart`): `typeId 'jet_cad.object_layer'`,
  `toJson {'layer': handle}`, value `==`; registered in `registerBuiltIns`,
  not `internal` (S-16).
- [ ] `objectLayer(target, group)` (spec D2: the component's layer if it
  exists, else layer 0).
- [ ] The six commands of spec D1 with P-2's two forms; the table's
  `capabilities` and `capability`; `touched` never empty (S-3); labels in
  plain English ("Add layer", "Rename layer", "Hide layer", "Move to
  layer", …) chosen by what changed; `SetLayerCommand`'s user form checks
  `layerNameError` (self excluded), layer 0's name, decision 7 against
  `drawingLayer`, before its `remove`.
- [ ] `RemoveLayerCommand`'s user form refuses a non-empty layer (spec D5:
  entity records including definition leaves, `InstanceNode`s,
  `ObjectLayer` on a **live** node, `drawingLayer`, layer 0). Expose
  `layerIsEmpty(target, layer)` for the panel.
- [ ] `validate.dart`: a `warning()` helper beside `error()`, codes
  `header.current_layer_unusable` and `component.object_layer_missing` (any
  handle, live or dead) in `ValidationCodes`.
- [ ] Tests (`layer_commands_test.dart`): each command applies, its inverse
  restores exactly (record or column `==`), re-apply; each user refusal
  leaves the encoded bytes unchanged — notably a rename to a case-folded
  duplicate and to an invalid name keeps the record; the four restore-form
  undo cases of spec Testing (R-2); permissions: `runtime` refuses the
  table commands and allows the moves, `readOnly` refuses all; `touched`
  non-empty for each. `layer_validate_test.dart`: both warnings, and their
  absence on a clean document.
- [ ] Mutants: **M-LP-7**, **M-LP-8**, **M-LP-9**, **M-LP-10** (all three
  halves; the dead-node half needs a dead handle carrying the component,
  made by a direct `components` write in the test, since Task 5's detach
  does not exist yet).
- [ ] Commit `feat(engine): layer commands and ObjectLayer`.

### Task 3: Engine — the index sees layer changes (spec D6 engine half, P-4)

- [ ] `_reconcile` skips a touched handle naming a record in
  `tables.layers` before `_reconcileEntity` (R-1); a handle no longer in
  the table still falls through (S-4).
- [ ] `_beginQuery` compares `document.tables.mutationRevision` with the
  remembered one and invalidates `_filters`; `rebuildAll` records it.
- [ ] P-4: `_effectiveLayer`, `acceptsEntityOnLayer`, `acceptsNodeOnLayer`,
  the ATTRIB rule in `acceptsEntity` with `_ownerLayer`; applied at
  `spatial_index.dart:571, 587, 865, 881, 909` (verify the lines on the
  branch; the report names each site).
- [ ] `test/support/layer_fixture.dart` (P-6, engine half).
- [ ] Tests (`layer_filter_test.dart`): hide after a query — through
  `SetLayerCommand` and through a direct table write — and the next
  rendering, picking and snapping query excludes the layer; show restores;
  undo and redo; `rebuildCount` unchanged across hide, show, lock, rename,
  recolour; substitution: instance on `A` with layer 0 hidden is drawn,
  picked, band-selected, snapped; a nested layer-0 instance follows `A`;
  the ATTRIB follows its instance both ways (S-2); hiding `A` hides and
  unpicks all of it. An allocation probe (the pattern of
  `query_allocation_test.dart`, in the new file) over a pick and a snap in
  the instance fixture: zero allocations in steady state.
- [ ] Mutants: **M-LP-1**, **M-LP-2**, **M-LP-14** (pick, snap, band, one
  level instead of recursive; the outline half is Task 6), **M-LP-23**,
  **M-LP-24**.
- [ ] Commit `feat(engine): the index follows layer visibility and lock`.

### Task 4: Engine — the `layer` parameter (spec D7, P-8)

- [ ] `draftRecord`, `addDrafted`, `addDraftedRegion` take a required
  `Handle layer`.
- [ ] Every caller passes `layer: ReservedHandles.layerZero` (engine lib
  `_recordOf` too, for now; render's three tools; the app's
  `startup_plan.dart`; every test listed in spec D7's blast radius, plus
  any the compiler finds). Nothing else changes.
- [ ] The report lists every changed call (a `git diff --stat` and the grep
  of `layer: ReservedHandles.layerZero` additions); all gates unchanged in
  counts.
- [ ] No mutant (mechanical); the reviewer checks the diff adds only
  `layer:` arguments and the parameter.
- [ ] Commit `refactor(engine): drafting takes the layer explicitly`.

### Task 5: Engine — the stamp and the detach (spec D2)

- [ ] `_recordOf` takes the object's layer (`objectLayer`); every added
  record (plain, region fill and boundary, TEXT) uses it.
- [ ] `_plan`: after the payload rewrite, a matched child whose layer `!=`
  the object's gets `SetEntityLayerCommand.restore`; a matched region,
  one per differing record. The `Generated` class comment records the
  one-column amendment of 06 D11 / 10 D13.
- [ ] 06 D8's cleanup (`regeneration.dart` around `:943`) and 10 D15's
  dissolve (`:530-533`) also plan `SetComponentCommand<ObjectLayer>(h,
  null)` when the object carries one.
- [ ] Tests (`object_layer_test.dart`, with the engine's parametric test
  catalog — the box and the region types the engine tests already use):
  move then edit keeps the layer on matched children; added and matched
  regions (both records); a TEXT child; a neighbour edit; undo and redo;
  no `ObjectLayer` ⇒ layer 0; a missing layer ⇒ layer 0 and the warning;
  an edit leaving layers alone: no `SetEntityLayerCommand` in the replay
  and `capability == components` (S-10); detach on delete and on dissolve,
  undo restores the component (S-1).
- [ ] The existing parametric suite green, unedited beyond Task 4.
- [ ] Mutants: **M-LP-3**, **M-LP-4** (boundary; fill), **M-LP-6**,
  **M-LP-11**.
- [ ] Commit `feat(engine): parametric objects keep their layer`.

### Task 6: Render — selection, outline, oracle (spec D6 render half, D8)

- [ ] `SelectionController`: on every `DocChange`, drop keys and the hover
  whose target's effective layer (root entity: its own, a drafted region's
  by its boundary; instance: its own; a parametric object: `objectLayer` —
  the render package reads the engine's `ObjectLayer`) is hidden or locked.
- [ ] `OutlineCache`'s instance walk uses the effective layer (P-4's rule;
  the outline walk is not on the per-entity frame path but keeps the same
  no-allocation discipline).
- [ ] `reference_walk`: P-5.
- [ ] Render `test/support/layer_fixture.dart`.
- [ ] Tests: prune and keep (`selection_prune_test`); outline of an
  instance on `A` with layer 0 hidden (`outline_layer_test`); the
  differential walk with a hidden layer, a hidden instance layer, a
  non-ACI-7 colour, plus the absolute assertion that the hidden handles
  are in neither sink (`reference_walk_layer_test`, R-18).
- [ ] Mutants: **M-LP-14** (outline half), **M-LP-15**, **M-LP-22**.
- [ ] Commit `feat(render): selection, outline and oracle follow layers`.

### Task 7: Render — the drawing tools and the frame (spec D6, D7)

- [ ] Line, text and placement tools pass `drawingLayer(document)`.
- [ ] Tests: each tool family draws on a non-zero current layer
  (`draw_tools_layer_test`); a `DraftCanvas` repaints after a hiding
  `SetLayerCommand` and its sink receives none of the layer's entities
  (`canvas_layer_test`, M-12e); a tile-cached canvas redraws after a layer
  move and after its undo (`tile_cache_layer_test`, M-LP-19); a page export
  omits a hidden layer (`export_layer_test`).
- [ ] Mutants: **M-LP-16** (drafting), **M-12e** (bypass `onMutated` in a
  copy of the table edit used by the test, as spec Named mutants says),
  **M-LP-19**.
- [ ] Commit `feat(render): drawing tools use the current layer`.

### Task 8: App — tools and hosts (spec D2's creation, D6's attach and host, D7)

- [ ] The six parametric tools add `SetComponentCommand<ObjectLayer>(h,
  ObjectLayer(drawingLayer(doc)))` to their creation compound; the symbol
  placer writes `drawingLayer` on the instance.
- [ ] `dimension_attach`: the host is kept only when its `objectLayer` is
  visible (spec D6, R-7); the doc comment's residual updated.
- [ ] `opening_tool`: the host must have a visible and unlocked
  `objectLayer` (S-11).
- [ ] App `test/support/layer_fixture.dart` (P-6, the app half).
- [ ] Tests: each tool creates on a non-zero current layer and its children
  are on it (`tools_layer_test`); attach refused through the opening of a
  hidden-layer wall (`attach_layer_test`); no host on a hidden or locked
  wall (`opening_host_layer_test`).
- [ ] Mutants: **M-LP-16** (symbol; parametric — one tool suffices, the
  report says which), **M-LP-20**, **M-LP-25**.
- [ ] Commit `feat(app): tools draw on the current layer`.

### Task 9: App — `LayerPanel` (spec D9, D10, D11)

- [ ] `lib/layers/layer_panel.dart` and `layer_row.dart` per spec D9;
  placement in `main.dart`'s right column between `SelectionPanel` and
  `Expanded(PagePanel)`; keys `layers-panel`, `layer-row-<hex>`,
  `layer-eye-<hex>`, `layer-lock-<hex>`, `layer-current-<hex>`,
  `layer-colour-<hex>`, `layer-name-<hex>`, `layers-add`, `layers-delete`.
- [ ] The rename field reuses the symbol search's shortcut guard pattern;
  emptiness (`layerIsEmpty`) only for the selected row.
- [ ] Tests (`layer_panel_test`): each control is one command (undo stack
  length), dirty, undo restores, the list follows undo and open; disabled
  states (hide on the effective current layer, current mark on a hidden
  layer, delete on non-empty / 0 / current); showing on a hidden effective
  current layer 0 enabled (S-6); rename on Enter, Esc, focus loss
  (invalid ⇒ nothing), the reason shown, no shortcut while typing; + names
  `Layer N`; order (D10); read-only dispatches nothing.
- [ ] Mutants: **M-12a**, **M-LP-18**, **M-LP-26**.
- [ ] Web build. Commit `feat(app): the Layers panel`.

### Task 10: App — `LayerPicker` (spec D12)

- [ ] `lib/layers/layer_picker.dart`; `SelectionPanel` renders it for a
  non-empty selection whenever no tool-settings section shows, including
  where it returns `SizedBox.shrink()` today.
- [ ] Per-key mapping of spec D12 (entity; region both directions, every
  fill; instance; ATTRIB → its instance; parametric object; plain group
  disables); no-ops skipped; one command or one compound.
- [ ] Tests (`layer_picker_test`): shown for a line-only selection; a mixed
  selection (line, region picked on its fill, symbol, wall) in one undo
  step with both region records moved; "Mixed"; all-no-op dispatches
  nothing; moving to a hidden layer empties the selection; read-only
  disabled.
- [ ] Mutants: **M-LP-5**, **M-LP-17**.
- [ ] Web build. Commit `feat(app): move the selection to a layer`.

### Task 11: End to end, sweep, results, the ledger (spec Exit gate)

- [ ] `layers_end_to_end_test.dart`: `FloorPlannerApp` with fake files; make
  a layer, make it current, draw a line and a wall, hide the layer (both
  vanish from the painted frame), show it, move the wall to layer 0, Save,
  Open, Save: byte-identical, the current layer and every layer kept.
- [ ] P-10: the mutant table; the final review re-fires a sample on the
  tip.
- [ ] The two allocation invariant tests unedited (empty diff); no
  `analysis_options.yaml`; no golden PNG changed and the golden tag at
  exactly the 7 standing failures.
- [ ] `docs/superpowers/notes/2026-10-01-plan-12b-results.md` (13's form):
  gates, the mutant table, risks seen, found-not-fixed (at least the
  ATTRIB style residual and the definition-leaf residual), and **the
  human's look list** copied from the spec (nothing marked done for them);
  "Amended at execution (Plan 12b)" in the spec if anything moved; roadmap
  12 and 00 status.
- [ ] The final whole-branch review (separate detached worktree), its
  fixes, then the ledger archive to
  `docs/superpowers/ledgers/2026-10-01-plan-12b/` with a README row, as
  the branch's last commit.
- [ ] All gates + web. Commits `test(app): layers end to end`,
  `docs: plan 12b results`, `docs: archive the plan 12b ledger`.

## Mutant ownership

| Task | Mutants |
|---|---|
| 1 | M-LP-12, M-LP-13, M-LP-21, `layerNameError` branches |
| 2 | M-LP-7, M-LP-8, M-LP-9, M-LP-10 (×3) |
| 3 | M-LP-1, M-LP-2, M-LP-14 (pick, snap, band, recursion), M-LP-23, M-LP-24 |
| 5 | M-LP-3, M-LP-4 (×2), M-LP-6, M-LP-11 |
| 6 | M-LP-14 (outline), M-LP-15, M-LP-22 |
| 7 | M-LP-16 (drafting), M-LP-19, M-12e |
| 8 | M-LP-16 (symbol, parametric), M-LP-20, M-LP-25 |
| 9 | M-12a, M-LP-18, M-LP-26 |
| 10 | M-LP-5, M-LP-17 |

## Exit gate (12b)

- Engine, render and app green (the engine's 2 and render's 7 standing
  failures exactly as at the branch point, no new one; no golden PNG
  changed); analyze and format clean; `flutter build web --release` builds;
  `dev_harness_2d` analyze green; the two allocation invariant tests
  unedited and green.
- Every named mutant fired red (any equivalent one recorded by
  experiment), re-fired by the reviewer; the final review's sample on the
  tip.
- **The human's look on macOS and web**, the spec's list; never marked done
  for the human.
- Merge on the human's word, `--no-ff`, from the main checkout; STATUS
  through a small docs branch merged `--no-ff`; `main` pushed; worktrees and
  local branches removed; merged remote branches named for the human.
