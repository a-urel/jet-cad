# jet_cad_2d Plan 3d — The vertices sink

**Status:** draft, awaiting review
**Parent:** [2026-07-27-jet-cad-2d-architecture-design.md](2026-07-27-jet-cad-2d-architecture-design.md)
**Carried in from:** [2026-08-20-dash-leaf-separation.md](../notes/2026-08-20-dash-leaf-separation.md) and [2026-08-20-vertices-sink-spike.md](../notes/2026-08-20-vertices-sink-spike.md)
**Written against:** `main` at `bb67137` (Plans 1, 2, 3a, 3b and 3c merged) and
the spike branch `spike/vertices-sink` at `d0e872e`, which was that branch's
head while this was written and is now its second commit back — this document
and the revision below are the two after it. Every fact was read off that tree,
not remembered.
**Revised:** 2026-08-20, after three independent reviews. Their findings and
what changed are at the end.

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
in `DraftCanvas` and overridable by the caller. Not a `bool`, because a third
backend is foreseeable (`flutter_gpu`), and not read in more than one place,
because two call sites that each decide would eventually disagree.

The contract, in full, because a widget parameter is public API and a test
needs to know what it may ask for:

- `DraftCanvas` takes `RenderBackend? backend`, defaulting to `null`.
- `null` means "the platform's own choice", resolved in one function:
  `kIsWeb ? RenderBackend.canvas : RenderBackend.vertices`.
- A non-null value is **honoured on every platform**, including
  `RenderBackend.vertices` on web. It is not clamped, because the web
  measurement in Phase C needs to force it, and a parameter that silently
  ignores what it is given is worse than one that is slow.
- `devicePixelRatio` reaches `VerticesDrawSink` the way the spike already does
  it: read in `build` from `MediaQuery.devicePixelRatioOf(context)` and
  assigned to the sink, never cached at construction, because the ratio
  changes when a window moves between displays.
- The resolved backend is readable from `DraftCanvasState`, so a rig reports
  what it measured rather than what it asked for.

The widget owns both sinks' lifetimes as it owns `CanvasDrawSink`'s today: one
per widget, rebound per paint, so a prop change that recreates a sink does not
throw away the paragraph cache behind it.

### The two backends draw the same picture, except where the vertices one is
### more correct

The first draft of this spec said the backends may differ only on
anti-aliasing and rounding, and that anything else was a defect. **That is
false, and it is false by construction rather than by accident.** Two of the
divergences are things the vertices sink does *better*, and a comparison
written against the earlier claim could only pass on a fixture at the identity
transform — the degenerate fixture `CLAUDE.md` names as this repository's
dominant failure mode.

**The vertices backend is authoritative.** Where the two disagree below, the
canvas backend is the one being bounded, and the bound is "close enough that a
drawing is recognisably the same", not "identical".

