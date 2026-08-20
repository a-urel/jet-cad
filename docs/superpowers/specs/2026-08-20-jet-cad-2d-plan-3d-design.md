# jet_cad_2d Plan 3d — The vertices sink

**Status:** draft, awaiting review
**Parent:** [2026-07-27-jet-cad-2d-architecture-design.md](2026-07-27-jet-cad-2d-architecture-design.md)
**Carried in from:** [2026-08-20-dash-leaf-separation.md](../notes/2026-08-20-dash-leaf-separation.md) and [2026-08-20-vertices-sink-spike.md](../notes/2026-08-20-vertices-sink-spike.md)
**Written against:** `main` at `bb67137` (Plans 1, 2, 3a, 3b and 3c merged) and
the spike branch `spike/vertices-sink` at `d0e872e`. Every fact below was read
off that tree, not remembered.

## Summary

The frame is bound by the number of canvas calls it makes, and by nothing else
that has been measured. Holding the drawn geometry fixed at
`screenSpaceLeafCount=1664` and moving only `dashedFraction` moved the frame
**6.0x**, from 57.2 ms to 9.5 ms, with `build` linear in call count to within
30 µs across a 12.8x range. Reading Impeller at the revision that produced
those numbers shows why nothing cheaper is available on the current path: a
dash span is a two-point path, so `dl_dispatcher.cc:622` lowers it through
`IsLine` to `AttemptDrawLineSDF` and it never reaches the stroke tessellator.
There is no tessellation left to remove. What is left is one Impeller `Entity`
per call.

The spike built the only lever that acts on that: `VerticesDrawSink` builds
each stroked segment's two triangles itself and submits the frame's strokes as
one ordered `drawVertices`. At 10,000 entities the frame goes **57.3 ms to
14.3 ms** — about 17 fps to about 70, inside the 16.67 ms budget for the first
time — while the *segment* count goes **up** 2.3x. More triangles, fewer
entities, faster frame.

3d turns that spike into a shippable renderer. One plan, three phases, and the
order is not negotiable:

| Phase | Contents |
|---|---|
| **A — the sink** | backend selection, joins and caps, the allocation question, text, and the retirement of the spike's measurement-only defines |
| **B — the apparatus** | a pure-Dart triangle rasterizer, goldens on both backends, and the sink-against-sink coverage test |
| **C — measurement** | 10k / 50k / 500k on both backends, desktop and web, and the results note |

Phase B comes before C because a measurement of a renderer nobody has looked at
is worth nothing: **both of the spike's bugs were found by looking at a
screenshot, not by a test that failed.**

### Renumbering

This plan takes the letter **3d**, which the carry-forward note assigned to
fills. Fills move to **3e** and the caches, tiles and `documentRevision` to
**3f**. The order changed because a fill is triangles: 3e writes its fill path
once, against a sink that already batches triangles in draw order, instead of
writing it against `CanvasDrawSink` and again afterwards. The carry-forward
note's items keep their content and change only their letter; item 2 (the
`fill.handle < boundary.handle` problem) is unaffected, because this plan
strengthens rather than weakens the draw-order guarantee it depends on.

## Non-goals

- **Round joins and caps.** `CanvasDrawSink` ships Flutter's `Paint` defaults —
  `StrokeCap.butt` and `StrokeJoin.miter` — and the 14 goldens pin them.
  Changing the appearance and changing the renderer in one plan makes every
  golden diff unreadable. Whether CAD convention wants round ends is a real
  question and it gets its own decision later, on one line of the new sink.
- **Text as triangles.** A paragraph is not triangles. Text keeps going to
  `CanvasDrawSink`, and the buffer flushes before it so ordering holds.
- **Fills, hatch, `documentRevision`, tiles, the picture cache.** 3e and 3f.
- **`flutter_gpu`.** It ships in the SDK and it is the escape hatch if
  `drawVertices` had not been enough. It was enough. Recorded, not used.
- **Removing `CanvasDrawSink`.** The spike note proposed retiring it. Web
  changes that; see below.
- **A DXF or SVG codec.** Neither exists (`packages/jet_cad_2d/lib/src/codec/`
  holds `json_codec.dart` and `schema_version.dart` and nothing else) and
  neither is 3d's business.

## What the tree constrains

Verified against `main` at `bb67137` and the spike at `d0e872e`.

1. **`DrawSink` has seven methods** — `beginResidual`, `endResidual`, `point`,
   `polyline`, `circle`, `arc`, `text` — and five implementations once
   `VerticesDrawSink` lands: `CanvasDrawSink`, `RecordingDrawSink`,
   `NullDrawSink`, the rig's `TextKeySink`, and the new one.
