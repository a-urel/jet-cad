# GPU backend, Plan D — fills

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The resident backend draws filled regions in the same buffer, the
same draw call and the same walk order as the strokes they sit among — so
that "draw order is emission order" becomes a claim a test can *fail*, which
it has not been able to do for three plans.

**Architecture:** A fill triangle becomes a fourth `kind` in the existing
instance record. `fillPolygon` arrives pre-triangulated, so the collector
reads the triangulation and writes one instance per triangle; `fillCircle` is
fanned at the *same* step count the circle's own outline uses. The vertex
shader gains one branch that reads `p0`, `p1`, `p2` as the triangle's corners
and expands nothing — a fill has no width. **No new vertex attribute, no new
record float, no change to the corner table**: the six per-vertex records
already carry a `join_weight` that can select three of four roles, and the
fourth role is folded onto `p1` so the second triangle is degenerate. The
pixel instrument grows the half of spec criterion 1 it has never had — a
*colour* comparison — because coverage alone cannot see one opaque shape
drawn over another, which is precisely what a fill is.

**Tech Stack:** Dart, Flutter 3.47.1, `flutter_scene` 0.23.0 (for its internal
`flutter_gpu` shim only), `impellerc` for the shader bundle, `flutter_test`.

**Spec:** [docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md](../specs/2026-08-29-gpu-resident-render-backend-design.md)
(revision 4), sections **"One buffer, one kind tag, one draw call"** and
**"Fills"**. Read both before Task 1. This plan argues from them and departs
from neither.

**Predecessors:** [Plan A](2026-08-29-gpu-backend-plan-a-seam-and-strokes.md),
merged at `cd5bc98`; [Plan B](2026-08-30-gpu-backend-plan-b-joins-and-hairlines.md),
merged at `72b162d`; [Plan C](2026-08-31-gpu-backend-plan-c-shaded-dashes.md),
merged at `3a61b45`. Their ledgers are at [docs/superpowers/ledgers/](../ledgers/).
**Read Plan B's Ruling B6 and Plan C's Ruling C6 before Task 5** — B6 is why
`test/support/instance_expander.dart` is a statement-for-statement
transcription of the vertex shader and must stay one; C6 is why the attribute
count may not grow.

**Reference implementation — one, and it is unchanged:**
`packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart`, its
`fillPolygon` (`:745-768`) and `fillCircle` (`:772-794`). It is the oracle for
this plan at both the record level and the pixel level. It is **not edited by
this plan**.

---

## Where Plan D sits

| plan | delivers | state |
|---|---|---|
| A | the facade, the enum, the collector and buffer for **stroked polylines**, one draw call, the ordering and differential gates, the fallback | **merged** `cd5bc98` |
| B | joins, `point()`, `circle()`/`arc()`, the `_coveredArgb` hairline alpha | **merged** `72b162d` |
| C | dashes evaluated in the shader, at the live scale | **merged** `3a61b45` |
| **D (this one)** | **fills, and the order gate they make testable** | this plan |
| E | the text split — *N* text ops, *N+1* draw calls | |
| F | the rebuild triggers, the reference scale and the watermark | |
| G | web: CanvasKit and Skwasm | |

**Plan D closes four of the spec's fourteen pre-committed mutations** —
*"give strokes, joins and fills separate draw calls"*, *"route fills through
`_coveredArgb`"*, and (because the instrument finally sees colour) the two
that were declared un-gateable at the pixel level in Plan B's own instrument
doc. It closes **spec exit-gate criterion 4** outright, which no earlier plan
could even state a failing case for.

---

## What is missing today, stated as a measurement rather than as a worry

`GeometryCollector` ends with three lines:

```dart
  @override
  void fillPolygon(Float64List points, int count, Int32List triangles,
          ResolvedStyle style) =>
      _skipped++;

  @override
  void fillCircle(double cx, double cy, double r, ResolvedStyle style) =>
      _skipped++;

  @override
  void text(String text, Handle style, ResolvedStyle resolved) => _skipped++;
```

(`geometry_collector.dart:625-637`.) A document with filled regions renders on
the resident arm with **holes where the fills are**, and the count of those
holes is `skippedOps`. That number is the deliverable this plan removes: after
Task 3 only `text` increments it.

**The second thing missing is a test that can fail.** Plan B's own instrument
says so, in `gpu_comparison.dart`'s doc:

> **Draw order is also unmeasured, and that is a repo non-negotiable, not a
> minor gap.** `TriangleRasterizer._fill` is last-write-wins over coverage
> with no depth test, so any permutation of emission order that preserves the
> union of triangle footprints paints the same pixels.

Coverage cannot see order because strokes are thin and mostly disjoint: a
permutation moves *which* triangle inked a pixel, never *whether* it is
inked. A fill is the first primitive in this backend that covers a large area
another primitive already covered — so reordering it changes the picture's
**colour** and nothing else. The instrument must therefore learn colour, and
Task 6 is where it does.

---

## Eight scope rulings, made here rather than left to an implementer

### Ruling D1 — a fill is `kKindFill = 3`, and it reuses the corner table unchanged

`ResidentGeometry.kCornerVertices` holds six per-vertex records: two triangles
whose `join_weight` selects one of `(V, A, B, M)`. A fill triangle needs three
corners across six vertices, so the mapping is:

| vertex | `join_weight` | role | fill reads |
|---|---|---|---|
| 0 | `(1,0,0,0)` | V | `p0` |
| 1 | `(0,1,0,0)` | A | `p1` |
| 2 | `(0,0,1,0)` | B | `p2` |
| 3 | `(0,1,0,0)` | A | `p1` |
| 4 | `(0,0,0,1)` | M | **`p1`** |
| 5 | `(0,0,1,0)` | B | `p2` |

Triangle 0 is `(p0, p1, p2)` — the fill. Triangle 1 is `(p1, p1, p2)` — zero
area, and it rasterises nothing on hardware and nothing in
`TriangleRasterizer._fill`, which returns early on `area == 0`.

The shader expresses that as one line with no branch and no float-equality
test on an index:

```glsl
px = join_weight.x * a0 + (join_weight.y + join_weight.w) * a1 +
     join_weight.z * a2;
```

**The cost, stated:** a fill triangle costs six vertex-shader invocations
where three would do. **The alternative costs a second draw call**, which the
spec's central correction forbids — a second draw call submits after every
instance of the first, which is exactly the reordering
`vertices_draw_sink.dart:41-57` records this repository shipping and
reverting. Two wasted vertex invocations per fill triangle is the price of
one draw call, and it is paid on rebuild, not per frame.

### Ruling D2 — a fill's `halfWidth` is 0 and nothing expands it

Every other kind expands geometry in **device pixels** at the live camera,
because a stroke's width is a screen quantity. A fill has no width: its three
corners are the drawing, and they are projected and used. `writeFill` writes
`halfWidth: 0` and the shader's fill branch never reads it.

A filled region's *outline* is a separate entity in this document model — the
boundary — and it already draws through `polyline` or `circle`. Nothing in
this plan touches it.

### Ruling D3 — `_coveredArgb` never reaches a fill

Copied from the spec, from `vertices_draw_sink.dart:752-757`, and already
written into `GeometryCollector._coveredArgb`'s own doc comment as a
constraint Plan D *inherits*:

> `fillPolygon` and `fillCircle` pass `style.argb` directly in the reference,
> because a fill entity's `ResolvedStyle` still carries a lineweight from the
> shared column and *"routing a fill through `_coveredArgb` would fade a
> filled room on a hairline layer"*.

The fill corpus in Task 4 puts a fill on a hairline layer for exactly this
reason, and mutation M-D5 fires it.

### Ruling D4 — the dash slots are written zero, explicitly

A fill is never dashed: `DraftPainter._drawFill` (`draft_painter.dart:700-766`)
opens a residual and calls `fillCircle` or `fillPolygon`, and never opens a
`beginDash` bracket. So `writeFill` takes **no dash arguments** — the same
shape as `writePoint`, for the same reason (a caller cannot express something
the reference cannot draw) — and it still writes all four dash floats to zero
explicitly rather than trusting a fresh `Float32List`'s zero-initialisation.
See `_writeDash`'s own doc for why that write has to be explicit.

The collector's fill methods must also **not consult** `_pendingSegPeriod`,
`_dashActive` or any other dash-bracket field. A fill that arrived inside a
stale bracket would otherwise inherit a period it can neither carry nor draw.

### Ruling D5 — `fillCircle` fans at the step count its own outline uses

Transcribed from `VerticesDrawSink.fillCircle`, including where the fan
starts:

- `steps = _flattenSteps(r * residual.scaleMagnitude, 2π)` — the **same**
  expression `_flatten` evaluates for the outline, so a fill and its own
  boundary stroke can never disagree about the silhouette at any zoom;
- the fan's first rim point is `(cx + r, cy)`, i.e. angle 0, and rim point `i`
  is at `2π · i / steps`;
- each triangle is `(centre, previous rim, next rim)`, in that vertex order;
- `r <= 0` returns, and `deviceRadius <= 0` returns.

`steps` triangles, therefore `steps` instances.

### Ruling D6 — no degenerate-triangle test is added at collection

`VerticesDrawSink._emitTriangle` (`:465-482`) has **no** zero-area test: it
writes whatever it is handed. The collector must not add one, for the reason
`_emit` and `_runTo` state in their own comments — *matching the formula, not
the intention* is what keeps the two arms' instance lists identical. A
triangulation that contains a degenerate triangle produces an instance on both
arms, and both arms' rasterisers drop it at raster time.

This is a **deliberate asymmetry** with `_emit`'s `sqrt(dx*dx + dy*dy) == 0`
guard: that guard exists because the reference has one, and this omission
exists because the reference has none.

