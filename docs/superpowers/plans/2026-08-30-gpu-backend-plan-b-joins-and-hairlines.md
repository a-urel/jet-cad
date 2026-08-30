# GPU backend, Plan B — joins, points and the hairline alpha

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The resident backend draws a stroked drawing the way
`VerticesDrawSink` draws it — mitred and bevelled joins, the seam join that
closes a circle, `point()` as a square, and the sub-pixel alpha fade — with
every one of those decisions made in the **vertex shader, at the live scale**,
so none of them thickens or distorts under zoom.

**Architecture:** The instance record grows from ten floats to twelve and gains
two kinds beside `kKindStroke`: `kKindJoin`, carrying a corner's three points,
and `kKindPoint`, carrying one. The collector grows the run state machine
`VerticesDrawSink` already has, so a join is emitted **before** its segment and
the seam join **after** the closing one, and it grows `circle()` and `arc()`,
which are the only ops that can reach a closed run. The vertex shader branches
three ways on the kind tag and builds the wedge and the square itself, in
device pixels, from the same arithmetic `_emitJoin` uses. A new pure-Dart
**expander** reproduces that shader statement for statement so the whole of it
is gated by `flutter test` and by a pixel differential against the reference
sink, neither of which can reach a GPU.

**Tech Stack:** Dart, Flutter 3.47.1, `flutter_scene` 0.23.0 (for its internal
`flutter_gpu` shim only), `impellerc` for the shader bundle, `flutter_test`.

**Spec:** [docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md](../specs/2026-08-29-gpu-resident-render-backend-design.md)
(revision 4). Read it before Task 2; this plan argues from it.

**Predecessor:** [Plan A](2026-08-29-gpu-backend-plan-a-seam-and-strokes.md),
merged at `cd5bc98`. Its ledger, its twenty-six rulings and its nine task
reports are at
[docs/superpowers/ledgers/2026-08-29-gpu-backend-plan-a-seam-and-strokes/](../ledgers/2026-08-29-gpu-backend-plan-a-seam-and-strokes/).
**Read `progress.md`'s Task 6 and Task 8 entries before Task 3 of this plan** —
they are the two rulings this plan discharges.

**Reference implementation:** `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart`.
It is not a model to copy loosely; it is the oracle every gate in this plan
compares against, line by line. Where this plan quotes it, the quote is the
requirement.

---

## Where Plan B sits

| plan | delivers | state |
|---|---|---|
| A | the facade, the enum, the collector and buffer for **stroked polylines**, one draw call, the ordering and differential gates, the fallback | **merged** `cd5bc98` |
| **B (this one)** | **joins, `point()`, `circle()`/`arc()`, and the `_coveredArgb` hairline alpha** | this plan |
| C | dashes in the shader | |
| D | fills | |
| E | the text split — *N* text ops, *N+1* draw calls | |
| F | the rebuild triggers, the reference scale and the watermark | |
| G | web: CanvasKit and Skwasm | |

**Plan B's exit is not the spec's exit gate.** It closes four of the spec's
fourteen pre-committed mutations and establishes the pixel-differential
instrument spec criterion 1 needs. Criteria 6-9, 11, 12 and 13 belong to later
plans.

### Three scope rulings, made here rather than left to an implementer

**Ruling B1 — `circle()` and `arc()` are in scope, and they are not a
smuggled extra.** The spec requires the seam join and states that it is
*"reachable only from `circle()`, since the painter passes `closed: false` at
every polyline site"* — and the spec's own mutation list requires *"skip the
seam join → the circle-notch test fails"*. There is no circle without
`circle()`. Collecting them also turns on the **general-affine residual** path
(`draft_painter.dart:568`), which Plan A's transposition test was written to
guard and which no Plan A fixture could reach; the Plan A ledger records that
at Task 8. Chord counts are computed with the reference's own `_flattenSteps`
against the residual's scale, which is what freezes them at the reference scale
the day Plan F introduces one — no change is needed here for that.
**Cost if wrong:** Plan B ships more than the roadmap line says, and the seam
join has no witness anywhere.