2. **The painter never emits a closed polyline.** `closed:` is `false` at all
   four call sites in `draft_painter.dart` (208, 507, 520, 580). The parameter
   exists on the interface and is dead on the frame path. 3d must not remove
   it — 3e's fills will need it — but it may not rely on it either.
3. **`kLogicalPixelsPerMm` is `96.0 / 25.4`** (`draft_canvas.dart:18`), so the
   corpus's thinnest lineweight, 0.25 mm, is 0.945 logical pixels.
4. **Impeller floors a stroke at one device pixel and fades the alpha below
   it.** `kMinStrokeSize = 1.0f` (`impeller/entity/geometry/geometry.h:19`),
   applied at `line_geometry.cc:24`; the fade is
   `clamp(scaled_stroke_width * 2, 0, 1)` at `geometry.cc:148`, with a width of
   exactly zero taking full coverage as the hairline case.
5. **The miter limit is 4.0** (`painting.dart:1535`), and Impeller turns it
   into a cosine threshold: `2 * (1 / limit)^2 - 1`
   (`stroke_path_geometry.cc:442`). At 4.0 that is **-0.875** — a corner is
   mitred while the cosine of the direction change is at or above it, and
   bevelled below.
6. **All 14 golden PNGs contain strokes.** The text ladder carries an
   `EntityKind.polyline` as well as its text, so no golden escapes the sink
   swap by drawing text alone.
7. **`flutter_test` cannot render this sink.** Its software Skia backend did
   not finish a `drawVertices` of 1,007 segments in 7 minutes 28 seconds, where
   Impeller draws it instantly.
8. **The frame path is required to allocate nothing in steady state**
   (`CLAUDE.md`), and `query_allocation_test.dart` measures the *query* path,
   not the sink.
9. **`RecordingDrawSink` equality is the project's primary correctness
   mechanism** (`draw_sink.dart:11-16`) and it compares ops. A sink that emits
   no ops is outside it.

## Decisions carried in, not to be relitigated

These were settled in the design conversation of 2026-08-20 and are inputs.

- **The vertices sink is the default on desktop and mobile; `CanvasDrawSink`
  is the default on web and remains the fallback.** Both are production.
- **Joins and caps match Flutter's `Paint` defaults**: butt caps, miter joins,
  limit 4.0, bevel beyond it.
- **Goldens are rasterised by a rasterizer this repository owns**, in pure
  Dart, rather than by Skia or Impeller.
- **Fills are not in this plan.**

## Phase A — the sink

### Backend selection has one resolution point

A `RenderBackend` enum with two values, `canvas` and `vertices`, resolved once
in `DraftCanvas` from `kIsWeb` and overridable by an optional widget
parameter. Not a `bool`, because a third backend is foreseeable
(`flutter_gpu`), and not read in more than one place, because two call sites
that each decide would eventually disagree.

The widget owns both sinks' lifetimes as it owns `CanvasDrawSink`'s today: one
per widget, rebound per paint, so a prop change that recreates a sink does not
throw away the paragraph cache behind it.

### The two backends must draw the same picture

This is the invariant that makes two production paths tolerable, and it is the
reason joins and caps match `Paint`'s defaults rather than being chosen fresh.
It is not a claim the spec makes; it is a test Phase B writes.

Where they may differ, and only here:

| | Reason |
|---|---|
| Anti-aliasing | The canvas path anti-aliases analytically through the SDF; the vertices path gets MSAA. A coverage comparison must therefore be at a tolerance, not exact. |
| Sub-pixel strokes | Both apply the same two rules (fact 4), but the canvas path applies them in the engine and the vertices path in Dart, so they round differently in the last bit. |

Anything else is a defect.

### Joins and caps

Every segment is a quad today, so a polyline's corners have a notch on the
outside. 3d closes it:

- **Caps are butt.** The quad ends at the endpoint. This is what the sink
  already does, and it needs a test rather than a change.
- **Joins are miter, with bevel past the limit.** At each interior vertex,
  offset the two adjacent segment edges on the outside of the turn and add the
  triangle that fills the notch out to their intersection. When the cosine of
  the direction change falls below **-0.875** (fact 5), fill to the bevel
  instead: the triangle between the two outer corners and the vertex.
- **A zero-length segment contributes no direction** and is skipped, as it is
  now; the join is then taken between the segments either side of it.
- **A closed polyline joins at the seam rather than capping.** Dead on the
  frame path today (fact 2), live for 3e, and cheap to get right now.

The join belongs to the *pair* of segments, so it is emitted by the polyline
walk and not by `_emitSegment`. Curves are flattened into chords by the same
walk and get the same joins, which is what keeps a thick dashed arc from
showing 40 notches.

### The allocation question

`flush()` allocates `Vertices.raw`, two `sublistView`s and a `Paint` — about
four objects per flush, and with 18 text ops in the corpus that is about 76 per
frame. The non-negotiable says the frame path allocates **nothing** in steady
state (fact 8).

