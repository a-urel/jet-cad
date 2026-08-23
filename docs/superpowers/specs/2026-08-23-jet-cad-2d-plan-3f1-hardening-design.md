# Plan 3f.1 — hardening before the picture cache

**Date:** 2026-08-23
**Status:** approved design, ready for an implementation plan
**Predecessor:** [Plan 3f — text wiring and level of detail](2026-08-22-jet-cad-2d-plan-3f-text-design.md)
**Successor it exists for:** Plan 3g — the definition/tile picture cache

---

## Why this plan, and why before 3g

`STATUS.md` names 3g's first design decision and its five traps. Two of the
things 3g needs are not design questions at all — they are defects and missing
instruments that 3g would otherwise inherit and build on top of.

1. **`StyleContext` is the picture cache key**, and two of its six fields do
   not carry what they claim to. Fixing that after a cache exists means
   rekeying the cache; fixing it before means the cache is keyed correctly the
   first time.
2. **3g is the most measurement-dependent plan in this project so far** — every
   decision in it lands on a number. The instrument that produces those
   numbers currently prints them and asserts nothing, and the one gate that
   could see 3g's central risk has been proven blind to it.

Nothing in this plan is speculative work for a future that may not arrive. Both
items are already-recorded findings: the model gap is `STATUS.md`'s trap 4, and
the instrument gap is items 2 and 7 of the Plan 3f results note's "what this
plan did not close" list.

### Numbering

**This is Plan 3f.1, not Plan 3g.** The roadmap has been renumbered twice
already, and each renumbering left a correction paragraph in `STATUS.md` that a
reader has to hold in mind while reading older notes. `3g` is currently the
picture cache's name in `STATUS.md`, in the Plan 3f results note, and in the
3f spec. A point release consumes no letter and forces no third sweep.

---

## The three defects

### Defect 1 — `InstanceNode` carries 2 of `StyleContext`'s 6 fields

`StyleContext` (`lib/src/document/style_context.dart:12`) has six fields:
`color`, `linetype`, `linetypeScale`, `lineweight`, `transparency`, `layer`.

`DocumentStyleResolver.contextFor` (`lib/src/document/style_resolver.dart:27`)
computes exactly two of them from the instance — `color` and `layer`. The other
four pass through untouched:

```dart
return StyleContext(
  color: color,
  linetype: inherited.linetype,
  linetypeScale: inherited.linetypeScale,
  lineweight: inherited.lineweight,
  transparency: inherited.transparency,
  layer: layer,
);
```

The entity side already resolves BYBLOCK for three of those four
(`style_resolver.dart:76-93`): `kByBlock` for `lineweight` and `transparency`,
`ReservedHandles.byBlockLinetype` for `linetype`. So an entity inside a
definition can say "take the lineweight of whatever INSERT placed me" — and the
`InstanceNode` has nowhere to put a lineweight. The answer it gets is whatever
enclosed the outermost block, which for a root-level INSERT is
`StyleContext.documentRoot`'s hardcoded `lineweight: 25`.

The information does not exist in the model. This is a model gap, and the
resolver's current pass-through is the only defined answer given the gap.

### Defect 2 — `StyleContext.linetypeScale` is read by nothing

`styleFor` builds its `ResolvedStyle` with (`style_resolver.dart:102`):

```dart
linetypeScale: document.entities.linetypeScaleAt(slot),
```

The context's own `linetypeScale` is never consulted. The field is constructed,
copied by `copyWith`, compared by `==`, hashed by `hashCode`, and threaded
through `contextFor` — and no code path reads it to produce a drawing.

It is not an unused field: `ResolvedStyle.linetypeScale` is consumed by the
painter at `draft_painter.dart:615`, `:769` and `:803`, each multiplied by
`document.header.globalLinetypeScale`, to set dash spacing. The *entity's* scale
reaches the dashes. The *context's* does not.

### Defect 3 — no fixture in the repository could see defect 2

`linetypeScale:` appears 53 times across `lib/` and `test/` in `jet_cad_2d`,
plus every render fixture in `jet_cad_2d_flutter`. **Every one of them is
`1.0`**, with a single exception: `test/store/entity_store_test.dart:44` uses
`2.5`, in a storage round-trip test that never resolves a style.

`1.0` is the multiplicative identity. A channel that is connected and a channel
that is severed produce the same output when every value flowing through it is
the identity. This is `CLAUDE.md`'s named dominant failure mode — the
degenerate fixture — sitting directly on the field in question.