**Ruling B2 — caps are butt caps, so Plan B emits no cap geometry, and it
proves that rather than assuming it.** The reference states it outright:
*"An open run gets butt caps, which is to say nothing at all"*
(`vertices_draw_sink.dart`, `_endRun`'s doc). `ResolvedStyle` carries no cap
style, so no other cap is reachable from the document model. The spec's
*"Caps are a per-instance flag on a stroke"* is a provision for a cap style
that does not exist yet, and adding the flag now would be an untestable field.
**Plan B instead pins the absence**: Task 4's instance-count test asserts an
open run produces exactly *segments + interior joins* instances and nothing
more, which goes red the day somebody adds cap geometry without a cap style to
justify it. **Consequence to carry into the spec's exit gate:** criterion 8's
corpus requirement *"containing … joins, caps …"* is satisfied **vacuously** on
the caps term. That is recorded in Task 11's results note, not smoothed over.
**Cost if wrong:** a cap style arrives later and its geometry has to be added
against a test that currently forbids it — a one-line change to a named
assertion, not a redesign.

**Ruling B3 — antialiasing is NOT Plan B's, and `cad_stroke.frag`'s comment
saying it is gets corrected.** That comment (*"Antialiasing is Plan B's"*) was
written in Plan A Task 4 and contradicts the gate. Spec criterion 1 is a pixel
differential **against `VerticesDrawSink`**, which draws hard-edged triangles:
`flush()` submits `Vertices.raw` through `drawVertices` with `BlendMode.dst`
and per-vertex colours, and the class has no antialiasing path at all — the
word does not appear in the file. At the one-to-two device-pixel stroke widths
this corpus draws, edge pixels are most of the ink, so a fragment coverage fade
would differ from the reference by up to 255 per channel on most inked pixels
and blow criterion 1 outright. Antialiasing becomes possible only when
something other than the reference sink is the oracle. **Cost if wrong:**
the resident arm stays hard-edged one plan longer than the spec's budget
discussion assumed, which is visible as sharper strokes and costs no criterion.

---

## Global Constraints

Copied verbatim from `CLAUDE.md`, the spec and Plan A. Every task's
requirements implicitly include this section.

- **The frame path allocates nothing per entity in steady state, and O(1) per
  flush.**
- **Draw order is emission order** — *not* "ascending handle value". **Never
  sort the buffer.** Within an entity the order is also fixed: the join comes
  **before** its segment (`vertices_draw_sink.dart`, `_runTo`'s doc: *"at a
  corner the ink nearer the start of the run is written first"*) and the seam
  join comes **last**, after the closing segment.
- **Geometric decisions use `Tolerance`; stored value comparisons are exact
  `==`.**
- **Never commit `analysis_options.yaml`** — `flutter pub get` rewrites three of
  them in this workspace. Check `git status` before every commit and
  `git checkout --` them.
- **Never synthesize test output.** Run the command, paste what it printed,
  **including the exit code**. `dart format --set-exit-if-changed` printing
  `(1 changed)` **is** a failure even though the line looks informational;
  Plan A lost a round to that misreading.
- **Before firing a mutation, back the file up with `cp`, and restore from that
  copy.** Never `git checkout --` a file to revert a mutation: Plan A Task 5
  did, and wiped an entire round of uncommitted fix work.
- Code, comments and commit messages in English.
- **`packages/jet_cad_2d` is untouched by this plan.** Everything lives in
  `packages/jet_cad_2d_flutter` and `apps/dev_harness_2d`.
- Shaders are authored so `impellerc` can emit an **OpenGL ES 100** stage.
  **No bitwise operators and no integer attributes** — colour is four floats
  and the kind tag is a float compared with `<`. **Every declared attribute
  must be read by something the optimizer cannot fold away**, or `impellerc`
  fails reflection with *"Could not complete reflection on generated shader"*
  — Plan A Task 4 bisected that against this exact binary.
- **`_coveredArgb` must never reach a fill.** The reference bypasses it in
  `fillPolygon` and `fillCircle` deliberately, because *"routing a fill through
  `_coveredArgb` would fade a filled room on a hairline layer"*. Plan D
  inherits that constraint; Plan B must not make it harder to honour.
- Every task ends green:
  ```sh
  cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
  ```
  Tasks 1 and 11 additionally run the harness gate:
  ```sh
  cd apps/dev_harness_2d && flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
  ```

## File structure

| file | responsibility |
|---|---|
| `apps/dev_harness_2d/lib/gpu_arm.dart` | **create** — the harness GPU arm, moved out of `main.dart` (Task 1) |
| `apps/dev_harness_2d/lib/main.dart` | **modify** — loses the arm, keeps the wiring |
| `lib/src/gpu/instance_record.dart` | **modify** — twelve floats, three kinds, three writers |
| `lib/src/gpu/geometry_collector.dart` | **modify** — the run state machine, joins, the seam, `circle`/`arc`, `point`, `_coveredArgb` |
| `lib/src/gpu/resident_geometry.dart` | **modify** — the corner buffer gains `join_weight`; the vertex layout gains `p2` |
| `lib/src/gpu/gpu_draw_backend.dart` | **modify** — one line, `setCullMode(none)` |
| `shaders/cad_stroke.vert` | **modify** — three-way kind dispatch, the wedge, the square |
| `shaders/cad_stroke.frag` | **modify** — comment only (Ruling B3) |
| `assets/shaders/cad.shaderbundle` | regenerated, committed |
| `test/support/instance_expander.dart` | **create** — the vertex shader, in Dart, for the suite |
| `test/support/gpu_comparison.dart` | **create** — collector-vs-sink pixel agreement through `TriangleRasterizer` |
| `test/gpu/*_test.dart` | **modify/create** — per task |

All paths under `lib/`, `shaders/`, `test/` and `assets/` are relative to
`packages/jet_cad_2d_flutter/`.

---

### Task 1: The harness GPU arm moves out of `main.dart`

**Files:**
- Create: `apps/dev_harness_2d/lib/gpu_arm.dart`
- Modify: `apps/dev_harness_2d/lib/main.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: nothing other tasks depend on. This task exists on its own.

`STATUS.md`'s "Resume here" records this as owed and says where it came from:
Plan A's whole-branch review called the inlined arm *"a real inconsistency with
zero correctness content"* and said to move it **as a standalone commit at the
start of Plan B**. The same app keeps the widget spike's arm in sibling files
(`widget_arm.dart`, `widget_arm_rig.dart`), so `main.dart` carrying 534 lines of
GPU arm is the odd one out.

**This is a pure move. No behaviour changes, and the review of this task is
exactly that claim.**

- [ ] **Step 1: Find the arm's boundaries**

```bash
cd apps/dev_harness_2d
grep -n 'RUN_GPU_SPIKE\|GSPIKE\|GeometryCollector\|ResidentGeometry\|GpuDrawBackend' lib/main.dart
wc -l lib/main.dart
```

Record the line ranges in the report. The arm is everything reachable only from
the `RUN_GPU_SPIKE` entry point plus the types above; the camera script, the
corpus builder (`spikeDocument()`) and the frame-timing log are **shared** with
the other arms and stay in `main.dart`.

- [ ] **Step 2: Capture the before-picture**

```bash
cd apps/dev_harness_2d && flutter test --concurrency=1 2>&1 | tail -5
```

Paste the count and exit code into the report. It must be identical after the
move.

- [ ] **Step 3: Move the arm**

Create `lib/gpu_arm.dart` with the moved declarations and the imports they
need. In `lib/main.dart`, delete them and add `import 'gpu_arm.dart';`.

Anything the arm needs from `main.dart` (the corpus builder, the camera script,
the timing log) is imported the other way, exactly as `widget_arm.dart` already
does — read that file first and match its import direction rather than
inventing one. If a private (`_`-prefixed) declaration in `main.dart` is needed
by the moved code, rename it without the underscore rather than duplicating it,
and say so in the report.

- [ ] **Step 4: Prove it is a move, not a rewrite**

```bash
cd /Users/ahmeturel/Projects/oss/jet-cad
git diff --stat
```

Insertions into `gpu_arm.dart` and deletions from `main.dart` should be within
a few lines of each other. A large asymmetry means something was rewritten;
report it explicitly if so, with what and why.

- [ ] **Step 5: Gate**

```bash
cd apps/dev_harness_2d && flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
echo "exit=$?"
cd ../../packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
echo "exit=$?"
```

- [ ] **Step 6: Commit**

```bash
git add apps/dev_harness_2d/lib/gpu_arm.dart apps/dev_harness_2d/lib/main.dart
git commit -m "refactor(harness): the GPU arm moves out of main.dart into its own file"
```

---

### Task 2: The record grows to twelve floats and three kinds

**Files:**
- Modify: `lib/src/gpu/instance_record.dart`
- Modify: `lib/src/gpu/resident_geometry.dart`
- Test: `test/gpu/instance_record_test.dart`, `test/gpu/resident_geometry_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `const int kFloatsPerInstance = 12`; `const double kKindStroke = 0`,
  `kKindJoin = 1`, `kKindPoint = 2`; `abstract final class InstanceFieldOffset`
  with `kind, x0, y0, x1, y1, x2, y2, halfWidth, r, g, b, a`;
  `void writeStroke(Float32List, int, {double x0, y0, x1, y1, halfWidth, int argb})`;
  `void writeJoin(Float32List, int, {double vx, vy, prevX, prevY, nextX, nextY, halfWidth, int argb})`;
  `void writePoint(Float32List, int, {double x, y, halfWidth, int argb})`;
  `ResidentGeometry.kCornerVertices` at **six floats per vertex**;
  `ResidentGeometry.kInstanceVertexLayout` (renamed from `kStrokeVertexLayout`).

**Why twelve and not ten.** A join needs a vertex and its two neighbours — six
coordinates — where a stroke needs four. The two extra floats are 8 bytes per
instance; Task 11 prices the total against the spec's 8 MB budget.

**Why the neighbours and not two unit directions.** A unit direction in
collection space is only a unit direction in device space under a conformal
transform, and nothing guarantees the camera is one. The reference computes its
directions in **device** space, after the residual (`_runTo`: `dx = x -
_runPrevX` on already-transformed points). Storing the three points and
normalising in the shader **after** the mvp puts both arms in the same space
by construction, and it is what the stroke branch already does.

- [ ] **Step 1: Write the failing test**

Replace `test/gpu/instance_record_test.dart` with:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

void main() {
  test('the field offsets are contiguous and cover the stride', () {
    // The offsets are read by three independent consumers -- the writers
    // below, `ResidentGeometry.kInstanceVertexLayout`, and (as a fourth,
    // uncheckable copy) `cad_stroke.vert`'s attribute list. A gap or an
    // overlap here is silent on every one of them until a device run.
    const offsets = <int>[
      InstanceFieldOffset.kind,
      InstanceFieldOffset.x0,
      InstanceFieldOffset.y0,
      InstanceFieldOffset.x1,
      InstanceFieldOffset.y1,
      InstanceFieldOffset.x2,
      InstanceFieldOffset.y2,
      InstanceFieldOffset.halfWidth,
      InstanceFieldOffset.r,
      InstanceFieldOffset.g,
      InstanceFieldOffset.b,
      InstanceFieldOffset.a,
    ];
    expect(offsets, List<int>.generate(kFloatsPerInstance, (i) => i),
        reason: 'offsets must be 0..kFloatsPerInstance-1 with no gaps');
  });

  test('the three kind tags are distinct and ordered for the shader', () {
    // `cad_stroke.vert` dispatches with `kind < 0.5` then `kind < 1.5`, so
    // the tags must be 0, 1, 2 in that order -- not merely distinct.
    expect(kKindStroke, 0.0);
    expect(kKindJoin, 1.0);
    expect(kKindPoint, 2.0);
  });

  test('writeStroke fills every slot and leaves p2 zeroed', () {
    final b = Float32List(kFloatsPerInstance * 2);
    // Index 1, not 0: writing at a non-zero index is the only way to catch a
    // writer that ignores its `index` argument, and the zero-fill of a fresh
    // Float32List would hide it at index 0.
    writeStroke(b, 1,
        x0: 3, y0: -4, x1: 11, y1: 6, halfWidth: 1.25, argb: 0x80402010);
    final r = b.sublist(kFloatsPerInstance);
    expect(r[InstanceFieldOffset.kind], kKindStroke);
    expect(r[InstanceFieldOffset.x0], 3);
    expect(r[InstanceFieldOffset.y0], -4);
    expect(r[InstanceFieldOffset.x1], 11);
    expect(r[InstanceFieldOffset.y1], 6);
    expect(r[InstanceFieldOffset.x2], 0);
    expect(r[InstanceFieldOffset.y2], 0);
    expect(r[InstanceFieldOffset.halfWidth], 1.25);
    expect(r[InstanceFieldOffset.r], closeTo(0x40 / 255.0, 1e-6));
    expect(r[InstanceFieldOffset.g], closeTo(0x20 / 255.0, 1e-6));
    expect(r[InstanceFieldOffset.b], closeTo(0x10 / 255.0, 1e-6));
    expect(r[InstanceFieldOffset.a], closeTo(0x80 / 255.0, 1e-6));
    // The first record is untouched: a writer that ignored `index` would
    // have written here instead.
    expect(b.sublist(0, kFloatsPerInstance).every((v) => v == 0), isTrue);
  });

  test('writeJoin puts the vertex first and the neighbours after it', () {
    // Order matters and is not symmetric: the shader takes the incoming
    // direction as `p0 - p1` and the outgoing as `p2 - p0`. Swapping p1 and
    // p2 reverses the turn and mirrors the wedge onto the wrong side.
    final b = Float32List(kFloatsPerInstance);
    writeJoin(b, 0,
        vx: 10,
        vy: 20,
        prevX: 4,
        prevY: 20,
        nextX: 10,
        nextY: 33,
        halfWidth: 2,
        argb: 0xFF010203);
    expect(b[InstanceFieldOffset.kind], kKindJoin);
    expect(b[InstanceFieldOffset.x0], 10);
    expect(b[InstanceFieldOffset.y0], 20);
    expect(b[InstanceFieldOffset.x1], 4);
    expect(b[InstanceFieldOffset.y1], 20);
    expect(b[InstanceFieldOffset.x2], 10);
    expect(b[InstanceFieldOffset.y2], 33);
    expect(b[InstanceFieldOffset.halfWidth], 2);
  });

  test('writePoint carries one position and zeroes the unused slots', () {
    final b = Float32List(kFloatsPerInstance);
    writePoint(b, 0, x: -7, y: 2.5, halfWidth: 0.5, argb: 0xFFFFFFFF);
    expect(b[InstanceFieldOffset.kind], kKindPoint);
    expect(b[InstanceFieldOffset.x0], -7);
    expect(b[InstanceFieldOffset.y0], 2.5);
    expect(b[InstanceFieldOffset.x1], 0);
    expect(b[InstanceFieldOffset.y1], 0);
    expect(b[InstanceFieldOffset.x2], 0);
    expect(b[InstanceFieldOffset.y2], 0);
    expect(b[InstanceFieldOffset.halfWidth], 0.5);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd packages/jet_cad_2d_flutter && flutter test test/gpu/instance_record_test.dart
```

Expected: compile errors — `InstanceFieldOffset`, `kKindJoin`, `kKindPoint`,
`writeJoin` and `writePoint` are undefined.

- [ ] **Step 3: Rewrite `instance_record.dart`**

```dart
import 'dart:typed_data';

/// Floats per instance record.
///
/// `[kind, x0, y0, x1, y1, x2, y2, halfWidth, r, g, b, a]`.
///
/// **Twelve floats, and none of them packed, because of the web.** The shader
/// bundle must carry an OpenGL ES 100 stage — `flutter_scene`'s web loader
/// reads `entry.openglEs` and transpiles it to ES 300 — and ES 100 has neither
/// bitwise operators nor integer vertex attributes, so a `uint32` colour could
/// not be unpacked in the shader. 48 bytes per record.
///
/// **Ten became twelve in Plan B**, because a join carries a vertex and both
/// its neighbours where a stroke carries two endpoints. The third point is
/// stored rather than a pair of unit directions: a unit direction is only
/// unit-length after a *conformal* transform, and nothing promises the camera
/// is one. The reference takes its directions in device space, after the
/// residual (`vertices_draw_sink.dart`, `_runTo`), so storing points and
/// normalising in the shader after the mvp puts both arms in the same space
/// by construction instead of by coincidence.
const int kFloatsPerInstance = 12;

/// The kind tag, in slot 0 of every record.
///
/// **One buffer and one draw call carry every kind**, because separate
/// pipelines are separate draw calls and three draw calls submit as "all
/// strokes, then all joins, then all fills" — not walk order.
/// `vertices_draw_sink.dart:41-57` records that defect being shipped and
/// reverted once already, partitioned by colour rather than by kind.
///
/// **The values are 0, 1, 2 and the order is load-bearing**, not merely
/// distinct: `cad_stroke.vert` dispatches with `kind < 0.5` then
/// `kind < 1.5`, because ES 100 has no integer attributes and no `switch` on
/// one. Renumbering these without editing that shader silently draws every
/// join as a stroke.
const double kKindStroke = 0;

/// A corner between two segments. `(x0, y0)` is the vertex, `(x1, y1)` the
/// previous point and `(x2, y2)` the next one; the shader builds the bevel
/// and, where the turn is shallow enough, the miter tip.
const double kKindJoin = 1;

/// A `point()` op: a square of the stroke's own width centred on
/// `(x0, y0)`. `(x1, y1)` and `(x2, y2)` are unused.
///
/// **Not a zero-length capped stroke, and not a tiny horizontal segment
/// either.** The reference draws it as a horizontal segment from `px - half`
/// to `px + half` — but it computes that offset in **device** space, where
/// its residual has already been applied. This record holds *collection*
/// space, and the shader expands `halfWidth` in device pixels after the mvp,
/// so a `± half` baked into `x0`/`x1` here would scale with the camera on one
/// axis while the other stayed fixed: the square would shear under zoom. Its
/// own kind is what keeps both axes in the same space.
const double kKindPoint = 2;

/// The record's field layout, as an offset in **floats** from the record's
/// start — the writers below index by float, not byte.
///
/// **The one place this order is declared for Dart.**
/// `ResidentGeometry.kInstanceVertexLayout` derives its `offsetInBytes`
/// values from these same constants (`* 4`), so reordering a field here moves
/// the writers and the vertex layout together instead of leaving one behind.
/// `cad_stroke.vert`'s attribute list is a third, independent copy — GLSL
/// cannot read a Dart constant — and `test/support/instance_expander.dart` is
/// a fourth. The expander is the one that is *gated*: it reads these same
/// constants, and `test/gpu/expander_differential_test.dart` compares its
/// output against the reference sink, so a drift between this file and the
/// expander goes red in `flutter test`. A drift between either and the GLSL
/// still needs a device run or a hand-check against `impellerc`'s reflection.
abstract final class InstanceFieldOffset {
  static const int kind = 0;
  static const int x0 = 1;
  static const int y0 = 2;
  static const int x1 = 3;
  static const int y1 = 4;
  static const int x2 = 5;
  static const int y2 = 6;
  static const int halfWidth = 7;
  static const int r = 8;
  static const int g = 9;
  static const int b = 10;
  static const int a = 11;
}

/// Writes the four colour slots at record base [o]. [argb] is `0xAARRGGBB`.
void _writeColor(Float32List into, int o, int argb) {
  into[o + InstanceFieldOffset.r] = ((argb >> 16) & 0xFF) / 255.0;
  into[o + InstanceFieldOffset.g] = ((argb >> 8) & 0xFF) / 255.0;
  into[o + InstanceFieldOffset.b] = (argb & 0xFF) / 255.0;
  into[o + InstanceFieldOffset.a] = ((argb >> 24) & 0xFF) / 255.0;
}

/// Writes the stroke record at [index]. [argb] is `0xAARRGGBB`.
void writeStroke(
  Float32List into,
  int index, {
  required double x0,
  required double y0,
  required double x1,
  required double y1,
  required double halfWidth,
  required int argb,
}) {
  final o = index * kFloatsPerInstance;
  into[o + InstanceFieldOffset.kind] = kKindStroke;
  into[o + InstanceFieldOffset.x0] = x0;
  into[o + InstanceFieldOffset.y0] = y0;
  into[o + InstanceFieldOffset.x1] = x1;
  into[o + InstanceFieldOffset.y1] = y1;
  into[o + InstanceFieldOffset.x2] = 0;
  into[o + InstanceFieldOffset.y2] = 0;
  into[o + InstanceFieldOffset.halfWidth] = halfWidth;
  _writeColor(into, o, argb);
}

/// Writes the join record at [index].
///
/// The three points are **not interchangeable**: the shader takes the
/// incoming direction as `vertex - previous` and the outgoing as
/// `next - vertex`, and swapping the neighbours reverses the turn, which
/// puts the wedge on the inside of the corner where there is no notch to
/// fill.
void writeJoin(
  Float32List into,
  int index, {
  required double vx,
  required double vy,
  required double prevX,
  required double prevY,
  required double nextX,
  required double nextY,
  required double halfWidth,
  required int argb,
}) {
  final o = index * kFloatsPerInstance;
  into[o + InstanceFieldOffset.kind] = kKindJoin;
  into[o + InstanceFieldOffset.x0] = vx;
  into[o + InstanceFieldOffset.y0] = vy;
  into[o + InstanceFieldOffset.x1] = prevX;
  into[o + InstanceFieldOffset.y1] = prevY;
  into[o + InstanceFieldOffset.x2] = nextX;
  into[o + InstanceFieldOffset.y2] = nextY;
  into[o + InstanceFieldOffset.halfWidth] = halfWidth;
  _writeColor(into, o, argb);
}

/// Writes the point record at [index].
void writePoint(
  Float32List into,
  int index, {
  required double x,
  required double y,
  required double halfWidth,
  required int argb,
}) {
  final o = index * kFloatsPerInstance;
  into[o + InstanceFieldOffset.kind] = kKindPoint;
  into[o + InstanceFieldOffset.x0] = x;
  into[o + InstanceFieldOffset.y0] = y;
  into[o + InstanceFieldOffset.x1] = 0;
  into[o + InstanceFieldOffset.y1] = 0;
  into[o + InstanceFieldOffset.x2] = 0;
  into[o + InstanceFieldOffset.y2] = 0;
  into[o + InstanceFieldOffset.halfWidth] = halfWidth;
  _writeColor(into, o, argb);
}
```

- [ ] **Step 4: Run the record test**

```bash
cd packages/jet_cad_2d_flutter && flutter test test/gpu/instance_record_test.dart
```

Expected: 4 tests pass. `geometry_collector.dart` and `resident_geometry.dart`
will still fail to compile against `StrokeFieldOffset` — that is Step 5.

- [ ] **Step 5: Update `resident_geometry.dart`**

Three edits, all in that file:

1. Rename `kStrokeVertexLayout` → `kInstanceVertexLayout`, keeping its whole
   doc comment and replacing `StrokeFieldOffset` with `InstanceFieldOffset`
   throughout.
2. Add the `p2` attribute to the instance buffer's attribute list, between
   `p1` and `half_width`:
   ```dart
             gpu.VertexAttribute(
                 name: 'p2',
                 format: gpu.VertexFormat.float32x2,
                 offsetInBytes: InstanceFieldOffset.x2 * 4),
   ```
3. Replace the corner buffer — both `kCornerVertices` and buffer 0's
   descriptor:

```dart
  /// The six per-vertex records: two triangles, not a triangle strip, because
  /// a strip cannot mix kinds and Plans C and D add kinds to this same buffer.
  ///
  /// **Six floats per vertex: `corner.xy` then `join_weight.xyzw`.**
  ///
  /// `corner` is the quad parameterisation Plan A shipped — `x` picks the
  /// endpoint (0 = p0, 1 = p1), `y` picks the side (-1 or +1) — and the
  /// stroke and point branches still read only it.
  ///
  /// `join_weight` exists because the join branch needs **six distinct
  /// vertex roles** and `corner` alone offers only four: `(1,-1)` and `(0,1)`
  /// each appear twice, since the two triangles share the quad's diagonal.
  /// A join's two triangles are the bevel `(V, A, B)` and the miter tip
  /// `(A, M, B)` — four distinct points across six vertices, and the
  /// duplicated corners need *different* roles in each triangle, so they
  /// cannot be told apart by `corner`. The weight vector selects one of
  /// `(V, A, B, M)` per vertex, and the shader reads the position as
  /// `w.x*V + w.y*A + w.z*B + w.w*M` — no float-equality test on an index,
  /// which ES 100 makes unpleasant.
  ///
  /// Triangle 0 is `(V, A, B)` and triangle 1 is `(A, M, B)`. Both wind
  /// **either way** depending on the turn direction, because `_emitJoin`
  /// flips the outer side with the sign of the cross product — which is why
  /// `GpuDrawBackend.render` pins `CullMode.none`.
  ///
  /// `@visibleForTesting`: no test can reach this data through `create`
  /// itself (it runs only with a real GPU context), so it is hoisted here to
  /// be asserted directly by a plain `flutter test`.
  @visibleForTesting
  static const List<double> kCornerVertices = <double>[
    // corner.x corner.y | join_weight V, A, B, M
    0, -1, /*  */ 1, 0, 0, 0, // triangle 0, vertex 0 -> V
    0, 1, /*   */ 0, 1, 0, 0, // triangle 0, vertex 1 -> A
    1, -1, /*  */ 0, 0, 1, 0, // triangle 0, vertex 2 -> B
    1, -1, /*  */ 0, 1, 0, 0, // triangle 1, vertex 0 -> A
    0, 1, /*   */ 0, 0, 0, 1, // triangle 1, vertex 1 -> M
    1, 1, /*   */ 0, 0, 1, 0, // triangle 1, vertex 2 -> B
  ];

  /// Floats per entry in the corner buffer: `corner` (2) + `join_weight` (4).
  static const int kFloatsPerCorner = 6;
```

and buffer 0's descriptor becomes:

```dart
      gpu.VertexBuffer(
          strideInBytes: kFloatsPerCorner * 4,
          attributes: <gpu.VertexAttribute>[
            gpu.VertexAttribute(
                name: 'corner',
                format: gpu.VertexFormat.float32x2,
                offsetInBytes: 0),
            gpu.VertexAttribute(
                name: 'join_weight',
                format: gpu.VertexFormat.float32x4,
                offsetInBytes: 8),
          ]),
```

- [ ] **Step 6: Extend `resident_geometry_test.dart`**

Add these two tests to the existing file (keep everything already there, and
update any assertion that referenced `kStrokeVertexLayout` or a stride of 8):

```dart
  test('the corner buffer is six vertices of six floats', () {
    expect(ResidentGeometry.kCornerVertices.length,
        6 * ResidentGeometry.kFloatsPerCorner);
  });

  test('every join weight selects exactly one of the four points', () {
    // A weight vector that summed to anything but 1 would put the vertex
    // somewhere between two roles, which draws a wedge of the wrong shape
    // rather than failing loudly. A weight vector that was all zeroes would
    // collapse it onto the origin.
    for (var v = 0; v < 6; v++) {
      final base = v * ResidentGeometry.kFloatsPerCorner + 2;
      final w = ResidentGeometry.kCornerVertices.sublist(base, base + 4);
      expect(w.reduce((a, b) => a + b), 1.0, reason: 'vertex $v weights $w');
      expect(w.where((x) => x == 1.0).length, 1, reason: 'vertex $v weights $w');
    }
  });

  test('the two join triangles are (V, A, B) and (A, M, B)', () {
    // Named so a reordering of kCornerVertices is a test failure with the
    // role in the message, not a silently different wedge.
    const v = 0, a = 1, b = 2, m = 3;
    int roleOf(int vertex) {
      final base = vertex * ResidentGeometry.kFloatsPerCorner + 2;
      return ResidentGeometry.kCornerVertices
          .sublist(base, base + 4)
          .indexOf(1.0);
    }

    expect(<int>[roleOf(0), roleOf(1), roleOf(2)], <int>[v, a, b]);
    expect(<int>[roleOf(3), roleOf(4), roleOf(5)], <int>[a, m, b]);
  });
```

- [ ] **Step 7: Pin cull mode**

In `lib/src/gpu/gpu_draw_backend.dart`, immediately after
`pass.setPrimitiveType(gpu.PrimitiveType.triangle);`:

```dart
    // **Load-bearing from Plan B on, and it was not before.** A stroke quad's
    // winding is invariant under reversing the segment — the direction and
    // the normal flip together — so Plan A never had to think about this. A
    // join's is not: `_emitJoin` picks the outer side with
    // `s = cross > 0 ? -half : half` (`vertices_draw_sink.dart`), so a left
    // turn and a right turn wind opposite ways and any culling would drop
    // half the corners in a drawing. `CullMode.none` is also the enum's zero
    // value, so this is pinning a default rather than changing behaviour —
    // pinned because a default that becomes load-bearing and stays implicit
    // is the kind of thing that changes under you in a package upgrade.
    pass.setCullMode(gpu.CullMode.none);
```

- [ ] **Step 8: Update the collector's references and gate**

`geometry_collector.dart` references `StrokeFieldOffset` only indirectly
through `writeStroke`, so it should compile unchanged. Run the gate:

```bash
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
echo "exit=$?"
```

Fix whatever the record widening broke in the existing tests — notably any
assertion on `kFloatsPerInstance`, on a record's slot indices, or on
`byteLengthFor`. **Report every such change and why**: a test that had to be
edited to keep passing is either correctly following the widening or was
asserting the old layout by accident, and the reviewer needs to be able to
tell which.

- [ ] **Step 9: Commit**

```bash
git add packages/jet_cad_2d_flutter/lib/src/gpu packages/jet_cad_2d_flutter/test/gpu
git commit -m "feat(gpu): the instance record carries three kinds and twelve floats"
```

---

### Task 3: `_coveredArgb` — the hairline fade

**Files:**
- Modify: `lib/src/gpu/geometry_collector.dart`
- Test: `test/gpu/geometry_collector_test.dart`

**Interfaces:**
- Consumes: `writeStroke` (Task 2).
- Produces: `GeometryCollector` colours now match `VerticesDrawSink`'s
  including alpha, which **Task 9's pixel differential depends on**.

**This discharges a Plan A ruling.** The Plan A ledger, Task 3: *"the collector
writes `style.argb` unmodified while `VerticesDrawSink` fades sub-pixel strokes
through `_coveredArgb` … Plan A's own decomposition assigns the `_coveredArgb`
hairline alpha to Plan B, so the divergence is by design here. It is a
constraint on TASK 8, which compares the two arms: Task 8's fixture must keep
every lineweight above the hairline floor so the arms agree on colour."* That
constraint is lifted by this task, and Task 9's fixture is required to violate
it deliberately.

- [ ] **Step 1: Write the failing test**

Append to `test/gpu/geometry_collector_test.dart`:

```dart
  test('a sub-pixel stroke keeps its pixel and gives up alpha', () {
    // 0.05 mm at 3.7795275590551185 px/mm and dpr 1 is 0.189 device pixels --
    // under the one-pixel floor, so the reference fades it. The collector
    // must fade it by the same factor or the two arms disagree on colour on
    // every hairline layer, which is exactly what Task 9 rasterises.
    const dpr = 1.0;
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: dpr);
    final style = const ResolvedStyle(argb: 0xFF204060, lineweightHundredths: 5);
    c.polyline(Float64List.fromList(<double>[0, 0, 40, 0]), 2, style,
        closed: false);

    final deviceWidth = 5 / 100.0 * kLogicalPixelsPerMm * dpr;
    expect(deviceWidth, lessThan(1.0),
        reason: 'the fixture must actually be sub-pixel or this asserts nothing');
    final coverage = (deviceWidth * 2).clamp(0.0, 1.0);
    final expectedAlpha = (0xFF * coverage).round();

    final r = c.data;
    expect(r[InstanceFieldOffset.a] * 255.0, closeTo(expectedAlpha, 0.51));
    // The colour channels are untouched: `_coveredArgb` gives up alpha, it
    // does not darken. A implementation that multiplied the channels instead
    // would pass an alpha-only assertion.
    expect(r[InstanceFieldOffset.r] * 255.0, closeTo(0x20, 0.51));
    expect(r[InstanceFieldOffset.g] * 255.0, closeTo(0x40, 0.51));
    expect(r[InstanceFieldOffset.b] * 255.0, closeTo(0x60, 0.51));
    // And the width still floors at one device pixel: the fade replaces the
    // missing width, it does not accompany a thinner quad.
    expect(r[InstanceFieldOffset.halfWidth],
        closeTo(GeometryCollector.kMinStrokeDevicePixels / 2, 1e-6));
  });

  test('a stroke at or above one device pixel keeps full alpha', () {
    // The other side of the branch. Without this, deleting the
    // `deviceWidth >= kMinStrokeDevicePixels` guard -- fading *every* stroke
    // -- goes unnoticed.
    const dpr = 2.0;
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: dpr);
    final style =
        const ResolvedStyle(argb: 0xC0204060, lineweightHundredths: 25);
    c.polyline(Float64List.fromList(<double>[0, 0, 40, 0]), 2, style,
        closed: false);
    final deviceWidth = 25 / 100.0 * kLogicalPixelsPerMm * dpr;
    expect(deviceWidth, greaterThan(1.0),
        reason: 'the fixture must actually be above the floor');
    expect(c.data[InstanceFieldOffset.a] * 255.0, closeTo(0xC0, 0.51));
  });

  test('a zero lineweight is the hairline case and keeps full alpha', () {
    // `_coveredArgb`'s first branch: `deviceWidth <= 0` returns argb
    // unchanged. That is deliberate in the reference -- "A width of exactly
    // zero is the hairline case and keeps full alpha -- that is the first
    // branch there, not an omission" -- and a collector that clamped
    // coverage from 0 would draw every hairline entity invisible.
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.polyline(
        Float64List.fromList(<double>[0, 0, 40, 0]),
        2,
        const ResolvedStyle(argb: 0xFF112233, lineweightHundredths: 0),
        closed: false);
    expect(c.data[InstanceFieldOffset.a] * 255.0, closeTo(0xFF, 0.51));
  });
```

The file's existing imports need `import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';`
if it is not already there, and `kLogicalPixelsPerMm` from the package barrel.
If the existing test file uses a different name for the paper scale, use that
one — do not add a second constant.

- [ ] **Step 2: Run it and watch it fail**

```bash
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```

Expected: the first test fails with the alpha reading 255 instead of the faded
value. The other two pass already (the collector writes full alpha
unconditionally today), which is fine — they exist to keep the fix from
overshooting.

- [ ] **Step 3: Implement**

Add to `GeometryCollector`, directly under `_halfWidthFor`:

```dart
  /// The colour a stroke of this width is actually drawn in.
  ///
  /// Mirrors `VerticesDrawSink._coveredArgb`, which mirrors Impeller's
  /// `Geometry::ComputeStrokeAlphaCoverage`. A stroke thinner than one device
  /// pixel keeps its pixel — [_halfWidthFor] floors the width — and gives up
  /// alpha in proportion, so thinning a line fades it out instead of stopping
  /// at one pixel and staying there.
  ///
  /// **A width of exactly zero keeps full alpha.** That is the hairline case,
  /// and it is the first branch rather than an omission — the reference says
  /// so in as many words.
  ///
  /// **This must never reach a fill.** `fillPolygon` and `fillCircle` pass
  /// `style.argb` directly in the reference, because a fill entity's
  /// `ResolvedStyle` still carries a lineweight from the shared column and
  /// *"routing a fill through `_coveredArgb` would fade a filled room on a
  /// hairline layer"*. Plan D adds those two ops; it inherits that rule.
  int _coveredArgb(int argb, int lineweightHundredths) {
    final deviceWidth = lineweightHundredths /
        100.0 *
        pixelsPerPaperMm *
        lineweightScale *
        devicePixelRatio;
    if (!deviceWidth.isFinite ||
        deviceWidth <= 0 ||
        deviceWidth >= kMinStrokeDevicePixels) {
      return argb;
    }
    final coverage = (deviceWidth * 2).clamp(0.0, 1.0);
    final alpha = (((argb >> 24) & 0xFF) * coverage).round();
    return (alpha << 24) | (argb & 0x00FFFFFF);
  }
```

and in `polyline`, replace `style.argb` at both `_emit` call sites with a
hoisted local computed once:

```dart
    final half = _halfWidthFor(style.lineweightHundredths);
    final argb = _coveredArgb(style.argb, style.lineweightHundredths);
```

- [ ] **Step 4: Run the test**

```bash
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```

Expected: all pass.

- [ ] **Step 5: Fire the mutation and record it**

```bash
cd packages/jet_cad_2d_flutter
cp lib/src/gpu/geometry_collector.dart /tmp/gc.bak
# M-B1: drop _coveredArgb from strokes.
#   In `polyline`, change the hoisted `argb` back to `style.argb`.
flutter test test/gpu/geometry_collector_test.dart
cp /tmp/gc.bak lib/src/gpu/geometry_collector.dart
```

Expected: red on `a sub-pixel stroke keeps its pixel and gives up alpha`.
Paste the failure text and the restored-file `git diff --stat` (which must be
empty for that file) into the report.

- [ ] **Step 6: Correct the stale doc**

`geometry_collector.dart`'s `kMinStrokeDevicePixels` doc calls
`VerticesDrawSink.kMinStrokeDevicePixels` *"a private implementation detail"*.
It is public, and Plan A Task 8's fix relies on that by reading it live. The
Plan A ledger carries this as a deferred minor. Fix the sentence.

While in the file, update `skippedOps`' doc: after Tasks 4-6 the skipped set is
`fillPolygon`, `fillCircle` and `text` — not *"arcs, circles, fills, text,
points"*. Write it as the post-Plan-B set and note that this task is landing
ahead of them; Task 6 verifies the sentence is true.

- [ ] **Step 7: Gate and commit**

```bash
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
echo "exit=$?"
git add packages/jet_cad_2d_flutter
git commit -m "feat(gpu): the collector fades sub-pixel strokes the way the reference does"
```

---

### Task 4: Joins — the run state machine and the seam

**Files:**
- Modify: `lib/src/gpu/geometry_collector.dart`
- Test: `test/gpu/geometry_collector_test.dart`

**Interfaces:**
- Consumes: `writeJoin` (Task 2), `_coveredArgb` (Task 3).
- Produces: `GeometryCollector.polyline` emits, per run,
  `join(v_i)` **before** `segment(v_i, v_{i+1})` for every interior vertex, and
  on a closed run the closing segment followed by the seam join **last**.

**The order is the requirement, not an implementation detail.** The reference's
`_runTo` doc: *"The join comes before the segment so the buffer's order is the
drawing's order: at a corner the ink nearer the start of the run is written
first."* And `_endRun` emits the seam join after the closing `_runTo`. One
draw call means buffer order *is* draw order, so a reordering here is a
reordering of the picture.

**The bevel/miter/collinear decision is NOT made here.** It is made in the
shader, in device pixels, from the same arithmetic `_emitJoin` uses. The
collector emits a join instance at **every** interior vertex where both
neighbours exist; a collinear corner reaches the shader and collapses to two
zero-area triangles.

> **Ruling B4 — one implementation of the wedge decision, and it lives in the
> shader.** Deciding collinearity in the collector would put the test in
> `double`, in *collection* space, against a reference that tests it in
> `double` in *device* space — two different spaces and two different
> roundings, disagreeing on exactly the corners that are nearly straight. The
> shader's `float32` device-space test is the one that matches what the
> reference actually does. **The cost is one degenerate instance per collinear
> vertex**, which Task 11 measures on the 10,000-entity corpus and reports
> against the 8 MB budget. **Cost if wrong:** the buffer is larger than it
> needs to be on drawings with many collinear vertices, and the fix is a
> collector-side test added later with the divergence measured first.

- [ ] **Step 1: Write the failing tests**

Append to `test/gpu/geometry_collector_test.dart`:

```dart
  /// Reads the kind tag of instance [i].
  double _kindAt(GeometryCollector c, int i) =>
      c.data[i * kFloatsPerInstance + InstanceFieldOffset.kind];

  test('an open three-point run is join-before-segment, and nothing else', () {
    // Three points, one corner. The reference emits: segment(0,1),
    // join(1), segment(1,2) -- in that order, with the join written before
    // the segment it precedes. Butt caps mean there is nothing at either
    // end (Ruling B2), so the count is exactly 3.
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.polyline(
        Float64List.fromList(<double>[0, 0, 40, 0, 40, 30]),
        3,
        const ResolvedStyle(argb: 0xFF000000, lineweightHundredths: 25),
        closed: false);
    expect(c.instanceCount, 3,
        reason: 'segment, join, segment -- no caps, no trailing join');
    expect(<double>[_kindAt(c, 0), _kindAt(c, 1), _kindAt(c, 2)],
        <double>[kKindStroke, kKindJoin, kKindStroke],
        reason: 'the join is written BEFORE the segment that follows it');
  });

  test('the join carries the corner and both its neighbours', () {
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.polyline(
        Float64List.fromList(<double>[0, 0, 40, 0, 40, 30]),
        3,
        const ResolvedStyle(argb: 0xFF000000, lineweightHundredths: 25),
        closed: false);
    final j = c.data.sublist(kFloatsPerInstance, 2 * kFloatsPerInstance);
    expect(j[InstanceFieldOffset.x0], 40, reason: 'the vertex');
    expect(j[InstanceFieldOffset.y0], 0);
    expect(j[InstanceFieldOffset.x1], 0, reason: 'the previous point');
    expect(j[InstanceFieldOffset.y1], 0);
    expect(j[InstanceFieldOffset.x2], 40, reason: 'the next point');
    expect(j[InstanceFieldOffset.y2], 30);
  });

  test('a closed run emits the closing segment and then the seam join', () {
    // A triangle: three points, closed. Segments 0-1, 1-2, 2-0 with a join
    // at vertices 1 and 2, then the seam join at vertex 0 -- LAST, after the
    // closing segment. Six instances, and the last one is the seam.
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.polyline(
        Float64List.fromList(<double>[0, 0, 60, 0, 30, 50]),
        3,
        const ResolvedStyle(argb: 0xFF000000, lineweightHundredths: 25),
        closed: true);
    expect(c.instanceCount, 6);
    expect(
        List<double>.generate(6, (i) => _kindAt(c, i)),
        <double>[
          kKindStroke, // 0 -> 1
          kKindJoin, //   at 1
          kKindStroke, // 1 -> 2
          kKindJoin, //   at 2
          kKindStroke, // 2 -> 0, the closing segment
          kKindJoin, //   the seam, at 0, LAST
        ]);
    final seam = c.data.sublist(5 * kFloatsPerInstance);
    expect(seam[InstanceFieldOffset.x0], 0, reason: 'the seam is at the first point');
    expect(seam[InstanceFieldOffset.y0], 0);
    expect(seam[InstanceFieldOffset.x1], 30, reason: 'incoming from the last point');
    expect(seam[InstanceFieldOffset.y1], 50);
    expect(seam[InstanceFieldOffset.x2], 60, reason: 'outgoing to the second point');
    expect(seam[InstanceFieldOffset.y2], 0);
  });

  test('a repeated point is spanned by the join, not turned into one', () {
    // The reference's `_runTo` skips a zero-length step and KEEPS the
    // previous direction, so a duplicated vertex produces the same corner a
    // clean polyline would. A collector that reset its direction on the
    // repeat would emit a join between two identical points and draw
    // nothing there.
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.polyline(
        Float64List.fromList(<double>[0, 0, 40, 0, 40, 0, 40, 30]),
        4,
        const ResolvedStyle(argb: 0xFF000000, lineweightHundredths: 25),
        closed: false);
    expect(c.instanceCount, 3, reason: 'the repeat adds no instance');
    final j = c.data.sublist(kFloatsPerInstance, 2 * kFloatsPerInstance);
    expect(j[InstanceFieldOffset.x1], 0,
        reason: 'the incoming neighbour is still the first point');
    expect(j[InstanceFieldOffset.y1], 0);
  });

  test('a two-point run has no join at all', () {
    // The degenerate case a join implementation gets wrong in the other
    // direction: emitting a join at the start or the end of an open run.
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.polyline(
        Float64List.fromList(<double>[0, 0, 40, 30]),
        2,
        const ResolvedStyle(argb: 0xFF000000, lineweightHundredths: 25),
        closed: false);
    expect(c.instanceCount, 1);
    expect(_kindAt(c, 0), kKindStroke);
  });
```

- [ ] **Step 2: Run and watch them fail**

```bash
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```

Expected: the five new tests fail on instance counts (1, 2, 3 instead of 3, 3,
6, 3, 1) — the collector emits segments only.

- [ ] **Step 3: Implement the run state machine**

Add to `GeometryCollector`'s fields:

```dart
  // The run state machine, mirroring `VerticesDrawSink._beginRun` /
  // `_runTo` / `_endRun`. It is duplicated rather than shared because these
  // two classes are independent implementations of one `DrawSink` contract,
  // cross-checked against each other by the differential gates -- the same
  // reason `kMinStrokeDevicePixels` is a separate copy.
  //
  // Points, not directions: `_runBack` is the point BEFORE `_runPrev`, so a
  // join is written as its three points and the shader normalises after the
  // mvp. See `writeJoin`'s doc for why directions could not be stored here.
  double _runFirstX = 0, _runFirstY = 0;
  double _runSecondX = 0, _runSecondY = 0;
  double _runPrevX = 0, _runPrevY = 0;
  double _runBackX = 0, _runBackY = 0;
  bool _runHasDirection = false;
  int _runSegments = 0;
```

and the three methods:

```dart
  /// Starts a connected run at a collection-space point.
  void _beginRun(double x, double y) {
    _runFirstX = x;
    _runFirstY = y;
    _runSecondX = x;
    _runSecondY = y;
    _runPrevX = x;
    _runPrevY = y;
    _runBackX = x;
    _runBackY = y;
    _runHasDirection = false;
    _runSegments = 0;
  }

  /// Extends the run, emitting the join **before** the segment.
  ///
  /// The zero-length test is `length == 0` on the square root, not
  /// `x == _runPrevX && y == _runPrevY`, because that is the reference's test
  /// (`vertices_draw_sink.dart`, `_runTo`) and the two are not the same
  /// predicate: for a displacement near the underflow boundary `dx * dx`
  /// rounds to zero while `dx` itself is non-zero, so the equality form keeps
  /// a step the reference drops. Matching the formula rather than the
  /// intention is what keeps the two arms' instance lists identical.
  void _runTo(double x, double y, double half, int argb) {
    final dx = x - _runPrevX, dy = y - _runPrevY;
    if (math.sqrt(dx * dx + dy * dy) == 0) return;

    if (_runHasDirection) {
      _emitJoin(_runPrevX, _runPrevY, _runBackX, _runBackY, x, y, half, argb);
    } else {
      _runSecondX = x;
      _runSecondY = y;
    }
    _emit(_runPrevX, _runPrevY, x, y, half, argb);

    _runBackX = _runPrevX;
    _runBackY = _runPrevY;
    _runPrevX = x;
    _runPrevY = y;
    _runHasDirection = true;
    _runSegments++;
  }

  /// Ends the run.
  ///
  /// An open run gets butt caps, which is to say nothing at all — the
  /// reference's own words, and the reason this plan emits no cap geometry.
  /// A closed run gets the segment back to its first point and then the seam
  /// join, the corner no vertex list contains and the one whose absence puts
  /// a notch on every circle at its start angle.
  void _endRun({required bool closed, required double half, required int argb}) {
    if (!closed || !_runHasDirection) return;
    _runTo(_runFirstX, _runFirstY, half, argb);
    // Guarded for the same reason the reference guards it: today's callers
    // cannot reach here with one segment, but that is a fact about the
    // callers, not a promise the join arithmetic makes.
    if (_runSegments >= 2) {
      _emitJoin(_runFirstX, _runFirstY, _runBackX, _runBackY, _runSecondX,
          _runSecondY, half, argb);
    }
  }

  void _emitJoin(double vx, double vy, double prevX, double prevY, double nextX,
      double nextY, double half, int argb) {
    // No collinearity test here, deliberately: the bevel/miter/collinear
    // decision belongs to the shader, in device pixels, where the reference
    // makes it too. See this plan's Ruling B4.
    _reserve(_instances + 1);
    writeJoin(_buffer, _instances,
        vx: vx,
        vy: vy,
        prevX: prevX,
        prevY: prevY,
        nextX: nextX,
        nextY: nextY,
        halfWidth: half,
        argb: argb);
    _instances++;
  }
```

Add `import 'dart:math' as math;` at the top of the file.

Rewrite `_emit`'s guard to the same formula, replacing the exact-equality test:

```dart
  void _emit(
      double x0, double y0, double x1, double y1, double half, int argb) {
    // The reference's own test (`vertices_draw_sink.dart`, `_emitSegment`): a
    // zero-length segment has no direction to take a normal from. Matching
    // the formula, not the intention -- see `_runTo`.
    final dx = x1 - x0, dy = y1 - y0;
    if (math.sqrt(dx * dx + dy * dy) == 0) return;
    _reserve(_instances + 1);
    writeStroke(_buffer, _instances,
        x0: x0, y0: y0, x1: x1, y1: y1, halfWidth: half, argb: argb);
    _instances++;
  }
```

and rewrite `polyline` to drive the run:

```dart
  @override
  void polyline(Float64List points, int count, ResolvedStyle style,
      {required bool closed}) {
    if (count < 2) return;
    final half = _halfWidthFor(style.lineweightHundredths);
    final argb = _coveredArgb(style.argb, style.lineweightHundredths);
    final t = _residual;
    _beginRun(t.a * points[0] + t.c * points[1] + t.e,
        t.b * points[0] + t.d * points[1] + t.f);
    for (var i = 1; i < count; i++) {
      _runTo(t.a * points[i * 2] + t.c * points[i * 2 + 1] + t.e,
          t.b * points[i * 2] + t.d * points[i * 2 + 1] + t.f, half, argb);
    }
    _endRun(closed: closed, half: half, argb: argb);
  }
```

- [ ] **Step 4: Run the tests**

```bash
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```

Expected: all pass.

- [ ] **Step 5: Fire two mutations**

```bash
cd packages/jet_cad_2d_flutter
cp lib/src/gpu/geometry_collector.dart /tmp/gc.bak

# M-B2: emit the join AFTER its segment (swap the two statements in `_runTo`).
flutter test test/gpu/geometry_collector_test.dart
cp /tmp/gc.bak lib/src/gpu/geometry_collector.dart

# M-B3: skip the seam join (delete the `if (_runSegments >= 2)` block).
flutter test test/gpu/geometry_collector_test.dart
cp /tmp/gc.bak lib/src/gpu/geometry_collector.dart
```

Expected: M-B2 red on the kind-sequence assertions; M-B3 red on the closed-run
count and the seam's coordinates. Paste both failures.

- [ ] **Step 6: Gate and commit**

```bash
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
echo "exit=$?"
git add packages/jet_cad_2d_flutter
git commit -m "feat(gpu): the collector emits joins, in the reference's order"
```

The full suite may now show the differential test (Task 8 of Plan A) failing on
instance counts, since the collector emits joins the oracle does not rebuild.
**Do not weaken that test.** Task 9 rewrites it against a join-aware oracle. If
it goes red here, report the exact failure and mark the task
`DONE_WITH_CONCERNS` rather than editing the assertion.

---

### Task 5: `circle()` and `arc()`

**Files:**
- Modify: `lib/src/gpu/geometry_collector.dart`
- Test: `test/gpu/geometry_collector_test.dart`

**Interfaces:**
- Consumes: the run state machine (Task 4).
- Produces: `GeometryCollector.circle` and `.arc` emit flattened runs;
  `skippedOps` no longer counts them.

Ruling B1 above is the authority for this task being here. Two further facts an
implementer needs:

- **Flattening happens in the residual's *local* space, and only the chord
  *count* is a device-space decision.** The reference's `_flatten` doc says
  why: *"the residual may be non-uniform, and the arc that `Canvas` would draw
  under it is an ellipse. Flattening here and transforming each point
  reproduces that ellipse; flattening a device-space circle would not."*
- **This is the first op in the collector that receives a general-affine
  residual.** `draft_painter.dart:568` pushes `camera ∘ placement` for circles
  and arcs, where polylines get only a translation. Plan A's transposition
  test was written for exactly this path.

- [ ] **Step 1: Write the failing tests**

```dart
  test('a circle is a closed run: N chords, N joins, seam last', () {
    // The chord count comes from the reference's own formula, recomputed
    // here rather than hardcoded, so the test tracks a tolerance change
    // instead of pinning today's number.
    const r = 50.0;
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.identity());
    c.circle(0, 0, r, const ResolvedStyle(argb: 0xFF000000, lineweightHundredths: 25));

    final steps = (2 *
            math.pi *
            math.sqrt(r / (8 * VerticesDrawSink.kFlattenTolerance)))
        .ceil()
        .clamp(1, VerticesDrawSink.kMaxFlattenSegments);
    // A closed run of `steps` chords: `steps` segments, `steps - 1` interior
    // joins, and the seam. 2 * steps instances.
    expect(c.instanceCount, 2 * steps);
    expect(c.skippedOps, 0, reason: 'a circle is no longer skipped');
    expect(
        c.data[(2 * steps - 1) * kFloatsPerInstance +
            InstanceFieldOffset.kind],
        kKindJoin,
        reason: 'the seam join is the last instance');
  });

  test('an arc is an open run and has no seam', () {
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.identity());
    c.arc(0, 0, 50, 0, math.pi / 2,
        const ResolvedStyle(argb: 0xFF000000, lineweightHundredths: 25));
    // An open run of `steps` chords is `steps` segments and `steps - 1`
    // joins: odd, and ending on a segment.
    expect(c.instanceCount.isOdd, isTrue);
    expect(
        c.data[(c.instanceCount - 1) * kFloatsPerInstance +
            InstanceFieldOffset.kind],
        kKindStroke,
        reason: 'an open run ends on a segment -- butt caps, no seam');
  });

  test('a non-uniform residual makes an ellipse, not a scaled circle', () {
    // The degenerate-fixture guard for this op. Under `scale(3, 1)` a circle
    // of radius 10 spans 60 in x and 20 in y; a collector that flattened in
    // device space and transformed the CENTRE only would give a circle of
    // some single radius, and every x-extent assertion below would fail.
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.beginResidual(const Transform2(3, 0, 0, 1, 0, 0));
    c.circle(0, 0, 10, const ResolvedStyle(argb: 0xFF000000, lineweightHundredths: 25));
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (var i = 0; i < c.instanceCount; i++) {
      final o = i * kFloatsPerInstance;
      if (c.data[o + InstanceFieldOffset.kind] != kKindStroke) continue;
      final x = c.data[o + InstanceFieldOffset.x0];
      final y = c.data[o + InstanceFieldOffset.y0];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    expect(maxX - minX, closeTo(60, 0.5));
    expect(maxY - minY, closeTo(20, 0.5));
  });

  test('a zero or negative radius draws nothing', () {
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.identity());
    const style = ResolvedStyle(argb: 0xFF000000, lineweightHundredths: 25);
    c.circle(0, 0, 0, style);
    c.arc(0, 0, 10, 0, 0, style);
    expect(c.instanceCount, 0);
  });
```

Add `import 'dart:math' as math;` and the `VerticesDrawSink` import to the test
file if absent.

- [ ] **Step 2: Run and watch them fail**

```bash
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```

Expected: instance counts of 0 — `circle` and `arc` still only increment
`_skipped`.

- [ ] **Step 3: Implement**

Replace the `circle` and `arc` overrides and add the flattener:

```dart
  /// The chord error a flattened arc is allowed, in device pixels. The
  /// reference's own value, copied for the same reason
  /// [kMinStrokeDevicePixels] is: two independent implementations that agree
  /// are a differential test; one shared field is not.
  static const double kFlattenTolerance = 0.25;

  /// The chord ceiling, likewise copied.
  static const int kMaxFlattenSegments = 512;

  @override
  void circle(double cx, double cy, double r, ResolvedStyle style) =>
      _flatten(cx, cy, r, 0, 2 * math.pi, style, closed: true);

  @override
  void arc(double cx, double cy, double r, double start, double sweep,
          ResolvedStyle style) =>
      _flatten(cx, cy, r, start, sweep, style, closed: false);

  /// Walks a circular arc in the residual's **local** space, emitting a chord
  /// per step.
  ///
  /// Local space, not collection space, on purpose: the residual may be
  /// non-uniform, and the arc that `Canvas` would draw under it is an
  /// ellipse. Flattening here and transforming each point reproduces that
  /// ellipse; flattening a collection-space circle would not. Only the
  /// *count* is a scale decision, because the chord error the viewer sees is
  /// a pixel quantity.
  ///
  /// **This is the op that turns on the general-affine residual.**
  /// `draft_painter.dart:568` pushes `camera ∘ placement` here, where a
  /// polyline gets only a translation — the path Plan A's transposition test
  /// was written to guard and no Plan A fixture could reach.
  void _flatten(double cx, double cy, double r, double start, double sweep,
      ResolvedStyle style,
      {required bool closed}) {
    if (r <= 0 || sweep == 0) return;
    final t = _residual;
    final deviceRadius = r * t.scaleMagnitude;
    if (deviceRadius <= 0) return;

    final steps = _flattenSteps(deviceRadius, sweep.abs());
    final half = _halfWidthFor(style.lineweightHundredths);
    final argb = _coveredArgb(style.argb, style.lineweightHundredths);
    final step = sweep / steps;

    var lx = cx + r * math.cos(start);
    var ly = cy + r * math.sin(start);
    _beginRun(t.a * lx + t.c * ly + t.e, t.b * lx + t.d * ly + t.f);
    // A closed sweep stops one sample short: its last chord is the segment
    // `_endRun` draws back to the first point, so closing here would draw
    // that chord twice and leave the seam a duplicated point instead of a
    // join.
    final last = closed ? steps - 1 : steps;
    for (var i = 1; i <= last; i++) {
      final angle = start + step * i;
      lx = cx + r * math.cos(angle);
      ly = cy + r * math.sin(angle);
      _runTo(t.a * lx + t.c * ly + t.e, t.b * lx + t.d * ly + t.f, half, argb);
    }
    _endRun(closed: closed, half: half, argb: argb);
  }

  int _flattenSteps(double deviceRadius, double theta) {
    final ideal =
        (theta * math.sqrt(deviceRadius / (8 * kFlattenTolerance))).ceil();
    return ideal.clamp(1, kMaxFlattenSegments);
  }
```

- [ ] **Step 4: Run the tests**

```bash
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```

- [ ] **Step 5: Fire the mutation**

```bash
cd packages/jet_cad_2d_flutter
cp lib/src/gpu/geometry_collector.dart /tmp/gc.bak
# M-B4: flatten in collection space -- transform the centre, then walk the
# circle around it in collection space:
#   final ccx = t.a * cx + t.c * cy + t.e;
#   final ccy = t.b * cx + t.d * cy + t.f;
#   ... _runTo(ccx + deviceRadius * cos(angle), ccy + deviceRadius * sin(angle), ...)
flutter test test/gpu/geometry_collector_test.dart
cp /tmp/gc.bak lib/src/gpu/geometry_collector.dart
```

Expected: red on `a non-uniform residual makes an ellipse, not a scaled
circle` — both extents read 60.

- [ ] **Step 6: Gate and commit**

```bash
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
echo "exit=$?"
git add packages/jet_cad_2d_flutter
git commit -m "feat(gpu): the collector flattens circles and arcs, seam join included"
```

---

### Task 6: `point()`

**Files:**
- Modify: `lib/src/gpu/geometry_collector.dart`
- Test: `test/gpu/geometry_collector_test.dart`

**Interfaces:**
- Consumes: `writePoint` (Task 2), `_coveredArgb` (Task 3).
- Produces: `GeometryCollector.point` emits one `kKindPoint` instance;
  `skippedOps` counts only `fillPolygon`, `fillCircle` and `text`.

- [ ] **Step 1: Write the failing test**

```dart
  test('a point is one instance of its own kind, at the transformed position',
      () {
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    // A general residual, so a collector that dropped the off-diagonal terms
    // lands somewhere else: (2*4 + 0.5*(-1) + 10, ...) is not (2*4 + 10, ...).
    c.beginResidual(const Transform2(2, 0.5, -1, 3, 10, 10));
    c.point(4, -1,
        const ResolvedStyle(argb: 0xFF336699, lineweightHundredths: 25));
    expect(c.instanceCount, 1);
    expect(c.skippedOps, 0);
    final r = c.data;
    expect(r[InstanceFieldOffset.kind], kKindPoint);
    // x = a*4 + c*(-1) + e = 8 + 1 + 10 = 19
    // y = b*4 + d*(-1) + f = 2 - 3 + 10 = 9
    expect(r[InstanceFieldOffset.x0], closeTo(19, 1e-4));
    expect(r[InstanceFieldOffset.y0], closeTo(9, 1e-4));
    // The unused slots stay zero: a point that reused x1/y1 as a second
    // endpoint would be a stroke wearing the wrong tag.
    expect(r[InstanceFieldOffset.x1], 0);
    expect(r[InstanceFieldOffset.y1], 0);
    expect(r[InstanceFieldOffset.x2], 0);
    expect(r[InstanceFieldOffset.y2], 0);
  });

  test('a point takes the hairline fade like a stroke', () {
    // `point()` routes through `_coveredArgb` in the reference. A dot on a
    // hairline layer fades with everything else on it.
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 1.0);
    c.point(0, 0,
        const ResolvedStyle(argb: 0xFF000000, lineweightHundredths: 5));
    expect(c.data[InstanceFieldOffset.a] * 255.0, lessThan(0xFF));
  });

  test('after Plan B, only fills and text are skipped', () {
    // The sentence in `skippedOps`' doc, asserted. It goes red the day
    // another op is silently dropped -- or the day Plan D lands and forgets
    // to update the doc.
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.identity());
    const style = ResolvedStyle(argb: 0xFF000000, lineweightHundredths: 25);
    c.polyline(Float64List.fromList(<double>[0, 0, 10, 10]), 2, style,
        closed: false);
    c.circle(0, 0, 20, style);
    c.arc(0, 0, 20, 0, 1, style);
    c.point(1, 1, style);
    expect(c.skippedOps, 0, reason: 'four ops Plan B draws');
    c.fillPolygon(Float64List.fromList(<double>[0, 0, 1, 0, 0, 1]), 3,
        Int32List.fromList(<int>[0, 1, 2]), style);
    c.fillCircle(0, 0, 5, style);
    c.text('x', Handle.none, style);
    expect(c.skippedOps, 3, reason: 'three ops Plans D and E draw');
  });
```

- [ ] **Step 2: Run and watch them fail**

```bash
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```

- [ ] **Step 3: Implement**

```dart
  /// A dot the width of the stroke.
  ///
  /// The reference draws it as a horizontal segment of the stroke's own
  /// width, which is a square of it (`vertices_draw_sink.dart`, `point`);
  /// here it is [kKindPoint] instead, because that `± half` is a **device**
  /// quantity and this record holds collection space. See [kKindPoint]'s doc.
  @override
  void point(double x, double y, ResolvedStyle style) {
    final t = _residual;
    _reserve(_instances + 1);
    writePoint(_buffer, _instances,
        x: t.a * x + t.c * y + t.e,
        y: t.b * x + t.d * y + t.f,
        halfWidth: _halfWidthFor(style.lineweightHundredths),
        argb: _coveredArgb(style.argb, style.lineweightHundredths));
    _instances++;
  }
```

- [ ] **Step 4: Run, gate, commit**

```bash
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
echo "exit=$?"
git add packages/jet_cad_2d_flutter
git commit -m "feat(gpu): point() is its own kind, not a baked horizontal stroke"
```

---

### Task 7: The shader learns three kinds

**Files:**
- Modify: `shaders/cad_stroke.vert`
- Modify: `shaders/cad_stroke.frag` (comment only)
- Regenerate: `assets/shaders/cad.shaderbundle`

**Interfaces:**
- Consumes: the record layout and the corner buffer (Task 2).
- Produces: nothing Dart-visible. **Task 8's expander is the transcription of
  this file and must be written from it, not beside it.**

**Nothing in `flutter test` reaches this file.** The gate is Task 8's expander,
Task 9's pixel differential and Task 11's device run. Write it carefully and
read it twice.

- [ ] **Step 1: Rewrite `cad_stroke.vert`**

```glsl
// Expands one instance into a screen-space primitive, branching on its kind.
//
// **Authored for OpenGL ES 100.** `impellerc` emits the `openglEs` stage the
// web loader reads and transpiles to ES 300, and ES 100 has no bitwise
// operators and no integer attributes -- hence a float kind tag and a vec4
// colour rather than a packed uint32, and a `<` dispatch rather than a
// switch.
//
// **Everything scale-dependent happens HERE, at the live camera.** The
// instance buffer holds a centreline, a corner or a centre in collection
// space plus a half-width in device pixels; expanding any of it at collection
// time would thicken the drawing with the camera. That is why joins are a
// kind and not collector geometry: a miter is a function of the live
// half-width.
//
// **`test/support/instance_expander.dart` is this file, in Dart.** It is what
// the suite can actually run. Any edit here that is not mirrored there is a
// divergence no test in this package can see -- change them together.

uniform FrameInfo {
  mat4 mvp;            // collection space -> normalized device coordinates
  vec2 half_viewport;  // device pixels / 2
} frame_info;

// Per vertex: two triangles, six corners.
// `corner.x` picks the endpoint (0 = p0, 1 = p1), `corner.y` picks the side
// (-1 or +1). `join_weight` selects one of (V, A, B, M) for the join branch,
// which needs six distinct roles where `corner` offers only four.
in vec2 corner;
in vec4 join_weight;

// Per instance.
in float kind;
in vec2 p0;
in vec2 p1;
in vec2 p2;
in float half_width;  // device pixels
in vec4 color;

out vec4 v_color;

// Impeller's conversion of Flutter's default miter limit of 4:
// `2 * (1 / limit)^2 - 1` (`stroke_path_geometry.cc:442`). A corner is
// mitred up to about a 151-degree turn and bevelled past it. Restated as a
// literal because GLSL cannot read `VerticesDrawSink.kMinMiterCosine`;
// `instance_expander.dart` asserts the two agree.
const float kMinMiterCosine = -0.875;

vec2 to_pixels(vec2 p) {
  vec4 clip = frame_info.mvp * vec4(p, 0.0, 1.0);
  return clip.xy * frame_info.half_viewport;
}

void main() {
  vec2 px;

  if (kind < 0.5) {
    // kKindStroke: two triangles around a centreline.
    vec2 a = to_pixels(p0);
    vec2 b = to_pixels(p1);
    vec2 delta = b - a;
    float len = length(delta);
    // Reachable, not merely defensive. The collector's guard runs on
    // `double` before the values are narrowed to float32, and two distinct
    // doubles can collapse to one float; separately, two distinct floats can
    // still project to the same device pixel at extreme zoom-out. A NaN here
    // is a whole frame of nothing.
    vec2 dir = len > 0.0 ? delta / len : vec2(1.0, 0.0);
    vec2 normal = vec2(-dir.y, dir.x);
    px = mix(a, b, corner.x) + normal * half_width * corner.y;

  } else if (kind < 1.5) {
    // kKindJoin: the notch at a corner, as the bevel (V, A, B) plus the
    // miter tip (A, M, B). Exactly `VerticesDrawSink._emitJoin`, in device
    // pixels, which is the space that function works in too.
    vec2 v = to_pixels(p0);
    vec2 prev = to_pixels(p1);
    vec2 next = to_pixels(p2);

    vec2 in_delta = v - prev;
    vec2 out_delta = next - v;
    float in_len = length(in_delta);
    float out_len = length(out_delta);
    vec2 d0 = in_len > 0.0 ? in_delta / in_len : vec2(1.0, 0.0);
    vec2 d1 = out_len > 0.0 ? out_delta / out_len : d0;

    float cross_z = d0.x * d1.y - d0.y * d1.x;

    if (cross_z == 0.0 || in_len == 0.0 || out_len == 0.0) {
      // Collinear: either straight through, where the quads already meet, or
      // a reversal, where both the miter and the bevel are degenerate. The
      // reference emits nothing; collapsing every corner onto the vertex
      // gives two zero-area triangles, which is the same picture.
      px = v;
    } else {
      // The outer side of the turn is the one away from it: a left turn
      // (cross > 0) opens a notch on the right.
      float s = cross_z > 0.0 ? -half_width : half_width;
      vec2 n0 = vec2(-d0.y, d0.x) * s;
      vec2 n1 = vec2(-d1.y, d1.x) * s;
      vec2 a = v + n0;
      vec2 b = v + n1;

      // Bevel by default: with M at A the tip triangle (A, M, B) has zero
      // area and disappears, which is what the reference's early return
      // achieves by not emitting it.
      vec2 m = a;
      if (dot(d0, d1) >= kMinMiterCosine) {
        vec2 sum = n0 + n1;
        float sum_len = length(sum);
        if (sum_len > 0.0 && half_width > 0.0) {
          vec2 mu = sum / sum_len;
          // `n0` has length `half_width`, so this is the cosine of half the
          // included angle.
          float cos_half = dot(mu, n0) / half_width;
          if (cos_half > 0.0) {
            m = v + mu * (half_width / cos_half);
          }
        }
      }

      px = join_weight.x * v + join_weight.y * a + join_weight.z * b +
           join_weight.w * m;
    }

  } else {
    // kKindPoint: a square of the stroke's width centred on p0. Both axes
    // are expanded here, in device pixels, so the dot stays square and stays
    // the same size at every zoom -- which is what the reference gets for
    // free by computing its `+/- half` in device space.
    vec2 c = to_pixels(p0);
    px = c + vec2((corner.x * 2.0 - 1.0) * half_width, corner.y * half_width);
  }

  gl_Position = vec4(px / frame_info.half_viewport, 0.0, 1.0);
  v_color = color;
}
```

- [ ] **Step 2: Correct the fragment shader's comment**

Replace `cad_stroke.frag`'s header with:

```glsl
// Hard-edged, and it stays that way for now.
//
// The gate this backend is measured by is a pixel differential against
// `VerticesDrawSink`, which has no antialiasing path at all -- `flush()`
// submits `Vertices.raw` through `drawVertices` with per-vertex colours, and
// the word does not appear in the file. At one-to-two device-pixel stroke
// widths, edge pixels are most of the ink, so a coverage fade here would
// differ from the reference by most of a channel on most inked pixels and
// break spec criterion 1 outright. Antialiasing becomes possible when
// something other than the reference sink is the oracle.
//
// (An earlier version of this comment said antialiasing was Plan B's. It is
// not; Plan B's Ruling B3 records why.)
```

- [ ] **Step 3: Rebuild the bundle**

```bash
cd packages/jet_cad_2d_flutter && ./tool/build_shaders.sh
```

Expected: `wrote assets/shaders/cad.shaderbundle`, exit 0.

**If it fails with "Could not complete reflection on generated shader"**, an
attribute is declared but folded away by the optimizer. Every one of `corner`,
`join_weight`, `kind`, `p0`, `p1`, `p2`, `half_width` and `color` must be read
on a path the compiler cannot prove dead. Report which attribute you had to
touch and how.

- [ ] **Step 4: Verify the bundle carries an ES 100 stage**

The bundle is a flatbuffer; `strings` is not evidence, because the
`openglDesktop` stage uses `#version 120` with identical `attribute` syntax and
Plan A lost a review round to counting both. Decode it instead:

```bash
cd packages/jet_cad_2d_flutter
python3 - <<'PY'
import re
b = open('assets/shaders/cad.shaderbundle','rb').read()
print('size', len(b))
for tag in (b'#version 100', b'#version 120', b'#version 300 es'):
    print(tag.decode(), b.count(tag))
print('entry points:', sorted(set(re.findall(rb'Cad\w+', b))))
PY
sha256sum assets/shaders/cad.shaderbundle 2>/dev/null || shasum -a 256 assets/shaders/cad.shaderbundle
```

Expected: at least one `#version 100` occurrence, and both entry points
present. Paste the output and the new SHA-256 into the report; `STATUS.md` and
Task 11's results note both record it.

- [ ] **Step 5: Gate and commit**

```bash
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
echo "exit=$?"
git add packages/jet_cad_2d_flutter/shaders packages/jet_cad_2d_flutter/assets
git commit -m "feat(gpu): the vertex shader builds join wedges and point squares"
```

---

### Task 8: The vertex shader, in Dart

**Files:**
- Create: `test/support/instance_expander.dart`
- Test: `test/gpu/instance_expander_test.dart`

**Interfaces:**
- Consumes: `InstanceFieldOffset`, the kind constants,
  `ResidentGeometry.kCornerVertices`.
- Produces:
  ```dart
  class ExpandedTriangles {
    final Float32List positions;  // 2 floats per vertex, 6 vertices per instance
    final Int32List colors;       // 1 per vertex, 0xAARRGGBB
  }
  ExpandedTriangles expandInstances(
      Float32List data, int instanceCount, Transform2 collectionToDevice);
  ```
  Task 9 consumes both.

**Why this file exists.** `flutter test` has no GPU, so every line of
`cad_stroke.vert` is unreachable by this package's suite. Plan A lived with
that because its shader was four statements. Plan B's is fifty, and the miter
arithmetic is the part most likely to be wrong. This is that shader
transcribed into Dart, driven by the same instance buffer and the same corner
table, producing the triangle list the GPU would produce — which
`TriangleRasterizer` can then rasterise.

**It is a second copy, and that is stated rather than hidden.** The copy is
worth it because it converts an untestable file into a tested one, and because
the divergence it can hide is one file diff away. The one thing it must never
do is read the collector: it takes a `Float32List` and a transform, nothing
else.

- [ ] **Step 1: Write the failing test**

`test/gpu/instance_expander_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

import '../support/instance_expander.dart';

void main() {
  test('the miter cosine matches the reference constant', () {
    // `cad_stroke.vert` restates -0.875 as a literal because GLSL cannot
    // read a Dart constant. This is the assertion that keeps the literal
    // honest if the reference's miter limit ever moves.
    expect(kExpanderMinMiterCosine, VerticesDrawSink.kMinMiterCosine);
  });

  test('a horizontal stroke expands to the quad the reference builds', () {
    final data = Float32List(kFloatsPerInstance);
    writeStroke(data, 0,
        x0: 0, y0: 0, x1: 100, y1: 0, halfWidth: 4, argb: 0xFF112233);
    final out = expandInstances(data, 1, Transform2.identity());

    expect(out.positions.length, 12, reason: 'six vertices, two floats each');
    // Corner (0,-1) -> (0, -4); (0,1) -> (0, 4); (1,-1) -> (100, -4).
    // The normal of a +x direction is (0, +1), so corner.y = -1 is y = -4.
    expect(out.positions[0], closeTo(0, 1e-4));
    expect(out.positions[1], closeTo(-4, 1e-4));
    expect(out.positions[2], closeTo(0, 1e-4));
    expect(out.positions[3], closeTo(4, 1e-4));
    expect(out.positions[4], closeTo(100, 1e-4));
    expect(out.positions[5], closeTo(-4, 1e-4));
    expect(out.colors.every((c) => c == 0xFF112233), isTrue);
  });

  test('a right-angle join is mitred, and the tip is at the outer corner',
      () {
    // Incoming +x, outgoing +y: a left turn, so the notch is on the right
    // (negative y / positive x side). At 90 degrees the half-angle is 45,
    // cos is sqrt(1/2), and the miter reach is half / cos = 4 * sqrt(2).
    final data = Float32List(kFloatsPerInstance);
    writeJoin(data, 0,
        vx: 100,
        vy: 0,
        prevX: 0,
        prevY: 0,
        nextX: 100,
        nextY: 100,
        halfWidth: 4,
        argb: 0xFF000000);
    final out = expandInstances(data, 1, Transform2.identity());

    // Vertex 4 of the six is M, the miter tip.
    final mx = out.positions[8], my = out.positions[9];
    // d0 = (1,0), d1 = (0,1), cross = 1 > 0, so s = -4.
    // n0 = (-0,1)*-4 = (0,-4); n1 = (-1,0)*-4 = (4,0).
    // sum = (4,-4), mu = (1,-1)/sqrt2, cos_half = dot(mu,n0)/4
    //     = ((0*1 + -4*-1)/sqrt2)/4 = (4/sqrt2)/4 = 1/sqrt2.
    // reach = 4 / (1/sqrt2) = 4*sqrt2. m = v + mu*reach = (100+4, 0-4).
    expect(mx, closeTo(104, 1e-3));
    expect(my, closeTo(-4, 1e-3));
  });

  test('a hairpin turn is bevelled: the tip triangle has zero area', () {
    // Incoming +x, outgoing very nearly -x. dot is below -0.875, so the
    // reference bails before the miter and emits the bevel alone.
    final data = Float32List(kFloatsPerInstance);
    writeJoin(data, 0,
        vx: 100,
        vy: 0,
        prevX: 0,
        prevY: 0,
        nextX: 0,
        nextY: 1,
        halfWidth: 4,
        argb: 0xFF000000);
    final out = expandInstances(data, 1, Transform2.identity());
    final ax = out.positions[6], ay = out.positions[7];
    final mx = out.positions[8], my = out.positions[9];
    expect(mx, closeTo(ax, 1e-4),
        reason: 'M collapses onto A, so (A, M, B) has no area');
    expect(my, closeTo(ay, 1e-4));
  });

  test('a collinear join collapses onto its vertex', () {
    final data = Float32List(kFloatsPerInstance);
    writeJoin(data, 0,
        vx: 50,
        vy: 50,
        prevX: 0,
        prevY: 50,
        nextX: 100,
        nextY: 50,
        halfWidth: 4,
        argb: 0xFF000000);
    final out = expandInstances(data, 1, Transform2.identity());
    for (var i = 0; i < 6; i++) {
      expect(out.positions[i * 2], closeTo(50, 1e-4));
      expect(out.positions[i * 2 + 1], closeTo(50, 1e-4));
    }
  });

  test('a point expands to a square of the stroke width', () {
    final data = Float32List(kFloatsPerInstance);
    writePoint(data, 0, x: 10, y: 20, halfWidth: 3, argb: 0xFF000000);
    final out = expandInstances(data, 1, Transform2.identity());
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (var i = 0; i < 6; i++) {
      final x = out.positions[i * 2], y = out.positions[i * 2 + 1];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    expect(maxX - minX, closeTo(6, 1e-4));
    expect(maxY - minY, closeTo(6, 1e-4));
    expect((minX + maxX) / 2, closeTo(10, 1e-4));
    expect((minY + maxY) / 2, closeTo(20, 1e-4));
  });

  test('half-width does not scale with the transform', () {
    // The whole reason joins and quads are built in the shader. Under a 5x
    // camera the centreline moves five times as far and the quad stays four
    // device pixels wide.
    final data = Float32List(kFloatsPerInstance);
    writeStroke(data, 0,
        x0: 0, y0: 0, x1: 100, y1: 0, halfWidth: 4, argb: 0xFF000000);
    final out = expandInstances(data, 1, Transform2.scale(5, 5));
    expect(out.positions[4], closeTo(500, 1e-3), reason: 'the centreline scaled');
    expect(out.positions[3] - out.positions[1], closeTo(8, 1e-3),
        reason: 'the width did not');
  });
}
```

- [ ] **Step 2: Run and watch it fail**

```bash
cd packages/jet_cad_2d_flutter && flutter test test/gpu/instance_expander_test.dart
```

Expected: `Target of URI doesn't exist: '../support/instance_expander.dart'`.

- [ ] **Step 3: Write the expander**

`test/support/instance_expander.dart`:

```dart
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

/// `cad_stroke.vert`, in Dart, so `flutter test` can reach it.
///
/// **This is a deliberate second copy of a file no test can run.** The suite
/// has no GPU, so every line of the vertex shader is otherwise unreachable —
/// including the miter arithmetic, which is the part most likely to be
/// wrong. Transcribing it here converts an untestable file into a tested one
/// and reduces the risk to a single file diff.
///
/// **Read it beside the GLSL and keep the statement order.** Where the
/// shader writes `dot(d0, d1) >= kMinMiterCosine`, so does this; where it
/// collapses a corner onto the vertex, so does this. A "cleaner" Dart
/// rewrite is worth nothing here — the value of this file is that a reader
/// can diff it against the shader line by line.
///
/// It takes an instance buffer and a transform. It must never read the
/// collector: the collector's output is the input, which is exactly what the
/// GPU sees.
library;

/// The shader's `kMinMiterCosine` literal, mirrored so a test can assert it
/// against `VerticesDrawSink.kMinMiterCosine`.
const double kExpanderMinMiterCosine = -0.875;

/// The corner table's six entries, `(corner.xy, join_weight.xyzw)`.
///
/// Read from [ResidentGeometry.kCornerVertices] rather than restated, so a
/// reordering there is a change here too.
class _Corner {
  const _Corner(this.x, this.y, this.wv, this.wa, this.wb, this.wm);
  final double x, y, wv, wa, wb, wm;
}

List<_Corner> _corners() {
  const stride = ResidentGeometry.kFloatsPerCorner;
  final src = ResidentGeometry.kCornerVertices;
  return List<_Corner>.generate(
      6,
      (i) => _Corner(src[i * stride], src[i * stride + 1], src[i * stride + 2],
          src[i * stride + 3], src[i * stride + 4], src[i * stride + 5]));
}

/// The triangle list the GPU would produce, in the shape
/// `TriangleRasterizer.observe` takes.
class ExpandedTriangles {
  ExpandedTriangles(this.positions, this.colors);

  /// Two floats per vertex, six vertices per instance, in instance order.
  final Float32List positions;

  /// One `0xAARRGGBB` per vertex.
  final Int32List colors;

  int get vertexCount => colors.length;
}

/// Expands [instanceCount] records of [data] under [collectionToDevice].
///
/// [collectionToDevice] stands in for the shader's `mvp` composed with
/// `half_viewport`: the shader maps collection space to device pixels in two
/// steps because a `mat4` is what a uniform block carries, and the
/// composition is the same affine map. Feeding it directly here removes a
/// clip-space round trip that has no observable effect and would only add a
/// place for the two copies to disagree.
ExpandedTriangles expandInstances(
    Float32List data, int instanceCount, Transform2 collectionToDevice) {
  final corners = _corners();
  final positions = Float32List(instanceCount * 6 * 2);
  final colors = Int32List(instanceCount * 6);
  final t = collectionToDevice;

  double toX(double x, double y) => t.a * x + t.c * y + t.e;
  double toY(double x, double y) => t.b * x + t.d * y + t.f;

  for (var i = 0; i < instanceCount; i++) {
    final o = i * kFloatsPerInstance;
    final kind = data[o + InstanceFieldOffset.kind];
    final halfWidth = data[o + InstanceFieldOffset.halfWidth];
    final argb = _argbOf(data, o);

    final x0 = data[o + InstanceFieldOffset.x0];
    final y0 = data[o + InstanceFieldOffset.y0];
    final x1 = data[o + InstanceFieldOffset.x1];
    final y1 = data[o + InstanceFieldOffset.y1];
    final x2 = data[o + InstanceFieldOffset.x2];
    final y2 = data[o + InstanceFieldOffset.y2];

    for (var v = 0; v < 6; v++) {
      final c = corners[v];
      double px, py;

      if (kind < 0.5) {
        final ax = toX(x0, y0), ay = toY(x0, y0);
        final bx = toX(x1, y1), by = toY(x1, y1);
        final dx = bx - ax, dy = by - ay;
        final len = math.sqrt(dx * dx + dy * dy);
        final dirX = len > 0 ? dx / len : 1.0;
        final dirY = len > 0 ? dy / len : 0.0;
        final nx = -dirY, ny = dirX;
        px = ax + (bx - ax) * c.x + nx * halfWidth * c.y;
        py = ay + (by - ay) * c.x + ny * halfWidth * c.y;
      } else if (kind < 1.5) {
        final vx = toX(x0, y0), vy = toY(x0, y0);
        final pxp = toX(x1, y1), pyp = toY(x1, y1);
        final nxp = toX(x2, y2), nyp = toY(x2, y2);

        final inX = vx - pxp, inY = vy - pyp;
        final outX = nxp - vx, outY = nyp - vy;
        final inLen = math.sqrt(inX * inX + inY * inY);
        final outLen = math.sqrt(outX * outX + outY * outY);
        final d0x = inLen > 0 ? inX / inLen : 1.0;
        final d0y = inLen > 0 ? inY / inLen : 0.0;
        final d1x = outLen > 0 ? outX / outLen : d0x;
        final d1y = outLen > 0 ? outY / outLen : d0y;

        final crossZ = d0x * d1y - d0y * d1x;
        if (crossZ == 0 || inLen == 0 || outLen == 0) {
          px = vx;
          py = vy;
        } else {
          final s = crossZ > 0 ? -halfWidth : halfWidth;
          final n0x = -d0y * s, n0y = d0x * s;
          final n1x = -d1y * s, n1y = d1x * s;
          final ax = vx + n0x, ay = vy + n0y;
          final bx = vx + n1x, by = vy + n1y;

          var mx = ax, my = ay;
          if (d0x * d1x + d0y * d1y >= kExpanderMinMiterCosine) {
            final sumX = n0x + n1x, sumY = n0y + n1y;
            final sumLen = math.sqrt(sumX * sumX + sumY * sumY);
            if (sumLen > 0 && halfWidth > 0) {
              final muX = sumX / sumLen, muY = sumY / sumLen;
              final cosHalf = (muX * n0x + muY * n0y) / halfWidth;
              if (cosHalf > 0) {
                final reach = halfWidth / cosHalf;
                mx = vx + muX * reach;
                my = vy + muY * reach;
              }
            }
          }

          px = c.wv * vx + c.wa * ax + c.wb * bx + c.wm * mx;
          py = c.wv * vy + c.wa * ay + c.wb * by + c.wm * my;
        }
      } else {
        final cx = toX(x0, y0), cy = toY(x0, y0);
        px = cx + (c.x * 2.0 - 1.0) * halfWidth;
        py = cy + c.y * halfWidth;
      }

      final vi = (i * 6 + v);
      positions[vi * 2] = px;
      positions[vi * 2 + 1] = py;
      colors[vi] = argb;
    }
  }

  return ExpandedTriangles(positions, colors);
}

/// Reads the record's four colour floats back to `0xAARRGGBB`.
///
/// Exact round trip: the writer stored `channel / 255.0` and an 8-bit value
/// divided by 255 then multiplied by 255 is that value again in float32,
/// with the round only guarding against a representation surprise.
int _argbOf(Float32List data, int o) {
  int ch(int offset) =>
      (data[o + offset] * 255.0).round().clamp(0, 255).toInt();
  return (ch(InstanceFieldOffset.a) << 24) |
      (ch(InstanceFieldOffset.r) << 16) |
      (ch(InstanceFieldOffset.g) << 8) |
      ch(InstanceFieldOffset.b);
}
```

- [ ] **Step 4: Run the tests**

```bash
cd packages/jet_cad_2d_flutter && flutter test test/gpu/instance_expander_test.dart
```

Expected: 7 tests pass. **Recompute the miter test's numbers by hand before
accepting them** — the whole point of that test is that it was derived
independently of the code.

- [ ] **Step 5: Fire two mutations against the expander**

```bash
cd packages/jet_cad_2d_flutter
cp test/support/instance_expander.dart /tmp/ie.bak

# M-B5: expand the quad at collection scale -- multiply halfWidth by
#   t.scaleMagnitude before using it.
flutter test test/gpu/instance_expander_test.dart
cp /tmp/ie.bak test/support/instance_expander.dart

# M-B6: always miter -- delete the `>= kExpanderMinMiterCosine` guard.
flutter test test/gpu/instance_expander_test.dart
cp /tmp/ie.bak test/support/instance_expander.dart
```

Expected: M-B5 red on `half-width does not scale with the transform`; M-B6 red
on `a hairpin turn is bevelled`.

- [ ] **Step 6: Gate and commit**

```bash
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
echo "exit=$?"
git add packages/jet_cad_2d_flutter/test
git commit -m "test(gpu): the vertex shader, transcribed into Dart and gated"
```

---

### Task 9: The pixel differential against `VerticesDrawSink`

**Files:**
- Create: `test/support/gpu_comparison.dart`
- Create: `test/gpu/resident_pixel_differential_test.dart`
- Modify: `test/gpu/collector_differential_test.dart`

**Interfaces:**
- Consumes: `expandInstances` (Task 8), `TriangleRasterizer`
  (`test/support/triangle_rasterizer.dart`), `GeometryCollector`,
  `VerticesDrawSink`.
- Produces: `ResidentAgreement measureResidentAgreement(...)` and the gate that
  spec criterion 1 is measured by.

**This is the task the plan exists to reach.** Everything before it is
geometry that nothing compares against a picture. Read
`test/support/sink_comparison.dart` first: it already does this shape of work
for `CanvasDrawSink` versus `VerticesDrawSink`, including the ink floor and the
permitted-divergence table, and this file should look like its sibling rather
than like a new invention.

- [ ] **Step 1: Read the existing machinery**

```bash
cd packages/jet_cad_2d_flutter
sed -n '1,140p' test/support/sink_comparison.dart
sed -n '1,80p' test/support/triangle_rasterizer.dart
```

Report, in one paragraph, what `AgreementReport` counts and what
`TriangleRasterizer.observe` expects. If either does something this task's
sample code below assumes wrongly, **follow the code, not the sample**, and say
so.

- [ ] **Step 2: Write the comparison helper**

`test/support/gpu_comparison.dart`:

```dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'instance_expander.dart';
import 'triangle_rasterizer.dart';

/// What a resident-versus-reference comparison counted.
class ResidentAgreement {
  ResidentAgreement({
    required this.referenceInk,
    required this.residentInk,
    required this.differing,
    required this.overEight,
  });

  /// Pixels the reference inked.
  final int referenceInk;

  /// Pixels the resident arm inked.
  final int residentInk;

  /// Pixels differing by more than 2 on any channel.
  final int differing;

  /// Pixels differing by more than 8 on any channel.
  final int overEight;

  @override
  String toString() => 'ResidentAgreement(referenceInk: $referenceInk, '
      'residentInk: $residentInk, differing: $differing, '
      'overEight: $overEight)';
}

/// Draws [draw] through both arms at [size] and counts their disagreement.
///
/// **Both arms go through the same rasterizer.** The question this answers is
/// whether the collector plus the vertex shader produce the same triangles as
/// `VerticesDrawSink`, not whether two rasterizers agree — so the rasterizer
/// is held fixed and only the triangle source changes. A GPU comparison is
/// Task 11's device run; this is what `flutter test` can gate.
ResidentAgreement measureResidentAgreement(
  void Function(DrawSink sink) draw, {
  required Size size,
  required double devicePixelRatio,
  required double pixelsPerPaperMm,
}) {
  final w = (size.width * devicePixelRatio).round();
  final h = (size.height * devicePixelRatio).round();

  // The reference arm: `VerticesDrawSink`'s own triangles.
  final referenceRaster = TriangleRasterizer(w, h);
  final recorder = PictureRecorder();
  final sink = VerticesDrawSink(
    canvas: Canvas(recorder),
    pixelsPerPaperMm: pixelsPerPaperMm,
    devicePixelRatio: devicePixelRatio,
  )..observer = referenceRaster.observe;
  // The sink works in logical pixels and the rasterizer in device ones, so
  // the drawing is scaled into device space before it starts. This mirrors
  // what `sink_comparison.dart` does for the canvas arm.
  sink.beginResidual(Transform2.scale(devicePixelRatio, devicePixelRatio));
  draw(sink);
  sink.endResidual();
  sink.flush();
  recorder.endRecording().dispose();

  // The resident arm: the collector's buffer, expanded by the Dart copy of
  // the vertex shader. The collector already emits device-pixel half-widths,
  // so its geometry is scaled into device space by the same transform and
  // the expander is handed the identity.
  final collector = GeometryCollector(
      pixelsPerPaperMm: pixelsPerPaperMm, devicePixelRatio: devicePixelRatio);
  collector.beginResidual(Transform2.scale(devicePixelRatio, devicePixelRatio));
  draw(collector);
  collector.endResidual();
  final expanded = expandInstances(
      collector.data, collector.instanceCount, Transform2.identity());
  final residentRaster = TriangleRasterizer(w, h)
    ..observe(expanded.positions, expanded.colors);

  var referenceInk = 0, residentInk = 0, differing = 0, overEight = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final a = referenceRaster.inked(x, y);
      final b = residentRaster.inked(x, y);
      if (a) referenceInk++;
      if (b) residentInk++;
      if (a != b) {
        differing++;
        overEight++;
      }
    }
  }
  return ResidentAgreement(
      referenceInk: referenceInk,
      residentInk: residentInk,
      differing: differing,
      overEight: overEight);
}
```

**`TriangleRasterizer` is coverage-only** — `inked(x, y)` is a boolean, not a
colour — so `differing` and `overEight` are the same number here and the
per-channel half of spec criterion 1 is **not** measured by this instrument.
State that in the file's doc comment and in the results note. Colour agreement
is gated separately, by the record-level assertions in Tasks 3-6 and by the
extended `collector_differential_test.dart` in Step 5 below. **Do not describe
this as a full criterion-1 measurement.** If `TriangleRasterizer` turns out to
carry colour after all, use it and say so.

- [ ] **Step 3: Write the differential test**

`test/gpu/resident_pixel_differential_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/gpu_comparison.dart';

const Size _size = Size(400, 300);
const double _dpr = 2.0;
const double _ppmm = 3.7795275590551185;

const ResolvedStyle _thick =
    ResolvedStyle(argb: 0xFF102030, lineweightHundredths: 50);
const ResolvedStyle _hairline =
    ResolvedStyle(argb: 0xFF102030, lineweightHundredths: 5);

/// Every shape Plan B draws, at a scale and an offset chosen so nothing sits
/// on the identity transform, the origin, or an axis.
///
/// **Each element is here because a named mutation needs it**, and the test
/// below says which:
///  - the zigzag has three corners, one left turn and one right, so a sign
///    error in `s` shows on one of them;
///  - the hairpin turns past the miter limit, so the bevel path runs;
///  - the circle is closed, so the seam join runs and its absence is a notch;
///  - the point is a `point()` op;
///  - the hairline is under one device pixel, so `_coveredArgb` runs.
void _corpus(DrawSink sink) {
  sink.polyline(
      Float64List.fromList(<double>[20, 40, 90, 40, 90, 110, 160, 110, 160, 40]),
      5,
      _thick,
      closed: false);
  sink.polyline(
      Float64List.fromList(<double>[30, 160, 120, 165, 32, 170]), 3, _thick,
      closed: false);
  sink.circle(260, 90, 55, _thick);
  sink.arc(120, 230, 45, 0.4, 2.1, _thick);
  sink.point(340, 210, _thick);
  sink.polyline(
      Float64List.fromList(<double>[20, 260, 380, 268]), 2, _hairline,
      closed: false);
}

void main() {
  test('the resident arm draws the reference drawing', () {
    final r = measureResidentAgreement(_corpus,
        size: _size, devicePixelRatio: _dpr, pixelsPerPaperMm: _ppmm);

    // The anti-vacuity floor, the same one `tile_cache_test.dart:958-959`
    // uses: a comparison of two blank frames agrees perfectly and measures
    // nothing. This corpus must actually put ink on the canvas.
    expect(r.referenceInk, greaterThan(5000), reason: r.toString());
    expect(r.residentInk, greaterThan(5000), reason: r.toString());

    // Spec criterion 1's ink threshold: differing pixels below 1% of live
    // ink. This instrument is coverage-only, so this is the whole of what it
    // can assert -- the per-channel half of criterion 1 is gated by the
    // record-level colour assertions in Tasks 3 to 6.
    expect(r.differing, lessThan(r.referenceInk ~/ 100), reason: r.toString());
  });

  test('the seam join is load-bearing on the circle', () {
    // Not a mutation run in a comment: this measures the notch the seam join
    // fills, by drawing the same circle as an OPEN run of the same chords.
    // If the numbers came out equal, the corpus test above could not see a
    // missing seam either.
    double inkOf(void Function(DrawSink) draw) => measureResidentAgreement(
          draw,
          size: _size,
          devicePixelRatio: _dpr,
          pixelsPerPaperMm: _ppmm,
        ).residentInk.toDouble();

    final closed = inkOf((s) => s.circle(200, 150, 90, _thick));
    // A 2*pi arc is the same chords, open: no closing chord and no seam.
    final open =
        inkOf((s) => s.arc(200, 150, 90, 0, 6.283185307179586, _thick));
    expect(closed, greaterThan(open),
        reason: 'the closed circle has the closing chord and the seam; '
            'closed=$closed open=$open');
  });
}
```

- [ ] **Step 4: Run it**

```bash
cd packages/jet_cad_2d_flutter && flutter test test/gpu/resident_pixel_differential_test.dart
```

**Expect this to fail the first time and treat the failure as information.**
Paste `r.toString()` from the failure. Likely causes, in the order to check
them:

1. The two arms are in different spaces — the sink works in logical pixels and
   the collector already carries device half-widths. Re-derive the scaling in
   `measureResidentAgreement` from what each class documents about its own
   space, rather than adjusting until the number falls.
2. The rasterizer's `observe` expects a different tuple than the expander
   produces.
3. A genuine geometry defect from Tasks 4-6.

**If the differing count is small but non-zero, do not raise the threshold.**
Report the number, say where the pixels are (a boundary sliver, a miter tip,
the hairline), and let the reviewer decide. A threshold moved to make a
criterion pass is the one thing this plan's gate forbids.

- [ ] **Step 5: Extend the Plan A collector differential**

`test/gpu/collector_differential_test.dart` rebuilds an expected segment list
from a `RecordingDrawSink` and compares it slot by slot. Joins now sit between
those segments, so it fails. Fix it by **teaching the oracle about joins**, not
by skipping them:

- Where the loop walks a `PolylineOp`'s points, mirror the run state machine:
  expect `join` before every interior segment, and on `closed` the closing
  segment then the seam.
- Assert the kind of every instance, not only the strokes. The Plan A ledger
  records that the old kind assertion *"would pass on a genuinely unwritten
  slot and cannot catch a wrong-kind-among-several defect. Resolves itself
  when Plan B adds a second kind"* — this is that resolution, and it must
  actually discriminate.
- The alpha comparison the Plan A ledger deferred is now live: compare the
  full `argb`, and add one hairline entity to `differentialFixture` (or, if
  changing the shared fixture would disturb other suites, build the hairline
  case as a second local fixture in this file and say which you chose and
  why).

- [ ] **Step 6: Fire the corpus mutations**

Each is fired against the **production** file, with a `cp` backup, and each
must go red on `resident_pixel_differential_test.dart`:

```bash
cd packages/jet_cad_2d_flutter
cp lib/src/gpu/geometry_collector.dart /tmp/gc.bak
cp test/support/instance_expander.dart /tmp/ie.bak

# M-B3' (seam) : delete the seam-join block in `_endRun`.
# M-B7 (join side) : flip `s` in the expander -- `crossZ > 0 ? halfWidth : -halfWidth`.
# M-B8 (point as stroke) : in `point()`, emit `writeStroke` from (x-half, y) to
#   (x+half, y) instead of `writePoint`.
# M-B1' (hairline) : drop `_coveredArgb` from `polyline`.
```

Run the differential test after each and restore from the backup. Paste all
four transcripts. **M-B1' may survive**, because the rasterizer is
coverage-only and a fade changes colour, not coverage. If it does, **record it
as a survivor with that reason** and point at the record-level test in Task 3
as its gate of record. Do not invent a coverage difference to kill it.

- [ ] **Step 7: Gate and commit**

```bash
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
echo "exit=$?"
git add packages/jet_cad_2d_flutter/test
git commit -m "test(gpu): the resident arm is compared against the reference in pixels"
```

---

### Task 10: The mutation log

**Files:**
- Create: `docs/superpowers/notes/plan-b-mutation-log.md`

**Interfaces:**
- Consumes: every mutation transcript from Tasks 3-9.
- Produces: the document of record the exit gate's mutation clause is scored
  against.

Every earlier task fired its mutations and pasted the transcripts into its
report. This task collects them, re-fires any that were not run against the
**full** suite, and writes them up.

- [ ] **Step 1: Build the table**

Open the log with a summary table naming every mutant, its verdict and the
gate that killed it — the shape `plan-3i-mutation-log.md` uses. The mutants
this plan pre-committed:

| id | mutation | expected gate |
|---|---|---|
| M-B1 | drop `_coveredArgb` from strokes | `geometry_collector_test.dart`, the sub-pixel alpha test |
| M-B2 | emit the join after its segment | `geometry_collector_test.dart`, the kind-sequence test |
| M-B3 | skip the seam join | the closed-run count test **and** the pixel differential's seam test |
| M-B4 | flatten circles in collection space | the ellipse test |
| M-B5 | expand the quad at collection scale | `instance_expander_test.dart`, the half-width test |
| M-B6 | always miter, never bevel | `instance_expander_test.dart`, the hairpin test |
| M-B7 | flip the join's outer side | the pixel differential |
| M-B8 | treat `point()` as a zero-length capped stroke | the point test **and** the pixel differential |
| M-B9 | sort the instance buffer by kind before upload | the collector differential's order assertions |
| M-B10 | emit joins as collector geometry at the collection width | see Step 2 |

**M-B9 and M-B10 have not been fired by any earlier task.** Fire them here.

- [ ] **Step 2: Fire the two outstanding mutants**

**M-B9** — in `GeometryCollector.data`, sort the records by kind before
returning them:

```dart
  Float32List get data {
    final flat = _buffer.sublist(0, _instances * kFloatsPerInstance);
    final records = List<int>.generate(_instances, (i) => i)
      ..sort((a, b) => flat[a * kFloatsPerInstance]
          .compareTo(flat[b * kFloatsPerInstance]));
    final out = Float32List(flat.length);
    for (var i = 0; i < records.length; i++) {
      out.setRange(i * kFloatsPerInstance, (i + 1) * kFloatsPerInstance, flat,
          records[i] * kFloatsPerInstance);
    }
    return out;
  }
```

This is the spec's *"give strokes, joins and fills separate draw calls"*
mutation reduced to the one buffer this plan has. Expected: red on the
collector differential's order assertions and on the kind-sequence tests.

**M-B10** — the spec's own wording: *"emit joins as collector geometry at the
collection width → miters distort."* Fire it in the expander, which is where
this plan's shader lives: replace the join branch's `halfWidth` with
`halfWidth * t.scaleMagnitude`, then run the pixel differential with the
comparison's transform set to something other than the identity. **If the
existing comparison runs at the identity, this mutant cannot die**, which is
itself the finding: add a scaled arm to `resident_pixel_differential_test.dart`
that runs the corpus under a 3x transform and asserts agreement there too, then
re-fire. Report which of the two happened.

- [ ] **Step 3: Write the log**

For each mutant: the exact edit, the command, the verbatim failure or the
statement that it survived, and — for survivors — a derivation of *why* it
survives, in the shape Plan 3i's M24 entry uses. **A survivor with a reason is
a result; a survivor without one is a gap.**

Include M-B1' from Task 9 Step 6 if it survived the pixel differential, with
its reason and its gate of record.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/notes/plan-b-mutation-log.md
git commit -m "docs: Plan B's mutation log, ten mutants and their verdicts"
```

---

### Task 11: The device run, the budget, and the exit gate

**Files:**
- Create: `docs/superpowers/notes/2026-08-30-plan-b-results.md`
- Modify: `STATUS.md`

**Interfaces:**
- Consumes: everything.
- Produces: the results note of record and the scored exit gate.

- [ ] **Step 1: Run the harness on a device**

```bash
cd apps/dev_harness_2d
flutter run -d macos --profile \
  --dart-define=RUN_GPU_SPIKE=true \
  --dart-define=ENTITIES=10000 \
  --dart-define=SPIKE_DEFS=20 \
  --dart-define=SPIKE_INSTANCES=150 \
  --dart-define=SPIKE_FRAMES=30 \
  --dart-define=SPIKE_REPEATS=3
```

**Read macOS Low Power Mode before starting and record its state**, per the
standing rule in `STATUS.md` — every `flutter drive` note in this repo that
omitted it is contaminated.

**Look at the window.** Plan 3h's session established looking at the running
window as this project's third instrument, and it is the only one that found
any of that session's four defects. Specifically: are corners filled? Is the
circle notched at its start angle? Is the dot square? Does anything thicken as
you zoom in?

Record what you saw in the note, including "I could not tell" where that is the
honest answer.

- [ ] **Step 2: Price the buffer**

The harness prints `buffer=<N> MB`. Plan A measured 2.06 MB at 59,875
strokes-only segments. Record the new figure and the instance count, and state
the ratio. **The spec's budget is ≤ 8 MB for all kinds plus the resident text
list.** If joins push it past 8 MB, that is a **miss**, recorded with its
number — the threshold is pre-committed and does not move.

Also record how many of the joins were collinear degenerates (Ruling B4's
stated cost). If the harness does not count them, add a counter to
`GeometryCollector` behind a `debug` prefix and say that you did.

- [ ] **Step 3: Score the exit gate**

Pre-committed. A miss is recorded as a miss with its number.

1. **The resident arm draws the reference drawing**: differing pixels below 1%
   of reference ink on Task 9's corpus, with reference ink above the vacuity
   floor. Coverage-only — the per-channel half of spec criterion 1 is not
   measured by this instrument and the note says so.
2. **Emission order holds within an entity**: join before segment, seam last,
   asserted on an open run, a closed run and a flattened circle.
3. **The seam join is load-bearing**: the closed circle inks more than the
   equivalent open arc.
4. **Half-width is invariant under the transform**: the expander's 5x test,
   and the same corpus compared at 3x in Task 10 Step 2.
5. **A sub-pixel stroke fades and keeps its pixel**; a stroke at or above one
   device pixel does not fade; a zero lineweight keeps full alpha.
6. **`point()` is its own kind** and is a square at every scale.
7. **`skippedOps` counts exactly `fillPolygon`, `fillCircle` and `text`.**
8. **Resident geometry ≤ 8 MB** at 10,000 entities.
9. **The bundle carries an OpenGL ES 100 stage**, verified by decode rather
   than by `strings`.
10. **All ten pre-committed mutants are accounted for**: each killed with a
    transcript, or surviving with a derivation.
11. **The device run happened and the window was looked at**, with what was
    seen written down.

- [ ] **Step 4: Write the results note**

`docs/superpowers/notes/2026-08-30-plan-b-results.md`. It must carry:

- the gate, scored, criterion by criterion, misses included;
- the buffer figure, the instance count and the collinear-join count;
- **Ruling B2's consequence stated plainly**: caps are butt caps, Plan B emits
  no cap geometry, and spec criterion 8's "caps" term is therefore satisfied
  vacuously;
- **Ruling B3's consequence**: the resident arm is hard-edged, and the spec's
  budget discussion assumed antialiasing would be consuming headroom by now;
- what was **not** measured: no GPU comparison in the suite (the pixel
  differential is a CPU rasterisation of both arms), no per-channel colour
  comparison, no web run, no text, no fills, no dashes;
- the new shader bundle's SHA-256.

- [ ] **Step 5: Update `STATUS.md`**

Header, TL;DR, the branch map and "Resume here". State commit ranges, **never a
commit count** — `STATUS.md` says why, and says it was wrong twice in one task
for exactly that reason.

- [ ] **Step 6: Final gate and commit**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
echo "exit=$?"
cd ../jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
echo "exit=$?"
cd ../../apps/dev_harness_2d && flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
echo "exit=$?"
cd ../.. && git status --short
git add docs STATUS.md
git commit -m "docs: Plan B's results, its gate, and where the project stands"
```

`git status --short` must show no `analysis_options.yaml`. If it does,
`git checkout --` all three before committing.

---

## Self-review

**Spec coverage.** Of the spec's fourteen mutations, this plan closes four —
the seam join, `_coveredArgb` on strokes, `point()` as its own kind, and joins
as collector geometry — plus the buffer-partition mutation reduced to this
plan's single buffer (M-B9). It establishes the instrument spec criterion 1
needs and prices the spec's 8 MB budget for the first time with joins in it.
Criteria 6-9, 11, 12 and 13 remain later plans'; criteria 3, 4 and 10 were
Plan A's and are untouched here.

**Placeholders.** None. Every code step carries the code. Two steps
deliberately end in a judgement rather than a value — Task 9 Step 4's first
failure and Task 10 Step 2's M-B10 — and both state what to report in each
case rather than what number to reach.

**Type consistency.** `StrokeFieldOffset` becomes `InstanceFieldOffset` in
Task 2 and every later reference uses the new name.
`kStrokeVertexLayout` becomes `kInstanceVertexLayout` in the same task.
`kFloatsPerInstance` is 12 from Task 2 on; `kFloatsPerCorner` is new and is 6.
`writeStroke`'s signature is unchanged; `writeJoin` and `writePoint` are new.
`GeometryCollector` gains `_coveredArgb`, `_beginRun`, `_runTo`, `_endRun`,
`_emitJoin`, `_flatten`, `_flattenSteps`, `kFlattenTolerance` and
`kMaxFlattenSegments`. `expandInstances` returns `ExpandedTriangles`;
`measureResidentAgreement` returns `ResidentAgreement`.

**Known risk, stated rather than discovered.** Task 9's
`measureResidentAgreement` assumes `TriangleRasterizer.observe` takes
`(Float32List positions, Int32List colors)` and that `inked(x, y)` is a
boolean coverage test. Both are read from the file's current signatures. Step 1
of that task exists to check them before the code is written, and the step says
in as many words to follow the file over this plan's sample.
