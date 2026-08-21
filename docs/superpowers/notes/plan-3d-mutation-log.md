# Plan 3d mutation log

**Follow-up, 2026-08-21:** nine more mutants, run on `main` after the merge
against the new frame-path seam fixture. Eight killed, one survivor that the
existing suite already kills twice by name. Appended at the end; the forty-one
below are unchanged.

**Verdict: forty-one mutants accounted for. Thirty-four killed (two of them
only after a fix round, one of those — `A1` — needing a second, stronger test
after a first fix round proved too narrow), one recorded as a deliberate
control that is expected to survive, two recorded as unreachable dead code
rather than guarded, two recorded as not independently re-mutated with the
reason given, and two cited from the codebase's own confirmed record rather
than re-run.** Fourteen of the thirty-four kills are the design document's
own table — `J1`-`J9`, `B1`, `B2`, `A1`, `V1`, `P1` — run fresh in this task
in twelve mutation-test cycles (two pairs share one code line and one run
each: `J1`/`J6` and `J8`/`J9`, see the note under Part 1). The other twenty
kills, plus the one control, are drawn from the `// MUTATION:` comments the
spike and Tasks 2, 4, 5, 6, 8 and 9 left embedded in the inherited test
suite, plus a handful constructed to reach code the comments describe but do
not spell out, all run fresh in this task against today's code (Part 2, 21
rows). Two survivors surfaced (`A1`, `S2`) and both are closed, in this task,
with a new test each, and both are counted as killed in the total above.

| Category | Count | Outcome |
|---|---|---|
| Named in the design document (`J1`-`J9`, `B1`, `B2`, `A1`, `V1`, `P1`) | 14 | 13 killed outright, 1 (`A1`) survived and was closed |
| Spike-heritage, run fresh in this task (Part 2) | 21 | 19 killed outright, 1 (`S2`) survived and was closed, 1 (`E20_one`) is a deliberate control confirming a documented property |
| Unreachable, recorded as dead code rather than a guard | 2 | `cosHalf <= 0`, `mlen == 0` in `_emitJoin` — see below |
| Cited from the codebase's own confirmed-empirical record, not re-run | 2 | both previously confirmed (Task 2, Task 8) |
| Not independently reproducible, reason recorded | 2 | no discrete code path exists to mutate (structural) |
| **Total accounted for** | **41** | **34 killed, 1 control, 2 unreachable, 2 cited, 2 not reproducible** |

Parts 1 and 2 below run to thirty-three mutation-test cycles: twelve covering
the fourteen named mutants, twenty-one more for the spike-heritage set. The
paragraph below explains what "the spike's 33" means here and why this is
not a reproduction of it.

**What "the spike's 33" means in this log.** The spike's own note
(`docs/superpowers/notes/2026-08-20-vertices-sink-spike.md`) records a tally —
33 mutants, 32 killed, 1 not applicable — but no surviving per-mutant diff:
the individual edits lived only in a session-local script that was never
committed, so there is nothing to replay. What did survive, committed and
inherited, is `// MUTATION:` comments beside most of the tests the spike
shipped in `vertices_draw_sink_test.dart`, plus more that Tasks 2, 4, 5, 6, 8
and 9 added alongside their own work in `vertices_join_test.dart`,
`point_shape_test.dart` and `render_backend_test.dart`. Part 2 below runs
21 mutations drawn from those comments — a mix of genuine spike heritage and
later tasks' own additions to the same suite, not a spike-only set — for real
against today's code. That Part 1 (12) plus Part 2 (21) totals 33 is not a
target this task aimed at and not a claim that the spike's original 33 have
been reproduced; it is reported once, here, rather than repeated as a
coincidence throughout this document.

**How each mutant was applied and reverted.** A Python runner
(`scratchpad/mutate14.py`, session-local, not committed, modelled on Plan 3c's
`mutate13.py`) copies the target file aside, applies the edit, runs the
narrowest test file that should catch it, and restores from the copy in a
`finally` block — **`git checkout` was not used anywhere in this task.**
`git status --porcelain` was read after every mutation and confirmed the
backup-restored file carried no leftover edit; the four real (non-mutation)
changes this task makes — a `debugPaint` getter and three new tests — are the
only diff left in the tree once every mutation run finished, confirmed by
`grep -rn MUTATION packages/jet_cad_2d_flutter/lib/` finding nothing.

