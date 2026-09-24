# The parametric layer — design

**Date:** 2026-09-24. **Status:** design, **revision 2**, not yet a plan.
Revision 1 (`dd0251e`) was reviewed the same day by Codex CLI (`gpt-5.5`)
and Copilot CLI. Every finding was re-checked against the tree and is
recorded, with its ruling, in
[2026-09-24-parametric-layer-spec-review-r1.md](../notes/2026-09-24-parametric-layer-spec-review-r1.md).
Revision 2 applies them all. The four blockers:
- **B1: the first box was never wrapped.** The fast path now fires only
  when no parametric component exists *and* the command sets none (D2).
- **B2: a failed plan left the cleanup applied.** The cleanup and the
  regeneration are now one compound, and every failure path is stated (D4).
- **B3: planning burned handles.** Planning now reserves handles without
  advancing the seed (D4).
- **B4: `ParametricEdit.capability` is stateful.** It is now single-use by
  contract (D9).
**Sub-project:** `roadmap/06-parametric-layer.md`. **Size:** L.
**Brainstormed with the human on 2026-09-24**, on `main` at `2565912`,
after a throwaway spike whose findings are the evidence for most decisions
below:
[2026-09-24-parametric-spike-findings.md](../notes/2026-09-24-parametric-spike-findings.md)
(branch `spike/06-parametric`, never merged).
**Depends on:** 02 (merged): the command dispatcher and `CompoundCommand`.
**Blocks:** 07 (walls), 08 (openings), 10 (rooms), 11 (dimensions).

**Decisions the human made on 2026-09-24:**

| Question | Answer |
|---|---|
| Spike first? | Yes |
| Where the proof client lives | Mechanism, plus a small demo in the app |
| A direct edit of a generated line | Refused |
| Selection | A parametric object is one thing |
| Runtime permission | Derived geometry inherits the triggering edit's authority; the component type says which capability its parameter edits need |
| This design | Approved, "spec'i yaz" |

**Evidence of record.** Every claim about what exists was read from the
tree at `48b373c`/`2565912` on 2026-09-24. Each item below gives its file
and line.

- **The dispatcher** (`packages/jet_cad_2d/lib/src/document/undo.dart`):
  - `onAfterMutate` (80) and `onBeforeMutate` (89) are single nullable
    slots. `SpatialIndex` owns both (`spatial_index.dart:164,170`).
  - The render layer deliberately does not take them
    (`draft_canvas.dart:24-31`).
  - `execute` (104) runs these steps in order:
    1. `onBeforeMutate`;
    2. `_checkNotDisposed`;
    3. `_require(command)`, which checks `command.capabilities`;
    4. `apply`;
    5. `push(inverse)`;
    6. emits `CommandApplied(capability: command.capability)`, read
       *after* `apply`;
    7. `onAfterMutate`.
  - `undo` and `redo` call `_require(inverse)` on the stored inverse.
- **`CompoundCommand`** (`commands.dart:743`):
  - its inverse is the children's inverses in reverse order;
  - `capabilities` is the union of the children's;
  - `capability` is the highest-ranked child's (`Capability` declaration
    order, `command.dart:23`);
  - `SpatialIndex` and `TileCache` skip a change whose summary is
    `components` (spec 04 D13).
- **`SetEntityGeometryCommand`** (`commands.dart:452`) keeps the handle and
  the `geomIndex`. `AddEntityCommand` re-adds with the recorded handle.
  **Redo therefore restores the same handles.** The spike verified this in
  its Q2.
- **`ComponentStore.handles`** (`component.dart:43`) is ascending.
  `ComponentRegistry.loadJson` inserts in ascending order.
- **The codec** (`packages/jet_cad_2d/lib/src/codec/json_codec.dart:67-78`):
  - it writes entities in **slot order**;
  - freed slots are reused (`slot_allocator.dart:52`);
  - so the entity order is history, not state.
- **Selection** (`packages/jet_cad_2d_flutter/lib/src/selection.dart`):
  - `resolveHit` (49-64) selects the **topmost `GroupNode`** under the
    root for a hit on any leaf inside it;
  - band select picks a group only when all its leaves are in the band
    (`select_tool.dart:434-508`).
- **Grips** (`grip_cache.dart:264-265`) build only for root-owned leaves.
  A group has none. A group still gets the box and the rotation grip.
- **Move and rotate of a group** go through
  `TransformNodeCommand(t · node.transform)` (`grip_drag.dart:214-217`),
  which needs the `transform` capability.
- **Delete of a group** (`select_tool.dart:654-682`) runs, in order:
  1. `RemoveEntityCommand` for each child leaf;
  2. a recursion into child groups;
  3. `RemoveNodeCommand(group)`.

  All of it is one `CompoundCommand`. It never detaches a component.
- **Draw order** (`draft_painter.dart:316-381`):
  - a group's leaves are drawn among root leaves by their **own** handles,
    with the composed group transform;
  - there is no per-group pass.
