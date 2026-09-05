# GPU backend, Plan E — the text split, as patches

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The resident backend draws text — through the reference sink's own
paragraph path, over one render target — and restores emission order exactly
where later geometry covers a label, with a **patch** per such label, so that
the last op `GeometryCollector` still only counts is drawn, the criterion-8
corpus can finally contain text, and criterion 11 has a number.

**Architecture:** The collector writes a **resident text list** at rebuild —
one record per text op: the composed transform's six floats, the string, the
style handle, the colour, the instance index the op occurred at, and the
label's glyph box in collection space. A rebuild-time **classification** tests
every instance written *after* a label against that box (expanded by the
instance kind's reach at the band's lower scale bound) and gives each covered
label a **sub-buffer** of the instances that reach it, in emission order. Per
frame the main pass draws the whole buffer as today; each patch draws its
sub-buffer into a small **patch target** sized to the label's box; and a
GPU-free **compositor** walks the text list on the canvas in emission order —
`drawParagraph` for a plain label, `saveLayer` + paragraph + patch image with
`BlendMode.srcATop` for a patched one — so later geometry lands on the label's
ink and nowhere else. **No new shader, no new attribute, no new record
float.** The pixel instrument grows a *composited* differential that runs
both arms through Skia in `flutter test`, text included.

**Tech Stack:** Dart, Flutter 3.47.1, `flutter_scene` 0.23.0 (for its internal
`flutter_gpu` shim only), `flutter_test`, `dart:ui` `PictureRecorder` /
`Picture.toImage` for the composited differential.

**Spec:** [docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md](../specs/2026-08-29-gpu-resident-render-backend-design.md)
(**revision 5**, commit `d2095e7`), section **"Text: one render target, and a
patch where later geometry covers a label"**, plus the revision-5 paragraph at
the top, invariant 1, the budget row, the corpus and mutation list under
"Testing", and criterion 11. Read all of them before Task 1. This plan argues
from them and departs from them in exactly one place, Ruling E9, which is a
one-word correction in the spec's own conservative direction and is applied
to the spec in this plan's first commit.

**Predecessors:** [Plan A](2026-08-29-gpu-backend-plan-a-seam-and-strokes.md)
(`cd5bc98`), [Plan B](2026-08-30-gpu-backend-plan-b-joins-and-hairlines.md)
(`72b162d`), [Plan C](2026-08-31-gpu-backend-plan-c-shaded-dashes.md)
(`3a61b45`), [Plan D](2026-09-01-gpu-backend-plan-d-fills.md) (`de962bd`).
Ledgers at [docs/superpowers/ledgers/](../ledgers/). **Read Plan B's Ruling B6
before Task 5** — `test/support/instance_expander.dart` is a
statement-for-statement transcription of the vertex shader and this plan
reuses it unchanged on a sub-buffer.

**Reference implementation — two files, both unchanged:**
`packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart` (`text()` at
`:733-736`, `_flushBeforeUnbatchable` at `:647-650`) and
`packages/jet_cad_2d_flutter/lib/src/canvas_draw_sink.dart` (`text()` at
`:218-244` — the paragraph cache lookup and the baseline flip). The reference
*for text* is `VerticesDrawSink` with a `CanvasDrawSink` fallback: strokes as
triangles, text through `drawParagraph`, interleaved by the flush. **Neither
file is edited by this plan.**

---

## Where Plan E sits

| plan | delivers | state |
|---|---|---|
| A | the facade, the collector and buffer for **stroked polylines**, one draw call, the ordering and differential gates, the fallback | **merged** `cd5bc98` |
| B | joins, `point()`, `circle()`/`arc()`, the `_coveredArgb` hairline alpha | **merged** `72b162d` |
| C | dashes evaluated in the shader, at the live scale | **merged** `3a61b45` |
| D | fills, and the order gate they make testable | **merged** `de962bd` |
| **E (this one)** | **text, and the patch that keeps a covered label under what covers it** | this plan |
| F | the rebuild triggers, the reference scale, the band and the watermark; `DraftCanvas`'s `residentGpu` path | |
| G | web: CanvasKit and Skwasm | |

**Plan E closes five of the spec's pre-committed mutations** — *"draw all
text in one pass before or after the geometry"* and the four revision 5 added
beside it. It makes **criterion 8's corpus** finally satisfiable ("a corpus
containing text, fills, joins, caps, dashes and antialiasing — no waiver") and
gives **criterion 11** its first number. It does **not** wire `DraftCanvas`
(Plan F) and does **not** choose the band (Plan F); it takes the band as two
named provisional constants (Ruling E3).

---

## What is missing today, stated as a measurement rather than as a worry

`GeometryCollector` ends with one line:

```dart
  @override
  void text(String text, Handle style, ResolvedStyle resolved) => _skipped++;
```

(`geometry_collector.dart:708`.) A document with labels renders on the
resident arm with **no labels**, and `skippedOps` is the count. After Task 1
it is zero on any collector built with a measurer.

**The second thing missing is a test that can see text at all.** Every pixel
gate in `test/support/gpu_comparison.dart` rasterises triangles through
`TriangleRasterizer`, which has no notion of a paragraph. The reference draws
text through `drawParagraph`; so must the resident arm; so the instrument that
compares them must be Skia on both sides. Task 5 builds that instrument —
`measureCompositedAgreement` — and it is the first gate in this backend's
history that compares a *picture with text in it*.

**The third thing is the order.** The reference flushes its batch before every
text op (`_flushBeforeUnbatchable`), so a stroke emitted after a label draws
over it. With one texture and text composited on top, that stroke would draw
*under* the label. Revision 5's patch is the fix; Task 5's `text_order_test`
is the gate; and the mutation that turns the patch off — classify nothing,
draw all text on top — must go red there.

---

## Ten scope rulings, made here rather than left to an implementer

### Ruling E1 — a text record is an object, allocated at rebuild

`ResidentTextRecord` is a plain immutable class with final fields. It is
allocated by the collector at **rebuild**, which is not the frame path;
invariant 1 governs the frame, and the frame reads fields. A struct-of-arrays
layout would save nothing the invariant cares about and cost every reader a
stride calculation.

### Ruling E2 — the collector's measurer is optional, and without it text stays a counted skip

`GeometryCollector` gains two optional constructor arguments, `measurer`
(`TextMeasurer?`) and `textStyleOf` (`TextStyleRecord Function(Handle)?`),
the same pair `CanvasDrawSink` requires (`canvas_draw_sink.dart:17-25`). When
either is null, `text()` does exactly what it does today: `_skipped++`. Every
existing test and the harness keep compiling and keep their numbers; a
rebuild wired without a measurer shows as a non-zero `skippedOps`, which is
the same "a number, not a missing picture" discipline every earlier plan
used. The harness passes both in Task 7.

### Ruling E3 — the band is two provisional constants, owned by Plan F

`kBandLowerScale = 0.5` and `kBandUpperScale = 2.0`, declared in
`lib/src/gpu/text_patches.dart` with a doc that says Plan F owns them (spec
open question 3: *"the band is not pre-committed as a number"*). Every
function that depends on them takes them as **parameters with those
defaults**, so a test can pin either edge and Plan F can move them without
touching a call site. The classification expands the instance reach at the
**lower** bound (the conservative direction — a stroke that would touch the
label at any live scale inside the band is in the patch); the patch target is
sized at the **upper** bound (the largest device size the box reaches inside
the band).

### Ruling E4 — an instance's box is read per kind, and a point's box never includes the origin

`writePoint` writes `x1, y1, x2, y2` as **zero** (`instance_record.dart:236-
241`). A classifier that read all three point pairs for every kind would pull
every `point()`'s box to the origin and classify every label near the origin
as covered. So the box reads **2 points for a stroke, 3 for a join, 1 for a
point, 3 for a fill**, dispatched on `kind` with the same `< 0.5 / < 1.5 /
< 2.5 / else` chain the shader uses. Task 2 has a test whose point sits far
from the origin and whose label sits *at* the origin.

