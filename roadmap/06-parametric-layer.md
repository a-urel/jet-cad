# 06 — The parametric layer

**Status:** not started
**Depends on:** 02
**Blocks:** 07, 08, 10, 11 — the entire parametric half of the target
**Size:** L
**Risk:** highest in the roadmap. Read the spike recommendation at the end.

---

## What this delivers

The mechanism by which an object's **parameters** live in a `Component` and its
**geometry** is generated from them, and is regenerated when those parameters
or the object's neighbours change — with undo, redo, save, load, rendering,
hit-testing and snapping all continuing to work **unchanged**.

This file delivers the mechanism and one trivial client to prove it. Walls,
openings, rooms and dimensions are separate sub-projects that use it.

## Why it exists

Target B is *parametric*. A wall whose corners clean up when a neighbour moves,
a door that cuts the wall hosting it, a room whose area follows its walls, a
dimension that follows what it measures — none of these is expressible as
static geometry. Something has to recompute geometry from parameters, and that
something has to be undoable and deterministic or the document format breaks.

## The doctrine, already written into the engine

> *"Data only, never behavior. Behavior lives in application-side systems, so
> that the document stays serializable, deterministic and undoable."*
> — `packages/jet_cad_2d/lib/src/document/component.dart:12`

**A wall is therefore not a new `EntityKind`.** The engine's entity set is
DXF-shaped on purpose; adding `wall` would bump the codec schema, break the
foreign-format story, and put behaviour in the engine. Instead:

> A parametric object is a **`GroupNode`** whose children are ordinary
> generated core entities, with a **`Component` on the group's handle** holding
> the parameters. An **application-side system** regenerates the children.

## What already exists — more than you expect

- **`Component`** — `component.dart:14`. Contract: **immutable, value-equal,
  and `toJson` emits keys in a fixed order.** Value equality is what lets
  value-diff undo compare and restore component state; fixed key order is what
  keeps serialization byte-deterministic.
- **`ComponentRegistry.register<T>(typeId, factory, {internal})`** —
  `component.dart:70`. **Application code registers its own component types.**
  Nothing about this is engine-private.
- **Unknown component types are preserved verbatim** — `_unknown` at
  `component.dart:66`. Forward compatibility across versions is already solved.
- **`ComponentStore<T>` is sparse and keyed by `Type`** (`component.dart:31`,
  and the rationale at `:53`): "every handle carrying component X" costs the
  component count, not the entity count. Handles are returned in **ascending
  order** (`:43`) so results are stably ordered.
- **The codec persists components** — `json_codec.dart:78` writes
  `doc.components.toJson()`, `:127` reads it back.
- **`SetComponentCommand<T extends Component>`** — `commands.dart:400`. An
  undoable component edit already exists.
- **`Capability.components` is distinct from `Capability.geometry`** —
  `command.dart:16-27`. The permission model already separates "edit
  parameters" from "edit geometry". And the engine author was already imagining
  this exact product: `DraftPermissions.runtime`'s doc comment at
  `command.dart:46` reads *"A point-of-sale runtime: staff may move a table and
  change its properties, but cannot draw walls or alter a block definition."*
- **`DocChange` carries `touched: Set<Handle>`** —
  `doc_change.dart:18`. A regeneration trigger source.
- **`CommandDispatcher.onAfterMutate` and `onBeforeMutate`** — `undo.dart:80`
  and `:89`. Hooks for running a system around each mutation.
- **`DocumentTree.addNode` guards definition cycles** (`tree.dart`), and
  `childNodesOf` filters dangling children.

## What does not exist — and this is the hard part

### 1. There is no compound command. This is the central problem.

`UndoStack` (`undo.dart:10`) is a flat `List<DraftCommand>`. `push` appends
one inverse; `takeUndo` removes one. **One command is one undo step.** There is
no macro, batch, transaction or group anywhere in
`packages/jet_cad_2d/lib/src/document/` — grep confirms it.

So a regeneration that emits N commands creates N undo steps, and undoing one
of them leaves the parameters describing one thing and the geometry showing
another. **The document would be internally inconsistent in a state the user
can reach with one keystroke.**

This must be solved in this sub-project. It is also 03's multi-selection drag
problem and 07's "move one wall, three neighbours regenerate" problem. Solve it
once, here.

### 2. There is no dependency graph.

Wall A's mitred corner depends on walls B and C. Editing A must regenerate B
and C, in some order, without looping forever when the dependency is mutual —
and a mitre **is** mutual. Nothing in the repo tracks dependencies between
objects.

### 3. There is no regeneration system at all.

