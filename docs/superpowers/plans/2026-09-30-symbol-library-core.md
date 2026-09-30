# The symbol library, slice 09a (the core) — implementation plan

> **For agentic workers:** executed task by task, subagent-driven: a fresh
> implementer per task and an independent reviewer per task, then a final
> whole-branch review. Steps use checkbox (`- [ ]`) syntax.

**Goal:** a generated furniture library ships as `assets/library/
furniture.jetlib`; a typed `SymbolLibrary` loads and validates it;
`placeSymbol` returns one undoable command that copies a symbol's definition
into a document on first use and adds an instance at a chosen point, quarter
turn and mirror; the engine gains the two commands that make that undoable.
Headless: no palette, no tool (that is 09b).

**Spec:** [docs/superpowers/specs/2026-09-30-symbol-library-design.md](../specs/2026-09-30-symbol-library-design.md),
**revision 3** (`82b10bd`). Read it whole before Task 1. It has 14 decisions
(D1–D14), 5 rulings (R-1–R-5), 14 facts (F-1–F-14), mutants M-09a … M-09x
(M-09g and M-09p recorded equivalent) and no open question. It was reviewed
independently twice (V-1–V-11, R-1–R-3). **The human approved it on
2026-09-30** ("onaylıyorum. devam edelim."). The human's decisions 1–12 are
at its top.

**Slicing.** This plan is **09a**. D8 (search), D9 (gallery, thumbnails),
D11 (placement tool) and D12 (panel) are **09b**, with their own plan after
09a merges; nothing here builds them, and nothing here may preclude them.

**Architecture:**
- **Engine** (`packages/jet_cad_2d`): `AddDefinitionCommand`,
  `RemoveDefinitionCommand` (D4). Task 1; frozen after it.
- **Render layer** (`packages/jet_cad_2d_flutter`): **untouched**, except a
  test-only end-to-end in Task 6 (it may add a test, never lib code unless
  the ruling below says so).
- **App** (`apps/floor_planner`): `lib/symbols/` — `symbol_component.dart`,
  `symbol_library.dart`, `symbol_placer.dart`, `furniture_catalog.dart`,
  `build_library.dart`; `tool/generate_furniture_library.dart`;
  `assets/library/furniture.jetlib`; `registerAppComponents` gains the
  component.

**Tech stack:** Dart, Flutter 3.47.2 (`/root/flutter`); `package:test`,
`flutter_test`. **No new dependency.** The asset is declared in the app's
`pubspec.yaml` (`flutter: assets:`).

## Rulings made here rather than left to an implementer

- **P-1 (branch).** `plan-09/symbol-library-core`, cut from
  `spec-09/symbol-library` at the commit that adds this plan; worktree
  `.claude/worktrees/plan-09`. Reviews in detached worktrees
  (`.claude/worktrees/plan-09-review`). Merge is the human's (`--no-ff`),
  from the main checkout. Reviewed commits are pushed to
  `origin/plan-09/symbol-library-core`. The git proxy refuses remote branch
  deletion: name the merged branches for the human to delete.
- **P-2 (extension and content).** `.jetlib`, generated from Dart, about 24
  symbols in six categories (spec D7); the exact list is fixed in Task 5
  and recorded in the results note.
- **P-3 (where a lookup lives).** `placeSymbol` finds an existing definition
  through `doc.components.withComponent<SymbolComponent>()` (spec D6 step 1).
- **P-4 (fixtures).** Every fixture avoids the three degenerate cases:
  `basePoint` off the origin, an instance at a rotated, mirrored, off-origin
  placement, style overrides unequal to the defaults (a concrete colour and a
  lineweight that are not the instance defaults). A test is owed a named
  mutant that turns it red; the implementer fires it and the reviewer fires it
  again.
- **P-5 (what a mutant may cost).** Mutants `cp` a backup to the agent's
  scratch prefix, mutate one line, run the named test file, `cp` back and
  `diff` exits 0. Never `git checkout --` a `.dart` file.
- **P-6 (unknowns the spec left to the plan, each to be recorded in the
  results note):** how `DraftDocument.purge` treats a component on a
  definition (Task 2); whether the Select tool's rotation grip works on an
  `InstanceNode` (Task 6); what `validate()` reports on a saved plan with
  symbols (Task 4).

