# jet_cad_2d Plan 3c — Text

**Status:** approved 2026-08-17
**Parent:** [2026-07-27-jet-cad-2d-architecture-design.md](2026-07-27-jet-cad-2d-architecture-design.md)
**Carried in from:** [2026-08-10-jet-cad-2d-plan-3b-design.md](2026-08-10-jet-cad-2d-plan-3b-design.md), "Carried to Plan 3c"
**Predecessors:** Plans 1, 2, 3a and 3b — all merged, `main` at `e338754`;
667 engine tests, 123 widget tests including 8 goldens

## Summary

Text is the product's payload: a table number and a room label are what the user
reads. Two plans in a row have recorded it as a *floor* rather than a
measurement — `skippedTextCount` is 300 entities per whole-drawing frame at both
corpus sizes, 0.06% of the corpus, unchanged from 3a to 3b. 3c closes that.

The work is one plan in two phases, and the order is not negotiable:

| Phase | Contents |
|---|---|
| **A — engine** | string and tag columns, a `textStyle` handle column, an alignment column, the attributes in `scalars`, codec plus a schema bump, `SetEntityTextCommand`, the `TextMetrics` interface, a deterministic `MetricModelMeasurer`, box geometry in `entityBounds`, `HitKind.fill` hit-testing and the same rule in the brute-force reference query, and the corpus extension |
| **B — render** | `FlutterTextMeasurer`, the painter's text path, the paragraph cache, the mirrored-text golden, rig counters, and the measurement note |

Phase A comes first because `TextMeasurer` is currently a seam with nothing to
measure: no measurer test can be written against a document that stores no text.

## Non-goals

- **MTEXT.** Multi-line text with a declared subset of inline formatting codes is
  its own subsystem — a code parser, wrapping layout, and preservation of the
  codes it does not implement. It gets its own plan. The product's payload is
  single-line.
- **DXF 72=3 ("aligned") and 72=5 ("fit").** Both need a second alignment point
  and stretch or squeeze the text to reach it. The model carries the code so a
  future importer can round-trip it; the renderer rejects it with a `Diagnostic`
  and falls back to left alignment.
- **Text LOD.** Skipping glyphs below a screen-size threshold is the text analogue
  of 3b's dash collapse floor. 3c measures the cost; 3e decides, because 3e is
  where the cache that would change the answer lands.
- Fills and hatch (3d), the definition and tile picture caches,
  `documentRevision`, and the 16.6 ms gate (3e).
- An in-place geometry command. 3b recorded that none exists and that editing is
  remove-then-add; 3c does not change that, Plan 4 does.

## What the tree constrains

Six facts read out of `main` at `e338754`.

1. **`EntityRecord` stores no text.** Its fields are `handle, owner, kind, layer,
   linetype, linetypeScale, geomIndex, color, lineweight, transparency, flags`
   (`entity_store.dart:53-65`). Both `entityBounds` call sites pass the default
   `text: ''` with a hard-coded `ReservedHandles.standardTextStyle`
   (`draft_document.dart:226-231`, `container_index.dart:93-98`).
2. **Every store column is a typed list** — `Uint8List`, `Uint32List`,
   `Float64List`, `Int16List`, `Int32List` (`entity_store.dart:177-191`), each
   reallocated in `_grow` with `setAll`.
3. **The painter counts text and skips it.** `_skippedText++` for
   `EntityKind.text` and `.attrib` (`draft_painter.dart:597-599`), exposed as
   `skippedTextCount`.
4. **Leaf boxes are built with `doc.textMeasurer`**, so a real measurer changes
   every text box in the index the moment it is injected
   (`container_index.dart:93-98`, `spatial_index.dart:2358`).
5. **Text picks as an anchor vertex.** The narrow phase treats a text leaf's
   insertion point as a vertex candidate (`spatial_index.dart:765-775`); nothing
   tests the laid-out box.
6. **`kSchemaVersion` is 3**, and its own doc comment says to bump it whenever the
   on-disk shape changes and to add a migration for the previous value
   (`schema_version.dart`).

Two facts about the appearance model that the design leans on:

- `TextStyleRecord` carries `fontFamily`, `widthFactor`, `obliqueAngle`,
  `fixedHeight` ("Zero means the height is supplied per text entity"), `isShx`
  and `shxFileName` (`tables.dart:213-240`).