**Baseline before this task:** `jet_cad_2d` 720 tests; `jet_cad_2d_flutter`
236 passed / 1 skipped. **After:** `jet_cad_2d` 720 (unchanged, this task
touches no file in that package); `jet_cad_2d_flutter` **238** passed / 1
skipped — two net new tests, one closing `A1` (below) and one closing `S2`
(Part 2); `dart analyze`/`flutter analyze` and `dart format
--set-exit-if-changed` clean in all three packages.

---

## Part 1: the design document's table (14 mutants)

Run fresh in this task against `lib/src/vertices_draw_sink.dart`,
`lib/src/canvas_draw_sink.dart` and `lib/src/draft_canvas.dart`. `J8` and `J9`
share one code line (the seam join's `_emitJoin` call in `_endRun`) and so
share one mutation run; `J6`'s killer is the same `_emitJoin` no-op as `J1`,
reached through the arc fixture rather than a separate line, so it rides on
`J1`'s run rather than a second one.

| # | Mutant | Site | Killed by | Observed |
|---|---|---|---|---|
| J1 | Emit no join triangle at an interior vertex | `_emitJoin` becomes `return;` on entry | 12 of 14 tests in `vertices_join_test.dart`, e.g. `'a zero-length step is skipped and the join spans it'` | `Expected: <6> / Actual: <4>` |
| J6 | Skip the join between two chords of a flattened curve | same `_emitJoin` no-op (`J1`) | `'a flattened curve joins its chords'`, in the same run | `Expected: true / Actual: <false>` |
| J2 | Miter every corner, ignoring the limit | `if (d0x*d1x+d0y*d1y < kMinMiterCosine) return;` → `if (false) return;` | `'a corner past the miter limit is bevelled, one triangle'` (and 12 more) | `Expected: <5> / Actual: <6>` |
| J3 | Bevel every corner, ignoring the limit | same guard → `if (true) return;` | `'a corner just inside the limit is still mitred'` (and 8 more) | `Expected: <6> / Actual: <5>` |
| J4 | Take the miter on the inside of the turn | `s = cross > 0 ? -half : half;` → `? half : -half` | `'a mitred corner emits both the bevel and the tip triangle'` (and 6 more, including the right-angle and clockwise-turn fixtures the mutation's own comment names) | `Expected: true / Actual: <false>` |
| J5 | Join the first and last segment of an *open* polyline | `polyline`'s `_endRun(closed: closed, ...)` → `closed: true` | `'a corner past the miter limit is bevelled, one triangle'` (and 5 more — every open-run triangle count moves) | `Expected: <5> / Actual: <11>` |
| J7 | Emit the miter tip triangle without the bevel | bevel triangle rebuilt from the *inner* corners, honest form (see Task 4) | `'a mitred corner emits both the bevel and the tip triangle'` (and 2 more) | `Expected: true / Actual: <false>` |
| J8 | Cap the seam of a closed flatten instead of joining it | `_endRun`'s seam `_emitJoin` call disabled | `'a circle joins at its seam, so there is no notch at the start angle'` | `Expected: true / Actual: <false>` |
| J9 | Cap the seam of a closed polyline instead of joining it | same disabled call (`J8`) | `'the seam is one join, not two, and not a cap'`, same run | `Expected: <16> / Actual: <14>` |
| V1 | Never dispose the submitted `Vertices` | `vertices.dispose();` deleted | `'the submitted Vertices is disposed, and the flag reads its state'` | `Expected: true / Actual: <false>` |
| P1 | Emit the point square in local space, so it shears with the residual | `CanvasDrawSink.point` reverted to `_pushTransform()` + local-space `drawRect` | `'the marker is axis-aligned on screen under a sheared, non-uniformly-scaled residual'` | `Expected: (maxX: 9, maxY: 9, minX: 6, minY: 6) / Actual: (maxX: 11, maxY: 10, minX: 4, minY: 5)` |
| B1 | Resolve the backend per call site rather than once | `didUpdateWidget`'s comparison drops `widget.backend != oldWidget.backend` | `'changing the backend prop rebuilds the sinks'` | `Expected: not null / Actual: <null>` |
| B2 | Ignore the backend override, always use the platform default | `resolvedBackend = widget.backend ?? defaultRenderBackend();` → drops the `??` | `'only the resolved backend builds a sink'` | `Expected: null / Actual: <Instance of 'VerticesDrawSink'>` |
| A1 | Allocate the `Paint` per flush | field un-finalled, `_paint = Paint()..color = ...` inserted at the top of `flush()` | **survived first run — closed, see below** | `Expected: true / Actual: <false>` (after the fix) |

### J1/J6 and J8/J9: one code line, two rows

The design document lists these as four rows because they name four different
*properties*, but Plan 3d's own architecture (Task 5: "one shared walk") means
an interior-vertex join and a flattened curve's chord join are the same
`_emitJoin` call, and a closed polyline's seam and a closed flatten's seam are
the same call inside `_endRun`. Disabling `_emitJoin` entirely kills both `J1`
and `J6` fixtures in one run; disabling the seam call inside `_endRun` kills
both `J8` and `J9` fixtures in one run. Recording them as four rows with two
runs, rather than four runs, is the honest reflection of the code, not a
shortcut — mutating the shared line twice would be the same edit twice.

### J4's mutation as literally described

The mutant table names one property (miter on the inside of the turn), and
Task 4's own history (`progress.md`, Task 4 entries) found a **second**,
narrower way to reach the same wrong-side behaviour that its first review
missed entirely: collapsing `s = cross > 0 ? -half : half` to the constant
`s = -half` (always the left-turn side) left all 198 tests green until a
right-turn fixture was added specifically to catch it. This task re-ran both:
the sign-flip (`J4` as tabled) and the historic collapse (recorded as `J4b`
below, in Part 2, since it is not a distinct row of the design table but the
same property reached a second way). Both die today, on the same fixture
(`'a right (clockwise) turn is mitred out on its own outer side'` for `J4b`),
because that fixture exists precisely because the first review missed it.

### B1 — what was actually run, and why it stands in for the tabled mutant

The design document's `B1` is "resolve the backend per call site rather than
once," and its stated killer is "a test that overrides the backend and reads
it back from both the widget and the rig." **No such test exists.** There is
no rig-facing read of the resolved backend anywhere in this suite — `main.dart`
prints `backend=` from `DraftCanvasState.resolvedBackend` for the device
harness (`main.dart:288`), but nothing in `render_backend_test.dart` reads it
back through that path, only through `DraftCanvasState` directly.

`B1`'s literal mutation — a second call site independently deciding the
backend — also has no line to invert. `defaultRenderBackend()` is a pure,
unconditional function (`RenderBackend defaultRenderBackend() =>
RenderBackend.vertices;`) with exactly one call site in `lib/`:
`draft_canvas.dart:140`'s `resolvedBackend = widget.backend ??
defaultRenderBackend();`, inside `_attach()`. A second call site calling the
same pure function would always agree with the first, so "two call sites
disagreeing" cannot be written as a mutation of an unconditional function —
it would need new code with nothing to invert, the same shape as the `S1`
and join-local-space entries below.

What this task ran instead is the **property's equivalence class**: caching
the decision once and re-deciding it on every call are indistinguishable
exactly as long as the cache is invalidated whenever the input that fed it
changes. `didUpdateWidget` is that invalidation — `if (... || widget.backend
!= oldWidget.backend) { _changes.dispose(); _attach(); }` — so dropping
`backend` from that comparison is the reachable form of "the cached decision
goes stale relative to what a fresh per-call-site read would give," which is
the same failure the design document's own reasoning names ("a disagreement
would show as a drawing that changes when a widget is rebuilt somewhere
unrelated"). This is a genuine, defensible substitution, not a different
property — but it is a substitution, made without a test for the design
document's own stated fixture, and `Task 15`'s exit-gate reader should treat
`B1` as **killed via an equivalent mutation**, not as the tabled mutation run
literally.

### A1 — the one survivor in the named table, closed in two rounds

**Round 1.** `paint_allocation_test.dart` measures `debugCapacityVertices`,
which pins the two buffers but has no way to see a `Paint` object, because a
`Paint` is not part of either buffer. Mutating `flush()` to *reassign the
`_paint` field* to a fresh `Paint()..color = const Color(0xFFFFFFFF)` on
every call left every existing assertion in the file green:

```
[A1] file: lib/src/vertices_draw_sink.dart
+0: a steady-state frame allocates O(1) per flush, not O(entities)
All tests passed!
```

Closed, in the first pass, by adding a `debugPaint` getter (`Paint get
debugPaint => _paint;`) and pinning its identity across the subject frame.
That killed the field-reassignment form: `Expected: true / Actual: <false>`
on the `identical` check.

**Round 2 (post-review).** That fix is narrower than `A1`'s own title. A
reviewer wrote a mutation that never touches the field at all — a
call-site-local `Paint`, built fresh and handed straight to the call:

```dart
canvas.drawVertices(
  vertices,
  BlendMode.dst,
  Paint()..color = const Color(0xFFFFFFFF), // never assigns to _paint
);
```

Run against the round-1 fix and the full suite: **survived both**, `+238 ~1:
All tests passed!` — the `debugPaint` check is a field read, and the field
genuinely never changed, so it cannot see a Paint built and discarded at the
call site itself. Re-verified by the controller directly (not taken from the
reviewer's report): copied `vertices_draw_sink.dart` aside, applied the exact
mutation above, ran `paint_allocation_test.dart` (green) and the full
238-test suite (green), restored from the copy, confirmed `git status
--porcelain` clean.

**Closed for real** by reading what `dart:ui` actually receives, through
`test/support/spy_canvas.dart` (already in the tree, built for
`draft_painter_test.dart`'s call-recording needs). A new test flushes twice
and pins that `canvas.drawVertices`'s own `Paint` argument is `identical`
across both calls:

```dart
final calls = spy.named('drawVertices').toList();
final paints = calls.map((c) => c.args.whereType<Paint>().single).toList();
expect(identical(paints[0], paints[1]), isTrue, ...);
```

Re-run against the reviewer's mutation: **killed**, `Expected: true / Actual:
<false>`, on this `identical` check specifically, with the round-1 test and
the rest of the 238-test suite staying green — which is the point: this is
the one instrument that reads the call itself rather than any field, so a
`Paint` allocated anywhere on the way to `drawVertices` — a reassigned
field, a call-site-local temporary, or anything else with the same shape —
has to fail it. Both rounds' assertions are kept: the field-identity check is
still a real, narrower property (`_paint` is not reassigned), and the new
call-site check is the one that actually closes `A1` as named.

---

## Part 2: the inherited suite's own mutations (21, after one duplicate merge)

Each of these is either an existing `// MUTATION:` comment in
`vertices_draw_sink_test.dart`, `vertices_join_test.dart`,
`point_shape_test.dart` or `render_backend_test.dart` — most inherited from
the spike, some added by Tasks 2, 4, 5, 6, 8 and 9 — run for real against
today's code, or a mutation constructed to reach a documented finding
(`E`-prefixed below) that has no single-line comment of its own.

| id | Mutant | Killed by | Observed |
|---|---|---|---|
| S2 | Group the vertices by colour before flushing, instead of preserving emission order | **survived first run — closed, see below** | see below |
| S5 | A flush with nothing batched still tries to dispose | `'a flush with nothing batched disposes nothing'` | `Expected: <0> / Actual: <1>` |
| S6 | Hand the observer the whole buffer rather than the submitted view | `'the observer sees exactly what was submitted, before the rewind'` | `Expected: <12> / Actual: <8192>` |
| S8 | Call the observer unconditionally, even on an empty flush | `'the observer sees exactly what was submitted, before the rewind'` (calls count moves) | `Expected: <1> / Actual: <2>` |
| S10 | Replace the segment count with a constant 8 | `'the flattened arc stays within a quarter pixel of the true one'` | `Expected: a value less than <0.25> / Actual: <0.9607...>` |
| S11 | Take the radius in local space instead of device space | `'the segment count follows the arc as the residual scales it'` | `Expected: a value greater than <32> / Actual: <8>` |
| S12 | Emit nothing for a point | `'a point is a square of the stroke width, at the residual'` | `Expected: <1> / Actual: <0>` |
| S13 | Let text reach the fallback without flushing first | `'an unbatchable op flushes first, so draw order holds across it'` | `Expected: <2> / Actual: <1>` |
| S14 | Report `lastFlushSegmentCount` as the frame total | same test, second assertion | `Expected: <4> / Actual: <1>` |
| S15 / S17b | Drop `devicePixelRatio` from the half-width floor (`_halfWidthFor`) — the same code line under two names, merged, see note | `'a sub-pixel stroke gets one device pixel and loses alpha for it'`, `'a lineweight of zero is a hairline at full alpha'`, `'the floor is device pixels, so it moves with the ratio'` | `Expected: a numeric value within <1e-6> of <0.25> / Actual: <0.5>` |
| S16 | Clamp the width without touching the alpha (`_coveredArgb` returns `argb` unchanged) | `'a sub-pixel stroke gets one device pixel and loses alpha for it'` | `Expected: <3422552064> / Actual: <4278190080>` (0xCC000000 vs 0xFF000000) |
| S17 | Drop `devicePixelRatio` from `_coveredArgb`'s own `deviceWidth` (the alpha-fade width, a distinct line from `S15`/`S17b`'s floor — constructed, not from a single comment) | `'a sub-pixel stroke...'`, `'every emitter fades, not just the straight one'`, `'the fade multiplies the style alpha...'` | `Expected: <3422552064> / Actual: <1711276032>` |
| S18 | Let zero fall through to the proportional fade | `'a lineweight of zero is a hairline at full alpha'` | `Expected: <4278190080> / Actual: <0>` (alpha to 0x00) |
| S19 | Pass `style.argb` directly in `point()`, bypassing the fade | `'every emitter fades, not just the straight one'` | `Expected: <3422552064> / Actual: <4278190080>` |
| S20 | Write the coverage as the alpha instead of scaling the style's own alpha by it | `'the fade multiplies the style alpha rather than replacing it'` | `Expected: <1712469078> / Actual: <3423745110>` |
| J4b | Collapse `s = cross > 0 ? -half : half` to `s = -half` (Task 4's historic survivor, see Part 1 note) | `'a right (clockwise) turn is mitred out on its own outer side'` | `Expected: true / Actual: <false>` |
| E17 | A zero-length step loses the run's accumulated direction (`_runHasDirection = false` on the skip) | `'a zero-length step is skipped and the join spans it'` | `Expected: true / Actual: <false>` |
| E20_one | Disable only the `cross == 0` bail in `_emitJoin` | **expected non-kill, see note** | all 14 tests pass |
| E20_all | Disable all three of `_emitJoin`'s bails at once (`cross == 0`, `dot < kMinMiterCosine`, `mlen == 0`) | `'a corner past the miter limit is bevelled, one triangle'` (and 1 more) | `Expected: <5> / Actual: <6>` |
| E21 | Build both sinks unconditionally in `_attach()` | `'only the resolved backend builds a sink'` | `Expected: null / Actual: <Instance of 'VerticesDrawSink'>` |
| E22 | Swap `a` and `d` in `CanvasDrawSink.point`'s coordinate math | `'the marker is axis-aligned on screen under a sheared, non-uniformly-scaled residual'` | `Expected: (maxX: 9, minX: 6, ...) / Actual: (maxX: 7, maxY: 12, minX: 3, minY: 8)` |

That is 21 rows in this table (`S2` counted, `S15`/`S17b` merged into one).
Combined with the 12 mutation *runs* in Part 1 (which cover 14 rows, `J1`/`J6`
and `J8`/`J9` sharing), that is **33 distinct mutations executed in this
task.**

### E20_one — a control, not a survivor

`vertices_join_test.dart`'s own comment on `'a closed run of two points closes
without a phantom seam'` (the fixture two points make: one segment out, one
back) states that disabling `_emitJoin`'s `cross == 0` bail alone does not
reach the division-by-zero the fixture is built to catch. This task re-ran
that claim rather than take it on faith: disabling only `cross == 0` left all
14 tests in the file green, because `dot < kMinMiterCosine` — still active —
catches the same exact reversal on its own (`dot` is exactly `-1` for a
180-degree reversal, well below the `-0.875` threshold, so this bail fires
whether or not `cross == 0` was checked first). `E20_all` — `cross == 0`,
`dot < kMinMiterCosine` *and* `mlen == 0` all disabled together — then does
fail, on `v.isFinite` reading false. `E20_one` is recorded as a **deliberate
control**, not an open survivor: it shows `cross == 0` is redundant with
`dot < kMinMiterCosine` for this one fixture, which is a fact about the code.
It does **not** show that `mlen == 0` is reachable on its own — see the next
section, which the first version of this log conflated with this one.

### Two branches recorded as unreachable, not guarded

`progress.md:68` (Task 4) records that `cosHalf <= 0` and `mlen == 0` inside
`_emitJoin`'s tip-triangle computation (`vertices_draw_sink.dart:401`,
`:406`) are unreachable **given the `dot < kMinMiterCosine` bail at line 397
being active**: that bail bounds the turn angle at roughly 151 degrees before
either line is ever reached, and neither can be produced by any narrower
angle. The first version of this log filed both under `E20_one`'s "no single
bail is load-bearing alone" — which is true of `cross == 0` (the previous
section) but is the wrong frame for these two: they are not redundant with
another guard for one fixture, they are **dead code under the shipped
configuration**, full stop.

