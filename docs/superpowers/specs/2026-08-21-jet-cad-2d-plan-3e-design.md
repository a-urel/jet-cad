# jet_cad_2d Plan 3e — Solid fills

**Status:** design, approved 2026-08-21.
**Supersedes nothing.** Extends the model and the render path built by Plans 1,
2, 3a, 3b, 3c and 3d.
**Binding authority above this document:**
[`2026-07-27-jet-cad-2d-architecture-design.md`](2026-07-27-jet-cad-2d-architecture-design.md)
— its "Fills and floor patterns" section defines the model this plan implements
a slice of.
**Predecessor's carry-forward:**
[`2026-08-21-plan-3d-results.md`](../notes/2026-08-21-plan-3d-results.md),
"What 3d owes 3e and 3f".

---

## Summary

A drawing whose rooms are outlines is not a floor plan. This plan makes a
region *fill*: a closed boundary paints a solid colour beneath its own
outline, in the correct order, at zero per-entity frame cost, on both render
backends.

It implements the smallest slice of the architecture spec's fill model that
produces a shippable drawing:

- a new `EntityKind.fill`, which carries **no geometry of its own** — only a
  reference to the boundary entity whose loop it fills;
- a boundary that is a **closed polyline or a circle**, exactly the two things
  `SpatialIndex` already answers with `HitKind.fill`;
- an **engine-side triangulation cache**, so the frame path reads and never
  computes;
- a **region command that reserves the draw order** by allocating the pair's
  handles in one transaction, fill first;
- a **geometry-edit command**, without which associativity cannot work at all;
- a **pre-declared decision rule** for the translucent-seam divergence Plan 3d
  handed over, resolved by measurement rather than by preference.