## Global constraints

- CLAUDE.md's non-negotiables. Frame path untouched (nothing here runs per
  frame; the two allocation invariant tests stay **unedited** and green).
- `CI=true` on every test command; `export PATH=/root/flutter/bin:$PATH`.
- Pure-Dart files stay pure: nothing under `lib/symbols/` in 09a imports
  Flutter or `dart:io`; the asset is read through `dart:io` **only** in tests and the
  generator tool, and through `rootBundle` only in 09b.
- Never commit `analysis_options.yaml`. Never synthesize output.
- Commit trailers:
  ```
  Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
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
```
Plus `CI=true flutter build web --release` in the app from Task 5 on (the
asset is bundled). Branch point (`main` `5022e32`): engine 1,106 + 2 standing
(`test/testing/generate_document_test.dart`); render 974 + 1 skip + 7
standing (text ladders); app 596. Record the counts at the end of each task.

## File structure

| File | Task |
|---|---|
| `packages/jet_cad_2d/lib/src/document/commands.dart`, `lib/jet_cad_2d.dart` (only if an export is needed), `lib/src/index/spatial_index.dart` (class comment only) | 1 |
| `packages/jet_cad_2d/test/document/definition_commands_test.dart` (new) | 1 |
| `apps/floor_planner/lib/symbols/symbol_component.dart` (new), `parametric/catalog.dart` | 2 |
| `apps/floor_planner/test/symbols/symbol_component_test.dart` (new) | 2 |
| `apps/floor_planner/lib/symbols/symbol_library.dart` (new) | 3 |
| `apps/floor_planner/test/symbols/symbol_library_test.dart`, `test/support/symbol_fixtures.dart` (new) | 3 |
| `apps/floor_planner/lib/symbols/symbol_placer.dart` (new) | 4 |
| `apps/floor_planner/test/symbols/symbol_placer_test.dart` (new) | 4 |
| `apps/floor_planner/lib/symbols/{furniture_catalog,build_library}.dart`, `tool/generate_furniture_library.dart`, `assets/library/furniture.jetlib` (new), `pubspec.yaml` | 5 |
| `apps/floor_planner/test/symbols/furniture_library_test.dart` (new) | 5 |
| `apps/floor_planner/test/symbols/symbol_end_to_end_test.dart` (new) | 6 |
| `docs/superpowers/notes/2026-09-30-plan-09a-results.md` (new), spec amendments, `roadmap/09-symbol-library.md`, `roadmap/00-README.md`, the ledger archive | 7 |

---

### Task 1: Engine — the definition commands (spec D4, R-1)

**Files:** `commands.dart`; the class comment of `SpatialIndex` (lines
128-136, which says a definition command "removes this caveat"); new
`test/document/definition_commands_test.dart`.

- [ ] `AddDefinitionCommand(Definition)`, `Capability.structure`, label
  `Add definition`. `apply`: throws `DuplicateHandleError` if the handle names
  a definition (`tree.definition`), a node (`tree[h]`) or an entity
  (`entities.containsHandle`); throws `ArgumentError` if `children` is not
  empty; `tree.addDefinition`, `handleSeed.raiseTo`, `invalidateDerived`;
  `CommandResult(inverse: RemoveDefinitionCommand(h), touched: {h})`.
- [ ] `RemoveDefinitionCommand(Handle)`, `structure`. `apply`: `StateError`
  if not a definition; `StateError` if any node is an `InstanceNode` of it, any
  node's `parent` is it, or any entity's `owner` is it (use
  `doc.leavesByOwner()`-style reads the target exposes; if `CommandTarget`
  lacks the read, add the narrowest one and say so in the report);
  `tree.removeDefinition`, `invalidateDerived`; inverse
  `AddDefinitionCommand(removed)` (the value read **before** removal).
- [ ] Both atomic: every refusal throws before any mutation (the dispatcher
  pushes no history).
- [ ] Update the `SpatialIndex` class comment: definition commands exist and
  the index learns through `touched` (spec F-13).