**3d does not relax the non-negotiable by assertion.** It does three things, in
order:

1. **Measure it.** Extend the allocation invariant to the paint path, with a
   `NullDrawSink` control and the vertices sink as the subject, and record what
   a steady-state frame actually allocates through each. Today nobody knows,
   because the measurement covers queries only.
2. **Remove what can be removed.** The `Paint` is a field, not a local, in
   every other sink here; there is no reason it is not one in this one. The two
   `sublistView`s are views over a reused buffer and allocate a wrapper each.
3. **State the residue and its bound.** If a `Vertices` object cannot be reused
   across frames — the plan must check whether `Vertices` is disposable and
   whether a raw one may be retained — then the residue is **O(1) per flush,
   not O(entities)**, and the non-negotiable is amended in `CLAUDE.md` to say
   so in those words, with the measured number beside it.

An amendment with a measurement behind it is a decision. Silence would be a
breach.

### Text, and why `CanvasDrawSink` survives

Text goes to `CanvasDrawSink` and the buffer flushes before it, so no stroke
batched earlier draws after it. That is already true on the spike and needs
only its test kept.

The spike note proposed retiring `CanvasDrawSink` once the vertices sink took
over. The web decision cancels that: it is the web backend, so it is production
code with production tests, and the composition the spike uses for text is no
longer a transitional shape.

### The defines come out

`DraftCanvas.useVertices` and the harness's `VERTICES` define exist so a spike
could be measured against a baseline. Once the backend is chosen by platform
they are the wrong control: the rig needs to force a *backend*, not to toggle a
sink. `useVertices` is replaced by the `RenderBackend` parameter and the
harness define becomes `BACKEND=canvas|vertices`, defaulting to the platform's
own choice so an ordinary run measures what a user gets.

`DASHED`, `TEXT`, `DRAW_TEXT`, `LINEWEIGHT_SCALE` and `ENTITIES` stay as they
are.

## Phase B — the apparatus

### A rasterizer this repository owns

Pure Dart, in `test/support/`: walk the sink's triangle buffer, scan-convert
each triangle into a coverage-and-colour buffer, write a PNG. No
anti-aliasing — a pixel is inside a triangle or it is not. It is a test
support file and never ships in `lib/`.

It is worth its own code for three reasons. It does not depend on a renderer
that cannot cope (fact 7). It is deterministic across machines and Flutter
versions, where the existing goldens are not. And it tests **production
geometry**: the buffer it reads is the buffer Impeller draws.

What it does not do is anti-alias, which means its goldens are of coverage and
not of appearance. That is the right trade for a regression test and the wrong
one for judging how a drawing looks; the screenshot on the device stays the
instrument for the second question, and the plan says so rather than pretending
one artefact does both jobs.

### Goldens, on both backends

The existing 14 PNGs keep their fixtures and their assertions and are pinned to
the **canvas** backend, which is the web renderer. They are not dead-code tests
after the web decision; they are the web backend's regression suite.

The same fixtures are rendered again through the **vertices** backend and the
rasterizer, into their own PNGs. Both sets are checked in. A fixture that
cannot be drawn by one backend does not exist.

### The sink-against-sink coverage test

The new test, and the one that earns the two-backend decision. For a fixture
carrying every primitive: render it through `CanvasDrawSink` into an image with
`flutter_test`, render it through `VerticesDrawSink` and the rasterizer, and
compare coverage at a tolerance that admits the two rows of the table above and
nothing else.

The tolerance is a number this plan measures rather than guesses: the plan
records the observed per-pixel disagreement on the fixture and sets the bound
above it with the margin stated.

### What the existing differential oracle keeps doing

`test/support/vertices_differential.dart` stays as the spike wrote it, with its
three recorded blind spots. It answers a different question from the
sink-against-sink test — "is the ink where the *walk* says", against "do the two
backends agree" — and neither subsumes the other.

## Phase C — measurement

Every row on an M3 Pro with Low Power Mode **off** and `pmset -g` checked after
the run, because Plan 3c's results note is contaminated by it and the
re-measurement showed a uniform ~24% on both raster and build.

| Rig | Corpus | Backends |
|---|---|---|
| R2 pan and zoom | 10,000 / 50,000 / 500,000 | canvas, vertices |
| R4a leaf edit | 50,000 | canvas, vertices |
| R4b instance drag | 50,000 | canvas, vertices |
| R2, `--platform chrome` | 10,000 / 50,000 | canvas, vertices |

Three consecutive runs per row, median reported, spread reported beside it. A
single reading is not a measurement: the spike recorded 6.88 ms once and 8.47
to 8.87 ms on every run after it, and only the repetition showed which was the
outlier.

