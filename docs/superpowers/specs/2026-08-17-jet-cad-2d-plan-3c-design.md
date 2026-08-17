# jet_cad_2d Plan 3c — Text

**Status:** approved 2026-08-17, revised after two review passes
**Parent:** [2026-07-27-jet-cad-2d-architecture-design.md](2026-07-27-jet-cad-2d-architecture-design.md)
**Carried in from:** [2026-08-10-jet-cad-2d-plan-3b-design.md](2026-08-10-jet-cad-2d-plan-3b-design.md), "Carried to Plan 3c"
**Written against:** `main` at `e338754` (Plans 1, 2, 3a and 3b merged); the
first draft of this spec is `ff33dfc`, and every fact below was re-verified
against the tree during the revision.

## Summary

Text is the product's payload: a table number and a room label are what the user
reads. Two plans in a row have recorded it as a *floor* rather than a
measurement — `skippedTextCount` is 300 entities per whole-drawing frame at both
corpus sizes, because `generate_document` caps text at
`min(300, rootEntityCount ~/ 100)`. That is 0.06% of a 500,000-entity corpus and
0.6% of a 50,000-entity one; 3b's note quotes the smaller figure for both. 3c
closes it.

One plan, two phases, and the order is not negotiable:

| Phase | Contents |
|---|---|
| **A — engine** | string and tag columns, a `textStyle` handle column, a packed text-attribute column, the attributes in `scalars`, codec plus a schema bump, `SetEntityTextCommand`, the `TextMetrics` seam, a deterministic `MetricModelMeasurer`, one resolution point for box geometry, `HitKind.fill` hit-testing with the same rule in the brute-force reference query, and the corpus extension |
| **B — render** | `FlutterTextMeasurer`, the painter's text path, the paragraph cache, the mirrored-text and attribute-ladder goldens, rig counters, and the measurement note |

Phase A comes first because `TextMeasurer` is currently a seam with nothing to
measure: no measurer test can be written against a document that stores no text.

## Non-goals

- **MTEXT.** Multi-line text with a declared subset of inline formatting codes is
  its own subsystem — a code parser, wrapping layout, and preservation of the
  codes it does not implement. It gets its own plan. The product's payload is
  single-line.