- **The app** (`apps/floor_planner/lib`):
  - `main.dart:64-120` holds the tools and the palette entries;
  - V L P R C A T are taken, and **B is free**;
  - `page_panel.dart` is the only panel. It edits the page through
    `SetComponentCommand<PageComponent>` (53);
  - `startup_plan.dart` uses no `GroupNode`;
  - `PlacementTool.commit(ctx, builder)` (`placement_tool.dart:229`) is the
    shared commit path of 05's drawing tools.

## What this delivers

1. **A generic parametric mechanism** in `packages/jet_cad_2d`, pure Dart.
   - A parametric object's **parameters** live in a `Component` on a
     `GroupNode`'s handle.
   - Its **geometry** is ordinary LINE, ARC, POLYLINE and other entities
     owned by that group, **generated** from the parameters.
   - Every edit that changes a parametric object's parameters, placement,
     existence or neighbourhood regenerates the affected objects **inside
     the same undo step**.
   - Undo, redo, save, load, rendering, hit-testing and snapping all keep
     working unchanged.
2. **A small demo client in the app:** `ParametricBox`, a rectangle.
   - Its parameters are `width` and `height`.
   - Where boxes overlap, each loses the part of its outline inside the
     other, so overlapping boxes read as one merged outline. That is the
     wall clean-up preview.
   - A **Box tool** (key **B**) places one.
   - A **Selection section** in the right panel edits one selected box's
     parameters.

## Non-goals

- **Walls, openings, rooms and dimensions:** 07, 08, 10 and 11.
- **Back-solving parameters from a grip drag.** A generated child is not
  editable directly (D6).
- **Parametric objects inside definitions or instances.** A parametric
  group is a **root-level** group. Its children are leaves it owns. A
  nested parametric group is refused at regeneration (D5).
- **A general inspector.** The Selection section edits one box. 12 builds
  the app shell's real panels.
- **Changing the file format.** No schema bump: components, groups and
  entities are all already persisted.
- **A spatial broad phase for neighbour search.** It is O(n²) over
  parametric objects. The spike measured 8.2–8.7 ms for one edit among 200
  objects. A floor plan has a few hundred.

## Decisions

### D1 — Where the mechanism lives (spike)

- **Location.** `packages/jet_cad_2d/lib/src/parametric/`, exported from
  the package. It is a *system that consumes* the document, not part of the
  document. The document stays data only (`component.dart:12`): nothing in
  `document/` imports `parametric/`.
- **Engine additions outside `parametric/`:** one, the dispatcher's
  expander slot (D2).
- **`ParametricSystem`:**
  - it is constructed over a `DraftDocument`;
  - it holds the registered types;
  - `install()` takes the expander slot;
  - `dispose()` releases it, if it is still its own tear-off, the way
    `SpatialIndex.dispose` does (`spatial_index.dart:3010-3019`).

**Amended at execution (Plan 06):** Ruling 06-13 — `ComponentRegistry`
gains `bool isRegistered<T extends Component>()`. `register<T>` replaces
`T`'s store unconditionally, wiping every component of that type
(`component.dart:74`); without this check, a second `ParametricSystem`
constructed over an already-loaded document — which the catalog's own
`registerInto` does on every construction (D3, Ruling 06-1) — would wipe
every live component of a type it re-registers. The catalog now calls
`register<T>` only when `isRegistered<T>()` is false. Pinned by `P10` and
`M-06v`. This is the one addition outside `parametric/` besides the
dispatcher's expander slot (D2).

### D2 — The dispatcher's expander slot (spike: approach A2)

- **The slot.** `CommandDispatcher` gains
  `DraftCommand Function(DraftCommand command)? expander`. `execute` calls
  it after `_checkNotDisposed` and before `_require`:

  ```dart
  final effective = expander?.call(command) ?? command;
  _require(effective);
  final result = effective.apply(target);
  ```

  Everything after that uses `effective`: the history push, the
  `CommandApplied` label, `touched` and `capability`.
- **`undo` and `redo` never call it.** They replay concrete inverses.
- **Why a slot in the dispatcher.** Tools execute through
  `ToolContext.execute`, but the page panel and `startupPlan` call
  `document.commands.execute` directly. Only the dispatcher sees every
  edit.
- **Why not the alternatives:**
  - `onAfterMutate` is taken by the index.
  - Approach B, the second-command pass, gave two undo entries and a stale
    state one keystroke away (spike Q9). Folding it needs a history-merge
    API, a re-entrancy flag and chaining onto the index's slot (spike
    Q10).
- **Contract, documented on the slot:**
  - the expander must be a pure wrapper;
  - it may not mutate;
  - it may return the command unchanged.
- **A slot, not a list.** One `ParametricSystem` per document. A second
  `install()` on the same document throws `StateError`.