**Defect 3 is the reason defects 1 and 2 survived to be found by reading rather
than by a red test, and it is why this plan carries an anti-degenerate rule
with the force of a criterion.**

### Defect 4 — the structural invariants are printed, not asserted, in a suite that does not run

Plan 3f's mutant 7 — `metricsLimit` defaulting to `kParagraphCacheLimit` —
passed all 297 tests in the suite it shipped with. Two independent things had
to be true for that:

1. **Every test in `flutter_text_measurer_test.dart` constructs its subject
   with both bounds passed explicitly.** A test file that always supplies a
   default cannot see that default being wrong.
2. **The one place the defect was visible does not run.**
   `test/rig/paint_microbench_test.dart` printed
   `liveMetrics=512 metricsEvictions=608634` for a run that should have read
   `liveMetrics=4020 metricsEvictions=0` — and passed, because the file has no
   `expect` in it, and because `dart_test.yaml` marks the `rig` tag
   `skip: "run explicitly: flutter test --tags rig --run-skipped"`.

The rig's own header argues its position and **is right about what it is
arguing**:

> These print; they do not assert. A rig that fails the build on a slow
> machine teaches people to ignore it.

That argument is correct for timings and wrong for everything else in the same
file. Two kinds of number are mixed under one rule.

### Defect 5 — the Flutter side cannot measure allocation at all

`AllocationMeter` lives at
`packages/jet_cad_2d/test/invariants/vm_allocation_meter.dart`. Dart cannot
import another package's `test/` directory, so `jet_cad_2d_flutter` has no
access to it. Its only allocation instrument is
`VerticesDrawSink.debugCapacityVertices`, and Plan 3e proved directly that this
instrument cannot see a lazily-populated cache: mutating `_drawFill` to compute
and store a triangulation on a cache miss left
`test/invariants/paint_allocation_test.dart` green.

3g's picture cache is exactly that shape.

---

## Decisions

**Decision 1 — `InstanceNode` gains four fields, typed and encoded exactly as
the entity store encodes the same properties.**

| field | type | default |
|---|---|---|
| `lineweight` | `int` | `kByBlock` (`-2`) |
| `transparency` | `int` | `kByBlock` (`-2`) |
| `linetype` | `Handle` | `ReservedHandles.byBlockLinetype` (`Handle(3)`) |
| `linetypeScale` | `double` | `1.0` |

Same constants, same sentinels, same meanings as `EntityRecord`. A second
encoding for the same concept would be a second thing to keep in step.

**Decision 2 — `contextFor` resolves the three sentinel-carrying fields exactly
as it already resolves `color`.**

For each of `lineweight`, `transparency`, `linetype`:

- BYBLOCK → the inherited value.
- BYLAYER → the **effective** layer's record; falling back to the inherited
  value when the record is absent or itself malformed.
- otherwise → the concrete value.

"Effective layer" means the layer-0 substitution the method already computes at
`style_resolver.dart:36-37`. The existing comment there states why one node must
not report two effective layers; that argument now governs four lookups instead
of one.

**The layer record is fetched once.** `_layerColorOf` currently fetches it for
`color` alone. Four fields asking the same table four times would be four map
lookups per instance per frame, on a path the non-negotiables bound.

**Decision 3 — `linetypeScale` composes multiplicatively, not by
substitution.**

DXF's rule for a nested entity's effective linetype scale is a product, not an
override. So:

```dart
// contextFor
linetypeScale: inherited.linetypeScale * node.linetypeScale,

// styleFor — the line that today ignores the context entirely
linetypeScale: ctx.linetypeScale * document.entities.linetypeScaleAt(slot),
```

The painter already multiplies by `header.globalLinetypeScale`, so the full
chain becomes entity × every enclosing INSERT × global, and nesting composes
without any special case for depth.

This is the fix for defect 2. It is not separable from decision 1: without an
INSERT scale there is nothing to multiply by.

**Decision 4 — schema v5 → v6, with the migration `InstanceNode.fromJson`
already demonstrates.**

`InstanceNode.toJson` writes the four new fields. `fromJson` supplies the
decision-1 defaults when they are absent — the same shape, and the same
argument, as the `color` field's existing comment: *"BYBLOCK is the correct
default because it is a no-op — it reproduces the old behaviour exactly."*