### Ruling D7 — the record wastes ten floats on a fill, and the plan reports it rather than fixing it

A fill instance uses `kind`, `x0..y2` and `r,g,b,a` — six of sixteen floats,
64 bytes to carry 40. At a fill-heavy corpus that is real memory against the
8 MB budget, and Task 9 measures it.

It is not optimised, because every way of optimising it is a second buffer or
a second stride, and both are a second draw call. **The budget is the gate,
not the efficiency**: if the measured buffer exceeds 8 MB the plan records a
miss with its number, per the spec's own rule that thresholds are not moved to
make a criterion pass.

### Ruling D8 — the pixel instrument grows a colour measurement, and that is Plan D's real deliverable

Spec criterion 1 is *"per-channel difference ≤ 2 on ≥ 99.5% of pixels, ≤ 8 on
the rest, on premultiplied RGBA"*. Plan B's instrument measures **coverage**
and says so:

> [differing] and [overEight] below are always the same number and neither one
> measures *colour* agreement. The per-channel half of the design document's
> criterion 1 is not something this file can gate.

Fills make colour measurable and make it necessary in the same stroke: an
opaque fill over a stroke changes a pixel's colour without changing whether it
is inked. Task 6 adds the measurement, and Task 7 uses it for spec criterion 4
— *"submitting the buffer out of walk order changes the rendering on the
fill-overlap corpus, and the test asserts it does."*

**Both arms still go through the same rasterizer**, which does no blending —
`_fill` writes the triangle's colour over whatever was there. That is not a
limitation for this gate: last-write-wins is *more* sensitive to order than
blending, and both arms share it, so it cancels in the differential exactly
the way MSAA does.

---

## Global Constraints

Copied verbatim from `CLAUDE.md`, the spec, and Plans A, B and C. Every task's
requirements implicitly include this section.

- **The frame path allocates nothing per entity in steady state, and O(1) per
  flush.**
- **Draw order is emission order** — *not* "ascending handle value". **Never
  sort the buffer.** Within an entity the order is also fixed: the join comes
  **before** its segment and the seam join comes **last**; a primitive's *D*
  dash instances are emitted consecutively, in ascending cycle position.
  **Plan D adds a third axis:** a fill's triangles are emitted in the order
  the triangulation lists them, and a fan's in ascending angle. Asserted in
  Tasks 2, 3 and 7.
- **Geometric decisions use `Tolerance`; stored value comparisons are exact
  `==`.**
- **Never commit `analysis_options.yaml`** — `flutter pub get` rewrites three
  of them in this workspace. Check `git status` before every commit and
  `git checkout --` them.
- **Never synthesize test output.** Run the command, paste what it printed,
  **including the exit code**. `dart format --set-exit-if-changed` printing
  `(1 changed)` **is** a failure even though the line looks informational.
- **Before firing a mutation, back the file up with `cp`, and restore from
  that copy.** Never `git checkout --` a file to revert a mutation: a Plan A
  implementer did, and wiped an entire round of uncommitted fix work.
- Code, comments and commit messages in English.
- **`packages/jet_cad_2d` is untouched by this plan.** `AddRegionCommand`,
  `FillIndex` and `boundaryHandleOf` are **read**, never edited. Everything
  written lives in `packages/jet_cad_2d_flutter` and `apps/dev_harness_2d`.
- **`vertices_draw_sink.dart` is untouched by this plan.** It is the oracle at
  both levels; editing it would make every differential circular.
- Shaders are authored so `impellerc` can emit an **OpenGL ES 100** stage.
  **No bitwise operators, no integer attributes, no dynamic indexing of
  uniform arrays in the fragment stage, and at most eight vertex attributes**
  (Ruling C6). **Plan D adds no attribute and no record float** — the count
  stays at eight and the record stays at sixteen floats. Every declared
  attribute must be read by something the optimizer cannot fold away, or
  `impellerc` fails reflection with *"Could not complete reflection on
  generated shader"*.
- **`_coveredArgb` must never reach a fill** (Ruling D3).
- **`ResolvedStyle` takes four required named arguments** — `argb`,
  `lineweightHundredths`, `linetype`, `linetypeScale`. Plan B's sample code
  got this wrong four times and Plan C's once. Every literal in this plan
  spells all four.
- Every task ends green:
  ```sh
  cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
  ```
  Tasks 4 and 9 additionally run the engine and harness gates:
  ```sh
  cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
  cd apps/dev_harness_2d && flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
  ```

## File structure

| file | responsibility |
|---|---|
| `lib/src/gpu/instance_record.dart` | **modify** — `kKindFill`, `writeFill`, the kind-order doc |
| `lib/src/gpu/geometry_collector.dart` | **modify** — `fillPolygon`, `fillCircle`, `skippedOps`' doc |
| `lib/src/gpu/resident_geometry.dart` | **modify** — the corner-table doc gains the fill's role mapping; **no data change** |
| `shaders/cad_stroke.vert` | **modify** — one branch, no new attribute |
| `assets/shaders/cad.shaderbundle` | regenerated, committed |
| `test/support/instance_expander.dart` | **modify** — the fill branch, transcribed |
| `test/support/gpu_comparison.dart` | **modify** — `ResidentColorAgreement` and `measureResidentColor` |
| `test/support/fixtures.dart` | **modify** — `fillFixture()` (Task 4) |
| `test/support/fixtures_test.dart` | **modify** — the corpus's own non-degeneracy guards |
| `test/gpu/instance_record_test.dart` | **modify** — `writeFill` |
| `test/gpu/geometry_collector_test.dart` | **modify** — both fill ops at the record level |
| `test/gpu/collector_differential_test.dart` | **modify** — fills in the record-level differential |
| `test/gpu/instance_expander_test.dart` | **modify** — the fill branch's six vertices |
| `test/gpu/fill_order_test.dart` | **create** — spec criterion 4 |
| `test/gpu/resident_pixel_differential_test.dart` | **modify** — the fill corpus, and colour |
| `apps/dev_harness_2d/lib/gpu_arm.dart` | **modify** — the spike corpus grows fills |
| `docs/superpowers/notes/plan-d-mutation-log.md` | **create** |
| `docs/superpowers/notes/2026-09-01-plan-d-results.md` | **create** |

All paths under `lib/`, `shaders/`, `test/` and `assets/` are relative to
`packages/jet_cad_2d_flutter/`.

---

## The record, restated so no task restates it from memory

Unchanged by this plan except for one new legal value in slot 0.

```
float index  field            meaning
   0         kind             0 stroke, 1 join, 2 point, 3 FILL (new)
   1         halfWidth        device pixels; ZERO on a fill
   2, 3      x0, y0           collection space; a fill's first corner
   4, 5      x1, y1           a fill's second corner
   6, 7      x2, y2           a fill's third corner
   8..11     r, g, b, a       0..1; a fill's is style.argb, never _coveredArgb
  12         dashPeriod       0 on a fill
  13         dashPhase        0 on a fill
  14         dashFracStart    0 on a fill
  15         dashFracEnd      0 on a fill
```

Sixteen floats, **64 bytes** per instance. **Eight vertex attributes**, the
ES 100 floor, unchanged from Plan C.

**The kind dispatch is `<` chained and the order is load-bearing.** After this
plan the shader reads:

```glsl
if (kind < 0.5)        { /* stroke */ }
else if (kind < 1.5)   { /* join   */ }
else if (kind < 2.5)   { /* point  */ }
else                   { /* fill   */ }
```

The `else if (kind < 2.5)` line is **new**: today the point branch is the
bare `else`. An implementer who adds the fill branch without narrowing the
point branch draws every fill as a point — a single 1-pixel square where a
room should be. Task 5's expander tests fire on exactly that.

---

### Task 1: The record learns a fourth kind

**Files:**
- Modify: `lib/src/gpu/instance_record.dart`
- Test: `test/gpu/instance_record_test.dart`

**Interfaces:**
- Consumes: `kFloatsPerInstance`, `InstanceFieldOffset`, `_writeColor`,
  `_writeDash` — all already in this file.
- Produces:
  ```dart
  const double kKindFill = 3;

  void writeFill(
    Float32List into,
    int index, {
    required double x0,
    required double y0,
    required double x1,
    required double y1,
    required double x2,
    required double y2,
    required int argb,
  });
  ```

- [ ] **Step 1: Write the failing tests**

Append to `test/gpu/instance_record_test.dart`:

```dart
  test('a fill record carries three corners, no width and no dash', () {
    // Pre-filled with garbage so a writer that leaves a slot untouched is
    // caught. A fresh Float32List is all zeros, and most of this record's
    // expected values are zero, so a zero-initialised buffer would let a
    // missing write pass -- the degenerate-fixture trap, at the record
    // level.
    final data = Float32List(kFloatsPerInstance)..fillRange(0, kFloatsPerInstance, 17.5);
    writeFill(data, 0,
        x0: 3.5, y0: -4.25, x1: 11.0, y1: 2.5, x2: -6.75, y2: 9.5,
        argb: 0x8033CC66);

    expect(data[InstanceFieldOffset.kind], kKindFill);
    expect(data[InstanceFieldOffset.halfWidth], 0.0,
        reason: 'a fill has no width and the shader must not expand it');
    expect(data[InstanceFieldOffset.x0], 3.5);
    expect(data[InstanceFieldOffset.y0], -4.25);
    expect(data[InstanceFieldOffset.x1], 11.0);
    expect(data[InstanceFieldOffset.y1], 2.5);
    expect(data[InstanceFieldOffset.x2], -6.75);
    expect(data[InstanceFieldOffset.y2], 9.5);
    expect(data[InstanceFieldOffset.r], closeTo(0x33 / 255.0, 1e-6));
    expect(data[InstanceFieldOffset.g], closeTo(0xCC / 255.0, 1e-6));
    expect(data[InstanceFieldOffset.b], closeTo(0x66 / 255.0, 1e-6));
    expect(data[InstanceFieldOffset.a], closeTo(0x80 / 255.0, 1e-6));
    expect(data[InstanceFieldOffset.dashPeriod], 0.0);
    expect(data[InstanceFieldOffset.dashPhase], 0.0);
    expect(data[InstanceFieldOffset.dashFracStart], 0.0);
    expect(data[InstanceFieldOffset.dashFracEnd], 0.0);
  });

  test('the four kind tags are distinct and ordered for a < dispatch', () {
    // The shader dispatches `kind < 0.5`, `< 1.5`, `< 2.5`, else. These
    // values are not merely distinct: renumbering them without editing
    // cad_stroke.vert draws one kind as another, silently.
    expect(<double>[kKindStroke, kKindJoin, kKindPoint, kKindFill],
        <double>[0, 1, 2, 3]);
  });

  test('a fill at index 2 writes only its own record', () {
    final data = Float32List(kFloatsPerInstance * 4)
      ..fillRange(0, kFloatsPerInstance * 4, 17.5);
    writeFill(data, 2,
        x0: 1, y0: 2, x1: 3, y1: 4, x2: 5, y2: 6, argb: 0xFF000000);
    expect(data[kFloatsPerInstance * 1], 17.5,
        reason: 'the record before it is untouched');
    expect(data[kFloatsPerInstance * 3], 17.5,
        reason: 'the record after it is untouched');
    expect(data[kFloatsPerInstance * 2 + InstanceFieldOffset.kind], kKindFill);
  });
```

- [ ] **Step 2: Run them and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/instance_record_test.dart
```
Expected: compile failure — `kKindFill` and `writeFill` are undefined.

- [ ] **Step 3: Add the constant and the writer**

In `instance_record.dart`, after `kKindPoint`'s doc block:

```dart
/// One triangle of a fill. `(x0, y0)`, `(x1, y1)` and `(x2, y2)` are its
/// three corners in collection space, and [InstanceFieldOffset.halfWidth] is
/// zero — a fill has no width, so unlike every other kind nothing here is
/// expanded in device pixels. The shader reads the three corners through the
/// `join_weight` roles `V`, `A` and `B`, and folds `M` onto `A` so the second
/// triangle of the six-vertex quad is degenerate (Plan D's Ruling D1).
///
/// **A fill is never dashed and never fades.** `DraftPainter._drawFill` opens
/// no dash bracket, and the colour is `style.argb` rather than
/// `_coveredArgb`'s — routing a fill through the sub-pixel alpha fade would
/// fade a filled room on a hairline layer (`vertices_draw_sink.dart:752-757`).
const double kKindFill = 3;
```

Update `kKindStroke`'s doc, which today says *"The values are 0, 1, 2"* — it
becomes:

```dart
/// **The values are 0, 1, 2, 3 and the order is load-bearing**, not merely
/// distinct: `cad_stroke.vert` dispatches with `kind < 0.5`, then
/// `kind < 1.5`, then `kind < 2.5`, because ES 100 has no integer attributes
/// and no `switch` on one. Renumbering these without editing that shader
/// silently draws every join as a stroke, or every fill as a point.
```

And append the writer at the end of the file:

```dart
/// Writes the fill-triangle record at [index]. [argb] is `0xAARRGGBB`.
///
/// **Takes no half-width and no dash arguments, by design.** A fill has no
/// width to expand (Ruling D2) and cannot be dashed (Ruling D4): the painter
/// reaches `fillPolygon` and `fillCircle` outside any `beginDash` bracket. All
/// five slots are still written explicitly — see [_writeDash]'s own doc for
/// why an explicit zero is not the same as a fresh buffer's zero.
void writeFill(
  Float32List into,
  int index, {
  required double x0,
  required double y0,
  required double x1,
  required double y1,
  required double x2,
  required double y2,
  required int argb,
}) {
  final o = index * kFloatsPerInstance;
  into[o + InstanceFieldOffset.kind] = kKindFill;
  into[o + InstanceFieldOffset.halfWidth] = 0;
  into[o + InstanceFieldOffset.x0] = x0;
  into[o + InstanceFieldOffset.y0] = y0;
  into[o + InstanceFieldOffset.x1] = x1;
  into[o + InstanceFieldOffset.y1] = y1;
  into[o + InstanceFieldOffset.x2] = x2;
  into[o + InstanceFieldOffset.y2] = y2;
  _writeColor(into, o, argb);
  _writeDash(into, o, 0, 0, 0, 0);
}
```

- [ ] **Step 4: Run the tests**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/instance_record_test.dart
```
Expected: PASS.

- [ ] **Step 5: Full gate and commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git add lib/src/gpu/instance_record.dart test/gpu/instance_record_test.dart
git commit -m "feat(gpu): the instance record learns a fill kind"
```

---

### Task 2: The collector fills a polygon

**Files:**
- Modify: `lib/src/gpu/geometry_collector.dart:625-631`
- Test: `test/gpu/geometry_collector_test.dart`

**Interfaces:**
- Consumes: `writeFill` and `kKindFill` from Task 1; `_reserve`, `_residual`.
- Produces: `GeometryCollector.fillPolygon` writing `triangles.length ~/ 3`
  instances; `skippedOps` no longer counts it.

**The reference, which this transcribes** (`vertices_draw_sink.dart:745-768`):
`triangles` triple-indexes into `points`' own point numbering, so each index
is doubled to reach the coordinate pair; each of the three points is
transformed by the residual as it is read; `triangles.isEmpty` returns; the
colour is `style.argb` directly.

- [ ] **Step 1: Write the failing tests**

Append to `test/gpu/geometry_collector_test.dart`:

```dart
  test('a fill polygon is one instance per triangle, in triangulation order',
      () {
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    // A non-identity, non-uniform, off-origin residual: the identity would
    // hide a transposed matrix element, which is the defect Plan A's
    // post-mortem names.
    c.beginResidual(Transform2.translation(120, -35)
        .multiply(Transform2.rotation(0.4))
        .multiply(Transform2.scale(1.7, 0.6)));
    c.fillPolygon(
        Float64List.fromList(<double>[0, 0, 10, 0, 10, 6, 0, 6]),
        4,
        Int32List.fromList(<int>[0, 1, 2, 0, 2, 3]),
        const ResolvedStyle(
            argb: 0xFF3366CC,
            lineweightHundredths: 25,
            linetype: Handle.none,
            linetypeScale: 1));
    c.endResidual();

    expect(c.instanceCount, 2);
    expect(c.skippedOps, 0, reason: 'a fill is drawn now, not counted');

    final data = c.data;
    for (var i = 0; i < 2; i++) {
      expect(data[i * kFloatsPerInstance + InstanceFieldOffset.kind],
          kKindFill);
      expect(data[i * kFloatsPerInstance + InstanceFieldOffset.halfWidth], 0.0);
    }

    // The residual, applied by hand to point 1 (10, 0), against the first
    // triangle's second corner. Computed here rather than read from the
    // collector so the assertion is an independent derivation.
    final t = Transform2.translation(120, -35)
        .multiply(Transform2.rotation(0.4))
        .multiply(Transform2.scale(1.7, 0.6));
    expect(data[InstanceFieldOffset.x1],
        closeTo(t.a * 10 + t.c * 0 + t.e, 1e-3));
    expect(data[InstanceFieldOffset.y1],
        closeTo(t.b * 10 + t.d * 0 + t.f, 1e-3));

    // Triangulation order: the second instance is (0, 2, 3), so its second
    // corner is point 2 (10, 6) and its third is point 3 (0, 6). A
    // collector that walked the triangle list backwards, or that sorted it,
    // fails here -- and draw order is emission order.
    final o = kFloatsPerInstance;
    expect(data[o + InstanceFieldOffset.x1],
        closeTo(t.a * 10 + t.c * 6 + t.e, 1e-3));
    expect(data[o + InstanceFieldOffset.x2],
        closeTo(t.a * 0 + t.c * 6 + t.e, 1e-3));
  });

  test('a fill keeps its own colour on a hairline layer', () {
    // The lineweight is sub-pixel, which is exactly what `_coveredArgb`
    // fades for a stroke. A fill must not fade: routing it through that
    // function would fade a filled room on a hairline layer.
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 1.0);
    c.beginResidual(Transform2.translation(5, 7));
    c.fillPolygon(
        Float64List.fromList(<double>[0, 0, 8, 0, 4, 9]),
        3,
        Int32List.fromList(<int>[0, 1, 2]),
        const ResolvedStyle(
            argb: 0xFF884422,
            lineweightHundredths: 1,
            linetype: Handle.none,
            linetypeScale: 1));
    c.endResidual();

    final data = c.data;
    expect(data[InstanceFieldOffset.a], closeTo(1.0, 1e-6),
        reason: 'a fill never goes through _coveredArgb');
    expect(data[InstanceFieldOffset.r], closeTo(0x88 / 255.0, 1e-6));
  });

  test('an empty triangulation writes nothing', () {
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 1.0);
    c.beginResidual(Transform2.translation(5, 7));
    c.fillPolygon(
        Float64List.fromList(<double>[0, 0, 8, 0, 4, 9]),
        3,
        Int32List(0),
        const ResolvedStyle(
            argb: 0xFF884422,
            lineweightHundredths: 25,
            linetype: Handle.none,
            linetypeScale: 1));
    c.endResidual();
    expect(c.instanceCount, 0);
  });

  test('a degenerate triangle is written, not dropped', () {
    // `VerticesDrawSink._emitTriangle` has no zero-area test, so neither
    // does this: matching the formula rather than the intention is what
    // keeps the two arms' instance lists identical. Both rasterisers drop
    // it at raster time instead.
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 1.0);
    c.beginResidual(Transform2.translation(5, 7));
    c.fillPolygon(
        Float64List.fromList(<double>[0, 0, 8, 0, 4, 9]),
        3,
        Int32List.fromList(<int>[0, 1, 1]),
        const ResolvedStyle(
            argb: 0xFF884422,
            lineweightHundredths: 25,
            linetype: Handle.none,
            linetypeScale: 1));
    c.endResidual();
    expect(c.instanceCount, 1);
  });