Colour, transparency and layer come from the fill entity's own style columns.
There is no `SolidFill` class in this plan: the architecture spec's `sealed
class Fill` is born when gradients and patterns arrive, and inventing its
one-member first version here would be a type that exists to be extended later.

---

## Non-goals

Named so no task quietly grows into one.

- **Pattern and gradient fills.** `PatternFill` produces *strokes*, not area:
  its own clipper, its own scale axis, and a scanline count that grows without
  bound. That is its own plan.
- **Image fills.** Lossy, and they need a raster reference the document model
  does not have.
- **Multi-loop boundaries and holes.** A fill has one boundary, one loop.
- **Self-intersecting boundaries.** Refused and counted, never repaired.
- **The region tool.** The architecture spec's "single region tool creates and
  edits the boundary/fill pair, and the user never sees two entities" is an
  `InteractionTool`, and no `InteractionTool` exists yet. This plan builds the
  command the tool will call.
- **`SortentsTable` / an explicit draw-order key.** Considered and rejected —
  see [Draw order](#draw-order-is-reserved-not-overridden).
- **The picture cache and tiles.** Plan 3f.
- **DXF import or export.** No reader exists. The model is chosen to round-trip
  losslessly when one arrives, and that claim is argued, not tested.

---

## What the tree constrains

Facts established by reading the code, each of which decides something below.

### `HitKind.fill` already exists, and closedness is already stored

`SpatialIndex` produces `HitKind.fill` for a text box, a **closed polyline**
and a **circle interior**. Its polyline test is:

```dart
count >= 3 &&
coords[0] == coords[(count - 1) * 2] &&
coords[1] == coords[(count - 1) * 2 + 1]
```

Exact equality, with the comment "does the data say closed" — a stored-value
comparison, which is what `CLAUDE.md` requires of one.

**So the model already encodes closedness, by convention rather than by
flag, and the index already depends on that convention.** `draft_painter.dart`'s
note that "the model carries no closed-polyline flag yet" is half true: there
is no column, but there is a contract. This plan adds no column. It adopts the
same test, at the same exactness, and the fillable boundary set is exactly the
set the index can already answer a fill hit for.

### There is no geometry-edit command, and `GeometryStore.replace` has no caller

`replace(slot, payload)` exists, mutates in place and keeps the `geomIndex`. It
is called by nothing — not by a command, not by a test, nowhere in the
repository. Editing an entity's points today means `RemoveEntityCommand` +
`AddEntityCommand`, which is why the R4a rig prints `handles burned=201` over
200 steps.

**This breaks associativity outright.** A fill that references its boundary by
handle loses its referent the moment the boundary is edited, because the
"edited" boundary is a different entity with a different handle. Associativity
is not an extra this plan chooses to add; it is unreachable without a
command that preserves identity. `SetEntityGeometryCommand` is therefore in
scope, and `replace` finally gets its caller.

### `geomIndex` slots are recycled

`GeometryStore` frees slots through `SlotAllocator` and reuses them. Any cache
keyed by `geomIndex` that is not invalidated on removal will eventually serve a
stale value **to a different entity**. This is the sharpest hazard in the plan
and its own named mutant.

### `replace` keeps the `geomIndex`

Which means a geometry edit does **not** change the cache key. The cache cannot
rely on key churn for invalidation; the command invalidates explicitly.

### Draw order is load-bearing far outside the painter

`SpatialIndex` uses ascending handle value for pick priority, snap tie-breaks
and "topmost"; the codec serialises in handle order; `DocumentTree` keeps
children in handle order; `reference_walk` walks in handle order. `CLAUDE.md`
lists it as a non-negotiable. Any design that reorders drawing reorders all of
those.

---

## Decisions carried in, not to be relitigated

These were settled in brainstorming on 2026-08-21. A task that wants to reopen
one raises it as a ruling; it does not decide alone.

1. **Solid fills only.** Scope, above.
2. **The draw order is reserved, not overridden.**
3. **Triangulation lives in an engine-side cache**, not in the document and not
   in the frame path.
4. **A fill references its boundary's handle** and stores no loop of its own.
5. **The boundary is a closed polyline or a circle**, and nothing else.

---

## The model

### `EntityKind.fill`

A new member of `enum EntityKind { point, line, polyline, circle, arc, text,
attrib, fill }`. **Appended, not inserted.** Stored documents are safe either
way — `EntityRecord` serialises `kind.name` and reads it back with
`EntityKind.values.byName`, so the JSON never depends on ordinal. The columnar
store does: `EntityStore` keeps `_kind[slot] = r.kind.index` in a `Uint8List`.
Appending costs nothing and removes the question for that column and for any
binary format later.

Its `GeometryPayload`:

| field | contents |
|---|---|
| `coords` | **empty**. A fill has no geometry of its own. |
| `scalars` | `[boundaryHandle.value.toDouble()]` |

A handle in a `Float64List` is exact: handles are `int`s well under 2⁵³, and
`Handle` is an extension type over `int`, so the conversion is lossless in both
directions. The alternative — a new `Int32List` column on the entity store for
one kind's benefit — costs every entity the width.

Colour, transparency, layer, linetype and lineweight are the fill entity's own
style columns, resolved exactly as any other entity's. `linetype` and
`lineweight` are meaningless for an area and are ignored by the sinks; they are
not removed, because the columns are per-entity and shared.

### What a boundary may be

Referent must be a live entity in the **same owner** as the fill, and must be
one of:

- `EntityKind.polyline` with `pointCount >= 3` and `coords[0] == coords[last]`
  and `coords[1] == coords[last + 1]`, compared exactly;
- `EntityKind.circle`.

Anything else is rejected by the command and reported by the codec. The
same-owner requirement is what makes the reference resolvable inside a block
definition: a definition's fill names a handle in that definition, and every
instance of it resolves the same way, once.

### Draw order is reserved, not overridden

Handles are monotonic by creation, and the natural authoring order is *draw the
boundary, then hatch it* — which produces exactly the failing case, a fill
painting over its own outline.

**`AddRegionCommand` allocates both handles in one transaction, fill first.**
The fill's handle is therefore strictly lower than the boundary's, ascending
handle order is unchanged, and no other system moves.

The two alternatives were considered and rejected:

- **An explicit draw-order key** the painter honours ahead of handle order.
  DXF-native (`SortentsTable`) and fully general, but it rewrites a
  non-negotiable and ripples through pick priority, snap tie-breaks, "topmost",
  the codec's ordering, `reference_walk` and the differential oracle. It is a
  plan, not a section of one. **It remains a strict superset of what is built
  here** — adding it later does not undo the reservation.
- **A fills-first pass.** Cheapest, no model change, but it is a *global* rule:
  a fill could never sit above a stroke, so solid poché over a hatch is
  unrepresentable, and a document that says otherwise cannot be drawn faithfully.

**Known limitation, stated rather than hidden:** a fill cannot be added to a
pre-existing boundary, because no lower handle is available. Within this plan's
scope — the region command creates both — that is not yet a limitation. It
becomes one the day a "hatch this existing outline" tool is wanted, and that
day is when the explicit key earns its cost.

**Load-time validation.** A document from anywhere but this command may carry
`fill.handle > boundary.handle`. It is **reported and changed nothing** — not
reordered, not renumbered, not refused. A loader that silently re-sorts to
preserve "ascending handle is draw order" breaks that rule in the act of
defending it: the drawing then differs from the file. The document draws as
written, and the report says it will look wrong.

### The commands

| command | behaviour |
|---|---|
| `AddRegionCommand` | Takes the boundary's kind and payload plus both entities' style. Allocates two handles, fill first, writes both into one owner. Inverse removes both. |
| `SetEntityGeometryCommand` | Replaces one entity's payload in place, preserving handle and `geomIndex`. Inverse restores the previous payload, read through `GeometryStore.read` — never `peek`, whose shared buffer would let a later edit rewrite undo history. Invalidates the triangulation entry. |
| `RemoveEntityCommand` (existing) | Extended: removing a boundary removes its fills, in the same transaction, restored together by the inverse. Also invalidates the triangulation entry. |

**A command cannot report.** `CommandResult` carries an inverse and a touched
set and nothing else, and `DraftCommand.apply`'s contract is that it "must
either complete fully or leave the target unmutated". So a command's answer to
a boundary it cannot fill is to **throw**, in the shape `AddEntityCommand`
already uses for `DuplicateHandleError`. Passing an unfillable boundary to
`AddRegionCommand` is a caller's mistake, not a data condition, and it is
refused before anything is written.

### How a bad boundary is reported

Data conditions — a document that already contains a bad fill — are not the
command's business, and this plan invents no channel for them. Both channels
it uses exist:

**`DocumentValidation.validate()`**, the "reports and never mutates" pass with
symbolic codes, gains five, following the existing `'entity.owner_missing'`
naming:

| code | condition |
|---|---|
| `fill.boundary_missing` | the referenced handle resolves to nothing |
| `fill.boundary_not_fillable` | the referent is not a polyline or a circle |
| `fill.boundary_not_closed` | a polyline whose first and last points differ |
| `fill.boundary_foreign_owner` | boundary and fill are in different owners |
| `fill.draw_order_inverted` | `fill.handle > boundary.handle` |

**`skippedFillCount`** on the painter, the same instrument Plan 3c's
`skippedTextCount` is, counts fills the frame declined to draw — an unresolvable
reference, or a boundary the triangulator returned nothing for. It is a failable
criterion of the exit gate, and its threshold is **zero on the rig corpus**.
Splitting the two is deliberate: `validate()` answers "is this document
well-formed", which a caller asks once; the counter answers "did this frame
draw everything it was given", which the gate asks every run.

**Removing a boundary removes its fills.** The alternative — an orphaned fill
that draws nothing and reports nothing — is the failure mode this codebase
already names as the worst kind: it looks like it works.

### Codec

Schema 4 → 5. A fill is an entity, so the existing entity serialisation carries
it; what is added is the new `kind` value and the boundary-handle read. Nothing
derived is written: no triangles, no closedness flag, no copy of the loop.

**One copy of the truth is the point.** There is no second representation that
can drift out of agreement with the first, so byte-identical round-trip is
preserved without a reconciliation step.

---

## Triangulation

### Circles are not cached, and this is not an optimisation

A circle's triangulation is **scale-dependent**: the flattening step count comes
from the device-space radius, and a fan cached at a fixed step count goes
visibly polygonal on zoom. A circle fill is therefore built per frame as a fan
from the centre — `(c, pᵢ, pᵢ₊₁)` — which is pure arithmetic against the
existing flattener, allocates nothing, and is what the stroked circle already
does.

A polygon's triangulation **is** scale-invariant: the points are fixed and the
triangulation stays valid at every zoom. Only polygons are cached.

**This keeps Plan 3f's third trap out of 3e entirely.** That trap is "a cached
picture is no longer scale-invariant now that dashes exist". Here the only
scale-dependent thing is never cached and the only cached thing is genuinely
scale-invariant. No new invalidation axis is created.

### The cache

| | |
|---|---|
| lives in | `packages/jet_cad_2d`, pure Dart, no `dart:ui` |
| key | the **boundary's** `geomIndex` |
| value | `Int32List` of triangle indices into the boundary's own `coords` |
| bound | the number of live fills in the document; no eviction policy |
| hit | returns the stored list by reference — **zero allocation** |
| miss | after an edit or on first draw, never per frame |

**Indices, not coordinates.** The points already live in the boundary's
payload, the transform is applied to them at draw time, and an index list is
small and transform-free. Storing coordinates would duplicate the loop — the
thing the model design exists to avoid.

**No eviction policy, deliberately.** Entries are created on demand and
destroyed with their boundary, so the cache is bounded by the document's fill
count, which is the correct bound. A limit like `kParagraphCacheLimit` exists
because paragraphs are keyed by *content* and the key space is unbounded; a
`geomIndex` key space is exactly the live slot count.

### Invalidation, and the trap in it

Two sites:

1. `SetEntityGeometryCommand` — `replace` mutates in place and keeps the
   `geomIndex`, so the key does not change and the entry would otherwise go
   stale silently.
2. `RemoveEntityCommand` — **and this is the dangerous one.** `geomIndex` slots
   are recycled. An entry left behind after a removal is served to whatever
   entity next takes that slot: a silent, plausible, wrong drawing.

The test for (2) must force slot reuse — remove, then add a differently-shaped
entity, assert it landed in the same slot, then draw. **A test that removes and
does not re-add is the degenerate fixture here**: it stays green and proves
nothing.

### The algorithm

**Ear clipping**, O(n²), pure Dart, in `packages/jet_cad_2d/lib/src/geometry/`.
Room boundaries are tens of points. A thousand-point imported loop is 10⁶
operations, once per edit, off the frame path. Winding is normalised to
counter-clockwise so triangle orientation is consistent for every consumer.

**Refused, and reported.** A self-intersecting loop, and any boundary the
clipper cannot reduce, yields no triangles and the fill **is not drawn**.
Silently drawing nothing is a failure this codebase has already paid for, so
the condition is reported through two existing channels and no new one — see
[How a bad boundary is reported](#how-a-bad-boundary-is-reported).

---

## Rendering

### The sink grows two operations

```dart
void fillPolygon(Float64List points, int count, Int32List triangles,
    ResolvedStyle style);