The bump exists for the **reader**, not the writer. `json_codec.dart:104`
refuses `version > kSchemaVersion`. Without a bump, a build predating this plan
would load a v6 file, silently drop four fields, and render a different
drawing. With it, that build refuses the file and says why. This is the same
argument v4→v5 made for `EntityKind.fill`.

**Decision 5 — the defaults preserve current behaviour exactly, and that is a
hazard as much as a property.**

With decision 1's defaults, decision 2 reduces to `inherited.<field>` — the
identical expression the code has today — and decision 3 reduces to
`inherited.linetypeScale * 1.0`, which is bit-exact for every finite double,
for the infinities, and for NaN.

So no existing document, golden, or test moves. That makes the change safe to
land and **makes the feature invisible to any test that does not opt in** —
which is the precise shape of Plan 3f's mutant 7. See the anti-degenerate rule.

**Decision 6 — structural invariants move to always-on tests at the smallest
scale that can carry them; the rig is not touched.**

Two kinds of number, two rules:

- **Machine-dependent** (p50, p95, min, wall-clock): stays printed, stays in
  the rig, stays `skip:`. The rig header's argument stands unamended.
- **Machine-independent** (cache occupancy, eviction counts, distinct key
  counts, op counts, leaf counts): becomes an assertion in
  `test/invariants/`, which runs on every `flutter test`.

The invariant tests are sized by **the bound under test, not by realism**.
Mutant 7's signature needs more distinct keys than `kParagraphCacheLimit`; the
limit is 512, so 600 strings suffice. It does not need 50,000 entities. That is
why the invariant costs seconds and the rig costs minutes, and why they can
have different rules about failing the build.

**Decision 7 — `AllocationMeter` moves to `lib/src/testing/`, and
`vm_service` becomes a real dependency of `jet_cad_2d`.**

`lib/testing.dart` already exists and already argues this exact case:

> It lives in `lib/` for one reason: the Flutter package's render rigs and this
> package's query benchmark must generate byte-identical documents, and a file
> under `benchmark/` cannot be imported across packages.

The same sentence is true of `test/`. The move applies an existing pattern a
second time rather than opening a new one.

**The cost, stated plainly:** a Dart dependency resolves at package level, not
library level. `jet_cad_2d.dart` does not export `testing.dart`, but every
consumer of `jet_cad_2d` will still resolve `vm_service`. Tree shaking removes
the unused code from a built application; what is paid is dependency-tree
weight, not binary size.

**Decision 8 — the move is a precondition of the probe, and the probe has a
pre-committed stop clause.**

Dart cannot import across `test/` directories, so the probe cannot run until
the meter has moved. The order is: move, re-point the three existing call
sites, then probe from the Flutter package.

The probe asks two questions, and connecting is not enough:

1. **Does it connect?** `AllocationMeter.connect()` under `flutter_tester`'s
   VM — the trick the meter relies on is
   `dart:developer`'s `Service.controlWebServer(enable: true)`, verified under
   plain `dart test` and **never** under `flutter test`.
2. **Does it count?** A positive control: a class defined by the probe and
   instantiated nowhere else in the run, allocated a known 100,000 times, must
   read back at **90% or more**.

**Stop clause, binding:** if `connect()` returns null, or the positive control
reads below 90%, then the move commit is reverted, the finding is recorded with
its transcript in the results note, and Section 3 is dropped from the plan.
Sections 1 and 2 do not depend on the meter and continue unaffected.

**Decision 9 — if the probe is green, the first Flutter-side use is 3g's
trap 5, not the metrics-lookup claim.**

The Plan 3f results note names the metrics-map lookup as the thing a moved
meter would close. That target collides with the meter's own documented rule —
watch classes the path under test does not build in bulk. The metrics key is a
`(String, int)` record, and records are allocated throughout the frame path.
Whether it can be isolated is unknown.

`ui.Picture` can be. Nothing else on the frame path allocates pictures in bulk,
and it is the exact class 3g's cache would allocate on a miss. So the
deliverable is not "the meter is available" but **"a lazily-populated cache
allocating on the frame path is visible to a gate"** — the claim
`debugCapacityVertices` was proven unable to make.

The metrics-record claim is attempted. It is **not promised**: if it cannot be
isolated, it is recorded as unmeasurable with its reason, exactly as the Plan 3f
mutation log records it now.

---

## Section 1 — model, resolution, schema