A dashed stroke's box is the **whole segment**, gaps included — that is what
the record carries, and over-inclusion is correct (spec: *"a candidate test,
not an ink test"*).

### Ruling E5 — the reach per kind, with the miter bound pinned

| kind | reach, device pixels |
|---|---|
| stroke, point | `halfWidth` |
| join | `halfWidth × kMiterLimit`, `kMiterLimit = 4.0` |
| fill | `0` |

The join bound is the shader's own: `_emitJoin` computes `reach = half /
cosHalf` (`vertices_draw_sink.dart:460`) and `kMinMiterCosine` is derived
from `kMiterLimit = 4.0` (`:544-552`) so that `cosHalf` never falls below
`1/4` on a miter — the tip is at most `4 × half` from the vertex. The
constant is **copied** into `text_patches.dart` (same independence rule as
`kMinStrokeDevicePixels`) and a test pins it to
`VerticesDrawSink.kMiterLimit` so the copy cannot drift silently.

Reach in collection units is `reachDevice / (devicePixelRatio ×
bandLowerScale)`: the buffer is in collection-camera logical pixels, one of
which is `devicePixelRatio` device pixels at the collection camera and
`devicePixelRatio × s` at live scale `s` relative to it; the largest
collection-unit reach inside the band is at `s = bandLowerScale`.

### Ruling E6 — the compositor is a GPU-free class, so the pixel gate runs in `flutter test`

`TextCompositor` (`lib/src/gpu/text_compositor.dart`) takes a `Canvas`, a
main `ui.Image?`, the text list, and a list of `PatchImage`s (a `ui.Image`
plus three `Rect`s each). It knows nothing about `flutter_gpu`. That is what
lets Task 5 build both arms in `flutter test`: the resident arm's images are
made by `expandInstances` (Ruling B6's shader transcription) drawn through
`Canvas.drawVertices` into a `Picture`, and the reference is the real
`VerticesDrawSink` + `CanvasDrawSink` pair — both rasterised by Skia. On a
device the same class composites the images `GpuDrawBackend` renders.

### Ruling E7 — `GpuDrawBackend.render` stays; `paint` is added beside it

`render(camera, viewport, dpr) → ui.Image?` keeps its signature and its
one-draw-call main pass, and additionally renders every patch target. The new
`paint(canvas, camera, viewport, dpr)` calls `render` then the compositor.
The harness moves to `paint` (Task 7). Nothing that calls `render` today
breaks.

### Ruling E8 — the patch pass's coordinate convention, transcribed from the spec

The region drawn is the label's box under the live camera, in **device
pixels**, intersected with the viewport, rounded **outward** to integers,
then clamped to the patch target's own size. It is rendered **anchored at the
patch target's origin**: `Viewport(0, 0, w, h)`, `Scissor(0, 0, w, h)`, and a
`FrameInfo` built from `Transform2.translation(-rx, -ry)` composed *outside*
`collectionToDevice`, with `w, h` as `widthPx, heightPx`. `flutter_gpu`'s
`Viewport` and `Scissor` throw on a negative origin
(`render_pass.dart:201-207, 229-235`); anchoring at the origin is what makes a
label half off the top-left edge drawable at all. Where the region sits on
screen is the compositor's business (its `dst` rect), never the pass's.

`patchRegionFor` is a pure function (Task 6) and is tested without a GPU,
including the negative-origin and the larger-than-target cases.

### Ruling E9 — the box padding is one device pixel at the band's **lower** bound, and the spec's "upper" is corrected

Revision 5 says the label box is *"padded by one device pixel at the band's
upper scale bound"*. The pad exists to cover antialiased glyph edges and glyph
overhang, both of which are device-pixel quantities; one device pixel is
**most** collection units at the band's *lower* scale, so the conservative
pad is `1 / (devicePixelRatio × bandLowerScale)` — the same direction the
spec's own reach argument takes one paragraph later. This plan's first commit
changes that one word in the spec (`upper` → `lower`) and cites this ruling;
the patch *target* is still sized at the upper bound, which is correct as
written.

### Ruling E10 — what criterion 11 measures, and what "text pass" means in the harness

Two runs of the spike corpus with `SPIKE_TEXT=true`, identical but for
`DRAW_TEXT=true` / `DRAW_TEXT=false`; the text pass is the **build and raster
p50 difference** per phase, arm C only. `DRAW_TEXT=false` makes the painter
emit no text op, so the collector records no text and classifies no patch —
the whole text path is off, nothing else moves (`DraftPainter.drawText`'s
own doc: *"this moves one branch"*). The gate is `≤ 0.5 ms` on the sum of the
two deltas. **The corpus must contain a patch whose later instance is a solid
stroke crossing the glyphs**, so Task 7 adds deliberate patched labels to the
spike corpus and the run reports their count; a run whose patch count is zero
measures nothing and says so.

---

## Global Constraints

Copied verbatim from `CLAUDE.md`, the spec, and Plans A–D. Every task's
requirements implicitly include this section.

- **The frame path allocates nothing per entity in steady state, and O(1) per
  flush.** Revision 5's stated exception: **a patch costs the engine one
  `saveLayer` and one `ui.Image` handle per frame**, per label later geometry
  reaches. The remaining per-patch Dart allocations are enumerated in
  `GpuDrawBackend`'s class doc and the spec's exception; nothing per
  instance, nothing per plain label. The compositor's
  matrix buffer and its three `Paint`s are fields, allocated once.
- **Draw order is emission order** — *not* "ascending handle value". **Never
  sort the buffer.** A patch's sub-buffer is a **subsequence** of the main
  buffer in the main buffer's order; the compositor walks the text list in
  list order; `classifyTextPatches` returns patches in ascending `textIndex`.
- **Geometric decisions use `Tolerance`; stored value comparisons are exact
  `==`.** The box-meets-box test is a geometric decision made with plain
  `<=`/`>=` on doubles, like `Aabb2.intersects`; it is conservative by
  construction and a tolerance would only widen it further.
- **Never commit `analysis_options.yaml`** — `flutter pub get` rewrites three
  of them in this workspace. Check `git status` before every commit and
  `git checkout --` them.
- **Never synthesize test output.** Run the command, paste what it printed,
  **including the exit code**. `dart format --set-exit-if-changed` printing
  `(1 changed)` **is** a failure even though the line looks informational.
- **Before firing a mutation, back the file up with `cp`, and restore from
  that copy.** Never `git checkout --` a file to revert a mutation.
- Code, comments and commit messages in English.
- **`packages/jet_cad_2d` is untouched by this plan.** `TextLayout`,
  `TextMeasurer`, `TextStyleRecord`, `Aabb2` are **read**, never edited.
- **`vertices_draw_sink.dart` and `canvas_draw_sink.dart` are untouched by
  this plan.** They are the oracle; editing either makes the composited
  differential circular.
- **No shader change.** `shaders/cad_stroke.vert`, `cad_stroke.frag` and
  `assets/shaders/cad.shaderbundle` are not touched: a patch pass runs the
  same pipeline on a sub-buffer. If an implementer finds a reason to touch
  the shader, that is a plan defect to ledger, not a change to make.
- **`ResolvedStyle` takes four required named arguments** — `argb`,
  `lineweightHundredths`, `linetype`, `linetypeScale`. Every literal in this
  plan spells all four.
- **`TextStyleRecord` in tests is spelled the way `canvas_draw_sink_test.dart:17`
  spells it:** `const TextStyleRecord(handle: Handle(11), name: 'Standard',
  fontFamily: 'Roboto')`.
- **Fonts in `flutter test` are not the device's fonts.** Every text pixel
  assertion in this plan finds its ink and non-ink sample points by
  rendering the label alone and reading alpha back — never by assuming a
  glyph shape. A test that hard-codes "pixel (12, 7) is ink" is a degenerate
  fixture with extra steps.
- Every task ends green:
  ```sh
  cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
  ```
  Tasks 7 and 9 additionally run:
  ```sh
  cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
  cd apps/dev_harness_2d && flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
  ```

## File structure

| file | responsibility |
|---|---|
| `lib/src/gpu/resident_text.dart` | **create** — `ResidentTextRecord` |
| `lib/src/gpu/text_patches.dart` | **create** — `kBandLowerScale`, `kBandUpperScale`, `kTextBoxPadDevicePixels`, `kMiterLimit`, `TextPatch`, `classifyTextPatches`, `patchTargetSizeFor`, `patchRegionFor` |
| `lib/src/gpu/text_compositor.dart` | **create** — `PatchImage`, `TextCompositor` |
| `lib/src/gpu/geometry_collector.dart` | **modify** — `measurer`, `textStyleOf`, `text()`, `texts` |
| `lib/src/gpu/resident_geometry.dart` | **modify** — `texts`, `patches` (`ResidentPatch`), `byteLength` includes sub-buffers, `patchTargetBytes` |
| `lib/src/gpu/gpu_draw_backend.dart` | **modify** — patch passes in `render`, new `paint` |
| `lib/jet_cad_2d_flutter.dart` | **modify** — export `resident_text.dart`, `text_patches.dart`, `text_compositor.dart` |
| `test/support/fixtures.dart` | **modify** — `textOverlapFixture()` |
| `test/support/fixtures_test.dart` | **modify** — the corpus's non-degeneracy guards |
| `test/support/gpu_comparison.dart` | **modify** — `CompositedAgreement`, `measureCompositedAgreement` |
| `test/gpu/resident_text_test.dart` | **create** — the collector's text records |
| `test/gpu/text_patches_test.dart` | **create** — classification, reach, band, region, target size |
| `test/gpu/text_compositor_test.dart` | **create** — the composite, pixel-checked through Skia |
| `test/gpu/text_order_test.dart` | **create** — spec mutation *"draw all text in one pass"* and the four-scale label |
| `test/gpu/resident_geometry_test.dart` | **modify** — byte length with sub-buffers |
| `apps/dev_harness_2d/lib/main.dart` | **modify** — `SPIKE_TEXT`, `_addPatchedLabels`, `drawText` to the spike app |
| `apps/dev_harness_2d/lib/gpu_arm.dart` | **modify** — measurer wiring, `paint`, GSPIKE lines |
| `apps/dev_harness_2d/test/spike_text_test.dart` | **create** — `SPIKE_TEXT` inert at default; patched labels are patches |
| `.vscode/launch.json` | **modify** — two text runs, `DRAW_TEXT` on and off |
| `docs/superpowers/notes/plan-e-mutation-log.md` | **create** |
| `docs/superpowers/notes/2026-09-04-plan-e-results.md` | **create** |
| `docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md` | **modify** — the one word of Ruling E9 |
| `STATUS.md` | **modify** |

All paths under `lib/` and `test/` are relative to `packages/jet_cad_2d_flutter/`.

---

## The text record, restated so no task restates it from memory

```dart
class ResidentTextRecord {
  const ResidentTextRecord({
    required this.text,
    required this.style,
    required this.argb,
    required this.a, required this.b, required this.c,
    required this.d, required this.e, required this.f,
    required this.boxMinX, required this.boxMinY,
    required this.boxMaxX, required this.boxMaxY,
    required this.instanceIndex,
  });
  final String text;
  final Handle style;          // the text style handle -- the paragraph cache key's second field
  final int argb;              // `resolved.argb` -- the cache key's third field
  final double a, b, c, d, e, f; // the residual the painter pushed: glyph space -> collection space
  final double boxMinX, boxMinY, boxMaxX, boxMaxY; // glyph box in collection space, padded (Ruling E9)
  final int instanceIndex;     // instances written BEFORE this op; instances >= this index are "after"
}
```

The residual is `chain ∘ textLocal` (`draft_painter.dart:960-966`): glyph
space, y up, origin on the baseline. `CanvasDrawSink.text` reconciles that with
`drawParagraph`'s y-down paragraph space by `translate(0, baseline); scale(1,
-1)` — the compositor does exactly the same, in Task 4.

---

### Task 1: The collector records text, and the spec's one word

**Files:**
- Create: `lib/src/gpu/resident_text.dart`
- Modify: `lib/src/gpu/geometry_collector.dart` (constructor, fields, `skippedOps` doc, `text()`)
- Modify: `lib/jet_cad_2d_flutter.dart` (export)
- Modify: `docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md` (Ruling E9's one word)
- Test: `test/gpu/resident_text_test.dart`

**Interfaces:**
- Consumes: `TextMeasurer.measure({text, style})`, `TextLayout.layOutBox(metrics)`
  (`packages/jet_cad_2d/lib/src/document/text_geometry.dart:231`), the collector's
  `_residual`, `_instances`, `devicePixelRatio`.
- Produces: `ResidentTextRecord` (the class restated above);
  `GeometryCollector({..., TextMeasurer? measurer, TextStyleRecord Function(Handle)? textStyleOf})`;
  `List<ResidentTextRecord> get texts` (unmodifiable view); `text()` records
  when both are non-null, counts otherwise (Ruling E2). This task also creates
  `lib/src/gpu/text_patches.dart` holding only the four constants (Step 4);
  Task 2 adds the functions to that same file, so each constant is declared
  exactly once.

- [ ] **Step 1: The spec's one word (Ruling E9)**

In the spec's text section, the sentence *"padded by one device pixel at the
band's upper scale bound so antialiased glyph edges and glyph overhang past the
advance box are inside it"* becomes *"padded by one device pixel at the band's
**lower** scale bound (Plan E's Ruling E9 — one device pixel is most collection
units at the band's floor, the same direction the reach takes) so antialiased
glyph edges and glyph overhang past the advance box are inside it"*. Use a
script with an exact-match assertion, not a hand edit:

```sh
python3 - <<'PY'
p = 'docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md'
s = open(p).read()
old = ("padded by one\n  device pixel at the band's upper scale bound so antialiased glyph edges and\n  glyph overhang past the advance box are inside it.")
assert s.count(old) == 1, s.count(old)
new = ("padded by one\n  device pixel at the band's **lower** scale bound (Plan E's Ruling E9 -- one\n  device pixel is most collection units at the band's floor, the same direction\n  the reach takes) so antialiased glyph edges and glyph overhang past the\n  advance box are inside it.")
open(p, 'w').write(s.replace(old, new))
print('ok')
PY
```

If the assertion fails, read the spec's current wording and adjust `old` — do
not skip the step.

- [ ] **Step 2: Write the failing tests**

Create `test/gpu/resident_text_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_flutter/src/gpu/text_patches.dart';

const TextStyleRecord _standard =
    TextStyleRecord(handle: Handle(11), name: 'Standard', fontFamily: 'Roboto');

/// Fixed metrics, so the box below is arithmetic rather than font trivia:
/// advance 40, ascent 8, descent 2 -> glyph box (0, -2) .. (40, 8).
class _FixedMeasurer implements TextMeasurer {
  const _FixedMeasurer();
  @override
  TextMetrics measure({required String text, required TextStyleRecord style}) =>
      const TextMetrics(advanceWidth: 40, ascent: 8, descent: 2, capHeight: 7);
}

const ResolvedStyle _style = ResolvedStyle(
    argb: 0xFF112233,
    lineweightHundredths: 25,
    linetype: Handle.none,
    linetypeScale: 1);

GeometryCollector _collector({double dpr = 2.0}) => GeometryCollector(
    pixelsPerPaperMm: 3.78,
    devicePixelRatio: dpr,
    measurer: const _FixedMeasurer(),
    textStyleOf: (Handle h) => _standard);

void main() {
  test('a text op becomes one record carrying the residual, flat', () {
    final c = _collector();
    // Rotated, sheared, non-uniform, off-origin: an identity residual would
    // leave b == c == 0 and hide a transposed element.
    const t = Transform2(2, 3, 5, 7, 110, -40);
    c.beginResidual(t, debugHandle: const Handle(901));
    c.text('WC', const Handle(11), _style);
    c.endResidual();

    expect(c.texts, hasLength(1));
    expect(c.skippedOps, 0, reason: 'text is recorded now, not counted');
    final r = c.texts.single;
    expect(r.text, 'WC');
    expect(r.style, const Handle(11));
    expect(r.argb, 0xFF112233);
    expect([r.a, r.b, r.c, r.d, r.e, r.f], [2, 3, 5, 7, 110, -40]);
  });

  test('the instance index is the number of instances written before it', () {
    final c = _collector();
    c.beginResidual(Transform2.translation(10, 10));
    c.polyline(Float64List.fromList([0, 0, 50, 0, 50, 40]), 3, _style,
        closed: false);
    c.endResidual();
    final before = c.instanceCount;
    expect(before, greaterThan(0));
    c.beginResidual(Transform2.translation(20, 20));
    c.text('A', const Handle(11), _style);
    c.endResidual();
    c.beginResidual(Transform2.translation(10, 10));
    c.polyline(Float64List.fromList([0, 0, 5, 5]), 2, _style, closed: false);
    c.endResidual();
    expect(c.texts.single.instanceIndex, before,
        reason: 'instances at or past this index were emitted AFTER the label');
  });

  test('the box is the four transformed corners, padded at the band floor', () {
    // dpr 2, band floor 0.5: one device pixel is 1 / (2 * 0.5) = 1.0
    // collection unit of padding.
    final c = _collector(dpr: 2.0);
    // A pure rotation by 90 degrees about the origin, then a translation:
    // glyph box (0,-2)..(40,8) rotates to (-8,0)..(2,40), so a classifier
    // that transformed only min and max corners (instead of all four) gets
    // a box with a negative width.
    final t = Transform2.translation(100, 200)
        .multiply(Transform2.rotation(3.141592653589793 / 2));
    c.beginResidual(t);
    c.text('WC', const Handle(11), _style);
    c.endResidual();
    final r = c.texts.single;
    expect(r.boxMinX, closeTo(100 - 8 - 1, 1e-6));
    expect(r.boxMaxX, closeTo(100 + 2 + 1, 1e-6));
    expect(r.boxMinY, closeTo(200 + 0 - 1, 1e-6));
    expect(r.boxMaxY, closeTo(200 + 40 + 1, 1e-6));
  });

  test('the pad is one device pixel at the band floor, not at the ceiling', () {
    // The pad must be the LARGEST one device pixel is inside the band:
    // 1 / (dpr * kBandLowerScale). At dpr 1 and floor 0.5 that is 2.0
    // collection units; a pad taken at the ceiling would be 0.5.
    final c = _collector(dpr: 1.0);
    c.beginResidual(Transform2.identity());
    c.text('WC', const Handle(11), _style);
    c.endResidual();
    final r = c.texts.single;
    expect(r.boxMinX, closeTo(0 - 1 / (1.0 * kBandLowerScale), 1e-9));
    expect(r.boxMaxX, closeTo(40 + 1 / (1.0 * kBandLowerScale), 1e-9));
  });

  test('a mirrored residual still yields min <= max', () {
    final c = _collector();
    c.beginResidual(const Transform2(-1, 0, 0, 1, 0, 0));
    c.text('WC', const Handle(11), _style);
    c.endResidual();
    final r = c.texts.single;
    expect(r.boxMinX, lessThan(r.boxMaxX));
    expect(r.boxMinX, closeTo(-40 - 1, 1e-6));
  });

  test('without a measurer, text is counted and not recorded (Ruling E2)', () {
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 1.0);
    c.beginResidual(Transform2.identity());
    c.text('WC', const Handle(11), _style);
    c.endResidual();
    expect(c.texts, isEmpty);
    expect(c.skippedOps, 1);
  });

  test('the text list is in emission order and is not sortable by handle', () {
    final c = _collector();
    for (final s in ['C', 'A', 'B']) {
      c.beginResidual(Transform2.identity());
      c.text(s, const Handle(11), _style);
      c.endResidual();
    }
    expect(c.texts.map((r) => r.text), ['C', 'A', 'B']);
    expect(() => c.texts.add(c.texts.first), throwsUnsupportedError,
        reason: 'the list handed out is a view; nobody reorders it');
  });

  test('the band constants and the pad are what the spec says', () {
    expect(kBandLowerScale, 0.5);
    expect(kBandUpperScale, 2.0);
    expect(kTextBoxPadDevicePixels, 1.0);
    expect(kMiterLimit, VerticesDrawSink.kMiterLimit,
        reason: 'a copy, pinned to the oracle so it cannot drift');
  });
}
```

- [ ] **Step 3: Run them and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/resident_text_test.dart
```
Expected: a compile error — `text_patches.dart` does not exist, `texts` and
`measurer` are not defined.

- [ ] **Step 4: Create `lib/src/gpu/text_patches.dart` with the constants only**

```dart
import 'dart:typed_data';

import 'instance_record.dart';
import 'resident_text.dart';

/// **Provisional, and Plan F's to move.** The spec leaves the watermark band
/// un-committed as a number (open question 3); Plan E needs a floor to expand
/// an instance's reach at and a ceiling to size a patch target at, and takes
/// these two until Plan F measures the band. Every function in this file
/// takes them as parameters with these defaults, so a test can pin either
/// edge and Plan F can move them without touching a call site.
const double kBandLowerScale = 0.5;
const double kBandUpperScale = 2.0;

/// The label box is padded by this many device pixels, taken at the band's
/// LOWER scale (Ruling E9): one device pixel is most collection units at the
/// band's floor, so that is the conservative pad. It covers antialiased glyph
/// edges and glyph overhang past the advance box.
const double kTextBoxPadDevicePixels = 1.0;

/// The miter limit the shader's join branch is bounded by -- a miter tip is
/// never further than `halfWidth * kMiterLimit` from its vertex
/// (`vertices_draw_sink.dart:460, 544-552`). **A copy, not a reference**, by
/// the same rule `GeometryCollector.kMinStrokeDevicePixels` states: the two
/// arms arrive at their numbers separately and the differential is what
/// catches a drift. `resident_text_test.dart` pins this to
/// `VerticesDrawSink.kMiterLimit`.
const double kMiterLimit = 4.0;
```

(The two imports are unused until Task 2 adds the functions; `dart analyze`
flags unused imports as **info**, not error, so this task's gate stays green.
If it does not on this toolchain, leave the imports out and Task 2 adds them.)

- [ ] **Step 5: Create `lib/src/gpu/resident_text.dart`**

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart';

/// One text op, as the resident backend keeps it between rebuilds.
///
/// **Allocated at rebuild, read on the frame** (Ruling E1). The frame walks
/// the list and reads fields; nothing here is built per frame.
///
/// [a]..[f] are the residual the painter pushed for this op -- `chain ∘
/// textLocal` (`draft_painter.dart:960-966`), glyph space (y up, origin on
/// the baseline) to **collection** space. Stored flat rather than as a
/// `Transform2` so a frame never composes one per op (invariant 1).
///
/// [boxMinX]..[boxMaxY] is the label's glyph box in collection space: the
/// four corners of `TextLayout.layOutBox`'s box under the residual,
/// re-bounded (a rotated label's axis-aligned bound), padded by
/// `kTextBoxPadDevicePixels` at the band's floor (Ruling E9).
///
/// [instanceIndex] is the number of instances the collector had written when
/// this op arrived. Instances at or past it were emitted **after** the
/// label; that index is the whole basis of `classifyTextPatches`.
class ResidentTextRecord {
  const ResidentTextRecord({
    required this.text,
    required this.style,
    required this.argb,
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.e,
    required this.f,
    required this.boxMinX,
    required this.boxMinY,
    required this.boxMaxX,
    required this.boxMaxY,
    required this.instanceIndex,
  });

  final String text;
  final Handle style;
  final int argb;
  final double a, b, c, d, e, f;
  final double boxMinX, boxMinY, boxMaxX, boxMaxY;
  final int instanceIndex;
}
```

- [ ] **Step 6: The collector**

In `geometry_collector.dart`:

Add imports:
```dart
import 'resident_text.dart';
import 'text_patches.dart';
```

Extend the constructor and fields:
```dart
  GeometryCollector({
    required this.pixelsPerPaperMm,
    required this.devicePixelRatio,
    this.lineweightScale = 1.0,
    this.measurer,
    this.textStyleOf,
  });

  /// The measurer the label's glyph box is read through, and the style
  /// lookup its `fontFamily` comes from -- the same pair `CanvasDrawSink`
  /// requires. **Optional (Ruling E2):** with either null, [text] counts the
  /// op in [skippedOps] exactly as it did before Plan E, so a collector wired
  /// without a measurer shows as a number rather than a missing picture.
  final TextMeasurer? measurer;
  final TextStyleRecord Function(Handle)? textStyleOf;

  final List<ResidentTextRecord> _texts = <ResidentTextRecord>[];

  /// Reused per text op, never per frame: `TextLayout` is caller-owned and
  /// refilled in place (`text_geometry.dart`'s own ownership rule).
  final TextLayout _textLayout = TextLayout();

  /// Every text op this walk recorded, in emission order. A view: the list
  /// is the draw order and nobody reorders it.
  List<ResidentTextRecord> get texts => List.unmodifiable(_texts);
```

`List.unmodifiable` copies; it is called by tests and once per rebuild by the
harness, never per frame — but say so in the doc comment above, the way
`data`'s doc does.

Replace `skippedOps`'s doc:
```dart
  /// Ops this walk could not draw. **Zero on a collector built with a
  /// measurer**, since Plan E: `text` was the last op counted here, and it
  /// now records a [ResidentTextRecord] instead -- unless [measurer] or
  /// [textStyleOf] is null (Ruling E2), in which case it still counts.
  int get skippedOps => _skipped;
```

Replace `text()`:
```dart
  /// Records the label for the compositor (Plan E); draws nothing itself.
  ///
  /// The glyph box is `TextLayout.layOutBox` on the same `measure` the
  /// reference sink's paragraph is laid out against, taken through all four
  /// corners of the residual so a rotated, sheared or mirrored label bounds
  /// correctly (`Aabb2.transformedBy`'s own rule, written out here to avoid
  /// allocating two `Aabb2`s and four `Vector2`s per label at rebuild --
  /// cheap, but this method is on the walk and the walk is measured).
  @override
  void text(String text, Handle style, ResolvedStyle resolved) {
    final measurer = this.measurer;
    final textStyleOf = this.textStyleOf;
    if (measurer == null || textStyleOf == null) {
      _skipped++;
      return;
    }
    _textLayout.layOutBox(measurer.measure(text: text, style: textStyleOf(style)));
    final t = _residual;
    final x0 = _textLayout.minX, y0 = _textLayout.minY;
    final x1 = _textLayout.maxX, y1 = _textLayout.maxY;
    var minX = double.infinity, minY = double.infinity;
    var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    void corner(double x, double y) {
      final cx = t.a * x + t.c * y + t.e, cy = t.b * x + t.d * y + t.f;
      if (cx < minX) minX = cx;
      if (cx > maxX) maxX = cx;
      if (cy < minY) minY = cy;
      if (cy > maxY) maxY = cy;
    }
    corner(x0, y0);
    corner(x1, y0);
    corner(x0, y1);
    corner(x1, y1);
    // Ruling E9: one device pixel at the band's FLOOR, the most collection
    // units a device pixel is anywhere inside the band.
    final pad = kTextBoxPadDevicePixels / (devicePixelRatio * kBandLowerScale);
    _texts.add(ResidentTextRecord(
      text: text,
      style: style,
      argb: resolved.argb,
      a: t.a, b: t.b, c: t.c, d: t.d, e: t.e, f: t.f,
      boxMinX: minX - pad,
      boxMinY: minY - pad,
      boxMaxX: maxX + pad,
      boxMaxY: maxY + pad,
      instanceIndex: _instances,
    ));
  }