```

- [ ] **Step 2: Run them and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```
Expected: `Expected: <2> Actual: <0>` on the first — `fillPolygon` still only
increments `_skipped`.

- [ ] **Step 3: Implement**

Replace `fillPolygon`'s body in `geometry_collector.dart`:

```dart
  /// One instance per triangle, in the triangulation's own order.
  ///
  /// **Read, never computed** — the triangulation was materialised by the
  /// command, the codec or undo, and `DraftPainter._drawFill` passes it
  /// through. This transcribes `VerticesDrawSink.fillPolygon`, including
  /// that `triangles` triple-indexes into `points`' *point* numbering, so
  /// each index is doubled to reach a coordinate pair.
  ///
  /// **`style.argb` directly, NOT `_coveredArgb`** (Ruling D3): a fill has no
  /// width to fade, and a fill entity's `ResolvedStyle` still carries a
  /// lineweight because the column is shared with strokes.
  ///
  /// **No degenerate-triangle test** (Ruling D6): the reference's
  /// `_emitTriangle` has none, and adding one here would make the two arms'
  /// instance lists differ on a triangulation that contains one.
  @override
  void fillPolygon(
      Float64List points, int count, Int32List triangles, ResolvedStyle style) {
    if (triangles.isEmpty) return;
    final t = _residual;
    final argb = style.argb;
    _reserve(_instances + triangles.length ~/ 3);
    for (var i = 0; i + 2 < triangles.length; i += 3) {
      final a = triangles[i], b = triangles[i + 1], c = triangles[i + 2];
      final ax = points[a * 2], ay = points[a * 2 + 1];
      final bx = points[b * 2], by = points[b * 2 + 1];
      final cx = points[c * 2], cy = points[c * 2 + 1];
      writeFill(_buffer, _instances,
          x0: t.a * ax + t.c * ay + t.e,
          y0: t.b * ax + t.d * ay + t.f,
          x1: t.a * bx + t.c * by + t.e,
          y1: t.b * bx + t.d * by + t.f,
          x2: t.a * cx + t.c * cy + t.e,
          y2: t.b * cx + t.d * cy + t.f,
          argb: argb);
      _instances++;
    }
  }
```

Update `skippedOps`' doc, which today names three ops:

```dart
  /// Ops this plan does not draw yet — `text` alone, since Plan D.
  ///
  /// Counted rather than ignored so a corpus that needs Plan E is visible as
  /// a number instead of as a missing picture.
  ///
  /// `circle` and `arc` stopped counting here in Plan B's Task 5; `point` in
  /// its Task 6; `fillPolygon` and `fillCircle` in Plan D's Tasks 2 and 3.
```

- [ ] **Step 4: Run**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```
Expected: PASS.

- [ ] **Step 5: Full gate and commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git add lib/src/gpu/geometry_collector.dart test/gpu/geometry_collector_test.dart
git commit -m "feat(gpu): the collector writes a pre-triangulated fill"
```

Expected during Step 5: `test/gpu/geometry_collector_test.dart`'s existing
*"the collector counts what it cannot draw"* test (if one asserts
`skippedOps == 3` on a corpus with a fill) goes red. Update its expectation
and its comment in the same commit — the number it asserts is now the text ops
alone.

---

### Task 3: The collector fills a circle at its outline's step count

**Files:**
- Modify: `lib/src/gpu/geometry_collector.dart:633-637`
- Test: `test/gpu/geometry_collector_test.dart`

**Interfaces:**
- Consumes: `writeFill`, `_flattenSteps`, `_residual`.
- Produces: `GeometryCollector.fillCircle` writing `steps` instances.

- [ ] **Step 1: Write the failing tests**

```dart
  test('a filled circle is a fan at the same step count as its own outline',
      () {
    // The fill and the stroke of the same circle must tessellate
    // identically, or the fill peeks out from under its own boundary at
    // some zoom. Both go through _flattenSteps; this asserts they agree
    // rather than that either equals a hardcoded number.
    const style = ResolvedStyle(
        argb: 0xFF224466,
        lineweightHundredths: 25,
        linetype: Handle.none,
        linetypeScale: 1);
    final residual = Transform2.translation(300, 90)
        .multiply(Transform2.rotation(-0.6))
        .multiply(Transform2.scale(1.35, 1.35));

    final outline = GeometryCollector(
        pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0)
      ..beginResidual(residual)
      ..circle(12, -5, 7.5, style)
      ..endResidual();
    // A closed run: `steps` segments and `steps` joins (the seam included).
    final chords = outline.instanceCount ~/ 2;

    final fill = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0)
      ..beginResidual(residual)
      ..fillCircle(12, -5, 7.5, style)
      ..endResidual();

    expect(fill.instanceCount, chords,
        reason: 'the fan and the outline must use one step count');
    expect(fill.skippedOps, 0);
  });

  test('the fan shares one centre and walks the rim in ascending angle', () {
    const style = ResolvedStyle(
        argb: 0xFF224466,
        lineweightHundredths: 25,
        linetype: Handle.none,
        linetypeScale: 1);
    final t = Transform2.translation(300, 90).multiply(Transform2.scale(2, 3));
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0)
      ..beginResidual(t)
      ..fillCircle(12, -5, 7.5, style)
      ..endResidual();

    final data = c.data;
    final centreX = t.a * 12 + t.c * -5 + t.e;
    final centreY = t.b * 12 + t.d * -5 + t.f;
    for (var i = 0; i < c.instanceCount; i++) {
      final o = i * kFloatsPerInstance;
      expect(data[o + InstanceFieldOffset.kind], kKindFill);
      expect(data[o + InstanceFieldOffset.x0], closeTo(centreX, 1e-3),
          reason: 'every triangle of a fan starts at the centre');
      expect(data[o + InstanceFieldOffset.y0], closeTo(centreY, 1e-3));
    }
    // Triangle 0's second corner is the rim at angle 0: (cx + r, cy).
    expect(data[InstanceFieldOffset.x1],
        closeTo(t.a * (12 + 7.5) + t.c * -5 + t.e, 1e-3));
    // Consecutive triangles share an edge: triangle i's third corner is
    // triangle i+1's second. A fan written out of order fails here.
    final o1 = kFloatsPerInstance;
    expect(data[o1 + InstanceFieldOffset.x1],
        closeTo(data[InstanceFieldOffset.x2], 1e-6));
    expect(data[o1 + InstanceFieldOffset.y1],
        closeTo(data[InstanceFieldOffset.y2], 1e-6));
  });

  test('a zero or negative radius fills nothing', () {
    const style = ResolvedStyle(
        argb: 0xFF224466,
        lineweightHundredths: 25,
        linetype: Handle.none,
        linetypeScale: 1);
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 1.0)
      ..beginResidual(Transform2.translation(3, 4))
      ..fillCircle(1, 1, 0, style)
      ..fillCircle(1, 1, -2, style)
      ..endResidual();
    expect(c.instanceCount, 0);
  });
```

- [ ] **Step 2: Run and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```
Expected: `Expected: <N> Actual: <0>`.

- [ ] **Step 3: Implement**

```dart
  /// A triangle fan around the circle's centre, at the same step count
  /// [_flatten] would give the circle's own outline.
  ///
  /// **The shared `_flattenSteps` call is the point** (Ruling D5): a filled
  /// circle's silhouette is tessellated by the same expression as its own
  /// boundary stroke, so the two never disagree at any zoom. The rim starts
  /// at angle 0, i.e. `(cx + r, cy)`, exactly as
  /// `VerticesDrawSink.fillCircle` does.
  @override
  void fillCircle(double cx, double cy, double r, ResolvedStyle style) {
    if (r <= 0) return;
    final t = _residual;
    final deviceRadius = r * t.scaleMagnitude;
    if (deviceRadius <= 0) return;
    const theta = 2 * math.pi;
    final steps = _flattenSteps(deviceRadius, theta);
    // `style.argb` directly, never `_coveredArgb` -- Ruling D3.
    final argb = style.argb;
    final ccx = t.a * cx + t.c * cy + t.e;
    final ccy = t.b * cx + t.d * cy + t.f;
    var px = cx + r, py = cy;
    var dx = t.a * px + t.c * py + t.e, dy = t.b * px + t.d * py + t.f;
    _reserve(_instances + steps);
    for (var i = 1; i <= steps; i++) {
      final angle = theta * i / steps;
      px = cx + r * math.cos(angle);
      py = cy + r * math.sin(angle);
      final nx = t.a * px + t.c * py + t.e, ny = t.b * px + t.d * py + t.f;
      writeFill(_buffer, _instances,
          x0: ccx, y0: ccy, x1: dx, y1: dy, x2: nx, y2: ny, argb: argb);
      _instances++;
      dx = nx;
      dy = ny;
    }
  }
```

- [ ] **Step 4: Run**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```
Expected: PASS.