No dirty marking, no propagation, no ordering, no re-entrancy protection, no
determinism guarantee.

## Open questions — these are the spec

**Every one of these is load-bearing. This is not a checklist to skim.**

- **Where does the compound command live?** In the engine as a general
  `CompoundCommand` (pure Dart, small, and every later feature wants it), or
  application-side as one bespoke command that performs a whole regeneration?
  **Recommendation: engine-side `CompoundCommand`.** It is a genuine gap in the
  engine, not a floor-planner concern, and 03 and 07 both need it. It changes
  `undo.dart` and `command.dart` and needs its own inverse semantics — note
  that a compound's inverse is its children's inverses **in reverse order**.
- **When does regeneration run?** Synchronously inside the same dispatch (one
  undo step naturally, but it mutates while a command is executing and must not
  trip `_guardMutation` at `spatial_index.dart:183`), or as an
  `onAfterMutate` pass that emits a second command (simpler and better
  isolated, but two undo steps unless the two are folded into one compound)?
- **What triggers regeneration?** `DocChange.touched`, or explicit dirty
  marking by whatever performed the edit? `touched` is automatic but coarse.
- **How is the dependency graph derived?** Stored explicitly in each component
  (edges are data, survive save/load, but can go stale), or recomputed
  geometrically each time (always correct, costs a query)? **A hybrid — derive
  geometrically, cache in the component — is what CAD tools actually do**, and
  it is what 07's junction detection needs.
- **Cycle handling.** Mutual dependencies are normal here, not an error.
  Fixed-point iteration with a bound? Two-phase (compute all joins, then emit
  all geometry)? **Two-phase is strongly preferred** — it makes the result
  independent of visit order, which is the determinism requirement below.
- **Determinism.** Regeneration must be a pure function of parameters plus
  neighbours, evaluated in an order that does not depend on hash iteration.
  `ComponentStore.handles` is already ascending for this reason. Anything that
  walks a `Map` in insertion order breaks byte-identical round-trips.
- **What happens on load?** Is geometry trusted as saved, or regenerated on
  open? Trusting is fast and makes the file the truth; regenerating is
  self-healing and catches version drift — but if regeneration is not perfectly
  deterministic it silently rewrites the user's file.
- **What if the geometry is edited directly?** A user grip-drags a generated
  line. Reject it, accept it and back-solve the parameters, or accept it and
  mark the object "broken / no longer parametric"?
- **Does a parametric object's group show up as one selectable thing?** This is
  02's group-versus-leaf question arriving with real stakes.

## Exit criteria sketch

Use a **trivial** client to prove the mechanism — a `ParametricRectangle` with
`width` and `height` parameters generating four line entities. Walls come later
and must not be this file's test subject.

- Changing a parameter regenerates the geometry.
- The parameter change plus its regeneration is **exactly one** undo step, and
  undo restores both parameters and geometry.
- Redo restores both, with the **same handles**.
- Save → load → regenerate produces **byte-identical** JSON.
- Regeneration order does not depend on hash iteration order: a test that
  builds the same document by two different insertion orders produces
  byte-identical output.
- A two-object mutual dependency reaches a fixed point and terminates.
- Regeneration does not trip `QueryReentrancyError`.
- `query_allocation_test.dart` and `paint_allocation_test.dart` still pass.
- Draw order remains ascending handle value across a regeneration.

## Named mutants to fire

- **M-06a:** make the compound command's inverse apply its children in forward
  order rather than reverse. Must go red — **impossible to catch when the
  children are independent**, so the fixture must contain two commands whose
  order matters (create a node, then set a component on it).
- **M-06b:** walk `ComponentStore`'s handles in hash order rather than
  ascending. The determinism test must go red.
- **M-06c:** emit the regeneration as a separate command rather than folding it
  into the compound. The one-undo-step test must go red.
- **M-06d:** skip regenerating dependents, regenerating only the directly
  edited object. The mutual-dependency test must go red — **impossible to catch
  with a single isolated object.**
- **M-06e:** remove the fixed-point bound. The mutual-dependency test must hang
  or fail — if it passes, the fixture has no real cycle in it.
- **M-06f:** regenerate on load. The byte-identical round-trip test must still
  pass; if it does not, regeneration is not deterministic and the whole design
  is unsound. **This mutant is a probe, not a defect — its value is the answer.**
- **M-06g:** drop the parent group's transform when generating child geometry.
  Must go red — **the signature degenerate-fixture trap: impossible to catch if
  every group sits at the identity transform.** Place the fixture's group at a
  non-identity, non-origin transform.

## Traps