- **Fast path.** The expander returns the command itself, with no wrapper
  and no scan, when both hold:
  - the document holds no parametric component;
  - the command, recursing into compounds, contains no
    `SetComponentCommand` whose value type is parametric.

  A plain line edit in a plan with no boxes costs one store-length check.
  The first box's creation is wrapped (review B1).
- **Re-entry is refused.** While a `ParametricEdit` is applying, the
  expander throws `StateError`, and so does any other `execute`. A client's
  `generate` that calls back into the dispatcher fails loudly (review I6).

### D3 — `ParametricType<T>` and what a client provides

```dart
abstract class ParametricType<T extends Component> {
  /// The capability a change of T's value needs (D7). A box: geometry.
  Capability get editCapability;

  /// The world region this object's generation depends on and affects,
  /// from parameters and the group's accumulated transform only.
  Aabb2 reach(T params, Transform2 toWorld);

  /// Phase 2: this object's entities, in the group's local space, from its
  /// own parameters and its neighbours' — never from generated geometry.
  List<Generated> generate(ParametricView view, Handle self);
}

final class Generated {
  const Generated(this.kind, this.payload);
  final EntityKind kind;
  final GeometryPayload payload;
}
```

- **Registration.**
  `system.register<T>(String typeId, ComponentFactory<T>, ParametricType<T>)`
  registers the component with the document's `ComponentRegistry` and the
  type with the system in one call.
- **`ParametricView`** is read-only. It offers:
  - `paramsOf<U>(Handle)`;
  - `toWorld(Handle)`, the accumulated transform;
  - `neighbours(Handle)`: ascending handles of parametric objects whose
    `reach` overlaps this one's by more than `Tolerance.standard.linear`
    on both axes. Touching boxes are not neighbours.
- **Generated entities** carry D2 of spec 05's defaults: `draftRecord`
  with the group as owner.
- **`Generated` refuses `EntityKind.fill`** with `ArgumentError`:
  `SetEntityGeometryCommand` rejects a fill's payload, and regions are out
  of scope (review m4).

**Amended at execution (Plan 06):** Ruling 06-1 — types live in a
document-free `ParametricCatalog`, not on `ParametricSystem` as first
written. `DraftDocumentCodec.decode` creates the document and needs the
component factories *before* it loads components
(`json_codec.dart:115`), so a per-document `ParametricSystem` cannot exist
yet at that point. `catalog.register<T>(typeId, factory, type)` adds one
type; `catalog.registerComponents` is the function every decode passes as
`registerComponents:` (D10); `ParametricSystem(document, catalog)`
registers the catalog's components into that document (subject to Ruling
06-13's `isRegistered` check) and reads its types from it. Cost: one
indirection.

### D4 — Regeneration: two-phase, parameters only, sorted (spike)

The wrapper `ParametricEdit(inner)` does this in `apply`:

1. **Before.** Snapshot:
   - the neighbour map;
   - the set `G` of every entity owned by a live parametric group.

   Both come from one scan of the entities (an owner→children map) plus
   the parametric handles.
2. **Apply `inner`.** It yields `r`.
3. **Guard** (D6). If `inner` edited a generated child, apply `r.inverse`
   and throw. Nothing has been planned or reserved yet.
4. **Clean up** (D8). Every parametric component whose group node no longer
   exists gets a `SetComponentCommand<T>(h, null)`. This step is
   **unconditional**: it runs for any command that removes such a node,
   not only the select tool's delete (review m2). These commands are
   planned here and applied in step 8.
5. **Seeds.** Each handle in `r.touched` that is:
   - a parametric group; or
   - a child in `G`; or
   - a group that just lost its node (from step 4).
6. **Closure.** The seeds, the seeds' neighbours before, and the seeds'
   neighbours after, **as a sorted list of live parametric groups**.
   - Neighbours are one hop. Generation reads neighbours' parameters,
     never their geometry, so a neighbour's neighbour cannot change.
   - This is what makes a mutual dependency terminate with no iteration.
     **M-06e is vacuous by construction**, and that is recorded, not
     tested.
7. **Plan.** For each object in the closure, ascending:
   - call `generate`;
   - match its output to the existing children **by `(kind, ordinal)`**:
     the i-th generated LINE goes to the i-th existing LINE child in
     ascending handle order;
   - a match whose payload differs becomes `SetEntityGeometryCommand`;
   - an equal payload becomes nothing (exact `==` on the stored doubles);
   - a surplus child becomes `RemoveEntityCommand`;
   - a missing child becomes `AddEntityCommand` with a **reserved**
     handle: `handleSeed.current + 1`, `+ 2`, and so on, **without
     advancing the seed**. `AddEntityCommand.apply` raises the seed when
     the add actually lands (`commands.dart:58`). A plan that is never
     applied costs no handle (review B3).

   Handles are reserved in closure order, so the walk **must sort
   itself**. It must not rely on `ComponentStore.handles` (spike finding
   4, M-06b′).

   **A changed payload is always `SetEntityGeometryCommand`, never remove
   plus add.** That keeps the child's slot, and the codec writes entities in
   slot order, so the raw bytes of "same state plus same edit" depend on it
   (D11, M-06p).