- [ ] **Step 5: Full gate and commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git add lib/src/gpu/geometry_collector.dart test/gpu/geometry_collector_test.dart
git commit -m "feat(gpu): the collector fans a filled circle at the outline's step count"
```

---

### Task 4: The corpus grows two fills, and a guard that they are not degenerate

**Files:**
- Modify: `test/support/fixtures.dart`
- Modify: `test/support/fixtures_test.dart`
- Test: `test/support/fixtures_test.dart`

**Interfaces:**
- Produces: `DraftDocument fillFixture()`, a document whose handles are
  documented below and are relied on by Tasks 7 and 8.

**The corpus the spec asks for**, verbatim: *"an opaque fill overlapping
strokes of both lower and higher handle"*, and *"a translucent fill"*. Both
clauses are load-bearing:

- **Both sides of the handle order.** A fill that only overlaps strokes of
  *lower* handle draws over them in emission order; permuting the buffer
  changes nothing visible, because the fill was on top either way. Only a
  stroke of *higher* handle — drawn after the fill, so visible over it —
  makes the permutation change a pixel.
- **A hairline layer** for the opaque fill, so Ruling D3's mutation has a
  fixture.

**Handles, fixed here so later tasks name them rather than counting:**

| handle | what |
|---|---|
| 900 | a thick stroke **under** the fill (lower handle) |
| 901 | the fill entity, opaque, on a hairline layer |
| 902 | its boundary polygon |
| 903 | a thick stroke **over** the fill (higher handle), crossing it |
| 904 | the translucent fill entity |
| 905 | its boundary circle |

- [ ] **Step 1: Write the failing guard tests**

Append to `test/support/fixtures_test.dart`:

```dart
  group('fillFixture', () {
    test('is not degenerate in any of the four ways that would hide a defect',
        () {
      final doc = fillFixture();

      // 1. A fill exists and is indexed, so the painter can reach it.
      final fillSlot = doc.entities.slotOf(const Handle(901))!;
      expect(doc.entities.kindAt(fillSlot), EntityKind.fill);
      expect(doc.fills.trianglesFor(const Handle(902)), isNotNull,
          reason: 'an unfillable boundary is skipped by the painter and the '
              'corpus would silently draw no fill at all');

      // 2. Strokes on BOTH sides of the fill in handle order. Without the
      //    higher one, permuting the buffer changes no pixel and the
      //    criterion-4 test in Task 7 passes vacuously.
      expect(const Handle(900).value, lessThan(const Handle(901).value));
      expect(const Handle(903).value, greaterThan(const Handle(901).value));

      // 3. The translucent fill is actually translucent -- neither opaque
      //    nor invisible.
      final translucentSlot = doc.entities.slotOf(const Handle(904))!;
      final translucent = doc.entities.transparencyAt(translucentSlot);
      expect(translucent, greaterThan(0));
      expect(translucent, lessThan(255));

      // 4. No identity transform: the fill sits under a rotated, non-uniform
      //    instance well away from the origin. An axis-aligned fill at the
      //    origin hides a transposed matrix element -- Plan 2's post-mortem.
      final node = doc.tree.nodeOf(const Handle(910))! as InstanceNode;
      expect(node.transform.a, isNot(closeTo(node.transform.d, 1e-9)));
      expect(node.transform.b, isNot(0.0));
      expect(node.transform.e.abs(), greaterThan(1.0));
    });

    test('the fill and the higher-handle stroke actually overlap on screen',
        () {
      // A corpus whose "overlapping" shapes miss each other proves nothing.
      // Painted through the reference sink, the stroke's ink must land
      // inside the fill's bounding box.
      final doc = fillFixture();
      final fillBox = doc.extents;
      expect(fillBox.min.x, lessThan(fillBox.max.x));
      final overlap = strokeInkInsideFill(doc);
      expect(overlap, greaterThan(200),
          reason: 'fewer than 200 shared device pixels and the order gate '
              'cannot see a permutation');
    });
  });
```

`strokeInkInsideFill` is a helper this task adds to `fixtures.dart` — it
paints the corpus through `VerticesDrawSink` twice, once with handle 903
present and once with it removed, and returns the number of pixels that
differ inside the fill's screen box.

**Check `EntityIndex`'s accessor names against the source before writing the
guard.** The sample above reads `transparencyAt(slot)`; if this document
model spells it differently, use the real name — the assertion is that the
value is strictly between 0 and 255, not that any particular getter exists.

- [ ] **Step 2: Run and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/support/fixtures_test.dart
```
Expected: compile failure — `fillFixture` is undefined.

- [ ] **Step 3: Build the fixture**

In `test/support/fixtures.dart`:

```dart
/// A corpus for Plan D: two fills, and strokes on both sides of one of them
/// in handle order.
///
/// **Every element is here because a named mutation needs it:**
///  - handle 900 is a thick stroke the fill covers, so a fill that failed to
///    draw leaves it visible;
///  - handle 901 is an opaque fill on a **hairline layer**, so a fill routed
///    through `_coveredArgb` fades (M-D5) where a correct one does not;
///  - handle 903 is a thick stroke of HIGHER handle crossing the fill, so it
///    is drawn *after* the fill and stays visible over it. Permuting the
///    buffer to draw all fills last hides it -- which is spec criterion 4,
///    and the reason this corpus exists at all;
///  - handle 904 is a translucent fill over a circle boundary, so the fan
///    path (`fillCircle`) is exercised and the colour comparison has a
///    non-opaque value to disagree about;
///  - the whole thing sits under instance 910, rotated and non-uniformly
///    scaled, far from the origin: an identity transform commutes and hides
///    composition-order defects (Plan 2's post-mortem).
DraftDocument fillFixture() {
  final doc = DraftDocument.empty();

  const content = Handle(890);
  doc.tree.addDefinition(Definition(
      handle: content,
      name: 'filled-room',
      basePoint: Vector2.zero(),
      children: const []));

  // 900: under the fill.
  addEntity(doc, content, const Handle(900), EntityKind.line,
      [1, 1, 19, 13], const [], lineweight: 60);

  // 901 / 902: the opaque fill and its boundary, on a hairline layer.
  final hairline = doc.handleSeed.next();
  doc.commands.execute(AddLayerCommand(LayerRecord(
    handle: hairline,
    name: 'hairline',
    color: const TrueColor(0x333333),
    linetype: ReservedHandles.continuousLinetype,
    lineweight: 1,
  )));
  doc.commands.execute(AddRegionCommand(
    fill: EntityRecord(
      handle: const Handle(901),
      owner: content,
      kind: EntityKind.fill,
      layer: hairline,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const TrueColor(0x2E7D32),
      lineweight: 1,
      transparency: 0,
      flags: 0,
    ),
    boundary: EntityRecord(
      handle: const Handle(902),
      owner: content,
      kind: EntityKind.polyline,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const TrueColor(0x000000),
      lineweight: kLineweightDefault,
      transparency: 0,
      flags: 0,
    ),
    boundaryPayload: GeometryPayload(
      coords: Float64List.fromList(<double>[
        2, 2, //
        17, 3, //
        16, 12, //
        3, 11, //
        2, 2, // closing duplicate
      ]),
      scalars: Float64List(0),
    ),
  ));

  // 903: over the fill, and crossing it.
  addEntity(doc, content, const Handle(903), EntityKind.line,
      [3, 12, 17, 2], const [], lineweight: 60);

  // 904 / 905: the translucent fill, over a circle boundary.
  doc.commands.execute(AddRegionCommand(
    fill: EntityRecord(
      handle: const Handle(904),
      owner: content,
      kind: EntityKind.fill,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const TrueColor(0xC62828),
      lineweight: kLineweightDefault,
      transparency: 128,
      flags: 0,
    ),
    boundary: EntityRecord(
      handle: const Handle(905),
      owner: content,
      kind: EntityKind.circle,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const TrueColor(0x000000),
      lineweight: kLineweightDefault,
      transparency: 0,
      flags: 0,
    ),
    boundaryPayload: GeometryPayload(
      coords: Float64List.fromList(<double>[24, 7]),
      scalars: Float64List.fromList(<double>[5.5]),
    ),
  ));

  // The placement: rotated, non-uniformly scaled, far from the origin.
  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: const Handle(910),
    parent: doc.rootHandle,
    transform: Transform2.translation(37.5, 22.25)
        .multiply(Transform2.rotation(0.44))
        .multiply(Transform2.scale(1.8, 1.15)),
    definition: content,
    layer: ReservedHandles.layerZero,
    color: const IndexedColor(7),
  )));

  return doc;
}
```

**A polygon boundary needs a triangulation**, and `AddRegionCommand`
materialises one — assert it in Step 1's guard rather than assuming it. If
`doc.fills.trianglesFor(const Handle(902))` comes back null, put one in by
hand with `doc.fills.putTriangles`, as `fill_render_test.dart:132` does, and
say so in the fixture's doc.

- [ ] **Step 4: Run**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/support/fixtures_test.dart
```
Expected: PASS.

- [ ] **Step 5: Both gates and commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
git status --short
git add packages/jet_cad_2d_flutter/test/support/fixtures.dart packages/jet_cad_2d_flutter/test/support/fixtures_test.dart
git commit -m "test(gpu): a fill corpus with strokes on both sides of the fill"
```

---

### Task 5: The shader draws a fill, and the Dart transcription says the same thing

**Files:**
- Modify: `shaders/cad_stroke.vert`
- Regenerate: `assets/shaders/cad.shaderbundle`
- Modify: `test/support/instance_expander.dart`
- Modify: `lib/src/gpu/resident_geometry.dart` (documentation only)
- Test: `test/gpu/instance_expander_test.dart`

**Interfaces:**
- Consumes: `kKindFill`, `writeFill`.
- Produces: no signature change. `expandInstances` handles kind 3.

