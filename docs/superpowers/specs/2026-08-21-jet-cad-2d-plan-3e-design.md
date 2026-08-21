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

### There is no geometry-edit command, and `replace` has no production caller

`replace(slot, payload)` exists, mutates in place and keeps the `geomIndex`. It
has **no production caller** — no command calls it, nothing in `lib/` calls it.
It is pinned by one test, `geometry_store_test.dart:94` ("replace swaps the
payload in place without changing the slot"), so the API is specified and
unused rather than untested and unused.

*(An earlier draft of this document said "not by a command, not by a test,
nowhere in the repository". That was wrong: the search behind it was
`geometry\.replace`, and the test calls `store.replace`. An absence found with
a narrow pattern is not an absence.)*

Editing an entity's points today therefore means `RemoveEntityCommand` +
`AddEntityCommand`, which is why the R4a rig prints `handles burned=201` over
200 steps — measured in the 2026-08-21 follow-up runs recorded in the Plan 3d
results note, not in the note's original body.

**This breaks associativity outright.** A fill that references its boundary by
handle loses its referent the moment the boundary is edited, because the
"edited" boundary is a different entity with a different handle. Associativity
is not an extra this plan chooses to add; it is unreachable without a
command that preserves identity. `SetEntityGeometryCommand` is therefore in
scope, and `replace` finally gets its caller.

### `geomIndex` is not a safe cache key, and `purge()` is why

Three separate facts, which together decide the key.

1. **Slots are recycled.** `GeometryStore` frees slots through `SlotAllocator`
   and reuses them, so an entry left behind after a removal is eventually served
   **to a different entity**.
2. **`replace` keeps the `geomIndex`.** An edit does not churn the key, so the
   cache cannot rely on key churn for invalidation.
3. **`purge()` renumbers every `geomIndex` wholesale** — `draft_document.dart`
   takes `geometry.purge()`'s remap and rewrites `record.geomIndex` for every
   live entity. A `geomIndex`-keyed cache does not go *stale* here. It goes
   **permuted**: every surviving entry is now attached to the wrong entity at
   once.

**Handles have none of these properties.** `HandleSeed.next()` only increments
and handles are never reissued; `purge()` compacts slots and leaves handles
untouched, which is exactly what `CLAUDE.md`'s "draw order is ascending handle
value, stable across undo, save, load and **purge**" asserts; and
`RemoveEntityCommand`'s inverse re-inserts with the same handle through
`handleSeed.raiseTo`.

| | keyed by `geomIndex` | keyed by boundary `Handle` |
|---|---|---|
| `purge()` | silently **permuted** | untouched |
| slot recycling | wrong drawing, plausible | not a key space at all |
| missed invalidation on remove | wrong drawing | a **leak**, bounded by removals |
| remove then undo | new slot, must re-triangulate | same handle, same payload — the surviving entry is still correct |

**So the cache is keyed by the boundary's `Handle`.** The failure mode moves
from *a lie* to *a leak*, which is the trade this codebase makes everywhere
else, and `purge()` needs no invalidation hook at all — the third site
disappears instead of being patched.

### Draw order is load-bearing far outside the painter

`SpatialIndex` uses ascending handle value for pick priority, snap tie-breaks
and "topmost"; `reference_walk` sorts into handle order before walking;
`CLAUDE.md` lists the rule as a non-negotiable. Any design that reorders drawing
reorders all of those.

**Two things are *not* in handle order, and saying so matters because the
round-trip argument below leans on the difference.** The codec emits entities in
**ascending slot order** (`json_codec.dart:67-69`, and its comment says so),
which parts company with handle order after an undo — a restored entity keeps
its high handle and takes a recycled low slot. `DocumentTree._link` **appends**
children in insertion order (`tree.dart:561`); ascending handle order is
re-established downstream, by `reference_walk`'s sort. Neither breaks this plan.
Both are pre-existing, and neither is a place to put a fill's ordering.

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

**`AddRegionCommand` is one `apply`, not two composed.** It writes the fill
first, and at that instant the boundary it names does not exist. If it composed
two `AddEntityCommand`s, `invalidateDerived()` would fire between them and an
observer — the index, the extents cache — would see a document containing a fill
with a dangling reference. Required: **one `apply`, both writes, one
`invalidateDerived`, the intermediate state never observed.** The inverse
removes in the opposite order, boundary then fill, for the same reason.

**`SetEntityGeometryCommand` refuses `EntityKind.fill`.** A fill's payload is a
*reference*, not geometry, and letting a geometry command rewrite `scalars[0]`
would repoint a fill at another boundary with no validation, no cache move and
no `touched` story. Re-association is a different operation and is out of scope;
the command throws, and the refusal is a named mutant.

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
| key | the **boundary's `Handle`** — see [why not `geomIndex`](#geomindex-is-not-a-safe-cache-key-and-purge-is-why) |
| value | `Int32List` of triangle indices into the boundary's own `coords` |
| bound | one entry per boundary that a fill names; no eviction policy |
| hit | returns the stored list by reference — **zero allocation** |
| miss | **never on the frame path** — see below |

**Indices, not coordinates.** The points already live in the boundary's
payload, the transform is applied to them at draw time, and an index list is
small and transform-free. Storing coordinates would duplicate the loop — the
thing the model design exists to avoid.

**Populated eagerly, never lazily.** The frame path *reads*; it does not
compute. A cache that misses "on first draw" still ear-clips and still allocates
on a paint, for every fill that becomes visible after a load or an edit — which
contradicts the rule this design is built around rather than satisfying it. So
an entry is materialised at the four moments a boundary's geometry becomes
current, all of which are off the frame path:

`AddRegionCommand` · `SetEntityGeometryCommand` · codec load · undo and redo

**The cost this moves rather than removes** is load time: a document with N
fills triangulates all N before its first frame. Room boundaries are tens of
points and ear clipping is O(n²) in points, not in fills, so this is expected to
be small — and it is a **measured** row of the exit gate, not an assumption.

**No eviction policy, deliberately.** Entries are created with a fill and
destroyed with the boundary they name, so the cache holds at most one entry per
boundary that some fill has named — bounded by the document, never by its edit
history. A limit like `kParagraphCacheLimit` exists because paragraphs are keyed
by *content*, an unbounded key space; a boundary handle is not.

### Invalidation, and the trap in it

Two sites, and — because the key is a `Handle` — only two:

1. `SetEntityGeometryCommand` — the payload changes under a key that does not,
   so the entry is replaced, not merely dropped.
2. `RemoveEntityCommand` — removing a boundary drops its entry.

**`purge()` is deliberately not a third site.** It renumbers every `geomIndex`
and touches no handle, so a handle-keyed cache is correct across it with no hook
at all. Under a `geomIndex` key it would have been the worst site of the three,
permuting every live entry at once. **A test must pin this**: purge a document
with fills and assert the drawing is unchanged. Under `geomIndex` keying that
test goes red; under `Handle` keying it passes for a reason, and the reason is
the point.

**And a missed invalidation is now a leak, not a lie.** Forgetting site 2 grows
the cache; it cannot draw the wrong thing, because handles are never reissued.
The test for it is a *count*, not a picture: remove a fill's boundary, then
assert the cache is empty.

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

A fill has no `coords`, so `pointBounds` returns an empty box, and its box has
to come from the boundary.

**`entityBounds` does not resolve the reference, because the file forbids it in
writing.** Its doc comment says, of the text style it takes as a record rather
than a handle:

> giving this function a document dependency so it could look one up would be
> worse: every caller already holds the document and can resolve the record once.

A boundary handle is the same shape of lookup, and the same answer applies. The
**caller** resolves, exactly as it already does for `TextStyleRecord`, and
`entityBounds` gains two parameters:

```dart
EntityKind? boundaryKind,
GeometryPayload? boundaryPayload,
```

both null for every kind but `fill`, and both required for `fill` — a fill with
no boundary resolved returns an empty box and is counted, never guessed at.

**`entityBounds` and every one of its call sites are one task, not several.**
This is exactly the shape of Plan 3c's Task 4, and for the same reason: update
the function, miss a call site, and the index carries a wrong box silently. Each
call site must also state **`peek` or `read`** for the boundary payload:
`read` copies three objects, `peek` returns the store's own buffer, and the
index's hot paths already use `peek` for exactly that reason. Commands, which
keep what they read, use `read`.

### The fill's box goes stale when its boundary is edited — and that is the trap

`SpatialIndex` re-derives boxes **only for the handles in a command's `touched`
set**. `SetEntityGeometryCommand` on a boundary touches the boundary. The fill's
box is *derived* from that boundary and its handle is not in the set, so the
index keeps the old box: the fill is culled against a region it no longer
occupies, and picks near it answer against an outline that has moved.

**This is the same class as the cache hazard, one subsystem over**, and it is
the reason the design cannot reason about the cache in isolation and call the
job done.

**`SetEntityGeometryCommand`'s `touched` set must contain every fill that names
the edited boundary.** That requires a reverse lookup, which the design owes
explicitly:

**`boundary Handle → fills`, a map the document maintains**, not an owner scan.
A scan is O(entities) per edit, and R4a already establishes that an edit happens
per frame during a drag; at 50,000 entities that is a scan per frame. The map is
written by the same three commands that write fills, and is rebuilt on load. It
is needed twice — here, and for the cascade in `RemoveEntityCommand` — so it is
not machinery introduced for one caller.

### Picking: a fill is drawn, not picked

**The design's earlier claim that "a fill answers `HitKind.fill` on its own
handle" is withdrawn. It cannot work, and it should not.**

Two independent facts make a fill unpickable, and both are correct as they
stand:

- `_considerLeaf` returns before any kind dispatch when `pointCount == 0`. A
  fill has no coordinates, so it is never a candidate.
- Even if it were, it would always lose. Pick priority is kind first, then
  ancestor, then **greater handle wins**. A fill's handle is strictly lower than
  its boundary's — that is the whole point of the reservation — and a closed
  polyline already answers `HitKind.fill` on its own interior. The boundary wins
  every interior click, in every case, by construction.

So the resolution is to **delete the requirement, not to add a picker**.
Clicking inside a filled room selects the **boundary**, with `HitKind.fill`,
exactly as it does today for an unfilled closed polyline; the region tool maps
either half of the pair to the pair, which is the architecture spec's "the user
never sees two entities" working as designed.

Two consequences to state so nobody later "fixes" them:

- **`snapCentreOfLeaf` returns null for a fill** and **`NarrowPhaseSlack.ofLeaf`
  returns `none`** — both already, through `if (kind != circle && kind != arc)`
  guards rather than a switch with a default. Both answers are *right*: a fill
  contributes no snap candidate (its boundary already contributes every vertex,
  and doubling them would break snap tie-breaks), and its box contains its
  narrow phase trivially because it has none. The plan states the reasoning;
  it changes no code there.
- **The parallel oracle needs the same silence.** `reference_query.dart`'s two
  `switch (record.kind)` statements must gain `fill` cases that produce no hit
  and no snap candidate, or the differential oracle goes red for a disagreement
  that is not one.

### The translucent seam, decided by measurement

Plan 3d recorded permitted divergence 5 as "overlapping translucent strokes
double-blend", inert while the corpus is opaque, "live the moment 3e adds
fills". **There are two modes here, not one, and an earlier draft of this
document wrongly replaced the recorded one instead of adding to it.**

**Mode 1 — overlapping strokes, exactly as 3d recorded it.** At every join,
`_emitJoin` fills the notch on the *outer* side of the turn, and the two chord
quads meeting at that vertex overlap in a lens on the *inner* side. That overlap
is geometric and unavoidable: two rectangles of the same half-width sharing an
endpoint at an angle intersect. So every corner of every polyline and every step
of every flattened circle double-blends under alpha. 3d's shape was right.

**Mode 2 — shared triangulation edges, new with fills.** A triangulation of a
simple polygon *tiles* its interior: triangles share edges but not area, so
there is no overlap. The divergence arrives at the edges. `Paint.isAntiAlias`
defaults true and `VerticesDrawSink` does not clear it, so edge pixels are
covered partially and two adjacent triangles blend the same pixel twice at
partial alpha — visible as seam lines *across the interior of a single fill*.
`Canvas.drawPath` computes coverage once for the whole path and has no seam.

Both are measured. Neither is assumed.

#### The instrument, and why the obvious one is wrong

**`TriangleRasterizer` cannot see either mode, and a test written against it
would pass vacuously.** Its inner loop is `pixels[y * width + x] = rgba` — a
plain store. No blending, no alpha compositing, no antialiasing, last write
wins. It is a *coverage* instrument, which is what it was built to be, and both
modes are *blending* artefacts. A seam test on the repository's own rasterizer
is a reviewed degenerate fixture, which is this codebase's named worst case.

The seam is therefore measured against the **real engine**: a `ui.Picture`
recorded through each sink, `picture.toImage()`, `toByteData()`, compared pixel
by pixel — the instrument Plan 3d's Task 2 already used when it needed an answer
the rasterizer could not give.

#### The thresholds, declared here, before the measurement

Fixture: a single convex-and-a-notch boundary filled at `alpha = 0x80` over
white, one entity, 400 × 300 logical at the `flutter_test` default device pixel
ratio of 3.0. Compared: `CanvasDrawSink`'s `drawPath` against
`VerticesDrawSink`'s `drawVertices`, both through `picture.toImage()`.
Interior pixels only — the outer boundary ring, one device pixel wide, is
excluded, because edge antialiasing there is not the artefact under test.

> **Routing fires if** more than **0.5 %** of interior pixels differ by more
> than **8/255** in any channel, **or** any single interior pixel differs by
> more than **32/255**.

If it fires, translucent fills route through the fallback sink —
`_flushBeforeUnbatchable`, the mechanism Plan 3d handed over, whose only caller
today is `text`. If it does not, translucent fills batch and both divergences
are recorded as inert in practice **with the measured percentage and maximum
beside them**.

**A third answer exists and is rejected on the record:** clearing
`isAntiAlias` on the vertices `Paint` removes the partial coverage and with it
the seam. It also jags every stroke in the drawing, on every frame, to fix an
artefact that appears only under alpha. Rejected, not overlooked.

#### The opaque floor, also declared

The opaque agreement row is measured with the existing `measureAgreement`
harness at `kInkAlphaFloor = 0xC0`, and its threshold is a **ratio** so it does
not depend on the fixture's size:

> `strayVerticesPixels` and `uncoveredCanvasPixels` must each be **at most 1 %**
> of `canvasInkPixels`, and `canvasInkPixels` must exceed **4000** so the row
> cannot pass against a near-blank surface.

### Two invariants on the vertices sink

**`_coveredArgb` must never see a fill's style.** It fades alpha in proportion
to device *stroke* width, mirroring `Geometry::ComputeStrokeAlphaCoverage`. A
fill entity's `ResolvedStyle` still carries `lineweightHundredths`, because the
column is per-entity and shared, so routing a fill through that function would
fade a filled room on a hairline layer — **on the vertices backend only**, and
the ink floor would then hide the disagreement. `fillPolygon` and `fillCircle`
use `style.argb` directly.

**A circle fill's fan uses the same step count as the circle's own stroke**, not
merely a similar one: the identical expression, `(theta * sqrt(deviceRadius /
(8 * kFlattenTolerance))).ceil()` clamped to `kMaxFlattenSegments`. A different
count makes a filled circle's silhouette and its own outline disagree, and the
disagreement changes with zoom.

### The painter decides the skip, not the sinks

A boundary that yields no triangles must never reach a sink. `CanvasDrawSink`
ignores `triangles` and fills the path by non-zero winding, so a self-
intersecting loop would paint *something* there while `VerticesDrawSink` painted
nothing — a divergence created exactly on the malformed case this plan says it
refuses. So the **painter** checks for an empty triangulation, skips the fill,
and increments `skippedFillCount`; neither sink is ever handed an empty fill,
and the rule is a stated painter invariant with a test.

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
| key the cache by `geomIndex` instead of `Handle` | **purge a document containing fills and draw again** — a suite that never calls `purge()` cannot tell the two keyings apart |
| drop dependent fills from `SetEntityGeometry`'s `touched` set | edit a boundary, then **pick or cull inside the new-but-outside-the-old region** — asserting the drawing alone will not show it |
| make `AddRegionCommand` two composed commands | assert no observer sees a fill whose boundary is missing — a test that only checks the end state passes |
| let `SetEntityGeometryCommand` accept a fill | assert it throws; a suite that only ever edits boundaries cannot tell |
| route a fill through `_coveredArgb` | a fill on a **hairline** layer — every fixture at a normal lineweight passes |
| give the circle fan its own step count | compare a filled circle's silhouette against its own outline **at two zooms** |
| hand an empty triangulation to the sinks | a **self-intersecting** boundary through both backends — canvas paints, vertices does not |
| drop the `fill` cases from `reference_query.dart` | the differential oracle, which fails for the right reason only if the cases exist |

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
| ink agreement between backends, opaque fills | `strayVerticesPixels` and `uncoveredCanvasPixels` each **≤ 1 %** of `canvasInkPixels`, with `canvasInkPixels > 4000` |
| translucent seam difference | measured **against the real engine**, not `TriangleRasterizer`; routing fires above 0.5 % of interior pixels at 8/255, or any pixel at 32/255 |
| `skippedFillCount` on the rig corpus | **0** |
| a malformed fill in a loaded document | reported by `validate()` with the matching code, and nothing mutated |
| triangulation entries after `purge()` | drawing unchanged, byte for byte |
| cache entries after removing every fill's boundary | **zero** |
| load-time triangulation cost, rig corpus | measured and recorded; no threshold, but no plan may skip the row |
| the mutation log | every mutant killed or argued equivalent |

**If a failable row misses: record the number and stop.** Plan 3b's Task 4 stop
clause is the precedent — a row that fires is a result, and the note says what
it implies for 3f rather than being tuned into compliance.

The results note must state whether macOS Low Power Mode was on.

---

## What 3e owes the plans after it

- **3f (caches and tiles)** inherits a second cache, and the argument for why it
  is keyed by `Handle` rather than by a slot — `purge()` permutes slots, and a
  picture or tile cache keyed on one has the same defect for the same reason. It
  also inherits a fill path whose cost is triangles rather than canvas calls,
  which is the arithmetic a tiling scheme changes.
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
| The seam test is written against `TriangleRasterizer` and passes vacuously | The rasterizer does not blend — `pixels[i] = rgba`, last write wins. Named in the design, and the instrument is specified as `picture.toImage()` instead |
| Eager triangulation makes load slow on a fill-heavy document | It is a measured gate row rather than an assumption, and ear clipping is O(n²) in a boundary's points, not in the document's fills |
| The reverse lookup is rebuilt wrongly on load and nothing notices | It is derived state with one source of truth; a test rebuilds it from a loaded document and compares against the map the commands built |
| A fill's transparency makes the corpus non-opaque and disturbs Plan 3d's measurements | The rig carries fills behind a define, as text does, so on/off is one flag apart on one corpus |
| The first frame after an edit allocates, and the allocation gate reads it | The gate measures the **steady state**, exactly as Plan 3c's "zero new paragraph layouts on a repeat frame" does. A miss after an edit is expected; a miss on a repeat frame is the failure |

---

## Review, and what it changed

Three independent reviews, 2026-08-21, before any task was written. Every claim
below was re-verified against the tree rather than taken on report — the
codebase's own rule, and it paid: two review findings were themselves
overstated, and one thing none of the three found is the sharpest item here.

### Changed the design

- **The cache is keyed by the boundary's `Handle`, not its `geomIndex`.** A
  review found a third invalidation site the draft had missed — `purge()`
  renumbers every `geomIndex` wholesale, so a `geomIndex`-keyed cache is not
  stale after a purge but **permuted**. Rather than add a third hook, the key
  moved. Handles survive purge, are never reissued, and are restored by undo, so
  two of the three hazards stop existing and the third degrades from a wrong
  drawing to a leak.
- **`entityBounds` does not resolve the boundary handle.** The draft said it
  must. `extents.dart`'s own doc comment refuses exactly that dependency, in
  writing, for `TextStyleRecord`. The caller resolves and passes
  `boundaryKind` + `boundaryPayload`, following the precedent already in the
  file, and each call site declares `peek` or `read`.
- **A fill is drawn, not picked, and the claim that it "answers `HitKind.fill`
  on its own handle" is withdrawn.** Two independent facts make it unpickable
  and both are correct: `_considerLeaf` returns before kind dispatch when
  `pointCount == 0`, and pick priority breaks kind ties by **greater** handle,
  which a reserved-lower fill loses to its own boundary by construction. Two
  reviews proposed adding a fill case to the picker. The verified answer is the
  opposite — delete the requirement. Clicking a filled room selects the
  boundary, which is what it already does, and the region tool owns the mapping.
- **`SetEntityGeometryCommand`'s `touched` set must carry every dependent
  fill**, and a `boundary → fills` map is now owed explicitly. `SpatialIndex`
  reconciles only touched handles, so editing a boundary left its fill's indexed
  box describing geometry that no longer exists — the same class as the cache
  trap, one subsystem over, and the reason this design cannot reason about one
  subsystem at a time.
- **Triangulation is materialised eagerly**, at command, load and undo/redo.
  "A miss on first draw" is still a computation on a paint, which contradicts
  the rule the design is built around instead of satisfying it.
- **Thresholds are numbers now.** "The floor the plan declares" is not a floor.
  The seam rule is 0.5 % of interior pixels at 8/255, or any pixel at 32/255, at
  a stated fixture, viewport and device pixel ratio; the opaque row is 1 % of
  canvas ink with a non-vacuity floor of 4000.
- **`AddRegionCommand` is one `apply`**, and `SetEntityGeometryCommand` refuses
  fills. Both were unstated and both have a named mutant now.
- **Two vertices-sink invariants** are stated: `_coveredArgb` never sees a
  fill's style, and a circle fill's fan shares the stroke's exact step
  expression.
- **The painter owns the empty-triangulation skip**, because `CanvasDrawSink`
  fills a self-intersecting path by non-zero winding while `VerticesDrawSink`
  would draw nothing — a divergence manufactured on the very case the plan
  refuses.

### Found by verifying, not by any review

**`TriangleRasterizer` cannot see the translucent seam at all.** Its inner loop
is `pixels[y * width + x] = rgba`: a plain store, no blending, no alpha
compositing, no antialiasing. Both divergence modes are blending artefacts. A
seam test written against the repository's own rasterizer — the natural
instrument, the one the goldens use — would have passed against a sink drawing
the artefact at full strength. The measurement is specified against
`picture.toImage()` instead.

This is the failure this codebase names as dominant, in its most expensive form:
not a degenerate fixture that slipped through, but one that a review had already
approved.

### Corrected a fact

- **`GeometryStore.replace` has a test caller**, `geometry_store_test.dart:94`.
  The draft said "not by a command, not by a test, nowhere in the repository".
  The search behind that sentence was `geometry\.replace`; the test calls
  `store.replace`. The true statement is *no production caller*, and it is now
  the one in the text. An absence found with a narrow pattern is not an absence.
- **The codec emits entities in slot order, not handle order**, and
  `DocumentTree._link` appends in insertion order — handle order is
  re-established downstream by `reference_walk`'s sort. The draft asserted
  handle order for both. Neither affects a decision here, but the round-trip
  argument leaned on a claim that was only approximately true.
- **The `handles burned=201` figure** comes from the 2026-08-21 follow-up device
  runs, not from Plan 3d's original results note.

### Considered and not changed

- **A fill-specific picker narrow phase.** Two reviews asked for one. Verified
  unnecessary: the correct behaviour is no hit, and the existing `count == 0`
  early-out already produces it.
- **`NarrowPhaseSlack.ofLeaf` and `snapCentreOfLeaf` "fail silently" for a new
  kind.** Reported as a hazard; verified as correct behaviour. Both use a
  negative guard — `if (kind != circle && kind != arc)` — not a switch with a
  default, and both of their answers for a fill are the right ones: zero slack,
  because a fill's box contains a narrow phase it does not have, and no snap
  centre, because its boundary already contributes every candidate and doubling
  them would corrupt snap tie-breaks. The reasoning is recorded so a later
  reader does not "fix" it.
- **The cache "accumulates across fill/remove history".** Verified false: the key
  space is live boundary handles, so the cache cannot exceed the document's
  boundary count regardless of how many fills have come and gone. The draft's
  stated bound — "the number of live fills" — was imprecise and is corrected,
  but the bound itself holds.
- **Clearing `isAntiAlias` to remove the seam.** Named and rejected on the
  record rather than left unconsidered: it would jag every stroke on every frame
  to fix an artefact that only appears under alpha.
