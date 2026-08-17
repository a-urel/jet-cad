# Carry-forward additions for Plans 3c, 3d and 3e

**Date:** 2026-08-17
**Status:** notes for the designer of each named plan; nothing here is a decision

Six items that the existing carry-forward lists
([3b design](../specs/2026-08-10-jet-cad-2d-plan-3b-design.md), "Carried to Plan
3c / 3d / 3e") name only as topics. Each is a specific trap or an undecided
question inside one of those topics, verified against the tree at `750dba8`.

## Provenance

They come out of an abandoned Plan 3 rendering spec written on 2026-08-17 whose
premise — that nothing in the repository rendered yet — was false: Plan 3a was
merged, its spike had run, and 3b was designed, planned and largely implemented
on the `plan-3b` worktree. That spec was deleted in the same commit that added
this note. Two review passes over it produced items 3, 4, 5 and 6 below; items 1
and 2 came out of reading the shipped code against the parent architecture spec.
Nothing else in it survives, and its constants in particular were wrong against
shipped code (it declared an anisotropy threshold of 1.1 where
`draft_painter.dart:18` ships 2.0, and a fixed `kPixelsPerMm` where
`draft_canvas.dart:60` correctly takes `pixelsPerPaperMm` as a viewport
parameter).

## For Plan 3c — text

### 1. The paragraph layout cache needs a bound, and a row that proves it holds

Every other cache in this architecture is given a number — the parent spec bounds
definition-cache entries per definition, 3a bounds the cull floor. The paragraph
layout cache, keyed by `(string, style handle, resolved height band)`, has none
written anywhere.

A `Paragraph` holds native glyph memory, and a pan across a text-heavy plan
touches every string in the document, so an unbounded cache grows to the whole
document's text. It needs an eviction policy (LRU is the obvious one) with a
declared entry bound, and a measured row: peak live paragraphs during a pan
across the text-heavy corpus.

## For Plan 3d — fills

### 2. `fill.handle < boundary.handle` cannot be achieved by declaration

Draw order is ascending handle value. A region's fill must therefore carry a
lower handle than its boundary, or it paints over its own outline.

Handles are monotonic by creation (`HandleSeed.next`, `handle.dart:61-70`), and
the natural authoring order is *draw the boundary, then hatch it*, which produces
exactly the failing case. A "hatch this existing boundary" command cannot satisfy
the convention without reassigning the boundary's handle, which would break every
reference to it.

So 3d has to choose, and say which:

- give the fill an explicit draw-order key that the painter honours ahead of
  handle order, or
- require the region command to create boundary and fill in one transaction with
  the ordering reserved, and define what happens when a fill is added to a
  boundary that already exists.

A convention the dominant workflow violates is not a convention.

## For Plan 3e — the caches and the two channels

### 3. What bumps `documentRevision` is unspecified, and it does not exist yet

`documentRevision` appears in no source file in the tree. It is part of the cache
key `(definition, StyleContext, scaleBand, documentRevision)` and is described as
"global and rare", but the rule that makes it rare is nowhere written.

If an ordinary entity edit bumps it, every definition picture in the drawing is
discarded on every command, which is precisely the pathology the two-channel
split exists to avoid — and the gate row that tests the split ("one runtime
override toggled per frame → zero picture rebuilds") exercises `overrideChanges`
only, so it would not catch it. 3e must state which mutations bump the revision
(the intent is layer- and style-table edits alone) and add a row that pins the
other direction: a geometry edit inside one definition must not invalidate any
other definition's picture.

### 4. Tile invalidation has a hole for edits inside a definition

`DocChange` carries `Set<Handle> touched` and nothing else — no previous
geometry. Recovering the old position is possible for root-level leaves by
recording, per tile, the handles baked into it as an ascending `Uint32List` (free,
because queries already return in that order) and binary-searching it on every
change, then also invalidating tiles that intersect the touched handles' new
boxes. Both directions are needed, for the reason `_letBoundRecede` exists.

That scheme has a hole. Tiles bake non-overridden instances, so an edit to an
entity *inside a definition* puts a handle in `touched` that appears in no tile's
handle list, and whose new box is in definition-local space rather than world
space. Neither direction fires, and every instance of that definition keeps stale
pixels.

A tile must therefore also record which definitions it baked, and a touched
handle owned by a definition must be mapped through that definition's placements
before the intersection test.

### 5. Baked dashes inherit the scale band's quantisation error

3b computes the dash period in screen space ("The period is computed in screen
space", 3b design). A definition picture is recorded per scale band, so the
moment 3e bakes dashes into pictures the period is quantised to the band
representative and inherits the same relative error as a baked stroke width.

A stroke-width error of that size is close to invisible; a *period* error is not
the same kind of error, because the period beats against segment length — a dash
pattern that no longer divides a wall the way it did one band ago reads as the
pattern shifting. 3e should either argue the error is acceptable with a number,
or give dashes a tighter band than strokes, or keep them out of the baked
picture.

### 6. `InstanceNode` carries two of `StyleContext`'s six fields

`InstanceNode` is `definition, layer, color, transform, visible`
(`node.dart:153-173`). `StyleContext` as the parent spec defines it also carries
`linetype`, `linetypeScale`, `lineweight` and `transparency`, and DXF's INSERT
carries all four (group codes 6, 48, 370, 440).

`StyleContext` is the picture cache key, so adding a field to it later changes
the key, its `hashCode`, and every test keyed on it. If 3e wants those four
fields to come from the instance rather than be inherited unchanged from the
parent context, the model addition belongs before the cache, not after it. If it
wants them inherited, that is a declared round-trip gap and should be written as
one.