- `ComponentStore` is a handle-keyed `Map` (`component.dart:32`), so a component
  lookup on the frame path costs slot → handle → map. Text content is a native
  DXF field (group code 1), which in the parent spec's two-tier model belongs in
  a column, not in the lossy rich-appearance tier.

## Decisions carried in, not to be relitigated

- Draw order is ascending handle value.
- The frame path allocates nothing in steady state.
- Geometric *decisions* use `Tolerance`; *stored value* comparisons are exact.
- ATTRIB entities are owned by the `InstanceNode` and are already indexed in the
  root leaf tree under the instance's composed transform, with the transform
  available as `transformOfLeaf(slot)`. `ConvenienceQueries.attributesOf` is a
  full store scan and must never be called on the frame path.
- Mirrored blocks render text faithfully mirrored in v1.

## Phase A — the model

### Two string columns

`_text` and `_tag`, slot-parallel `List<String>`, `''` for non-text kinds.
`_grow` follows the other columns' shape — `List<String>.filled(capacity, '')`
then `setRange` — and `free` resets both to `''`, which the existing
slot-lifetime tests already walk.

Interning into a pool with a `Uint32List` index column was considered and
rejected for now: it would preserve the all-typed-list homogeneity and make the
paragraph cache key an int, but it adds a refcount to the slot lifetime — the
one area where Plan 1's mutation testing actually found defects — and Dart
memoises `String.hashCode`, so the cache key is not the reason to do it. It is
recorded as an available optimisation, to be taken when a measurement asks for
it: two reference arrays at 500k entities is roughly 8 MB.

### One handle column, one packed column

- `_textStyle`: `Uint32List`, defaulting to `ReservedHandles.standardTextStyle`,
  which every call site hard-codes today.
- `_alignment`: `Uint8List`, DXF group code 72 in the low nibble and 73 in the
  high nibble.

### The attributes live in `scalars`, and inheritance is NaN

```
scalars[0] = height          (already there)
scalars[1] = rotation        (radians)
scalars[2] = widthFactor     NaN -> TextStyleRecord.widthFactor
scalars[3] = obliqueAngle    NaN -> TextStyleRecord.obliqueAngle
```

NaN-as-absent is this codebase's own device: `DirtyList` encodes "no centre" as
NaN so the containment test rejects it by arithmetic rather than by a flag. Same
reasoning here — one field instead of a field plus a flag, and no `==`
comparison can accidentally succeed.

**Effective height** is `style.fixedHeight != 0 ? style.fixedHeight : scalars[0]`,
which is DXF's rule and what `fixedHeight`'s doc comment already states. It is
resolved in exactly one place, because `entityBounds` and the painter must see
the same number or the box will not be where the glyphs are.

**The `transformedBy` trap is documented, not moved.** `GeometryPayload.transformedBy`
copies `scalars` verbatim and takes no `EntityKind`
(`geometry_store.dart:32-42`), with a test pinning that behaviour
(`geometry_store_test.dart:45`). Putting rotation in `scalars[1]` means a future
rotate command must rotate it explicitly. 3c pays that down by documenting what
`scalars` means per kind, warning on `transformedBy` that scalars are the
caller's responsibility, and adding a test that makes the trap visible — a
scaled circle and a rotated text — rather than by changing command semantics,
which is Plan 4's subject. Storing rotation as a second point in `coords` would
make `transformedBy` correct for free but forces the codec to convert DXF's angle
in both directions and makes the bounds path kind-aware about which points count.

### Codec and the schema bump

`EntityRecord.toJson` gains four keys in fixed order after `flags`: `text`,
`tag`, `textStyle`, `alignment`. `kSchemaVersion` goes **3 → 4**, because the
on-disk shape changes and the constant's own doc comment requires the bump.

The migration chain is Plan 5's. 3c's obligation is to record, in the plan and in
the commit, that documents written at version 3 stop being readable until Plan 5
lands, and that this is accepted because no published file exists. Pretending the
shape did not change would break the codec's own stated rule, which is worse than
an explicitly recorded gap.

Determinism, idempotence and unknown-preservation tests all extend to the new
keys: `save(load(save(d))) == save(d)` must still hold, and a foreign key inside
an entity record must still survive.

### One command