The web rows are the ones that can still change a decision. If CanvasKit's
`drawVertices` is slower than its `drawPath` at these counts, the platform
default stands as written and the plan records why. If it is faster, the
default flips for web too and `CanvasDrawSink` becomes a fallback with no
default platform — which is a smaller change than it sounds, because both
backends are staying either way.

## Testing

### Mutants that must be killed, and the fixture property each one needs

The spike ran 33 against the sink as it stands and killed 32, with one not
applicable. These are the ones Phase A adds.

| # | Mutation | Needs |
|---|---|---|
| J1 | Emit no join triangle at an interior vertex | A polyline with a corner and a lineweight wide enough that the notch is more than one pixel |
| J2 | Miter every corner, ignoring the limit | A corner sharper than the -0.875 threshold |
| J3 | Bevel every corner, ignoring the limit | A corner shallower than it |
| J4 | Take the miter on the inside of the turn | A corner that turns in a known direction |
| J5 | Join the first and last segment of an *open* polyline | An open polyline whose ends are near each other |
| J6 | Skip the join between two chords of a flattened curve | A thick dashed arc |
| B1 | Resolve the backend per call site rather than once | A test that overrides the backend and reads it back from both the widget and the rig |
| B2 | Ignore the backend override, always use the platform default | The same |
| A1 | Allocate the `Paint` per flush | The extended allocation invariant |

### The tests that carry the design

- The 24 unit tests the spike wrote, unchanged.
- The differential oracle's four, unchanged.
- Join and cap geometry, one test per row of the mutant table above.
- The extended allocation invariant, with its `NullDrawSink` control.
- The sink-against-sink coverage test.
- Goldens on both backends.

### Existing tests this plan rewrites

The 14 golden tests gain a backend parameter and keep their PNGs. Nothing else
in the suite changes; `differential_test.dart` compares op streams and is
indifferent to which sink draws them.

## Exit gate

Every criterion is failable and each names how it is checked.

1. Engine suite and widget suite green, analyze and format clean in both
   packages.
2. Every mutant in the table above killed by a named test, recorded in
   `docs/superpowers/notes/plan-3d-mutation-log.md`.
3. The sink-against-sink coverage test passes on a fixture carrying point,
   polyline, circle, arc and text, at a tolerance whose value is justified by a
   recorded measurement.
4. Goldens exist and pass on both backends for all 14 fixtures.
5. **At 10,000 entities on the working-set camera, the vertices backend's
   frame is under 16.67 ms**, median of three, spread recorded.
6. At 50,000 and 500,000, the vertices backend's raster p50 is **better than**
   the canvas backend's by more than the run-to-run spread of either, median of
   three. "No worse than" would pass on noise; the plan exists to make the
   frame faster, so a tie at 500,000 is a failure that reopens the design.
7. The allocation invariant covers the paint path and passes, with the residue
   measured and either zero or bounded and written into `CLAUDE.md`.
8. The web rows are measured and the platform default is stated with the number
   that justifies it.

Criteria 5 and 6 are the plan's purpose. 3 and 7 are the ones most likely to
fail, and failing them is a result, not a delay.

## What 3d owes the plans after it

- **3e (fills).** A triangle buffer that is already appended to in draw order,
  and a flush that already happens before anything unbatchable. The
  `fill.handle < boundary.handle` question is unchanged and still 3e's to
  answer; 3d only makes the guarantee it relies on stronger.
- **3f (caches and tiles).** A picture cache that records into a `Picture`
  interacts with a sink that batches across residuals. 3f must decide whether a
  cached picture flushes the buffer at its boundary — 3d's `_flushBeforeUnbatchable`
  is the shape that decision extends.
- **Whoever chooses round joins.** One branch, in one method, with a golden on
  each backend to show the difference.

## Risks

- **The join geometry is where the bugs will be.** Miter, bevel, the limit, the
  inside-versus-outside of a turn, and near-180° reversals are five ways to be
  wrong and they are all invisible at hairline widths, which is most of a CAD
  drawing. Mitigated by the mutant table demanding a fixture property for each,
  and by goldens at a lineweight where the corner is visible.
- **The rasterizer becomes a second renderer to maintain.** Mitigated by
  keeping it coverage-only and by the sink-against-sink test, which fails if it
  drifts from what Skia draws.
- **Two production backends drift apart.** This is the standing cost of the web
  decision. Mitigated by the sink-against-sink test being an exit criterion
  rather than a nice-to-have.
- **The allocation residue turns out to be unavoidable and larger than
  expected.** Then criterion 7 fails and the plan reports it. A non-negotiable
  amended with a measurement is a decision; one amended to make a plan pass is
  not.
- **CanvasKit makes the web rows bad enough to want a third path.** Out of
  scope by construction: the fallback already exists and is already the web
  default.