**Ruling B6 governs this task.** `instance_expander.dart` is `cad_stroke.vert`
transcribed statement for statement, because `flutter test` has no GPU. Edit
them in the same commit, in the same order, with the same variable names.

**No new attribute and no new record float** — the eight-attribute ES 100
ceiling is not approached by this task, and that is worth stating in the task
report because it is the single risk Plan C spent a ruling on.

- [ ] **Step 1: Write the failing expander tests**

```dart
  test('a fill expands to its three corners and one degenerate triangle', () {
    final data = Float32List(kFloatsPerInstance);
    writeFill(data, 0,
        x0: 10, y0: 10, x1: 40, y1: 12, x2: 25, y2: 38, argb: 0xFF2E7D32);
    final e = expandInstances(data, 1, Transform2.identity(), dashScale: 1.0);

    // Triangle 0 is (p0, p1, p2), in that vertex order.
    expect(e.positions[0], closeTo(10, 1e-6));
    expect(e.positions[1], closeTo(10, 1e-6));
    expect(e.positions[2], closeTo(40, 1e-6));
    expect(e.positions[3], closeTo(12, 1e-6));
    expect(e.positions[4], closeTo(25, 1e-6));
    expect(e.positions[5], closeTo(38, 1e-6));

    // Triangle 1 is (p1, p1, p2): zero area, so it rasterises nothing.
    final area = (e.positions[8] - e.positions[6]) *
            (e.positions[11] - e.positions[7]) -
        (e.positions[9] - e.positions[7]) * (e.positions[10] - e.positions[6]);
    expect(area, 0.0,
        reason: 'the second triangle of a fill instance must be degenerate');
  });

  test('a fill is not expanded by a half-width, at any camera', () {
    // The defect this catches: a fill routed through the stroke branch, or a
    // fill branch that read `half_width`. Either one grows the triangle by a
    // device-pixel margin, so its corners move away from the projected
    // points -- and the amount would change with the camera.
    final data = Float32List(kFloatsPerInstance);
    writeFill(data, 0,
        x0: 10, y0: 10, x1: 40, y1: 12, x2: 25, y2: 38, argb: 0xFF2E7D32);
    // Deliberately poison the half-width slot: a correct fill branch ignores
    // it. `writeFill` writes zero there, so without this the assertion could
    // not tell "ignored" from "zero".
    data[InstanceFieldOffset.halfWidth] = 9.0;

    final t = Transform2.translation(120, -35)
        .multiply(Transform2.rotation(0.4))
        .multiply(Transform2.scale(1.7, 0.6));
    final e = expandInstances(data, 1, t, dashScale: 1.0);
    expect(e.positions[0], closeTo(t.a * 10 + t.c * 10 + t.e, 1e-4));
    expect(e.positions[1], closeTo(t.b * 10 + t.d * 10 + t.f, 1e-4));
  });

  test('a fill is solid: the dash test never runs on it', () {
    final data = Float32List(kFloatsPerInstance);
    writeFill(data, 0,
        x0: 10, y0: 10, x1: 40, y1: 12, x2: 25, y2: 38, argb: 0xFF2E7D32);
    final e = expandInstances(data, 1, Transform2.identity(), dashScale: 0.01);
    for (var v = 0; v < ResidentGeometry.cornerVertexCount; v++) {
      expect(e.dashVaryings[v * 3 + 1], lessThan(0.0),
          reason: 'a negative fracStart is the solid sentinel; a fill must '
              'carry it at every camera, collapse scale included');
    }
  });

  test('a point is still a point after the fill branch lands', () {
    // The regression this guards: adding `else { fill }` without narrowing
    // the point branch to `else if (kind < 2.5)` draws every fill as a
    // one-pixel square -- or, with the branches swapped, every point as a
    // triangle. Both directions are silent.
    final data = Float32List(kFloatsPerInstance);
    writePoint(data, 0, x: 20, y: 30, halfWidth: 4, argb: 0xFF102030);
    final e = expandInstances(data, 1, Transform2.identity(), dashScale: 1.0);
    final xs = <double>[for (var v = 0; v < 6; v++) e.positions[v * 2]];
    final ys = <double>[for (var v = 0; v < 6; v++) e.positions[v * 2 + 1]];
    expect(xs.reduce(math.max) - xs.reduce(math.min), closeTo(8, 1e-6));
    expect(ys.reduce(math.max) - ys.reduce(math.min), closeTo(8, 1e-6));
  });
```

- [ ] **Step 2: Run and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/instance_expander_test.dart
```
Expected: the first three fail — kind 3 currently falls into the point branch
and draws an 8-device-pixel square at `p0`.

- [ ] **Step 3: Add the shader branch**

In `cad_stroke.vert`, add to the header:

```
// **A fill is the one kind that expands nothing.** Its three corners are
// projected and used; `half_width` is zero and is not read. The six-vertex
// corner table is reused unchanged: `join_weight`'s V, A and B select the
// three corners and M is folded onto A, so the second triangle is
// degenerate and rasterises nothing (Plan D's Ruling D1).
```

Narrow the point branch and add the fill branch:

```glsl
  } else if (kind < 2.5) {
    // kKindPoint: a square of the stroke's width centred on p0. Both axes
    // are expanded here, in device pixels, so the dot stays square and stays
    // the same size at every zoom -- which is what the reference gets for
    // free by computing its `+/- half` in device space. A point is never
    // dashed.
    vec2 c = to_pixels(p0);
    px = c + vec2((corner.x * 2.0 - 1.0) * half_width, corner.y * half_width);

  } else {
    // kKindFill: one triangle of a pre-triangulated fill. Nothing is
    // expanded -- a fill has no width -- so `half_width` is not read here at
    // all. `join_weight` selects the corner: V -> p0, A -> p1, B -> p2, and
    // M folded onto p1, which makes the second triangle (A, M, B) =
    // (p1, p1, p2) degenerate.
    vec2 a0 = to_pixels(p0);
    vec2 a1 = to_pixels(p1);
    vec2 a2 = to_pixels(p2);
    px = join_weight.x * a0 + (join_weight.y + join_weight.w) * a1 +
         join_weight.z * a2;
    // `along` stays 0 and `dash` is all zeros on a fill, so the tail's
    // `period > 0.0` test fails and `v_dash` keeps its solid sentinel.
  }
```

- [ ] **Step 4: Regenerate and verify the bundle**

```sh
cd packages/jet_cad_2d_flutter && sh tool/build_shaders.sh
shasum -a 256 assets/shaders/cad.shaderbundle
strings -a assets/shaders/cad.shaderbundle | grep -c "attribute "
```

Record the hash and the attribute count in the task report. The count must be
**8**, unchanged — this task adds no attribute. If `impellerc` fails with
*"Could not complete reflection on generated shader"*, the cause is an
attribute the optimizer folded away; check that all eight are still read on a
path the compiler cannot prove dead.

- [ ] **Step 5: Mirror it in `instance_expander.dart`**

In the per-vertex loop, narrow the point branch to `else if (kind < 2.5)` and
append:

```dart
      } else {
        // kKindFill: one triangle of a pre-triangulated fill. Nothing is
        // expanded -- a fill has no width -- so `halfWidth` is not read here
        // at all. `join_weight` selects the corner: V -> p0, A -> p1,
        // B -> p2, and M folded onto p1, which makes the second triangle
        // (A, M, B) = (p1, p1, p2) degenerate.
        final a0x = toX(x0, y0), a0y = toY(x0, y0);
        final a1x = toX(x1, y1), a1y = toY(x1, y1);
        final a2x = toX(x2, y2), a2y = toY(x2, y2);
        px = c.wv * a0x + (c.wa + c.wm) * a1x + c.wb * a2x;
        py = c.wv * a0y + (c.wa + c.wm) * a1y + c.wb * a2y;
      }
```

Update the file's header to say the fill branch is transcribed too, and update
`resident_geometry.dart`'s `kCornerVertices` doc with the role mapping table
from Ruling D1 — that data is unchanged, but a reader of the join-only
explanation would not know a fourth kind reads it.

- [ ] **Step 6: Run**

```sh
cd packages/jet_cad_2d_flutter && flutter test
```
Expected: PASS, all of it.

- [ ] **Step 7: Commit**

```sh
git status --short
git add shaders/cad_stroke.vert assets/shaders/cad.shaderbundle test/support/instance_expander.dart lib/src/gpu/resident_geometry.dart test/gpu/instance_expander_test.dart
git commit -m "feat(gpu): the vertex shader draws a fill triangle"
```

---

### Task 6: The pixel instrument learns colour

**Files:**
- Modify: `test/support/gpu_comparison.dart`
- Test: `test/gpu/resident_pixel_differential_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class ResidentColorAgreement {
    final int union;        // pixels either arm inked
    final int withinTwo;    // per-channel difference <= 2
    final int overEight;    // per-channel difference > 8
    final int referenceInk;
    double get withinTwoFraction;
  }

  ResidentColorAgreement measureResidentColor(
      void Function(DrawSink) corpus,
      {required Size size,
      required double devicePixelRatio,
      required double pixelsPerPaperMm,
      List<int> Function(List<int> order)? permute});
  ```

**Why this exists** (Ruling D8): `gpu_comparison.dart`'s own doc records that
its coverage measurement cannot see order, and that *"the per-channel half of
the design document's criterion 1 is not something this file can gate"*. Both
sentences stop being true here, and both must be **rewritten in this task**,
not left standing next to a measurement that contradicts them.

`permute` reorders the *instance* buffer before expansion, so a caller can
submit the same instances out of walk order. It is `null` for every ordinary
measurement; Task 7 is its only caller.

- [ ] **Step 1: Write the failing test**

In `test/gpu/resident_pixel_differential_test.dart`:

```dart
  test('the two arms agree per channel, not merely on coverage', () {
    final r = measureResidentColor(_corpus,
        size: _size, devicePixelRatio: _dpr, pixelsPerPaperMm: _ppmm);
    // Spec criterion 1: per-channel difference <= 2 on >= 99.5% of pixels,
    // <= 8 on the rest.
    expect(r.withinTwoFraction, greaterThanOrEqualTo(0.995), reason: r.toString());
    expect(r.overEight, 0, reason: r.toString());
    // Anti-vacuity: an instrument that measured an empty picture would pass
    // both lines above.
    expect(r.referenceInk, greaterThan(5000), reason: r.toString());
  });

  test('the colour measurement can actually fail', () {
    // The control arm Plan 3i's Ruling 14 requires: an instrument whose
    // failing case is never exercised reads 1.00 and proves nothing. Here
    // the resident arm is fed a deliberately recoloured buffer.
    final r = measureResidentColor(_corpus,
        size: _size,
        devicePixelRatio: _dpr,
        pixelsPerPaperMm: _ppmm,
        debugTintResident: 0x00202020);
    expect(r.withinTwoFraction, lessThan(0.995), reason: r.toString());
  });