`SetEntityTextCommand(handle, text, tag)`, whose inverse restores the previous
pair. `AddEntityCommand` and `RemoveEntityCommand` carry an `EntityRecord`, so
they carry the new fields for free.

## Phase A — measurement, and the simplification it produces

**Only the string and the style affect layout.** The other four attributes are
transforms:

| Attribute | What it is |
|---|---|
| height | uniform scale, `effectiveHeight / kNominalTextPixels` |
| rotation | rotation |
| widthFactor | horizontal scale — the parent spec is explicit that this is a canvas scale, not a font feature |
| obliqueAngle | shear |
| alignment (72/73) | a translation computed from the metrics |

So a `Paragraph` is laid out **once at a nominal size** — `kNominalTextPixels = 100.0`
— and everything else enters the matrix.

Two consequences, both load-bearing:

1. **The cache key is `(string, textStyle)` and nothing else.** The parent spec
   assumed a "resolved height band"; no band is needed. Zoom never invalidates a
   text entry. 3b named a new invalidation axis for dashes, whose period is a
   function of screen scale; text's equivalent axis simply does not come into
   existence.
2. One `Paragraph` serves the same string at every height, angle and width
   factor.

```dart
/// Font metrics at the nominal size, unrotated, unaligned, with no width factor.
class TextMetrics {
  final double advanceWidth;
  final double ascent;
  final double descent;

  static const TextMetrics zero =
      TextMetrics(advanceWidth: 0, ascent: 0, descent: 0);
}

abstract class TextMeasurer {
  TextMetrics measure({required String text, required Handle style});
}
```

Three implementations, with distinct jobs:

- `FlutterTextMeasurer` — `ParagraphBuilder` plus `computeLineMetrics`, backed by
  the same cache the painter draws from. One cache, two consumers: two caches
  would be two truths about the same string.
- `MetricModelMeasurer` — deterministic, advance-ratio, no font stack, in the
  pure package. Pure-Dart bounds, pick, snap, extents and differential tests run
  against it. **Its ascent must differ from its descent**, or every vertical
  alignment defect is invisible.
- `InsertionPointMeasurer` — stays, now returning zero metrics, and its doc
  comment keeps saying what it is: a declared lower bound.

**Alignment, rotation, width factor and oblique are composed by the engine**, in
one place, into the text's local `Transform2`. The painter receives that
transform. The rule from 3a stands: `rebase.dart` is the only file that
constructs a `Matrix4`.

"One place" needs a name, or it is unverifiable. A new
`lib/src/document/text_geometry.dart` holds two functions and nothing else:

```dart
/// Everything the four attributes resolve to, with the style's defaults and
/// `fixedHeight` already applied. One resolution, so the box and the glyphs
/// cannot disagree.
ResolvedTextAttributes resolveTextAttributes(
    GeometryPayload payload, int alignment, TextStyleRecord style);

/// Insertion, alignment offset, height scale, width factor, oblique shear and
/// rotation, composed in that order into the owner's space.
Transform2 textLocalTransform(
    ResolvedTextAttributes attrs, TextMetrics metrics, Vector2 insertion);
```

`entityBounds` therefore takes the `TextStyleRecord` rather than only a style
handle: `fixedHeight` and the NaN inheritance cannot be resolved from a handle
alone, and having `entityBounds` reach into `doc.tables` itself would give a
bounds function a document dependency it does not otherwise have. Both call
sites already hold the document (`draft_document.dart:226-231`,
`container_index.dart:93-98`) and pass the record down.

The painter calls the same two functions. That is what makes "the box is where
the glyphs are" a structural property rather than a claim maintained by hand in
two files.

**The measurer is fixed for a document's lifetime.** Index leaf boxes are built
with `doc.textMeasurer`, so swapping it means rebuilding the index.
`DraftDocument` takes it at construction, which gives the rule for free — but an
unwritten rule is not a rule, and the measurer-dependence test is what holds it.

## Phase A — hit-testing

The narrow phase transforms the query point into text-local space and tests the
box built from the metrics, reporting **`HitKind.fill`** — the parent spec's rule,
and `HitKind.fill` already exists, produced today for closed-polyline and circle
interiors. The insertion point stops being a pick kind and stays a snap kind
(`SnapKind.insertion`); picking and snapping are different questions and the snap
engine already answers the second one.

**`NarrowPhaseSlack` is zero for text.** The narrow phase never reaches outside
the box, and the box is exact. Adding slack here would be an unmeasured cost.