Re-confirmed directly in this fix round, each in isolation, against the
*entire* 238-test suite rather than the 14-test join file alone (`cross == 0`
and `dot < kMinMiterCosine` both left active):

```
mlen == 0    -> `if (false && mlen == 0) return;`    -> +238 ~1: All tests passed!
cosHalf <= 0 -> `if (false && cosHalf <= 0) return;`  -> +238 ~1: All tests passed!
```

Neither is counted as killed, tested, or guarded anywhere in this log's
tally; both are recorded as **not applicable**, with the file:line that makes
each unreachable, per the same convention Plan 3c's `S10` used for a mutant
with no site at all. (`E20_all`'s crash, above, is a different, compound
experiment — disabling all three checks including `mlen == 0`'s own line —
and does not bear on whether `mlen == 0` is reachable when `dot <
kMinMiterCosine` is left active, which it is not.)

### S2 — the other survivor, closed

`'draw order survives batching: segments stay in emission order'` reads
`sink.debugColors()` **before any `flush()` runs** — it pins that `polyline`
writes `_colors` in call order, which is true by construction (nothing
reorders on the way in) and therefore cannot see a reorder introduced *inside*
`flush()`, on the way to `drawVertices` — which is exactly where the sink's
first shipped cut had its real bug (the class comment: "every segment of one
colour then drew after every segment of another whatever order the walk
emitted them in"). Grouping the vertices by colour inside `flush()`, before
building the submitted view, left this test green:

```
[S2] file: lib/src/vertices_draw_sink.dart
+31: All tests passed!
```

**Closed** by adding `'draw order survives the flush itself, not just the
pre-flush buffer'` (`vertices_draw_sink_test.dart:172-206`), which attaches
`sink.observer` and reads the colours the observer actually receives, rather
than the pre-flush buffer. Re-run against the widened file: **killed**,
`Expected: equals [4294901760, 4278255360, 4294901760] ordered / Actual:
[4278255360, 4294901760, 4294901760]` (0xFFFF0000, 0xFF00FF00, 0xFFFF0000
read back unsigned) — green, red, red instead of red, green, red, on the new
test specifically; the old test stays green either way, exactly as diagnosed.

**What this new test constrains, precisely.** The observer's view is *today*
identical to what `Vertices.raw` receives, but the test does not pin that —
it pins only what the observer is handed, one call earlier in `flush()`.
Confirmed directly: grouping by colour *after* `observer?.call(positions,
colors)` and *before* `Vertices.raw(...)` — so the observer still sees
emission order and only the submitted `Vertices` is reordered — survives the
new test **and the full 238-test suite, goldens and `sink_comparison_test.dart`
included**. The `S2` mutation this log logs (grouping before the observer
call) is genuinely killed; a narrower, later-reordering variant of the same
property is not. Recorded here rather than left implicit.

---

## Two mutations cited, not re-run

**Dispose before `drawVertices` instead of after.**
`vertices_draw_sink_test.dart`'s `'the disposed Vertices rasterises the same
pixels a retained one would'` carries its own confirmed record: "swapping the
two lines fails an `assert(!vertices.debugDisposed)` inside `dart:ui`'s
`Canvas.drawVertices`, before this expectation is ever reached." That is an
engine-level assert, not a test assertion this suite could re-derive, and
Task 2's review (`progress.md`, Task 2 entries) already ran this exact swap
and confirmed the crash independently. Not re-run in this task; the citation
is to that engine assert and to Task 2's own re-run, not to the comment alone.

**Move the observer call to after the `assert` block.**
`'the observer sees exactly what was submitted, before the rewind'` records
that this one is unfalsifiable through any public API: `Vertices.raw` copies
`positions`/`colors` into native memory synchronously at construction, so the
three-line window between `vertices.dispose()` and the `assert` block that
reads `debugDisposed` has no observable side effect, whichever side of that
window the observer call sits on. Task 8's review reached the same conclusion
independently (`progress.md`, Task 8: "An honestly unfalsifiable window,
recorded rather than papered over"). Not re-run in this task for the same
reason it was not run again in Task 8: there is nothing a re-run could show
that the first one did not already rule out.

## Two mutations not independently re-mutated

**S1 — take the perpendicular in local space and transform it with the
segment.** `polyline` transforms every point (`a*points[i]+c*points[i+1]+e`,
similarly for `y`) *before* `_beginRun`/`_runTo` ever compute a direction or a
normal — there is no local-space normal anywhere in `_runTo`, `_emitQuad` or
`_emitJoin` to redirect; all three only ever see already-device-space
coordinates. Reaching the described mutation would mean writing a second,
parallel geometry path (compute direction from the untransformed points, take
its normal, transform *that*), which is not a mutation of a line that exists
today — it is new code with no counterpart to delete or invert. The property
is structurally guaranteed by the code's shape, and pinned by `'stroke width
is device pixels under a non-uniform residual'`, which already passes against
today's code and would need that same non-existent path to fail.

**The equivalent for joins ("joins are emitted under the residual, not in
local space").** The same argument applies one level up: `_emitJoin` receives
`vx, vy, d0x, d0y, d1x, d1y` that are already device-space by the time
`_runTo` calls it, for the identical reason. `'joins are emitted under the
residual, not in local space'` pins it and, notably, was one of the tests `J4`
and `J4b`'s mutations both broke as a side effect (both appear in Part 1 and
Part 2's failing-test lists above) — real evidence that the residual-space
property is exercised on every join mutation this task ran, even without a
dedicated local-space-join mutant to run against it directly.

---

## What this does not cover

Consistent with Task 11's architectural finding (`progress.md`, Task 11), and
correcting the first version of this log against it: the seam join and the
point-shape fix are not equally reachable, and calling both "unreachable" is
wrong for one of them.

- **`J9`** — capping the seam of a closed *polyline* instead of joining it —
  is genuinely unreachable from the frame path: `closed:` is `false` at all
  four of `draft_painter.dart`'s `polyline` call sites, so no drawing this
  repository can generate ever calls `VerticesDrawSink.polyline(...,
  closed: true)`. This log's `J9` mutation is killed only because
  `vertices_join_test.dart` calls it directly, exactly as the design
  document's own table says ("no painter reaches this").
- **`J8`** — capping the seam of a closed *flatten* (a circle) — is
  **not** unreachable. `progress.md:122` corrects the claim this log first
  made: the painter *does* reach `closed: true`, via `sink.circle`
  (`draft_painter.dart:588`, `:619`), for every circle entity the corpus
  draws. The seam geometry is on the frame path already. What is missing is
  a test that reads the actual triangle buffer *through* the painter and
  checks the seam is joined there — the goldens and `sink_comparison_test.dart`
  compare ink regions and pixel coverage, neither of which is built to
  isolate one join's few square pixels from the rest of a drawn circle. The
  seam is **unobservable through the painter with today's instruments, not
  unreachable by it.**
- **`J5`, `P1`** — `draft_painter.dart` routes point, line and polyline
  through `_emitScreenSpace`, whose residual is a bare
  `Transform2.translation`, so a *rotated or sheared* residual — the
  specific case `P1`'s fixture needs — never reaches `point` through the
  frame path, and an *open* polyline forced closed (`J5`'s shape) is not
  a distinct entity the corpus generates either.

This log pins what the sink does when driven directly, through
`VerticesDrawSink`'s own interface; it does not claim `J5`, `J8`, `J9` or
`P1` are exercised end to end through `DraftPainter`. `J8` is the one row
where that gap is a testing gap rather than an architectural one, and a
future task could close it by reading `debugPositions()` after a painter
frame that draws a circle, rather than by adding a new mutant.

---

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart` — one getter
  added, `debugPaint`, exposing `_paint`'s identity for `A1`'s round-1 test.
  No behaviour change.
- `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart` —
  two tests for `A1`: the round-1 `debugPaint` identity check, and the
  round-2 `SpyCanvas`-based check of what `drawVertices` actually receives,
  which is the one that closes it.
- `packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart` — one new
  test, `'draw order survives the flush itself, not just the pre-flush
  buffer'`, closing `S2`.

## Reproducing

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/vertices-spike

# baseline
(cd packages/jet_cad_2d          && dart test)      # 720 pass
(cd packages/jet_cad_2d_flutter  && flutter test)   # 238 pass, 1 skip

# the two mutants that needed new tests, narrowest suite each
(cd packages/jet_cad_2d_flutter && flutter test \
  test/vertices_draw_sink_test.dart \
  test/invariants/paint_allocation_test.dart)
```

The runner used for the mutants themselves is `scratchpad/mutate14.py`
(session-local, not committed). Its shape:

```python
shutil.copy(path, backup)          # NOT `git checkout` -- see the header above
try:
    apply_edits(path, spec["edits"])
    proc = run(["flutter", "test", *spec["narrow"]])
    killed = proc.returncode != 0
finally:
    shutil.copy(backup, path)
    os.remove(backup)
    assert git_status_porcelain(spec["file"]) == expected  # clean modulo the
                                                             # three real edits
```

Every mutation's exact `old` → `new` strings live in that script; the `Site`
and `Killed by` columns above name the file and test for each.

---

## Part 4 — the frame-path seam fixture, 2026-08-21

Run on `main` at `70d824e`, against
`packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart`, which did not
exist when Parts 1–3 were written. Same discipline as the rest of this log:
`cp` the file aside, apply the edit, run the narrow suite, restore from the
copy in a `trap` — **never `git checkout`**, for the reason the header gives.

All nine mutate `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart`.
Narrow suite: `flutter test test/frame_path_seam_test.dart`.

| # | Mutation | Site | Outcome |
|---|---|---|---|
| S3 | `_endRun`'s closed branch returns unconditionally | `_endRun` | **killed** — centreline blank at `[0, 352…359]` |
| S4 | seam join dropped, closing chord kept | `_endRun` | **killed** — triangle count `4c − 2` |
| S5 | closed walk runs to `steps`, not `steps − 1` | `_flatten` | **killed** — open-sweep comparison |
| S6 | `circle` forwards `closed: false` | `circle` | **killed** — centreline and count |
| S7 | closing chord dropped, seam join kept | `_endRun` | **killed** — centreline |
| S8 | zero-length step no longer skipped | `_runTo` | **survived** — see below |
| S9 | seam join's two directions swapped | `_endRun` | **killed** — wedge on the inner side |
| S10 | `s = cross > 0 ? half : -half` — every join flips inward | `_emitJoin` | **killed** — wedge on the inner side |
| S11 | bevel triangle dropped, tip only | `_emitJoin` | **killed** — triangle count |

**S8 survived and is not this fixture's job.** `if (length == 0) return` guards
a repeated point, and no step of a flattened circle is exactly zero-length. The
widget suite kills it twice, by name: `a zero-length segment emits nothing
rather than a NaN normal` in `vertices_draw_sink_test.dart` and `a zero-length
step is skipped and the join spans it` in `vertices_join_test.dart`. Verified by
running the whole widget suite under S8 and reading both failures.

**S5 is the one that changed a belief.** `_flatten`'s comment predicts that
closing a sample too late leaves "a duplicated point instead of a join", and
the natural reading is that `_runTo`'s zero-length guard absorbs it and nothing
changes. It does not: `cos(2π)` does not land back on the first point, so the
extra step is a real sub-pixel chord with its own join, and the seam join is
then taken from that noisy direction. Measured **172 triangles against 168** on
the fixture. Both divide by 4, so the divisibility assertion is blind to it —
which is why the fixture also compares against the open full-sweep arc.

**What no mutation could reach.** `_emit`'s `point`, `line` and `polyline`
cases in `draft_painter.dart` were emptied in the same session, and no mutation
of them is listed here because none is meaningful: `_drawLeafComposed` returns
before reaching them, unconditionally, so any edit survives every suite. That
is a control-flow fact, not a coverage result. The inverse was measured
instead — throwing at the top of `_emitScreenSpace` fails 114 test lines, which
is where the traffic actually goes.