void fillCircle(double cx, double cy, double r, ResolvedStyle style);
```

`CanvasDrawSink` draws the polygon as a closed `Path` with
`PaintingStyle.fill` and **ignores `triangles`** — `Canvas` resolves concavity
itself — and the circle with `drawCircle`. `VerticesDrawSink` writes the
indexed triangles into the batch, and fans the circle.

Both sinks receive the same ops with the same arguments, so `RecordingDrawSink`
equality and the differential oracle continue to work unchanged.

### Bounds

A fill has no `coords`, so `pointBounds` returns an empty box. `entityBounds`
must resolve the reference and return the boundary's box.

**`entityBounds` and every one of its call sites are one task, not several.**
This is exactly the shape of Plan 3c's Task 4, and for the same reason: update
the function and miss a call site and the index carries a wrong box silently.

### Picking

A fill answers `HitKind.fill` on its own handle. Reporting the boundary instead
is policy, and policy lives in the widget layer — the architecture spec already
says the engine reports the path and the viewer decides what to select.

### The translucent seam, decided by measurement

Plan 3d recorded permitted divergence 5 as "overlapping translucent strokes
double-blend", inert while the corpus is opaque, "live the moment 3e adds
fills". **The shape of it is not quite what was recorded, and the correction
matters.**

A triangulation of a simple polygon *tiles* its interior: triangles share edges
but not area, so there is no overlap to double-blend. The divergence arrives
along the **shared edges**. An antialiasing rasteriser covers edge pixels
partially, and two adjacent triangles blend the same pixel twice at partial
alpha — visible as seam lines across the interior of a translucent fill.
`Canvas.drawPath` computes coverage once for the whole path and has no seam.

So the divergence is live for a **single** translucent fill, and has nothing to
do with overlapping strokes.

**The decision rule is declared here, before the measurement, and either
outcome is a result:**

> A translucent fill is drawn through both backends and the difference along
> interior triangulation edges is measured. **If it exceeds the threshold the
> plan states before measuring**, translucent fills route through the fallback
> sink — flush the batch, draw the path — using `_flushBeforeUnbatchable`,
> which is the mechanism Plan 3d handed over for exactly this. **If it does
> not**, translucent fills batch, and divergence 5 is recorded as inert in
> practice **with the measured number beside it**.

Measuring and stopping is the outcome. Tuning until the number complies is not.

---

## Testing

The bar is `CLAUDE.md`'s: a new test is worth landing only if a named mutation
makes it go red.

| what | instrument |
|---|---|
| the two sinks agree | `sink_comparison.dart`'s ink comparison, with fill fixtures |
| the painter is right | the differential oracle — `reference_walk` walks fills independently |
| the drawing | goldens, **on both backends**, in the ladder Plan 3d established |
| allocation | `paint_allocation_test` extends to a corpus containing fills |
| the triangulator | pure-Dart unit tests: concave, L-shaped, reversed winding, collinear runs, degenerate |

### Mutants that must be killed, named before the plan is written

| mutation | the fixture property that kills it |
|---|---|
| drop the removal-path cache invalidation | a fixture that **forces slot reuse**: remove, add a differently-shaped entity into the freed slot, then draw |
| drop `SetEntityGeometry`'s invalidation | a boundary edited **into a different shape**, not merely translated |
| drop winding normalisation | a boundary authored **clockwise** — a CCW-only fixture set cannot see this |
| reverse the pair's handle order in `AddRegionCommand` | a golden or ink test where the fill's colour differs from the boundary's, so covering is visible |
| skip one of `entityBounds`' call sites | a fill whose box is queried through **that** call site specifically |
| return an empty triangle list instead of counting the skip | assert `skippedFillCount`, not just the blank result — a blank surface passes a blankness test forever |
| drop one `validate()` code | one fixture document per code; a suite that checks "validate returns non-empty" cannot tell which |
| treat a nearly-closed polyline as closed | a loop whose ends differ by less than any tolerance — closedness is an exact stored-value test |

The last one is the `Tolerance` rule stated as a fixture: a boundary whose
first and last points differ by 1e-12 is **not** closed, is **not** fillable,
and a test that uses an exactly-closed loop everywhere cannot tell.

---

## Exit gate

### Checks

Every task ends green on all three packages, per `CLAUDE.md`.

### Failable criteria

| criterion | threshold |
|---|---|
| allocations per fill in a steady-state frame | **zero** |
| 10,000 entities with fills on, vertices backend | under 16.67 ms |
| a fill's cost in `canvasCalls` on the vertices backend | **zero** — it joins the same batch |
| ink agreement between backends, opaque fills | above the floor the plan declares |
| translucent seam difference | measured; the routing rule fires or does not |
| `skippedFillCount` on the rig corpus | **0** |
| a malformed fill in a loaded document | reported by `validate()` with the matching code, and nothing mutated |
| the mutation log | every mutant killed or argued equivalent |

**If a failable row misses: record the number and stop.** Plan 3b's Task 4 stop
clause is the precedent — a row that fires is a result, and the note says what
it implies for 3f rather than being tuned into compliance.

The results note must state whether macOS Low Power Mode was on.

---

## What 3e owes the plans after it

- **3f (caches and tiles)** inherits a second cache keyed by `geomIndex` with a
  slot-recycling hazard already characterised, and a fill path whose cost is
  triangles rather than canvas calls — which is the arithmetic a tiling scheme
  changes.
- **The pattern-fill plan** inherits the boundary contract, the triangulation
  cache and its invalidation, and the region command. What it does not inherit
  is a clipper: a pattern is strokes clipped to a loop, and nothing here clips.
- **A DXF reader** inherits the claim that this model round-trips a solid
  associative HATCH losslessly, argued and untested. It also inherits the
  non-associative HATCH as an unsolved case: this model cannot express one.
- **Whoever wants a fill on an existing boundary** inherits the reservation
  decision and the explicit draw-order key as its named successor.

---

## Risks

| risk | mitigation |
|---|---|
| The recycled-slot cache bug ships because its test never forces reuse | It is named here, before the plan, and the fixture property is written out |
| Ear clipping is wrong on a boundary shape nobody tested | Concave, reversed, collinear and degenerate cases are required fixtures, not optional ones |
| `entityBounds` is updated and a call site is missed | One task owns the function and all its call sites, as in Plan 3c |
| The translucent seam is worse than expected and the plan tunes rather than reports | The decision rule and both outcomes are declared before the measurement |
| `SetEntityGeometryCommand` grows past its purpose | It replaces one payload and nothing else; it is not an edit framework |
| A fill's transparency makes the corpus non-opaque and disturbs Plan 3d's measurements | The rig carries fills behind a define, as text does, so on/off is one flag apart on one corpus |
| The first frame after an edit allocates, and the allocation gate reads it | The gate measures the **steady state**, exactly as Plan 3c's "zero new paragraph layouts on a repeat frame" does. A miss after an edit is expected; a miss on a repeat frame is the failure |