```

- [ ] **Step 2: Run and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/resident_pixel_differential_test.dart
```
Expected: compile failure — `measureResidentColor` is undefined.

- [ ] **Step 3: Implement the measurement**

In `gpu_comparison.dart`, beside `measureResidentAgreement`:

```dart
/// A per-channel comparison of the two arms' rasterised colour.
///
/// **This is the half of spec criterion 1 that coverage cannot reach.**
/// `TriangleRasterizer._fill` is last-write-wins with no blending, so a
/// pixel's final colour is the colour of the *last* triangle to cover it --
/// which makes this the only measurement in the suite that can see emission
/// order at all. Both arms share the rasterizer, so the absence of blending
/// cancels exactly the way MSAA does in the device comparison.
class ResidentColorAgreement {
  ResidentColorAgreement(
      this.union, this.withinTwo, this.overEight, this.referenceInk);

  /// Pixels either arm inked. The comparison runs over these: a pixel
  /// neither arm touched is background on both sides and says nothing.
  final int union;

  /// Pixels whose every channel differs by at most 2.
  final int withinTwo;

  /// Pixels with any channel differing by more than 8 -- spec criterion 1
  /// allows none.
  final int overEight;

  final int referenceInk;

  double get withinTwoFraction => union == 0 ? 1.0 : withinTwo / union;

  @override
  String toString() => 'union=$union withinTwo=$withinTwo '
      '(${(withinTwoFraction * 100).toStringAsFixed(3)}%) '
      'overEight=$overEight referenceInk=$referenceInk';
}
```

`measureResidentColor` runs the same two arms `measureResidentAgreement`
does — `VerticesDrawSink` with the rasterizer attached as its observer, and
`GeometryCollector` expanded through `expandInstances` into a second
rasterizer — then walks both `pixels` buffers once:

```dart
  var union = 0, withinTwo = 0, overEight = 0, referenceInk = 0;
  for (var i = 0; i < reference.pixels.length; i++) {
    final a = reference.pixels[i], b = resident.pixels[i];
    if (a != 0) referenceInk++;
    if (a == 0 && b == 0) continue;
    union++;
    var worst = 0;
    for (var shift = 0; shift < 32; shift += 8) {
      final d = (((a >> shift) & 0xFF) - ((b >> shift) & 0xFF)).abs();
      if (d > worst) worst = d;
    }
    if (worst <= 2) withinTwo++;
    if (worst > 8) overEight++;
  }
```

`debugTintResident` adds its argument to the resident arm's every written
colour before rasterisation — **test-only, and it must never appear in
`lib/`**, exactly as `TriangleRasterizer.debugDisableDashTest` is documented.

- [ ] **Step 4: Rewrite the two doc paragraphs that are now false**

`gpu_comparison.dart`'s header says colour and order are unmeasurable.
Replace both paragraphs, keeping their history:

```dart
/// **Colour agreement was unmeasurable until Plan D, and the limitation is
/// recorded rather than deleted.** Until [measureResidentColor] existed this
/// file could only compare coverage, so [ResidentAgreement.differing] and
/// [ResidentAgreement.overEight] were always the same number and neither
/// measured colour. That is still true of [ResidentAgreement] itself --
/// it is a coverage instrument and stays one. [ResidentColorAgreement] is
/// the per-channel measurement, and it is what spec criterion 1's first
/// clause is gated by.
///
/// **Draw order likewise.** Coverage cannot see a permutation that preserves
/// the union of footprints, which is every permutation of strokes. It can be
/// seen in colour, and only once the corpus contains a fill: a large opaque
/// shape drawn over a stroke changes that stroke's pixels' colour without
/// changing whether they are inked. `test/gpu/fill_order_test.dart` is the
/// gate; this instrument is what makes it possible.
```

- [ ] **Step 5: Run and commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git add test/support/gpu_comparison.dart test/gpu/resident_pixel_differential_test.dart
git commit -m "test(gpu): the pixel instrument compares colour, not only coverage"
```

---

### Task 7: The fill corpus in the pixel gate, and spec criterion 4

**Files:**
- Modify: `test/gpu/resident_pixel_differential_test.dart`
- Create: `test/gpu/fill_order_test.dart`
- Modify: `test/gpu/collector_differential_test.dart`

**Interfaces:**
- Consumes: `fillFixture()` (Task 4), `measureResidentColor` and its
  `permute` (Task 6), `kKindFill`.

**Spec criterion 4, verbatim:** *"Submitting the buffer out of walk order
changes the rendering on the fill-overlap corpus, and the test asserts it
does."* This is the criterion no earlier plan could write a failing case for.

- [ ] **Step 1: Write the failing tests**

`test/gpu/fill_order_test.dart`:

```dart
/// Spec criterion 4: emission order is the drawing, and a permutation of the
/// buffer is a different picture.
///
/// **This file exists because of fills.** A permutation of strokes preserves
/// the union of covered pixels, so the coverage instrument cannot see it --
/// `gpu_comparison.dart` says so. A fill covers a stroke, so reordering the
/// two changes the colour of every pixel they share. Without a fill in the
/// corpus this whole file passes vacuously, which is why the first test
/// below asserts the corpus's own overlap before the second asserts the
/// permutation changes it.
void main() {
  test('the fill corpus really does have a stroke drawn over a fill', () {
    final c = collectFillFixture();
    final data = c.data;
    var lastFill = -1, strokeAfterFill = -1;
    for (var i = 0; i < c.instanceCount; i++) {
      final kind = data[i * kFloatsPerInstance + InstanceFieldOffset.kind];
      if (kind == kKindFill) lastFill = i;
      if (kind == kKindStroke && lastFill >= 0 && strokeAfterFill < 0) {
        strokeAfterFill = i;
      }
    }
    expect(lastFill, greaterThanOrEqualTo(0), reason: 'no fill was collected');
    expect(strokeAfterFill, greaterThan(lastFill),
        reason: 'no stroke is emitted after a fill, so no permutation of '
            'this corpus could change a pixel and criterion 4 would pass '
            'vacuously');
  });

  test('submitting the buffer out of walk order changes the rendering', () {
    // In walk order the higher-handle stroke is drawn after the fill and is
    // visible over it. Sorted by kind -- which is what a separate pipeline
    // per kind would submit -- every fill is drawn last and covers it.
    final inOrder = renderFillFixture();
    final byKind = renderFillFixture(permute: sortByKind);

    final differing = countDifferingPixels(inOrder, byKind);
    expect(differing, greaterThan(200),
        reason: 'a permutation that changed no pixel would mean this gate '
            'cannot fail, whatever it reads');
  });

  test('the resident arm matches the reference in walk order and only there',
      () {
    final ordered = measureResidentColor(paintFillFixture,
        size: _size, devicePixelRatio: _dpr, pixelsPerPaperMm: _ppmm);
    expect(ordered.withinTwoFraction, greaterThanOrEqualTo(0.995),
        reason: ordered.toString());

    final permuted = measureResidentColor(paintFillFixture,
        size: _size,
        devicePixelRatio: _dpr,
        pixelsPerPaperMm: _ppmm,
        permute: sortByKind);
    expect(permuted.withinTwoFraction, lessThan(0.995),
        reason: 'if a kind-sorted buffer still matched the reference, this '
            'backend would have no order to preserve and the single-draw-call '
            'design would be unnecessary: ${permuted.toString()}');
  });
}
```

`sortByKind` returns a stable permutation of instance indices ordered by the
record's `kind` slot — the order three pipelines would submit in. Write it in
this file; it is a test-only ordering and must never appear in `lib/`.

Add to `resident_pixel_differential_test.dart`:

```dart
  test('the fill corpus agrees per channel', () {
    final r = measureResidentColor(paintFillFixture,
        size: _size, devicePixelRatio: _dpr, pixelsPerPaperMm: _ppmm);
    expect(r.withinTwoFraction, greaterThanOrEqualTo(0.995), reason: r.toString());
    expect(r.overEight, 0, reason: r.toString());
    expect(r.referenceInk, greaterThan(5000), reason: r.toString());
  });
```

And to `collector_differential_test.dart`, extend the existing record-level
walk to the fill fixture: every instance's `kind`, `argb` and three points
must match the reference's triangle stream, in order.

**A fill's colour is gated here as well as in the pixel gate, and the reason
belongs in the test's comment.** Only the resident arm has `_coveredArgb`
within reach of a fill — the reference passes `style.argb` straight through
(`vertices_draw_sink.dart:752-757`) — so a faded fill is a real difference
the colour instrument would also see. The record-level assertion is kept
because it names the wrong *value*, where the pixel gate only reports a
percentage.

- [ ] **Step 2: Run and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/fill_order_test.dart
```
Expected: compile failure first, then a real failure if the corpus's overlap
is too small — which is a corpus defect, and Task 4's guard is where it gets
fixed, not here.