- **DXF 72=3 ("aligned") and 72=5 ("fit").** Both need two points and stretch or
  squeeze the text to reach the second. The model carries the code so a future
  importer round-trips it; **`resolveTextAttributes` falls back to left
  alignment** and the painter emits the `Diagnostic`. The fallback lives in the
  resolver, not in the painter, or the box and the glyphs would disagree for
  exactly those entities — see [One resolution point](#one-resolution-point).

  **The code round-trips; the geometry does not.** These two codes are the one
  case that needs a second stored point, the entity stores one, and entity-level
  unknown-key preservation does not exist (fact 9), so the second point is lost
  rather than preserved. That is owed to the DXF plan, which must either add the
  second point to the payload for these two codes or reject them at import with a
  `Diagnostic`. Recorded rather than silently deferred.
- **Text LOD.** Skipping glyphs below a screen-size threshold is the text analogue
  of 3b's dash collapse floor. 3c measures the cost; 3e decides, because 3e is
  where the cache that changes the answer lands.
- Fills and hatch (3d), the definition and tile picture caches,
  `documentRevision`, and the 16.6 ms gate (3e).
- An in-place geometry command. 3b recorded that none exists and that editing is
  remove-then-add; Plan 4 changes that, not 3c.
- **Cap-height fidelity against a reference application.** 3c declares the ratio
  it uses and records the deviation as a known appearance gap; comparing against
  AutoCAD's own rendering belongs to the plan that acquires the real-file corpus.

## What the tree constrains

Fourteen facts, each read out of the tree. Facts 10 to 14 were added after the
third review pass; each one changed a decision below.

1. **`EntityRecord` stores no text.** Its fields are `handle, owner, kind, layer,
   linetype, linetypeScale, geomIndex, color, lineweight, transparency, flags`
   (`entity_store.dart:53-65`).
2. **Every store column is a typed list** — `Uint8List`, `Uint32List`,
   `Float64List`, `Int16List`, `Int32List` (`entity_store.dart:177-191`), each
   reallocated in **`_ensureCapacity`** with `..setAll(0, _column)`
   (`entity_store.dart:312-329`). `EntityRecord` also carries `operator ==`
   (`:143`), `hashCode` (`:158`) and `copyWith`, all three of which the four new
   fields must join: command inverses and the codec's idempotence tests compare
   records.
3. **`entityBounds` has four production call sites**, not two:
   `draft_document.dart:226`, `container_index.dart:93`,
   `spatial_index.dart:2358` — the incremental dirty-overlay path — and
   `reference_walk.dart:108` in the widget package, which is the brute-force
   reference the differential oracle depends on. All four change. Test call sites
   change too: `corpus.dart:632`, `reference_query.dart:210` and `:805`,
   `extents_test.dart`, `snap_centre_index_test.dart:120`.
4. **The painter counts text and skips it** (`draft_painter.dart:597-599`), and a
   test asserts the count is non-zero and folds it into a count identity
   (`draft_painter_root_test.dart:287-289`). Both flip in this plan.
5. **Text picks as an anchor vertex.** One `switch` case covers `point`, `text`
   and `attrib` (`spatial_index.dart:765-778`). Removing text from vertex picking
   means splitting that case so `point` keeps its behaviour.
6. **`jsonEncode` rejects non-finite doubles.** Verified:
   `JsonUnsupportedObjectError: Converting object to an encodable object failed:
   NaN`. `GeometryPayload.toJson` writes `scalars.toList()`
   (`geometry_store.dart:44-47`) into a bare `jsonEncode`
   (`json_codec.dart:84`) with no `toEncodable` hook.
7. **`listEquals` compares with `!=`** (`list_equality.dart:7-14`), so a NaN in
   `scalars` also breaks `GeometryPayload ==`, which commands and the codec's
   idempotence tests rely on. Facts 6 and 7 together are why this plan does not
   encode inheritance as NaN — see [Inheritance is a bitmask](#inheritance-is-a-bitmask-not-nan).
8. **The codec accepts every version at or below the current one**:
   `version < 1 || version > kSchemaVersion` throws (`json_codec.dart:103`). A
   version-3 document therefore loads under a build that writes 4, provided
   `fromJson` defaults absent keys.
9. **`EntityRecord.fromJson` drops unknown keys** (`entity_store.dart:123-140`).
   Unknown-preservation today is document-level only (`unknownDocumentFields`,
   pinned by `preserve_unknown_test.dart:51-58`).
10. **A text entity written today carries exactly one scalar.**
    `_addFloorText` writes `scalars: [100.0 + random.nextDouble() * 200.0]`
    (`generate_document.dart:535`), and `entityBounds` already defends with
    `payload.scalars.isEmpty ? 0 : payload.scalars[0]`. Reading `scalars[1..3]`
    on any existing document is a `RangeError`.
11. **`ui.Paragraph` bakes its colour, font and size at build time**, and
    `Canvas.drawParagraph(paragraph, offset)` takes no `Paint`. `ResolvedStyle`
    carries `argb` with alpha derived from transparency
    (`resolved_style.dart:16-19`), and the measurement corpus sets
    `layerCount: 8` with `byBlockFraction: 0.3` (`rig_support.dart:53-64`), so
    the same string genuinely arrives in several colours.
12. **`textMeasurer` is a constructor argument** (`draft_document.dart:58`), and
    its own doc comment says taking it at construction "removes the stale-cache
    hazard by construction". It therefore cannot look a table record up: it
    exists before the document does.
13. **`CanvasDrawSink` holds one reusable `Float64List(16)`** (`:51`) filled by
    `_matrix4OfResidual` (`:144`) and latched by `_transformPushed`
    (`:55`, `:83-96`). A second matrix cannot be conjured per draw without
    allocating.
14. **`rigCorpus` is shared** (`rig_support.dart:53-64`) and is what every 3a and
    3b measurement ran against, with `workingSetCamera` a 3000x2250 window over a
    60000x40000 drawing.

Two more, about the layers this design touches:

- **There is no `rebase.dart`, and no `Matrix4` constructor in either 2D
  package.** The residual is written into one reused `Float64List(16)` in
  `CanvasDrawSink` (`canvas_draw_sink.dart:51`, `:142-152`) and handed to
  `canvas.transform`. That file is the single place a matrix is built, and text
  does not change it.
- **`TextStyleRecord`** carries `fontFamily`, `widthFactor`, `obliqueAngle`,
  `fixedHeight` ("Zero means the height is supplied per text entity"), `isShx`
  and `shxFileName` (`tables.dart:213-240`).
- **ATTRIB entities are already indexed** in the root leaf tree under the
  instance's composed transform (`container_index.dart:208-210`), reachable as
  `transformOfLeaf(slot)`. `ConvenienceQueries.attributesOf` is a full store scan
  and must never be called on the frame path.

## Decisions carried in, not to be relitigated

Draw order is ascending handle value. The frame path allocates nothing in steady
state. Geometric *decisions* use `Tolerance`; *stored value* comparisons are
exact. Mirrored blocks render text faithfully mirrored in v1.

## Phase A — the model

### Two string columns

`_text` and `_tag`, slot-parallel `List<String>`, `''` for non-text kinds.
`_ensureCapacity` follows the other columns' shape — `List<String>.filled(capacity,
'')` then `..setAll(0, _text)`, the same call the typed columns use — and `free`
resets both to `''`, which the existing slot-lifetime tests already walk.

Interning into a pool with a `Uint32List` index column was considered and
rejected for now: it would preserve the all-typed-list homogeneity and make the
cache key an int, but it adds a refcount to the slot lifetime — the one area
where Plan 1's mutation testing actually found defects — and Dart memoises
`String.hashCode`, so the key is not the reason to do it. Recorded as an
available optimisation: two reference arrays at 500k entities is roughly 8 MB.

### One handle column, one packed attribute column

- `_textStyle`: `Uint32List`, defaulting to `ReservedHandles.standardTextStyle`,
  which every call site hard-codes today.
- `_textAttrs`: `Uint16List`, laid out as

```
bits 0-3   horizontal justification   DXF group 72
bits 4-7   vertical justification     DXF group 73 for TEXT, group 74 for ATTRIB
bit  8     widthFactor is overridden
bit  9     obliqueAngle is overridden
```

The vertical code's group number differs by kind and the column's doc comment
must say so: for an ATTRIB, group 73 is *field length*, not justification. Naming
it "73" would hand Plan 5's importer a wrong mapping.

`72 = 4` ("middle") is supported, and DXF ignores the vertical code when it is
set; `resolveTextAttributes` enforces that rather than leaving it to callers.

### Inheritance is a bitmask, not NaN

The first draft encoded "inherit from the style" as NaN in `scalars`, on the
precedent of `DirtyList`, which uses NaN for "no centre". That precedent does not
transfer, and the reason is two verified facts: `jsonEncode` throws on NaN
(fact 6), so the first entity inheriting a width factor would make **save fail
outright**; and `listEquals` compares with `!=` (fact 7), so NaN also breaks
`GeometryPayload ==`, which command inverses and the codec's idempotence tests
depend on. `DirtyList`'s NaN is in-memory and never serialised or compared, which
is why it is safe there and not here.

Bits 8 and 9 of `_textAttrs` carry the override instead. Every scalar stays
finite, JSON stays encodable, equality stays exact, and the check is a bit test
rather than an arithmetic accident.

### The attributes live in `scalars`

```
scalars[0] = height          (already there)
scalars[1] = rotation        (radians)
scalars[2] = widthFactor     read only when bit 8 is set
scalars[3] = obliqueAngle    read only when bit 9 is set
```

**Effective height** is `style.fixedHeight != 0 ? style.fixedHeight : scalars[0]`,
DXF's rule and what `fixedHeight`'s own doc comment states.

**The `transformedBy` trap is documented, not moved.**
`GeometryPayload.transformedBy` copies `scalars` verbatim and takes no
`EntityKind` (`geometry_store.dart:32-42`), with a test pinning that behaviour
(`geometry_store_test.dart:45`). Rotation in `scalars[1]` means a future rotate
command must rotate it explicitly. 3c pays that down by documenting what
`scalars` means per kind, warning on `transformedBy` that scalars are the
caller's responsibility, and adding a test that makes the trap visible — a scaled
circle and a rotated text — rather than by changing command semantics, which is
Plan 4's subject.

### The stored point is the point DXF would use

DXF ignores group 10 when the justification is anything but left/baseline; the
real coordinate is then the alignment point, group 11/21. So the entity stores
**one** point, and which one it is follows from the codes: the alignment point
when justification is non-default, the insertion point otherwise.

This keeps import and export exact and measurer-independent. The alternative —
always storing group 10 and deriving the other by subtracting a measured offset —
would make a round-trip depend on the font stack that happened to be installed,
which is the same class of mistake as storing a measured box.

### Codec and the schema bump

`EntityRecord.toJson` gains four keys in fixed order after `flags`: `text`,
`tag`, `textStyle`, `textAttrs`. `kSchemaVersion` goes **3 → 4**, because the
on-disk shape changes.

**Nothing is stranded, and no debt goes to Plan 5.** Fact 8: the codec accepts
any version at or below the current one, so a version-3 document loads under a
version-4 build as soon as `fromJson` defaults the absent keys —
`text ?? ''`, `tag ?? ''`, `textStyle ?? standardTextStyle`, `textAttrs ?? 0`.
Those four defaults *are* the v3→v4 migration. The first draft of this spec
proposed accepting a readability gap in order to obey `schema_version.dart`'s
"add a migration" comment, which inverted what that comment is for.

**The record keys are not the whole migration — `scalars` is the other half.**
Fact 10: an existing text entity carries one scalar, so `resolveTextAttributes`
reading `scalars[1..3]` on a version-3 document throws `RangeError`. The rule is
**read defensively**, through one helper that returns a declared default past the
end of the array, and the payload is **not** rewritten on load. Padding on load
would mutate geometry the file did not contain and would make
`save(load(save(d))) == save(d)` compare a padded payload against an unpadded
one; reading defensively leaves old documents byte-identical through a round-trip.
A version-3 fixture in the codec tests pins this.

Determinism, idempotence and the round-trip property all extend to the new keys.
**Entity-level unknown-key preservation is explicitly out of scope**: fact 9 says
it does not exist today, only document-level preservation does, and adding it is a
separate change with its own tests. This plan does not claim it and does not add
it.

### One command

`SetEntityTextCommand(handle, text, tag)`, whose inverse restores the previous
pair. `AddEntityCommand` and `RemoveEntityCommand` carry an `EntityRecord`, so
they carry the new fields for free.

**Changing a string changes the box, so the command must dirty the index** exactly
as a geometry edit does — it emits `touched` with the entity's handle and the
index re-derives that leaf's box through the incremental path. The
overlay-equals-rebuild test therefore mutates **through the command**; mutating a
column directly would test a path no caller uses and would pass while the command
was broken.

## Phase A — measurement, and the simplification it produces

**Only the string and the style affect layout.** The rest are transforms:

| Attribute | What it is |
|---|---|
| height | uniform scale |
| rotation | rotation |
| widthFactor | horizontal scale — the parent spec is explicit that this is a canvas scale, not a font feature |
| obliqueAngle | shear |
| justification | a translation computed from the metrics |

So a `Paragraph` is laid out **once at a nominal size** —
`kNominalTextPixels = 100.0` — and everything else enters the matrix.

Two consequences, both load-bearing:

1. **The cache key carries no height, angle or width factor.** The parent spec
   assumed a "resolved height band"; no band is needed, and zoom never
   invalidates a text entry. 3b named a new invalidation axis for dashes, whose
   period is a function of screen scale; text's equivalent axis never comes into
   existence.
2. One `Paragraph` serves the same string at every height, angle and width factor
   — but **not** at every colour. See
   [The cache key includes the colour](#the-cache-key-includes-the-colour).

**The scale factor, written out, because getting it wrong is invisible.** The
matrix scale is `effectiveHeight / metrics.capHeight`, with the metrics taken at
`kNominalTextPixels`, so `metrics.capHeight` is
`kCapHeightRatio * kNominalTextPixels` for the Flutter measurer. Laying the
paragraph out at the *effective* em size instead — `effectiveHeight /
kCapHeightRatio` — renders **correctly** and silently destroys the cache, because
the key would then have to carry the height. Every golden and every arithmetic
expectation passes under that mistake, and the only row that catches it is the
zero-new-layouts gate row.

### Cap height, and the ratio this plan declares

DXF's text height is **cap height** — the height of a capital letter — while a
font's `fontSize` is the em size. Mapping one to the other directly renders every
glyph oversized by whatever the font's cap ratio is, typically 25-40%, and the
error propagates into vertical justification, because "middle" and "top"
reference cap height too.

So `TextMetrics` carries `capHeight`, and the em size used for layout is
`effectiveHeight / kCapHeightRatio` with **`kCapHeightRatio = 0.7`** as a
declared constant.

`MetricModelMeasurer` declares its ratio exactly, so pure-Dart arithmetic
expectations are computable. `FlutterTextMeasurer` uses the same constant rather
than a per-font measurement, because `dart:ui` exposes no cap height:
`computeLineMetrics` gives ascent and descent only. **That approximation is a
declared appearance deviation**, recorded in the plan and visible in the
attribute-ladder golden, and closing it needs a reference to compare against —
which is the real-file corpus plan, not this one.

```dart
/// Font metrics at the nominal size: unrotated, unaligned, no width factor.
class TextMetrics {
  const TextMetrics({
    required this.advanceWidth,
    required this.ascent,
    required this.descent,
    required this.capHeight,
  });

  final double advanceWidth;
  final double ascent;
  final double descent;
  final double capHeight;

  static const TextMetrics zero =
      TextMetrics(advanceWidth: 0, ascent: 0, descent: 0, capHeight: 0);
}

abstract class TextMeasurer {
  /// Takes the record, not a handle: `fontFamily`, `widthFactor` and
  /// `obliqueAngle` live on it, and a measurer is constructed *before* the
  /// document (fact 12), so it cannot look one up.
  TextMetrics measure({required String text, required TextStyleRecord style});
}
```

**`measure` must not allocate on a cache hit.** `TextMetrics` is a class, so a
naive implementation allocates one per call — and the text pick path calls it per
candidate, which would break `query_allocation_test`, the harness Plan 2 built to
hold the zero-allocation budget. Both real measurers therefore memoise the
`TextMetrics` object beside the entry they already keep, and a hit returns the
same instance. This is a gate row, not a nicety.

**Editing a `TextStyleRecord` invalidates the paragraph cache and the index.** The
cache is keyed by the style *handle* while the metrics come from the *record*, so
changing the record without invalidating both leaves stale boxes and stale glyphs
— the same hazard, and the same rule, as the measurer being fixed for a
document's lifetime. No command mutates a table record today (`query_filter.dart`
records the same gap for `FilterEvaluator.invalidate`), so 3c states the rule and
the first command that breaks it owns the invalidation.

Three implementations, with distinct jobs:

- `FlutterTextMeasurer` — `ParagraphBuilder` plus `computeLineMetrics`, backed by
  the same cache the painter draws from. One cache, two consumers; two caches
  would be two truths about one string.
- `MetricModelMeasurer` — deterministic, advance-ratio, no font stack, in the pure
  package. Pure-Dart bounds, pick, snap, extents and differential tests run
  against it. **Its ascent must differ from its descent**, or every vertical
  justification defect is invisible.
- `InsertionPointMeasurer` — stays, now returning `TextMetrics.zero`, and its doc
  comment keeps saying what it is: a declared lower bound.

### One resolution point

```dart
// lib/src/document/text_geometry.dart — these two functions and nothing else.

/// Everything the attributes resolve to, with the style's defaults, fixedHeight,
/// the 72=4 rule and the aligned/fit fallback already applied.
ResolvedTextAttributes resolveTextAttributes(
    GeometryPayload payload, int textAttrs, TextStyleRecord style);

/// Composed in this order, innermost first:
///   oblique shear  ->  width-factor x-scale  ->  height scale
///   ->  justification offset  ->  rotation  ->  translation to the stored point
Transform2 textLocalTransform(
    ResolvedTextAttributes attrs, TextMetrics metrics, Vector2 anchor);
```

The composition order is written out because **shear and x-scale do not
commute**: `w*(x + k*y)` is not `w*x + k*y`. Shearing first and scaling second is
what makes the width factor scale the already-slanted glyph, which is the DXF
reading; the attribute-ladder golden is the evidence, and a mutant that swaps the
two must be killed by it.

`entityBounds` takes the `TextStyleRecord`, not only a style handle: `fixedHeight`
and the override bits cannot be resolved from a handle, and having a bounds
function reach into `doc.tables` would give it a document dependency it does not
otherwise have. **All four call sites** (fact 3) pass the record down, including
`spatial_index.dart:2358` — the incremental path an editing session spends all
its time on. Leave that one hard-coding `text: ''` and an edited text keeps a
degenerate point box while a rebuilt one gets the laid-out box, which is exactly
"the box is not where the glyphs are", on the hottest path. A failable test pins
it: mutate a text entity, then assert the dirty-overlay box equals the box after
`rebuildAll()`.

The painter calls the same two functions. That is what makes "the box is where
the glyphs are" structural rather than maintained by hand in two files.

**The measurer is fixed for a document's lifetime.** Leaf boxes are built with
`doc.textMeasurer`, so swapping it means rebuilding the index. `DraftDocument`
takes it at construction, which gives the rule for free — but an unwritten rule is
not a rule, and the measurer-dependence test is what holds it.

## Phase A — hit-testing

The narrow phase transforms the query point into text-local space and tests the
box built from the metrics, reporting **`HitKind.fill`** — the parent spec's rule,
and the kind already exists, produced today for closed-polyline and circle
interiors. The shared `point`/`text`/`attrib` case (fact 5) splits so `point`
keeps vertex picking.

The insertion point stops being a pick kind and stays a snap kind
(`SnapKind.insertion`). Text corners are not snap candidates; AutoCAD does not
offer them either.

**`NarrowPhaseSlack` is zero for text**: the narrow phase never reaches outside
the box, and the box is exact.

The pick path measures through `doc.textMeasurer`, the same measurer that built
the leaf boxes. Under `InsertionPointMeasurer` the box is degenerate and text is
therefore unpickable — consistent with what that measurer declares itself to be,
and stated here so it is not discovered as a bug.

The brute-force reference query implements the same rule independently, so the
differential corpus covers text picking for the first time.

## Phase B — the render path

`DrawSink` gains one op:

```dart
void drawText(String text, Handle style, Transform2 local, ResolvedStyle resolved);
```

Both sinks implement it. `CanvasDrawSink` resolves the string through the
paragraph cache and draws it; `RecordingDrawSink` records the op's fields.

### The cache key includes the colour

`ui.Paragraph` bakes colour, font and size when it is built, and
`Canvas.drawParagraph` takes no `Paint` (fact 11). A `Paragraph` is a baked raster
recipe, not a re-parameterisable object. So the key is

```
(string, textStyle handle, ResolvedStyle.argb)
```

Colour is not a rounding error in the key: the measurement corpus runs
`layerCount: 8` with `byBlockFraction: 0.3`, so the same label string genuinely
arrives in several colours, and a key without `argb` would collapse them into one
entry and draw some of them in the wrong colour — a wrong picture, not a slow one.

The alternative, drawing one white paragraph under
`saveLayer` plus a `ColorFilter.srcIn`, is **rejected**: it costs an offscreen
layer per text entity on the raster path this plan is trying not to make worse,
and 3b's raster profile already showed raster time is the binding cost. A
paragraph per colour is cheaper than a layer per draw.

This cascades, deliberately: the 512 bound, the hit-rate rows, the zero-layout
gate row and the mutant table all reckon with colour as part of the key.

### Getting the matrix onto the canvas

`CanvasDrawSink` holds **one** reusable `Float64List(16)`, written by
`_matrix4OfResidual` and latched by `_transformPushed` (fact 13). Text needs
`residual ∘ local` on the canvas, which the latched residual alone cannot express.
So `drawText` pops the latched residual, then, inside `canvas.save()` /
`canvas.restore()`, pushes a **second reusable `Float64List(16)`** whose six terms
are written in place from the composed transform.

A second buffer rather than composing `Transform2` values, because
`Transform2.multiply` returns a new object: one allocation per text entity per
frame, on exactly the path whose budget is zero. The first draft of this spec said
text "does not change `canvas_draw_sink.dart`"; that was wrong.

### The oracle, and what it does not see

**Op comparison keeps working with text on.** 3a's `differential.dart` compares
*ops*, not pixels — `DrawnItem`'s kind, style, points, radius, start and sweep at
`kScreenTolerance = 1e-6`. For text the compared quantity is the draw *request*,
so a font-dependent feature is verified in a font-independent way.

The flattening has to be written down, though, because a text op is not a point
list:

- `kind` is `'text'`; the string compares **exactly**; the style handle compares
  exactly; `ResolvedStyle` compares by its own `==`.
- the transform compares as six terms, and **the tolerance is not uniform**:
  `1e-6` is a screen-pixel tolerance, which is right for `e` and `f` and
  meaningless for the unitless `a`, `b`, `c`, `d`. Those four compare with a
  **relative** tolerance of `1e-9`, the scale-free counterpart.

Without that split the row is either vacuous on translation or spuriously red on
scale.

**But the oracle is blind inside `textLocalTransform`.** Both walks call the same
helper, so op-equality for the transform holds trivially: it proves the same
entity was reached with the same style, not that the width factor or the rotation
is right. The killers for those mutants are therefore **hand-computed arithmetic
expectations against `MetricModelMeasurer`** — one expectation per attribute, on
the box and on the transform, computed from the model's declared advance ratio,
ascent, descent and cap ratio. The golden is corroboration, not the oracle.

**The paragraph cache** is `(string, textStyle, argb) -> (Paragraph, TextMetrics)`,
LRU, bounded at **512 live entries**, and **evicting an entry calls
`Paragraph.dispose()`** — the object holds native glyph memory, so a bound on the
count is not a bound on the memory unless eviction releases it. The metrics ride
in the same entry so a hit allocates nothing.

**Mirrored text** needs no code: a mirroring transform mirrors the glyphs, and v1
renders that faithfully. A golden pins it so a later "fix" cannot quietly
introduce a counter-transform.

## The corpus, and why it has two text sources

Today `generate_document` produces `min(300, rootEntityCount ~/ 100)` texts. Two
off-by-default parameters extend it, following 3b's `dashedFraction` pattern:

- **`labelFraction`** (default 0) — **repeating** labels drawn from a fixed
  twenty-string vocabulary, taken **out of** the root entity budget rather than
  added beyond it. This is the distribution the cache hits.
- **`attributedInstanceFraction`** (default 0) — one **unique** ATTRIB per
  selected instance ("T-0001"), **additive**, since an ATTRIB is a new leaf owned
  by an instance node. This is the distribution the cache misses.

The measurement corpus uses `labelFraction: 0.02` and
`attributedInstanceFraction: 0.2`. At `entityCount: 50000` with 20,000 instances
that is roughly 900 repeating labels and 4,000 unique attributes — about 4,900
text entities in roughly 50,900 leaves, so **about 10% of the drawing is text,
with 80% of that text unique**. Unique dominates deliberately: that is the shape a
floor plan has, and it is the share the cache cannot help.

The legacy `min(300, ...)` texts are unchanged when both fractions are zero, so
every existing measurement stays comparable.

**The measurement corpus is a new function, not a change to `rigCorpus`.**
`rigCorpus` (fact 14) is what every 3a and 3b number was measured against, and
`labelFraction` comes out of the root budget, so switching it on inside
`rigCorpus` would move the line, polyline, circle and arc counts and retire 3b's
dash and canvas-call baselines as a side effect. Instead a `textRigCorpus` sits
beside it: `rigCorpus`'s arguments plus the two fractions. The "text on against
text off" comparison then runs on `textRigCorpus` both times, one painter flag
apart, which is the honest comparison anyway — same document, same camera.

Four mechanics the corpus file's own rules require:

1. **The extensions draw from the existing shared `extra` stream**
   (`generate_document.dart:96`, `math.Random(0x5EEDED)`), and **draw nothing
   while they are off**. There is one such stream, not one per extension, and the
   consequence has to be owned: turning `labelFraction` on shifts every
   `attributedInstanceFraction` draw, so the two fractions are **not**
   independently reproducible. Fixtures name both values together or neither.
2. `generate_document_test.dart:49-52` pins two FNV-1a fingerprints over the full
   serialisation, and its comment calls them "the whole guard" on corpus
   extensions: one stray `nextDouble()` at a default setting shifts every
   subsequent value in the document.
3. **The four new `EntityRecord.toJson` keys move both fingerprints.** They are
   therefore re-baselined in the **codec commit, in Phase A**, before either
   fraction lands. Re-baselining in the same commit that adds the fractions would
   ship the corpus change together with the voiding of its own guard.
4. The structural assertions beside the fingerprints must still hold at defaults:
   one layer, **three linetypes**, and every entity `ByLayer` on layer zero with
   the by-layer linetype (`generate_document_test.dart:56-66`).

### Measured rows

- `skippedTextCount` — must be 0 on the measurement corpus.
- paragraph layouts per frame: first frame against a repeat frame, at both cameras.
- **evictions per frame**, at both cameras.
- peak live `Paragraph` count.
- **distinct visible cache keys — `(string, style, colour)` — at the working-set
  camera**, measured before the exit gate is finalised; see below.
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

| Mutant | Required fixture property | Killer |
|---|---|---|
| drop `widthFactor` from the local transform | a style with `widthFactor != 1` **and** an entity overriding it | arithmetic expectation |
| read an unset override bit as "overridden" | style `widthFactor != 1` with the entity's bit 8 clear — a fixture where everything is 1.0 hides this | arithmetic expectation |
| swap the oblique shear and the width-factor scale | `widthFactor != 1` **and** `obliqueAngle != 0` together — either alone commutes | attribute-ladder golden |
| ignore `fixedHeight` | a style with `fixedHeight != 0` and an entity whose `scalars[0]` differs | arithmetic expectation |
| map height to em size instead of dividing by `kCapHeightRatio` | any text; the model's ratio is not 1 | arithmetic expectation |
| treat 72=1 (centre) as 72=0 (left) | a non-empty string, asserted on the **box position** (extents), not only on pixels | extents test |
| honour the vertical code when 72=4 | an entity with 72=4 and a non-default vertical code | arithmetic expectation |
| swap vertical top and baseline | a metric model whose ascent differs from its descent | arithmetic expectation |
| flip the sign of rotation | an angle that is not a multiple of pi — 0 and pi are degenerate | arithmetic expectation |
| use group 73 as ATTRIB justification | an ATTRIB with a field length that would decode as a different justification | codec test |
| drop `textStyle` from the cache key | the same string under two styles with different fonts | cache test |
| drop `argb` from the cache key | the same string on two layers of different colour, or one `ByBlock` under two instance colours | cache test plus a colour golden |
| lay the paragraph out at the effective em size instead of the nominal one | any two text entities sharing a string at different heights | zero-new-layouts row — no golden or arithmetic test can see this |
| allocate a fresh `TextMetrics` on a cache hit | a pick sweep over text, under the allocation harness | `query_allocation_test` |
| read `scalars[1..3]` without the defensive default | a version-3 fixture whose text entities carry one scalar | codec test |
| skip the index-dirty notification in `SetEntityTextCommand` | a text edited **through the command** | overlay-equals-rebuild test |
| counter-transform mirrored text | text inside a mirrored instance | mirrored golden |
| return `HitKind.vertex` for a text pick | a pointer inside the box but far from the anchor | pick test |
| leave `spatial_index.dart:2358` hard-coding `text: ''` | an **edited** text entity, so the dirty overlay holds its box | overlay-equals-rebuild test |
| skip `Paragraph.dispose()` on eviction | more distinct strings than the cache bound | eviction test |
| swap the measurer mid-life without rebuilding the index | two metric models that disagree | measurer-dependence test |

### The tests that carry the design

- **Differential, text on**: the reference walk against the production painter
  over the text-heavy corpus, plus the existing non-vacuity test.
- **Reference-query differential**: text picking against the brute-force query.
- **Arithmetic expectations** against `MetricModelMeasurer`: one per attribute, on
  the box and on the local transform. These, not the differential, are what kill
  the attribute mutants.
- **Overlay equals rebuild**: an edited text's dirty-overlay box equals its box
  after `rebuildAll()`.
- **Measurer dependence**: the same document under two deliberately different
  metric models yields different extents and different boxes.
- **Codec**: determinism, idempotence, round-trip, and a version-3 fixture loading
  under the version-4 build with defaults applied.
- **Slot lifetime**: delete → undo → redo → purge with the text and tag columns,
  asserting both reset to `''` on free.
- **Goldens**: an attribute ladder (justifications, rotation, width factor,
  oblique, and the two combined) and one mirrored instance. Goldens pin appearance
  intent; they are not the oracle for geometry or cache correctness.

### Existing tests this plan retires or rewrites

`draft_painter_root_test.dart:287-289` asserts `skippedTextCount > 0` and folds it
into a count identity; both change, deliberately and in the commit that makes text
draw. Any test pinning text-as-vertex picking retires the same way. The corpus
fingerprints are re-baselined once, in the codec commit.

## Exit gate

**Failable, and machine-independent by construction:**

| Row | Threshold |
|---|---|
| a repeat frame at the **working-set** camera | **zero** new paragraph layouts |
| evictions per repeat frame at the working-set camera | **zero** |
| peak live paragraphs | <= 512 |
| `skippedTextCount` on the measurement corpus | 0 |
| differential and non-vacuity, text on | pass |
| reference-query differential, text picking | pass |
| overlay-equals-rebuild for an edited text | pass |
| `query_allocation_test` with text in the corpus | zero allocation in steady state — the metrics cache is what makes this reachable |
| engine and widget suites, analyze, format | pass and clean |
| `dart run benchmark/query_throughput.dart` | unchanged in shape; `snap at dirty threshold` remains the known carried failure from Plan 2 |

`peak live paragraphs <= 512` is close to tautological against an LRU bounded at
512 — it catches retention *outside* the cache and nothing else. The eviction row
is the sharp one, and it is why both are listed.

**The zero-layout row names the working-set camera, and its feasibility is a
number nobody has yet.** The measurement corpus holds about 4,000 unique attribute
strings, and the key is a `(string, style, colour)` triple over eight layers with
30% `ByBlock`, so the number of distinct keys is larger than the number of
distinct strings. If more than 512 of them are visible at the working-set camera,
the row fails by construction — the LRU would evict entries it is about to need
again. Phase A therefore **measures distinct visible keys at that camera before
the row is finalised**, and if the count exceeds the bound, one of the two numbers
moves, with the measurement on the table rather than the row quietly relaxed. The
whole-drawing camera is expected to thrash: it is recorded as layouts and
evictions per repeat frame, and that number is the input to 3e's text-LOD
decision.

**Recorded, not failable:** text's time cost with its scope named — corpus,
camera, entity count, machine — exactly as 3b recorded its dash cost, plus the
thrash numbers and the cap-height deviation. A threshold on an unavoidable cost
asserts the cost is optional. Text must be drawn; the number is the deliverable.

If a failable row misses, the number is recorded and the plan stops, as 3b's own
Task 4 stop clause did.

## What 3c owes the plans after it

- **3d (fills):** nothing new. 3b already recorded that 3d inherits no batching
  mechanism, only the ordinary one-call-per-primitive sink.
- **3e (the caches):** the text cost at both corpus sizes, hit rates split by
  source, the whole-drawing thrash numbers, and the LOD decision left open with a
  measurement behind it. Also that text needs **no** scale-band invalidation axis,
  one axis fewer than dashes.
- **Plan 4:** text is pickable as `HitKind.fill`, so a select tool gets it free;
  editing rotation or justification still goes through remove-then-add until an
  in-place geometry command exists.
- **Plan 5 and the DXF plan:** the vertical justification group differs by kind
  (73 for TEXT, 74 for ATTRIB); the stored point is group 11/21 when
  justification is non-default and group 10 otherwise; **72=3 and 72=5 keep their
  code but lose their second point**, so the importer either adds it to the
  payload or refuses those codes with a `Diagnostic`; `kCapHeightRatio` is an
  approximation awaiting a reference comparison; entity-level unknown-key
  preservation still does not exist; and editing a `TextStyleRecord` must
  invalidate both the paragraph cache and the index, which nothing enforces
  because no command mutates table records yet.

## Risks

| Risk | Where it is addressed |
|---|---|
| paragraph layout dominates on text-heavy plans | the layout cache, its bound, the two-source corpus, the recorded cost |
| a font-dependent feature cannot be verified deterministically | arithmetic expectations against the metric model, the op-level differential, goldens for glyphs |
| the corpus stays a floor and the measurement means nothing | the two fractions, and `skippedTextCount == 0` as a failable row |
| a fixture symmetric in width factor, height or justification hides an inheritance defect | the mutant table's middle column is the fixture specification |
| text metrics never actually reach the engine | the measurer-dependence test |
| the incremental index path keeps degenerate text boxes | the overlay-equals-rebuild test, and all four `entityBounds` call sites named |
| cap height mapped as em size renders every glyph oversized | `kCapHeightRatio`, `TextMetrics.capHeight`, an arithmetic expectation, and a declared deviation |
| the corpus fingerprints are re-baselined in the same commit that changes the corpus | re-baselining is ordered into the codec commit, before the fractions land |
