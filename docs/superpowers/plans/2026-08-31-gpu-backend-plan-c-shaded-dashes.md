# GPU backend, Plan C — dashes in the shader

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A dashed line in the resident backend keeps the dash pattern the
reference draws **at every zoom**, because the pattern is evaluated per
fragment against a per-instance period rather than cut into spans at
collection time — and the buffer gets *smaller* for doing it.

**Architecture:** `DrawSink` gains a capability getter and a two-call bracket,
so `DraftPainter` hands a dash-shading sink the **undashed** geometry plus the
pattern instead of the spans it cuts for every other sink. The instance record
grows from twelve floats to sixteen and gains a `dash` attribute
`(period, phase, fracStart, fracEnd)`; the collector emits **one instance per
segment per drawn pattern element**, so instance count follows the pattern's
element count and not the dash count. The vertex shader turns that into one
varying, `t = (phase + s) / period`, measured in **collection space** — where
the live camera's scale cancels exactly — and the fragment shader keeps the
fragment when `fract(t)` lands inside the element. The live scale reaches the
shader for one purpose only: the `kDashCollapsePx` screen test, which becomes
live and exact instead of frozen at one camera.

**Tech Stack:** Dart, Flutter 3.47.1, `flutter_scene` 0.23.0 (for its internal
`flutter_gpu` shim only), `impellerc` for the shader bundle, `flutter_test`.

**Spec:** [docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md](../specs/2026-08-29-gpu-resident-render-backend-design.md)
(revision 4), section **"Dashes are shaded, with the conversion the painter
actually uses"**. Read that section before Task 1; this plan argues from it and
departs from it in two places, each recorded as a ruling below.

**Predecessors:** [Plan A](2026-08-29-gpu-backend-plan-a-seam-and-strokes.md),
merged at `cd5bc98`; [Plan B](2026-08-30-gpu-backend-plan-b-joins-and-hairlines.md),
merged at `72b162d`. Their ledgers are at
[docs/superpowers/ledgers/](../ledgers/). **Read Plan B's
`progress.md` Ruling B5 and Ruling B6 before Task 5** — B5 is the pre-flight
discipline this plan repeats, B6 is why `test/support/instance_expander.dart`
is a transcription and must stay one.

**Reference implementations — two, and they are not the same oracle:**

- `packages/jet_cad_2d/lib/src/geometry/dasher.dart` — where a dash pattern is
  walked. It decides *where the spans are*, and this plan must agree with it
  analytically, not approximately.
- `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart` — where the
  spans become triangles. It stays the pixel oracle, unchanged.

---

## Where Plan C sits

| plan | delivers | state |
|---|---|---|
| A | the facade, the enum, the collector and buffer for **stroked polylines**, one draw call, the ordering and differential gates, the fallback | **merged** `cd5bc98` |
| B | joins, `point()`, `circle()`/`arc()`, the `_coveredArgb` hairline alpha | **merged** `72b162d` |
| **C (this one)** | **dashes evaluated in the shader, at the live scale** | this plan |
| D | fills | |
| E | the text split — *N* text ops, *N+1* draw calls | |
| F | the rebuild triggers, the reference scale and the watermark | |
| G | web: CanvasKit and Skwasm | |

**Plan C's exit is not the spec's exit gate.** It closes two of the spec's
fourteen pre-committed mutations — *"accumulate dash phase along a polyline
instead of restarting per vertex"* and *"drop the running phase on arcs"* —
and extends the pixel-differential instrument to a corpus the reference and
the resident arm now reach by **different routes**, which is new and is the
single largest risk in this plan.

---

## What is wrong today, stated as a measurement rather than as a worry

`apps/dev_harness_2d/lib/gpu_arm.dart` already says it, in the comment Plan B
left behind: *"A dash pattern's spans are split at that camera's scale and then
baked into the resident buffer, so they stretch under zoom."*

The arithmetic. `DraftPainter._dashScale` is
`style.linetypeScale × header.globalLinetypeScale × toScreen.scaleMagnitude`
(`draft_painter.dart:651-654`), so the reference's on-screen period is
proportional to the **live** camera scale. The resident buffer holds spans cut
at the **collection** camera scale, drawn through the live camera — so its
on-screen period is *also* proportional to the live scale, and the two agree.
**The period is not what drifts.** What drifts is everything else: the number
of spans is frozen, so a line that shows eight dashes at the collection scale
still shows eight dashes at 4× zoom instead of the thirty-two the reference
draws, each four times too long. Zoomed out it shows eight where the reference
has collapsed the pattern to solid entirely.

Both statements matter and only one of them is in the harness comment. Write
the second one into the results note; a reader who believes only "they
stretch" will look for the wrong defect in the window.

---

## Six scope rulings, made here rather than left to an implementer

### Ruling C1 — `DrawSink` gains three members, and `packages/jet_cad_2d` still is not touched

The spec's invariant 4 says *"`DraftPainter` and `DrawSink` are already in
`jet_cad_2d_flutter`; this design adds no painter API at all."* This plan adds
three members to `DrawSink`. That is a departure and it is deliberate.

**The binding half of invariant 4 is "`packages/jet_cad_2d` is untouched", and
this plan honours it completely.** The sentence about the painter is the
spec's argument for *why* invariant 4 is cheap to hold, not a second
requirement — and the spec's own dash section, four pages earlier, mandates a
design that cannot be built without it. Read them together and only one
reading survives:

- The collector is a `DrawSink` (spec: "The design is therefore what
  `VerticesDrawSink` already is"). It is handed whatever the painter hands it.
- The painter dashes **before** any sink sees anything: `_emitSpan` calls
  `sink.polyline(_span, 2, ...)` per span (`draft_painter.dart:298-309`). A
  sink receives spans, never a pattern.
- A span carries no pattern, no cycle and no phase. **No collector, however
  written, can recover the dash pattern from the spans it is given.** The
  information is destroyed one call above it.

So "shade the dashes" and "add nothing to `DrawSink`" cannot both hold. The
spec's dash section is specific, derived and load-bearing; the painter clause
is an aside inside an invariant whose subject is a different package.
**The dash section wins.**

**What is added** — the minimum that carries the lost information:

```dart
bool get shadesDashes;
void beginDash(DashPattern pattern, double patternToLocal, double localToPixels);
void endDash();
```

**Cost if wrong:** six `DrawSink` implementations gain three members, one of
which is a constant. If a later plan finds a way to route the pattern without
touching the interface, removing it is mechanical. The alternative — leaving
dashes baked — makes the spec's dash section undeliverable in every plan, not
just this one.

### Ruling C2 — one instance per (primitive × drawn pattern element), not a lookup texture

The spec says the record carries "the period" and stops. It does not say how
the *shape* of the pattern reaches the shader, and the obvious answer — a
lookup texture, one row per linetype, sampled at `fract(t)` — is rejected here
for three reasons, in order of weight:

1. **It cannot be gated by `flutter test`.** This package's fragment-stage
   instrument is `TriangleRasterizer`, and Plan B's Ruling B6 discipline is
   that every shader line has a Dart transcription the suite runs. A sampler
   adds a texture upload, a binding and a filtering mode to the transcription,
   and the transcription would then be reproducing a *driver's* sampling, not
   arithmetic.
2. **It quantises.** A 1024-wide row puts the dash edge within `period/1024`
   of its true position — at a live period of 300 px, 0.29 px, growing with
   the watermark band that Plan F has yet to measure. Criterion 1 is a
   per-channel pixel gate; spending a fraction of a pixel on every dash edge
   to buy generality nothing in the corpus needs is a bad trade made early.
3. **ES 100 has no dynamic indexing of uniform arrays in the fragment stage**,
   so the texture is not one option among several — it is the *only*
   texture-free general mechanism, and it is being rejected on its own merits
   rather than chosen by elimination.

**Instead: the collector emits one instance per drawn element of the cycle,
per primitive.** Each carries `fracStart` and `fracEnd`, the element's own
normalised extent within the cycle, and the fragment keeps itself when
`fract(t)` falls inside. Exact at every scale, no sampler, no quantisation.

**The cost is instance count, and it is bounded by the pattern, not by the
zoom.** A pattern with *D* drawn elements multiplies a dashed primitive's
instances by *D*. `DASHED` (`[12, -6]`) has *D* = 1 — no multiplication at
all. `DASHDOT` and `CENTER` have *D* = 2, `PHANTOM` *D* = 3. Against today's
baked spans, a line of length *L* at period *P* costs `D·L/P` instances and
will cost *D*. **Task 12 must report the measured instance count against Plan
B's 109,068 and say which direction it moved.**

**Cost if wrong:** a document using a twelve-element ISO linetype on most of
its geometry pays 6× the instances on that geometry. The mitigation, if it is
ever needed, is the texture — and this ruling is where a later plan will find
the argument it has to beat.

### Ruling C3 — a dashed polyline emits no joins; a dashed arc keeps them

This is a correctness requirement, not a saving.

The reference emits each span as its **own two-point `polyline` op**
(`draft_painter.dart:298-309`), and `VerticesDrawSink` treats every op as its
own run. So a dashed polyline in the reference has **no join geometry
anywhere** — not between spans, and not at the polyline's own vertices. Its
corners are notched, and that is what the pixels show.

A shaded dashed polyline is one run, so the collector would emit a join at
every interior vertex, filling corners the reference leaves open. Since a
polyline's phase restarts at every vertex (`dasher.dart:94-96`) the pattern
begins with element 0 on both sides of the corner, so if element 0 is drawn
the corner has ink on both arms and the added wedge is squarely visible.
**The collector therefore emits no joins on a dashed run.**

A dashed **arc** is the mirror image: the reference chords each span and joins
*within* it (`vertices_draw_sink.dart`'s arc path), so joins exist and must be
reproduced. The shaded arm chords the whole arc once and emits a join at every
chord vertex, each dash-tested at its own phase — a join inside a gap
discards, a join inside a dash draws.

**Cost if wrong:** dashed corners are filled where the reference leaves them
notched. Task 10's pixel differential is where that shows, and M-C6 fires it
deliberately.

### Ruling C4 — the arc chording divergence is RECORDED, not reproduced

The spec: *"The plan must either reproduce the per-span chording or record the
divergence."* This plan records it, and quantifies it.

The reference re-chords **each span independently**
(`vertices_draw_sink.dart:674-716`), so its chord vertices sit wherever a
span's own `_flattenSteps` puts them; the shaded arm chords the whole sweep
once, at collection scale. Reproducing the reference would mean choosing chord
counts per span at collection time from a span set that only exists at one
camera — i.e. baking exactly what this plan exists to unbake.

**The divergence, with its arithmetic.** Both arms flatten to a chord error of
at most `kFlattenTolerance = 0.25` device pixels at the scale they flatten
for. The reference flattens at the live camera every frame, so it is always
within 0.25 px. The resident arm flattens once, at the collection camera, so
at a live-to-collection scale ratio *r* its sagitta is `0.25·r` px.

**This is not a dash defect and this plan does not create it.** Every circle
and arc the resident backend has drawn since Plan B carries it; dashes only
make it easier to see, because a dash edge is a hard boundary the eye can
line up. It is the **watermark band's** business — spec criterion 2 — and
Plan F owns the band. Task 12 reports the arc's measured pixel divergence at
`r = 1` (where it must be zero) and states the `0.25·r` growth law without
claiming a band.

**Cost if wrong:** a dashed arc is measurably off its true circle away from
the collection scale, by a bound this ruling states, in a plan that does not
own the band that bounds `r`.

### Ruling C5 — dashes go in a NEW fixture; `differentialFixture` stays continuous

Plan B's Ruling B5 was the pre-flight scan finding that a fixture change
broke four tasks' gates. This plan's scan found the opposite shape and the
answer is the opposite too.

`test/support/fixtures.dart`'s `differentialFixture` is the corpus behind six
test files, and `test/differential_test.dart` compares `DraftPainter` against
`reference_walk.dart`. **`reference_walk.dart` does not dash** — the word does
not appear in the file; it emits raw `polyline`/`arc` ops. Adding a dashed
entity to `differentialFixture` makes the painter emit spans and the reference
walk emit whole polylines, and the painter-vs-reference oracle — this
project's oldest correctness gate — goes red for a reason that has nothing to
do with this plan.

**So dashes get `shadedDashFixture()`**, a new fixture in the same file, and
`differentialFixture` is not touched.

**The cost, stated rather than discovered later:** the gates that run on
`differentialFixture` — emission order, allocation, the existing collector
differential — do **not** see dashes for free. Every one of them that should
see dashes gets an explicit dashed arm in this plan, named per task. A gate
this plan does not give a dashed arm to is a gate that does not cover dashes,
and Task 12 lists them.

**Cost if wrong:** the corpus is split across two fixtures and a future reader
has to know both exist. That is written at the top of both.

### Ruling C6 — the shader stays at eight vertex attributes

`gl_MaxVertexAttribs` is **at least 8** in OpenGL ES 2.0 / GLSL ES 100. The
shader today declares exactly eight: `corner`, `join_weight`, `kind`, `p0`,
`p1`, `p2`, `half_width`, `color`. A `dash` attribute makes nine.

In practice nine binds everywhere this project runs — WebGL2 guarantees 16,
Metal and Vulkan more. **The claim in `cad_stroke.vert`'s own header is
"Authored for OpenGL ES 100", and a claim that holds only in practice is
exactly the kind of thing this repository treats as a defect** (see the
`cad_stroke.frag` comment that cited evidence it did not have).

**So `kind` and `half_width` merge into one `vec2 kind_half`**, and the record
is reordered to put them adjacent. Eight attributes, claim intact.

**Cost if wrong:** the record's field order changes, which moves
`InstanceFieldOffset`, `kInstanceVertexLayout`, three writers, the shader and
the expander together — all of which this plan touches anyway. Task 4 does it
in one commit.

---

## Global Constraints

Copied verbatim from `CLAUDE.md`, the spec, Plan A and Plan B. Every task's
requirements implicitly include this section.

- **The frame path allocates nothing per entity in steady state, and O(1) per
  flush.**
- **Draw order is emission order** — *not* "ascending handle value". **Never
  sort the buffer.** Within an entity the order is also fixed: the join comes
  **before** its segment and the seam join comes **last**. **Plan C adds a
  second axis to that order** — a primitive's *D* dash instances are emitted
  consecutively, in ascending cycle position. Both axes are asserted in Task 8.
- **Geometric decisions use `Tolerance`; stored value comparisons are exact
  `==`.**
- **Never commit `analysis_options.yaml`** — `flutter pub get` rewrites three of
  them in this workspace. Check `git status` before every commit and
  `git checkout --` them.
- **Never synthesize test output.** Run the command, paste what it printed,
  **including the exit code**. `dart format --set-exit-if-changed` printing
  `(1 changed)` **is** a failure even though the line looks informational.
- **Before firing a mutation, back the file up with `cp`, and restore from that
  copy.** Never `git checkout --` a file to revert a mutation: a Plan A
  implementer did, and wiped an entire round of uncommitted fix work.
- Code, comments and commit messages in English.
- **`packages/jet_cad_2d` is untouched by this plan.** `Dasher`,
  `DashPattern` and `kDashCollapsePx` are **read**, never edited. Everything
  written lives in `packages/jet_cad_2d_flutter` and `apps/dev_harness_2d`.
- Shaders are authored so `impellerc` can emit an **OpenGL ES 100** stage.
  **No bitwise operators, no integer attributes, no dynamic indexing of
  uniform arrays in the fragment stage, and at most eight vertex attributes**
  (Ruling C6). **Every declared attribute must be read by something the
  optimizer cannot fold away**, or `impellerc` fails reflection with *"Could
  not complete reflection on generated shader"*.
- **`_coveredArgb` must never reach a fill.** Plan D inherits that constraint;
  Plan C must not make it harder to honour.
- **`ResolvedStyle` takes four required named arguments** — `argb`,
  `lineweightHundredths`, `linetype`, `linetypeScale`. Plan B's sample code got
  this wrong four times. Every literal in this plan spells all four.
- Every task ends green:
  ```sh
  cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
  ```
  Tasks 1, 2 and 12 additionally run the engine and harness gates:
  ```sh
  cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
  cd apps/dev_harness_2d && flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
  ```

## File structure

| file | responsibility |
|---|---|
| `lib/src/draw_sink.dart` | **modify** — `shadesDashes`, `beginDash`, `endDash`, and the two recorded ops |
| `lib/src/canvas_draw_sink.dart` | **modify** — declares it does not shade dashes |
| `lib/src/vertices_draw_sink.dart` | **modify** — same; otherwise untouched, it is the oracle |
| `lib/src/draft_painter.dart` | **modify** — routes undashed geometry to a shading sink |
| `lib/src/gpu/instance_record.dart` | **modify** — sixteen floats, `kind_half` adjacency, the `dash` quad, three writers |
| `lib/src/gpu/geometry_collector.dart` | **modify** — the dash bracket, per-element emission, arc phase |
| `lib/src/gpu/resident_geometry.dart` | **modify** — the vertex layout's eight attributes |
| `lib/src/gpu/gpu_draw_backend.dart` | **modify** — `dash_scale` in the uniform block, same 80 bytes |
| `shaders/cad_stroke.vert` | **modify** — `t`, the collapse branch, the degenerate-vertex path |
| `shaders/cad_stroke.frag` | **modify** — the `fract` test and the `discard` |
| `assets/shaders/cad.shaderbundle` | regenerated, committed |
| `test/support/fixtures.dart` | **modify** — `shadedDashFixture()` (Ruling C5) |
| `test/support/instance_expander.dart` | **modify** — the dash varying, transcribed |
| `test/support/triangle_rasterizer.dart` | **modify** — the fragment stage learns the dash test |
| `test/support/gpu_comparison.dart` | **modify** — threads the varying, and drives the two arms by their two routes |
| `test/gpu/dash_differential_test.dart` | **create** — the record-level declarative oracle for dashes |
| `test/gpu/*_test.dart` | **modify** — per task |
| `apps/dev_harness_2d/lib/gpu_arm.dart` | **modify** — the GSPIKE note, which currently says dashes are baked |
| `docs/superpowers/notes/plan-c-mutation-log.md` | **create** |
| `docs/superpowers/notes/2026-08-31-plan-c-results.md` | **create** |

All paths under `lib/`, `shaders/`, `test/` and `assets/` are relative to
`packages/jet_cad_2d_flutter/`.

---

## The record, decided once here

Every task that touches the buffer uses this layout. It is stated once so no
task restates it from memory.

```
float index  field            meaning
   0         kind             0 stroke, 1 join, 2 point
   1         halfWidth        device pixels
   2, 3      x0, y0           collection space
   4, 5      x1, y1
   6, 7      x2, y2
   8..11     r, g, b, a       0..1
  12         dashPeriod       collection units; 0 = solid;
                              NEGATIVE marks the collapse representative
  13         dashPhase        collection units, already reduced into [0, |period|)
  14         dashFracStart    the element's start, as a fraction of the cycle
  15         dashFracEnd      the element's end, as a fraction of the cycle
```

Sixteen floats, **64 bytes** per instance, up from Plan B's 48.

**Vertex attributes — eight, which is the ES 100 floor (Ruling C6):**

| attribute | format | buffer | offset (bytes) |
|---|---|---|---|
| `corner` | float32x2 | slot 0, per vertex | 0 |
| `join_weight` | float32x4 | slot 0, per vertex | 8 |
| `kind_half` | float32x2 | slot 1, per instance | 0 |
| `p0` | float32x2 | slot 1 | 8 |
| `p1` | float32x2 | slot 1 | 16 |
| `p2` | float32x2 | slot 1 | 24 |
| `color` | float32x4 | slot 1 | 32 |
| `dash` | float32x4 | slot 1 | 48 |

**Why `dashPeriod` carries a sign instead of a seventeenth float.** When the
live period falls under `kDashCollapsePx`, the reference draws the primitive
**solid** — `dashPolyline` returns false and the caller draws the whole
polyline (`draft_painter.dart:629-631`). The shaded arm has *D* instances for
that primitive, and all *D* drawing solid would overdraw the same pixels *D*
times; with blending enabled and a translucent layer that is visibly darker,
not merely wasteful. So exactly one instance per primitive is the **collapse
representative**, and it is marked by a negative period. Every other instance
of that primitive collapses to a degenerate vertex and rasterises nothing.
The sign is exact in float32 and costs no width. M-C8 fires it.

**Why the phase is reduced into `[0, |period|)` at collection.** `fract(t)` in
the fragment stage is evaluated on a `float`; `t` grows with distance along
the primitive, and an unreduced arc phase adds the whole preceding arc length
on top of it. Reducing at collection costs one `%` per instance and buys back
the precision. **The residual precision limit is stated rather than removed**:
at a live distance of 10^6 px and a 20 px period, `t ≈ 50000`, and float32
carries about seven significant digits, so `fract(t)` is good to roughly
6×10^-3 of a cycle — about 0.12 px. Task 12 records that arithmetic; no
fixture in this plan reaches it.

---

### Task 1: The dash seam on `DrawSink`

**Files:**
- Modify: `lib/src/draw_sink.dart`
- Modify: `lib/src/canvas_draw_sink.dart`
- Modify: `lib/src/vertices_draw_sink.dart`
- Modify: `lib/src/gpu/geometry_collector.dart` (declaration only — behaviour is Task 5)
- Modify: `test/support/text_key_sink.dart`
- Test: `test/draw_sink_test.dart` (create if absent)

**Interfaces:**
- Produces: `DrawSink.shadesDashes`, `DrawSink.beginDash(DashPattern, double)`,
  `DrawSink.endDash()`, `BeginDashOp`, `EndDashOp`, and
  `RecordingDrawSink({bool shadesDashes = false})`.
- Consumes: `DashPattern` from `package:jet_cad_2d` — already exported, already
  imported by `draw_sink.dart` through the barrel.

**The one design decision, so the implementer does not have to make it.**
`beginDash` takes **two** arguments, not three. `patternToLocal` converts
pattern units to the space the coordinates in the bracketed ops are in — which
is the residual's local space, by `DrawSink`'s own contract at the top of the
file. Everything else the collector needs it derives from the residual it
already holds. The two values are exactly the two the painter already computes
at its two dash sites, so nothing new is calculated anywhere:

- polylines: `_dashScale(style, toScreen)` — the points are already in screen
  space and the residual is a bare translation.
- circles and arcs: `style.linetypeScale * document.header.globalLinetypeScale`
  — the coordinates are in the leaf's own space and the residual carries the
  scale.

- [ ] **Step 1: Write the failing test**

Create `test/draw_sink_test.dart` (or append, if it exists):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

void main() {
  const pattern = DashPattern(dashes: [12.0, -6.0], totalLength: 18.0);

  test('a recording sink defaults to not shading dashes, and says so by '
      'refusing the bracket rather than by ignoring it', () {
    final sink = RecordingDrawSink();
    expect(sink.shadesDashes, isFalse);
    expect(() => sink.beginDash(pattern, 2.5), throwsUnsupportedError);
    expect(() => sink.endDash(), throwsUnsupportedError);
  });

  test('a shading recording sink records the bracket with its scale', () {
    final sink = RecordingDrawSink(shadesDashes: true);
    expect(sink.shadesDashes, isTrue);
    sink.beginDash(pattern, 2.5);
    sink.endDash();
    expect(sink.ops, <DrawOp>[
      const BeginDashOp(pattern, 2.5),
      const EndDashOp(),
    ]);
  });

  test('the bracket ops compare by value, scale included', () {
    // The scale is part of `==` because the oracle asks whether two walks
    // dashed at the same rate, not merely whether both dashed.
    expect(const BeginDashOp(pattern, 2.5) == const BeginDashOp(pattern, 2.5),
        isTrue);
    expect(const BeginDashOp(pattern, 2.5) == const BeginDashOp(pattern, 2.6),
        isFalse);
  });

  test('every non-shading sink in this package refuses the bracket', () {
    final sinks = <DrawSink>[NullDrawSink(), RecordingDrawSink()];
    for (final sink in sinks) {
      expect(sink.shadesDashes, isFalse, reason: '$sink');
      expect(() => sink.beginDash(pattern, 1.0), throwsUnsupportedError,
          reason: '$sink');
    }
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/draw_sink_test.dart
```
Expected: compile failure — `shadesDashes`, `beginDash`, `BeginDashOp` are
not defined.

- [ ] **Step 3: Add the three members to the interface**

In `lib/src/draw_sink.dart`, inside `abstract class DrawSink`, after
`endResidual()`:

```dart
  /// Whether this sink evaluates dash patterns itself.
  ///
  /// **False means "hand me the spans"; true means "hand me the geometry and
  /// the pattern".** `DraftPainter` reads this and takes one of two routes: a
  /// false sink is given the cut spans it has always been given, through
  /// ordinary [polyline] and [arc] calls; a true sink is given the *undashed*
  /// primitive, bracketed by [beginDash] and [endDash].
  ///
  /// **The information a span carries is strictly less than the pattern that
  /// produced it.** A two-point span has no cycle, no phase and no element
  /// index, so a sink that wants to decide dash coverage per fragment — at
  /// the live camera, rather than at whatever camera cut the spans — cannot
  /// recover what it needs from the span stream. That is the whole reason
  /// this getter exists rather than a sink simply doing something different
  /// with what it is given.
  bool get shadesDashes;

  /// Opens a dashed bracket. Every geometry op until [endDash] is dashed with
  /// [pattern].
  ///
  /// [patternToLocal] converts pattern units to the units the bracketed ops'
  /// coordinates are in — which is the residual's local space, by this
  /// interface's own contract above. It is `linetypeScale ×
  /// globalLinetypeScale` folded with whatever the caller has already applied
  /// to the coordinates: for a polyline the painter has already carried the
  /// points into screen space, so the factor includes the screen scale; for a
  /// curve the coordinates stay in the leaf's own space and it does not.
  ///
  /// **Only called on a sink whose [shadesDashes] is true.** Every other sink
  /// in this package throws here, deliberately: a wiring mistake that routed
  /// undashed geometry to a span-consuming sink would otherwise draw a solid
  /// line where the document says dashed, which is a picture nobody would
  /// question. A throw is loud; a solid line is not.
  void beginDash(DashPattern pattern, double patternToLocal);

  /// Closes the bracket opened by [beginDash].
  void endDash();
```

Add the ops beside the other `DrawOp` subclasses:

```dart
@immutable
final class BeginDashOp extends DrawOp {
  const BeginDashOp(this.pattern, this.patternToLocal);

  final DashPattern pattern;

  /// Part of `==` on purpose: two walks that dashed the same pattern at
  /// different rates drew different pictures, and an oracle that compared
  /// only the pattern would call them equal.
  final double patternToLocal;

  @override
  bool operator ==(Object other) =>
      other is BeginDashOp &&
      other.pattern == pattern &&
      other.patternToLocal == patternToLocal;

  @override
  int get hashCode => Object.hash(pattern, patternToLocal);

  @override
  String toString() => 'BeginDashOp($pattern, $patternToLocal)';
}

@immutable
final class EndDashOp extends DrawOp {
  const EndDashOp();

  @override
  bool operator ==(Object other) => other is EndDashOp;

  @override
  int get hashCode => (EndDashOp).hashCode;

  @override
  String toString() => 'EndDashOp()';
}
```

- [ ] **Step 4: Implement in all six sinks**

`RecordingDrawSink` — it gains a constructor it did not have. Existing
`RecordingDrawSink()` call sites keep compiling:

```dart
class RecordingDrawSink implements DrawSink {
  RecordingDrawSink({this.shadesDashes = false});

  /// **Defaults to false so this class stays the oracle it already is.**
  /// `draft_painter_test.dart` asserts span counts against a recording sink
  /// over a dashed fixture; flipping the default would change what those
  /// tests are looking at without changing a line of them.
  @override
  final bool shadesDashes;

  @override
  void beginDash(DashPattern pattern, double patternToLocal) => shadesDashes
      ? _ops.add(BeginDashOp(pattern, patternToLocal))
      : throw UnsupportedError(
          'this RecordingDrawSink does not shade dashes; '
          'construct it with shadesDashes: true to record the bracket');

  @override
  void endDash() => shadesDashes
      ? _ops.add(const EndDashOp())
      : throw UnsupportedError(
          'this RecordingDrawSink does not shade dashes');
```

`NullDrawSink`, `CanvasDrawSink`, `VerticesDrawSink`, `TextKeySink` — all four
take the same shape:

```dart
  @override
  bool get shadesDashes => false;

  @override
  void beginDash(DashPattern pattern, double patternToLocal) =>
      throw UnsupportedError(
          '<ClassName> consumes dash spans, not dash patterns; '
          'DraftPainter must not open a dash bracket on a sink whose '
          'shadesDashes is false');

  @override
  void endDash() => throw UnsupportedError('<ClassName> does not shade dashes');
```

`GeometryCollector` — **declaration only in this task.** `shadesDashes => true`,
and `beginDash`/`endDash` bodies that do nothing yet with a `// Task 5` comment.
It must compile and it must not change what the collector emits.

- [ ] **Step 5: Run the test and the suite**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/draw_sink_test.dart && flutter test
```
Expected: the new file passes; the rest of the suite is unchanged. The
collector now answers `true` to a question nobody asks yet.

- [ ] **Step 6: Gate and commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../../apps/dev_harness_2d && flutter test --concurrency=1 && flutter analyze
cd ../.. && git status --short   # analysis_options.yaml must not be staged
git add packages/jet_cad_2d_flutter/lib packages/jet_cad_2d_flutter/test
git commit -m "feat(sink): a dash bracket, for a sink that shades rather than consumes spans"
```

---

### Task 2: The painter routes undashed geometry to a shading sink

**Files:**
- Modify: `lib/src/draft_painter.dart`
- Test: `test/draft_painter_test.dart`

**Interfaces:**
- Consumes: Task 1's `shadesDashes`, `beginDash`, `endDash`, `BeginDashOp`.
- Produces: nothing new. This task is a branch at three call sites.

**The three sites, and nothing else.** `_patternFor(style)` is consulted in
exactly three places today: the polyline path in `_emitScreenSpace`, and the
`circle` and `arc` cases in the residual path. Each grows the same branch,
between the `pattern == null` early return and the `_dasher` call.

- [ ] **Step 1: Write the failing test**

Append to `test/draft_painter_test.dart`. It reuses that file's own local
`dashedFixture` helper, which already registers a `DASHED` linetype with
`DashPattern(dashes: [12.0, -6.0], totalLength: 18.0)`:

```dart
  test('a shading sink is handed the undashed polyline inside a bracket, '
      'and the bracket carries the painter\'s own dash scale', () {
    final doc = dashedFixture(
        placement: Transform2.translation(3, 2).multiply(Transform2.scale(2, 2)));
    final sink = RecordingDrawSink(shadesDashes: true);
    final camera = ViewportTransform.fit(worldOf(doc), kViewport);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    DraftPainter(
            document: doc, index: index, resolver: DocumentStyleResolver(doc))
        .paint(sink, camera, kViewport);

    final begins = sink.ops.whereType<BeginDashOp>().toList();
    expect(begins, hasLength(1),
        reason: 'one dashed leaf, one bracket -- not one per span');
    expect(sink.ops.whereType<EndDashOp>(), hasLength(1));

    // The undashed geometry, whole: two points, not a span list.
    final lines = sink.ops.whereType<PolylineOp>().toList();
    expect(lines, hasLength(1));
    expect(lines.single.points, hasLength(4));

    // The scale is the painter's own `_dashScale`: linetypeScale ×
    // globalLinetypeScale × toScreen.scaleMagnitude. Asserted as an
    // arithmetic identity against the camera, not as a copied literal --
    // a literal would survive the factor being dropped.
    final expected = 1.0 *
        doc.header.globalLinetypeScale *
        (camera.worldToScreenMatrix.scaleMagnitude * 2.0 /* placement */);
    expect(begins.single.patternToLocal, closeTo(expected, 1e-9));
  });

  test('a non-shading sink still gets spans, and no bracket', () {
    final doc = dashedFixture(placement: Transform2.translation(3, 2));
    final sink = RecordingDrawSink(); // shadesDashes: false
    // ... paint as above ...
    expect(sink.ops.whereType<BeginDashOp>(), isEmpty);
    expect(sink.ops.whereType<PolylineOp>().length, greaterThan(1),
        reason: 'the dasher cut this line into spans, as it always has');
  });

  test('a shading sink sees no dash-span counters move', () {
    // `dashSpanCount` and `collapsedDashCount` describe the dasher's work,
    // and a shading sink means the dasher never ran. Zero here is the
    // correct reading, not a broken counter -- Task 12's results note says
    // so where the harness prints them.
    final painter = /* painted into a shading sink over dashedFixture */;
    expect(painter.dashSpanCount, 0);
    expect(painter.collapsedDashCount, 0);
  });
```

**Implementer note:** the file's existing dashed tests build their camera and
painter a particular way — copy that construction rather than inventing one,
and replace the `/* ... */` placeholders above with it. The assertions are the
requirement; the scaffolding is the file's own.

- [ ] **Step 2: Run it and watch it fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/draft_painter_test.dart
```
Expected: the first test fails on `begins` being empty — the painter still
dashes into every sink.

- [ ] **Step 3: Branch the polyline site**

In `_emitScreenSpace`, immediately after the `if (pattern == null) { ... }`
block and **before** `_spanSink = sink;`:

```dart
    if (sink.shadesDashes) {
      // The sink evaluates the pattern itself, per fragment, at the live
      // camera. Handing it spans instead would freeze the dash count at
      // whatever camera this walk ran under -- which for the resident
      // backend is a camera the viewer is not looking through.
      sink.beginDash(pattern, _dashScale(style, toScreen));
      sink.polyline(_points, count, style, closed: false);
      sink.endDash();
      sink.endResidual();
      return;
    }
```

- [ ] **Step 4: Branch the two curve sites**

In the `EntityKind.circle` case, after its own `pattern == null` early return:

```dart
        if (sink.shadesDashes) {
          // Local units, not screen: the coordinates below stay in the
          // leaf's own space and the residual carries the scale, so the
          // factor must not include `chain.scaleMagnitude` -- the same
          // reason `dashArc` is passed this value and `pixelScale`
          // separately.
          sink.beginDash(pattern,
              style.linetypeScale * document.header.globalLinetypeScale);
          sink.circle(coords[0] - ox, coords[1] - oy, r, style);
          sink.endDash();
          return;
        }
```

And the identical shape in `EntityKind.arc`, calling
`sink.arc(coords[0] - ox, coords[1] - oy, r, start, sweep, style)`.

**Do not factor these three into one helper.** They differ in the scale they
pass and in the op they emit, and the two curve cases differ from each other
in their arguments; a helper would take four parameters to save six lines and
would put the one value this task is about — the scale — behind an indirection.

- [ ] **Step 5: Run the tests**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/draft_painter_test.dart && flutter test
```
Expected: green, including every existing dashed test — they all use
non-shading sinks and take the unchanged route.

- [ ] **Step 6: Commit**

```sh
git add packages/jet_cad_2d_flutter/lib/src/draft_painter.dart packages/jet_cad_2d_flutter/test/draft_painter_test.dart
git commit -m "feat(painter): a dash-shading sink gets the pattern, not the spans"
```

---

### Task 3: `shadedDashFixture()` — the corpus, and why it is not the old one

**Files:**
- Modify: `test/support/fixtures.dart`
- Test: `test/support/fixtures_test.dart` (create if absent)

**Interfaces:**
- Produces: `DraftDocument shadedDashFixture({double linetypeScale})` and the
  handles it uses, which later tasks name.

**Ruling C5 is the whole reason this is a new function.** Put the reason in
the doc comment, in the file, where the next reader will be: the
painter-versus-`reference_walk` oracle in `test/differential_test.dart` runs on
`differentialFixture`, and `reference_walk.dart` does not dash. A dashed entity
there makes that oracle red for a reason that has nothing to do with dashes.

- [ ] **Step 1: Write the fixture**

Append to `test/support/fixtures.dart`:

```dart
/// The corpus for shaded dashes.
///
/// **Separate from [differentialFixture] on purpose, and the reason is not
/// tidiness.** `test/differential_test.dart` compares [DraftPainter] against
/// `reference_walk.dart`, and the reference walk does not dash at all -- it
/// emits raw `polyline` and `arc` ops. A dashed entity in
/// [differentialFixture] would make the painter emit spans and the reference
/// walk emit whole polylines, reddening this project's oldest correctness
/// gate over a difference that is not a defect. The cost of the split is
/// that every gate which should see dashes needs a dashed arm written for it
/// explicitly; Plan C's results note lists the gates that have one.
///
/// **Nothing here sits at the identity, the origin, or a uniform scale.**
/// Every placement carries a rotation and a distinct non-uniform scale --
/// `CLAUDE.md`'s named dominant failure mode is the degenerate fixture, and a
/// dashed arc under an anisotropic placement is exactly the case Ruling C4
/// bounds.
///
/// Handles, so a test can name what it is looking at:
///
/// | handle | what |
/// |---|---|
/// | 900 | the `DASHED` linetype, `[12, -6]` -- one drawn element |
/// | 901 | the `DASHDOT` linetype, `[12, -3, 0.5, -3]` -- two drawn elements |
/// | 902 | the `ALLGAP` linetype, `[-4]` -- **no** drawn element |
/// | 910 | a five-vertex dashed polyline, three interior corners |
/// | 911 | a dashed circle -- a closed run, so the seam join is in play |
/// | 912 | a dashed arc under the non-uniform instance |
/// | 913 | a `DASHDOT` line, so `D == 2` has a witness |
/// | 914 | an `ALLGAP` line, so the collapse representative has a witness |
/// | 915 | a **solid** line crossing 910, so dash gaps have something behind them |
/// | 916 | a hairline dashed line (`lineweight: 1`), so `_coveredArgb` meets a dash |
DraftDocument shadedDashFixture({double linetypeScale = 1.0}) {
  // ... construction ...
}
```

**Construction requirements, each with its reason — the implementer chooses
the exact coordinates:**

1. **Register three linetypes** at handles 900, 901, 902 with the patterns in
   the table. `DashPattern(dashes: [...], totalLength: <the sum of the
   absolute values>)`. The totals must be *consistent* with the dashes here;
   `dasher.dart` deliberately ignores `totalLength` and this fixture must not
   be the place that hides a disagreement.
2. **Entity 910 is a five-point polyline with three interior vertices**, at
   least one of them a sharp turn (interior angle under 90°) and one nearly
   straight (turn under 5°). Ruling C3 says a dashed run emits no joins;
   a fixture whose corners are all shallow cannot tell a missing join from a
   collinear one.
3. **The whole document must span enough length that every pattern repeats at
   least four times** at the camera the tests use. A fixture where the pattern
   fits once is a fixture where `fract` is never exercised past its first
   cycle. Assert this in Step 2 rather than eyeballing it.
4. **Entity 916 carries `lineweight: 1`**, which is below one device pixel at
   `dpr` 1 and therefore routes through `_coveredArgb`. Plan B's final review
   found `lineweightScale` sitting at the identity in every instrument; a
   dashed hairline is a second, independent place that factor has to be right.
5. **Set `doc.header.globalLinetypeScale` to something other than 1.0** — use
   `1.7`. It is a multiplicand in `_dashScale` and a fixture that leaves it at
   1 cannot tell it from a dropped term.
6. The `linetypeScale` parameter multiplies entity 913's `linetypeScale` field
   only, so a test can vary one entity's rate without rebuilding the corpus.

- [ ] **Step 2: Write the fixture's own guard test**

The fixture is an instrument, so it gets a test that fails when it goes
degenerate. In `test/support/fixtures_test.dart`:

```dart
  test('shadedDashFixture is not degenerate in any of the four ways that '
      'would make a dash test pass vacuously', () {
    final doc = shadedDashFixture();

    // 1. globalLinetypeScale is a real multiplicand.
    expect(doc.header.globalLinetypeScale, isNot(1.0));

    // 2. Every placement is non-uniform and rotated.
    for (final node in /* the fixture's instance and group nodes */) {
      final t = node.transform;
      expect(t.a * t.d - t.b * t.c, isNot(0.0));
      expect((t.a.abs() - t.d.abs()).abs(), greaterThan(0.05),
          reason: 'a uniform scale cannot distinguish Ruling C4 divergence '
              'from agreement');
      expect(t.b, isNot(0.0), reason: 'unrotated');
    }

    // 3. The pattern repeats. Painted at the test camera, the longest dashed
    //    entity must be at least four periods long.
    // ... measure it through DraftPainter into a shading RecordingDrawSink,
    //     divide the polyline's screen length by cycle * patternToLocal ...
    expect(repeats, greaterThan(4.0));

    // 4. The three patterns have three different drawn-element counts.
    expect(<int>{drawnElements(900), drawnElements(901), drawnElements(902)},
        <int>{1, 2, 0});
  });
```

- [ ] **Step 3: Run**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/support/fixtures_test.dart
```
Expected: green once the fixture satisfies its own guard. **If assertion 3
fails, lengthen the geometry — do not lower the threshold.**

- [ ] **Step 4: Prove the split was necessary**

This is the step that makes Ruling C5 evidence instead of assertion. Add the
dashed polyline to `differentialFixture` **temporarily**, run
`flutter test test/differential_test.dart`, record what it printed, then
**revert with `git checkout -- test/support/fixtures.dart`** (this file is
committed and unmodified at this point, so the ban on `git checkout --` for
mutation reverts does not apply — the ban is about reverting *uncommitted work*).
Paste the failure into the task report. If it does **not** fail, say so: the
ruling then rests on a premise that did not hold and Task 12 must record that.

- [ ] **Step 5: Commit**

```sh
git add packages/jet_cad_2d_flutter/test/support/fixtures.dart packages/jet_cad_2d_flutter/test/support/fixtures_test.dart
git commit -m "test(fixtures): a dashed corpus, separate from the walk oracle's"
```

---

### Task 4: The record grows to sixteen floats and reorders

**Files:**
- Modify: `lib/src/gpu/instance_record.dart`
- Modify: `lib/src/gpu/resident_geometry.dart` (the vertex layout only)
- Test: `test/gpu/instance_record_test.dart`
- Test: `test/gpu/resident_geometry_test.dart`

**Interfaces:**
- Produces: `kFloatsPerInstance = 16`; `InstanceFieldOffset` with
  `kind = 0, halfWidth = 1, x0 = 2 … a = 11, dashPeriod = 12, dashPhase = 13,
  dashFracStart = 14, dashFracEnd = 15`; `writeStroke`/`writeJoin`/`writePoint`
  each gaining four optional named dash arguments; `kInstanceVertexLayout` with
  eight attributes.
- Consumes: nothing new.

**Two changes in one commit, on purpose.** The reorder (Ruling C6) and the
widening both move `InstanceFieldOffset`, and splitting them would leave one
commit where the layout and the writers disagree.

- [ ] **Step 1: Write the failing tests**

In `test/gpu/instance_record_test.dart`:

```dart
  test('the record is sixteen floats and kind_half is adjacent', () {
    expect(kFloatsPerInstance, 16);
    expect(InstanceFieldOffset.halfWidth, InstanceFieldOffset.kind + 1,
        reason: 'the shader reads them as one vec2 attribute, which is what '
            'keeps the attribute count at ES 100\'s floor of eight');
  });

  test('a solid stroke writes zero into all four dash slots', () {
    final into = Float32List(kFloatsPerInstance);
    writeStroke(into, 0,
        x0: 1, y0: 2, x1: 3, y1: 4, halfWidth: 0.5, argb: 0xFF112233);
    expect(into[InstanceFieldOffset.dashPeriod], 0.0);
    expect(into[InstanceFieldOffset.dashPhase], 0.0);
    expect(into[InstanceFieldOffset.dashFracStart], 0.0);
    expect(into[InstanceFieldOffset.dashFracEnd], 0.0);
  });

  test('a dashed stroke carries its element extent and its phase', () {
    final into = Float32List(kFloatsPerInstance);
    writeStroke(into, 0,
        x0: 1, y0: 2, x1: 3, y1: 4, halfWidth: 0.5, argb: 0xFF112233,
        dashPeriod: 18.0, dashPhase: 4.0,
        dashFracStart: 0.0, dashFracEnd: 12.0 / 18.0);
    expect(into[InstanceFieldOffset.dashPeriod], 18.0);
    expect(into[InstanceFieldOffset.dashPhase], 4.0);
    expect(into[InstanceFieldOffset.dashFracEnd], closeTo(0.6667, 1e-4));
  });

  test('a negative period is preserved bit for bit -- it is the collapse '
      'representative marker, not a magnitude', () {
    final into = Float32List(kFloatsPerInstance);
    writeJoin(into, 0,
        vx: 0, vy: 0, prevX: -1, prevY: 0, nextX: 0, nextY: 1,
        halfWidth: 1, argb: 0xFF000000, dashPeriod: -18.0);
    expect(into[InstanceFieldOffset.dashPeriod], -18.0);
    expect(into[InstanceFieldOffset.dashPeriod].isNegative, isTrue);
  });

  test('a point is never dashed', () {
    // `VerticesDrawSink.point` does not consult a linetype, and neither does
    // the painter's point path -- `_emitScreenSpace` returns before
    // `_patternFor` is ever called. `writePoint` therefore takes no dash
    // arguments at all, so a caller cannot express something the reference
    // cannot draw.
    final into = Float32List(kFloatsPerInstance);
    writePoint(into, 0, x: 1, y: 2, halfWidth: 0.5, argb: 0xFF112233);
    expect(into[InstanceFieldOffset.dashPeriod], 0.0);
  });
```

In `test/gpu/resident_geometry_test.dart`:

```dart
  test('the vertex layout declares eight attributes, which is the ES 100 '
      'floor the shader header claims', () {
    final attributes = ResidentGeometry.kInstanceVertexLayout.buffers
        .expand((b) => b.attributes)
        .toList();
    expect(attributes, hasLength(8),
        reason: 'gl_MaxVertexAttribs is guaranteed to be at least 8 and no '
            'more; a ninth binds on every platform this project runs on '
            'today and falsifies the header');
    expect(attributes.map((a) => a.name), containsAll(<String>[
      'corner', 'join_weight', 'kind_half', 'p0', 'p1', 'p2', 'color', 'dash',
    ]));
  });

  test('every instance attribute offset is derived from InstanceFieldOffset', () {
    final instanceBuffer = ResidentGeometry.kInstanceVertexLayout.buffers[1];
    expect(instanceBuffer.strideInBytes, kFloatsPerInstance * 4);
    expect(
        instanceBuffer.attributes
            .firstWhere((a) => a.name == 'dash')
            .offsetInBytes,
        InstanceFieldOffset.dashPeriod * 4);
  });

  test('the buffer prices sixteen floats', () {
    expect(ResidentGeometry.byteLengthFor(1000), 1000 * 16 * 4);
  });
```

- [ ] **Step 2: Run and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/instance_record_test.dart test/gpu/resident_geometry_test.dart
```
Expected: `kFloatsPerInstance` is 12, `dashPeriod` is undefined.

- [ ] **Step 3: Rewrite `InstanceFieldOffset` and `kFloatsPerInstance`**

```dart
/// Floats per instance record.
///
/// `[kind, halfWidth, x0, y0, x1, y1, x2, y2, r, g, b, a,
///   dashPeriod, dashPhase, dashFracStart, dashFracEnd]`.
///
/// **Sixteen floats, none of them packed, because of the web.** ES 100 has
/// neither bitwise operators nor integer vertex attributes. 64 bytes per
/// record.
///
/// **Twelve became sixteen in Plan C**, and `kind` moved next to `halfWidth`
/// in the same change. The four new slots carry the dash: the period in
/// collection units, the phase at this instance's start, and the drawn
/// pattern element's own extent as a fraction of the cycle. The move is
/// Ruling C6: the shader reads `kind` and `half_width` as one `vec2`
/// attribute, because `gl_MaxVertexAttribs` is guaranteed to be no more than
/// 8 under GLSL ES 100 and the eighth slot is now the `dash` quad.
///
/// **`dashPeriod` is signed and the sign is data.** Zero means solid.
/// Negative marks the one instance per primitive that draws solid when the
/// live period falls under `kDashCollapsePx` -- see `cad_stroke.vert`'s
/// collapse branch, and Plan C's record section for why the alternative
/// (every instance of a collapsed primitive drawing solid) is visibly wrong
/// rather than merely wasteful.
const int kFloatsPerInstance = 16;

abstract final class InstanceFieldOffset {
  static const int kind = 0;
  static const int halfWidth = 1;
  static const int x0 = 2;
  static const int y0 = 3;
  static const int x1 = 4;
  static const int y1 = 5;
  static const int x2 = 6;
  static const int y2 = 7;
  static const int r = 8;
  static const int g = 9;
  static const int b = 10;
  static const int a = 11;
  static const int dashPeriod = 12;
  static const int dashPhase = 13;
  static const int dashFracStart = 14;
  static const int dashFracEnd = 15;
}
```

- [ ] **Step 4: Widen the writers**

`writeStroke` and `writeJoin` each gain four optional named arguments,
defaulting to solid. `writePoint` gains none — see the test above for why.

```dart
void writeStroke(
  Float32List into,
  int index, {
  required double x0,
  required double y0,
  required double x1,
  required double y1,
  required double halfWidth,
  required int argb,
  /// Collection units. 0 is solid; a negative value marks the collapse
  /// representative and its magnitude is the period.
  double dashPeriod = 0,
  double dashPhase = 0,
  double dashFracStart = 0,
  double dashFracEnd = 0,
}) {
  final o = index * kFloatsPerInstance;
  into[o + InstanceFieldOffset.kind] = kKindStroke;
  into[o + InstanceFieldOffset.halfWidth] = halfWidth;
  into[o + InstanceFieldOffset.x0] = x0;
  // ... y0, x1, y1, and x2/y2 = 0 ...
  _writeColor(into, o, argb);
  _writeDash(into, o, dashPeriod, dashPhase, dashFracStart, dashFracEnd);
}

void _writeDash(Float32List into, int o, double period, double phase,
    double fracStart, double fracEnd) {
  into[o + InstanceFieldOffset.dashPeriod] = period;
  into[o + InstanceFieldOffset.dashPhase] = phase;
  into[o + InstanceFieldOffset.dashFracStart] = fracStart;
  into[o + InstanceFieldOffset.dashFracEnd] = fracEnd;
}
```

- [ ] **Step 5: Rewrite the instance half of `kInstanceVertexLayout`**

Six attributes, offsets derived from `InstanceFieldOffset` as they already are:

```dart
        attributes: <gpu.VertexAttribute>[
          gpu.VertexAttribute(
              name: 'kind_half',
              format: gpu.VertexFormat.float32x2,
              offsetInBytes: InstanceFieldOffset.kind * 4),
          gpu.VertexAttribute(
              name: 'p0',
              format: gpu.VertexFormat.float32x2,
              offsetInBytes: InstanceFieldOffset.x0 * 4),
          gpu.VertexAttribute(
              name: 'p1',
              format: gpu.VertexFormat.float32x2,
              offsetInBytes: InstanceFieldOffset.x1 * 4),
          gpu.VertexAttribute(
              name: 'p2',
              format: gpu.VertexFormat.float32x2,
              offsetInBytes: InstanceFieldOffset.x2 * 4),
          gpu.VertexAttribute(
              name: 'color',
              format: gpu.VertexFormat.float32x4,
              offsetInBytes: InstanceFieldOffset.r * 4),
          gpu.VertexAttribute(
              name: 'dash',
              format: gpu.VertexFormat.float32x4,
              offsetInBytes: InstanceFieldOffset.dashPeriod * 4),
        ],
```

Update the doc comment above it: it currently narrates the twelve-float
record and its `[kind, x0, y0, ...]` order. A doc that describes the old order
beside the new offsets is worse than no doc.

- [ ] **Step 6: Run everything**

```sh
cd packages/jet_cad_2d_flutter && flutter test
```
Expected: `test/gpu/instance_expander_test.dart`,
`test/gpu/collector_differential_test.dart`,
`test/gpu/geometry_collector_test.dart` and
`test/gpu/resident_pixel_differential_test.dart` **all fail** — the expander
reads `InstanceFieldOffset` live and its arithmetic is fine, but anything
asserting a float count or a byte size moves. **Repair every one of them in
this task.** A widening that leaves the suite red is not a completed task, and
the shader is not touched yet, so nothing here is blocked on the bundle.

- [ ] **Step 7: Commit**

```sh
git add packages/jet_cad_2d_flutter/lib packages/jet_cad_2d_flutter/test
git commit -m "feat(gpu): sixteen floats, and kind beside half-width for ES 100's eighth attribute"
```

---

### Task 5: The collector shades a dashed polyline

**Files:**
- Modify: `lib/src/gpu/geometry_collector.dart`
- Test: `test/gpu/geometry_collector_test.dart`

**Interfaces:**
- Consumes: Task 1's bracket, Task 4's writers.
- Produces: the collector's dash state and its emission rule, which Task 6
  extends to curves and Task 8's oracle reproduces.

**The emission rule, stated once.** For a dashed primitive with *D* drawn
elements in its cycle, the collector emits **exactly *D* instances per
geometric primitive** (or exactly **one** when *D* is zero), consecutively, in
ascending cycle position. Instance *k* carries:

| field | value |
|---|---|
| `dashPeriod` | `periodLocal × factor`, negated when `k == 0` |
| `dashPhase` | `(phaseLocal mod periodLocal) × factor` |
| `dashFracStart` | `cumulative(k) / cycle` |
| `dashFracEnd` | `(cumulative(k) + |dashes[k]|) / cycle` |

where `periodLocal = cycle × patternToLocal`, and **`factor` is the primitive's
own local-to-collection length ratio**, not the residual's `scaleMagnitude`:

```
factor = (the primitive's length in collection space)
       / (the primitive's length in the space the pattern is measured in)
```

For a polyline segment both lengths are the segment's, so `factor` is 1
whenever the residual is a translation — which is every call the painter makes
— and is exactly right when it is not. **Computing it rather than assuming 1 is
what makes an anisotropic residual correct per segment instead of correct on
average**, which is the same approximation `draft_painter.dart`'s own
`anisotropicCurveCount` exists to count.

**Ruling C3 in code: `_suppressJoins`.** A dashed run emits no joins. The
reference gives every span its own `polyline` op and therefore its own run, so
it has no join geometry on a dashed polyline anywhere.

- [ ] **Step 1: Write the failing tests**

In `test/gpu/geometry_collector_test.dart`:

```dart
  const dashed = DashPattern(dashes: [12.0, -6.0], totalLength: 18.0);
  const dashDot = DashPattern(dashes: [12.0, -3.0, 0.5, -3.0], totalLength: 18.5);
  const allGap = DashPattern(dashes: [-4.0], totalLength: 4.0);
  const style = ResolvedStyle(
      argb: 0xFF112233,
      lineweightHundredths: 25,
      linetype: Handle(900),
      linetypeScale: 1.0);

  test('a dashed polyline emits one instance per segment per drawn element, '
      'and no joins at all', () {
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.translation(10, 20));
    c.beginDash(dashed, 2.0);
    c.polyline(Float64List.fromList([0, 0, 10, 0, 10, 10]), 3, style,
        closed: false);
    c.endDash();
    c.endResidual();

    // Two segments, one drawn element, no joins.
    expect(c.instanceCount, 2);
    for (var i = 0; i < 2; i++) {
      expect(c.data[i * kFloatsPerInstance + InstanceFieldOffset.kind],
          kKindStroke,
          reason: 'a dashed run has no joins: the reference gives every span '
              'its own polyline op and therefore its own run');
    }
  });

  test('the same polyline undashed keeps its join -- so the assertion above '
      'is about dashes, not about the fixture', () {
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.translation(10, 20));
    c.polyline(Float64List.fromList([0, 0, 10, 0, 10, 10]), 3, style,
        closed: false);
    c.endResidual();
    expect(c.instanceCount, 3); // segment, join, segment
  });

  test('a two-element pattern doubles the instances and the two elements '
      'tile the cycle without overlapping', () {
    final c = /* as above, but beginDash(dashDot, 2.0) and one segment */;
    expect(c.instanceCount, 2);
    final e0Start = c.data[InstanceFieldOffset.dashFracStart];
    final e0End = c.data[InstanceFieldOffset.dashFracEnd];
    final e1Start =
        c.data[kFloatsPerInstance + InstanceFieldOffset.dashFracStart];
    final e1End = c.data[kFloatsPerInstance + InstanceFieldOffset.dashFracEnd];
    expect(e0Start, 0.0);
    expect(e0End, closeTo(12.0 / 18.5, 1e-6));
    expect(e1Start, closeTo(15.0 / 18.5, 1e-6));
    expect(e1End, closeTo(15.5 / 18.5, 1e-6));
    expect(e0End, lessThan(e1Start), reason: 'the gap between them is a gap');
  });

  test('the period is the cycle times the scale, in collection units', () {
    // cycle 18, patternToLocal 2.0, residual a translation -> factor 1.
    final c = /* one dashed segment, beginDash(dashed, 2.0) */;
    expect(c.data[InstanceFieldOffset.dashPeriod].abs(), closeTo(36.0, 1e-6));
  });

  test('a scaled residual scales the period, because the pattern is measured '
      'in the space the points are in', () {
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.scale(3.0, 3.0));
    c.beginDash(dashed, 2.0);
    c.polyline(Float64List.fromList([0, 0, 10, 0]), 2, style, closed: false);
    c.endDash();
    c.endResidual();
    expect(c.data[InstanceFieldOffset.dashPeriod].abs(), closeTo(108.0, 1e-4),
        reason: '18 x 2.0 x 3.0');
  });

  test('exactly one instance per primitive is the collapse representative', () {
    final c = /* one dashed segment with dashDot, so D == 2 */;
    final periods = <double>[
      c.data[InstanceFieldOffset.dashPeriod],
      c.data[kFloatsPerInstance + InstanceFieldOffset.dashPeriod],
    ];
    expect(periods.where((p) => p < 0), hasLength(1),
        reason: 'two representatives would draw the collapsed line twice, '
            'and with blending on that is darker, not merely wasteful');
    expect(periods.first, lessThan(0), reason: 'the first drawn element');
  });

  test('a pattern with no drawn element still emits one instance, so the '
      'collapse case has something to draw', () {
    final c = /* one segment, beginDash(allGap, 2.0) */;
    expect(c.instanceCount, 1);
    expect(c.data[InstanceFieldOffset.dashPeriod], lessThan(0));
    expect(c.data[InstanceFieldOffset.dashFracStart],
        c.data[InstanceFieldOffset.dashFracEnd],
        reason: 'an empty extent draws nothing until the pattern collapses, '
            'and the reference draws the whole line solid when it does');
  });

  test('endDash restores solid emission', () {
    final c = /* beginDash, one polyline, endDash, a second polyline */;
    // The second polyline is a plain two-segment run: two segments, one join.
    expect(c.instanceCount, 1 + 3);
  });

  test('a zero-cycle pattern is solid, matching dashPolyline returning false', () {
    const degenerate = DashPattern(dashes: [0.0], totalLength: 0.0);
    final c = /* beginDash(degenerate, 2.0), one segment */;
    expect(c.instanceCount, 1);
    expect(c.data[InstanceFieldOffset.dashPeriod], 0.0);
  });

  test('the phase of every polyline segment is zero -- the pattern restarts '
      'at each vertex, which is dasher.dart:94-96', () {
    final c = /* a three-segment dashed polyline */;
    for (var i = 0; i < c.instanceCount; i++) {
      expect(c.data[i * kFloatsPerInstance + InstanceFieldOffset.dashPhase], 0.0);
    }
  });
```

- [ ] **Step 2: Run and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```
Expected: instance counts are the solid ones and every dash field reads 0 —
`beginDash` is still the empty stub Task 1 left.

- [ ] **Step 3: Add the bracket state**

```dart
  // --- the dash bracket ---------------------------------------------------
  //
  // Set by `beginDash`, cleared by `endDash`. Kept as fields rather than
  // threaded through `_runTo` for the same reason `DraftPainter` keeps
  // `_spanSink` and `_spanStyle` as fields: the alternative is a closure or a
  // widened signature on the hot path, and this class's contract is that a
  // rebuild allocates per document, not per primitive.
  bool _dashActive = false;
  double _dashPeriodLocal = 0;
  double _dashCycle = 0;

  /// The drawn elements' extents, as fractions of the cycle. Two parallel
  /// lists rather than a list of pairs: a pair object per element per
  /// `beginDash` is an allocation per dashed entity per rebuild.
  final List<double> _dashFracStart = <double>[];
  final List<double> _dashFracEnd = <double>[];

  /// Per-primitive values, set immediately before the `_emit` / `_emitJoin`
  /// call that consumes them. Same idiom, same reason.
  double _pendingSegPeriod = 0, _pendingSegPhase = 0;
  double _pendingJoinPeriod = 0, _pendingJoinPhase = 0;
  bool _suppressJoins = false;

  @override
  bool get shadesDashes => true;

  @override
  void beginDash(DashPattern pattern, double patternToLocal) {
    _dashFracStart.clear();
    _dashFracEnd.clear();
    // The cycle is summed from the array, never read from
    // `pattern.totalLength` -- `dasher.dart` says why in as many words, and
    // this class must agree with the dasher about where a cycle ends or the
    // two draw different pictures from the same pattern.
    var cycle = 0.0;
    for (final d in pattern.dashes) {
      cycle += d.abs();
    }
    if (!cycle.isFinite || cycle <= 0.0 || !patternToLocal.isFinite) {
      // `dashPolyline` returns false here and the caller draws solid. This is
      // the same decision, reached by the same test.
      _dashActive = false;
      return;
    }
    _dashCycle = cycle;
    _dashPeriodLocal = cycle * patternToLocal;
    var at = 0.0;
    for (final d in pattern.dashes) {
      final w = d.abs();
      if (d >= 0) {
        _dashFracStart.add(at / cycle);
        _dashFracEnd.add((at + w) / cycle);
      }
      at += w;
    }
    _dashActive = true;
  }

  @override
  void endDash() {
    _dashActive = false;
    _suppressJoins = false;
    _pendingSegPeriod = 0;
    _pendingSegPhase = 0;
    _pendingJoinPeriod = 0;
    _pendingJoinPhase = 0;
  }
```

**A note the implementer must keep in the code**: `beginDash` uses `|d|` for
the extents where `dasher.dart` substitutes `1e-9` for a zero-length element
(`dasher.dart:169`). The divergence is `1e-9` pattern units per zero element,
which against a period the collapse rule floors at 3 device pixels is at most
`3 × 10^-10` px — below any representable difference. **Say that in the
comment**; a reader who spots the mismatch must find the arithmetic there
rather than "fixing" it.

- [ ] **Step 4: Make `_emit` and `_emitJoin` emit the element fan**

```dart
  /// Writes this primitive's instances: one, if it is solid; one per drawn
  /// pattern element, if it is dashed; exactly one, if it is dashed with a
  /// pattern that draws nothing.
  ///
  /// **The first instance carries a negative period.** That marks it as the
  /// primitive's collapse representative -- the one the shader draws solid
  /// when the live period falls under `kDashCollapsePx`, while its
  /// siblings collapse to a degenerate vertex. Without the mark, all of them
  /// draw solid and a collapsed translucent line is drawn D times over
  /// itself.
  void _emit(double x0, double y0, double x1, double y1, double half, int argb) {
    final dx = x1 - x0, dy = y1 - y0;
    if (math.sqrt(dx * dx + dy * dy) == 0) return;
    final period = _pendingSegPeriod;
    if (period == 0.0) {
      _reserve(_instances + 1);
      writeStroke(_buffer, _instances,
          x0: x0, y0: y0, x1: x1, y1: y1, halfWidth: half, argb: argb);
      _instances++;
      return;
    }
    final n = _dashFracStart.isEmpty ? 1 : _dashFracStart.length;
    _reserve(_instances + n);
    for (var k = 0; k < n; k++) {
      writeStroke(_buffer, _instances,
          x0: x0,
          y0: y0,
          x1: x1,
          y1: y1,
          halfWidth: half,
          argb: argb,
          dashPeriod: k == 0 ? -period : period,
          dashPhase: _pendingSegPhase,
          dashFracStart: k < _dashFracStart.length ? _dashFracStart[k] : 0.0,
          dashFracEnd: k < _dashFracEnd.length ? _dashFracEnd[k] : 0.0);
      _instances++;
    }
  }
```

`_emitJoin` takes the identical shape against `_pendingJoinPeriod` /
`_pendingJoinPhase`, keeping its existing `debugCollinearJoins` accounting —
**count the corner once, not once per element**, or that diagnostic starts
reporting *D* times the corners the drawing has.

- [ ] **Step 5: Suppress joins on a dashed run**

In `_runTo`, guard the join call:

```dart
    if (_runHasDirection && !_suppressJoins) {
      _emitJoin(_runPrevX, _runPrevY, _runBackX, _runBackY, x, y, half, argb);
    } else if (!_runHasDirection) {
      _runSecondX = x;
      _runSecondY = y;
    }
```

**Read that carefully — the `else` branch is not a stylistic rewrite.** The
original is `if (_runHasDirection) { join } else { record the second point }`,
and `_runSecondX/Y` must still be recorded on the first step even when joins
are suppressed, because `_endRun` uses it for the seam. Writing this as
`if (A && !B) {...} else {...}` would record the second point on *every*
suppressed step and corrupt the seam. The shape above is the correct one.

And in `_endRun`, guard the seam join with `!_suppressJoins` too — Task 6
derives why.

- [ ] **Step 6: Give `polyline` the dashed path**

```dart
  @override
  void polyline(Float64List points, int count, ResolvedStyle style,
      {required bool closed}) {
    if (count < 2) return;
    final half = _halfWidthFor(style.lineweightHundredths);
    final argb = _coveredArgb(style.argb, style.lineweightHundredths);
    final t = _residual;
    _suppressJoins = _dashActive;
    var px = t.a * points[0] + t.c * points[1] + t.e;
    var py = t.b * points[0] + t.d * points[1] + t.f;
    _beginRun(px, py);
    for (var i = 1; i < count; i++) {
      final lx = points[i * 2], ly = points[i * 2 + 1];
      final nx = t.a * lx + t.c * ly + t.e;
      final ny = t.b * lx + t.d * ly + t.f;
      if (_dashActive) {
        // The phase restarts at every vertex (`dasher.dart:94-96`), so a
        // polyline's segments all carry phase 0. The period is scaled by
        // THIS segment's own local-to-collection length ratio rather than by
        // the residual's scale magnitude: under an anisotropic residual the
        // two disagree, and only the first one is right for this segment.
        final llx = lx - points[i * 2 - 2], lly = ly - points[i * 2 - 1];
        final localLen = math.sqrt(llx * llx + lly * lly);
        final cdx = nx - px, cdy = ny - py;
        final collectionLen = math.sqrt(cdx * cdx + cdy * cdy);
        _pendingSegPeriod =
            localLen > 0 ? _dashPeriodLocal * (collectionLen / localLen) : 0.0;
        _pendingSegPhase = 0.0;
      }
      _runTo(nx, ny, half, argb);
      px = nx;
      py = ny;
    }
    _endRun(closed: closed, half: half, argb: argb);
    _suppressJoins = false;
    _pendingSegPeriod = 0;
  }
```

**Watch the `_pendingSegPeriod = 0` at the end.** A pending value that
survives the primitive is a value the next solid primitive silently inherits.
The final `endDash` clears it too; both are needed, because `polyline` can be
called twice inside one bracket.

- [ ] **Step 7: Run**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart && flutter test
```
Expected: the new tests pass; everything else is unchanged, because
`_dashActive` is false for every existing caller.

- [ ] **Step 8: Commit**

```sh
git add packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart
git commit -m "feat(gpu): a dashed polyline collects as elements, not as spans"
```

---

### Task 6: The collector shades a dashed circle and arc

**Files:**
- Modify: `lib/src/gpu/geometry_collector.dart`
- Test: `test/gpu/geometry_collector_test.dart`

**Interfaces:**
- Consumes: Task 5's state and emission rule.
- Produces: the arc phase law, which Task 8's oracle reproduces.

**Ruling C3, third clause — derived here rather than assumed.** A dashed
closed run gets **no seam join**. The reference emits each arc span as its own
`arc()` op (`draft_painter.dart:311-314`), so a dashed circle is a sequence of
*open* runs and there is no closed run anywhere in it — the seam join, which
exists only on a closed run, is not drawn. Suppressing it on a dashed run is
therefore the reference's behaviour, not an omission. **A dashed circle is
notched at its start angle in both arms, and the solid circle's seam test
remains the gate that the notch is fixed when the linetype is continuous.**

**The phase law.** `dasher.dart` measures the pattern along the arc in
**local** units — `_walkArcRange` converts a distance to an angle by dividing
by `r` (`dasher.dart:346`), and `dashArc` is passed `scale = linetypeScale ×
globalLinetypeScale` with no screen term. So:

```
phaseLocal(i)  = r * |step| * i          // arc length from `start` to vertex i
period(i)      = periodLocal * factor(i)
factor(i)      = |chord i in collection space| / (r * |step|)
phase(i)       = (phaseLocal(i) mod periodLocal) * factor(i)
```

**`factor` divides by the local ARC length, not the local chord length.** The
reference measures the pattern along the arc; the shaded arm measures it along
the chord the shader draws. Dividing by the arc length makes the two agree at
every chord *endpoint* exactly, and leaves a bounded disagreement inside a
chord — at most `arc − chord` over one chord, which for a chord flattened to
`kFlattenTolerance = 0.25` px of sagitta is under a tenth of a pixel of phase
at the collection scale. **That is the honest form of Ruling C4** and the
comment in the code must say it.

- [ ] **Step 1: Write the failing tests**

```dart
  test('a dashed arc carries a running phase, and consecutive chords advance '
      'it by one chord of arc length', () {
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.translation(5, 7));
    c.beginDash(dashed, 0.5);
    c.arc(0, 0, 40, 0, 1.2, style);
    c.endDash();
    c.endResidual();

    // Read the phases off the stroke instances in order.
    final phases = <double>[/* every kKindStroke instance's dashPhase */];
    expect(phases.first, 0.0);
    // Each step advances by r * |sweep| / steps, reduced mod the period.
    final period = /* the first instance's |dashPeriod| */;
    for (var i = 1; i < phases.length; i++) {
      final delta = (phases[i] - phases[i - 1] + period) % period;
      expect(delta, closeTo(expectedChordArc, 1e-3),
          reason: 'a constant advance is what "running" means; a phase that '
              'restarts per chord is dasher.dart\'s polyline rule applied '
              'to a curve, which is the spec\'s own named mutation');
    }
  });

  test('a dashed circle emits no seam join', () {
    final c = /* beginDash(dashed, 0.5); circle(0, 0, 40, style); endDash() */;
    final solid = /* the same circle with no bracket */;
    // The solid circle's join count is chords; the dashed one's is chords - 1
    // (interior joins only, no seam).
    expect(joinCount(c), joinCount(solid) - 1);
  });

  test('a solid circle still has its seam join -- the assertion above is '
      'about dashes', () {
    // Guards against "no joins at all" passing the test above.
    final solid = /* circle, no bracket */;
    expect(joinCount(solid), greaterThan(0));
  });

  test('the chord count does not change when a dash bracket is open', () {
    // Flattening is a scale decision, not a linetype one. A dashed arc that
    // chorded differently from a solid one would put the two arms' geometry
    // in different places for a reason that has nothing to do with the
    // pattern.
    expect(strokeCount(dashedArc) ~/ drawnElements, strokeCount(solidArc));
  });

  test('an anisotropic residual scales each chord\'s period by that chord\'s '
      'own ratio, not by one number for the whole arc', () {
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.scale(3.0, 1.0)); // a circle becomes an ellipse
    c.beginDash(dashed, 0.5);
    c.arc(0, 0, 40, 0, math.pi, style);
    c.endDash();
    c.endResidual();
    final periods = <double>[/* every stroke instance's |dashPeriod| */];
    expect(periods.reduce(math.max) / periods.reduce(math.min),
        closeTo(3.0, 0.1),
        reason: 'a chord along x is stretched 3x and a chord along y is not; '
            'one period for the whole arc would read 1.0 here and would be '
            'the scaleMagnitude approximation this fixture exists to reject');
  });

  test('the phase is reduced into [0, period) at collection', () {
    // A long arc accumulates many periods; leaving them in the record spends
    // float32 precision the fragment stage needs for `fract`.
    final c = /* a long dashed arc */;
    for (final phase in allPhases) {
      expect(phase, greaterThanOrEqualTo(0.0));
      expect(phase, lessThan(matchingPeriod));
    }
  });
```

- [ ] **Step 2: Run and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```
Expected: every phase reads 0 — `_flatten` sets no pending dash values.

- [ ] **Step 3: Thread the phase through `_flatten`**

Inside `_flatten`, after `steps` and `step` are computed:

```dart
    _suppressJoins = false; // arcs keep their interior joins -- Ruling C3
    final arcStep = r * step.abs(); // local arc length per chord
    var lx = cx + r * math.cos(start);
    var ly = cy + r * math.sin(start);
    var px = t.a * lx + t.c * ly + t.e;
    var py = t.b * lx + t.d * ly + t.f;
    _beginRun(px, py);
    final last = closed ? steps - 1 : steps;
    for (var i = 1; i <= last; i++) {
      final angle = start + step * i;
      lx = cx + r * math.cos(angle);
      ly = cy + r * math.sin(angle);
      final nx = t.a * lx + t.c * ly + t.e;
      final ny = t.b * lx + t.d * ly + t.f;
      if (_dashActive && arcStep > 0) {
        final cdx = nx - px, cdy = ny - py;
        // The pattern is measured along the ARC and drawn along the CHORD.
        // Dividing the chord's collection length by the chord's LOCAL ARC
        // length makes the two agree exactly at every chord endpoint and
        // leaves the disagreement inside one chord, bounded by (arc - chord)
        // -- under a tenth of a pixel at this flattener's 0.25 px sagitta.
        // Ruling C4 records this rather than removing it: removing it means
        // re-chording per span, which is chording at one camera, which is
        // what this plan exists to stop doing.
        final factor = math.sqrt(cdx * cdx + cdy * cdy) / arcStep;
        _pendingSegPeriod = _dashPeriodLocal * factor;
        _pendingSegPhase = (arcStep * (i - 1)) % _dashPeriodLocal * factor;
        // The join at the vertex this step arrives from sits at the START of
        // this chord, so it takes this chord's phase and this chord's factor.
        _pendingJoinPeriod = _pendingSegPeriod;
        _pendingJoinPhase = _pendingSegPhase;
      }
      _runTo(nx, ny, half, argb);
      px = nx;
      py = ny;
    }
    if (_dashActive) _suppressJoins = true; // no seam join -- Ruling C3
    _endRun(closed: closed, half: half, argb: argb);
    _suppressJoins = false;
    _pendingSegPeriod = 0;
    _pendingSegPhase = 0;
    _pendingJoinPeriod = 0;
    _pendingJoinPhase = 0;
```

**Read the `_pendingSegPhase` line's precedence.** Dart's `%` and `*` bind
left to right at the same precedence, so
`(arcStep * (i - 1)) % _dashPeriodLocal * factor` is
`(((arcStep * (i - 1)) % _dashPeriodLocal) * factor)` — the reduction happens
before the scaling, which is what the phase law requires. **Parenthesise it
anyway.** A precedence argument in a comment is a defect waiting for a reader
who does not check.

**And read the `_endRun` ordering.** The closing chord that `_endRun` emits for
a closed run carries the *last* pending values, which are the final chord's —
correct, since the closing chord is the arc's last one. Setting
`_suppressJoins = true` before `_endRun` suppresses the seam join without
suppressing that closing chord's own emission, because `_emit` does not consult
`_suppressJoins` at all.

- [ ] **Step 4: Run**

```sh
cd packages/jet_cad_2d_flutter && flutter test
```

- [ ] **Step 5: Commit**

```sh
git add packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart
git commit -m "feat(gpu): a dashed arc carries a running phase, per chord"
```

---

### Task 7: The live scale reaches the shader, in the same 80 bytes

**Files:**
- Modify: `lib/src/gpu/gpu_draw_backend.dart`
- Test: `test/gpu/frame_info_test.dart`

**Interfaces:**
- Produces: `buildFrameInfo(Transform2, int, int, {required double dashScale})`,
  writing `dashScale` at float index 18 of the same 80-byte block.
- Consumes: nothing new.

**The block does not grow, and that is arithmetic rather than luck.** std140
puts `mat4 mvp` at bytes 0–63 and `vec2 half_viewport` at 64–71; a trailing
`float` needs 4-byte alignment, so it sits at 72–75, and the struct's own
16-byte alignment rounds 76 up to **80** — exactly the size
`buildFrameInfo` already writes, with float indices 18 and 19 currently zero.
`dash_scale` takes index 18. **Do not add a `vec2` and leave one component
unread**: an entirely unread uniform member risks being optimised out of the
reflection, and this project has already lost a bisect to
*"Could not complete reflection on generated shader"*.

**What the number is.** Live **logical** pixels per collection unit. The
collection buffer is in the collection camera's logical screen space, and
`GpuDrawBackend.render` already computes the collection-to-live-logical
transform on its way to the device one — it is the inner `composeTransforms`
call. Its `scaleMagnitude` is the whole answer.

**Logical, not device, and the reason is `kDashCollapsePx`.** That constant is
compared against `cycle × scale` in `dashPolyline`, where the points are the
painter's screen-space points — logical pixels (`viewport_transform.dart`:
*"screen coordinates are logical pixels"*) — and against `period × pixelScale`
in `dashArc`, where `pixelScale` is `chain.scaleMagnitude`, also logical.
Handing the shader a device-space ratio would collapse patterns at
`dpr` times the wrong zoom: right at `dpr == 1`, wrong on every retina display,
which is the exact shape of the defect Plan A's device run found in the
half-width.

- [ ] **Step 1: Write the failing tests**

In `test/gpu/frame_info_test.dart`:

```dart
  test('the block is still 80 bytes and dash_scale is at float 18', () {
    final data = buildFrameInfo(Transform2.identity(), 800, 600, dashScale: 2.5);
    expect(data.lengthInBytes, 80);
    expect(data.getFloat32(18 * 4, Endian.host), 2.5);
    expect(data.getFloat32(19 * 4, Endian.host), 0.0,
        reason: 'the tail stays zero; the block\'s size comes from the mat4\'s '
            'alignment, not from a member sitting there');
  });

  test('dash_scale does not disturb the mvp or the half viewport', () {
    final without = buildFrameInfo(someTransform, 800, 600, dashScale: 1.0);
    final with3 = buildFrameInfo(someTransform, 800, 600, dashScale: 3.0);
    for (var i = 0; i < 18; i++) {
      expect(with3.getFloat32(i * 4, Endian.host),
          without.getFloat32(i * 4, Endian.host),
          reason: 'float $i');
    }
  });

  test('the scale is logical, not device -- a dpr of 2 does not double it', () {
    // Built from the same camera pair at dpr 1 and dpr 2 through the
    // backend's own composition, the dash scale must read the same number.
    // A device-space ratio would read twice as large at dpr 2 and would
    // collapse every dash pattern at half the zoom it should.
    expect(dashScaleAt(dpr: 2.0), closeTo(dashScaleAt(dpr: 1.0), 1e-9));
  });
```

**The third test needs a seam to observe.** `render` cannot run without a GPU.
Extract the one line that computes the ratio into a top-level function beside
`composeTransforms` and test that:

```dart
/// Live logical pixels per collection unit — the factor the shader compares
/// a dash period against `kDashCollapsePx`.
///
/// **Logical, deliberately.** See this file's `buildFrameInfo` doc.
double dashScaleFor(ViewportTransform camera, Transform2 collectionInverse) =>
    composeTransforms(camera.worldToScreenMatrix, collectionInverse)
        .scaleMagnitude;
```

Now the test builds two cameras and calls it directly, and `render` calls it
too — one implementation, one witness.

- [ ] **Step 2: Run and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/frame_info_test.dart
```

- [ ] **Step 3: Implement**

`buildFrameInfo` gains `{required double dashScale}` and writes
`f(18, dashScale)`. Make it **required**: a defaulted dash scale is a silent 0,
and a 0 collapses every pattern in the drawing to solid — a whole-drawing
defect behind a defaulted argument.

In `render`, name the intermediate rather than composing twice:

```dart
    final collectionToLogical =
        composeTransforms(camera.worldToScreenMatrix, _collectionInverse);
    final collectionToDevice =
        composeTransforms(Transform2.scale(dpr, dpr), collectionToLogical);
    pass.bindUniform(
      geometry.vertexShader.getUniformSlot('FrameInfo'),
      geometry.uniforms.emplace(buildFrameInfo(
          collectionToDevice, widthPx, heightPx,
          dashScale: collectionToLogical.scaleMagnitude)),
    );
```

**`scaleMagnitude` is read once per frame on a `Transform2` that already
exists** — one `sqrt` of a determinant, no allocation. That keeps this inside
the frame-path invariant.

- [ ] **Step 4: Run and commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add packages/jet_cad_2d_flutter/lib/src/gpu/gpu_draw_backend.dart packages/jet_cad_2d_flutter/test/gpu/frame_info_test.dart
git commit -m "feat(gpu): the live logical scale, for the collapse test only"
```

---

### Task 8: The shaders, and the Dart that has to say the same thing

**Files:**
- Modify: `shaders/cad_stroke.vert`
- Modify: `shaders/cad_stroke.frag`
- Regenerate: `assets/shaders/cad.shaderbundle`
- Modify: `test/support/instance_expander.dart`
- Test: `test/gpu/instance_expander_test.dart`

**Interfaces:**
- Produces: `ExpandedTriangles` gaining `Float32List dashVaryings` (three
  floats per vertex: `t`, `fracStart`, `fracEnd`), and
  `expandInstances(..., {required double dashScale})`.

**Plan B's Ruling B6 governs this task.** `test/support/instance_expander.dart`
is `cad_stroke.vert` transcribed into Dart statement for statement, because
`flutter test` has no GPU. Any line added to the shader that is not added to
the expander is a line no test in this package can see. **Edit them in the same
commit, in the same order, with the same variable names.**

- [ ] **Step 1: Write the failing expander tests**

In `test/gpu/instance_expander_test.dart`:

```dart
  test('a solid instance signals solid with a negative fracStart', () {
    final e = expandInstances(solidStrokeBuffer, 1, Transform2.identity(),
        dashScale: 1.0);
    for (var v = 0; v < ResidentGeometry.cornerVertexCount; v++) {
      expect(e.dashVaryings[v * 3 + 1], lessThan(0.0));
    }
  });

  test('t runs from phase/period to (phase + length)/period across the quad', () {
    // A 30-unit segment, period 18, phase 3.
    final e = expandInstances(oneDashedStroke, 1, Transform2.identity(),
        dashScale: 1.0);
    final ts = <double>[/* the six vertices' t */];
    expect(ts.reduce(math.min), closeTo(3.0 / 18.0, 1e-6));
    expect(ts.reduce(math.max), closeTo((3.0 + 30.0) / 18.0, 1e-6));
  });

  test('t is measured in COLLECTION units, so the camera cancels', () {
    // The same instance expanded at two different device scales must give
    // the same t at every vertex. This is the design's central claim: the
    // reference's period grows with the camera and so does the distance, so
    // the ratio does not move. A t that changed here would mean the pattern
    // stretching or compressing under zoom -- the defect this plan exists
    // to remove, reintroduced in the shader.
    final a = expandInstances(oneDashedStroke, 1,
        Transform2.scale(1.0, 1.0), dashScale: 1.0);
    final b = expandInstances(oneDashedStroke, 1,
        Transform2.scale(4.0, 4.0), dashScale: 4.0);
    for (var i = 0; i < a.dashVaryings.length; i += 3) {
      expect(b.dashVaryings[i], closeTo(a.dashVaryings[i], 1e-6));
    }
  });

  test('a collapsed non-representative instance produces a degenerate '
      'triangle', () {
    // period 18 collection units at dashScale 0.1 -> 1.8 live logical px,
    // under kDashCollapsePx.
    final e = expandInstances(twoElementDashedStroke, 2, Transform2.identity(),
        dashScale: 0.1);
    // Instance 0 is the representative: real positions, solid varying.
    expect(e.dashVaryings[1], lessThan(0.0));
    expect(area(triangleOf(e, instance: 0, triangle: 0)), greaterThan(0.0));
    // Instance 1 collapses to a point.
    final second = ResidentGeometry.cornerVertexCount;
    expect(area(triangleOf(e, instance: 1, triangle: 0)), 0.0);
  });

  test('the collapse threshold is the dasher\'s own value', () {
    expect(kExpanderDashCollapsePx, kDashCollapsePx /* the engine's own top-level constant, 3.0 */,
        reason: 'GLSL cannot read a Dart constant, so cad_stroke.vert '
            'restates 3.0 as a literal; this assertion is what keeps the '
            'restatement honest, the same way kMinMiterCosine is kept');
  });

  test('a point instance is never dashed', () {
    final e = expandInstances(pointBuffer, 1, Transform2.identity(),
        dashScale: 1.0);
    expect(e.dashVaryings[1], lessThan(0.0));
  });
```

- [ ] **Step 2: Run and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/instance_expander_test.dart
```

- [ ] **Step 3: Rewrite `cad_stroke.vert`**

Header additions first — the file's existing header keeps its two paragraphs
and gains one:

```
// **Dashes are decided here and tested one line away.** The vertex stage
// turns the instance's `dash` quad into a single varying, `t`, which is the
// pattern-space coordinate at this vertex; the fragment stage keeps the
// fragment when `fract(t)` lands inside the element's own extent. `t` is
// measured in COLLECTION units, and the live camera does not appear in it at
// all: the reference's on-screen period is proportional to the camera scale
// (`draft_painter.dart`'s `_dashScale` folds in `toScreen.scaleMagnitude`)
// and so is the distance along the primitive, so the ratio is scale-free.
// The camera reaches this file for one purpose only -- deciding whether the
// pattern has collapsed to solid.
```

The body:

```glsl
uniform FrameInfo {
  mat4 mvp;            // collection space -> normalized device coordinates
  vec2 half_viewport;  // device pixels / 2
  float dash_scale;    // live LOGICAL pixels per collection unit
} frame_info;

in vec2 corner;
in vec4 join_weight;

// Per instance. `kind` and `half_width` share one attribute because GLSL
// ES 100 guarantees only eight vertex attributes and `dash` takes the eighth.
in vec2 kind_half;   // (kind, half width in device pixels)
in vec2 p0;
in vec2 p1;
in vec2 p2;
in vec4 color;
in vec4 dash;        // (period, phase, fracStart, fracEnd), collection units

out vec4 v_color;

// (t, fracStart, fracEnd). A NEGATIVE fracStart means "solid" and the
// fragment stage skips the test entirely -- one sentinel rather than a
// second varying.
out vec3 v_dash;

const float kMinMiterCosine = -0.875;

// `kDashCollapsePx`, restated because GLSL cannot read a Dart
// constant; `instance_expander.dart` asserts the two agree.
const float kDashCollapsePx = 3.0;

vec2 to_pixels(vec2 p) {
  vec4 clip = frame_info.mvp * vec4(p, 0.0, 1.0);
  return clip.xy * frame_info.half_viewport;
}

void main() {
  float kind = kind_half.x;
  float half_width = kind_half.y;
  vec2 px;

  // Distance from the primitive's start to this vertex, in COLLECTION units.
  float along = 0.0;

  if (kind < 0.5) {
    // ... the existing stroke branch, unchanged ...
    px = mix(a, b, corner.x) + normal * half_width * corner.y;
    // Collection units, taken from the attributes rather than from `a` and
    // `b`: `to_pixels` has already applied the live camera to those, and the
    // camera must not appear in `t`.
    along = corner.x * length(p1 - p0);

  } else if (kind < 1.5) {
    // ... the existing join branch, unchanged ...
    // `along` stays 0: every vertex of a join wedge sits at the corner, so
    // the whole wedge is tested at the phase stored for that corner.

  } else {
    // ... the existing point branch, unchanged. A point is never dashed.
  }

  gl_Position = vec4(px / frame_info.half_viewport, 0.0, 1.0);
  v_color = color;

  // The dash decision. `dash.x` is signed: zero is solid, and a negative
  // value marks the one instance per primitive that draws solid when the
  // pattern collapses.
  v_dash = vec3(0.0, -1.0, 0.0);
  float period = abs(dash.x);
  if (period > 0.0) {
    if (period * frame_info.dash_scale < kDashCollapsePx) {
      // Collapsed. The reference stops dashing and draws the whole primitive
      // (`draft_painter.dart:629-631` takes `dashPolyline`'s false return and
      // calls `polyline` with the untouched points), so the representative
      // keeps its solid `v_dash` and every sibling collapses to a point.
      if (dash.x > 0.0) {
        gl_Position = vec4(0.0, 0.0, 0.0, 1.0);
      }
    } else {
      v_dash = vec3((dash.y + along) / period, dash.z, dash.w);
    }
  }
}
```

- [ ] **Step 4: Rewrite `cad_stroke.frag`**

Keep the whole existing comment — it is a record of two corrections — and add
the test:

```glsl
in vec4 v_color;
in vec3 v_dash;   // (t, fracStart, fracEnd); a negative fracStart means solid
out vec4 frag_color;

void main() {
  // `discard` rather than a zero alpha: a transparent fragment still writes
  // depth on hardware that has it and still costs a blend. The spec's budget
  // discussion already names the cost of this line -- "the shaded-dash
  // `discard` defeats early-Z" -- so it is a known price, not a surprise.
  if (v_dash.y >= 0.0) {
    float f = fract(v_dash.x);
    if (f < v_dash.y || f >= v_dash.z) {
      discard;
    }
  }
  frag_color = v_color;
}
```

**Half-open, `[start, end)`, matching `dasher.dart`'s own `b > a` emission
test.** A closed interval would double-cover the boundary between two adjacent
drawn elements — which no standard pattern has, since drawn elements are
separated by gaps — but would also draw a zero-width element as one fragment
wide, where the reference draws nothing.

- [ ] **Step 5: Regenerate and verify the bundle**

```sh
cd packages/jet_cad_2d_flutter && sh tool/build_shaders.sh
shasum -a 256 assets/shaders/cad.shaderbundle
strings -a assets/shaders/cad.shaderbundle | grep -c "attribute "
```

Record the hash in the task report. **If `impellerc` fails with "Could not
complete reflection on generated shader", the cause is almost always an
attribute the optimizer folded away** — check that every one of the eight is
read on a path the compiler cannot prove dead.

- [ ] **Step 6: Mirror all of it in `instance_expander.dart`**

`expandInstances` gains `{required double dashScale}` and
`ExpandedTriangles` gains `dashVaryings`. The dash block goes **at the end of
the per-vertex loop, in the same order as the shader**, reading
`kExpanderDashCollapsePx` for the threshold. Split `kind_half` the same way:
read `kind` and `halfWidth` from `InstanceFieldOffset.kind` and
`InstanceFieldOffset.halfWidth` — which are now adjacent, which is the point.

Update the file's header to say the dash varying is transcribed too.

- [ ] **Step 7: Run**

```sh
cd packages/jet_cad_2d_flutter && flutter test
```
Expected: `test/gpu/resident_pixel_differential_test.dart` fails to compile —
`expandInstances` now needs `dashScale`. Pass `1.0` there for now; Task 9 gives
that file a real dashed arm.

- [ ] **Step 8: Commit**

```sh
git add packages/jet_cad_2d_flutter/shaders packages/jet_cad_2d_flutter/assets packages/jet_cad_2d_flutter/test
git commit -m "feat(shaders): the dash test, in GLSL and in the Dart that stands in for it"
```

---

### Task 9: The fragment stage gets an instrument

**Files:**
- Modify: `test/support/triangle_rasterizer.dart`
- Modify: `test/support/gpu_comparison.dart`
- Test: `test/support/triangle_rasterizer_test.dart`

**Interfaces:**
- Produces: `TriangleRasterizer.observe(positions, colors, {Float32List? dash})`
  and `measureResidentAgreement(..., {required double dashScale})`.

**Why this is its own task.** Every gate in this package rasterises through
`TriangleRasterizer`, and it has never had a fragment stage worth the name —
`_fill` sets a pixel whenever it is inside the triangle. A dash is the first
thing this backend draws that a *fragment* decides. Without this task the
resident arm's dashes are invisible to every pixel gate in the suite, and Task
10 would compare two arms neither of which dashed.

- [ ] **Step 1: Write the failing tests**

In `test/support/triangle_rasterizer_test.dart`:

```dart
  test('without dash varyings, nothing changes', () {
    // The existing tests in this file are the regression suite for this
    // claim; this one pins the contract explicitly.
    final r = TriangleRasterizer(16, 16);
    r.observe(oneTrianglePositions, oneTriangleColors);
    expect(inkCount(r), unchangedFromBefore);
  });

  test('a fragment outside the element\'s extent is not inked', () {
    // One axis-aligned quad, 20 px long, period 10, element [0, 0.5): the
    // left half of each 10 px cycle is inked and the right half is not.
    final r = TriangleRasterizer(24, 8);
    r.observe(quadPositions, quadColors, dash: quadDashVaryings);
    expect(r.inked(2, 4), isTrue);
    expect(r.inked(7, 4), isFalse);
    expect(r.inked(12, 4), isTrue);
    expect(r.inked(17, 4), isFalse);
  });

  test('t is interpolated barycentrically, not taken from a vertex', () {
    // A triangle whose three vertices carry t = 0, 1 and 2. The pixel at the
    // centroid must read 1.0. Taking any single vertex's value would read
    // 0, 1 or 2, and only one of those three is right by accident.
    expect(tAtCentroid, closeTo(1.0, 1e-3));
  });

  test('a negative fracStart disables the test for that triangle only', () {
    // Two triangles in one observe call, one solid and one dashed. The solid
    // one must ink its gap positions.
  });
```

- [ ] **Step 2: Run and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/support/triangle_rasterizer_test.dart
```

- [ ] **Step 3: Implement the fragment test**

`observe` gains `{Float32List? dash}` — three floats per vertex, same vertex
order as `positions`. `_fill` gains the triangle's three `(t, start, end)`
triples and, inside its pixel loop, after the three edge functions pass:

```dart
        if (hasDash) {
          // Barycentric weights from the edge functions already computed.
          // `w0` is the edge (a, b) against p, which is proportional to the
          // weight of the OPPOSITE vertex, c -- getting that correspondence
          // wrong reads a plausible number at every pixel and the wrong one
          // at all but the centroid.
          final sum = w0 + w1 + w2;
          if (sum <= 0) continue;
          final t = (w1 * ta + w2 * tb + w0 * tc) / sum;
          final f = t - t.floorToDouble(); // `fract`
          if (f < startA || f >= endA) continue;
        }
```

`startA`/`endA` come from vertex `a`; all three vertices of a triangle carry
the same element extent by construction, and **the implementer must assert
that** rather than assume it:

```dart
      assert(startA == startB && startA == startC,
          'every vertex of one instance carries the same element extent; '
          'a triangle whose vertices disagree came from two instances');
```

**Update the class doc.** `gpu_comparison.dart`'s header lists three things
that instrument cannot measure, and one of them — *"geometry added INSIDE the
existing footprint is invisible"* — is now **more** true, not less: a dash gap
removes ink, which the differential does see, but a wrongly-*kept* fragment
inside another primitive's footprint still does not move a pixel. Say so.

- [ ] **Step 4: Thread the varyings through `gpu_comparison.dart`**

`measureResidentAgreement` gains `{required double dashScale}`, passes it to
`expandInstances`, and hands `expanded.dashVaryings` to
`residentRaster.observe`.

**And it gains the harder half: the two arms now reach the same picture by two
different routes.** The reference arm must be given spans and the resident arm
the pattern. The closure the caller passes takes a `DrawSink` and can branch on
`sink.shadesDashes` — which is exactly what the painter does, so the honest
form of this helper is to **drive `DraftPainter` itself** rather than a
hand-written closure. Add a second entry point beside the existing one:

```dart
/// Draws [document] through both arms with the real painter, at [camera].
///
/// **The two arms take different routes through `DraftPainter` and that is
/// the point.** `VerticesDrawSink.shadesDashes` is false, so the painter cuts
/// the spans; `GeometryCollector.shadesDashes` is true, so the painter hands
/// over the pattern. A closure written here that dashed for one arm and not
/// the other would be a third implementation of that branch, and the branch
/// is what this comparison is for.
ResidentAgreement measurePaintedAgreement(
  DraftDocument document, {
  required ViewportTransform camera,
  required Size size,
  required double devicePixelRatio,
  required double pixelsPerPaperMm,
}) { ... }
```

Its `dashScale` is `1.0`: both arms are painted at the same camera the buffer
is collected at, so the live-to-collection ratio is exactly 1. **Say that in
the code**, and have Task 10 assert it rather than leaving a literal `1.0`
unexplained.

- [ ] **Step 5: Run and commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add packages/jet_cad_2d_flutter/test
git commit -m "test(gpu): the coverage rasterizer learns the one thing a fragment decides"
```

---

### Task 10: The gates — a declarative oracle, a pixel differential, and the one measurement that would have failed yesterday

**Files:**
- Create: `test/gpu/dash_differential_test.dart`
- Modify: `test/gpu/resident_pixel_differential_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 1–9.
- Produces: nothing. This task is the gate.

**The oracle must not be a transcription.** Plan B's Task 4 shipped an oracle
whose local variables were the collector's private field names minus the
underscore; it agreed with the implementation because it *was* the
implementation. The rule this task follows: **the expected instance list is
generated from indices and the pattern, with no run state machine, no
`hasDirection` flag and no "previous point" variable.**

```dart
/// What the collector must have written, derived from the inputs rather than
/// from the collector.
///
/// **No bookkeeping.** Transform the points, drop the zero-length steps, and
/// then read the answer off the indices: for a dashed open polyline of `n`
/// surviving points the instance list is
///
///     for i in 0 .. n-2:  for k in 0 .. D-1:  Stroke(p[i], p[i+1], k)
///
/// with no joins at all (Ruling C3), every phase 0 (`dasher.dart:94-96`) and
/// element k's extent taken from the cumulative sums of `|dashes|`. A dashed
/// arc is the same shape with joins interleaved and a running phase. Nothing
/// here can share a state-machine defect with the collector, because there is
/// no state machine.
List<_ExpectedInstance> expectedDashInstances(...) { ... }
```

- [ ] **Step 1: The record-level differential**

```dart
  test('the collector writes exactly the instances the rule produces, in '
      'order, for every dashed entity in the corpus', () {
    final doc = shadedDashFixture();
    final collector = GeometryCollector(
        pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    DraftPainter(
            document: doc, index: index, resolver: DocumentStyleResolver(doc))
        .paint(collector, camera, kViewport);

    final expected = expectedDashInstances(doc, camera);
    expect(collector.instanceCount, expected.length,
        reason: 'neither dropping nor duplicating an element');
    for (var i = 0; i < expected.length; i++) {
      expectInstanceMatches(collector.data, i, expected[i]);
    }
  });
```

**Before writing the implementation side of anything in this task, confirm this
test can fail.** Disable the dash fan in `_emit` (emit one instance regardless
of *D*), run it, and paste the *expected N vs actual M* line into the report. A
first-try green here proves nothing — Plan B lost a task to exactly that.

- [ ] **Step 2: Emission order, including the new axis**

```dart
  test('a primitive\'s elements are consecutive and in ascending cycle '
      'position', () {
    // Not merely "all D are present": a fan emitted in descending order, or
    // interleaved across primitives, draws the same pixels today and stops
    // doing so the moment a translucent dashed layer exists.
    for (final run in primitiveRuns(collector.data)) {
      expect(run.map((i) => fracStartOf(i)), isSorted);
    }
  });

  test('on a dashed arc the join still precedes its segment', () {
    // Plan B's ordering rule survives the fan: J(v)xD then S(i)xD.
  });

  test('order survives undo, redo, save, load and purge', () {
    // The same buffer, byte for byte, after each. This is the spec's
    // criterion 3 with a dashed corpus, which `differentialFixture` cannot
    // give it (Ruling C5).
    for (final mutate in <void Function(DraftDocument)>[...]) {
      expect(collectAfter(mutate), byteEquals(baseline));
    }
  });
```

- [ ] **Step 3: The pixel differential, with its vacuity control**

```dart
  test('the resident arm draws the dashed corpus the way the reference does', () {
    final r = measurePaintedAgreement(shadedDashFixture(),
        camera: camera,
        size: kViewport,
        devicePixelRatio: 2.0,
        pixelsPerPaperMm: 3.78);
    expect(r.differing, lessThan(r.referenceInk * 0.01));
    // The absolute floor matters as much as the ratio. Plan B shipped a gate
    // budgeting 81 differing pixels against a corpus whose entire join ink
    // was 26 -- a gate that could not fail. Record the corpus's DASH ink
    // here and require the budget to be a fraction of it.
    expect(r.differing, lessThan(dashGapPixels * 0.1),
        reason: 'the gap pixels are what this plan changed; a budget larger '
            'than them is a budget the change cannot fail');
  });

  test('the control: with the fragment dash test disabled, the same '
      'measurement blows the budget by more than 4x', () {
    // The gate above is only evidence if the instrument can see the defect
    // it is aimed at. This arm is the proof, run in the same test file, not
    // a claim in a report.
    final r = measurePaintedAgreement(..., debugDisableDashTest: true);
    expect(r.differing, greaterThan(dashGapPixels * 0.4));
  });
```

**`debugDisableDashTest` is a test-only flag on the rasterizer**, not on `lib/`.
Plan 3i's Ruling 14 is the precedent: an interleaved control arm that cannot be
switched on is an arm that reads 1.00 and proves nothing.

- [ ] **Step 4: The measurement that would have failed before this plan**

This is the criterion the whole plan exists for, and it is worth its own test
with its own name:

```dart
  test('the dash count follows the camera: four scales, four counts, each '
      'matching the reference painted at that same scale', () {
    // Before Plan C the resident arm drew the same number of dashes at every
    // scale, because the spans were cut once. This test fails on a buffer
    // built by Plan B's collector and passes on this one, which is the whole
    // claim, measured rather than argued.
    for (final ratio in <double>[0.5, 1.0, 2.0, 4.0]) {
      final live = cameraScaledBy(ratio);
      final reference = referenceInkAt(live);   // VerticesDrawSink, painted live
      final resident = residentInkAt(live);     // ONE buffer, collected at 1.0
      expect(drawnRunCount(resident), drawnRunCount(reference),
          reason: 'at ratio $ratio');
    }
  });
```

`drawnRunCount` counts maximal inked runs along the dashed entity's
centreline — a count of dashes, not a pixel total, so it fails loudly on a
pattern that stretched and only marginally on one that is a fraction of a pixel
out of phase.

**Note what this test does NOT gate: the arc chording divergence (Ruling C4).**
At ratios other than 1.0 the resident arc's sagitta grows as `0.25 × ratio` px
and its dash edges move with it. Run this test on the dashed **polyline** and
report the arc's numbers without a threshold — the band that would bound them
is Plan F's.

- [ ] **Step 5: Run everything, then commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add packages/jet_cad_2d_flutter/test
git commit -m "test(gpu): the dash gates, and the control that proves they can fail"
```

---

### Task 11: Mutation testing

**Files:**
- Create: `docs/superpowers/notes/plan-c-mutation-log.md`
- Modify: `test/support/fixtures.dart` (one addition, below)

**Discipline, repeated because it has been broken before:**

- **`cp` the file before mutating; restore from the copy.** Never
  `git checkout --`.
- Fire one mutation at a time. Run the **whole** package suite, not the file
  you expect to fail — a mutation that kills an unexpected test is information.
- Record the exact command, the exact failing test name and the exit code. **Do
  not paraphrase test output and do not write output you did not see.**
- A survivor is a result. Write down *why* it survived and either declare it
  equivalent with a proof, or name the gate that would kill it and say the gate
  does not exist.

**One fixture addition this task needs.** `shadedDashFixture` gains linetype
handle **903, `DISHONEST`**: `DashPattern(dashes: [12.0, -6.0], totalLength:
99.0)` on its own line entity. Nothing in the document model enforces that
`totalLength` agrees with `dashes`, `dasher.dart` says so twice, and **M-C1
cannot be fired without a pattern where the two disagree.** Add it, re-run the
suite green, commit, then start firing.

- [ ] **The pre-committed mutations**

| id | mutation | expected gate |
|---|---|---|
| M-C1 | `beginDash` takes the cycle from `pattern.totalLength` instead of summing `\|d\|` | the record differential, on entity 903 |
| M-C2 | a polyline's segments accumulate phase instead of restarting at 0 | the record differential, and the pixel differential (**the spec's own named mutation**) |
| M-C3 | an arc's chords all carry phase 0 | same (**the spec's other named mutation**) |
| M-C4 | `factor` is `residual.scaleMagnitude` instead of the per-chord ratio | the anisotropic-arc test in Task 6 |
| M-C5 | `factor` divides by the chord's collection length instead of its local **arc** length | *expected to survive at these chord counts* — see below |
| M-C6 | `_suppressJoins` is never set for a dashed polyline | the record differential (instance count), then the pixel differential |
| M-C7 | the seam join is emitted on a dashed closed run | the record differential |
| M-C8 | every element carries a negative period, not only `k == 0` | the record test in Task 5 — **not** the pixel gate, which is coverage-only and cannot see overdraw |
| M-C9 | the shader's collapse branch is deleted | the collapse test, at a zoomed-out camera |
| M-C10 | `dashScale` is taken from `collectionToDevice` instead of `collectionToLogical` | the collapse test, at `dpr` 2 |
| M-C11 | the fragment test is closed, `f <= v_dash.z` | *expected to survive* — see below |
| M-C12 | `along` is `length(b - a)` (device) instead of `length(p1 - p0)` (collection) | the four-scale dash-count test |
| M-C13 | every element is written with `fracStart = 0, fracEnd = 1` | the pixel differential (the whole line draws solid) |
| M-C14 | the rasterizer's barycentric correspondence is rotated (`w0`↔`w1`) | the instrument's own centroid test — a mutation aimed at the instrument, not the code |

**Two are declared as likely survivors before they are fired, which is what
makes them honest rather than excuses afterwards.**

- **M-C5** changes the phase advance per chord by the chord-to-arc ratio,
  which at `kFlattenTolerance = 0.25` px is `1 - chord/arc ≈ θ²/24` for a
  chord subtending θ. At the chord counts this flattener produces, θ is small
  and the per-chord error is a fraction of a percent of the period,
  accumulating only within one chord because each chord's phase is stored
  absolutely. **If it survives, the log records the arithmetic and the
  statement that the two formulations are indistinguishable at this
  tolerance** — which is a real result about Ruling C4's bound, not a gap.
- **M-C11** differs from the correct code on exactly the fragments where
  `fract(t)` lands within one float ULP of `fracEnd`. **If it survives, say
  so and say why**: the measure of the set it changes is zero in the
  continuum and vanishing in float32, so no pixel gate can be expected to
  see it.

- [ ] **Write the log**

`docs/superpowers/notes/plan-c-mutation-log.md`, opening with a summary table
naming every mutant, its verdict and its gate — the shape Plan 3i's log
established and Plan B's followed. Every row carries the command and the
failing test name.

- [ ] **The gate for this task**

**At least ten of the fourteen go red.** Fewer than ten means the instruments
are weaker than the plan claims, and the correct response is another gate, not
a lowered count. Every survivor gets a paragraph.

---

### Task 12: The device run, the results note, and everything that says what this backend does

**Files:**
- Modify: `apps/dev_harness_2d/lib/gpu_arm.dart`
- Create: `docs/superpowers/notes/2026-08-31-plan-c-results.md`
- Modify: `STATUS.md`
- Modify: `docs/superpowers/notes/plan-c-mutation-log.md` (final verdicts)

- [ ] **Step 1: Correct the harness's own description of itself**

`gpu_arm.dart`'s header currently says, in two places, things Plan C makes
false:

- *"dashed **arcs** are Plan C's (a dashed polyline's spans already reach the
  sink as ordinary `polyline` calls, so straight dashed strokes draw today)"* —
  after this plan, neither reaches the sink as spans.
- *"A dash pattern's spans are split at that camera's scale and then baked into
  the resident buffer, so they stretch under zoom"* — no longer true, and the
  replacement must state the **correct** old defect too, because the old
  sentence named the wrong one (see this plan's "What is wrong today").

A transcript that misdescribes what it measured is this repository's own
standing failure mode; Plan B corrected this same comment for the same reason
at `72b938a`. **Keep what is still true**: butt caps only, no antialiasing,
fills and text still counted in `skippedOps`.

- [ ] **Step 2: Report the counters that now read zero**

`DraftPainter.dashSpanCount` and `collapsedDashCount` describe the dasher's
work and the dasher does not run for arm C. The harness prints them. **Either
label them per arm or stop printing them for arm C** — a zero under a label
that reads like a measurement is worse than no line.

- [ ] **Step 3: Run the device arm**

```sh
cd apps/dev_harness_2d
flutter run -d macos --profile --dart-define=RUN_GPU_SPIKE=true \
  --dart-define=ENTITIES=10000 --dart-define=DASHED=0.35 \
  --dart-define=SPIKE_DEFS=20 --dart-define=SPIKE_INSTANCES=150 \
  --dart-define=SPIKE_FRAMES=30 --dart-define=SPIKE_REPEATS=3
```

**State whether macOS Low Power Mode was on.** Every `flutter drive` and
`flutter run` note in this project must; Plan 3b's whole results note is
contaminated because one did not.

**Record, at minimum:**

| quantity | against |
|---|---|
| instance count | Plan B's **109,068** — this plan expects it to **fall**, and a rise is a finding |
| buffer bytes | the 8 MB budget; 16 floats × 4 × instances |
| `collect+upload` walk ms | Plan B's 5.7 ms, itself unexplained against Plan A's 14.7 |
| rebuild total ms | the 16.67 ms budget — **Plan B missed at 79.6 ms and named a hypothesis it could not test**; this run has the chance to take a warm figure and settle it |
| gesture build / raster p50, p95 | 1.2 / 2.0 / 3.0 ms, **with `discard` live** |
| `skippedOps` | fills and text only |

- [ ] **Step 4: Look at the window, and discharge Plan B's debt while you are there**

**Plan B's exit gate is 10 of 11 and the open one is exactly this.** The
resumer's list in `STATUS.md` has carried it since the merge. This run puts a
human in front of the same arm, so both plans' window checks are one act.

For Plan B, still owed: corners filled, a circle **not** notched at its start
angle, a square dot, nothing thickening as you zoom.

For Plan C, new:

1. **Zoom in two stops.** The dashes must get *more numerous*, not longer. A
   pattern that stretches is the defect this plan removed and it is instantly
   visible.
2. **Zoom out until the dashes disappear into solid.** That is the collapse
   branch. It must happen at the same zoom on arm C as on arm A — flip between
   them and watch the transition, not the endpoints.
3. **A dashed corner.** It must be notched, not filled. Ruling C3 says the
   reference leaves it open, and a filled corner means the join suppression
   was lost.
4. **A dashed circle.** It must be notched at its start angle — the *opposite*
   of the solid circle's requirement, and the pair is the check: solid closed,
   dashed open.
5. **Look for phase crawl.** Pan slowly and watch a long dashed line. The
   dashes must move *with* the line. A pattern that slides along its own line
   under a pan means the phase is anchored to the screen rather than to the
   geometry.

**Write down what was seen, including "I could not tell" where that is the
honest answer.** Plan 3h's session made this the project's third instrument and
it was the only one of the three that caught any of that session's four
defects.

- [ ] **Step 5: The results note**

`docs/superpowers/notes/2026-08-31-plan-c-results.md`. It must carry:

- Every exit-gate criterion below with its measured value and PASS / MISS.
  **A miss is recorded as a miss with its number. No threshold moves.**
- The instance-count and buffer comparison against Plan B, in both directions.
- **Ruling C4's divergence, measured**: the dashed arc's pixel disagreement at
  ratio 1.0 (which must be at the criterion-1 level) and at 2.0 and 4.0 (which
  are reported without a threshold, because the band is Plan F's).
- **What was not measured**: no web run, no fills, no text, no warm rebuild if
  none was taken, no per-channel colour in the pixel differential (that
  instrument is coverage-only and this plan did not change that), and the
  instrument's standing structural blind spot — geometry added inside an
  existing footprint, proven by Plan B's M-B7 against M-B15.
- The mutation summary, with every survivor's paragraph.
- **The gates that do not cover dashes**, per Ruling C5's stated cost: name
  every test still running only on `differentialFixture`.

- [ ] **Step 6: `STATUS.md`**

Header, the branch map, the resume point, and a `## Plan C` section in the
shape Plan B's has. **If criterion 11 is unmet, say so in those words** — and
if Plan B's window check was discharged in Step 4, say that too, in its own
sentence, because `STATUS.md` has carried it as owed since `cc7aba5`.

- [ ] **Step 7: The full three-package gate, then commit**

```sh
cd packages/jet_cad_2d       && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d_flutter     && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../../apps/dev_harness_2d && flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
```

---

## Exit gate

Pre-committed. **Thresholds are not moved to make a criterion pass; a miss is
recorded as a miss with its number.**

1. **Pixel differential on `shadedDashFixture`**, resident against
   `VerticesDrawSink`, both painted by `DraftPainter` at the collection camera:
   differing pixels **< 1% of reference ink** *and* **< 10% of the corpus's
   dash-gap pixels**. The second clause is the anti-vacuity floor; Plan B
   shipped a gate whose budget exceeded the ink it measured.
2. **The gate can fail**: with the fragment dash test disabled, the same
   measurement exceeds its budget by **more than 4×**, asserted in the suite
   rather than claimed in a report.
3. **The dash count follows the camera.** At live-to-collection ratios 0.5, 1,
   2 and 4, the resident arm's drawn-run count along the dashed polyline equals
   the reference's, painted at that same camera. **One buffer, collected once.**
4. **`t` is scale-free**: the same instance expanded at three device scales
   gives the same `t` at every vertex, to 1e-6.
5. **Emission order**, on the dashed corpus: a primitive's *D* instances are
   consecutive and ascending in cycle position; joins still precede their
   segments on arcs; the buffer is byte-identical after undo, redo, save, load
   and purge.
6. **Collapse is live and single**: below `kDashCollapsePx` the resident arm
   matches the solid arm within criterion 1's budget, and exactly one instance
   per primitive draws.
7. **Ruling C3 holds in pixels**: a dashed corner is notched and a dashed
   circle is notched at its start angle, while a **solid** circle is not.
8. **Resident geometry ≤ 8 MB** at 10,000 entities with `DASHED=0.35`, reported
   beside Plan B's 4.99 MB / 109,068 instances **with the direction of the
   change stated**.
9. **Gesture p50 ≤ 1.2 ms build and ≤ 2.0 ms raster; p95 raster ≤ 3.0 ms**, on
   the harness corpus, with `discard` live. The spec's budget discussion names
   this `discard` as a consumer of the raster margin; if it consumes it, that
   is a miss and is recorded as one.
10. **At least ten of the fourteen pre-committed mutations go red**, and every
    survivor is declared with a proof or with the name of the gate that does
    not exist.
11. **A human has looked at the running window** and written down what they
    saw, against the five checks in Task 12 Step 4 — **and Plan B's four,
    which are still owed.**

**Criteria this plan does NOT gate, and why**: the watermark band (spec
criterion 2 — Plan F owns it, and Ruling C4's `0.25 × ratio` arc divergence is
bounded by it); web (Plan G); fills and text (Plans D and E); the rebuild
budget (spec criterion 7 — Plan B missed it at 79.6 ms with an untested
hypothesis, and this plan **reports** the number without owning the fix).

---

## Self-review

**Spec coverage.** The spec's dash section makes six statements. Five are
implemented: the collected quantity is the period folding `linetypeScale`,
`globalLinetypeScale` and the placement scale (Task 5's `factor`); polyline
phase restarts per vertex (Task 5); arcs carry a running phase (Task 6); the
collapse rule reduces to a shader branch on the same threshold (Task 8); the
corpus gains a dashed arc (Task 3). The sixth — *"the uniform is the
live-to-reference scale ratio"* — **is implemented for one purpose only**, the
collapse test, because the ratio provably cancels out of the phase. That is a
narrowing of the spec, derived in this plan's header, and Task 12 records it.

**The spec's two dash mutations** are M-C2 and M-C3, both pre-committed.

**Placeholders.** Every code step carries the code. Where a step says
`/* the file's own helper */` it is pointing at scaffolding that already exists
in the file being edited, and the assertion around it is complete — that is
deliberate, not a gap, and it is marked at each site.

**Type consistency.** `beginDash(DashPattern, double)` in Task 1 is called with
two arguments in Task 2 and consumed with two in Task 5.
`expandInstances(..., {required double dashScale})` in Task 8 is called with
`dashScale` in Task 9. `buildFrameInfo(..., {required double dashScale})` in
Task 7 is called in Task 7. `kFloatsPerInstance` is 16 from Task 4 onward and
every later task's byte arithmetic uses it rather than a literal.

**Known plan risks, stated rather than discovered:**

1. **Task 4 breaks four test files at once.** That is intended and assigned;
   an implementer who reports it as a blocker has read the task correctly and
   should repair them, not stop.
2. **Task 9's rasterizer change touches the instrument every pixel gate in the
   package runs through.** If the "without dash varyings, nothing changes"
   test is not written first, a regression there is invisible.
3. **Criterion 3 is the plan's whole claim and it is also the hardest test to
   write.** `drawnRunCount` needs a centreline to walk; the implementer should
   sample along the dashed polyline's known device-space endpoints rather than
   trying to find the line in the image.