Text corners are not snap candidates. AutoCAD does not offer them either.

The brute-force reference query implements the same rule independently, so the
differential corpus covers text picking for the first time — today it cannot,
because every text box is a degenerate point.

## Phase B — the render path

`DrawSink` gains one op:

```dart
void drawText(String text, Handle style, Transform2 local, ResolvedStyle resolved);
```

Both sinks implement it. `CanvasDrawSink` resolves the string through the
paragraph cache and calls `canvas.drawParagraph` under the residual;
`RecordingDrawSink` records the op's fields.

**This is what keeps the differential oracle working with text on.** 3a's
`differential.dart` compares *ops*, not pixels — `kScreenTolerance = 1e-6` over
`DrawnItem`'s kind, style and points. For text the compared quantity is the draw
*request* (string, style, transform), not the glyphs, so a font-dependent feature
is verified in a font-independent way. The glyphs themselves are the golden's
job. A pixel-comparing oracle would have been helpless here.

**The paragraph cache** is `(string, textStyle) -> Paragraph`, LRU, bounded at
**512 live entries**. The bound is declared rather than discovered, and the peak
live count is recorded, so the number can be revised on evidence. It is bounded
at all because a `Paragraph` holds native glyph memory and a pan across a
text-heavy plan touches every string in the drawing; it is the only cache in this
architecture that had no number attached to it.

**Mirrored text** needs no code: a mirroring transform mirrors the glyphs, and v1
renders that faithfully. A golden pins it, so a later "fix" cannot silently
introduce a counter-transform.

## The corpus, and why it has two text sources

Today `generate_document` produces `min(300, rootEntityCount ~/ 100)` texts —
0.06%. Two off-by-default parameters extend it, following 3b's `dashedFraction`
pattern:

- `labelFraction` — **repeating** root-level labels ("WC", "Kitchen"), the
  distribution the cache hits.
- `attributedInstanceFraction` — a **unique** ATTRIB per instance ("T-0001"), the
  distribution the cache misses.

The measurement corpus is explicit rather than "roughly":
`labelFraction: 0.05` over root entities, drawn from a fixed vocabulary of about
twenty label strings, plus `attributedInstanceFraction: 0.5` over the corpus's
20,000 instances, each ATTRIB carrying a string unique to its instance. At
50,000 entities that is about 2,500 repeating labels and 10,000 unique
attributes — roughly 10% of the drawing is text, with the unique share
deliberately the larger of the two, because that is the share a floor plan
actually has and it is the share the cache cannot help.

Both sources, because one alone hides the other: all-unique makes the cache look
dead, all-repeating makes it look perfect, and which one a reader sees would be
chosen by the fixture author rather than by the measurement. Both fractions
default to zero, so every existing measurement stays comparable.

### Measured rows

- `skippedTextCount` — must be 0 on the measurement corpus.
- paragraph layouts per frame, first frame against a repeat frame at the same
  camera.
- peak live `Paragraph` count.
- text draw ops per frame.
- build and raster p50/p95 with text on and off — same corpus, same camera, one
  flag apart.
- cache hit rate, **split by source**, since separating those two distributions is
  the whole reason the corpus has both.

## Testing

Plan 2's lesson governs: defects here surface through differential testing against
a brute-force reference and through mutation, not through reading, and the
dominant failure is a fixture that cannot tell right from wrong.

### Mutants that must be killed, and the fixture property each one needs

| Mutant | Required fixture property |
|---|---|
| drop `widthFactor` from the local transform | a style with `widthFactor != 1` **and** an entity overriding it |
| read NaN inheritance as 0 instead of the style's value | style `widthFactor != 1` with the entity holding NaN — a fixture where everything is 1.0 hides this |
| ignore `fixedHeight` | a style with `fixedHeight != 0` and an entity whose `scalars[0]` differs |
| treat 72=1 (centre) as 72=0 (left) | a non-empty string with asymmetric alignment, asserted on the **box position** (extents), not only on pixels |
| swap 73 top and baseline | a metric model whose ascent differs from its descent |
| flip the sign of rotation | an angle that is not a multiple of pi — 0 and pi are degenerate |
| drop `textStyle` from the cache key | the same string under two styles with different fonts |
| counter-transform mirrored text | text inside a mirrored instance; the golden pins faithful mirroring |
| return `HitKind.vertex` for a text pick | a pointer inside the box but far from the anchor |
| compute the box without `widthFactor` | `widthFactor != 1` and a pick near the far edge |
| swap the measurer mid-life without rebuilding the index | the measurer-dependence test |