- [ ] Tests (definition at a non-origin `basePoint`; real dispatcher; leaves
  off the origin): add, undo, redo (the definition, then absent, then the same
  value); duplicate against a definition, a node and an entity; non-empty
  `children` refused; removal refused while an instance names it and while a
  leaf is owned by it, **allowed once both are gone**, and its undo restores
  the same value; `permissions = readOnly` refuses both; `stateId` moves on
  each; **a pick finds an instance of an added definition with no rebuild
  call**, and after undo finds nothing; the document's extents follow a
  compound of add-definition + add-entity + add-instance and its undo.
- [ ] Mutants (record red test and line for each): **M-09q** (drop the
  "named by" guard), **M-09r** (drop the non-empty-`children` guard; and,
  separately, the definition arm of the duplicate check). **M-09g and M-09p
  are equivalent (spec): do not fire them for red; one sentence each in the
  report confirming by experiment (run the mutant, the suite stays green).**
- [ ] Gates. Commit `feat(engine): undoable definition commands`.

### Task 2: App — `SymbolComponent` and its registration (spec D3, D1)

**Files:** new `lib/symbols/symbol_component.dart`; `parametric/catalog.dart`;
new `test/symbols/symbol_component_test.dart`.

- [ ] `SymbolComponent implements Component`: fields `key`, `name`,
  `category`, `tags` (unmodifiable copy, lower-case is the library's duty, not
  enforced here), `version`; `componentTypeId = 'jetcad.symbol'`;
  `register(ComponentRegistry)`; `fromJson`; `toJson` in fixed key order;
  value `==`/`hashCode` with `tags` compared **in order**. Constructor asserts
  `version >= 1` and non-empty `key` (throw `ArgumentError`, not `assert`).
- [ ] `registerAppComponents` calls `SymbolComponent.register(r)`. Not in
  `parametricCatalog` (spec D1): add no parametric registration.
- [ ] Tests: value equality per field (each field differs once), tag order
  matters, JSON round trip, key order pinned, a document with the component
  on a **definition handle** saves and loads (through
  `registerAppComponents`) with byte-identical re-encoding and a typed
  component; loaded **without** the registration it is preserved verbatim
  (unknown type) and re-encodes identically; a document holding it reports no
  diagnostics and `ParametricSystem.regenerate` (whatever the app calls its
  full pass; read `parametric_system.dart`) leaves it untouched; the
  live-object rule never names it.
- [ ] Record (P-6): what `purge` does to a definition's component. Do not fix
  it unless it loses data a save needs; if it does, stop and report.
- [ ] Mutants: **M-09u** (equality ignores tag order; and `toJson` key order
  swapped); a registration omitted from `registerAppComponents` (the load
  test goes red: the component comes back untyped).
- [ ] Gates. Commit `feat(app): the symbol component`.

### Task 3: App — `SymbolLibrary`, the loader that validates (spec D5)

**Files:** new `lib/symbols/symbol_library.dart`; new
`test/symbols/symbol_library_test.dart`, `test/support/symbol_fixtures.dart`.

- [ ] `final class SymbolEntry { key, name, category, tags, version,
  definition (Definition), leaves (List<({EntityRecord record, GeometryPayload
  payload})>, ascending by handle) }`; `final class SymbolLibrary { entries }`;
  `SymbolLibrary.decode(Uint8List bytes)` (UTF-8 → `DraftDocumentCodec.
  decodeString` with `registerComponents: registerAppComponents`);
  `SymbolLibraryError(message)` naming the key or handle. Entries in
  definition-handle order; categories in first-appearance order (a getter).
- [ ] Validation, each its own throw site so each has its own mutant (spec D5):
  no `SymbolComponent`; duplicate `(key, version)`; a definition whose
  `children` names anything; any node other than the root (instance or
  group); a leaf whose owner is not a definition; kind `text`/`fill`/`attrib`/
  `point`; style off the allow-list (layer `layerZero`; linetype in
  {BYLAYER, BYBLOCK, CONTINUOUS}; text style STANDARD; colour `ByBlockColor` or
  `ByLayerColor`; lineweight and transparency `kByBlock` or `kByLayer`; flags
  0; linetypeScale finite — **including DASHED 6 refused**); degenerate or
  non-finite geometry (coordinate beyond ±1e6, zero-length line, polyline under
  two vertices or a non-finite bulge, radius ≤ 0, zero sweep); non-finite
  `basePoint`.