| Divergence | Which is right | Why |
|---|---|---|
| **Anisotropic stroke width** | vertices | `CanvasDrawSink._widthFor` divides the width by `scaleMagnitude`, `sqrt(\|det\|)` — one scalar standing in for two axis scales, exact only when the residual is conformal. The vertices sink takes the perpendicular *after* transforming the endpoints, so the half-width is a device-pixel quantity on both axes. Under a non-conformal residual the two draw different widths, not different last bits. |
| **Point shape** | neither, they are different conventions | `CanvasDrawSink.point` pushes the residual onto the canvas and calls `drawRawPoints`, so the square cap rotates and shears with the residual. The vertices sink emits a device-space axis-aligned square. Under a rotated residual these are different squares. 3d picks one — the axis-aligned square, because a point marker that shears is not what a point marker is for — and changes `CanvasDrawSink` to match. |
| **Anti-aliasing** | canvas | Analytic SDF coverage against MSAA. Not fixable on the vertices path without a coverage shader, and out of scope. |
| **Sub-pixel strokes** | vertices, but untestable by comparison | See the next section. |
| **Overlapping translucent strokes** | canvas | A stroked path unions its coverage; a triangle soup does not, so two quads that overlap at a near-180° reversal double-blend. Inert while the corpus is opaque (`argb`'s alpha is `255 - transparency`, `resolved_style.dart:15`), live the moment 3e adds fills. Recorded, not fixed. |

Anything **not** in this table is a defect.

### Joins and caps

Every segment is a quad today, so a polyline's corners have a notch on the
outside. 3d closes it:

- **Caps are butt.** The quad ends at the endpoint. This is what the sink
  already does, and it needs a test rather than a change.
- **Joins are miter, with bevel past the limit, and a miter is two triangles.**
  The notch at an interior vertex is the quadrilateral `(V, A, M, B)` — the
  vertex, the outer corner of the incoming segment, the miter point where the
  two offset edges meet, and the outer corner of the outgoing one. Filling it
  takes the **bevel triangle `(V, A, B)` and the tip triangle `(A, M, B)`**.
  One triangle alone leaves a hairline crack at every mitred corner, which is
  invisible in a unit test that only counts triangles and obvious in a golden
  at a visible lineweight. When the cosine of the direction change falls below
  **-0.875** (fact 5), emit the bevel triangle alone.
- **A zero-length segment contributes no direction** and is skipped, as it is
  now; the join is then taken between the segments either side of it.

The join belongs to the *pair* of segments, so it is emitted by the walk and
not by `_emitSegment`. There are **two** walks today — `polyline` and
`_flatten` — and the join code is shared between them rather than written
twice; a thick dashed arc showing 40 notches and a thick polyline showing none
is the failure that shape prevents.

A closed walk joins at its seam instead of capping. That is live for `circle`,
which is a `_flatten` at a full sweep whose last chord lands on its first
point: without a seam join every circle at a visible lineweight carries one
notch at its start angle. It is dead for `polyline`, which the painter never
calls with `closed: true` (fact 2) — but it is directly reachable from a test,
`sink.polyline(..., closed: true)` needs no painter, so it lands with a test
and a mutant rather than as unreached code. The spike's one not-applicable
mutant was this same branch; 3d does not add a second.

### `Vertices` is disposable, and the spike never disposes

`Vertices` extends `NativeFieldWrapperClass1` and carries a real
`void dispose()` over a native `Vertices::dispose` symbol, with `_disposed`
and `debugDisposed` beside it
(`sky_engine/lib/ui/painting.dart`, in the `Vertices` class body). `flush()`
builds one per flush and drops it on the floor. At 19 flushes a frame and 60
frames a second that is **1,140 undisposed native-backed objects a second**,
each holding the frame's position and colour buffers, reclaimed only when a
finalizer eventually runs.

This is not a line item inside the allocation discussion below. It is a native
memory leak in code the spike already ships, and it is Phase A's to close.

The open question the plan must settle first, by test rather than by reading:
**whether a `Vertices` may be disposed immediately after the `drawVertices`
that submitted it**, or whether the recorded `Picture` still refers to it. The
test is a device run — the frame must keep drawing, and `debugDisposed` must
read true — because a `PictureRecorder` in `flutter_test` may retain what a
real rasterisation does not. If it may not be disposed at submission, the plan
records what it costs to hold one per frame and dispose it on the next.

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
   across frames, then the residue is **O(1) per flush, not O(entities)**, and
   an amendment to `CLAUDE.md` saying so in those words, with the measured
   number beside it, is *proposed*.

An amendment with a measurement behind it is a decision. Silence would be a
breach. **The plan does not grant itself the amendment**: `CLAUDE.md` is a
governing document, criterion 7 is not satisfied by editing it, and the change
needs the same explicit approval this spec did. If the approval does not come,
criterion 7 fails and the residue has to go to zero or the plan stops. Writing
the exit gate so it can be passed by rewriting the rule it is measured against
is Ruling 4's failure mode wearing a different hat.

### What Phase A does not have to build

The spike already ships, tested, and 3d inherits rather than writes:

- Both of Impeller's sub-pixel stroke rules (fact 4), in `_halfWidthFor` and
  `_coveredArgb`, pinned by six of the 24 unit tests.
- The curve flattening and its chord-error budget.
- The single ordered buffer, the per-vertex colour, and the mid-frame flush.
- The differential oracle and its four tests.

One thing it ships that is **wrong and must be fixed**: the class comment at
`vertices_draw_sink.dart:63` still says "Points, circles, arcs and text still
go to `CanvasDrawSink`… the one place draw order is still wrong". Points,
circles and arcs have batched since the curve commit; only text falls back, and
it flushes first. A reader of the tree finds the code and the comment
disagreeing, and one review of this spec read the comment and reported an
ordering defect that does not exist. Fixing it is Phase A's first task.

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

**It is a `String.fromEnvironment`, and it stays one.** Plan 3c lost a full
device run to `bool.fromEnvironment('TEXT')` reading `--dart-define=TEXT=1` as
false while printing plausible numbers; the string form has no such hazard, and
an unrecognised value is a `StateError` at startup rather than a silent
fallback. Nobody is to helpfully convert it back to a `bool`.

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

> **Annotation, 2026-08-21 (post-implementation).** The premise of the sentence
> above — that canvas is the web renderer — was overturned by Phase C's own
> measurement and no longer holds. Task 13 flipped the default to the
> **vertices** backend on *every* platform, the web included: the within-platform
> build ratios (17.3x at 10,000 entities, 17.5x at 50,000) decided it. Both
> backends are now goldened, so the canvas PNGs are the canvas backend's
> regression suite rather than "the web backend's". The argument in this
> section is left exactly as it was written — it was correct against the
> evidence available at the time, and rewriting it would erase the fact that
> the measurement changed the answer. See
> `docs/superpowers/notes/2026-08-21-plan-3d-results.md`.

The same fixtures are rendered again through the **vertices** backend and the
rasterizer, into their own PNGs. Both sets are checked in. A fixture that
cannot be drawn by one backend does not exist.

### The sink-against-sink coverage test

The new test, and the one that earns the two-backend decision. Render a fixture
through `CanvasDrawSink` into an image with `flutter_test`, render it through
`VerticesDrawSink` and the rasterizer, and compare.

Four things about it are decided here rather than left to the implementer,
because each of them is a way for the test to pass without meaning anything.

**It compares ink regions, not pixel colours.** The rasterizer has no
anti-aliasing and a CAD stroke is about one pixel wide, so essentially every
ink pixel on the canvas side is an edge pixel. A per-pixel tolerance loose
enough to admit that admits real geometry defects with it, and the
measure-then-set-the-bound procedure would produce a number that is not a
bound on anything. The comparison is membership instead, in both directions:
every pixel the rasterizer inked must fall inside the canvas image's ink
dilated by one pixel, and every pixel of the canvas image above a stated
opacity floor must be inked by the rasterizer. That is the same shape as
`vertices_differential.dart`'s two directions, one level up.

**`flutter_test` is software Skia, so facts 4 and 5 do not hold on the canvas
side.** The one-device-pixel floor and the alpha fade are Impeller's, and the
comparison runs in an environment that has neither. Worse, `flutter_test`
defaults to `devicePixelRatio` 1, where the corpus's thinnest lineweight is
0.945 device pixels (fact 3) — every thin stroke lands in exactly the regime
the two engines treat differently. The fixture therefore **pins
`devicePixelRatio` and uses lineweights above the floor at that ratio**, and
the plan says in the test's own header that this buys agreement by excluding
the sub-pixel rules from the comparison. Those rules stay pinned by the six
unit tests that already cover them, and by nothing else.

**Text is excluded from the pixel comparison.** A paragraph never enters the
triangle buffer, so the vertices-side image has no glyphs while the canvas-side
one does. Criterion 3's fixture still *carries* text — because text forces the
mid-frame flush, and the ordering that depends on it is what the fixture is
there to exercise — but the comparison masks the text's own bounds out and
asserts the flush count instead. A fixture with text whose glyphs were compared
would fail for a reason that is not a defect; a fixture without text would not
exercise the flush at all.

**The rasterizer needs the triangles before `flush()` destroys them.**
`flush()` builds the `Vertices`, submits it and rewinds the buffer in one call,
so a test that runs after it finds an empty buffer and one that runs before it
has not exercised the code under test. Phase A adds the seam: `flush()` gains
an optional observer that is handed the position and colour views *as
submitted*, before the rewind. The rasterizer is that observer. It reads what
Impeller was given, which is the whole point of owning it — no duplicated
geometry, no second walk.

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
| R2 on web | 10,000 / 50,000 | canvas, vertices |

Three consecutive runs per row, median reported, spread reported beside it. A
single reading is not a measurement: the spike recorded one reading of 6.88 ms
that no later run reproduced, against 8.47 to 8.87 ms across the six taken
after it. It is written down in the spike note under the measurements table,
where it belongs — as the reason for the rule, not as a result.

The web rows run through `flutter drive ... -d chrome`, not
`flutter test --platform chrome`: the first is the integration-test driver the
other rows use and it needs `chromedriver` on the path, the second runs widget
tests and cannot drive the frame-timing rig. The plan pins the exact
invocation, because getting this wrong is how a web row comes back empty and
gets reported as "web is fine".

The results note also records **peak buffer bytes**, not only frame time.
`_reserve` doubles and never gives capacity back — that is what makes the
steady-state frame allocation-free, and it means one zoom-out at 500,000
entities pins the peak for the life of the widget. One line, so the number
exists before somebody is surprised by it.

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
| J7 | Emit the miter tip triangle without the bevel triangle | A mitred corner at a lineweight where the crack is more than one pixel |
| J8 | Cap the seam of a closed flatten instead of joining it | A thick circle, checked at its start angle |
| J9 | Cap the seam of a closed polyline instead of joining it | `sink.polyline(..., closed: true)` directly — no painter reaches this |
| V1 | Never dispose the submitted `Vertices` | `debugDisposed` read after a flush |
| P1 | Emit the point square in local space, so it shears with the residual | A point under a rotated residual |
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
   the canvas backend's by more than the spread, median of three. **Spread is
   `max - min` of the three runs**, chosen over a standard deviation because
   three samples do not support one; the criterion is met when the two
   backends' `[min, max]` intervals do not overlap and the vertices one is
   lower. "No worse than" would pass on noise.

   **If it ties at 500,000, that is a result and the plan says what happens
   next** rather than stalling: the working-set camera may already be culling
   the call count down to where per-`Entity` cost stops dominating, which is
   the model's own prediction and not a defect. The fallback is to record the
   crossover — the entity count above which the two backends converge — as the
   plan's finding, keep the vertices backend for the counts below it, and hand
   3f the number, because a picture cache changes exactly that arithmetic. The
   spike measured only 10,000; nothing about 500,000 is known yet, and a stop
   clause with no stated next step is how a plan stalls.
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

## Review, and what it changed

Three independent reviews of the draft. Their findings are recorded here rather
than silently folded in, because two of them found things that were true of the
shipped spike and not only of the document.

### Changed the design

- **The allowed-difference table was wrong, and wrong in the way this repository
  is warned about.** It admitted anti-aliasing and rounding and called anything
  else a defect, which made criterion 3 passable only on a fixture at the
  identity transform. Two divergences already exist in the spike and one is the
  vertices sink being *more* correct: anisotropic stroke width, where
  `CanvasDrawSink` divides by `scaleMagnitude` and the vertices sink does not
  approximate at all; and point shape, where one square shears with the residual
  and the other does not. A third, translucent overlap, is inert now and live
  for 3e. The table is rewritten, the vertices backend is named authoritative,
  and `CanvasDrawSink.point` changes to match.
- **Criterion 3 could not be implemented as written.** The rasterizer reads the
  triangle buffer; `flush()` destroys it in the same call that submits it. The
  spec now specifies the observer seam. Text never enters the buffer at all, so
  the comparison masks it and asserts the flush count instead. And comparing a
  no-AA raster against an anti-aliased one at a per-pixel tolerance is not a
  bound on anything at one-pixel strokes — the comparison is ink-region
  membership in both directions instead.
- **`flutter_test` is software Skia, so facts 4 and 5 do not hold on the canvas
  side of that comparison** — and its default `devicePixelRatio` of 1 puts the
  corpus's thinnest lineweight at 0.945 device pixels, squarely in the regime
  the two engines treat differently. The fixture pins the ratio and stays above
  the floor, and the spec says out loud what that costs: the sub-pixel rules are
  pinned by unit test and by nothing else.
- **A miter is two triangles, not one.** The draft said "the triangle that fills
  the notch"; the notch is a quadrilateral, and one triangle leaves a hairline
  crack at every mitred corner. Bevel triangle plus tip triangle, and the bevel
  triangle alone past the limit.
- **`Vertices` is disposable and the spike never disposes it** — about 1,140
  undisposed native-backed objects a second at 60 fps. Promoted out of the
  allocation discussion into its own Phase A item, with the open question
  (may it be disposed at submission?) named and assigned a test.
- **Circles have a seam.** `circle` is a full-sweep `_flatten` whose last chord
  lands on its first point, and no mutant covered the join there. Added, with
  the closed-polyline seam beside it — that one is unreachable from the painter
  but directly reachable from a test, so it lands with a mutant rather than as
  unreached code.
- **Criterion 6 needed a definition and a fallback.** Spread is `max - min` of
  three runs and the intervals must not overlap; a tie at 500,000 records the
  crossover and hands it to 3f rather than stalling the plan.
- **The plan may not grant itself the `CLAUDE.md` amendment.** Criterion 7 is
  not satisfied by editing the rule it is measured against.

### Corrected a fact

- The draft cited a 6.88 ms reading that appeared in no note. It is now recorded
  in the spike note where it belongs, as an unreproduced reading and the reason
  every row is a median of three.

### Found a defect in the tree, not in the spec

- `vertices_draw_sink.dart:63` still claims points, circles and arcs go to the
  fallback and that draw order is wrong there. It has been false since the curve
  commit. One review read the comment rather than the code and reported an
  ordering defect that does not exist — which is exactly the cost of a stale
  comment, and why fixing it is Phase A's first task.

### Considered and not changed

- **Backend selection contract** — was underspecified rather than wrong; now
  written out in full, including that `vertices` is honoured on web because
  Phase C needs to force it.
- **`BACKEND` as a string define** — flagged as correctly dodging Plan 3c's
  `bool.fromEnvironment` trap. Said so explicitly, so nobody converts it.
- **Buffer capacity never shrinks** — that is the property that makes the frame
  allocation-free, not a leak. Peak buffer bytes joins the results note.