8. **Apply** the cleanup commands followed by the regeneration plan as
   **one** `CompoundCommand`, giving `g`. It is all-or-nothing through
   `CompoundCommand`'s own rollback. A throw during planning (step 7, for
   example from a client's `generate`) happens before anything but `r` has
   applied: apply `r.inverse` and rethrow. On failure of `g`:
   - `g` rolled itself back: apply `r.inverse`, then rethrow `g`'s error;
   - `g` threw its own "partially mutated" `StateError`
     (`commands.dart:776-788`): rethrow it as is; `r.inverse` is **not**
     layered onto a target in an unknown state;
   - `r.inverse` throws: throw a `StateError` naming both failures, the
     same escalation `CompoundCommand` uses.

   In every failure case the dispatcher pushes nothing and emits nothing. A
   reserved add that applied before the failure leaves the seed raised, as
   any engine `CompoundCommand` rollback does today (review B3).
9. **Return** `CommandResult(inverse: ParametricReplay(Compound([g.inverse,
   r.inverse]), capabilities: this.capabilities), touched: r ∪ g)`.

**Amended at execution (Plan 06):**

- **Step 4, ruling 06-3.** "Every parametric component whose group node no
  longer exists" is narrowed to components of objects that were **live
  before the edit**. Taken literally, the step would also detach a
  *misplaced* component on a leaf handle (D5) on every edit — a leaf has no
  tree node either, so it would always read as "gone". Cost if wrong: a
  misplaced component survives a delete; it is already reported by
  `diagnostics()`.
- **Step 5, ruling 06-4.** A touched handle that *was* an object is a seed
  too, not only one that still is. An explicit
  `SetComponentCommand<T>(h, null)` turns a box back into a plain group, and
  its old neighbours must regrow — so both `before.objects` handles and
  `after.objects` handles seed the closure.