```

`resolved.argb` **directly, never `_coveredArgb`** — a label has no stroke
width; the reference passes `resolved.argb` to `paragraphFor`
(`canvas_draw_sink.dart:221`).

Add to `lib/jet_cad_2d_flutter.dart`:
```dart
export 'src/gpu/resident_text.dart';
export 'src/gpu/text_patches.dart';
```

- [ ] **Step 7: Run the tests**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/resident_text_test.dart
```
Expected: all eight PASS. Then the whole suite, analyze, format.

- [ ] **Step 8: Commit**

```sh
git status --short   # no analysis_options.yaml
git add docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md \
  packages/jet_cad_2d_flutter/lib/src/gpu/resident_text.dart \
  packages/jet_cad_2d_flutter/lib/src/gpu/text_patches.dart \
  packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart \
  packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart \
  packages/jet_cad_2d_flutter/test/gpu/resident_text_test.dart
git commit -m "feat(gpu): the collector records text as a resident list"
```

---

### Task 2: The classification — which labels are covered, and by what

**Files:**
- Modify: `lib/src/gpu/text_patches.dart` (add `TextPatch`, `classifyTextPatches`)
- Test: `test/gpu/text_patches_test.dart`

**Interfaces:**
- Consumes: `ResidentTextRecord` (Task 1), `kFloatsPerInstance`,
  `InstanceFieldOffset`, `kKindStroke/Join/Point/Fill`, `kMiterLimit`,
  `kBandLowerScale`.
- Produces:
  ```dart
  class TextPatch {
    const TextPatch({required this.textIndex, required this.instances, required this.instanceCount});
    final int textIndex;          // index into the text list
    final Float32List instances;  // a sub-buffer: kFloatsPerInstance * instanceCount floats, main-buffer order
    final int instanceCount;
  }
  List<TextPatch> classifyTextPatches(
      Float32List data, int instanceCount, List<ResidentTextRecord> texts,
      {required double devicePixelRatio, double bandLowerScale = kBandLowerScale});
  ```
  Returned in ascending `textIndex`; a label nothing reaches has no entry.

- [ ] **Step 1: Write the failing tests**

Create `test/gpu/text_patches_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

/// A label with a box and an index -- nothing else matters to the classifier.
ResidentTextRecord _label(
        {required double minX,
        required double minY,
        required double maxX,
        required double maxY,
        required int at}) =>
    ResidentTextRecord(
        text: 'L',
        style: const Handle(11),
        argb: 0xFF000000,
        a: 1, b: 0, c: 0, d: 1, e: 0, f: 0,
        boxMinX: minX, boxMinY: minY, boxMaxX: maxX, boxMaxY: maxY,
        instanceIndex: at);

/// A buffer built record by record through the real writers, so the
/// classifier is read against the layout the shader reads, not a hand-rolled
/// one.
class _Buf {
  final Float32List data = Float32List(kFloatsPerInstance * 32);
  int count = 0;
  void stroke(double x0, double y0, double x1, double y1, {double half = 1}) {
    writeStroke(data, count++,
        x0: x0, y0: y0, x1: x1, y1: y1, halfWidth: half, argb: 0xFF000000);
  }
  void join(double vx, double vy, double px, double py, double nx, double ny,
      {double half = 1}) {
    writeJoin(data, count++,
        vx: vx, vy: vy, prevX: px, prevY: py, nextX: nx, nextY: ny,
        halfWidth: half, argb: 0xFF000000);
  }
  void point(double x, double y, {double half = 1}) {
    writePoint(data, count++, x: x, y: y, halfWidth: half, argb: 0xFF000000);
  }
  void fill(double x0, double y0, double x1, double y1, double x2, double y2) {
    writeFill(data, count++,
        x0: x0, y0: y0, x1: x1, y1: y1, x2: x2, y2: y2, argb: 0xFF000000);
  }
}

void main() {
  // dpr 1, band floor 1: reach in collection units == reach in device pixels,
  // so every number below is readable without a conversion. Tests that are
  // ABOUT the conversion pass their own floor.
  const dpr = 1.0;
  const floor = 1.0;

  test('an instance emitted after the label and crossing its box is a patch',
      () {
    final b = _Buf()
      ..stroke(0, 0, 10, 0) // index 0: before the label
      ..stroke(0, 50, 100, 50); // index 1: after, crosses the box
    final texts = [_label(minX: 40, minY: 40, maxX: 60, maxY: 60, at: 1)];
    final patches = classifyTextPatches(b.data, b.count, texts,
        devicePixelRatio: dpr, bandLowerScale: floor);
    expect(patches, hasLength(1));
    expect(patches.single.textIndex, 0);
    expect(patches.single.instanceCount, 1);
    // The sub-buffer is a verbatim copy of record 1, all sixteen floats.
    final sub = patches.single.instances;
    for (var i = 0; i < kFloatsPerInstance; i++) {
      expect(sub[i], b.data[kFloatsPerInstance + i], reason: 'float $i');
    }
  });

  test('an instance emitted BEFORE the label never enters its patch', () {
    final b = _Buf()
      ..stroke(0, 50, 100, 50) // crosses the box, but index 0 < 1
      ..stroke(0, 0, 10, 0);
    final texts = [_label(minX: 40, minY: 40, maxX: 60, maxY: 60, at: 1)];
    expect(
        classifyTextPatches(b.data, b.count, texts,
            devicePixelRatio: dpr, bandLowerScale: floor),
        isEmpty,
        reason: 'the reference draws it under the label; so must we');
  });

  test('a label nothing reaches has no patch, and one that is reached does',
      () {
    final b = _Buf()
      ..stroke(0, 50, 100, 50); // index 0
    final texts = [
      _label(minX: 40, minY: 40, maxX: 60, maxY: 60, at: 0), // reached
      _label(minX: 40, minY: 400, maxX: 60, maxY: 420, at: 0), // not
    ];
    final patches = classifyTextPatches(b.data, b.count, texts,
        devicePixelRatio: dpr, bandLowerScale: floor);
    expect(patches.map((p) => p.textIndex), [0]);
  });

  test('a stroke whose centerline misses the box but whose width reaches it '
      'is a patch', () {
    // Centerline at y = 65, box top at 60, half-width 6: the stroke's lower
    // edge is at 59, inside the box. A classifier that tested the centerline
    // (reach 0) would miss it.
    final b = _Buf()..stroke(0, 65, 100, 65, half: 6);
    final texts = [_label(minX: 40, minY: 40, maxX: 60, maxY: 60, at: 0)];
    expect(
        classifyTextPatches(b.data, b.count, texts,
            devicePixelRatio: dpr, bandLowerScale: floor),
        hasLength(1));
    // And with half-width 4 (edge at 61) it is not.
    final n = _Buf()..stroke(0, 65, 100, 65, half: 4);
    expect(
        classifyTextPatches(n.data, n.count, texts,
            devicePixelRatio: dpr, bandLowerScale: floor),
        isEmpty);
  });

  test("a join's reach is the miter bound, 4 x half-width", () {
    // Vertex at (50, 70), box top at 60: distance 10. Half-width 3 reaches
    // 12 with the miter bound (in), and 3 without it (out).
    final b = _Buf()..join(50, 70, 0, 70, 100, 70, half: 3);
    final texts = [_label(minX: 40, minY: 40, maxX: 60, maxY: 60, at: 0)];
    expect(
        classifyTextPatches(b.data, b.count, texts,
            devicePixelRatio: dpr, bandLowerScale: floor),
        hasLength(1),
        reason: 'reach = half * kMiterLimit = 12 >= 10');
    final far = _Buf()..join(50, 73, 0, 73, 100, 73, half: 3);
    expect(
        classifyTextPatches(far.data, far.count, texts,
            devicePixelRatio: dpr, bandLowerScale: floor),
        isEmpty,
        reason: '12 < 13');
  });

  test('a fill has no reach: its corners are the whole of it', () {
    final b = _Buf()..fill(0, 61, 100, 61, 50, 90); // 1 unit above the box
    final texts = [_label(minX: 40, minY: 40, maxX: 60, maxY: 60, at: 0)];
    expect(
        classifyTextPatches(b.data, b.count, texts,
            devicePixelRatio: dpr, bandLowerScale: floor),
        isEmpty);
  });

  test("a point's box is its one point -- never the origin (Ruling E4)", () {
    // The point is far from the label; the label sits AT the origin, where
    // `writePoint`'s zeroed x1, y1, x2, y2 would land if they were read.
    final b = _Buf()..point(500, 500, half: 2);
    final texts = [_label(minX: -5, minY: -5, maxX: 5, maxY: 5, at: 0)];
    expect(
        classifyTextPatches(b.data, b.count, texts,
            devicePixelRatio: dpr, bandLowerScale: floor),
        isEmpty);
    final near = _Buf()..point(6, 0, half: 2);
    expect(
        classifyTextPatches(near.data, near.count, texts,
            devicePixelRatio: dpr, bandLowerScale: floor),
        hasLength(1));
  });

  test('the reach is expanded at the band floor, in collection units', () {
    // Half-width 4 device px; dpr 2; floor 0.5: reach = 4 / (2 * 0.5) = 4.0
    // collection units. Centerline 3.5 above the box: in at the floor, out
    // if expanded at the reference scale (4 / 2 = 2.0).
    final b = _Buf()..stroke(0, 63.5, 100, 63.5, half: 4);
    final texts = [_label(minX: 40, minY: 40, maxX: 60, maxY: 60, at: 0)];
    expect(
        classifyTextPatches(b.data, b.count, texts,
            devicePixelRatio: 2.0, bandLowerScale: 0.5),
        hasLength(1));
    expect(
        classifyTextPatches(b.data, b.count, texts,
            devicePixelRatio: 2.0, bandLowerScale: 1.0),
        isEmpty,
        reason: 'expanding at the reference scale is the named mutation');
  });

  test('a sub-buffer keeps main-buffer order and skips non-reaching instances',
      () {
    final b = _Buf()
      ..stroke(0, 50, 100, 50) // 0 in
      ..stroke(0, 500, 100, 500) // 1 out
      ..stroke(50, 0, 50, 100) // 2 in
      ..stroke(0, 45, 100, 45); // 3 in
    final texts = [_label(minX: 40, minY: 40, maxX: 60, maxY: 60, at: 0)];
    final p = classifyTextPatches(b.data, b.count, texts,
            devicePixelRatio: dpr, bandLowerScale: floor)
        .single;
    expect(p.instanceCount, 3);
    double y0(int k) => p.instances[k * kFloatsPerInstance + InstanceFieldOffset.y0];
    expect([y0(0), y0(1), y0(2)], [50, 0, 45],
        reason: 'emission order, not sorted, not reversed');
  });

  test('patches come back in ascending text index, one per covered label', () {
    final b = _Buf()
      ..stroke(0, 50, 100, 50) // 0
      ..stroke(0, 250, 100, 250); // 1
    final texts = [
      _label(minX: 40, minY: 240, maxX: 60, maxY: 260, at: 0), // hit by 1
      _label(minX: 40, minY: 40, maxX: 60, maxY: 60, at: 0), // hit by 0
    ];
    final patches = classifyTextPatches(b.data, b.count, texts,
        devicePixelRatio: dpr, bandLowerScale: floor);
    expect(patches.map((p) => p.textIndex), [0, 1]);
  });

  test('a dashed stroke is a candidate over its whole segment, gaps included',
      () {
    final b = _Buf();
    writeStroke(b.data, b.count++,
        x0: 0, y0: 50, x1: 100, y1: 50, halfWidth: 1, argb: 0xFF000000,
        dashPeriod: -20, dashPhase: 0, dashFracStart: 0.0, dashFracEnd: 0.1);
    final texts = [_label(minX: 40, minY: 40, maxX: 60, maxY: 60, at: 0)];
    expect(
        classifyTextPatches(b.data, b.count, texts,
            devicePixelRatio: dpr, bandLowerScale: floor),
        hasLength(1),
        reason: 'the record carries the segment; over-inclusion is correct');
  });
}
```

- [ ] **Step 2: Run and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/text_patches_test.dart
```
Expected: compile error — `TextPatch`, `classifyTextPatches` undefined.

- [ ] **Step 3: Implement, in `text_patches.dart`**

```dart
/// A label some later instance reaches, and the instances that reach it.
///
/// [instances] is a **subsequence** of the main buffer in the main buffer's
/// order -- `kFloatsPerInstance * instanceCount` floats, copied record by
/// record. Draw order is emission order (CLAUDE.md), and a patch is drawn
/// from this alone, so its order is the main buffer's or the patch draws a
/// different picture from the reference.
class TextPatch {
  const TextPatch(
      {required this.textIndex,
      required this.instances,
      required this.instanceCount});

  final int textIndex;
  final Float32List instances;
  final int instanceCount;
}

/// Classifies every label in [texts] against every instance written after
/// it, in collection space -- the spec's "conservative, box on box" test.
///
/// For each label, instances `[instanceIndex, instanceCount)` are tested:
/// the instance's own points (per kind, Ruling E4), expanded by the kind's
/// reach (Ruling E5) at the band's **lower** scale bound, meet the label's
/// box or they do not. A label at least one instance meets is a [TextPatch]
/// whose sub-buffer is exactly those instances, in order.
///
/// **A candidate test, not an ink test.** A stroke through the whitespace
/// between two glyphs, or a dashed instance whose gap crosses the box, is a
/// candidate although no pixel of it covers label ink. Over-inclusion is
/// correct -- `TextCompositor` makes an unneeded patch a no-op -- and its
/// cost is what criterion 11 measures.
///
/// Cost: `labels x later instances` box tests in `double`, at rebuild.
/// Reported by the harness against criterion 7's budget (Task 7).
List<TextPatch> classifyTextPatches(
  Float32List data,
  int instanceCount,
  List<ResidentTextRecord> texts, {
  required double devicePixelRatio,
  double bandLowerScale = kBandLowerScale,
}) {
  // Collection units per device pixel, at the band's floor -- the LARGEST
  // a device-pixel reach is anywhere inside the band.
  final unitsPerDevicePixel = 1.0 / (devicePixelRatio * bandLowerScale);
  final patches = <TextPatch>[];
  final hits = <int>[];
  for (var ti = 0; ti < texts.length; ti++) {
    final t = texts[ti];
    hits.clear();
    for (var i = t.instanceIndex; i < instanceCount; i++) {
      if (_reaches(data, i, t, unitsPerDevicePixel)) hits.add(i);
    }
    if (hits.isEmpty) continue;
    final sub = Float32List(hits.length * kFloatsPerInstance);
    for (var k = 0; k < hits.length; k++) {
      sub.setRange(k * kFloatsPerInstance, (k + 1) * kFloatsPerInstance, data,
          hits[k] * kFloatsPerInstance);
    }
    patches.add(
        TextPatch(textIndex: ti, instances: sub, instanceCount: hits.length));
  }
  return patches;
}

/// Whether instance [i]'s reach-expanded box meets [t]'s box.
///
/// Points per kind (Ruling E4): a stroke's two, a join's three, a point's
/// ONE -- `writePoint` zeroes the other slots and reading them would pull
/// every point's box to the origin -- a fill's three. Reach per kind
/// (Ruling E5): half-width for a stroke and a point, `halfWidth *
/// kMiterLimit` for a join, nothing for a fill. The kind dispatch is the
/// shader's own chain of `<` comparisons.
bool _reaches(
    Float32List d, int i, ResidentTextRecord t, double unitsPerDevicePixel) {
  final o = i * kFloatsPerInstance;
  final kind = d[o + InstanceFieldOffset.kind];
  final half = d[o + InstanceFieldOffset.halfWidth];
  final int points;
  final double reachDevice;
  if (kind < 0.5) {
    points = 2;
    reachDevice = half;
  } else if (kind < 1.5) {
    points = 3;
    reachDevice = half * kMiterLimit;
  } else if (kind < 2.5) {
    points = 1;
    reachDevice = half;
  } else {
    points = 3;
    reachDevice = 0;
  }
  final reach = reachDevice * unitsPerDevicePixel;
  var minX = double.infinity, minY = double.infinity;
  var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  for (var p = 0; p < points; p++) {
    final x = d[o + InstanceFieldOffset.x0 + p * 2];
    final y = d[o + InstanceFieldOffset.y0 + p * 2];
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;
  }
  return minX - reach <= t.boxMaxX &&
      maxX + reach >= t.boxMinX &&
      minY - reach <= t.boxMaxY &&
      maxY + reach >= t.boxMinY;
}
```

`InstanceFieldOffset.x0 + p * 2` relies on `x0, y0, x1, y1, x2, y2` being
consecutive at offsets 2..7 (`instance_record.dart:103-108`). Add one line to
`instance_record_test.dart` pinning that: `expect([InstanceFieldOffset.x0,
InstanceFieldOffset.y0, InstanceFieldOffset.x1, InstanceFieldOffset.y1,
InstanceFieldOffset.x2, InstanceFieldOffset.y2], [2, 3, 4, 5, 6, 7]);`.

- [ ] **Step 4: Run, then the full gate, then commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/text_patches_test.dart
flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add lib/src/gpu/text_patches.dart test/gpu/text_patches_test.dart test/gpu/instance_record_test.dart
git commit -m "feat(gpu): classify which labels later geometry reaches"
```