- [ ] `symbol_fixtures.dart`: a builder that makes a small valid library
  document (two symbols, non-origin `basePoint`s, a line, a polyline, an arc,
  a circle) and a way to break it one rule at a time. A case for the leaf handle
  in `children` uses **hand-built JSON** (the codec strips leaf handles on
  encode; spec V-9).
- [ ] Tests: a valid library lists both entries with every field equal to what
  was built; one rejection case per rule above, each asserting the message
  names the key or handle; draw order: `leaves` ascending by handle.
- [ ] Mutants (**M-09j**, one per rule): delete each rule's throw in turn; the
  named case must go red, and only it (record the matrix).
- [ ] Gates. Commit `feat(app): the symbol library loader`.

### Task 4: App — the placer (spec D6)

**Files:** new `lib/symbols/symbol_placer.dart`; new
`test/symbols/symbol_placer_test.dart`.

- [ ] `Transform2 placementTransform({required Vector2 at, required Vector2
  basePoint, int quarterTurns = 0, bool mirrored = false})` `= translation(at)
  · rotation(q·90°) · scale(mirrored ? -1 : 1, 1) · translation(−basePoint)`
  via `multiply` (the argument applies first); quarter turns use exact cos/sin
  (0, ±1) and every stored matrix component has `-0.0` normalised to `0.0`;
  `quarterTurns` taken modulo 4 (negative allowed).
- [ ] `final class InstanceStyle { color = ByBlockColor(), lineweight = kByBlock,
  transparency = kByBlock, linetype = byBlockLinetype, linetypeScale = 1.0 }` —
  check `InstanceNode`'s own defaults and match them; the placer passes every
  field through.
- [ ] `CompoundCommand placeSymbol(DraftDocument doc, SymbolEntry entry,
  {required Vector2 at, int quarterTurns = 0, bool mirrored = false,
  InstanceStyle style = const InstanceStyle()})`: label `Place <name>`;
  allocates every handle from `doc.handleSeed` at construction; does not
  execute. Find (P-3), else copy (fresh handles for the definition and each
  leaf, allocated in the library's ascending leaf order so handles ascend with
  it; definition name `"$key@$version"`, `#2`, `#3`… while a definition of that
  name exists; `AddDefinitionCommand`, `SetComponentCommand<SymbolComponent>`,
  then one `AddEntityCommand` per leaf, `owner` the new definition), then
  `AddNodeCommand(InstanceNode(… parent: doc.rootHandle, layer:
  ReservedHandles.layerZero, transform: placementTransform(…), style…))`.
- [ ] Tests (P-4 fixtures: a library entry with `basePoint` off the origin;
  `at` off the origin; rotated and mirrored; instance colour and lineweight
  distinct from the defaults):
  - the base point lands on `at`: transform a leaf endpoint (computed
    independently in the test from the local coordinates) and compare within
    `Tolerance`, at quarter turns 0–3, mirrored and not;
  - two placements of one symbol: one definition, two instances, distinct
    handles (`doc.tree.definitions.length`, node count);
  - style fields reach the instance (each field, `==`);
  - undo is one step (`undoDepth` +1), removes instance, leaves, component and
    definition (counts and `validate()` empty), redo restores the same handles;
    dirty follows `stateId`;
  - **cross-document handles**: the target document already holds entities and
    a node at the handles the library's leaves use (library handles ≥ 16 and the
    target's own seed is raised to reach them) → places without
    `DuplicateHandleError` and the target's own entities are untouched;
  - a stored older version (place v1, then a library entry of the same key at
    v2): v1's definition untouched, v2 copied beside it, names distinct, two
    definitions, each instance on its own;
  - a **foreign** definition already named `"$key@$version"` (no component):
    the copy is named `…#2`; a second foreign name → `#3`;
  - quarter-turn matrices exactly 0/±1 and no `-0.0` in the encoded bytes
    (assert on the encoded JSON text);
  - save → load (`registerAppComponents`) byte-identical with instances and
    definitions; `validate()` empty (P-6: record what it reports);
  - draw order: leaves' handles ascend with the library's order; after undo,
    redo and a save/load they still do; handle-distinct fixtures;
  - a denied `components` capability (a permissions set without it) makes the
    whole placement refuse through `execute`, and leaves the document unchanged
    (the handle seed is allowed to have moved).