- **Step 8, review-found hardening (P11, M-06w).** The after-survey
  (`after = _survey(...)`), the `lost` list, `cleanup` and `seeds` are
  computed **inside** the same `try` that guards step 7's planning, not
  ahead of it. A `reach` that throws while surveying the *new* parameters
  (a live possibility: `reach` is client code, D3) must roll `r` back the
  same way a throwing `generate` does — spec text ("in every failure case
  the dispatcher pushes nothing") already required this; moving these
  computations outside the `try` was a review-found gap, not a design
  change. Killed by `M-06w`.

Both mutants, `M-06w` (this hardening) and `M-06x` (D6's, below), were
added to the mutant table by the fix round that closed them, and are fired
in the mutation log alongside the spec's own M-06a…M-06t.

**What undo and redo replay.** They replay `ParametricReplay`, a concrete
compound. They never regenerate. The spike's Q2 showed the handles and the
bytes restored. `ParametricReplay.apply` returns, as its own inverse,
another `ParametricReplay` with the **same capability set**, so redo is
authorised exactly as undo was (review I8).

**If nothing parametric is touched** (no seeds and no cleanup), the wrapper
returns `r` unchanged. A non-parametric edit is byte-for-byte the command it
was, and its inverse is the plain inverse.

### D5 — What is parametric

- **A parametric object is a `GroupNode` whose parent is the root and whose
  handle carries a registered parametric component.**
- **Anything else carrying such a component is not regenerated.** That
  covers a component on a leaf, on a nested group or on an instance.
  `ParametricSystem.diagnostics()` reports each one (D10). The engine's
  `validate()` cannot: it does not know which component types are
  parametric.

### D6 — Generated geometry is not directly editable (human: refuse)

- **The rule.** After `inner` applies, the command is refused if any handle
  in `r.touched ∩ G`:
  - still exists; or
  - was removed while its owning group still exists.

  The wrapper applies `r.inverse` and throws
  `GeneratedGeometryError(handle)`. The dispatcher pushes nothing and emits
  nothing.
- **What stays allowed:** a group removed together with its children.
- **What is refused besides a direct edit:** adding a new entity owned by a
  parametric group. It is caught by the same after-check: an entity in
  `r.touched` that is not in `G` but whose owner is a live parametric
  group.
- **The UI never offers these edits:**
  - a parametric group has no leaf grips (`grip_cache.dart:264`);
  - its children are not individually selectable (`resolveHit`).

  So the guard is the engine-level backstop that a future tool cannot
  bypass.

**Amended at execution (Plan 06):** the guard is tightened to the spec text
above — a touched handle in `G` is refused if it **still exists**, whatever
its owner now is, not only while its owner is still a live parametric
object. The looser rule (refuse only while the owner is still "an object")
let a bundled command detach a box's component and then, in the same
compound, directly edit one of its still-live generated children, sidestepping
the backstop. The reviewer graded the original gap Minor; the controller
ruled the spec binding and required the fix, since a compound that detaches
an owner and edits its old child in one command must still be refused. Cost
if wrong: such a compound is refused even though no tool in this plan issues
one. Killed by `P12`, mutant `M-06x` (dropping the "still exists" check from
the `owner != null` arm, leaving only the "is a live object" check).

### D7 — Permissions: derived geometry inherits (human)

- **The wrapper's `capabilities`, checked by `_require` before `apply`:**
  - `inner.capabilities`;
  - plus `type.editCapability` for every `SetComponentCommand` in `inner`,
    recursing into compounds, whose component type is parametric.

  Regeneration adds no capability of its own. The edit that caused it
  authorises it.
- **Consequences:**
  - A box declares `editCapability = geometry`: a runtime user cannot
    resize a box.
  - A future type, such as a table's seat count, can declare `components`.
  - A move of a box under runtime (`transform`) regenerates its
    neighbours' geometry. That is allowed, since the move authorises it.
- **`ParametricReplay`, the inverse, carries the same capability set**, and
  so does its own inverse, for redo. The concrete inverse alone would demand
  `geometry` because it holds `SetEntityGeometryCommand`s, and a runtime
  user could then **not undo their own edit**. The spike did not test undo
  under runtime; this is a design catch. It is killed by M-06i, for undo
  and for redo.
- **A delete under runtime.** Delete needs `structure` and `geometry`,
  which runtime denies, so it is refused at `_require` before anything
  happens. A permitted delete's undo needs exactly the set the delete
  needed, because the inverse carries the wrapper's own set (review I8).

### D8 — Deleting a parametric object

- **Existing behaviour.** The select tool's delete cascade removes the
  children and then the node (`select_tool.dart:654-682`).
- **What the wrapper adds (step 4).** For each parametric group handle
  whose node is gone but whose component remains, it plans
  `SetComponentCommand<T>(h, null)`, applied in step 8's compound. The
  type-specific closure comes from the registration.
- **Undo** restores the component, the node, the children and the
  neighbours' geometry, all through the concrete inverse.
- **Neighbours regrow** because the removed group is a seed: its
  before-neighbours are in the closure.

### D9 — The capability summary must say geometry changed

- **The rule.** `ParametricEdit.capability`, read by the dispatcher *after*
  `apply`, is the highest of:
  - `inner.capability`;
  - `geometry`, if the plan was non-empty.
- **Why it matters.** A width edit is a `SetComponentCommand`, which on its
  own summarises as `components`. The index and the tile cache skip a
  `components` change (04 D13). The regenerated children would then be
  drawn and hit-tested from stale boxes. That is killed by M-06h.
- **`ParametricReplay.capability`** is its compound's summary, and so is
  `geometry` whenever geometry was replayed.
- **`ParametricEdit` is single-use** (review B4). Every other command's
  `capability` is a function of its constructor state. This one depends on
  its `apply`, and that is contained by contract:
  - the expander creates one per `execute`;
  - the dispatcher reads `capability` once, after `apply`, as it already
    does (`undo.dart:113-119`);
  - history never holds a `ParametricEdit`, only its `ParametricReplay`
    inverse;
  - a second `apply` of the same instance throws `StateError`.

### D10 — Load, and drift

- **On load, geometry is trusted.** The file is the truth. Regenerating on
  load changed nothing in the spike (Q4). The M-06f probe was answered:
  generation is a pure function of saved doubles, and doubles round-trip
  exactly.
- **Typed components need registration first.** Components come back typed
  only if their factory is registered before `loadJson` runs
  (`json_codec.dart:115`); otherwise they are kept as unknown payloads.
  `ParametricSystem.registerComponents(ComponentRegistry)` is the function
  every decode passes as `registerComponents:`. The app has no open path
  yet, so the round-trip tests decode with it (review I2).
- **`ParametricSystem.drift()`** returns the handles whose regeneration
  would change anything: a dry-run plan over every parametric object.
- **`ParametricSystem.diagnostics()`** returns one `Diagnostic` per
  parametric component on a non-parametric holder (D5). The app runs
  `drift()` and `diagnostics()` in a test over the sample document.
- **The codec needs no change.** Unknown components are already preserved
  verbatim.

**Amended at execution (Plan 06):** Ruling 06-1 — `registerComponents` is
`ParametricCatalog.registerComponents`, not a `ParametricSystem` method
(D3's amendment gives the reason: the document does not exist yet when the
codec needs the factories). A test decoding with it, then constructing a
`ParametricSystem(document, catalog)` over the freshly-loaded document, is
safe only because of Ruling 06-13's `isRegistered` guard — otherwise the
system's own construction would re-register every type and wipe the
components `decode` just loaded.

### D11 — Determinism and byte identity (spike finding 3)

Restated from the roadmap, which asked for byte-identical output from "two
insertion orders". That is unattainable and not wanted: handles are history,
and the spike's Q6 showed creation order changing child handles. This spec
requires instead:

- **Load → save** is byte-identical.
- **The same document state plus the same edit gives the same bytes**,
  whatever the in-memory insertion order of the component store. The spike's
  Q5b shape applies: a document and its reload, with an edit that makes two
  neighbours gain children at once. Killed by M-06b.
- **Two seeds in one command give the same bytes in either child order.**
  One compound moves boxes A and B, `[A, B]` or `[B, A]`, and each gains
  children. Killed by M-06b′, the planner's sort alone (review I5).
- **Raw bytes survive because slots do.** A changed payload is rewritten in
  place (D4 step 7), so no slot is freed and reused. Killed by M-06p
  (review I9).
- **Per-object world geometry** is independent of creation order.
- **Undo then redo** restores the post-edit state. It is compared in a
  canonical form (entities sorted by handle), because freed-slot reuse makes
  raw entity order history-dependent. Raw bytes are also recorded.

### D12 — Draw order

- **The rule.** Children keep their handles across regeneration (D4 step
  7), so an unchanged object's draw order never moves.
- **The accepted cost.** A child *added* by a later regeneration takes a
  fresh, higher handle and draws above older content (spike Q6). A box's
  outline is lines on layer 0, so nothing visible depends on it.
- **Recorded for 07.** Walls with fills may need a per-object draw pass.
  This spec does not add one.

### D13 — The demo: `ParametricBox`, the Box tool and the Selection section (human)

- **Files:** in `apps/floor_planner/lib/parametric/`:
  - `box.dart`: `BoxParams` and `BoxType`;
  - `box_tool.dart`.
- **`BoxParams`:**
  - fields: `width` and `height`, doubles, both > 0;
  - `toJson` key order: `width`, `height`;
  - value-equal;
  - `typeId` is `floor_planner.box`.
- **`BoxType`:**
  - `editCapability = geometry`;
  - `reach` is the world AABB of the four transformed corners;
  - `generate` produces four LINEs `(0,0)→(w,0)→(w,h)→(0,h)→(0,0)`, each
    minus its parameter interval strictly inside each neighbour's rectangle
    (transformed into this group's local space), in edge order, then
    ascending `t`. This is the spike's `generate`, with `Tolerance` for the
    inside test and the minimum piece length.
- **The Box tool, B:**
  - a `PlacementTool` with two clicks, like `RectangleTool`, world-axis
    aligned;
  - it commits
    `Compound([AddNodeCommand(group at translation(min corner)),
    SetComponentCommand(BoxParams(|dx|, |dy|))])` through `commit(ctx, …)`;
  - **`PlacementTool.commit` gains an optional `Set<Capability> needs`**,
    default `{geometry}`, so 05's tools are unchanged. The Box tool passes
    `{structure, components, geometry}`, checked before the group's handle
    is allocated (review I1);
  - the expander regenerates it;
  - Fill does not apply;
  - B joins `kShellLetterKeys` and the palette.
- **The Selection section** sits in the right panel, above the page
  section:
  - it shows only when exactly one selected key is a root-level group
    carrying `BoxParams`;
  - it has two numeric fields, **Width** and **Height**, in mm;
  - Enter or focus-out commits one `SetComponentCommand<BoxParams>`, which
    is one undo step;
  - a value ≤ 0 or unparseable is rejected, and the field reverts;
  - under runtime permissions the fields are read-only (`editCapability`);
  - it is guarded like the page panel's fields: `shortcut_guard.dart`, so
    typing "B" in a field does not switch tools.
- **Startup plan:** unchanged, and it holds no parametric object. The look
  starts from an empty spot and draws boxes.
- **`GeneratedGeometryError`** propagates like `PermissionDeniedError`.
  The UI never offers the edit, so nothing catches it (review m5).

## Architecture

### Files

- **The engine, `packages/jet_cad_2d`:**
  - `lib/src/document/undo.dart`: the `expander` slot (D2);
  - `lib/src/parametric/parametric_system.dart`:
    - `ParametricSystem`, `ParametricType`, `Generated`, `ParametricView`;
    - `ParametricEdit`, `ParametricReplay`;
    - `GeneratedGeometryError`;
  - `lib/src/parametric/regeneration.dart`: the planner (D4 steps 5–7),
    `drift()` and `diagnostics()`;
  - `lib/jet_cad_2d.dart`: exports;
  - `test/parametric/`: tests with a test-only rectangle client that has
    the spike's shape, including the mutual-clip fixture.
- **The render layer:** one change, the optional `needs` set on
  `PlacementTool.commit` (`lib/src/draw/placement_tool.dart`, review I1).
  Group selection, move, rotate and the delete cascade already work; the
  expander makes them regenerate.
- **The app, `apps/floor_planner`:**
  - `lib/parametric/box.dart` and `lib/parametric/box_tool.dart`;
  - `lib/selection_panel.dart`;
  - `lib/main.dart`: build and install the system right after
    `startupPlan` returns, before any tool can run. `startupPlan` builds and
    fills its own document and creates no parametric object, so installing
    after it is safe; the sample-plan test pins that (review I3). Add the
    palette entry and the key, and lay out the panel;
  - `lib/shortcut_guard.dart`: add B;
  - `test/`: box, tool and panel tests.

### Invariants

- **The frame path allocates nothing new.** Regeneration runs on edits only.
  `query_allocation_test.dart` and `paint_allocation_test.dart` stay green,
  unchanged.
- **Draw order is ascending handle value**, unchanged (D12).
- **Geometric decisions use `Tolerance`:**
  - inside tests;
  - minimum piece length;
  - reach overlap.

  **Stored-value comparisons are exact:** the D4 step 7 payload comparison,
  and component equality.
- **No query walk is open during a regeneration.** It reads the tree and the
  component stores, never the index. A regeneration triggered from inside a
  query visitor fails with `QueryReentrancyError` before anything mutates,
  as any edit does.

## Testing

The testing bar is CLAUDE.md's: a test lands only if a named mutant turns it
red. Fixtures sit at non-identity, non-origin transforms, and every
relational fixture is **rotated**: translation alone would let a transposed
local transform survive (review I7, M-06o). Every relational
test uses **two or more objects that clip each other**, and asserts the
clipped child counts (5 and 3 in the spike's pair), so the fixture cannot
silently stop overlapping. The spike's first fixture did exactly that.

**Amended at execution (Plan 06):** `G3` and `G6` compare state with the
root's child order **normalised**, and `G3` without `handleSeed` (Task 4's
ruling). This is pre-existing engine behaviour, not a Plan 06 defect:
`RemoveNodeCommand`'s inverse re-links a removed node at the **end** of its
parent's children (`tree.dart`, `_link`), and `HandleSeed` never moves back
on undo. A rolled-back or undone delete is therefore state-equal, not
byte-equal, and this spec's earlier "bytes unchanged" wording for `G6`
overstated what the engine can give. Cost if wrong: a real ordering
regression in a rollback would hide behind the normalisation; the
component, node, entity and geometry assertions in `G3`/`G6` still stand on
their own.

### Named mutants

| Mutant | What it breaks | Must be killed by |
|---|---|---|
| M-06a | `CompoundCommand` inverse in forward order | the engine's existing `compound_command_test.dart`. It is not reachable from this design's compounds (spike finding 6); recorded as covered there |
| M-06b | the planner walks the closure unsorted **and** `ComponentStore.handles` is unsorted (both, since either sort alone suffices) | D11's two-neighbours determinism test |
| M-06b′ | the planner walks the closure unsorted, the store still sorted | D11's two-seeds test: one compound moves A and B, in both child orders, same bytes |
| M-06c | the wrapper returns `r` and drops `g` from the inverse | one-undo-step test: undo restores parameters **and** geometry |
| M-06d | the closure is the seeds only | the neighbour-changes test, and the move-away-restores test |
| M-06e | — | N/A by construction (D4 step 6), recorded |
| M-06f | regenerate on load | **a probe, not a kill** (review I4): with it fired, load then `drift()` stays empty. The load decision is pinned instead by a file saved with deliberately stale geometry: load keeps it byte for byte, and `drift()` reports its handle |
| M-06g | the group transform is dropped in `reach` and in the local transform | the two-object relation tests. **An isolated object cannot kill it** (spike finding 5) |
| M-06h | `ParametricEdit.capability` returns `inner.capability` | a width edit with a live `SpatialIndex`: a hit test at a new child's midpoint finds it |
| M-06i | `ParametricReplay.capabilities` is the concrete compound's, or its own inverse is a bare compound | undo **and then redo** of a component-capability edit under a runtime-like permission set both succeed |
| M-06j | the D6 guard is skipped | `SetEntityGeometryCommand` on a generated child throws `GeneratedGeometryError`, and bytes and undo depth are unchanged |
| M-06k | the D8 component detach is skipped | delete a box: its component is gone, and undo brings it back |
| M-06l | old neighbours are left out of the closure (only after) | moving A off B restores B's full outline |
| M-06m | children are matched by ordinal ignoring kind | a test type that generates a LINE and an ARC and swaps their order between two parameter values |
| M-06n | the expander is called in `undo` too | undo of a width edit: the undo depth and redo stack behave, and no new handles are allocated |
| M-06o | `toLocal` is the forward transform, not its inverse | the rotated two-object relation tests |
| M-06p | a changed payload is planned as remove plus add | D11's same-state-same-edit test compares **raw** bytes, with a child whose slot otherwise stays put |
| M-06q | the fast path ignores the command's own parametric `SetComponentCommand` | the first box in an empty document gets four children |
| M-06r | the cleanup is applied at step 4, on its own, outside `g` (revision 1's shape) | a test client whose `generate` throws when a neighbour is deleted: after the refused delete, the bytes are unchanged and the deleted box's component is still attached |
| M-06s | the re-entry guard is removed | a test client whose `generate` calls `execute` gets `StateError`, and history is unchanged |
| M-06t | planning advances `handleSeed` | a refused plan (a throwing `generate`) leaves `handleSeed` unchanged |

**Amended at execution (Plan 06):** five additions and clarifications, all
recorded in [plan-06-mutation-log.md](../notes/plan-06-mutation-log.md):

- **M-06u (Ruling 06-10):** `PlacementTool.commit` ignores its own `needs`
  argument (D13), checking only `Capability.geometry`. Killed by `CN1`
  (Task 5).
- **M-06v (Ruling 06-13):** `_Registration.registerInto` re-registers a type
  unconditionally, wiping an already-loaded store. Killed by `P10`.
- **M-06w (D4 step 8's amendment above):** the after-survey, `lost`,
  `cleanup` and `seeds` are computed outside step 7's rollback `try`. Killed
  by `P11`.
- **M-06x (D6's amendment above):** the D6 guard refuses a touched generated
  child only while its owner is still a live parametric object, dropping
  the "still exists" check. Killed by `P12`.
- **M-06y:** `onTapOutside` is removed from the Selection section's field
  builder (D13). Killed by `SE8`.

Two clarifications to the table above, found while firing it:

- **M-06g (app):** in `apps/floor_planner`, this mutant (dropping
  `BoxType.reach`'s `toWorld` transform) is killed by `BT6`, a direct
  assertion on `reach`'s output, not by `BT3`'s clipped-outline test. With
  untransformed corners, every box's reach contains its own local origin
  region, so every pair still counts as neighbours and `generate`'s exact
  inside test still produces the right 5/3 split — the mutant costs
  correctness of *which* boxes regenerate needlessly, not the outcome this
  fixture can observe (the spec's own open question on `reach`, below).
- **M-06b′:** first fired against `N6`'s original pierce-and-swallow fixture
  and **survived** — a degenerate fixture (CLAUDE.md's dominant failure
  mode): only one side of the move reserved a new handle, so an unsorted
  closure had nothing to disturb. `N6`'s geometry was rewritten, test-only,
  to a cross overlap where both objects gain children in the same `_plan`
  call; re-fired, killed.

### Differential check

- **The oracle.** `drift()` must be empty after every mutation in every
  relational test. A full regeneration from scratch must agree with the
  incremental one.
- **The redo check.** After `redo`, the child handle list equals the
  post-edit list exactly.

### Widget and app tests

- **The Box tool:** two clicks make one group, one component and four
  LINE children, in one undo step.
- **Two overlapping boxes:** each shows the clipped outline, and the child
  counts are asserted.
- **The Selection section:**
  - it shows for one box and hides for none, two, or a non-box;
  - Enter commits one step;
  - an invalid value reverts;
  - under runtime the fields are read-only;
  - typing B in the field does not switch tools.
- **The sample plan:** `drift()` is empty (it has no parametric objects).

## Exit gate

1. The four gate lines are green with `CI=true`:
   - engine, render layer and harness;
   - the app, with both release builds `✓ Built`;
   - the render layer's only failures are the five standing
     `text_ladder_golden_test.dart` goldens.
2. A parameter change regenerates the geometry, including a neighbour's.
3. The change plus its regeneration is exactly one undo step. Undo restores
   the parameters and the geometry. Redo restores both with the same
   handles.
4. Load → save is byte-identical, and the typed component comes back.
5. The same state plus the same edit gives the same bytes regardless of
   store insertion order (D11).
6. A mutual dependency terminates, with no iteration (D4).
7. Regeneration does not trip `QueryReentrancyError`.
8. The allocation invariants pass unchanged.
9. Draw order stays ascending, and an unchanged object keeps its child
   handles.
10. A direct edit of a generated child is refused (D6).
11. Delete detaches the component, and undo restores it (D8).
12. The runtime inherit rule holds, including undo and redo (D7).
13. Every named mutant is killed, or recorded as N/A or covered, as the
    table says.
14. **The human's look** at the Box tool and the Selection section, on
    macOS, in Chrome and in Firefox.

## Open questions

None blocking. Recorded for 07:

- **Draw order of added children** (D12).
- **The O(n²) neighbour search.** A broad phase is needed only past a few
  hundred parametric objects.
- **Whether `reach` needs to be richer than an AABB.** A long diagonal wall
  has a large AABB and would produce spurious neighbours. Those cost time,
  not correctness: generation does the exact test. The per-axis tolerance
  rule in D3 is a placeholder that 07 must re-derive for mitred corners,
  not inherit (review m3).