- **`QueryReentrancyError`** (`spatial_index.dart:33`) and `_guardMutation`
  (`:183`). A regeneration system that reads the index to find neighbours and
  then mutates inside the same walk will trip this. Collect first, mutate after.
- **The allocation invariant.** Regeneration runs on edits, not on frames, so
  it is not on the frame path — but the components it touches are read during
  paint. Do not allocate in the read path.
- **Value equality is a hard requirement on `Component`** (`component.dart:5`),
  not a nicety: undo compares component values. A component with default
  `Object` identity silently breaks undo.
- **Fixed key order in `toJson`** is likewise a requirement, for byte
  determinism.
- **`addDefinition` and `replaceDefinition` are unguarded for cycles** — the
  doc comment in `tree.dart` says so explicitly. Only `addNode` guards.
- Unknown component types are preserved verbatim, so a round-trip test can pass
  with the type never registered. Assert the **typed** value came back.

## Strong recommendation: spike this before writing the spec

Three things here have never been exercised anywhere in this repository:
compound undo, regeneration determinism, and re-entrancy under mutation during
a query. Build one throwaway `ParametricRectangle`, drive it through parameter
edit → undo → redo → save → load → regenerate, and find out what breaks.

The repo's own history is the argument: Plan 3i's most valuable decision was
running the whole-branch review **before** the device measurements, which
turned four would-be retractions into findings. A spike here is the same move
one stage earlier — and the cost of discovering "compound undo needs a
different shape" during a fourteen-task plan is an order of magnitude higher
than discovering it in a day.

Label anything the spike builds as throwaway. Its output is an answer.

---

## Standing context — read before touching anything

**Repo:** `/Users/ahmeturel/Projects/oss/jet-cad`, Dart/Flutter workspace,
branch `main`. **Read `STATUS.md` first**, then `CLAUDE.md`. The full roadmap
context, the target and the dependency graph are in `roadmap/00-README.md`.

**The target:** a **parametric** floor planner. Walls have thickness and clean
up at their corners, openings cut the walls that host them, rooms follow the
walls that enclose them. Chosen by the human on 2026-08-29 over the
stencil-diagram alternative.

**This file is an input to `superpowers:brainstorming`, not a plan.** Read it,
brainstorm, write a spec into `docs/superpowers/specs/`, write a plan into
`docs/superpowers/plans/`, then execute it task by task with
`superpowers:subagent-driven-development`.

**Packages:**

- `packages/jet_cad_2d` — the pure-Dart engine. **No Flutter, no `dart:ui`,
  ever.**
- `packages/jet_cad_2d_flutter` — the Flutter render layer. Here
  `unused_import` and `unused_element` are **errors**.
- `apps/dev_harness_2d` — the measurement harness. An instrument, not a
  product; do not grow the product inside it.

**Non-negotiables (`CLAUDE.md`):**

- The frame path allocates **nothing per entity** in steady state, O(1) per
  flush. Gated by `query_allocation_test.dart` and `paint_allocation_test.dart`.
- **Draw order is ascending handle value**, stable across undo, save, load and
  purge.
- Geometric **decisions** use `Tolerance`; **stored value** comparisons are
  exact `==`.
- **Never commit `analysis_options.yaml`** — `flutter pub get` rewrites three
  of them in this workspace.
- **Never synthesize test output.**
- Code, comments and commit messages in English.

**Every task ends green:**

```sh
cd packages/jet_cad_2d          && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd packages/jet_cad_2d_flutter  && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

**Prefix test commands with `CI=true`** — otherwise Dart's analytics
phone-home blocks the runner for minutes at roughly zero CPU.

**Never `git checkout` a file to revert a mutation.** Copy aside with `cp`,
mutate, restore from the copy, `diff` to verify.

**The testing bar.** Defects here surface through **mutation and differential
testing**, not through reading. The dominant failure mode is the **degenerate
fixture** — a test that passes because every fixture sits at the identity
transform, the origin, or a default attribute. A new test is worth landing only
if a **named mutation** makes it go red. This repository has repeatedly caught
instruments that could not fail; assume yours is one until a mutant proves
otherwise.

**Scale note.** A floor plan is 500–5,000 entities, not 500,000. The repo's own
figures: a 10,000-entity frame is 9.5 ms at `DASHED=0`, and the vertices sink
draws 10,000 entities in 5.71 ms build / 6.68 ms raster. **Default the tile
cache off** (`DraftCanvas(tiles: false)`) and turn it on only if a measurement
demands it. Plan 3i's blurry-zoom behaviour is a 500,000-entity problem.
