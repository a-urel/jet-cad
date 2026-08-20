# Task 6 report — text picks as `HitKind.fill`

Commit: `6e046f8` (single commit, on `plan-3c`, parent `419d512`).

Suites: `packages/jet_cad_2d` **710 passing** (697 at `419d512`; +9 pick tests,
+4 differential blocks from the new corpus fixture). `packages/jet_cad_2d_flutter`
**123 passing, 1 skip** (unchanged). `dart analyze` and
`dart format --output=none --set-exit-if-changed .` clean in both packages. No
`analysis_options.yaml` was touched.

## What changed and why

### 1. `spatial_index.dart` — the split case

`_considerLeaf`'s shared `point`/`text`/`attrib` case became two. `point` keeps
its old body verbatim (only its comment lost the text half). `text`/`attrib`
now:

1. resolves the style through `document.textStyleOf(entities.textStyleAt(slot))`
   — the accessor from Task 5's fix round, **not** the brief's
   `?? tables.textStyles[standardTextStyle]!` expression;
2. measures through `document.textMeasurer`;
3. fills the reusable `TextLayout` (resolved attributes, glyph box, composed
   local transform) from the payload, the entity's own `textAttrs`, and the
   anchor read as two raw doubles (`coords[0]`, `coords[1]` — `payload.pointAt(0)`
   would allocate a `Vector2`);
4. answers "no hit" for a zero-area box, then composes leaf-to-world with
   text-local into six locals, guards `det == 0 || !det.isFinite`, and solves the
   2×2 system for the query point in glyph space;
5. reports `HitKind.fill` at the query point when that point is in the closed
   box.

No `Transform2.invert()` (ruling 1 — the method is `invert()`, not `inverted()`,
and it throws `SingularTransformError`), no `Transform2.multiply`, no `Aabb2`.
The singular case returns "no hit" rather than letting an exception escape a
pointer move — the same answer `_descend` already gives for a singular container
transform. A test pins it (`a text entity with no laid-out box is not pickable`,
using the default `InsertionPointMeasurer`).

`_considerSnapLeaf`'s text case is untouched, so the insertion point remains a
`SnapKind.insertion` candidate.

### 2. `text_geometry.dart` — `TextLayout` (the part the brief did not anticipate)

The brief's Step 3 snippet calls `resolveTextAttributes`, `textLocalTransform`
and `textLocalBounds` per candidate. That is one `ResolvedTextAttributes`, one
`Transform2` and one `Aabb2` **per text candidate**, plus a fourth object for the
inverse — and `Transform2` and `Aabb2` are two of the three classes
`query_allocation_test.dart` watches. On a document with labels everywhere that
scales with candidate count, which is exactly the shape Plan 2's budget forbids.

The obvious fix — hand-inline the layout math inside the index — is the thing
`text_geometry.dart`'s own doc comments exist to prevent ("the single place these
decisions are made"). So instead the mutable form is now where the math lives:

- `class TextLayout` holds the resolved attributes, the six local-transform
  coefficients and the four box bounds, and exposes `resolve`, `adopt`,
  `layOutBox`, `composeTransform`, `attributes`.
- `resolveTextAttributes`, `textLocalTransform` and `textLocalBounds` are now
  thin wrappers that fill a throwaway `TextLayout` and copy the answer out.
  Their signatures, semantics and doc comments are unchanged; every existing
  caller (four `entityBounds` sites, the geometry tests) is unaffected.
- The index owns one `TextLayout` for its lifetime and refills it per candidate.

So the fixed-height rule, DXF's 72=4 rule, the aligned/fit fallback and the
shear-before-scale order are still written exactly once, and there is no second
copy in the index to drift.

`TextLayout`'s fourteen doubles live in a single `Float64List`, not in plain
`double` fields — see the measurements below; that is not a style choice.

### 3. `text_metrics.dart` — ruling 8's allocation obligation