**Files:** `lib/src/document/node.dart`, `lib/src/document/style_resolver.dart`,
`lib/src/codec/schema_version.dart`.

`InstanceNode` gains the four fields of decision 1, in its constructor,
`copyWith`, `toJson`, `fromJson`, `operator ==` and `hashCode`. `contextFor`
gains the resolution of decision 2 and the single layer-record fetch. `styleFor`
gains the `ctx.linetypeScale *` factor of decision 3. `kSchemaVersion` becomes
`6` with a documented v5→v6 entry beside the existing v3→v4 and v4→v5 ones.

### Worked example, and the fixture shape it dictates

The nested `linetypeScale` criterion uses **2.0 (entity) × 4.0 (inner INSERT) ×
8.0 (outer INSERT) = 64.0**.

Every factor is exact in binary, so the assertion is `==` and not a tolerance —
`CLAUDE.md`'s rule that stored-value comparisons are exact applies. And 64.0
differs from each factor (2, 4, 8), from each pairwise product (8, 16, 32),
from their sum (14), and from their maximum (8). A mutant that drops one
multiplication, replaces it with addition, or takes a maximum lands on a
different number in every case.

The BYLAYER criterion needs the layer-0 substitution to be observable, so its
fixture places an INSERT **on layer 0**, through a container whose context
carries layer `L`, with the INSERT's `lineweight` set to `kByLayer`, and with
layer `L`'s record and layer 0's record holding **different** lineweights. The
correct answer is `L`'s; the mutation that reads `node.layer` gets layer 0's.
If both records held the same value the criterion would pass under its own
mutant.

---

## Section 2 — structural invariants

**Files created:** `test/invariants/text_cache_invariants_test.dart`,
`test/invariants/frame_accounting_test.dart`, both in `jet_cad_2d_flutter`.
**File moved:** `TextKeySink`, from `test/rig/rig_support.dart` to
`test/support/`, imported back by the rig. One definition, two readers.

**Not touched:** `dart_test.yaml`, the `rig` tag's `skip:`, the rig's timing
prints, or the rig header's argument.

### `text_cache_invariants_test.dart`

One fixture closes two of Plan 3f's three named untested-default instances. It
is sized from the bound, not from realism:

```
kParagraphCacheLimit (512) < distinct keys ≤ kMetricsCacheLimit (8192)
```

600 unique strings, one text style, one resolved colour — so 600 distinct
metrics keys and 600 distinct paragraph keys. **The measurer is constructed
bare — `FlutterTextMeasurer()`, no arguments.** That is the whole point: the
defaults are what is under test.

After a **single** paint that draws all 600:

| counter | expected | under mutant 7 |
|---|---|---|
| `liveMetrics` | 600 | 512 |
| `metricsEvictionCount` | 0 | 88 |
| `liveParagraphCount` | 512 | 512 |
| `paragraphEvictionCount` | 88 | 88 |

The same assertions cover `paragraphLimit`'s default: under a mutant that
raises it to `kMetricsCacheLimit`, the last two rows read 600 and 0.

**The fixture must prove it drew all 600.** Level of detail could cull some of
the labels and produce a smaller, self-consistent, wrong set of numbers. The
test asserts `culledTextCount == 0` and `textOpCount == 600` alongside the
cache counters, so the key count is verified rather than assumed.

The third untested default — `reference_walk.dart:36`'s `minTextCapPixels` —
gets its own short test: `referenceWalk` is called **without** the argument over
a document carrying sub-threshold text, and the text must not be drawn. Today
every caller supplies its own threshold, so the parameter's default is shadowed
and setting it to `0.0` leaves the whole suite green.

### `frame_accounting_test.dart`

No magic constants. Three identities, each true at any corpus size:

1. **Text accounting closes.**
   `textOpCount + culledTextCount + skippedTextCount` equals the number of text
   leaves the frame visited. A cull that swallows an entity, or counts one
   twice, breaks the equality. The expected total is derived by the test from
   the document's own entities — Plan 3e's Ruling 28 in miniature: an oracle
   that asks the painter what the answer should be shares the assumption it
   exists to test.
2. **A repeated frame is a repeated frame.** Two identical paints agree on
   every counter.
3. **The two backends describe one drawing.** `screenSpaceLeafCount`,
   `fillCount`, `skippedFillCount`, `textOpCount` and `culledTextCount` are
   exactly equal between `RenderBackend.canvas` and `RenderBackend.vertices`.