---

### Task 3: The corpus — labels the spec names, and a guard that each overlap is real

**Files:**
- Modify: `test/support/fixtures.dart` (add `textOverlapFixture`)
- Modify: `test/support/fixtures_test.dart`

**Interfaces:**
- Consumes: `addEntity`, `addText`, `AddRegionCommand`, `AddNodeCommand`,
  `InstanceNode`, `DraftDocument.empty(measurer:)`.
- Produces: `DraftDocument textOverlapFixture(TextMeasurer measurer, {int
  grazeLineweight = 400})` with the handle table below;
  `kTextOverlapLabelHeight = 600.0`; `Future<int> strokeInkInsideLabel(doc,
  stroke, label)`.

**The spec's corpus, for text** (revision 5, "Testing"): *text overlapped by
a stroke of higher handle, and by a translucent fill of higher handle; text a
stroke of higher handle passes within its width of but whose centerline misses
the glyphs; text overlapped by a stroke of lower handle only; the overlapped
label at four scales inside the band, including its lower edge; text near the
culling threshold; text under a mirrored / non-uniform instance.* The four
scales are the gate's business (Task 5); the rest is this document.

| handle | what | why |
|---|---|---|
| 900 | a thick solid stroke, lineweight 120, crossing the middle of label 901 | **lower** handle: must stay UNDER the label; a classifier admitting earlier instances draws it over |
| 901 | label `'COVERED'`, height 600 | the patched label: 903 and 905 reach it |
| 903 | a thick solid stroke, lineweight 120, crossing the middle of label 901 | **higher** handle: must draw OVER the label — the spec's headline mutation |
| 904/905 | a translucent fill (transparency 128) and its polygon boundary, x 4300..7000, over the right half of label 901 (which spans x ~3000..5500) | `srcATop` vs `srcOver` — a double blend shows outside the glyphs |
| 911 | label `'UNDER'`, height 600 | overlapped by 910 only |
| 910 | a thick stroke crossing label 911, **lower** handle | the label nothing later reaches: zero patches, drawn as a plain paragraph |
| 921 | label `'GRAZED'`, height 600 | |
| 922 | a stroke of lineweight 400 whose centerline runs just above label 921's box, within its width of the glyphs | the centerline-vs-reach mutation |
| 931 | label `'TINY'`, height 140 | near `kMinTextCapPixels` at the fitted camera: culled or not, both arms must agree |
| 990 | the placement instance: rotated 0.3 rad, **mirrored** (`scale(-0.9, 1.1)`), off-origin | an identity placement hides a transposed box corner |

All entities live in one definition (`Handle(890)`) placed by instance 990,
so every label sits under a non-uniform, mirrored, rotated residual. The
definition's floor is a 30,000 × 20,000 unit rectangle (handle 899, a thin
line across its diagonal) so the fitted camera at 800 × 600 logical is about
0.026 px/unit and a 600-unit label is ~16 px tall — comfortably above
`kMinTextCapPixels` (3) at every band scale from 0.5 to 2.0, while `'TINY'`
at 140 units is ~3.6 px at scale 1 and crosses the threshold inside the band.

- [ ] **Step 1: Write the guard tests first**

Append to `test/support/fixtures_test.dart`:

```dart
  group('textOverlapFixture', () {
    late DraftDocument doc;
    setUp(() => doc = textOverlapFixture(FlutterTextMeasurer()));

    test('has the handles the table names, and the strokes are thick', () {
      for (final h in [900, 901, 903, 904, 905, 910, 911, 921, 922, 931]) {
        expect(doc.entities.slotOf(Handle(h)), isNotNull, reason: 'handle $h');
      }
      int lineweightOf(int h) =>
          doc.entities.lineweightAt(doc.entities.slotOf(Handle(h))!);
      expect(lineweightOf(903), 120);
      expect(lineweightOf(922), 400);
    });

    test('the placement is mirrored, rotated and non-uniform', () {
      // `DocumentTree.operator []` is the lookup by handle (`tree.dart:12`).
      final t = (doc.tree[const Handle(990)]! as InstanceNode).transform;
      expect(t.determinant, lessThan(0), reason: 'mirrored');
      expect(t.b, isNot(0.0), reason: 'rotated');
      expect(t.anisotropyRatio, isNot(closeTo(1.0, 1e-6)),
          reason: 'non-uniform');
    });

    test('stroke 903 actually crosses label 901 at the fitted camera', () {
      // The overlap is measured, not assumed: the label alone is painted
      // through the reference and its ink read back; then the stroke alone;
      // the two must share at least 200 device pixels. `strokeInkInsideLabel`
      // is the same instrument Task 5's gate reads.
      expect(strokeInkInsideLabel(doc, const Handle(903), const Handle(901)),
          greaterThan(200));
      expect(strokeInkInsideLabel(doc, const Handle(900), const Handle(901)),
          greaterThan(200));
    });

    test("stroke 922's centerline misses label 921 but its width reaches it",
        () async {
      expect(
          await strokeInkInsideLabel(doc, const Handle(922), const Handle(921)),
          greaterThan(50));
      // The same corpus rebuilt with 922 at hairline width: there is no
      // modify-lineweight command in this package, so the fixture takes the
      // lineweight as a parameter and the test builds it twice.
      final hairline =
          textOverlapFixture(FlutterTextMeasurer(), grazeLineweight: 1);
      expect(
          await strokeInkInsideLabel(
              hairline, const Handle(922), const Handle(921)),
          0,
          reason: 'at hairline width the same centerline touches no glyph');
    });
  });
```

`doc.entities.slotOf` and `lineweightAt` are `EntityStore`'s own accessors
(`packages/jet_cad_2d/lib/src/store/entity_store.dart`); `DocumentTree`'s
`operator []` is `tree.dart:12`. The two `strokeInkInsideLabel` tests are `async` — the
helper returns a `Future<int>` (Step 4) — so mark the first of them `async`
and `await` both calls as well.

`strokeInkInsideLabel` goes in `fixtures.dart` beside `strokeInkInsideFill`
(Plan D) and is built the same way: a `PictureRecorder`, a `CanvasDrawSink`
over a real `FlutterTextMeasurer`, `DraftPainter.paint` of a document holding
**only** the label (every other entity removed with `RemoveEntityCommand`),
`toImage`, read alpha; the same for the stroke alone; count pixels where
both alphas exceed 128. Because it is Skia on both, this is the
one helper in this plan that can read *text* ink.

- [ ] **Step 2: Run and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/support/fixtures_test.dart
```
Expected: compile error — `textOverlapFixture` undefined.

- [ ] **Step 3: Write the fixture**

Append to `test/support/fixtures.dart`:

```dart
/// A label's height in this corpus, in definition units. ~16 logical px at
/// the fitted 800x600 camera; see `textOverlapFixture`.
const double kTextOverlapLabelHeight = 600.0;

/// A corpus for Plan E: three labels and what does or does not cover them.
/// See the plan's Task 3 table for every handle and the mutation it exists
/// for. Everything sits under instance 990 -- rotated, MIRRORED and
/// non-uniformly scaled, far from the origin.
DraftDocument textOverlapFixture(TextMeasurer measurer,
    {int grazeLineweight = 400}) {
  final doc = DraftDocument.empty(measurer: measurer);

  const content = Handle(890);
  doc.tree.addDefinition(Definition(
      handle: content,
      name: 'labelled-floor',
      basePoint: Vector2.zero(),
      children: const []));

  // The floor's extent, so the fit is decided by this and not by a label.
  addEntity(doc, content, const Handle(899), EntityKind.line,
      [0, 0, 30000, 20000], const [], lineweight: 1);

  // --- COVERED: under 900, over 903 and the translucent fill 904 ---------
  addEntity(doc, content, const Handle(900), EntityKind.line,
      [3000, 5300, 9000, 5300], const [], lineweight: 120);
  addText(doc, content, const Handle(901), 'COVERED', 3000, 5000,
      kTextOverlapLabelHeight);
  addEntity(doc, content, const Handle(903), EntityKind.line,
      [3000, 5250, 9000, 5250], const [], lineweight: 120);
  doc.commands.execute(AddRegionCommand(
    fill: const EntityRecord(
      handle: Handle(904),
      owner: content,
      kind: EntityKind.fill,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: TrueColor(0xCC3311),
      lineweight: kLineweightDefault,
      transparency: 128,
      flags: 0,
    ),
    boundary: const EntityRecord(
      handle: Handle(905),
      owner: content,
      kind: EntityKind.polyline,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: TrueColor(0x000000),
      lineweight: kLineweightDefault,
      transparency: 0,
      flags: 0,
    ),
    boundaryPayload: GeometryPayload(
      coords: Float64List.fromList(<double>[
        4300, 4800, // COVERED at height 600 spans x ~3000..5500; the fill
        7000, 4800, // covers its right half and runs past it
        7000, 5800, //
        4300, 5800, //
        4300, 4800, // closing duplicate
      ]),
      scalars: Float64List(0),
    ),
  ));

  // --- UNDER: a lower-handle stroke only -- no patch ---------------------
  addEntity(doc, content, const Handle(910), EntityKind.line,
      [3000, 9300, 9000, 9300], const [], lineweight: 120);
  addText(doc, content, const Handle(911), 'UNDER', 3000, 9000,
      kTextOverlapLabelHeight);

  // --- GRAZED: centerline above the box, width reaches into it -----------
  addText(doc, content, const Handle(921), 'GRAZED', 12000, 5000,
      kTextOverlapLabelHeight);
  // The box top is at 5000 + ascent; ascent for a 600 high label is about
  // 600 * (ascent / capHeight) -- the guard test measures the overlap
  // rather than deriving it, so this y only needs to be near the box's top.
  addEntity(doc, content, const Handle(922), EntityKind.line,
      [12000, 5700, 18000, 5700], const [], lineweight: grazeLineweight);

  // --- TINY: near the culling threshold ---------------------------------
  addText(doc, content, const Handle(931), 'TINY', 12000, 9000, 140);

  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: const Handle(990),
    parent: doc.rootHandle,
    transform: Transform2.translation(400000, -250000)
        .multiply(Transform2.rotation(0.3))
        .multiply(Transform2.scale(-0.9, 1.1)),
    definition: content,
    layer: ReservedHandles.layerZero,
    color: const IndexedColor(7),
  )));

  return doc;
}
```

If `AddRegionCommand` refuses a fill whose boundary is added by the same
command in this shape, follow `fillFixture` (`fixtures.dart:722-800`) exactly —
it is the working example in this file.

**`kLineweightDefault`, `TrueColor`, `IndexedColor`, `ReservedHandles`** are
whatever `fillFixture` imports; copy its import block.

- [ ] **Step 4: `strokeInkInsideLabel`**

Model on `strokeInkInsideFill` in the same file. Signature:

```dart
/// Device pixels where [stroke]'s ink and [label]'s glyph ink both exceed
/// alpha 128, each painted ALONE through the reference (`CanvasDrawSink`
/// over a real `FlutterTextMeasurer`) at the fitted 800x600 camera, dpr 1.
/// The one helper in the GPU suite that can see text ink, because it reads
/// Skia's output rather than `TriangleRasterizer`'s.
Future<int> strokeInkInsideLabel(DraftDocument doc, Handle stroke, Handle label);
```

It must remove every entity except the one it paints (so the floor line 899
and the placement 990 stay — 990 is a node, not an entity — and 899 is a
hairline that adds one pixel-wide line; subtract nothing, it is thin enough
to sit under the 200-pixel floor). Use `Picture.toImage(800, 600)` and
`toByteData(format: ImageByteFormat.rawRgba)`; alpha is byte `i * 4 + 3`.
`toImage` is async, hence the `Future<int>`.

- [ ] **Step 5: Run, gate, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/support/fixtures_test.dart
flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add test/support/fixtures.dart test/support/fixtures_test.dart
git commit -m "test(gpu): a corpus of labels and what covers them"
```

**If the guard's overlap numbers come out under the floors,** move the
stroke's y or the label's x — the numbers in this task are the plan's
estimate, and Plan D's Task 4 recorded exactly this kind of correction
(`lineweightHundredths: 60` → `120`). Record the correction in the ledger.

---

### Task 4: The compositor, and the region arithmetic it draws by

**Files:**
- Create: `lib/src/gpu/text_compositor.dart`
- Modify: `lib/src/gpu/text_patches.dart` (add `PatchRegion`, `patchRegionFor`, `patchTargetSizeFor`)
- Modify: `lib/jet_cad_2d_flutter.dart` (export)
- Test: `test/gpu/text_compositor_test.dart`, `test/gpu/text_patches_test.dart` (region and size)

**Interfaces:**
- Consumes: `ResidentTextRecord`, `FlutterTextMeasurer.paragraphFor(text, styleHandle, style, argb)`,
  `Paragraph.alphabeticBaseline`, `Transform2`.
- Produces:
  ```dart
  class PatchRegion { final int x, y, width, height; }   // device pixels, on screen
  PatchRegion? patchRegionFor(ResidentTextRecord t, Transform2 collectionToDevice,
      int widthPx, int heightPx, {required int maxWidth, required int maxHeight});
  (int, int) patchTargetSizeFor(ResidentTextRecord t, double devicePixelRatio,
      {double bandUpperScale = kBandUpperScale, required int maxWidth, required int maxHeight});
  class PatchImage { textIndex; ui.Image image; Rect src; Rect dst; Rect layerBounds; }
  class TextCompositor {
    TextCompositor({required FlutterTextMeasurer measurer, required TextStyleRecord Function(Handle) textStyleOf});
    void paint(Canvas canvas, {ui.Image? main, required Size viewport,
        required Transform2 collectionToLogical, required List<ResidentTextRecord> texts,
        required List<PatchImage> patches});
    int get patchesComposited;   // diagnostics, reset per paint
  }
  Rect labelBoundsLogical(ResidentTextRecord t, Transform2 collectionToLogical);
  ```