Measured, confirmed, fixed. `MetricModelMeasurer.measure` built a five-field
record key for a static memo and called `putIfAbsent` with a closure. With
`measure` on the pick path that is a record **and** a closure **and** a context
per text candidate. The memo is now a per-instance `Map<int, TextMetrics>`
(the ratios are fixed for one measurer's life, so they do not belong in the key),
read with an explicit lookup rather than `putIfAbsent`.

Cost: `MetricModelMeasurer` loses its `const` constructor (a const instance
cannot carry a mutable field). Twelve `const MetricModelMeasurer(...)` sites,
all in tests, became non-const. `text_metrics_test.dart`'s "keyed by ratios"
test still passes and its name and comment were updated to describe the memo
that now exists rather than the one that does not.

### 4. `reference_query.dart` — the oracle, kept independent

The oracle's `_hitAtOf` also split `point` from `text`/`attrib`. Its text branch
is deliberately **not** the index's algorithm:

| | index | oracle |
|---|---|---|
| mapping | composes leaf→world with text-local into six doubles, then **inverts** by solving a 2×2 system | maps the box's **four corners forwards** into world space |
| containment | closed-interval test on the axis-aligned glyph box | sign of four **edge cross products** (`_insideParallelogram`) against the resulting quadrilateral |
| degenerate | `maxX <= minX \|\| maxY <= minY`, then `det == 0` | `maxX <= minX \|\| maxY <= minY`, then shoelace area `== 0` |

They agree only if the composition, the inversion and the interval test are all
right. `resolveTextAttributes`/`textLocalBounds`/`textLocalTransform` *are*
shared, on the same footing as `entityBounds` and `distance.dart`'s formulas
that this file's header already sanctions: those are the definition of where a
text entity's glyphs sit, not the index under test. What is not shared is the
containment rule, which is the part the index could get wrong.

The half-plane test is inclusive so that it matches the index's *closed* box on
a point exactly on an edge; and both sides state the zero-area rule explicitly,
because otherwise a collapsed quadrilateral would swallow the point it collapsed
to on one side and not the other. Mutation 3 below shows the oracle is doing real
work: a reversed composition order in the index is caught **only** by the
differential.

### 5. `corpus.dart` — `textLaidOut`

The only existing text fixture, `textDefaultMeasurer`, uses
`InsertionPointMeasurer`: every box is zero-area, so the new rule is trivially
false for every query point and the differential would have agreed without ever
evaluating it. `textLaidOut` uses `MetricModelMeasurer` and carries five text
entities (left/baseline; centre/middle rotated; right/top with both per-entity
override bits live; a non-STANDARD `TALL` style with `fixedHeight`, its own
width factor and oblique angle; an `aligned` code that must fall back to left)
plus an ATTRIB under a rotated, non-uniformly scaled instance. Each one asserts
its own box has real area at build time, in this corpus's existing style.
`_addEntity` gained optional `text`/`textStyle`/`textAttrs` parameters whose
defaults leave every other fixture byte-identical.

## Allocation harness: before and after

`_deepNestedDocument` now places a label beside every line — 64 text leaves
alongside 64 lines, with justification, rotation and string length all varying
with `i` so nothing can be hoisted — and the document uses `MetricModelMeasurer`.
The pick test asserts a probe point inside the first label's box reports
`HitKind.fill` before it measures anything, so a pick path that skipped text
entirely could not read a clean profile and pass.

Numbers, from a scratch probe that dumped the whole accumulated profile over
1,000 warmed picks against that fixture (deleted before commit; the harness
itself still watches named classes only, for the noise reasons its own file
documents):

| class | naive (record memo, plain `double` fields) | after both fixes |
|---|---|---|
| `_Record` | **41.5 / call** | 0 (absent from the profile) |
| `_Closure` | 52.2 / call | 10.5 / call |
| `Context` | 46.8 / call | 5.2 / call |
| `_Double` | 881 / call | 663 / call |
| `Transform2` | 4.55 / call | 4.46 / call (budget 10) |
| `Aabb2` | 2.60 / call | 2.55 / call (budget 7) |
| `Vector2` | ~0 | ~0 (budget 0.5) |

The `_Closure`/`Context` drop is the `putIfAbsent` callback going away; what
remains is the pre-existing per-recursion-level closure cost `_descend`'s doc
comment already documents (a no-text run of the same fixture reads below the
top-25 cutoff for both). `Transform2` and `Aabb2` did not move: no per-candidate
matrix or box was introduced, which is the point.

`_Record` is now in `_recursiveCandidateScalingClasses`, so `pickInto` and
`snapInto` watch it at the same 0.5/call budget as `Vector2`. **Confirmed by
mutation:** restoring the record-keyed `putIfAbsent` memo fails
`pickInto does not allocate in steady state` with `_Record: 4.163 per call`
(reverted). The test was strengthened, never relaxed.

### The one thing I could not take to zero: boxed doubles

`TextLayout` with plain `double` fields measured ~10 extra `_Double` per text
candidate (881/call vs 237/call for the same fixture with the layout call
skipped): a store to an ordinary `double` field of a Dart object boxes its
value, and this object is refilled per candidate. Moving all fourteen doubles
into one `Float64List` recovered ~218/call. Roughly 6 boxed doubles per text
candidate remain, source not pinned down: inlining `scalarOr`'s two lines by
hand recovered only 0.75 of them, and a probe that returned *before* reading
`layout.a`..`layout.maxY` measured *higher*, not lower, so it is not the
accessors either. For context, the pre-existing line path already allocates
roughly one `_Double` per candidate (64/call on a 64-line, no-text run), so
per-candidate double boxing is not something this narrow phase has ever been
free of, and `_Double` is not a class this harness can watch — its own file
comment explains why a whole-heap sum carries four to five orders of magnitude
more noise than the budget it is trying to resolve. Recorded here as a known
residual rather than presented as clean.

## RED evidence

Step 2 (before any implementation): 7 of the 9 new pick tests failed; the two
that passed are the two that must (`a point entity still picks as a vertex`,
`the insertion point is still a snap candidate`).

Fixture-strength mutations, each applied to the committed implementation,
observed failing, then reverted:

| # | mutation | caught by |
|---|---|---|
| 1 | `..resolve(payload, 0, style)` — ignore `textAttrs`, i.e. every text is left/baseline | `pick_test: a justified text box is where its justification puts it` **and** `differential: textLaidOut pick` |
| 2 | `document.textStyleOf(const Handle(5))` — a bare STANDARD lookup instead of the entity's own style | `pick_test: a non-STANDARD style's fixed height sizes the pickable box` **and** `differential: textLaidOut pick` |
| 3 | reversed composition order (`layout` after the leaf transform instead of before) | `differential: textLaidOut pick` **only** — until the attrib fixture was strengthened (see below), then also `pick_test: an attrib picks by its box too` |
| 4 | widen `minX` by 1e9 for `text` — i.e. test a bound rather than the oriented box | `pick_test: a pointer near the insertion point is no longer a vertex hit` **and** `differential: textLaidOut pick` |
| 5 | `if (false && ...)` — never report a text fill | `differential: textLaidOut pick` (trial 12), proving the new corpus fixture actually exercises the rule |
| 6 | restore the record-keyed `putIfAbsent` memo | `query_allocation_test: pickInto does not allocate in steady state` at `_Record: 4.163/call` |

Mutation 3 changed the work: my first `an attrib picks by its box too` fixture
placed the instance with a pure translation and the text unrotated, so the text's
local transform was the identity and the composition order was unobservable — a
degenerate fixture of exactly the kind the task warned about, which only the
differential caught. The fixture now rotates the instance a quarter turn *and*
rotates the text 0.3 rad about an off-origin anchor, with the expected world
point computed by hand (`(-547.914, 1045.678)`), and it fails under mutation 3.

## Where the brief and the code disagreed

- **`textStyleOf`** — used, as instructed; the brief's `??` chain would crash on
  a document whose table lacks handle 5.
- **`Transform2.inverted()`** (ruling 1) — does not exist, and nothing inverts a
  `Transform2` on this path anyway: the composed map is inverted by solving a
  2×2 system into locals.
- **`SnapMask.only(...)`** (ruling 3) — does not exist; the snap test uses
  `SnapMask.none.with_(SnapKind.insertion)`.
- **`toLocal`/`ownerX`/`ownerY`** — the brief's snippet reads variables that do
  not exist in `_considerLeaf`; there is no world→local inverse in scope there,
  only the six forward coefficients `ta..tf`. The composition is therefore
  built and solved from those.
- **`document.entities.read(slot)`** — the brief's snippet builds a whole
  `EntityRecord` per candidate. The column accessors (`textAt`, `textStyleAt`,
  `textAttrsAt`) do not allocate, so the pick path uses those.
- **Per-candidate allocation generally** — the brief's snippet allocates four
  objects per candidate. See `TextLayout` above; this is the largest deviation
  and the one most worth a reviewer's attention.

## Things I am not certain about

1. **`TextLayout` is new public API** (`text_geometry.dart` is exported from the
   barrel). It is the smallest shape I found that keeps one source of truth
   *and* an allocation-free pick path, but it is more surface than Task 6 was
   scoped to add, and a reviewer may reasonably prefer either (a) a private
   inlined copy in the index, or (b) accepting the per-candidate allocations.
   I rejected (a) on drift grounds and (b) on ruling 8.
2. **Losing `const MetricModelMeasurer()`** touched twelve test call sites. An
   alternative that keeps `const` is a static map keyed by measurer identity
   with a nested per-length map; I rejected it because it retains every measurer
   ever constructed and keeps the cross-test global state the current design
   already has.
3. **Residual boxed doubles** (~6 per text candidate), above.
4. **Boundary agreement.** Index and oracle agree exactly on the closed box for
   any non-degenerate quadrilateral up to floating-point rounding; a query point
   within an ulp of an edge could in principle be classified differently. This
   is the same class of exposure every `distance <= radius` comparison in this
   file already has, and the corpus's random points do not probe it.
5. **`_Record` as a watched class** is a name from the VM's class table, not a
   Dart type this file can reference. If a future query path legitimately builds
   a record, that budget will need revisiting rather than silently loosening.

---

# Minors round (review of `6e046f8`)

Commit: `3515a72`. Suites unchanged: jet_cad_2d **710 passing**,
jet_cad_2d_flutter **123 passing / 1 skip**; analyze and format clean in both.
No `analysis_options.yaml` touched.

## 1. Stale doc comment — `query_allocation_test.dart`

`_candidateScalingClasses`' comment described `_recursiveCandidateScalingClasses`
as "`Vector2` alone"; it has been `Vector2` and `_Record` since `6e046f8`. Now
says so.

## 2. `@internal` on `TextLayout`

Annotated (`package:meta` was already imported for `@immutable`). `dart analyze`
stays clean — this package's lint set does not raise
`invalid_export_of_internal_element`, so the barrel export at
`jet_cad_2d.dart:29` is unchanged and the annotation is what carries the intent:
a consumer package's analyzer flags `invalid_use_of_internal_member` on any use
of `TextLayout` from outside `jet_cad_2d`. The doc comment says exactly that
rather than claiming a barrel hide that is not there, and points outside callers
at `resolveTextAttributes`/`textLocalTransform`/`textLocalBounds`.

## 3. Fixture weakness — the anchor x/y swap

Confirmed the reviewer's finding: swapping `composeTransform`'s anchor to
`coords[1], coords[0]` passed all nine of my new pick tests. Four fixtures
anchored at `(0, 0)`, where the swap is the identity; the `(1000, 1000)` one is
equally blind; and the attrib's `(2, 3)` shifts by 1.4 units against a 0.5-unit
probe radius on a box roughly 110 units across.

`a pointer inside a text box hits it as a fill` now anchors at **`(300, 20)`** —
the two coordinates differ by more than the box is tall (285.7), so the swapped
anchor `(20, 300)` yields a box (`x` 20..2220, `y` 242.86..528.57) sharing no
point with the correct one (`x` 300..2500, `y` -37.14..248.57). It also gained
two edge probes either side of the left edge, at `(305, -30)` (inside, 5 units
in and 7 above the descent line) and `(295, -30)` (outside): a probe in the
middle of a box tolerates an anchor wrong by tens of units, and these do not.
`a pointer near the insertion point is no longer a vertex hit` and
`the insertion point is still a snap candidate` moved to the same anchor — the
snap path reads the same two coordinates, so `(0, 0)` could not tell them apart
there either, and that test now pins the snap point at `(300, 20)`.

**RED evidence.** With the anchor swap applied to the committed implementation,
`test/index/pick_test.dart: a pointer inside a text box hits it as a fill`
fails (it was the 32nd test to run; the suite reported `+31 -1`). Reverted;
all 710 pass again.

The general lesson, worth carrying into the remaining Plan 3c tasks: an anchor
at the origin, or with equal coordinates, cannot distinguish the two payload
coordinates from each other, and a probe at a box's centre cannot distinguish a
box that is merely near-right from one that is right.