The third is not a new claim. It is written down today as a comment, in
`apps/dev_harness_2d/lib/measurement_rig.dart:95-97`:

> at a fixed corpus size they must match exactly across `BACKEND=canvas` and
> `BACKEND=vertices`

An invariant whose only auditor is a human reading two transcripts side by side
is an invariant that goes stale when the code is copied — which is how R4a and
R4b kept the canvas-only guard after R2's was fixed. This test takes that
sentence away from the human.

---

## Section 3 — the allocation meter

**Files:** `lib/src/testing/allocation_meter.dart` (moved from
`test/invariants/vm_allocation_meter.dart`), `lib/testing.dart`,
`pubspec.yaml`, the three existing call sites
(`test/invariants/query_allocation_test.dart`,
`test/invariants/text_paint_allocation_test.dart`,
`test/index/packed_rtree_test.dart`), and a new probe in `jet_cad_2d_flutter`.

The move is mechanical: the file's contents, including its long header on the
three failure modes it designs around, travel unchanged. The three call sites
change one import line each to `package:jet_cad_2d/testing.dart`. The engine
suite must be green on the moved file before the probe runs, so a failure in the
probe is unambiguously about `flutter test` and not about the move.

Then the probe of decision 8, then — only if green — the trap-5 demonstration of
decision 9.

---

## Failable criteria

Fifteen. Fourteen of them are claims a test makes, and each of those has at
least one named mutant below that must turn it red. **Criterion 14 is the
exception and is stated as one**: it is a measurement of whether an instrument
works in an environment, not a claim about code under test, so no mutation can
address it. Its stop clause is what makes it failable.

**Section 1 — model and resolution**

1. An INSERT carrying a concrete `lineweight` imposes it on a BYBLOCK entity
   inside its definition.
2. The same for `transparency`.
3. The same for `linetype`.
4. Nested instances compose `linetypeScale` multiplicatively: entity `2.0` ×
   inner INSERT `4.0` × outer INSERT `8.0` resolves to exactly `64.0`.
5. An INSERT whose `lineweight` is BYLAYER reads the **substituted** layer's
   record, not `node.layer`'s.
6. A v5 document loads under a v6 build and every entity's `ResolvedStyle` is
   bit-identical to what the v5 build resolved for it.
7. A v6 round-trip preserves all four fields at non-default values.
8. Every pre-existing golden PNG is byte-identical. No golden is regenerated by
   this plan.

**Section 2 — structural invariants**

9. A bare-constructed `FlutterTextMeasurer()` over the 600-key fixture reads
   `liveMetrics=600`, `metricsEvictionCount=0`, `liveParagraphCount=512`,
   `paragraphEvictionCount=88`, with `textOpCount=600` and `culledTextCount=0`
   proving the fixture drew what it claims.
10. `referenceWalk`, called without `minTextCapPixels`, culls sub-threshold
    text.
11. `textOpCount + culledTextCount + skippedTextCount` equals the frame's text
    leaf count. **The right-hand side is counted by the test from the
    document**, never read back from the painter: an identity whose two sides
    come from the same source is not an identity.
12. Two identical paints agree on every counter.
13. Canvas and vertices agree exactly on `screenSpaceLeafCount`, `fillCount`,
    `skippedFillCount`, `textOpCount` and `culledTextCount`.

**Section 3 — the allocation meter**

14. The probe connects **and** reads its positive control at 90% or above — or
    the stop clause fires, the move is reverted, and the finding is recorded
    with its transcript.
15. Given a green probe: a frame-path mutation that allocates lazily is visible
    to the meter, on a fixture where `debugCapacityVertices` stays flat.

---

## Named mutants

| # | mutation | criterion it must redden |
|---|---|---|
| M1 | `contextFor` reverts `lineweight` to `inherited.lineweight` | 1 |
| M2 | `contextFor` reverts `transparency` to `inherited.transparency` | 2 |
| M3 | `contextFor` reverts `linetype` to `inherited.linetype` | 3 |
| M4 | `styleFor` drops the `ctx.linetypeScale *` factor | 4 |
| M5 | `contextFor` uses `node.layer` for the BYLAYER lookup | 5 |
| M6 | v6 `fromJson` defaults `linetype` to `byLayerLinetype` | 6, 8 |
| M7 | `metricsLimit` defaults to `kParagraphCacheLimit` — **Plan 3f's survivor** | 9 |
| M8 | `paragraphLimit` defaults to `kMetricsCacheLimit` | 9 |
| M9 | `reference_walk.dart:36`'s default becomes `0.0` | 10 |
| M10 | `_drawText` increments `_culledText` but does not `return` | 11 |
| M11 | `VerticesDrawSink` drops one text op on delegation | 13 |
| M12 | a frame-path allocation made lazily on a cache miss | 15 |
| M13 | `InstanceNode.toJson` omits `linetypeScale` | 7 |
| M14 | a painter text counter is not reset between paints | 12 |