- [ ] **Step 3: Implement the helpers**

`collectFillFixture`, `renderFillFixture`, `paintFillFixture` and
`countDifferingPixels` go in `test/support/gpu_comparison.dart` beside the
measurement, so `fill_order_test.dart` holds assertions and nothing else.
`paintFillFixture(DrawSink sink)` paints `fillFixture()` through
`DraftPainter` at the fitted camera — the fills only exist through the painter,
which is what resolves a fill entity to its boundary's triangulation.

- [ ] **Step 4: Run**

```sh
cd packages/jet_cad_2d_flutter && flutter test
```
Expected: PASS.

- [ ] **Step 5: Commit**

```sh
git status --short
git add test/gpu/fill_order_test.dart test/gpu/resident_pixel_differential_test.dart test/gpu/collector_differential_test.dart test/support/gpu_comparison.dart
git commit -m "test(gpu): emission order is the drawing, and a fill proves it"
```

---

### Task 8: Mutation testing

**Files:**
- Create: `docs/superpowers/notes/plan-d-mutation-log.md`

**Every mutation is fired, one at a time, from a `cp` backup, and restored
from that backup.** Never `git checkout --`.

| id | mutation | must fire |
|---|---|---|
| M-D1 | `fillPolygon` writes `_coveredArgb(style.argb, ...)` instead of `style.argb` | `geometry_collector_test.dart` — *a fill keeps its own colour on a hairline layer* |
| M-D2 | `fillCircle` writes `_coveredArgb(...)` | the same, extended to the fan |
| M-D3 | the shader's fill branch reads `half_width` (expand each corner outward) | `instance_expander_test.dart` — *a fill is not expanded by a half-width* |
| M-D4 | the fill branch folds `M` onto `p2` instead of `p1` | *one degenerate triangle* — the second triangle gains area |
| M-D5 | the point branch stays `else` and the fill branch is added before it | *a point is still a point* |
| M-D6 | `fillCircle` fans at `_flattenSteps(deviceRadius, theta) + 1` | *the same step count as its own outline* |
| M-D7 | `fillPolygon` walks the triangulation backwards | *in triangulation order* |
| M-D8 | `fillPolygon` drops zero-area triangles | *a degenerate triangle is written, not dropped* |
| M-D9 | the collector sorts the buffer by kind before `data` returns | `fill_order_test.dart` — *matches the reference in walk order and only there* |
| M-D10 | `writeFill` leaves `dashPeriod` unwritten | `instance_record_test.dart` — the garbage pre-fill survives |
| M-D11 | `writeFill` writes `halfWidth: 1` | *a fill record carries three corners, no width* |
| M-D12 | `fillCircle`'s fan starts at angle `2π/steps` rather than 0 | *the fan walks the rim in ascending angle* |

- [ ] **Step 1: Fire each mutation and record what died**

For each row:

```sh
cd packages/jet_cad_2d_flutter
cp lib/src/gpu/geometry_collector.dart /tmp/plan-d-backup.dart
# edit, then:
flutter test 2>&1 | tail -20
cp /tmp/plan-d-backup.dart lib/src/gpu/geometry_collector.dart
```

Paste the **actual failure line** for each — the test name and the
`Expected:`/`Actual:` pair — into the log. A mutation that does not fire is
recorded as a survivor with an explanation, not quietly dropped, and a
survivor that reveals a missing test gets the test written in this task.

- [ ] **Step 2: Write the log**

`docs/superpowers/notes/plan-d-mutation-log.md`, one section per mutation:
the diff applied, the command run, the output pasted verbatim, the verdict.

- [ ] **Step 3: Commit**

```sh
git add docs/superpowers/notes/plan-d-mutation-log.md
git commit -m "docs: Plan D's mutation log"
```

---

### Task 9: The device run, the results note, and everything that says what this backend does

**Files:**
- Modify: `apps/dev_harness_2d/lib/gpu_arm.dart`
- Create: `docs/superpowers/notes/2026-09-01-plan-d-results.md`
- Modify: `STATUS.md`

- [ ] **Step 1: The harness corpus grows fills**

The spike arm draws strokes only. Add filled regions in the same proportion
the spec's corpus implies, so the window shows a drawing with rooms in it and
the buffer measurement includes them. Keep the existing
`--dart-define` knobs; add `SPIKE_FILLS` with a default that leaves today's
numbers reproducible when it is zero.

- [ ] **Step 2: Measure the buffer**

At 10,000 entities, report: instance count by kind, total bytes, and the
figure against the **8 MB** budget. Plan C measured 6.41 MB at 105,076
instances; the delta this plan adds is the deliverable of this step. **If it
exceeds 8 MB, record a miss with its number** — the threshold does not move.

- [ ] **Step 3: Run the harness on macOS, in profile, with Low Power Mode OFF**

```sh
cd apps/dev_harness_2d
flutter run -d macos --profile --dart-define=RUN_GPU_SPIKE=true \
  --dart-define=ENTITIES=10000 --dart-define=SPIKE_DEFS=20 \
  --dart-define=SPIKE_INSTANCES=150 --dart-define=SPIKE_FRAMES=30 \
  --dart-define=SPIKE_REPEATS=3
```

**Confirm Low Power Mode is off before the run and say so in the note.** Plan
C's device run was contaminated by it and every timing in that note carries
the caveat.

- [ ] **Step 4: Look at the window, and write down what you saw**

Plan D's five checks:

1. a filled region is **filled**, not outlined and hollow;
2. the higher-handle stroke crossing it is **visible over** the fill, not
   hidden under it;
3. a filled circle's fill reaches exactly to its own boundary stroke at every
   zoom — no rim of background between them, no fill spilling past;
4. a fill on a hairline layer is **not faded**;
5. a translucent fill shows what is under it.

**Plan B's four and Plan C's five are still owed** and one run discharges all
fourteen. List them in the note as discharged or still owed, per what was
actually seen.

- [ ] **Step 5: Write the results note**

`docs/superpowers/notes/2026-09-01-plan-d-results.md`, following Plan C's
note: the criterion table with PASS/MISS per row and the measured number
beside each, the mutation summary, what the plan's own premises measured
false, and the device-run conditions. **A miss is recorded as a miss.**

- [ ] **Step 6: Rewrite STATUS.md's head**

Plan D's state, the resume point, and the criterion-11 debt in whatever state
Step 4 left it.

- [ ] **Step 7: Both gates and commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../../apps/dev_harness_2d && flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git commit -m "docs: Plan D's results, and what the window showed"
```

---

## Exit gate

Pre-committed. Thresholds are not moved to make a criterion pass; a miss is
recorded as a miss with its number.

1. **Record-level differential:** for the fill corpus, the collector's
   instance stream and `VerticesDrawSink`'s triangle stream agree instance for
   instance on `kind`, `argb` and all three points. **Exact, not a budget.**
2. **Pixel differential, colour:** per-channel difference ≤ 2 on ≥ 99.5% of
   the union, ≤ 8 on the rest, on the fill corpus and on Plan B's stroke
   corpus both.
3. **Anti-vacuity:** `referenceInk > 5000` on every measured corpus, and the
   colour instrument's own control arm (`debugTintResident`) reads below the
   gate.
4. **Spec criterion 4:** a kind-sorted buffer changes more than 200 pixels
   against the walk-ordered one, and the resident arm matches the reference in
   walk order and **fails to** under the permutation.
5. **`skippedOps` counts text alone** on the fill corpus.
6. **Resident geometry ≤ 8 MB** at 10,000 entities with fills, measured.
7. **All twelve mutations fire**, each with pasted output; survivors declared
   with a reason.
8. **A human looks at the window** and reports Plan D's five checks — and
   Plan B's four and Plan C's five, still owed.
9. Every gate green in `packages/jet_cad_2d_flutter`, `packages/jet_cad_2d`
   and `apps/dev_harness_2d`.

---

## Self-review

**Spec coverage.** The spec's "Fills" section is Tasks 2, 3 and 5;
`fillPolygon` pre-triangulated (Task 2), `fillCircle` fanned at its outline's
step count (Task 3). "One buffer, one kind tag, one draw call" is Ruling D1
and Task 7. The `_coveredArgb` exclusion is Ruling D3, Tasks 2, 3 and M-D1/2.
Criterion 4 is Task 7. Criterion 1's per-channel clause is Task 6 — the spec
requirement no plan had gated. Criterion 6's 8 MB is Task 9. **Not covered by
this plan, deliberately:** text (Plan E), the rebuild triggers and the
watermark (Plan F), web (Plan G), and the `DraftCanvas` widget path, which
still renders `residentGpu` as `vertices` and needs Plan F's triggers.

**Placeholder scan.** No "TBD", no "handle edge cases", no "similar to Task
N". Two steps name work whose exact shape depends on a measurement rather than
on a decision — Task 9's harness fill proportion and Task 4's fallback to
`putTriangles` if `AddRegionCommand` does not materialise a triangulation —
and both state the test that decides it.

**Type consistency.** `writeFill` is declared once (Task 1) and called with
the same six coordinates and one `argb` in Tasks 2 and 3. `kKindFill` is `3`
everywhere. `measureResidentColor` and `ResidentColorAgreement` are declared
in Task 6 and used with the same signature in Task 7. `ResolvedStyle` carries
all four required named arguments in every literal in this document.