- [ ] Mutants: **M-09a** (no `translation(−basePoint)`), **M-09b** (copy every
  time), **M-09c** (drop rotation; drop mirror; each), **M-09d** (style not
  passed, per field), **M-09e** (omit `AddDefinitionCommand`), **M-09f**
  (compound lacks the component removal or definition removal on undo: mutate
  the order so undo leaves the definition), **M-09h** (lookup ignores
  `version`), **M-09i** (leaves keep the library's handles), **M-09n**
  (`rotation(rad)` for quarter turns), **M-09o** (leaf handles allocated in
  descending order), **M-09t** (`#2` suffix dropped), **M-09v** (`R·T·S`: the
  fixture has a non-zero turn, an off-origin `at` **and** an off-origin
  `basePoint`), **M-09w** (n/a here: the tool is 09b; note it is owed there).
  Record red test and line for each.
- [ ] Gates. Commit `feat(app): the symbol placer`.

### Task 5: App — the content, the generator, the asset (spec D2, D7)

**Files:** new `lib/symbols/furniture_catalog.dart`, `build_library.dart`,
`tool/generate_furniture_library.dart`, `assets/library/furniture.jetlib`;
`pubspec.yaml` (`flutter: assets: - assets/library/furniture.jetlib`); new
`test/symbols/furniture_library_test.dart`.

- [ ] `furniture_catalog.dart`: each symbol as data (`key`, `name`, `category`,
  `tags` (≥ 2, lower-case), `version: 1`, `basePoint`, a list of shapes: line,
  polyline (open/closed), arc, circle — in **mm**, authored in a corner-origin
  local frame with a `basePoint` at the centre or front-centre, so `basePoint !=
  (0, 0)` for every symbol). About 24 symbols in six categories (spec D7's
  list); realistic dimensions (a double bed 1600×2000, a dining chair 450×450,
  a 4-seat table 1600×900, …); plain outlines, **no text, no fill, no point**.
  Record the final list in the results note.
- [ ] `build_library.dart`: `DraftDocument buildFurnitureLibrary()` — `prepare`
  a document (units mm, `registerAppComponents`; reuse `prepareDocument` but
  **not** the DASHED record, which the allow-list refuses: construct with
  `DraftDocument.empty` + `registerAppComponents` + units if `prepareDocument`
  adds DASHED; say which in the report), then per symbol
  `AddDefinitionCommand`, `SetComponentCommand<SymbolComponent>` and
  `AddEntityCommand`s with handles ascending in catalog order, `owner` the
  definition, style BYBLOCK-friendly and on the allow-list; `clearHistory()`.
  Returns a document whose `encodeToString` is deterministic.
- [ ] `tool/generate_furniture_library.dart`: `dart run` writes
  `utf8.encode(encodeToString(buildFurnitureLibrary()))` to
  `assets/library/furniture.jetlib`. Runs from the app directory.
- [ ] Generate and commit the asset.
- [ ] Tests: the built library's bytes `==` the committed asset's (read with
  `dart:io` in the test); `SymbolLibrary.decode(asset)` succeeds and lists every
  catalog key, each once; every entry's `basePoint != (0, 0)`; every entry has a
  non-empty category and ≥ 2 tags; keys unique and dotted lower-case; every
  entry's leaves non-empty; **each symbol placed into a fresh `prepareDocument`
  at an off-origin point and quarter turn validates and has its transformed
  bounds containing `at`**; building twice gives identical bytes.
- [ ] Mutants: a symbol authored at `basePoint` (0,0) (the origin test goes
  red); a shape of kind `point` or a text leaf added (the loader rejects: the
  decode test goes red); the asset left stale (edit a coordinate in the
  catalog: the bytes test goes red).
- [ ] Gates **plus `CI=true flutter build web --release`**. Commit `feat(app):
  the furniture library`.

### Task 6: The end to end (spec D10, F-7)

**Files:** new `apps/floor_planner/test/symbols/symbol_end_to_end_test.dart`.
No lib change unless a defect is found (see the ruling below).

- [ ] One test, in the app's test style (a recording draw sink or the existing
  painter test harness: read `draft_painter_recursion_test.dart` and
  `draft_painter_test.dart` for the recording sink), on a document from
  `prepareDocument` with the real dispatcher: place a library symbol
  **rotated a quarter turn, mirrored**, at a point far from the origin, with a
  distinct instance colour and lineweight. Assert, in this one test: the
  painter's recorded strokes carry the instance colour and the resolved
  lineweight (and **not** the definition's/default), at the transformed
  positions; a pick at the instance's world position returns the leaf under the
  chain; a snap onto a **named leaf endpoint** whose world position the test
  computes independently (F-12: the insertion point is not a candidate), within
  `Tolerance`; the extents; `validate()` empty; save → load byte-identical.
- [ ] A second case: the Select tool's rotation/move grips on the placed
  instance (P-6): record whether they work on an `InstanceNode`. If they do not,
  **do not fix here**: record it as a found item for 09b.
- [ ] **Ruling P-7 (what a defect here means).** F-7 says nothing has combined
  these before, so this test may find a real engine or render defect. If it
  does, the implementer stops, reports the failing assertion and a minimal
  reproduction, and does **not** patch engine or render code on its own
  initiative: the controller rules (fix in this plan inside the spec's bounds,
  or record and scope). A test that only passes by weakening an assertion is
  not acceptable.
- [ ] Mutants: **M-09c** and **M-09d** at the painter level (mutate the placer's
  transform / style: this test must go red for each independently of Task 4's);
  the snap assertion must go red if the placer ignores `basePoint` (M-09a).
- [ ] Gates. Commit `test(app): a placed symbol through paint, pick, snap and
  the codec`.

### Task 7: Sweep, results and the ledger (spec Exit gate)

- [ ] Re-run every mutant of Tasks 1–6 in the final tree; fill the results
  note's table (id, file:line, red test).
- [ ] The two allocation invariant tests unedited and green (record `git diff
  origin/main -- <those files>` empty).
- [ ] Greps: no `dart:io` or Flutter import in `lib/symbols/` (assert in the
  note); `analysis_options.yaml` not in the diff.
- [ ] Record P-6's three unknowns, Task 6's grip finding and any found items.
- [ ] `docs/superpowers/notes/2026-09-30-plan-09a-results.md` (form of 12a's):
  the branch, the tasks table with reviews, what the execution found that the
  spec did not, the gate numbers (Linux container), the mutant table, **the
  human's look** — 09a has none; the list for 09b is in the spec's Exit gate,
  and nothing is marked done for the human.
- [ ] Spec amendments (a closing "Amended at execution (Plan 09a)" section; it
  rewrites nothing above it); `roadmap/09-symbol-library.md` status;
  `roadmap/00-README.md` status row (plan and results links).
- [ ] Archive the ledger to `docs/superpowers/ledgers/2026-09-30-plan-09a/`
  with a row in its README, as the branch's **last commit**.
- [ ] The final whole-branch review (separate detached worktree) precedes the
  archive; its findings are applied or recorded first.
- [ ] Gates (all three + web build). Commit `docs: plan 09a results`.

## Exit gate (09a)

- Engine, render layer, app: the standing gates green with `CI=true`; engine
  2 and render 7 + 1 skip standing failures unchanged; app `flutter build web
  --release` builds; the two allocation invariant tests unedited and green.
- Every named mutant of 09a fired red (M-09g and M-09p recorded equivalent by
  experiment) and recorded in the results note; the reviewer re-fired them.
- The generated bytes equal the asset; the loader accepts it and every rule
  of D5 has a red case.
- Merge on the human's word, `--no-ff`, from the main checkout; then STATUS
  recorded through a small docs branch merged `--no-ff`, `main` pushed, the
  worktrees and local branches removed, and the merged remote branches named
  for the human to delete (the proxy refuses it).