A mutant that no criterion reddens is recorded as a survivor with its reason,
never quietly dropped. Plan 3f's mutation log carries three such entries and
they are the most useful rows in it.

---

## The anti-degenerate rule

**Binding, with the force of a criterion.**

- No test written by this plan uses `linetypeScale: 1.0`.
- No instance fixture written by this plan leaves all four new fields at their
  defaults.
- Every criterion in section 1 is exercised by a fixture where the property
  under test differs between the instance, the layer record, and the document
  root — so a resolution that reads the wrong one of the three lands on a
  different number.

Fifty-three fixtures in this repository already wrote `1.0` and none of them
could see that the channel was severed. Decision 5 makes the new code
behaviourally identical at its defaults, which means a fixture at the defaults
proves nothing at all.

---

## Out of scope

- **No command for authoring instance style.** Model, resolution and schema
  only. Nothing in the repository needs to set these fields at runtime yet, and
  an undo-safe mutation command for a property with no caller is a surface to
  maintain for no reader.
- **No DXF import or export.** There is no DXF codec in this repository; the
  DXF references in this document are about semantics, not file format.
- **`kParagraphCacheLimit` stays 512.** Ruling 4's single permitted raise stays
  unspent and available to 3g, with its measured 3,876 recorded beside it.
- **`kMinTextCapPixels` stays 3.0.** Plan 3f refused to tune it to fit a gate;
  this plan does not revisit that.
- **The rig keeps its `skip:` and its prints.**
- **Nothing in this plan touches the picture cache.** It prepares 3g; it does
  not begin it.
- **Permitted divergence 5** — overlapping translucent strokes on a triangle
  soup — stays open. It is unrelated to all three items here.

---

## Accepted gaps

1. **Criterion 6 proves the migration is a no-op; it cannot prove the bump is
   necessary.** That a v5 build refuses a v6 file is a property of the version
   check, already pinned by the v4→v5 tests. This plan does not re-test it.
2. **`ui.Picture` isolation is assumed, not yet measured.** Decision 9 argues
   that nothing else on the frame path allocates pictures in bulk. If the probe
   is green and that assumption turns out false, criterion 15 is recorded as
   unmeasurable with the reading that showed it.
3. **The `vm_service` dependency weight is accepted, not minimised.** The
   separate-package alternative was considered and rejected in favour of the
   existing `lib/testing.dart` precedent. If the dependency later proves a real
   problem for a consumer, extracting `jet_cad_2d_testing` remains a
   mechanical change.
4. **Criterion 13 compares counters, not pixels.** Two backends agreeing on op
   counts is not two backends drawing the same image; the golden suite and
   `vertices_differential_test.dart` carry that claim, and this criterion does
   not restate it.

---

## What Plan 3g inherits

- **A correctly-keyed `StyleContext`.** All six fields carry what they claim,
  so the picture cache key is right the first time and does not need rekeying
  after the fact.
- **`linetypeScale` connected end to end** — entity × every enclosing INSERT ×
  global — which matters directly to 3g's trap 3: a baked picture is not
  scale-invariant now that dashes exist, and dash phase is a function of this
  product.
- **Structural invariants that run on every `flutter test`**, so 3g's own
  counters land on a suite that can fail rather than one that prints.
- **The two-backend agreement asserted rather than commented**, which is the
  claim 3g will lean on when it decides whether a cached picture flushes the
  vertex buffer at its boundary.
- **Either a working Flutter-side allocation meter with trap 5 demonstrated, or
  a recorded finding that the mechanism does not work under `flutter test`** —
  and in the second case, 3g knows before it starts that its central risk needs
  a command-time assertion rather than a frame-path gate, which is what
  actually proved fills eager in Plan 3e.
- **Ruling 4 still unspent**, with its measured 3,876 beside it.