**What the compositor does, in order** (revision 5, "Per frame, in emission
order"): the main image over the viewport; then the text list in list order —
a plain label is `save; transform(outer ∘ residual); translate(0, baseline);
scale(1, -1); drawParagraph; restore`; a patched label is `saveLayer(layerBounds)`
then the same paragraph then `drawImageRect(patch, src, dst, srcATop)` then
`restore`. `patches` is sorted by `textIndex` (Task 2 guarantees it) and is
consumed with one cursor. **The baseline flip is in one helper both branches
call** — the spec says so because it is the flip `canvas_draw_sink_test.dart`'s
*"a paragraph is drawn in glyph space, y up"* test exists to protect.

- [ ] **Step 1: Region and size tests**

Append to `test/gpu/text_patches_test.dart`:

```dart
  group('patchRegionFor', () {
    // A label whose collection box is (10, 20) .. (50, 40); the camera maps
    // collection to device by scale 2 and a translation, so on screen the
    // box is (120, 240) .. (200, 280).
    final t = _label(minX: 10, minY: 20, maxX: 50, maxY: 40, at: 0);
    const cam = Transform2(2, 0, 0, 2, 100, 200);

    test('is the box under the camera, rounded outward, on screen', () {
      final r = patchRegionFor(t, cam, 800, 600, maxWidth: 800, maxHeight: 600)!;
      expect([r.x, r.y, r.width, r.height], [120, 240, 80, 40]);
    });

    test('rounds outward, never inward', () {
      const cam2 = Transform2(2, 0, 0, 2, 100.4, 200.6);
      final r = patchRegionFor(t, cam2, 800, 600, maxWidth: 800, maxHeight: 600)!;
      // 120.4 -> 120, 240.6 -> 240, right edge 200.4 -> 201, bottom 280.6 -> 281
      expect([r.x, r.y, r.width, r.height], [120, 240, 81, 41]);
    });

    test('a label partly off the top-left edge is clamped, not negative', () {
      // `Viewport` and `Scissor` throw on a negative origin. Box on screen:
      // (-40, -20) .. (40, 20) -> the visible part is (0, 0) .. (40, 20).
      const cam3 = Transform2(2, 0, 0, 2, -60, -60);
      final r = patchRegionFor(t, cam3, 800, 600, maxWidth: 800, maxHeight: 600)!;
      expect([r.x, r.y, r.width, r.height], [0, 0, 40, 20]);
      // Box on screen: (-280, -360) .. (-200, -320) -> entirely off: null.
      const cam4 = Transform2(2, 0, 0, 2, -300, -400);
      expect(patchRegionFor(t, cam4, 800, 600, maxWidth: 800, maxHeight: 600),
          isNull);
    });

    test('a region larger than the target is clamped to the target', () {
      final r = patchRegionFor(t, cam, 800, 600, maxWidth: 30, maxHeight: 30)!;
      expect([r.width, r.height], [30, 30]);
    });

    test('a rotated camera bounds all four corners', () {
      // 90-degree rotation: the 40x20 box becomes 20x40 on screen; a region
      // built from two corners only would have a negative size.
      final rot = Transform2.translation(300, 300)
          .multiply(Transform2.rotation(3.141592653589793 / 2));
      final r = patchRegionFor(t, rot, 800, 600, maxWidth: 800, maxHeight: 600)!;
      expect(r.width, 20);
      expect(r.height, 40);
    });
  });

  group('patchTargetSizeFor', () {
    final t = _label(minX: 10, minY: 20, maxX: 50, maxY: 40, at: 0);
    test('is the box at the band ceiling, in device pixels, rounded up', () {
      // 40x20 collection units * dpr 2 * ceiling 2 = 160x80.
      expect(patchTargetSizeFor(t, 2.0, maxWidth: 4000, maxHeight: 4000),
          (160, 80));
    });
    test('is clamped to the viewport', () {
      expect(patchTargetSizeFor(t, 2.0, maxWidth: 100, maxHeight: 50), (100, 50));
    });
    test('is never zero', () {
      final thin = _label(minX: 10, minY: 20, maxX: 10, maxY: 20, at: 0);
      expect(patchTargetSizeFor(thin, 1.0, maxWidth: 100, maxHeight: 100), (1, 1));
    });
  });
```

- [ ] **Step 2: Implement the region arithmetic in `text_patches.dart`**

```dart
/// Where a patch draws on screen this frame: device pixels, on the viewport.
class PatchRegion {
  const PatchRegion(this.x, this.y, this.width, this.height);
  final int x, y, width, height;
}

/// The label's box under the live camera, intersected with the viewport,
/// rounded outward and clamped to the patch target's size (Ruling E8).
///
/// Returns null when the label is entirely off screen -- no pass, no
/// composite. Never returns a negative origin: `flutter_gpu`'s `Viewport`
/// and `Scissor` throw on one, and the pass is anchored at the target's own
/// origin anyway; this region's `x, y` are for the compositor's `dst`.
PatchRegion? patchRegionFor(ResidentTextRecord t, Transform2 collectionToDevice,
    int widthPx, int heightPx,
    {required int maxWidth, required int maxHeight}) {
  final m = collectionToDevice;
  var minX = double.infinity, minY = double.infinity;
  var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  void corner(double x, double y) {
    final dx = m.a * x + m.c * y + m.e, dy = m.b * x + m.d * y + m.f;
    if (dx < minX) minX = dx;
    if (dx > maxX) maxX = dx;
    if (dy < minY) minY = dy;
    if (dy > maxY) maxY = dy;
  }
  corner(t.boxMinX, t.boxMinY);
  corner(t.boxMaxX, t.boxMinY);
  corner(t.boxMinX, t.boxMaxY);
  corner(t.boxMaxX, t.boxMaxY);
  final x0 = minX.floor().clamp(0, widthPx);
  final y0 = minY.floor().clamp(0, heightPx);
  final x1 = maxX.ceil().clamp(0, widthPx);
  final y1 = maxY.ceil().clamp(0, heightPx);
  if (x1 <= x0 || y1 <= y0) return null;
  final w = (x1 - x0).clamp(0, maxWidth);
  final h = (y1 - y0).clamp(0, maxHeight);
  return PatchRegion(x0, y0, w, h);
}

/// The patch target's size: the label's box at the band's CEILING, in
/// device pixels, rounded up and clamped to the viewport -- the largest
/// region [patchRegionFor] can return inside the band, so a zoom inside it
/// resizes the region and never the texture. Never zero in either
/// dimension: a zero-sized texture is a per-backend question this plan does
/// not ask (the same rule `ResidentGeometry._upload` applies to an empty
/// instance buffer).
(int, int) patchTargetSizeFor(ResidentTextRecord t, double devicePixelRatio,
    {double bandUpperScale = kBandUpperScale,
    required int maxWidth,
    required int maxHeight}) {
  final k = devicePixelRatio * bandUpperScale;
  final w = ((t.boxMaxX - t.boxMinX) * k).ceil().clamp(1, maxWidth);
  final h = ((t.boxMaxY - t.boxMinY) * k).ceil().clamp(1, maxHeight);
  return (w, h);
}
```

**A rotated box under a rotating camera:** `patchTargetSizeFor` sizes by the
collection box's width and height, but under a rotated live camera the
device region is the rotated box's bound and can be up to √2 larger in each
dimension. `CameraController` in this codebase pans and zooms and does not
rotate; if that changes, `patchRegionFor`'s clamp-to-target keeps the pass
legal (the drawn region shrinks) and the harness's `patchClipped` counter
(Task 6) reports it. Write that sentence into `patchTargetSizeFor`'s doc.

- [ ] **Step 3: Compositor tests**

Create `test/gpu/text_compositor_test.dart`:

```dart
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

const TextStyleRecord _standard =
    TextStyleRecord(handle: Handle(11), name: 'Standard', fontFamily: 'Roboto');

const int _w = 200, _h = 120;

/// Paints [draw] into a [_w] x [_h] image.
Future<Image> _image(void Function(Canvas c) draw) {
  final recorder = PictureRecorder();
  draw(Canvas(recorder));
  return recorder.endRecording().toImage(_w, _h);
}

Future<Uint8List> _rgba(Image image) async =>
    (await image.toByteData(format: ImageByteFormat.rawRgba))!.buffer.asUint8List();

int _alpha(Uint8List px, int x, int y) => px[(y * _w + x) * 4 + 3];
int _red(Uint8List px, int x, int y) => px[(y * _w + x) * 4];
int _blue(Uint8List px, int x, int y) => px[(y * _w + x) * 4 + 2];

/// A label at a large size, placed so its glyphs sit around (60, 60) in a
/// y-up glyph space mapped onto the image by a y-flip -- the shape of
/// residual the painter actually hands a sink.
ResidentTextRecord _label({required int instanceIndex}) =>
    const ResidentTextRecord(
        text: 'A B',
        style: Handle(11),
        argb: 0xFF000000,
        a: 1, b: 0, c: 0, d: -1, e: 20, f: 80,
        boxMinX: 0, boxMinY: 0, boxMaxX: _w.toDouble(), boxMaxY: _h.toDouble(),
        instanceIndex: instanceIndex);

void main() {
  late FlutterTextMeasurer measurer;
  late TextCompositor compositor;
  setUp(() {
    measurer = FlutterTextMeasurer();
    compositor = TextCompositor(
        measurer: measurer, textStyleOf: (Handle h) => _standard);
  });

  /// Where the label alone has ink, and where inside its box it has none --
  /// found by rendering, never assumed: `flutter test`'s font is not the
  /// device's.
  Future<(Point<int>, Point<int>)> samplePoints() async {
    final alone = await _rgba(await _image((c) => compositor.paint(c,
        main: null,
        viewport: const Size(_w.toDouble(), _h.toDouble()),
        collectionToLogical: Transform2.identity(),
        texts: [_label(instanceIndex: 0)],
        patches: const [])));
    Point<int>? ink, blank;
    for (var y = 20; y < 100 && (ink == null || blank == null); y++) {
      for (var x = 20; x < 180; x++) {
        final a = _alpha(alone, x, y);
        if (a > 200 && ink == null) ink = Point(x, y);
        if (a == 0 && blank == null && x > 30) blank = Point(x, y);
      }
    }
    expect(ink, isNotNull, reason: 'the label rendered no ink at all');
    expect(blank, isNotNull, reason: 'the label has no blank pixel to test');
    return (ink!, blank!);
  }

  test('a plain label draws over the main image, in glyph space, y up', () async {
    final (ink, blank) = await samplePoints();
    final main = await _image((c) => c.drawRect(
        Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
        Paint()..color = const Color(0xFFFF0000)));
    final out = await _rgba(await _image((c) => compositor.paint(c,
        main: main,
        viewport: const Size(_w.toDouble(), _h.toDouble()),
        collectionToLogical: Transform2.identity(),
        texts: [_label(instanceIndex: 0)],
        patches: const [])));
    expect(_red(out, ink.x, ink.y), lessThan(60), reason: 'ink is black');
    expect(_red(out, blank.x, blank.y), greaterThan(200), reason: 'main shows');
    expect(compositor.patchesComposited, 0);
  });

  test('a patch puts later geometry over the ink and nowhere else (srcATop)',
      () async {
    final (ink, blank) = await samplePoints();
    final main = await _image((c) => c.drawRect(
        Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
        Paint()..color = const Color(0xFFFF0000)));
    // The patch: solid blue over the whole region, transparent elsewhere --
    // what a pass over a sub-buffer of one huge stroke would render.
    final patch = await _image((c) => c.drawRect(
        Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
        Paint()..color = const Color(0xFF0000FF)));
    final out = await _rgba(await _image((c) => compositor.paint(c,
        main: main,
        viewport: const Size(_w.toDouble(), _h.toDouble()),
        collectionToLogical: Transform2.identity(),
        texts: [_label(instanceIndex: 0)],
        patches: [
          PatchImage(
              textIndex: 0,
              image: patch,
              src: Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
              dst: Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
              layerBounds: Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble())),
        ])));
    expect(_blue(out, ink.x, ink.y), greaterThan(200),
        reason: 'over the glyph: the later stroke covers the label');
    expect(_red(out, blank.x, blank.y), greaterThan(200),
        reason: 'beside the glyph: the main image, untouched -- srcOver '
            'would paint blue here');
    expect(_blue(out, blank.x, blank.y), lessThan(60));
    expect(compositor.patchesComposited, 1);
  });

  test('a translucent later fill blends once inside the ink, never twice',
      () async {
    final (ink, blank) = await samplePoints();
    // Main: the fill (50% blue) already over white, as the main pass draws
    // it. Patch: the same 50% blue over transparent.
    const half = Color(0x800000FF);
    final main = await _image((c) => c
      ..drawRect(Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
          Paint()..color = const Color(0xFFFFFFFF))
      ..drawRect(Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
          Paint()..color = half));
    final patch = await _image((c) => c.drawRect(
        Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()), Paint()..color = half));
    final out = await _rgba(await _image((c) => compositor.paint(c,
        main: main,
        viewport: const Size(_w.toDouble(), _h.toDouble()),
        collectionToLogical: Transform2.identity(),
        texts: [_label(instanceIndex: 0)],
        patches: [
          PatchImage(
              textIndex: 0,
              image: patch,
              src: Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
              dst: Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
              layerBounds: Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble())),
        ])));
    // Beside the glyph: exactly the main image's 50% blue over white --
    // red channel ~128. A second blend (srcOver) would push it to ~64.
    expect(_red(out, blank.x, blank.y), inInclusiveRange(118, 138));
    // Over the glyph: 50% blue over black ink -- red 0, blue ~128.
    expect(_blue(out, ink.x, ink.y), inInclusiveRange(118, 138));
  });

  test('labels and patches walk in list order, with one cursor', () async {
    // Two labels; only the SECOND is patched. A compositor that matched
    // patches by position rather than by textIndex would patch the first.
    final (ink, _) = await samplePoints();
    final far = ResidentTextRecord(
        text: 'A B', style: const Handle(11), argb: 0xFF000000,
        a: 1, b: 0, c: 0, d: -1, e: 20, f: 300, // off the image
        boxMinX: 0, boxMinY: 200, boxMaxX: _w.toDouble(), boxMaxY: 400,
        instanceIndex: 0);
    final patch = await _image((c) => c.drawRect(
        Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
        Paint()..color = const Color(0xFF0000FF)));
    final out = await _rgba(await _image((c) => compositor.paint(c,
        main: null,
        viewport: const Size(_w.toDouble(), _h.toDouble()),
        collectionToLogical: Transform2.identity(),
        texts: [_label(instanceIndex: 0), far],
        patches: [
          PatchImage(
              textIndex: 1,
              image: patch,
              src: Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
              dst: Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
              layerBounds: Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble())),
        ])));
    expect(_blue(out, ink.x, ink.y), lessThan(60),
        reason: "the first label's ink is not patched");
  });

  test('the outer transform moves the label, and is applied once', () async {
    // Under `translation(30, 0)` every pixel of the label's row moves by
    // exactly 30: a compositor that applied the outer transform twice moves
    // it by 60, one that ignored it by 0, and neither reproduces the row.
    final (ink, _) = await samplePoints();
    Future<Uint8List> under(Transform2 outer) async =>
        _rgba(await _image((c) => compositor.paint(c,
            main: null,
            viewport: const Size(_w.toDouble(), _h.toDouble()),
            collectionToLogical: outer,
            texts: [_label(instanceIndex: 0)],
            patches: const [])));
    final identity = await under(Transform2.identity());
    final shifted = await under(Transform2.translation(30, 0));
    var inked = 0;
    for (var x = 0; x + 30 < _w; x++) {
      expect(_alpha(shifted, x + 30, ink.y), _alpha(identity, x, ink.y),
          reason: 'row ${ink.y}, x $x');
      if (_alpha(identity, x, ink.y) > 200) inked++;
    }
    expect(inked, greaterThan(0), reason: 'the row compared carries ink');
  });

  test('labelBoundsLogical is the four corners under the outer transform', () {
    final t = _label(instanceIndex: 0);
    final r = labelBoundsLogical(t, Transform2.rotation(3.141592653589793 / 2));
    expect(r.width, closeTo(_h.toDouble(), 1e-6));
    expect(r.height, closeTo(_w.toDouble(), 1e-6));
  });
}
```

The `Point` type is `dart:math`'s; add `import 'dart:math' show Point;`.

- [ ] **Step 4: Implement `text_compositor.dart`**

```dart
import 'dart:typed_data';
import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../flutter_text_measurer.dart';
import 'resident_text.dart';

/// One patch's image and where it goes this frame.
///
/// [src] is the drawn region inside the patch target, anchored at the
/// target's origin (Ruling E8); [dst] is the same region on screen in
/// LOGICAL pixels; [layerBounds] is the label's box in logical pixels, the
/// `saveLayer` the patch is composited inside. Three `Rect`s per patch per
/// frame: the per-patch allocation invariant 1 names as its one exception.
class PatchImage {
  const PatchImage(
      {required this.textIndex,
      required this.image,
      required this.src,
      required this.dst,
      required this.layerBounds});

  final int textIndex;
  final Image image;
  final Rect src;
  final Rect dst;
  final Rect layerBounds;
}

/// The label's box under the outer transform, as a logical-pixel `Rect`.
/// Four corners, re-bounded -- a rotated camera or a mirrored label must
/// not produce a negative-sized layer.
Rect labelBoundsLogical(ResidentTextRecord t, Transform2 m) {
  var minX = double.infinity, minY = double.infinity;
  var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  void corner(double x, double y) {
    final lx = m.a * x + m.c * y + m.e, ly = m.b * x + m.d * y + m.f;
    if (lx < minX) minX = lx;
    if (lx > maxX) maxX = lx;
    if (ly < minY) minY = ly;
    if (ly > maxY) maxY = ly;
  }
  corner(t.boxMinX, t.boxMinY);
  corner(t.boxMaxX, t.boxMinY);
  corner(t.boxMinX, t.boxMaxY);
  corner(t.boxMaxX, t.boxMaxY);
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

/// Composites one frame: the main image, then the resident text list in
/// emission order, with a patch composited over each covered label.
///
/// **GPU-free** (Ruling E6): images in, canvas calls out. That is what lets
/// the composited differential run both arms through Skia in `flutter test`.
///
/// The paragraph path is the reference sink's own: `paragraphFor` on the
/// same cache, `translate(0, baseline); scale(1, -1)` for the same reason
/// `CanvasDrawSink.text` gives -- `drawParagraph` lays glyphs out y-down
/// from the top of the line while the residual maps glyph space, y up,
/// origin on the baseline. **One helper, [_drawLabel], used by both
/// branches**, so the flip cannot be forgotten on one of them.
class TextCompositor {
  TextCompositor({required this.measurer, required this.textStyleOf});

  final FlutterTextMeasurer measurer;
  final TextStyleRecord Function(Handle) textStyleOf;

  /// Reused per label: the column-major 4x4 `Canvas.transform` wants,
  /// written in place. Slots 10 and 15 are 1 forever.
  final Float64List _matrix = Float64List(16)
    ..[10] = 1.0
    ..[15] = 1.0;

  final Paint _imagePaint = Paint()..filterQuality = FilterQuality.none;
  final Paint _patchPaint = Paint()
    ..filterQuality = FilterQuality.none
    ..blendMode = BlendMode.srcATop;
  final Paint _layerPaint = Paint();

  /// Patches composited by the last [paint]. Diagnostics; reset per call.
  int get patchesComposited => _patchesComposited;
  int _patchesComposited = 0;

  void paint(
    Canvas canvas, {
    required Image? main,
    required Size viewport,
    required Transform2 collectionToLogical,
    required List<ResidentTextRecord> texts,
    required List<PatchImage> patches,
  }) {
    _patchesComposited = 0;
    if (main != null) {
      canvas.drawImageRect(
          main,
          Rect.fromLTWH(0, 0, main.width.toDouble(), main.height.toDouble()),
          Rect.fromLTWH(0, 0, viewport.width, viewport.height),
          _imagePaint);
    }
    var p = 0;
    for (var i = 0; i < texts.length; i++) {
      final patch = p < patches.length && patches[p].textIndex == i
          ? patches[p++]
          : null;
      if (patch == null) {
        _drawLabel(canvas, texts[i], collectionToLogical);
        continue;
      }
      // The layer's bounds are in the OUTER frame -- logical pixels -- and
      // the label's own six floats are applied inside `_drawLabel`, after
      // this call. A layer opened after the residual would be transformed
      // twice (a Copilot review finding on revision 5's first draft).
      canvas.saveLayer(patch.layerBounds, _layerPaint);
      _drawLabel(canvas, texts[i], collectionToLogical);
      canvas.drawImageRect(patch.image, patch.src, patch.dst, _patchPaint);
      canvas.restore();
      _patchesComposited++;
    }
  }

  /// `outer ∘ residual`, composed by hand into [_matrix] -- six multiplies,
  /// no `Transform2` built per op (invariant 1) -- then the reference's
  /// baseline flip and `drawParagraph`.
  void _drawLabel(Canvas canvas, ResidentTextRecord t, Transform2 o) {
    final paragraph =
        measurer.paragraphFor(t.text, t.style, textStyleOf(t.style), t.argb);
    _matrix[0] = o.a * t.a + o.c * t.b;
    _matrix[1] = o.b * t.a + o.d * t.b;
    _matrix[4] = o.a * t.c + o.c * t.d;
    _matrix[5] = o.b * t.c + o.d * t.d;
    _matrix[12] = o.a * t.e + o.c * t.f + o.e;
    _matrix[13] = o.b * t.e + o.d * t.f + o.f;
    canvas.save();
    canvas.transform(_matrix);
    canvas.translate(0, paragraph.alphabeticBaseline);
    canvas.scale(1, -1);
    canvas.drawParagraph(paragraph, Offset.zero);
    canvas.restore();
  }
}
```

The hand composition is `Transform2.multiply`'s formula with `o` as the
receiver (`transform2.dart:62-69`) — check it term for term against that
method before committing, and add a test in `text_compositor_test.dart` that
records `_matrix` through a `SpyCanvas` (`test/support/spy_canvas.dart`) for
one label under a non-identity outer transform and compares it with
`o.multiply(Transform2(t.a, t.b, t.c, t.d, t.e, t.f))` — the same way
`canvas_draw_sink_test.dart` reads `_transformBeforeDraw`.

Add to `lib/jet_cad_2d_flutter.dart`:
```dart
export 'src/gpu/text_compositor.dart';
```

- [ ] **Step 5: Run, gate, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/text_compositor_test.dart test/gpu/text_patches_test.dart
flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add lib/src/gpu/text_compositor.dart lib/src/gpu/text_patches.dart lib/jet_cad_2d_flutter.dart \
  test/gpu/text_compositor_test.dart test/gpu/text_patches_test.dart
git commit -m "feat(gpu): the text compositor -- a label over the main image, a patch over its ink"
```

---

### Task 5: The composited differential, and the order gate

**Files:**
- Modify: `test/support/gpu_comparison.dart` (add `CompositedAgreement`, `measureCompositedAgreement`)
- Create: `test/gpu/text_order_test.dart`

**Interfaces:**
- Consumes: `textOverlapFixture` (Task 3), `classifyTextPatches`,
  `patchRegionFor`, `TextCompositor`, `PatchImage`, `expandInstances`
  (`test/support/instance_expander.dart:110`), `VerticesDrawSink(fallback:)`,
  `CanvasDrawSink`.
- Produces:
  ```dart
  class CompositedAgreement { final int union, withinTwo, overEight, referenceInk, patchCount; double get agreement; }
  Future<CompositedAgreement> measureCompositedAgreement(DraftDocument document, {
      required ViewportTransform collectionCamera, required ViewportTransform liveCamera,
      required Size size, required double devicePixelRatio, required double pixelsPerPaperMm,
      required FlutterTextMeasurer measurer,
      List<TextPatch> Function(List<TextPatch>)? mutatePatches,   // test seam: the "all text in one pass" mutation is `(_) => []`
      double minTextCapPixels = kMinTextCapPixels});
  ```

**The corpus is undashed, and the instrument says so in its doc.** Skia's
`drawVertices` cannot honour `expandInstances`'s dash varyings (the shader
discards per fragment; `TriangleRasterizer` reproduces that, Skia does not),
so a dashed instance would draw solid on the resident arm here. Dash
correctness is Plan C's gates; this instrument is for text and order, on
solid geometry.

**Both arms through Skia.** The reference is the painter driving
`VerticesDrawSink` with a `CanvasDrawSink` fallback on the **same** `Canvas`
(the widget's own arrangement) at the **live** camera. The resident arm is
the painter driving `GeometryCollector` (with a measurer) at the **collection**
camera; `classifyTextPatches`; then, per Ruling B6, `expandInstances` turns
the main buffer and each sub-buffer into device-space triangles that
`Canvas.drawVertices` draws into a `Picture` — the main one at viewport size,
each patch at its region's size under `translation(-x, -y) ∘
collectionToDevice` — `toImage` each, and `TextCompositor.paint` onto the
final canvas under `canvas.scale(dpr)`. Per-channel comparison as
`_colorAgreementOf` does it. **`dashScale`** for `expandInstances` is the
live-to-collection ratio (`dashScaleFor`'s formula), because the two cameras
differ here — that is the point of the four-scale test.

- [ ] **Step 1: The gate, written first**

Create `test/gpu/text_order_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/fixtures.dart';
import '../support/gpu_comparison.dart';

const Size _size = Size(800, 600);
const double _dpr = 1.0;
const double _ppmm = 3.78;

/// The camera the buffer is collected at, and the four live cameras the
/// gate runs at: the band's floor, two interior points, and the ceiling.
/// The floor is where the reach expansion is load-bearing.
ViewportTransform _fit(DraftDocument doc) =>
    ViewportTransform.fit(doc.extents, _size);

ViewportTransform _scaled(ViewportTransform base, double s) {
  final centre = Offset(_size.width / 2, _size.height / 2);
  final m = Transform2.translation(centre.dx, centre.dy)
      .multiply(Transform2.scale(s, s))
      .multiply(Transform2.translation(-centre.dx, -centre.dy))
      .multiply(base.worldToScreenMatrix);
  return ViewportTransform(worldToScreenMatrix: m);
}

void main() {
  late FlutterTextMeasurer measurer;
  late DraftDocument doc;
  setUp(() {
    measurer = FlutterTextMeasurer();
    doc = textOverlapFixture(measurer);
  });

  for (final s in const [0.5, 0.8, 1.25, 2.0]) {
    test('the composited picture matches the reference at scale $s', () async {
      // `minTextCapPixels: 0` -- level of detail OFF on both arms. Text
      // culling is a watermark decision frozen at the reference scale (the
      // spec's table), so with it on the two arms legitimately disagree
      // about TINY away from scale 1; that disagreement is Plan F's band
      // statement, not this gate's. The LOD-on case is the next test.
      final base = _fit(doc);
      final m = await measureCompositedAgreement(doc,
          collectionCamera: base,
          liveCamera: _scaled(base, s),
          size: _size,
          devicePixelRatio: _dpr,
          pixelsPerPaperMm: _ppmm,
          measurer: measurer,
          minTextCapPixels: 0.0);
      expect(m.referenceInk, greaterThan(5000), reason: 'anti-vacuity');
      expect(m.patchCount, greaterThanOrEqualTo(1),
          reason: 'COVERED must be a patch or this test sees no ordering');
      expect(m.agreement, greaterThanOrEqualTo(0.995),
          reason: 'spec criterion 1, per channel <= 2 on >= 99.5% of the '
              'union; scale $s: withinTwo=${m.withinTwo} union=${m.union} '
              'overEight=${m.overEight}');
    });
  }

  test('with level of detail on, both arms cull TINY the same way at scale 1',
      () async {
    final base = _fit(doc);
    final m = await measureCompositedAgreement(doc,
        collectionCamera: base,
        liveCamera: base,
        size: _size,
        devicePixelRatio: _dpr,
        pixelsPerPaperMm: _ppmm,
        measurer: measurer);
    expect(m.agreement, greaterThanOrEqualTo(0.995));
  });

  test('drawing all text in one pass -- no patches -- changes the picture',
      () async {
    // The spec's headline text mutation, as a seam rather than a source
    // edit: with the classifier's output discarded, the later stroke 903
    // draws UNDER label COVERED, and the fill 904 under it too.
    final base = _fit(doc);
    final m = await measureCompositedAgreement(doc,
        collectionCamera: base,
        liveCamera: base,
        size: _size,
        devicePixelRatio: _dpr,
        pixelsPerPaperMm: _ppmm,
        measurer: measurer,
        mutatePatches: (_) => const []);
    expect(m.patchCount, 0);
    expect(m.overEight, greaterThan(200),
        reason: 'the ink of 903 and 904 inside COVERED\'s glyphs is where '
            'the two arms now disagree; fewer than 200 pixels means the '
            'overlap is not real and Task 3\'s guard is wrong');
    expect(m.agreement, lessThan(0.995));
  });

  test('the label nothing later reaches is not a patch, and still matches',
      () async {
    final base = _fit(doc);
    final m = await measureCompositedAgreement(doc,
        collectionCamera: base,
        liveCamera: base,
        size: _size,
        devicePixelRatio: _dpr,
        pixelsPerPaperMm: _ppmm,
        measurer: measurer);
    // Exactly the labels the table says are covered: COVERED and GRAZED.
    // UNDER is not (its only stroke is of lower handle); TINY is not.
    expect(m.patchCount, 2,
        reason: 'a classifier that patches every label reads 4 here');
  });
}
```

- [ ] **Step 2: Run and watch it fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/text_order_test.dart
```
Expected: compile error — `measureCompositedAgreement` undefined.

- [ ] **Step 3: Implement the instrument in `gpu_comparison.dart`**

```dart
/// The per-channel agreement of two Skia-rendered pictures, plus how many
/// patches the resident arm composited. Same fields and the same 2/8
/// thresholds as [ResidentColorAgreement]; a separate class because the
/// instrument is different -- this one sees text.
class CompositedAgreement {
  const CompositedAgreement(this.union, this.withinTwo, this.overEight,
      this.referenceInk, this.patchCount);
  final int union, withinTwo, overEight, referenceInk, patchCount;
  double get agreement => union == 0 ? 1.0 : withinTwo / union;
}

/// Both arms through Skia, text included -- the first instrument in this
/// suite that can. See the plan's Task 5 for the arrangement.
Future<CompositedAgreement> measureCompositedAgreement(
  DraftDocument document, {
  required ViewportTransform collectionCamera,
  required ViewportTransform liveCamera,
  required Size size,
  required double devicePixelRatio,
  required double pixelsPerPaperMm,
  required FlutterTextMeasurer measurer,
  List<TextPatch> Function(List<TextPatch>)? mutatePatches,
  double minTextCapPixels = kMinTextCapPixels,
}) async {
  final w = (size.width * devicePixelRatio).round();
  final h = (size.height * devicePixelRatio).round();
  final index = SpatialIndex(document);
  final resolver = DocumentStyleResolver(document);
  final painter = DraftPainter(
      document: document,
      index: index,
      resolver: resolver,
      minTextCapPixels: minTextCapPixels);

  // --- reference: the widget's own arrangement, at the live camera -------
  final refRecorder = PictureRecorder();
  final refCanvas = Canvas(refRecorder)..scale(devicePixelRatio, devicePixelRatio);
  final fallback = CanvasDrawSink(
      canvas: refCanvas,
      pixelsPerPaperMm: pixelsPerPaperMm,
      measurer: measurer,
      textStyleOf: document.textStyleOf);
  final reference = VerticesDrawSink(
      canvas: refCanvas,
      pixelsPerPaperMm: pixelsPerPaperMm,
      devicePixelRatio: devicePixelRatio,
      fallback: fallback);
  painter.paint(reference, liveCamera, size);
  reference.flush();
  final refImage = await refRecorder.endRecording().toImage(w, h);

  // --- resident: collect at the collection camera, classify, expand ------
  final collector = GeometryCollector(
      pixelsPerPaperMm: pixelsPerPaperMm,
      devicePixelRatio: devicePixelRatio,
      measurer: measurer,
      textStyleOf: document.textStyleOf);
  painter.paint(collector, collectionCamera, size);
  final data = collector.data;
  final texts = collector.texts;
  var patches = classifyTextPatches(data, collector.instanceCount, texts,
      devicePixelRatio: devicePixelRatio);
  if (mutatePatches != null) patches = mutatePatches(patches);

  final collectionInverse = collectionCamera.worldToScreenMatrix.invert();
  final collectionToLogical =
      composeTransforms(liveCamera.worldToScreenMatrix, collectionInverse);
  final collectionToDevice = composeTransforms(
      Transform2.scale(devicePixelRatio, devicePixelRatio), collectionToLogical);
  final dashScale = dashScaleFor(liveCamera, collectionInverse);

  Future<Image> triangles(Float32List buf, int count, Transform2 toDevice,
      int width, int height) {
    final expanded = expandInstances(buf, count, toDevice, dashScale: dashScale);
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    if (count > 0) {
      final vertices = Vertices.raw(VertexMode.triangles, expanded.positions,
          colors: expanded.colors);
      // As `VerticesDrawSink.flush` draws: the vertex colour is the colour,
      // the paint contributes alpha only.
      canvas.drawVertices(vertices, BlendMode.dst, Paint());
      vertices.dispose();
    }
    return recorder.endRecording().toImage(width, height);
  }

  final mainImage =
      await triangles(data, collector.instanceCount, collectionToDevice, w, h);
  final patchImages = <PatchImage>[];
  for (final p in patches) {
    final t = texts[p.textIndex];
    final region = patchRegionFor(t, collectionToDevice, w, h,
        maxWidth: w, maxHeight: h);
    if (region == null) continue;
    final toPatch = composeTransforms(
        Transform2.translation(-region.x.toDouble(), -region.y.toDouble()),
        collectionToDevice);
    final img = await triangles(
        p.instances, p.instanceCount, toPatch, region.width, region.height);
    patchImages.add(PatchImage(
        textIndex: p.textIndex,
        image: img,
        src: Rect.fromLTWH(0, 0, region.width.toDouble(), region.height.toDouble()),
        dst: Rect.fromLTWH(region.x / devicePixelRatio, region.y / devicePixelRatio,
            region.width / devicePixelRatio, region.height / devicePixelRatio),
        layerBounds: labelBoundsLogical(t, collectionToLogical)));
  }

  final outRecorder = PictureRecorder();
  final outCanvas = Canvas(outRecorder)..scale(devicePixelRatio, devicePixelRatio);
  final compositor =
      TextCompositor(measurer: measurer, textStyleOf: document.textStyleOf);
  compositor.paint(outCanvas,
      main: mainImage,
      viewport: size,
      collectionToLogical: collectionToLogical,
      texts: texts,
      patches: patchImages);
  final outImage = await outRecorder.endRecording().toImage(w, h);

  final a = (await refImage.toByteData(format: ImageByteFormat.rawRgba))!;
  final b = (await outImage.toByteData(format: ImageByteFormat.rawRgba))!;
  var union = 0, withinTwo = 0, overEight = 0, referenceInk = 0;
  for (var i = 0; i < w * h; i++) {
    final o = i * 4;
    final inkA = a.getUint8(o + 3) != 0, inkB = b.getUint8(o + 3) != 0;
    if (inkA) referenceInk++;
    if (!inkA && !inkB) continue;
    union++;
    var worst = 0;
    for (var ch = 0; ch < 4; ch++) {
      final d = (a.getUint8(o + ch) - b.getUint8(o + ch)).abs();
      if (d > worst) worst = d;
    }
    if (worst <= 2) withinTwo++;
    if (worst > 8) overEight++;
  }
  return CompositedAgreement(
      union, withinTwo, overEight, referenceInk, compositor.patchesComposited);
}
```

**Two things to expect, and what to do about each:**

1. **A white background on one arm and transparent on the other.** The
   reference draws onto a transparent picture; so does the resident. If
   `refImage` comes back with an opaque white ground (a `CanvasDrawSink`
   quirk), draw a white rect first on **both** canvases before painting,
   and say so in the function's doc. Do not clear alpha on one side only.
2. **Antialiasing of `drawParagraph` is identical on both arms** — the
   same `Paragraph` object from the same cache, drawn under a transform that
   is the same composition by a different route. Where it differs by a
   float-rounding amount, the ≤ 2 tolerance absorbs it. If the four-scale
   rows miss 99.5% by a small margin **only at 0.5 and 2.0**, that is the
   band edge and it is recorded as the number, not adjusted (Plan C's rule).

- [ ] **Step 4: Run, gate, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/text_order_test.dart
flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add test/support/gpu_comparison.dart test/gpu/text_order_test.dart
git commit -m "test(gpu): the composited differential sees text, and gates its order"
```

---

### Task 6: The resident geometry carries patches, and the backend paints them

**Files:**
- Modify: `lib/src/gpu/resident_geometry.dart`
- Modify: `lib/src/gpu/gpu_draw_backend.dart`
- Test: `test/gpu/resident_geometry_test.dart`, `test/gpu/frame_info_test.dart`

**Interfaces:**
- Consumes: `TextPatch`, `ResidentTextRecord`, `patchTargetSizeFor`,
  `patchRegionFor`, `TextCompositor`, `PatchImage`, `labelBoundsLogical`,
  `buildFrameInfo`, `composeTransforms`, `dashScaleFor`.
- Produces:
  ```dart
  class ResidentPatch {           // @internal getters, as ResidentGeometry's own
    final int textIndex; final int instanceCount;
    final gpu.DeviceBuffer instances; final gpu.Texture target;
    final int targetWidth, targetHeight;
  }
  ResidentGeometry.create(Float32List instances, int instanceCount, {
      List<ResidentTextRecord> texts = const [], List<TextPatch> patches = const [],
      double devicePixelRatio = 1.0, int maxPatchWidth = 4096, int maxPatchHeight = 4096});
  List<ResidentTextRecord> get texts; List<ResidentPatch> get patches;
  int get byteLength;          // main buffer + every sub-buffer
  int get patchTargetBytes;    // sum of targetWidth * targetHeight * 4
  static int byteLengthFor(int instances, {int patchInstances = 0});
  GpuDrawBackend(ResidentGeometry geometry, ViewportTransform collectionCamera,
      {FlutterTextMeasurer? measurer, TextStyleRecord Function(Handle)? textStyleOf});
  ui.Image? render(ViewportTransform camera, Size viewport, double dpr);   // unchanged signature; now also renders patches
  void paint(Canvas canvas, ViewportTransform camera, Size viewport, double dpr);
  int get patchesRendered; int get patchesClipped; int get patchesOffscreen;  // last frame
  ```

- [ ] **Step 1: The GPU-free tests**

Append to `test/gpu/resident_geometry_test.dart`:

```dart
  test('the byte length prices every sub-buffer beside the main buffer', () {
    // 1000 main instances + 37 patch instances, 64 bytes each.
    expect(ResidentGeometry.byteLengthFor(1000, patchInstances: 37),
        (1000 + 37) * 64);
  });

  test('create still returns null with no GPU, patches or not', () async {
    debugSetGpuFactory(() => throw StateError('no gpu'));
    final g = await ResidentGeometry.create(
        Float32List(kFloatsPerInstance), 1,
        texts: const [],
        patches: [
          TextPatch(
              textIndex: 0,
              instances: Float32List(kFloatsPerInstance),
              instanceCount: 1)
        ]);
    expect(g, isNull);
  });
```

Append to `test/gpu/frame_info_test.dart`:

```dart
  test('a patch FrameInfo maps the region origin to the NDC corner', () {
    // Region at device (120, 240), 80x40; collectionToDevice scale 2 +
    // (100, 200). Composed with translation(-120, -240) OUTSIDE, the
    // collection point that lands at device (120, 240) must land at NDC
    // (-1, +1): the top-left of an 80x40 target.
    const cam = Transform2(2, 0, 0, 2, 100, 200);
    final toPatch = composeTransforms(Transform2.translation(-120, -240), cam);
    final data = buildFrameInfo(toPatch, 80, 40, dashScale: 1.0);
    double at(int i) => data.getFloat32(i * 4, Endian.host);
    // collection (10, 20) -> device (120, 240) -> patch (0, 0) -> NDC (-1, 1)
    final x = at(0) * 10 + at(4) * 20 + at(12);
    final y = at(1) * 10 + at(5) * 20 + at(13);
    expect(x, closeTo(-1, 1e-6));
    expect(y, closeTo(1, 1e-6));
    expect(at(16), 40, reason: 'half_viewport is the REGION\'s, so the '
        'half-width expansion stays in device pixels');
    expect(at(17), 20);
  });
```

- [ ] **Step 2: `ResidentGeometry`**

Add the class and fields:

```dart
/// One covered label's GPU-side patch: its sub-buffer and its target.
///
/// Both allocated at upload and reused every frame -- the target at the
/// label's size at the band's ceiling (`patchTargetSizeFor`), so a zoom
/// inside the band never reallocates it.
class ResidentPatch {
  ResidentPatch._(this.textIndex, this.instanceCount, this._instances,
      this._target, this.targetWidth, this.targetHeight);

  final int textIndex;
  final int instanceCount;
  final gpu.DeviceBuffer _instances;
  final gpu.Texture _target;
  final int targetWidth;
  final int targetHeight;

  @internal
  gpu.DeviceBuffer get instances => _instances;
  @internal
  gpu.Texture get target => _target;
}
```

Extend `create` / `_upload` (the same try/catch, the same `null` on no GPU):

```dart
  static Future<ResidentGeometry?> create(
    Float32List instances,
    int instanceCount, {
    List<ResidentTextRecord> texts = const <ResidentTextRecord>[],
    List<TextPatch> patches = const <TextPatch>[],
    double devicePixelRatio = 1.0,
    int maxPatchWidth = 4096,
    int maxPatchHeight = 4096,
  }) async { ... }
```

In `_upload`, after the main buffers:

```dart
    final residentPatches = <ResidentPatch>[];
    for (final p in patches) {
      final (tw, th) = patchTargetSizeFor(texts[p.textIndex], devicePixelRatio,
          maxWidth: maxPatchWidth, maxHeight: maxPatchHeight);
      residentPatches.add(ResidentPatch._(
        p.textIndex,
        p.instanceCount,
        context.createDeviceBufferWithCopy(ByteData.sublistView(
            p.instances, 0, p.instanceCount * kFloatsPerInstance)),
        // A patch target must be shader-readable: the compositor draws it
        // through `asImage()`, which the web shim refuses on a texture
        // without `enableShaderReadUsage` (`web/texture.dart:358`). It is the
        // default on both backends; passed explicitly so it cannot drift.
        context.createTexture(gpu.StorageMode.devicePrivate, tw, th,
            enableShaderReadUsage: true),
        tw,
        th,
      ));
    }
```

`texts`, `patches` become fields; `byteLength` becomes
`byteLengthFor(instanceCount, patchInstances: sum of patch instanceCounts)`;
`patchTargetBytes` sums `targetWidth * targetHeight * 4`. Keep `byteLengthFor`'s
existing single-argument calls working with the named default.

**Why `maxPatchWidth/Height` default to 4096 and not the viewport:** `create`
does not know the viewport. The harness passes the viewport in device pixels
(Task 7); the default is a ceiling that keeps a mis-wired caller from asking
for a texture the driver refuses. Say so in the doc.

- [ ] **Step 3: `GpuDrawBackend`**

Constructor gains `measurer` and `textStyleOf` (optional; without them `paint`
draws the main image and no text, and says so in its doc — Ruling E2's shape
again). Fields:

```dart
  final TextCompositor? _compositor;   // null without a measurer
  final List<PatchImage> _patchImages = <PatchImage>[];
  int patchesRendered = 0, patchesClipped = 0, patchesOffscreen = 0;
```

In `render`, after the main pass's `pass.draw(...)` and **before**
`commandBuffer.submit()`, one more render pass per patch on the **same command
buffer**:

```dart
    _patchImages.clear();
    patchesRendered = 0;
    patchesClipped = 0;
    patchesOffscreen = 0;
    final dashScale = dashScaleFor(camera, _collectionInverse);
    for (final patch in geometry.patches) {
      final t = geometry.texts[patch.textIndex];
      final region = patchRegionFor(t, collectionToDevice, widthPx, heightPx,
          maxWidth: patch.targetWidth, maxHeight: patch.targetHeight);
      if (region == null) {
        patchesOffscreen++;
        continue;
      }
      // The region reached the target's size: either the live scale is past
      // the band's ceiling and Plan F's rebuild has not landed, or it sits
      // exactly at the ceiling. Drawn anyway, short if clamped; counted so
      // the harness can say how often. A diagnostic, not a decision.
      if (region.width == patch.targetWidth ||
          region.height == patch.targetHeight) {
        patchesClipped++;
      }
      final patchPass = commandBuffer.createRenderPass(gpu.RenderTarget.singleColor(
        gpu.ColorAttachment(
            texture: patch.target, clearValue: vm.Vector4(0, 0, 0, 0)),
      ));
      patchPass.bindPipeline(geometry.pipeline);
      patchPass.setPrimitiveType(gpu.PrimitiveType.triangle);
      patchPass.setCullMode(gpu.CullMode.none);
      patchPass.setColorBlendEnable(true);
      // Ruling E8: anchored at the target's origin. `Viewport`/`Scissor`
      // throw on a negative origin, and the region's on-screen position is
      // the compositor's business.
      patchPass.setViewport(gpu.Viewport(
          x: 0, y: 0, width: region.width, height: region.height));
      patchPass.setScissor(gpu.Scissor(
          x: 0, y: 0, width: region.width, height: region.height));
      patchPass.bindVertexBuffer(
          gpu.BufferView(geometry.corners,
              offsetInBytes: 0, lengthInBytes: geometry.corners.sizeInBytes),
          slot: 0);
      patchPass.bindVertexBuffer(
          gpu.BufferView(patch.instances,
              offsetInBytes: 0, lengthInBytes: patch.instances.sizeInBytes),
          slot: 1);
      final toPatch = composeTransforms(
          Transform2.translation(-region.x.toDouble(), -region.y.toDouble()),
          collectionToDevice);
      patchPass.bindUniform(
        geometry.vertexShader.getUniformSlot('FrameInfo'),
        geometry.uniforms.emplace(buildFrameInfo(
            toPatch, region.width, region.height,
            dashScale: dashScale)),
      );
      patchPass.draw(ResidentGeometry.cornerVertexCount,
          instanceCount: patch.instanceCount);
      patchesRendered++;
      _pendingRegions.add((patch, region));
    }

    commandBuffer.submit();
    frames++;

    // **`asImage()` only after `submit()`, on purpose.** On native the image
    // is a handle over the live texture (`flutter_gpu/texture.cc`'s
    // `Texture::AsImage`) and reads whatever the texture holds when the
    // picture rasterises, so the order would not matter there. On the web
    // shim `asImage()` SNAPSHOTS the texture now (`snapshotTextureSync`), so
    // taken before the submit it would show last frame's patch. One order
    // that is right on both backends -- the finding Codex made against
    // revision 5's first draft.
    for (final (patch, region) in _pendingRegions) {
      _patchImages.add(PatchImage(
        textIndex: patch.textIndex,
        image: patch.target.asImage(),
        src: Rect.fromLTWH(
            0, 0, region.width.toDouble(), region.height.toDouble()),
        dst: Rect.fromLTWH(region.x / dpr, region.y / dpr,
            region.width / dpr, region.height / dpr),
        layerBounds: labelBoundsLogical(
            geometry.texts[patch.textIndex], collectionToLogical),
      ));
    }
    _pendingRegions.clear();
    return target.asImage();
```

`_pendingRegions` is a `List<(ResidentPatch, PatchRegion)>` field, cleared
per frame — the existing `commandBuffer.submit(); frames++; return
target.asImage();` tail of `render` is replaced by the block above. `_patchImages`
is cleared at the top of the patch loop as shown.

**The uniform ring.** `geometry.uniforms` is a bump allocator reset once per
`render` (its own comment, `:150-186`). One `emplace` per pass, `1 + P` per
frame; the ring's blocks are large relative to 80 bytes, but if a run's
`FlutterError` reports a failed emplace at high patch counts, that is the
number to report and the sentence to write, not a reason to reset mid-frame.

Then `paint`:

```dart
  /// One frame onto [canvas]: `render`, then the compositor. This is the
  /// call site a widget uses (Plan F) and the harness uses (Task 7).
  void paint(Canvas canvas, ViewportTransform camera, Size viewport, double dpr) {
    final main = render(camera, viewport, dpr);
    final compositor = _compositor;
    if (compositor == null) {
      if (main != null) {
        canvas.drawImageRect(
            main,
            Rect.fromLTWH(0, 0, main.width.toDouble(), main.height.toDouble()),
            Rect.fromLTWH(0, 0, viewport.width, viewport.height),
            _imagePaint);
      }
      return;
    }
    final collectionToLogical =
        composeTransforms(camera.worldToScreenMatrix, _collectionInverse);
    compositor.paint(canvas,
        main: main,
        viewport: viewport,
        collectionToLogical: collectionToLogical,
        texts: geometry.texts,
        patches: _patchImages);
  }
```

`collectionToLogical` is computed a third time here (once in `render`, once
in `dashScaleFor`, once here): per frame, not per entity, inside the
non-negotiable — the same sentence `render` already carries for its second
composition. Better: have `render` store the frame's `collectionToLogical` in
a field and read it here; do that, and drop the recomputation.

- [ ] **Step 4: Gate and commit**

`render` and `paint` cannot run in `flutter test`; the tests above cover
what can be. The harness run (Task 7) is where this code first executes.

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add lib/src/gpu/resident_geometry.dart lib/src/gpu/gpu_draw_backend.dart \
  test/gpu/resident_geometry_test.dart test/gpu/frame_info_test.dart
git commit -m "feat(gpu): patch targets and sub-buffers on the device, and a paint that composites them"
```

---

### Task 7: The harness draws text, and measures it

**Files:**
- Modify: `apps/dev_harness_2d/lib/main.dart`
- Modify: `apps/dev_harness_2d/lib/gpu_arm.dart`
- Create: `apps/dev_harness_2d/test/spike_text_test.dart`
- Modify: `.vscode/launch.json`

**Interfaces:**
- Consumes: everything Tasks 1–6 produce; `harnessMeasurer`, `kDrawText`,
  `kMeasurementViewport`, `_intDefine`/`String.fromEnvironment` patterns,
  `AddEntityCommand`, `doc.handleSeed.next()`.
- Produces: `kSpikeText` (`SPIKE_TEXT`, `'false'` default, throws on any
  other string — `kSpikeFills`'s shape); `spikeDocument({..., bool? text})`;
  `_addPatchedLabels(doc, entityCount)`; `GpuSpikeApp(drawText:)`;
  `GpuSpikeState.textOps, patches, subBufferBytes, patchTargetBytes,
  classifyMs`; new GSPIKE lines.

- [ ] **Step 1: Harness tests first**

Create `apps/dev_harness_2d/test/spike_text_test.dart`, modelled on
`spike_fill_scale_test.dart`:

```dart
import 'package:dev_harness_2d/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

const int _kEntities = 2000;

int _textCount(DraftDocument doc) {
  var n = 0;
  for (final slot in doc.entities.liveSlots) {
    final k = doc.entities.kindAt(slot);
    if (k == EntityKind.text || k == EntityKind.attrib) n++;
  }
  return n;
}

void main() {
  test('SPIKE_TEXT is inert at its default', () {
    expect(_textCount(spikeDocument(entityCount: _kEntities)), 0);
    expect(_textCount(spikeDocument(entityCount: _kEntities, text: false)), 0);
  });

  test('with text on, the corpus carries labels, and some are patched', () {
    final doc = spikeDocument(entityCount: _kEntities, text: true);
    expect(_textCount(doc), greaterThan(0));
    // Collect at the fitted camera and classify, exactly as the arm does:
    // the deliberate patched labels must be patches, or criterion 11 has
    // nothing to measure.
    final index = SpatialIndex(doc);
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    final collector = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm,
        devicePixelRatio: 1.0,
        measurer: harnessMeasurer,
        textStyleOf: doc.textStyleOf);
    final camera = ViewportTransform.fit(doc.extents, kMeasurementViewport);
    painter.paint(collector, camera, kMeasurementViewport);
    final patches = classifyTextPatches(
        collector.data, collector.instanceCount, collector.texts,
        devicePixelRatio: 1.0);
    expect(collector.skippedOps, 0, reason: 'text is drawn now');
    expect(patches.length, greaterThanOrEqualTo(kPatchedLabelCount),
        reason: 'every deliberate patched label is a patch');
    index.dispose();
  });
}
```

- [ ] **Step 2: `main.dart`**

Beside `kSpikeFills`:

```dart
/// Whether the GPU spike corpus carries text -- Plan E's Task 7. Same shape
/// and same reason as [kSpikeFills]: a `String.fromEnvironment` that throws
/// on anything but `true`/`false`, inert at `false` so every number a run
/// took before this define existed is reproducible unchanged.
///
/// On, [spikeDocument] generates labels at [harnessDocument]'s own fractions
/// (`labelFraction: 0.02`, `attributedInstanceFraction: 0.2`) and adds
/// [kPatchedLabelCount] deliberate **patched** labels through
/// [_addPatchedLabels]: a label, then a thick solid stroke of higher handle
/// through its middle. Criterion 11 requires at least one such label or the
/// text-pass number measures nothing.
final bool kSpikeText = switch (
    const String.fromEnvironment('SPIKE_TEXT', defaultValue: 'false')) {
  'false' => false,
  'true' => true,
  final other =>
    throw StateError('SPIKE_TEXT must be true or false; got "$other"'),
};

/// Deliberate patched labels [_addPatchedLabels] adds. Eight: enough to put
/// a patch on screen at the fitted camera and under every pan step, few
/// enough that the corpus is still the measured corpus plus text.
const int kPatchedLabelCount = 8;

/// A label the fitted camera can read -- 600 units is ~13.5 logical px at
/// 0.0225 px/unit, above `kMinTextCapPixels` at every band scale.
const double kPatchedLabelHeight = 600.0;

/// Adds [kPatchedLabelCount] labels, each followed (higher handle) by a solid
/// stroke of lineweight 100 through its middle -- so each is a patch by
/// construction. Placed in the corridor `_addFillRegions` uses, spaced along
/// x, so a pan of `(4, 0)` per frame keeps at least one on screen.
void _addPatchedLabels(DraftDocument doc, int entityCount) {
  final centerX = kDefaultOriginX + kFloorWidth / 2;
  final centerY = kOriginY + kFloorHeight / 2;
  for (var i = 0; i < kPatchedLabelCount; i++) {
    final x = centerX - 3000.0 + i * 800.0;
    final y = centerY - 750.0;
    final label = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: EntityRecord(
        handle: label,
        owner: doc.rootHandle,
        kind: EntityKind.text,
        layer: ReservedHandles.layerZero,
        linetype: ReservedHandles.byLayerLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const ByLayerColor(),
        lineweight: kByLayer,
        transparency: 0,
        flags: 0,
        text: 'ROOM ${i + 1}',
        textStyle: ReservedHandles.standardTextStyle,
        textAttrs: packTextAttrs(),
      ),
      payload: GeometryPayload(
        coords: Float64List.fromList([x, y]),
        scalars: Float64List.fromList([kPatchedLabelHeight, 0, 1, 0]),
      ),
    ));
    final stroke = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: EntityRecord(
        handle: stroke,
        owner: doc.rootHandle,
        kind: EntityKind.line,
        layer: ReservedHandles.layerZero,
        linetype: ReservedHandles.byLayerLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const ByLayerColor(),
        lineweight: 100,
        transparency: 0,
        flags: 0,
      ),
      payload: GeometryPayload(
        coords: Float64List.fromList(
            [x - 100, y + kPatchedLabelHeight * 0.4, x + 2500, y + kPatchedLabelHeight * 0.4]),
        scalars: Float64List(0),
      ),
    ));
  }
}
```

`packTextAttrs`, `kByLayer`, `kDefaultOriginX`, `kFloorWidth`, `kOriginY`,
`kFloorHeight` are what `_addFillRegions` and `addText` (in the flutter
package's fixtures) already use; copy their imports.

`spikeDocument` gains `bool? text`:

```dart
DraftDocument spikeDocument(
    {int? entityCount, bool? fillsEnabled, double? fillScale, bool? text}) {
  final count = entityCount ?? kEntities;
  final withText = text ?? kSpikeText;
  final doc = generateDocument(
    count,
    ...,
    labelFraction: withText ? 0.02 : 0,
    attributedInstanceFraction: withText ? 0.2 : 0,
    measurer: harnessMeasurer,
  );
  if (fillsEnabled ?? kSpikeFills) {
    _addFillRegions(doc, count, sizeScale: fillScale ?? kSpikeFillScale);
  }
  if (withText) _addPatchedLabels(doc, count);
  return doc;
}
```

`GpuSpikeApp(document: spikeDocument(), ..., drawText: kDrawText)`.

- [ ] **Step 3: `gpu_arm.dart`**

- `GpuSpikeApp` gains `required this.drawText`; `_buildResidentGeometry`
  passes `drawText: widget.drawText` to `DraftPainter` (replacing the
  hard-coded `true` and rewriting the comment beside it: with text drawn by
  the arm, `DRAW_TEXT=false` is now the criterion-11 control, not a way to
  undercount).
- The collector: `measurer: harnessMeasurer, textStyleOf:
  widget.document.textStyleOf`.
- After the walk: `final classifyWatch = Stopwatch()..start(); final patches
  = classifyTextPatches(collector.data, collector.instanceCount,
  collector.texts, devicePixelRatio: dpr); classifyWatch.stop();` — `dpr`
  read once from `MediaQuery` beside the existing read.
- `ResidentGeometry.create(collector.data, collector.instanceCount, texts:
  collector.texts, patches: patches, devicePixelRatio: dpr, maxPatchWidth:
  (widget.viewport.width * dpr).round(), maxPatchHeight:
  (widget.viewport.height * dpr).round())`.
- `GpuDrawBackend(geometry, collectionCamera, measurer: harnessMeasurer,
  textStyleOf: widget.document.textStyleOf)`.
- `GpuArmPainter.paint`: replace the `render` + `drawImageRect` pair with
  `backend.paint(canvas, camera.value, size, devicePixelRatio);` and rewrite
  its ownership comment: the main image and each patch image are now handles
  the compositor records into the picture, same lifetime argument, `1 + P`
  per frame instead of one.
- The `GSPIKE collect+upload` line grows: `textOps=N patches=P
  subBuffer=X.XX MB patchTargets=Y.YY MB classify=Z.Z ms` — `subBuffer` is
  `geometry.byteLength - ResidentGeometry.byteLengthFor(instanceCount)`.
- Per phase, arm C: a new line `GSPIKE C | phase | patches rendered=R
  clipped=C offscreen=O` from the backend's counters read after the phase.
- The `GSPIKE note` text: remove "text: Plan E's job"; say text is drawn
  through the compositor and how many patches the corpus has; say
  `DRAW_TEXT=false` is the criterion-11 control.
- The section comment at the top of the file: rewrite the paragraph *"What
  arm C still does not draw"* — nothing, since Plan E; what remains not
  wired is `DraftCanvas` (Plan F).

- [ ] **Step 4: `launch.json`**

Two configurations after the fills pair, same shape:

- `2d: GPU spike -- text ON (criterion 11, DRAW_TEXT=true)`: the measurement
  scale's defines plus `--dart-define=SPIKE_TEXT=true`.
- `2d: GPU spike -- text ON, DRAW_TEXT=false (criterion 11 control)`: the
  same plus `--dart-define=DRAW_TEXT=false`.

With a comment on each saying the pair is read as a difference and neither
number means anything alone.

- [ ] **Step 5: All three gates, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd ../../apps/dev_harness_2d && flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git add apps/dev_harness_2d/lib/main.dart apps/dev_harness_2d/lib/gpu_arm.dart \
  apps/dev_harness_2d/test/spike_text_test.dart .vscode/launch.json
git commit -m "feat(harness): arm C draws text, and SPIKE_TEXT puts labels it must patch in the corpus"
```

---

### Task 8: Mutation testing

**Files:**
- Create: `docs/superpowers/notes/plan-e-mutation-log.md`

For each mutation: `cp` the file to a backup, apply the edit, run the named
test, **paste the failing output verbatim**, restore from the backup, run
the test again green. A survivor is declared with a reason, never with a
threshold moved.

| id | mutation | must go red in |
|---|---|---|
| M-E1 | `classifyTextPatches` returns `[]` (spec: *draw all text in one pass*) | `text_order_test` "drawing all text in one pass" is the seam; the source mutation must ALSO fail the four-scale rows |
| M-E2 | the inner loop starts at `0` instead of `t.instanceIndex` (spec: *admit an instance emitted before the label*) | `text_patches_test` "an instance emitted BEFORE"; `text_order_test` at scale 1 (stroke 900 over COVERED) |
| M-E3 | `reachDevice = 0` for every kind (spec: *test the centerline*) | `text_patches_test` "centerline misses"; `text_order_test` (GRAZED) |
| M-E4 | `unitsPerDevicePixel = 1.0 / devicePixelRatio` (spec: *expand at the reference scale*) | `text_patches_test` "expanded at the band floor"; `text_order_test` at scale 0.5 |
| M-E5 | `_patchPaint.blendMode = BlendMode.srcOver` (spec: *`srcOver` instead of `srcATop`*) | `text_compositor_test` "translucent later fill"; `text_order_test` (fill 904) |
| M-E6 | `hits.add(i)` unconditionally (spec: *classify every label as a patch*) | `text_order_test` "the label nothing later reaches" (`patchCount 2` → 4) |
| M-E7 | join reach `half` instead of `half * kMiterLimit` (spec: *per-instance miter length*) | `text_patches_test` "a join's reach" |
| M-E8 | `points = 3` for a point (Ruling E4) | `text_patches_test` "a point's box" |
| M-E9 | `saveLayer` opened after `canvas.transform(_matrix)` (Copilot finding 4) — move the `saveLayer` call into `_drawLabel` after the transform | `text_compositor_test` "outer transform once" and the srcATop test (layer misplaced → patch clipped) |
| M-E10 | drop the baseline flip (`translate`/`scale(1,-1)`) in `_drawLabel` | `text_order_test` every row (the reference flips) |
| M-E11 | the box pad at the band ceiling: `kBandUpperScale` in place of `kBandLowerScale` in `text()` (Ruling E9) | `resident_text_test` "the pad is one device pixel at the band floor" |
| M-E12 | the compositor matches patches by position (`patches[i]`) instead of by `textIndex` | `text_compositor_test` "one cursor" |
| M-E13 | `patchRegionFor` clamps with `x0 = minX.floor()` unclamped (negative origin) | `text_patches_test` "partly off the top-left" |
| M-E14 | `sub.setRange` copies `hits[k]` in reverse (`hits.reversed`) | `text_patches_test` "keeps main-buffer order" |

Fourteen. **If M-E1 as a source edit and as the seam disagree** — the seam
goes red and the source edit does not — the seam is not measuring the
classifier and Task 5 has a defect; stop and ledger it.

- [ ] **Step 1: Run all fourteen, in a new file; commit the log**

```sh
git add docs/superpowers/notes/plan-e-mutation-log.md
git commit -m "docs: Plan E's mutation log"
```

---

### Task 9: The device run, criterion 11, the results note, and the resume point

**Files:**
- Create: `docs/superpowers/notes/2026-09-04-plan-e-results.md`
- Modify: `STATUS.md`

- [ ] **Step 1: Two runs, macOS profile, Low Power Mode OFF, and say so**

```sh
cd apps/dev_harness_2d
flutter run -d macos --profile --dart-define=RUN_GPU_SPIKE=true \
  --dart-define=ENTITIES=10000 --dart-define=SPIKE_DEFS=20 \
  --dart-define=SPIKE_INSTANCES=150 --dart-define=SPIKE_FRAMES=30 \
  --dart-define=SPIKE_REPEATS=3 --dart-define=SPIKE_FILLS=true \
  --dart-define=SPIKE_TEXT=true
# then the same with --dart-define=DRAW_TEXT=false
```

Record from the first run: `textOps`, `patches`, `subBuffer`, `patchTargets`,
`classify` ms, and per phase `patches rendered / clipped / offscreen`. From
both: arm C's build and raster p50 per phase, per repeat; the **median of
three** per phase; the **difference** between the runs, build and raster
summed, per phase. **Criterion 11 is the hold and pan phases' difference ≤
0.5 ms.** Zoom is reported beside it. If `patches` is `0`, the run measures
nothing — stop and fix `_addPatchedLabels` before recording a number.

- [ ] **Step 2: Criterion 6 and criterion 7's share**

`buffer + subBuffer` against 8 MB (Plan D measured 6.51 MB without text);
`classify` ms against the 16.67 ms rebuild budget (Plan C's rebuild is
already a recorded MISS at 115 ms; this adds to that number and is recorded
as its share, not as a pass).

- [ ] **Step 3: Look at the window, and write down what you saw**

Plan E's five checks:

1. labels are **drawn**, right way up, at the size and place arm A draws them;
2. a `ROOM n` label's crossing stroke is visible **over** its glyphs — and
   the same stroke is **not** drawn over the empty space beside the glyphs
   any differently from arm A;
3. panning keeps the patched stroke over the label with no lag and no seam
   at the label's box edge;
4. zooming in to 2× and out to 0.5× keeps the label sharp (it is a paragraph,
   not a bitmap) and the stroke over it at every step;
5. `DRAW_TEXT=false` shows the same drawing with no labels and no patches.

Plan B's four, Plan C's five and Plan D's five remain formally OWED (STATUS
"Resume here"); one run can discharge all nineteen, and the note lists each
as discharged or still owed, per what was actually seen.

- [ ] **Step 4: The results note**

`docs/superpowers/notes/2026-09-04-plan-e-results.md`, following Plan D's:
the criterion table with PASS/MISS and the number beside each, the mutation
summary, what the plan's own premises measured false, the device-run
conditions, the two-run difference table for criterion 11.

- [ ] **Step 5: STATUS.md**

Plan E's state, the resume point, the nineteen window checks in whatever
state Step 3 left them, and the sentence that Plan F is next (rebuild
triggers, the band, `DraftCanvas`'s `residentGpu` path — which now has a
`paint` to call).

- [ ] **Step 6: All gates, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd ../../apps/dev_harness_2d && flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git commit -m "docs: Plan E's results, criterion 11's first number, and what the window showed"
```

---

## Exit gate

Pre-committed. Thresholds are not moved to make a criterion pass; a miss is
recorded as a miss with its number.

1. **Composited differential, text corpus:** per-channel ≤ 2 on ≥ 99.5% of
   the union, ≤ 8 on the rest, at all four band scales `0.5, 0.8, 1.25, 2.0`,
   with `referenceInk > 5000` and `patchCount ≥ 1` on every row.
2. **The order gate:** with no patches the same corpus disagrees on > 200
   pixels by more than 8 and falls below 99.5%; with patches it passes.
3. **Exactly the covered labels are patches:** `patchCount == 2` on the
   fixture (COVERED, GRAZED), never 4.
4. **`skippedOps == 0`** on every collector built with a measurer, on every
   corpus in the suite.
5. **Criterion 11:** hold + pan text-pass difference ≤ 0.5 ms p50, arm C,
   median of three; `patches ≥ 8` on the corpus; the patch count, the text-op
   count, `classify` ms, `subBuffer` and `patchTargets` MB all in the note.
6. **Criterion 6:** `buffer + subBuffer ≤ 8 MB` at 10,000 entities with
   fills and text, measured.
7. **All fourteen mutations fire**, each with pasted output; survivors
   declared with a reason.
8. **No shader or bundle change** in the branch's diff (`git diff --stat
   main..HEAD -- packages/jet_cad_2d_flutter/shaders
   packages/jet_cad_2d_flutter/assets` is empty).
9. **A human looks at the window** and reports Plan E's five checks — and
   the fourteen still owed.
10. Every gate green in `packages/jet_cad_2d_flutter`, `packages/jet_cad_2d`
    and `apps/dev_harness_2d`.

---

## Self-review

**Spec coverage.** Revision 5's text section: the resident text list is Task
1 (six floats flat, string, style, `resolved.argb`, instance index, the
four-corner padded box — Ruling E9 corrects the pad's scale and the spec);
classification, per-kind reach, the miter bound, the band floor, the
sub-buffer as a by-product, "candidate not ink" — Task 2; the per-frame
arrangement — main pass, patch passes anchored at the target's origin with a
region-sized `FrameInfo`, the compositor's `saveLayer` in the outer frame,
one paragraph helper with the baseline flip, `srcATop` — Tasks 4 and 6; "no
GPU resource allocated per frame", the target sized at the ceiling and
reused, the named per-patch exception — Task 6 and Global Constraints; the
cost statement — Task 7's `classify` ms and criterion 11's two-run
difference; criterion 11 as rewritten — Ruling E10, Task 7, Task 9; the
corpus's six text items — Task 3 (five) and Task 5 (the four scales); the
seven text mutations in the spec's list — M-E1..M-E7; the budget row — Task
6's `byteLength` and Task 9. **Not covered, deliberately:** the band's real
value and the watermark rebuild (Plan F, Ruling E3), `DraftCanvas`'s
`residentGpu` path (Plan F, Ruling E7), web (Plan G — but `asImage()`'s
ordering on web is handled in Task 6 so Plan G inherits no trap), an
allocation instrument for the frame path (spec invariant 1's "new mechanism",
which the spec assigns to the plan that wires the widget — Plan F).

**Placeholder scan.** No "TBD", no "handle edge cases", no "similar to Task
N". Three steps name work whose exact shape depends on what the package
actually exposes rather than on a decision, and each names the fallback:
Task 3's record/instance accessors (`slotOf` + `*At` getters), Task 3's
`lineweightOverride` (rebuild the document if there is no modify command),
Task 5's white-ground question (draw white on both arms). Task 6's
`asImage()` placement is decided (after `submit()`), with the reason.

**Type consistency.** `ResidentTextRecord` has the fourteen fields of the
restatement in every task that constructs one (Tasks 1, 2, 4). `TextPatch`
is `(textIndex, instances, instanceCount)` in Tasks 2, 5, 6, 7.
`classifyTextPatches(data, count, texts, {devicePixelRatio, bandLowerScale})`
is called with that shape in Tasks 2, 5, 7. `patchRegionFor(t, m, w, h,
{maxWidth, maxHeight})` in Tasks 4, 5, 6. `PatchImage(textIndex, image, src,
dst, layerBounds)` in Tasks 4, 5, 6. `TextCompositor.paint(canvas, {main,
viewport, collectionToLogical, texts, patches})` in Tasks 4, 5, 6.
`ResidentGeometry.create(instances, count, {texts, patches, devicePixelRatio,
maxPatchWidth, maxPatchHeight})` in Tasks 6, 7. `GpuDrawBackend(geometry,
collectionCamera, {measurer, textStyleOf})` and `paint(canvas, camera,
viewport, dpr)` in Tasks 6, 7. `ResolvedStyle` spells four named arguments
in every literal. `TextStyleRecord` is spelled as `canvas_draw_sink_test.dart`
spells it.