### The tests that carry the design

- **Differential, text on**: the reference walk against the production painter
  over the text-heavy corpus, plus the existing non-vacuity test.
- **Reference query differential**: text picking against the brute-force query.
- **Measurer dependence**: the same document under `MetricModelMeasurer` and under
  a second, deliberately different metric model yields different extents and
  different boxes — the test that proves text metrics actually reach the engine.
- **Codec**: determinism, idempotence and unknown-preservation over the new keys.
- **Slot lifetime**: delete → undo → redo → purge with text and tag columns,
  asserting both reset to `''` on free.
- **Goldens**: one text ladder (alignments, rotation, width factor, oblique) and
  one mirrored-instance case. Goldens pin appearance intent; they are not the
  oracle for cache or geometry correctness.

## Exit gate

**Failable, and machine-independent by construction:**

| Row | Threshold |
|---|---|
| a repeat frame at the **working-set** camera | **zero** new paragraph layouts |
| peak live paragraphs | <= 512 |
| `skippedTextCount` on the measurement corpus | 0 |
| differential and non-vacuity, text on | pass |
| reference-query differential, text picking | pass |
| engine and widget suites, analyze, format | pass and clean |
| `dart run benchmark/query_throughput.dart` | unchanged in shape; `snap at dirty threshold` remains the known carried failure from Plan 2 |

**Why the zero-layout row names the working-set camera, and does not name the
whole-drawing one.** The measurement corpus holds about 12,500 text entities at
50,000, roughly 10,000 of them carrying a unique string. A 512-entry cache cannot
hold that, so a whole-drawing camera thrashes it by construction: every frame
evicts entries it will ask for again, and a repeat frame performs thousands of
layouts. Writing the row without a camera would make the gate contradict its own
corpus, and raising the bound until it passed would only restore the unbounded
cache the bound exists to prevent.

So the row is scoped to the camera where the visible text fits — the working set,
which is what an editing session actually looks at — and the whole-drawing
thrash becomes a **recorded number**: layouts per repeat frame, and evictions per
frame, at both corpus sizes. That number is the input to 3e's text-LOD decision,
which is the mechanism that would fix it. 3c is not the plan that decides it;
3c is the plan that measures it honestly enough for 3e to decide.

**Recorded, not failable:** text's time cost, with its scope named — the corpus,
the camera, the entity count and the machine — exactly as 3b recorded its dash
cost, plus the thrash numbers above. A threshold on an unavoidable cost asserts
that the cost is optional. Text must be drawn; the number is the deliverable.

If a failable row misses, the number is recorded and the plan stops, as 3b's own
Task 4 stop clause did.

## What 3c owes the plans after it

- **3d (fills):** nothing new. 3b already recorded that 3d inherits no batching
  mechanism, only the ordinary one-call-per-primitive sink.
- **3e (the caches):** the text cost number at both corpus sizes, the cache hit
  rates split by source, and the LOD decision left open with a measurement behind
  it. Also the fact that text needs **no** scale-band invalidation axis, which is
  one axis fewer than dashes gave it.
- **Plan 4:** text is now pickable as `HitKind.fill`, so a select tool gets it for
  free; editing a text's rotation or alignment still goes through
  remove-then-add until an in-place geometry command exists.

## Risks

| Risk | Where it is addressed |
|---|---|
| paragraph layout dominates on text-heavy plans | the layout cache, its 512 bound, the two-source corpus, and the recorded cost |
| a font-dependent feature cannot be verified deterministically | the op-level differential oracle plus the deterministic metric model; goldens carry the glyphs |
| the schema bump strands version-3 documents | recorded and accepted; Plan 5 owns the migration chain |
| the corpus stays a floor and the measurement means nothing | `labelFraction` and `attributedInstanceFraction`, and `skippedTextCount == 0` as a failable row |
| a fixture symmetric in width factor, height or alignment hides an inheritance defect | the mutant table's right-hand column is the fixture specification |
| text metrics never actually reach the engine | the measurer-dependence test, which fails if boxes are measurer-independent |
